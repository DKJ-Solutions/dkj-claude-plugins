<#
.SYNOPSIS
    Fast-forwards a checkout's trunk to origin -- only where that cannot touch anybody's work (issue
    #3605). One function, two callers: the SessionStart prep hook (trunk-sync-sessionprep.ps1) and the
    sync-trunk entry point (scripts/task/sync-trunk.ps1), single checkout or -AllCheckouts.

.DESCRIPTION
    WHY IT EXISTS. A checkout's trunk sat behind origin routinely, and the owner synced it by hand
    (Maikel, October 27, 2026). Nothing in the workflow fast-forwards a trunk that is merely standing
    there: new-branch.ps1 does it at the moment a branch is cut, open-pr.ps1 refuses when origin is
    ahead, and the CI fold runner lands its fold commit on origin AFTER ship-pr has returned the
    checkout to the trunk -- so a finished chain leaves the checkout behind by construction.

    THE SAFETY CONDITIONS, every one of which must hold before anything moves:
      1. the folder is the root of a git work tree;
      2. the trunk can be read (the caller's -Trunk, else origin/HEAD, else 'main') and its
         remote-tracking ref exists;
      3. the checkout is ON the trunk -- a branch, or a detached HEAD (a rebase or bisect in progress),
         is never touched, and is not even fetched for;
      4. no tracked file has an uncommitted change -- untracked files are allowed, because
         'merge --ff-only' itself refuses to overwrite one;
      5. the trunk has no local commit origin lacks -- a diverged trunk is reported, never merged.
    The move itself is 'git merge --ff-only', which cannot create a commit or lose one.

    OUTCOMES, so each caller decides what to print:
      synced   -- fast-forwarded by .Behind commit(s)
      current  -- nothing to do (.Ahead may be > 0: local commits origin lacks, nothing behind)
      would    -- -DryRun: would fast-forward by .Behind
      skipped  -- a safety condition failed; .Detail says which, .Behind says how far behind (-1 = not
                  measured, because the condition failed before the fetch)
      failed   -- a git step failed; .Detail carries git's first line

    EVERY GIT CALL IS BOUNDED (code review). The prep hook runs in the dispatcher's own process, before
    the pool whose deadline bounds the checks, so nothing outside this lib can interrupt it: a 'status'
    on a network drive or a git waiting on a lock would otherwise stall the whole session start. Reads
    get 15 s, the fetch the caller's -TimeoutSeconds, the merge 60 s.

    WHY NOT Get-TrunkGap (entry-scaffold-lib.ps1). It answers "how far behind" and nothing else, and it
    lives in a 6,000-line lib a session-start hook should not parse. This needs the ahead count, the
    dirty and on-trunk gates, the bounded fetch and the move, so only the rev-list half would have been
    shared.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script. Depends on
    Invoke-NativeCapture (native-capture-lib.ps1), which every caller loads first.
#>

# THE HOOK-FREE PREFIX, for a checkout the person did not open (security review, #3605). git honours a
# repo's own .git/config and hooks: 'status' runs core.fsmonitor, and 'merge' runs post-merge and
# post-checkout. In the checkout a session opens, that is the same trust as opening it. A sweep over
# every checkout in the install administration would extend it to repos nobody opened this time, so
# that caller passes -NoRepoHooks and every git call below carries this prefix. A hooksPath that does
# not exist means git finds no hook to run.
function Get-TrunkSyncGitPrefix {
    param([switch]$NoRepoHooks)
    if (-not $NoRepoHooks) { return @() }
    $none = Join-Path ([System.IO.Path]::GetTempPath()) 'dkj-trunk-sync-no-hooks'
    return @('-c', 'core.fsmonitor=false', '-c', "core.hooksPath=$none")
}

function Get-TrunkSyncGitLine {
    # One trimmed line of git output, or '' where git answers nothing or fails -- every caller treats ''
    # as "could not establish", never as a value.
    param([string]$Path, [string[]]$GitArgs)
    $r = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $Path) + $script:TrunkSyncPrefix + $GitArgs) -DiscardStderr -TimeoutSeconds 15
    if ($r.ExitCode -ne 0) { return '' }
    return ("$(@($r.Output) | Where-Object { "$_".Trim() } | Select-Object -First 1)").Trim()
}

