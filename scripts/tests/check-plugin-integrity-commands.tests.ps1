<#
.SYNOPSIS
    check-plugin-integrity.ps1, part 2 of 4: check 11 (printed lifecycle commands carry their flags),
    check 12 (printed install-record queries name the disambiguating fields), scenario 33 -- a root
    document nobody named is still scanned by both -- and the three script-reading checks that joined them
    since: check 31 (the Shopify CLI is never invoked bare), check 33 (printed instructions naming a
    model-barred skill), check 34 (a numbered section header is unique, ascending, and in one form) and
    check 37 (this file's own check list, against the headers it claims to enumerate).

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite is four files.

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
    # line, which is present on every run. Same trap the check 10 pattern above documents.
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


    # --- check 33: a printed instruction must not name a skill barred to its reader -------------------
    # The class #731 -> #734 repaired once and #1093/#1096 rediscovered from scratch a month later. The
    # fixture's skill-beta carries 'disable-model-invocation: true' and skill-alpha does not, which is
    # the pair every scenario below turns on: the SAME sentence about the two must come out differently.
    #
    # Matched on the error phrase rather than the bare '[barred-skill]' tag -- that tag also prefixes the
    # coverage line, which is present on every run. Same trap the check 10 and check 11 patterns document.
    $BarredFindingPattern = "\[barred-skill\].*tells its reader to run the"

    # --- Scenario 42: a printed message naming a BARRED skill fails ----------------------------------
    Write-Host "check 33 -- a printed instruction naming a barred skill fails" -ForegroundColor Cyan
    $s42Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  [STOP] nothing is set up here -- run the skill-beta skill first."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s42Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB42 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rB42.Code 'scenario 42: exit 1 -- naming a barred skill is an error'
    Assert-True ($rB42.Out -match [regex]::Escape('probe.ps1:2') + ".*tells its reader to run the 'skill-beta' skill") 'scenario 42: the finding names the file, the line and the skill'
    Assert-True ($rB42.Out -match '/skill-beta') 'scenario 42: and hands over the slash-command form as the remedy'
    Assert-True ($rB42.Out -match '\[barred-skill\] checked [1-9]') 'scenario 42: and the set WAS examined -- the failure is not an empty scan'

    # --- Scenario 43: the SAME sentence about an UNFLAGGED skill passes ------------------------------
    #     The scenario that keeps this from being a phrasing rule. check-script-contract.ps1 names
    #     'adopt-dkj-policy' with exactly this wording in the real tree and is correct to; a check
    #     built as a grep for the phrasing would be born with that false finding.
    Write-Host "check 33 -- the same wording about an UNFLAGGED skill passes" -ForegroundColor Cyan
    $s43Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  [STOP] nothing is set up here -- run the skill-alpha skill first."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s43Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB43 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB43.Out -match $BarredFindingPattern)) 'scenario 43: an unflagged skill may be named with a bare imperative'

    # --- Scenario 44: the DISCRIMINATOR -- an imperative without the word 'skill' passes -------------
    #     Measured on the real tree: without this, 8 unique sites of which 4 are wrong. Three of the four
    #     name the SCRIPT rather than the skill, which is a correct instruction to a reader who has just
    #     run it.
    Write-Host "check 33 -- naming the script rather than the skill passes" -ForegroundColor Cyan
    $s44Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  that push failed -- run skill-beta by hand for the reason."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s44Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB44 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB44.Out -match $BarredFindingPattern)) 'scenario 44: without the word "skill" it is a script name, not a route to a page'

    # --- Scenario 45: a HYPHENATED continuation is not the barred name ------------------------------
    #     The false finding the naive rule really produced: '\bpark\b' matches inside 'park-cycle',
    #     because a hyphen is a non-word character. The check's own boundary is (?![\w-]).
    Write-Host "check 33 -- a longer hyphenated name is not the barred one" -ForegroundColor Cyan
    $s45Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  run the skill-beta-helper skill to finish up."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s45Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB45 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB45.Out -match $BarredFindingPattern)) 'scenario 45: skill-beta-helper is a different name, not skill-beta with a suffix'

    # --- Scenario 46: a COMMENT carrying the wording passes ------------------------------------------
    #     The reason this reads the PowerShell parser instead of matching lines: every comment explaining
    #     the rule -- check 33's own included -- has to quote the wording it forbids.
    Write-Host "check 33 -- the same wording in a COMMENT is not an instruction" -ForegroundColor Cyan
    $s46Lines = @(
        '$ErrorActionPreference = ''Stop'''
        '# This used to say "run the skill-beta skill", which is the defect this comment records.'
        'Write-Host "  nothing to do here."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s46Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB46 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB46.Out -match $BarredFindingPattern)) 'scenario 46: a comment is not printed output, so it is not a subject'

    # --- Scenario 47: MARKDOWN is a subject too ------------------------------------------------------
    #     Measured: printed output carried 6 of the 7 real sites and INSTALL.md the seventh -- the one a
    #     consumer actually reads. An output-only check would have passed straight over it.
    Write-Host "check 33 -- a shipped markdown page is a subject as well" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), "`$ErrorActionPreference = 'Stop'`n", $Utf8NoBom)
    $s47Lines = @(
        '# Contributing'
        ''
        'When the roster drifts, run the `skill-beta` skill to stage the catch-up.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s47Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB47 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rB47.Code 'scenario 47: exit 1 -- a shipped page may not name a barred skill either'
    Assert-True ($rB47.Out -match [regex]::Escape('CONTRIBUTING.md:3') + ".*'skill-beta'") 'scenario 47: the finding names the markdown file and its line'

    # --- Scenario 48: the REPAIRED wording passes ----------------------------------------------------
    #     The shape every one of the seven real sites was rewritten into, asserted so the check and the
    #     repair cannot drift apart: name the command, and say who types it.
    Write-Host "check 33 -- the repaired wording passes" -ForegroundColor Cyan
    $s48Lines = @(
        '# Contributing'
        ''
        'When the roster drifts, type `/dkj-subagents-alpha:skill-beta` to stage the catch-up -- that command is'
        'reserved for explicit user invocation, so a session hands it to you rather than running it.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s48Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB48 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB48.Out -match $BarredFindingPattern)) 'scenario 48: naming the command and the actor is what the check asks for'
    Remove-Item -LiteralPath (Join-Path $Fixture 'scripts\probe.ps1') -Force -ErrorAction SilentlyContinue


    # --- Scenario 49: a FENCED example is an illustration, not an instruction ------------------------
    #     How this exclusion was found: the branch that added check 33 quotes the forbidden wording in its
    #     own plan in order to explain what the check forbids, and the gate refused to push it. A rule that
    #     cannot be written down in the document introducing it is a rule nobody can explain. Checks 10 and
    #     11 mask fences for the same reason, and this borrows their Get-FenceMaskedText.
    Write-Host "check 33 -- a fenced example of the wording is not an instruction" -ForegroundColor Cyan
    $s49Lines = @(
        '# Contributing'
        ''
        'Do not write this:'
        ''
        '```text'
        'run the skill-beta skill to stage the catch-up'
        '```'
        ''
        'Write the command and say who types it instead.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s49Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB49 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB49.Out -match $BarredFindingPattern)) 'scenario 49: a fenced example is masked, so the rule can be written down'

    # --- Scenario 50: HISTORY is excluded ------------------------------------------------------------
    #     Check 11's exclusion, inherited with its file set: CHANGELOG.md records what was true then and is
    #     never rewritten, so a released note describing the old wording must not become a finding. Asserted
    #     rather than assumed, because the set is borrowed and a later narrowing of check 11's would move
    #     this check in silence.
    Write-Host "check 33 -- history is not rewritten, so it is not a subject" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), "# Contributing`n`nNothing here.`n", $Utf8NoBom)
    $s50Path = Join-Path $Fixture 'dkj-policy\CHANGELOG.md'
    $s50Prev = if (Test-Path -LiteralPath $s50Path) { [System.IO.File]::ReadAllText($s50Path, [System.Text.Encoding]::UTF8) } else { $null }
    $s50Lines = @(
        '# Changelog'
        ''
        '## [Unreleased]'
        ''
        'The line then read: run the skill-beta skill to stage the catch-up.'
    )
    [System.IO.File]::WriteAllText($s50Path, (($s50Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB50 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB50.Out -match $BarredFindingPattern)) 'scenario 50: the changelog records the old wording and is never rewritten'
    if ($null -ne $s50Prev) { [System.IO.File]::WriteAllText($s50Path, $s50Prev, $Utf8NoBom) } else { Remove-Item -LiteralPath $s50Path -Force -ErrorAction SilentlyContinue }


    # --- check 31: the Shopify CLI is never invoked bare ---------------------------------------------
    #     Inbound #1183. Under $ErrorActionPreference = 'Stop' -- which every script here sets -- one
    #     stderr line from the CLI is a TERMINATING ErrorRecord, so a bare call dies on the line AFTER it
    #     and the $LASTEXITCODE check below it never runs. The wrapper is scripts/lib/shopify-cli-lib.ps1;
    #     what this check exists for is that THE DANGEROUS FORM IS THE ABSENCE OF ONE -- there is no
    #     redirect to grep for, so a convention alone produced four bare sites before anybody noticed.
    #
    #     Matched on the error phrase rather than the bare '[shopify-cli]' tag: that tag also prefixes the
    #     coverage line, which is present on every run. Same trap the two patterns above document.
    $ShopifyFindingPattern = '\[shopify-cli\].*invokes the Shopify CLI bare'
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\task') -Force | Out-Null

    # --- Scenario 51: a bare call is a finding, and it names the line --------------------------------
    Write-Host "check 31 -- a bare '& shopify' call is reported with its line" -ForegroundColor Cyan
    $s51Path  = Join-Path $Fixture 'scripts\task\sync-something.ps1'
    $s51Lines = @(
        '$ErrorActionPreference = ''Stop'''
        '# A comment naming shopify theme list must NOT be a subject -- only a CommandAst is.'
        'Write-Host "run: shopify theme list --store x"'
        '& shopify theme pull --store x --theme 1 --path y'
        'if ($LASTEXITCODE -ne 0) { exit 1 }'
    )
    [System.IO.File]::WriteAllText($s51Path, (($s51Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC51 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC51.Out -match $ShopifyFindingPattern) 'scenario 51: the bare call is a finding'
    Assert-True ($rC51.Out -match 'sync-something\.ps1:4:') 'scenario 51: and it names the line the call is on, not the file alone'
    Assert-Equal 1 ([regex]::Matches($rC51.Out, $ShopifyFindingPattern).Count) 'scenario 51: the comment and the printed hint are NOT subjects -- exactly one finding'

    # --- Scenario 52: the wrapper itself is exempt, by name ------------------------------------------
    #     The one permitted bare call lives inside the wrapper, so the check would otherwise report the
    #     repair as the defect. Matched on the file NAME rather than a full path, which is what makes the
    #     plugin mirror exempt too -- the same file, one directory tree over, and check 8 already holds
    #     the two byte-identical.
    Write-Host "check 31 -- the wrapper holds the one permitted call and is exempt" -ForegroundColor Cyan
    Remove-Item -LiteralPath $s51Path -Force
    $s52Path = Join-Path $Fixture 'scripts\lib\shopify-cli-lib.ps1'
    [System.IO.File]::WriteAllText($s52Path, "function Invoke-ShopifyCli {`n    & shopify @args`n}`n", $Utf8NoBom)
    $rC52 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC52.Out -match $ShopifyFindingPattern)) 'scenario 52: the wrapper is not reported for holding the call it exists to hold'
    Remove-Item -LiteralPath $s52Path -Force


    # --- check 34: a numbered section header is unique, ascending, and in one form -------------------
    #     Issue #1494. Two unrelated checks in check-plugin-integrity.ps1 both carried the number 30, and
    #     both were already load-bearing in published release notes pointing at DIFFERENT checks. The
    #     numbers were prose -- hand-assigned, cited everywhere, read back by nothing -- in the one file
    #     whose purpose is refusing a hand-maintained list a machine could check.
    #
    #     THE HEADERS IN THIS SUITE ARE INDENTED ON PURPOSE, including the one directly above. Scenario
    #     separators inside a function are not file sections and carry their own numbering; scenario 57
    #     is the assert that keeps them out of the check's reach, so this suite is its own fixture for
    #     that bound.
    #
    #     Matched on the finding phrases rather than the bare '[section-number]' tag: that tag also
    #     prefixes the coverage line, which is present on every run. Same trap the three patterns above
    #     document.
    $SectionFindingPattern = '\[section-number\].*(is already used at line|no longer ascend|second form)'
    $s53Dir = Join-Path $Fixture 'scripts\task'
    New-Item -ItemType Directory -Path $s53Dir -Force | Out-Null

    # --- Scenario 53: two sections sharing a number is a finding, naming BOTH lines ------------------
    #     The measured defect itself. Naming only the second line would leave a reader to hunt for the
    #     first, which is the search that returned two answers in the first place.
    Write-Host "check 34 -- two sections sharing a number is a finding, at both lines" -ForegroundColor Cyan
    $s53Path  = Join-Path $s53Dir 'numbered-dupe.ps1'
    $s53Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 2. an unrelated thing that took a taken number ----------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s53Path, (($s53Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC53 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC53.Out -match 'section number 2 is already used at line 4') 'scenario 53: the duplicate is a finding and names the line the number was first used on'
    Assert-True ($rC53.Out -match 'numbered-dupe\.ps1:7:') 'scenario 53: and it is reported at the LATER of the two, which is the one that has to move'
    Assert-Equal 1 ([regex]::Matches($rC53.Out, $SectionFindingPattern).Count) 'scenario 53: one duplicate is one finding -- the ascending rule does not report it a second time'
    Remove-Item -LiteralPath $s53Path -Force

    # --- Scenario 54: a number that goes backwards is a finding --------------------------------------
    #     Ascending order is the property that leaves a new section exactly one legal number, so it is
    #     what prevents the duplicate rather than merely tidying the file. Renumbering a colliding check
    #     without moving it satisfies uniqueness and lands here instead, which is the case this asserts:
    #     it is what a repair of scenario 53 looks like if the block is left where it was.
    Write-Host "check 34 -- a section number that goes backwards is a finding" -ForegroundColor Cyan
    $s54Path  = Join-Path $s53Dir 'numbered-desc.ps1'
    $s54Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 9. renumbered out of the way but left where it sat ------------------'
        '$b = 2'
        ''
        '# --- 2. the section it was inserted above --------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s54Path, (($s54Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC54 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC54.Out -match 'section number 2 sits after 9 at line 4') 'scenario 54: the descent is a finding and names what it came after'
    Assert-True ($rC54.Out -match 'numbered-desc\.ps1:7:') 'scenario 54: reported at the header that broke the order'
    Remove-Item -LiteralPath $s54Path -Force

    # --- Scenario 55: the second spelling is a finding wherever it appears ---------------------------
    #     Four headers in the gate read '# --- Check <n>: ' where the rest read '# --- <n>. ', so no
    #     single pattern listed them all and the duplicate showed up in a grep of neither. Passing over
    #     an unrecognised spelling would let a file opt out of the numbering rule entirely.
    Write-Host "check 34 -- the second header spelling is a finding" -ForegroundColor Cyan
    $s55Path  = Join-Path $s53Dir 'numbered-form.ps1'
    $s55Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- Check 2: the same thing said the other way --------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s55Path, (($s55Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC55 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC55.Out -match 'numbered-form\.ps1:4:.*second form') 'scenario 55: the other spelling is reported, at its own line'
    Assert-True ($rC55.Out -match "Rewrite it as '# --- 2\. ") 'scenario 55: and the finding says what to write instead, in the legal form'
    Remove-Item -LiteralPath $s55Path -Force

    # --- Scenario 56: gaps and lettered sub-sections are legal ---------------------------------------
    #     Both are deliberate conventions in the gate: 9, 17 and 19 are retired checks whose numbers are
    #     NOT reused (reusing one would silently repoint every older citation), and 3b/3c/13b are
    #     sub-sections of the check above them. A rule that reported either would be the gate inventing a
    #     convention the repo declined -- the narrowing check 26 had to make for the same reason.
    Write-Host "check 34 -- a gap and a lettered sub-section are not findings" -ForegroundColor Cyan
    $s56Path  = Join-Path $s53Dir 'numbered-clean.ps1'
    $s56Lines = @(
        '# --- 3. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 3b. a sub-section of it ---------------------------------------------'
        '$b = 2'
        ''
        '# --- 3c. and another -----------------------------------------------------'
        '$c = 3'
        ''
        '# --- 7. after a gap where two retired checks stood ------------------------'
        '$d = 4'
        ''
        '# --- Report --------------------------------------------------------------'
        '$e = 5'
    )
    [System.IO.File]::WriteAllText($s56Path, (($s56Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC56 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC56.Out -match 'numbered-clean\.ps1')) 'scenario 56: a gap, three lettered sub-sections and an unnumbered terminator are all legal'
    Remove-Item -LiteralPath $s56Path -Force

    # --- Scenario 57: an INDENTED header is not a subject --------------------------------------------
    #     The bound the whole check rests on, and the one it would be easiest to get wrong: this suite
    #     and its three siblings use the same '# ---' marker indented inside a function to separate
    #     scenarios, under their own numbering, which restarts and repeats freely. Those are not file
    #     sections. Written as a fixture rather than left to the suites' own headers so the assert says
    #     what it is proving instead of depending on this file staying shaped as it is.
    Write-Host "check 34 -- an indented header belongs to its block, not to the file" -ForegroundColor Cyan
    $s57Path  = Join-Path $s53Dir 'numbered-indented.ps1'
    $s57Lines = @(
        'function Test-Something {'
        '    # --- 1. a scenario separator inside a function ------------------------'
        '    $a = 1'
        '    # --- 1. the same number again, one block down -------------------------'
        '    $b = 2'
        '    # --- Check 1: and in the other spelling -------------------------------'
        '    $c = 3'
        '}'
    )
    [System.IO.File]::WriteAllText($s57Path, (($s57Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC57 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC57.Out -match 'numbered-indented\.ps1')) 'scenario 57: three headers that would all be findings at column 0 are passed over when indented'
    Assert-True ($rC57.Out -match '\[section-number\] checked \d+') 'scenario 57: and the check still reports its coverage, so passing over is not the same as not running'
    Remove-Item -LiteralPath $s57Path -Force


    # --- check 37: this file's own check list, against the headers it claims to enumerate ------------
    #     Issue #1680. Check 34 holds the column-0 headers to EACH OTHER; nothing read the prose list in
    #     check-plugin-integrity.ps1's own .DESCRIPTION -- the summary a reader who has not opened the
    #     file consults, and the one a lens, a hook, a test name or a release note quotes a number from.
    #     It had stopped at 30 while the code ran to 36, its item 30 described the check #1494 had
    #     renumbered to 33, 13b was missing with no report having noticed, and 9 and 17 still read as
    #     live checks a month after they were retired.
    #
    #     THE MARKER IS COMPOSED, NEVER WRITTEN OUT, and that is not style. This suite is a .ps1 in the
    #     script set check 37 walks, so a literal marker in these fixture lines would open a span in the
    #     SUITE -- a file with no numbered headers of its own -- and the real gate run would report this
    #     file. Same self-fixturing trap scenario 57 documents for check 34's indented headers, arriving
    #     through the other door: there the suite has to prove the bound, here it has to stay outside it.
    $clTag   = 'checks:list'
    $clOpen  = "<!-- $clTag -->"
    $clClose = "<!-- /$clTag -->"
    #     Matched on the finding's PATH rather than on a phrase, and that is not a shortcut: this check's
    #     own coverage line -- present on every run -- contains the words "claims to enumerate them", so a
    #     phrase pattern counts the coverage line as a second finding. It did, on the first run of
    #     scenario 58. A finding opens with the repo-relative path; the coverage line opens with 'checked'.
    $ClFindingPattern = '\[check-list\] \.'
    $s58Dir = Join-Path $Fixture 'scripts\lint'
    New-Item -ItemType Directory -Path $s58Dir -Force | Out-Null

    # --- Scenario 58: a header with no entry in the list is a finding, naming both lines -------------
    #     The measured defect. Naming only the header would leave a reader to find the list; naming only
    #     the list would leave them to find which check is missing.
    Write-Host "check 37 -- a header absent from the marked list is a finding" -ForegroundColor Cyan
    $s58Path  = Join-Path $s58Dir 'listed-gap.ps1'
    $s58Lines = @(
        '<#'
        '.SYNOPSIS'
        '    A gate that says what it checks.'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. the second thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one nobody wrote down ---------------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s58Path, (($s58Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC58 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC58.Out -match 'listed-gap\.ps1:16:.*check 3 has a section header but no entry') 'scenario 58: the unlisted check is a finding, at the line its header sits on'
    Assert-True ($rC58.Out -match 'span at line 5') 'scenario 58: and it names the line the list opens on, so the reader has both ends'
    Assert-Equal 1 ([regex]::Matches($rC58.Out, $ClFindingPattern).Count) 'scenario 58: the two checks that ARE listed are not reported -- exactly one finding'
    Remove-Item -LiteralPath $s58Path -Force

    # --- Scenario 59: an entry with NO header is deliberately not a finding --------------------------
    #     The bound the whole check rests on, and the reason it could be born green. A retired check
    #     keeps its number as a tombstone (9 and 17 in the real gate), and the consumer-doc guard the
    #     suites call check 19 carries no header of its own. Asserting the reverse direction would have
    #     needed exactly those three as exemptions on the day it was written -- the shape this repo
    #     declined at 124 findings all false.
    Write-Host "check 37 -- an entry with no header of its own is not a finding" -ForegroundColor Cyan
    $s59Path  = Join-Path $s58Dir 'listed-tombstone.ps1'
    $s59Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. RETIRED, and its number is kept so older citations still mean this.'
        '      3. a guard the suites name but that carries no header of its own.'
        '      4. the last thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 4. after a gap where a retired check stood --------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s59Path, (($s59Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC59 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC59.Out -match 'listed-tombstone\.ps1')) 'scenario 59: two entries with no header -- a tombstone and a headerless guard -- are both legal'
    Remove-Item -LiteralPath $s59Path -Force

    # --- Scenario 60: a lettered sub-section needs its own entry -------------------------------------
    #     13b was the seventh missing entry and the one no report had noticed: it is a real check with a
    #     real header, and reading '13' as covering it would let a whole sub-section vanish from the
    #     summary. The key is the number AND the letter, exactly as check 34 reads it.
    Write-Host "check 37 -- a lettered sub-section is a header of its own" -ForegroundColor Cyan
    $s60Path  = Join-Path $s58Dir 'listed-lettered.ps1'
    $s60Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 1b. a sub-section of it ---------------------------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s60Path, (($s60Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC60 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC60.Out -match 'listed-lettered\.ps1:10:.*check 1b has a section header but no entry') 'scenario 60: the sub-section is a subject of its own, not covered by the number above it'
    Remove-Item -LiteralPath $s60Path -Force

    # --- Scenario 61: a list in a file with no headers at all is a finding ---------------------------
    #     Silence there would read as a pass. Either the headers were renamed out of the convention check
    #     34 holds, or the marker is on the wrong file; both are worth a sentence rather than a green run.
    Write-Host "check 37 -- a marked list in a file carrying no headers is a finding" -ForegroundColor Cyan
    $s61Path  = Join-Path $s58Dir 'listed-headerless.ps1'
    $s61Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. something this file has no header for.'
        "    $clClose"
        '#>'
        '$a = 1'
    )
    [System.IO.File]::WriteAllText($s61Path, (($s61Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC61 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC61.Out -match 'listed-headerless\.ps1:.*claims to') 'scenario 61: a list claiming to enumerate nothing is reported rather than passed over'
    Remove-Item -LiteralPath $s61Path -Force

    # --- Scenario 62: an unpaired marker is a hard error, and no marker at all is not a subject ------
    #     The first half is Invoke-MarkedSpanWalk's rule, asserted here for this category too: a typo'd
    #     sentinel must never read as "no list here", which is the one failure that turns a gate green by
    #     silencing it. The second half is what makes the check opt-in -- the 19 files check 34 measured
    #     carry numbered headers and claim to enumerate nothing, and none of them may be a finding.
    Write-Host "check 37 -- an unpaired marker is an error; no marker is not a subject" -ForegroundColor Cyan
    $s62Path  = Join-Path $s58Dir 'listed-unpaired.ps1'
    $s62Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
    )
    [System.IO.File]::WriteAllText($s62Path, (($s62Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC62 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC62.Out -match 'listed-unpaired\.ps1:.*has no matching') 'scenario 62: the opener without a closer is a hard error, not a silent skip'
    Remove-Item -LiteralPath $s62Path -Force

    $s62bPath  = Join-Path $s58Dir 'listed-unmarked.ps1'
    $s62bLines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s62bPath, (($s62bLines -join "`n") + "`n"), $Utf8NoBom)
    $rC62b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC62b.Out -match 'listed-unmarked\.ps1')) 'scenario 62: a file with headers and no marker claims nothing, so it is not a subject'
    Assert-True ($rC62b.Out -match '\[check-list\] checked \d+') 'scenario 62: and the check still reports its coverage, so opting out is not the same as not running'
    Remove-Item -LiteralPath $s62bPath -Force

    # --- Scenario 63: a nested enumeration inside an entry's prose is not a claim --------------------
    #     Found by PROBING the check rather than by measuring the tree -- the real list contains no such
    #     shape, so no measurement of it would have surfaced this (check 35's lesson, applied to its
    #     neighbour). A number opening a line is ordinary inside an entry's prose, and counting one as a
    #     claim silences the check exactly where it matters: the nested pair below would keep satisfying
    #     headers that had been dropped from the list, with the gate green.
    Write-Host "check 37 -- a number opening a line inside an entry's prose is not a claim" -ForegroundColor Cyan
    $s63Path  = Join-Path $s58Dir 'listed-nested.ps1'
    $s63Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. the second thing, which documents two cases of its own:'
        '         3. the first case -- indented past the gutter, so it is prose, not an entry.'
        '         4. the second case.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one the nested list would have covered for -------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s63Path, (($s63Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC63 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC63.Out -match 'listed-nested\.ps1:16:.*check 3 has a section header but no entry') 'scenario 63: the nested 3. does not satisfy header 3 -- the gap is still reported'
    Assert-Equal 1 ([regex]::Matches($rC63.Out, $ClFindingPattern).Count) 'scenario 63: and the nested 4., which matches no header, adds nothing -- exactly one finding'
    Remove-Item -LiteralPath $s63Path -Force

    # --- Scenario 64: two spans in one file are unioned and counted once -----------------------------
    #     Run inside the span callback this counted each header once PER SPAN, so a second span doubled
    #     the coverage figure and named one missing entry twice -- one defect, two owners, which is what
    #     the first-occurrence rule for headers already avoids. A split list still enumerates one file,
    #     so the union is the tolerant reading rather than an error of its own.
    Write-Host "check 37 -- two spans are read as one list, and a gap is named once" -ForegroundColor Cyan
    $s64Path  = Join-Path $s58Dir 'listed-twospans.ps1'
    $s64Lines = @(
        '<#'
        '.DESCRIPTION'
        '    The early checks:'
        "    $clOpen"
        '      1. the first thing.'
        "    $clClose"
        '    And the later ones:'
        "    $clOpen"
        '      2. the second thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one in neither span ------------------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s64Path, (($s64Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC64 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC64.Out, $ClFindingPattern).Count) 'scenario 64: the header in neither span is one finding, not one per span'
    Assert-True ($rC64.Out -match "any of this file's 2 'checks:list' spans \(lines 4, 8\)") 'scenario 64: and the finding names both spans, since either could hold the entry'
    Remove-Item -LiteralPath $s64Path -Force
    # --- check 41: the #1934 fixture load guard cannot be half-removed -------------------------------
    # THE CLASS: a fixture missing a lib the copied acting script dot-sources UNGUARDED kills the child
    # during LOAD, and the suite then reports the absence of the document it never wrote. #1934 wired six
    # suites in three parts and nothing asserted any of the three was still there.
    #
    # THE RULE IS SELF-ANCHORING, which is what these scenarios are really pinning: a file carrying ANY
    # part must carry all three. The alternative #1948 proposed -- flag any captured child invocation
    # with no verdict -- was measured at 71 findings over 82 invocations on the real tree and is #1954,
    # not this check. So the discriminator below (a suite carrying NONE of the parts) matters as much as
    # the findings: get it wrong and this check becomes that one.
    $FsFindingPattern = '\[fixture-script\] \.'
    $fsTests = Join-Path $Fixture 'scripts\tests'
    New-Item -ItemType Directory -Path $fsTests -Force | Out-Null
    $fsPath = Join-Path $fsTests 'wired.tests.ps1'

    # A fully wired suite, in the shape the six real ones take: the dot-source, the verdict at the
    # invocation, and the summary whose return becomes an exit code.
    $fsWiredLines = @(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        'function Invoke-Child {'
        '    $out = & powershell -NoProfile -File $script:child 2>&1'
        '    $code = $LASTEXITCODE'
        '    Assert-FixtureScriptLoaded -Code $code -Script $script:child -Output $out'
        '    return $code'
        '}'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        'if ($loadBroken) { exit 1 }'
    )

    Write-Host "check 41 -- a fully wired suite reports nothing" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, (($fsWiredLines -join "`n") + "`n"), $Utf8NoBom)
    $rC65 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC65.Out, $FsFindingPattern).Count) 'scenario 65: all three parts present and the summary read -- no finding'
    Assert-True ($rC65.Out -match '\[fixture-script\] checked \d+') 'scenario 65: and the check ran rather than being silently absent'

    # THE DISCRIMINATOR, and it is the whole boundary between this check and #1954. A suite that runs a
    # child with its output captured and carries NONE of the three parts is NOT a subject: 65 such suites
    # exist on the real tree, and reporting them is the 71-finding rule this check was built instead of.
    Write-Host "check 41 -- a suite carrying none of the parts is not a subject" -ForegroundColor Cyan
    $fsUnwired = Join-Path $fsTests 'unwired.tests.ps1'
    [System.IO.File]::WriteAllText($fsUnwired, (@(
        '$out = & powershell -NoProfile -File $child 2>&1'
        '$code = $LASTEXITCODE'
        'if ($code -ne 0) { Write-Host ''it failed'' }'
    ) -join "`n") + "`n", $Utf8NoBom)
    $rC66 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC66.Out, $FsFindingPattern).Count) 'scenario 66: an unwired suite that captures a child is not reported -- that is #1954, not this check'
    Remove-Item -LiteralPath $fsUnwired -Force

    # EACH PART, DROPPED ON ITS OWN. Three scenarios rather than one, because they fail differently and a
    # single "something is missing" assert would pass while naming the wrong part.
    Write-Host "check 41 -- each missing part is named" -ForegroundColor Cyan

    # The verdict dropped -- the #1948 hazard verbatim: an edit to the invocation helper removes the call.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'Assert-FixtureScriptLoaded' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC67 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC67.Out, $FsFindingPattern).Count) 'scenario 67: the dropped verdict is one finding'
    Assert-True ($rC67.Out -match 'not a call to Assert-FixtureScriptLoaded') 'scenario 67: and the finding names the part that is gone, not merely that one is'

    # The summary dropped -- the run then exits 0 on a load failure the asserts happened not to notice.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'Write-FixtureScriptSummary|loadBroken' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC68 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC68.Out, $FsFindingPattern).Count) 'scenario 68: the dropped summary is one finding'
    Assert-True ($rC68.Out -match 'not a call to Write-FixtureScriptSummary') 'scenario 68: and it is named'

    # The dot-source dropped. This one is the least likely to happen alone -- it makes the other two
    # unresolved commands -- but it is the cheapest to state and it closes the third direction.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'fixture-script-lib' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC69 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC69.Out, $FsFindingPattern).Count) 'scenario 69: the dropped dot-source is one finding'
    Assert-True ($rC69.Out -match 'not the dot-source of scripts/lib/fixture-script-lib\.ps1') 'scenario 69: and it is named'

    # THE FOURTH FACT, AND THE WORSE FAILURE OF THE TWO. All three parts present, and the summary's
    # verdict thrown away: the block still PRINTS, so the run says a child died on load and then exits 0
    # -- wearing the guard's own output as proof that it is wired. Three discard spellings, because a
    # check whose arms disagree about wrapping teaches the shape that gets past it (check 35's lesson).
    Write-Host "check 41 -- a summary whose verdict is discarded, in three spellings" -ForegroundColor Cyan
    foreach ($fsDiscard in @(
        @{ Label = 'Out-Null';   Line = 'Write-FixtureScriptSummary -Subject ''child.ps1'' | Out-Null' }
        @{ Label = 'a null assignment'; Line = '$null = Write-FixtureScriptSummary -Subject ''child.ps1''' }
        @{ Label = 'assigned but never read'; Line = '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1''' }
    )) {
        $fsLines = @(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            'function Invoke-Child {'
            '    $out = & powershell -NoProfile -File $script:child 2>&1'
            '    $code = $LASTEXITCODE'
            '    Assert-FixtureScriptLoaded -Code $code -Script $script:child -Output $out'
            '}'
            $fsDiscard.Line
        )
        [System.IO.File]::WriteAllText($fsPath, (($fsLines -join "`n") + "`n"), $Utf8NoBom)
        $rC70 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 1 ([regex]::Matches($rC70.Out, $FsFindingPattern).Count) "scenario 70/$($fsDiscard.Label): a verdict that is never read is a finding"
        Assert-True ($rC70.Out -match 'is never read, so nothing turns it into an exit code') "scenario 70/$($fsDiscard.Label): and the finding says what is missing rather than that the call is"
    }

    # AND A PAIR OF BRACKETS IS NOT AN ESCAPE HATCH -- the same property check 35 states, asserted here
    # because this check climbs the same wrapping and would otherwise be free to drift from it.
    Write-Host "check 41 -- brackets do not launder a discard" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '(Write-FixtureScriptSummary -Subject ''child.ps1'') | Out-Null'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC71 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC71.Out, $FsFindingPattern).Count) 'scenario 71: a parenthesised discard is still a discard'

    # AND THE READ IS COUNTED IN EVERY SHAPE THE TREE ACTUALLY USES, so a suite asserting the return
    # rather than storing it is not reported. fixture-script-lib.tests.ps1 does exactly this.
    Write-Host "check 41 -- a verdict consumed in place is a read" -ForegroundColor Cyan
    foreach ($fsRead in @(
        @{ Label = 'an if condition'; Line = 'if (Write-FixtureScriptSummary -Subject ''child.ps1'') { exit 1 }' }
        @{ Label = 'an argument';     Line = 'Assert-True (Write-FixtureScriptSummary -Subject ''child.ps1'') ''it said so''' }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            $fsRead.Line
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC72 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 0 ([regex]::Matches($rC72.Out, $FsFindingPattern).Count) "scenario 72/$($fsRead.Label): consuming the verdict in place is a read"
    }

    # A MENTION IS NOT A WIRING, which is why the dot-source is read through the AST and not by matching
    # the lib's name in the text. A file naming it in a comment or a string has adopted nothing, and
    # reporting it would send a reader to wire a suite that never ran a child at all.
    Write-Host "check 41 -- a bare mention of the lib is not a wiring" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '# This suite does not use fixture-script-lib.ps1 -- it runs no child process.'
        '$note = ''see scripts/lib/fixture-script-lib.ps1 for the load guard'''
        'Write-Host $note'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC73 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC73.Out, $FsFindingPattern).Count) 'scenario 73: a comment and a string naming the lib are not a dot-source'
    # THE FOUR PROBES THE CODE REVIEW RAN AGAINST THIS CHECK, pinned so the repairs cannot regress. Each
    # was a real answer the check gave before it was narrowed, and three of the four were FALSE NEGATIVES
    # -- the direction that matters for a guard whose whole subject is a guard that stopped guarding.
    Write-Host "check 41 -- the read search is scoped and ordered" -ForegroundColor Cyan

    # (a) A REFERENCE BEFORE THE ASSIGNMENT is a different variable's life, and used to clear the dead
    #     assignment that followed it.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'if ($loadBroken) { Write-Host ''stale reference to a variable that does not exist yet'' }'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC74 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC74.Out, $FsFindingPattern).Count) 'scenario 74: a reference BEFORE the assignment does not clear it'

    # (b) THE SAME NAME IN AN UNRELATED FUNCTION used to clear a dead file-scope assignment. PowerShell
    #     scopes by runtime lookup, so the two are genuinely different values.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'function Test-Unrelated {'
        '    $loadBroken = $true'
        '    if ($loadBroken) { Write-Host ''this is a different variable entirely'' }'
        '}'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC75 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC75.Out, $FsFindingPattern).Count) 'scenario 75: the same name inside an unrelated function does not clear a file-scope assignment'

    # (c) AND THE MIRROR OF (b): a read in the SAME function still clears, so the narrowing did not turn
    #     into a false positive on a suite that wires its guard inside a helper.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        'function Complete-Suite {'
        '    $out = & powershell -NoProfile -File $child 2>&1'
        '    Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '    $loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        '    if ($loadBroken) { exit 1 }'
        '}'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC76 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC76.Out, $FsFindingPattern).Count) 'scenario 76: a read in the SAME function still clears -- the narrowing is not a false positive'

    # (d) A VERDICT HANDED BACK BY A FUNCTION is not discarded, in both spellings. This was a false
    #     POSITIVE: the call is the last statement of the body, which is PowerShell's implicit return.
    Write-Host "check 41 -- a verdict handed back by a function is not a discard" -ForegroundColor Cyan
    foreach ($fsRet in @(
        @{ Label = 'an implicit return'; Line = '    Write-FixtureScriptSummary -Subject ''child.ps1''' }
        @{ Label = 'an explicit return'; Line = '    return Write-FixtureScriptSummary -Subject ''child.ps1''' }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            'function Get-LoadBroken {'
            $fsRet.Line
            '}'
            'if (Get-LoadBroken) { exit 1 }'
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC77 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 0 ([regex]::Matches($rC77.Out, $FsFindingPattern).Count) "scenario 77/$($fsRet.Label): a verdict handed back to the caller is not a discard"
    }

    # AND A BARE CALL THAT IS *NOT* A RETURN IS STILL A DISCARD -- the discriminator for (d), without
    # which that arm would clear every dropped verdict at file scope.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'Write-FixtureScriptSummary -Subject ''child.ps1'''
        'Write-Host ''done'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC78 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC78.Out, $FsFindingPattern).Count) 'scenario 78: a bare call at file scope is still a discard, not an implicit return'

    # AND A [void] CAST IS A DISCARD EVEN AS THE LAST STATEMENT OF A FUNCTION -- the OTHER discriminator
    # for (d), and the one that was missing. Scenario 78 pins that a bare call at file scope is not an
    # implicit return; this pins that a cast-away call inside a function is not one either. Until #1956
    # the check climbed straight through the ConvertExpressionAst without noticing the cast, so this
    # exact shape reached the implicit-return arm and was cleared as a READ -- 0 findings here, against
    # 1 for the same call one line further up. [void] is precisely what stops a last statement being a
    # return value, so the two positions have to agree, and a check whose arms disagree about wrapping
    # teaches the shape that gets past it (check 35's lesson, one level up).
    Write-Host "check 41 -- a [void] cast is a discard in both positions" -ForegroundColor Cyan
    foreach ($fsVoid in @(
        @{ Label = 'as the last statement'; Tail = @() }
        @{ Label = 'one line further up';   Tail = @('    Write-Host ''done''') }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            'function Close-Suite {'
            '    [void](Write-FixtureScriptSummary -Subject ''child.ps1'')'
        ) + $fsVoid.Tail + @(
            '}'
            'Close-Suite'
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC78b = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 1 ([regex]::Matches($rC78b.Out, $FsFindingPattern).Count) "scenario 78b/$($fsVoid.Label): a [void] cast is a discard, not an implicit return"
        Assert-True ($rC78b.Out -match 'is never read, so nothing turns it into an exit code') "scenario 78b/$($fsVoid.Label): and the finding says what is missing"
    }

    # (e) THE DOT-SOURCE LEAF IS ANCHORED: a different file whose name merely ends the same way is not
    #     this lib, and used to count as the wiring.
    Write-Host "check 41 -- a lookalike lib name is not the dot-source" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\my-other-fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        'if ($loadBroken) { exit 1 }'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC79 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC79.Out, $FsFindingPattern).Count) 'scenario 79: a lookalike leaf does not satisfy the dot-source part'
    Assert-True ($rC79.Out -match 'not the dot-source of scripts/lib/fixture-script-lib\.ps1') 'scenario 79: and the finding names the part that is genuinely absent'

    Remove-Item -LiteralPath $fsPath -Force
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
