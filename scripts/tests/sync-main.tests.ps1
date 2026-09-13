<#
.SYNOPSIS
    Regression tests for scripts/task/sync-main.ps1 -- dkj-subagents-shopify's pre-task sync (inbound #787,
    rewritten for the content rule on inbound #807).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell and git.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/sync-main.tests.ps1

    THE SUBJECT IS THE REFUSALS AND THE VERDICTS. The rules themselves are covered by
    scripts/tests/sync-rules.tests.ps1, against each query directly. What this suite drives is the script
    around them -- every path where it declines to run, and every path where it decides who wins a file --
    because each one exists to stop the same failure: a sync that proceeds on an assumption and silently
    reverts somebody's merged work. A refusal that regresses into a shrug does not break a test anywhere
    else; it just quietly starts losing work.

    THE HEADLINE CASE IS 'ours/buried'. It is the whole reason the rule moved from time to content: the
    trunk changed a file, a later sync commit buried that change below the floor, and live still holds the
    trunk's OLD copy. The time rule reports "the trunk has not touched this since the floor" and hands
    live's older content back -- forever, on every future run. The content rule recognises live's bytes as
    ours and holds the file back. If that assert ever flips, the sync has gone back to losing merged work.

    WHAT IS DELIBERATELY NOT TESTED HERE, stated rather than left as a gap:

      * The Shopify pull. It needs a store, credentials and a network, so every case passes -MirrorPath
        and stands in for live with a directory of its own. The pull is one line; every line after it is
        what these cases exercise.
      * The PR and the merge, which need a 'gh' that talks to GitHub. The seam defaults to not merging, so
        these cases never enter that branch.
      * The push is not ASSERTED, though it does run: the fixture's origin is a local bare repo, so the
        drift case genuinely pushes a sync branch into it. An assert on that would prove git can write to
        a directory, which is not a claim about this script.

    So the coverage boundary is honest: everything from "which paths differ" through "what happens to
    each one" is measured, and the network half is not.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary, and two runs sharing one fixed temp path tear down each other's tree
    mid-assert.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\sync-main.ps1'

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1622, moved to a shared source by #1635. This
# file is where the rule was first written, inline; sixteen sibling suites turned out to need the same
# forty lines, so the counter, the printer and the summary now live in one place and this suite reads
# them like every other. See the lib for why an unjudged fixture command is worse than an unjudged
# production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

$script:pass = 0
$script:fail = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Invoke-Git {
    <#
        Every fixture MUTATION in this file goes through here -- init, config, checkout, add, commit,
        remote add, push -- so what this function does with a failure is what the whole suite does.

        THE EAP IS LOWERED because git writes ordinary progress to stderr, and under EAP=Stop that is a
        terminating NativeCommandError. That much was always right.

        WHAT WAS NOT: IT DISCARDED THE EXIT CODE AS WELL (issue #1622). The body was one line --
        `& git @args 2>$null | Out-Null` -- so a git command that FAILED was indistinguishable from one
        that worked. A fixture then half-built, and the cases that read the run's output failed in a
        block while the ones that read the disk stayed green, with no error text anywhere to say why.

        THAT IS THE SHAPE #1622 REPORTED: this suite red once under the 16-lane gate, green standalone,
        and no evidence left to read. The report offered two causes and neither survives -- the `net:`
        cases are static scans of the script's source and the one that runs points at a local
        `no-such-origin.git`, so the suite reaches no network at all; and fixture roots carry `$PID` AND
        six hex of a GUID while gate lanes are separate processes, so a path collision needs the PIDs to
        match first. What IS different under thirty lanes is dozens of concurrent `git` processes over
        one temp tree, where a transient index.lock sharing violation, a scanner holding a file, or disk
        pressure is ordinary rather than rare -- and this function was built to say nothing about any of
        them.

        SO THE EXIT CODE IS JUDGED AND git's OWN STDERR IS PRINTED, and the failure is counted so the
        summary can say the asserts below are not a verdict on the script. It does NOT throw: a suite
        that dies at the first fixture hiccup reports less than one that runs on and names what broke,
        and the count at the end is what makes the difference impossible to miss.

        `2>&1` RATHER THAN `2>$null`, which is the same call worktree-lane.tests.ps1's own Invoke-Git
        already makes: under Windows PowerShell 5.1 that wraps each stderr line in an ErrorRecord, which
        is harmless at EAP=Continue and is why the redirect is inside the try. `$LASTEXITCODE` is
        unaffected by it -- it is `$?` that the wrapping disturbs, and nothing here reads `$?`.

        THE JUDGING ITSELF NOW COMES FROM scripts/lib/fixture-git-lib.ps1 (issue #1635). It was written
        inline here first, and then sixteen sibling suites needed the same forty lines -- so the verdict,
        the counter and the printed block moved to one source and this function kept its own signature.
        Everything above still describes what happens; only the place it is implemented changed.
    #>
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & git @args 2>&1
        Assert-FixtureGitOk -Code $LASTEXITCODE -GitArgs @($args | ForEach-Object { "$_" }) -Output $out
    } finally { $ErrorActionPreference = $prevEap }
}

function Set-FixtureFile {
    <# Writes a file (creating its directory) with the bytes given, LF endings preserved. #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Rel,
        [Parameter(Mandatory = $true)][string]$Value
    )
    $target = Join-Path $Root ($Rel -replace '/', '\')
    $parent = Split-Path -Parent $target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    # WriteAllText rather than Set-Content: the CRLF case needs the bytes it was given, and Set-Content's
    # encoding handling is one more thing between the test and what it claims to assert.
    [System.IO.File]::WriteAllText($target, $Value, (New-Object System.Text.ASCIIEncoding))
}

function New-Consumer {
    <#
        A fixture Shopify consumer: a git repo on 'main' with a local bare origin it can fast-forward
        from, plus a scripts/repo-config.ps1 carrying whichever seam answers the case needs.

        THE ORIGIN IS REAL because the script fast-forwards the trunk before it measures anything, so a
        fixture without one cannot reach the interesting cases at all.

        THE THEME FILE SITS UNDER sections/, NOT AT THE ROOT, and that is not decoration: the script
        compares only the directories a Shopify pull writes, so a fixture file at the root is invisible to
        it -- which would make every verdict assert here vacuously green.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$ThemeId = '',
        [string]$StoreDomain = '',
        [string]$ExtraSeams = ''
    )
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ("syncmain-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $work = Join-Path $base 'work'
    $bare = Join-Path $base 'origin.git'
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    New-Item -ItemType Directory -Path $bare -Force | Out-Null
    $script:trees += $base

    Invoke-Git -C $bare init --bare --quiet
    Invoke-Git -C $work init --quiet
    Invoke-Git -C $work config user.name  'sync-main test'
    Invoke-Git -C $work config user.email 'sync@test.invalid'
    Invoke-Git -C $work config core.autocrlf false
    # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
    Invoke-Git -C $work config commit.gpgsign false
    Invoke-Git -C $work checkout -q -b main

    $seams = @('# fixture repo-config')
    if ($ThemeId)     { $seams += "function Get-ShopifyLiveThemeId { return '$ThemeId' }" }
    if ($StoreDomain) { $seams += "function Get-ShopifyStoreDomain { return '$StoreDomain' }" }
    if ($ExtraSeams)  { $seams += $ExtraSeams }
    New-Item -ItemType Directory -Path (Join-Path $work 'scripts') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $work 'scripts\repo-config.ps1') -Value ($seams -join "`n") -Encoding ascii

    Set-FixtureFile -Root $work -Rel 'sections/theme.liquid' -Value 'v1'
    Invoke-Git -C $work add -A
    Invoke-Git -C $work commit -q -m 'initial'
    Invoke-Git -C $work remote add origin $bare
    Invoke-Git -C $work push -q -u origin main

    return $work
}

function Add-FixtureCommit {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Message,
        [hashtable]$Write = @{},
        [string[]]$Delete = @()
    )
    foreach ($rel in $Write.Keys) { Set-FixtureFile -Root $Dir -Rel $rel -Value $Write[$rel] }
    foreach ($rel in $Delete) {
        $t = Join-Path $Dir ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Force }
    }
    Invoke-Git -C $Dir add -A
    Invoke-Git -C $Dir commit -q -m $Message
    Invoke-Git -C $Dir push -q origin main
}

function Add-PredecessorBranch {
    <#
        A sync branch from an earlier run, pushed to the fixture's origin and then DELETED LOCALLY -- which
        is the state that matters, not a convenience. A predecessor pushed from another machine has no
        local ref at all, and that is exactly the branch the naming loop's refs/remotes/origin/* check
        cannot see; deleting it here makes the case real and exercises the guard's own fetch.

        -MergeIntoTrunk merges it into main first, so the ancestry half of the two-part merged test has a
        subject. The ref is left standing on origin afterwards on purpose: a consumer without
        delete_branch_on_merge keeps it forever, and refusing that consumer's every future run is the
        failure mode of getting this test wrong.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [hashtable]$Files = @{},
        [switch]$MergeIntoTrunk
    )
    Invoke-Git -C $Dir checkout -q -b $Name
    foreach ($rel in $Files.Keys) { Set-FixtureFile -Root $Dir -Rel $rel -Value $Files[$rel] }
    Invoke-Git -C $Dir add -A
    Invoke-Git -C $Dir commit -q -m 'sync: mirror in-flight third-party edits from live (1 file(s))'
    Invoke-Git -C $Dir push -q -u origin $Name
    Invoke-Git -C $Dir checkout -q main
    if ($MergeIntoTrunk) {
        Invoke-Git -C $Dir merge -q --no-edit $Name
        Invoke-Git -C $Dir push -q origin main
    }
    Invoke-Git -C $Dir branch -q -D $Name
}

