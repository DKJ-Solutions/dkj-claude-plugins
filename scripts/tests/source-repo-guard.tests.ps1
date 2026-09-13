<#
.SYNOPSIS
    Regression tests for scripts/lib/source-repo-guard-lib.ps1 -- the guard that refuses a shared script
    running from a released copy inside the repo that maintains it.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/source-repo-guard.tests.ps1

    TWO LAYERS, DELIBERATELY. Get-OwnCopyPath is exercised directly against synthetic trees, because the
    decision it makes has more branches than a child process can cheaply cover -- and one integration case
    runs a REAL entry point from a copy outside a real repo, because the thing that has to hold is that the
    script actually stops, with a non-zero exit code, and says which path to run instead.

    THE ALLOW CASES CARRY THE RISK, NOT THE REFUSAL. A guard that refuses too much breaks every consumer,
    which is worse than the defect it repairs -- so a consumer with no marketplace, a consumer carrying a
    same-named script of their own, and the source repo's own in-repo mirror each get a case saying the
    guard stays out of it.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary, and two runs sharing one fixed temp path tear down each other's tree
    mid-assert.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$GuardLib = Join-Path $RepoRoot 'scripts\lib\source-repo-guard-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message -- expected '$Expected', got '$Actual'" -ForegroundColor Red }
}

function New-Tree {
    <#
        A synthetic repo root. -Publishes writes .claude-plugin/marketplace.json, which is the condition
        that separates a repo that MAINTAINS shared scripts from a consumer that merely runs them.
        -Local writes the repo's own copy at scripts/<Relative>.
    #>
    param(
        [Parameter(Mandatory)][string]$Label,
        [switch]$Publishes,
        [switch]$Local,
        [string]$Relative = 'task\park-branch.ps1'
    )
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("srguard-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if ($Publishes) {
        New-Item -ItemType Directory -Path (Join-Path $dir '.claude-plugin') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir '.claude-plugin\marketplace.json') -Value '{}' -Encoding UTF8
    }
    if ($Local) {
        $p = Join-Path (Join-Path $dir 'scripts') $Relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
        Set-Content -LiteralPath $p -Value '# local copy' -Encoding UTF8
    }
    return $dir
}

