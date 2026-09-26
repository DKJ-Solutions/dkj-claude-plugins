<#
.SYNOPSIS
    Tests for scripts/task/adopt-workflow-folder.ps1 -- the scaffold that places the workflow's own
    root folder (dkj-policy/) in a consuming repo.

.DESCRIPTION
    What is covered, and why these six:
      1. the DRY RUN default writes nothing -- the same contract adopt-config is trusted on;
      2. -Apply places every file the folder promises, with the branch files in the reset shape the
         shared formatters write -- and the releases page carrying NO history table, since the list
         belongs at the repo root (inbound #786);
      3. a re-run is additive: a file somebody edited is never overwritten, whatever it says;
      4. a repo that publishes plugins is refused -- the source keeps its docs at its root (Dave,
         August 14, 2026), so the scaffold must not build the layout its owner declined;
      5. the LEGACY REPORT: a consumer who still carries dkj-policy/README.md or
         dkj-policy/CONTRIBUTING.md from before #2171 is told this command no longer writes or
         refreshes them, and nothing here is ever created, deleted, or rewritten because of it;
      6. the CONSTITUTION IMPORT (#2531): CLAUDE.md gets the one '@'-line that loads the plugin's rules
         -- created, inserted above the first import, or appended -- once, and never twice.

    The repo root is pinned per child run via CLAUDE_PROJECT_DIR, the same dual-context branch every
    mirrored script resolves first, so the fixtures need no git of their own.

    #2171 (September 20, 2026) RETIRED THE SCAFFOLDING OF THE FOLDER'S README.md AND CONTRIBUTING.md,
    and with it the whole refreshable-fence mechanism (#1766) that used to keep the README's "Updating
    the plugins" section current across a re-run -- the marker constants, the four top-up states (fresh,
    re-run, top-up-an-existing-page, replace-a-stale-fence), the pre-fence-legacy state, and the CRLF
    byte-exactness coverage from inbound #1829. None of that machinery exists in the script any more, so
    none of it is tested here any more either -- see the comment where that block used to sit, further
    down this file, for exactly what left and why bending those asserts into something else was declined
    in favour of dropping them outright.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\adopt-workflow-folder.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "adopt-workflow-folder-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

# Dot-sourced for the constants the scaffolded CHANGELOG is asserted against rather than against literals
# (inbound #1098, issue #1518): Get-EntryHeadingLevel, Get-ChangelogUnreleasedHeading, and the shared
# pre-flat guard the fold and the cut both read the document with. The lib is pure and loads no state.
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -match $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern not found: '$Pattern'" -ForegroundColor Red
    }
}

function New-FixtureConsumer {
    <#
        -AsWorkflowSource writes a marketplace that publishes THIS workflow; -AsOtherPluginSource writes
        one that publishes something else. The second shape used to be unreachable: the switch was
        -AsPluginSource and wrote an empty '{}', because the refusal was `Test-Path marketplace.json` and
        any manifest would do. Issue #998 (August 27, 2026) narrowed it, so the fixture has to say WHAT is
        published, and the two cases are now distinguishable -- which is the whole point.
    #>
    param(
        [string]$Label, [switch]$AsWorkflowSource, [switch]$AsOtherPluginSource,
        # -WithRepoConfig writes the lib the note-root seam is appended to; -NoteRootAnswer puts an answer
        # in it; -WithFallbackNotes puts a note at the shared 'releases/notes' fallback. Together they are
        # the three conditions the seam write is gated on (issue #1150), so every branch is reachable here.
        [switch]$WithRepoConfig, [string]$NoteRootAnswer, [switch]$WithFallbackNotes
    )
    $root = Join-Path $Fixture "consumer-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if ($WithRepoConfig -or $NoteRootAnswer) {
        $cfg = "# This repo's own seam answers.`n"
        if ($NoteRootAnswer) { $cfg += "function Get-ReleaseNoteRoot { '$NoteRootAnswer' }`n" }
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        # WRITTEN WITH A BOM, deliberately -- it is the harder path and the realistic one. On a .ps1 a BOM
        # is the FIX rather than the defect (Windows PowerShell 5.1 otherwise decodes a non-ASCII byte as
        # the system ANSI code page), so a command that only meant to add a function must not strip it.
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), $cfg, (New-Object System.Text.UTF8Encoding($true)))
    }
    if ($WithFallbackNotes) {
        New-Item -ItemType Directory -Path (Join-Path $root 'releases\notes\0.x') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root 'releases\notes\0.x\0.1.0.md'), "# 0.1.0`n")
    }
    if ($AsWorkflowSource -or $AsOtherPluginSource) {
        $plugin = if ($AsWorkflowSource) { 'dkj-policy' } else { 'some-other-product' }
        $manifest = '{ "name": "fixture", "plugins": [ { "name": "' + $plugin + '", "source": "./x" } ] }'
        New-Item -ItemType Directory -Path (Join-Path $root '.claude-plugin') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root '.claude-plugin\marketplace.json'), $manifest)
    }
    return $root
}

