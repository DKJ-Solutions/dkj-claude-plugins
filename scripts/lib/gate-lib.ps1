<#
.SYNOPSIS
    Gate evidence: record what the gates proved, against which exact working state -- and notice
    when that state moved while they ran.

.DESCRIPTION
    The gates (lint + test suites) are expensive and are frequently asked to prove the same thing
    twice. ship-pr.ps1 calls open-pr.ps1, which runs both; on a branch whose PR is already open
    open-pr skips only the `gh pr create` and runs the gates anyway. So a branch that was opened in
    one step and shipped in a later one pays for the identical commit twice.

    MEASURED BEFORE IT WAS BUILT (August 16, 2026), because the figure in circulation was wrong.
    Over 293 merged PRs, the gap between the gating CI run going green and the merge landing is
    sharply bimodal: 205 merges land within 60s (median 14s) and 83 land at a median of 263s, with a
    void between 60s and 180s and an interior peak at 240-300s. A void followed by an interior peak
    is a fixed-cost operation; human delay produces a monotonic tail with no interior peak. The one
    confound that could fake it -- ship-pr waiting on a second CI run -- was ruled out: zero of the
    83 have a push-event run on the same sha. So the excess is 249s on 28.3% of merges, not the
    "3m 27s, 3m 18s, ~3 min, 4m 02s, 4m 18s across five releases" the release notes carried. That
    series conflates the whole merge-with-fold leg with the gate re-run inside it; only v4.9.0
    separates the two.

    WHAT THE WORKAROUND WAS, AND WHY IT IS THE ACTUAL DEFECT. The practitioner's answer has been
    `ship-pr.ps1 -SkipLint -SkipTests`, used deliberately because the identical commit passed both
    gates minutes earlier. It is correct exactly while the commit is unchanged, and dangerous the
    moment it is not -- and NOTHING CHECKS THAT. The flag is doing the design's job without the
    design's safety. So the repair is not a better flag or a default-off gate: it is to make the
    unchanged case provably not need one.

    THE EVIDENCE IS THE CONTENT, NOT THE CLOCK AND NOT A PROMISE. A gate run is recorded against a
    fingerprint of precisely what it judged -- HEAD, plus the content of every dirty and untracked
    file. If the fingerprint still matches, re-running the gate cannot reach a different verdict,
    and the skip is a deduction rather than a favour. If anything moved, the fingerprint moves with
    it and the gate runs, with nobody having to remember why.

    WHY HEAD ALONE IS NOT ENOUGH, stated because it is the obvious shortcut. `git status --porcelain`
    reports that a file is modified, never what it was modified TO -- so a file edited, gated, and
    edited again presents an identical status line over different content. The fingerprint therefore
    hashes the dirty files themselves. On the common case (a clean tree, which is what open-pr and
    ship-pr both see) that costs one `git rev-parse` and nothing else.

    WHAT THE FINGERPRINT DOES NOT COVER, so nobody reads it as stronger than it is:
      - GITIGNORED FILES. They are outside `git status` by definition, so a gate input that lives in
        one is invisible here. Nothing in this repo's gates reads one; a consumer whose does should
        not rely on this skip.
      - THE ENVIRONMENT. A git, PowerShell or dependency upgrade between two runs changes what the
        suites do without changing a byte in the tree. That is what the age bound below is for --
        not a safety property of the content, but an honest limit on how long "nothing moved" is
        allowed to stand in for "nothing changed".

    AND WHY IT IS THE WHOLE TREE RATHER THAN PER SUITE -- MEASURED, AND DECLINED (issue #2323,
    September 22, 2026). The objection is obvious and correct as far as it goes: one fingerprint over
    the whole tree means ANY commit discards the proof for every suite at once, so a comment-only edit
    throws away 130 green runs. It has a nasty circularity too -- #2317's measured instance was a
    commit the gate itself had demanded, a comment having pushed a `return` outside a test's 400-char
    window. Fixing what the gate asked for is what cost the re-run. The proposal was a per-suite proof
    keyed on the files that suite actually reads, so an edit to a file no suite reads keeps the other
    129.

    THE MEASUREMENT WAS POSSIBLE BECAUSE THE ERROR ONLY RUNS ONE WAY. Nothing here knows what a suite
    reads -- a suite is a `powershell` child that dot-sources libs, globs directories, builds git
    fixtures and shells out, and its read set is neither statically knowable nor constant between
    runs. But a static model of that read set is a FLOOR on the real one, so the survival rate it
    produces is a CEILING on what any per-suite scheme could recover. A low ceiling therefore settles
    the question without anyone having to build the mechanism first.

    WHAT IT SAID. Over 1,114 non-merge commits in the 14 days after the September rename (branch
    documents and the trunk's own fold and release commits excluded, leaving 606 that touch code or
    docs), the issue's own target class -- at most two files and twenty lines under `scripts/**` or
    `plugins/**` -- is 39 commits, 3.5% of the population. For those, the ceiling is a median 88.5% of
    suites and 80.5% of suite-seconds. Real, and never the whole prize, because of three things the
    numbers made visible:

      - IT NEVER REACHES 100%. Sixteen of the 130 suites are whole-tree self-checks: they lint every
        `.md` and every manifest, or scan `scripts/**` against its mirror. Scanning the tree IS what
        they do, so no keying scheme can narrow them, and every commit under `scripts/**` or
        `plugins/**` loses nine to fourteen suites structurally. They are 12.3% of the count and 20.7%
        of the seconds.
      - A FEW LIBS ARE IN NEARLY EVERY READ SET. `command-probe-lib.ps1` is in 94 of 130 (72%),
        `repo-root-lib.ps1` in 84, `check-report-lib.ps1` in 79 -- mostly reached transitively, through
        libs that almost every suite loads. A commit touching one of them is close to the status quo
        whatever the mechanism.
      - WALL CLOCK RUNS 10-15 POINTS BEHIND SUITE COUNT, consistently. The suites that never survive
        are the expensive ones, so the count overstates what is actually bought.

    AND THE DECIDING FACT IS NOT THE NUMBER, IT IS THE CHEAPER ALTERNATIVE. #2317's lever 1 -- when
    the local proof is stale but CI for this exact commit is in flight, wait for the certificate
    instead of re-proving -- removes the expensive instance ENTIRELY, where a per-suite proof recovers
    about four fifths of it. The merge cannot land before that check is green anyway, Get-CiTestCertificate
    below is already the reader it needs, and 100% beats 80% at a fraction of the machinery. What is
    left over for a per-suite scheme is the narrower case lever 1 cannot reach: local iteration before
    any certificate exists. Nobody has measured how often that happens or what it costs, and THAT
    measurement -- not a rebuild of this one -- is what would reopen this.

    AND #3223 IS NOT THAT PROPOSAL REOPENED (October 20, 2026). Get-AffectedSuiteSelection below runs
    the suites a branch's changes can affect, but it RECORDS nothing: the evidence here still means
    every suite passed, and the required CI check still runs every suite before the merge. So a suite it
    misses costs a red CI run, not an ungated merge -- the hint bar this paragraph holds a per-suite
    proof to, met by not being a proof at all.

    WHY EACH OF THE THREE SHAPES FAILS THE BAR. Get-TestSuiteCostHints states the bar for its own
    file: a hint that can only cost wall clock, never coverage. A per-suite proof is not a hint. A
    false negative costs one suite run; a false positive skips a suite on a tree it never measured,
    and unlike the CI certificate -- which is stronger evidence than the run it replaces -- there is
    nothing behind the local proof to catch one. DECLARED, each suite naming its own inputs in a
    header, is cheap and drifts silently, which fails in precisely that direction; the static model
    above took three iterations to get right and the dependency graph moved twice while it was being
    built. COARSE ZONES is undercut by the near-universal libs: any boundary coarse enough to be
    practical bundles them with everything else. OBSERVED, recording what each suite actually opened,
    is the only shape that meets the bar, and it is a large amount of Windows-specific machinery for a
    saving that is now the secondary one.

    AND THE SAME FINGERPRINT ANSWERS A SECOND QUESTION, ASKED AT THE OTHER END OF THE RUN (issue
    #1145). Before the gates it decides whether they may be skipped; after them, compared with a
    fresh reading, it says whether the tree the gates judged is still the tree in front of you. It
    does not answer that one alone -- a checkout borrowed and handed back leaves the fingerprint
    identical -- so Get-GateHeadMoveCount reads HEAD's reflog depth beside it, and
    Get-GateTreeMovedNote is what the callers actually ask.

    THE STATE LIVES IN THE GIT DIRECTORY, deliberately. It is guaranteed present, guaranteed local,
    guaranteed never committed, and per-worktree -- so a linked worktree cannot inherit the trunk's
    evidence. That is four properties a tracked file plus a .gitignore entry would each have to be
    given, in every consumer, correctly.

    CI IS UNAFFECTED AND MUST STAY SO. A fresh checkout has no state file, so ci.yml always runs the
    gate for real. The skip is a local-only optimisation over a local-only redundancy; the required
    merge check never consults it.

    NOT MOVED HERE: Invoke-TestSuiteGate. native-capture-lib.ps1's own note asks that if a second
    gate helper ever appears, both move out together rather than that file being widened again --
    and this file is that second helper. It is deliberately NOT taken in this change: the move would
    put ci.yml, the one check that blocks every merge, into the same diff that changes gate
    behaviour, and coupling those two risks buys nothing. The constraint the note actually states is
    honoured -- native-capture-lib is not widened. The move is a clean follow-up on its own.
#>

# THE PROSE SANITISER FOR EXTERNALLY-AUTHORED NAMES, loaded here rather than asked of the caller
# (issue #1715). Get-CiTestCertificate below prints check names read out of a `gh` payload, and a
# check's displayed name is chosen by whoever produced it. remote-ahead-lib.ps1 and
# entry-scaffold-lib.ps1 both load this the same way, for the reason their own notes give:
# ref-print-lib.ps1 is a leaf with no dependencies of its own, which is what makes it safe to load
# first -- so this is not the class of dependency the header above asks the caller to supply.
. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

# AND THE CLOSE-OUT SUPPRESSION, so a gate run can step out of a chain it is not part of (issue
# #1910). command-probe-lib.ps1 is a leaf like ref-print-lib above, on the same grounds, and carries
# Test-FunctionDefined. closeout-lib.ps1 is a leaf too, but its dot-source is GUARDED, on the
# reasoning open-pr.ps1 already gives for its own: these files are mirrored into every consumer's
# plugin cache and arrive by plugin UPDATE rather than by choice, so a consumer whose mirror predates
# that lib must not crash on LOAD of the file that gates their push.
#
# LOADED HERE RATHER THAN ASKED OF THE CALLER, unlike the two libs the header above does ask for.
# open-pr.ps1's -GatesOnly short-circuit reaches Invoke-WorkflowGates BEFORE that script dot-sources
# closeout-lib itself -- deliberately, since the short-circuit sits above the branch check and the
# lib sits below it -- so a caller-supplied dependency would leave exactly one of the two gate call
# sites silently uncovered, and silently is how #1910 got there in the first place. No line numbers:
# the ORDER is the load-bearing fact and the distance is not, and a cited number rots on the next edit.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')
$gateCloseoutLib = Join-Path $PSScriptRoot 'closeout-lib.ps1'
if (Test-Path -LiteralPath $gateCloseoutLib -PathType Leaf) { . $gateCloseoutLib }

# AND THE SHA-256 RENDERING (issue #2058). A leaf with no dependencies, like the two above, and
# loaded UNGUARDED rather than on closeout-lib's pattern: Get-GateFingerprint cannot produce a
# fingerprint without it, so a payload missing this file must fail at LOAD rather than fall through
# to a guard and then crash one call deeper, where the failure no longer names the missing file.
# That is merged-pr-lib.ps1's reasoning at sync-main.ps1, and it applies wherever the dependency is
# required rather than optional.
. (Join-Path $PSScriptRoot 'hash-hex-lib.ps1')

# AND THE PORCELAIN READ AND ITS LINE PARSE (issue #2102), which park-lib.ps1 and fanout-lib.ps1 both
# dot-source too -- that shared ownership is the whole point of the file, and Get-NoteTreeOnlyVerdict
# below is its third consumer. GUARDED, on fanout-lib's grounds rather than hash-hex-lib's above: this
# file is mirrored into every consumer's plugin cache and arrives by plugin UPDATE rather than by
# choice, and everything else in this lib works without it -- so a mirror that predates the porcelain
# lib must not crash on LOAD of the file that gates their push. The one function that needs it reports
# "could not be read", which is already its answer for a git call that fails.
$gatePorcelainLib = Join-Path $PSScriptRoot 'git-porcelain-lib.ps1'
if (Test-Path -LiteralPath $gatePorcelainLib -PathType Leaf) { . $gatePorcelainLib }

# How long a recorded pass is allowed to stand in for a fresh run. Not a content property -- the
# fingerprint already covers content exactly -- but a bound on the environment drifting underneath
# it. Four hours comfortably covers the measured case (open-pr and ship-pr minutes apart) while
# refusing to let yesterday's green decide today's push. A constant rather than a parameter, so it
# cannot become another knob somebody sets to skip a gate.
$script:GateEvidenceMaxAgeMinutes = 240

# The recognised gate names. A typo in a caller would otherwise record evidence nothing ever reads,
# which fails in the worst direction: silently, as a gate that keeps running.
$script:GateEvidenceKnownGates = @('lint', 'tests')

# HOW LONG A CALLER WILL WAIT FOR AN IN-FLIGHT CI CERTIFICATE BEFORE RUNNING THE SUITES ANYWAY --
# issue #2317. The wait replaces a local pool run with the CI run that is already proving the same
# commit, so the bound is sized against what that run costs rather than against anybody's patience.
# The figures are in ci.yml's own `timeout-minutes` banner, re-derived there from the run history
# rather than restated here: over its 19 most recent runs the slowest shard was shard 2 at a median
# of 12.5 min and a maximum of 13.4 min. Against that, #2317 measured one of its own local pools at
# 43.3 minutes reaching the same verdict.
#
# 1800 SECONDS IS AN UPPER BOUND ON THE WAIT, NOT AN ESTIMATE OF THE RUN, AND IT IS SIZED OFF THE
# WHOLE DISTRIBUTION RATHER THAN OFF THE MEDIAN. Measured September 22, 2026 over the 98 most recent
# completed CI runs, end to end: median 693s, six runs over 900s (1137, 1194, 1378, 1413) and two over
# this bound (3422s and 4273s). The shape is a tight body with a long, sparse tail, and the tail is
# NOT suite runtime -- it is GitHub runner-queue contention, one shard starting 15-70 minutes late
# while its siblings start on time and finish normally.
#
# THE TAIL IS WHY THE BOUND IS HIGH AND NOT WHY IT SHOULD BE LOW, which is the reading worth writing
# down because the obvious one is backwards. A review of this constant proposed lowering it to 900s on
# the ground that everything above that is queueing rather than real CI. True, and it does not follow:
# what decides the saving is not whether a run was QUEUED but whether it CERTIFIES BEFORE THE BOUND,
# and all four runs between 900s and this bound did. Lowering to 900s would give up on those four --
# paying the wait AND the pool on each -- to cap the loss on the two above it. On this distribution
# that is a worse trade, four times over.
#
# AND THE WORST CASE IS NOT "THE BOUND PLUS THE POOL", WHICH IS WHAT THIS COMMENT SAID FIRST AND IS
# TOO PESSIMISTIC BY THE WHOLE OF ITS OWN POINT. That figure is what an expired wait costs THIS RUN;
# it is not what the change costs, because the run it is compared against also cannot merge until the
# required check is green -- ship-pr waits for exactly that in its own step 3. So against the old
# behaviour the loss is (bound + pool) - max(pool, T) for a check finishing at T, which is at its
# worst when T lands just past the bound (loss about the bound) and shrinks to nothing as T grows:
# at the measured 4273s the old path was already waiting out the same queue, and the loss is minutes.
#
# THE TRADE, THEN: the body of the distribution saves a whole pool run, and the losing case is a check
# that finishes just after a bound sized past 97% of this repo's recorded runs.
#
# THE FALL-THROUGH IS ALSO WHY THE NUMBER IS ALLOWED TO BE APPROXIMATE, in the direction that matters.
# Nothing here can fail a gate, skip a suite or move a merge: every exit either hands back a
# certificate CI actually granted, or hands back nothing and lets the pool run. So a wrong constant
# costs wall clock and never coverage -- the same asymmetry Get-TestSuiteCostHints states for its own
# hints file, and the reason this is a constant rather than another knob. The knob for a session that
# wants none of it is -NoCiWait, which is a switch and cannot be set to a wrong number.
$script:CiCertificateWaitSeconds = 1800

# How long between two reads of the required checks while waiting. 30s against a run measured in
# minutes is ~60 reads at the bound, which is cheap against `gh`'s own rate limit and fine-grained
# enough that the wait ends within half a minute of CI finishing. Lower would spend calls to learn
# nothing; higher would hand the saved minutes back at the end.
$script:CiCertificateWaitPollSeconds = 30

function Invoke-GitRead {
    <#
        A git QUERY, captured with its exit code. Query commands write their result to stdout and
        only real errors to stderr, so this does not need the EAP dance Invoke-NativeCapture does for
        `git push`. What it does need is the repo's standing rule: capture in full, record
        $LASTEXITCODE immediately, and only then filter -- never pipe the native call itself into a
        cmdlet, which can tear the process down before it exits cleanly.

        Returns $null on any non-zero exit, so every caller degrades to "cannot answer" rather than
        to a plausible wrong answer.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$GitArgs
    )

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git -C $RepoRoot @GitArgs 2>$null
        $code = $LASTEXITCODE
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $prevEap
    }

    if ($code -ne 0) { return $null }
    # Assigned first and wrapped at the call site, not returned as @(...): PowerShell unrolls a
    # single-element array on return, and a caller indexing the result would get a character.
    $lines = @($output | ForEach-Object { "$_" })
    return ,$lines
}

function Get-GateFingerprint {
    <#
        A stable hash of exactly what a gate would judge: HEAD, plus the path AND content hash of
        every dirty or untracked file. Returns $null when git cannot answer, which every caller
        treats as "no evidence" -- so a non-git checkout simply runs its gates as it always did.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $headLines = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('rev-parse', 'HEAD')
    if (-not $headLines -or $headLines.Count -eq 0) { return $null }
    $head = "$($headLines[0])".Trim()
    if (-not $head) { return $null }

    # --untracked-files=all so a new file inside an untracked DIRECTORY is listed individually
    # rather than as the directory alone -- the directory form would hash nothing and let a new
    # suite slip past the fingerprint.
    $statusLines = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('status', '--porcelain', '--untracked-files=all')
    if ($null -eq $statusLines) { return $null }

    $parts = New-Object System.Collections.ArrayList
    $parts.Add("head:$head") | Out-Null

    foreach ($line in ($statusLines | Sort-Object)) {
        if (-not "$line".Trim()) { continue }
        # Porcelain v1: two status columns, a space, then the path. A rename carries 'old -> new';
        # the new path is the one on disk, so that is the half worth hashing.
        $rest = if ("$line".Length -gt 3) { "$line".Substring(3) } else { '' }
        $path = $rest
        $arrow = $rest.IndexOf(' -> ')
        if ($arrow -ge 0) { $path = $rest.Substring($arrow + 4) }
        $path = $path.Trim('"').Trim()
        if (-not $path) { continue }

        $full = Join-Path $RepoRoot $path
        $contentHash = 'absent'
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            try {
                $contentHash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
            } catch {
                # Unreadable (locked, or vanished between the listing and the read) -- recorded as a
                # distinct value rather than skipped, so it cannot silently match a later run in
                # which the file reads fine.
                $contentHash = 'unreadable'
            }
        }
        $parts.Add("file:$path=$contentHash") | Out-Null
    }

    return (Get-Sha256Hex -Text ($parts -join "`n"))
}

