<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: on session start it checks whether this checkout acts as
    one GitHub account and commits as another -- the split identity that makes the claim rule's `@me`
    write the wrong account (issue #1315) -- and surfaces the finding if it does.

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the source repo itself). Like
    unfolded-entry-sessioncheck.ps1, this check runs LOCALLY: check-git-identity.ps1 reads the keyring
    through `gh auth status` and the checkout's own `git config` -- there is no source checkout to find
    and no network call. The hook runs the mirrored check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-git-identity.ps1) against the current repo.

    WHY A HOOK AND WHY NOTHING ELSE. There is no CI half here, deliberately, and it is the one place
    this hook differs from its three siblings: the finding is a fact about the MACHINE rather than
    about the tree, and a CI runner authenticates as a bot and commits as one -- a mismatch by design
    that says nothing about the change under review. So a workflow run would report a false positive
    on every push. The moment that matters is the START of a session, which is exactly when the
    session is about to claim an issue with `@me` and then commit under a different name. Nothing else
    reaches that moment: the mismatch produces no error, no failing gate and no wrong file -- only a
    tracker and a branch that quietly disagree about who is working.

    Deliberately soft, mirroring unfolded-entry-sessioncheck.ps1:
      - check script not found -> a notice and done (exit 0);
      - no usable git author identity ([WARNING]) -> the report, FIRST and unconditionally. This one is
        not a comparison at all: the checkout cannot commit, so every commit in the cycle fails and
        new-branch.ps1 refuses outright. Reported here because the alternative is learning it from an
        exit 128 inside new-branch, after HEAD has moved (inbound #1867);
      - a blocking signal ([ERROR]) -> the report in the session context, never a block;
      - genuine agreement ([OK]) -> the one-line in-sync sentence;
      - nothing to compare ([SKIP], exit 0) -> stays silent at session start; a deliberate run of
        check-git-identity.ps1 shows the reason. Until issue #1830 this branched on the exit code alone,
        so every [SKIP] -- gh absent, user.name unset, a display name -- was reported as [OK]'s
        agreement sentence: a claimed comparison where none had been made, on a machine that may have no
        git identity at all. #1830 routed all three to silence, which was right for two of them and
        wrong for the third; inbound #1867 split that third one out into the [WARNING] above, so what
        stays silent here is now only the states that genuinely have nothing to say;
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    Read-only: the hook changes nothing, in any repo. It writes no git config and runs no `gh auth`
    command -- the repair is the reader's choice between two accounts, and the check prints both ways
    out rather than picking one.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-git-identity.ps1 as -RootOverride, the repo root
    whose `git config` is read.
#>
[CmdletBinding()]
param(
    [string]$CheckScriptOverride = '',
    [string]$ConsumerPathOverride = ''
)

Set-StrictMode -Version Latest

try {
    if ($CheckScriptOverride) {
        $checkScript = $CheckScriptOverride
    } elseif ($env:CLAUDE_PLUGIN_ROOT) {
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-git-identity.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'git-identity-sessioncheck: check script not found -- check skipped.'
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script. $PSScriptRoot-relative,
    # so it resolves the same in the source tree, in the plugin mirror and in a consumer's plugin cache --
    # lib and hook travel in one payload. Unguarded, and inside this try: a payload missing it reports
    # itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-RootOverride' would
    # bind to the check's first positional parameter and the path itself would be dropped -- silently,
    # with no error anywhere. See trap 1 in hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($ConsumerPathOverride) { $checkArgs['RootOverride'] = $ConsumerPathOverride }

    # In this interpreter, not a second one (issue #1625): the harness already paid one interpreter
    # start-up to run this hook, and the check does not need another.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # [ERROR] and [OK] are check-git-identity's tokens for "a comparison was made" -- the first for a
    # provable split identity, the second for provable agreement. [WARNING] is its token for the state
    # that outranks the comparison (inbound #1867): no usable git author identity, i.e. this checkout
    # cannot commit at all. -cmatch keeps all three case-exact so the words "error"/"ok"/"warning" in
    # prose never count. [SKIP] (nothing to compare) is deliberately NOT matched here: reporting it
    # falls through to the exit-code branch below, which stays silent, per the docstring's own promise.
    # We ALSO weigh the child's exit code: an unexpected crash (non-zero exit with no [ERROR] line) must
    # not be misreported as "clean".
    $signals   = @($out | Where-Object { $_ -cmatch '\[ERROR\]' })
    $agreement = @($out | Where-Object { $_ -cmatch '\[OK\]' })
    $noIdent   = @($out | Where-Object { $_ -cmatch '\[WARNING\]' })

    # FIRST, BECAUSE IT OUTRANKS THE COMPARISON (inbound #1867). check-git-identity exits on this
    # state before it compares anything, so in practice these arms are mutually exclusive; the order
    # states the precedence anyway, so a future check that reported both could not bury this one. This
    # is the one identity state a session must know BEFORE it opens a branch -- new-branch.ps1 refuses
    # on it, and every commit in the cycle fails without it.
    if ($noIdent.Count -gt 0) {
        Write-Host 'git-identity-sessioncheck: this checkout has no usable git author identity -- it cannot commit (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($signals.Count -gt 0) {
        Write-Host 'git-identity-sessioncheck: this checkout acts as one GitHub account and commits as another (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($agreement.Count -gt 0) {
        Write-Host 'git-identity-sessioncheck: the gh account and the git identity agree.'
    } elseif ($code -eq 0) {
        # [SKIP]: nothing to compare -- gh absent, user.name unset, or a display name rather than a
        # login. Stays silent at session start rather than claiming a comparison that was never made.
    } else {
        Write-Host "git-identity-sessioncheck: the check could not complete (exit $code)."
    }
} catch {
    Write-Host ('git-identity-sessioncheck skipped due to an error: ' + $_.Exception.Message)
}
exit 0
