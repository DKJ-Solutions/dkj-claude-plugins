<#
.SYNOPSIS
    Tests for scripts/lib/gate-lib.ps1 -- the record of what the gates proved, and against which
    exact working state.

.DESCRIPTION
    This lib decides whether open-pr.ps1 may SKIP a gate. Every way it can be wrong is asymmetric: a
    false negative costs one gate run, a false positive lets an ungated commit reach a merge. So the
    suite is written from that side -- most cases here assert that evidence is REFUSED, and the
    happy path is the short one.

    THE PROPERTY THAT WOULD BREAK SILENTLY IS THE FINGERPRINT'S SENSITIVITY. The obvious
    implementation hashes HEAD plus `git status --porcelain`, and it passes every casual test: a
    clean tree matches itself, a dirty tree differs from a clean one. It is still wrong, because
    porcelain reports THAT a file is modified and never what it was modified TO -- so a file edited,
    gated, and edited again presents a byte-identical status line over different content, and the
    gate would be skipped on a tree it never saw. Case 3 is that exact sequence and it is the reason
    this file exists.

    A REAL GIT REPOSITORY PER CASE, NOT A STUB. The lib's whole job is to be right about what git
    reports, so a fake that returns canned porcelain would prove only that the parser agrees with
    the fake. Each fixture is a genuine `git init` under the temp directory, keyed on $PID so
    concurrent suites cannot collide (the gate runs these in parallel).

    SINCE AUGUST 30, 2026 (issue #1156) THIS FILE ALSO COVERS Invoke-WorkflowGates, THE FUNCTION AT
    THE BOTTOM OF gate-lib.ps1. It is the block that used to live inline in open-pr.ps1 -- the
    dirty-tree warning, the fingerprint, the reflog depth, both Test-GateEvidence consults, both
    Save-GateEvidence records, all four Get-GateTreeMovedNote calls -- pulled out so a second caller
    (open-pr's own -GatesOnly short-circuit, needed for the release-notes commit made standing on
    main) can reach it without rebuilding it by hand. Cases 8, 12 and 13 are the structural asserts
    that used to read $openPr and now read the function's own source; case 9 is what is left of
    open-pr's part; cases 14-16 are new for the move itself.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$LibPath  = Join-Path $RepoRoot 'scripts\lib\gate-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Assert-True (Test-Path -LiteralPath $LibPath) 'gate-lib.ps1 exists at its registered source path'
. $LibPath

$FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "gate-lib-tests-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding $false
$script:seq  = 0

function Invoke-FixtureGit {
    <#
        Git MUTATIONS inside a fixture, run under EAP=Continue.

        This is the repo's standing pitfall and it bit this very suite on its first run: `git add`
        writes the autocrlf "LF will be replaced by CRLF" notice to stderr, which under
        $ErrorActionPreference = 'Stop' becomes a TERMINATING NativeCommandError even though git
        exits 0 -- the same failure that broke cut-release.ps1 while cutting v1.12.0. The redirect
        alone is not enough, because the error is raised on the stderr write rather than on the exit
        code, so the preference has to be lowered around the call.
    #>
    param([string]$Dir, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # THE EXIT CODE IS READ, NOT DISCARDED (issue #1635). It used to go to Out-Null with the output,
        # so a failed fixture command was indistinguishable from a working one -- and a half-built repo
        # then makes every assert below it measure the wrong thing.
        $out = & git -C $Dir @GitArgs 2>&1
        Assert-FixtureGitOk -Code $LASTEXITCODE -GitArgs (@('-C', $Dir) + @($GitArgs)) -Output $out
    } finally { $ErrorActionPreference = $prev }
}

function New-GitFixture {
    <#
        A real repository with one committed file. Returns its path. Each call gets its own
        directory, so a case that dirties a tree cannot leak into the next.
    #>
    $script:seq++
    $dir = Join-Path $FixtureRoot "repo-$script:seq"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-FixtureGit -Dir $dir 'init' '-q'
    # Pinned rather than inherited: on a machine with core.autocrlf=true the checkout would rewrite
    # line endings underneath the fixture, which is a second, invisible way to move a fingerprint.
    Invoke-FixtureGit -Dir $dir 'config' 'core.autocrlf' 'false'
    Invoke-FixtureGit -Dir $dir 'config' 'user.email' 'tycho@example.test'
    Invoke-FixtureGit -Dir $dir 'config' 'user.name'  'Tycho'
    # Pinned for the same reason: a machine with commit.gpgsign=true and a locked signing agent would
    # otherwise fail every fixture commit, and the failing assert would name the script under test (#1287).
    Invoke-FixtureGit -Dir $dir 'config' 'commit.gpgsign' 'false'
    [System.IO.File]::WriteAllText((Join-Path $dir 'tracked.txt'), "one`n", $Utf8NoBom)
    Invoke-FixtureGit -Dir $dir 'add' '-A'
    Invoke-FixtureGit -Dir $dir 'commit' '-qm' 'init'
    return $dir
}

function Set-FixtureFile {
    param([string]$Dir, [string]$Name, [string]$Content)
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), $Content, $Utf8NoBom)
}