function Format-TrunkSyncSafeText {
    # A failure's Detail carries git's own first line, which is foreign text -- a remote's error message,
    # a consumer's path -- and the prep hook forwards it into session context. Whitespace first, so no
    # newline can forge a line, then control characters, then brackets, so no marker can form (#2271).
    param([string]$Text)
    return (((($Text -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')').Trim()
}

function Get-TrunkSyncCount {
    # rev-list --count for a range, or -1 where git cannot answer.
    param([string]$Path, [string]$Range)
    $line = Get-TrunkSyncGitLine -Path $Path -GitArgs @('rev-list', '--count', $Range)
    $n = 0
    if ($line -and [int]::TryParse($line, [ref]$n)) { return $n }
    return -1
}

function Invoke-TrunkFastForward {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # The trunk, when the caller knows it. Otherwise origin/HEAD, then 'main'.
        [string]$Trunk = '',
        # Bound on the fetch, so an unreachable origin cannot stall a session start.
        [int]$TimeoutSeconds = 30,
        [switch]$DryRun,
        # Run git with the checkout's own hooks and fsmonitor switched off -- see Get-TrunkSyncGitPrefix.
        [switch]$NoRepoHooks
    )

    $script:TrunkSyncPrefix = @(Get-TrunkSyncGitPrefix -NoRepoHooks:$NoRepoHooks)
    $git = { param([string[]]$GitArgs) @('-C', $RepoRoot) + $script:TrunkSyncPrefix + $GitArgs }

    $result = [pscustomobject]@{
        Path    = $RepoRoot
        Trunk   = $Trunk
        Outcome = 'skipped'
        Detail  = ''
        Behind  = -1
        Ahead   = -1
    }

    # 1. The root of a work tree -- asked as --show-cdup, not --show-toplevel, which returns raw UTF-8 a
    #    code page can corrupt (#2115). An empty cdup line inside a work tree means this IS the root.
    $probe = Invoke-NativeCapture -FilePath 'git' -Arguments (& $git @('rev-parse', '--is-inside-work-tree', '--show-cdup')) -DiscardStderr -TimeoutSeconds 15
    $probeLines = @(@($probe.Output) | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($probe.ExitCode -ne 0 -or $probeLines.Count -ne 1 -or $probeLines[0] -ne 'true') {
        $result.Detail = 'not the root of a git checkout'
        return $result
    }

    # 2. The trunk and its remote-tracking ref.
    if (-not $Trunk) {
        $Trunk = (Get-TrunkSyncGitLine -Path $RepoRoot -GitArgs @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')) -replace '^origin/', ''
    }
    if (-not $Trunk) { $Trunk = 'main' }
    $result.Trunk = $Trunk
    $ref = "refs/remotes/origin/$Trunk"
    if (-not (Get-TrunkSyncGitLine -Path $RepoRoot -GitArgs @('rev-parse', '--verify', '--quiet', $ref))) {
        $result.Detail = "no origin/$Trunk to sync from"
        return $result
    }

    # 3. On the trunk -- checked BEFORE the fetch, so a mid-work checkout costs no network call.
    $branch = Get-TrunkSyncGitLine -Path $RepoRoot -GitArgs @('branch', '--show-current')
    if ($branch -ne $Trunk) {
        $shown = if ($branch) { "branch '$branch'" } else { 'a detached HEAD' }
        $result.Detail = "on $shown, not on '$Trunk' -- a checkout off its trunk is never touched"
        return $result
    }

    # The fetch, narrowed to the trunk. Git's own first line is kept on failure: it is the only
    # diagnosis a reader gets, and a failing fetch leaks no credential (#1313).
    $fetch = Invoke-NativeCapture -FilePath 'git' -Arguments (& $git @('fetch', '--quiet', 'origin', $Trunk)) -TimeoutSeconds $TimeoutSeconds
    if ($fetch.ExitCode -ne 0) {
        $why = if ($fetch.PSObject.Properties['TimedOut'] -and $fetch.TimedOut) { "no answer within $TimeoutSeconds s" }
               else { "$(@($fetch.Output) | Where-Object { "$_".Trim() } | Select-Object -First 1)".Trim() }
        $result.Outcome = 'failed'
        $result.Detail = "fetch from origin failed$(if ($why) { ": $why" })"
        return $result
    }

    $result.Behind = Get-TrunkSyncCount -Path $RepoRoot -Range "HEAD..$ref"
    $result.Ahead  = Get-TrunkSyncCount -Path $RepoRoot -Range "$ref..HEAD"
    if ($result.Behind -lt 0 -or $result.Ahead -lt 0) {
        $result.Outcome = 'failed'
        $result.Detail = 'could not count the commits between the trunk and origin'
        return $result
    }
    if ($result.Behind -eq 0) {
        $result.Outcome = 'current'
        return $result
    }

    # 4. No uncommitted change to a tracked file. A git failure counts as dirty: the move runs only on a
    #    positive answer.
    $status = Invoke-NativeCapture -FilePath 'git' -Arguments (& $git @('status', '--porcelain', '--untracked-files=no')) -DiscardStderr -TimeoutSeconds 15
    if ($status.ExitCode -ne 0 -or @(@($status.Output) | Where-Object { "$_".Trim() }).Count -gt 0) {
        $result.Detail = 'uncommitted changes (or git could not say) -- commit or stash them, then sync'
        return $result
    }

    # 5. Not diverged.
    if ($result.Ahead -gt 0) {
        $result.Detail = "diverged: $($result.Ahead) local commit(s) on '$Trunk' that origin lacks -- never merged automatically"
        return $result
    }

    if ($DryRun) {
        $result.Outcome = 'would'
        return $result
    }

    $merge = Invoke-NativeCapture -FilePath 'git' -Arguments (& $git @('merge', '--ff-only', '--quiet', $ref)) -TimeoutSeconds 60
    if ($merge.ExitCode -ne 0) {
        $why = "$(@($merge.Output) | Where-Object { "$_".Trim() } | Select-Object -First 1)".Trim()
        $result.Outcome = 'failed'
        $result.Detail = "fast-forward refused$(if ($why) { ": $why" })"
        return $result
    }
    $result.Outcome = 'synced'
    return $result
}
