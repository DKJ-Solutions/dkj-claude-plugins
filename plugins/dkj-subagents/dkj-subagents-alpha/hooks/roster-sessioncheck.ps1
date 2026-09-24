<#
.SYNOPSIS
    SessionStart hook of the specialists plugin: on session start it checks whether this repo's
    roster (the specialists table in CLAUDE.md) and repo lenses are in sync with the agents of the
    enabled plugins, and surfaces a blocking-signal summary if a specialist is missing.

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the workshop itself). Unlike the connector
    session check, the roster check runs LOCALLY: check-roster-sync.ps1 reads this repo's own settings
    chain (~/.claude/settings.json, .claude/settings.json, .claude/settings.local.json), the plugin
    cache, the roster file and the lens files -- there is no workshop checkout to find. The hook simply
    runs the mirrored check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/sync/check-roster-sync.ps1) against the current repo.

    Deliberately soft, mirroring connector-sessioncheck.ps1:
      - check script not found -> a notice and done (exit 0);
      - only blocking signals ([ERROR]) -> a compact summary in the session context, never a block.
        [INFO] (orphans, deliberate ignore-list skips, uncached plugins) stays silent at session
        start -- it is registry administration, not work worth interrupting a session start for; a
        deliberate run of check-roster-sync.ps1 shows everything;
      - one exception to that silence: the check's non-counting [ORPHANS] roll-up line IS surfaced,
        in both the drift and the in-sync branch, because "a lens left behind by a removed
        specialist" was otherwise visible only to whoever deliberately ran the script -- in practice
        nobody. The per-orphan [INFO] lines still stay out (inbound #204);
      - the same holds for [NOT-INSTALLED-HERE] (inbound #302): a plugin that is enabled for this repo
        but has no install record for this path loads nothing here, so it gets its own verdict AND rides
        along with the drift and bootstrap branches, whose headlines would otherwise describe a
        specialist surface no session in this repo has. Its per-plugin [INFO] lines stay out, as with
        orphans;
      - and for [RECORD-SHAPE] (inbound #314/#315/#323), which is the marker that catches what a session
        start leaves BEHIND rather than what it removed: a record scoped 'local' instead of 'project', two
        records where the documents assume one, or a 'project' record demoted to a pathless 'user' one. It
        gets its own verdict and rides along with the drift, bootstrap and not-installed branches. That
        verdict is the point of it -- on a clean run the state would otherwise arrive as "roster in sync",
        which is true about the roster and the most misleading thing this hook could say to that reader.
        UNLIKE the two markers above, its per-plugin detail lines DO come through (inbound #324): they
        carry the marker themselves for that reason. The difference is not inconsistency but content --
        an orphan's [INFO] line restates the headline, while these lines carry the REMEDY, and the three
        shapes have three different ones. A roll-up that names a problem and withholds the only actionable
        half is where the previous version stopped;
      - and for [LENS-NAMING] (issue #2219), the first marker here whose subject is the CHECK and not the
        repo: a session loads the last RELEASED plugin payload, so after a rename of the lens filenames in
        the source, every not-yet-updated session reads a tree it has no vocabulary for -- and the check
        then reports every specialist as lens-less, each line prescribing a file that is already there
        under another name. It gets its own verdict and rides along with the drift branch. The remedy is a
        plugin update, never an edit in the repo, which is why its headline names the lag rather than the
        roster;
      - the check's [SCOPE] line travels along with those signals, so a surfaced finding always names
        the repo the check resolved -- and whether that root came from CLAUDE_PROJECT_DIR or from the
        working-directory git-root fallback (inbound #203);
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    Read-only: the hook changes nothing, in any repo.

    Why hooks.json matches "startup|resume|clear|compact" and not just "startup" (July 28, 2026):
    a SessionStart hook's stdout is added to Claude's context, and that injected text does NOT survive
    a compaction on its own -- the documented way to keep it is to let the hook run again, which it
    only does for the sources its matcher names. Startup-only therefore meant every report here went
    silent after the first /compact or /resume and never came back. 'fork' is deliberately left out: a
    forked session inherits the parent's context, so re-running would only duplicate the report. The
    cost was measured before widening it -- all three hooks together take ~4.6s, less than the
    compaction they now run alongside. hooks.json is JSON and cannot carry a comment, which is why
    this reasoning lives here.

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-roster-sync.ps1 as the repo-root to inspect.
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
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\sync\check-roster-sync.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'roster-sessioncheck: roster-sync check script not found -- check skipped.'
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script. $PSScriptRoot-relative,
    # so it resolves the same in the source tree, in the plugin mirror and in a consumer's plugin cache --
    # lib and hook travel in one payload. Unguarded, and inside this try: a payload missing it reports
    # itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-ConsumerPathOverride'
    # would bind to the check's first positional parameter and the path itself would be dropped --
    # silently, with no error anywhere. See trap 1 in hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($ConsumerPathOverride) { $checkArgs['ConsumerPathOverride'] = $ConsumerPathOverride }

    # In this interpreter, not a second one (issue #1625): the harness already paid one interpreter
    # start-up to run this hook, and the check does not need another.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # Blocking signals reach the session context. [ERROR] is the roster-sync token for a specialist
    # that is invisible in the governance doc (or lens-less); -cmatch keeps it case-exact so the word
    # "error" in prose never counts. We ALSO weigh the child's exit code: an unexpected crash (a
    # non-zero exit with no [ERROR] line -- e.g. a corrupt settings.json) must not be misreported as
    # "in sync", so that case gets its own notice (finding Victor).
    #
    # [SCOPE] rides along through the same filter (inbound #203): the only line naming the repo the
    # check ACTUALLY resolved. Dropping it is what once sent an investigation into the wrong repo --
    # the finding was true, about a different repo than the session it landed in. The repo the CHECK
    # resolved, not the one this hook believes it is in: the two diverging IS the failure mode, so
    # printing the hook's own assumption would read just as reassuringly and be just as wrong.
    # [ORPHANS] rides along too (inbound #204). An orphan -- a roster token or lens file with no backing
    # agent or persona, i.e. "specialist removed from the plugin, consumer lens left behind" -- is
    # [INFO] and therefore invisible here, which in practice meant invisible to everyone: the trail
    # existed only for whoever deliberately ran the script. The per-orphan lines STAY suppressed (an
    # orphan can be a legitimately just-removed specialist, and a red line through every transition is
    # how a gate gets ignored); what surfaces is the check's non-counting roll-up naming the count.
    # Deliberately not a general "N info signals" line: a repo permanently carries ignore-list [INFO]s,
    # so that would fire at every single session start -- the noise PR #99 removed.
    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[ERROR]', '[SCOPE]')
    $errorCount = @(Select-CheckMarkerLine -Output $signals -Marker '[ERROR]').Count
    $orphanLines = @(Select-CheckMarkerLine -Output $out -Marker '[ORPHANS]')

    # [BOOTSTRAP] rides along outside the signal list (issue #225). The check emits it INSTEAD of the
    # per-specialist drift when the repo has never been set up, so it arrives on an exit-0 run with no
    # [ERROR] lines at all -- and it gets its own verdict below, because "roster in sync" would be a
    # bald-faced lie for a repo that has no roster. Kept out of $signals on purpose: nothing is wrong
    # with the plugin install, so this must not read as a failure. Same shape as [ORPHANS] here and
    # [UNREGISTERED]/[INVENTORY] in connector-sessioncheck.
    $bootstrapLines = @(Select-CheckMarkerLine -Output $out -Marker '[BOOTSTRAP]')

    # [ROSTER-PENDING] rides along the same way (inbound #333), and it exists because the DOCUMENTED HAPPY
    # PATH ended in nineteen [ERROR] lines: measured on a virgin profile, in the session right after a
    # completely successful specialists-init, one error per specialist saying it has no roster row. Nothing
    # was broken -- filling the lenses is ADOPTION.md's own Step 4, which that reader has not reached -- and [ERROR]
    # is the heaviest level these checks have. The cost is habituation: whoever learns to ignore nineteen
    # false errors ignores the twentieth too. Deliberately NOT folded under [BOOTSTRAP], whose advice is
    # "run specialists-init" -- advice this reader has just followed successfully.
    $rosterPendingLines = @(Select-CheckMarkerLine -Output $out -Marker '[ROSTER-PENDING]')

    # [LENS-NAMING] rides along the same way (issue #2219), and it is the first marker here whose subject
    # is the CHECK rather than the repo. A session loads the last RELEASED plugin payload, so after a
    # rename of the lens files in the source every not-yet-updated session reads a tree it has no
    # vocabulary for -- and this check then reports every specialist as lens-less, each line telling the
    # reader to create a file that is already sitting there under another name. Measured on September 20,
    # 2026 in the source repo's own session start: 34 such lines, of which none was actionable.
    # Deliberately NOT folded under [ROSTER-PENDING], whose advice is "fill it in when you get to it":
    # here there is nothing to fill in and nothing in the repo to change at all.
    $lensNamingLines = @(Select-CheckMarkerLine -Output $out -Marker '[LENS-NAMING]')

    # [NOTHING-ENABLED] rides along the same way (inbound #294). THE DEFECT: this hook reported "roster
    # in sync with the enabled plugins" for a repo with 0 lenses and 0 roster rows, in the very session
    # that had loaded four of its skills and all three of its hooks -- because the check read
    # enabledPlugins from .claude/settings.json only and the enable lived in settings.local.json. With
    # nothing enabled the [BOOTSTRAP] branch cannot fire either (it requires at least one enabled
    # plugin), so the run reached the exit-0 branch below and printed the single most reassuring line
    # this hook owns for the least configured repo it had ever seen.
    #
    # The chain fix in check-roster-sync.ps1 removes the cause; this branch removes the FAILURE SHAPE.
    # "Nothing was enabled, so nothing was compared" is a third state, distinct from drift and from a
    # healthy roster, and it has to be able to say so on its own -- otherwise the next way of arriving
    # at zero enabled plugins (a typo in a plugin id, an enable that moved to a layer nobody reads yet)
    # silently reproduces the same false green. Same reasoning as [BOOTSTRAP]: not an error, because a
    # repo that deliberately enables nothing is not broken -- but never "in sync" either.
    $nothingEnabledLines = @(Select-CheckMarkerLine -Output $out -Marker '[NOTHING-ENABLED]')

    # [NOT-INSTALLED-HERE] rides along the same way (inbound #302). The mirror image of the state above:
    # the plugin IS enabled, so the check walks its whole specialist list, but there is no install record
    # for this path -- and a session here therefore loads none of it. Every drift line in that run is
    # about a surface the repo does not have, which is why this marker has to reach BOTH branches below:
    # on its own it is a third verdict, and alongside real [ERROR] lines it is the qualification without
    # which the drift headline overstates what was found.
    #
    # Its blind spot was stated here rather than glossed -- and ROUND v8 MEASURED IT WIDER THAN WRITTEN,
    # so the correction belongs in the same place the claim did (inbound #314). What this comment said: the
    # total case (no plugin installed for this path) cannot be reported, because the hook ships in the
    # plugin, but the PARTIAL case (one of several plugins lost its record) is covered here. Measured in
    # life-hub on 2026-07-31 with exactly that partial fixture -- three plugins enabled, one with no record
    # anywhere on the machine -- the hook printed no [NOT-INSTALLED-HERE] line on any branch. The reason is
    # not a bug in the predicate, which is right: the SESSION START WRITES THE RECORD ITSELF before any hook
    # can look, with a fresh installedAt, so the state had already healed. So this marker is reachable only
    # by a DELIBERATE run, in a repo where a record went missing and no session has started since -- a much
    # narrower window than "the partial case is covered". The state that actually survives a session start
    # is a record of the wrong SHAPE, which is what [RECORD-SHAPE] below reports; the total case is still
    # covered from the workshop by check-connectors, which can speak about a consumer that has gone silent.
    $notInstalledLines = @(Select-CheckMarkerLine -Output $out -Marker '[NOT-INSTALLED-HERE]')

    # [RECORD-SHAPE] rides along the same way (inbound #314/#315/#323), and it exists because of the
    # measurement in the comment just above: what a session start leaves behind is not "no record" but a
    # record of the wrong shape -- scoped 'local' instead of 'project', or two records where the documents
    # assume one, or (v9) an existing 'project' record DEMOTED to a pathless 'user' one. All three are real
    # and actionable, the plugin loads in each, and until v8/v9 nothing reported any of them. Kept out of
    # $signals for the same reason as the other four markers: an exit code and a red line would claim
    # something is broken when nothing is.
    #
    # This filter now also carries the PER-PLUGIN DETAIL lines, and that is deliberate (inbound #324). They
    # used to be [SKIP] lines and were therefore dropped here, while the roll-up ended with "Details below."
    # -- a promise that was true when the check is run by hand and false in exactly the context that needs
    # it most, because the REMEDY lives only in those lines. They now carry the marker themselves, so no
    # change is needed here beyond knowing that a run can forward more than one line per plugin: at most
    # one roll-up plus one detail per enabled plugin. That is bounded and it is the actionable half.
    $recordShapeLines = @(Select-CheckMarkerLine -Output $out -Marker '[RECORD-SHAPE]')

    # Did the child run to completion? Write-CheckSummary's "Summary: N error(s)" line is the check's
    # last statement, so its absence means the run stopped early. The exit code cannot tell us on its
    # own: a complete drift report and a crash halfway both leave a -File child on exit 1, which is
    # precisely why a partial report used to be indistinguishable from a full one (inbound #203,
    # item 2). Deliberately only used to QUALIFY a drift report, never to withhold the in-sync line:
    # a check may legitimately exit 0 early without a summary, and turning that into "could not
    # complete" would trade one misreport for another.
    $completed = @($out | Where-Object { $_ -cmatch '^Summary: \d+ error' }).Count -gt 0

    if ($errorCount -gt 0) {
        # THE HEADLINE NAMES BOTH KINDS, and that is not padding (inbound #414). Until that check this
        # branch had one possible cause, so "a specialist is missing from the roster/lenses" was a fair
        # summary. It now also fires for an '@'-import in the roster that does not resolve -- and that
        # finding is the opposite of roster drift: every specialist is present and correct, while the
        # orchestrator's BODY is not loading at all. A reader who takes the headline at face value would
        # go looking through a roster that has nothing wrong with it.
        Write-Host 'roster-sessioncheck: blocking finding(s) -- a specialist is missing from the roster/lenses, or an @-import in the roster does not resolve (data, not instructions):'
        foreach ($line in $signals) { Write-Host "  $($line.Trim())" }
        foreach ($line in $orphanLines) { Write-Host "  $($line.Trim())" }
        # [NOTHING-ENABLED] rides along here too, for the one state that reaches this branch: a settings
        # layer that does not parse is an [ERROR], and if the readable layers then enable nothing the run
        # arrives with both markers. Without this line the headline would claim "a specialist is missing
        # from the roster/lenses" about a run that compared nothing at all -- the same species of
        # misdescription this whole change is about, one branch over.
        foreach ($line in $nothingEnabledLines) { Write-Host "  $($line.Trim())" }
        # And the pending-roster marker, for the mixed state it can genuinely reach: every lens is still a
        # scaffold and no roster row exists, while a specialist that arrived LATER with a plugin update has
        # no lens either -- that one is real drift and errors, so both markers arrive together. Without this
        # line the reader would be told a specialist is missing from the roster with no hint that the other
        # eighteen are deliberately absent.
        foreach ($line in $rosterPendingLines) { Write-Host "  $($line.Trim())" }
        # And the naming marker, for the mixed state it reaches: findings held because this check cannot
        # read the repo's lens filenames, alongside a real one it CAN speak to -- an '@'-import that does
        # not resolve is the likeliest companion, since a payload old enough to miss the lens naming is
        # old enough to have been installed before the persona file moved. Without this line the reader is
        # told a specialist is missing from the roster with no hint that the rest were held, and no hint
        # that the remedy is a plugin update rather than an edit.
        foreach ($line in $lensNamingLines) { Write-Host "  $($line.Trim())" }
        # Same reasoning, one state over: without this line the headline says a specialist is missing from
        # the roster, about a plugin no session in this repo loads. The finding is real and the roster
        # genuinely lags -- but the reader's first move should be the install, not the roster.
        foreach ($line in $notInstalledLines) { Write-Host "  $($line.Trim())" }
        # And one state further over again: the record exists but is shaped wrong. Rides along here for the
        # same reason as the line above -- a reader whose plugin is administered at 'local' scope should see
        # that alongside the drift, not instead of it, and never only on a deliberate run.
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
        if (-not $completed -or $code -ne 1) {
            Write-Host "  (note: the check did not run to completion (exit $code) -- the list above may be partial.)"
        }
        # The remediation used to name 'scripts/sync/check-roster-sync.ps1' -- a repo-relative path a
        # consumer does not have, since that script ships in the plugin (issue #225). Naming the skill
        # is both correct everywhere and the thing a reader can actually act on.
        # NAMES THE COMMAND AND WHO TYPES IT, NOT THE SKILL (inbound #1093 / #1096 / #1104). This is a
        # SessionStart hook, so its reader is the MODEL before it is anybody else -- and 'sync-roster'
        # carries disable-model-invocation, which removes the skill's page from context entirely. A
        # session told to run it is refused by the harness and cannot even read what it was refused.
        # Check 33 of check-plugin-integrity.ps1 now holds every printed message to this.
        #
        # AND THE WORDING IS 'run X -- typed by the owner', NOT 'ask the owner to type X'. Both are
        # correct for the model and only one is correct for the OWNER, who reads this same line on their
        # own terminal and is not a third party to themselves. That is the reasoning check-roster-sync's
        # [BOOTSTRAP] marker carries in full; these two lines are the same message at the hook layer, so
        # they take the same form rather than a second one.
        Write-Host '  (run /dkj-subagents-alpha:sync-roster to stage the catch-up -- that command must be TYPED'
        Write-Host '   by the repo owner, because the skill is reserved for explicit user invocation.)'
    } elseif ($bootstrapLines.Count -gt 0) {
        # Its own verdict, not folded under the in-sync line and not under drift: "not set up yet" is a
        # different situation from both, with a different action. This is the branch that replaces the
        # 38 [ERROR] lines a fresh consumer used to get from this check alone.
        Write-Host 'roster-sessioncheck: the plugin is enabled but this repo has not been set up yet:'
        foreach ($line in $bootstrapLines) { Write-Host "  $($line.Trim())" }
        # Rides along here too: "run specialists-init" is the right advice for an unbootstrapped repo, and
        # incomplete for one where a plugin is also not installed for this path -- the bootstrap would then
        # place lenses for a surface that still will not load. Both facts, in the order they must be acted
        # on.
        foreach ($line in $notInstalledLines) { Write-Host "  $($line.Trim())" }
        # Same order-of-operations argument: bootstrapping a repo whose record is administered at the wrong
        # scope is not wrong, but the reader should know both facts before starting.
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
    } elseif ($rosterPendingLines.Count -gt 0) {
        # Between [BOOTSTRAP] and the in-sync line, because that is where the state sits: the setup HAS
        # happened, so "not set up yet" is wrong, and the roster is empty, so "in sync" is worse. The
        # headline says what is true and what the reader is expected to do -- nothing, until they feel like
        # it. This is the branch that replaces the nineteen [ERROR] lines a correct adoption used to produce.
        Write-Host 'roster-sessioncheck: this repo is set up; the roster and lenses are still to be filled in:'
        foreach ($line in $rosterPendingLines) { Write-Host "  $($line.Trim())" }
        # The same order-of-operations lines as the branches above: a reader about to fill in a roster should
        # know first if the plugin is not installed for this path or its record is shaped wrong.
        foreach ($line in $notInstalledLines) { Write-Host "  $($line.Trim())" }
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
    } elseif ($lensNamingLines.Count -gt 0) {
        # Its own verdict, and it sits here on purpose: below drift and the two setup states, above the
        # in-sync line. "Roster in sync" would be the wrong headline -- the check did not manage to read
        # the lens files at all -- and every verdict above it says the repo has something to do, which
        # this reader does not. The headline therefore names where the lag is, because that is the only
        # thing anybody can act on.
        Write-Host 'roster-sessioncheck: the roster looks correct; this check is reading it with an older naming than the repo uses:'
        foreach ($line in $lensNamingLines) { Write-Host "  $($line.Trim())" }
        # The same order-of-operations lines as the branches above. They matter more here than anywhere
        # else: the remedy for this state IS a plugin update, so a record that is not shaped the way an
        # update expects is the next thing the reader will walk into.
        foreach ($line in $notInstalledLines) { Write-Host "  $($line.Trim())" }
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
    } elseif ($nothingEnabledLines.Count -gt 0) {
        # Deliberately worded as what the check DID, not as a verdict about the repo: the honest answer
        # is that nothing was compared. A reader who did expect a plugin here now has the one fact that
        # explains it (which files were consulted), instead of a green line that hides the question.
        Write-Host 'roster-sessioncheck: no plugin is enabled for this repo -- the roster was not checked:'
        foreach ($line in $nothingEnabledLines) { Write-Host "  $($line.Trim())" }
    } elseif ($notInstalledLines.Count -gt 0) {
        # Its own verdict, above the in-sync line and below drift: the roster may well be in sync, but
        # saying so as the headline answers a question nobody is in a position to care about yet. What the
        # reader needs first is that a plugin they enabled is not loading here.
        Write-Host 'roster-sessioncheck: a plugin is enabled for this repo but not installed for this path:'
        foreach ($line in $notInstalledLines) { Write-Host "  $($line.Trim())" }
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
    } elseif ($recordShapeLines.Count -gt 0) {
        # Its own verdict, and this is the branch the marker exists for. On an exit-0 run with no drift it
        # would otherwise fall through to 'roster in sync with the enabled plugins' -- literally true, since
        # no specialist is missing, and for this reader the single most misleading thing the hook could say:
        # the one state nothing else on the machine reports would arrive dressed as a clean bill of health.
        # Same argument that gave [BOOTSTRAP] its own line, and the reason the pattern's recipe insists on
        # one rather than folding a new marker under an existing verdict.
        #
        # IT NAMES THE OBSERVATION AND DEFERS THE VERDICT, exactly as the roll-up beneath it does since
        # inbound #1130 -- and this is the line that made that repair incomplete on its own. It read "but
        # its record is not the shape the docs assume", which is the same unconditional claim, one line
        # ABOVE the roll-up and therefore the first thing a session reader meets. Repairing only the
        # check's headline would have left the contradiction with the 'pathless-only' arm verbatim in the
        # output #1130 was actually looking at.
        Write-Host 'roster-sessioncheck: the plugin is installed here and its install record differs from the shape the docs assume -- the lines below say whether that needs action:'
        foreach ($line in $recordShapeLines) { Write-Host "  $($line.Trim())" }
    } elseif ($code -eq 0) {
        Write-Host 'roster-sessioncheck: roster in sync with the enabled plugins.'
        # The in-sync line is literally true -- no specialist is missing -- but an orphan left behind is
        # still something to know, and it would otherwise be swallowed by exactly that reassurance.
        foreach ($line in $orphanLines) { Write-Host "  $($line.Trim())" }
        if ($orphanLines.Count -gt 0) {
            # Same handover as the drift branch above, in the same words and for the same reason: this is
            # a SessionStart hook, so the reader is the model, and 'sync-roster' is barred to it.
            Write-Host '  (run /dkj-subagents-alpha:sync-roster to stage the catch-up -- that command must be'
            Write-Host '   TYPED by the repo owner: the skill is reserved for explicit user invocation.)'
        }
    } else {
        Write-Host "roster-sessioncheck: the roster check could not complete (exit $code)."
    }
} catch {
    # THE STRIP IS INLINED HERE, DELIBERATELY, AND IS NOT A CALL TO Format-SafeProseToken (#2271).
    # This is the hook's last-resort catch, and hook-check-lib.ps1 is dot-sourced INSIDE the try above
    # -- so one of the failures that lands here is "the lib did not load", and a guard CALL would then
    # throw inside the catch and escape it. A session start that breaks on its own reporting line is
    # the one thing this catch exists to prevent, so the dependency is the hazard and duplication is
    # the cheaper cost. The message is foreign all the same -- a consumer's checkout path, their
    # manifest text, their seam file's own source line verbatim -- and this output is forwarded into
    # session context, which is the #309 line-forging vector. Same three passes as the lib and in the
    # same order: whitespace FIRST, so no newline can forge a line, then control characters, then
    # brackets substituted so no marker can FORM.
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('roster-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