try {
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null

    # --- 1. the happy path, and it is deliberately the short one -------------------------------
    Write-Host "`n== 1. a recorded pass covers the tree it was recorded against ==" -ForegroundColor Cyan
    $r1 = New-GitFixture
    $f1 = Get-GateFingerprint -RepoRoot $r1
    Assert-True ([bool]$f1) 'a clean repository yields a fingerprint'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r1 -Gate 'tests')) 'with no record, evidence is refused'
    Assert-True ([bool](Save-GateEvidence -RepoRoot $r1 -Gate 'tests' -Fingerprint $f1)) 'a pass can be recorded'
    Assert-True (Test-GateEvidence -RepoRoot $r1 -Gate 'tests') 'and is then honoured on the same tree'

    # The two gates prove different things. Recording one must not vouch for the other -- otherwise
    # -SkipTests plus a lint pass would silently satisfy the test gate.
    Assert-True (-not (Test-GateEvidence -RepoRoot $r1 -Gate 'lint')) 'a tests pass does NOT vouch for the lint gate'
    Assert-True ([bool](Save-GateEvidence -RepoRoot $r1 -Gate 'lint' -Fingerprint $f1)) 'the lint gate records separately'
    Assert-True (Test-GateEvidence -RepoRoot $r1 -Gate 'lint')  'lint is now honoured'
    Assert-True (Test-GateEvidence -RepoRoot $r1 -Gate 'tests') 'and the tests pass survived the second write'

    # --- 2. the state file is never committable ------------------------------------------------
    Write-Host "`n== 2. the record lives inside the git directory ==" -ForegroundColor Cyan
    $path1 = Get-GateEvidencePath -RepoRoot $r1
    Assert-True ([bool]$path1) 'a path is resolved'
    Assert-True ($path1 -like '*\.git\*') "the record sits under .git (got '$(Split-Path $path1 -Leaf)')"
    Assert-True (Test-Path -LiteralPath $path1 -PathType Leaf) 'and it was actually written'
    # Nothing under .git can be added to a commit, so this is what makes the file un-committable
    # without a .gitignore entry every consumer would otherwise have to be given.
    Push-Location $r1
    try { $porcelain = @(& git status --porcelain 2>$null | ForEach-Object { "$_" }) } finally { Pop-Location }
    Assert-Equal 0 @($porcelain | Where-Object { $_ -match 'gate-evidence' }).Count 'the record is invisible to git status'

    # --- 3. THE CASE THIS FILE EXISTS FOR ------------------------------------------------------
    Write-Host "`n== 3. content, not the status letter ==" -ForegroundColor Cyan
    $r3 = New-GitFixture
    Set-FixtureFile -Dir $r3 -Name 'tracked.txt' -Content "edited once`n"
    $a = Get-GateFingerprint -RepoRoot $r3
    [void](Save-GateEvidence -RepoRoot $r3 -Gate 'tests' -Fingerprint $a)
    Assert-True (Test-GateEvidence -RepoRoot $r3 -Gate 'tests') 'the dirty tree is gated and recorded'

    # Same file, still modified, still ' M tracked.txt' in porcelain -- different bytes. A
    # fingerprint built on porcelain alone would call this a match and skip the gate.
    Set-FixtureFile -Dir $r3 -Name 'tracked.txt' -Content "edited twice`n"
    $b = Get-GateFingerprint -RepoRoot $r3
    Assert-True ($a -ne $b) 'a second edit with the SAME status letter moves the fingerprint'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r3 -Gate 'tests')) 'so the recorded pass no longer covers it'

    # Restoring the exact earlier content must restore the match: the evidence is the content, so
    # an undo is genuinely the tree that was gated.
    Set-FixtureFile -Dir $r3 -Name 'tracked.txt' -Content "edited once`n"
    Assert-True (Test-GateEvidence -RepoRoot $r3 -Gate 'tests') 'and reverting to the gated content honours it again'

    # --- 4. every other way the tree can move --------------------------------------------------
    Write-Host "`n== 4. new commits and untracked files move it too ==" -ForegroundColor Cyan
    $r4 = New-GitFixture
    $c0 = Get-GateFingerprint -RepoRoot $r4
    [void](Save-GateEvidence -RepoRoot $r4 -Gate 'tests' -Fingerprint $c0)

    Set-FixtureFile -Dir $r4 -Name 'untracked.txt' -Content "new`n"
    Assert-True (-not (Test-GateEvidence -RepoRoot $r4 -Gate 'tests')) 'an untracked file invalidates the record'
    Remove-Item -LiteralPath (Join-Path $r4 'untracked.txt') -Force
    Assert-True (Test-GateEvidence -RepoRoot $r4 -Gate 'tests') 'removing it again restores the match'

    # A new commit changes HEAD while leaving the working tree clean -- the single most common real
    # movement between an open-pr and a ship-pr, and the one the skip must never survive.
    Set-FixtureFile -Dir $r4 -Name 'tracked.txt' -Content "committed change`n"
    Invoke-FixtureGit -Dir $r4 'add' '-A'
    Invoke-FixtureGit -Dir $r4 'commit' '-qm' 'second'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r4 -Gate 'tests')) 'a new commit invalidates the record'

    # --- 5. a stale or malformed record is no record -------------------------------------------
    Write-Host "`n== 5. every failure path refuses, rather than trusting ==" -ForegroundColor Cyan
    $r5 = New-GitFixture
    $f5 = Get-GateFingerprint -RepoRoot $r5
    [void](Save-GateEvidence -RepoRoot $r5 -Gate 'tests' -Fingerprint $f5)
    $p5 = Get-GateEvidencePath -RepoRoot $r5

    # Age bound: the content has not moved, so only the clock can refuse this one.
    $old = [pscustomobject]@{
        fingerprint = $f5
        recordedAt  = ([datetime]::UtcNow.AddMinutes(-241)).ToString('o')
        gates       = [pscustomobject]@{ tests = $true }
    }
    [System.IO.File]::WriteAllText($p5, ($old | ConvertTo-Json -Depth 4), $Utf8NoBom)
    Assert-True (-not (Test-GateEvidence -RepoRoot $r5 -Gate 'tests')) 'a record past the age bound is refused'

    $fresh = [pscustomobject]@{
        fingerprint = $f5
        recordedAt  = ([datetime]::UtcNow.AddMinutes(-5)).ToString('o')
        gates       = [pscustomobject]@{ tests = $true }
    }
    [System.IO.File]::WriteAllText($p5, ($fresh | ConvertTo-Json -Depth 4), $Utf8NoBom)
    Assert-True (Test-GateEvidence -RepoRoot $r5 -Gate 'tests') 'a record inside the bound is honoured'

    # A clock that moved backwards leaves a record stamped in the future. That is also what a
    # restored or hand-edited file looks like, so it is refused rather than treated as very fresh.
    $future = [pscustomobject]@{
        fingerprint = $f5
        recordedAt  = ([datetime]::UtcNow.AddMinutes(30)).ToString('o')
        gates       = [pscustomobject]@{ tests = $true }
    }
    [System.IO.File]::WriteAllText($p5, ($future | ConvertTo-Json -Depth 4), $Utf8NoBom)
    Assert-True (-not (Test-GateEvidence -RepoRoot $r5 -Gate 'tests')) 'a record stamped in the future is refused'

    [System.IO.File]::WriteAllText($p5, "{ not json at all", $Utf8NoBom)
    Assert-True (-not (Test-GateEvidence -RepoRoot $r5 -Gate 'tests')) 'a malformed record is refused, not thrown on'
    Assert-True ($null -eq (Read-GateEvidence -RepoRoot $r5)) 'and reads back as no record at all'

    [System.IO.File]::WriteAllText($p5, (([pscustomobject]@{ gates = [pscustomobject]@{ tests = $true } }) | ConvertTo-Json), $Utf8NoBom)
    Assert-True (-not (Test-GateEvidence -RepoRoot $r5 -Gate 'tests')) 'a record with no fingerprint is refused'

    # --- 6. no repository, no evidence ---------------------------------------------------------
    Write-Host "`n== 6. outside a repository the gate simply runs ==" -ForegroundColor Cyan
    $bare = Join-Path $FixtureRoot 'not-a-repo'
    New-Item -ItemType Directory -Path $bare -Force | Out-Null
    Assert-True ($null -eq (Get-GateFingerprint -RepoRoot $bare)) 'a non-repository yields no fingerprint'
    Assert-True (-not (Test-GateEvidence -RepoRoot $bare -Gate 'tests')) 'and therefore never honours a skip'
    Assert-True (-not (Save-GateEvidence -RepoRoot $bare -Gate 'tests')) 'and records nothing'

    # --- 7. Clear-GateEvidence -----------------------------------------------------------------
    Write-Host "`n== 7. the record can be dropped ==" -ForegroundColor Cyan
    $r7 = New-GitFixture
    $f7 = Get-GateFingerprint -RepoRoot $r7
    [void](Save-GateEvidence -RepoRoot $r7 -Gate 'tests' -Fingerprint $f7)
    Assert-True (Test-GateEvidence -RepoRoot $r7 -Gate 'tests') 'recorded'
    Assert-True ([bool](Clear-GateEvidence -RepoRoot $r7)) 'cleared'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r7 -Gate 'tests')) 'and the skip is gone with it'
    Assert-True ([bool](Clear-GateEvidence -RepoRoot $r7)) 'clearing an absent record is not an error'

    # The raw text of both files, read once here and reused across the structural cases below --
    # extracting the same text twice would be two chances to read it differently.
    $libText = [System.IO.File]::ReadAllText($LibPath)
    $openPr  = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\open-pr.ps1'))

    # Invoke-WorkflowGates is the LAST function in gate-lib.ps1 (verified by case 8 below), so a
    # greedy match from its declaration to the last '}' in the file lands exactly on its own closing
    # brace and cannot cross into another function -- the same reasoning the old $lintBlock/$testBlock
    # extraction against $openPr relied on when that code lived at the top level of that file.
    $gatesFuncBody = [regex]::Match($libText, '(?s)function Invoke-WorkflowGates \{.*\}').Value

    # --- 8. Invoke-WorkflowGates wires the evidence in, and only on a real pass ----------------
    # RETARGETED HERE ON AUGUST 30, 2026 (issue #1156). This block -- the dirty-tree warning, the
    # fingerprint, both Test-GateEvidence consults, both Save-GateEvidence records -- used to live
    # inline in open-pr.ps1 and is asserted there in the suite's history. It now lives inside this
    # function, so the SAME asserts (same counts, same "the escape valves must record nothing"
    # property) are asked of gate-lib.ps1's own text instead. Case 9 covers what is left in open-pr.
    #
    # The lib being right proves nothing about it being REACHED -- the lesson pr-issues-lib cost: a
    # pure decision table proves the decision, never that it is reached.
    Write-Host "`n== 8. Invoke-WorkflowGates consults and records ==" -ForegroundColor Cyan
    Assert-True ([bool]$gatesFuncBody) 'Invoke-WorkflowGates is found, and is the last function in the file'
    Assert-True ($gatesFuncBody -match 'Get-GateFingerprint -RepoRoot \$RepoRoot') 'it computes the fingerprint once'
    Assert-Equal 1 ([regex]::Matches($gatesFuncBody, 'Get-GateFingerprint').Count) 'exactly once, not per gate'
    Assert-Equal 2 ([regex]::Matches($gatesFuncBody, 'Test-GateEvidence').Count) 'both gates consult the record'
    Assert-Equal 2 ([regex]::Matches($gatesFuncBody, 'Save-GateEvidence').Count) 'and both record their own pass'

    # The escape valves must record nothing: a skipped gate proves nothing about the tree, and
    # evidence written there would make -SkipTests suppress the NEXT run's gate as well.
    #
    # '\n    \}' (four spaces, nothing else on the line) rather than '\n\}': this code is now
    # INDENTED one level inside the function, so the top-level-code pattern the suite used while this
    # lived in open-pr.ps1 would run straight past the nested if/else braces underneath it and stop
    # at the wrong place. The outer if's own close is the only line at exactly this indent within
    # each block (verified against the fixture: every inner close sits at eight spaces or deeper).
    $lintBlock = [regex]::Match($gatesFuncBody, '(?s)if \(-not \$SkipLint\) \{.*?\n    \}').Value
    $testBlock = [regex]::Match($gatesFuncBody, '(?s)if \(-not \$SkipTests\) \{.*?\n    \}').Value
    Assert-True ([bool]$lintBlock) 'the -SkipLint guard is found as a single block'
    Assert-True ([bool]$testBlock) 'the -SkipTests guard is found as a single block'
    Assert-True ($lintBlock -match 'Save-GateEvidence') 'the lint save sits INSIDE the -SkipLint guard'
    Assert-True ($testBlock -match 'Save-GateEvidence') 'the tests save sits INSIDE the -SkipTests guard'

    # --- 9. open-pr's own part shrank to two call sites (issue #1156) --------------------------
    # The whole point of the move was that open-pr keeps no second copy of the gate logic and no
    # second way to reach it: one dot-source, two calls into the shared function, nothing else.
    Write-Host "`n== 9. open-pr reaches the gates through Invoke-WorkflowGates alone ==" -ForegroundColor Cyan
    Assert-True ($openPr -match "lib\\gate-lib\.ps1") 'open-pr still dot-sources gate-lib'
    Assert-Equal 2 ([regex]::Matches($openPr, 'Invoke-WorkflowGates -RepoRoot \$repoRoot').Count) 'exactly two call sites -- the PR path and -GatesOnly'
    Assert-True ($openPr -notmatch 'Save-GateEvidence') 'no inline Save-GateEvidence left behind'
    Assert-True ($openPr -notmatch 'Get-GateFingerprint') 'no inline Get-GateFingerprint left behind'
    Assert-True ($openPr -notmatch 'Test-GateEvidence') 'no inline Test-GateEvidence left behind'

    # --- 10. the pair is registered and mirrored ------------------------------------------------
    Write-Host "`n== 10. the lib travels to the consumer ==" -ForegroundColor Cyan
    . (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
    $pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
    $gatePair = @($pairs | Where-Object { $_.Name -eq 'gate-lib' })
    Assert-Equal 1 $gatePair.Count 'gate-lib is registered exactly once'
    if ($gatePair.Count -eq 1) {
        Assert-True ([bool]$gatePair[0].LibOnly) 'registered as a dot-sourced library'
        Assert-True (Test-Path -LiteralPath $gatePair[0].MirrorPath) 'and its mirror exists in the plugin tree'
        $srcText = [System.IO.File]::ReadAllText($gatePair[0].SourcePath)
        $mirText = [System.IO.File]::ReadAllText($gatePair[0].MirrorPath)
        Assert-Equal $srcText.Length $mirText.Length 'source and mirror are byte-identical in length'
    }

    # --- 11. CI must never consult a local record ----------------------------------------------
    # A fresh checkout has no state file, so this holds today by construction. The assert exists so
    # that stays true if somebody later teaches ci.yml to reuse open-pr's gate wiring.
    Write-Host "`n== 11. CI is unaffected ==" -ForegroundColor Cyan
    $ci = [System.IO.File]::ReadAllText((Join-Path $RepoRoot '.github\workflows\ci.yml'))
    Assert-True ($ci -notmatch 'Test-GateEvidence') 'ci.yml does not consult gate evidence'
    Assert-True ($ci -notmatch 'gate-lib') 'ci.yml does not load gate-lib at all'

    # --- 12. the dirty-tree statement (issue #1026) --------------------------------------------
    # The fingerprint answers "same tree as last time" and CANNOT answer "is this tree HEAD" -- it
    # hashes the distinction away. That second question is the one a gate RESULT depends on, because
    # the gates judge the working tree while the PR ships HEAD. Measured on PR #1025: a lint run
    # walked a manual with two new rules in it, reported zero errors, and the rules were not in the PR.
    Write-Host "`n== 12. how far the tree is from HEAD ==" -ForegroundColor Cyan
    $r12dirty = New-GitFixture
    Assert-Equal 0 (Get-GateTreeDirtyCount -RepoRoot $r12dirty) 'a clean tree is zero files from HEAD'

    Set-FixtureFile -Dir $r12dirty -Name 'tracked.txt' -Content "two`n"
    Assert-Equal 1 (Get-GateTreeDirtyCount -RepoRoot $r12dirty) 'a modified tracked file counts'

    # --untracked-files=all, for the same reason park-lib forces it: git's default collapses an
    # untracked DIRECTORY to one entry naming the directory, so a new suite inside a new folder would
    # count as a single file -- or as none, once the folder is the thing being reported.
    New-Item -ItemType Directory -Path (Join-Path $r12dirty 'fresh') -Force | Out-Null
    Set-FixtureFile -Dir $r12dirty -Name 'fresh\a.txt' -Content "a`n"
    Set-FixtureFile -Dir $r12dirty -Name 'fresh\b.txt' -Content "b`n"
    Assert-Equal 3 (Get-GateTreeDirtyCount -RepoRoot $r12dirty) 'untracked files inside a NEW directory are counted individually'

    # Committing clears it: that is the whole point -- a clean tree is what makes a green gate
    # evidence about the PR rather than about the working copy.
    Invoke-FixtureGit -Dir $r12dirty 'add' '-A'
    Invoke-FixtureGit -Dir $r12dirty 'commit' '-qm' 'second'
    Assert-Equal 0 (Get-GateTreeDirtyCount -RepoRoot $r12dirty) 'committing the lot brings it back to zero'

    # NOT MEASURED is not ZERO. Zero is the reassuring answer, and handing it back for "git could not
    # answer" would print an all-clear over an unknown.
    Assert-True ($null -eq (Get-GateTreeDirtyCount -RepoRoot $FixtureRoot)) 'outside a repository the count is $null, never 0'

    # And Invoke-WorkflowGates has to actually SAY it -- the lib being right proves nothing about it
    # being reached. Retargeted at gate-lib.ps1's own function body on August 30, 2026 (issue #1156):
    # this used to be asked of $openPr, at the top level of that file, while the measurement lived
    # there inline.
    Assert-True ($gatesFuncBody -match 'Get-GateTreeDirtyCount -RepoRoot \$RepoRoot') 'Invoke-WorkflowGates measures the distance from HEAD'
    Assert-Equal 1 ([regex]::Matches($gatesFuncBody, 'Get-GateTreeDirtyCount').Count) 'exactly once, above both gates rather than inside each'
    Assert-True ($gatesFuncBody -match 'DIRTY tree') 'and warns in words a reader can act on'
    # Said BEFORE either gate runs, so it frames the results instead of trailing them.
    Assert-True ($gatesFuncBody.IndexOf('Get-GateTreeDirtyCount') -lt $gatesFuncBody.IndexOf('if (-not $SkipLint)')) 'the warning is printed above the lint gate, not after it'

    # --- 13. the checkout that moved WHILE the gate ran (issue #1145) --------------------------
    # The fingerprint above is taken before the gates and spent on the skip decision. Asked again
    # afterwards it answers a second question -- did the gates judge one settled tree -- and it
    # answers it INCOMPLETELY, which is the property this case exists to pin. A borrowed checkout
    # comes back: prune-merged.ps1 fast-forwards the trunk and returns the branch, so HEAD, the
    # branch name and every tracked file are identical at both ends. Measured on PR #1144, where one
    # suite of 55 went red inside a ship's gate and green standalone on the same commit.
    Write-Host "`n== 13. a tree that moved under a gate ==" -ForegroundColor Cyan
    $r13moved = New-GitFixture
    $f13 = Get-GateFingerprint -RepoRoot $r13moved
    $h13 = Get-GateHeadMoveCount -RepoRoot $r13moved
    Assert-True ($null -ne $h13 -and $h13 -ge 1) 'a repository with a commit has a reflog depth'
    Assert-True ($null -eq (Get-GateTreeMovedNote -RepoRoot $r13moved -Gate 'tests' -Fingerprint $f13 -HeadMoves $h13)) 'a tree that held still reports nothing'

    # THE BORROW, AND THE BLIND SPOT IT PROVES. Both asserts matter: the second says the fingerprint
    # alone would have seen NOTHING here, which is why the reflog depth is read beside it.
    Invoke-FixtureGit -Dir $r13moved 'checkout' '-q' '-b' 'borrowed'
    Invoke-FixtureGit -Dir $r13moved 'checkout' '-q' '-'
    Assert-Equal ($h13 + 2) (Get-GateHeadMoveCount -RepoRoot $r13moved) 'a borrow-and-return costs two reflog entries'
    Assert-Equal $f13 (Get-GateFingerprint -RepoRoot $r13moved) 'and leaves the fingerprint identical -- the blind spot'

    $red13 = Get-GateTreeMovedNote -RepoRoot $r13moved -Gate 'tests' -Fingerprint $f13 -HeadMoves $h13 -Failed
    Assert-True ([bool]$red13) 'so the borrow is still reported'
    Assert-True ($red13 -match 'NOT trustworthy') 'a red says the verdict cannot be relied on'
    $green13 = Get-GateTreeMovedNote -RepoRoot $r13moved -Gate 'tests' -Fingerprint $f13 -HeadMoves $h13
    Assert-True ($green13 -match 'NOT recorded as gate evidence') 'a green says it will not be filed as proof'
    Assert-True ($green13 -notmatch 'trustworthy') 'and does not borrow the red sentence'

    # The other half: content that changed and stayed changed, with HEAD never moving.
    $r13content = New-GitFixture
    $f13b = Get-GateFingerprint -RepoRoot $r13content
    $h13b = Get-GateHeadMoveCount -RepoRoot $r13content
    Set-FixtureFile -Dir $r13content -Name 'tracked.txt' -Content "changed mid-gate`n"
    Assert-Equal $h13b (Get-GateHeadMoveCount -RepoRoot $r13content) 'an edit moves no reflog entry'
    Assert-True ([bool](Get-GateTreeMovedNote -RepoRoot $r13content -Gate 'lint' -Fingerprint $f13b -HeadMoves $h13b)) 'and the fingerprint catches it instead'

    # NEITHER SIGNAL MEASURED IS NOT MOVEMENT. A caller whose readings failed gets silence, never a
    # warning it cannot act on -- the same direction every other error path in this lib takes.
    Assert-True ($null -eq (Get-GateTreeMovedNote -RepoRoot $r13moved -Gate 'tests')) 'with neither reading, nothing is claimed'
    Assert-True ($null -eq (Get-GateTreeMovedNote -RepoRoot $FixtureRoot -Gate 'tests' -Fingerprint $f13 -HeadMoves $h13)) 'outside a repository, nothing is claimed'
    Assert-True ($null -eq (Get-GateHeadMoveCount -RepoRoot $FixtureRoot)) 'and the depth itself is $null there, never 0'

    # And Invoke-WorkflowGates has to ASK, on both gates and on both verdicts -- the lib being right
    # proves nothing about it being reached. Retargeted at gate-lib.ps1's own function body on
    # August 30, 2026 (issue #1156), same reasoning as case 12 above.
    Assert-Equal 1 ([regex]::Matches($gatesFuncBody, 'Get-GateHeadMoveCount').Count) 'Invoke-WorkflowGates reads the reflog depth once, beside the fingerprint'
    Assert-Equal 4 ([regex]::Matches($gatesFuncBody, 'Get-GateTreeMovedNote -RepoRoot \$RepoRoot').Count) 'both gates ask, on both verdicts'
    Assert-Equal 2 ([regex]::Matches($gatesFuncBody, 'Get-GateTreeMovedNote[^\r\n]*-Failed').Count) 'and only the two red paths ask as a failure'
    Assert-True ($gatesFuncBody.IndexOf('Get-GateHeadMoveCount') -lt $gatesFuncBody.IndexOf('if (-not $SkipLint)')) 'the depth is read before the first gate, not after it'
    # THE PASS PATH IS THE ONE WITH TEETH: a green over a moved tree must not be filed as evidence,
    # or the next run skips a gate on a tree nothing ever judged.
    Assert-True ($lintBlock.IndexOf('$movedNote') -lt $lintBlock.IndexOf('Save-GateEvidence')) 'the lint pass is recorded only after the movement question'
    Assert-True ($testBlock.IndexOf('$movedNote') -lt $testBlock.IndexOf('Save-GateEvidence')) 'the tests pass is recorded only after the movement question'
    Assert-True ($lintBlock -match '\} else \{[^\}]*Save-GateEvidence') 'the lint save sits in the else of that question'
    Assert-True ($testBlock -match '\} else \{[^\}]*Save-GateEvidence') 'the tests save sits in the else of that question'

    # --- 14. -GatesOnly reaches the trunk it was built for (issue #1156) ------------------------
    # The flag exists because open-pr refuses on main hundreds of lines below where the gates used to
    # sit -- so the one property that actually matters is WHERE in the file the short-circuit sits: a
    # block placed after the branch check is unreachable from the trunk it was built to serve, which
    # is exactly the defect this issue reports. Everything else about the flag is secondary to that.
    Write-Host "`n== 14. -GatesOnly sits before the branch check, not after it ==" -ForegroundColor Cyan
    $idxGateLibSource  = $openPr.IndexOf('\lib\gate-lib.ps1')
    $idxVulInPreflight = $openPr.IndexOf('repo -match ''VUL-IN''')
    $idxGatesOnly      = $openPr.IndexOf('if ($GatesOnly) {')
    $idxBranchCheck    = $openPr.IndexOf('if ($branch -eq ''main'')')
    Assert-True ($idxGateLibSource -ge 0 -and $idxVulInPreflight -ge 0 -and $idxGatesOnly -ge 0 -and $idxBranchCheck -ge 0) 'all four landmarks are found'
    Assert-True ($idxGateLibSource -lt $idxGatesOnly) '-GatesOnly sits after gate-lib is dot-sourced, so Invoke-WorkflowGates is already in scope'
    Assert-True ($idxVulInPreflight -lt $idxGatesOnly) '-GatesOnly sits after the VUL-IN pre-flight, so it never runs on an unfilled scaffold'
    Assert-True ($idxGatesOnly -lt $idxBranchCheck) 'and -GatesOnly sits BEFORE the branch-eq-main refusal -- the whole reason it can run on the trunk'

    $gatesOnlyBlock = [regex]::Match($openPr, '(?s)if \(\$GatesOnly\) \{.*?\n\}').Value
    Assert-True ([bool]$gatesOnlyBlock) 'the -GatesOnly block is found as a single top-level if'
    Assert-True ($gatesOnlyBlock -match 'exit 0') 'and exits 0 on success rather than falling through into the branch/push/PR code below it'

    # The two call sites must describe DIFFERENT points in the chain, or the reader cannot tell from
    # the message alone which run they are looking at.
    $callSites = @([regex]::Matches($openPr, 'Invoke-WorkflowGates -RepoRoot \$repoRoot[^\r\n]*'))
    Assert-Equal 2 $callSites.Count 'exactly two call sites to compare'
    if ($callSites.Count -eq 2) {
        $contexts     = @($callSites | ForEach-Object { [regex]::Match($_.Value, "-Context '([^']*)'").Groups[1].Value })
        $consequences = @($callSites | ForEach-Object { [regex]::Match($_.Value, "-FailureConsequence '([^']*)'").Groups[1].Value })
        Assert-True ($contexts[0] -and $contexts[1] -and $contexts[0] -ne $contexts[1]) '-Context differs between the two call sites'
        Assert-True ($consequences[0] -and $consequences[1] -and $consequences[0] -ne $consequences[1]) '-FailureConsequence differs between the two call sites'
    }

    # --- 15. Invoke-WorkflowGates itself, against a real fixture (issue #1156) -------------------
    # Cases 8-14 prove the SHAPE of the function and of its two callers; this case runs the function
    # for real, because a decision table (and a shape) proves the decision and proves nothing about
    # what actually happens when it executes.
    Write-Host "`n== 15. Invoke-WorkflowGates runs for real ==" -ForegroundColor Cyan

    # 15a. Both gates skipped: no seam is needed at all, nothing is recorded, and the call succeeds.
    # This is the case every existing branch in flight exercises today (-SkipLint -SkipTests), so it
    # is the one that must never regress.
    $r15 = New-GitFixture
    Assert-True (Invoke-WorkflowGates -RepoRoot $r15 -SkipLint -SkipTests -Context 'test' -FailureConsequence 'x') '-SkipLint -SkipTests returns true without touching either seam'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r15 -Gate 'lint'))  'and records no lint evidence'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r15 -Gate 'tests')) 'nor test evidence'

    # 15b. THE CONTRACT ITSELF -- Get-LintScript and Invoke-TestSuiteGate are read from the CALLER's
    # scope, not embedded in this file (the docstring's "the caller must have dot-sourced two more
    # things"). Proven by their absence: with -SkipTests but NOT -SkipLint, and no Get-LintScript
    # defined anywhere in this process, the call must fail LOUDLY -- a command-not-found -- rather
    # than silently skip the gate it cannot run.
    $threwNoSeam = $false
    try { [void](Invoke-WorkflowGates -RepoRoot $r15 -SkipTests -Context 'test' -FailureConsequence 'x') }
    catch { $threwNoSeam = $true }
    Assert-True $threwNoSeam 'without a caller-supplied Get-LintScript the lint gate fails loudly, not silently'

    # From here on the suite supplies its own Get-LintScript, exactly as open-pr's dot-sourced
    # repo-config.ps1 would. Invoke-TestSuiteGate is deliberately left undefined for the rest of this
    # case -- every remaining call passes -SkipTests, so the test gate is never reached and the
    # suite does not have to fake a second seam it is not exercising.
    $script:FixtureLintScript = ''
    function Get-LintScript { return $script:FixtureLintScript }

    # 15c. A failing lint script: THE RETURN VALUE IS THE ANSWER, NOT AN EXCEPTION (August 30, 2026).
    # Both Write-Error calls inside the function run -ErrorAction Continue precisely so this is true --
    # every caller of this function runs under $ErrorActionPreference = 'Stop', where a plain
    # Write-Error would terminate, the `return $false` below it would be dead code, and a test could
    # only observe a failure by catching an exception instead of reading the bool this function
    # promises. So both halves are asserted: the call does not throw, AND it returns $false.
    #
    # 2>$null on the call, not -ErrorAction on the call: the two Write-Error lines inside the function
    # hardcode their OWN -ErrorAction Continue, which is an explicit per-cmdlet override and is not
    # overridden in turn by an -ErrorAction the caller passes in. Redirecting stream 2 is what actually
    # keeps the (expected, non-terminating) error record out of this suite's console output.
    $r15fail = New-GitFixture
    $script:FixtureLintScript = 'fixture-lint.ps1'
    Set-FixtureFile -Dir $r15fail -Name $script:FixtureLintScript -Content "exit 1`n"
    $threwOnFail = $false
    $resultFail = $null
    try { $resultFail = Invoke-WorkflowGates -RepoRoot $r15fail -SkipTests -Context 'test' -FailureConsequence 'x' 2>$null }
    catch { $threwOnFail = $true }
    Assert-True (-not $threwOnFail) 'a failing lint script is reported through the return value, not by throwing'
    Assert-True (-not $resultFail) 'and the call returns $false'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r15fail -Gate 'lint')) 'recording nothing for the gate that failed'

    # 15d. A passing lint script records ONLY the lint gate -- -SkipTests must not vouch for the other,
    # the same separation case 1 already proved for Save-GateEvidence/Test-GateEvidence directly.
    $r15pass = New-GitFixture
    Set-FixtureFile -Dir $r15pass -Name $script:FixtureLintScript -Content "exit 0`n"
    Assert-True (Invoke-WorkflowGates -RepoRoot $r15pass -SkipTests -Context 'test' -FailureConsequence 'x') 'a passing lint script makes the call return true'
    Assert-True (Test-GateEvidence -RepoRoot $r15pass -Gate 'lint') 'and records the lint pass'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r15pass -Gate 'tests')) 'but -SkipTests records no test evidence -- the escape valve proves nothing about the tree'

    # 15d-clock. THE LINT GATE PRINTS ITS OWN WALL-CLOCK (issue #1319). Without it a "the full gate
    # cost ~Ys" figure has a number for the test half ("all N suites passed in Xs") and nothing for
    # the lint half. Captured off the information stream (6>&1); the boolean the function returns
    # still flows down the pipe as the last element and is not what these cases read.
    $r15clock = New-GitFixture
    Set-FixtureFile -Dir $r15clock -Name $script:FixtureLintScript -Content "exit 0`n"
    $clockPass = & { Invoke-WorkflowGates -RepoRoot $r15clock -SkipTests -Context 'test' -FailureConsequence 'x' } 6>&1 2>$null | Out-String
    Assert-True ($clockPass -match 'lint gate: integrity check passed in \d+s\.') 'a real lint run prints its own elapsed seconds, the way the test gate does'

    # The second run is served from the evidence cache: it prints the skip line and NO seconds, since
    # nothing ran to time -- the same distinction Invoke-TestSuiteGate makes on its own cache branch.
    $clockCached = & { Invoke-WorkflowGates -RepoRoot $r15clock -SkipTests -Context 'test' -FailureConsequence 'x' } 6>&1 2>$null | Out-String
    Assert-True ($clockCached -match 'lint gate: already proved against this exact tree -- skipped\.') 'the cache-hit fast path still prints its skip line'
    Assert-True ($clockCached -notmatch 'check (passed|FAILED) in \d+s\.') 'and prints no elapsed figure -- nothing ran to time'

    # A failing lint run reports its seconds too, so both verdicts carry the number.
    $r15clockFail = New-GitFixture
    Set-FixtureFile -Dir $r15clockFail -Name $script:FixtureLintScript -Content "exit 1`n"
    $clockFail = & { Invoke-WorkflowGates -RepoRoot $r15clockFail -SkipTests -Context 'test' -FailureConsequence 'x' } 6>&1 2>$null | Out-String
    Assert-True ($clockFail -match 'lint gate: integrity check FAILED in \d+s\.') 'a failing lint run also prints its elapsed seconds'

    # 15d-progress. THE LINT GATE PUBLISHES A PROGRESS RECORD FOR THE STATUSLINE (issue #2173). The bar had
    # two publishers, and the lint gate -- the step that runs FIRST in a ship and took 78s on the measured
    # run -- was neither, so the statusline was blank for exactly the stretch a reader watches. The lint
    # child is asked what it can SEE while it runs, because a record that exists only before or after the
    # child says nothing about the wait the record is for.
    #
    # TWO PIECES OF THE PROCESS ENVIRONMENT ARE SET FOR EACH RUN AND PUT BACK. LOCALAPPDATA is redirected so
    # the record lands in a fixture root rather than in the runner's real per-user directory --
    # Get-RunProgressRoot reads it at call time and the child inherits it. DKJ_TEST_GATE_DEPTH is CLEARED
    # for the publishing cases, because this suite normally runs as a child of the test gate, where it reads
    # 1 and would make every lint run below look nested and stay silent; the nested case sets it on purpose.
    # run-progress-lib is already loaded here (gate-lib reaches it through git-porcelain-lib and
    # native-capture-lib) -- which is itself the fact the nested case exists for: EVERY suite that drives
    # this function has the publisher, so nothing but the depth stops each of them repainting the statusline.
    $progRoot  = Join-Path $FixtureRoot 'progress-localappdata'
    $progDir   = Join-Path $progRoot 'dkj-run-progress'
    $progProbe = Join-Path $FixtureRoot 'progress-probe.txt'
    New-Item -ItemType Directory -Path $progRoot -Force | Out-Null
    $probeTemplate = @'
