<#
.SYNOPSIS
    The last fetch attempt per remote -- what was asked for and how it went -- so a remote that has
    just been found unreachable is not waited out a second time seconds later.

.DESCRIPTION
    THE MEASUREMENT THIS EXISTS FOR (issue #1860, September 11, 2026). The opening of an
    issue-driven assignment runs two scripts in a row, by design: claim-issue.ps1 claims the issue
    and new-branch.ps1 cuts the branch, with nothing between them but reading the issue. Since
    #1853 the first runs `git fetch --quiet` for its parked-fix scan, and the second has always run
    `git fetch origin --quiet` inside Get-TrunkGap. In a one-remote checkout those are the identical
    call: ~666ms each (five warm samples, 550-914ms), against ~28ms for the `git log` the scan
    actually spends it on.

    AND ONLY ONE OF THE TWO HALVES OF THAT REPORT IS REPAIRED HERE, DELIBERATELY. #1860 named a
    duplicated ~700ms and a doubled worst case: both calls are independently bounded at
    $NativeCaptureNetworkTimeoutSeconds (#1639), so an unreachable remote stalls the opening of an
    assignment for up to twice that, and a session that never starts prints nothing to say why. This
    lib fixes the second and leaves the first alone.

    WHY THE ~700ms IS LEFT ON THE TABLE, WHICH IS THE WHOLE DESIGN. The obvious seam is symmetric:
    remember that origin was fetched N seconds ago and let the second caller skip either way. It was
    built that way first, and this repo's own suite refused it -- new-branch.tests.ps1 case (y1), the
    #1439 collision, plus the #1139 parked-branch case. Both reproduce two runs seconds apart with
    another session's push in between, which is exactly the interval a freshness window covers, and
    exactly the event these probes exist to see. A success-skip therefore buys 700ms by blinding the
    two checks whose entire subject is a push somebody else has just made -- the same trade #1853's
    own review refused when it declined to drop the fetch altogether.

    A FAILURE-SKIP TRADES NOTHING, and that asymmetry is the reason this shape is not a compromise.
    A fetch that failed refreshed no ref, so reporting it instead of repeating it removes no
    information from any later check; what it removes is a second two-minute wait against a remote
    that was unreachable seconds ago. The only thing given up is the case where the remote recovered
    inside the window, which is what bounds the window rather than what argues against it.

    AND IT IS THE FAILED ATTEMPT THAT HAS TO BE REMEMBERED, NOT THE SUCCESSFUL ONE. A fetch that
    TIMES OUT never writes FETCH_HEAD -- so the tempting "skip if FETCH_HEAD is young" implementation
    leaves the doubled ceiling exactly where it was, while silently taking on the correctness cost
    above. The record is of the ATTEMPT, which is the half FETCH_HEAD cannot carry.

    TWO THINGS IT MUST NOT GET WRONG, each of which would fail quietly:

      1. SCOPE. `git fetch origin <trunk>` is not `git fetch origin`, and a narrow fetch can fail for
         a reason that says nothing about a wide one -- "couldn't find remote ref main" is about that
         ref, not about reachability. So a record carries WHICH fetch it was, and coverage is
         one-directional: a failure of the wide fetch answers for a narrow request, never the
         reverse. Get-TrunkGap narrows to the trunk for the fold and widens for new-branch (#1416),
         so both shapes really do occur.

      2. THE REMOTE'S IDENTITY. claim-issue fetches the DEFAULT remote (no remote argument);
         Get-TrunkGap fetches 'origin' by name. In a checkout whose default remote is not 'origin'
         those are different calls, and #1860's own "Not measured" section says so. The record is
         keyed on the RESOLVED remote name, so such a repo matches nothing and skips nothing -- the
         premise never has to hold there, rather than being assumed to.

    THE STATE LIVES IN THE GIT COMMON DIRECTORY, which is where it differs from gate-lib.ps1's
    otherwise identical arrangement. That lib records per-worktree, correctly: a gate judges a
    working tree, and a lane has its own. What is recorded here is whether a REMOTE answered, which
    is a property of the clone and not of any one tree -- so --git-common-dir is the scope that says
    so. Guaranteed present, guaranteed local, guaranteed never committed.

    RECORDING IS A FACT; SKIPPING IS A POLICY. Every call through here records what its fetch did,
    whether or not the caller asked to be allowed to skip -- the record costs one small write and is
    true regardless. Only a caller that passes -RecentFailureSeconds may itself be let off, which is
    what keeps this away from the fold, whose fetch backs a REFUSAL rather than an advisory warning.

    NO DEPENDENCIES OF ITS OWN, on ref-print-lib.ps1's precedent -- it is a leaf, which is what makes
    it safe for entry-scaffold-lib.ps1 to load first. Invoke-NativeCapture is the caller's to supply,
    exactly as Get-TrunkGap has always assumed it.

    Pure ASCII (repo convention for .ps1).
#>

# HOW LONG A FAILED ATTEMPT STANDS IN FOR A RETRY. Ninety seconds, sized off the interval #1860
# measured: claim-issue records the moment its fetch gives up, and new-branch follows in the same turn
# with only the issue read between them. Past that, a retry is worth making -- the operator has had
# time to notice their network, and an outage that outlives the window costs exactly one extra wait.
#
# IT BOUNDS A FAILURE AND NOTHING ELSE, which is why it can be this generous without costing a
# guardrail: see the header for the success-skip that was built, measured against this repo's own
# suite, and dropped. A caller opts in by passing it; nothing here reads it on its own.
#
# NOT A PARAMETER ANYWHERE THE OPERATOR CAN SEE. The failure mode of a knob on this is a checkout
# configured never to fetch, which is the one thing the parked-fix scan (#1853) and the parked-branch
# probe (#1139) both exist to prevent.
$script:RemoteFetchRecentFailureSeconds = 90

# How many lines of git's own diagnosis are carried forward with a failed attempt. git writes one or
# two lines on an unreachable remote; the cap is here so a pathological remote cannot grow a file
# inside the git directory. Carried at all because those lines -- "could not read from remote
# repository", "Authentication failed" -- are what tell a reader whether this is their network or
# their credentials, and the whole point of the skip is that the second caller never sees them
# first-hand (#1313's reasoning, one hop further along).
$script:RemoteFetchStampDetailLines = 6

function Get-RemoteFetchScope {
    <#
        The scope string an attempt is recorded under: 'all' for a remote's configured refspec, or
        'ref:<name>' for a fetch narrowed to one ref. Two strings rather than a structure, because
        the only question ever asked of them is whether one covers the other.
    #>
    param([string]$Refspec)

    if ($Refspec) { return "ref:$Refspec" }
    return 'all'
}

function Test-RemoteFetchScopeCovers {
    <#
        May an attempt recorded under $Recorded stand in for one requested under $Requested?

        ONE-DIRECTIONAL: 'all' covers everything, a narrow scope covers only itself. The reverse would
        let a failure that is ABOUT ONE REF -- "couldn't find remote ref main" -- suppress a wide
        fetch that would have succeeded, which is a failure invented rather than reported.
    #>
    param([string]$Recorded, [string]$Requested)

    if (-not $Recorded -or -not $Requested) { return $false }
    if ($Recorded -eq 'all') { return $true }
    return ($Recorded -eq $Requested)
}

function Get-DefaultFetchRemoteName {
    <#
        Which remote `git fetch` with no remote argument will actually contact -- git's own rule:
        branch.<current>.remote when it is set, and 'origin' otherwise.

        Returns $null when that cannot be established (no git, detached with no config, no remote
        called 'origin'), and a $null is NOT a guess: the caller then records nothing and skips
        nothing, which leaves it doing exactly what it did before this lib existed. That is the
        conservative half of #1860's "Not measured" -- a multi-remote checkout is left alone rather
        than reasoned about.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $head = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--abbrev-ref', 'HEAD') -DiscardStderr
    if ($head -and $head.ExitCode -eq 0) {
        $branch = ((@($head.Output) -join '').Trim())
        if ($branch -and $branch -ne 'HEAD') {
            $configured = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'config', '--get', "branch.$branch.remote") -DiscardStderr
            if ($configured -and $configured.ExitCode -eq 0) {
                $name = ((@($configured.Output) -join '').Trim())
                if ($name) { return $name }
            }
        }
    }

    # git's fallback is the literal name 'origin' -- so this confirms it EXISTS rather than assuming
    # it. A checkout without one makes the fetch itself fail, and recording a key for a remote that
    # is not there would let two unrelated failures match each other.
    $remotes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'remote') -DiscardStderr
    if ($remotes -and $remotes.ExitCode -eq 0) {
        foreach ($line in @($remotes.Output)) {
            if ("$line".Trim() -eq 'origin') { return 'origin' }
        }
    }
    return $null
}

function Get-RemoteFetchStampPath {
    <#
        Where the record lives: inside the git COMMON directory, shared by every worktree of the
        clone -- see the header for why this differs from gate-lib's per-worktree choice. Returns
        $null when git cannot answer, which every caller reads as "no record, and none can be kept".
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $dirLines = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--git-common-dir') -DiscardStderr
    if (-not $dirLines -or $dirLines.ExitCode -ne 0) { return $null }
    $gitDir = ((@($dirLines.Output) -join '').Trim())
    if (-not $gitDir) { return $null }
    # `--git-common-dir` answers relatively when the query is made from inside the work tree.
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $RepoRoot $gitDir }
    return (Join-Path $gitDir 'workflow-fetch-attempt.json')
}

