<#
.SYNOPSIS
    The one implementation of parking a branch: stage, commit, push -- no PR, no live action.

.DESCRIPTION
    Dot-source this file from a script in scripts/task/:

        . (Join-Path $PSScriptRoot '..\lib\park-lib.ps1')

    Supplies Invoke-GitPark, which all three parking entry points call: park-branch.ps1 (an existing
    branch, mid-work, everything outstanding), new-branch.ps1 (a branch at creation) and park-cycle.ps1
    (the development document, automatically, for the life of the branch). The first is invoked
    deliberately; the other two run on their own, and Test-GitOriginConfigured below is the one thing
    that distinguishes them -- see its own note.

    AND SINCE #1269 IT SUPPLIES THE COMMIT HALF ON ITS OWN, as Invoke-GitParkCommit -- stage and commit,
    no push. Invoke-GitPark is that function plus the push; open-pr.ps1 is the caller that needs the
    first without the second, because its own push is bounded against the credential-prompt hang (#1179)
    and this file's is not. Read Invoke-GitParkCommit's own note for why that is a shared function rather
    than a second copy of the pathspec.

    WHY ONE OWNER (issue #507, August 7, 2026). The two entry points had a copy each of the same four
    steps, and they had already drifted in the way that matters least to a script and most to a person:
    THEY WROTE THE IDENTICAL COMMIT MESSAGE. Both said `park: <branch> (work parked for later)` while
    committing different things -- new-branch -Park commits ONLY the two branch files, park-branch commits
    everything outstanding. So afterwards the git log could not tell you which half of your work was
    safely on origin, which is the single question a park exists to answer.

    THE MEASUREMENT THAT SHAPED THIS, because it refuted the obvious proposal. Across the whole history
    there are THREE park commits: two from `new-branch -Park` (eb5e0f7, a72cc91) and one from
    `park-branch` (fd2083b). The proposal on the table was "drop -Park, it parks a branch with nothing in
    it yet" -- and two of the three real parks are exactly that case. -Park is the more used of the two.
    Neither was deleted; what was wrong was never that there are two moments to park at, but that the
    record could not tell them apart.

    THE SCOPE AND THE MESSAGE COME FROM ONE DECISION, deliberately. -Scope picks both the pathspec that is
    committed and the words that describe it, so a future caller cannot commit one scope while announcing
    another -- which is the defect this function was written to end, reappearing one level down.

    WHY A NEW LIB RATHER THAN native-capture-lib.ps1, where Invoke-TestSuiteGate went the same week: that
    file's own note says it took an imperfect fit deliberately and asks the next person NOT to widen it
    again ("if a second gate helper ever appears, move both out together"). A park is not a gate, and its
    cost here is one registry entry and one mirror -- no contract row, since nothing in it is repo-owned.

    AND SINCE #960 IT ALSO OWNS WHAT THE COMMIT SAYS IS BEHIND THE PLAN. Get-GitParkBacking measures it,
    Format-GitParkBacking words it, Get-GitParkBackingMarker names the one literal the reader looks for.
    They sit here for the reason the scope map does: the park commit's body is this file's format, so a
    caller cannot stamp a fact in a shape the reader cannot find.

    THAT READER IS A PERSON SINCE #957, and every shape decision below still assumes one. A reporter used
    to find the note in a parked branch's last commit and print it back; it went with /lock and /handover.
    Nothing about the writing side changed -- the note is read with 'git log -1 --pretty=%B origin/<branch>'
    now, which is a git rendering rather than a block inside another script's output, and every constraint
    the shapes were chosen for (the 72-column body, the single paragraph, no hanging indent) is a property
    of that rendering too.

    Self-contained apart from the shared native-capture helper: git only, no repo-owned config, so a
    consumer needs no scaffold for it.

    Every git call goes through Invoke-NativeCapture (EAP=Continue -> run -> record $LASTEXITCODE),
    because git writes progress to stderr, which under EAP=Stop would become a terminating
    NativeCommandError before the exit code could be judged (the #96/#97/#107 pitfall). The commit message
    goes via `git commit -F <file>`, never `-m "...$branch..."`: a branch name may legally carry a `"`,
    which embedded in an -m argument would break native argv reconstruction (the quoting lesson).

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# The porcelain read and its line parse (#1682), which fanout-lib.ps1 dot-sources too -- that shared
# ownership is the whole point of the file. Guarded on fanout-lib's grounds: dot-sourcing twice is
# harmless, and a tree whose mirror predates this lib must not crash on load. Invoke-NativeCapture is
# deliberately NOT dot-sourced here and never has been -- every caller of this lib already supplies it,
# and the porcelain lib guards its own copy the same way.
$parkPorcelainLib = Join-Path $PSScriptRoot 'git-porcelain-lib.ps1'
if (Test-Path -LiteralPath $parkPorcelainLib -PathType Leaf) { . $parkPorcelainLib }

# THE TWO SCOPES, AND WHAT EACH IS CALLED IN THE COMMIT. One map, so the words and the pathspec are the
# same decision -- see the note above. 'Everything' carries no pathspec: git add -A and a bare commit.
$script:GitParkScopes = @{
    Everything = 'all outstanding work'
    BranchFiles = 'the branch files only'
}

function Get-GitParkScopes {
    <# The scope names this function accepts, and the phrase each one puts in the commit subject. Exposed
       so a test can assert the pair rather than re-typing either half. #>
    return $script:GitParkScopes
}

function Test-GitOriginConfigured {
    <#
        Does $RepoRoot have a remote called 'origin' at all? $true / $false, and it asks nothing about
        whether that remote is reachable -- that is the push's answer to give.

        WHY THE AUTOMATIC CALLERS NEED THIS AND THE DELIBERATE ONE DOES NOT (#900, August 26, 2026). A
        repo with no remote is a legitimate repo, and until this was the DEFAULT nobody met the case: you
        asked for a park, so a push failure naming the remote was the right answer to give you. Once
        new-branch pushes on its own, that same failure arrives unasked -- and it would exit 1 out of
        branch CREATION in every remote-less repo, turning "there is nowhere to push" into "your branch
        could not be made". Found by the suite, whose fixtures deliberately configure no remote to assert
        that new-branch stayed local.

        So Invoke-GitPark still REPORTS every failed push and park-branch.ps1 still stops on it. This is
        the question its two automatic callers ask FIRST, and skip on -- so a remote-less repo never
        reaches the push at all. What that report SAYS stopped being one fixed sentence in #1143, for the
        other half of the same shift: see Get-GitPushFailureMessage.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $res = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'remote') -DiscardStderr
    if ($res.ExitCode -ne 0) { return $false }
    return @(($res.Output | Out-String) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq 'origin' }).Count -gt 0
}

# THE FIRST WORD OF THE BACKING NOTE, and the one literal that makes it findable. park-cycle writes the
# note into the commit body and a reader greps for this word in 'git log'. It was the literal BOTH SIDES
# shared until #957: session-status found the note again in a parked branch's last commit and printed it
# back, and a second copy of the word would have been the drift shape where the writer stamps a fact the
# reader never finds, silent on both sides. With the reading side gone the accessor stays, because the
# suites assert against it and a literal spelled twice is the same drift one release later.
$script:GitParkBackingMarker = 'Backing:'

function Get-GitParkBackingMarker {
    <# The lead word of the backing note. Everything from that line to the next blank line is the note. #>
    return $script:GitParkBackingMarker
}

function Get-GitParkBacking {
    <#
        What is actually behind this branch's plan, as an object: files COMMITTED on the branch besides
        $Paths, files UNCOMMITTED in this working copy besides $Paths, and a flag per figure saying
        whether it could be established at all.

        THE PROBLEM THIS EXISTS FOR (issue #960). A park publishes the branch's development document and
        nothing else, by design -- bound 1 of park-cycle. On a branch whose work is uncommitted in
        ANOTHER device's working copy, that means origin carries a plan reading '[x] done' eight times
        over with no commit behind a single tick. From origin, 'ticked and committed' and 'ticked and
        uncommitted elsewhere' are the same document. A session picking it up in good faith either
        rebuilds eight changes that already exist somewhere, or opens a PR that merges 161 lines the fold
        then deletes, delivering nothing.

        SO IT IS MEASURED HERE AND NOWHERE ELSE, on the device that HOLDS the uncommitted work at the
        moment it becomes invisible. No other reader can take this measurement: from origin the files do
        not exist, and by the time somebody wonders, the session that had them is over.

        COUNTS ONLY, NEVER FILENAMES, and that is a bound rather than brevity. The uncommitted figure
        describes work nobody asked to publish; a park commit listing those paths would leak the shape of
        unrelated work onto a public branch, which is bound 1 defeated one layer along.

        THE TRUNK REF IS VERIFIED BEFORE IT IS COMPARED AGAINST, and an absent one reports UNKNOWN rather
        than zero. Zero is an answer -- 'nothing else is committed', the alarming one -- and handing it
        back for 'this checkout has no ref by that name' would raise the alarm on a repo that is merely
        configured differently.

        THE REMOTE-TRACKING REF IS PREFERRED OVER THE BARE LOCAL NAME, when one exists (#1399). $Trunk
        arrives as a bare local branch name ('main'), and the normal flow lets local main sit behind
        origin/main for the length of a branch -- new-branch's own base warning allows exactly that, and
        the documented way to catch up mid-branch is 'git merge origin/main' rather than a rebase, which
        the safety rules block as a force-push. That merge fast-forwards the branch's merge-base with
        LOCAL main to include every commit it just pulled in from origin, because local main itself never
        moved -- so '$Trunk...HEAD' now counts those already-upstream commits as this branch's own
        committed work. A branch with zero real commits of its own then reports Committed > 0, and the
        backing gate that exists to catch an unbacked park goes silent on exactly the case it was built
        for. refs/remotes/origin/$Trunk does not have this problem: a fetch (which 'git merge origin/main'
        requires as its first step) keeps it current with the remote, so it is preferred whenever this
        checkout has one. Checking for it is a local, offline read of what the last fetch already
        recorded -- no network call, matching the docstring's existing offline-friendly claim -- and where
        it does not exist (no origin configured, or origin/main never fetched) this falls back to the bare
        $Trunk name exactly as before. The OBJECT'S Trunk FIELD KEEPS THE ORIGINAL NAME either way: it is
        what Format-GitParkBacking prints in the 'not measured' sentence, and a reader expects that
        sentence to name the trunk ('main'), not the ref this function resolved it to internally.

        core.quotePath IS FORCED ON, and it is the language rule about reading a native command's output
        rather than a preference: the paths here are COMPARED against $Paths, and PowerShell 5.1 decodes
        a child's stdout with whatever console code page the run inherited. Quoting holds the wire to
        ASCII, where every candidate code page agrees, so a filename with an accent cannot decode into
        something that accidentally matches -- or fails to match -- the path being excluded. A repo may
        set core.quotepath in its own config, hence -c rather than trusting the default. It is stated
        here because THIS function still spawns the `git diff` half itself; since #1682 the porcelain
        half inherits the same flag from git-porcelain-lib.ps1, which documents it for both callers.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Trunk,
        [string[]]$Paths = @()
    )

    # Forward slashes both sides: git reports them, a caller may hand back either.
    $skip = @{}
    foreach ($p in $Paths) { if ($p) { $skip[([string]$p -replace '\\', '/')] = $true } }

    $committed = 0
    $committedKnown = $false
    # PREFER THE REMOTE-TRACKING REF (#1399): resolve refs/remotes/origin/$Trunk first, and only fall back
    # to the bare local name when this checkout has no such ref. See the docstring's "THE REMOTE-TRACKING
    # REF IS PREFERRED" section for why the bare name silently over-counts a branch's committed work.
    # THE VERIFY RESULT IS REUSED RATHER THAN ASKED TWICE: a successful check against
    # refs/remotes/origin/$Trunk already proves that ref resolves, so re-verifying it a line later would
    # be a second native `git` process spawned for a question already answered -- and the common case,
    # once this ships, is exactly the one where origin exists and is current.
    $trunkRef = $Trunk
    $remoteRefRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Trunk") -DiscardStderr
    $refRes = if ($remoteRefRes.ExitCode -eq 0) {
        $trunkRef = "refs/remotes/origin/$Trunk"
        $remoteRefRes
    } else {
        Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--verify', '--quiet', $trunkRef) -DiscardStderr
    }
    if ($refRes.ExitCode -eq 0) {
        # THREE DOTS: the branch against its MERGE BASE with the trunk, not against the trunk's tip -- so
        # a trunk that has moved on since the branch was cut does not report its own commits as this
        # branch's work.
        $diffRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-c', 'core.quotePath=true', '-C', $RepoRoot, 'diff', '--name-only', "$trunkRef...HEAD")
        if ($diffRes.ExitCode -eq 0) {
            $committedKnown = $true
            $committed = @(($diffRes.Output | Out-String) -split '\r?\n' |
                ForEach-Object { $_.Trim().Trim('"') } |
                Where-Object { $_ -and -not $skip.ContainsKey($_) }).Count
        }
    }

    $uncommitted = 0
    $uncommittedKnown = $false
    # THE READ AND THE PARSE COME FROM git-porcelain-lib.ps1 (#1682), fanout-lib.ps1's other caller.
    # Both flags and all three lessons live in that file's header, this function's measurement among
    # them; what stays here is what the exclusion does with them.
    #
    # WHY --untracked-files=all MATTERS TO THE EXCLUSION SPECIFICALLY, which is the half the lib cannot
    # state: git's default collapses an untracked DIRECTORY to one entry naming the directory --
    # '?? dkj-policy/' -- so on the very first park of a branch, where the cycle document's folder is
    # itself new, the one path this function is asked to EXCLUDE never appears at all and its parent is
    # counted as unpublished work instead. Caught by the suite on the ordinary happy path: 2 uncommitted
    # files reported where there was 1.
    #
    # ONLY THE COUNT AND THE EXCLUSION ARE THIS FUNCTION'S, and the lib's From field is deliberately
    # ignored: a count follows no file, so a rename is one outstanding path either way. The keys were
    # already forward-slashed on both sides before this change and the lib normalises Path, so the
    # comparison is unchanged.
    $st = Get-GitPorcelainStatus -RepoRoot $RepoRoot
    if ($st.Known) {
        $uncommittedKnown = $true
        foreach ($e in $st.Entries) {
            if ($skip.ContainsKey($e.Path)) { continue }
            $uncommitted++
        }
    }

    return [pscustomobject]@{
        Committed        = $committed
        CommittedKnown   = $committedKnown
        Uncommitted      = $uncommitted
        UncommittedKnown = $uncommittedKnown
        Trunk            = $Trunk
    }
}

function Get-BranchMachineLocalFindings {
    <#
        Which of $MachineLocalPaths appear in this branch's COMMITTED diff against its merge base with
        the trunk -- as an object: Paths (the matches, sorted-unique) and Known (whether the diff could
        be read at all).

        THE PROBLEM THIS EXISTS FOR (issue #1559). A tracked file a person edited for their own clone
        -- .claude/settings.json with extra plugins enabled locally -- rides into a branch commit on a
        `git add -A` and past every gate: measured on PR #1557, where it reached the merge queue. The
        development-document gates (scaffold, step-list, impact, link) never read the diff's file set;
        the backing gate reads the diff but asks the opposite question -- work MISSING from the commit,
        not surplus in it. open-pr.ps1 turns this list into an advisory note before the push.

        THREE DOTS, like Get-GitParkBacking: the branch against its MERGE BASE with the trunk, so a
        trunk that moved on since the branch was cut does not put its own touched files in this list.

        THE REMOTE-TRACKING REF IS PREFERRED over the bare local name, the same #1399 reason
        Get-GitParkBacking gives: a bare `main` that has fallen behind origin/main, then caught up via
        `git merge origin/main` (the documented, non-force way), makes `$Trunk...HEAD` include commits
        that are already upstream. refs/remotes/origin/$Trunk is advanced by that merge's own fetch, so
        it lands on the branch's real diff. A six-line copy of that resolution rather than a shared
        helper, deliberately: extracting it would touch Get-GitParkBacking, which is the backing gate.

        core.quotePath IS FORCED ON, the language rule about reading a native command's output: the
        paths here are COMPARED against $MachineLocalPaths, and PowerShell 5.1 decodes a child's stdout
        with whatever console code page the run inherited. Quoting holds the wire to ASCII, where every
        candidate code page agrees, so an accented filename cannot decode into something that
        accidentally matches -- or misses -- a path being watched.

        AN UNREADABLE DIFF IS Known = $false, NEVER an empty Paths that reads as "all clear" -- same
        degrade-to-cannot-answer rule as every lookup in this file. A repo that defines no machine-local
        paths gets Known = $true and Paths = @(): there is nothing to check, which is an answer.

        A TRAILING '/' on an entry matches a whole directory; anything else is an exact path match.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Trunk,
        [string[]]$MachineLocalPaths = @()
    )

    # Forward slashes throughout: git reports them, a caller may hand back either. Split the specs into
    # exact-match keys and directory prefixes (the entries ending '/').
    $exact = @{}
    $dirs  = @()
    foreach ($p in $MachineLocalPaths) {
        if (-not $p) { continue }
        $norm = ([string]$p -replace '\\', '/').Trim()
        if (-not $norm) { continue }
        if ($norm.EndsWith('/')) { $dirs += $norm } else { $exact[$norm] = $true }
    }
    if ($exact.Count -eq 0 -and $dirs.Count -eq 0) {
        return [pscustomobject]@{ Paths = @(); Known = $true }
    }

    # PREFER THE REMOTE-TRACKING REF (#1399); fall back to the bare local name only where this checkout
    # has no such ref. The successful verify is reused rather than asked twice.
    $trunkRef = $Trunk
    $remoteRefRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Trunk") -DiscardStderr
    $refRes = if ($remoteRefRes.ExitCode -eq 0) {
        $trunkRef = "refs/remotes/origin/$Trunk"
        $remoteRefRes
    } else {
        Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--verify', '--quiet', $trunkRef) -DiscardStderr
    }
    if ($refRes.ExitCode -ne 0) {
        return [pscustomobject]@{ Paths = @(); Known = $false }
    }

    $diffRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-c', 'core.quotePath=true', '-C', $RepoRoot, 'diff', '--name-only', "$trunkRef...HEAD")
    if ($diffRes.ExitCode -ne 0) {
        return [pscustomobject]@{ Paths = @(); Known = $false }
    }

    $hits = @{}
    foreach ($line in (($diffRes.Output | Out-String) -split '\r?\n')) {
        $path = $line.Trim().Trim('"') -replace '\\', '/'
        if (-not $path) { continue }
        if ($exact.ContainsKey($path)) { $hits[$path] = $true; continue }
        foreach ($d in $dirs) {
            if ($path.StartsWith($d)) { $hits[$path] = $true; break }
        }
    }

    return [pscustomobject]@{
        Paths = @($hits.Keys | Sort-Object)
        Known = $true
    }
}

function Split-GitParkBackingLines {
    <#
        Word-wraps one sentence to commit-body width, as an array of lines. No hanging indent, no
        hyphenation, and a word longer than the width gets its own line rather than being broken -- a
        broken path or branch name is worse than a long line.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        # 72, THE COMMIT-BODY CONVENTION, AND IT WAS LOAD-BEARING FOR A SECOND READER TOO. session-status
        # printed this note indented six spaces inside its parked-branches block; at 78 the result is 84
        # columns, which an 80-column console reflows -- and a reflowed note breaks mid-word, since the
        # indent is not repeated. 72 + 6 fits. That reporter went with /lock and /handover (#957), so only
        # the git convention is left holding the number -- which is the half that never depended on it.
        [int]$Width = 72
    )
    $out = @()
    $current = ''
    foreach ($word in ($Text -split '\s+' | Where-Object { $_ })) {
        if (-not $current) { $current = $word }
        elseif (($current.Length + 1 + $word.Length) -le $Width) { $current = "$current $word" }
        else { $out += $current; $current = $word }
    }
    if ($current) { $out += $current }
    return $out
}

function Get-BranchBackingFinding {
    <#
        Pure: is this a plan that CLAIMS to be finished with no work on the branch behind it, and if so
        which of the two shapes -- as an object, or $null when there is nothing to say.

        Kind is 'UncommittedHere' when the work is sitting uncommitted in THIS working copy, and
        'NotInThisCheckout' when nothing is uncommitted here either. They are different faults and their
        two callers answer them differently: the park note describes both, while open-pr's backing gate
        REFUSES the first -- this session's own omission, one command from repaired -- and only warns on
        the second, which cannot be told apart from a branch legitimately shipping its entry alone, and
        where refusing would wedge the cross-device flow #960 exists to serve.

        WHY IT IS A FUNCTION AND NOT TWO INLINE TESTS (issue #1026). The condition was written once for
        Format-GitParkBacking's alarm; open-pr's gate needs exactly the same question answered, and a
        second spelling of it is the drift shape this repo keeps paying for -- a park that alarms and a
        gate that does not, over one tree, with nothing to say which is right.

        WHY IT IS THAT NARROW. 'Any resolved step with no commit behind it' would fire on nearly every
        early branch: a planning step ticked before a line of code exists is the ordinary case, and a
        warning that fires almost always is one nobody reads by the time it matters. Open == 0 with
        Resolved > 0 is a plan claiming completeness, and it is rare.

        AN UNMEASURED COMMITTED FIGURE IS NOT A FINDING. 'not measured' and '0' are different claims, and
        raising the alarm on the first would fire it on a checkout that merely has no trunk ref.

        -Steps IS DUCK-TYPED, like Format-GitParkBacking's: any object carrying Open, Resolved and Total.
    #>
    param(
        [Parameter(Mandatory)]$Steps,
        [Parameter(Mandatory)]$Backing
    )

    $total    = [int]$Steps.Total
    $open     = [int]$Steps.Open
    $resolved = [int]$Steps.Resolved

    if (-not ($total -gt 0 -and $open -eq 0 -and $resolved -gt 0)) { return $null }
    if (-not ($Backing.CommittedKnown -and [int]$Backing.Committed -eq 0)) { return $null }

    $uncommitted = if ($Backing.UncommittedKnown) { [int]$Backing.Uncommitted } else { 0 }
    return [pscustomobject]@{
        Kind        = if ($uncommitted -gt 0) { 'UncommittedHere' } else { 'NotInThisCheckout' }
        Total       = $total
        Resolved    = $resolved
        Uncommitted = $uncommitted
    }
}

function Format-GitParkBacking {
    <#
        The backing note as commit-body text: one 'Backing:' sentence always, plus an alarm paragraph
        when -- and only when -- the plan reads as FINISHED with nothing behind it.

        WHY THE ALARM IS THAT NARROW. 'Any resolved step with no commit behind it' would fire on nearly
        every early park: a planning step ticked before a line of code exists is the ordinary case, and a
        warning that fires on almost every park is one nobody reads by the time it matters. Open == 0 and
        Resolved > 0 is the shape #960 was measured on -- a plan that CLAIMS to be complete -- and it is
        rare. Every other case still gets the numbers, which is what a reader needs to judge it.

        -Steps IS DUCK-TYPED ON PURPOSE: any object carrying Open, Resolved and Total. This lib is
        self-contained apart from the shared native-capture helper, and Get-BranchProgressTally lives in
        entry-scaffold-lib -- which knows the document format, and which a park has no other reason to
        load. The caller that already has both hands one to the other.

        AN UNMEASURED FIGURE SAYS SO. 'not measured' and '0' are different claims, and printing the
        second for the first is how a report gets trusted for something it never established.
    #>
    param(
        [Parameter(Mandatory)]$Steps,
        [Parameter(Mandatory)]$Backing
    )

    $total    = [int]$Steps.Total
    $open     = [int]$Steps.Open
    $resolved = [int]$Steps.Resolved

    $stepClause = if ($total -eq 0) {
        'no steps written yet'
    } else {
        "$resolved of $total step(s) resolved"
    }
    $committedClause = if (-not $Backing.CommittedKnown) {
        "what else is committed: not measured (no '$($Backing.Trunk)' ref in this checkout)"
    } elseif ([int]$Backing.Committed -eq 0) {
        'nothing else committed on this branch'
    } else {
        "$([int]$Backing.Committed) file(s) committed besides this document"
    }
    $uncommittedClause = if (-not $Backing.UncommittedKnown) {
        'uncommitted work here: not measured'
    } elseif ([int]$Backing.Uncommitted -eq 0) {
        'nothing uncommitted in the working copy this park came from'
    } else {
        "$([int]$Backing.Uncommitted) file(s) uncommitted in the working copy this park came from"
    }

    # WRAPPED, because this is a commit body and a git log renders it as written. Unwrapped it ran to 143
    # characters in the case it was measured on, which every `git log` view truncates or reflows -- and
    # the clause most likely to fall off the end is the last one, the uncommitted count that carries the
    # whole point. No hanging indent: a reader takes the note from its marker to the next BLANK line, so
    # an indented continuation reads as a quote -- and did print with the indent doubled while #957's
    # reporter was the one doing the taking.
    $lines = @(Split-GitParkBackingLines -Text "$($script:GitParkBackingMarker) $stepClause; $committedClause; $uncommittedClause.")

    # THE CONDITION IS ASKED OF Get-BranchBackingFinding, NOT RESTATED HERE (issue #1026). open-pr's
    # backing gate needs the identical question answered, and two spellings of it over one tree is how a
    # park that alarms and a gate that stays silent end up disagreeing with nothing to say which is right.
    $finding = Get-BranchBackingFinding -Steps $Steps -Backing $Backing
    if ($finding) {
        $alarm = 'This plan reads as FINISHED and no work behind it is on origin. '
        $alarm += if ($finding.Kind -eq 'UncommittedHere') {
            'That work is uncommitted in the working copy this park came from -- it is not missing. ' +
            'Do NOT rebuild it, and do not open a PR that would merge this document alone: ask that ' +
            'checkout to commit and push first.'
        } else {
            'And nothing is uncommitted here either, so the work this plan describes is not in this ' +
            'checkout at all. Establish where it is before rebuilding any of it.'
        }
        # WRAPPED THE SAME WAY AS THE LINE ABOVE, through the same helper, so the width is one decision.
        # It is one paragraph with the marker line, deliberately: a reader stops at the first blank line,
        # and an alarm in a paragraph of its own is the half that gets dropped. Measured against a reader
        # that did exactly that in code (session-status, gone with /lock and /handover in #957); the same
        # is true of anyone skimming a 'git log' body.
        $lines += Split-GitParkBackingLines -Text $alarm
    }
    return ($lines -join "`n")
}

function Get-GitPushFailureMessage {
    <#
        The one sentence Invoke-GitPark writes over a failed `git push`, CHOSEN FROM WHAT GIT SAID rather
        than asserting a single cause (issue #1143, August 30, 2026). $Output is the push's own captured
        output: Invoke-NativeCapture is called there WITHOUT -DiscardStderr, so git's own diagnosis is in
        it and on the screen already -- what was wrong was only the summary sitting underneath it.

        WHY IT STOPPED BEING ONE SENTENCE. `park: git push failed (is 'origin' configured and reachable?)`
        was the right question while park-branch.ps1 was the only caller: you had ASKED for a park, so the
        interesting failure was that there was nowhere to push to. Since #900 the push is what new-branch
        does on every branch creation and what cycle-autopark does on every Stop, so the common failure is
        now a NON-FAST-FORWARD against a branch that is already on origin -- and a reader who trusts the
        summary over the raw text above it (which is what a summary is for) goes and checks `git remote -v`
        for nothing. park-branch.tests.ps1 section (d3) stages exactly that push and holds this function to
        it; before this change both of its end-to-end asserts were red.

        THE LAST ARM NAMES NO CAUSE ON PURPOSE. Where neither shape matches, the run does not know why the
        push failed, and pointing at the output it has already printed is worth more than a guess that
        reads as a finding.

        Exposed rather than inlined so a test can assert the three arms from their text, instead of having
        to stage three different remote failures -- the same reason Get-GitParkScopes is a function.
    #>
    param([string]$Output)

    # -match, NOT -like: '[rejected]' is a character class to BOTH operators, so the brackets have to be
    # escaped either way, and a regex is the form that can carry the alternation as well. 'fetch first' is
    # git's own advice line on the same rejection, kept so the hint alone is still recognised.
    if ($Output -match '\[rejected\]|non-fast-forward|fetch first') {
        return "park: git push was rejected -- origin already has commits this branch does not (see the '[rejected]' line above). Bring the branch up to date first (git pull --rebase), then park again."
    }

    # There is nowhere to push TO -- the question the old single sentence asked. Test-GitOriginConfigured
    # answers the 'no remote at all' half before either automatic caller reaches a push, so what arrives
    # here is a remote that is named but unusable: gone, renamed, offline, or refusing this account.
    if ($Output -match 'does not appear to be a git repository|Could not read from remote repository|Repository not found|Permission denied|Authentication failed|unable to access') {
        return "park: git push failed -- origin could not be reached (see git's message above). Check the remote and your access to it."
    }

    return "park: git push failed -- git's own output is above."
}

function Invoke-GitParkCommit {
    <#
        The stage-and-commit half of a park, WITHOUT the push: stages what $Scope says and commits it when
        there is something staged. Returns an object -- Ok (every git call succeeded) and Committed (a
        commit was actually made) -- so a caller can tell "nothing to do" from "it failed", which a bare
        bool cannot.

        NOTHING TO COMMIT IS NOT A FAILURE. A branch whose files were already committed locally but never
        pushed is the real-world case park exists for (issue #175): the commit is skipped, Ok stays $true
        and Committed comes back $false.

        THE PATHSPEC IS NAMED, NOT SWEPT, in the BranchFiles scope -- so anything the caller had already
        staged for their own next commit stays staged and uncommitted rather than riding along.

        -Intent AND -BodyNote ARE BOTH COMMIT BODY AND ARE DELIBERATELY TWO PARAMETERS. -Intent is a
        person's parking note: where they left off, in their words. -BodyNote is a fact the script
        measured -- today the backing note above (#960). Folding the second through the first would make
        the log unable to say which half a human wrote, which is the same class of defect this whole lib
        was extracted to end: one field describing two different things. Intent first where both are
        given, because a reader's own words outrank a generated line.

        WHY IT IS A FUNCTION OF ITS OWN (issue #1269, September 3, 2026). open-pr.ps1 needs exactly these
        steps and NOT the push: its own push is bounded against the credential-prompt hang (#1179), and
        reusing Invoke-GitPark below would put an unbounded network call three lines in front of the
        bounded one. A second copy of the staging dance was the alternative, and a second copy of a git
        pathspec is the drift shape this lib was extracted to end.

        -Continuation IS THE CLAUSE THE TWO "nothing to do" LINES END WITH, and it exists because the
        sentence is only half this function's to write. 'pushing the existing commits as-is' is true for
        Invoke-GitPark and a lie for a caller that does not push, so the PUSHER supplies it and the
        default says only what this function actually did. It reads as a parameter with one caller,
        because it is: open-pr asks whether there is anything to commit BEFORE calling, so it never
        reaches either line -- the word 'park' means nothing in that script and the line would print on
        almost every run of it. That is a reason for the default to stay honest rather than a reason to
        hard-code the pusher's clause: the next caller that does not push gets the truthful line without
        having to discover this one.

        -ErrorAction Continue ON BOTH FAILURE MESSAGES, and it is the same lesson gate-lib.ps1's
        Invoke-WorkflowGates records: every caller here runs under $ErrorActionPreference = 'Stop', where
        Write-Error TERMINATES. That was harmless while this code sat inline in a function returning a
        bare bool the callers only ever used to `exit`; it is a lie in a function that promises an object,
        because the return would be dead code and the caller's own message would never print. It also
        breaks park-cycle.ps1's documented "ALWAYS EXITS 0" contract -- it runs on a Stop hook, and a
        terminating error there is a hook that interrupts the work it was added to protect. So the message
        is emitted non-terminating and the CALLER decides what a failure costs.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Branch,
        [ValidateSet('Everything', 'BranchFiles')][string]$Scope = 'Everything',
        [string[]]$Paths = @(),
        [string]$Intent = '',
        [string]$BodyNote = '',
        [string]$Continuation = ''
    )

    # One composer for both "nothing to do" lines, so the caller's clause cannot be attached to one and
    # forgotten on the other.
    $tail = if ($Continuation.Trim()) { " -- $($Continuation.Trim())." } else { "." }

    $pathArgs = @()
    if ($Scope -eq 'BranchFiles') {
        # Only paths that exist: a branch parked before one of its files was written would otherwise fail
        # on a pathspec git cannot resolve.
        $pathArgs = @($Paths | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $RepoRoot $_)) })
        if ($pathArgs.Count -eq 0) {
            Write-Host "park: nothing to stage in this scope$tail" -ForegroundColor Yellow
        }
    }

    if ($Scope -eq 'Everything') {
        $addRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'add', '-A')
    } elseif ($pathArgs.Count -gt 0) {
        $addRes = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $RepoRoot, 'add', '--') + $pathArgs)
    } else {
        $addRes = $null
    }
    if ($addRes) {
        $addRes.Output | ForEach-Object { Write-Host $_ }
        if ($addRes.ExitCode -ne 0) {
            Write-Error "park: staging failed." -ErrorAction Continue
            return [pscustomobject]@{ Ok = $false; Committed = $false }
        }
    }

    # `git diff --cached --quiet` exits 0 when nothing is staged and 1 when there is -- so this asks
    # whether there is anything to commit, scoped exactly as the staging above was.
    $diffArgs = @('-C', $RepoRoot, 'diff', '--cached', '--quiet')
    if ($pathArgs.Count -gt 0) { $diffArgs += @('--') + $pathArgs }
    $diffRes = Invoke-NativeCapture -FilePath 'git' -Arguments $diffArgs

    if ($diffRes.ExitCode -eq 0) {
        Write-Host "park: nothing new to commit$tail" -ForegroundColor Yellow
        return [pscustomobject]@{ Ok = $true; Committed = $false }
    }

    $msg = "park: $Branch ($($script:GitParkScopes[$Scope]))"
    if ($Intent.Trim()) { $msg = "$msg`n`n$($Intent.Trim())" }
    if ($BodyNote.Trim()) { $msg = "$msg`n`n$($BodyNote.Trim())" }
    $msgFile = New-ScratchPath -Label 'git-park-msg' -Extension '.txt'
    [System.IO.File]::WriteAllText($msgFile, $msg, (New-Object System.Text.UTF8Encoding $false))
    try {
        $commitArgs = @('-C', $RepoRoot, 'commit', '-F', $msgFile)
        if ($pathArgs.Count -gt 0) { $commitArgs += @('--') + $pathArgs }
        $commitRes = Invoke-NativeCapture -FilePath 'git' -Arguments $commitArgs
        $commitRes.Output | ForEach-Object { Write-Host $_ }
        if ($commitRes.ExitCode -ne 0) {
            Write-Error "park: committing failed." -ErrorAction Continue
            return [pscustomobject]@{ Ok = $false; Committed = $false }
        }
    } finally {
        Remove-Item -Path $msgFile -Force -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{ Ok = $true; Committed = $true }
}

function Invoke-GitPark {
    <#
        Parks $Branch: stages what $Scope says, commits it when there is something staged, and pushes with
        `git push -u`. Returns $true on success, $false with a message written by the caller's own
        Write-Error -- the caller owns the exit code, because the two entry points differ in what a
        failure means (park-branch stops; new-branch has already created the branch and the files).

        THE STAGE-AND-COMMIT HALF IS Invoke-GitParkCommit ABOVE since #1269, and every parameter here is
        passed straight through to it -- so the scope still picks both the pathspec and the words, and the
        two halves cannot describe one commit differently. This function owns the push and the sentence
        that mentions it.

        -ErrorAction Continue ON THE PUSH FAILURE MESSAGE, for the reason Invoke-GitParkCommit records
        above and issue #1275 measured on all three of these messages before the split: every caller runs
        under $ErrorActionPreference = 'Stop', where Write-Error TERMINATES. Left terminating, the
        `return $false` below is dead code, the caller's `if (-not $ok)` arm never runs, park-cycle.ps1
        exits non-zero on the ordinary divergence case -- breaking its documented "ALWAYS EXITS 0"
        contract on a Stop hook -- and park-branch.ps1 emits the Get-GitPushFailureMessage sentence as a
        raw error record instead of letting its own `if (-not $ok) { exit 1 }` report it. The message is
        non-terminating and the CALLER decides what a red costs. Two of that issue's three messages moved
        into the extracted half above; this is the third.

        -NoFailureMessage IS FOR THE CALLER THAT SAYS IT BETTER (issue #1600). park-cycle.ps1 runs on a
        Stop hook, and since #1600 its failure arm fetches the ref and names the OTHER SESSION on the far
        side of a refused push -- count, author and subject -- which is strictly more than the sentence
        here can know. The hook now also merges the child's stderr into what it prints, so leaving both in
        puts a seven-line PowerShell error banner directly above that report, in a hook whose whole
        contract is that it never fails. The message this suppresses is a REPORT, never the verdict:
        `return $false` is unchanged, so a caller that passes this still learns the push failed and still
        decides what it costs. park-branch.ps1 does not pass it and is byte-for-byte unaffected -- there
        the sentence IS the report, and the run stops on it.

        -PushTimeoutSeconds IS FOR THE CALLER RUNNING UNDER A HOOK'S CEILING (issue #1958). The push below
        is bounded by the shared per-call network number, which is TWICE the whole budget the Stop hook
        that drives park-cycle.ps1 has -- so this one call could legitimately outrun the hook and be
        killed from outside, taking every fail-safe arm and every printed line with it. The caller that
        knows it is on a clock passes what its budget has left; 0 (the default) keeps the shared number,
        so park-branch.ps1 and new-branch.ps1 are byte-for-byte unaffected. Named for what it bounds
        rather than 'Budget', because this function makes exactly one network call and a per-call number
        is the honest thing to hand it -- the deadline arithmetic belongs to the run that HAS the deadline.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Branch,
        [ValidateSet('Everything', 'BranchFiles')][string]$Scope = 'Everything',
        [string[]]$Paths = @(),
        [string]$Intent = '',
        [string]$BodyNote = '',
        [switch]$NoFailureMessage,
        [int]$PushTimeoutSeconds = 0
    )

    $commit = Invoke-GitParkCommit -RepoRoot $RepoRoot -Branch $Branch -Scope $Scope -Paths $Paths `
                                   -Intent $Intent -BodyNote $BodyNote `
                                   -Continuation 'pushing the existing commits as-is'
    if (-not $commit.Ok) { return $false }

    # Push + set upstream tracking, so the branch is reachable (and continuable) from another device.
    # No PR: push != PR (the PR rule stays intact and separate).
    #
    # BOUNDED BY THE SHARED NETWORK TIMEOUT (issue #1641). This was the one git call in this family that
    # reached the network unbounded, while native-capture-lib's own header names the three that are not --
    # open-pr's push, ship-pr's fetch, the fold's push -- and park-cycle.ps1's failure-path fetch passes
    # the same number a few lines further on. THE ASYMMETRY MATTERED MOST HERE: this function is what the
    # cycle-autopark Stop hook drives, so a stall on a credential prompt nothing can answer hangs a turn,
    # every turn, in the one caller where no operator is watching a prompt to Ctrl-C.
    #
    # THE OUTPUT'S SHAPE CHANGES WITH THE BOUND and both readers below are safe on it: -TimeoutSeconds
    # routes into the Start-Process arm, which returns an ARRAY OF STRINGS rather than the & operator's
    # objects. The Write-Host loop is indifferent, and Get-GitPushFailureMessage is handed
    # ($pushRes.Output | Out-String) -- already flattened, for the array reason the comment below gives.
    # stderr stays merged (no -DiscardStderr), because git's own words are the answer here (#1143).
    #
    # AND THE NUMBER IS THE CALLER'S WHERE THE CALLER IS ON A CLOCK (#1958). 0 means "use the shared one",
    # which is every caller but park-cycle.ps1 under its Stop hook -- see -PushTimeoutSeconds above.
    $pushBound = if ($PushTimeoutSeconds -gt 0) { $PushTimeoutSeconds } else { $NativeCaptureNetworkTimeoutSeconds }
    $pushRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'push', '-u', 'origin', $Branch) `
                                    -TimeoutSeconds $pushBound
    $pushRes.Output | ForEach-Object { Write-Host $_ }
    if ($pushRes.ExitCode -ne 0) {
        # Flattened before it is matched: with stderr merged in (2>&1) the captured output is an ARRAY that
        # can hold ErrorRecords as well as strings, and -match against an array returns the matching
        # elements rather than a boolean -- which an if() then reads as true for any non-empty result.
        if (-not $NoFailureMessage) {
            Write-Error (Get-GitPushFailureMessage -Output ($pushRes.Output | Out-String)) -ErrorAction Continue
        }
        return $false
    }

    Write-Host "Branch '$Branch' parked on origin -- $($script:GitParkScopes[$Scope]) (pushed, no PR)." -ForegroundColor Green
    return $true
}