function New-Mirror {
    <# A stand-in for the live theme: a directory holding whatever live is supposed to have. #>
    param([Parameter(Mandatory = $true)][string]$Label, [hashtable]$Files = @{})
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("syncmirror-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    foreach ($rel in $Files.Keys) { Set-FixtureFile -Root $dir -Rel $rel -Value $Files[$rel] }
    return $dir
}

function Invoke-Sync {
    <# Runs the script in a child process against the fixture. -RootOverride both points it at the
       fixture and bypasses the marketplace refusal, exactly as the adopt-shopify-floor suite uses it. #>
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$Mirror = '', [string[]]$Extra = @())
    if ($Mirror) { $Extra = @('-MirrorPath', $Mirror) + $Extra }
    # The EAP is lowered for the call, and this is the merged-stream pitfall rather than caution: git
    # writes ordinary lines like "Already on 'main'" to stderr, and '2>&1' under EAP=Stop wraps each one
    # in a NativeCommandError that terminates the suite. The redirection is what the assertions read, so
    # it stays and the preference gives way.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Dir @Extra 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

function Invoke-LabelSeamRun {
    <# One drift run against a consumer whose only extra seam is the label one, so every assert in that
       block reads the same printed 'gh pr create' line and differs only in what the seam answered.

       THE DRIFT IS A FILE ONLY LIVE HAS, which is the cheapest shape that reaches the PR step at all --
       a run with nothing to take exits before composing either the body or the labels. #>
    param([Parameter(Mandatory = $true)][string]$Label, [string]$Seam = '')
    $repo = New-Consumer -Label $Label -ThemeId '123456' -StoreDomain 'a-store.myshopify.com' -ExtraSeams $Seam
    Add-FixtureCommit -Dir $repo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    $mir = New-Mirror -Label $Label -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    return (Invoke-Sync -Dir $repo -Mirror $mir)
}

function Get-PrintedCreateLine {
    <# The 'gh pr create' line the non-merging path prints, without the DarkGray notes around it -- those
       mention '--label' too, and an assert reading the whole output would pass on the wrong line. #>
    param([Parameter(Mandatory = $true)][string]$Output)
    if ($Output -match '(gh pr create[^\r\n]*)') { return $Matches[1] }
    return ''
}

try {
    # --- The seam refusals, both before anything is touched -----------------------------------------
    Write-Host 'the seam refusals'

    $noId = New-Consumer -Label 'noid' -StoreDomain 'a-store.myshopify.com'
    $r = Invoke-Sync -Dir $noId
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'Get-ShopifyLiveThemeId') 'seam/no-id: an unanswered theme id refuses, naming the seam'

    # A PLACEHOLDER IS NOT AN ANSWER. The same rule the guard applies, and the reason is the same: a
    # 'VUL-IN' left behind reads as answered to anything testing for emptiness.
    $vulIn = New-Consumer -Label 'vulin' -ThemeId 'VUL-IN' -StoreDomain 'a-store.myshopify.com'
    $r = Invoke-Sync -Dir $vulIn
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'does not answer with a theme id') 'seam/placeholder: a non-numeric id counts as no answer'

    $noStore = New-Consumer -Label 'nostore' -ThemeId '123456'
    $r = Invoke-Sync -Dir $noStore
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'Get-ShopifyStoreDomain') 'seam/no-store: an unanswered store refuses rather than guessing'
    $r = Invoke-Sync -Dir $noStore -Extra @('-Store', 'given.myshopify.com')
    Assert-True ($r.Out -notmatch 'Get-ShopifyStoreDomain is unanswered') 'seam/no-store: -Store gets past it for one run'

    # --- The retired switch ------------------------------------------------------------------------
    # -SkipPull meant "run the rule over the working tree", which cannot mean anything now that the pull
    # goes to a mirror. It is accepted purely so the refusal can name what replaced it, instead of leaving
    # a consumer with PowerShell's own "cannot find a parameter named" and no route forward.
    Write-Host ''
    Write-Host 'the retired -SkipPull switch'
    $r = Invoke-Sync -Dir $noStore -Extra @('-SkipPull')
    Assert-True ($r.Code -eq 1 -and $r.Out -match '-DryRun') 'retired/skippull: it refuses by name and points at -DryRun and -MirrorPath'
    Assert-True ($r.Out -match 'Nothing was changed') 'retired/skippull: and says nothing was changed'

    # --- The dirty tree ----------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'the working-tree refusal'
    $dirty = New-Consumer -Label 'dirty' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Set-FixtureFile -Root $dirty -Rel 'sections/mine.liquid' -Value 'work in progress'
    $dirtyMirror = New-Mirror -Label 'dirty' -Files @{ 'sections/theme.liquid' = 'v1' }
    $r = Invoke-Sync -Dir $dirty -Mirror $dirtyMirror
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'not clean') 'dirty: uncommitted work refuses -- it would be committed as third-party drift'
    Assert-True (Test-Path -LiteralPath (Join-Path $dirty 'sections\mine.liquid')) 'dirty: and the uncommitted file is still there'
    # AND THE ONE CASE WHERE A DIRTY TREE IS THE INPUT. -DryRun writes nothing at all, so a dirty tree is
    # exactly when somebody wants to ask what the sync would do to it -- refusing there would make the
    # check unavailable at the one moment it is worth running.
    $r = Invoke-Sync -Dir $dirty -Mirror $dirtyMirror -Extra @('-DryRun')
    Assert-True ($r.Out -notmatch 'not clean') 'dirty: -DryRun does not refuse on a dirty tree'
    Assert-True ($r.Out -match 'DRY RUN') 'dirty: and says so, so nobody reads it as a real run'

    # --- No reference point ------------------------------------------------------------------------
    # It no longer decides who wins a file, but it is what notices that BOTH sides moved -- and without
    # it such a conflict would be taken silently, which is the failure this refusal exists for.
    Write-Host ''
    Write-Host 'the reference-point refusal'
    $bare = New-Consumer -Label 'noref' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    $bareMirror = New-Mirror -Label 'noref' -Files @{ 'sections/theme.liquid' = 'v1' }
    $r = Invoke-Sync -Dir $bare -Mirror $bareMirror
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'No reference point') 'noref: no sync commit and no tag refuses'
    Assert-True ($r.Out -match 'sync by hand|Tag the current state') 'noref: and says what to do instead'

    # --- The content rule, end to end --------------------------------------------------------------
    Write-Host ''
    Write-Host 'the content rule, driven through the script'
    $live = New-Consumer -Label 'live' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    # THE ACCENTED PATH IS A PIN, NOT DECORATION, AND IT HAS CAUGHT THE SAME BUG TWICE. A path with a byte
    # above 0x7F has to survive the trip from git into a hashtable key, and both failures put it there in a
    # form the mirror walk never produces -- after which the trunk's copy reads as a path live does not
    # have while live's IDENTICAL file reads as content the trunk has never held: foreign, taken, trunk
    # overwritten.
    #   1. git's default QUOTING -- '"assets/caf\303\251.js"' -- fixed by core.quotePath=false;
    #   2. which put raw UTF-8 bytes on the wire, decoded by the inherited console code page (inbound #821):
    #      right in a UTF-8 terminal, wrong on cp850, so the answer depended on who launched the run.
    # Now the wire is quoted ON PURPOSE and Convert-GitQuotedPath unpacks it, so this case is green at
    # cp850, cp1252 and cp65001 alike -- measured, because for one commit it was green under the test gate
    # and red standalone, and the gate was the run that was wrong.
    # The name is built from a code point because this layer is ASCII (repo convention), which
    # is the same reason the scaffolder writes its middle dot as [char]0x00B7.
    $accented = 'sections/caf' + [char]0x00E9 + '.liquid'
    $floorFiles = @{
        'sections/editor.liquid'  = 'e1'
        'sections/dropped.liquid' = 'was here once'
        'sections/crlf.liquid'    = "a`nb"
    }
    $floorFiles[$accented] = 'an accented filename, identical on both sides'
    Add-FixtureCommit -Dir $live -Message 'sync: the first floor' -Write $floorFiles
    # Trunk work: one file changed, one deleted, one added that live has never seen.
    Add-FixtureCommit -Dir $live -Message 'fix: the trunk changes a file' -Write @{ 'sections/theme.liquid' = 'trunk-v2' }
    Add-FixtureCommit -Dir $live -Message 'chore: the trunk drops a file'  -Delete @('sections/dropped.liquid')
    Add-FixtureCommit -Dir $live -Message 'feat: a file only the trunk has' -Write @{ 'sections/only-trunk.liquid' = 'not live yet' }
    # AND THEN A LATER SYNC, which is what buries all of that below the floor. This is the state the time
    # rule cannot survive: from here on it reports every one of those paths as untouched-since.
    Add-FixtureCommit -Dir $live -Message 'sync: a later sync that buries the trunk work' -Write @{ 'sections/unrelated.liquid' = 'u1' }

    $liveMirror = New-Mirror -Label 'live' -Files @{
        # live still holds the trunk's OLD copy of a file the trunk has since fixed -- ours, so held back.
        'sections/theme.liquid'     = 'v1'
        # live still holds a file the trunk deliberately deleted -- ours, so NOT resurrected.
        'sections/dropped.liquid'   = 'was here once'
        # a third party edited this one in the theme editor -- foreign, and the trunk has not touched it.
        'sections/editor.liquid'    = 'a third party wrote this'
        # a file only live has, that this repo has never held -- foreign, so taken.
        'sections/brand-new.liquid' = 'made in the theme editor'
        # the same text with CRLF endings: a line-ending difference is not drift.
        'sections/crlf.liquid'      = "a`r`nb"
        'sections/unrelated.liquid' = 'u1'
    }
    Set-FixtureFile -Root $liveMirror -Rel $accented -Value 'an accented filename, identical on both sides'

    $r = Invoke-Sync -Dir $live -Mirror $liveMirror
    Assert-True ($r.Out -match 'sections/theme\.liquid\s+live holds a version this repo has had before') 'ours/buried: live''s older copy of OUR file is held back, though the floor no longer covers it'
    Assert-True ($r.Out -match 'sections/dropped\.liquid\s+the trunk deleted this file') 'ours/deleted: a file the trunk deleted is NOT resurrected from live'
    Assert-True ($r.Out -match 'sections/only-trunk\.liquid\s+only the trunk has this file') 'never-deletes: a file live does not have is kept and reported, never deleted'
    Assert-True ($r.Out -match 'sections/editor\.liquid\s+content this repo has never held') 'foreign/changed: a third party''s edit to an untouched file is taken'
    Assert-True ($r.Out -match 'sections/brand-new\.liquid\s+content this repo has never held') 'foreign/added: a file only live has and we never held is taken'
    Assert-True ($r.Out -notmatch 'sections/crlf\.liquid') 'crlf: a line-ending-only difference is not a difference at all'
    # THE NEEDLE CARRIES ITS PATH PREFIX, and that is the whole of inbound #1117 (August 29, 2026).
    # It read `-notmatch 'caf'` and went red under the CI gate on PR #1105 -- a branch byte-identical
    # to the trunk in both this suite and the script it tests, green locally, green on the trunk 16
    # minutes later, and the only CI failure in 30 runs. It was filed as a possible second axis behind
    # #821 (a git path decoded off the console code page) and it is not that at all.
    #
    # WHAT IT ACTUALLY WAS: `c`, `a` and `f` are all hex digits, and the fixtures are named
    # `syncmain-<pid>-<label>-<six hex chars>` from a GUID. The run PRINTS those paths --
    # "using the mirror given: ...\Temp\syncmirror-32348-live-caf123" -- so roughly one run in 500
    # spells the needle in a directory name and fails an assert about a file it never touched.
    # Reproduced by forcing the suffix to 'caf123': `FAILED: 1 of 80 asserts.`, the same one, which is
    # also why the sibling `drift on 2 file(s)` assert stayed green in the CI run -- nothing was ever
    # miscounted as drift. Measured over 2,000,000 random six-hex names: 0.0968% contain 'caf', and
    # two such names are printed per run, so 0.194% -- one in 517.
    #
    # THE TAIL IS STILL TRUNCATED ON PURPOSE. Matching the full `sections/caf<e9>.liquid` would defeat
    # the assert: mojibake is what it is looking for, and mojibake lands in exactly the bytes the full
    # name would pin. So the needle keeps its short tail and gains the one prefix that makes it name a
    # path in the report rather than three characters anywhere in a temp directory.
    #
    # AND THE FIXTURE SUFFIX IS DELIBERATELY LEFT ALONE. Making it digits-only would kill 'caf' and
    # open the same door to a digit needle -- this tree already has `-notmatch '2099'` and
    # `-notmatch '332340'` (neither at risk today: one suite has no GUID, the other's tag does not
    # reach the haystack). A random suffix is legitimately random; asserting on a three-character
    # substring of a whole run's output was the defect.
    Assert-True ($r.Out -notmatch 'sections/caf') 'quotepath: a path with a non-ASCII byte is compared, not read as a new file'
    Assert-True ($r.Out -match 'drift on 2 file\(s\)') 'take: exactly the two foreign files go into the sync'
    # THE MIRROR MODEL'S OWN GUARANTEE: a held-back file is never written, so it cannot be damaged by a
    # rule that got it wrong or by a failure halfway. The wholesale version overwrote first and restored
    # afterwards, so every bug in the rule was a bug that had already happened.
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $live 'sections\theme.liquid')) -eq 'trunk-v2') 'ours/buried: the trunk''s version is still the one on disk'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $live 'sections\dropped.liquid'))) 'ours/deleted: and the deleted file was never written back'
    Assert-True (Test-Path -LiteralPath (Join-Path $live 'sections\brand-new.liquid')) 'take: the taken file IS written'

    # --- The PR body on the non-merging path -------------------------------------------------------
    # THE PATH THAT USED TO COMPOSE NO BODY AT ALL (inbound #1000). It is also the DEFAULT path -- the
    # seam that merges is opt-in -- so the repo with no body was the common one, not the edge.
    $bodyFile = ''
    if ($r.Out -match '--body-file "([^"]+)"') { $bodyFile = $Matches[1]; $script:trees += $bodyFile }
    Assert-True ($bodyFile -and (Test-Path -LiteralPath $bodyFile)) 'body/file: the non-merging path writes the body and hands over its path'
    $prBody = if ($bodyFile -and (Test-Path -LiteralPath $bodyFile)) { [System.IO.File]::ReadAllText($bodyFile) } else { '' }
    Assert-True ($prBody -match 'new on live -- .sections/brand-new\.liquid.') 'body/take: what was taken is in the body, with its kind'
    Assert-True ($prBody -match 'gone from live -- .sections/only-trunk\.liquid.') 'body/keep: and a path live no longer has is reported as GONE, not as a bare filename'
    Assert-True ($prBody -match 'changed on live -- .sections/theme\.liquid.') 'body/keep: a held-back edit keeps its own kind too'

    # --- The body seam: a consumer whose review policy IS the PR body ------------------------------
    Write-Host ''
    Write-Host 'the PR body seam'
    $seamSrc = @(
        'function Get-ShopifySyncPrBody {',
        '    param($Take, $Keep, $Default)',
        '    return "SEAM-TEMPLATE take=$($Take.Count) keep=$($Keep.Count)" + [Environment]::NewLine + $Default',
        '}'
    ) -join "`n"
    $seamRepo = New-Consumer -Label 'bodyseam' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com' -ExtraSeams $seamSrc
    Add-FixtureCommit -Dir $seamRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    $seamMirror = New-Mirror -Label 'bodyseam' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $r = Invoke-Sync -Dir $seamRepo -Mirror $seamMirror
    Assert-True ($r.Out -match 'composed by Get-ShopifySyncPrBody') 'seam/body: an answered seam is used, and the run says so'
    $seamFile = ''
    if ($r.Out -match '--body-file "([^"]+)"') { $seamFile = $Matches[1]; $script:trees += $seamFile }
    $seamBody = if ($seamFile -and (Test-Path -LiteralPath $seamFile)) { [System.IO.File]::ReadAllText($seamFile) } else { '' }
    Assert-True ($seamBody -match '^SEAM-TEMPLATE') 'seam/body: the consumer''s own wording is what the PR gets'
    # THE ROWS THEMSELVES REACH IT TOO, and that is what this asserts rather than -Default alone: a seam is
    # handed the classified data so it can order, filter or count it, and passing an array through a
    # scriptblock's $args is exactly where one silently arrives unwrapped.
    Assert-True ($seamBody -match 'take=1 keep=0') 'seam/body: -Take and -Keep arrive as the arrays they are, not unwrapped'
    # -Default is the half that makes the seam cheap to answer: a consumer wraps the composed body rather
    # than rebuilding it, so it keeps every kind and reason without knowing how they are spelled.
    Assert-True ($seamBody -match 'new on live -- .sections/from-editor\.liquid.') 'seam/body: and -Default carries the composed body into it'

    # A SEAM THAT THROWS IS REPORTED, NOT SWALLOWED. Every other seam here degrades silently because its
    # default is a correct answer; this one means the consumer asked for a specific record and got the
    # generic one -- which is the failure #1000 was filed about, so it says so on the run.
    $badRepo = New-Consumer -Label 'bodythrow' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com' `
        -ExtraSeams 'function Get-ShopifySyncPrBody { param($Take, $Keep, $Default) throw ''no body today'' }'
    Add-FixtureCommit -Dir $badRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    $badMirror = New-Mirror -Label 'bodythrow' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $r = Invoke-Sync -Dir $badRepo -Mirror $badMirror
    Assert-True ($r.Code -eq 0) 'seam/throw: a broken body seam costs the custom body, never the sync'
    Assert-True ($r.Out -match 'Get-ShopifySyncPrBody threw' -and $r.Out -match 'no body today') 'seam/throw: and it is reported by name, with the fault'
    $badFile = ''
    if ($r.Out -match '--body-file "([^"]+)"') { $badFile = $Matches[1]; $script:trees += $badFile }
    $badBody = if ($badFile -and (Test-Path -LiteralPath $badFile)) { [System.IO.File]::ReadAllText($badFile) } else { '' }
    Assert-True ($badBody -match 'new on live -- .sections/from-editor\.liquid.') 'seam/throw: the default body is written instead'

    # --- The label seam: the PR ROUTE rather than the body (inbound #1023) -------------------------
    # ASSERTED ON THE PRINTED LINE, and that is a property of the suite rather than a shortcut. The
    # merging path needs a 'gh' that talks to GitHub, which this suite deliberately does not have -- but
    # the printed line is composed from the SAME list in the same place, so what it carries is what the
    # create would carry. It is also the path most consumers run, the merge seam being opt-in.
    Write-Host ''
    Write-Host 'the PR label seam'

    $r = Invoke-LabelSeamRun -Label 'nolabel'
    $line = Get-PrintedCreateLine -Output $r.Out
    Assert-True ($line -ne '') 'seam/labels: the unanswered case still prints the create line'
    Assert-True ($line -notmatch '--label') 'seam/labels: and carries no --label, which is the default and the behaviour before #1023'
    Assert-True ($r.Out -notmatch 'Get-ShopifySyncPrLabels') 'seam/labels: an unanswered seam is silent, not reported as missing'

    # A BARE STRING IS ACCEPTED, and this is the assert that matters most for a config file: 'return "sync"'
    # is what somebody writes first, and the @() around the pipeline is what keeps that one label a label
    # rather than four characters PowerShell iterates over.
    $r = Invoke-LabelSeamRun -Label 'onelabel' -Seam "function Get-ShopifySyncPrLabels { return 'sync' }"
    $line = Get-PrintedCreateLine -Output $r.Out
    Assert-True ($line -match '--label "sync"') 'seam/labels: a bare string arrives as one label on the printed line'
    Assert-True (([regex]::Matches($line, '--label')).Count -eq 1) 'seam/labels: exactly one --label, not one per character'
    Assert-True ($r.Out -match 'Get-ShopifySyncPrLabels: sync') 'seam/labels: and the run names what it is going to apply'

    # REPEATED '--label' RATHER THAN ONE COMMA-SEPARATED VALUE, so a label whose own name holds a comma
    # cannot arrive as two.
    $r = Invoke-LabelSeamRun -Label 'twolabels' -Seam "function Get-ShopifySyncPrLabels { return @('sync', 'automated') }"
    $line = Get-PrintedCreateLine -Output $r.Out
    Assert-True (([regex]::Matches($line, '--label')).Count -eq 2) 'seam/labels: an array becomes one --label per entry'
    Assert-True ($line -match '--label "sync".*--label "automated"') 'seam/labels: both of them, in the order the seam answered'

    # A CLEARED PLACEHOLDER READS AS UNANSWERED, the same rule the theme id gets. A blank entry left behind
    # in a config file must not become an empty --label, which gh rejects and which would fail the create
    # for a repo that had answered the seam correctly enough.
    $r = Invoke-LabelSeamRun -Label 'blanklabels' -Seam "function Get-ShopifySyncPrLabels { return @('sync', '', '   ') }"
    $line = Get-PrintedCreateLine -Output $r.Out
    Assert-True (([regex]::Matches($line, '--label')).Count -eq 1) 'seam/labels: blank and whitespace entries are dropped, not passed on'

    # AND A THROWING LABEL SEAM IS REPORTED, which is the body seam's rule above applied to the PR route:
    # the fallback here is not a correct answer but a PR a guardrail repo cannot merge, so it must not be
    # reached quietly.
    $r = Invoke-LabelSeamRun -Label 'labelthrow' -Seam "function Get-ShopifySyncPrLabels { throw 'no labels today' }"
    Assert-True ($r.Code -eq 0) 'seam/labels: a broken label seam costs the label, never the sync'
    Assert-True ($r.Out -match 'Get-ShopifySyncPrLabels threw' -and $r.Out -match 'no labels today') 'seam/labels: and it is reported by name, with the fault'
    $line = Get-PrintedCreateLine -Output $r.Out
    Assert-True ($line -notmatch '--label') 'seam/labels: the line then carries no label it could not compose'

    # --- Both sides moved: a conflict, and nothing written -----------------------------------------
    # The one thing the floor still decides. It can only ever escalate to a human, which is why a wrong
    # floor now costs an extra conflict report instead of silent data loss.
    Write-Host ''
    Write-Host 'the conflict refusal'
    $clash = New-Consumer -Label 'clash' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $clash -Message 'sync: the floor' -Write @{ 'sections/both.liquid' = 'b1' }
    Add-FixtureCommit -Dir $clash -Message 'fix: the trunk changes it too' -Write @{ 'sections/both.liquid' = 'trunk-b2' }
    $clashMirror = New-Mirror -Label 'clash' -Files @{
        'sections/theme.liquid' = 'v1'
        'sections/both.liquid'  = 'a third party changed it as well'
    }
    $r = Invoke-Sync -Dir $clash -Mirror $clashMirror
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'REFUSING TO SYNC') 'conflict: both sides changed one path, so nothing is decided'
    Assert-True ($r.Out -match 'git diff --no-index') 'conflict: and it hands over the command that compares the two'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $clash 'sections\both.liquid')) -eq 'trunk-b2') 'conflict: the trunk''s version is untouched on disk'
    $branchNow = ([string](& git -C $clash rev-parse --abbrev-ref HEAD)).Trim()
    Assert-True ($branchNow -eq 'main') 'conflict: and no sync branch was created'
    # THE REFUSAL NOW SAYS WHAT TO DO WITH THE MERGE, NOT ONLY HOW TO SEE IT (inbound #1945). "Compare
    # them by hand" is complete about the content and silent about the shape, and the shape is where a
    # single reconciliation commit fails -- in one of two ways chosen by nothing but its subject.
    Assert-True ($r.Out -match 'NOT DURABLE, IN EITHER SPELLING') 'conflict: and it warns that one reconciliation commit settles nothing'
    Assert-True ($r.Out -match '-ReconcileBase') 'conflict: and names the switch that writes the durable shape'

    # --- -ReconcileBase: the durable shape, written --------------------------------------------------
    # THE ASSERT THAT MATTERS IS THE LAST ONE: after this branch, the same run that refused reports the
    # path as held back. Everything above it is there because the way this repair fails is by writing a
    # HALF of the pair -- one commit in, the branch holds live's content for those paths, which is the
    # wholesale overwrite the whole script exists to prevent.
    Write-Host ''
    Write-Host 'the reconciliation base'
    $rec = New-Consumer -Label 'recbase' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $rec -Message 'sync: the floor' -Write @{ 'sections/both.liquid' = 'b1' }
    Add-FixtureCommit -Dir $rec -Message 'fix: the trunk changes it too' -Write @{ 'sections/both.liquid' = 'trunk-b2' }
    $recMirror = New-Mirror -Label 'recbase' -Files @{
        'sections/theme.liquid' = 'v1'
        'sections/both.liquid'  = 'a third party changed it as well'
    }

    # A DRY RUN WRITES NOTHING, INCLUDING THIS. The switch is the only write on the refusing path, so the
    # two compose the one way they can -- report and stop.
    $r = Invoke-Sync -Dir $rec -Mirror $recMirror -Extra @('-DryRun', '-ReconcileBase')
    Assert-True ($r.Out -match 'DRY RUN -- -ReconcileBase would put') 'recbase/dry: a dry run reports the base it would write'
    Assert-True ((([string](& git -C $rec rev-parse --abbrev-ref HEAD)).Trim()) -eq 'main') 'recbase/dry: and writes no branch'

    $r = Invoke-Sync -Dir $rec -Mirror $recMirror -Extra @('-ReconcileBase')
    Assert-True ($r.Code -eq 1) 'recbase: the run still refuses -- nothing was taken from live'
    $recBranch = ([string](& git -C $rec rev-parse --abbrev-ref HEAD)).Trim()
    Assert-True ($recBranch -like 'sync/live-*') 'recbase: and it leaves the operator on the sync branch it wrote'
    $subjects = @(& git -C $rec log --format='%s' 'main..HEAD')
    Assert-True ($subjects.Count -eq 2) 'recbase: two commits, not one -- the half-written pair is the way this fails'
    Assert-True ($subjects[1] -match '^sync: live verbatim as the reconciliation base') 'recbase: the first takes live verbatim, spelled as the agreement point it genuinely is'
    Assert-True ($subjects[0] -match '^fix: put the trunk content back') 'recbase: the second puts the trunk content back'
    # NO FILE CHANGES AT ALL, which is what makes merging it safe at every point.
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $rec 'sections\both.liquid')) -eq 'trunk-b2') 'recbase: the trunk''s content is what sits on disk afterwards'
    Assert-True (@(& git -C $rec diff --name-only 'main..HEAD').Where({ $_ }).Count -eq 0) 'recbase: so the branch changes no file against the trunk'

    # AND THE POINT OF ALL OF IT. Merge the pair and re-run the very run that refused: the path is settled
    # by provenance, so it reads as held back rather than as the same conflict or as drift to take.
    # THE BRANCH IS DELETED ON BOTH SIDES BECAUSE THAT IS WHAT MERGING ITS PR DOES. It is a sync branch
    # like any other, so until it lands the standing-predecessor guard refuses the next run by name --
    # correctly, and deliberately not special-cased: a second way for a sync branch to be ignored is the
    # direction that loses work, and that guard's instruction (merge or close it) is already the right one
    # here. Leaving it standing in this fixture is what made the assert below read a DIFFERENT refusal.
    Invoke-Git -C $rec checkout -q main
    Invoke-Git -C $rec merge -q --no-ff -m "merge: $recBranch" $recBranch
    Invoke-Git -C $rec push -q origin --delete $recBranch
    Invoke-Git -C $rec branch -q -D $recBranch
    $r = Invoke-Sync -Dir $rec -Mirror $recMirror
    # 'REFUSING TO SYNC' ALONE IS NOT ENOUGH TO ASSERT, and this is the assert catching itself: the run
    # above refused on the standing predecessor, whose wording is 'Refusing: 1 sync branch(es)', so a
    # notmatch on the conflict banner passed while the run had refused for another reason entirely.
    Assert-True ($r.Out -notmatch 'REFUSING TO SYNC' -and $r.Out -notmatch 'Refusing:') 'recbase: after the merge the same run no longer refuses, for any reason'
    Assert-True ($r.Out -match 'held back .* wins\): 1') 'recbase: the path is held back -- the trunk wins, permanently'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $rec 'sections\both.liquid')) -eq 'trunk-b2') 'recbase: and live never overwrote the trunk on the way through'

    # --- Nothing foreign at all --------------------------------------------------------------------
    Write-Host ''
    Write-Host 'the quiet run'
    $quiet = New-Consumer -Label 'quiet' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $quiet -Message 'sync: the floor' -Write @{ 'sections/floor.liquid' = 'f1' }
    Add-FixtureCommit -Dir $quiet -Message 'fix: the trunk changes a file' -Write @{ 'sections/theme.liquid' = 'trunk-v2' }
    $quietMirror = New-Mirror -Label 'quiet' -Files @{
        'sections/theme.liquid' = 'v1'
        'sections/floor.liquid' = 'f1'
    }
    $r = Invoke-Sync -Dir $quiet -Mirror $quietMirror
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'No third-party drift') 'quiet: everything held back means nothing to sync, and exit 0'
    $status = & git -C $quiet status --porcelain
    Assert-True (-not (@($status | Where-Object { $_ }).Count)) 'quiet: and the tree is left clean, not half-written'

    # --- A gitignored path is not the sync's business ----------------------------------------------
    # config/settings_data.json is the case this exists for: a repo that ignores the live theme's settings
    # would otherwise see it arrive as a brand-new foreign file on every single run and capture it forever.
    # The filter is also where a measured trap sits -- 'check-ignore --stdin <paths>' exits 128 and reports
    # nothing ignored, so this assert is what proves the argument form is the one in use.
    Write-Host ''
    Write-Host 'the gitignore filter'
    $ign = New-Consumer -Label 'ignored' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $ign -Message 'sync: the floor' -Write @{ '.gitignore' = "config/settings_data.json`n" }
    $ignMirror = New-Mirror -Label 'ignored' -Files @{
        'sections/theme.liquid'      = 'v1'
        'config/settings_data.json'  = '{"live":"settings"}'
    }
    $r = Invoke-Sync -Dir $ign -Mirror $ignMirror
    Assert-True ($r.Out -match 'gitignored here and are left alone') 'ignored: the filter reports what it excluded'
    Assert-True ($r.Out -notmatch 'settings_data\.json\s+content this repo has never held') 'ignored: and the ignored file is not captured as drift'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $ign 'config\settings_data.json'))) 'ignored: nor written into the repo'

    # --- the standing-predecessor guard (inbound #1021) ---------------------------------------------
    # WHAT THESE CASES PROTECT is the one failure in this script that produced no error at all: four sync
    # branches in seven days, each run green, the newest a strict superset of the three before it. The
    # rules in sync-rules.ps1 were correct throughout -- so nothing here re-tests them. What is measured
    # is the SCRIPT's behaviour around the answer: that it refuses, that the refusal lands before the
    # pull, that a dry run still reports instead of refusing, and that a merged branch is not a
    # predecessor.
    #
    # gh IS NOT REACHED OVER THE NETWORK BY ANY OF THIS, and it is worth saying why the suite does not
    # have to arrange that: the script does Set-Location to the fixture, whose origin is a local bare
    # repo, so 'gh pr list' has no GitHub repository to answer for and fails. That drives the two-part
    # merged test onto its ancestry half and onto the "gh could not answer" note -- deterministically,
    # offline, and covering the fallback rather than skipping it.
    Write-Host ''
    Write-Host 'the standing-predecessor guard'

    $predBranch = 'sync/live-2026-08-21'

    $guardRepo = New-Consumer -Label 'guard' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $guardRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $guardRepo -Name $predBranch -Files @{ 'sections/from-editor.liquid' = 'a third party wrote this' }
    $guardMirror = New-Mirror -Label 'guard' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }

    $refused = Invoke-Sync -Dir $guardRepo -Mirror $guardMirror
    Assert-True ($refused.Code -eq 1) 'guard: a standing sync branch refuses the run'
    Assert-True ($refused.Out -match 'STILL STANDING: sync/live-2026-08-21') 'guard: and names the branch that is standing'
    Assert-True ($refused.Out -match 'Refusing: 1 sync branch') 'guard: with the count, because four is the case that produced this'
    Assert-True ($refused.Out -match 'gh pr list --head sync/live-2026-08-21') 'guard: it hands over the command that shows what that branch holds'
    Assert-True ($refused.Out -match '-AllowStacking') 'guard: and names the override rather than leaving it to be found'

    # THE REFUSAL IS UPSTREAM OF THE MIRROR STEP, which is the whole reason the detection sits at the
    # naming step rather than beside the verdict it feeds. A refused run must cost no theme pull.
    Assert-True ($refused.Out -notmatch 'mirroring live') 'guard: the refusal lands BEFORE the mirror step, so it costs no pull'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $guardRepo 'sections\from-editor.liquid'))) 'guard: nothing was written into the repo'
    $onBranch = ([string](& git -C $guardRepo rev-parse --abbrev-ref HEAD)).Trim()
    Assert-True ($onBranch -eq 'main') 'guard: and no sync branch was checked out'

    # A DRY RUN IS EXEMPT, and this is the case the exemption exists for: somebody looking at an open sync
    # PR asks whether today's drift already contains it. A refusal here would withhold the answer.
    $dry = Invoke-Sync -Dir $guardRepo -Mirror $guardMirror -Extra @('-DryRun')
    Assert-True ($dry.Code -eq 0) 'guard/dry: a dry run reports instead of refusing'
    Assert-True ($dry.Out -match 'all of them in this run') 'guard/dry: and says this run supersedes that branch'
    Assert-True ($dry.Out -match 'close that PR') 'guard/dry: naming the action, not just the verdict'

    # -AllowStacking LETS IT THROUGH, and the verdict is printed before anything is written rather than
    # after the push: the operator asked for a second candidate, so they get its relationship to the first.
    $stacked = Invoke-Sync -Dir $guardRepo -Mirror $guardMirror -Extra @('-AllowStacking')
    Assert-True ($stacked.Code -eq 0) 'guard/override: -AllowStacking runs the sync anyway'
    Assert-True ($stacked.Out -match 'continuing anyway') 'guard/override: and says so rather than falling silent'
    Assert-True ($stacked.Out -match 'all of them in this run') 'guard/override: with the verdict, before the branch is written'

    # THE SECOND ROW, which is what the override actually exists for: a path the predecessor captured and
    # this run does not, because a third party reverted it on live in between. Neither branch supersedes
    # the other, and the uncovered path is named rather than counted.
    $indepRepo = New-Consumer -Label 'guard-indep' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $indepRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $indepRepo -Name 'sync/live-2026-08-20' -Files @{ 'sections/reverted-since.liquid' = 'live had this, then lost it' }
    $indepMirror = New-Mirror -Label 'guard-indep' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $indep = Invoke-Sync -Dir $indepRepo -Mirror $indepMirror -Extra @('-DryRun')
    Assert-True ($indep.Out -match '1 NOT in this run') 'guard/independent: a path this run does not take denies supersession'
    Assert-True ($indep.Out -match 'sections/reverted-since\.liquid') 'guard/independent: and that path is named, because it is the decision'
    Assert-True ($indep.Out -match 'Neither supersedes the other') 'guard/independent: so neither branch is presented as redundant'

    # AN UNSAFE PREDECESSOR NAME REACHES THE PRINTED COMMAND, and this is the behavioural half of #1627 --
    # the source-shape asserts in ref-print-lib.tests.ps1 prove the call site, this proves the output. The
    # name is a LEGAL ref that the paste allowlist refuses: `git check-ref-format --branch` exits 0 on
    # 'sync/live-2026-08-17;touch' (measured), and nothing between `git ls-remote` and that `Write-Host`
    # asks git anything anyway -- whoever pushed a branch under this prefix chose the name.
    #
    # THE TWO HALVES ARE ASSERTED SEPARATELY ON PURPOSE. The command must carry the placeholder, and the
    # note must carry the real name -- a remedy that hides the name leaves the reader unable to act, which
    # is the failure Get-PasteableRef's own contract calls worse than the one it guards.
    $unsafePred = 'sync/live-2026-08-17;touch'
    $evilRepo = New-Consumer -Label 'guard-evil' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $evilRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $evilRepo -Name $unsafePred -Files @{ 'sections/from-editor.liquid' = 'a third party wrote this' }
    $evilMirror = New-Mirror -Label 'guard-evil' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $evil = Invoke-Sync -Dir $evilRepo -Mirror $evilMirror
    Assert-True ($evil.Code -eq 1) 'guard/unsafe: a standing branch still refuses the run, whatever it is called'
    Assert-True ($evil.Out -match [regex]::Escape('gh pr list --head <branch> --state open')) 'guard/unsafe: the printed command carries the placeholder, not the name'
    Assert-True ($evil.Out -notmatch [regex]::Escape('gh pr list --head sync/live-2026-08-17;touch')) 'guard/unsafe: and never the raw name after a command word'
    Assert-True ($evil.Out -match 'not safe to paste into the line above') 'guard/unsafe: the note explains why the line reads a placeholder'
    # 'The branch name is:' -- the note's own noun, which #1637 made a function of -Kind. Asserted with
    # the noun rather than around it, because that word is the half telling the reader WHAT kind of thing
    # to go looking for, and a path-shaped note here would be the wrong answer rather than a wording nit.
    Assert-True ($evil.Out -match [regex]::Escape('The branch name is: sync/live-2026-08-17;touch')) 'guard/unsafe: and names the real branch as PROSE, so the reader can still act on it'

    # THE #821 CLASS AT THE PREDECESSOR READ (issue #1629), which is the one read that never had this pin.
    # The accented path further up pins it at the ls-tree/mirror comparison; this read is the one that
    # decides SUPERSESSION, and it asked git for the predecessor's file set with no core.quotePath of its
    # own. git quotes a path with a byte above 0x7F by default, so that side arrived as
    # '"sections/caf\303\251.liquid"' while the take set holds the decoded string from the mirror walk --
    # no match, and a branch this run covers exactly reported as independent.
    #
    # THE WRONG ANSWER IS THE EXPENSIVE DIRECTION. 'all of them in this run' tells the operator to close
    # that PR; 'NOT in this run' tells them both branches are needed. So the defect kept a redundant sync
    # PR alive and told the operator the two were unrelated -- while naming a path that IS in the run.
    # Its own accented name rather than the one above, so this case does not depend on that block's order.
    $predAccented = 'sections/pr' + [char]0x00E9 + 'd' + [char]0x00E9 + 'cesseur.liquid'
    $qpRepo = New-Consumer -Label 'guard-qp' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $qpRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $qpRepo -Name 'sync/live-2026-08-18' -Files @{ $predAccented = 'a third party wrote this' }
    $qpMirror = New-Mirror -Label 'guard-qp' -Files @{
        'sections/theme.liquid'     = 'v1'
        'sections/unrelated.liquid' = 'u1'
    }
    Set-FixtureFile -Root $qpMirror -Rel $predAccented -Value 'a third party wrote this'
    $qp = Invoke-Sync -Dir $qpRepo -Mirror $qpMirror -Extra @('-DryRun')
    Assert-True ($qp.Out -match 'all of them in this run') 'guard/quotepath: an accented path the predecessor captured is recognised in this run'
    Assert-True ($qp.Out -notmatch 'NOT in this run') 'guard/quotepath: so the branch is not reported as independent when this run supersedes it'
    Assert-True ($qp.Out -match 'close that PR') 'guard/quotepath: and the operator is told the action, which the wrong verdict withheld'
    # THE QUOTED FORM MUST NOT REACH THE REPORT EITHER: an octal escape printed at the operator is the
    # same wrong answer wearing a different face, and it is what a fix that only decoded HALF would leave.
    Assert-True ($qp.Out -notmatch [regex]::Escape('\303\251')) 'guard/quotepath: no C-quoted octal escape is printed anywhere in the verdict'

    # A MERGED BRANCH IS NOT A PREDECESSOR. Its ref lingers here because the fixture has no
    # delete_branch_on_merge, which is exactly the consumer this script must not refuse forever.
    $mergedRepo = New-Consumer -Label 'guard-merged' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $mergedRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $mergedRepo -Name 'sync/live-2026-08-19' -Files @{ 'sections/landed.liquid' = 'this one was merged' } -MergeIntoTrunk
    $mergedMirror = New-Mirror -Label 'guard-merged' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/landed.liquid'      = 'this one was merged'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $merged = Invoke-Sync -Dir $mergedRepo -Mirror $mergedMirror -Extra @('-DryRun')
    Assert-True ($merged.Out -notmatch 'STILL STANDING') 'guard/merged: a branch already in the trunk is not standing'
    Assert-True ($merged.Out -match 'all merged') 'guard/merged: and the run says it looked and found them merged'

    # THE PREFIX IS THE SEAM'S, NOT 'sync/'. This is the one defect the inbound report's own proposal
    # carried, and it fails silently in production: a consumer whose branches are named otherwise gets a
    # guard that scans, finds nothing, and never fires.
    $seamRepo = New-Consumer -Label 'guard-prefix' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com' `
        -ExtraSeams "function Get-ShopifySyncBranchPrefix { return 'theme-drift/' }"
    Add-FixtureCommit -Dir $seamRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Add-PredecessorBranch -Dir $seamRepo -Name 'theme-drift/2026-08-21' -Files @{ 'sections/from-editor.liquid' = 'a third party wrote this' }
    Add-PredecessorBranch -Dir $seamRepo -Name 'sync/live-2026-08-21' -Files @{ 'sections/other.liquid' = 'not this consumer''s prefix' }
    $seamMirror = New-Mirror -Label 'guard-prefix' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $seamRun = Invoke-Sync -Dir $seamRepo -Mirror $seamMirror
    Assert-True ($seamRun.Code -eq 1) 'guard/prefix: a branch under the consumer''s own prefix refuses the run'
    Assert-True ($seamRun.Out -match 'STILL STANDING: theme-drift/2026-08-21') 'guard/prefix: the seam''s prefix is what the scan anchors on'
    Assert-True ($seamRun.Out -notmatch 'STILL STANDING: sync/live-2026-08-21') 'guard/prefix: and a ''sync/'' branch is not this consumer''s predecessor'

    # NO PREDECESSOR AT ALL is the ordinary state, and it must stay silent rather than becoming one more
    # line every run prints -- a signal that is always present stops being read, which is the failure
    # this whole guard was filed about.
    $cleanRepo = New-Consumer -Label 'guard-clean' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $cleanRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    $cleanRun = Invoke-Sync -Dir $cleanRepo -Mirror (New-Mirror -Label 'guard-clean' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }) -Extra @('-DryRun')
    Assert-True ($cleanRun.Code -eq 0) 'guard/none: no standing branch is not a refusal'
    Assert-True ($cleanRun.Out -match 'none on origin') 'guard/none: the step reports that it looked'
    Assert-True ($cleanRun.Out -notmatch 'Standing sync branches, measured') 'guard/none: and prints no verdict table for branches that do not exist'

    # --- the network guard (inbound #1181, gh half #1184) -------------------------------------------
    # WHAT THESE CASES PROTECT is a failure with no error message: a call that reaches the network,
    # blocks on a credential prompt nothing can answer, and reads as a run still in progress. Inbound
    # #1179 closed that class inside Invoke-NativeCapture -- the non-interactive environment plus an
    # opt-in bound -- and this script was not a caller, so its nine network calls sat outside it: five
    # git (#1181) and, filed beside them rather than ridden along, four gh (#1184).
    #
    # FOUR OF THE FIVE ARE ALREADY DRIVEN FOR REAL by the cases above, against the fixture's local bare
    # origin: the trunk pull at [1/6], the ls-remote and the fetch at [3b/6], and the push on the drift
    # case (the suite header says that push is not asserted, and it still is not -- what it now proves is
    # that the call SURVIVES the routing, which is a claim about this script). So a regression that broke
    # the wiring would already be red. What no existing case can reach is the SHAPE of the guard, and
    # that is what the static asserts below are for.
    Write-Host ''
    Write-Host 'the network guard'

    $src = Get-Content -LiteralPath $Script -Raw

    Assert-True ($src -match [regex]::Escape('. (Join-Path $PSScriptRoot ''..\lib\native-capture-lib.ps1'')')) `
        'net: the lib is dot-sourced'
    # UNGUARDED, unlike the source-repo guard three lines above it in the script. A Test-Path wrapper
    # would turn a payload missing the lib into a run that pushes unbounded, which is the defect.
    Assert-True ($src -notmatch 'Test-Path[^\n]*native-capture-lib') `
        'net: and unguarded, so a payload without it fails at load rather than pushing unbounded'

    # NO BARE '& git' NETWORK VERB LEFT. The local ones -- status, rev-parse, checkout, commit, ls-tree --
    # are deliberately untouched: they cannot reach a credential helper, and a bound on them would buy
    # nothing. So the assert names the four verbs that do reach the network rather than banning '& git'.
    Assert-True ($src -notmatch '&\s*git\s+(pull|push|fetch|ls-remote)\b') `
        'net: no bare ''& git'' call reaches the network any more'

    # NOR THROUGH Invoke-SyncGitQuiet, which is the half of this that is easy to reintroduce. That
    # wrapper swallows stderr by design (inbound #801), so a network call routed back through it fails
    # silently as well as unboundedly -- and its remaining callers are all local queries.
    Assert-True ($src -notmatch 'Invoke-SyncGitQuiet\s+@\(\s*''(pull|push|fetch|ls-remote)''') `
        'net: and none goes back through the stderr-swallowing wrapper'

    # NO BARE gh NETWORK VERB LEFT EITHER (inbound #1184, widened by #1187). Named verbs rather than a
    # ban on '& gh', for the same reason as the git assert above: the local-only gh calls a future edit
    # may add have no business failing this. 'checks' JOINED THE LIST WITH #1187 -- it was carved out
    # until then because the poll was deliberately bare, and that carve-out was the thing #1187 removed.
    Assert-True ($src -notmatch '&\s*gh\s+pr\s+(list|create|view|merge|checks)\b') `
        'net: no bare ''& gh'' call reaches the network any more'
    # AND NOT AS A BARE COMMAND EITHER, which is the shape the poll actually had: it sat inside a
    # hand-rolled EAP bracket with no '&' in front of it, so the assert above would have read clean over
    # it. That is why this one matches the command text rather than the call operator.
    Assert-True ($src -notmatch 'gh pr checks \$pr --json state') `
        'net: and the poll is no longer a bare ''gh pr checks'' inside a hand-rolled EAP bracket'

    # THE POLL'S TIMEOUT IS NOT A VERDICT, and this is the behavioural claim the routing had to preserve
    # (inbound #1187). Two things would each turn a stall into a wrong answer, and neither is visible in
    # a count: the bounded arm APPENDS two '[timeout]' lines to Output, which parsed as states match
    # nothing and read as CI failure; and 'gh pr checks' exits 8 while checks are pending and 1 when one
    # has failed, so gating the parse on ExitCode -eq 0 would discard a real red and sit out the whole
    # deadline instead. So the source must judge TimedOut and must NOT judge the exit code here.
    Assert-True ($src -match [regex]::Escape('if ($poll.TimedOut) {')) `
        'net/poll: a timed-out poll is judged on TimedOut, not on what it printed'
    Assert-True ($src -notmatch '\$poll\.ExitCode') `
        'net/poll: and the exit code is deliberately not judged -- gh exits 8 on pending and 1 on red'

    # EVERY Invoke-NativeCapture HERE CARRIES THE SHARED BOUND, and the count is pinned at eleven so a
    # twelfth network call added without one fails this assert rather than passing unnoticed. The number
    # rather than a ratio: 11 == 11 would also hold if somebody deleted a call and its bound together.
    # '-FilePath' IS PART OF THE PATTERN rather than the bare function name, because the banner at the
    # top of the script names the function in prose -- and a bare-name count read 6 against 5 real calls.
    # WAS FIVE UNTIL #1184 added the four gh calls, NINE UNTIL #1187 routed the poll, and TEN UNTIL #1945
    # added -ReconcileBase's push; the git half is otherwise unchanged throughout.
    $calls  = @([regex]::Matches($src, 'Invoke-NativeCapture\s+-FilePath\b')).Count
    $bounds = @([regex]::Matches($src, [regex]::Escape('-TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds'))).Count
    Assert-True ($calls -eq 11) "net: eleven network calls go through the lib (found $calls)"
    Assert-True ($bounds -eq 11) "net: and all eleven pass the shared bound (found $bounds)"

    # THE FIVE gh CALLS BY NAME, because the count above is blind to WHICH ten they are: it would still
    # read 10 if a gh call went back to being bare and a git call were split in two.
    foreach ($verb in @('list', 'create', 'view', 'merge', 'checks')) {
        Assert-True ($src -match "Invoke-NativeCapture -FilePath 'gh'(?s).{0,400}?'pr', '$verb'") `
            "net: gh pr $verb goes through the lib"
    }

    # -DiscardStderr ON THE THREE --json READS AND NOT ON THE TWO WRITES, which is the half a count cannot
    # see. The reads are parsed -- a merged gh status line becomes a branch name, a PR number or a check
    # state that .Trim() returns happily -- while the writes are progress whose stderr carries the PR URL.
    Assert-True ($src -match "Invoke-NativeCapture -FilePath 'gh' -DiscardStderr(?s).{0,400}?'pr', 'list'") `
        'net: the merged-PR read discards stderr, so a status line cannot become a branch name'
    Assert-True ($src -match "Invoke-NativeCapture -FilePath 'gh' -DiscardStderr(?s).{0,400}?'pr', 'view'") `
        'net: and the PR-number read discards stderr, so a status line cannot become the number'
    # THE POLL'S FLAG IS THE ONE THAT REPLACED A HAND-ROLLED BRACKET (#1187), so it is load-bearing in a
    # way the other two are not: 'gh pr checks' WRITES to stderr on every pending run, which is the state
    # the loop exists to sit through. Without it that noise arrives as states and reads as CI failure.
    Assert-True ($src -match "Invoke-NativeCapture -FilePath 'gh' -DiscardStderr(?s).{0,400}?'pr', 'checks'") `
        'net: and the checks poll discards the stderr a pending run writes, which is what its old bracket did'

    # THE EXIT-CODE CHECK ON 'gh pr view', WHICH IS THE DEFECT #1184 DID NOT REPORT. The old line piped
    # the output straight into .Trim(), so a failed read produced an EMPTY $pr and no message -- and the
    # checks loop then polled with no PR number for the whole of -ChecksTimeoutMinutes before telling the
    # operator to run 'gh pr merge  --squash'. The PR was open and green throughout.
    Assert-True ($src -notmatch [regex]::Escape('([string](& gh pr view')) `
        'net: gh pr view no longer pipes an unjudged read into .Trim()'
    Assert-True ($src -match [regex]::Escape('if ($prView.ExitCode -ne 0 -or -not $pr) {')) `
        'net: and an unreadable PR number now exits instead of polling with an empty one'

    # NO HAND-ROLLED EAP BRACKET LEFT ANYWHERE IN THE SCRIPT. #1184 expected that dance at all four gh
    # sites; measured, only 'gh pr list' carried it, and the count was pinned at one for the checks
    # loop's. #1187 routed that loop, which took the last one with it -- so the pin is now zero, and the
    # reason it is a COUNT rather than a spot check is unchanged: the lib owns this dance, and a bracket
    # reappearing here means a call went back around it.
    $eap = @([regex]::Matches($src, [regex]::Escape('$prevEap = $ErrorActionPreference'))).Count
    Assert-True ($eap -eq 0) "net: no hand-rolled EAP bracket left -- the lib owns that dance (found $eap)"

    # THE LIB TRAVELS IN dkj-subagents-shopify's OWN PAYLOAD. Without this entry the mirrored script dot-sources a
    # file that is not in the mirror, and it fails at load in a consumer that installed dkj-subagents-shopify
    # without dkj-policy -- which is most of them. build-shared-scripts -Check cannot catch
    # that: it compares the pairs the registry declares, so a missing entry is a pair it never looks at.
    . (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
    $shopLib = @(Get-SharedScriptPairs -RepoRoot $RepoRoot |
        Where-Object { $_.Plugin -eq 'dkj-subagents-shopify' -and $_.SourceRel -eq 'scripts\lib\native-capture-lib.ps1' })
    Assert-True ($shopLib.Count -eq 1) 'net: the registry mirrors the lib into dkj-subagents-shopify'
    Assert-True ($shopLib.Count -eq 1 -and (Test-Path -LiteralPath $shopLib[0].MirrorPath -PathType Leaf)) `
        'net: and that mirror is present beside the mirrored sync-main.ps1'

    # AND THE SAME FOR THE QUOTED-PATH DECODER (issue #1689, September 9, 2026). Convert-GitQuotedPath moved
    # out of sync-rules.ps1 into git-porcelain-lib.ps1, which this script now dot-sources directly and
    # unguarded -- so it needs its own dkj-subagents-shopify mirror for exactly the reason the block above gives,
    # and the same reason that block gives for why nothing else can catch a missing entry. The dot-source is
    # asserted too: unguarded is the point, because a payload without the file must fail at LOAD rather than
    # fall through to a path that is silently mis-decoded, which is inbound #821's failure exactly.
    $porcLib = @(Get-SharedScriptPairs -RepoRoot $RepoRoot |
        Where-Object { $_.Plugin -eq 'dkj-subagents-shopify' -and $_.SourceRel -eq 'scripts\lib\git-porcelain-lib.ps1' })
    Assert-True ($porcLib.Count -eq 1) 'decoder: the registry mirrors git-porcelain-lib into dkj-subagents-shopify'
    Assert-True ($porcLib.Count -eq 1 -and (Test-Path -LiteralPath $porcLib[0].MirrorPath -PathType Leaf)) `
        'decoder: and that mirror is present beside the mirrored sync-main.ps1'
    Assert-True ($src -match [regex]::Escape("lib\git-porcelain-lib.ps1")) 'decoder: sync-main dot-sources the lib it takes Convert-GitQuotedPath from'
    Assert-True ($src -notmatch 'Test-Path[^\r\n]*git-porcelain-lib') 'decoder: and does so UNGUARDED -- a missing payload must fail at load, not mis-decode quietly'
    # THE FUNCTION IS NO LONGER IN sync-rules.ps1, which is the half that keeps that file dependency-free.
    # A future tidy-up that moved it back would disarm the live-theme guard's catch, so it is pinned here.
    $rulesSrc = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\sync-rules.ps1') -Raw
    Assert-True ($rulesSrc -notmatch 'function Convert-GitQuotedPath') 'decoder: sync-rules.ps1 no longer defines it'
    Assert-True ($rulesSrc -notmatch '^\s*\.\s+.*git-porcelain-lib') 'decoder: and sync-rules.ps1 does not dot-source it either -- it must stay dependency-free'

    # THE ls-remote FAILURE: A REAL RUN REFUSES, A DRY RUN REPORTS AND CONTINUES (inbound #1181,
    # DryRun carve-out #1373). Before #1181 the call ran through Invoke-SyncGitQuiet, so an unreachable
    # origin produced no lines -- indistinguishable from "no sync branch on origin" -- and the guard
    # reported 'none on origin' and let the run proceed: the silent miss the guard was filed to end.
    # #1181 made it a hard refusal. #1373 is the follow-up: a DRY RUN writes and pushes nothing, so
    # refusing there only withholds the verdict and breaks the documented offline -MirrorPath rehearsal
    # (.PARAMETER MirrorPath). So a dry run now SKIPS the check and carries on to the verdict -- without
    # ever reading the failure as 'none on origin', which is the false negative #1181 closed. A dry run is
    # also the only run that reaches [3b] on a broken origin at all: a real run fails first at the [1/6]
    # trunk pull, asserted just below.
    $netRepo = New-Consumer -Label 'net-lsremote' -ThemeId '123456' -StoreDomain 'a-store.myshopify.com'
    Add-FixtureCommit -Dir $netRepo -Message 'sync: the floor' -Write @{ 'sections/unrelated.liquid' = 'u1' }
    Invoke-Git -C $netRepo remote set-url origin (Join-Path $netRepo 'no-such-origin.git')
    $netMirror = New-Mirror -Label 'net-lsremote' -Files @{
        'sections/theme.liquid'       = 'v1'
        'sections/unrelated.liquid'   = 'u1'
        'sections/from-editor.liquid' = 'a third party wrote this'
    }
    $netRun = Invoke-Sync -Dir $netRepo -Mirror $netMirror -Extra @('-DryRun')
    Assert-True ($netRun.Code -eq 0) 'net/ls-remote: a dry run against an unreadable origin continues instead of refusing'
    Assert-True ($netRun.Out -match 'standing-predecessor check is skipped for this dry run') 'net/ls-remote: and says the check could not run'
    Assert-True ($netRun.Out -notmatch 'none on origin') 'net/ls-remote: without reading the failure as ''no predecessor'' (the #1181 false negative)'
    Assert-True ($netRun.Out -match '\[5/6\] comparing live against') 'net/ls-remote: the dry run reaches the verdict the offline -MirrorPath rehearsal exists for'
    Assert-True ($netRun.Out -match 'DRY RUN') 'net/ls-remote: and is still plainly a dry run'

    # A REAL RUN against the same broken origin still stops -- at the [1/6] trunk pull, ahead of [3b].
    $netReal = Invoke-Sync -Dir $netRepo -Mirror $netMirror
    Assert-True ($netReal.Code -eq 1) 'net/ls-remote: a real run against an unreadable origin still refuses'

    # AND [3b]'s own hard refusal survives in the non-DryRun branch, where a real run would reach it --
    # the carve-out is a distinct branch, not a softened refusal.
    Assert-True ($src -match 'is still standing is UNKNOWN') 'net/ls-remote: [3b]''s real-run refusal message is intact'
    Assert-True ($src -match "run again\.' -ForegroundColor Red\s*\r?\n\s*exit 1") 'net/ls-remote: and it still hard-exits right after it'
    Assert-True ($src -match [regex]::Escape('if ($DryRun) {') -and $src -match [regex]::Escape('$lsRemoteUnknown = $true')) 'net/ls-remote: the dry-run path is a distinct branch that sets its own flag, not a softened refusal'

    # --- the merged test proves the REF, not its name (inbound #1190, shared by issue #1194) ---------
    # WHAT THIS PROTECTS CANNOT BE DRIVEN FROM THIS SUITE AT ALL, which is why it is asserted statically
    # rather than left uncovered. The fixture's origin is a local bare repo, so 'gh pr list' has no
    # GitHub repository to answer for -- every guard case above therefore runs on the ancestry half, and
    # that is precisely the half that was already correct. The decision itself is unit-tested in
    # merged-pr-lib.tests.ps1, where it is pure and where prune-merged.ps1's copy of it now lands too
    # (issue #1194); what these asserts pin is that THIS script still routes into it, and asks gh for the
    # one field the decision cannot be made without.
    Assert-True ($src -match [regex]::Escape("'--json', 'headRefName,headRefOid'")) `
        'oid: gh is asked for the tip each merged PR carried, not only for its branch name'
    Assert-True ($src -match [regex]::Escape('[.headRefName, .headRefOid] | @tsv')) `
        'oid: as a tab-separated row, so no branch name is split by a character of its own'
    Assert-True ($src -match [regex]::Escape('$mergedTips = Get-MergedPrTipsFromTsv -Lines @($prList.Output)')) `
        'oid: and those rows are parsed by the lib rather than re-read here'
    Assert-True ($src -match [regex]::Escape("'rev-parse', '--verify', '--quiet',")) `
        'oid: the loop reads the standing ref''s current tip'
    Assert-True ($src -match [regex]::Escape('Test-RefMergedByPr -Name $name -Tip $tip -MergedTips $mergedTips')) `
        'oid: and asks the two-part question with it'
    Assert-True ($src -notmatch [regex]::Escape('$mergedHeads -contains')) `
        'oid: the bare-name match that let a merged name vouch for a re-created branch is gone'

    # --- The sync log (inbound #1382) ----------------------------------------------------------------
    # THE ORDERING ASSERT IS THE ONE THAT MATTERS. The commit is path-bounded ('git commit -- @paths'),
    # so an entry written after the add would sit untracked in the working copy while the run reported a
    # clean success -- a sync that says it left a record and did not. Nothing on screen would differ.
    Write-Host ''
    Write-Host 'the sync log'

    Assert-True ($src -match [regex]::Escape('Get-ShopifySyncLogPath')) `
        'log: the seam is read at all'
    # DEFAULT SILENCE. The machinery reaches every Shopify consumer through a plugin update; the policy
    # of keeping a log belongs to the repo. An unanswered seam must leave no file behind.
    Assert-True ($src -match [regex]::Escape("SyncLogPath = ''")) `
        'log: and its default is empty, so a repo that never asked for a log does not get one'
    Assert-True ($src -match '(?s)function Write-SyncLogEntry.{0,1200}if \(-not \$rel\) \{ return '''' \}') `
        'log: an unanswered seam returns early and writes nothing'
    Assert-True ($src -match '(?s)function Write-SyncLogEntry.{0,1600}VUL-IN') `
        'log: and a scaffold marker left standing counts as unanswered, like the theme id'

    $addIdx   = $src.IndexOf("Invoke-SyncGitQuiet @(@('add', '--') + `$paths)")
    $writeIdx = $src.IndexOf('$logRel = Write-SyncLogEntry')
    Assert-True ($writeIdx -gt 0 -and $addIdx -gt 0 -and $writeIdx -lt $addIdx) `
        'log: the entry is written BEFORE the path-bounded add, or it would be left untracked by a run that reports success'
    Assert-True ($src -match [regex]::Escape('if ($logRel) { $paths = @($paths) + $logRel }')) `
        'log: and its path joins the set the add and the commit are bounded to'

    # A FAULT COSTS THE LOG, NEVER THE SYNC. At this point the branch holds a third party's in-flight
    # edits and the only copy is local; a badly answered seam must not take that down.
    Assert-True ($src -match '(?s)function Write-SyncLogEntry.{0,3000}\} catch \{(?s).{0,400}return ''''') `
        'log: a write that throws is reported and the run continues, rather than losing the sync with it'
    # The prepend itself lives in the lib, where the suite can walk it without running a sync.
    Assert-True ($src -match [regex]::Escape('Add-SyncLogEntry -Existing $existing -Entry $entry')) `
        'log: where the entry goes is the lib''s decision, not a second copy of it here'
}
finally {
    foreach ($d in $script:trees) {
        if ($d -and (Test-Path -LiteralPath $d)) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT, AND IT CHANGES WHAT THE VERDICT MEANS (issue #1622). Every
# assert below a git command that failed is measuring a repo that was never built, so reading them as a
# judgement on sync-main.ps1 is the wrong conclusion -- and it is the conclusion a reader reaches by
# default, because a red suite normally means the script regressed. Printed even when every assert
# passed: a fixture that half-built and still went green is a case this suite is not testing, and the
# reader should know which run they are looking at.
#
# THE BLOCK ITSELF IS NOW Write-FixtureGitSummary's (issue #1635) -- same text, same reasoning, one
# source, shared with the sixteen sibling suites that turned out to need it.
$fixtureBroken = Write-FixtureGitSummary -Subject 'sync-main.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
# A CLEAN SWEEP OF ASSERTS OVER A BROKEN FIXTURE IS NOT A PASS. Nothing above would have caught it: the
# count is the only thing that knows, so it is what decides the exit code here rather than a green run
# quietly certifying a suite that never ran what it claims to.
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