function Invoke-Adopt {
    # -ScriptPath so the same scenario can be driven through the plugin mirror as well as the root
    # copy (#1857). It defaults to the root copy, so every existing call is unchanged.
    param([string]$Dir, [string[]]$ScriptArgs = @(), [string]$ScriptPath = $Script)
    $prevPd = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $Dir
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
        # Flat is FOR PHRASE ASSERTS ONLY: the child wraps its Write-Host lines at its own host width,
        # a point that moves with the console and with the fixture's temp path length, so a phrase
        # sitting mid-line arrives split MID-WORD across two records. Joined with '' rather than a
        # space because the break is a hard one at a column, so the halves reconstruct exactly --
        # prune-merged.tests.ps1's Get-FlatOutput carries the full reasoning, and #982/#959 are the two
        # suites this class had already turned red. Out keeps the line structure for the [create]/
        # [exists] asserts, which are per-line and must stay that way.
        return [pscustomobject]@{
            Code = $LASTEXITCODE
            Out  = ($out -join "`n")
            Flat = (($out | ForEach-Object { [string]$_ }) -join '')
        }
    } finally {
        if ($null -eq $prevPd) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

# Every file -Apply must place. Read from the same claim the script makes rather than restated per
# assert, so a target added there fails ONE list here instead of passing unexamined.
#
# README.md, CONTRIBUTING.md AND releases/README.md ARE DELIBERATELY ABSENT FROM THIS LIST (#2171 and
# #2196, September 20, 2026). This command no longer scaffolds any of the three -- see the
# legacy-report section further down, which is where their coverage now lives.
#
# SO THE LIST IS DOWN TO ONE ENTRY, AND IT IS KEPT AS A LIST ON PURPOSE. A single Test-Path inlined
# where the loop is would read as "this file is placed" rather than as "these are ALL the files that
# are placed", which is the claim the loop below actually makes and the only one worth having: the
# folder's whole contents are now one file, and the next page added here has to be added here.
$ExpectedFiles = @(
    'dkj-policy\CHANGELOG.md'
)
# THE ABSENCE ITSELF IS ASSERTED, NOT JUST IMPLIED BY LEAVING THEM OFF THE LIST ABOVE. A list nobody
# checks the negative of is a list the next refactor can add a line back to without any assert
# noticing -- which is exactly how these pages arrived silently in the first place.
$RetiredScaffoldFiles = @(
    'dkj-policy\README.md',
    'dkj-policy\CONTRIBUTING.md',
    'dkj-policy\releases\README.md'
)

try {
    Write-Host "== adopt-workflow-folder.tests: scripts/task/adopt-workflow-folder.ps1 ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    # --- 1. Dry run (the default): the plan is printed, nothing is written -------------------------
    Write-Host "adopt-workflow-folder -- dry run writes nothing" -ForegroundColor Cyan
    $c1 = New-FixtureConsumer -Label 'dryrun'
    $r1 = Invoke-Adopt -Dir $c1
    Assert-Equal 0 $r1.Code 'dry run: exit 0'
    Assert-Match 'DRY RUN' $r1.Out 'dry run: says so out loud'
    Assert-Match '\[create\]\s+dkj-policy/CHANGELOG\.md' $r1.Out 'dry run: lists the changelog as to-create'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c1 'dkj-policy'))) 'dry run: the folder was not created'
    # NO RETIRED PAGE IS EVER LISTED AS TO-CREATE (#2171, #2196) -- this run scaffolds none of the
    # three, so a dry run over a fresh consumer (who has none of them) reports no legacy line either:
    # there is nothing to report on.
    Assert-True ($r1.Out -notmatch '\[create\]\s+dkj-policy/README\.md') 'dry run: the retired README is never listed as to-create'
    Assert-True ($r1.Out -notmatch '\[create\]\s+dkj-policy/CONTRIBUTING\.md') 'dry run: the retired CONTRIBUTING is never listed as to-create'
    Assert-True ($r1.Out -notmatch '\[create\]\s+dkj-policy/releases/README\.md') 'dry run: the retired releases page is never listed as to-create'
    Assert-True ($r1.Out -notmatch '\[legacy\]') 'dry run: a fresh consumer with no retired page triggers no legacy report'
    # The PR template is in the plan and not on disk -- the whole promise of the default run (#1843).
    Assert-Match '\[create\]\s+\.github/pull_request_template\.md' $r1.Out 'dry run: lists the PR template as to-create'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c1 '.github\pull_request_template.md'))) 'dry run: and did not write it'

    # --- 2. -Apply places the whole folder ----------------------------------------------------------
    Write-Host "adopt-workflow-folder -- -Apply places every file" -ForegroundColor Cyan
    $c2 = New-FixtureConsumer -Label 'apply'
    $r2 = Invoke-Adopt -Dir $c2 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r2.Code '-Apply: exit 0'
    foreach ($rel in $ExpectedFiles) {
        Assert-True (Test-Path -LiteralPath (Join-Path $c2 $rel) -PathType Leaf) "-Apply: $rel exists"
    }
    # AND THE TWO RETIRED PAGES ARE POSITIVELY ASSERTED ABSENT (#2171) -- an absence nobody asserts is
    # an absence the next refactor restores by accident, exactly as it did once already for the fenced
    # UPDATE section this same change also removed.
    foreach ($rel in $RetiredScaffoldFiles) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $c2 $rel))) "-Apply: $rel is NOT created any more"
    }

    # --- THE ENTRY GATE, AND THE PATH IT REACHES INTO THIS TREE FOR (#1805) -----------------------
    # This runner was the ONE file this command places outside the folder and the only one nothing here
    # asserted at all -- not that it lands, and not that the script it names exists. It does not vendor
    # the gate: it checks THIS repository out beside the consumer's tree and runs a path into it, so the
    # dependency points the wrong way and this suite is the only end of it this repo can hold.
    #
    # THE PATH IS DERIVED FROM THE EMITTED FILE, NEVER RESTATED HERE, and that is the whole point of the
    # assert rather than a style preference. adopt-ci-floor.tests.ps1 pins its three paths as literal
    # strings -- `$fold -like '*.workflow-scripts/plugins/dkj-policy/...*'` -- which compares the
    # scaffolder's output against itself and stays green when the script moves in this tree. It did move
    # (plugins/workflows/contributing-davekjohn/ -> plugins/dkj-policy/), every suite stayed green, and
    # two consumers were red on every pull request for five days before anybody noticed.
    #
    # AND SINCE #2422 THE DEPENDENCY HAS TWO HOPS, so both are followed. The placed file is a CALLER of a
    # reusable workflow in this repo, and that workflow is what checks this repo out and runs the script.
    # Asserting only the first hop would leave the #1805 shape open one file further in: the reusable
    # workflow could name a moved script and every consumer would go red with this suite green.
    . (Join-Path $RepoRoot 'scripts\lib\consumer-runner-lib.ps1')
    foreach ($gate in @('branch-entry', 'always-on-budget')) {
        $gateRel = ".github\workflows\$gate.yml"
        $gateAbs = Join-Path $c2 $gateRel
        Assert-True (Test-Path -LiteralPath $gateAbs -PathType Leaf) "-Apply: the $gate gate workflow is placed"
        if (-not (Test-Path -LiteralPath $gateAbs -PathType Leaf)) { continue }
        $gateText = [System.IO.File]::ReadAllText($gateAbs, [System.Text.Encoding]::UTF8)

        $calls = @(Get-SharedScriptReference -WorkflowText $gateText -RepositoryName 'dkj-claude-plugins')
        Assert-Equal 1 $calls.Count "-Apply: the $gate caller reaches exactly one path into this repo"
        Assert-Equal 'call' ([string]@($calls | ForEach-Object { $_.Kind })[0]) "-Apply: the $gate caller reaches it by a reusable-workflow CALL, not a checkout of its own"
        # GitHub refuses timeout-minutes (and runs-on/steps) on a job that calls a reusable workflow, so a
        # caller carrying one is a workflow that fails to load in every consumer.
        Assert-True ($gateText -notmatch '(?m)^\s*(timeout-minutes|runs-on|steps):') "-Apply: the $gate caller carries no runner keys a calling job may not have"

        foreach ($judged in @(Test-SharedScriptReference -Reference $calls -SourceRoot $RepoRoot)) {
            Assert-True $judged.Exists "-Apply: the $gate caller calls '$($judged.Path)', and that workflow EXISTS in this tree"
            if (-not $judged.Exists) { continue }
            $called = [System.IO.File]::ReadAllText((Join-Path $RepoRoot ($judged.Path -replace '/', '\')), [System.Text.Encoding]::UTF8)
            Assert-True ($called -match '(?m)^\s*workflow_call:') "-Apply: '$($judged.Path)' is a reusable workflow (on: workflow_call)"
            $scripts = @(Get-SharedScriptReference -WorkflowText $called -RepositoryName 'dkj-claude-plugins' | Where-Object { $_.Kind -eq 'checkout' })
            Assert-Equal 1 $scripts.Count "-Apply: '$($judged.Path)' runs exactly one script out of a checkout of this repo"
            foreach ($s in @(Test-SharedScriptReference -Reference $scripts -SourceRoot $RepoRoot)) {
                Assert-True $s.Exists "-Apply: '$($judged.Path)' runs '$($s.Path)', and that path EXISTS in this tree"
                Assert-True ($s.Path -like 'plugins/*') "-Apply: '$($s.Path)' is the published plugin mirror, not this repo's own scripts/ copy"
            }

            # THE DEPLOY LOCK (#2429) needs BOTH hops, and each half fails silently alone. The runner must
            # pass -Pr, and must NOT declare permissions: a called workflow asking for a scope its caller
            # did not grant fails to start, which would turn every caller placed before #2429 red. The
            # caller must grant pull-requests: read (the only place the scope can come from) and fire on
            # `edited`, or `open-pr -RefreshBody` repairs a drift the check can never re-read (#1710).
            if ($gate -eq 'branch-entry') {
                Assert-True ($called -match 'check-branch-entry\.ps1[^\r\n]*-Pr "\$\{\{ github\.event\.pull_request\.number \}\}"') "-Apply: '$($judged.Path)' passes -Pr, so a consumer holds the DEPLOY lock"
                Assert-True ($called -notmatch '(?m)^\s*permissions:') "-Apply: '$($judged.Path)' declares no permissions, so a caller that grants no pull-requests scope still starts"
                Assert-True ($gateText -match '(?m)^\s+pull-requests: read\s*$') "-Apply: the branch-entry caller grants pull-requests: read, the scope the lock reads the PR body with"
                Assert-True ($gateText -match '(?m)^\s+types: \[[^\]]*\bedited\b[^\]]*\]') "-Apply: the branch-entry caller fires on 'edited', so the check re-runs after open-pr -RefreshBody"
            }
        }
    }

    # --- THE PR TEMPLATE, THE SECOND FILE PLACED OUTSIDE THE FOLDER (#1843) -----------------------
    # It is a COPY where the gate above is a call, because GitHub reads a PR template only from this path
    # in the consumer's own repo. What makes its absence worth a test rather than a note: open-pr wraps
    # its whole body-building block in 'if (Test-Path $templatePath)' with no else, so a consumer without
    # the file gets a PR with no body at all and no warning -- the one warning that block carries fires
    # on a placeholder that does not MATCH, which is a different state.
    #
    # NEITHER ASSERT RESTATES THE TEMPLATE, for the reason the gate asserts above were rewritten (#1805):
    # a literal here would compare the scaffolder's output against this file rather than against the
    # thing it has to agree with, and stay green when that thing moves. So the first reads the shipped
    # reference off disk, and the second reads the placeholder list open-pr itself matches on.
    $prtRel = '.github\pull_request_template.md'
    $prtPlaced = Join-Path $c2 $prtRel
    Assert-True (Test-Path -LiteralPath $prtPlaced -PathType Leaf) '-Apply: the PR template is placed'
    $prtRefPath = Join-Path $RepoRoot 'plugins\dkj-policy\templates\pull_request_template.md'
    Assert-True (Test-Path -LiteralPath $prtRefPath -PathType Leaf) '-Apply: and the shipped reference it is copied from exists in this tree'
    if ((Test-Path -LiteralPath $prtPlaced) -and (Test-Path -LiteralPath $prtRefPath)) {
        $prtPlacedText = [System.IO.File]::ReadAllText($prtPlaced, [System.Text.Encoding]::UTF8)
        $prtRefText    = [System.IO.File]::ReadAllText($prtRefPath, [System.Text.Encoding]::UTF8)
        Assert-Equal ($prtRefText -replace "`r`n", "`n") ($prtPlacedText -replace "`r`n", "`n") `
            '-Apply: what is placed is the shipped reference, not a second copy typed into the scaffolder'

        # THE CONTRACT, NOT THE BYTES: one line of what lands has to be a placeholder open-pr recognises,
        # or the consumer gets PRs with no description -- the outcome the whole list exists to prevent.
        # Read from pr-body-lib so a reference edited without its matcher fails HERE, at adoption, rather
        # than silently in a consumer's first PR.
        . (Join-Path $RepoRoot 'scripts\lib\pr-body-lib.ps1')
        $prtKnown = @(Get-PrDescriptionPlaceholderDefaults)
        $prtLines = @(($prtPlacedText -replace "`r`n", "`n") -split "`n" | ForEach-Object { $_.TrimEnd() })
        Assert-True ([bool](@($prtLines | Where-Object { $prtKnown -contains $_ }).Count)) `
            '-Apply: and it carries a line open-pr recognises as the description placeholder'
    }

    # THE BRANCH DOCUMENT IS NOT PLACED, and that is this adopter's half of the lifetime rule (Dave,
    # August 23, 2026). It used to be written here in its reset state, so a consumer's first look at the
    # folder was also their reference. The document exists only while a branch is open now, so placing one
    # would hand them a file their own first fold deletes -- the only entry in this list that is not
    # permanently theirs.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c2 'dkj-policy\development.md'))) '-Apply: the branch document is NOT placed -- it lives only while a branch is open'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c2 'dkj-policy\branch'))) '-Apply: and no branch/ directory is placed any more'
    # NEITHER IS THE AUDIENCE ROOT (issue #1150). It was placed as a .gitkeep on the stated ground that
    # "the audience root must exist before the first cut writes into it" -- a premise cut-release itself
    # contradicts: it creates the note's own parent before writing. So the file bought nothing, while what
    # it did buy was an empty committed directory asserting a destination the unanswered seam did not use.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c2 'dkj-policy\releases\audience'))) '-Apply: the audience root is NOT placed -- the first cut creates it'
    # TWO ASSERTS ON THE SCAFFOLDED RELEASES PAGE WERE DROPPED HERE (#2196), NOT MOVED. They were the
    # regression guard on inbound #786: until August 20, 2026 that page was scaffolded with a
    # '## Release history' heading, a table, and a VUL-IN promising that the cut would insert its rows
    # there -- while this same command's closing advice told the reader to leave Get-ReleaseHistoryPath
    # at the repo root. Two statements in one run that cannot both be true, and the consumer who
    # followed the advice got a table that stays empty forever. The repair was to have the page name
    # the seam's answer instead, and these asserts held it to that.
    #
    # DROPPED RATHER THAN RETARGETED, for the reason #2171's fence asserts were: the page is not
    # scaffolded any more, so there is no document for either claim to be ABOUT. Retargeting them at
    # the changelog would test a page that never carried a history table and never promised one. The
    # #786 defect cannot recur, because its precondition was a scaffolded page making a promise, and
    # this command now makes none. Its coverage is the absence assert in $RetiredScaffoldFiles above.
    # THE CHANGELOG INTRO STATES THE LEVEL THE FOLD ACTUALLY WRITES (inbound #1098). It said '##' while the
    # fold has written '###' since the levels shifted, so the one piece of prose a consumer ever reads ABOUT
    # their own changelog contradicted the first entry three lines below it. Nothing breaks, which is why it
    # survived a release: no gate compares the two, and the first person to notice is somebody debugging why
    # their hand-written '##' entry did not fold.
    #
    # ASSERTED AGAINST Get-EntryHeadingLevel RATHER THAN AGAINST '###'. Pinning the literal would pass while
    # the sentence went stale again at the next shift, which is exactly the failure being repaired -- and it
    # would also turn red for a repo that legitimately overrode the level. The constant is the claim.
    $clText = [System.IO.File]::ReadAllText((Join-Path $c2 'dkj-policy\CHANGELOG.md'), [System.Text.Encoding]::UTF8)
    $entryHashes = '#' * (Get-EntryHeadingLevel)
    # SUPERSEDED BY #2486: there is no intro sentence left to go stale. The scaffolded document IS the fixed
    # head, byte for byte, which retires the #1098 defect by removing the sentence it lived in.
    Assert-Equal ((@(Get-ChangelogHeadLines) -join "`n") + "`n") ($clText -replace "`r`n", "`n") '-Apply: the scaffolded changelog is exactly the fixed head (#2486)'
    Assert-True ($clText -notmatch 'per change') '-Apply: and carries no intro prose about the entry level'

    # AND IT CARRIES THE PENDING HEADING (issue #1518). It did not until September 6, 2026: the intro was
    # followed straight by the entries, the pre-August-26 flat shape, while entry-scaffold-lib called this
    # heading "the heading every un-cut entry sits under" and DEVELOPMENT-portable.md -- which travels to
    # every consumer -- tells them to grep '[Unreleased]' for what a behaviour used to be. In a repo
    # scaffolded here that grep matched nothing. Nothing broke, which is why it survived: both shapes fold
    # and cut correctly, so no gate had anything to say and only a reader following the portable page found
    # out.
    #
    # ASSERTED AGAINST Get-ChangelogUnreleasedHeading, for the same reason the level above is: a repo that
    # translated the label or repointed the entry level must get ITS heading, and a literal would pass while
    # the sentence went stale again.
    $unreleased = Get-ChangelogUnreleasedHeading
    Assert-Match ([regex]::Escape($unreleased)) $clText '-Apply: the scaffolded changelog carries the pending heading'
    Assert-True ($clText -notmatch 'sits under') '-Apply: and no intro sentence points at it -- there is no intro (#2486)'

    # IT IS THE LAST LINE, AND THAT IS THE PLACEMENT RULE RATHER THAN TIDINESS. The first fold into an
    # entry-less document appends at the END of the content (fold-changelog-entry's $listStart fallback), so
    # a heading written anywhere above the intro's closing prose would collect its entries ABOVE itself --
    # the exact mis-placement Get-PreFlatChangelogRefusal exists to refuse, arriving from the scaffold.
    Assert-Equal $unreleased ($clText.TrimEnd() -split "`r?`n")[-1] '-Apply: the pending heading is the last line, so the first fold lands beneath it'

    # AND THE WHOLE DOCUMENT PASSES THE PRE-FLAT GUARD, which is the one check that reads this shape the way
    # the fold and the cut do. A second pending heading, or a stray at that level, is a finding here.
    Assert-Equal '' (Get-PreFlatChangelogRefusal -Content $clText -Consequence 'x') '-Apply: and the scaffolded document is not pre-flat to the shared guard'

    # And the closing block names the two seams only this repo can answer.
    Assert-Match 'Get-ReleaseNoteRoot' $r2.Out '-Apply: the next-steps block names Get-ReleaseNoteRoot'
    Assert-Match 'Get-ReleaseHistoryPath' $r2.Out '-Apply: and Get-ReleaseHistoryPath'

    # --- 3. Additive: a re-run never overwrites what somebody wrote --------------------------------
    # RETARGETED TWICE IN ONE DAY, WHICH IS THE POINT WORTH KEEPING. It pinned
    # dkj-policy\CONTRIBUTING.md until #2171 and dkj-policy\releases\README.md until #2196, and each
    # time for the same reason: the file it named stopped being scaffolder output, so it could no
    # longer stand for "a file the scaffold placed and a re-run must leave alone". Their own coverage
    # is in the legacy-report section below. dkj-policy\CHANGELOG.md is the last file this command
    # places inside the folder, so it is what the general additive contract pins now -- and if that one
    # is ever retired too, this assert has nowhere left to go and the contract it proves is empty.
    Write-Host "adopt-workflow-folder -- re-run keeps every existing file" -ForegroundColor Cyan
    $marker = '# HAND-EDITED -- the scaffold must never win over this line'
    [System.IO.File]::WriteAllText((Join-Path $c2 'dkj-policy\CHANGELOG.md'), $marker)
    $r3 = Invoke-Adopt -Dir $c2 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r3.Code 're-run: exit 0'
    Assert-Match '\[exists\]\s+dkj-policy/CHANGELOG\.md' $r3.Out 're-run: the edited file is reported as left alone'
    $kept = [System.IO.File]::ReadAllText((Join-Path $c2 'dkj-policy\CHANGELOG.md'), [System.Text.Encoding]::UTF8)
    Assert-Equal $marker $kept 're-run: the hand-edited content survives byte for byte'

    # AND THE SAME FOR THE PR TEMPLATE, asserted separately because it is the file most likely to be
    # already there and the only one placed as a verbatim copy (#1843). A consumer who has been running
    # this workflow for months has their own -- with their checkboxes, their sections, possibly an older
    # placeholder this script's own matcher still recognises on purpose. Overwriting it would replace a
    # working form with a one-line stub and take their PR body's whole structure with it.
    $prtMine = "<!-- MY OWN TEMPLATE -- the scaffold must never win over this -->`n`n## Checklist`n- [ ] mine"
    [System.IO.File]::WriteAllText((Join-Path $c2 $prtRel), $prtMine)
    $r3b = Invoke-Adopt -Dir $c2 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r3b.Code 're-run: exit 0 with a PR template already present'
    Assert-Match '\[exists\]\s+\.github/pull_request_template\.md' $r3b.Out 're-run: the consumer PR template is reported as left alone'
    Assert-Equal $prtMine ([System.IO.File]::ReadAllText((Join-Path $c2 $prtRel), [System.Text.Encoding]::UTF8)) `
        're-run: the consumer PR template survives byte for byte'

    # --- 4. THE SOURCE OF THIS WORKFLOW is refused ---------------------------------------------------
    Write-Host "adopt-workflow-folder -- refused in the source of this workflow" -ForegroundColor Cyan
    $c4 = New-FixtureConsumer -Label 'source' -AsWorkflowSource
    $r4 = Invoke-Adopt -Dir $c4 -ScriptArgs @('-Apply')
    Assert-Equal 1 $r4.Code 'workflow source: exit 1'
    Assert-Match 'REFUSED' $r4.Out 'workflow source: says it is refusing, and why'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c4 'dkj-policy'))) 'workflow source: nothing was written'

    # --- 4b. A repo that publishes OTHER plugins is NOT refused (issue #998) -------------------------
    # THE CASE THIS SCRIPT USED TO GET WRONG, and the harm was concrete: the refusal was `Test-Path
    # marketplace.json`, so a repo publishing an unrelated product was told it "arranges
    # dkj-policy/ by hand" and turned away from the one command that scaffolds the folder it
    # needs. Under Dave's own one-product-one-repository rule that repo is the next product, and it
    # consumes this workflow like any other consumer.
    Write-Host "adopt-workflow-folder -- a repo publishing OTHER plugins is a consumer" -ForegroundColor Cyan
    $cOther = New-FixtureConsumer -Label 'other-source' -AsOtherPluginSource
    $rOther = Invoke-Adopt -Dir $cOther -ScriptArgs @('-Apply')
    Assert-Equal 0 $rOther.Code 'other plugins: exit 0 -- not refused'
    Assert-True ($rOther.Out -notmatch 'REFUSED') 'other plugins: no refusal in the output'
    Assert-True (Test-Path -LiteralPath (Join-Path $cOther 'dkj-policy\CHANGELOG.md')) 'other plugins: the folder really was scaffolded'

    # --- 5. The two generated note roots #914 moved (issue #955) -------------------------------------
    # BOTH DIRECTIONS ARE ASSERTED, and the silent one is the half that matters. A warning that fires
    # unconditionally is one every consumer learns to scroll past, and this block exists precisely
    # BECAUSE the two sibling seams' warnings were noticed. So: it names the resolved roots always, and
    # it warns only where a pre-#914 tree is genuinely still sitting at the repo root.
    #
    # Asserted on Flat, not Out: these phrases sit mid-line in a Write-Host the child wraps at its own
    # width, which is the exact shape that turned seam-lib and internal-note red (#982, #959).
    Write-Host "adopt-workflow-folder -- the two note roots #914 moved" -ForegroundColor Cyan
    $c5 = New-FixtureConsumer -Label 'strandednotes'
    New-Item -ItemType Directory -Path (Join-Path $c5 'releases\development\2.x') -Force | Out-Null
    1..3 | ForEach-Object {
        [System.IO.File]::WriteAllText((Join-Path $c5 "releases\development\2.x\2.$_.0.md"), "note $_")
    }
    New-Item -ItemType Directory -Path (Join-Path $c5 'releases\github\2.x') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $c5 'releases\github\2.x\2.1.0.md'), 'body')
    $r5 = Invoke-Adopt -Dir $c5
    Assert-Equal 0 $r5.Code 'stranded notes: exit 0 -- this is a warning, never a refusal'
    Assert-Match 'Get-ReleaseChangelogNotesRoot ->' $r5.Flat 'stranded notes: the changelog-notes root is named with its resolved answer'
    Assert-Match 'Get-ReleaseGithubNotesRoot' $r5.Flat 'stranded notes: and so is the github-notes root'
    Assert-Match 'a generated-notes tree is still sitting at' $r5.Flat 'stranded notes: the re-adoption warning fires'
    Assert-Match 'releases/development/  -- 3 \.md file' $r5.Flat 'stranded notes: it names the tree AND counts what is in it, so the reader can see the scale'
    Assert-Match 'releases/github/  -- 1 \.md file' $r5.Flat 'stranded notes: for both roots, not just the first'
    Assert-Match 'git mv the tree' $r5.Flat 'stranded notes: and it offers the migrate answer'
    Assert-Match 'define the seam in' $r5.Flat 'stranded notes: and the repoint answer, because both are honest'

    # THE SILENT CASE. A fresh consumer has no such tree and must not be warned about one.
    Write-Host "adopt-workflow-folder -- no stranded tree, no warning" -ForegroundColor Cyan
    $c6 = New-FixtureConsumer -Label 'nonotes'
    $r6 = Invoke-Adopt -Dir $c6
    Assert-Equal 0 $r6.Code 'no stranded tree: exit 0'
    Assert-Match 'Get-ReleaseChangelogNotesRoot ->' $r6.Flat 'no stranded tree: the resolved roots are still named'
    Assert-True ($r6.Flat -notmatch 'a generated-notes tree is still sitting at') 'no stranded tree: and the warning stays silent'

    # --- 6. The note-root seam: answered for a fresh adoption, never for anybody else (issue #1150) ---
    # THE CONTRADICTION THIS BLOCK GUARDS. This command scaffolded dkj-policy/releases/audience/
    # and its own pages said the cut drafts the note there, while Get-ReleaseNoteRoot's shared fallback
    # writes to releases/notes/ at the repo root. Both statements are produced by the same run, so one
    # clean adoption plus one clean release left a fresh consumer with an empty committed directory and
    # their note outside the folder the adoption had just built.
    #
    # ALL FOUR BRANCHES ARE ASSERTED, and the three that DECLINE are the half that matters -- the write is
    # only safe because it is narrow, so a test that covered the write alone would pass while the guard
    # rotted.
    #
    # EACH CASE USED TO ALSO ASSERT WHAT THE SCAFFOLDED CONTRIBUTING.md SAID about that same destination,
    # because a page naming a destination the seam does not resolve to was the defect itself rather than a
    # side effect of it. That half is DROPPED here, not rewritten (#2171, September 20, 2026): the page
    # those asserts read no longer exists -- this command scaffolds no CONTRIBUTING.md at all any more --
    # and there is no other page for the same sentence to be reworded onto, so the only honest options were
    # dropping the assert or inventing a page to hang it on. What the three cases below still pin is the
    # part of #1150 that is unaffected by #2171: whether Get-ReleaseNoteRoot itself gets answered.

    Write-Host "adopt-workflow-folder -- fresh adoption: the note-root seam is answered" -ForegroundColor Cyan
    $c7 = New-FixtureConsumer -Label 'seam-fresh' -WithRepoConfig
    $r7 = Invoke-Adopt -Dir $c7 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r7.Code 'seam fresh: exit 0'
    $cfg7 = [System.IO.File]::ReadAllText((Join-Path $c7 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
    Assert-Match 'function Get-ReleaseNoteRoot' $cfg7 'seam fresh: the answer was written into scripts/repo-config.ps1'
    Assert-Match "'dkj-policy/releases/audience'" $cfg7 'seam fresh: and it points into the folder this run just scaffolded'
    # THE GENERATED SOURCE IS PARSED, not merely matched. This block writes PowerShell into somebody
    # else's lib, and the failure mode it already produced once in development is a file that greps
    # correctly and does not parse -- an array literal splits an unparenthesised 'a' + $x + 'b' into three
    # elements, so -join wrote the seam's own path across three lines as an unterminated string. A regex
    # assert passes on that; every later run of every shared script does not.
    $perr = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $c7 'scripts\repo-config.ps1'), [ref]$null, [ref]$perr) | Out-Null
    Assert-Equal 0 @($perr).Count 'seam fresh: the lib it wrote into still parses as PowerShell'
    # THE APPEND MUST NOT RE-ENCODE THEIR FILE. Read-modify-write would strip the BOM the fixture wrote,
    # silently, in a command whose whole job here is to ADD one function -- and on a .ps1 that BOM is what
    # keeps 5.1 from decoding the file as the system ANSI code page.
    $head7 = [System.IO.File]::ReadAllBytes((Join-Path $c7 'scripts\repo-config.ps1'))[0..2]
    Assert-Equal '239-187-191' ($head7 -join '-') 'seam fresh: their file''s byte-order mark survived the append'

    Write-Host "adopt-workflow-folder -- notes already at the fallback: the seam is left alone" -ForegroundColor Cyan
    $c8 = New-FixtureConsumer -Label 'seam-hasnotes' -WithRepoConfig -WithFallbackNotes
    $r8 = Invoke-Adopt -Dir $c8 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r8.Code 'seam has-notes: exit 0 -- declining is never a refusal'
    $cfg8 = [System.IO.File]::ReadAllText((Join-Path $c8 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
    Assert-True ($cfg8 -notmatch 'Get-ReleaseNoteRoot') 'seam has-notes: NOTHING was written into their lib'
    Assert-True (Test-Path -LiteralPath (Join-Path $c8 'releases\notes\0.x\0.1.0.md')) 'seam has-notes: and their existing note was not touched'
    Assert-Match 'left UNANSWERED' $r8.Flat 'seam has-notes: the run says out loud that it declined'

    Write-Host "adopt-workflow-folder -- an answer already given always wins" -ForegroundColor Cyan
    $c9 = New-FixtureConsumer -Label 'seam-answered' -NoteRootAnswer 'my/own/notes'
    $r9 = Invoke-Adopt -Dir $c9 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r9.Code 'seam answered: exit 0'
    $cfg9 = [System.IO.File]::ReadAllText((Join-Path $c9 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
    Assert-Equal 1 ([regex]::Matches($cfg9, 'function Get-ReleaseNoteRoot').Count) 'seam answered: their function was not duplicated or overwritten'
    Assert-Match 'already answered here' $r9.Flat 'seam answered: the run reports it as left alone'

    # NO LIB TO WRITE INTO. specialists-init owns that file's existence, exactly as adopt-config says when
    # it stops -- so this run scaffolds the folder and reports the seam instead of half-creating a lib.
    Write-Host "adopt-workflow-folder -- no repo-config.ps1: the folder still lands, the seam is reported" -ForegroundColor Cyan
    $c10 = New-FixtureConsumer -Label 'seam-noconfig'
    $r10 = Invoke-Adopt -Dir $c10 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r10.Code 'seam no-config: exit 0'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c10 'scripts\repo-config.ps1'))) 'seam no-config: no lib was conjured up'
    Assert-True (Test-Path -LiteralPath (Join-Path $c10 'dkj-policy\CHANGELOG.md')) 'seam no-config: the folder was scaffolded anyway'
    Assert-Match 'has no scripts/repo-config\.ps1' $r10.Flat 'seam no-config: and the run says why the seam is unanswered'

    # --- WHAT USED TO BE HERE: the UPDATE-section fence (#1766) and its CRLF coverage (#1829) --------
    # Sections 11 through 13 lived in this exact spot until #2171 (September 20, 2026): the fresh/
    # re-run/top-up/replace/pre-fence-legacy states of the README's refreshable "Updating the plugins"
    # block, and the CRLF byte-exactness pass over all of it. Every one of those asserts read or wrote
    # dkj-policy\README.md AS SCAFFOLDER OUTPUT, and proved a mechanism -- the fenced block this run
    # rewrote on every -Apply -- that no longer exists in the script at all: adopt-workflow-folder.ps1
    # scaffolds no README.md any more, so there is no page for a fence to sit in and nothing left for
    # any of these asserts to be ABOUT.
    #
    # DROPPED RATHER THAN BENT INTO SOMETHING ELSE, on purpose. Every candidate rewrite -- pointing the
    # fence asserts at releases/README.md instead, or inventing a new fenced region there to keep the
    # mechanism exercised -- would have tested a feature the script does not have, on a file the script
    # was never asked to refresh. That is not what dropping these represents: it says a real capability
    # is gone from the surface, not that it was renamed. Nothing here should read this gap as an
    # oversight; it is the point of the branch this suite was rewritten for.

    # --- 7. The legacy report: an existing retired page is reported, never touched -----------------
    # WHAT REPLACED THE FENCE (#2171, widened by #2196). Where the fence used to keep a scaffolded
    # README's UPDATE section current across a re-run, the three pages themselves are retired: none is
    # placed on a fresh adoption any more, and an EXISTING copy -- left over from before those changes,
    # or from a consumer who wrote one by hand -- is reported with a one-line `[legacy]` verdict plus
    # explanatory lines, and never created, deleted, or rewritten. Three states, because each is a
    # different code path in the script: no file present (nothing to report), all present (all
    # reported, all survive), and some present (only the ones that exist are named).
    #
    # releases/README.md IS ASSERTED IN THE SAME CASES AS THE OTHER TWO AND NOT IN A BLOCK OF ITS OWN.
    # It is the same $legacyPages list and the same loop in the script, so a separate section would
    # prove the same code path a second time -- and would let a widening that reaches only two of the
    # three pass, which asserting all three in one run is what catches. Its extra property is the one
    # the other two do not have: it sits one directory DOWN, so the script's path join is exercised
    # rather than assumed.
    Write-Host "adopt-workflow-folder -- the legacy report on an existing retired page" -ForegroundColor Cyan

    # (a) NO FILE PRESENT: a fresh consumer. Nothing about any legacy page is printed, and none is
    # created -- covered above in section 1 (dry run) and section 2 (-Apply), via
    # $RetiredScaffoldFiles, so it is not repeated a third time here. What follows is the two states
    # that DO exist to report on.

    # (b) ALL THREE PRESENT, WITH ARBITRARY CONTENT: the important case, because it is the one where a
    # regression would silently start rewriting or deleting a consumer's own page again.
    $c17 = New-FixtureConsumer -Label 'legacy-both'
    New-Item -ItemType Directory -Path (Join-Path $c17 'dkj-policy') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $c17 'dkj-policy\releases') -Force | Out-Null
    $legacyReadme = "# Our own dkj-policy folder`r`n`r`nWritten long before #2171, in our own words.`r`n"
    $legacyContributing = "# Our own CONTRIBUTING`n`nArbitrary content, no BOM, no relation to anything this script writes.`n"
    $legacyReleases = "# Our own releases page`r`n`r`nOur seam answers, written before #2196.`r`n"
    [System.IO.File]::WriteAllText((Join-Path $c17 'dkj-policy\README.md'), $legacyReadme, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $c17 'dkj-policy\CONTRIBUTING.md'), $legacyContributing, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $c17 'dkj-policy\releases\README.md'), $legacyReleases, (New-Object System.Text.UTF8Encoding($false)))
    $r17 = Invoke-Adopt -Dir $c17 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r17.Code 'legacy both: exit 0'
    Assert-Match '\[legacy\]\s+dkj-policy/README\.md' $r17.Flat 'legacy both: the README is reported as legacy'
    Assert-Match '\[legacy\]\s+dkj-policy/CONTRIBUTING\.md' $r17.Flat 'legacy both: and so is CONTRIBUTING'
    Assert-Match '\[legacy\]\s+dkj-policy/releases/README\.md' $r17.Flat 'legacy both: and so is the releases page, one directory down'
    Assert-Match 'no longer writes or refreshes it' $r17.Flat 'legacy both: the report names what changed'
    # THE PART THAT MATTERS MOST: BYTE FOR BYTE, after -Apply. A CRLF file with no trailing BOM and an
    # LF file are read back exactly as written, so a rewrite -- even one that only touched line endings
    # or re-encoded the file -- would be caught here.
    $afterReadme17 = [System.IO.File]::ReadAllText((Join-Path $c17 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)
    $afterContributing17 = [System.IO.File]::ReadAllText((Join-Path $c17 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)
    $afterReleases17 = [System.IO.File]::ReadAllText((Join-Path $c17 'dkj-policy\releases\README.md'), [System.Text.Encoding]::UTF8)
    Assert-Equal $legacyReadme $afterReadme17 'legacy both: README.md survives -Apply byte for byte'
    Assert-Equal $legacyContributing $afterContributing17 'legacy both: CONTRIBUTING.md survives -Apply byte for byte'
    Assert-Equal $legacyReleases $afterReleases17 'legacy both: releases/README.md survives -Apply byte for byte'
    # AND NO DELETE COMMAND IS EVER PRINTED (the script's own header says why: several consumers hold
    # these pages today and nothing here can tell a stale scaffold from a repo's only written statement
    # of something it answered).
    Assert-True ($r17.Flat -notmatch 'Remove-Item') 'legacy both: no delete command is printed for any of the three'

    # (c) ONE PRESENT, ONE ABSENT: only the one that exists is named, and the absent one is neither
    # reported nor created.
    $c18 = New-FixtureConsumer -Label 'legacy-onlyreadme'
    New-Item -ItemType Directory -Path (Join-Path $c18 'dkj-policy') -Force | Out-Null
    $onlyReadme = "# Just our README, no CONTRIBUTING here.`n"
    [System.IO.File]::WriteAllText((Join-Path $c18 'dkj-policy\README.md'), $onlyReadme, (New-Object System.Text.UTF8Encoding($false)))
    $r18 = Invoke-Adopt -Dir $c18 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r18.Code 'legacy one-of-two: exit 0'
    Assert-Match '\[legacy\]\s+dkj-policy/README\.md' $r18.Flat 'legacy one-of-two: the present README is reported'
    Assert-True ($r18.Flat -notmatch '\[legacy\]\s+dkj-policy/CONTRIBUTING\.md') 'legacy one-of-two: the absent CONTRIBUTING is not reported'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c18 'dkj-policy\CONTRIBUTING.md'))) 'legacy one-of-two: and it was not created either'
    Assert-Equal $onlyReadme ([System.IO.File]::ReadAllText((Join-Path $c18 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)) `
        'legacy one-of-two: the present README survives -Apply byte for byte'

    # And the mirror image, so the "only the present one is named" claim is proven both ways.
    $c19 = New-FixtureConsumer -Label 'legacy-onlycontributing'
    New-Item -ItemType Directory -Path (Join-Path $c19 'dkj-policy') -Force | Out-Null
    $onlyContributing = "# Just our CONTRIBUTING, no README here.`n"
    [System.IO.File]::WriteAllText((Join-Path $c19 'dkj-policy\CONTRIBUTING.md'), $onlyContributing, (New-Object System.Text.UTF8Encoding($false)))
    $r19 = Invoke-Adopt -Dir $c19 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r19.Code 'legacy other-of-two: exit 0'
    Assert-Match '\[legacy\]\s+dkj-policy/CONTRIBUTING\.md' $r19.Flat 'legacy other-of-two: the present CONTRIBUTING is reported'
    Assert-True ($r19.Flat -notmatch '\[legacy\]\s+dkj-policy/README\.md') 'legacy other-of-two: the absent README is not reported'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c19 'dkj-policy\README.md'))) 'legacy other-of-two: and it was not created either'
    Assert-Equal $onlyContributing ([System.IO.File]::ReadAllText((Join-Path $c19 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)) `
        'legacy other-of-two: the present CONTRIBUTING survives -Apply byte for byte'

    # --- The plugin mirror, run from its OWN depth (issue #1857) -----------------------------------
    # THE RESOLUTION THIS ISSUE WAS FILED ABOUT. The PR-template reference is read from
    # '..\..\templates\pull_request_template.md', with a second candidate one level deeper for the
    # source copy. Two levels up is the PLUGIN root from the mirror and a <repo>\templates that does
    # not exist from here -- so every assert above proves candidate 2, and candidate 1 is the one that
    # fires in every released install. The drift lint holds the two files byte-identical, which is
    # exactly what makes the difference invisible: identical text, different folder, nothing to diff.
    #
    # AND THE FAILURE IS SILENT BY DESIGN. An absent reference places nothing and warns; it does not
    # fall back to a literal. So a mirror that resolved neither candidate would simply omit the
    # template, with every other assert in this suite still green -- which is why what is asserted
    # below is that the file LANDS and matches the shipped reference, not merely that the run exits 0.
    Write-Host ''
    Write-Host 'The plugin mirror'

    $mirrorScript = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\task\adopt-workflow-folder.ps1'
    Assert-True (Test-Path -LiteralPath $mirrorScript -PathType Leaf) 'mirror: it exists at the registered path'

    $cMirror = New-FixtureConsumer -Label 'mirror'
    $rMirror = Invoke-Adopt -Dir $cMirror -ScriptArgs @('-Apply') -ScriptPath $mirrorScript
    Assert-Equal 0 $rMirror.Code 'mirror: exit 0'
    $mirrorPlaced = Join-Path $cMirror $prtRel
    Assert-True (Test-Path -LiteralPath $mirrorPlaced -PathType Leaf) `
        'mirror: the PR template is placed -- candidate 1 resolved from the plugin root, which the root copy can never exercise'
    if ((Test-Path -LiteralPath $mirrorPlaced) -and (Test-Path -LiteralPath $prtRefPath)) {
        $mirrorText = [System.IO.File]::ReadAllText($mirrorPlaced, [System.Text.Encoding]::UTF8)
        $refText    = [System.IO.File]::ReadAllText($prtRefPath, [System.Text.Encoding]::UTF8)
        Assert-Equal ($refText -replace "`r`n", "`n") ($mirrorText -replace "`r`n", "`n") `
            'mirror: and what it placed is the shipped reference, so it read the real artefact rather than any file that happened to be there'
    }
    Assert-True (-not ($rMirror.Flat -match 'could not be found')) `
        'mirror: no "reference could not be found" warning -- the silent branch this resolution fails through did not fire'

    # --- The constitution import in CLAUDE.md (issue #2531) ----------------------------------------
    # The line used to be an instruction plus a session-start warning, and a consumer ran for weeks
    # without it. Five shapes: no CLAUDE.md, an existing one with imports (CRLF + BOM, the harder path),
    # one with prose and no import, one that already imports it, and the dry run that writes nothing.
    Write-Host ''
    Write-Host 'The constitution import'
    $constRx = '^@~/\.claude/plugins/marketplaces/[^/]+/plugins/dkj-policy/CLAUDE\.md$'

    $cC1 = New-FixtureConsumer -Label 'const-none'
    $rC1 = Invoke-Adopt -Dir $cC1 -ScriptArgs @('-Apply')
    Assert-Equal 0 $rC1.Code 'constitution, no CLAUDE.md: exit 0'
    $cC1Md = Join-Path $cC1 'CLAUDE.md'
    Assert-True (Test-Path -LiteralPath $cC1Md -PathType Leaf) 'constitution, no CLAUDE.md: CLAUDE.md is created'
    if (Test-Path -LiteralPath $cC1Md) {
        $cC1Lines = @(([System.IO.File]::ReadAllText($cC1Md)).TrimEnd() -split "`r?`n")
        Assert-Equal 1 $cC1Lines.Count 'constitution, no CLAUDE.md: it holds exactly one line'
        Assert-Match $constRx $cC1Lines[0] 'constitution, no CLAUDE.md: and that line is the constitution import'
    }

    $cC2 = New-FixtureConsumer -Label 'const-crlf'
    $cC2Md = Join-Path $cC2 'CLAUDE.md'
    [System.IO.File]::WriteAllText($cC2Md, "# Title`r`n`r`n@~/.claude/other.md`r`n", (New-Object System.Text.UTF8Encoding($true)))
    $rC2 = Invoke-Adopt -Dir $cC2 -ScriptArgs @('-Apply')
    Assert-Equal 0 $rC2.Code 'constitution, existing imports: exit 0'
    $cC2Bytes = [System.IO.File]::ReadAllBytes($cC2Md)
    Assert-True ($cC2Bytes.Length -ge 3 -and $cC2Bytes[0] -eq 0xEF -and $cC2Bytes[1] -eq 0xBB -and $cC2Bytes[2] -eq 0xBF) `
        'constitution, existing imports: the byte-order mark is kept'
    $cC2Text = [System.IO.File]::ReadAllText($cC2Md)
    Assert-True (($cC2Text -replace "`r`n", '') -notmatch "`n") 'constitution, existing imports: no lone LF lands in a CRLF file'
    $cC2Lines = @($cC2Text -split "`r`n")
    Assert-Equal '# Title' $cC2Lines[0] 'constitution, existing imports: the title stays first'
    Assert-Match $constRx $cC2Lines[2] 'constitution, existing imports: the line lands directly above the first import'
    Assert-Equal '@~/.claude/other.md' $cC2Lines[3] 'constitution, existing imports: and the existing import follows it unchanged'
    $rC2b = Invoke-Adopt -Dir $cC2 -ScriptArgs @('-Apply')
    Assert-Equal $cC2Text ([System.IO.File]::ReadAllText($cC2Md)) 'constitution, existing imports: a re-run changes nothing'
    Assert-Match '\[keep\]\s+CLAUDE\.md already imports' $rC2b.Flat 'constitution, existing imports: and the re-run says it kept it'

    $cC3 = New-FixtureConsumer -Label 'const-prose'
    $cC3Md = Join-Path $cC3 'CLAUDE.md'
    [System.IO.File]::WriteAllText($cC3Md, "# Prose`n`nSome text.`n")
    $null = Invoke-Adopt -Dir $cC3 -ScriptArgs @('-Apply')
    $cC3Lines = @(([System.IO.File]::ReadAllText($cC3Md)).TrimEnd() -split "`n")
    Assert-Equal 'Some text.' $cC3Lines[2] 'constitution, prose only: the existing text is left in place'
    Assert-Match $constRx $cC3Lines[-1] 'constitution, prose only: the line is appended at the end'

    $cC4 = New-FixtureConsumer -Label 'const-done'
    $cC4Md = Join-Path $cC4 'CLAUDE.md'
    $cC4Text = "@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/CLAUDE.md`n"
    [System.IO.File]::WriteAllText($cC4Md, $cC4Text)
    $rC4 = Invoke-Adopt -Dir $cC4 -ScriptArgs @('-Apply')
    Assert-Equal $cC4Text ([System.IO.File]::ReadAllText($cC4Md)) `
        'constitution, already imported under another marketplace name: the file is untouched'
    Assert-Match '\[keep\]\s+CLAUDE\.md already imports' $rC4.Flat 'constitution, already imported: says it kept it'

    # A FOUR-BACKTICK BLOCK WRAPPING A THREE-BACKTICK EXAMPLE: the inner fence must not close the outer
    # one, or the line lands inside the quoted example and imports nothing (Victor's review of #2531).
    $cC6 = New-FixtureConsumer -Label 'const-nested'
    $cC6Md = Join-Path $cC6 'CLAUDE.md'
    $bt3 = '`' * 3; $bt4 = '`' * 4
    [System.IO.File]::WriteAllText($cC6Md, (@('# Title', "${bt4}markdown", $bt3, '@fake/inside.md', $bt3, $bt4, '@real/import.md', '') -join "`n"))
    $null = Invoke-Adopt -Dir $cC6 -ScriptArgs @('-Apply')
    $cC6Lines = @([System.IO.File]::ReadAllText($cC6Md) -split "`n")
    Assert-Equal '@fake/inside.md' $cC6Lines[3] 'constitution, nested fence: the quoted example is untouched'
    Assert-Match $constRx $cC6Lines[6] 'constitution, nested fence: the line lands above the first REAL import'
    Assert-Equal '@real/import.md' $cC6Lines[7] 'constitution, nested fence: and that import follows it'

    # THE LINE QUOTED IN A FENCE IS NOT AN IMPORT -- the skill page itself shows it that way, so a consumer
    # copying the example must still get the real line.
    $cC7 = New-FixtureConsumer -Label 'const-quoted'
    $cC7Md = Join-Path $cC7 'CLAUDE.md'
    [System.IO.File]::WriteAllText($cC7Md, (@('# Ours', $bt3, '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md', $bt3, '') -join "`n"))
    $rC7 = Invoke-Adopt -Dir $cC7 -ScriptArgs @('-Apply')
    Assert-Match '\[added\]' $rC7.Flat 'constitution, quoted in a fence: not mistaken for an import -- the line is added'
    $cC7Lines = @(([System.IO.File]::ReadAllText($cC7Md)).TrimEnd() -split "`n")
    Assert-Match $constRx $cC7Lines[-1] 'constitution, quoted in a fence: appended after the block, not inside it'

    # MIXED LINE ENDINGS SURVIVE BYTE FOR BYTE: only the inserted line is new.
    $cC8 = New-FixtureConsumer -Label 'const-mixed'
    $cC8Md = Join-Path $cC8 'CLAUDE.md'
    $cC8Before = "# T`n`n@~/.claude/a.md`r`n@~/.claude/b.md`n"
    [System.IO.File]::WriteAllText($cC8Md, $cC8Before)
    $null = Invoke-Adopt -Dir $cC8 -ScriptArgs @('-Apply')
    $cC8After = [System.IO.File]::ReadAllText($cC8Md)
    $cC8Line = ([regex]::Match($cC8After, '@~/\.claude/plugins/[^\r\n]*\r\n')).Value
    Assert-True ($cC8Line.Length -gt 0) 'constitution, mixed EOL: the line takes the CRLF of the import it lands above'
    Assert-Equal $cC8Before ($cC8After.Replace($cC8Line, '')) 'constitution, mixed EOL: every other byte is unchanged'

    $cC5 = New-FixtureConsumer -Label 'const-dry'
    $rC5 = Invoke-Adopt -Dir $cC5
    Assert-Match '\[create\]\s+CLAUDE\.md, holding the constitution import' $rC5.Flat 'constitution, dry run: lists CLAUDE.md as to-create'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $cC5 'CLAUDE.md'))) 'constitution, dry run: and does not write it'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
