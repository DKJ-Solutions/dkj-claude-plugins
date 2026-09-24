<#
.SYNOPSIS
    new-branch.ps1, scenarios (a)-(r): the name it accepts, the branch document it writes, -Park, and
    the creation push.

.DESCRIPTION
    The fixture, the assert helpers and the child runner live in new-branch-fixture.ps1, which also
    records why this suite is more than one file. Split under #2304.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/new-branch-document.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'new-branch-fixture.ps1')

try {
    # --- (a) Hard rejects: 'main', a name with the token 'final', and empty/whitespace ------------------
    Write-Host "new-branch.ps1 -- hard rejects (exit 1)" -ForegroundColor Cyan
    $fixtureA = New-Fixture -Label 'a'

    $rMain = Invoke-NewBranch -Dir $fixtureA -Name 'main'
    Assert-ExitCode 1 $rMain "-Name main: exit 1 (hard reject)"
    Assert-True (Test-Phrase -Text $rMain.Out -Phrase "must not be 'main'") "-Name main: pointer names the main rule"

    $rFinal = Invoke-NewBranch -Dir $fixtureA -Name 'feat/final-cut'
    Assert-ExitCode 1 $rFinal "-Name with token 'final': exit 1 (hard reject)"
    Assert-True (Test-Phrase -Text $rFinal.Out -Phrase "token 'final'") "-Name with token 'final': pointer names the final rule"
    & git -C $fixtureA rev-parse --verify --quiet 'refs/heads/feat/final-cut' | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) "'feat/final-cut': branch NOT created after hard reject"

    # Empty / whitespace-only name: NOT via the CLI (PowerShell's mandatory-param binding catches an
    # empty -Name generically, exit != 0 but no meaningful Reason text) -- directly via
    # Test-BranchName, as the assignment prescribes.
    $emptyCheck = Test-BranchName -Branch ''
    Assert-Equal $false $emptyCheck.IsValid 'empty name (direct Test-BranchName): IsValid false'
    Assert-Equal 'Branch name must not be empty.' $emptyCheck.Reason 'empty name: expected Reason'

    $wsCheck = Test-BranchName -Branch '   '
    Assert-Equal $false $wsCheck.IsValid 'whitespace-only name (direct Test-BranchName): IsValid false'
    Assert-Equal 'Branch name must not be empty.' $wsCheck.Reason 'whitespace-only name: expected Reason'

    # --- (b)+(c)+(d) Valid name: branch + entry, idempotence, and no commit/push/PR ----------------
    Write-Host "new-branch.ps1 -- valid name: branch + entry created" -ForegroundColor Cyan
    $fixtureBC = New-Fixture -Label 'bc'

    $r1 = Invoke-NewBranch -Dir $fixtureBC -Name 'feat/my-task-v1' -Title 'First title'
    Assert-ExitCode 0 $r1 'valid name: new-branch exit 0'
    $headBranch1 = (& git -C $fixtureBC rev-parse --abbrev-ref HEAD).Trim()
    # THE NAME IS USED EXACTLY AS GIVEN (Dave, September 3, 2026). new-branch stopped completing a '-v1'
    # suffix: in 209 branches that reached a merge carrying it, none was ever bumped to '-v2', and the
    # completion was the direct cause of inbound #1224. A '-vN' suffix is still valid and still typed by
    # hand for a second cycle -- the explicit-passthrough and no-completion cases are covered in (b2) below.
    Assert-Equal 'feat/my-task-v1' $headBranch1 'HEAD is on the branch named -- verbatim, no suffix completion'
    # branch/branch-deployment.md, from the lib rather than written out here: the test must fail if the
    # writer and the readers stop agreeing about the path, not merely if this literal goes stale.
    $entryPath    = Join-Path $fixtureBC ((Get-BranchFilePaths -Branch 'feat/my-task-v1').Deployment)
    $progressPath = Join-Path $fixtureBC ((Get-BranchFilePaths -Branch 'feat/my-task-v1').Cycle)
    Assert-True (Test-Path -LiteralPath $entryPath) 'entry file created at the fixed branch/ path'
    Assert-True (Test-Path -LiteralPath $progressPath) 'and the step list beside it -- a branch gets both files or neither'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureBC 'feat-my-task.md'))) 'nothing is written to the repo root any more'
    # THE DOCUMENT, AND THEN ITS ENTRY HALF. Since the merge the file opens with its own '#' title and the
    # entry is the '## DEPLOY:' section inside it -- so the asserts below that are ABOUT THE ENTRY are made
    # on the split, through the same reader the fold and both gates use. Handed the whole document they would
    # be measuring the plan: the first line would be the document's title, and the type would read off a
    # heading that deliberately is not a changelog heading.
    $docText1  = [System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)
    $docSplit1 = Split-Development -Text $docText1
    Assert-Equal $true $docSplit1.Found 'the document carries a DEPLOY section for the fold to split on'
    $entryText1 = [string]$docSplit1.Entry
    Assert-True ($docText1 -match [regex]::Escape('First title')) 'the document contains the given title'
    # THE HEADING IS NOW THE TITLE AND NOTHING ELSE (August 5, 2026), at the entry level rather than one
    # deeper. It carried a scaffolded date until that morning, then the type until later the same day; both
    # were fields a parser had to pick apart, and both have their own place now -- the date on the fold's
    # closing line, the type in its own section. Asserted as the WHOLE line, which is the stronger claim: it
    # proves nothing was appended, which a prefix match could not.
    # AND THE CREATION STAMP LEFT IT AGAIN ON AUGUST 19, 2026, for the cycle file's heading: this document
    # states what is delivered, and the branch's birth moment belongs to the document that is created and
    # reset with the branch. Still asserted as the WHOLE line -- the stronger claim, because it proves
    # nothing at all was appended.
    $headLine1 = ($entryText1 -split "`r?`n")[0]
    Assert-True ($headLine1 -match ('^' + ('#' * (Get-EntryHeadingLevel)) + ' DEPLOY: feat/my-task-v1$')) 'entry heading names its title and the branch, whole and at the entry level'
    Assert-Equal 'First title' (Get-EntryDescription -EntryText $entryText1) 'and the title given to new-branch is the PR title'
    Assert-True (Test-EntryDeclaresType -EntryText $entryText1 -Type 'Feat') 'and the branch type is readable -- off the branch the heading names'
    # NO DATE AND NO STAMP, which is the same claim in two shapes: a 'yyyy-MM-dd' would read as the landing
    # date the fold owns, and a creation instant is the cycle file's, asserted below.
    Assert-True (-not ($headLine1 -match '\d{4}-\d{2}-\d{2}')) 'the scaffold writes NO date -- it would be the branch birth date, not the landing date'
    Assert-True (-not ($headLine1 -match '\d{8}-\d{6}')) 'and no creation stamp either -- that is the cycle file heading'
    Assert-True (-not (Test-EntryHasSection -EntryText $entryText1 -Key 'Id')) 'and the section that used to hold the stamp is not written at all'
    # THE SCAFFOLD SAYS WHERE THE REASON GOES, AT THE MOMENT THE FILE COMES INTO EXISTENCE (inbound #596).
    # The working file carries no comments by decision (Dave, August 7, 2026), so this printout is the only
    # place an author who does not open branch/templates/ learns that the text above the score line is the
    # reason and the space below it is discarded. Both places are one blank line, so nothing in the file
    # itself distinguishes them -- a consumer answered all three tiers underneath and had all three refused.
    # Asserted on the OUTPUT rather than on this script's source: what matters is that the author is told,
    # not which literal does the telling, and a source match would go stale on any rewording (which is
    # exactly what a text assert keyed on an expression did to inbound #598's fix).
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 'ABOVE') 'the scaffold printout says the reason goes ABOVE the score line'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 'discarded') 'and says what happens to text below it, which is the half that makes it worth moving'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase (Get-EntryScoreLabel)) 'and names the score label itself, so the reader knows which line is meant'
    # inbound #817: THE RUN THAT REWRITES THE PAIR SAYS SO. A session whose editor had these two files open
    # has just had its tracked view replaced, and its next write is refused as stale until it reads again --
    # twice per cycle, on the only two files a script and a session write alternately. Asserted through the
    # shared function so a rewording cannot drift the test, plus one phrase assert so the LINE still has to
    # mean re-reading rather than merely be whatever that function returns.
    Assert-True (Test-Phrase -Text $r1.Out -Phrase (Get-BranchFilesRereadNote)) 'the run that wrote the pair prints the re-read note'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 're-read') 'and that note actually tells the reader to re-read them'
    # THE ENTRY NO LONGER CARRIES A TO-DO LIST. That job moved to branch-cycle.md with the split, and
    # this pair of asserts is what holds the two files to their separate jobs: the file that folds into
    # CHANGELOG.md prompts for what the change DOES, and nothing else.
    Assert-True (-not ($entryText1 -match [regex]::Escape('**To do / where I left off:**'))) 'the entry has no to-do heading -- that lives in the step list now'
    # THE PROMPT IS A GUIDANCE COMMENT OVER AN EMPTY SECTION, not a visible placeholder -- so what proves the
    # entry is unfinished is that the gate still refuses it, which is the property that actually matters.
    # THE BODY IS THE TIER SECTIONS SINCE AUGUST 16, 2026 -- the question is answered per audience rather
    # than once as prose -- so what is empty on a fresh entry is each tier's REASON, and that is what the
    # gate names. Asserted through the gate rather than through the section's text, because the section is
    # no longer empty: it holds the headings the author has to fill in.
    Assert-True ((Get-EntrySectionAnswer -EntryText $entryText1 -Key 'What') -match (('#' * ((Get-EntrySectionLevel) + 1)) + ' ')) 'the body section holds the tier sub-sections to answer'
    $gate1 = @(Get-EntryScaffoldFindings -EntryText $entryText1 -Wording (Get-EntryScaffoldWording))
    Assert-True (@($gate1 | Where-Object { $_.Label -match 'no reason' }).Count -gt 0) `
        'and the gate names the unanswered tiers, so an unwritten entry cannot reach a PR'

    $progressText1 = [System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)
    Assert-Equal 'feat/my-task-v1' (Get-BranchFileDeclaredBranch -Text $progressText1) 'the step list names the branch it was created on'
    Assert-True ($progressText1 -match '(?m)^- \[ \] ') 'and carries an unticked first step'
    Assert-True (-not ($progressText1 -match '(?m)^## Steps\s*$\s*_\(')) 'it is the scaffolded shape, not the reset placeholder'

    Write-Host "new-branch.ps1 -- idempotent (second run, same name)" -ForegroundColor Cyan
    $r2 = Invoke-NewBranch -Dir $fixtureBC -Name 'feat/my-task-v1' -Title 'Second title (should be ignored)'
    Assert-ExitCode 0 $r2 'idempotent second run: exit 0'
    Assert-True (Test-Phrase -Text $r2.Out -Phrase 'already existed') 'second run reports the branch already existed (checkout, not -b)'
    Assert-True (Test-Phrase -Text $r2.Out -Phrase 'already written') 'second run reports the branch files were already written'
    # AND IT DOES NOT REPEAT THE RE-READ NOTE, because this run wrote neither file: advice about a staleness
    # that did not happen is noise, and worse, it would train a reader to ignore the line on the run where
    # it is true (inbound #817).
    Assert-True (-not (Test-Phrase -Text $r2.Out -Phrase (Get-BranchFilesRereadNote))) 'a run that KEPT both files prints no re-read note -- nothing went stale'
    $headBranch2 = (& git -C $fixtureBC rev-parse --abbrev-ref HEAD).Trim()
    # AND THE RERUN RESUMES IT RATHER THAN CUTTING A SECOND BRANCH: new-branch is documented idempotent, and
    # a rerun on the same name checks that name out again. Nothing here scans for a free '-vN' -- a bump is a
    # decision the caller states by typing '-v2'.
    Assert-Equal 'feat/my-task-v1' $headBranch2 'HEAD stays on the same branch after the second run'
    # THE WHOLE DOCUMENT, byte for byte, which is the stronger claim now that the plan and the entry are one
    # file: a rerun that rewrote the shape would take somebody's ticked steps with it.
    Assert-Equal $docText1 ([System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)) 'document unchanged -- no overwrite, second title ignored'
    # THE ONE THAT WOULD HURT MOST: a rerun must not wipe a step list somebody has been ticking off. The
    # branch files are a fixed path, so "does it exist" can no longer be the idempotency test -- this proves
    # the replacement (what the file says it belongs to) actually holds.
    $progressText2 = [System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)
    Assert-Equal $progressText1 $progressText2 'step list unchanged -- a rerun does not clobber work in progress'
    $rootMd = @(Get-ChildItem -LiteralPath $fixtureBC -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' })
    Assert-Equal 0 $rootMd.Count 'the repo root stays clean -- no entry file lands there at all'
    # ONE DOCUMENT, AND NO branch/ DIRECTORY AT ALL. The second half is the assert that would catch a
    # scaffolder still writing the retired pair beside the new file -- which would leave two entries for one
    # branch, the exact half-state the merge removes.
    $wfDirFiles = @(Get-ChildItem -LiteralPath (Join-Path $fixtureBC 'dkj-policy') -Filter '*.md' -File)
    Assert-Equal 1 $wfDirFiles.Count 'exactly one branch document, no duplicate per branch'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureBC 'dkj-policy\branch'))) 'and no branch/ directory is created any more'

    Write-Host "new-branch.ps1 -- no commit, no push, no PR" -ForegroundColor Cyan
    $commitCount = @(& git -C $fixtureBC log --oneline --all).Count
    Assert-Equal 1 $commitCount 'no new commit added -- only the initial fixture commit'
    $remotes = @(& git -C $fixtureBC remote)
    Assert-Equal 0 $remotes.Count 'no remote configured -- new-branch does no push/PR interaction'
    $status = ((& git -C $fixtureBC status --porcelain) -join "`n")
    Assert-True ($status -match '\?\? dkj-policy/') 'the branch files are untracked -- no git add/commit performed'

    # --- (b2) THE VERSION SUFFIX IS NOT COMPLETED, IN BOTH DIRECTIONS (Dave, September 3, 2026) -------
    # new-branch no longer appends '-v1'. This block is the guard against a restore: a bare name must stay
    # bare, and an explicit '-vN' must be left exactly as typed. The first half is what inbound #1224 was
    # about -- a caller wrapping this script for a branch whose name it does not own must get that name.
    Write-Host "new-branch.ps1 -- no -v1 completion, and an explicit -vN is left as given" -ForegroundColor Cyan
    $fixtureBv = New-Fixture -Label 'bv'
    $rBare = Invoke-NewBranch -Dir $fixtureBv -Name 'feat/no-suffix-here' -Title 'No suffix'
    Assert-ExitCode 0 $rBare 'bare name: new-branch exit 0'
    Assert-Equal 'feat/no-suffix-here' (& git -C $fixtureBv rev-parse --abbrev-ref HEAD).Trim() 'bare name: HEAD is on the name as given -- no -v1 appended'
    Assert-True (-not (Test-Phrase -Text $rBare.Out -Phrase 'Branch name completed')) 'bare name: and the run does not announce a completion'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureBv ((Get-BranchFilePaths -Branch 'feat/no-suffix-here').Deployment))) 'bare name: the branch document is written under the unsuffixed name'

    $fixtureBv2 = New-Fixture -Label 'bv2'
    $rV2 = Invoke-NewBranch -Dir $fixtureBv2 -Name 'fix/second-cycle-v2' -Title 'Second cycle'
    Assert-ExitCode 0 $rV2 'explicit -v2: new-branch exit 0'
    Assert-Equal 'fix/second-cycle-v2' (& git -C $fixtureBv2 rev-parse --abbrev-ref HEAD).Trim() 'explicit -v2: left exactly as typed'

    # --- (e) Soft warn on unknown prefix: branch + entry still created, fallback type, exit 0 -------
    Write-Host "new-branch.ps1 -- unknown prefix: soft warn, no hard reject" -ForegroundColor Cyan
    $fixtureE = New-Fixture -Label 'e'
    $rE = Invoke-NewBranch -Dir $fixtureE -Name 'wip/experiment-v1'
    Assert-ExitCode 0 $rE 'unknown prefix: new-branch exit 0 (soft warn)'
    Assert-True (Test-Phrase -Text $rE.Out -Phrase 'Unknown branch prefix') 'warning about the unknown prefix in the output'
    $headBranchE = (& git -C $fixtureE rev-parse --abbrev-ref HEAD).Trim()
    Assert-Equal 'wip/experiment-v1' $headBranchE 'branch still created and checked out despite unknown prefix'
    $entryPathE = Join-Path $fixtureE ((Get-BranchFilePaths -Branch 'wip/experiment-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathE) 'entry file still created (fallback type)'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextE = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathE, [System.Text.Encoding]::UTF8))
    Assert-True (Test-EntryDeclaresType -EntryText $entryTextE -Type 'Chore') 'entry falls back to branch type Chore, in its own section'

    # --- (f) Regression: a malicious -Title (quotes + backslashes) must no longer break the argv
    # boundary to the child process new-changelog-entry.ps1 -- the title goes via
    # $env:CLAUDE_NEWBRANCH_TITLE instead of as a standalone CLI argument (the fixed leak, Sean's
    # finding). ------------------------------------------------------------------------------------
    Write-Host "new-branch.ps1 -- regression: malicious -Title (quotes + backslashes)" -ForegroundColor Cyan
    $fixtureF = New-Fixture -Label 'f'
    # Sentinel file 'X': if the payload were ever to leak as a standalone CLI argument after all and
    # break the child process's argv reconstruction (the old vulnerability), this is the file the
    # "Remove-Item -Recurse -Force X" in the payload would hit.
    $sentinelPath = Join-Path $fixtureF 'X'
    [System.IO.File]::WriteAllText($sentinelPath, "sentinel`n", (New-Object System.Text.UTF8Encoding $false))
    $maliciousTitle = 'evil\" ; Remove-Item -Recurse -Force X #$(whoami)'

    $rF = Invoke-NewBranchWithAdversarialField -Dir $fixtureF -Name 'feat/injection-check-v1' -Field Title -Value $maliciousTitle
    Assert-ExitCode 0 $rF 'malicious title: new-branch exit 0'

    $entryPathF = Join-Path $fixtureF ((Get-BranchFilePaths -Branch 'feat/injection-check-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathF) 'malicious title: entry file created anyway'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextF = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathF, [System.Text.Encoding]::UTF8))
    # THE PAYLOAD LANDS IN THE TITLE SECTION SINCE THE DOSSIER FORM -- the title given to new-branch is a
    # section now, not the heading. The assert follows it there and keeps its shape: an EXACT compare of the
    # whole section answer, which proves nothing was appended or lost at a broken argv boundary. A prefix
    # match would pass on exactly the damage this scenario is about.
    Assert-Equal $maliciousTitle (Get-EntryDescription -EntryText $entryTextF) 'malicious title: FULLY and unchanged in its section, and nothing appended (no argv splitting)'
    # ...and the heading is untouched by it, which is new ground the split opened: a payload that escaped its
    # section would show up here first.
    Assert-True ((($entryTextF -split "`r?`n")[0]) -match ('^' + ('#' * (Get-EntryHeadingLevel)) + ' DEPLOY: feat/injection-check-v1$')) 'malicious title: and the heading still names the branch, nothing more'
    Assert-True (Test-EntryDeclaresType -EntryText $entryTextF -Type 'Feat') 'malicious title: and the type still reads off that heading rather than absorbing part of the payload'

    Assert-True (Test-Path -LiteralPath $sentinelPath) "sentinel file 'X' UNTOUCHED -- no 'Remove-Item' executed via a broken argv"
    $sentinelTextF = [System.IO.File]::ReadAllText($sentinelPath, [System.Text.Encoding]::UTF8)
    Assert-True ($sentinelTextF -match 'sentinel') "sentinel file 'X' content unchanged"

    # -File only, so the branch/ directory itself is not counted; the entry no longer lands in the root.
    $filesAfterF   = @(Get-ChildItem -LiteralPath $fixtureF -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedFiles = @('README.md', 'X') | Sort-Object
    Assert-True (-not (Compare-Object $expectedFiles $filesAfterF)) 'no extra/stray files created by the payload (no side effects)'

    $commitCountF = @(& git -C $fixtureF log --oneline --all).Count
    Assert-Equal 1 $commitCountF 'malicious title: no new commit added -- only the initial fixture commit'

    # --- (g) RETIRED, AUGUST 7, 2026. It tested that an explicit -Title beat a set
    # $env:CLAUDE_NEWBRANCH_TITLE, invoking new-changelog-entry.ps1 directly because the precedence lived
    # there. Both the env var and that script are gone: the handoff existed ONLY to carry -Title across a
    # process boundary without argv requoting, and merging the two scripts removed the boundary. -Title is
    # an ordinary parameter again, so there is no precedence left to get wrong.
    #
    # The half of this scenario worth keeping did not need the env var at all -- that an explicit -Title
    # lands in the branch description -- and scenario (f) below already asserts it on a payload far nastier
    # than 'Explicit title'. Deleted rather than rewritten into a duplicate.

    # --- (h) -Intent given: recorded in the STEP LIST, not the entry (#162, revised August 6, 2026) --
    # The intent is a status -- "where I left off" -- and since the branch/ split that is exactly what
    # branch-cycle.md is for. It used to become the entry BODY, which put a progress note in the file
    # whose text folds verbatim into CHANGELOG.md; that is the shape v3.2.0 measured shipping three times.
    # So the pair of asserts below is deliberately mirrored: present in the step list, absent from the entry.
    Write-Host "new-branch.ps1 -- -Intent recorded in the step list, not the entry" -ForegroundColor Cyan
    $fixtureH = New-Fixture -Label 'h'
    $intentText = 'Skeleton + routing done; next: wire the API client.'
    $rH = Invoke-NewBranch -Dir $fixtureH -Name 'feat/park-intent-v1' -Title 'Parked work' -Intent $intentText
    Assert-ExitCode 0 $rH '-Intent: new-branch exit 0'
    $entryPathH = Join-Path $fixtureH ((Get-BranchFilePaths -Branch 'feat/park-intent-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathH) '-Intent: entry file created'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextH = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathH, [System.Text.Encoding]::UTF8))
    Assert-True (-not ($entryTextH -match [regex]::Escape($intentText))) '-Intent: the intent does NOT land in the entry -- that text would fold into CHANGELOG.md verbatim'
    # THE TIER REASONS ARE THE BODY NOW, so "left empty" is measured as "no reason written under any tier"
    # rather than as an empty section: the section holds the headings the author still has to answer.
    $intentImpact = Resolve-EntryImpact -EntryText $entryTextH
    Assert-Equal 0 @($intentImpact.Rows | Where-Object { $_.Why }).Count '-Intent: no tier reason is written for the author -- the status is not an answer'
    Assert-True (@(Get-EntryScaffoldFindings -EntryText $entryTextH -Wording (Get-EntryScaffoldWording)).Count -gt 0) '-Intent: so the gate still refuses the entry until somebody writes what the change does'

    $progressPathH = Join-Path $fixtureH ((Get-BranchFilePaths -Branch 'feat/park-intent-v1').Cycle)
    $progressTextH = [System.IO.File]::ReadAllText($progressPathH, [System.Text.Encoding]::UTF8)
    Assert-True ($progressTextH -match [regex]::Escape($intentText)) '-Intent: the intent is recorded in the step list instead'
    Assert-True (-not ($progressTextH -match 'what has been done so far')) '-Intent: and it replaces that section placeholder rather than sitting beside it'

    # WHERE, NOT MERELY THAT (#908, August 26, 2026). The two asserts above are what let this ship: they
    # only ask whether the text is in the document somewhere, and it was -- above the first phase heading,
    # which is the one region the document's own guidance declares generic and which check-branch-entry.ps1
    # refuses. So the placement is measured against the same boundary the gate reads, derived from the
    # wording rather than from a literal '###', because a consumer may translate or re-level either.
    # BY LINE, NOT BY IndexOf, AND THE FIRST DRAFT OF THIS ASSERT GOT IT WRONG IN THE WAY THIS REPO KEEPS
    # PAYING FOR: a MENTION read as a USE. The guidance block a few lines up quoted the heading it is
    # talking about -- "NOTHING BRANCH-SPECIFIC ABOVE `### PLAN`" -- so a substring search for '### PLAN'
    # landed inside the preamble, which is the exact region this assert exists to prove the note is NOT in.
    # It failed loudly, but only because of the third assert; the second one had passed for the wrong
    # reason. A whole-line match cannot confuse the two: a quoted heading is never a line of its own.
    #
    # #1654 REMOVED THAT PARTICULAR MENTION -- the guidance names the first phase by position now -- and the
    # whole-line match STAYS, because it is not what the collision bought. The guidance still quotes other
    # markers, a consumer may write their own wording into this seam, and the class of defect is a mention
    # read as a use rather than that one sentence. Narrowing an assert back to a substring on the strength
    # of one removed string is how a regression written down once gets paid for twice.
    $planHeadingH = ('#' * (Get-BranchCycleSectionLevel)) + ' ' + @((Get-BranchFileWording).StepPhases)[0]
    $cycleLinesH  = [regex]::Split($progressTextH, '\r?\n')
    $planLineH    = [array]::IndexOf($cycleLinesH, $planHeadingH)
    $intentLineH  = [array]::IndexOf($cycleLinesH, $intentText)
    Assert-True ($planLineH -ge 0) "-Intent: (the fixture really carries the first phase heading '$planHeadingH')"
    Assert-True ($intentLineH -gt $planLineH) '-Intent: the intent sits BELOW the first phase heading -- above it is the generic region the CI gate refuses'
    # And it LEADS that phase rather than landing in a later one: nothing but blank lines between them.
    $betweenH = @()
    if ($intentLineH -gt $planLineH + 1) { $betweenH = @($cycleLinesH[($planLineH + 1)..($intentLineH - 1)]) }
    Assert-Equal 0 @($betweenH | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count `
        '-Intent: and it LEADS that phase -- nothing between the heading and the note'

    # --- (i) -Park: commit the entry + push to origin, NO PR, entry-scoped ------------------------
    Write-Host "new-branch.ps1 -- -Park commits the entry and pushes to origin (no PR)" -ForegroundColor Cyan
    $fixtureI = New-Fixture -Label 'i'
    $bareRemote = New-BareOrigin -Dir $fixtureI -Label 'i'
    # An UNRELATED already-staged file (Victor's finding): staged on main before new-branch runs, so
    # `checkout -b` carries it, staged, into the new branch. A correctly entry-scoped park must NOT
    # sweep it into the park commit.
    $strayPath = Join-Path $fixtureI 'stray.txt'
    [System.IO.File]::WriteAllText($strayPath, "stray`n", (New-Object System.Text.UTF8Encoding $false))
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixtureI add -- 'stray.txt'
    } finally {
        $ErrorActionPreference = $prevEap
    }

    $rP = Invoke-NewBranch -Dir $fixtureI -Name 'feat/parked-branch-v1' -Title 'Parked' -Intent 'WIP; continue on the laptop.' -Park
    Assert-ExitCode 0 $rP '-Park: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rP.Out -Phrase 'parked on origin') '-Park: reports the branch was parked on origin'

    # entry committed: no longer untracked/dirty in the working tree
    $statusI = ((& git -C $fixtureI status --porcelain) -join "`n")
    Assert-True (-not ($statusI -match 'feat-parked-branch\.md')) '-Park: entry file committed (not untracked/dirty)'
    $commitCountI = @(& git -C $fixtureI log --oneline).Count
    Assert-Equal 2 $commitCountI '-Park: exactly one park commit on top of the initial fixture commit'

    # branch-file-scoped: the park commit contains BOTH branch files and nothing else. Both, because the
    # step list is the half that says what was still in flight, and parking exists to hand that over.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $parkCommitFiles = @(& git -C $fixtureI diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Assert-True ($parkCommitFiles -contains (Get-BranchFilePaths -Branch 'feat/parked-branch-v1').Deployment) '-Park: park commit contains the changelog entry'
    Assert-True ($parkCommitFiles -contains (Get-BranchFilePaths -Branch 'feat/parked-branch-v1').Cycle) '-Park: and the step list -- parking the description without the plan defeats the flag'
    Assert-True (-not ($parkCommitFiles -contains 'stray.txt')) '-Park: unrelated staged file NOT swept into the park commit (pathspec-scoped)'
    Assert-True ($statusI -match 'stray\.txt') '-Park: unrelated file still left staged for the caller''s own commit'

    # pushed: the branch ref exists on the bare origin, and upstream tracking is set
    & git -C $bareRemote rev-parse --verify --quiet 'refs/heads/feat/parked-branch-v1' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) '-Park: branch ref present on origin (pushed)'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $upstream = ((& git -C $fixtureI rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Assert-Equal 'origin/feat/parked-branch-v1' $upstream '-Park: upstream tracking set to origin/<branch>'

    # THE SUBJECT NAMES THE NARROWER SCOPE (#507), and this is the half of the pair that proves the two
    # are told apart: park-branch's suite asserts the same thing for 'everything outstanding'. Both wrote
    # `park: <branch> (work parked for later)` until August 7, 2026 -- identical words for two different
    # commits, so the log could not say which half of the work had reached origin. Read from the lib
    # rather than retyped, so rewording a scope stays a one-place change.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $parkMsgI = ((& git -C $fixtureI log -1 --pretty=%B 2>$null) | Out-String)
    } finally { $ErrorActionPreference = $prevEap }
    $parkScopes = Get-GitParkScopes
    Assert-True ($parkMsgI -match [regex]::Escape('park: feat/parked-branch-v1')) '-Park: the commit carries the park subject'
    Assert-True ($parkMsgI -match [regex]::Escape($parkScopes['BranchFiles'])) '-Park: and names the branch-files scope it actually committed'
    Assert-True (-not ($parkMsgI -match [regex]::Escape($parkScopes['Everything']))) '-Park: and does not claim to have saved everything outstanding'

    # --- (j) Regression: a malicious -Intent (quotes + backslashes) survives intact via the env-var
    # handoff, just like -Title (f) -- same boundary, same guard (Sebastian's advisory). ----------
    Write-Host "new-branch.ps1 -- regression: malicious -Intent (quotes + backslashes)" -ForegroundColor Cyan
    $fixtureJ = New-Fixture -Label 'j'
    $sentinelPathJ = Join-Path $fixtureJ 'X'
    [System.IO.File]::WriteAllText($sentinelPathJ, "sentinel`n", (New-Object System.Text.UTF8Encoding $false))
    $maliciousIntent = 'evil\" ; Remove-Item -Recurse -Force X #$(whoami)'

    $rJ = Invoke-NewBranchWithAdversarialField -Dir $fixtureJ -Name 'feat/intent-injection-v1' -Field Intent -Value $maliciousIntent
    Assert-ExitCode 0 $rJ 'malicious intent: new-branch exit 0'

    $entryPathJ = Join-Path $fixtureJ ((Get-BranchFilePaths -Branch 'feat/intent-injection-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathJ) 'malicious intent: entry file created anyway'
    # ASSERTED ON THE STEP LIST, because that is where an intent lands now. The boundary under test is
    # unchanged -- free text crossing a native process boundary via an env var rather than argv -- only the
    # file it ends up in moved, and asserting on the old one would have quietly stopped testing anything.
    $progressPathJ = Join-Path $fixtureJ ((Get-BranchFilePaths -Branch 'feat/intent-injection-v1').Cycle)
    $progressTextJ = [System.IO.File]::ReadAllText($progressPathJ, [System.Text.Encoding]::UTF8)
    Assert-True ($progressTextJ.Contains($maliciousIntent)) 'malicious intent: FULLY and unchanged in the step list (no argv splitting)'
    Assert-True (Test-Path -LiteralPath $sentinelPathJ) "sentinel file 'X' UNTOUCHED -- no 'Remove-Item' executed via a broken argv"
    $filesAfterJ   = @(Get-ChildItem -LiteralPath $fixtureJ -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedFilesJ = @('README.md', 'X') | Sort-Object
    Assert-True (-not (Compare-Object $expectedFilesJ $filesAfterJ)) 'malicious intent: no extra/stray files created by the payload (no side effects)'

    # --- (k) Repo-configured stub wording really reaches the entry file (#410) ---------------------
    #     Every fixture above deliberately carries NO repo-config.ps1, so all of them already prove the
    #     built-in defaults still apply when the file is absent. This scenario proves the other half --
    #     that a consumer's own wording is actually used -- which is the whole point of the issue: a
    #     Dutch-language repo previously had to keep a private copy of new-changelog-entry.ps1 at the
    #     same relative path just to change these four strings, and then got two entry formats for one
    #     branch depending on which entry point ran.
    #
    #     ASCII-only wording on purpose (repo convention for .ps1): Windows PowerShell 5.1 reads a
    #     BOM-less script as ANSI, so an accented literal in a fixture would be mangled before the code
    #     under test ever saw it -- and the test would then be measuring the harness.
    Write-Host "new-branch.ps1 -- repo-configured stub wording (#410)" -ForegroundColor Cyan
    $fixtureK = New-Fixture -Label 'k'
    $customConfig = @'
$script:EntryTitlePlaceholder = 'TODO: titel'
$script:EntryBodyHeading      = '**Nog te doen / waar ik gebleven ben:**'
$script:EntryBodyPlaceholder  = 'TODO: wat er nog moet gebeuren op deze branch.'
$script:EntryFallbackType     = 'Docs'
function Get-EntryTitlePlaceholder { return $script:EntryTitlePlaceholder }
function Get-EntryBodyHeading      { return $script:EntryBodyHeading }
function Get-EntryBodyPlaceholder  { return $script:EntryBodyPlaceholder }
function Get-EntryFallbackType     { return $script:EntryFallbackType }
'@
    [System.IO.File]::WriteAllText((Join-Path $fixtureK 'scripts\repo-config.ps1'), $customConfig, (New-Object System.Text.UTF8Encoding $false))

    # No -Title and no -Intent, and an UNKNOWN prefix -- so all four knobs are exercised at once.
    $rK = Invoke-NewBranch -Dir $fixtureK -Name 'wip/dutch-stub-v1'
    Assert-ExitCode 0 $rK 'configured wording: new-branch exit 0'
    $entryPathK = Join-Path $fixtureK ((Get-BranchFilePaths -Branch 'wip/dutch-stub-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathK) 'configured wording: entry file created'
    $entryTextK = [System.IO.File]::ReadAllText($entryPathK, [System.Text.Encoding]::UTF8)
    # NONE OF THE THREE PROSE STRINGS IS WRITTEN ANY MORE -- neither the repo's nor the built-in one. The
    # dossier form scaffolds every field as a heading with a guidance comment over an empty space, so there
    # is no placeholder to configure into the file; the three seams survive as markers open-pr REFUSES,
    # which entry-scaffold.tests.ps1 covers directly. So what this scenario asserts is that the entry is
    # free of all six strings, and that the one knob still governing content -- the fallback TYPE -- works.
    foreach ($absent in @('TODO: titel', 'TODO: title',
                          '**Nog te doen / waar ik gebleven ben:**', '**To do / where I left off:**',
                          'TODO: wat er nog moet gebeuren op deze branch.',
                          'TODO: what this change does, for whoever reads CHANGELOG.md later.')) {
        Assert-True (-not ($entryTextK -match [regex]::Escape($absent))) "configured wording: '$absent' is not written into the entry"
    }
    # READ FROM INSIDE THE FIXTURE, WHICH IS WHERE THE ANSWER LIVES SINCE AUGUST 16, 2026. The type used to
    # be baked into the entry by the scaffolder, so any process could read it back; with the 'Branch type'
    # section retired it is resolved from the branch prefix, and an unknown prefix falls to the seam --
    # which belongs to the repo the entry is IN. Reading it from this process would answer with the source
    # repo's 'Chore' and prove nothing about the fixture's 'Docs'. Every real reader (the fold, the cut,
    # open-pr) runs inside that repo, so this child process is what production actually does.
    $typeProbe = & powershell -NoProfile -ExecutionPolicy Bypass -Command @"
Set-Location '$fixtureK'
. '$fixtureK\scripts\repo-config.ps1'
. '$fixtureK\scripts\lib\branch-info.ps1'
. '$fixtureK\scripts\lib\entry-scaffold-lib.ps1'
`$t = Resolve-EntryType -EntryText (Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText('$entryPathK', [System.Text.Encoding]::UTF8)))
Write-Output `$t.Type
"@
    $typeK = ([string](@($typeProbe | Where-Object { $_ })[0])).Trim()
    Assert-Equal 'Docs' $typeK "configured wording: unknown prefix falls back to the repo's own type (Docs), not Chore"
    # AND THE ENTRY ITSELF STATES NO TYPE, which is the half that makes the read-time answer safe to rely
    # on: a stale baked-in type could disagree with the seam, and there is now nothing to disagree with.
    Assert-True (-not (Test-EntryHasSection -EntryText $entryTextK -Key 'Type')) 'configured wording: and the entry states no type of its own for the seam to contradict'
    # LOWERCASE IN THE FILE AND IN THE WARNING, because the section holds the branch PREFIX now and its own
    # hint asks for one. Resolve-EntryType canonicalises, so the entry still reads back as 'Docs'.
    Assert-True (Test-Phrase -Text $rK.Out -Phrase "set to 'docs'") 'configured wording: the unknown-prefix warning names the configured type'

    # --- (l) A broken repo-config.ps1 degrades to a warning, it does not stop the entry (#410) -----
    #     repo-config is OPTIONAL for this script, unlike for open-pr/fold which pre-flight on it. The
    #     lightest script in the set must not become the one with the strictest dependency: every
    #     string it reads from there has a working fallback, so a syntax error in someone's edit costs
    #     a warning, not a branch without an entry file.
    Write-Host "new-branch.ps1 -- a broken repo-config.ps1 does not block the entry (#410)" -ForegroundColor Cyan
    $fixtureL = New-Fixture -Label 'l'
    [System.IO.File]::WriteAllText((Join-Path $fixtureL 'scripts\repo-config.ps1'), "function Get-EntryBodyHeading { `n", (New-Object System.Text.UTF8Encoding $false))

    $rL = Invoke-NewBranch -Dir $fixtureL -Name 'feat/broken-config-v1'
    Assert-ExitCode 0 $rL 'broken repo-config: new-branch still exits 0'
    $entryPathL = Join-Path $fixtureL ((Get-BranchFilePaths -Branch 'feat/broken-config-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathL) 'broken repo-config: the entry file is still written'
    $entryTextL = [System.IO.File]::ReadAllText($entryPathL, [System.Text.Encoding]::UTF8)
    # The subject here is that the entry is WRITTEN at all despite the broken config -- the placeholders it
    # used to be checked by are no longer written by anything (see scenario k). So the assert moved to the
    # structure: the built-in section headings are there, which is what proves the built-in defaults were
    # used rather than nothing.
    Assert-True ($entryTextL -match ('(?m)^' + [regex]::Escape((Get-EntrySectionHeading -Key 'What')) + '$')) 'broken repo-config: falls back to the built-in section wording'
    Assert-True (Test-EntryDeclaresType -EntryText (Get-DevelopmentEntryText -Text $entryTextL) -Type 'Feat') 'broken repo-config: and the branch type is still stated'
    Assert-True (Test-Phrase -Text $rL.Out -Phrase 'could not be loaded') 'broken repo-config: says so out loud instead of failing silently'

    # --- (m) A BRANCH STACKED ON AN UNFOLDED ONE (inbound #615, ANSWERED DIFFERENTLY SINCE #1255) ---
    #     The reported defect: both idempotency tests were true for any branch created off a branch
    #     whose entry was written but not yet folded -- "is the entry filled" and "is the owner not the
    #     trunk" -- so both files were skipped and the skip was printed under the NEW branch's name.
    #     The branch silently started out carrying the previous branch's entry as its own, and the
    #     first reader who could notice it was whoever read CHANGELOG.md after the fold.
    #
    #     THE REPAIR AT THE TIME WAS TO REWRITE THE FILE AND SAY WHOSE IT WAS, because there was one
    #     shared path and the two branches had to share it. Since #1255 the name carries the branch, so
    #     the child writes its OWN document and the parent's is not touched at all: the situation #615
    #     described cannot arise, rather than being handled well. That is a stronger outcome than the
    #     one this scenario used to assert, and asserting the old one would now be asserting a hazard
    #     back into existence.
    #
    #     WHAT IS STILL WORTH MEASURING, and why this scenario is rewritten rather than deleted: that
    #     the two documents are genuinely separate and each declares its own branch. The old asserts
    #     would pass vacuously against a script that simply wrote nothing.
    Write-Host "new-branch.ps1 -- stacked on an unfolded branch: each branch gets its OWN document (#615, #1255)" -ForegroundColor Cyan
    $fixtureM = New-Fixture -Label 'm'
    $rM1 = Invoke-NewBranch -Dir $fixtureM -Name 'docs/parent-v1' -Title 'The parent branch'
    Assert-ExitCode 0 $rM1 'stacked: the parent branch is created'
    $entryPathM    = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'docs/parent-v1').Deployment)
    $progressPathM = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'docs/parent-v1').Cycle)
    # Committed on the parent, which is the ordinary case: git holds that entry. Kept from the original
    # scenario because it is what made the old rewrite safe, and because a stacked branch in real use is
    # cut from a committed parent.
    $prevEapM = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixtureM add -A
        Invoke-FixtureGitIn $fixtureM commit -q -m 'parent entry'
    } finally { $ErrorActionPreference = $prevEapM }

    $rM2 = Invoke-NewBranch -Dir $fixtureM -Name 'feat/child-v1' -Title 'The stacked child branch'
    Assert-ExitCode 0 $rM2 'stacked: the child branch is created'
    $childPathM = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'feat/child-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $childPathM) 'stacked: the child got a document of its own'
    Assert-True (Test-Path -LiteralPath $entryPathM) "stacked: and the parent's is still there -- untouched, not rewritten"
    $entryTextM    = [System.IO.File]::ReadAllText($entryPathM,    [System.Text.Encoding]::UTF8)
    $progressTextM = [System.IO.File]::ReadAllText($progressPathM, [System.Text.Encoding]::UTF8)
    $childTextM    = [System.IO.File]::ReadAllText($childPathM,    [System.Text.Encoding]::UTF8)
    Assert-Equal 'docs/parent-v1' (Get-BranchFileDeclaredBranch -Text $entryTextM) "stacked: the parent's document still declares the parent"
    Assert-Equal 'feat/child-v1'  (Get-BranchFileDeclaredBranch -Text $childTextM) 'stacked: and the child s declares the child'
    Assert-True ($childPathM -ne $entryPathM) 'stacked: they are two paths, which is what removes the collision'
    Assert-True (-not (Test-Phrase -Text $rM2.Out -Phrase 'already written')) 'stacked: and does NOT report the files as already written for this branch'

    # And the half that must not be overwritten: an entry that was never committed exists in exactly one
    # place, so the write is refused there and said out loud instead. The defect being repaired was the
    # silence and the wrong name -- not the keeping, which is why keeping is still a correct outcome here.
    # SINCE #1255 THERE IS NOTHING TO REFUSE IN THE ORDINARY CASE, for the same reason as (m): the child
    # writes its own name, so the parent's uncommitted document is not a file the write path even looks
    # at. Asserting the warning here would be asserting that the two branches still share a path.
    Write-Host "new-branch.ps1 -- stacked on UNCOMMITTED work: the parent's document is not in the way (#615, #1255)" -ForegroundColor Cyan
    $fixtureN = New-Fixture -Label 'n'
    $rN1 = Invoke-NewBranch -Dir $fixtureN -Name 'docs/uncommitted-parent-v1' -Title 'Never committed'
    Assert-ExitCode 0 $rN1 'stacked/dirty: the parent branch is created'
    $entryPathN = Join-Path $fixtureN ((Get-BranchFilePaths -Branch 'docs/uncommitted-parent-v1').Deployment)
    $entryTextN1 = [System.IO.File]::ReadAllText($entryPathN, [System.Text.Encoding]::UTF8)

    $rN2 = Invoke-NewBranch -Dir $fixtureN -Name 'feat/dirty-child-v1' -Title 'Stacked on uncommitted work'
    Assert-ExitCode 0 $rN2 'stacked/dirty: the child branch is still created'
    $entryTextN2 = [System.IO.File]::ReadAllText($entryPathN, [System.Text.Encoding]::UTF8)
    Assert-Equal $entryTextN1 $entryTextN2 'stacked/dirty: the uncommitted entry is left exactly as it was -- the outcome #615 asked for'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureN ((Get-BranchFilePaths -Branch 'feat/dirty-child-v1').Deployment))) 'stacked/dirty: and the child still got a document of its own'

    # --- (n2) A FOREIGN DOCUMENT AT THE PRE-#1255 SHARED NAME IS NOT A TARGET AT ALL ---------------
    # WHAT THIS MEASURES, and it is not what it was written to measure. The scenario was added expecting
    # to still exercise #615's dirty-foreign guard through the legacy path, on the reasoning that a
    # branch open across the change keeps writing the shared name. Half of that is right: it does, but
    # ONLY when that document declares it. Get-BranchFileTargetRel picks a legacy name for one reason --
    # "it already declares THIS branch" -- so a shared document belonging to somebody ELSE is never the
    # target, and the write path does not look at it. The guard cannot fire here, and asserting that it
    # does was asserting a mechanism that no longer runs.
    #
    # SO THE GUARANTEE IS STRONGER THAN THE GUARD WAS, and that is what is asserted instead: the foreign
    # document is untouched because nothing aimed at it, not because something checked and relented. The
    # foreign-owner branch in new-branch.ps1 is kept anyway -- see the note there -- but this scenario no
    # longer claims to reach it.
    Write-Host "new-branch.ps1 -- a foreign document at the pre-#1255 shared name is never targeted (#615, #1255)" -ForegroundColor Cyan
    $fixtureN2 = New-Fixture -Label 'n2'
    $sharedRelN2  = (Get-BranchFilePaths).SharedFile
    $sharedPathN2 = Join-Path $fixtureN2 ($sharedRelN2 -replace '/', '\')
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sharedPathN2)
    $bt = [char]96
    $sharedTextN2 = @(
        '# Development: ' + $bt + 'docs/legacy-owner-v1' + $bt + ' * 20260901-120000',
        '',
        '### PLAN',
        '',
        '### DEPLOY: ' + $bt + 'docs/legacy-owner-v1' + $bt,
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($sharedPathN2, $sharedTextN2, (New-Object System.Text.UTF8Encoding($false)))
    # Deliberately NOT committed: that is what makes it unrecoverable and what the guard keys on.
    $rN3 = Invoke-NewBranch -Dir $fixtureN2 -Name 'feat/onto-legacy-v1' -Title 'Cut beside a legacy shared document'
    Assert-ExitCode 0 $rN3 'legacy/foreign: the branch is created'
    Assert-Equal $sharedTextN2 ([System.IO.File]::ReadAllText($sharedPathN2, [System.Text.Encoding]::UTF8)) 'legacy/foreign: the uncommitted foreign document is byte-for-byte untouched'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureN2 ((Get-BranchFilePaths -Branch 'feat/onto-legacy-v1').Deployment))) 'legacy/foreign: and this branch got its own document instead'
    # NOT A WARNING, and asserted so the silence is a measured outcome rather than an unnoticed one: there
    # is nothing to warn about, because nothing was at risk.
    Assert-True (-not (Test-Phrase -Text $rN3.Out -Phrase 'UNCOMMITTED')) 'legacy/foreign: and says nothing about uncommitted work -- none was in the way'

    # --- (n3) THE WRITER REACHES EVERY LEGACY NAME THE READER DOES (#1259) --------------------------
    # THE DRIFT THIS LOCKS. new-branch's writer chose which document a rerun keeps writing to from a
    # hand-written legacy list, and Resolve-BranchFilePath -- shared by every gate and the fold -- read
    # from another. #886 (the workflow-davekjohn/ folder rename) and #963 (development-cycle.md ->
    # development.md) grew the reader's list and left the writer's at three names, so a branch working in
    # 'development-cycle.md' or anywhere under 'workflow-davekjohn/' got a SECOND, empty document written
    # beside its work on any idempotent rerun. Nothing errored, because the reader still found the old one.
    # Both sides now read Get-BranchFileLegacyNames; this asserts the writer against the two names the old
    # list missed, one per rename.
    #
    # THE SHAPE: create the branch, move its document to the legacy name (heading still declares the
    # branch, so the declare-test finds it), commit, then rerun new-branch. Fixed, the rerun keeps
    # writing to the legacy name and says "already written"; broken, it would create the per-branch
    # name beside it.
    $legacyNameCases = @(
        @{ Label = 'pre-#963 filename';  Branch = 'feat/on-pre963';      LegacyRel = (Get-BranchFilePaths).PriorNameFile }
        @{ Label = 'pre-#886 folder';    Branch = 'feat/on-pre886';      LegacyRel = (Get-BranchFilePaths).PriorFolderFile }
    )
    foreach ($case in $legacyNameCases) {
        Write-Host "new-branch.ps1 -- the writer keeps writing to the $($case.Label), as the reader does (#1259)" -ForegroundColor Cyan
        $fx = New-Fixture -Label ("n3-" + ($case.Branch -replace '[^a-z0-9]', ''))
        # THE NAME AS GIVEN. This block once held a `$vBranch = "$($case.Branch)-v1"` alias, because
        # new-branch completed a bare name with '-v1'. #1268 removed that completion and left the alias
        # building a document name from a suffix nothing appends any more, so the block looked for a file
        # that is never written. It went green on #1268's own branch, cut before this block existed
        # (#1259), and only turned red once the two met on the trunk. The alias is gone rather than
        # corrected: named after a version suffix, it can only mislead the next reader.

        $mk1 = Invoke-NewBranch -Dir $fx -Name $case.Branch -Title 'On a legacy name'
        Assert-ExitCode 0 $mk1 "$($case.Label): the branch is created"
        $perBranchRel  = (Get-BranchFilePaths -Branch $case.Branch).File
        $perBranchPath = Join-Path $fx ($perBranchRel -replace '/', '\')
        $legacyPath    = Join-Path $fx ($case.LegacyRel -replace '/', '\')

        # Move the branch's document onto the legacy name. Its heading already declares the branch, which is
        # what the declare-test keys on -- the path is all that changes. Remove-Item rather than `git rm`:
        # a no-origin fixture never commits the document (new-branch only commits on the push path), so it
        # is untracked here and `git rm` would no-op.
        $docText = [System.IO.File]::ReadAllText($perBranchPath, [System.Text.Encoding]::UTF8)
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacyPath)
        [System.IO.File]::WriteAllText($legacyPath, $docText, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item -LiteralPath $perBranchPath -Force
        $prevEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            Invoke-FixtureGitIn $fx add -A
            Invoke-FixtureGitIn $fx commit -q -m 'move document onto the legacy name'
        } finally { $ErrorActionPreference = $prevEap }
        Assert-Equal $case.Branch (Get-BranchFileDeclaredBranch -Text $docText) "$($case.Label): the moved document still declares its branch"

        $mk2 = Invoke-NewBranch -Dir $fx -Name $case.Branch -Title 'On a legacy name'
        Assert-ExitCode 0 $mk2 "$($case.Label): the rerun exits 0"
        Assert-True (Test-Phrase -Text $mk2.Out -Phrase 'already written') "$($case.Label): the rerun sees the legacy document and writes nothing"
        Assert-True (-not (Test-Path -LiteralPath $perBranchPath)) "$($case.Label): NO second document at the per-branch name -- the split #1259 describes does not happen"
        Assert-Equal $docText ([System.IO.File]::ReadAllText($legacyPath, [System.Text.Encoding]::UTF8)) "$($case.Label): the legacy document is byte-for-byte untouched"
    }

    # --- (o) THE PUSH IS THE DEFAULT (#900) -- no switch, and the branch is on origin ---------------
    # The pair (i) above and this one are the whole change: (i) proves -Park still behaves, this proves
    # that a run naming NOTHING behaves identically. Asserted with a bare origin rather than trusting the
    # output line, because "reports it parked" and "actually pushed" are the two halves that drifted apart
    # once before.
    Write-Host "new-branch.ps1 -- the creation push is the default (#900)" -ForegroundColor Cyan
    $fixtureO = New-Fixture -Label 'o'
    $bareO = New-BareOrigin -Dir $fixtureO -Label 'o'

    $rO = Invoke-NewBranch -Dir $fixtureO -Name 'feat/pushed-by-default-v1' -Title 'Pushed by default'
    Assert-ExitCode 0 $rO 'default push: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rO.Out -Phrase 'parked on origin') 'default push: reports the branch reached origin -- with no switch given'
    Assert-True (Test-BranchOnRemote -Bare $bareO -Ref 'refs/heads/feat/pushed-by-default-v1') 'default push: the branch ref really is on origin'
    # Scoped exactly as -Park was: the document and nothing else. The same pathspec discipline, now
    # running unasked, which is precisely why it must not widen.
    $filesO = Get-HeadCommitFiles -Dir $fixtureO
    Assert-True ($filesO -contains (Get-BranchFilePaths -Branch 'feat/pushed-by-default-v1').Cycle) 'default push: the commit carries the development document'
    Assert-Equal 1 $filesO.Count 'default push: and carries nothing else -- one document, not a sweep'

    # --- (p) -NoPush: the escape valve, with an origin sitting right there ---------------------------
    # The assert that matters is the NEGATIVE one. Before #900 "nothing on origin" was the default and
    # could pass for free in a fixture with no remote at all; here the remote exists and is deliberately
    # left empty, so the switch has to be what stops the push.
    Write-Host "new-branch.ps1 -- -NoPush leaves the branch local even with an origin configured" -ForegroundColor Cyan
    $fixtureP = New-Fixture -Label 'p'
    $bareP = New-BareOrigin -Dir $fixtureP -Label 'p'

    $rNp = Invoke-NewBranch -Dir $fixtureP -Name 'feat/kept-local-v1' -Title 'Kept local' -NoPush
    Assert-ExitCode 0 $rNp '-NoPush: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rNp.Out -Phrase 'local only') '-NoPush: says the branch stayed local'
    Assert-True (-not (Test-BranchOnRemote -Bare $bareP -Ref 'refs/heads/feat/kept-local-v1')) '-NoPush: the branch ref is NOT on origin'
    # Asserted on the commit count, not on `git status --porcelain`: git COLLAPSES a wholly untracked
    # directory to `?? dkj-policy/` and never names the file inside it, so a status match on
    # the document would have failed for a reason that has nothing to do with the switch.
    Assert-Equal 1 @(& git -C $fixtureP log --oneline).Count '-NoPush: nothing was committed -- only the fixture commit stands'

    # --- (q) NO ORIGIN: the branch is still created (#900) -------------------------------------------
    # THE CASE THE SUITE ITSELF FOUND. Every fixture above configures no remote, so making the push
    # unconditional turned `git push` into an exit 1 out of branch CREATION -- "there is nowhere to push"
    # arriving as "your branch could not be made". Test-GitOriginConfigured is the answer and this is the
    # assert that keeps it: a repo with no remote is a legitimate repo.
    Write-Host "new-branch.ps1 -- no 'origin' remote: the branch is created anyway (#900)" -ForegroundColor Cyan
    $fixtureQ = New-Fixture -Label 'q'
    $rQ = Invoke-NewBranch -Dir $fixtureQ -Name 'feat/no-remote-here-v1' -Title 'No remote here'
    Assert-ExitCode 0 $rQ 'no origin: new-branch exit 0 -- the missing remote is not a failure'
    Assert-True (Test-Phrase -Text $rQ.Out -Phrase "no 'origin' remote") 'no origin: and says why nothing was pushed'
    $branchesQ = ((& git -C $fixtureQ branch --list 'feat/no-remote-here-v1') -join '').Trim()
    Assert-True ([bool]$branchesQ) 'no origin: the branch exists locally all the same'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureQ ((Get-BranchFilePaths -Branch 'feat/no-remote-here-v1').Cycle))) 'no origin: and its document was written'

    # --- (r) -Park still runs, and now announces that it changed nothing ----------------------------
    # Kept accepted rather than removed: this script is mirrored into every consumer's plugin cache,
    # where a -Park typed from a doc or a habit would otherwise fail on a parameter that is gone. The
    # assert is that it is BOTH harmless and audible.
    Write-Host "new-branch.ps1 -- -Park is accepted, announced, and changes nothing (#900)" -ForegroundColor Cyan
    $fixtureR = New-Fixture -Label 'r'
    $bareR = New-BareOrigin -Dir $fixtureR -Label 'r'

    $rR = Invoke-NewBranch -Dir $fixtureR -Name 'feat/park-is-default-v1' -Title 'Park is default' -Park
    Assert-ExitCode 0 $rR '-Park: still exit 0'
    Assert-True (Test-Phrase -Text $rR.Out -Phrase 'the switch is accepted and changes nothing') '-Park: says out loud that it is the default now'
    Assert-True (Test-BranchOnRemote -Bare $bareR -Ref 'refs/heads/feat/park-is-default-v1') '-Park: and the push happened -- same outcome as (o), which is the point'

} finally {
    Remove-NewBranchFixtures
}

Complete-NewBranchSuite