function Get-GateTreeDirtyCount {
    <#
        How many files differ from HEAD right now -- dirty or untracked. Returns $null when git cannot
        answer, which a caller reports as "not measured" rather than as zero.

        WHY THIS EXISTS BESIDE THE FINGERPRINT (issue #1026). Get-GateFingerprint already walks exactly
        this list, and then hashes it away: what comes back is a value that answers "is this the same
        tree as last time" and cannot answer "is this tree HEAD". Those are different questions and the
        second one is the one a gate result depends on -- the gates judge the WORKING TREE while the PR
        ships HEAD, so on a dirty tree a green run is evidence about something other than what merges.
        Measured on PR #1025, where a lint run walked a manual WITH two new rules in it, reported zero
        errors, and the rules were not in the PR.

        A COUNT, NEVER FILENAMES, borrowed from the same bound park-lib works under: the caller prints
        this into a console line about an unrelated gate, and the files it counts are frequently nothing
        to do with the change being shipped.

        NOT A GATE, deliberately. A dirty tree is the ordinary state of a session mid-flight and refusing
        it would make the gates ceremony; what was missing was never a refusal but the sentence that
        stops a green result from reading as proof about the PR.

        core.quotePath IS FORCED ON, but NOT for park-lib's reason. That lib quotes because it COMPARES
        the paths against a list, and a code-page mis-decode there can accidentally match or fail to
        match. Nothing is compared here -- the answer is a count of lines -- and the risk is one line
        further down: an unquoted path containing a newline is reported across two lines and inflates the
        count by one. Quoting escapes it, so one file stays one file whatever it is called.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $statusLines = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'status', '--porcelain', '--untracked-files=all')
    if ($null -eq $statusLines) { return $null }
    return @($statusLines | Where-Object { "$_".Trim() }).Count
}

function Get-GateHeadMoveCount {
    <#
        How many times HEAD has moved in THIS worktree, ever -- the depth of its reflog. Returns
        $null when git cannot answer, which every caller treats as "not measured".

        WHY A DEPTH AND NOT A SHA (issue #1145). The thing this has to notice is a checkout that CAME
        BACK -- a second command that switches away and switches straight back, leaving HEAD, the
        branch name and every tracked file byte-identical before and after. A sha read at each end
        sees nothing at all; the reflog is where the two moves are recorded, and its depth grows by
        one per move whether or not the second one undoes the first. Measured in a fixture: a
        borrow-and-return takes the depth from 2 to 4 with the sha unchanged.

        THE SCRIPT THIS WAS MEASURED ON NO LONGER DOES IT (issue #1147), and the reading stands
        anyway. scripts\task\prune-merged.ps1 borrowed the trunk to fast-forward it until August 30,
        2026; it advances the ref without a checkout now, so the collision this function was built for
        cannot come from that direction any more. Removing the depth would be the wrong conclusion:
        new-branch.ps1 and worktree-lane.ps1 still move this checkout, a hand-typed pair of git
        commands still can, and a borrow-and-return is exactly the shape the fingerprint alone is
        blind to. What changed is which script to name in the finding, not whether to look.

        PER-WORKTREE, WHICH IS EXACTLY THE SCOPE THAT MATTERS. git keeps HEAD's reflog in the
        worktree's own git directory, so a lane moving its own checkout does not register here -- and
        it should not: a lane has its own tree and cannot disturb this one. What registers is a second
        command in THIS checkout, which is the collision the gates are exposed to.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    # `reflog show` on a repository with no commits yet exits non-zero, which Invoke-GitRead returns
    # as $null -- "not measured" rather than 0, so a later reading cannot look like growth.
    $lines = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('reflog', 'show', 'HEAD')
    if ($null -eq $lines) { return $null }
    return @($lines | Where-Object { "$_".Trim() }).Count
}

function Get-GateTreeMovedNote {
    <#
        Did the checkout move WHILE THE GATE RAN, and what does that make the result worth? Returns
        the sentence to print, or $null when nothing moved -- and also when the question cannot be
        answered, because a "the tree may have moved" line printed on every unreadable repository is
        a line nobody reads.

        WHY A GATE NEEDS THIS AT ALL (issue #1145). Get-GateFingerprint is taken BEFORE the gates and
        spent on the skip decision; until this function existed nothing looked again afterwards. But
        the gates read the WORKING TREE for a minute or more, and the primary checkout is not private
        to them: a session is told by name to run maintenance commands mid-assignment, and ship-pr
        backgrounds itself precisely so the session can get on with something else. Measured on
        PR #1144 -- one suite of 55 went red inside a backgrounded ship's gate and green standalone on
        the same commit seconds later, while prune-merged.ps1 had the trunk checked out beside it. The
        suite walks every *.md under dkj-policy/, and the branch's development document exists on the branch
        and not on the trunk, so a file in the walked set vanished and reappeared mid-run. That one
        script stopped taking the checkout in #1147; the class it belongs to did not.

        TWO SIGNALS, BECAUSE ONE OF THEM CANNOT SEE THE MEASURED CASE. The fingerprint answers "is the
        tree still what it was" and catches a change that PERSISTED past the gate; a borrow that hands
        the checkout back leaves it identical. The reflog depth answers "did HEAD move at all" and
        catches exactly that. Either one is enough to make the verdict untrustworthy.

        BOTH VERDICTS ARE WORTH LESS, IN OPPOSITE DIRECTIONS:
          - A RED is not trustworthy, and that is the expensive half. A false red reads as a real
            defect -- this repo's own language-layers rule tells a session in so many words that a
            suite which is red under the gate is reporting a REAL defect until proven otherwise -- so
            whoever meets one has a documented reason to go hunting for a bug that is not there.
          - A GREEN is not evidence. The pass is real for whatever mixture of trees the run saw, and
            that mixture is not the fingerprint the caller is about to record it under. So the caller
            skips Save-GateEvidence rather than storing a pass against a tree nothing judged.

        IT IS NOT A REFUSAL, deliberately. A red still blocks the push exactly as before -- what
        changes is that the reader is told which of the two results they are holding. Refusing would
        turn a concurrency the workflow invites into a hard stop, and re-running the gate is the
        remedy either way.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('lint', 'tests')][string]$Gate,
        # What the tree fingerprinted as, and how deep its reflog was, when the run started. Both are
        # optional in the sense that a $null one simply cannot report movement -- a caller that could
        # not measure one of them still gets the other.
        [string]$Fingerprint,
        [object]$HeadMoves,
        # The gate's verdict, because the two sentences say different things.
        [switch]$Failed
    )

    $moved = $false

    if ($Fingerprint) {
        $current = Get-GateFingerprint -RepoRoot $RepoRoot
        # UNPROVABLE IS NOT MOVED. $null means git could not answer just now; the gate has already
        # run, and a warning the reader cannot act on is worse than silence.
        if ($current -and $current -ne $Fingerprint) { $moved = $true }
    }

    if (-not $moved -and $null -ne $HeadMoves) {
        $now = Get-GateHeadMoveCount -RepoRoot $RepoRoot
        if ($null -ne $now -and [int]$now -ne [int]$HeadMoves) { $moved = $true }
    }

    if (-not $moved) { return $null }

    $lead = "$Gate gate: the checkout CHANGED while the gate ran -- HEAD or a file under it moved, so the run did not judge one settled tree."
    if ($Failed) {
        return "$lead This red is therefore NOT trustworthy: re-run the gate before hunting the failure. The usual cause is a second command in the same checkout (new-branch.ps1 and worktree-lane.ps1 move it; prune-merged.ps1 moves it only when it reaps the branch you are standing on) -- the primary checkout is single-occupancy while a gate is running."
    }
    return "$lead This pass is therefore NOT recorded as gate evidence, so the next run gates the tree as it then stands."
}

function Get-GateEvidencePath {
    <#
        Where the record lives: inside the git directory, which is per-worktree and never committed.
        Returns $null when git cannot answer.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $dirLines = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--git-dir')
    if (-not $dirLines -or $dirLines.Count -eq 0) { return $null }
    $gitDir = "$($dirLines[0])".Trim()
    if (-not $gitDir) { return $null }
    # `--git-dir` answers relatively when the query is made from inside the work tree.
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $RepoRoot $gitDir }
    return (Join-Path $gitDir 'workflow-gate-evidence.json')
}

function Read-GateEvidence {
    <#
        The record as an object, or $null when there is none, it cannot be read, or it is malformed.
        Every one of those is "no evidence", which fails toward running the gate.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $path = Get-GateEvidencePath -RepoRoot $RepoRoot
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    try {
        $raw = [System.IO.File]::ReadAllText($path)
        # Assigned before use: @(... | ConvertFrom-Json) collects a parsed array as ONE element in
        # PowerShell 5.1, the trap this repo has now hit in two unrelated scripts.
        $parsed = $raw | ConvertFrom-Json
    } catch {
        return $null
    }
    if (-not $parsed) { return $null }
    return $parsed
}

function Test-GateEvidence {
    <#
        Does a recorded pass of $Gate still cover the tree as it stands right now?

        $true only when all four hold: a record exists, it names this gate as passed, its fingerprint
        equals the tree's fingerprint today, and it is younger than the age bound. Anything else is
        $false -- including every error path, because the cost of a false $false is one gate run and
        the cost of a false $true is an ungated merge.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('lint', 'tests')][string]$Gate,
        # The tree's current fingerprint, when the caller has already computed it. Passing it keeps
        # one push from hashing the same tree once per gate.
        [string]$Fingerprint
    )

    $record = Read-GateEvidence -RepoRoot $RepoRoot
    if (-not $record) { return $false }

    $recorded = $null
    if ($record.PSObject.Properties['gates']) {
        $gatesNode = $record.gates
        if ($gatesNode -and $gatesNode.PSObject.Properties[$Gate]) { $recorded = $gatesNode.$Gate }
    }
    if (-not $recorded) { return $false }

    if (-not $record.PSObject.Properties['fingerprint']) { return $false }
    $current = if ($PSBoundParameters.ContainsKey('Fingerprint') -and $Fingerprint) {
        $Fingerprint
    } else {
        Get-GateFingerprint -RepoRoot $RepoRoot
    }
    if (-not $current) { return $false }
    if ("$($record.fingerprint)" -ne "$current") { return $false }

    if (-not $record.PSObject.Properties['recordedAt']) { return $false }
    try {
        $stamp = [datetime]::Parse("$($record.recordedAt)", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    } catch {
        return $false
    }
    $ageMinutes = ([datetime]::UtcNow - $stamp).TotalMinutes
    # A negative age is a clock that moved backwards, not a fresh record -- refused rather than
    # trusted, since "recorded in the future" is exactly what a tampered or restored file looks like.
    if ($ageMinutes -lt 0) { return $false }
    if ($ageMinutes -gt $script:GateEvidenceMaxAgeMinutes) { return $false }

    return $true
}

function Save-GateEvidence {
    <#
        Record that $Gate passed against the tree as it stands. A fingerprint that differs from the
        stored one RESETS the other gates rather than joining them: the two gates prove different
        things about the same tree, so a lint pass on today's tree must not inherit yesterday's test
        pass on a different one.

        Best-effort by design -- an unwritable git directory costs a future skip, never this run.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('lint', 'tests')][string]$Gate,
        [string]$Fingerprint
    )

    $current = if ($PSBoundParameters.ContainsKey('Fingerprint') -and $Fingerprint) {
        $Fingerprint
    } else {
        Get-GateFingerprint -RepoRoot $RepoRoot
    }
    if (-not $current) { return $false }

    $path = Get-GateEvidencePath -RepoRoot $RepoRoot
    if (-not $path) { return $false }

    $gates = @{}
    $existing = Read-GateEvidence -RepoRoot $RepoRoot
    if ($existing -and $existing.PSObject.Properties['fingerprint'] -and "$($existing.fingerprint)" -eq "$current") {
        if ($existing.PSObject.Properties['gates'] -and $existing.gates) {
            foreach ($name in $script:GateEvidenceKnownGates) {
                if ($existing.gates.PSObject.Properties[$name] -and $existing.gates.$name) { $gates[$name] = $true }
            }
        }
    }
    $gates[$Gate] = $true

    $record = [ordered]@{
        fingerprint = $current
        recordedAt  = [datetime]::UtcNow.ToString('o')
        gates       = $gates
    }

    try {
        $json = $record | ConvertTo-Json -Depth 4
        # WriteAllText with an explicit BOM-less UTF8: Set-Content -Encoding utf8 means WITH BOM in
        # Windows PowerShell 5.1, and this file is read back by ConvertFrom-Json on every run.
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        return $false
    }
    return $true
}

function Clear-GateEvidence {
    <#
        Drop the record entirely. Used by the suites, and available to anyone who wants the next run
        to prove everything again from scratch.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $path = Get-GateEvidencePath -RepoRoot $RepoRoot
    if (-not $path) { return $false }
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { Remove-Item -LiteralPath $path -Force } catch { return $false }
    }
    return $true
}

