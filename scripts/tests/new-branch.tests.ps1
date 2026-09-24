<#
.SYNOPSIS
    new-branch.ps1, scenarios (0) and (v)-(z): the phrase matcher every assert rests on, resuming a
    branch and its remote head, and the refusals made before anything is created.

.DESCRIPTION
    The fixture, the assert helpers and the child runner live in new-branch-fixture.ps1, which also
    records why this suite is more than one file. Split under #2304.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/new-branch.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'new-branch-fixture.ps1')

try {
    # --- (0) Get-FlatOutput: the property every phrase assert below rests on ---------------------------
    # Synthetic rather than captured on purpose: the real wrap only appears at particular console widths,
    # so a test that waited for it would pass on this machine and prove nothing on the next. This pins the
    # property itself -- a record split MID-WORD still matches the phrase.
    Write-Host "Get-FlatOutput -- a wrapped record still matches its phrase" -ForegroundColor Cyan
    $flatProbe = Get-FlatOutput @('powershell.exe : new-branch cannot run: Branch name mus', "t not be 'main'.")
    Assert-True (Test-Phrase -Text $flatProbe -Phrase "must not be 'main'") 'a MID-WORD wrap still matches the phrase'
    Assert-True ($flatProbe -notmatch "`n") 'no newline survives normalization'
    # THE AT-SPACE WRAP, which this block used to name as unmeasured and leave uncovered -- with a
    # prediction attached: "if that case ever bites, the fix is to strip ALL whitespace from both the text
    # and the pattern before comparing". It bit on August 3, 2026 at width 198, and the prediction was
    # right. Both directions are pinned here now, so neither can regress into the other's fix.
    $flatProbeSpace = Get-FlatOutput @('powershell.exe : new-branch cannot run: ... must not contain the token', "'final'.")
    Assert-True (Test-Phrase -Text $flatProbeSpace -Phrase "token 'final'") 'an AT-SPACE wrap still matches the phrase'
    Assert-True (Test-Phrase -Text (Get-FlatOutput @('a b')) -Phrase 'a b') 'an unwrapped phrase matches too -- the normalization is not one-directional'


    # --- (v) A BRANCH THAT EXISTS ONLY ON ORIGIN IS RESUMED, NOT FORKED (#1139) ----------------------
    # THE CASE THE REPORT WAS FILED ON, and it is this workflow's own cross-device handoff: #900 pushes
    # every new branch by default and cycle-autopark keeps it current on origin, so a branch whose only
    # copy is on the remote is the NORMAL product of the flow rather than an edge case. new-branch asked
    # refs/heads/<name> alone, read the miss as "create it", and cut a second branch of that name at the
    # current base.
    #
    # WHY THE ASSERT LIST IS SHAPED THE WAY IT IS. Almost nothing on screen could tell the two apart: the
    # run reads clean because idempotence PROMISES a clean run, and the scaffold written into the fork is
    # byte-identical to the one on the parked branch because the same script wrote both. What differs is
    # the branch's WORK -- so the marker file is the assert that could not have passed before, and every
    # phrase assert below is about the run SAYING which of the three things it did.
    Write-Host "new-branch.ps1 -- a branch that exists only on origin is resumed, not forked (#1139)" -ForegroundColor Cyan
    $fixParked  = New-Fixture -Label 'v'
    $bareParked = New-BareOrigin -Dir $fixParked -Label 'v'
    Publish-FixtureTrunk -Dir $fixParked
    # The trunk is left BEHIND on purpose, so the base check has something it would have warned about --
    # that is what makes the "not warned" assert below mean anything instead of passing on an empty gap.
    Add-OriginCommits -Bare $bareParked -Label 'v' -Count 3
    Add-OriginBranch -Bare $bareParked -Label 'v' -Branch 'fix/parked-elsewhere-v1' -MarkerFile 'parked-work.txt'

    # The fixture really is in the reported state: reachable on origin, absent locally. Asserted rather
    # than assumed -- a helper that quietly failed to push would make every assert below vacuous.
    Assert-True (Test-BranchOnRemote -Bare $bareParked -Ref 'refs/heads/fix/parked-elsewhere-v1') 'parked branch: it is on origin'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & git -C $fixParked rev-parse --verify --quiet 'refs/heads/fix/parked-elsewhere-v1' | Out-Null
        $localMissing = ($LASTEXITCODE -ne 0)
    } finally { $ErrorActionPreference = $prevEap }
    Assert-True $localMissing 'parked branch: and this checkout has no local ref for it -- the state the fork happened in'

    $rV = Invoke-NewBranch -Dir $fixParked -Name 'fix/parked-elsewhere-v1' -Title 'Parked elsewhere'
    Assert-ExitCode 0 $rV 'parked branch: exit 0'
    # THE ASSERT THAT MATTERS. The parked work is in the checkout, which is the one thing a fork could
    # never produce.
    Assert-True (Test-Path -LiteralPath (Join-Path $fixParked 'parked-work.txt')) 'parked branch: the work parked from the other device is here'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $upstreamV = ((& git -C $fixParked rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
    Assert-Equal 'origin/fix/parked-elsewhere-v1' $upstreamV 'parked branch: tracking the remote branch, so the next push continues it rather than colliding'
    # AND IT SAYS SO. The report rules out a SILENT adoption, not the adoption -- an assignee is a claim
    # rather than a locked door here, and a script that quietly takes over somebody else's remote branch
    # makes that claim unreadable. These two asserts are that rule.
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'existed ONLY on origin') 'parked branch: names which of the three things it did'
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'That is a RESUME, not a new branch') 'parked branch: and says it in the words an operator can act on'
    # NOT TOLD ABOUT A BASE. The trunk really is 3 behind here, so the pre-#1139 ordering would have
    # attributed that gap to a branch cut somewhere else entirely.
    Assert-True (-not (Test-Phrase -Text $rV.Out -Phrase 'behind origin/main')) 'parked branch: not warned about a base it was never cut from'
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'Base not compared') 'parked branch: and says why the base was not compared'

    # --- (w) A LOCAL RESUME IS NOT TOLD ITS BASE IS BEHIND EITHER (#1139) ---------------------------
    # THE SAME FALSEHOOD, ONE CASE OLDER, and it is why the resume question moved in FRONT of the base
    # check rather than beside it. The gap is HEAD..origin/<trunk> measured before the checkout, so on a
    # resume it is a reading about whatever the operator happened to be standing on -- the trunk, in the
    # normal case -- printed with the resumed branch's name attached to it. Nobody can act on that.
    Write-Host "new-branch.ps1 -- a local resume is not told the trunk's gap is its own (#1139)" -ForegroundColor Cyan
    $fixResume  = New-Fixture -Label 'w'
    $bareResume = New-BareOrigin -Dir $fixResume -Label 'w'
    Publish-FixtureTrunk -Dir $fixResume
    Add-OriginCommits -Bare $bareResume -Label 'w' -Count 2

    # Run one: a genuine cut, which SHOULD be warned -- the positive control for the assert below.
    # -SkipStaleBase because this run is the FIXTURE and not the subject: since #1417 a cut from a base
    # two behind refuses, and (s) in new-branch-base.tests.ps1 is where that is asserted. What this block is about is the run AFTER it,
    # so the valve is what gets the branch onto disk without restating a check that has its own case.
    $rW1 = Invoke-NewBranch -Dir $fixResume -Name 'feat/resume-me-v1' -Title 'Resume me' -SkipStaleBase
    Assert-ExitCode 0 $rW1 'local resume: the first run (a real cut, valved) exits 0'
    Assert-True (Test-Phrase -Text $rW1.Out -Phrase '2 behind origin/main') 'local resume: the cut IS warned -- #1046 still holds where a base is being chosen'

    # Back to the trunk, which is where a resume is typed from.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixResume checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    # NO VALVE ON THIS ONE, DELIBERATELY, and it is the assert #1417 rests on. The trunk under this run
    # is still two behind, so if the refusal could reach a resume it would fire here and this exits 1.
    # That is exactly the fear #1046 recorded as its reason for warning instead -- a refusal landing on
    # the script consumers are told to re-run to resume a parked branch -- and the reason it does not
    # hold is structural rather than a promise: the whole base block is gated on `-not $resuming`. So
    # the guarantee is asserted where it can actually fail, on a stale trunk and without the escape.
    $rW2 = Invoke-NewBranch -Dir $fixResume -Name 'feat/resume-me-v1' -Title 'Resume me'
    Assert-ExitCode 0 $rW2 'local resume: exit 0 -- a resume is never refused, stale trunk and no valve'
    Assert-True (Test-Phrase -Text $rW2.Out -Phrase 'already existed -- checked out') 'local resume: reports the resume'
    Assert-True (-not (Test-Phrase -Text $rW2.Out -Phrase 'behind origin/main')) 'local resume: and is NOT handed the trunk gap under the branch name'
    Assert-True (Test-Phrase -Text $rW2.Out -Phrase 'Base not compared') 'local resume: says why the base was not compared'

    # --- (y1) THE BRANCH YOU RESUME IS BEHIND ITS OWN REMOTE HEAD -- warned, twice, never refused (#1439) -
    # THE THIRD MEASURED DUPLICATE, AND THE FIRST ONE NO TRACKER COULD HAVE CAUGHT. #1282 and #1409 are
    # both about an ISSUE worked twice and both need an issue number; #1409 closed by naming exactly this
    # gap -- "that leaves the case where no issue number is passed, which is most branches". Two sessions
    # then built feat/plugin-policy-precedence end to end from one parked commit, each running the lint
    # gate and all 69 suites, and met at `git push`.
    #
    # THE FIXTURE IS THE REPORTED STATE AND NOT THE #1139 ONE. There, no local ref existed. Here run one
    # creates the branch locally AND pushes it (the #900 default), and only then does the other session
    # advance origin -- so this checkout holds a local ref at the older tip, which is precisely the state
    # `git status` prints with no ahead/behind marker, indistinguishable from "in sync".
    Write-Host "new-branch.ps1 -- a resume of a branch whose remote head has moved is warned (#1439)" -ForegroundColor Cyan
    $fixAhead  = New-Fixture -Label 'y1'
    $bareAhead = New-BareOrigin -Dir $fixAhead -Label 'y1'
    Publish-FixtureTrunk -Dir $fixAhead

    $rY1a = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch'
    Assert-ExitCode 0 $rY1a 'remote ahead: the first run (the cut, which also pushes) exits 0'
    Assert-True (Test-BranchOnRemote -Bare $bareAhead -Ref 'refs/heads/feat/dup-1439-v1') 'remote ahead: and the branch really is on origin -- the shared ref the other session will move'

    # The other session, in the words the operator has to read. 'park: ... (all outstanding work)' is the
    # verbatim subject from the measured incident, and 'Other Session' stands in for the second git
    # identity that made it legible there.
    Add-OriginBranchCommits -Bare $bareAhead -Label 'y1' -Branch 'feat/dup-1439-v1' -MarkerFile 'their-work.txt' -Author 'Other Session' -Subject 'park: feat/dup-1439-v1 (all outstanding work)'

    # Back to the trunk, which is where a resume is typed from -- and the checkout that follows is what
    # would otherwise land silently on the older tip.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixAhead checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    $rY1b = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch'
    # EXIT 1, AND IT IS THE PUSH RATHER THAN A REFUSAL BY THIS CHECK -- the distinction the two asserts
    # below draw, because an exit code alone cannot. A resume of a branch whose remote head has moved
    # CANNOT push: the creation push is a non-fast-forward, which is the measured incident's own ending.
    # This suite is what found that, and it is why the repeat is a function called from both ends of the
    # run instead of a block above exit 0 that this case never reaches.
    Assert-ExitCode 1 $rY1b 'remote ahead: exit 1 -- from the rejected push, which is the symptom itself'
    Assert-Equal 'feat/dup-1439-v1' ((& git -C $fixAhead rev-parse --abbrev-ref HEAD) | Out-String).Trim() 'remote ahead: and the checkout still happened -- this check warns, it does not refuse'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'already existed -- checked out') 'remote ahead: still the local resume route, unchanged'
    # THE ASSERT THAT COULD NOT HAVE PASSED BEFORE. Everything else about this run was already correct.
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase "'feat/dup-1439-v1' is 1 commit(s) behind origin/feat/dup-1439-v1") 'remote ahead: names the branch and the count'
    # THE SUBJECT AND THE AUTHOR, which are what separate a collision from a fast-forward of your own
    # autopark. A count alone reads the same in both cases.
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'Other Session: park: feat/dup-1439-v1 (all outstanding work)') 'remote ahead: and names the remote tip -- who wrote it and what they called it'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'Another session or another device has pushed work to this branch') 'remote ahead: says what it means in words an operator can act on'
    # THE REPEAT, on the same argument as (s2)'s in new-branch-base.tests.ps1 and load-bearing for a stronger reason: this check never
    # refuses, so these two copies are the ENTIRE record. Between them print the checkout, the scaffold,
    # the tier rubric, the commit and the push.
    $flatAhead = Get-FlatOutput $rY1b.Out
    $aheadHits = @([regex]::Matches($flatAhead, [regex]::Escape((Get-Squeezed 'is 1 commit(s) behind origin/feat/dup-1439-v1')))).Count
    Assert-Equal 2 $aheadHits 'remote ahead: said twice -- once before the checkout, once out of the rejected push'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'git pull --ff-only') 'remote ahead: the last copy carries the remedy'
    # NOT MOVED FOR YOU, which is the other half of "it warns". The work is still only on origin.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixAhead 'their-work.txt'))) 'remote ahead: and the checkout is NOT fast-forwarded behind your back -- this script does not move HEAD'

    # --- (y2) THE OTHER END OF THE RUN, reached with -NoPush (#1439) ---------------------------------
    # THE REPEAT HAS TWO CALL SITES AND (y) ONLY EXERCISES ONE. There, the push is rejected and the
    # second copy comes out of the failed-push branch; a repeat that existed ONLY above `exit 0` would
    # therefore have passed nothing in (y) and been dead code in the case it was written for. -NoPush is
    # what reaches the tail: same divergent fixture, no push to reject, so the run ends on exit 0 with
    # the note as its last line -- which is the shape the other two repeats in this script have.
    Write-Host "new-branch.ps1 -- the divergence note is the last line of a run that completes (#1439)" -ForegroundColor Cyan
    $rY2a = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch' -NoPush
    Assert-ExitCode 0 $rY2a '-NoPush resume: exit 0 -- nothing to reject, so the run completes'
    $flatY2a = Get-FlatOutput $rY2a.Out
    $y2aHits = @([regex]::Matches($flatY2a, [regex]::Escape((Get-Squeezed 'is 1 commit(s) behind origin/feat/dup-1439-v1')))).Count
    Assert-Equal 2 $y2aHits '-NoPush resume: still said twice -- once before the checkout, once as the last line'

    # --- (y3) THE REMOTE IS LEVEL: nothing to warn about ----------------------------------------------
    # The negative half, and it is what keeps this from becoming noise on the routine resume -- which is
    # every second run of an idempotent script. Same fixture shape, same route, origin simply never moved.
    Write-Host "new-branch.ps1 -- a resume whose remote head has NOT moved says nothing (#1439)" -ForegroundColor Cyan
    $fixLevel  = New-Fixture -Label 'y3'
    $bareLevel = New-BareOrigin -Dir $fixLevel -Label 'y3'
    Publish-FixtureTrunk -Dir $fixLevel
    $rY3a = Invoke-NewBranch -Dir $fixLevel -Name 'feat/level-1439-v1' -Title 'Level with origin'
    Assert-ExitCode 0 $rY3a 'remote level: the cut exits 0'
    Assert-True (Test-BranchOnRemote -Bare $bareLevel -Ref 'refs/heads/feat/level-1439-v1') 'remote level: the cut pushed, so there IS a remote head to compare against'
    $rY3b = Invoke-NewBranch -Dir $fixLevel -Name 'feat/level-1439-v1' -Title 'Level with origin'
    Assert-ExitCode 0 $rY3b 'remote level: the resume exits 0'
    Assert-True (Test-Phrase -Text $rY3b.Out -Phrase 'already existed -- checked out') 'remote level: it is the resume route'
    Assert-True (-not (Test-Phrase -Text $rY3b.Out -Phrase 'commit(s) behind origin/feat/level-1439-v1')) 'remote level: and nothing is said about a gap that does not exist'

    # --- (y4) A BRANCH RESUMED FROM ORIGIN ALONE IS NOT WARNED EITHER (#1439 x #1139) -----------------
    # THE ROUTE THIS CHECK DELIBERATELY DOES NOT REACH, asserted rather than left to the reading of one
    # `if`. $branchOnOrigin creates the branch AT the remote tip, so its gap is 0 by construction -- and a
    # warning there would be the #1139 mirror of what (w) rules out: a number about a ref the run has
    # just aligned itself with, printed as if the operator were missing something.
    Write-Host "new-branch.ps1 -- a resume from origin alone is never told it is behind (#1439)" -ForegroundColor Cyan
    $fixOnly  = New-Fixture -Label 'y4'
    $bareOnly = New-BareOrigin -Dir $fixOnly -Label 'y4'
    Publish-FixtureTrunk -Dir $fixOnly
    Add-OriginBranch -Bare $bareOnly -Label 'y4' -Branch 'fix/origin-only-1439-v1' -MarkerFile 'only-there.txt'
    $rY4a = Invoke-NewBranch -Dir $fixOnly -Name 'fix/origin-only-1439-v1' -Title 'Origin only'
    Assert-ExitCode 0 $rY4a 'origin-only resume: exit 0'
    Assert-True (Test-Phrase -Text $rY4a.Out -Phrase 'existed ONLY on origin') 'origin-only resume: it is the #1139 route'
    Assert-True (-not (Test-Phrase -Text $rY4a.Out -Phrase 'commit(s) behind origin/fix/origin-only-1439-v1')) 'origin-only resume: and carries no gap, because it was created at the remote tip'

    # --- (y5) THE REMOTE TIP IS SOMEBODY ELSE'S TEXT, so it is stripped before it is printed (#1439) --
    # THE ONE PIECE OF TEXT THIS SCRIPT EMITS THAT IT DID NOT WRITE. %an and %s are chosen by whoever
    # pushed the commit, and the check under test prints them to a console. ONE OF THREE SUCH CONSOLES,
    # not the only one -- ship-pr relays a failing workflow's own annotation (Get-AuthoredFailureNote,
    # pr-issues-lib.ps1, stripping the same class since #1612) and Get-PasteableRef prints the name it
    # refused (ref-print-lib.ps1, #1594). pr-issues.tests.ps1 pins all three patterns to each other and
    # asserts the count. The neighbouring adversarial case (a malicious -Title,
    # section (f) in new-branch-document.tests.ps1) asserts the OPPOSITE and is not a precedent: that payload goes into a FILE,
    # where landing fully and unchanged is the correctness property and truncation is the damage.
    #
    # THE PAYLOAD IS THE ATTACK AND NOT A GENERIC "WEIRD STRING": an ANSI colour escape and a cursor
    # move (what repaints a terminal), an RTL override and a zero-width joiner (what makes a printed
    # line read as something other than what it says). A reader deceived by the very line that exists to
    # tell them whose work is on the other side of their branch is the failure worth a section.
    Write-Host "new-branch.ps1 -- an adversarial remote tip is stripped, not printed raw (#1439)" -ForegroundColor Cyan
    $fixEvil  = New-Fixture -Label 'y5'
    $bareEvil = New-BareOrigin -Dir $fixEvil -Label 'y5'
    Publish-FixtureTrunk -Dir $fixEvil
    $rY5a = Invoke-NewBranch -Dir $fixEvil -Name 'feat/evil-tip-1439-v1' -Title 'Evil tip'
    Assert-ExitCode 0 $rY5a 'adversarial tip: the cut exits 0'

    $esc = [char]27
    $evilSubject = "park:${esc}[31m${esc}[2K harmless-looking$([char]0x202E)$([char]0x200D) subject"
    Add-OriginBranchCommits -Bare $bareEvil -Label 'y5' -Branch 'feat/evil-tip-1439-v1' -MarkerFile 'evil.txt' -Author 'Other Session' -Subject $evilSubject

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixEvil checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    $rY5b = Invoke-NewBranch -Dir $fixEvil -Name 'feat/evil-tip-1439-v1' -Title 'Evil tip'
    # THE FIXTURE REALLY CARRIES THE PAYLOAD, asserted rather than assumed -- the same discipline (y4)
    # applies to its parked branch. Without this the three "no ESC in the output" asserts below pass
    # just as happily against a helper that quietly dropped the characters on the way in, which is the
    # shape of a security test that proves nothing.
    # READ BACK WITH AN EXPLICIT UTF-8 DECODE, NOT WITH `& git` (issue #1446, September 5, 2026). This
    # block asks "does the fixture really carry the payload", and until that date it asked through the
    # same mangling it was meant to be independent of: `& git` is decoded with [Console]::OutputEncoding,
    # so on a cp850 console the RTL override came back as the three printable characters e2/80/ae map to
    # there and this assert read FALSE against a commit that was perfectly intact. A premise assert that
    # can be defeated by the console it runs on cannot vouch for anything below it -- and the three
    # characters it is checking for are precisely the ones no non-UTF-8 code page can represent.
    $evilOnRemote = ((Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $bareEvil, 'log', '-1', '--format=%s', 'refs/heads/feat/evil-tip-1439-v1') -DiscardStderr -Utf8).Output -join "`n")
    Assert-True ($evilOnRemote.Contains($esc)) 'adversarial tip: the commit on origin really carries the ESC -- so the asserts below are not vacuous'
    Assert-True ($evilOnRemote.Contains([char]0x202E)) 'adversarial tip: and the RTL override'
    Assert-True ($evilOnRemote.Contains([char]0x200D)) 'adversarial tip: and the zero-width joiner -- all three asserted, because all three are stripped below'

    # ASSERTED ON THE FLATTENED CAPTURE AND THAT IS SAFE HERE, unlike for a whitespace-shaped payload:
    # Get-FlatOutput strips '\s', and none of these three characters is whitespace to .NET -- ESC, the
    # RTL override and the ZWJ all survive it. So a raw one would be visible to these asserts.
    Assert-True (-not $rY5b.Out.Contains($esc)) 'adversarial tip: no ESC reaches the output -- the terminal cannot be repainted from a commit subject'
    Assert-True (-not $rY5b.Out.Contains([char]0x202E)) 'adversarial tip: nor an RTL override, which would reverse how the line reads'
    Assert-True (-not $rY5b.Out.Contains([char]0x200D)) 'adversarial tip: nor a zero-width joiner'
    # AND THE STRIPPING IS NOT SILENCE. The point of the line is that the reader recognises the commit,
    # so the words have to survive what the escapes did not.
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase 'harmless-looking') 'adversarial tip: the readable words survive -- stripping the attack is not dropping the subject'
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase 'Other Session') 'adversarial tip: and the author still identifies who pushed it'
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase "is 1 commit(s) behind origin/feat/evil-tip-1439-v1") 'adversarial tip: the warning still fires -- the strip is not a refusal to report'

    # --- (y6) THE CAP: an unbounded remote tip subject does not reach the output whole (#1439) -------
    # A subject has no length limit, and an unbounded one pushes the half of the sentence that says what
    # to DO off the screen -- the same failure the repeat exists to prevent, arriving from the other
    # direction. The cap is asserted in both directions: enough survives to recognise the commit, and
    # not so much that the remedy is pushed off the end.
    Write-Host "new-branch.ps1 -- an unbounded remote tip subject is capped (#1439)" -ForegroundColor Cyan
    $fixLong  = New-Fixture -Label 'y6'
    $bareLong = New-BareOrigin -Dir $fixLong -Label 'y6'
    Publish-FixtureTrunk -Dir $fixLong
    $rY6a = Invoke-NewBranch -Dir $fixLong -Name 'feat/long-tip-1439-v1' -Title 'Long tip'
    Assert-ExitCode 0 $rY6a 'capped tip: the cut exits 0'
    $longSubject = 'park: ' + ('x' * 400)
    Add-OriginBranchCommits -Bare $bareLong -Label 'y6' -Branch 'feat/long-tip-1439-v1' -MarkerFile 'long.txt' -Author 'Other Session' -Subject $longSubject
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixLong checkout -q main
    } finally { $ErrorActionPreference = $prevEap }
    $rY6b = Invoke-NewBranch -Dir $fixLong -Name 'feat/long-tip-1439-v1' -Title 'Long tip'
    # THE PREMISE, ASSERTED RATHER THAN ASSUMED -- the same discipline (y5) applies to its payload, one
    # layer out (issue #1915). All three cap asserts read a sentence that only exists if the divergence was
    # FOUND, and finding it needs this run's own fetch to have refreshed refs/remotes/origin/<branch>. When
    # that does not happen the note is '', and the three come out as PASS/FAIL/FAIL -- a signature that
    # reads as "the cap is broken" and sent #1915's reporter to the fixture helpers. Named here, the same
    # failure says which half went wrong in its own words.
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase 'is 1 commit(s) behind origin/feat/long-tip-1439-v1') 'capped tip: the divergence was found at all -- the premise the three cap asserts below read'
    Assert-True (-not (Test-Phrase -Text $rY6b.Out -Phrase ('x' * 200))) 'capped tip: the 400-character subject does not reach the output whole'
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase ('x' * 80)) 'capped tip: but enough of it does to recognise the commit'
    # THE HALF THAT MATTERS IS STILL THERE, which is the whole reason for the cap.
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase 'git pull --ff-only') 'capped tip: and the remedy is not pushed off the end by it'

    # --- (y7) A COUNT TAKEN AGAINST A REF NOBODY REFRESHED IS SAID, NOT PRINTED AS SILENCE (#1915) ----
    # THE HOLE THE SIX CASES ABOVE ALL SIT ON. Every one of them asserts what the divergence check SAYS
    # once it has looked; none asks what it says when it could not look. Get-RemoteAheadNote returns ''
    # for both "origin has nothing you do not have" and "the ref I counted against is whatever the last
    # fetch left", and until #1915 this caller printed the second as the first -- so the #1439 guard
    # reported the shape of a clean branch on the one run where it was blind.
    #
    # THE STATE IS STAGED WITH A FAILED FETCH RECORD RATHER THAN A BROKEN REMOTE, because that is the
    # shape the gate actually produced: since #1860 new-branch opts into -RecentFailureSeconds, so ONE
    # transient failure suppresses the retry for the next 90 seconds -- and a claim, a cut and a resume
    # all live inside that interval. A record is also the only way to reach this deterministically; a
    # remote made unreachable would exercise git's own failure rather than the seam's.
    #
    # -KeepFetchStamp IS LOAD-BEARING AND IS THIS CASE'S ALONE: Invoke-NewBranch clears the record before
    # every other run in this file, which is the repair for the flake #1915 was filed about.
    Write-Host "new-branch.ps1 -- a run whose fetch did not refresh says so instead of nothing (#1915)" -ForegroundColor Cyan
    $fixStale  = New-Fixture -Label 'y7'
    $bareStale = New-BareOrigin -Dir $fixStale -Label 'y7'
    Publish-FixtureTrunk -Dir $fixStale
    $rY7a = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed'
    Assert-Equal 0 $rY7a.Code 'unrefreshed: the cut exits 0'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixStale checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    # The record the lib itself would have written, at the path the lib itself names -- so a move of
    # either cannot leave this case staging a file nothing reads.
    $stampPath = Get-RemoteFetchStampPath -RepoRoot $fixStale
    Assert-True ([bool]$stampPath) 'unrefreshed: the fetch-attempt record has a path in this fixture -- the premise of the staging below'
    $stampBody = ([ordered]@{
        remote     = 'origin'
        scope      = 'all'
        ok         = $false
        note       = 'git fetch exited 128'
        detail     = @('fatal: staged by new-branch.tests.ps1')
        recordedAt = [datetime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 4)
    [System.IO.File]::WriteAllText($stampPath, $stampBody, (New-Object System.Text.UTF8Encoding $false))

    # NOTHING HAS MOVED ON ORIGIN, deliberately: this is the case where there genuinely is no divergence,
    # so '' out of Get-RemoteAheadNote is the honest return and the whole question is what the CALLER does
    # with it. Staging a divergence too would prove the same sentence for the wrong reason.
    $rY7b = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed' -KeepFetchStamp
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'fetch did not refresh it') 'unrefreshed: the run says the ref it compared against was not refreshed'
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'is what this run could not see, not what is on the branch') 'unrefreshed: and says what the silence means, rather than leaving the reader to infer a clean branch'
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'git fetch origin feat/unrefreshed-1915-v1') 'unrefreshed: and hands over the command that settles it, naming the branch'
    # THE TRUNK'S OWN NOTE IS NOT THIS ONE, and the case asserts both so neither can be mistaken for the
    # other: 'Base: ...' speaks about origin/<trunk>, and a reader given only that has no way to know the
    # branch-divergence probe went blind on the same reading.
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'not retried') 'unrefreshed: the skipped fetch is reported too -- the trunk-level note, which is a different sentence'

    # AND IT IS SILENT WHEN THE FETCH DID REFRESH, which is the overwhelming majority of runs. Same
    # fixture, same absence of divergence: only the record is gone, so this run fetches for itself.
    $rY7c = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed'
    Assert-True (-not (Test-Phrase -Text $rY7c.Out -Phrase 'fetch did not refresh it')) 'unrefreshed: a run that fetched successfully says nothing about it -- the check cannot become noise'
    Assert-True (-not (Test-Phrase -Text $rY7c.Out -Phrase 'not retried')) 'unrefreshed: and the record is gone, so nothing is skipped either'


    # --- (y) NO USABLE GIT AUTHOR IDENTITY: REFUSED BEFORE ANYTHING IS CREATED (inbound #1867) --------
    # THE FAILURE THIS REPLACES. On a machine with nothing in system, global or local config, and a
    # hostname with no domain part for git's auto-guess to work from, every commit dies with exit 128 --
    # and the first one to do so was this script's own park, several hundred lines after the checkout.
    # The run left a local branch with an uncommitted document standing on it, for a condition that was
    # knowable before a single ref existed. Reported from a consumer that measured the machine state.
    #
    # THE SAME TWO-HALF SHAPE AS (s) IN new-branch-base.tests.ps1, and for the same reason: naming the repair is what the
    # message has to do, and NOTHING HAPPENED is what makes refusing cheaper than failing late. A
    # refusal that left half a branch behind would be strictly worse than the exit 128 it replaces.
    Write-Host "new-branch.ps1 -- a checkout that cannot commit is REFUSED (inbound #1867)" -ForegroundColor Cyan
    # THE FIXTURE'S IDENTITY IS REMOVED IN ALL THREE PLACES GIT READS, not just the local config that
    # New-Fixture wrote: git falls back to global, then system -- and on a developer machine the global
    # config alone would keep the probe green and assert nothing. GIT_AUTHOR_* / GIT_COMMITTER_* are
    # cleared too, because the environment outranks all of it and a runner that exports them (some CI
    # images do) would otherwise make this case silently vacuous.
    $fixIdent = New-Fixture -Label 'y'
    Invoke-FixtureGitIn $fixIdent config --unset user.name
    Invoke-FixtureGitIn $fixIdent config --unset user.email
    $identEnvNames = @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL')
    $identEnvPrev = @{}
    foreach ($n in $identEnvNames) { $identEnvPrev[$n] = (Get-Item "Env:\$n" -ErrorAction SilentlyContinue).Value }
    # AN EMPTY GLOBAL CONFIG IS NOT ENOUGH, AND THAT IS THE WHOLE POINT OF THIS FIXTURE (#1888).
    # Emptying every config scope leaves git with nothing to read AND STILL NAMING AN AUTHOR: Git for
    # Windows falls back to the OS account, and that fallback produces a real display name and a real
    # address rather than the username@hostname guess git then refuses -- so it exits 0 and every
    # assert below measures a checkout that can commit perfectly well. Measured on DAVE-KOK-BWJ,
    # git 2.55.0.windows.5: with local unset, GIT_CONFIG_NOSYSTEM=1 and GIT_CONFIG_GLOBAL pointed at
    # nothing, `git config --show-origin --get user.email` exits 1 (no config source has it) while
    # `git var GIT_AUTHOR_IDENT` exits 0 with a usable ident. `EMAIL` and the GIT_AUTHOR_*/GIT_COMMITTER_*
    # vars are empty, and substituting a genuinely empty FILE for the unreadable path changes nothing:
    # this is not a leak to be plugged but a fallback to be switched off.
    #
    # `user.useConfigOnly = true` is that switch, and it needs a real file to live in -- which is why
    # GIT_CONFIG_GLOBAL points at one written here instead of at NUL. The file is a SIBLING of the
    # fixture rather than a file inside it: this repo is the one new-branch.ps1 reads `git status` on,
    # and an untracked config file in its root would put a second subject into every assert.
    $identGlobalCfg = "$fixIdent.gitconfig"
    [System.IO.File]::WriteAllText($identGlobalCfg, "[user]`n`tuseConfigOnly = true`n", (New-Object System.Text.UTF8Encoding $false))
    $script:fixtures += $identGlobalCfg
    try {
        foreach ($n in $identEnvNames) { Remove-Item "Env:\$n" -ErrorAction SilentlyContinue }
        # GIT_CONFIG_GLOBAL / GIT_CONFIG_NOSYSTEM remain git's own documented way to suppress the outer
        # two config scopes, and they are inherited by the child process Invoke-NewBranch starts; the
        # file they now point at carries the one key that stops git guessing past them.
        $env:GIT_CONFIG_GLOBAL = $identGlobalCfg
        $env:GIT_CONFIG_NOSYSTEM = '1'

        # FIXTURE SANITY FIRST, because every assert below is vacuous if the identity is still readable
        # -- and it would be vacuous SILENTLY, passing for the wrong reason on a machine where the
        # suppression did not take. Asserted against git's own probe, which is the one this script reads.
        $identProbe = Invoke-CapturedChild -WorkDir $fixIdent -ChildArgs @('-NoProfile', '-Command', "git -C '$fixIdent' var GIT_AUTHOR_IDENT; exit `$LASTEXITCODE")
        Assert-ExitCode 128 $identProbe 'no identity: fixture sanity -- git itself refuses to name an author here'

        $rY = Invoke-NewBranch -Dir $fixIdent -Name 'fix/1867-cannot-commit-v1' -Title 'Cannot commit'
        Assert-ExitCode 1 $rY 'no identity: new-branch exits 1 rather than dying at exit 128 in the park'
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'no usable git author identity') 'no identity: and says which state it is in, in words'
        # AND IT NAMES THE EXIT CODE ITS OWN GUARD GATED ON (issue #1932). The refusal composes this number
        # from git-identity-lib.ps1's $GitAuthorIdentityUnknownExitCode rather than carrying a third
        # hand-typed copy of it, and falls back to wording that claims NO number where a mirror predating
        # #1920 supplies no constant. That fallback is what this assert is really guarding: the sentence
        # reads perfectly well without the code, so a composition that silently lost it -- a renamed
        # constant, a scope the lookup no longer reaches -- would degrade the refusal's only measured
        # detail with nothing on screen looking wrong. The probe two asserts up is the other half: it
        # pins that 128 is still what GIT reports, which is the fact the constant encodes.
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'exits 128') 'no identity: and states the exit code its own guard gated on, read from the lib constant'
        # THE REPAIR, both keys. Setting only user.name leaves git refusing exactly as hard, which is the
        # whole reason user.name was the wrong thing to read for this question in the first place.
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'user.name') 'no identity: names user.name as part of the repair'
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'user.email') 'no identity: and user.email, which is the half a user.name-only check misses'

        # AND NOTHING WAS TOUCHED -- the same three reads as (s) in new-branch-base.tests.ps1, for the same reason.
        $branchesY = ((& git -C $fixIdent branch --list 'fix/1867-cannot-commit-v1') -join '').Trim()
        Assert-True (-not [bool]$branchesY) 'no identity: and NO branch was created -- the refusal is before the checkout'
        $docY = Join-Path $fixIdent (Join-Path 'dkj-policy' 'fix-1867-cannot-commit-v1.md')
        Assert-True (-not (Test-Path -LiteralPath $docY)) 'no identity: and no branch document was scaffolded either'
        $headY = ((& git -C $fixIdent rev-parse --abbrev-ref HEAD) -join '').Trim()
        Assert-Equal 'main' $headY 'no identity: and HEAD is left exactly where the operator was standing'
    } finally {
        foreach ($n in $identEnvNames) {
            if ($null -eq $identEnvPrev[$n]) { Remove-Item "Env:\$n" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:\$n" -Value $identEnvPrev[$n] }
        }
    }

    # --- (y2) AND A HEALTHY CHECKOUT IS UNTOUCHED BY THE PROBE ---------------------------------------
    # The other direction, and it is what keeps the guard shippable: every fixture above already proves
    # it in passing, but none of them SAYS so, and a probe that answered 'no' too readily would refuse
    # every branch in the workflow. One explicit case, so the regression has a name.
    $fixIdentOk = New-Fixture -Label 'y2'
    $rY2 = Invoke-NewBranch -Dir $fixIdentOk -Name 'fix/1867-can-commit-v1' -Title 'Can commit' -NoPush
    Assert-ExitCode 0 $rY2 'healthy identity: new-branch runs exactly as before -- the guard costs one local git var'
    Assert-True (-not (Test-Phrase -Text $rY2.Out -Phrase 'no usable git author identity')) 'healthy identity: and says nothing about identity at all'

    # --- (z) THE REPO ROOT CANNOT BE RESOLVED -- A NAMED REFUSAL, NOT A NULL DEREFERENCE (#1913) ---
    # The script's first statement used to be `(git rev-parse --show-toplevel).Trim()`, unjudged. Where
    # git answers nothing that is `$null.Trim()`: exit 1, nothing created, and the only thing printed is
    # a PowerShell error naming a line number in a script the reader did not write.
    #
    # AND THE COMMAND IT NAMES CHANGED UNDER #2115, which is what the phrase below pins. The read is
    # now `rev-parse --is-inside-work-tree --show-cdup`: --show-toplevel returns a raw path for
    # [Console]::OutputEncoding to mangle, so the question was changed rather than the decode. A
    # refusal quoting a command the script no longer issues sends the reader to reproduce something
    # that is not the thing that failed, which is why this assert has to move with it.
    #
    # WHY THIS IS ASSERTED RATHER THAN LEFT TO THE OTHER CASES. It is the one failure mode that is
    # INVISIBLE to every fixture above, because every fixture above is a real repository -- so the
    # regression back to the silent form would pass this whole suite. It is also the mode #1913's own
    # difficulty was made of: a child that exits 1 while saying nothing is a red gate with no cause in
    # it. The subject is that the refusal SPEAKS, and the exit code is the smaller half.
    #
    # A PLAIN DIRECTORY, NOT A FIXTURE: New-Fixture builds a git repo, which is exactly what this case
    # must not have -- so the script is copied in WITHOUT `git init`. Only the script file itself is
    # needed, because the refusal fires before a single lib is dot-sourced. Registered for the same
    # teardown as every fixture above.
    Write-Host "new-branch.ps1 -- outside a repository, the refusal names its cause (#1913)" -ForegroundColor Cyan
    $notARepo = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-z-notarepo-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path (Join-Path $notARepo 'scripts\task') -Force | Out-Null
    $script:fixtures += $notARepo
    # fixture-dep: script-not-loaded scripts/task/new-branch.ps1 -- outside a repository the script refuses before any lib loads
    Copy-Item -LiteralPath $NewBranchSrc -Destination (Join-Path $notARepo 'scripts\task\new-branch.ps1') -Force
    $rZ = Invoke-NewBranch -Dir $notARepo -Name 'docs/outside-a-repo-v1' -Title 'Outside a repo' -NoPush
    Assert-ExitCode 1 $rZ 'no repo root: exits 1 rather than dying on a null dereference'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'could not work out which repository') 'no repo root: says which question it could not answer'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'rev-parse --is-inside-work-tree --show-cdup') 'no repo root: names the command whose answer it needed'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'Nothing was created') 'no repo root: and states that nothing was created, which is what a reader needs before re-running'
    Assert-True (-not (Test-Phrase -Text $rZ.Out -Phrase 'null-valued expression')) 'no repo root: and NOT the null-dereference this replaced'
} finally {
    Remove-NewBranchFixtures
}

Complete-NewBranchSuite
