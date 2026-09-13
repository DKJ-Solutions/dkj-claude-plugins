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
# open-pr.ps1 reaches Invoke-WorkflowGates on its -GatesOnly path several hundred lines BEFORE it
# dot-sources closeout-lib itself, so a caller-supplied dependency would leave exactly one of the two
# gate call sites silently uncovered -- and silently is how #1910 got there in the first place.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')
$gateCloseoutLib = Join-Path $PSScriptRoot 'closeout-lib.ps1'
if (Test-Path -LiteralPath $gateCloseoutLib -PathType Leaf) { . $gateCloseoutLib }

# How long a recorded pass is allowed to stand in for a fresh run. Not a content property -- the
# fingerprint already covers content exactly -- but a bound on the environment drifting underneath
# it. Four hours comfortably covers the measured case (open-pr and ship-pr minutes apart) while
# refusing to let yesterday's green decide today's push. A constant rather than a parameter, so it
# cannot become another knob somebody sets to skip a gate.
$script:GateEvidenceMaxAgeMinutes = 240

# The recognised gate names. A typo in a caller would otherwise record evidence nothing ever reads,
# which fails in the worst direction: silently, as a gate that keeps running.
$script:GateEvidenceKnownGates = @('lint', 'tests')

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

    $joined = ($parts -join "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
        $hash = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
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
        gate. ref-print-lib.ps1 is dot-sourced at the top of THIS file rather than asked of the
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
        [pscustomobject] Certified (bool), Note (string).
    #>
    param(
        [string]$HeadSha,
        [string]$PrHeadSha,
        [string]$RequiredChecksJson,
        [string]$CheckName
    )

    $refuse = { param([string]$Why) [pscustomobject]@{ Certified = $false; Note = $Why } }
    # Eight characters is what git itself abbreviates to here, and a reader asked to compare two
    # 40-character hashes by eye is being asked to do the job this line exists to have done for them.
    $short = { param([string]$Sha) $Sha.Substring(0, [Math]::Min(8, $Sha.Length)) }

    $wanted = Get-DisplayRef -Ref $CheckName
    if (-not $wanted) { return (& $refuse 'this repo has not named the check that proves its test suites (Get-CiTestCheckName)') }

    $head = ([string]$HeadSha).Trim()
    $prHead = ([string]$PrHeadSha).Trim()
    if (-not $head)   { return (& $refuse 'no local HEAD to compare') }
    if (-not $prHead) { return (& $refuse 'no PR head to compare -- nothing has been certified yet') }
    if ($head -ne $prHead) {
        return (& $refuse ("the PR head ({0}) is not this HEAD ({1}) -- the certificate is about a different commit" -f (& $short $prHead), (& $short $head)))
    }

    if (-not $RequiredChecksJson -or -not $RequiredChecksJson.Trim()) {
        return (& $refuse 'the required checks could not be read')
    }
    try { $parsed = $RequiredChecksJson | ConvertFrom-Json } catch {
        return (& $refuse 'the required checks could not be parsed')
    }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object, the
    # same trap Get-RequiredCheckContexts and Get-MergeQueueVerdict each document beside their parse.
    $records = @(@($parsed) | Where-Object { $_ -and $_.PSObject.Properties['name'] })
    if ($records.Count -eq 0) {
        return (& $refuse ("'{0}' has not registered on this commit yet -- no required check has" -f $wanted))
    }

    # SANITISED BEFORE IT IS COMPARED, not only before it is printed. The comparison has to be made on
    # the same string the reader is shown, or a name carrying a zero-width character could match here
    # and print as something else -- or, worse, fail to match while the printed line says it should.
    $named = @($records | Where-Object { (Get-DisplayRef -Ref ([string]$_.name)) -eq $wanted })
    if ($named.Count -eq 0) {
        $present = @(@($records | ForEach-Object { Get-DisplayRef -Ref ([string]$_.name) }) | Sort-Object -Unique)
        return (& $refuse ("'{0}' is not among this trunk's required checks on this commit (found: {1})" -f $wanted, ($present -join ', ')))
    }

    $notPassing = @($named | Where-Object {
        $bucket = if ($_.PSObject.Properties['bucket']) { ([string]$_.bucket).Trim().ToLowerInvariant() } else { '' }
        $bucket -ne 'pass'
    })
    if ($notPassing.Count -gt 0) {
        return (& $refuse ("'{0}' is not green on this commit" -f $wanted))
    }

    return [pscustomobject]@{
        Certified = $true
        Note      = ("{0} green on this exact commit ({1})" -f $wanted, (& $short $head))
    }
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
        [string]$TestsProvedByCi = ''
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
                    $lintRun = Start-Process -FilePath 'powershell' `
                        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $lintPath + '"')) `
                        -NoNewWindow -Wait -PassThru -WorkingDirectory (Get-Location).Path
                    $lintStopwatch.Stop()
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
            if (Test-GateEvidence -RepoRoot $RepoRoot -Gate 'tests' -Fingerprint $gateFingerprint) {
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