function Get-CiTestCertificate {
    <#
        Is the commit that is about to be shipped ALREADY proved by the trunk's own required checks?
        Pure: it judges JSON and two SHAs that the caller fetched, so the suite can walk every refusal
        without a network or a PR. Returns Certified (bool) and Note (string, always set).

        WHY A THIRD EVIDENCE SOURCE AT ALL (issue #1715, September 9, 2026). The record above is
        keyed on a LOCAL fingerprint, so it answers "did THIS machine already gate this exact tree".
        That is blind to the one run that costs the most: ship-pr calls open-pr, and between the two
        the branch is routinely brought forward onto a moved trunk. HEAD is then a commit no local run
        has seen, the fingerprint misses, and the full suite runs -- on a commit CI has just certified
        green. Measured on PR #1708: 84 suites in 1,775s locally, then ~7 min in CI, then the same 85
        suites starting again while `lint-en-tests pass` was already on the screen. Three runs of one
        measurement.

        AND THE WALL-CLOCK IS THE CHEAPER HALF. A ~40-minute cycle loses races a ~10-minute one wins:
        on that same PR the trunk moved during the third run, the stale-CI gate (#1292) refused
        correctly, the re-run went CONFLICTING (#1247), and a two-file docs change took over two hours.
        The window is what makes those gates fire, and this run is a third of the window spent
        re-proving what the required check had already recorded.

        THE CERTIFICATE IS STRONGER EVIDENCE THAN THE RUN IT REPLACES, which is what makes this a
        skip and not a relaxation. CI ran the same suites on a clean checkout of that exact commit,
        and it is the certificate the MERGE is gated on -- `main`'s ruleset blocks the merge until the
        required context passes. A local re-run cannot change the merge decision; it can only delay it.

        IT CERTIFIES ON A NAMED CHECK AND NEVER ON "WHATEVER WAS REQUIRED", which is the whole safety
        of the skip. The first draft of this function trusted every record `gh pr checks --required`
        returned, and two independent reviews found the same hole from opposite sides:

          - A consumer whose trunk requires an UNRELATED check -- a CLA bot, a PR-title linter, a
            theme-check -- would have its local test gate skipped the moment that check went green,
            with the suites never having run anywhere for that commit.
          - Where a trunk requires TWO contexts, the unrelated one registers and goes green first
            while the test check has not registered at all; the payload is then non-empty, every
            record in it is `pass`, and the certificate is granted. That is the registration race
            Get-RequiredCheckContexts documents in pr-issues-lib -- in its PARTIAL shape rather than
            its empty one, which is the shape a `Count -eq 0` guard cannot see.

        So the caller passes the check its repo has NAMED (Get-CiTestCheckName), and the named check
        must be PRESENT in the required set and green. Absent is a refusal, which is what closes the
        race: a check that has not registered cannot be found, so it cannot certify.

        WHAT IT REFUSES, and every one of these runs the gate exactly as before:

          - No check name. A repo that has not said which check proves its suites gets no certificate
            -- the pre-seam behaviour, and the reason the seam is optional.
          - No PR head to compare against (the first open-pr of a branch, before any push).
          - PR head != local HEAD. The certificate is about a commit; anything else is about a
            different tree. This is what makes an unpushed local commit safe.
          - Nothing readable, or an empty required set.
          - The named check missing from the payload -- not required by this trunk, or not registered
            yet. Both are "no certificate", deliberately: a check the merge does not depend on is not
            a bar this gate may stand down for.
          - The named check not in the `pass` bucket.

        THE CHECK NAMES IT PRINTS COME FROM OUTSIDE, so they go through Get-DisplayRef before they
        reach a console -- the same rule, and the same single source, that new-branch.ps1's remote-tip
        line follows. A check's displayed name is chosen by whoever produced it, and a third-party
        integration can build one out of branch- or PR-derived text; an ANSI or OSC escape in it
        repaints the terminal it lands in, and a zero-width run makes the printed line read as
        something other than what it says -- in the one line whose job is to say what stood down a
        gate. It is used for PRINTING ONLY: the match itself is made on the raw name (#3157), since a
        sanitised comparison let a name with a zero-width or space edge certify as the declared one.
        ref-print-lib.ps1 is dot-sourced at the top of THIS file rather than asked of the
        caller, which is what remote-ahead-lib and entry-scaffold-lib do with the same function and
        for the reason their notes give: it is a leaf with no dependencies, so loading it here cannot
        produce the two-answers problem the header's caller contract exists to avoid. Not degraded
        gracefully if it were ever absent, deliberately -- a sanitiser that silently switches itself
        off is worse than none.

        THE DIRTY-TREE CASE IS THE CALLER'S, deliberately, and this function never asks. What lands is
        HEAD, so a certificate on HEAD is exactly as true on a dirty tree as on a clean one; what
        changes is that the local gate would have judged something else. Invoke-WorkflowGates already
        warns about that difference in one place for both gates, and open-pr's backing gate is where
        the shape that is genuinely wrong gets stopped.

    .PARAMETER HeadSha
        The local HEAD this run would push and merge.

    .PARAMETER PrHeadSha
        `gh pr view <n> --json headRefOid` -- the commit CI actually ran against.

    .PARAMETER RequiredChecksJson
        `gh pr checks <n> --required --json name,bucket` output. Empty or unparseable -> not certified.

    .PARAMETER CheckName
        The check context whose green proves the suites, from the repo's own Get-CiTestCheckName seam.
        Empty or absent -> not certified, which is the pre-seam behaviour.

    .OUTPUTS
        [pscustomobject] Certified (bool), Note (string), InFlight (bool).

        InFlight IS THE THIRD STATE, AND UNTIL #2317 THE TWO IT SEPARATES WERE ONE WORD -- 'not green'.
        A named check that has FAILED and a named check that is STILL RUNNING are opposite facts about
        the same commit: the first says the suites have been measured and the answer is no, the second
        says the very measurement this gate is about to make by hand is already running, on a clean
        checkout of this exact tree. Both refused the certificate identically, so the caller re-proved
        the whole pool locally while the run the merge is gated on was in flight -- 43 minutes on
        PR #2316, which could not make the merge happen one second sooner, because `main`'s ruleset
        blocks it on that check regardless of what any local run decides.

        IT IS TRUE ONLY ON A COMMIT MATCH, which is what keeps it from being a licence to wait on
        anything. Every refusal above the bucket test -- no check name, no head, a PR head that is not
        this HEAD, an unreadable payload, a check that has not registered -- returns $false, because
        none of them has established that the thing still running is running on THIS tree. So a caller
        may read InFlight as "waiting is not patience here, it is waiting for the answer to exactly the
        question I was about to spend the pool on".

        NOT REGISTERED IS NOT IN FLIGHT ON ITS OWN, and that asymmetry is the whole safety of the
        state. A check absent from the payload is indistinguishable from one this trunk will never run
        on this commit, so a caller that waited on it would wait out its entire bound and then run the
        suites anyway. Absent stays a plain refusal, exactly as it was for the certificate.

        UNLESS OTHER CHECKS ON THIS EXACT COMMIT ARE STILL RUNNING (#3344). The named check can be an
        aggregator that registers only once the jobs it waits on are done: measured on PR #3345,
        'lint-en-tests' registered at 12:40:14 after five suite shards that ran from 12:32:16, and for
        those eight minutes `--required` answered "no required checks reported". So with -AllChecksJson
        (every check on the head) holding a pending record, an absent named check reads as in flight.
        The wait it starts ends on its own once nothing is pending: the next read either finds the named
        check or finds it still absent with nothing left running, which is then the plain refusal.
    #>
    param(
        [string]$HeadSha,
        [string]$PrHeadSha,
        [string]$RequiredChecksJson,
        [string]$CheckName,
        [string]$AllChecksJson
    )

    # $InFlight defaults to $false, so every refusal already written below keeps its exact shape and
    # only the calls that have established a commit match and something still pending pass $true.
    $refuse = { param([string]$Why, [bool]$InFlight = $false) [pscustomobject]@{ Certified = $false; Note = $Why; InFlight = $InFlight } }
    # How many checks on the head are still pending, from -AllChecksJson; 0 when it is absent or unreadable.
    $othersPending = {
        if (-not $AllChecksJson -or -not $AllChecksJson.Trim()) { return 0 }
        try { $all = $AllChecksJson | ConvertFrom-Json } catch { return 0 }
        return @(@($all) | Where-Object {
            $_ -and $_.PSObject.Properties['bucket'] -and ([string]$_.bucket).Trim().ToLowerInvariant() -eq 'pending'
        }).Count
    }
    # The refusal for a named check that has not registered: in flight while anything else still runs.
    $unregistered = {
        param([string]$Why)
        $pendingCount = & $othersPending
        if ($pendingCount -gt 0) {
            return (& $refuse ("'{0}' has not registered on this exact commit ({1}) yet, while {2} other check(s) on it are still running" -f $wanted, (& $short $head), $pendingCount) $true)
        }
        return (& $refuse $Why)
    }
    # Eight characters is what git itself abbreviates to here, and a reader asked to compare two
    # 40-character hashes by eye is being asked to do the job this line exists to have done for them.
    $short = { param([string]$Sha) $Sha.Substring(0, [Math]::Min(8, $Sha.Length)) }

    $wanted = Get-DisplayRef -Ref $CheckName
    if (-not $wanted) { return (& $refuse 'this repo has not named the check that proves its test suites (Get-CiTestCheckName)') }
    # The match below is made on the RAW name (#3157), so a declared name that does not print as itself
    # would match one string and print another. Refused rather than matched through: a seam value with an
    # edge space or a format character is a misdeclaration, and the gate then runs exactly as before.
    if ($wanted -cne $CheckName) {
        return (& $refuse ("the declared check name does not print as itself (it reads as '{0}') -- Get-CiTestCheckName should return the plain name" -f $wanted))
    }

    $head = ([string]$HeadSha).Trim()
    $prHead = ([string]$PrHeadSha).Trim()
    if (-not $head)   { return (& $refuse 'no local HEAD to compare') }
    if (-not $prHead) { return (& $refuse 'no PR head to compare -- nothing has been certified yet') }
    if ($head -ne $prHead) {
        return (& $refuse ("the PR head ({0}) is not this HEAD ({1}) -- the certificate is about a different commit" -f (& $short $prHead), (& $short $head)))
    }

    # `gh pr checks --required` prints nothing while no required check has registered, so an empty read
    # is that state as often as it is a failed one -- the other checks decide which (#3344).
    if (-not $RequiredChecksJson -or -not $RequiredChecksJson.Trim()) {
        return (& $unregistered 'the required checks could not be read')
    }
    try { $parsed = $RequiredChecksJson | ConvertFrom-Json } catch {
        return (& $refuse 'the required checks could not be parsed')
    }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object, the
    # same trap Get-RequiredCheckContexts and Get-MergeQueueVerdict each document beside their parse.
    $records = @(@($parsed) | Where-Object { $_ -and $_.PSObject.Properties['name'] })
    if ($records.Count -eq 0) {
        return (& $unregistered ("'{0}' has not registered on this commit yet -- no required check has" -f $wanted))
    }

    # COMPARED RAW, PRINTED SANITISED (#3157). Comparing after Get-DisplayRef let a look-alike certify:
    # 'lint-en-tests' with a zero-width or plain space on either edge strips and trims to the declared
    # name, so a check this repo never named could stand the gate down. The exact, case-sensitive match
    # decides; the sanitised form is only what a reader is shown. A record that merely PRINTS as the
    # declared name is called out by name in the refusal, because its line would otherwise read as the
    # very check it says is missing.
    $named = @($records | Where-Object { [string]$_.name -ceq $CheckName })
    if ($named.Count -eq 0) {
        $present = @(@($records | ForEach-Object { Get-DisplayRef -Ref ([string]$_.name) }) | Sort-Object -Unique)
        $lookAlike = @($records | Where-Object { (Get-DisplayRef -Ref ([string]$_.name)) -eq $wanted })
        if ($lookAlike.Count -gt 0) {
            return (& $refuse ("a required check prints as '{0}' but is not that name character for character -- a look-alike does not certify" -f $wanted))
        }
        return (& $unregistered ("'{0}' is not among this trunk's required checks on this commit (found: {1})" -f $wanted, ($present -join ', ')))
    }

    # THE BUCKETS ARE READ ONCE AND KEPT, because two questions are asked of them now: is the named
    # check green, and -- where it is not -- is it FAILING or still RUNNING. A record with no bucket
    # property reads as '' and is therefore neither, which keeps an unparseable record on the refusing
    # side of both tests instead of letting it fall through to the in-flight one.
    $buckets = @($named | ForEach-Object {
        if ($_.PSObject.Properties['bucket']) { ([string]$_.bucket).Trim().ToLowerInvariant() } else { '' }
    })
    $notPassing = @($buckets | Where-Object { $_ -ne 'pass' })
    if ($notPassing.Count -gt 0) {
        # EVERY non-passing record has to be pending for this to read as 'still running'. A check name
        # that appears more than once -- a matrix leg, a re-run -- is green only when all of its records
        # are, and it is FAILING the moment one of them is. Requiring unanimity puts a mixed payload on
        # the red side, which is the safe direction: the caller then runs the suites exactly as it
        # always did, rather than waiting for a verdict that has already been reached.
        $pending = @($notPassing | Where-Object { $_ -eq 'pending' })
        if ($pending.Count -eq $notPassing.Count) {
            return (& $refuse ("'{0}' is still running on this exact commit ({1})" -f $wanted, (& $short $head)) $true)
        }
        return (& $refuse ("'{0}' is not green on this commit" -f $wanted))
    }

    return [pscustomobject]@{
        Certified = $true
        Note      = ("{0} green on this exact commit ({1})" -f $wanted, (& $short $head))
        InFlight  = $false
    }
}

function Wait-CiTestCertificate {
    <#
        Poll an IN-FLIGHT CI certificate to its verdict, instead of re-proving the same commit locally
        while that run is still going -- issue #2317, September 22, 2026.

        WHAT IT REPLACES. Get-CiTestCertificate above answers one question at one instant, and the
        caller acted on it at the one instant it is least likely to be answerable: ship-pr calls
        open-pr immediately after the push, so the required check has typically just started. The
        certificate refused, correctly, and the whole pool then ran -- against the run that was at that
        moment proving the identical tree on a clean checkout. Measured over seven gate runs in one
        session: 12,801s of local gate for two pull requests, of which one single re-run was 2,595s
        (43.3 min) spent re-proving a commit whose CI went on to decide the merge anyway.

        THE ARGUMENT IS THE ONE THE CERTIFICATE ALREADY MAKES, ONE TENSE LATER. That function's own
        docstring states it: the certificate is STRONGER evidence than the run it replaces, because CI
        ran the same suites on a clean checkout of that exact commit and it is the certificate the
        MERGE is gated on -- a local re-run cannot change the merge decision, it can only delay it.
        All this adds is that the same sentence is just as true five minutes before the check goes
        green as five minutes after, and the only thing separating the two is time nobody has to spend
        running a second copy of the measurement.

        IT CANNOT FAIL A GATE, SKIP A SUITE, OR MOVE A MERGE, and that is the safety argument in full.
        There are exactly three ways out. CERTIFIED: CI granted the certificate, and the caller takes
        the same skip it would have taken had the check been green when it first asked. SETTLED: the
        certificate stopped being in flight for some other reason -- the check went red, the PR head
        moved under it, the payload stopped being readable -- and the caller runs the suites exactly as
        it did before this function existed. GAVE UP: the bound ran out while it was still pending, and
        the caller runs the suites. Two of the three are byte-for-byte the old behaviour, and the third
        is a skip the caller was already entitled to.

        A RED CHECK IS DELIBERATELY NOT A REFUSAL HERE. It would be a defensible one -- the merge is
        blocked on that check, so a green local pool cannot rescue the branch -- but it is a SECOND
        behaviour change riding on this one, and it would take a verdict away from a session whose CI
        red may be the flake this repo has measured twice (#1232/#1401, and #2317's own
        native-capture.tests.ps1 red that passed locally on the same commit, exit 0). So red falls
        through to the pool, which is what a session would have got anyway, and this function stays a
        pure saving.

        WHY THE READS ARE INJECTED. This runs inside a loop that must be walked at its every exit --
        certified, red, moved, unreadable, expired -- and none of those is reachable from a fixture
        that has to produce a real pull request with a real check suite in a real state. So the caller
        passes -Reader, the same shadowing seam Get-AvailableMemoryMB and Get-ResidentPowerShellCount
        use one lib over for the same reason, and -Sleeper so a suite can walk laps without spending
        them. The JUDGEMENT stays in Get-CiTestCertificate and is not restated here: this function
        decides only when to ask again, never what an answer means.

        A LAP THAT CANNOT BE READ IS NOT A VERDICT. -Reader returning $null, or throwing, is treated as
        "ask again" rather than as an answer, because an intermittently-unhealthy `gh` is exactly the
        shape this workflow has measured before (#1628) and one failed call says nothing about the
        check. The bound is what stops that being unbounded patience: a `gh` that never answers spends
        the wait and then the caller runs the pool, which is where it would have been regardless.

        BOTH BOUNDS ARE CHECKED, and they answer different failures. -MaxLaps bounds the number of
        READS, which is what a fixture can control and what a rate limit cares about; -TimeoutSeconds
        bounds the WALL CLOCK, which is what the operator is actually spending and what a slow `gh`
        would otherwise blow past while the lap count sat still. Whichever is reached first ends the
        wait. Either may be 0 to disable that half, and a caller passing 0 for both has asked for an
        unbounded wait, which this function will give it -- named here because it is the one way to
        misuse this and it is the caller's to avoid.

    .PARAMETER HeadSha
        The local HEAD being waited on. Re-compared on every lap against the PR head the reader
        returns, so a push landing during the wait ends it as 'settled' rather than certifying a
        commit that is no longer the one in hand.

    .PARAMETER CheckName
        The check context whose green proves the suites, exactly as Get-CiTestCertificate takes it.

    .PARAMETER Reader
        Scriptblock returning an object with PrHeadSha and RequiredChecksJson, and optionally
        AllChecksJson (#3344), or $null when the read failed. Called once per lap.

    .PARAMETER Sleeper
        Scriptblock called once per lap BEFORE the read -- the caller has just read, so reading again
        immediately would spend a call to learn what it already knows. Omitted means no delay, which
        is what a suite passes.

    .PARAMETER OnLap
        Optional scriptblock called with (lap, elapsedSeconds) after each read that did not end the
        wait, so a caller can narrate a long wait without this function owning a console.

    .OUTPUTS
        [pscustomobject] Certified (bool), Note (string), Outcome ('certified'|'settled'|'gave-up'),
        Laps (int), WaitedSeconds (double).
    #>
    param(
        [Parameter(Mandatory)][string]$HeadSha,
        [string]$CheckName,
        [Parameter(Mandatory)][scriptblock]$Reader,
        [scriptblock]$Sleeper,
        [scriptblock]$OnLap,
        [int]$MaxLaps = 0,
        [int]$TimeoutSeconds = 0
    )

    $waitClock = [System.Diagnostics.Stopwatch]::StartNew()
    $waitLaps  = 0
    # The note a gave-up verdict carries when the loop never got a readable answer at all. Overwritten
    # by the last in-flight note the moment one arrives, so the caller's message names the check rather
    # than this placeholder wherever there is something better to say.
    $waitLastNote = 'the required checks were never readable during the wait'

    while ($true) {
        if ($MaxLaps -gt 0 -and $waitLaps -ge $MaxLaps) { break }
        if ($TimeoutSeconds -gt 0 -and $waitClock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { break }

        # GUARDED LIKE THE READ, because the asymmetry was the finding (code review, #2317): a throwing
        # -Reader is an unreadable lap and a throwing -Sleeper was an exception out of the whole wait.
        # Nothing in either case is worth failing a gate over -- the caller's fall-through is to run the
        # suites -- and a sleeper that cannot sleep turns the poll into a spin, which the two bounds
        # below already contain. Inert with today's caller (Start-Sleep on a fixed positive constant);
        # written so that a -Sleeper doing anything more interesting cannot take the run with it.
        if ($Sleeper) { try { & $Sleeper | Out-Null } catch { } }
        $waitLaps++

        # EVERY LOCAL IN THIS LOOP IS PREFIXED, AND THAT IS NOT STYLE -- PowerShell scriptblocks are
        # DYNAMICALLY scoped, so `& $Reader` runs in a child of THIS scope and the caller's scriptblock
        # can see -- and shadow against -- every variable named here. Measured while writing this
        # function's own suite: a caller whose helper was also called $reading resolved it to this
        # local instead, which was $null on the line that reads it, so every lap threw, was swallowed
        # as an unreadable read, and the wait ran to its bound. It fails as "CI never answered", which
        # is indistinguishable from the real thing. The prefix is what keeps a caller's own names out
        # of the collision.
        # THE PARAMETERS ABOVE ARE IN THAT SAME NAMESPACE, and PowerShell is CASE-INSENSITIVE, so a
        # caller whose scriptblock reads its own $headSha gets this function's $HeadSha. That one
        # happens to hold the same value and so would hide rather than break -- which is worse. A
        # caller's scriptblock should assign what it uses, and read only what it passed in.
        $lapReading = $null
        try { $lapReading = & $Reader } catch { $lapReading = $null }
        if ($null -eq $lapReading) {
            if ($OnLap) { & $OnLap $waitLaps $waitClock.Elapsed.TotalSeconds | Out-Null }
            continue
        }

        $lapCert = Get-CiTestCertificate -HeadSha $HeadSha `
                                         -PrHeadSha ([string]$lapReading.PrHeadSha) `
                                         -RequiredChecksJson ([string]$lapReading.RequiredChecksJson) `
                                         -CheckName $CheckName `
                                         -AllChecksJson $(if ($lapReading.PSObject.Properties['AllChecksJson']) { [string]$lapReading.AllChecksJson } else { '' })
        if ($lapCert.Certified) {
            return [pscustomobject]@{
                Certified     = $true
                Note          = $lapCert.Note
                Outcome       = 'certified'
                Laps          = $waitLaps
                WaitedSeconds = $waitClock.Elapsed.TotalSeconds
            }
        }
        if (-not $lapCert.InFlight) {
            return [pscustomobject]@{
                Certified     = $false
                Note          = $lapCert.Note
                Outcome       = 'settled'
                Laps          = $waitLaps
                WaitedSeconds = $waitClock.Elapsed.TotalSeconds
            }
        }
        $waitLastNote = $lapCert.Note
        if ($OnLap) { & $OnLap $waitLaps $waitClock.Elapsed.TotalSeconds | Out-Null }
    }

    return [pscustomobject]@{
        Certified     = $false
        Note          = $waitLastNote
        Outcome       = 'gave-up'
        Laps          = $waitLaps
        WaitedSeconds = $waitClock.Elapsed.TotalSeconds
    }
}

function ConvertTo-CommitCheckBucketsJson {
    <#
        Turn `gh api repos/<slug>/commits/<sha>/check-runs` output into the `[{name, bucket}]` shape
        Get-CiTestCertificate judges, so a commit with NO pull request -- a trunk tip, certified by the
        CI run its push started -- is judged by the same function, on the same named check, as a PR head
        is. Pure: JSON in, JSON out. Returns '' where the payload is empty or unparseable, which that
        function already reads as "could not be read" and refuses.

        WHY A COMMIT AND NOT A PR (issue #3155, October 19, 2026). cut-release's second origin check
        (#2899) finds the trunk moved during the gates. The commits that moved it reached the trunk
        through pull requests, but this repo's ruleset is not strict (#1325), so each PR's own check ran
        against that PR's base and not against the combined trunk. The only run that has proved the tree
        the cut would tag is the one the push to the trunk started, and that run hangs off the commit.

        THE BUCKETS ARE gh pr checks' OWN WORDS, so the judging function needs no second vocabulary:
        a run that has not completed is 'pending', a success is 'pass', a skipped or neutral run is
        'skipping', and every other conclusion -- failure, cancelled, timed_out, action_required,
        stale -- is 'fail'. Only 'pass' certifies and only 'pending' waits, so a conclusion this mapping
        has never heard of lands on the refusing side, which is the safe one.

        ONLY GITHUB ACTIONS' OWN RUNS ARE KEPT (security review of #3155). The PR path trusts a check by
        name because the ruleset pins that context; a commit's raw check-runs list has no such pin, so any
        app with checks:write could post a green run under the same name and stand the cut's gates down.
        A run whose app is not 'github-actions' is dropped before judging, so it can neither certify nor
        mask a red Actions run. A repo whose test check is posted by another app gets no catch-up, which
        is the pre-#3155 behaviour.
    #>
    param([AllowEmptyString()][AllowNull()][string]$CheckRunsJson)

    if (-not $CheckRunsJson -or -not $CheckRunsJson.Trim()) { return '' }
    try { $parsed = $CheckRunsJson | ConvertFrom-Json } catch { return '' }
    if (-not $parsed -or -not $parsed.PSObject.Properties['check_runs']) { return '' }

    # Assign first, wrap second -- the 5.1 one-object pipeline trap Get-CiTestCertificate names.
    $runs = @(@($parsed.check_runs) | Where-Object {
        $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['app'] -and $_.app -and
        $_.app.PSObject.Properties['slug'] -and ([string]$_.app.slug) -ceq 'github-actions'
    })
    $records = @($runs | ForEach-Object {
        $status = if ($_.PSObject.Properties['status']) { ([string]$_.status).ToLowerInvariant() } else { '' }
        $conclusion = if ($_.PSObject.Properties['conclusion']) { ([string]$_.conclusion).ToLowerInvariant() } else { '' }
        $bucket = if ($status -ne 'completed') { 'pending' }
                  elseif ($conclusion -eq 'success') { 'pass' }
                  elseif ($conclusion -eq 'skipped' -or $conclusion -eq 'neutral') { 'skipping' }
                  else { 'fail' }
        [pscustomobject]@{ name = [string]$_.name; bucket = $bucket }
    })
    # An empty array is still JSON a caller can hand on: the judging function reads it as "nothing has
    # registered on this commit yet", which is exactly what an empty check_runs list means.
    if ($records.Count -eq 0) { return '[]' }
    return (ConvertTo-Json -InputObject $records -Compress -Depth 3)
}

function Get-TrunkCatchUpDecision {
    <#
        May cut-release fast-forward over the commits that landed on origin while its gates ran, instead
        of refusing? Pure: the caller measures, this decides, so the suite can walk every branch without
        a remote. Returns Allowed (bool) and Reason (string; set on every refusal, '' when allowed).

        THE DECISION BEHIND IT (#3155, the owner's choice between two designs, October 19, 2026). A cut on
        a trunk that merges every ~15 minutes lost the race twice in a row against a ~13-minute gate,
        and every retry paid the whole gate again. The chosen design keeps #2899's protection and moves
        what proves the new commits: not a second local gate, but the main-push CI run for the new
        origin/main tip, after which the cut fast-forwards and re-runs itself with the gates certified
        for exactly that commit.

        WHAT IS NEVER CAUGHT UP OVER, whatever else holds:
          - AHEAD of origin. A trunk commit no PR shipped would ride along with the release push, and no
            CI run of origin's has seen it. That refusal is #2899's and stays word for word.
          - BEFORE THE GATES ON A FIRST RUN. Nothing has been paid yet, so the refusal costs one
            `git merge --ff-only`, and the cut then runs every gate against the tree it will tag -- the
            stronger proof. Inside a catch-up re-run there is no local gate left to run, so there the
            same catch-up is allowed at either moment.
          - PAST THE ROUND BOUND. Each round waits for a CI run, so a trunk that never settles would
            otherwise wait forever, one run at a time. The bound turns that into a refusal that says so.
          - WITHOUT A NAMED CHECK OR A REPO. With no check name nothing can certify (the
            Get-CiTestCertificate rule), and with no repo there is nothing to ask -- both are the
            pre-#3155 behaviour, which is why a consumer that has stated neither sees no change.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('before the gates', 'after the gates')][string]$Moment,
        [int]$BehindCount,
        [int]$AheadCount,
        [int]$Round,
        [int]$MaxRounds,
        [string]$CheckName,
        [string]$RepoName,
        [switch]$InCatchUpRun
    )

    $refuse = { param([string]$Why) [pscustomobject]@{ Allowed = $false; Reason = $Why } }
    if ($AheadCount -gt 0) { return (& $refuse 'main is AHEAD of origin/main, and no CI run of origin''s has seen those commits') }
    if ($BehindCount -le 0) { return (& $refuse 'main is not behind origin/main -- there is nothing to catch up over') }
    if ($Moment -eq 'before the gates' -and -not $InCatchUpRun) {
        return (& $refuse 'the gates have not run yet, so fast-forwarding and running them against the new tree is the stronger proof')
    }
    if ($Round -ge $MaxRounds) {
        return (& $refuse ("origin/main moved again after {0} catch-up round(s) -- the trunk is not settling, so this run stops rather than waiting on another CI run" -f $Round))
    }
    if (-not ([string]$CheckName).Trim()) { return (& $refuse 'this repo has not named the check that proves its test suites (Get-CiTestCheckName), so no CI run can certify the new commits') }
    if (-not ([string]$RepoName).Trim()) { return (& $refuse 'this repo has not stated its GitHub slug (Get-RepoName), so the CI run for the new commits cannot be read') }
    return [pscustomobject]@{ Allowed = $true; Reason = '' }
}

function Get-ReleaseNoteTreeRoots {
    <#
        The repo-root-relative directories the RELEASE-NOTES exception covers -- the hand-written note
        tree Get-ReleaseNoteRoot names, plus the internal tree Get-ReleaseInternalNotesRoot names where
        a repo still runs the two-document flow. Forward-slashed and trailing-slash-free, so a caller
        comparing against a porcelain path does not have to normalise either side.

        BOTH SEAMS ARE OPTIONAL and neither is reached for directly: a consumer that has stated only one
        gets one root, and one that has stated neither gets an EMPTY list -- which every caller reads as
        "nothing can be deduced here", never as "everything qualifies". That inversion is the whole
        hazard of this family, so the empty case is the refusing one by construction rather than by a
        check somebody has to remember.

        THE BOUND IS THE EXCEPTION'S OWN, deliberately, and it is narrower than what was measured. The
        measurement in #2102 moved the whole of dkj-policy/releases/ aside; this reads only the two
        trees the third direct-on-`main` exception already names and that the release-notes commit
        already has to name in its own commit message. A deduction sized to the exception cannot outlive
        it, and the wider tree buys nothing the cut actually needs.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $roots = New-Object System.Collections.ArrayList
    foreach ($seam in @('Get-ReleaseNoteRoot', 'Get-ReleaseInternalNotesRoot')) {
        if (-not (Test-FunctionDefined $seam)) { continue }
        $value = ''
        try { $value = "$(& $seam)" } catch { $value = '' }
        $value = $value.Replace('\', '/').Trim().TrimEnd('/')
        if ($value) { [void]$roots.Add($value) }
    }
    return @($roots)
}

function Get-NoteTreeOnlyVerdict {
    <#
        Whether every path that differs from HEAD right now sits inside one of $NoteRoots -- the question
        that decides whether the TEST gate can be deduced away on a release-notes commit. Returns
        {Proven, Inside, Outside, Roots, Reason}; Proven is $true only when the answer was measured AND
        came back clean, so every failure mode lands on $false and the caller runs the gate it always ran.

        WHY THE DEDUCTION IS SOUND, MEASURED RATHER THAN ASSUMED (issue #2102, September 18, 2026). The
        whole of dkj-policy/releases/ was moved aside and all 114 suites were run against the result. Four
        went red, and none of the four reads a release note:

          - repo-config.tests.ps1 fails one EXISTENCE assert over the path set Get-MojibakePaths returns
            ('reaches the archived release notes'). It reads the list, never a file in it, and a cut only
            ever ADDS notes -- so the assert it makes can only become more true.
          - bootstrap-drift.tests.ps1, fix-mojibake.tests.ps1 and subagent-shared.tests.ps1 fail because
            all three run check-plugin-integrity.ps1 over the LIVE repo as a smoke assert.

        So the entire coverage the 114 suites have of that tree IS the lint gate, run three more times --
        which means skipping the suites over a note-tree-only change removes no coverage the lint half is
        not already providing in the same run. That is the inversion worth stating plainly: lint-only here
        is not an APPROXIMATION of the test gate's answer, it is that answer.

        TWO OF THOSE THREE SMOKES ARE GONE SINCE #2793 (October 4, 2026), and the deduction holds more
        strongly for it. bootstrap-drift.tests.ps1 no longer runs the gate at all. fix-mojibake.tests.ps1
        runs only check 14's own tool (fix-mojibake.ps1 -Check, whose path set reaches the notes), which the
        lint half runs too. subagent-shared.tests.ps1 still runs the whole gate, for its [shared] and
        [tool-block] coverage lines, but no longer asserts its exit code.

        WHAT IT COSTS, WITH EACH FIGURE CREDITED TO THE RUN THAT PRODUCED IT. On the v5.5.0 cut, the
        second gate leg -- the gates run again from the trunk, over one hand-written markdown file -- cost
        325s. It is one of the two runs that together are 652s of that 1,166s release: 56% of it spent on
        the same 114 suites twice, which is what #2102 was filed about. What this switch leaves standing is
        the LINT half, and that half was measured here rather than there: 27s, against 249s for the suites
        at 30 lanes, on the machine that filed the issue. The cut's own 325s is not broken down into the
        two halves anywhere, so no lint figure is attributed to it.

        IT PROVES, IT DOES NOT FILTER, and the difference is the reason this shape was built rather than a
        path predicate. A filter decides what to run FROM the paths and is silent when its pattern is
        wrong; this asks one question whose only affirmative answer is "every changed path is inside the
        exception's own bound", and answers $false to everything else -- an unreadable git, a repo that
        names no note tree, a clean tree, one stray path. #2102 declined a docs-only predicate by name for
        exactly that reason, and this is the shape that survives the objection: the narrow case is proved,
        never assumed, and the fallback is today's behaviour rather than a smaller gate.

        A CLEAN TREE IS NOT PROVEN, which looks backwards and is not. The claim being made is about what
        CHANGED; with nothing changed there is no note-tree change to reason from, and the run would be
        deducing a gate away on the strength of an empty set. The genuinely unchanged tree is already
        Test-GateEvidence's subject, consulted ahead of this and costing a file read -- so nothing is lost
        by refusing here.

        A RENAME IS JUDGED ON BOTH HALVES. Porcelain reports 'old -> new', and a note dragged OUT of the
        tree changes a path the suites might read even though the surviving path is inside -- so From is
        held to the same bound as Path, and a rename out of the tree is Outside.

        PATH MATCHING IS ORDINAL, case and all, because the wrong direction here is silent. Git reports
        the on-disk spelling; a root whose case has drifted from it simply fails to match and the run
        gates for real, which is the harmless half of being wrong.

        WHAT IT TRUSTS, STATED SO A LATER READER DOES NOT HAVE TO DERIVE IT. The roots are taken at face
        value as exactly the release-note tree and nothing more, so widening Get-ReleaseNoteRoot or
        Get-ReleaseInternalNotesRoot widens what this can be asked to skip over -- pointed at a repo's
        whole workflow folder rather than at its note tree, it would prove a deduction nobody measured.
        That is the same trust Get-LintScript and -TestsProvedByCi already carry and it is not new here,
        but those two seams are now load-bearing for a gate as well as for a directory, which is worth a
        reviewer's eye on any change to them. Every malformed answer fails SAFE rather than open -- '',
        '/', '.', '..' and an absolute path each match nothing a git-relative path can be, so the run
        gates for real -- so what is left is the deliberate widening, which no check can tell from a
        deliberate move.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string[]]$NoteRoots = @()
    )

    $roots = @(@($NoteRoots) | ForEach-Object { "$_".Replace('\', '/').Trim().TrimEnd('/') } |
        Where-Object { $_ })

    $verdict = [pscustomobject]@{
        Proven  = $false
        Inside  = @()
        Outside = @()
        Roots   = @($roots)
        Reason  = ''
    }

    if ($roots.Count -eq 0) {
        $verdict.Reason = 'this repo names no release-note tree (Get-ReleaseNoteRoot / Get-ReleaseInternalNotesRoot), so there is no bound to hold anything to'
        return $verdict
    }

    if (-not (Test-FunctionDefined 'Get-GitPorcelainStatus')) {
        $verdict.Reason = 'git-porcelain-lib.ps1 is not loaded, so the working copy could not be read'
        return $verdict
    }

    $status = Get-GitPorcelainStatus -RepoRoot $RepoRoot
    if (-not $status.Known) {
        $verdict.Reason = 'git could not be read, so nothing about the working copy was measured'
        return $verdict
    }

    $inside = New-Object System.Collections.ArrayList
    $outside = New-Object System.Collections.ArrayList
    foreach ($entry in @($status.Entries)) {
        # Both halves of a rename, for the reason the header gives. From is empty on everything else.
        $paths = @($entry.Path) + @(if ($entry.From) { $entry.From } else { @() })
        foreach ($p in $paths) {
            $isInside = $false
            foreach ($root in $roots) {
                if ($p -ceq $root -or $p.StartsWith(($root + '/'), [System.StringComparison]::Ordinal)) {
                    $isInside = $true
                    break
                }
            }
            if ($isInside) { [void]$inside.Add($p) } else { [void]$outside.Add($p) }
        }
    }

    $verdict.Inside = @($inside)
    $verdict.Outside = @($outside)

    if ($inside.Count -eq 0 -and $outside.Count -eq 0) {
        $verdict.Reason = 'nothing differs from HEAD, so there is no note-tree change to deduce from'
        return $verdict
    }
    if ($outside.Count -gt 0) {
        $verdict.Reason = ("{0} changed path(s) sit outside the release-note tree" -f $outside.Count)
        return $verdict
    }

    $verdict.Proven = $true
    return $verdict
}

function ConvertTo-SuiteReference {
    <#
        One path-shaped string, reduced to the form the affected-suite selection matches on (issue
        #3223): forward slashes, lower case, variables and '.'/'..' segments dropped, so
        "$PSScriptRoot\..\lib\gate-lib.ps1" and 'scripts\lib\gate-lib.ps1' both become a tail a tracked
        path can END WITH. Returns '' for anything that is not a file reference -- prose with spaces, a
        wildcard, or a leaf built from a variable ("$Name.ps1"), which names no particular file.
    #>
    param([AllowEmptyString()][string]$Value, [switch]$Expandable)

    $v = "$Value"
    if ($Expandable) {
        # A leaf that is itself a variable names no file, so only the text after the last variable is
        # trusted to be literal -- and only when it starts a new path segment.
        $v = [regex]::Replace($v, '\$\([^)]*\)|\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_:]*', '<var>')
    }
    $v = $v.Trim().Replace('\', '/')
    if (-not $v -or $v -match '\s' -or $v -match '[*?]') { return '' }
    $segments = @($v.Split('/') | Where-Object { $_ -and $_ -ne '.' -and $_ -ne '..' })
    if ($segments.Count -eq 0) { return '' }
    $leaf = $segments[-1]
    if ($leaf.Contains('<var>')) { return '' }
    # Everything up to and including the last variable segment is dropped; what is left is literal.
    $start = 0
    for ($i = 0; $i -lt $segments.Count; $i++) { if ($segments[$i].Contains('<var>')) { $start = $i + 1 } }
    $segments = @($segments[$start..($segments.Count - 1)])
    $leaf = $leaf.ToLowerInvariant()
    # A dotfile ('.gitignore') and an extensionless name ('LICENSE') are files too -- the first draft's
    # pattern dropped both, so a suite reading the live .gitignore was never selected for a change to it.
    if ($leaf -notmatch '^\.?[a-z0-9_][a-z0-9_.-]*$') { return '' }
    return (($segments -join '/').ToLowerInvariant())
}

function Get-SuiteReferenceSet {
    <#
        What one PowerShell file names, read off its syntax tree rather than its text (issue #3223).
        Returns {Parsed, Run, Read, Walks}:
          - Run   : the references the file EXECUTES -- dot-sourced, called with &, or handed to
                    -File / Start-Process / powershell -- including through a variable assigned one
                    statement earlier, the shape `$lib = Join-Path $PSScriptRoot 'x.ps1'; . $lib` takes.
          - Read  : every other file reference in a string or a bare argument.
          - Walks : whether it ENUMERATES the live repo -- a Get-ChildItem, git ls-files/grep, a
                    recursive copy or a directory listing on a path built from $RepoRoot -- or says so
                    itself with a '# gate-selection: always' line.
          - Scope : the path patterns a '# gate-selection: walks <pattern> ...' line names -- what the
                    walks can read. Empty means unbounded: the walk reaches whatever the tree holds.
          - WalksOpen : whether one of those live-tree walks can return a file of ANY type -- every walk
                    that no constant in its own arguments narrows to a type (the rule is at the walk
                    detection below), or the '# gate-selection: always' line, whose walk nobody can read.
                    CI's asset-only selection never drops such a suite by file type (issue #3316): it reads
                    the suite's text for the changed extension, and an open walk reads a type it never names.
          - WalkSamples : per live-tree walk, the paths it can return, as samples a declared scope must
                    admit (issue #3392) -- its root, resolved through the variables it is built from, plus
                    each type its constants filter on, or '<root>/x.gate-any' for an open walk. A walk whose
                    root cannot be resolved samples from no directory, so only a pattern without one admits
                    it. A lib-function enumeration is typed and has no sample. -SuiteDirectory (the file's
                    repo-relative folder) is what $PSScriptRoot resolves to; without it, a walk rooted there
                    is unresolved.

        COMMENTS ARE NOT REFERENCES, AND THAT IS MEASURED. Counting every file name a script's text
        mentions selected all 162 suites for every change, because these scripts' docstrings name
        nearly every other file. Reading string and argument tokens only still selected 121 of 162
        for a CSS file, because shared-scripts-lib.ps1 holds the mirrored-script registry as DATA and
        nearly every suite reaches it -- which is why Run and Read are kept apart: a library that lists
        a script does not run it.

        A FILE THAT DOES NOT PARSE IS NOT EMPTY, it is unknown: Parsed is $false, and the caller runs
        every suite that reaches it.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$SuiteDirectory = ''
    )

    $run = New-Object 'System.Collections.Generic.HashSet[string]'
    $read = New-Object 'System.Collections.Generic.HashSet[string]'
    $result = [pscustomobject]@{ Parsed = $false; Run = $run; Read = $read; Walks = $false; WalksOpen = $false; Scope = @(); WalkSamples = @() }

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { return $result }
    $result.Parsed = $true
    if ($Text -match '(?m)^\s*#\s*gate-selection:\s*always\s*$') { $result.Walks = $true; $result.WalksOpen = $true }
    # THE WALK'S SCOPE, DECLARED (issue #3309, lever 1): '# gate-selection: walks *.ps1 plugin.json' says
    # which changed paths the file's walks can read, and is a walk declaration in its own right. A file
    # that also says 'always' keeps no scope -- the two lines disagree, and the safe reading wins.
    $scopeLines = [regex]::Matches($Text, '(?m)^[ \t]*#[ \t]*gate-selection:[ \t]*walks[ \t]+(\S.*?)[ \t]*$')
    if ($scopeLines.Count -gt 0) {
        $result.Walks = $true
        if ($Text -notmatch '(?m)^\s*#\s*gate-selection:\s*always\s*$') {
            $result.Scope = @($scopeLines | ForEach-Object { $_.Groups[1].Value -split '\s+' } |
                ForEach-Object { $_.Replace('\', '/').ToLowerInvariant() } | Where-Object { $_ } | Sort-Object -Unique)
        }
    }

    # ONE WALK OVER THE TREE, and every later question answered by climbing a node's PARENT chain
    # rather than by searching the tree again. Both choices are measured: FindAll with a script-block
    # predicate is the expensive call on Windows PowerShell 5.1, and asking "which strings sit inside
    # this command" per command made the large scripts here quadratic (open-pr.ps1 alone did not
    # finish in ten minutes).
    $nodes = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
        $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -or
        $n -is [System.Management.Automation.Language.VariableExpressionAst] -or
        $n -is [System.Management.Automation.Language.CommandAst] -or
        $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -or
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -or
        $n -is [System.Management.Automation.Language.ForEachStatementAst]
    }, $true)

    # The commands first: which of them RUN a file, and which WALK a directory.
    $runCommands = New-Object 'System.Collections.Generic.HashSet[object]'
    $walkNodes = New-Object 'System.Collections.Generic.HashSet[object]'
    $openWalkNodes = New-Object 'System.Collections.Generic.HashSet[object]'
    # The constants that narrowed each walk to a type -- the filters its samples are built from (#3392).
    $typedOf = @{}
    # Whether a constant names a file type in its last path segment: '*.ps1', 'hooks.json'. '*.*' and a
    # bare directory name do not.
    $namesType = { param($v) return (("$v" -split '[\\/]')[-1] -match '\.[A-Za-z0-9]+$') }
    foreach ($n in $nodes) {
        if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
            $member = "$($n.Member)".ToLowerInvariant()
            if ($member -in @('enumeratefiles', 'getfiles', 'enumeratedirectories', 'getdirectories', 'enumeratefilesystementries')) {
                [void]$walkNodes.Add($n)
                # A FILE listing is open unless one of its constant arguments names a type (the search
                # pattern); a directory listing returns no file at all.
                $typed = @(@($n.Arguments) | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and (& $namesType $_.Value) })
                if ($member -notin @('enumeratedirectories', 'getdirectories') -and -not $typed.Count) {
                    [void]$openWalkNodes.Add($n)
                }
                $typedOf[$n] = @($typed | ForEach-Object { $_.Value })
            }
            continue
        }
        if ($n -isnot [System.Management.Automation.Language.CommandAst]) { continue }
        $name = "$($n.GetCommandName())".ToLowerInvariant()
        $flags = New-Object System.Collections.ArrayList
        $words = New-Object System.Collections.ArrayList
        foreach ($e in $n.CommandElements) {
            if ($e -is [System.Management.Automation.Language.CommandParameterAst]) { [void]$flags.Add($e.ParameterName.ToLowerInvariant()) }
            elseif ($e -is [System.Management.Automation.Language.StringConstantExpressionAst]) { [void]$words.Add($e.Value.ToLowerInvariant()) }
        }
        # The lib functions that ENUMERATE the root they are handed count as a walk too -- a suite that
        # loops over Get-SharedScriptPairs on the live repo reads every mirrored script without naming
        # one (measured: thirteen suites do). A function missing from this list is a walk the reading
        # cannot see, which is what '# gate-selection: always' is for.
        if (($name -in @('get-childitem', 'gci', 'dir', 'ls', 'get-specialistfiles', 'get-sharedscriptpairs',
                         'get-repopluginroots', 'get-repoworkflowrecord', 'get-alwaysondocuments')) -or
            ($name -eq 'copy-item' -and $flags -contains 'recurse') -or
            ($name -in @('git', 'git.exe') -and (($words -contains 'ls-files') -or ($words -contains 'grep')))) {
            [void]$walkNodes.Add($n)
        }
        # AN OPEN WALK IS EVERY WALK NOT PROVABLY NARROWED TO A FILE TYPE AT THE SOURCE (#3316) -- open is
        # the default, because getting it wrong in that direction costs a suite kept, never one dropped.
        # Narrowed means a CONSTANT in the walk's own arguments whose last segment names a type
        # ('*.ps1', 'hooks.json'), in a position that filters:
        #   - Get-ChildItem: the value of -Filter or -Include, or a positional constant (the path or the
        #     positional filter). Never the value of -Exclude, which narrows nothing. A filter held in a
        #     variable is not provable, so the walk stays open.
        #   - Copy-Item -Recurse: a constant source naming a type.
        #   - git ls-files: a pathspec naming a type. git grep: only a pathspec after '--', because before
        #     it a '*' is a regex ("a.*b" is no filter).
        # A walk narrowed only AFTER the fact (| Where-Object Extension -eq '.ps1') is open here. The lib
        # functions above are typed enumerations (mirrored scripts, specialist and always-on documents,
        # workflow records, plugin roots) and are not open: what a suite then walks under a root they
        # return is a walk of its own, read here like any other. Ported from PR #3313's f3f2f17b8.
        if ($walkNodes.Contains($n) -and $name -in @('get-childitem', 'gci', 'dir', 'ls', 'copy-item', 'git', 'git.exe')) {
            $narrowed = $false
            $previous = ''
            $afterDashes = $false
            $typedOf[$n] = New-Object System.Collections.ArrayList
            # Element 0 is the command name itself, and 'git.exe' would read as a type.
            foreach ($e in @($n.CommandElements | Select-Object -Skip 1)) {
                if ($e -is [System.Management.Automation.Language.CommandParameterAst]) {
                    if ($e.Extent.Text -eq '--') { $afterDashes = $true }
                    $previous = $e.ParameterName.ToLowerInvariant()
                    continue
                }
                $consts = @($e.FindAll({ param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) |
                    Where-Object { $_.Parent -isnot [System.Management.Automation.Language.ExpandableStringExpressionAst] })
                $byType = @($consts | Where-Object { & $namesType $_.Value }).Count -gt 0
                $isExclude = $previous.Length -ge 2 -and 'exclude'.StartsWith($previous)
                $typedHere = @($consts | Where-Object { & $namesType $_.Value } | ForEach-Object { $_.Value })
                if ($name -in @('git', 'git.exe')) {
                    if ($byType -and (($words -contains 'ls-files') -or $afterDashes)) { $narrowed = $true; [void]$typedOf[$n].AddRange($typedHere) }
                } elseif ($byType -and -not $isExclude) { $narrowed = $true; [void]$typedOf[$n].AddRange($typedHere) }
                $previous = ''
            }
            # A Get-ChildItem -Directory lists no file at all, like the .NET directory listings above.
            if ($name -in @('get-childitem', 'gci', 'dir', 'ls') -and @($flags | Where-Object { $_ -eq 'ad' -or ($_.Length -ge 2 -and 'directory'.StartsWith($_)) }).Count) { $narrowed = $true }
            if (-not $narrowed) { [void]$openWalkNodes.Add($n) }
        }
        $op = $n.InvocationOperator
        if (($op -eq [System.Management.Automation.Language.TokenKind]::Dot) -or
            ($op -eq [System.Management.Automation.Language.TokenKind]::Ampersand) -or
            ($name -in @('powershell', 'powershell.exe', 'pwsh', 'pwsh.exe', 'start-process', 'start-job')) -or
            ($flags -contains 'file') -or ($words -contains '-file')) {
            [void]$runCommands.Add($n)
        }
        if ($name -like '*.ps1') {
            $r = ConvertTo-SuiteReference -Value $name
            if ($r) { [void]$run.Add($r) }
        }
    }

    # The variable an assignment writes, or '' -- read off its left-hand side.
    $assignedName = {
        param($assignment)
        $left = $assignment.Left
        if ($left -is [System.Management.Automation.Language.ConvertExpressionAst]) { $left = $left.Child }
        if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) { return $left.VariablePath.UserPath.ToLowerInvariant() }
        return ''
    }

    $assignedRefs = @{}
    $derivedFrom = New-Object System.Collections.ArrayList
    $varUses = New-Object System.Collections.ArrayList
    foreach ($n in $nodes) {
        $isString = ($n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                    ($n -is [System.Management.Automation.Language.ExpandableStringExpressionAst])
        $isVar = $n -is [System.Management.Automation.Language.VariableExpressionAst]
        if (-not $isString -and -not $isVar) { continue }
        $ref = ''
        if ($isString) {
            # Most strings in a script are not file names; the two characters every reference here
            # carries -- an extension dot or a kebab hyphen -- are checked before the conversion is paid for.
            $raw = "$($n.Value)"
            if ($raw.IndexOf('.') -lt 0 -and $raw.IndexOf('-') -lt 0) { continue }
            $ref = if ($n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                ConvertTo-SuiteReference -Value $n.Value -Expandable
            } else { ConvertTo-SuiteReference -Value $n.Value }
            if (-not $ref) { continue }
            [void]$read.Add($ref)
        }
        $varName = if ($isVar) { $n.VariablePath.UserPath.ToLowerInvariant() } else { '' }
        $parent = $n.Parent
        while ($null -ne $parent) {
            if ($parent -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Extent.StartOffset -ge $parent.Right.Extent.StartOffset -and $n.Extent.EndOffset -le $parent.Right.Extent.EndOffset) {
                $target = & $assignedName $parent
                if ($target) {
                    if ($isString) {
                        if (-not $assignedRefs.ContainsKey($target)) { $assignedRefs[$target] = New-Object System.Collections.ArrayList }
                        [void]$assignedRefs[$target].Add($ref)
                    } else {
                        [void]$derivedFrom.Add(@($target, $varName))
                    }
                }
            }
            if ($runCommands.Contains($parent)) {
                if ($isString) { [void]$run.Add($ref) } else { [void]$varUses.Add(@('run', $varName)) }
            }
            if ($isVar -and $walkNodes.Contains($parent)) { [void]$varUses.Add(@('walk', $varName, $parent)) }
            $parent = $parent.Parent
        }
    }

    # Which variables hold a path built from $RepoRoot -- a fixed point, so a variable derived from a
    # derived one counts too.
    # SEEDED WITH $PSScriptRoot AS WELL AS $RepoRoot: a suite's own directory IS the live tree, and two
    # suites measured walking it that way (native-capture's repo-wide audits, release-lib's plugin walk)
    # were missed while only $RepoRoot was seeded.
    $rootVars = New-Object 'System.Collections.Generic.HashSet[string]'
    [void]$rootVars.Add('reporoot')
    [void]$rootVars.Add('psscriptroot')
    do {
        $grew = $false
        foreach ($pair in $derivedFrom) {
            if ($rootVars.Contains($pair[1]) -and $rootVars.Add($pair[0])) { $grew = $true }
        }
    } while ($grew)

    foreach ($use in $varUses) {
        if ($use[0] -eq 'walk' -and $rootVars.Contains($use[1])) {
            $result.Walks = $true
            if ($openWalkNodes.Contains($use[2])) { $result.WalksOpen = $true }
        }
        if ($use[0] -eq 'run' -and $assignedRefs.ContainsKey($use[1])) {
            foreach ($r in $assignedRefs[$use[1]]) { [void]$run.Add($r) }
        }
    }

    # WHERE EACH LIVE WALK IS ROOTED (#3392). CI's asset-only selection trusts a declared scope to drop a
    # walker, so the scope guard has to hold the declaration against what the walk can return, root
    # included -- a '*.ps1' filter is covered by 'scripts/*.ps1' only when the walk sits under scripts/.
    # A root is a SET of repo-relative paths, resolved from $RepoRoot (the repo root) and $PSScriptRoot
    # (-SuiteDirectory) through Join-Path, Split-Path, Resolve-Path, [IO.Path]::Combine, "$var\x", a
    # foreach or ForEach-Object over a constant list, and the variables those are assigned to. Anything
    # else is unresolved, which only narrows what a scope can be said to cover.
    $liveWalks = New-Object System.Collections.ArrayList
    foreach ($use in $varUses) {
        if ($use[0] -eq 'walk' -and $rootVars.Contains($use[1]) -and -not $liveWalks.Contains($use[2])) { [void]$liveWalks.Add($use[2]) }
    }
    if ($liveWalks.Count -gt 0) {
        # A path climbing above the repo root is unresolved: '' is the root itself, $null is unknown.
        $normalize = {
            param([string]$Path)
            $out = New-Object System.Collections.ArrayList
            foreach ($seg in ($Path.Replace('\', '/') -split '/')) {
                if (-not $seg -or $seg -eq '.') { continue }
                if ($seg -eq '..') { if ($out.Count -eq 0) { return $null }; $out.RemoveAt($out.Count - 1); continue }
                [void]$out.Add($seg.ToLowerInvariant())
            }
            return ($out -join '/')
        }
        # Every base joined with every combination of the parts; $null when any of them is unresolved.
        $combine = {
            param($Bases, $Parts)
            if ($null -eq $Bases) { return $null }
            $acc = @($Bases)
            foreach ($part in $Parts) {
                if ($null -eq $part) { return $null }
                $acc = @(foreach ($a in $acc) { foreach ($v in @($part)) { & $normalize ("$a/$v") } })
            }
            if (@($acc | Where-Object { $null -eq $_ }).Count) { return $null }
            return ,@($acc | Sort-Object -Unique)
        }
        $seeds = @('reporoot', 'psscriptroot')
        $seedRoots = @{ 'reporoot' = @('') }
        if ($SuiteDirectory) {
            $suiteDir = & $normalize $SuiteDirectory
            if ($null -ne $suiteDir) { $seedRoots['psscriptroot'] = @($suiteDir) }
        }
        $rootOf = $seedRoots.Clone()
        $constOf = @{}
        # The value-taking parameters of the commands a root is built with; any other is a switch.
        $valued = @('path', 'literalpath', 'childpath', 'additionalchildpath', 'filter', 'include', 'exclude', 'depth', 'attributes', 'erroraction', 'errorvariable', 'outvariable', 'destination')
        $argsOf = {
            param($cmd)
            $named = @{}
            $switches = New-Object System.Collections.ArrayList
            $positional = New-Object System.Collections.ArrayList
            $els = @($cmd.CommandElements)
            for ($i = 1; $i -lt $els.Count; $i++) {
                $e = $els[$i]
                if ($e -is [System.Management.Automation.Language.CommandParameterAst]) {
                    $p = $e.ParameterName.ToLowerInvariant()
                    $full = @($valued | Where-Object { $p.Length -ge 2 -and $_.StartsWith($p) } | Select-Object -First 1)
                    if ($full.Count -eq 0) { [void]$switches.Add($p); continue }
                    if ($null -ne $e.Argument) { $named[$full[0]] = $e.Argument }
                    elseif ($i + 1 -lt $els.Count) { $i++; $named[$full[0]] = $els[$i] }
                    continue
                }
                [void]$positional.Add($e)
            }
            return @{ Named = $named; Switches = $switches; Positional = $positional }
        }
        $pathArg = {
            param($a)
            if ($a.Named.ContainsKey('literalpath')) { return $a.Named['literalpath'] }
            if ($a.Named.ContainsKey('path')) { return $a.Named['path'] }
            if ($a.Positional.Count) { return $a.Positional[0] }
            return $null
        }
        # The constant strings an expression holds; $Bind is what $_ holds inside a ForEach-Object.
        $constsOf = {
            param($e, $Bind)
            if ($null -eq $e) { return $null }
            if ($e -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return ,@($e.Value) }
            if ($e -is [System.Management.Automation.Language.CommandExpressionAst]) { return (& $constsOf $e.Expression $Bind) }
            if ($e -is [System.Management.Automation.Language.ParenExpressionAst]) { return (& $constsOf $e.Pipeline $Bind) }
            if ($e -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                $st = @($e.SubExpression.Statements)
                if ($st.Count -ne 1) { return $null }
                return (& $constsOf $st[0] $Bind)
            }
            if ($e -is [System.Management.Automation.Language.PipelineAst]) {
                if (@($e.PipelineElements).Count -ne 1) { return $null }
                return (& $constsOf $e.PipelineElements[0] $Bind)
            }
            if ($e -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                $out = New-Object System.Collections.ArrayList
                foreach ($x in @($e.Elements)) {
                    $v = & $constsOf $x $Bind
                    if ($null -eq $v) { return $null }
                    [void]$out.AddRange(@($v))
                }
                return ,@($out)
            }
            if ($e -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $v = $e.VariablePath.UserPath.ToLowerInvariant()
                if ($v -in @('_', 'psitem')) { return $Bind }
                if ($constOf.ContainsKey($v)) { return ,@($constOf[$v]) }
            }
            return $null
        }
        # The repo-relative paths an expression holds, or $null.
        $pathOf = {
            param($e, $Bind)
            if ($null -eq $e) { return $null }
            if ($e -is [System.Management.Automation.Language.CommandExpressionAst]) { return (& $pathOf $e.Expression $Bind) }
            if ($e -is [System.Management.Automation.Language.ParenExpressionAst]) { return (& $pathOf $e.Pipeline $Bind) }
            if ($e -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                $st = @($e.SubExpression.Statements)
                if ($st.Count -ne 1) { return $null }
                return (& $pathOf $st[0] $Bind)
            }
            if ($e -is [System.Management.Automation.Language.PipelineAst]) {
                $els = @($e.PipelineElements)
                if ($els.Count -eq 1) { return (& $pathOf $els[0] $Bind) }
                # @('a', 'b') | ForEach-Object { Join-Path $RepoRoot $_ } | Where-Object { ... } -- a filter
                # stage only drops a path, so it is read past.
                $items = & $constsOf $els[0] $Bind
                $each = $els[1]
                if ($null -eq $items -or $each -isnot [System.Management.Automation.Language.CommandAst] -or
                    "$($each.GetCommandName())".ToLowerInvariant() -notin @('foreach-object', '%')) { return $null }
                $block = @($each.CommandElements | Select-Object -Skip 1)
                if ($block.Count -ne 1 -or $block[0] -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { return $null }
                $st = @($block[0].ScriptBlock.EndBlock.Statements)
                if ($st.Count -ne 1) { return $null }
                foreach ($rest in @($els | Select-Object -Skip 2)) {
                    if ($rest -isnot [System.Management.Automation.Language.CommandAst] -or "$($rest.GetCommandName())".ToLowerInvariant() -notin @('where-object', '?', 'where')) { return $null }
                }
                $out = New-Object System.Collections.ArrayList
                foreach ($item in @($items)) {
                    $v = & $pathOf $st[0] @($item)
                    if ($null -eq $v) { return $null }
                    [void]$out.AddRange(@($v))
                }
                return ,@($out | Sort-Object -Unique)
            }
            if ($e -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
                # [System.IO.Path]::Combine($base, 'x', ...)
                if ("$($e.Member)" -ne 'Combine' -or @($e.Arguments).Count -lt 2) { return $null }
                return (& $combine (& $pathOf @($e.Arguments)[0] $Bind) @(@($e.Arguments | Select-Object -Skip 1) | ForEach-Object { ,(& $constsOf $_ $Bind) }))
            }
            if ($e -is [System.Management.Automation.Language.MemberExpressionAst]) {
                if ("$($e.Member)" -in @('Path', 'ProviderPath', 'FullName')) { return (& $pathOf $e.Expression $Bind) }
                return $null
            }
            if ($e -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $v = $e.VariablePath.UserPath.ToLowerInvariant()
                if ($rootOf.ContainsKey($v)) { return ,@($rootOf[$v]) }
                return $null
            }
            if ($e -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                # "$RepoRoot\plugins\x": one leading variable and a constant rest.
                $nested = @($e.NestedExpressions)
                if ($nested.Count -ne 1 -or $nested[0] -isnot [System.Management.Automation.Language.VariableExpressionAst]) { return $null }
                $lead = $nested[0].Extent.Text
                $body = "$($e.Extent.Text)".Trim('"')
                if (-not $body.StartsWith($lead, [StringComparison]::OrdinalIgnoreCase)) { return $null }
                return (& $combine (& $pathOf $nested[0] $Bind) @(,@($body.Substring($lead.Length))))
            }
            if ($e -is [System.Management.Automation.Language.CommandAst]) {
                $cmdName = "$($e.GetCommandName())".ToLowerInvariant()
                $a = & $argsOf $e
                if ($cmdName -eq 'join-path') {
                    $base = if ($a.Named.ContainsKey('path')) { $a.Named['path'] } elseif ($a.Positional.Count) { $a.Positional[0] } else { $null }
                    $children = New-Object System.Collections.ArrayList
                    if ($a.Named.ContainsKey('childpath')) { [void]$children.Add($a.Named['childpath']) }
                    $skip = if ($a.Named.ContainsKey('path')) { 0 } else { 1 }
                    foreach ($c in @($a.Positional | Select-Object -Skip $skip)) { [void]$children.Add($c) }
                    if ($a.Named.ContainsKey('additionalchildpath')) { [void]$children.Add($a.Named['additionalchildpath']) }
                    return (& $combine (& $pathOf $base $Bind) @($children | ForEach-Object { ,(& $constsOf $_ $Bind) }))
                }
                if ($cmdName -in @('resolve-path', 'convert-path', 'get-item')) { return (& $pathOf (& $pathArg $a) $Bind) }
                if ($cmdName -eq 'split-path') {
                    # Split-Path returns the parent unless a switch asks for another part.
                    if (@($a.Switches | Where-Object { $_ -ne 'parent' }).Count) { return $null }
                    $paths = & $pathOf (& $pathArg $a) $Bind
                    if ($null -eq $paths -or @($paths | Where-Object { -not $_ }).Count) { return $null }
                    return ,@($paths | ForEach-Object { if ($_.Contains('/')) { $_.Substring(0, $_.LastIndexOf('/')) } else { '' } } | Sort-Object -Unique)
                }
            }
            return $null
        }
        # The assignments and foreach loops, to a fixed point: a variable resolves when every write to it
        # resolves, to the union of what they write. The two seeds keep their value whatever is assigned.
        $writes = New-Object System.Collections.ArrayList
        foreach ($n in $nodes) {
            if ($n -is [System.Management.Automation.Language.AssignmentStatementAst] -and "$($n.Operator)" -eq 'Equals') {
                $target = & $assignedName $n
                if ($target -and $seeds -notcontains $target) { [void]$writes.Add(@($target, $n.Right)) }
            } elseif ($n -is [System.Management.Automation.Language.ForEachStatementAst]) {
                $target = $n.Variable.VariablePath.UserPath.ToLowerInvariant()
                if ($seeds -notcontains $target) { [void]$writes.Add(@($target, $n.Condition)) }
            }
        }
        $lastKey = ''
        for ($pass = 0; $pass -lt 8; $pass++) {
            $nextRoots = $seedRoots.Clone()
            $nextConsts = @{}
            $unresolvedRoot = @{}
            $unresolvedConst = @{}
            foreach ($w in $writes) {
                $p = & $pathOf $w[1] $null
                if ($null -eq $p) { $unresolvedRoot[$w[0]] = $true } else { $nextRoots[$w[0]] = @(@($nextRoots[$w[0]]) + @($p) | Where-Object { $null -ne $_ } | Sort-Object -Unique) }
                $c = & $constsOf $w[1] $null
                if ($null -eq $c) { $unresolvedConst[$w[0]] = $true } else { $nextConsts[$w[0]] = @(@($nextConsts[$w[0]]) + @($c) | Where-Object { $null -ne $_ } | Sort-Object -Unique) }
            }
            foreach ($k in @($unresolvedRoot.Keys)) { $nextRoots.Remove($k) }
            foreach ($k in @($unresolvedConst.Keys)) { $nextConsts.Remove($k) }
            $rootOf = $nextRoots
            $constOf = $nextConsts
            $key = (@($rootOf.Keys | Sort-Object | ForEach-Object { "$_=$(@($rootOf[$_]) -join ',')" }) + '|' + @($constOf.Keys | Sort-Object | ForEach-Object { "$_=$(@($constOf[$_]) -join ',')" })) -join ';'
            if ($key -eq $lastKey) { break }
            $lastKey = $key
        }

        $fill = { param([string]$v) return $v.Replace('\', '/').ToLowerInvariant().Replace('*', 'x').Replace('?', 'x').TrimStart('/') }
        $samples = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($w in $liveWalks) {
            $isGit = $false
            $roots = $null
            if ($w -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
                $roots = & $pathOf @($w.Arguments)[0] $null
            } else {
                $cmdName = "$($w.GetCommandName())".ToLowerInvariant()
                if ($cmdName -in @('get-childitem', 'gci', 'dir', 'ls', 'copy-item')) {
                    $roots = & $pathOf (& $pathArg (& $argsOf $w)) $null
                } elseif ($cmdName -in @('git', 'git.exe')) {
                    $isGit = $true
                    $els = @($w.CommandElements)
                    for ($i = 1; $i -lt $els.Count - 1; $i++) {
                        if ($els[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $els[$i].ParameterName -ceq 'C') { $roots = & $pathOf $els[$i + 1] $null; break }
                    }
                } else {
                    # A lib function's enumeration is typed (Get-SharedScriptPairs, ...): nothing to sample.
                    continue
                }
            }
            # Unresolved samples from no directory, which only a pattern without one admits.
            if ($null -eq $roots) { $roots = @('') }
            foreach ($root in @($roots)) {
                $prefix = if ($root) { $root + '/' } else { '' }
                if ($openWalkNodes.Contains($w)) { [void]$samples.Add($prefix + 'x.gate-any'); continue }
                $rootIsFile = $root -and (& $namesType $root)
                foreach ($t in @($typedOf[$w])) {
                    if ($rootIsFile) { [void]$samples.Add((& $fill $root)) }
                    elseif ($isGit) { [void]$samples.Add($prefix + (& $fill $t)) }
                    else { [void]$samples.Add($prefix + (& $fill (("$t" -split '[\\/]')[-1]))) }
                }
            }
        }
        $result.WalkSamples = @($samples | Sort-Object)
    }
    return $result
}

function Test-WalkScopeMatch {
    <# Whether a repo-relative path (lower case, forward slashes) falls inside a declared walk scope
       pattern. A pattern with a directory matches the whole path, one without matches the leaf -- so
       '*.ps1' is every script at any depth and 'scripts/*.ps1' every script under scripts/. -like's '*'
       crosses '/', which is the direction a scope must err in: wider, never narrower. #>
    param([string]$Path, [string]$Pattern)
    if ($Pattern.Contains('/')) { return ($Path -like $Pattern) }
    return ((($Path -split '/')[-1]) -like $Pattern)
}

function Get-UncoveredWalkSample {
    <# The walk samples (Get-SuiteReferenceSet's WalkSamples) no pattern of a declared scope admits --
       what the scope guard in affected-suites.tests.ps1 refuses (#3392). Empty means the declaration
       covers every live walk it can see: its roots as well as its types, Copy-Item sources included. #>
    param([AllowEmptyCollection()][string[]]$Samples, [AllowEmptyCollection()][string[]]$Scope)
    return @(@($Samples) | Where-Object {
        $sample = $_
        -not @(@($Scope) | Where-Object { Test-WalkScopeMatch -Path $sample -Pattern $_ }).Count
    })
}

function Test-SuiteReferenceMatch {
    <# Whether a repo-relative path (lower case, forward slashes) is what a reference names. A
       reference with a directory matches on its whole tail; a bare one matches the leaf, and a bare
       kebab name also matches that name with '.ps1' on it -- the form a list of lib names takes. #>
    param([string]$Path, [string]$Reference)
    if ($Reference.Contains('/')) {
        return ($Path -eq $Reference -or $Path.EndsWith('/' + $Reference, [StringComparison]::Ordinal))
    }
    $leaf = ($Path -split '/')[-1]
    return ($leaf -eq $Reference -or $leaf -eq ($Reference + '.ps1'))
}

function Get-GateChangedPaths {
    <#
        Every path this branch changes against its trunk, as the affected-suite selection reads it
        (issue #3223): what differs between the merge-base with the trunk and the WORKING TREE --
        committed, staged, unstaged and untracked alike, because the gate judges the working tree --
        with renames split into their two halves, so a file dragged out of a directory still names the
        path it left. Returns {Known, Paths, Base, Reason}; Known is $false whenever any of the three
        reads failed, and the caller then runs every suite.

        AGAINST origin/<trunk> WHERE THERE IS ONE, on claim-issue's reasoning for its branch-weight
        scan: a local trunk behind its remote reports commits as this branch's own that have already
        landed, which here only widens the selection -- but it is a wrong number, and it is avoidable.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $result = [pscustomobject]@{ Known = $false; Paths = @(); Base = ''; Reason = '' }
    $trunk = 'main'
    if (Test-FunctionDefined 'Get-TrunkBranchName') {
        try { $named = "$(Get-TrunkBranchName)".Trim(); if ($named) { $trunk = $named } } catch { }
    }
    $base = ''
    foreach ($candidate in @("origin/$trunk", $trunk)) {
        if ($null -ne (Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--verify', '--quiet', "$candidate^{commit}"))) { $base = $candidate; break }
    }
    if (-not $base) { $result.Reason = "no trunk ref ('origin/$trunk' or '$trunk') to compare the branch with"; return $result }
    $result.Base = $base

    $mergeBase = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('merge-base', 'HEAD', $base)
    if (-not $mergeBase -or -not "$($mergeBase[0])".Trim()) { $result.Reason = "HEAD and $base share no merge-base"; return $result }

    $diffed = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'diff', '--name-only', '--no-renames', "$($mergeBase[0])".Trim())
    $untracked = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'ls-files', '--others', '--exclude-standard')
    if ($null -eq $diffed -or $null -eq $untracked) { $result.Reason = 'git could not list what this branch changes'; return $result }

    $result.Paths = @(@($diffed) + @($untracked) | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    $result.Known = $true
    return $result
}

function Get-GateBranchDocument {
    <# The checked-out branch's development document, repo-relative, for Get-AffectedSuiteSelection's
       -BranchDocument (#3379) -- through the one resolver every gate uses. '' where it is not loaded or
       fails, which leaves the document in the scope match: the selection only grows. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    if (-not (Test-FunctionDefined 'Resolve-BranchFilePath')) { return '' }
    try { return "$(Resolve-BranchFilePath -Kind File -RepoRoot $RepoRoot)".Trim() } catch { return '' }
}

function Get-SuiteReferenceCachePath {
    <# Where the per-blob reference cache lives -- beside the gate evidence, in the git directory, for
       the four reasons this file's header gives for keeping state there. $null when git cannot say. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $evidence = Get-GateEvidencePath -RepoRoot $RepoRoot
    if (-not $evidence) { return $null }
    return (Join-Path (Split-Path -Parent $evidence) 'workflow-suite-refs.json')
}

function Get-AffectedSuiteSelection {
    <#
        Which test suites a set of changed paths can affect -- the local half of issue #3223, where
        open-pr runs those and leaves the whole pool to the required CI check. Returns {Proven, Suites,
        Always, Scoped, Walkers, Open, Matched, PoolCount, Reason}: Suites is what to run (Always, Scoped and
        Matched), Always the suites that run in every selection, Scoped the tree-walking suites whose
        declared scope a changed path falls in, Walkers every tree-walking suite whether it was selected
        or not, Open the walkers with a walk that can return a file of any type (Get-SuiteReferenceSet's
        WalksOpen, in any test-owned file the suite reaches, or a file that does not parse; #3316), and Proven is $false -- with the Reason -- whenever the mapping could not be made, in
        which case the caller runs every suite. Why maps each selected suite to one sentence saying why
        it was selected, which the dev server's /test-gate page shows (#3309, lever 3); nothing decides on it.

        THE MAP IS A REFERENCE GRAPH, READ OFF THE SYNTAX TREE. A suite affects a path when the path is
        the suite itself, a file the suite reaches by EXECUTING it (dot-source, &, -File, transitively),
        or a file any of those names. Two asymmetries keep that graph from collapsing into "everything
        reaches everything", and both are measured in Get-SuiteReferenceSet's header: a library is
        followed only through what it runs, never through what it merely lists, and a library's DATA
        reference counts only when it names a path with a directory -- the bare 'CLAUDE.md' and
        'README.md' that repo-config.ps1 hands out as seam values describe a file in whatever tree the
        caller passes, which in a suite is a fixture. And repo-config.ps1 itself contributes no data
        reference at all, directory or not (#3343): it is the seam, so every path it names is such a
        value, and one CSS file in its house-style allowlist selected 118 of 166 suites that load it
        without reading that file. A change to repo-config.ps1 still runs the whole pool (below). A file
        under the tests directory (a suite, or a fixture builder) is held to none of this: everything it
        names counts.

        THE SUITES THAT ENUMERATE THE LIVE TREE RUN EVERY TIME. A suite that globs $RepoRoot reads files
        no name points at, so nothing here can say which change reaches it. #2323 counted sixteen such
        whole-tree self-checks; this reading finds them by their Get-ChildItem / git ls-files / recursive
        copy over a path built from $RepoRoot or $PSScriptRoot, or by the live root handed to a lib
        function that enumerates it (Get-SharedScriptPairs and its kind) -- 40 suites on October 22, 2026. A suite whose
        walk this cannot see -- one done inside a script it runs against the live tree -- says so with a
        '# gate-selection: always' line.

        UNLESS THE WALK DECLARES ITS SCOPE (issue #3309, lever 1). Of the 40 that ran every time on
        October 22, 2026, nearly every walk filtered on *.ps1, *.md, a manifest or a named folder, so a
        CSS fix waited on all of them. A suite that says '# gate-selection: walks <pattern> ...' runs
        only when a changed path falls inside one of the patterns (Test-WalkScopeMatch), and its
        reference graph still selects it as before. A declaration is the suite author's claim about
        what the walk reads -- including what a script it runs against the live tree reads -- and a
        wrong one costs a red CI run, the same bar as everything else here. CI's asset-only selection
        (ci-suite-selection-lib.ps1) trusts it too since #3392, where a wrong one costs an ungated merge,
        so the scope guard in affected-suites.tests.ps1 holds every declaration against the roots and
        types of the walks the reading can see (WalkSamples).

        THE BRANCH'S OWN DOCUMENT FALLS IN NO WALK SCOPE (issue #3379). new-branch writes
        dkj-policy/<branch>.md on every branch, so a '*.md' scope selected its suite on every branch:
        measured on PR #3375, a one-line CSS comment, five scoped suites came from that document alone and
        script-contract set an 89s makespan where ~23s would do. None of the five reads a branch document
        (they read root docs, personas, the always-on closure, manifests). -BranchDocument names it, the
        caller resolves it, and it is left out of the scope match ONLY: a suite that names or reaches the
        document is still selected by the reference graph. Empty removes nothing. CI's half is #3370's
        Remove-BranchDocumentPath.

        KNOWN GAPS, each costing a red CI run rather than an ungated
        merge: a file name assembled at run time ("x-" + "lib.ps1"), Import-Module, and a script run
        through Invoke-Expression or [scriptblock]::Create are not followed.

        WHY THIS IS NOT THE PER-SUITE PROOF #2323 DECLINED. That proposal would have RECORDED a suite as
        proved without running it, with nothing behind the record to catch a wrong one. This records
        nothing: a selected run writes no gate evidence, and the required CI check still runs every
        suite before anything merges. A suite this misses costs a red CI run instead of a red local
        one, which is the asymmetry Get-TestSuiteCostHints asks of a hint -- it can cost time, not
        coverage. And the static model's known direction of error is the safe one here: wherever it
        cannot follow a reference, it either runs the suite (a file that does not parse, a live-tree
        walk) or falls back to the whole pool (the reasons below).

        THE WHOLE POOL, WITH THE REASON, WHENEVER:
          - git cannot list the tree;
          - a changed path is not plain ASCII (git quotes it, and a quoted path cannot be matched);
          - the change touches the selection, the gate that runs it, or the CI behind it -- this
            file, native-capture-lib.ps1, the libs this file loads, repo-config.ps1 or a workflow
            under .github/workflows/, in the source or a mirror -- since a selector must not judge its
            own change, and a change that could shrink CI must not shrink the local gate with it.

        WHAT IT COSTS. Parsing ~480 scripts takes about a minute on Windows PowerShell 5.1, so each
        file's references are cached in the git directory by BLOB ID: an unchanged file is never parsed
        twice, a changed one is parsed once, and the cache is keyed by a hash of the extractor itself so
        a change to the rules below invalidates it. A file that differs from the index is parsed fresh
        and not cached, because its blob id names content it no longer has.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedPaths,
        [string]$TestsDir = 'scripts/tests',
        [AllowEmptyString()][string]$BranchDocument = ''
    )
    $branchDoc = "$BranchDocument".Trim().Replace('\', '/').ToLowerInvariant()
    $testsPrefix = ($TestsDir.Replace('\', '/').Trim('/')).ToLowerInvariant() + '/'
    $verdict = [pscustomobject]@{ Proven = $false; Suites = @(); Always = @(); Scoped = @(); Walkers = @(); Open = @(); Matched = @(); Why = @{}; PoolCount = 0; Reason = '' }

    $changed = @($ChangedPaths | ForEach-Object { "$_".Trim().Replace('\', '/') } | Where-Object { $_ })
    $quoted = @($changed | Where-Object { $_.StartsWith('"') })
    if ($quoted.Count -gt 0) {
        $verdict.Reason = "$($quoted.Count) changed path(s) are not plain ASCII, and a quoted path cannot be matched to a reference"
        return $verdict
    }
    $own = @($changed | Where-Object {
        $_ -match '(^|/)(gate-lib|native-capture-lib|hash-hex-lib|command-probe-lib|git-porcelain-lib|repo-config|ci-suite-selection-lib|get-pr-suite-selection)\.ps1$' -or
        $_ -match '^\.github/workflows/'
    })
    if ($own.Count -gt 0) {
        $verdict.Reason = "the change touches the selection, the gate that runs it or the CI behind it ($($own -join ', ')), and a selector does not judge its own change"
        return $verdict
    }
    $changed = @($changed | ForEach-Object { $_.ToLowerInvariant() })

    $staged = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'ls-files', '--stage')
    $untracked = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'ls-files', '--others', '--exclude-standard')
    $modified = Invoke-GitRead -RepoRoot $RepoRoot -GitArgs @('-c', 'core.quotePath=true', 'ls-files', '--modified')
    if ($null -eq $staged -or $null -eq $untracked -or $null -eq $modified) {
        $verdict.Reason = 'git could not list the tree, so no suite could be mapped'
        return $verdict
    }
    # '<mode> <blob> <stage>TAB<path>' -- the blob id is what the cache is keyed on.
    $blobOf = @{}
    $files = New-Object System.Collections.ArrayList
    foreach ($line in $staged) {
        $tab = "$line".IndexOf("`t")
        if ($tab -lt 0) { continue }
        $path = "$line".Substring($tab + 1)
        $meta = "$line".Substring(0, $tab).Split(' ')
        if (-not $blobOf.ContainsKey($path)) { [void]$files.Add($path) }
        if ($meta.Count -ge 2) { $blobOf[$path] = $meta[1] }
    }
    foreach ($u in $untracked) { if ("$u".Trim()) { [void]$files.Add("$u") } }
    foreach ($m in $modified) { if ($blobOf.ContainsKey("$m")) { $blobOf.Remove("$m") } }

    $byLeaf = @{}
    foreach ($f in $files) {
        $lower = $f.ToLowerInvariant()
        $leaf = ($lower -split '/')[-1]
        if (-not $byLeaf.ContainsKey($leaf)) { $byLeaf[$leaf] = New-Object System.Collections.ArrayList }
        [void]$byLeaf[$leaf].Add($f)
    }
    $suites = @($files | Where-Object {
        $l = $_.ToLowerInvariant()
        $l.StartsWith($testsPrefix, [StringComparison]::Ordinal) -and $l.Substring($testsPrefix.Length) -notmatch '/' -and $l.EndsWith('.tests.ps1')
    } | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) -PathType Leaf } | Sort-Object)
    # ON DISK, not only in the index: a suite deleted but not yet staged is in ls-files and not in the
    # directory Invoke-TestSuiteGate globs, and naming it there throws.
    $verdict.PoolCount = $suites.Count

    # THE CACHE, keyed by the extractor's own source so a change to how references are read can never be
    # answered from a cache written under the old rules. Best-effort in both directions: an unreadable or
    # malformed file is an empty cache, and an unwritable one costs the next run its parse.
    $extractor = Get-Sha256Hex -Text ("v2`n" + ${function:ConvertTo-SuiteReference}.ToString() + ${function:Get-SuiteReferenceSet}.ToString())
    $cachePath = Get-SuiteReferenceCachePath -RepoRoot $RepoRoot
    $stored = @{}
    if ($cachePath -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        try {
            $raw = [System.IO.File]::ReadAllText($cachePath) | ConvertFrom-Json
            if ($raw -and "$($raw.extractor)" -eq $extractor -and $raw.blobs) {
                foreach ($p in $raw.blobs.PSObject.Properties) { $stored[$p.Name] = $p.Value }
            }
        } catch { $stored = @{} }
    }
    $used = @{}
    $cacheState = @{ Dirty = $false }

    $refs = @{}
    $refsOf = {
        param([string]$Path)
        if ($refs.ContainsKey($Path)) { return $refs[$Path] }
        $r = [pscustomobject]@{ Parsed = $true; Run = @(); Read = @(); Walks = $false; WalksOpen = $false; Scope = @() }
        $full = Join-Path $RepoRoot $Path
        if ($Path -like '*.ps1' -and (Test-Path -LiteralPath $full -PathType Leaf)) {
            $blob = if ($blobOf.ContainsKey($Path)) { $blobOf[$Path] } else { '' }
            if ($blob -and $stored.ContainsKey($blob)) {
                $e = $stored[$blob]
                $r = [pscustomobject]@{ Parsed = [bool]$e.p; Run = @($e.r); Read = @($e.d); Walks = [bool]$e.w; WalksOpen = [bool]$e.o; Scope = @($e.s | Where-Object { $_ }) }
            } else {
                $r = Get-SuiteReferenceSet -Text ([System.IO.File]::ReadAllText($full))
                if ($blob) {
                    $stored[$blob] = [pscustomobject]@{ p = [int]$r.Parsed; r = @($r.Run); d = @($r.Read); w = [int]$r.Walks; o = [int]$r.WalksOpen; s = @($r.Scope) }
                    $cacheState.Dirty = $true
                }
            }
            if ($blob) { $used[$blob] = $true }
        }
        $refs[$Path] = $r
        return $r
    }
    # WHICH TRACKED .ps1 FILES A REFERENCE RESOLVES TO, computed once per reference rather than once per
    # suite that meets it -- the same libs are met by nearly every suite, and resolving them afresh each
    # time was most of this function's cost.
    $targetCache = @{}
    $targetsOf = {
        param([string]$Reference)
        if ($targetCache.ContainsKey($Reference)) { return $targetCache[$Reference] }
        $leaf = ($Reference -split '/')[-1]
        $out = New-Object System.Collections.ArrayList
        foreach ($k in @($leaf, "$leaf.ps1")) {
            if (-not $k.EndsWith('.ps1') -or -not $byLeaf.ContainsKey($k)) { continue }
            foreach ($f in $byLeaf[$k]) {
                if (Test-SuiteReferenceMatch -Path $f.ToLowerInvariant() -Reference $Reference) { [void]$out.Add($f) }
            }
        }
        $targetCache[$Reference] = $out
        return $out
    }

    $selected = New-Object System.Collections.ArrayList
    $always = New-Object System.Collections.ArrayList
    $scoped = New-Object System.Collections.ArrayList
    $walkers = New-Object System.Collections.ArrayList
    $open = New-Object System.Collections.ArrayList
    $matched = New-Object System.Collections.ArrayList
    $why = @{}
    foreach ($s in $suites) {
        $reached = New-Object 'System.Collections.Generic.HashSet[string]'
        $named = New-Object 'System.Collections.Generic.HashSet[string]'
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue($s); [void]$reached.Add($s)
        $runAlways = $false
        $walks = $false
        $walksOpen = $false
        $scope = New-Object 'System.Collections.Generic.HashSet[string]'
        while ($queue.Count -gt 0) {
            $p = $queue.Dequeue()
            $r = & $refsOf $p
            $testOwned = $p.ToLowerInvariant().StartsWith($testsPrefix, [StringComparison]::Ordinal)
            # A file that does not parse is unknown, so its suite always runs and its walk is open.
            if (-not $r.Parsed) { $runAlways = $true; $walksOpen = $true; $why[$s] = "$p does not parse, so what it reaches is unknown"; break }
            if ($testOwned -and $r.Walks) {
                # A walk with no declared scope reads whatever the tree holds; one with a scope adds it to
                # the suite's, and the graph is still followed for everything else the file names -- an
                # unscoped one too, so an open walk further along still marks the suite Open (#3316). The
                # first unscoped walk met is the reason given.
                if ($r.WalksOpen) { $walksOpen = $true }
                if (@($r.Scope).Count -eq 0 -and -not $runAlways) { $runAlways = $true; $why[$s] = "$p walks the live tree and declares no scope, so it runs for every change" }
                $walks = $true
                foreach ($pattern in @($r.Scope)) { [void]$scope.Add($pattern) }
            }
            $follow = @($r.Run)
            if ($testOwned) { $follow += @($r.Read) }
            # The seam config hands out data, never a dependency: every path it names is a value a caller
            # reads in whatever tree it passes (#3343). Only what it RUNS is followed.
            $isSeam = $p -match '(^|/)repo-config\.ps1$'
            foreach ($ref in @($r.Read)) {
                if ($testOwned -or (-not $isSeam -and $ref.Contains('/') -and $ref -notlike '*.ps1')) { [void]$named.Add($ref) }
            }
            foreach ($ref in $follow) {
                [void]$named.Add($ref)
                foreach ($t in (& $targetsOf $ref)) {
                    if ($reached.Add($t)) { $queue.Enqueue($t) }
                }
            }
        }
        if ($walksOpen) { [void]$open.Add($s) }
        if ($runAlways) { [void]$always.Add($s); [void]$walkers.Add($s); [void]$selected.Add($s); continue }
        if ($walks) {
            [void]$walkers.Add($s)
            $inScope = $false
            foreach ($c in $changed) {
                if ($branchDoc -and $c -eq $branchDoc) { continue }
                foreach ($pattern in $scope) { if (Test-WalkScopeMatch -Path $c -Pattern $pattern) { $inScope = $true; $why[$s] = "its walk scope '$pattern' covers $c"; break } }
                if ($inScope) { break }
            }
            if ($inScope) { [void]$scoped.Add($s); [void]$selected.Add($s); continue }
        }
        $hit = $false
        foreach ($c in $changed) {
            foreach ($rp in $reached) {
                if ($rp.ToLowerInvariant() -eq $c) {
                    $hit = $true
                    $why[$s] = $(if ($rp -eq $s) { 'it is itself a changed file' } else { "it reaches $c" })
                    break
                }
            }
            if (-not $hit) { foreach ($ref in $named) { if (Test-SuiteReferenceMatch -Path $c -Reference $ref) { $hit = $true; $why[$s] = "it or a file it runs names $c"; break } } }
            if ($hit) { break }
        }
        if ($hit) { [void]$selected.Add($s); [void]$matched.Add($s) }
    }
    $verdict.Suites = @($selected)
    $verdict.Always = @($always)
    $verdict.Scoped = @($scoped)
    $verdict.Walkers = @($walkers)
    $verdict.Open = @($open)
    $verdict.Matched = @($matched)
    $verdict.Why = $why
    $verdict.Proven = $true

    # Written only when something new was parsed or something stale can be dropped, and then holding
    # only the blobs this tree still uses -- so the file is bounded by the tree, not by its history.
    if ($cachePath -and ($cacheState.Dirty -or $stored.Count -ne $used.Count)) {
        $keep = [ordered]@{}
        foreach ($k in ($used.Keys | Sort-Object)) { if ($stored.ContainsKey($k)) { $keep[$k] = $stored[$k] } }
        try {
            $json = [ordered]@{ extractor = $extractor; blobs = $keep } | ConvertTo-Json -Depth 5 -Compress
            [System.IO.File]::WriteAllText($cachePath, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch { }
    }
    return $verdict
}
# THE LINT GATE'S OWN PROGRESS RECORD, FOR THE STATUSLINE -- issue #2173. The bar (#2101) had two
# publishers, the test gate's lane events and ship-pr's CI wait, and the lint gate is neither. It is the
# step that runs FIRST in a ship and it took 78s on the measured run (PR #2169, 2026-09-20) while
# publishing nothing, so the statusline showed only its context line for the stretch a reader is watching
# for. Where the suites were already proved for the tree, the one long publisher that does exist never
# fires either, and the whole pre-CI phase of the ship was silent.
#
# PUBLISHED HERE, AROUND THE CHILD, AND NOT FROM INSIDE check-plugin-integrity.ps1 -- which is what the
# issue proposed, on the reading that the check "knows its own check count as it walks". Read against the
# script, that is not so: Write-Coverage prints a per-class 'checked <n>', each with its own denominator,
# and no total number of checks exists at runtime. A bar needs one, so it would have to be a literal or a
# self-parse of the script's own headers, threaded through ~48 call sites -- and the checks are wildly
# uneven (one link walk dominates), so a fraction of CHECKS would sit still for most of the run. That is
# a fraction nobody measured, which run-progress-lib.ps1 says in so many words is an invention.
#
# WHAT THIS PUBLISHES IS THE SHAPE ship-pr's CI wait already uses, for the same reason: this function is
# blocked inside ONE child call, so it has a label and a start and nothing else honest to say. No counts,
# therefore no bar -- the reader gets 'lint gate' and the run's own clock, and the statusline derives the
# elapsed itself, so the readout keeps moving while this function writes nothing.
#
# GUARDED ON THE FUNCTION, NOT ON A DOT-SOURCE. run-progress-lib.ps1 arrives through native-capture-lib's
# guarded load, which every caller of this file has one way or another (git-porcelain-lib.ps1 above loads
# it, and open-pr.ps1 loads it first). A tree where that chain is broken -- a consumer whose mirror
# predates the bar -- simply gets no record, and the gate is byte-for-byte what it was. Best-effort by
# construction: neither helper throws, and a diagnostic must not cost the run it describes.
#
# ONLY AT THE TOP LEVEL, AND THAT IS WHAT KEEPS THE TEST GATE'S OWN BAR ON THE STATUSLINE. The statusline
# draws the NEWEST live record, and many suites drive this very function over a fixture lint script that
# exits in about a second -- each one would otherwise repaint the line with 'lint gate' in the middle of
# the test gate's bar, for a run nobody is waiting on. Invoke-TestSuiteGate exports DKJ_TEST_GATE_DEPTH to
# every suite it spawns and Get-GateNestingDepth reads it back, so a lint run inside a suite reads as
# depth 2 and stays silent, while a ship -- which is nobody's child -- reads 1 and publishes. The same
# variable already keeps a fixture gate from being mistaken for the real one on the console (#1717).
function Publish-LintGateProgress {
    param([Parameter(Mandatory = $true)][datetime]$StartedUtc)
    if (-not (Test-FunctionDefined 'Write-RunProgress')) { return }
    if ((Test-FunctionDefined 'Get-GateNestingDepth') -and (Get-GateNestingDepth) -gt 1) { return }
    try {
        [void](Write-RunProgress -Id (Get-RunProgressId -Name 'lint-gate') -Label 'lint gate' `
            -Note 'integrity check' -StartedUtc $StartedUtc)
    } catch { }
}

function Clear-LintGateProgress {
    <# The lint gate's record removed once its child has returned, pass or fail -- issue #2173. #>
    if (-not (Test-FunctionDefined 'Complete-RunProgress')) { return }
    try { [void](Complete-RunProgress -Id (Get-RunProgressId -Name 'lint-gate')) } catch { }
}

function Invoke-WorkflowGates {
    <#
        Runs the repo's two gates -- the lint script, then every test suite -- against the working tree,
        consulting and recording the evidence above so an unchanged tree is not gated twice -- and,
        since issue #1715, honouring the caller's CI certificate for the same commit so a tree CI has
        already proved is not gated a third time. Returns
        $true when both passed (or were skipped) and $false when either failed, having already written
        the diagnosis; the caller decides what a failure costs and whether to exit.

        WHY IT IS A FUNCTION AT ALL (issue #1156, August 30, 2026). These hundred lines lived inline in
        open-pr.ps1, which is the ONE documented way to run the gates -- and open-pr refuses on `main`,
        several hundred lines before it reaches them. So the release-notes commit, made standing on the
        trunk under the third direct-on-`main` exception, was told to "run the gates exactly as open-pr
        would have" via a script that will not run there. The repair is -GatesOnly on open-pr, which
        needs this block reachable before the branch check rather than after it.

        AND THE HAND-ROLLED ALTERNATIVE IS WHY A PROSE ANSWER WAS NOT ENOUGH. The invocation that gets
        invented in that spot is a fresh process dot-sourcing native-capture-lib and calling
        Invoke-TestSuiteGate directly. It runs, it goes green, and it is missing two things silently:
        Get-TestCommands is not in scope, so a consumer whose suites are not all PowerShell has the rest
        of them skipped without a word (the failure inbound #644 was filed about, and the one this lib's
        sibling warns ci.yml about by name), and the lint half gets the source repo's script hardcoded
        instead of the Get-LintScript seam the consumer set. A gate you can only reach by rebuilding it
        is a gate whose weakest invocation is the one that gets used.

        THE CALLER MUST HAVE DOT-SOURCED TWO MORE THINGS, and this function deliberately does not reach
        for them itself: scripts\repo-config.ps1 (for Get-LintScript, and for the optional
        Get-TestCommands that Invoke-TestSuiteGate reads on its own) and native-capture-lib.ps1 (for
        Invoke-TestSuiteGate). Same contract, and the same reasoning, as Invoke-TestSuiteGate's own --
        a lib that resolved its caller's repo root would have two answers to that question in one run.

        -ErrorAction Continue ON BOTH FAILURE MESSAGES, and it is not decoration. Every caller of this
        function runs under $ErrorActionPreference = 'Stop', where Write-Error TERMINATES -- which is
        harmless in a script that was going to exit 1 on the next line, and a lie in a function that
        promises a bool. Left terminating, the return value is dead code, the caller's exit never runs, and
        a test can only observe this function by catching an exception. So the message is emitted
        non-terminating and the CALLER decides what a red costs.

        THE MESSAGES ARE THE CALLER'S, through -FailureConsequence: what a red costs depends entirely on
        where in the chain it fired. At the PR nothing is pushed; on a -GatesOnly run nothing else was
        going to happen anyway. The rest of both sentences is fixed here so the two callers cannot drift
        into describing the same gate differently.

        -MaxParallel IS A PASSTHROUGH AND NOTHING ELSE (issue #1443, September 5, 2026). This function
        adds no lane policy of its own: it forwards the number to Invoke-TestSuiteGate, whose own
        `-le 0` branch resolves the default. That is what makes 0 -- the default here -- byte-identical
        to not passing it at all, which is the property the whole chain from ship-pr down rests on.

        WHY THE HOP EXISTS. Invoke-TestSuiteGate has taken -MaxParallel since it was written, and
        ci.yml passes it; the two callers that run a developer's machine could not, because this
        function sat between them and it did not carry the parameter. The only route past a gate that
        will not finish was therefore -SkipTests -- the switch that says "this run did not measure" --
        so a memory limit and a deliberate skip left the same trace. A lane count leaves the
        measurement inside the run that is supposed to make it, and the run says how many lanes it used.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [switch]$SkipLint,
        [switch]$SkipTests,
        # What Invoke-TestSuiteGate calls the thing being gated in its own output ('the PR', 'the gate run').
        [string]$Context = 'the gate',
        # What a failure costs at THIS point in the chain, e.g. 'branch not pushed, no PR opened'.
        [string]$FailureConsequence = 'nothing further ran',
        # Lanes for the test gate. 0 = let Invoke-TestSuiteGate resolve its own default; see the header.
        [int]$MaxParallel = 0,
        # The CI certificate for THIS commit, as Get-CiTestCertificate's Note (issue #1715). Non-empty
        # means the trunk's required checks are green on the exact HEAD this run would ship, and the
        # test gate is then satisfied without running. A STRING AND NOT A SWITCH: the note is the whole
        # value of the parameter -- a skip nobody can read is a gate nobody can audit -- and one
        # parameter cannot disagree with itself the way a switch plus a message can. The caller decides
        # whether a certificate exists, because it is the caller that can reach `gh`; this function
        # only decides what a certificate is worth.
        [string]$TestsProvedByCi = '',
        # OPT-IN, AND NEVER THE DEFAULT (issue #2102). Ask whether every path that differs from HEAD sits
        # inside the release-note tree, and where that is PROVEN, skip the test gate -- because the suites'
        # entire coverage of that tree is the lint gate this same run has just executed. Where it is not
        # proven, for any reason at all, the suites run exactly as they always did and the run says which
        # reason it was. A SWITCH AND NOT A DEFAULT because a deduction nobody asked for is the silent
        # matcher #2102 declined: the caller states that this is a note-tree commit, and this function
        # then refuses to take their word for it.
        [switch]$NoteTreeOnly,
        # RUN ONLY THE SUITES THIS BRANCH'S CHANGES CAN AFFECT (issue #3223) -- Get-AffectedSuiteSelection.
        # open-pr passes it by default and -AllSuites turns it off; every other caller (the release cut,
        # -GatesOnly) leaves it off and gates the whole pool. It applies only where a required CI check
        # runs the whole pool behind it, it records no gate evidence, and wherever the mapping is not
        # proven every suite runs and the run says why.
        [switch]$SelectSuites
    )
    # A GATE RUN IS NOT PART OF THE CHAIN WHOSE RECEIPT IS BEING SUPPRESSED (issue #1910). Both gates
    # below spawn CHILD PROCESSES -- the lint script, and every scripts\tests\*.tests.ps1 the test gate
    # runs -- and a child inherits DKJ_CLOSEOUT_SUPPRESS from whatever conductor is above this run. That
    # is the mechanism #1884 wants for chain-ending scripts and exactly wrong for these: a test suite is
    # not a link in the chain, it is the thing proving the chain may proceed.
    #
    # MEASURED, September 13, 2026. ship-pr suppressed around its open-pr child, open-pr's test gate
    # spawned the suites, and closeout-lib.tests.ps1 asserted on a receipt the inherited flag had
    # already muted -- so it crashed, the gate reported one of 101 suites failing, and ship-pr stopped
    # with nothing merged. It landed on the recovery path the staleness guard (#1292) itself prescribes:
    # re-running ship-pr is the way out, and a re-run is exactly when open-pr has something to push and
    # therefore reaches its gate. CI never saw it -- a fresh runner has no conductor above it -- so the
    # only gate that failed was the local one, which is the most confusing place for the two to disagree.
    #
    # HERE RATHER THAN IN THE SUITE, though that suite is fixed too. A suite asserting on an ambient
    # global is its own defect, but repairing only that leaves the next suite to rediscover this; the
    # rule "a gate run steps out of the suppression" has to hold for suites nobody has written yet.
    # Guarded, and suspended rather than popped: Pop-CloseOutSuppression is documented as unconditional,
    # so a run that used it would clear the flag for the conductor's remaining children too.
    $gateWasSuppressed = $false
    $gateCanSuspend = (Test-FunctionDefined 'Suspend-CloseOutSuppression') -and (Test-FunctionDefined 'Restore-CloseOutSuppression')
    if ($gateCanSuspend) { $gateWasSuppressed = Suspend-CloseOutSuppression }
    try {

        # The fingerprint is computed ONCE for both gates -- it hashes HEAD plus every dirty and untracked
        # file, so asking twice would hash the same tree twice. $null means git could not answer, and every
        # helper then reports "no evidence", which runs the gates exactly as before.
        $gateFingerprint = Get-GateFingerprint -RepoRoot $RepoRoot

        # AND HOW MANY TIMES HEAD HAS MOVED, read beside it and asked again after each gate (issue #1145). The
        # fingerprint above cannot see a checkout that CAME BACK -- a command that switches away and switches
        # straight back leaves every byte identical -- and a session runs maintenance commands mid-assignment,
        # which is exactly when a backgrounded ship is sitting inside step 1. The reflog depth is where those
        # two moves are recorded, and it is per-worktree, so a lane moving its own checkout never registers
        # here.
        $gateHeadMoves = Get-GateHeadMoveCount -RepoRoot $RepoRoot

        # AND THE GATES SAY WHEN THEY RAN AGAINST SOMETHING OTHER THAN HEAD (issue #1026). Both gates below
        # judge the WORKING TREE; a caller that pushes ships HEAD. On a clean tree those are the same thing
        # and a green result is evidence about what merges. On a dirty one they are not, and nothing said so:
        # PR #1025's lint run walked a manual with two new rules in it, reported zero errors, and shipped a PR
        # without them.
        #
        # ONE LINE, ABOVE BOTH GATES rather than repeated inside each. It is the same fact about the same tree,
        # and a warning printed twice is read half as often as one printed once. Said before either gate runs,
        # so it frames the results that follow instead of trailing them.
        #
        # NOT A REFUSAL. A dirty tree mid-flight is ordinary -- open-pr's backing gate is where the one shape
        # that is genuinely wrong gets stopped. This is here so a green line stops being mistaken for proof.
        $gateDirtyCount = Get-GateTreeDirtyCount -RepoRoot $RepoRoot
        if ($null -ne $gateDirtyCount -and $gateDirtyCount -gt 0 -and (-not $SkipLint -or -not $SkipTests)) {
            Write-Warning "the gates below run against a DIRTY tree - $gateDirtyCount file(s) differ from HEAD, and what lands is HEAD. A green result proves the working copy, not what merges."
        }

        # Lint gate: catch invalid manifests/frontmatter/dead links before they land on the trunk. The lint
        # script is repo-specific (via repo-config); errors block. -SkipLint deliberately skips the gate.
        if (-not $SkipLint) {
            $lintPath = Join-Path $RepoRoot (Get-LintScript)
            if (Test-Path $lintPath) {
                if (Test-GateEvidence -RepoRoot $RepoRoot -Gate 'lint' -Fingerprint $gateFingerprint) {
                    Write-Host "lint gate: already proved against this exact tree -- skipped." -ForegroundColor DarkGray
                } else {
                    Write-Host "lint gate: integrity check for $Context..." -ForegroundColor Cyan
                    # START-PROCESS AND NOT `& powershell`, AND THE DIFFERENCE IS THE FUNCTION BOUNDARY.
                    # As a top-level statement in open-pr.ps1 the bare call operator was safe: the child's
                    # stdout went to the console and only $LASTEXITCODE was read. Inside a function whose
                    # return value the caller consumes -- `if (-not (Invoke-WorkflowGates ...))` -- every
                    # uncaptured line the child prints becomes part of what this function RETURNS, because
                    # stream type does not survive a process boundary and arrives as plain strings on the
                    # success stream. PowerShell then coerces the resulting multi-element array to $true
                    # unconditionally, so `-not` is $false and A FAILING LINT GATE READS AS GREEN.
                    #
                    # REPRODUCED before it was repaired (August 30, 2026): a fake lint script printing two
                    # lines and exiting 1 made this function return @('line', 'line', $false), and the
                    # caller's exit never fired. It is invisible on the happy path -- a green run pollutes
                    # the return identically and the truthy answer happens to be correct -- which is why it
                    # would have survived any test that only ever passes.
                    #
                    # Start-Process -NoNewWindow -Wait emits NOTHING to the pipeline and hands the child this
                    # console, so the lint output stays live and coloured rather than being buffered or
                    # stripped by a pipe -- the same choice, for the same reason, that Invoke-TestSuiteGate
                    # makes for the suites. -WorkingDirectory is NOT optional: Start-Process starts the child
                    # in [Environment]::CurrentDirectory, which does not follow Set-Location, so the caller's
                    # own location has to be passed for the child to see the tree the bare call gave it.
                    # WALL-CLOCK, so a "the full gate cost ~Ys" figure has a lint half to name beside the
                    # test half's "all N suites passed in Xs" (issue #1319). #1314 measured what its absence
                    # costs -- three "full gate" figures for one test set, one bundling an unstated lint
                    # cost and two, by their wording, not. Timed ONLY around the real run: the evidence-cache
                    # fast path above prints "skipped" and no seconds, the way Invoke-TestSuiteGate's own
                    # cache branch does.
                    $lintStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    # PUBLISHED FOR THE STATUSLINE, and removed the moment the child returns on either
                    # verdict (issue #2173) -- see Publish-LintGateProgress for what it says and why not more.
                    Publish-LintGateProgress -StartedUtc ([datetime]::UtcNow)
                    $lintRun = Start-Process -FilePath 'powershell' `
                        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $lintPath + '"')) `
                        -NoNewWindow -Wait -PassThru -WorkingDirectory (Get-Location).Path
                    $lintStopwatch.Stop()
                    Clear-LintGateProgress
                    # Invariant-culture format, for the reason Format-GateSeconds (native-capture-lib.ps1)
                    # states at length (issue #1159): '-f' renders in the current culture, so above 1000s a
                    # Dutch machine prints the seconds a thousandfold off and still plausible. gate-lib does
                    # not dot-source native-capture-lib -- its callers supply both libs -- so the one-line
                    # format is repeated here rather than that helper borrowed across a lib boundary.
                    $lintSeconds = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:N0}', $lintStopwatch.Elapsed.TotalSeconds)
                    if ($lintRun.ExitCode -ne 0) {
                        # A RED IS ONLY A FINDING IF THE TREE HELD STILL FOR IT (issue #1145). Printed before
                        # the error, so it frames the red rather than trailing it.
                        $movedNote = Get-GateTreeMovedNote -RepoRoot $RepoRoot -Gate 'lint' -Fingerprint $gateFingerprint -HeadMoves $gateHeadMoves -Failed
                        if ($movedNote) { Write-Warning $movedNote }
                        Write-Host ("lint gate: integrity check FAILED in {0}s." -f $lintSeconds) -ForegroundColor Red
                        Write-Error "lint gate found errors - $FailureConsequence. Fix the errors, or run with -SkipLint to skip the gate." -ErrorAction Continue
                        return $false
                    }
                    Write-Host ("lint gate: integrity check passed in {0}s." -f $lintSeconds) -ForegroundColor Green
                    # Recorded only on a real pass. -SkipLint records nothing, deliberately: skipping a gate
                    # proves nothing about the tree, and writing evidence there would make the escape valve
                    # silently suppress the NEXT run's gate too.
                    #
                    # AND ONLY WHEN THE TREE HELD STILL (issue #1145). A pass earned over a tree that moved
                    # mid-run is real for the mixture the gate saw, and that mixture is not the fingerprint it
                    # would be filed under -- so it is reported and not recorded, and the next run gates for real.
                    $movedNote = Get-GateTreeMovedNote -RepoRoot $RepoRoot -Gate 'lint' -Fingerprint $gateFingerprint -HeadMoves $gateHeadMoves
                    if ($movedNote) {
                        Write-Warning $movedNote
                    } else {
                        [void](Save-GateEvidence -RepoRoot $RepoRoot -Gate 'lint' -Fingerprint $gateFingerprint)
                    }
                }
            } else {
                Write-Warning "lint script not found at '$lintPath' - lint gate skipped."
            }
        }

        # Test gate: all suites, exactly as CI -- a red suite should already block here, not only at the
        # PR (a lesson from PR #54). -SkipTests is the deliberate escape valve. A repo whose tests are not
        # all PowerShell names the rest in the optional Get-TestCommands (repo-config); Invoke-TestSuiteGate
        # reads it itself, so every call site stays identical (inbound #644).
        if (-not $SkipTests) {
            # THE NOTE-TREE VERDICT, MEASURED BEFORE THE CHAIN AND ONLY WHERE IT CAN DECIDE ANYTHING
            # (issue #2102). Computed here rather than inside the branch that consumes it so the REFUSAL
            # has somewhere to be said: a run that asked for the deduction and did not get it has to learn
            # which of the five reasons it was, and a verdict computed inside its own success branch can
            # only ever report the success.
            #
            # GATED ON THE TWO CHEAPER SKIPS, which is not an optimisation but the refusal's own honesty.
            # Both of them skip the suites for reasons of their own, so a run that prints "NOT proven --
            # running every suite" and is then told "already proved against this exact tree -- skipped"
            # has contradicted itself on two adjacent lines. The behaviour was right either way; what was
            # wrong was the transcript, and this file's own bar is that what it prints IS the argument.
            # So the refusal is only ever said where the suites are actually about to run -- and the git
            # call it costs is only ever spent there too. $null when nothing asked or nothing to decide,
            # which every branch below reads as "not applicable".
            $gateTestsProved = Test-GateEvidence -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint
            $gateNoteTree = $null
            if ($NoteTreeOnly -and -not $gateTestsProved -and -not $TestsProvedByCi) {
                $gateNoteTree = Get-NoteTreeOnlyVerdict -RepoRoot $RepoRoot -NoteRoots (Get-ReleaseNoteTreeRoots -RepoRoot $RepoRoot)
                if (-not $gateNoteTree.Proven) {
                    Write-Host ("test gate: -NoteTreeOnly was asked for and is NOT proven -- {0}. Running every suite, exactly as without the switch." -f $gateNoteTree.Reason) -ForegroundColor Yellow
                    foreach ($p in ($gateNoteTree.Outside | Select-Object -First 8)) {
                        Write-Host ("           outside the note tree: " + (Get-DisplayPath -Path $p)) -ForegroundColor Yellow
                    }
                    if ($gateNoteTree.Outside.Count -gt 8) {
                        Write-Host ("           ... and {0} more" -f ($gateNoteTree.Outside.Count - 8)) -ForegroundColor Yellow
                    }
                }
            }

            # THE AFFECTED-SUITE SELECTION, MEASURED ON THE SAME TERMS AS THE NOTE-TREE VERDICT ABOVE (issue
            # #3223): only where the suites are actually about to run, and its refusal said out loud. Last
            # among the deductions because it is the dearest -- a tree listing plus, on a cold cache, a parse
            # of every script.
            $gateSelection = $null
            if ($SelectSuites -and -not $gateTestsProved -and -not $TestsProvedByCi -and -not ($gateNoteTree -and $gateNoteTree.Proven)) {
                $ciCheck = ''
                if (Test-FunctionDefined 'Get-CiTestCheckName') { try { $ciCheck = "$(Get-CiTestCheckName)".Trim() } catch { $ciCheck = '' } }
                $gateSelection = [pscustomobject]@{ Proven = $false; Suites = @(); Always = @(); Scoped = @(); Walkers = @(); Open = @(); Matched = @(); PoolCount = 0; Reason = '' }
                if (-not $ciCheck) {
                    # NOTHING BEHIND A PARTIAL RUN, SO THERE IS NONE. The whole argument for selecting is that
                    # the required check runs every suite before anything merges; a repo that names no such
                    # check has only this gate.
                    $gateSelection.Reason = 'this repo names no required CI check (Get-CiTestCheckName) to run the whole pool behind a partial one'
                } else {
                    $gateChanges = Get-GateChangedPaths -RepoRoot $RepoRoot
                    if (-not $gateChanges.Known) {
                        $gateSelection.Reason = $gateChanges.Reason
                    } elseif ($gateChanges.Paths.Count -eq 0) {
                        $gateSelection.Reason = "nothing differs from $($gateChanges.Base), so there is no change to select from"
                    } else {
                        # A THROW HERE IS NOT A RED GATE: the selection is an optimisation, so whatever breaks it
                        # (an unreadable file, a cache, git) costs the saving and runs every suite.
                        try {
                            $gateSelection = Get-AffectedSuiteSelection -RepoRoot $RepoRoot -ChangedPaths $gateChanges.Paths -BranchDocument (Get-GateBranchDocument -RepoRoot $RepoRoot)
                        } catch {
                            $gateSelection = [pscustomobject]@{ Proven = $false; Suites = @(); Always = @(); Scoped = @(); Walkers = @(); Open = @(); Matched = @(); PoolCount = 0; Reason = "the selection failed: $($_.Exception.Message)" }
                        }
                        $extraTestCommands = @()
                        if (Test-FunctionDefined 'Get-TestCommands') { $extraTestCommands = @(Get-TestCommands | Where-Object { "$_".Trim() }) }
                        if ($gateSelection.Proven -and $gateSelection.Suites.Count -eq 0 -and $extraTestCommands.Count -gt 0) {
                            # The repo's own test commands are not suites and cannot be selected; an empty
                            # selection would skip them, so the whole gate runs instead.
                            $gateSelection.Proven = $false
                            $gateSelection.Reason = 'no suite is affected, and the repo test commands (Get-TestCommands) cannot be selected'
                        }
                    }
                }
                if (-not $gateSelection.Proven) {
                    Write-Host ("test gate: the affected-suite selection is NOT proven -- {0}. Running every suite." -f $gateSelection.Reason) -ForegroundColor Yellow
                }
            }

            if ($gateTestsProved) {
                Write-Host "test gate: all suites already proved against this exact tree -- skipped." -ForegroundColor DarkGray
            } elseif ($TestsProvedByCi) {
                # THE CI CERTIFICATE, CONSULTED AFTER THE LOCAL RECORD AND BEFORE THE RUN (issue #1715).
                # Second and not first because the local record is free -- it is a file read -- while the
                # certificate cost the caller two `gh` calls it has already paid for by the time we are
                # here. Order changes nothing about the verdict; it keeps the cheaper answer first.
                #
                # NOT RECORDED AS GATE EVIDENCE, deliberately -- and this branch is the one place in the
                # function that writes nothing at all. The record means "this machine proved this tree",
                # so filing a remote green in it would make the certificate look like a local run for the
                # next four hours, including after it stopped applying. It is re-read in seconds on the
                # next run, so there is nothing to cache and no reason to blur what the record means.
                # (The suite asserts the absence, and it also counts the record's writers by name -- which
                # is why this comment does not spell either of them out.)
                Write-Host "test gate: satisfied by CI -- $TestsProvedByCi. Not run again locally (#1715)." -ForegroundColor DarkGray
            } elseif ($gateNoteTree -and $gateNoteTree.Proven) {
                # THE DEDUCTION, THIRD AND NOT FIRST (issue #2102). The local record above is a file read
                # and the CI certificate is already paid for by the time we are here; this one costs a git
                # call, so it goes last among the three. Order changes no verdict -- it keeps the cheaper
                # answer first, which is the reasoning the certificate's own branch states one line up.
                #
                # WHAT IT PRINTS IS THE ARGUMENT, not the conclusion. A skip nobody can audit is a gate
                # nobody can trust, so the line names the bound that was proved and the paths it was proved
                # over -- the same standard -TestsProvedByCi is held to, where the note IS the parameter.
                Write-Host ("test gate: every changed path is inside the release-note tree ({0}) -- so the suites add nothing the lint gate above has not already run (#2102). Not run." -f ($gateNoteTree.Roots -join ', ')) -ForegroundColor DarkGray
                foreach ($p in ($gateNoteTree.Inside | Select-Object -First 8)) {
                    Write-Host ("           proved over: " + (Get-DisplayPath -Path $p)) -ForegroundColor DarkGray
                }
                if ($gateNoteTree.Inside.Count -gt 8) {
                    Write-Host ("           ... and {0} more" -f ($gateNoteTree.Inside.Count - 8)) -ForegroundColor DarkGray
                }
                # NOTHING IS RECORDED, on -SkipTests' own rule one branch down: this run did not measure the
                # suites, so filing evidence would make the NEXT run skip a gate this one never earned. The
                # deduction is re-made in one git call whenever it is asked for again, so there is nothing
                # worth caching and every reason not to blur what the record means.
            } elseif ($gateSelection -and $gateSelection.Proven -and $gateSelection.Suites.Count -lt $gateSelection.PoolCount) {
                # THE SELECTED RUN (issue #3223). What it prints is the argument, as above: how many suites
                # the changes reach, how many run regardless, and who runs the rest.
                $selectedNames = @($gateSelection.Suites | ForEach-Object { ($_ -split '/')[-1] })
                Write-Host ("test gate: {0} of {1} suites selected for this branch's changes -- {2} reached by a changed path, {3} that walk the live tree and always run, {5} whose declared walk scope a changed path falls in. CI ({4}) runs all {1}; -AllSuites runs them here (#3223, #3309)." -f $selectedNames.Count, $gateSelection.PoolCount, $gateSelection.Matched.Count, $gateSelection.Always.Count, $ciCheck, @($gateSelection.Scoped).Count) -ForegroundColor Cyan
                if ($selectedNames.Count -eq 0) {
                    Write-Host "test gate: no suite is affected by these changes -- none run here." -ForegroundColor DarkGray
                } elseif (-not (Invoke-TestSuiteGate -TestsDir (Join-Path $RepoRoot 'scripts\tests') -Context $Context -MaxParallel $MaxParallel -SuiteNames $selectedNames)) {
                    $movedNote = Get-GateTreeMovedNote -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint -HeadMoves $gateHeadMoves -Failed
                    if ($movedNote) { Write-Warning $movedNote }
                    Write-Error "test gate found failing suites - $FailureConsequence. Fix the tests, or run with -SkipTests to skip the gate." -ErrorAction Continue
                    return $false
                }
                # NOTHING IS RECORDED. The evidence means "every suite passed against this tree", and a
                # selected run proved a subset -- filing it would let the next open-pr skip the suites this
                # run never ran, which is the one thing the issue asked this to make impossible.
            } elseif (-not (Invoke-TestSuiteGate -TestsDir (Join-Path $RepoRoot 'scripts\tests') -Context $Context -MaxParallel $MaxParallel)) {
                # THIS IS THE GATE THE MOVEMENT CHECK WAS MEASURED ON (issue #1145). One suite of 55 went red
                # inside a backgrounded ship while prune-merged.ps1 held the trunk in the same checkout, and
                # green standalone on the same commit seconds later. That script no longer takes the checkout
                # (#1147); the check stays, because a red is expensive to disbelieve on a hunch and expensive to
                # believe wrongly, and every other tree-mover in this clone is still there.
                $movedNote = Get-GateTreeMovedNote -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint -HeadMoves $gateHeadMoves -Failed
                if ($movedNote) { Write-Warning $movedNote }
                Write-Error "test gate found failing suites - $FailureConsequence. Fix the tests, or run with -SkipTests to skip the gate." -ErrorAction Continue
                return $false
            } else {
                # Same rule as the lint gate above: recorded only on a real pass, never on -SkipTests -- and
                # never on a pass whose tree moved underneath it.
                $movedNote = Get-GateTreeMovedNote -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint -HeadMoves $gateHeadMoves
                if ($movedNote) {
                    Write-Warning $movedNote
                } else {
                    [void](Save-GateEvidence -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint)
                }
            }
        }

        return $true
    } finally {
        # IN A FINALLY, on ship-pr's own reasoning for its Pop: a gate that fails must not leave the
        # chain above it in a state it did not choose. Both failing branches above `return $false`
        # rather than throwing, so this fires on all three exits.
        if ($gateCanSuspend) { Restore-CloseOutSuppression -WasActive $gateWasSuppressed }
    }
}