$fixtures = @()
try {
    . $GuardLib

    Write-Host 'A foreign copy IS refused when the repo maintains the same script' -ForegroundColor Cyan
    # The measured case: a released mirror run inside the repo it was mirrored from.
    $src = New-Tree -Label 'src' -Publishes -Local; $fixtures += $src
    $cache = New-Tree -Label 'cache'; $fixtures += $cache
    $foreign = Join-Path $cache 'scripts\task\park-branch.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $foreign) -Force | Out-Null
    Set-Content -LiteralPath $foreign -Value '# released copy' -Encoding UTF8
    $own = Get-OwnCopyPath -ScriptPath $foreign -RepoRoot $src
    Assert-Equal 'scripts\task\park-branch.ps1' $own 'the local path to run instead is returned, repo-relative'

    Write-Host "The repo's own copy is NOT refused" -ForegroundColor Cyan
    $inside = Join-Path $src 'scripts\task\park-branch.ps1'
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $inside -RepoRoot $src) 'running the source itself is fine'

    Write-Host 'The in-repo plugin mirror is NOT refused' -ForegroundColor Cyan
    # Lint check 8 holds this byte-identical to the source, so running it is not the staleness the guard is
    # about. Refusing it would also make the drift lint's own fixtures unrunnable.
    $mirror = Join-Path $src 'plugins\dkj-policy\scripts\task\park-branch.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $mirror) -Force | Out-Null
    Set-Content -LiteralPath $mirror -Value '# in-repo mirror' -Encoding UTF8
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $mirror -RepoRoot $src) 'the mirror inside the repo is allowed'

    Write-Host 'A consumer is NEVER refused -- the two ways that must both hold' -ForegroundColor Cyan
    # 1. No marketplace: the ordinary consumer. This is the condition doing the real work.
    $plainConsumer = New-Tree -Label 'consumer' -Local; $fixtures += $plainConsumer
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $foreign -RepoRoot $plainConsumer) `
        'a repo that publishes no plugins is left alone even though it has a same-named script'
    # 2. Publishes, but has no copy of THIS script -- a repo publishing some other plugin entirely.
    $otherPublisher = New-Tree -Label 'other' -Publishes; $fixtures += $otherPublisher
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $foreign -RepoRoot $otherPublisher) `
        'a publishing repo without its own copy of this script is left alone'

    Write-Host 'A sibling directory whose name merely starts with the root name is still foreign' -ForegroundColor Cyan
    # '...\srguard-x-src-abc' vs '...\srguard-x-src-abc-two': a prefix compare without the separator reads
    # the second as being inside the first, and the guard would then wave through a genuinely foreign copy.
    $sibling = $src + '-two'
    $siblingScript = Join-Path $sibling 'scripts\task\park-branch.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $siblingScript) -Force | Out-Null
    Set-Content -LiteralPath $siblingScript -Value '# next door' -Encoding UTF8
    $fixtures += $sibling
    Assert-Equal 'scripts\task\park-branch.ps1' (Get-OwnCopyPath -ScriptPath $siblingScript -RepoRoot $src) `
        'a path that shares the root as a string PREFIX is not treated as being inside it'

    Write-Host 'The relative path comes from the INNERMOST scripts segment' -ForegroundColor Cyan
    # A mirror path carries two ('...\plugins\...\scripts\task\x.ps1'), and taking the first would compose
    # a nonsense local path like scripts\workflows\dkj-policy\scripts\task\x.ps1.
    $deep = New-Tree -Label 'deep'; $fixtures += $deep
    $deepScript = Join-Path $deep 'scripts\plugins\workflows\wf\scripts\task\park-branch.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $deepScript) -Force | Out-Null
    Set-Content -LiteralPath $deepScript -Value '# doubly nested' -Encoding UTF8
    Assert-Equal 'scripts\task\park-branch.ps1' (Get-OwnCopyPath -ScriptPath $deepScript -RepoRoot $src) `
        'two scripts segments: the last one wins'

    Write-Host 'A script that lives under no scripts/ directory at all is not judged' -ForegroundColor Cyan
    $loose = Join-Path $cache 'somewhere\else.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $loose) -Force | Out-Null
    Set-Content -LiteralPath $loose -Value '# loose' -Encoding UTF8
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $loose -RepoRoot $src) 'no scripts segment, no verdict'

    Write-Host 'An unresolvable repo root switches the guard OFF rather than refusing' -ForegroundColor Cyan
    # A guard that cannot tell which repo it is in must not refuse anything: that would break a script run
    # outside any repo, which is a legitimate thing to do with fix-mojibake -Path.
    Assert-Equal $null (Get-OwnCopyPath -ScriptPath $foreign -RepoRoot (Join-Path $cache 'no-such-tree')) `
        'a root that does not exist yields no finding'

    Write-Host 'INTEGRATION: a real entry point stops, with exit 1, naming the local path' -ForegroundColor Cyan
    # The asserts above prove the decision; this proves the CONSEQUENCE. Without it, a lib returning the
    # right answer to nobody would pass the suite.
    #
    # THE ENTRY POINT USED TO BE session-status.ps1, removed with /lock and /handover by #957. What this
    # block needs is any guarded entry point that (a) loads the guard BEFORE any other lib and (b) writes
    # nothing, so a guard that failed to fire cannot damage the real tree it is pointed at. check-branch-entry
    # qualifies on both counts: the guard is its first dot-source, and it only reports.
    $realRepo = $RepoRoot
    $awayDir = Join-Path ([System.IO.Path]::GetTempPath()) ("srguard-$PID-away-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $fixtures += $awayDir
    New-Item -ItemType Directory -Path (Join-Path $awayDir 'scripts\lint') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $awayDir 'scripts\lib') -Force | Out-Null
    # fixture-dep: script-not-loaded scripts/lint/check-branch-entry.ps1 -- the guard is its FIRST
    # dot-source and this block exists to watch it refuse, so the run exits 1 before any other lib is
    # reached. Copying the other five would be carrying equipment to a script that never gets that far,
    # and the fixture's whole point is that it does not. See fixture-dep-lib.ps1 for the declaration.
    Copy-Item (Join-Path $realRepo 'scripts\lint\check-branch-entry.ps1') (Join-Path $awayDir 'scripts\lint\check-branch-entry.ps1')
    Copy-Item $GuardLib (Join-Path $awayDir 'scripts\lib\source-repo-guard-lib.ps1')
    $prev = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $realRepo
        $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $awayDir 'scripts\lint\check-branch-entry.ps1') 2>&1) | Out-String
        $code = $LASTEXITCODE
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
    Assert-Equal 1 $code 'the run exits 1 rather than reporting'
    # -cmatch, CASE-SENSITIVELY, and the reason is worth keeping even though the script that produced it is
    # gone: session-status printed the lock file, whose prose was full of the word 'refuses', and a
    # case-insensitive match on 'REFUSED' passed against a run that never fired. Any entry point can print
    # the lowercase word in passing, so the marker is only evidence in the case the guard writes it.
    Assert-True ($out -cmatch 'REFUSED: this repo maintains') 'it says it refused, in its own words'
    Assert-True ($out -match 'run this: scripts.lint.check-branch-entry\.ps1') 'and names the copy to run instead'
    # IT STOPPED BEFORE DOING ANY OF ITS WORK, pinned on the very next thing it would have touched: the
    # away tree carries the guard lib and nothing else, so a guard that did not fire would fall over on the
    # dot-source below it and say so, naming the lib in the error.
    Assert-True (-not ($out -match 'entry-scaffold-lib')) 'and it stopped BEFORE doing any of its work'

    Write-Host 'A WORKTREE of the repo is NOT refused, and a CLONE still is (#851)' -ForegroundColor Cyan
    # REAL GIT HERE, not a directory fixture. The whole question is what `git rev-parse
    # --git-common-dir` answers, and a fabricated tree cannot answer it -- asserting against a stub
    # would test the stub. The pair matters more than either half: a worktree must be allowed AND a
    # separate clone must still be refused, because the second is the released mirror this guard exists
    # for, and a fix that let both through would remove the guard while looking like it narrowed it.
    #
    # EVERY git CALL GOES THROUGH Invoke-NativeCapture, and that is not tidiness. git writes progress to
    # stderr, which under this file's $ErrorActionPreference = 'Stop' becomes a TERMINATING error even
    # when git exits 0 -- the #96/#97/#107 pitfall the repo has paid for three times. Writing these
    # asserts the obvious way reproduced it immediately: `git worktree add` printed 'Preparing worktree'
    # and the suite died on a successful command.
    . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
    # KEPT FOR THE ONE git CALL THAT IS A QUESTION -- '--version', whose non-zero exit IS the answer and
    # is read in the same statement. Every fixture MUTATION below goes through Invoke-FixtureGitJudged
    # instead (issue #1635): those had their exit code discarded by '| Out-Null', so a worktree or a clone
    # that never got built read exactly like one that did, and the asserts below then measured a tree the
    # case never made.
    $git = {
        param([string[]]$Arguments)
        Invoke-NativeCapture -FilePath 'git' -Arguments $Arguments
    }

    $gitOk = (& $git @('--version')).ExitCode -eq 0
    if (-not $gitOk) {
        # Announced rather than silently skipped: a suite that needs git to prove a git rule must say when
        # it could not, or a green run means something different from what the reader thinks.
        Write-Host '  [SKIP] git is not available -- the worktree asserts did not run' -ForegroundColor Yellow
    } else {
        $gitSrc = New-Tree -Label 'gitsrc' -Publishes -Local; $fixtures += $gitSrc
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'init', '--quiet')
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'config', 'user.email', 'suite@example.invalid')
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'config', 'user.name', 'Suite')
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'config', 'commit.gpgsign', 'false')
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'add', '-A')
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'commit', '--quiet', '-m', 'fixture')

        # The lane lives OUTSIDE the repo root, exactly as worktree-lane.ps1 places it -- a worktree
        # inside the tree would be walked by the lint gate's link scan and by the suites.
        $lane = Join-Path ([System.IO.Path]::GetTempPath()) ("guard-lane-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
        $fixtures += $lane
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'worktree', 'add', '--detach', $lane)
        $laneScript = Join-Path $lane 'scripts\task\park-branch.ps1'

        Assert-True (Test-Path -LiteralPath $laneScript) 'the worktree carries the committed script'
        Assert-Equal $null (Get-OwnCopyPath -ScriptPath $laneScript -RepoRoot $gitSrc) `
            'a script in a WORKTREE of the repo is allowed -- it is the same repository, not a snapshot'

        # And the half that must not have changed: a separate clone of the same repo is a different
        # repository, answers with its own --git-common-dir, and is still refused.
        $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("guard-clone-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
        $fixtures += $clone
        Invoke-FixtureGitJudged @('clone', '--quiet', $gitSrc, $clone)
        $cloneScript = Join-Path $clone 'scripts\task\park-branch.ps1'
        Assert-True (Test-Path -LiteralPath $cloneScript) 'the clone carries the script too -- the two shapes are indistinguishable on disk'
        Assert-Equal 'scripts\task\park-branch.ps1' (Get-OwnCopyPath -ScriptPath $cloneScript -RepoRoot $gitSrc) `
            'a CLONE is still refused -- which is the released mirror this guard exists for'

        # The identity helper on its own terms, so a failure above can be told apart from a failure here.
        Assert-Equal (Get-GuardGitCommonDir -Path $gitSrc) (Get-GuardGitCommonDir -Path $lane) `
            'the repo and its worktree report the same shared .git'
        Assert-True ((Get-GuardGitCommonDir -Path $clone) -ne (Get-GuardGitCommonDir -Path $gitSrc)) `
            'and a clone reports a different one'
        Assert-Equal $null (Get-GuardGitCommonDir -Path $cache) `
            'a path in no git repository answers $null, which reads as "cannot tell" and keeps the guard refusing'

        # Leave no worktree registered behind: the fixture directory is deleted in the finally block, and a
        # stale registration would make later `git worktree` calls in the fixture repo complain.
        Invoke-FixtureGitJudged @('-C', $gitSrc, 'worktree', 'remove', '--force', $lane)
    }
}
finally {
    foreach ($d in $fixtures) {
        if ($d -and (Test-Path -LiteralPath $d)) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- COVERAGE: the guard is WIRED IN, not merely correct ------------------------------------------------
# EVERYTHING ABOVE TESTS WHETHER THE GUARD DECIDES CORRECTLY. Nothing tested whether it is actually
# CALLED, and that is the half that went wrong. Measured August 26, 2026 while repairing the stale
# tallies of issue #897: scripts/README.md claimed "fourteen of the sixteen shared entry points now
# refuse outright" and named two exceptions with a sound reason -- both are SessionStart hooks, invoked
# from the plugin by design, so refusing there would fail every session start in this repo. The real
# figures were 20 of 23, and the third absentee was scripts/maintenance/measure-always-on.ps1, which is
# no such hook. Its own skill page prints '${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1'
# and then says to run the local copy instead -- precisely the shape the guard exists for. A gap, not an
# exception, almost certainly missed when that script joined the registry the day before.
#
# WHY A TEST AND NOT A PROSE COUNT. The claim it replaces was a hand-typed ratio over a registry that can
# be asked, in a page nothing checks -- so it was wrong when written and would be wrong again after the
# next entry point. This assert derives the set from Get-SharedScriptPairs, so a new entry point is held
# to the rule on the day it is registered rather than on the day somebody re-counts.
#
# THE EXCEPTION LIST IS NAMED HERE AND NOWHERE ELSE, and it is deliberately short. Adding to it is a
# decision that has to be argued in this file, which is the property the README could never have: a page
# can go stale in silence, a failing assert cannot.
. (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')

# THE EXEMPTIONS ARE ALL HOOK-INVOKED, and that is the only reason ever accepted here: the harness runs
# these from the plugin against the current repo, so a refusal would fire on every session start -- or,
# for a Stop hook, on every turn -- in the repo that maintains them. The reason is specific to being a
# hook and does not extend to a script somebody runs.
#
# TWO OF THE FIVE WERE NEVER DECLARED (issue #1321), and that was not a lapse of judgement: the coverage
# check below used to be a text match over the whole file, which both of them satisfied with a COMMENT
# naming the lib -- in each case a comment explaining why the guard was deliberately left out. The assert
# never fired, so nobody ever had to argue the exemption, which is exactly the outcome the paragraph above
# calls impossible. Their code was right all along; only this bookkeeping was missing.
#
# check-git-identity.ps1 IS THE CONTROL CASE, and it is worth keeping the pairing on the record: it joined
# this list on September 3, 2026 (issue #1315) on exactly the same reason -- git-identity-sessioncheck.ps1
# runs it from '${CLAUDE_PLUGIN_ROOT}/scripts/lint/', the released copy, so Assert-OwnCopy would refuse it
# and thereby the hook at every session start here. It has no second caller: no CI half, deliberately,
# because a runner acts and commits as a bot and would report a mismatch on every push. What made it the
# control is that its "no guard" comment does not happen to name the lib, so the old text match DID fire
# on it and its exemption was argued here the way this block intends. Same reason, opposite outcome,
# decided by comment wording alone -- which is how #1321 was found.
$guardExempt = @(
    'scripts\sync\check-roster-sync.ps1',      # SessionStart: roster-sessioncheck
    'scripts\sync\check-script-contract.ps1',  # SessionStart: script-contract-sessioncheck
    'scripts\lint\check-git-identity.ps1',     # SessionStart: git-identity-sessioncheck (#1315)
    'scripts\lint\check-unfolded-entry.ps1',   # SessionStart: unfolded-entry-sessioncheck (#1270)
    # SessionStart: consumer-prose-sessioncheck (#1389 + #1415, merged by #1421). Same reason as the four
    # above, and it carries the answer the guard could not give it: what this repo needs here is not a
    # REFUSAL but a SKIP, and the check makes that decision itself on the guard's own condition 2 (a
    # .claude-plugin/marketplace.json exists). Refusing would take the hook down at every session start
    # here; skipping states the right thing.
    # THE SKIP MEANS SOMETHING DIFFERENT PER DETECTOR, which is worth stating rather than inheriting, and
    # is one of the things that drifted while this was two exemptions: for the retired-name half it is a
    # REPAIR (this repo's pages narrate the rename history and would read as consumer drift), while for
    # the supremacy half it is only a GUARD -- measured on the day it was written, this repo's own
    # always-on pages produce zero hits, because every supremacy sentence they carry names the plugin's
    # page as the winner and the detector reads direction.
    'scripts\lint\check-consumer-prose.ps1',
    # SessionStart: claude-home-sessioncheck (#1609). Same first reason as check-git-identity above --
    # the hook runs it from '${CLAUDE_PLUGIN_ROOT}/scripts/lint/', so Assert-OwnCopy would refuse it and
    # thereby the hook at every session start here -- and it has no second caller either: no CI half,
    # because a runner has no plugin administration at all and would report the empty state on every push.
    #
    # IT IS THE ONE EXEMPTION ON THIS LIST WHERE THE GUARD WOULD BE MEANINGLESS RATHER THAN MERELY
    # INCONVENIENT, and that is worth stating rather than inheriting the reason above. Every other script
    # here reads the REPO, so a released copy genuinely can answer a stale question about this tree --
    # which is the staleness the guard exists to refuse. This one reads one file in the user's HOME and
    # nothing repo-relative at all, so the released copy and this one are not merely both acceptable:
    # they compute the identical answer. There is no version of this script whose age can make it wrong.
    'scripts\lint\check-claude-home.ps1',
    'scripts\task\park-cycle.ps1'              # Stop: cycle-autopark (#900)
)

$entryPoints = @(Get-SharedScriptPairs -RepoRoot $RepoRoot |
    Where-Object { -not $_.LibOnly } |
    Select-Object -ExpandProperty SourceRel -Unique)

Assert-True ($entryPoints.Count -gt 0) `
    'coverage: the registry yields entry points at all -- an empty set would pass every assert below while checking nothing'