function Read-RemoteFetchStamp {
    <#
        The record as an object, or $null when there is none, it cannot be read, or it is malformed.
        Every one of those is "no record", which fails toward MAKING the network call -- the safe
        direction, since the cost of a false $null is one fetch and the cost of a false record is a
        check reading refs nobody refreshed.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $path = Get-RemoteFetchStampPath -RepoRoot $RepoRoot
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $raw = [System.IO.File]::ReadAllText($path)
        # Assigned before use: @(... | ConvertFrom-Json) collects a parsed array as ONE element in
        # Windows PowerShell 5.1, the trap this repo has hit in two unrelated scripts.
        $parsed = $raw | ConvertFrom-Json
    } catch {
        return $null
    }
    if (-not $parsed) { return $null }
    return $parsed
}

function Save-RemoteFetchStamp {
    <#
        Record that a fetch of $Remote at $Scope was ATTEMPTED just now, and how it went.

        A SUCCESS IS RECORDED TOO, THOUGH NOTHING SKIPS ON ONE. It is what CLEARS a failure inside its
        own window: a remote that comes back, and a caller that fetches it successfully, must not
        leave the next caller suppressing a retry on a failure the tree has already disproved.

        ONE RECORD, NOT A LOG. The only question ever asked is "what happened to the last attempt",
        so a later attempt simply replaces the earlier one -- which also means the file cannot grow.

        Best-effort by design: an unwritable git directory costs a future skip, never this run.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][bool]$Ok,
        [string]$Note = '',
        [string[]]$Detail = @()
    )

    $path = Get-RemoteFetchStampPath -RepoRoot $RepoRoot
    if (-not $path) { return $false }

    $record = [ordered]@{
        remote     = $Remote
        scope      = $Scope
        ok         = $Ok
        note       = $Note
        detail     = @(@($Detail | Where-Object { $_ -and "$_".Trim() }) | Select-Object -First $script:RemoteFetchStampDetailLines)
        recordedAt = [datetime]::UtcNow.ToString('o')
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

function Get-RemoteFetchStampAgeSeconds {
    <#
        How old the record is, or $null when it carries no readable timestamp.

        A NEGATIVE AGE IS REFUSED rather than trusted, on gate-lib's precedent: "recorded in the
        future" is what a clock that moved backwards -- or a restored file -- looks like, and it is
        the one value that would make a record suppress every retry for ever.
    #>
    param([Parameter(Mandatory)]$Stamp)

    if (-not $Stamp -or -not $Stamp.PSObject.Properties['recordedAt']) { return $null }
    try {
        $at = [datetime]::Parse("$($Stamp.recordedAt)", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    } catch {
        return $null
    }
    $age = ([datetime]::UtcNow - $at).TotalSeconds
    if ($age -lt 0) { return $null }
    return $age
}

function Invoke-RecordedRemoteFetch {
    <#
        Fetch $Remote and record the attempt -- unless an attempt on the same remote at a covering
        scope FAILED less than $RecentFailureSeconds ago, in which case report that one instead.
        Consult, fetch and record are one call rather than three, so no caller can do two of the
        three.

        A SUCCESSFUL ATTEMPT NEVER EXCUSES THIS ONE, however recent. See the header: this repo's own
        suite measured what that costs, and it is the two probes whose subject is a push somebody
        else has just made.

        THE RETURN IS ONE OBJECT:

          Ran        did this call actually contact the remote
          Skipped    was a recent FAILURE reported instead
          Fresh      did a fetch this call made succeed -- so the refs are current. $false on a
                     skipped retry, because nothing was refreshed.
          ExitCode   this call's, or the recorded failure's
          TimedOut   this call's
          Output     git's own lines -- this call's, or the recorded ones on a skip
          Note       the one-line reason a reader needs, or '' when there is nothing to say. It stops
                     at the FACT: both callers already own a sentence for what a stale ref means to
                     them, and a note carrying its own would be printed inside theirs, twice.
          AgeSeconds how old the reported failure was, on a skip

        -Remote NAMES THE REMOTE, AND OMITTING IT MEANS "let git pick". The argument-less form is
        claim-issue's, deliberately kept (#1853 chose `fetch --quiet` over `--all` so a checkout with
        three remotes does not pay for two of them) -- so this resolves the name for the RECORD
        without putting it on the command line. Where the name cannot be resolved, the fetch still
        runs and nothing is recorded or skipped.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # The remote to fetch by name. Omitted: git's own default, resolved for the record only.
        [string]$Remote,
        # One ref to narrow the fetch to. Omitted: the remote's configured refspec ('all').
        [string]$Refspec,
        # 0 -- the default -- never skips. Only a caller that says so may be let off a retry.
        [int]$RecentFailureSeconds = 0,
        # 0 leaves Invoke-NativeCapture on its own default.
        [int]$TimeoutSeconds = 0
    )

    $scope = Get-RemoteFetchScope -Refspec $Refspec
    $key = if ($Remote) { $Remote } else { Get-DefaultFetchRemoteName -RepoRoot $RepoRoot }

    $result = [pscustomobject]@{
        Ran        = $false
        Skipped    = $false
        Fresh      = $false
        ExitCode   = 0
        TimedOut   = $false
        Output     = @()
        Note       = ''
        AgeSeconds = $null
        Remote     = $key
        Scope      = $scope
    }

    if ($key -and $RecentFailureSeconds -gt 0) {
        $stamp = Read-RemoteFetchStamp -RepoRoot $RepoRoot
        $failed = $stamp -and $stamp.PSObject.Properties['ok'] -and -not ([bool]$stamp.ok)
        if ($failed -and $stamp.PSObject.Properties['remote'] -and "$($stamp.remote)" -eq $key -and
            $stamp.PSObject.Properties['scope'] -and (Test-RemoteFetchScopeCovers -Recorded "$($stamp.scope)" -Requested $scope)) {
            $age = Get-RemoteFetchStampAgeSeconds -Stamp $stamp
            if ($null -ne $age -and $age -le $RecentFailureSeconds) {
                $recordedNote = if ($stamp.PSObject.Properties['note']) { "$($stamp.note)" } else { '' }
                if (-not $recordedNote) { $recordedNote = 'a git fetch failed' }
                $result.Skipped = $true
                $result.AgeSeconds = $age
                $result.ExitCode = 1
                $result.Note = "$recordedNote ($([int]$age)s ago, not retried)"
                if ($stamp.PSObject.Properties['detail']) { $result.Output = @(@($stamp.detail) | Where-Object { $_ -and "$_".Trim() }) }
                return $result
            }
        }
    }

    $fetchArgs = @('-C', $RepoRoot, 'fetch')
    if ($Remote) { $fetchArgs += $Remote }
    if ($Refspec) { $fetchArgs += $Refspec }
    $fetchArgs += '--quiet'

    # NO -DiscardStderr, AND THAT IS THE CONVENTION RATHER THAN AN OVERSIGHT (#1313). A git call that
    # talks to a remote writes ALL of its output to stderr, and git redacts the credential out of that
    # line itself (transport_anonymize_url). Nothing here parses the capture, so the flag would buy
    # nothing and cost the reader git's own reason -- the trade #1313 declined for three other fetches.
    $fetch = if ($TimeoutSeconds -gt 0) {
        Invoke-NativeCapture -FilePath 'git' -Arguments $fetchArgs -TimeoutSeconds $TimeoutSeconds
    } else {
        Invoke-NativeCapture -FilePath 'git' -Arguments $fetchArgs
    }

    $result.Ran = $true
    if ($fetch) { $result.Output = @(@($fetch.Output) | Where-Object { $_ -and "$_".Trim() }) }
    if (-not $fetch) {
        $result.ExitCode = 1
        $result.Note = 'git fetch could not be run at all'
    } elseif ($fetch.TimedOut) {
        $result.TimedOut = $true
        $result.ExitCode = $fetch.ExitCode
        $result.Note = "git fetch did not answer within $TimeoutSeconds seconds"
    } elseif (-not (Test-NativeExitMeasured -Capture $fetch)) {
        # AN UNMEASURABLE EXIT CODE IS NOT A FAILED FETCH (issue #1931, audited under #2081), and here it
        # was reported as one in a sentence with the number missing from it: `$null` interpolates empty,
        # so the note came out as "git fetch exited " and Fresh stayed $false. Every caller of this lib
        # reads Fresh as "is the remote-tracking ref current", so the cost is a freshness claim the run
        # never measured -- and the stamp written below then suppresses the retry for the next window.
        # Fresh stays $false, which is the honest direction and unchanged; what changes is that the note
        # now says which of the two states this is, so a reader is not sent after a fetch that may well
        # have worked.
        $result.ExitCode = $fetch.ExitCode
        $result.Note = "git fetch ran but its exit code could not be measured (issue #1931) -- whether the ref is current is unknown here; this normally settles on a re-run"
    } elseif ($fetch.ExitCode -ne 0) {
        $result.ExitCode = $fetch.ExitCode
        $result.Note = "git fetch exited $($fetch.ExitCode)"
    } else {
        $result.Fresh = $true
    }

    if ($key) {
        Save-RemoteFetchStamp -RepoRoot $RepoRoot -Remote $key -Scope $scope -Ok ([bool]$result.Fresh) `
                              -Note $result.Note -Detail $result.Output | Out-Null
    }

    return $result
}