$d = Join-Path $env:LOCALAPPDATA 'dkj-run-progress'
$f = @(Get-ChildItem -LiteralPath $d -Filter 'lint-gate-*.json' -ErrorAction SilentlyContinue)
$t = ''
if ($f.Count -gt 0) { $t = [System.IO.File]::ReadAllText($f[0].FullName) }
[System.IO.File]::WriteAllText('__PROBE__', ($f.Count.ToString() + '|' + $t))
exit __EXIT__
'@
    function Invoke-ProbedLintGate {
        param([string]$Dir, [int]$LintExit, [AllowNull()][string]$GateDepth = $null, [switch]$KeepScript)
        if (-not $KeepScript) {
            Set-FixtureFile -Dir $Dir -Name $script:FixtureLintScript -Content ($probeTemplate.Replace('__PROBE__', $progProbe).Replace('__EXIT__', "$LintExit") + "`n")
        }
        Remove-Item -LiteralPath $progProbe -Force -ErrorAction SilentlyContinue
        $savedAppData = $env:LOCALAPPDATA
        $savedDepth = [Environment]::GetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', 'Process')
        $env:LOCALAPPDATA = $progRoot
        [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $GateDepth, 'Process')
        try {
            [void](Invoke-WorkflowGates -RepoRoot $Dir -SkipTests -Context 'test' -FailureConsequence 'x' 6>$null 2>$null)
        } finally {
            $env:LOCALAPPDATA = $savedAppData
            [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $savedDepth, 'Process')
        }
    }
    function Get-LeftoverLintRecordCount {
        return @(Get-ChildItem -LiteralPath $progDir -Filter 'lint-gate-*.json' -ErrorAction SilentlyContinue).Count
    }

    $r15progPass = New-GitFixture
    Invoke-ProbedLintGate -Dir $r15progPass -LintExit 0
    $progSeen = if (Test-Path -LiteralPath $progProbe) { [System.IO.File]::ReadAllText($progProbe) } else { '' }
    Assert-True ($progSeen -match '^1\|') 'exactly one lint-gate record is live WHILE the lint child runs'
    Assert-True ($progSeen -match '"label":"lint gate"') 'and it is labelled as the lint gate, which is what the statusline draws'
    Assert-True ($progSeen -match '"current":null' -and $progSeen -match '"total":null') 'with NO counts, so no bar -- the check has no total to publish, and a fraction nobody measured is an invention'
    Assert-True ((Get-LeftoverLintRecordCount) -eq 0) 'and the record is gone once the child has returned on a pass'

    $r15progFail = New-GitFixture
    Invoke-ProbedLintGate -Dir $r15progFail -LintExit 1
    $progSeenFail = if (Test-Path -LiteralPath $progProbe) { [System.IO.File]::ReadAllText($progProbe) } else { '' }
    Assert-True ($progSeenFail -match '^1\|') 'a run that will FAIL publishes the same record while it runs'
    Assert-True ((Get-LeftoverLintRecordCount) -eq 0) 'and removes it on a failing verdict too, so a red lint does not leave a bar behind'

    # Served from the evidence cache the child never runs, so there is nothing to describe and nothing is
    # published -- the probe is never even written. Same distinction the elapsed-seconds case above draws.
    # The script is NOT rewritten for this run: touching the tree would change its fingerprint and turn the
    # cache hit into a real run, which is the very thing being asserted about.
    Invoke-ProbedLintGate -Dir $r15progPass -LintExit 0 -KeepScript
    Assert-True (-not (Test-Path -LiteralPath $progProbe)) 'a cache hit runs no lint child, so nothing is published for it'

    # A lint run INSIDE a suite -- DKJ_TEST_GATE_DEPTH set by the test gate -- publishes nothing. Many suites
    # drive this function over a fixture lint that exits in about a second, and the statusline draws the
    # newest record, so without this each of them would repaint the line with 'lint gate' in the middle of
    # the test gate's bar. The probe IS written (the child ran) and reports zero records, which is what
    # separates "ran and published nothing" from "never ran".
    $r15progNested = New-GitFixture
    Invoke-ProbedLintGate -Dir $r15progNested -LintExit 0 -GateDepth '1'
    $progSeenNested = if (Test-Path -LiteralPath $progProbe) { [System.IO.File]::ReadAllText($progProbe) } else { 'NOT-WRITTEN' }
    Assert-True ($progSeenNested -match '^0\|') "a lint run nested inside the test gate ran and published NO record -- it must not repaint the test gate's bar"

    # 15e. THE SHAPE OF THE RETURN VALUE ITSELF -- a CRITICAL regression found in code review and
    # fixed the same day (August 30, 2026). A lint gate invoked as `& powershell -File $lintPath`
    # was safe as a top-level statement in open-pr.ps1: the child's stdout went straight to the
    # console and only $LASTEXITCODE was read. Moved inside a function whose return value the caller
    # consumes -- `if (-not (Invoke-WorkflowGates ...))` -- every line the child printed on its own
    # stdout came back as a plain String on the SUCCESS stream (stream type does not survive a
    # process boundary), ahead of this function's own `return $false`. PowerShell coerces a
    # MULTI-ELEMENT array to $true unconditionally, so `-not` read $false and A FAILING LINT GATE
    # CAME BACK GREEN. Reproduced with a fake lint script printing two lines and exiting 1, then
    # repaired with Start-Process -NoNewWindow -Wait -PassThru, which emits nothing to the pipeline.
    #
    # A CASE ASSERTING ONLY THE RETURN VALUE IN ISOLATION PASSES UNDER BOTH THE BROKEN AND THE FIXED
    # CODE -- cases 15c/15d above never printed anything from their fixture scripts, so they could
    # not have caught this. The property that actually regressed is the COUNT of what comes back, so
    # that is what @(...) and .Count are asked here, on scripts that print exactly the way the
    # reported repro did.
    $r15shapeFail = New-GitFixture
    Set-FixtureFile -Dir $r15shapeFail -Name $script:FixtureLintScript -Content "'line one'`n'line two'`nexit 1`n"
    $shapeFail = @(Invoke-WorkflowGates -RepoRoot $r15shapeFail -SkipTests -Context 'test' -FailureConsequence 'x' 2>$null)
    Assert-Equal 1 $shapeFail.Count 'a lint script that PRINTS two lines before failing still returns exactly one element'
    Assert-True ($shapeFail.Count -eq 1 -and $shapeFail[0] -is [bool] -and $shapeFail[0] -eq $false) 'and that one element is the boolean $false, not a polluted array coerced to $true'
    # Written exactly as every real caller writes it, so this exercises the actual expression that
    # read green in the reported bug rather than a paraphrase of it.
    Assert-True (-not (Invoke-WorkflowGates -RepoRoot $r15shapeFail -SkipTests -Context 'test' -FailureConsequence 'x' 2>$null)) "the caller's own idiom -- '-not (Invoke-WorkflowGates ...)' -- reads this failure as true"

    # The happy path pollutes identically -- a passing script that prints is indistinguishable from a
    # failing one by return value alone, which is exactly why only the element COUNT catches this.
    $r15shapePass = New-GitFixture
    Set-FixtureFile -Dir $r15shapePass -Name $script:FixtureLintScript -Content "'line one'`n'line two'`nexit 0`n"
    $shapePass = @(Invoke-WorkflowGates -RepoRoot $r15shapePass -SkipTests -Context 'test' -FailureConsequence 'x' 2>$null)
    Assert-Equal 1 $shapePass.Count 'a lint script that PRINTS two lines before passing ALSO returns exactly one element'
    Assert-True ($shapePass.Count -eq 1 -and $shapePass[0] -is [bool] -and $shapePass[0] -eq $true) 'and that one element is the boolean $true'

    # 15f. THE GATE'S CHILDREN DO NOT INHERIT THE CHAIN'S CLOSE-OUT SUPPRESSION (issue #1910), and
    # this case asks a REAL CHILD what it saw rather than reading this function's source text.
    #
    # WHY THE STRUCTURAL ASSERT IS NOT ENOUGH -- the point Victor's review made on the branch that
    # added this. closeout-lib.tests.ps1 greps Invoke-WorkflowGates for Suspend/Restore, which catches
    # the call being DELETED and misses the call being MOVED: a suspend that landed after the gates
    # instead of before them satisfies every regex and reintroduces #1910 in silence. What actually
    # has to hold is a fact about the spawned process, so the fixture lint script -- a genuine child,
    # spawned by the same Start-Process the real lint gate uses -- writes down the value it inherited.
    #
    # THE LINT GATE AND NOT THE TEST GATE, deliberately: both are spawned inside the same try, one
    # child costs milliseconds where a fixture test-suite run costs seconds, and the property under
    # test is the environment at the spawn boundary, which is the same boundary for both.
    $script:FixtureSeenFile = 'closeout-seen.txt'
    $seenScript = @(
        "`$v = [Environment]::GetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS')"
        "Set-Content -LiteralPath (Join-Path `$PSScriptRoot '$script:FixtureSeenFile') -Value ('[' + `$v + ']')"
        'exit 0'
    ) -join "`n"

    # Under a conductor: the child sees nothing, and the conductor's own flag survives the gate.
    $r15sup = New-GitFixture
    Set-FixtureFile -Dir $r15sup -Name $script:FixtureLintScript -Content ($seenScript + "`n")
    [Environment]::SetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS', '1')
    try {
        Assert-True (Invoke-WorkflowGates -RepoRoot $r15sup -SkipTests -Context 'test' -FailureConsequence 'x') 'the gate still passes with a conductor above it'
        Assert-Equal '[]' ((Get-Content -LiteralPath (Join-Path $r15sup $script:FixtureSeenFile) -Raw).Trim()) 'a child spawned by the gate does NOT inherit DKJ_CLOSEOUT_SUPPRESS -- the failure #1910 was filed about'
        Assert-Equal '1' ([Environment]::GetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS')) "...and the conductor's own suppression is restored, so #1884 is untouched"
    } finally { [Environment]::SetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS', $null) }

    # THE RESTORE IS IN A finally, so a RED gate must leave the chain above it exactly as it found it.
    # A gate that only restored on success would un-mute a conductor precisely when it stops -- which
    # is the run that then prints the receipt it was suppressing.
    $r15supFail = New-GitFixture
    Set-FixtureFile -Dir $r15supFail -Name $script:FixtureLintScript -Content "exit 1`n"
    [Environment]::SetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS', '1')
    try {
        Assert-True (-not (Invoke-WorkflowGates -RepoRoot $r15supFail -SkipTests -Context 'test' -FailureConsequence 'x' 2>$null)) 'a failing lint gate still returns false under a conductor'
        Assert-Equal '1' ([Environment]::GetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS')) '...and the suppression is restored on the failing path too'
    } finally { [Environment]::SetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS', $null) }

    # AND THE MIRROR IMAGE: with no conductor above, the gate must not leave a flag behind it. This is
    # the half an unconditional Pop would also satisfy and a naive "set it back to '1'" would not.
    $r15nosup = New-GitFixture
    Set-FixtureFile -Dir $r15nosup -Name $script:FixtureLintScript -Content ($seenScript + "`n")
    Assert-True (Invoke-WorkflowGates -RepoRoot $r15nosup -SkipTests -Context 'test' -FailureConsequence 'x') 'the gate passes with no conductor above it'
    Assert-Equal '[]' ((Get-Content -LiteralPath (Join-Path $r15nosup $script:FixtureSeenFile) -Raw).Trim()) 'the child still sees nothing'
    Assert-True ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('DKJ_CLOSEOUT_SUPPRESS'))) '...and the gate sets no flag it did not find -- Restore is a restore, not a Push'

    # --- 16. the mirror carries Invoke-WorkflowGates too ------------------------------------------
    Write-Host "`n== 16. the function travels to the plugin mirror ==" -ForegroundColor Cyan
    $mirrorLibPath    = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lib\gate-lib.ps1'
    $mirrorOpenPrPath = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\release\open-pr.ps1'
    Assert-True (Test-Path -LiteralPath $mirrorLibPath) 'the mirrored gate-lib.ps1 exists'
    Assert-True (Test-Path -LiteralPath $mirrorOpenPrPath) 'the mirrored open-pr.ps1 exists'
    if ((Test-Path -LiteralPath $mirrorLibPath) -and (Test-Path -LiteralPath $mirrorOpenPrPath)) {
        $mirrorLibText    = [System.IO.File]::ReadAllText($mirrorLibPath)
        $mirrorOpenPrText = [System.IO.File]::ReadAllText($mirrorOpenPrPath)
        Assert-True ($mirrorLibText -match 'function Invoke-WorkflowGates') 'the mirrored gate-lib.ps1 carries Invoke-WorkflowGates'
        Assert-Equal 2 ([regex]::Matches($mirrorOpenPrText, 'Invoke-WorkflowGates -RepoRoot \$repoRoot').Count) 'the mirrored open-pr.ps1 calls it at both sites'
    }

    # --- 17. the lane knob reaches the test gate, unchanged (issue #1443) -------------------------
    # THE WHOLE CHANGE IS A PASSTHROUGH, so the only thing worth asserting is that the number arrives
    # and that nothing on the way invents a policy of its own. Run for real, with a FAKE
    # Invoke-TestSuiteGate that records what it was handed -- which is exactly the seam case 15b
    # proves is read from the caller's scope, used here in the other direction.
    Write-Host "`n== 17. -MaxParallel travels from the caller to the test gate ==" -ForegroundColor Cyan

    $script:SeenMaxParallel = 'never called'
    function Invoke-TestSuiteGate {
        param([string]$TestsDir, [string]$Context, [int]$MaxParallel = 0, [int]$Shard = 0, [int]$ShardCount = 0)
        $script:SeenMaxParallel = $MaxParallel
        return $true
    }

    # 17a. A number passed in arrives as that number.
    $r17 = New-GitFixture
    Assert-True (Invoke-WorkflowGates -RepoRoot $r17 -SkipLint -MaxParallel 4 -Context 'test' -FailureConsequence 'x') 'the call succeeds with the fake test gate'
    Assert-Equal 4 $script:SeenMaxParallel '-MaxParallel 4 arrives at Invoke-TestSuiteGate as 4'

    # 17b. NOT PASSING IT IS THE OLD BEHAVIOUR, and 0 is what makes that true: Invoke-TestSuiteGate's
    # own `-le 0` branch resolves the default, so gate-lib forwarding a literal 0 is indistinguishable
    # from the call this replaced, which passed no -MaxParallel at all. This is the assertion that
    # keeps a well-meaning "resolve it here instead" from silently moving the policy up a level.
    $script:SeenMaxParallel = 'never called'
    $r17default = New-GitFixture
    Assert-True (Invoke-WorkflowGates -RepoRoot $r17default -SkipLint -Context 'test' -FailureConsequence 'x') 'the call succeeds without a lane count'
    Assert-Equal 0 $script:SeenMaxParallel 'and Invoke-TestSuiteGate is handed 0 -- its own default, resolved by it and not by gate-lib'

    # 17c. And the two scripts above it carry the parameter through rather than dropping it. Shape,
    # not behaviour: running open-pr for real would run the actual gate, which is the thing this
    # branch exists to make smaller.
    $shipPrPath = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'
    $shipPr     = [System.IO.File]::ReadAllText($shipPrPath)
    Assert-True ($openPr -match '\[int\]\$MaxParallel = 0')  'open-pr.ps1 declares -MaxParallel, defaulting to 0'
    Assert-True ($shipPr -match '\[int\]\$MaxParallel = 0')  'ship-pr.ps1 declares it too'
    Assert-Equal 2 ([regex]::Matches($openPr, 'Invoke-WorkflowGates -RepoRoot \$repoRoot[^\r\n]*-MaxParallel \$MaxParallel').Count) 'and open-pr forwards it at BOTH call sites -- the PR path and -GatesOnly'
    # ship-pr forwards only a non-zero value: open-pr's own default IS 0, so forwarding it always
    # would put a lane count on the command line of every ordinary run for no effect.
    Assert-True ($shipPr -match '\$MaxParallel -gt 0.*\$openArgs \+=') 'ship-pr forwards it to open-pr only when it was actually asked for'

    # ---------------------------------------------------------------------------------------------
    # 18. Get-CiTestCertificate -- the third evidence source (issue #1715).
    #
    # WRITTEN FROM THE REFUSAL SIDE, like every other case in this file, and here the asymmetry is at
    # its sharpest: a false negative costs one 30-minute gate run, a false positive lets a commit
    # merge on a certificate that was issued for a DIFFERENT commit. So the SHA comparison and the
    # all-or-nothing bucket rule each get their own case, and the happy path is one line.
    $sha  = 'a' * 40
    $other = 'b' * 40
    $named = 'lint-en-tests'
    $green = '[{"name":"lint-en-tests","bucket":"pass"}]'

    $c18a = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $green -CheckName $named
    Assert-True $c18a.Certified 'the named check green on the exact HEAD certifies the commit'
    Assert-True ($c18a.Note -match 'lint-en-tests') 'and the note names the check that carried it'
    Assert-True ($c18a.Note -match [regex]::Escape($sha.Substring(0, 8))) 'and the commit it was issued for'

    # THE CASE THIS FUNCTION EXISTS TO REFUSE. A moved trunk, a bring-forward, an unpushed local
    # commit -- all three arrive here as "the PR head is not this HEAD", and all three must run.
    $c18b = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $other -RequiredChecksJson $green -CheckName $named
    Assert-True (-not $c18b.Certified) 'a certificate for another commit does NOT certify this one'
    Assert-True ($c18b.Note -match 'different commit') 'and the refusal says why in those words'

    # NO NAME IS THE PRE-SEAM BEHAVIOUR, and it is the default every consumer starts on. A repo that
    # has not said which check proves its suites must keep running them.
    $c18n = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $green -CheckName ''
    Assert-True (-not $c18n.Certified) 'no declared check name -> no certificate, whatever CI says'
    Assert-True ($c18n.Note -match 'Get-CiTestCheckName') 'and the refusal names the seam to set'

    # No PR yet: the first open-pr of a branch. Not an error, not a skip.
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha '' -RequiredChecksJson $green -CheckName $named).Certified) 'no PR head -> no certificate'
    Assert-True (-not (Get-CiTestCertificate -HeadSha '' -PrHeadSha $sha -RequiredChecksJson $green -CheckName $named).Certified) 'no local HEAD -> no certificate'

    # EMPTY IS THE AMBIGUOUS ANSWER AND IT RESOLVES TOWARD THE GATE. `gh pr checks --required`
    # reports what has REGISTERED, so "nothing required" and "nothing registered yet" are the same
    # payload -- the race Get-RequiredCheckContexts documents. Skipping on it would hand every
    # GitHub Free consumer a permanently skipped test gate.
    foreach ($empty in @('', '   ', '[]', 'not json at all')) {
        $label = if ($empty.Trim()) { "'$empty'" } else { 'an empty payload' }
        Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $empty -CheckName $named).Certified) "$label is not a certificate"
    }

    # THE PARTIAL-REGISTRATION RACE -- the finding that made this function certify on a NAMED check
    # instead of on "every record that came back was green" (code review, September 9, 2026). A trunk
    # requiring two contexts: the unrelated one registers and goes green first, the test check has not
    # registered at all, so the payload is non-empty and holds no failure. A Count-based guard cannot
    # see this; only asking for the named check by name can.
    $partial = '[{"name":"branch-entry","bucket":"pass"}]'
    $c18p = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $partial -CheckName $named
    Assert-True (-not $c18p.Certified) 'a green UNRELATED required check does not certify while the named one is absent'
    Assert-True ($c18p.Note -match 'not among') 'and the refusal says the named check was not there'
    Assert-True ($c18p.Note -match 'branch-entry') 'naming what it did find, so a misdeclared seam is visible'

    # And the same shape with the named check present but not yet green.
    $mixed = '[{"name":"lint-en-tests","bucket":"pending"},{"name":"branch-entry","bucket":"pass"}]'
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $mixed -CheckName $named).Certified) 'the named check still pending refuses, however green its neighbours are'
    $failing = '[{"name":"lint-en-tests","bucket":"fail"}]'
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $failing -CheckName $named).Certified) 'a red named check refuses it too'

    # --- 18b. THE THIRD STATE: STILL RUNNING IS NOT THE SAME REFUSAL AS RED (issue #2317) -----------
    #
    # The two asserts directly above both read 'not Certified' and were both satisfied by one word --
    # 'not green'. They are opposite facts: one says the suites have been measured and the answer is
    # no, the other says the measurement this gate is about to make by hand is already running on this
    # exact commit. Collapsing them is what made the caller re-prove a whole pool locally while the run
    # the merge is gated on was in flight.
    #
    # WRITTEN FROM THE 'MUST NOT BE IN FLIGHT' SIDE, like everything else here, because the asymmetry
    # runs the same way: a missed in-flight costs one pool run, a spurious one makes a caller wait on a
    # check that is never going to answer.
    $c18f = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $mixed -CheckName $named
    Assert-True $c18f.InFlight 'the named check pending on this exact commit reads as IN FLIGHT'
    Assert-True (-not $c18f.Certified) 'and it is still not a certificate'
    Assert-True ($c18f.Note -match 'still running') 'and the note says which of the two refusals it is'
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $failing -CheckName $named).InFlight) 'a RED named check is not in flight -- the verdict is in'
    Assert-True (-not $c18a.InFlight) 'and neither is a green one'

    # A COMMIT MATCH IS REQUIRED FOR IN FLIGHT, which is what stops this being a licence to wait on
    # anything. A check pending on a DIFFERENT commit says nothing about this tree.
    $pendingOnly = '[{"name":"lint-en-tests","bucket":"pending"}]'
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $other -RequiredChecksJson $pendingOnly -CheckName $named).InFlight) 'pending on another commit is NOT in flight for this one'
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $partial -CheckName $named).InFlight) 'a check that has not registered is not in flight -- absent is indistinguishable from never'
    foreach ($empty in @('', '[]', 'not json at all')) {
        Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $empty -CheckName $named).InFlight) 'an unreadable payload is not in flight'
    }
    Assert-True (-not (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $pendingOnly -CheckName '').InFlight) 'and neither is anything at all when no check has been named'

    # UNANIMITY, so a matrix leg that has already failed cannot be waited on. One pending record and
    # one failing record under the same name is a check that is FAILING, not one that is running.
    $halfRed = '[{"name":"lint-en-tests","bucket":"pending"},{"name":"lint-en-tests","bucket":"fail"}]'
    $c18u = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $halfRed -CheckName $named
    Assert-True (-not $c18u.InFlight) 'one failing record among the named check''s own records is not in flight'
    Assert-True (-not $c18u.Certified) 'and certainly not a certificate'

    # --- 18c. Wait-CiTestCertificate -- the loop around it (issue #2317) ---------------------------
    #
    # Every exit is walked here, because none of them is reachable from a fixture: they need a real PR
    # with a real check suite passing through a real state change. The reader and the sleeper are the
    # seam that makes them reachable, and the judgement being tested is only WHEN TO ASK AGAIN -- what
    # an answer means stays in Get-CiTestCertificate above, which 18/18b already cover.
    $newReading = { param([string]$Head, [string]$Json) [pscustomobject]@{ PrHeadSha = $Head; RequiredChecksJson = $Json } }

    # CERTIFIED: pending, pending, then green. The saving this whole mechanism exists for.
    $script:waitLaps = 0
    $w1 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 10 -Sleeper {} -Reader {
        $script:waitLaps++
        if ($script:waitLaps -lt 3) { & $newReading $sha $pendingOnly } else { & $newReading $sha $green }
    }
    Assert-True $w1.Certified 'a check that goes green while we wait hands back the certificate'
    Assert-Equal 'certified' $w1.Outcome 'and says so as its outcome'
    Assert-Equal 3 $w1.Laps 'having stopped on the lap that answered, not later'
    Assert-True ($w1.Note -match 'lint-en-tests') 'and the note is the certificate''s own, not this loop''s'

    # SETTLED (red): the wait ends the moment the answer is in, and the caller runs the suites. A red
    # is deliberately NOT a refusal here -- see the function's docstring for why that would be a second
    # behaviour change riding on this one.
    $script:waitLaps = 0
    $w2 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 10 -Sleeper {} -Reader {
        $script:waitLaps++
        if ($script:waitLaps -lt 2) { & $newReading $sha $pendingOnly } else { & $newReading $sha $failing }
    }
    Assert-True (-not $w2.Certified) 'a check that goes red ends the wait without a certificate'
    Assert-Equal 'settled' $w2.Outcome 'and reports that the question was answered, not that we gave up'
    Assert-Equal 2 $w2.Laps 'on the lap that answered it'

    # SETTLED (the head moved): a push landing during the wait must not be certified by a check that
    # started on the commit before it. This is why the reader re-reads the head and not only the checks.
    $script:waitLaps = 0
    $w3 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 10 -Sleeper {} -Reader {
        $script:waitLaps++
        if ($script:waitLaps -lt 2) { & $newReading $sha $pendingOnly } else { & $newReading $other $green }
    }
    Assert-True (-not $w3.Certified) 'a green check on a head that has MOVED does not certify this HEAD'
    Assert-Equal 'settled' $w3.Outcome 'and that is an answer, so the wait stops'
    Assert-True ($w3.Note -match 'different commit') 'with the certificate''s own words for it'

    # GAVE UP: the bound is real. A check that never answers spends the bound and hands the caller back
    # to the pool, which is exactly where it would have been without any of this.
    $w4 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 4 -Sleeper {} -Reader { & $newReading $sha $pendingOnly }
    Assert-True (-not $w4.Certified) 'a check that never answers hands back no certificate'
    Assert-Equal 'gave-up' $w4.Outcome 'and says the bound ran out rather than claiming an answer'
    Assert-Equal 4 $w4.Laps 'having spent exactly the laps it was given'
    Assert-True ($w4.Note -match 'still running') 'the note carries the last thing it actually saw'

    # A LAP THAT CANNOT BE READ IS NOT A VERDICT. An intermittently-unhealthy `gh` (#1628's measured
    # shape) must not be read as "the check is gone" -- it means ask again. Both shapes: a reader that
    # returns nothing, and one that throws.
    $script:waitLaps = 0
    $w5 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 10 -Sleeper {} -Reader {
        $script:waitLaps++
        switch ($script:waitLaps) {
            1 { $null }
            2 { throw 'gh fell over' }
            default { & $newReading $sha $green }
        }
    }
    Assert-True $w5.Certified 'an unreadable lap is retried, not treated as an answer'
    Assert-Equal 3 $w5.Laps 'and the laps it cost are counted honestly'

    # AND A READER THAT NEVER ANSWERS STILL TERMINATES, on the bound alone.
    $w6 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 3 -Sleeper {} -Reader { throw 'gh is down' }
    Assert-Equal 'gave-up' $w6.Outcome 'a reader that only ever throws ends on the bound'
    Assert-Equal 3 $w6.Laps 'after exactly the laps it was allowed'
    Assert-True ($w6.Note -match 'never readable') 'and says it never got a readable answer at all, rather than inventing one'

    # THE WALL-CLOCK BOUND IS THE OTHER HALF, and it exists because -MaxLaps cannot see a slow `gh`:
    # 60 laps of a call that takes a minute each is an hour, with the lap count still inside its bound.
    $w7 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -TimeoutSeconds 1 -Sleeper { Start-Sleep -Milliseconds 400 } -Reader { & $newReading $sha $pendingOnly }
    Assert-Equal 'gave-up' $w7.Outcome 'the wall-clock bound ends the wait even with laps to spare'
    Assert-True ($w7.WaitedSeconds -ge 1) 'having actually spent the seconds it reports'

    # A CALLER'S OWN VARIABLE NAMES MUST NOT REACH INTO THIS LOOP'S LOCALS -- the defect this suite
    # found while it was being written, and the reason every local in that loop carries a prefix.
    # PowerShell scriptblocks are DYNAMICALLY scoped: `& $Reader` runs in a child of the function's
    # scope, so a caller reading a variable they did not assign in their own scriptblock gets the
    # function's local of that name. The first draft here had a helper called $reading and the
    # function had a local called $reading, which was $null on the line the caller read -- so every
    # lap threw, was swallowed as an unreadable read, and the wait ran to its bound. It fails as
    # "CI never answered", which is indistinguishable from the real thing.
    #
    # So this asserts the shape rather than the symptom: the loop's locals are named such that the
    # obvious caller-side names do not collide. Behavioural, not a source grep -- it uses the four
    # names a caller would most plausibly reach for.
    $reading  = & $newReading $sha $green   # deliberately the name that collided
    $cert     = 'not a certificate'
    $laps     = 99
    $lastNote = 'not a note'
    $w8 = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 2 -Sleeper {} -Reader { $reading }
    Assert-True $w8.Certified 'a caller whose reader closes over $reading still gets its own value'
    Assert-Equal 1 $w8.Laps 'on the first lap, with the caller''s $laps untouched'
    Assert-Equal 99 $laps 'and the caller''s own variables are not written by the loop'
    Assert-Equal 'not a certificate' $cert 'nor its $cert'
    Assert-Equal 'not a note' $lastNote 'nor its $lastNote'

    # THE SLEEPER RUNS BEFORE THE READ, not after: the caller has just read, so reading again
    # immediately would spend a `gh` call to learn what it already knows.
    $script:sleepFirst = $false
    $script:readSeen   = $false
    $null = Wait-CiTestCertificate -HeadSha $sha -CheckName $named -MaxLaps 1 `
                                   -Sleeper { if (-not $script:readSeen) { $script:sleepFirst = $true } } `
                                   -Reader  { $script:readSeen = $true; & $newReading $sha $green }
    Assert-True $script:sleepFirst 'the poll interval is spent before the first re-read, not after it'

    # AND THE TWO CONSTANTS ARE CONSTANTS, not another knob: a wait that can be set to zero is a gate
    # somebody can turn off by accident, and the escape valve is -NoCiWait, which is a switch.
    $gateSrcForWait = [System.IO.File]::ReadAllText($LibPath)
    Assert-True ($gateSrcForWait -match '\$script:CiCertificateWaitSeconds\s*=\s*\d+') 'the wait bound is a script constant'
    Assert-True ($gateSrcForWait -match '\$script:CiCertificateWaitPollSeconds\s*=\s*\d+') 'and so is the poll interval'

    # --- 18d. And the wiring in open-pr: the wait sits on the in-flight branch ONLY (issue #2317) ---
    Assert-True ($openPr -match '\$cert\.InFlight -and -not \$NoCiWait') 'open-pr waits only where the check is in flight and the valve is not set'
    Assert-True ($openPr -match 'Wait-CiTestCertificate') 'and it is the shared loop that does the waiting'
    Assert-True ($openPr -match '\[switch\]\$NoCiWait') 'open-pr takes the escape valve'
    Assert-True ($shipPr -match '\[switch\]\$NoCiWait') 'and ship-pr does too'
    Assert-True ($shipPr -match 'if \(\$NoCiWait\)\s*\{\s*\$openArgs \+= ''-NoCiWait''') 'forwarding it only when it was actually asked for, like every other flag on that hop'
    # THE OTHER REFUSALS MUST STILL FALL STRAIGHT THROUGH TO THE POOL. If the `else` ever disappeared,
    # a red check or a moved head would silently become a wait -- the one way this change could cost
    # time instead of saving it.
    Assert-True ($openPr -match "(?s)\} else \{\s*\n\s*Write-Host \""test gate: no CI certificate for this commit") 'every other refusal still runs the suites immediately'

    # 5.1 HANDS A ONE-ELEMENT JSON ARRAY THROUGH AS THE OBJECT ITSELF, which is why the parse wraps
    # before it filters. This repo's own ruleset requires exactly ONE check, so a collapse here would
    # be invisible in the source repo and would surface only in a consumer with two.
    $twoGreen = '[{"name":"lint-en-tests","bucket":"pass"},{"name":"branch-entry","bucket":"pass"}]'
    Assert-True (Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $twoGreen -CheckName $named).Certified 'the named check certifies alongside a second required check'

    # EXTERNALLY-AUTHORED NAMES ARE SANITISED BEFORE THEY ARE PRINTED **OR** COMPARED. A check name is
    # chosen by whoever produced the check, and an ANSI/OSC escape or a zero-width run in it would
    # repaint or misrepresent the one line that says what stood a gate down.
    $hostile = '[{"name":"lint-en-tests' + [char]0x1B + "[31m" + [char]0x200B + '","bucket":"pass"}]'
    $c18s = Get-CiTestCertificate -HeadSha $sha -PrHeadSha $sha -RequiredChecksJson $hostile -CheckName $named
    Assert-Equal 0 ([regex]::Matches($c18s.Note, '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]').Count) 'no control, format, line/paragraph separator or combining-mark character survives into the note'

    # 19. And the wiring: gate-lib honours the certificate, open-pr computes one, and neither records
    # it as local gate evidence. Shape asserts -- running open-pr for real would run the gate this
    # branch exists to skip.
    $gateSrc = [System.IO.File]::ReadAllText($LibPath)
    Assert-True ($gateSrc -match '\[string\]\$TestsProvedByCi') 'Invoke-WorkflowGates takes the certificate as a string, not a switch'
    Assert-True ($gateSrc -match 'elseif \(\$TestsProvedByCi\)') 'and consults it AFTER the local record and BEFORE the suites'
    Assert-True ($openPr -match 'Get-CiTestCertificate') 'open-pr computes the certificate'
    Assert-True ($openPr -match "if \(\`$existingPr -and -not \`$SkipTests\)") 'only where a PR exists and the suites were going to run'
    Assert-True ($openPr -match "'--required'") 'and asks for the REQUIRED checks, i.e. the trunk''s own bar'
    Assert-True ($openPr -match 'Get-CiTestCheckName') 'and reads the seam that names which check proves the suites'
    # The seam is PROBED before it is called, so a consumer whose repo-config predates it gets no
    # certificate instead of a crash -- the same failure direction as every other refusal here. The
    # probe was an inline Get-Command until #1729 and is Test-FunctionDefined now; what this assert is
    # for is that the call is guarded at all, so it matches the guard rather than the idiom of the day.
    Assert-True ($openPr -match "Test-FunctionDefined 'Get-CiTestCheckName'") 'defensively, so an older consumer repo-config does not break the run'
    # The sanitiser is loaded by the lib itself, following remote-ahead-lib and entry-scaffold-lib,
    # rather than being added to the caller contract in the header.
    Assert-True ($gateSrc -match "ref-print-lib\.ps1") 'gate-lib loads the prose sanitiser itself'
    # Three call sites: the declared name, the comparison against each name in the payload, and the
    # "found instead" list in the refusal. Every string that reaches the console passes through one.
    Assert-Equal 3 ([regex]::Matches($gateSrc, 'Get-DisplayRef -Ref').Count) 'and uses it at all three sites -- the declared name, the comparison, and the refusal list'
    # The one assertion that keeps the skip from silently outliving its certificate: a remote green
    # must never be filed as "this machine proved this tree", which Test-GateEvidence would then
    # honour for four hours.
    $certBranch = [regex]::Match($gateSrc, 'elseif \(\$TestsProvedByCi\)(.|\n)*?\} elseif').Value
    Assert-Equal 0 ([regex]::Matches($certBranch, 'Save-GateEvidence').Count) 'the CI certificate is NOT written into the local evidence record'

    # --- 18. THE NOTE-TREE DEDUCTION (issue #2102) --------------------------------------------------
    #
    #     WRITTEN FROM THE REFUSING SIDE, exactly as this file's header says the fingerprint cases are,
    #     and for the sharper version of the same reason. A false negative here costs one gate run; a
    #     false positive skips 114 suites over a commit that changed something they read. So one case
    #     asserts the happy path and the rest assert that the deduction is REFUSED -- including the two
    #     shapes that look like they should pass and must not (a clean tree, and a sibling directory
    #     whose name merely starts with a root).
    Write-Host "`n== 18. Get-NoteTreeOnlyVerdict -- the deduction refuses by default ==" -ForegroundColor Cyan

    $rN = New-GitFixture
    New-Item -ItemType Directory -Path (Join-Path $rN 'notes\audience') -Force | Out-Null
    $noteRoots = @('notes/audience', 'notes/internal')

    # A CLEAN TREE IS NOT PROVEN, and this is the case most likely to be "fixed" into a bug. The claim
    # is about what CHANGED; with nothing changed there is no note-tree change to reason from.
    $vClean = Get-NoteTreeOnlyVerdict -RepoRoot $rN -NoteRoots $noteRoots
    Assert-True (-not $vClean.Proven) 'a clean tree is NOT proven -- there is no note-tree change to deduce from'
    Assert-True ($vClean.Reason -match 'nothing differs from HEAD') 'and the reason says so rather than leaving the caller to guess'

    # The happy path: one untracked file, inside a root.
    Set-FixtureFile -Dir $rN -Name 'notes\audience\1.0.0.md' -Content "# 1.0.0`n"
    $vNote = Get-NoteTreeOnlyVerdict -RepoRoot $rN -NoteRoots $noteRoots
    Assert-True $vNote.Proven 'a change confined to the note tree IS proven'
    Assert-Equal 1 $vNote.Inside.Count 'and the run can name what it proved the deduction over'
    Assert-Equal 0 $vNote.Outside.Count 'with nothing outside'

    # ONE STRAY PATH IS ENOUGH TO REFUSE, which is the property the whole shape rests on.
    Set-FixtureFile -Dir $rN -Name 'tracked.txt' -Content "two`n"
    $vStray = Get-NoteTreeOnlyVerdict -RepoRoot $rN -NoteRoots $noteRoots
    Assert-True (-not $vStray.Proven) 'one path outside the note tree refuses the whole deduction'
    Assert-True ($vStray.Outside -contains 'tracked.txt') 'and the stray path is named, so the refusal is actionable'
    Assert-True ($vStray.Inside -contains 'notes/audience/1.0.0.md') 'while the inside paths are still reported'

    # NO ROOTS MEANS NO BOUND, and the empty case must be the REFUSING one -- the inversion where an
    # empty list reads as "everything qualifies" is the whole hazard of this family.
    $vNoRoots = Get-NoteTreeOnlyVerdict -RepoRoot $rN -NoteRoots @()
    Assert-True (-not $vNoRoots.Proven) 'a repo naming no note tree is NOT proven -- an empty bound refuses, it does not admit'
    Assert-True ($vNoRoots.Reason -match 'names no release-note tree') 'and it says which of the reasons it was'
    Assert-True (-not (Get-NoteTreeOnlyVerdict -RepoRoot $rN -NoteRoots @('', '   ')).Proven) 'and blank entries do not count as a bound either'

    Write-Host "`n== 18b. the prefix trap, the rename, and the case rule ==" -ForegroundColor Cyan

    # THE PREFIX TRAP. 'notes/audience-extra' starts with 'notes/audience' as a STRING and is a
    # different directory -- a StartsWith without the separator would silently admit it.
    $rP = New-GitFixture
    New-Item -ItemType Directory -Path (Join-Path $rP 'notes\audience-extra') -Force | Out-Null
    Set-FixtureFile -Dir $rP -Name 'notes\audience-extra\x.md' -Content "x`n"
    $vPrefix = Get-NoteTreeOnlyVerdict -RepoRoot $rP -NoteRoots @('notes/audience')
    Assert-True (-not $vPrefix.Proven) 'a sibling directory whose name merely STARTS with a root is not inside it'
    Assert-True ($vPrefix.Outside -contains 'notes/audience-extra/x.md') 'and it is reported as outside'

    # THE ROOT ITSELF, as a path, counts as inside -- the equality half of the same comparison.
    Assert-True (Get-NoteTreeOnlyVerdict -RepoRoot $rP -NoteRoots @('notes/audience-extra')).Proven 'a root pointed straight at the changed tree proves it'

    # A RENAME IS JUDGED ON BOTH HALVES. A note dragged OUT of the tree changes a path the suites might
    # read, even though the surviving path is inside -- so From is held to the same bound as Path.
    $rR = New-GitFixture
    New-Item -ItemType Directory -Path (Join-Path $rR 'notes\audience') -Force | Out-Null
    Set-FixtureFile -Dir $rR -Name 'notes\audience\2.0.0.md' -Content "# 2.0.0`n"
    Invoke-FixtureGit -Dir $rR 'add' '-A'
    Invoke-FixtureGit -Dir $rR 'commit' '-qm' 'note'
    Invoke-FixtureGit -Dir $rR 'mv' 'notes/audience/2.0.0.md' 'moved-out.md'
    $vRenameOut = Get-NoteTreeOnlyVerdict -RepoRoot $rR -NoteRoots @('notes/audience')
    Assert-True (-not $vRenameOut.Proven) 'a rename OUT of the note tree refuses, though one half of it is inside'
    Assert-True ($vRenameOut.Outside -contains 'moved-out.md') 'and the half that left is what is named'

    # And the mirror: a rename WITHIN the tree keeps both halves inside, so it still proves.
    $rR2 = New-GitFixture
    New-Item -ItemType Directory -Path (Join-Path $rR2 'notes\audience') -Force | Out-Null
    Set-FixtureFile -Dir $rR2 -Name 'notes\audience\3.0.0.md' -Content "# 3.0.0`n"
    Invoke-FixtureGit -Dir $rR2 'add' '-A'
    Invoke-FixtureGit -Dir $rR2 'commit' '-qm' 'note'
    Invoke-FixtureGit -Dir $rR2 'mv' 'notes/audience/3.0.0.md' 'notes/audience/3.0.1.md'
    Assert-True (Get-NoteTreeOnlyVerdict -RepoRoot $rR2 -NoteRoots @('notes/audience')).Proven 'a rename WITHIN the note tree still proves'

    # CASE IS ORDINAL, and the direction of being wrong is the point: a root whose case has drifted
    # from git's on-disk spelling simply fails to match, and the run gates for real.
    Assert-True (-not (Get-NoteTreeOnlyVerdict -RepoRoot $rP -NoteRoots @('NOTES/AUDIENCE-EXTRA')).Proven) `
        'a root whose case does not match git''s spelling refuses rather than admitting'

    Write-Host "`n== 18c. the roots resolver, and the wiring that consumes it ==" -ForegroundColor Cyan

    # THE RESOLVER READS TWO OPTIONAL SEAMS AND NEITHER IS REQUIRED. With neither defined it must hand
    # back an EMPTY list -- which the verdict above refuses on -- rather than a default anybody inherits.
    Assert-Equal 0 (@(Get-ReleaseNoteTreeRoots -RepoRoot $rN)).Count 'with neither seam defined the resolver returns nothing to hold anything to'
    function Get-ReleaseNoteRoot { return 'dkj-policy/releases/audience/' }
    Assert-Equal 'dkj-policy/releases/audience' (@(Get-ReleaseNoteTreeRoots -RepoRoot $rN))[0] 'a trailing slash is normalised away, so the caller never has to'
    function Get-ReleaseInternalNotesRoot { return 'dkj-policy\releases\internal' }
    $bothRoots = @(Get-ReleaseNoteTreeRoots -RepoRoot $rN)
    Assert-Equal 2 $bothRoots.Count 'both seams are read when both are defined'
    Assert-True ($bothRoots -contains 'dkj-policy/releases/internal') 'and a backslashed answer is forward-slashed, so it matches what git reports'
    Remove-Item -LiteralPath 'function:Get-ReleaseNoteRoot', 'function:Get-ReleaseInternalNotesRoot' -ErrorAction SilentlyContinue

    # THE SKIP MUST WRITE NOTHING, on -SkipTests' own rule: this run did not measure the suites, so
    # filing evidence would make the NEXT run skip a gate this one never earned. Asserted on the source
    # the same way the CI certificate's own branch is, two cases up.
    $noteBranch = [regex]::Match($gateSrc, '\} elseif \(\$gateNoteTree -and \$gateNoteTree\.Proven\) \{(.|\n)*?\n            \} elseif').Value
    Assert-True ([bool]$noteBranch) 'the note-tree branch is found as its own elseif'
    Assert-Equal 0 ([regex]::Matches($noteBranch, 'Save-GateEvidence').Count) 'and it records NO gate evidence -- a deduction is not a measurement'
    Assert-True ($noteBranch -match 'Get-DisplayPath') 'the paths it prints go through the console strip, like every other path this workflow prints'

    # THE REFUSAL IS PRINTED WHERE THE VERDICT IS TAKEN, not inside the branch that consumes it -- a
    # verdict computed inside its own success branch can only ever report the success.
    Assert-True ($gateSrc -match 'if \(-not \$gateNoteTree\.Proven\) \{') 'the not-proven case has its own printed refusal'
    Assert-True ($gateSrc -match 'Running every suite, exactly as without the switch') 'which states that the fallback is unchanged behaviour'

    # AND IT IS ONLY SAID WHERE THE SUITES ACTUALLY RUN. Both cheaper skips above it -- the evidence
    # record and the CI certificate -- skip for reasons of their own, so a refusal printed ahead of them
    # puts 'running every suite' and 'skipped' on two adjacent lines and contradicts itself. The
    # behaviour was right either way; the transcript was not, and this file's bar is that what a gate
    # prints IS the argument. The same gating is what keeps the git call off the cheap path.
    Assert-True ($gateSrc -match '\$NoteTreeOnly -and -not \$gateTestsProved -and -not \$TestsProvedByCi') `
        'the verdict is measured only where neither cheaper skip already applies -- so the refusal cannot contradict them'
    Assert-Equal 2 ([regex]::Matches($gatesFuncBody, 'Test-GateEvidence').Count) `
        'and hoisting the tests consult into a variable kept it at one per gate, not two for the test half'

    # AND open-pr WIRES IT AT THE -GatesOnly SITE ONLY, naming it on the PR path rather than letting it
    # do nothing quietly -- the failure class that script already refuses to tolerate for its own flags.
    Assert-Equal 1 ([regex]::Matches($openPr, '-NoteTreeOnly:\$NoteTreeOnly').Count) 'open-pr forwards -NoteTreeOnly at exactly one call site'
    $gatesOnlyRegion = [regex]::Match($openPr, '(?s)if \(\$GatesOnly\) \{.*?\n\}').Value
    Assert-True ($gatesOnlyRegion -match '-NoteTreeOnly:\$NoteTreeOnly') 'and that site is the -GatesOnly one, which is the case it was measured on'
    Assert-True ($openPr -match '-NoteTreeOnly applies to -GatesOnly only') 'the PR path says the flag was ignored instead of silently dropping it'

} finally {
    if (Test-Path -LiteralPath $FixtureRoot) {
        Remove-Item -Recurse -Force -LiteralPath $FixtureRoot -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'gate-lib.ps1'
if ($script:fail -gt 0) { exit 1 }
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
