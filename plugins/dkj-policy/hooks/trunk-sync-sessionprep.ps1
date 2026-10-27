<#
.SYNOPSIS
    SessionStart PREP step of the workflow plugin: fast-forwards the session's checkout to origin when
    it stands clean on its trunk and is merely behind (issue #3605).

.DESCRIPTION
    A checkout's trunk sat behind origin routinely -- the CI fold runner lands its fold commit on origin
    after ship-pr has returned the checkout to the trunk, so a finished chain leaves it behind by
    construction -- and the owner synced it by hand (Maikel, October 27, 2026). This closes that at the
    one moment a person is about to start work.

    The move is Invoke-TrunkFastForward's (trunk-sync-lib.ps1), shared with sync-trunk.ps1, so the
    safety conditions have one definition: on the trunk, no uncommitted change to a tracked file, not
    diverged, and 'git merge --ff-only'. Anything else is reported and left alone.

    A PREP STEP, NOT A CHECK: sessioncheck-dispatch.ps1 runs every *-sessionprep.ps1 one after another
    BEFORE its parallel pool opens, because the checks read the trunk this step moves -- the unfolded-
    entry check, run against a trunk merely behind origin, used to report an entry already folded (#1585).

    What it prints:
      - synced / skipped-while-behind / failed -> one line;
      - current, off the trunk, no origin, not a checkout -> SILENT: nothing to act on, and a session on
        a branch is the ordinary case;
      - DKJ_TRUNK_AUTOSYNC=0 in the environment -> nothing at all, and no git call.
    The fetch is bounded (20 s) so an unreachable origin cannot stall a session start, and the script
    ALWAYS ends with exit 0.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) The checkout to sync instead of the session's.
#>
[CmdletBinding()]
param(
    [string]$ConsumerPathOverride = ''
)

Set-StrictMode -Version Latest

try {
    if ($env:DKJ_TRUNK_AUTOSYNC -eq '0') { exit 0 }

    $libDir = Join-Path $PSScriptRoot '..\scripts\lib'
    . (Join-Path $libDir 'check-report-lib.ps1')
    . (Join-Path $libDir 'native-capture-lib.ps1')
    . (Join-Path $libDir 'trunk-sync-lib.ps1')

    $root = (Resolve-CheckRoot -Override $ConsumerPathOverride).Path
    if (-not $root) { exit 0 }

    $r = Invoke-TrunkFastForward -RepoRoot $root -TimeoutSeconds 20
    # Every value printed goes through the strip, not only git's own text (security review): the trunk
    # name comes from origin/HEAD, which the repo controls, and a later Detail may carry more than it does.
    $trunk = Format-TrunkSyncSafeText $r.Trunk
    $detail = Format-TrunkSyncSafeText $r.Detail
    switch ($r.Outcome) {
        'synced' {
            Write-Host "trunk-sync-sessionprep: fast-forwarded '$trunk' by $($r.Behind) commit(s) to origin/$trunk."
        }
        'failed' {
            Write-Host "trunk-sync-sessionprep: '$trunk' was not synced -- $detail."
        }
        'skipped' {
            # Only a skip on a trunk that IS behind is worth a line; Behind is -1 for every skip that
            # happened before the fetch (off the trunk, no origin), and those are the ordinary case.
            if ($r.Behind -gt 0) {
                Write-Host "trunk-sync-sessionprep: '$trunk' is $($r.Behind) commit(s) behind origin and was not fast-forwarded -- $detail."
            }
        }
    }
} catch {
    # Inlined strip, not a lib call: the lib may be the thing that failed to load (#2271).
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('trunk-sync-sessionprep skipped due to an error: ' + $safe.Trim())
}
exit 0
