<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: on session start it reports whether a FIXTURE has written
    into the real ~/.claude plugin administration (issue #1609), and keeps a snapshot of that
    administration while it reads healthy.

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the source repo itself). Like
    git-identity-sessioncheck.ps1 this check runs LOCALLY: check-claude-home.ps1 reads one file in the
    user's home -- there is no source checkout to find and no network call. The hook runs the mirrored
    check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-claude-home.ps1).

    WHY A HOOK, AND WHY THE HARNESS IS THE ONLY THING THAT REACHES THIS. The damage came from a
    throwaway diagnostic script -- written mid-investigation, never committed, seen by no gate. Nothing
    in the committed tree writes under ~/.claude at all, so there is no call site a shared helper could
    be enforced at and nothing for the lint gate to check. What is left is the moment a session starts,
    which is also the moment every downstream reader begins answering "which plugin version is this
    checkout running?" from records that are no longer there. The full measurement, and the
    command-string guard that was considered and declined, are in the check script's own docstring.

    NO CI HALF, deliberately, and for the reason git-identity-sessioncheck gives: the finding is a fact
    about the MACHINE rather than about the tree. A CI runner has no plugin administration at all, so a
    workflow leg would report the empty state on every push.

    Deliberately soft, mirroring git-identity-sessioncheck.ps1 beside it:
      - check script not found -> a notice and done (exit 0);
      - only a blocking signal ([ERROR]) -> the report in the session context, never a block. [OK] and
        [SKIP] stay silent at session start; a deliberate run of check-claude-home.ps1 shows them;
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    THIS ONE IS NOT READ-ONLY, and it is the only member of the family that is not. Every other session
    check states in as many words that it changes nothing; this one lets the check refresh
    ~/.claude/plugins/installed_plugins.snapshot.json, and that snapshot is half the repair -- restoring
    it puts the previous records BACK, where re-installing writes new ones and changes what is
    installed. The write is bounded to that one path, happens only when the administration reads
    healthy, and never on a finding. It touches nothing in any repo.

    The siblings are NAMED rather than counted here, on the rule the plugin README's own hooks cell
    states -- see check-claude-home.ps1's docstring for what counting them cost while this was written.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER HomeOverride
    (Optional, for tests) Passed through to check-claude-home.ps1 as -HomeOverride, the directory it
    treats as the user home. The suite for this hook passes it for every case -- a suite that
    exercised a check about polluting the real ~/.claude by polluting the real ~/.claude would be the
    defect wearing a test's clothes.
#>
[CmdletBinding()]
param(
    [string]$CheckScriptOverride = '',
    [string]$HomeOverride = ''
)

Set-StrictMode -Version Latest

try {
    if ($CheckScriptOverride) {
        $checkScript = $CheckScriptOverride
    } elseif ($env:CLAUDE_PLUGIN_ROOT) {
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-claude-home.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'claude-home-sessioncheck: check script not found -- check skipped.'
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script. $PSScriptRoot-relative,
    # so it resolves the same in the source tree, in the plugin mirror and in a consumer's plugin cache --
    # lib and hook travel in one payload. Unguarded, and inside this try: a payload missing it reports
    # itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-HomeOverride' would
    # bind to the check's first positional parameter and the path itself would be dropped -- silently,
    # with no error anywhere. See trap 1 in hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($HomeOverride) { $checkArgs['HomeOverride'] = $HomeOverride }

    # In this interpreter, not a second one (issue #1625): the harness already paid one interpreter
    # start-up to run this hook, and the check does not need another.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # [ERROR] is check-claude-home's token for a finding it can prove. Select-CheckMarkerLine keeps it
    # case-exact, so the word "error" in prose never counts, and counts it only where the check WROTE
    # it -- never inside a value the check is reporting (issue #2142). The child's exit code is weighed too: an unexpected crash
    # (non-zero exit with no [ERROR] line) must not be misreported as "clean".
    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[ERROR]')

    if ($signals.Count -gt 0) {
        Write-Host 'claude-home-sessioncheck: the plugin administration in ~/.claude needs a look (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($code -eq 0) {
        Write-Host 'claude-home-sessioncheck: no fixture records in the ~/.claude plugin administration.'
    } else {
        Write-Host "claude-home-sessioncheck: the check could not complete (exit $code)."
    }
} catch {
    Write-Host ('claude-home-sessioncheck skipped due to an error: ' + $_.Exception.Message)
}
exit 0