function Get-GuardWiringGap {
    <#
        What a file is MISSING in order to be guarded, read from its PARSED SYNTAX rather than its text.
        Returns an empty string when nothing is missing.

        A TEXT MATCH CANNOT ANSWER THIS (issue #1321). The check here was a whole-file `-notmatch` on the
        lib's name, so any COMMENT naming the lib counted as having the guard -- including a comment
        explaining why the guard was deliberately left out. It could not tell "loads the guard" from
        "talks about the guard", which made the assert weaker than it reads for EVERY entry point, not
        only for the two that happened to pass on prose. The parser hands back commands and string
        literals and never comments, so the same wording buys nothing here. It is also the preference the
        lint gate already applies in check 18: for this class of mistake, parse rather than grep.

        BOTH HALVES, BECAUSE EACH IS A REAL MISTAKE ON ITS OWN. A lib loaded and never called is a guard
        that cannot fire -- the very "correct but not wired in" shape this whole coverage block was added
        for (#897) -- and a call with no lib behind it is a crash on the first run. So the gap names which
        half is absent instead of reporting a bare no.

        THE LIB IS LOOKED FOR IN A STRING LITERAL, not in the dot-source's own extent, because every
        guarded script loads it through a variable: a Join-Path onto '..\lib\source-repo-guard-lib.ps1'
        assigned to $guardLib, then `. $guardLib`. Anchoring on the dot-source would report all twenty
        guarded scripts as unguarded, and resolving the variable would be a data-flow analysis to prove
        what the literal already says.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

    $namesLib = [bool](@($ast.FindAll({ param($n)
                    ($n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                     $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and
                    $n.Extent.Text -match 'source-repo-guard-lib'
                }, $true)).Count)

    $callsGuard = [bool](@($ast.FindAll({ param($n)
                    $n -is [System.Management.Automation.Language.CommandAst] -and
                    $n.GetCommandName() -eq 'Assert-OwnCopy'
                }, $true)).Count)

    $missing = @()
    if (-not $namesLib)   { $missing += 'never names the lib outside a comment' }
    if (-not $callsGuard) { $missing += 'never calls Assert-OwnCopy' }
    return ($missing -join ', and it ')
}

function New-MatcherFixture {
    # A one-file scratch script for the asserts below. $PID for the same reason New-Tree carries it: the
    # test gate runs suites in parallel, and two runs sharing a fixed path delete each other's file.
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Body)
    $p = Join-Path ([System.IO.Path]::GetTempPath()) ("srguard-$PID-matcher-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.ps1')
    Set-Content -LiteralPath $p -Value $Body -Encoding UTF8
    return $p
}

# THE MATCHER IS ITSELF HELD TO CATCHING #1321, and it has to be, because no real file exercises the
# comment case any more: all five scripts that would are skipped as exempt before the matcher is reached.
# So a regression back into a text match would leave the suite green and silent -- which is precisely how
# the defect survived the first time. These three run BEFORE the coverage assert on purpose: a broken
# matcher makes that assert's verdict meaningless in either direction.
Write-Host 'The wiring matcher tells loading the guard apart from talking about it (#1321)' -ForegroundColor Cyan
$matcherFixtures = @()
try {
    # The measured shape: check-unfolded-entry.ps1's line 60, prose naming the lib.
    $commentOnly = New-MatcherFixture -Label 'comment' -Body @'
# NO SOURCE-REPO GUARD, deliberately, and for the reason source-repo-guard-lib.ps1's own header gives.
Write-Host 'the work this script actually does'
'@
    $matcherFixtures += $commentOnly
    Assert-True ((Get-GuardWiringGap -Path $commentOnly) -ne '') `
        'the matcher: a COMMENT naming the lib is NOT the guard -- the whole-file text match said it was'

    # The shape all twenty guarded entry points use. It must pass, or the repair reports the whole repo.
    $wired = New-MatcherFixture -Label 'wired' -Body @'
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }
'@
    $matcherFixtures += $wired
    Assert-Equal '' (Get-GuardWiringGap -Path $wired) `
        'the matcher: the real two-line shape passes, loaded through a variable as every guarded script loads it'

    # Loaded and never fired -- the other thing the old check could not tell from being guarded.
    $loadedNotFired = New-MatcherFixture -Label 'halfway' -Body @'
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib }
'@
    $matcherFixtures += $loadedNotFired
    Assert-True ((Get-GuardWiringGap -Path $loadedNotFired) -match 'Assert-OwnCopy') `
        'the matcher: a guard loaded but never called is reported, and the gap names that half'
}
finally {
    foreach ($f in $matcherFixtures) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}

$missingGuard = @()
foreach ($ep in $entryPoints) {
    if ($guardExempt -contains $ep) { continue }
    $epPath = Join-Path $RepoRoot $ep
    if (-not (Test-Path -LiteralPath $epPath -PathType Leaf)) {
        $missingGuard += "$ep (registered but absent from the tree)"
        continue
    }
    $gap = Get-GuardWiringGap -Path $epPath
    if ($gap) { $missingGuard += "$ep ($gap)" }
}
Assert-True ($missingGuard.Count -eq 0) `
    "coverage: every shared entry point loads the guard AND calls it, except the named hook scripts$(if ($missingGuard.Count) { ' -- NOT WIRED IN: ' + ($missingGuard -join '; ') })"

# AND THE EXEMPTIONS ARE HELD TO BEING REAL. An exemption for a script that no longer exists, or that has
# since gained the guard, is a licence nobody is using -- and the next reader would take it as evidence
# that the entry is still needed. Same reasoning as the checks in the lint gate that refuse to carry a
# stale exclusion.
#
# THE SECOND HALF OF THAT SENTENCE WAS ASSERTED NOWHERE until #1321. The loop checked that an exempted
# file exists and is registered, and never that it still lacks the guard -- so the one claim needing a
# measurement was the one the block only stated. Get-GuardWiringGap makes it a single line, so the
# paragraph above is now true rather than aspirational.
foreach ($ex in $guardExempt) {
    $exPath = Join-Path $RepoRoot $ex
    Assert-True (Test-Path -LiteralPath $exPath -PathType Leaf) `
        "coverage: the exemption for $ex names a file that exists"
    Assert-True ($entryPoints -contains $ex) `
        "coverage: the exemption for $ex names a registered entry point, so it is exempting something real"
    if (Test-Path -LiteralPath $exPath -PathType Leaf) {
        Assert-True ((Get-GuardWiringGap -Path $exPath) -ne '') `
            "coverage: the exemption for $ex is still needed -- a script that has since gained the guard needs no licence"
    }
}

Write-Host ''
# ABOVE THE VERDICT AND EVEN ON A GREEN RUN: judging the fixture's git calls buys nothing unless the
# count reaches the exit code, and this suite's worktree and clone cases are exactly the ones whose
# absence reads as a passing assert (issue #1635).
$fixtureBroken = Write-FixtureGitSummary -Subject 'the source-repo guard'
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
