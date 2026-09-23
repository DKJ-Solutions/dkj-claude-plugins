<#
.SYNOPSIS
    check-plugin-integrity.ps1, printed commands: check 11 (printed lifecycle commands carry their
    flags), check 12 (printed install-record queries name the disambiguating fields) and scenario 33 --
    a root document nobody named is still scanned by both.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file.

    This file used to carry checks 31, 33, 34, 37, 41 and 44 and the shared script-set scenarios as
    well, and at 498.3s on CI it was the gate's critical path once -docs and -links had been split
    (#2304). Those now live in -script-rules, -script-set and -fixture-guard.

    The class these guard is the one three adoption rounds in a row kept producing: a doc printing a
    command that no longer holds, failing silently when copied. The ordering is deliberate -- first the
    two rules, then the DISCRIMINATOR (a bare mention must never be flagged, the over-detection that
    forced check 10 to be opt-in), then the two real bugs the check hit while being built, then the
    exclusions.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-commands-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- check 11: printed lifecycle commands carry their flags --------------------------------------
    # The class three adoption rounds in a row kept producing: a doc place printing a command that no
    # longer holds. The cases below are ordered by what they protect -- first the two rules, then the
    # DISCRIMINATOR (a bare mention must never be flagged; that over-detection is what forced check 10
    # to be opt-in), then the two real bugs this check hit while being built, then the exclusions.
    #
    # Matched on the error phrase, not the bare '[lifecycle]' tag: that tag also prefixes the coverage
    # line, which is present on every run. Same trap the check 10 pattern documents (in -skill-spans).
    $LifecycleFindingPattern = "\[lifecycle\].*printed 'claude plugin"

    # --- Scenario 17: a correctly printed install passes ---------------------------------------------
    Write-Host "check 11 -- refresh + install + scope flag reports nothing" -ForegroundColor Cyan
    $s17Lines = @(
        '# Contributing'
        ''
        'From the root of your repo:'
        ''
        '```powershell'
        'claude plugin marketplace update dkj-claude-plugins'
        'claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project'
        '```'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s17Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL17 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL17.Out -match $LifecycleFindingPattern)) 'scenario 17: a complete install block reports no [lifecycle] finding'
    Assert-True ($rL17.Out -match '\[lifecycle\] checked [1-9]') 'scenario 17: and the command WAS examined -- the pass is not an empty scan'

    # --- Scenario 18: a targeted install without --scope project fails -------------------------------
    #     Fails silently in reality: the scopeless install writes a machine-wide record with no
    #     projectPath and still reports success (inbound #274/#279).
    Write-Host "check 11 -- a targeted install without --scope project fails" -ForegroundColor Cyan
    $s18Lines = @(
        '# Contributing'
        ''
        'Run `claude plugin install dkj-subagents-alpha@dkj-claude-plugins` from the repo root.'
        ''
        'Refresh first with `claude plugin marketplace update dkj-claude-plugins`.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s18Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL18 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rL18.Code 'scenario 18: exit 1 -- a missing scope flag is an error'
    Assert-True ($rL18.Out -match [regex]::Escape('CONTRIBUTING.md:3') + ".*no '--scope project'") 'scenario 18: the finding names the file and the line'
    Assert-True (-not ($rL18.Out -match 'nor a link')) 'scenario 18: and NOT the refresh rule -- that one is satisfied two lines below'

    # --- Scenario 19: a targeted install with no refresh named nearby fails --------------------------
    Write-Host "check 11 -- a targeted install with no refresh nearby fails" -ForegroundColor Cyan
    $s19Lines = @(
        '# Contributing'
        ''
        'Run `claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project` from the root.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s19Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL19 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rL19.Code 'scenario 19: exit 1 -- a missing refresh is an error'
    Assert-True ($rL19.Out -match [regex]::Escape('CONTRIBUTING.md:3') + '.*nor a link') 'scenario 19: the refresh rule fires, naming file and line'
    Assert-True (-not ($rL19.Out -match "no '--scope project'")) 'scenario 19: and NOT the scope rule -- the flag is present'

    # --- Scenario 20 (THE DISCRIMINATOR): a bare mention is never flagged ----------------------------
    #     Prose discussing the command carries no @-target, and demanding flags there would be
    #     nonsense. This is the case that decides whether the check can be a generic scan at all: the
    #     147-hit over-detection measured on check 10 is what made THAT one opt-in.
    Write-Host "check 11 -- a bare mention in prose is NOT flagged (the over-detection guard)" -ForegroundColor Cyan
    $s20Lines = @(
        '# Contributing'
        ''
        'Note that `claude plugin update` defaults to user scope, and so does `claude plugin install`.'
        'Because `claude plugin update` pins the cache to a version, the card is always exact.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s20Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL20 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL20.Out -match $LifecycleFindingPattern)) 'scenario 20: three bare mentions, zero findings -- discussion is not instruction'
    Assert-True ($rL20.Out -match '\[lifecycle\] checked 0') 'scenario 20: they are counted as skipped, not as enforced'
    Assert-True ($rL20.Out -match 'bare mention|nothing to enforce') 'scenario 20: and the skip is stated rather than silent'

    # --- Scenario 21: a command WRAPPED across a newline inside one inline-code span -----------------
    #     Regression guard. The first build of this check was line-based and called the teardown
    #     SKILL's own `claude plugin uninstall ...` / `--scope project` pair a violation, because the
    #     flag sits on the next line of the same span.
    Write-Host "check 11 -- a command wrapped across lines in one inline span keeps its flag" -ForegroundColor Cyan
    $s21Lines = @(
        '# Contributing'
        ''
        'Removing it is a separate step: `claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins'
        '--scope project`, run from the repo root.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s21Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL21 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL21.Out -match $LifecycleFindingPattern)) 'scenario 21: the wrapped span is read as one command, flag included'

    # --- Scenario 22: a fenced block earlier in the file must not shift span pairing -----------------
    #     The second real bug: without fence masking, a ```-delimiter starts a phantom inline span and
    #     every real span downstream pairs one position out -- so scenario 21's command silently looked
    #     flagless. A silent misread, not an error, which is why it gets its own case.
    Write-Host 'check 11 -- a fenced code block earlier in the file does not break span pairing' -ForegroundColor Cyan
    $s22Lines = @(
        '# Contributing'
        ''
        '```powershell'
        'Write-Host "an unrelated example"'
        '```'
        ''
        'Removing it: `claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins'
        '--scope project`, from the root.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s22Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL22 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL22.Out -match $LifecycleFindingPattern)) 'scenario 22: the fence is masked, so the wrapped span downstream is still read correctly'

    # --- Scenario 23: uninstall needs the scope flag, and is exempt from the refresh -----------------
    #     Asymmetric on purpose: a stale cache cannot affect a removal.
    Write-Host "check 11 -- uninstall needs the scope flag but not the refresh" -ForegroundColor Cyan
    $s23Lines = @(
        '# Contributing'
        ''
        'Afterwards run `claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins` to detach.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s23Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL23 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rL23.Out -match [regex]::Escape('CONTRIBUTING.md:3') + ".*no '--scope project'") 'scenario 23: a scopeless uninstall is still an error'
    Assert-True (-not ($rL23.Out -match 'nor a link')) 'scenario 23: but the refresh is never demanded of an uninstall'

    # --- Scenario 24: history is excluded, permanently and on purpose -------------------------------
    #     CHANGELOG.md and the release notes record what was true at the time and are never rewritten.
    #     The real repo proves the need: specialists/CHANGELOG.md prints a targeted install with no
    #     scope flag, correctly, because that is what the release it describes actually said.
    Write-Host "check 11 -- a lifecycle command in CHANGELOG.md history is not flagged" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s24Contributing -join "`n") + "`n"), $Utf8NoBom)
    $s24Changelog = @(
        '# Changelog'
        ''
        'The install back then was `claude plugin install dkj-subagents-alpha@dkj-claude-plugins`, with no'
        'scope flag and no refresh -- which is exactly what that release documented.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'dkj-policy\CHANGELOG.md'), (($s24Changelog -join "`n") + "`n"), $Utf8NoBom)
    $rL24 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL24.Out -match $LifecycleFindingPattern)) 'scenario 24: history is not held to the current rules'
    Assert-True ($rL24.Out -match '\[lifecycle\] checked 0') 'scenario 24: the history command was not even counted as enforced'

    # --- Scenario 25: two commands with the SAME verb in one span are judged separately --------------
    #     Victor's review finding on the check itself: the tail was originally taken from
    #     IndexOf($verb) in the span, so a second `install` in the same span was judged on the FIRST
    #     one's arguments -- a scopeless command reading as flagged correctly. The offset now comes from
    #     the match position. The first command here is complete, the second is not, and only the second
    #     may be reported.
    Write-Host 'check 11 -- two same-verb commands in one span are judged on their own arguments' -ForegroundColor Cyan
    $s25Lines = @(
        '# Contributing'
        ''
        'Refresh with `claude plugin marketplace update dkj-claude-plugins` first.'
        ''
        'Then `claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project ; claude plugin install dkj-subagents-ecomm@dkj-claude-plugins` for both.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s25Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL25 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rL25.Out -match [regex]::Escape('CONTRIBUTING.md:5') + ".*no '--scope project'") 'scenario 25: the second, scopeless install IS reported'
    Assert-Equal 1 (@([regex]::Matches($rL25.Out, "no '--scope project'")).Count) 'scenario 25: and exactly once -- the first command is complete and must not be flagged too'

    # --- Scenario 26: `uninstall --scope local` passes -- the verb-specific exception ----------------
    #     Round v8 (inbound #314/#315) measured that a SESSION START can leave a record at
    #     `scope=local`, and that `claude plugin uninstall ... --scope project` refuses to remove one
    #     ("installed in local scope, not project"). So `--scope local` is the only command that does the
    #     job, and a gate demanding `project` here would reject the correct instruction -- enforcing the
    #     very assumption that round disproved. This is the case that keeps that fix documentable.
    Write-Host 'check 11 -- uninstall at --scope local passes (the state a session start leaves)' -ForegroundColor Cyan
    $s26Lines = @(
        '# Contributing'
        ''
        'Remove a record a session start left behind with'
        '`claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins --scope local`, then re-install.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s26Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL26 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rL26.Out -match $LifecycleFindingPattern)) 'scenario 26: a local-scoped uninstall is accepted'
    Assert-True ($rL26.Out -match '\[lifecycle\] checked [1-9]') 'scenario 26: and it WAS examined -- the pass is not an empty scan'

    # --- Scenario 27: the exception is verb-specific -- `install --scope local` still fails ----------
    #     The guard case that must ship with scenario 26, or the widening quietly becomes global. Nothing
    #     measured says a `local` INSTALL is ever what a reader wants; only the removal needs it.
    Write-Host 'check 11 -- install at --scope local is still an error (the exception is uninstall-only)' -ForegroundColor Cyan
    $s27Lines = @(
        '# Contributing'
        ''
        'Refresh with `claude plugin marketplace update dkj-claude-plugins` first.'
        ''
        'Then run `claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope local` from the root.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s27Lines -join "`n") + "`n"), $Utf8NoBom)
    $rL27 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rL27.Code 'scenario 27: exit 1 -- local scope does not satisfy the rule for install'
    Assert-True ($rL27.Out -match [regex]::Escape('CONTRIBUTING.md:5') + ".*no '--scope project'") 'scenario 27: the finding names the file and the line'
    Assert-True (-not ($rL27.Out -match 'nor a link')) 'scenario 27: and NOT the refresh rule -- that one is satisfied above'

    # --- check 12: a printed install-record query names the disambiguating fields ------------------
    # The class behind all three findings of round v8 rather than any one of them. Ordered like check 11's
    # block: the rule first, then the DISCRIMINATOR (an illustration must never be flagged), then the
    # exclusion that keeps prose out.
    $RecordQueryFindingPattern = "\[record-query\].*does not name"
    # The complete query, as both real docs now print it. Reused across the cases below with one field
    # removed at a time, so each case differs from the passing one in exactly one way.
    $rqFull = @(
        '```powershell'
        '$root = (Get-Location).Path'
        '(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |'
        '  ForEach-Object { $n = $_.Name; $_.Value | Where-Object { $_.projectPath -eq $root } |'
        '    ForEach-Object { "$n -> $($_.scope) $($_.version) $($_.gitCommitSha)" } }'
        '```'
    )

    # --- Scenario 28: the complete query passes, and WAS examined ------------------------------------
    Write-Host 'check 12 -- a query naming all four fields reports nothing' -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), ((@('# Contributing', '') + $rqFull) -join "`n") + "`n", $Utf8NoBom)
    $rQ28 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rQ28.Out -match $RecordQueryFindingPattern)) 'scenario 28: the complete query is accepted'
    Assert-True ($rQ28.Out -match '\[record-query\] checked [1-9]') 'scenario 28: and it WAS examined -- the pass is not an empty scan'

    # --- Scenario 29: a query without gitCommitSha fails (THE #313 CASE) ----------------------------
    #     The field whose absence let a consumer run main while every documented way of asking said 3.0.8.
    Write-Host 'check 12 -- a query without gitCommitSha fails (inbound #313)' -ForegroundColor Cyan
    $rq29 = @($rqFull) -replace ' \$\(\$_\.gitCommitSha\)', ''
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), ((@('# Contributing', '') + $rq29) -join "`n") + "`n", $Utf8NoBom)
    $rQ29 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rQ29.Code 'scenario 29: exit 1 -- a missing field is an error'
    # Line 4, not 3: the fence delimiter sits on line 3, and the anchor is the first line INSIDE it --
    # where the reader's eye has to go to fix the query.
    Assert-True ($rQ29.Out -match [regex]::Escape('CONTRIBUTING.md:4') + ".*does not name 'gitCommitSha'") 'scenario 29: the finding names the file, the first line INSIDE the fence, and the missing field'
    # The "does not name" clause lists ONLY what is missing. The message then goes on to name all four
    # required fields as context, deliberately, so the assertion pins the clause rather than the whole line.
    Assert-True ($rQ29.Out -match "does not name 'gitCommitSha'\.") 'scenario 29: the clause ends after the one missing field'
    Assert-True (-not ($rQ29.Out -match "does not name 'scope'")) 'scenario 29: the fields that ARE present are not reported as missing'

    # --- Scenario 30: a query without projectPath fails (the claude-plugin-list mistake) -----------
    #     Required rather than assumed: without it the query reports records beyond this repo, which is
    #     precisely the defect both documents spend a paragraph warning against. A doc printing that would
    #     be reproducing the mistake it warns about.
    Write-Host 'check 12 -- a query without projectPath fails (it would report other repos)' -ForegroundColor Cyan
    $rq30 = @(
        '```powershell'
        '(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |'
        '  ForEach-Object { $n = $_.Name; $_.Value | ForEach-Object { "$n -> $($_.scope) $($_.version) $($_.gitCommitSha)" } }'
        '```'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), ((@('# Contributing', '') + $rq30) -join "`n") + "`n", $Utf8NoBom)
    $rQ30 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rQ30.Code 'scenario 30: exit 1'
    Assert-True ($rQ30.Out -match "does not name 'projectPath'") 'scenario 30: the missing filter is the finding'
    Assert-True ($rQ30.Out -match 'claude plugin list') 'scenario 30: and the message says WHY, by naming the mistake it reproduces'

    # --- Scenario 31 (THE DISCRIMINATOR): a JSON illustration is not a subject ----------------------
    #     It names the same fields and is not a command anyone reads a verdict off. Same mention-versus-use
    #     question check 11 answers with its @-target, and the third time this repo has had to answer it.
    #     Without this case the check would forbid documenting the file's own shape.
    Write-Host 'check 12 -- a fenced JSON snippet illustrating the file is NOT flagged' -ForegroundColor Cyan
    $rq31 = @(
        '# Contributing'
        ''
        'A record in `installed_plugins.json` looks like this:'
        ''
        '```json'
        '{ "plugins": { "dkj-subagents-alpha@dkj-claude-plugins": ['
        '  { "scope": "project", "version": "3.0.8", "projectPath": "C:\\repo" } ] } }'
        '```'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($rq31 -join "`n") + "`n"), $Utf8NoBom)
    $rQ31 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rQ31.Out -match $RecordQueryFindingPattern)) 'scenario 31: an illustration is not held to the query rule, even though it lacks gitCommitSha'
    Assert-True ($rQ31.Out -match '\[record-query\] checked 0') 'scenario 31: and it is counted as skipped, not as enforced'
    Assert-True ($rQ31.Out -match 'skipped as illustration') 'scenario 31: the skip is STATED -- an empty scan must not read as "the docs are right"'

    # --- Scenario 32: a prose mention outside any fence is not a subject either ---------------------
    Write-Host 'check 12 -- prose naming the file is not a subject' -ForegroundColor Cyan
    $rq32 = @(
        '# Contributing'
        ''
        'Your version is written down in `installed_plugins.json` and nowhere else; the install'
        'success line names no version at all.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($rq32 -join "`n") + "`n"), $Utf8NoBom)
    $rQ32 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rQ32.Out -match $RecordQueryFindingPattern)) 'scenario 32: prose discussing the file is never an instruction'
    Assert-True ($rQ32.Out -match '\[record-query\] checked 0') 'scenario 32: nothing enforced'

    # --- Scenario 33: a NEW consumer-facing doc is in the scan set without being named ---------------
    #     The scan set for checks 11 and 12 (and the dead-link scan) used to be a hardcoded list of two
    #     family docs, 'README.md' and 'QUICKSTART.md'. UNINSTALL.md was then written beside them and no
    #     gate saw it -- a brand-new consumer-facing page printing exactly the class of command these two
    #     checks exist to police, invisible on the run that introduced it. #103 had closed the same gap by
    #     ADDING the two names, which is why a third name would have repeated the fix instead of closing
    #     the class: such a list is only ever correct until the next document is written, and nothing
    #     announces the omission.
    #
    #     So the assertion is deliberately about a file this suite has never heard of either. Its name is
    #     arbitrary on purpose -- if this scenario ever has to be updated because a real doc got that
    #     name, the enumeration has stopped being an enumeration.
    #
    #     THE SUBJECT SITS IN THE ROOT SINCE #405, because that is where the class lives now. Flattening
    #     moved QUICKSTART.md, UNINSTALL.md and the family README into the repo root, so the next
    #     consumer-facing page will be written there rather than in a family directory -- and a scenario
    #     testing the old directory would have gone on passing while the real gap reopened one level up.
    #     The named list this scenario exists to prevent is gone with it: the root carries the *.md glob.
    Write-Host 'scan set -- a root doc nobody named is still scanned (checks 11 + 12)' -ForegroundColor Cyan
    $s33Path = Join-Path $Fixture 'ZZ-NEWLY-WRITTEN-PAGE.md'
    $s33 = @(
        '# A page written after the scan set was last touched'
        ''
        'Remove it again:'
        ''
        '```powershell'
        'claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins'
        '```'
    )
    [System.IO.File]::WriteAllText($s33Path, (($s33 -join "`n") + "`n"), $Utf8NoBom)
    $r33 = Invoke-Integrity -FixtureRoot $Fixture
    # NOT asserted on the exit code, and that is a measurement rather than an oversight. Run against the
    # pre-fix scan set this scenario's exit code was 1 either way, so `Assert-Equal 1 $r33.Code` passed in
    # both worlds -- a green that proves nothing, which is the exact failure mode this suite keeps
    # catching in the checks it tests. The discriminating assertions are the ones naming the file.
    Assert-True ($r33.Out -match [regex]::Escape('ZZ-NEWLY-WRITTEN-PAGE.md')) 'scenario 33: the finding names the file that no line of the scan set mentions'
    Assert-True ($r33.Out -match 'scope') 'scenario 33: and it is the scope rule that catches it'
    # The same file is a subject for check 12 as well, which is the half that would fail if the widening
    # had been applied to only one of the two checks that share $linkFiles.
    [System.IO.File]::WriteAllText($s33Path, ((@('# Still unnamed', '') + (@($rqFull) -replace ' \$\(\$_\.gitCommitSha\)', '')) -join "`n") + "`n", $Utf8NoBom)
    $r33b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r33b.Out -match [regex]::Escape('ZZ-NEWLY-WRITTEN-PAGE.md') + ".*does not name 'gitCommitSha'") 'scenario 33: check 12 reaches the same unnamed file'
    Remove-Item -LiteralPath $s33Path -Force
    # And the removal is itself asserted, so a later scenario cannot inherit a stray subject from this one.
    $r33c = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r33c.Out -match [regex]::Escape('ZZ-NEWLY-WRITTEN-PAGE.md'))) 'scenario 33: the fixture is left as it was found'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
