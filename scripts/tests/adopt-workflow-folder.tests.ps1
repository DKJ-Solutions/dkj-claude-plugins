<#
.SYNOPSIS
    Tests for scripts/task/adopt-workflow-folder.ps1 -- the scaffold that places the workflow's own
    root folder (dkj-policy/) in a consuming repo.

.DESCRIPTION
    What is covered, and why these four:
      1. the DRY RUN default writes nothing -- the same contract adopt-config is trusted on;
      2. -Apply places every file the folder promises, with the branch files in the reset shape the
         shared formatters write -- and the releases page carrying NO history table, since the list
         belongs at the repo root (inbound #786);
      3. a re-run is additive: a file somebody edited is never overwritten, whatever it says;
      4. a repo that publishes plugins is refused -- the source keeps its docs at its root (Dave,
         August 14, 2026), so the scaffold must not build the layout its owner declined.

    The repo root is pinned per child run via CLAUDE_PROJECT_DIR, the same dual-context branch every
    mirrored script resolves first, so the fixtures need no git of their own.

    EVERY FIXTURE BELOW WROTE LF UNTIL INBOUND #1829, and that is how a Windows-only defect lived in
    the one block this suite pins hardest. The page the top-up compares against is read byte-exact,
    so on a CRLF checkout -- core.autocrlf=true, which is the default a Windows consumer clones with
    -- every line of the composed block differed from the identical committed line and the verdict
    read 'drifted' forever. Section 13 is the fixture that has the ending the reporter's checkout
    had; it is not a second reading of section 12.
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
$ExpectedFiles = @(
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
    Assert-Match '\[create\]\s+dkj-policy/README\.md' $r1.Out 'dry run: lists the folder README as to-create'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c1 'dkj-policy'))) 'dry run: the folder was not created'
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
    $gateRel = '.github\workflows\branch-entry.yml'
    Assert-True (Test-Path -LiteralPath (Join-Path $c2 $gateRel) -PathType Leaf) '-Apply: the branch-entry gate workflow is placed'
    . (Join-Path $RepoRoot 'scripts\lib\consumer-runner-lib.ps1')
    $gateRefs = @(Get-SharedScriptReference -WorkflowText ([System.IO.File]::ReadAllText((Join-Path $c2 $gateRel), [System.Text.Encoding]::UTF8)) -RepositoryName 'dkj-claude-plugins')
    Assert-Equal 1 $gateRefs.Count '-Apply: the gate reaches exactly one script out of a checkout of this repo'
    foreach ($judged in @(Test-SharedScriptReference -Reference $gateRefs -SourceRoot $RepoRoot)) {
        Assert-True $judged.Exists "-Apply: the gate runs '$($judged.Path)', and that path EXISTS in this tree"
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
    # THE FOLDER PAGE MUST NOT CARRY A HISTORY TABLE, and this assert is the regression guard on inbound
    # #786. It did until August 20, 2026: the page was scaffolded with a '## Release history' heading, a
    # table, and a VUL-IN promising that the cut would insert its rows there -- while this same command's
    # closing advice told the reader to leave Get-ReleaseHistoryPath at the repo root. Two statements in
    # one run that cannot both be true, and the consumer who followed the advice got a table that stays
    # empty forever. The page now points at the seam's answer instead.
    $relText = [System.IO.File]::ReadAllText((Join-Path $c2 'dkj-policy\releases\README.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($relText -notmatch '\| Version \| Date \| Type \| Title \|') '-Apply: the folder page carries NO history table (the list is not here)'
    # MATCHED ON THE LIST'S OWN PATH, not on 'releases/README.md'. That was the pattern until
# August 27, 2026, and it was passing on the wrong sentence: the scaffolded page names the seam's answer
# in one place and mentioned 'releases/README.md' in another, as a comparison with the source repo's
# layout, so removing the comparison turned this assert red while the thing it checks was untouched. The
# list's filename is what the assert is about.
Assert-Match 'releases/history\.md' $relText '-Apply: it names where the list actually lives instead'
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
    Assert-Match ('one `' + $entryHashes + '` per change') $clText '-Apply: the changelog intro states the heading level the fold writes'
    Assert-True ($clText -notmatch 'one `#{1,2}` per change') '-Apply: and no longer states a shallower one'

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
    Assert-Match ('sits under `' + [regex]::Escape($unreleased) + '`') $clText '-Apply: and the intro sentence points the reader at it'

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
    Write-Host "adopt-workflow-folder -- re-run keeps every existing file" -ForegroundColor Cyan
    $marker = '# HAND-EDITED -- the scaffold must never win over this line'
    [System.IO.File]::WriteAllText((Join-Path $c2 'dkj-policy\CONTRIBUTING.md'), $marker)
    $r3 = Invoke-Adopt -Dir $c2 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r3.Code 're-run: exit 0'
    Assert-Match '\[exists\]\s+dkj-policy/CONTRIBUTING\.md' $r3.Out 're-run: the edited file is reported as left alone'
    $kept = [System.IO.File]::ReadAllText((Join-Path $c2 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)
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
    Assert-True (Test-Path -LiteralPath (Join-Path $cOther 'dkj-policy\README.md')) 'other plugins: the folder really was scaffolded'

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
    # rotted. Each case also asserts what the SCAFFOLDED PAGE says, because that page naming a destination
    # the seam does not resolve to is the defect itself rather than a side effect of it.
    $NoteSentence = 'the cut drafts the hand-written note'

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
    $con7 = [System.IO.File]::ReadAllText((Join-Path $c7 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)
    Assert-Match ('`releases/audience/` is where\s+' + $NoteSentence) $con7 'seam fresh: and the scaffolded page names that same destination'

    Write-Host "adopt-workflow-folder -- notes already at the fallback: the seam is left alone" -ForegroundColor Cyan
    $c8 = New-FixtureConsumer -Label 'seam-hasnotes' -WithRepoConfig -WithFallbackNotes
    $r8 = Invoke-Adopt -Dir $c8 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r8.Code 'seam has-notes: exit 0 -- declining is never a refusal'
    $cfg8 = [System.IO.File]::ReadAllText((Join-Path $c8 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
    Assert-True ($cfg8 -notmatch 'Get-ReleaseNoteRoot') 'seam has-notes: NOTHING was written into their lib'
    Assert-True (Test-Path -LiteralPath (Join-Path $c8 'releases\notes\0.x\0.1.0.md')) 'seam has-notes: and their existing note was not touched'
    Assert-Match 'left UNANSWERED' $r8.Flat 'seam has-notes: the run says out loud that it declined'
    $con8 = [System.IO.File]::ReadAllText((Join-Path $c8 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)
    Assert-Match ('`releases/notes/` at your repo root is where\s+' + $NoteSentence) $con8 'seam has-notes: and the page names where their notes ACTUALLY go'

    Write-Host "adopt-workflow-folder -- an answer already given always wins" -ForegroundColor Cyan
    $c9 = New-FixtureConsumer -Label 'seam-answered' -NoteRootAnswer 'my/own/notes'
    $r9 = Invoke-Adopt -Dir $c9 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r9.Code 'seam answered: exit 0'
    $cfg9 = [System.IO.File]::ReadAllText((Join-Path $c9 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
    Assert-Equal 1 ([regex]::Matches($cfg9, 'function Get-ReleaseNoteRoot').Count) 'seam answered: their function was not duplicated or overwritten'
    Assert-Match 'already answered here' $r9.Flat 'seam answered: the run reports it as left alone'
    $con9 = [System.IO.File]::ReadAllText((Join-Path $c9 'dkj-policy\CONTRIBUTING.md'), [System.Text.Encoding]::UTF8)
    Assert-Match ('`my/own/notes/` at your repo root is where\s+' + $NoteSentence) $con9 'seam answered: and the page names THEIR answer, not the source''s'

    # NO LIB TO WRITE INTO. specialists-init owns that file's existence, exactly as adopt-config says when
    # it stops -- so this run scaffolds the folder and reports the seam instead of half-creating a lib.
    Write-Host "adopt-workflow-folder -- no repo-config.ps1: the folder still lands, the seam is reported" -ForegroundColor Cyan
    $c10 = New-FixtureConsumer -Label 'seam-noconfig'
    $r10 = Invoke-Adopt -Dir $c10 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r10.Code 'seam no-config: exit 0'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c10 'scripts\repo-config.ps1'))) 'seam no-config: no lib was conjured up'
    Assert-True (Test-Path -LiteralPath (Join-Path $c10 'dkj-policy\README.md')) 'seam no-config: the folder was scaffolded anyway'
    Assert-Match 'has no scripts/repo-config\.ps1' $r10.Flat 'seam no-config: and the run says why the seam is unanswered'

    # --- 11. The UPDATE section: placed fresh, topped up when missing, left alone when present ------
    # THE ONE WRITE THIS COMMAND MAKES INTO A FILE IT DID NOT CREATE, so every branch is pinned: a fresh
    # scaffold carries it, an existing page without it gets it appended, an existing page WITH it is
    # untouched, and a dry run over a page without it writes nothing while still saying so. The
    # untouched case is the assert that matters most -- a top-up that ran twice would grow the page on
    # every re-run, and a re-run finding nothing to do is the promise this whole command makes.
    Write-Host "adopt-workflow-folder -- the UPDATE section is placed, and never placed twice" -ForegroundColor Cyan
    $Marker = '<!-- dkj-policy:update-section -->'

    $c11 = New-FixtureConsumer -Label 'update-fresh'
    $r11 = Invoke-Adopt -Dir $c11 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r11.Code 'update fresh: exit 0'
    $readme11 = [System.IO.File]::ReadAllText((Join-Path $c11 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)
    Assert-Match ([regex]::Escape($Marker)) $readme11 'update fresh: the scaffolded README carries the marker'
    Assert-Match '## Updating the plugins' $readme11 'update fresh: and the section heading'
    Assert-Match 'claude plugin marketplace update' $readme11 'update fresh: the refresh command is in it'
    Assert-Match '--scope project' $readme11 'update fresh: and the scope flag, which is the half a reader drops'
    # THE REFRESH BEFORE THE UPDATE, not merely both present: a printed update without the refresh beside
    # it is the doc defect the source repo's lint gate refuses, and this page is generated rather than
    # written, so nothing else would ever read it.
    Assert-True ($readme11.IndexOf('claude plugin marketplace update') -lt $readme11.IndexOf('claude plugin update ')) `
        'update fresh: the refresh is printed BEFORE the per-plugin update'

    # A RE-RUN OVER THE PAGE IT JUST WROTE. Two runs, one section.
    $r11b = Invoke-Adopt -Dir $c11 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r11b.Code 'update re-run: exit 0'
    $readme11b = [System.IO.File]::ReadAllText((Join-Path $c11 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)
    Assert-Equal 1 ([regex]::Matches($readme11b, [regex]::Escape($Marker)).Count) 'update re-run: still exactly one section'
    Assert-Equal $readme11 $readme11b 'update re-run: the page was not touched at all'
    Assert-Match 'already carries the current block' $r11b.Flat 'update re-run: and it says so rather than staying silent'
    # AND PURE LF, which is what keeps #1829's repair from being a one-platform fix: the style is read
    # off the page, so a page with no CR in it is still written without one. Asserted here rather than
    # in section 13 because this run has already applied the repaired script to an LF page -- the fact
    # was there to be read, not to be measured again in a fresh process (Nolan, on this branch).
    Assert-Equal 0 ([regex]::Matches($readme11b, "`r").Count) 'update re-run: and the page is still pure LF -- no CR was introduced'

    # THE CASE THIS BLOCK EXISTS FOR: a repo that adopted BEFORE the section existed. Its README is its
    # own writing with no marker anywhere -- the state every already-adopted consumer is in.
    Write-Host "adopt-workflow-folder -- an already-adopted README is topped up, not rewritten" -ForegroundColor Cyan
    $c12 = New-FixtureConsumer -Label 'update-topup'
    New-Item -ItemType Directory -Path (Join-Path $c12 'dkj-policy') -Force | Out-Null
    $ownReadme = "# ``dkj-policy/`` -- our folder`n`nWe wrote this ourselves, before the section existed.`n"
    [System.IO.File]::WriteAllText((Join-Path $c12 'dkj-policy\README.md'), $ownReadme, (New-Object System.Text.UTF8Encoding($false)))

    # Dry run first: it reports the top-up and changes nothing.
    $r12dry = Invoke-Adopt -Dir $c12
    Assert-Equal 0 $r12dry.Code 'update topup dry: exit 0'
    Assert-Match 'has no plugin block' $r12dry.Flat 'update topup dry: the run names what it would append'
    Assert-Equal $ownReadme ([System.IO.File]::ReadAllText((Join-Path $c12 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)) `
        'update topup dry: and wrote nothing'

    $r12 = Invoke-Adopt -Dir $c12 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r12.Code 'update topup: exit 0'
    Assert-Match "the plugin's block was appended" $r12.Flat 'update topup: the run reports the append'
    $readme12 = [System.IO.File]::ReadAllText((Join-Path $c12 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)
    Assert-Match ([regex]::Escape($Marker)) $readme12 'update topup: the section is there now'
    # THEIR OWN WRITING SURVIVES BYTE FOR BYTE, and it still leads: this is an append, not a merge.
    Assert-True $readme12.StartsWith($ownReadme) 'update topup: their page is untouched and still first'
    Assert-Equal 1 ([regex]::Matches($readme12, [regex]::Escape($Marker)).Count) 'update topup: exactly one section was added'
    # BOTH HALVES OF THE EXCEPTION AT ONCE: the loop still leaves the FILE alone while this block appends
    # to it, which is what keeps the append bounded rather than a rewrite in disguise.
    Assert-Match '\[exists\]\s+dkj-policy/README\.md' $r12.Out 'update topup: the file itself was still left as it is'

    # --- 12. The fence: the plugin's block is REPLACED, and only between its own markers (#1766) -----
    # THE SECOND BOUNDED EXCEPTION TO "NEVER REWRITES", so every edge of it is pinned. The append closed
    # "a section added later never arrives"; it never closed "a section that arrived is never
    # CORRECTED", which is the half a consumer reported -- their page still named the branch document
    # `development.md` and still carried two pre-rename plugin ids, all of it this scaffold's own
    # generated writing sitting in a file it had promised not to touch again.
    Write-Host "adopt-workflow-folder -- the plugin's block is refreshed between its markers" -ForegroundColor Cyan
    $EndMarker = '<!-- /dkj-policy:update-section -->'

    Assert-Match ([regex]::Escape($EndMarker)) $readme11 'fence: the scaffolded README carries the closing marker too'
    Assert-Match 'plugin-versions' $readme11 'fence: and answers the version question with a command, not a number'
    Assert-True ($readme11.IndexOf($Marker) -lt $readme11.IndexOf($EndMarker)) 'fence: opening marker comes first'

    # THE REPLACE ITSELF. The repo's own writing is put BELOW the block and the block is then corrupted
    # by hand; a re-run must restore the block and leave both sides byte for byte.
    $c13 = New-FixtureConsumer -Label 'fence-replace'
    $r13 = Invoke-Adopt -Dir $c13 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r13.Code 'fence replace: scaffold exit 0'
    $p13 = Join-Path $c13 'dkj-policy\README.md'
    $fresh13 = [System.IO.File]::ReadAllText($p13, [System.Text.Encoding]::UTF8)

    $s13 = $fresh13.IndexOf($Marker)
    $e13 = $fresh13.IndexOf($EndMarker) + $EndMarker.Length
    $head13 = $fresh13.Substring(0, $s13)
    $ourTail = "`n`n## Our own notes`n`nWritten by this repo, below the block.`n"
    $stale = $head13 + $Marker + "`n## Updating the plugins`n`nstale: development.md, dkj-team-alpha`n" + $EndMarker + $ourTail
    [System.IO.File]::WriteAllText($p13, $stale, (New-Object System.Text.UTF8Encoding($false)))

    # Dry run reports the drift and writes nothing -- the contract every other branch here has.
    $r13dry = Invoke-Adopt -Dir $c13
    Assert-Match 'would be replaced' $r13dry.Flat 'fence replace dry: the run names what it would do'
    Assert-Equal $stale ([System.IO.File]::ReadAllText($p13, [System.Text.Encoding]::UTF8)) 'fence replace dry: and wrote nothing'

    $r13b = Invoke-Adopt -Dir $c13 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r13b.Code 'fence replace: exit 0'
    Assert-Match 'brought up to date' $r13b.Flat 'fence replace: the run says the block was refreshed'
    $after13 = [System.IO.File]::ReadAllText($p13, [System.Text.Encoding]::UTF8)
    Assert-True ($after13 -notmatch 'dkj-team-alpha') 'fence replace: the stale content is gone'
    Assert-True $after13.EndsWith($ourTail) 'fence replace: the repo''s own writing below the block survives byte for byte'
    Assert-True $after13.StartsWith($head13.TrimEnd("`r", "`n")) 'fence replace: and everything above it survives too'
    Assert-Equal 1 ([regex]::Matches($after13, [regex]::Escape($Marker)).Count) 'fence replace: still exactly one block'

    # IDEMPOTENT: a second run over a block already current writes nothing and says so. A refresh that
    # rewrote on every run would re-encode a file it has no other reason to touch, on every adoption.
    $r13c = Invoke-Adopt -Dir $c13 -ScriptArgs @('-Apply')
    Assert-Match 'already carries the current block' $r13c.Flat 'fence idempotent: a current block is left alone'
    Assert-Equal $after13 ([System.IO.File]::ReadAllText($p13, [System.Text.Encoding]::UTF8)) 'fence idempotent: and the file is untouched'

    # STATE 3 -- THE PRE-FENCE PAGE, which is what makes the fence safe rather than a licence. An opening
    # marker with no closing one has no machine-readable end, so cutting "to the end of the file" would
    # take the repo's own writing with it. Left alone and reported.
    Write-Host "adopt-workflow-folder -- a pre-fence section is left alone, not guessed at" -ForegroundColor Cyan
    $c14 = New-FixtureConsumer -Label 'fence-legacy'
    New-Item -ItemType Directory -Path (Join-Path $c14 'dkj-policy') -Force | Out-Null
    $legacy = "# dkj-policy`n`nOurs.`n`n$Marker`n## Updating the plugins`n`nthe old one-shot section`n`n## Our own section`n`nwritten after it, and it must survive`n"
    [System.IO.File]::WriteAllText((Join-Path $c14 'dkj-policy\README.md'), $legacy, (New-Object System.Text.UTF8Encoding($false)))
    $r14 = Invoke-Adopt -Dir $c14 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r14.Code 'fence legacy: exit 0'
    Assert-Match 'from before it was fenced' $r14.Flat 'fence legacy: the run names the state'
    Assert-Match 'delete the' $r14.Flat 'fence legacy: and the one thing the reader can do about it'
    Assert-Equal $legacy ([System.IO.File]::ReadAllText((Join-Path $c14 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)) `
        'fence legacy: the page is untouched, including the section written after the marker'

    # --- 13. A CRLF PAGE: the verdict is about the block, not about the line endings (inbound #1829) --
    # THE STATE EVERY WINDOWS CONSUMER IS IN. core.autocrlf=true is what a Windows clone defaults to,
    # so the committed LF page arrives on disk CRLF -- and the compare that decides this block's whole
    # verdict reads the file byte-exact. Measured in a consumer: 'drifted' on every fresh checkout,
    # -Apply reporting a top-up, and `git diff` empty afterwards. Both halves are pinned here, because
    # each fails on its own: the VERDICT must read 'current', and a page that genuinely IS stale must
    # still be replaced -- a compare repaired by normalising both sides would pass the first assert
    # and then write LF into the page anyway, which is the mixed file the defect already produced.
    # THE FIXTURE IS SEEDED FROM $readme11, NOT SCAFFOLDED AGAIN (Nolan, on this branch). Every
    # Invoke-Adopt here is a real child process at ~440ms, so a spawn that only produces bytes this
    # suite is already holding is 440ms of gate and CI time on every PR. $readme11 IS the page the
    # scaffold writes -- section 11 read it off disk -- so converting a copy of it is the same fixture
    # one process cheaper, and it stays in step if that page's content ever changes.
    Write-Host "adopt-workflow-folder -- a CRLF page is judged on its block, and rewritten in its own endings" -ForegroundColor Cyan
    $c15 = New-FixtureConsumer -Label 'crlf-page'
    New-Item -ItemType Directory -Path (Join-Path $c15 'dkj-policy') -Force | Out-Null
    $p15 = Join-Path $c15 'dkj-policy\README.md'

    # The page exactly as autocrlf=true checks it out. Nothing about it changes but the line endings --
    # these are the bytes section 11 asserted 'nothing to do' on, one conversion over.
    $crlf15 = (($readme11 -replace "`r`n", "`n") -replace "`n", "`r`n")
    [System.IO.File]::WriteAllText($p15, $crlf15, (New-Object System.Text.UTF8Encoding($false)))
    Assert-True ($crlf15 -ne $readme11) 'crlf: the fixture really is a different byte sequence than the LF page'

    # ONE RUN PROVES BOTH FACTS, so there is no dry run beside it: the script's 'already carries the
    # current block' branch is decided by `$rebuilt -eq $existingReadme` and never consults $Apply, so a
    # dry run over a current page reaches the identical line and writes nothing either. An -Apply run
    # therefore pins the verdict AND that the page is left byte for byte, which is the stronger pair.
    $r15c = Invoke-Adopt -Dir $c15 -ScriptArgs @('-Apply')
    Assert-Match 'already carries the current block' $r15c.Flat 'crlf: the current block reads as current, not as drift'
    Assert-True ($r15c.Flat -notmatch 'drifted') 'crlf: and no drift is reported'
    Assert-Equal $crlf15 ([System.IO.File]::ReadAllText($p15, [System.Text.Encoding]::UTF8)) `
        'crlf: -Apply over a current CRLF page leaves it byte for byte'

    # THE OTHER HALF: a CRLF page whose block IS stale is still replaced, and the page it gets back is
    # CRLF throughout. A bare LF anywhere in it is the mixed state the defect produced -- git normalises
    # it away under autocrlf and reports nothing, so this assert is the only reader that would see it.
    $s15 = $crlf15.IndexOf($Marker)
    $e15 = $crlf15.IndexOf($EndMarker) + $EndMarker.Length
    $stale15 = $crlf15.Substring(0, $s15) + $Marker + "`r`n## Updating the plugins`r`n`r`nstale: development.md`r`n" +
               $EndMarker + "`r`n`r`n## Ours`r`n`r`nbelow the block, in CRLF.`r`n"
    [System.IO.File]::WriteAllText($p15, $stale15, (New-Object System.Text.UTF8Encoding($false)))
    $r15d = Invoke-Adopt -Dir $c15
    Assert-Match 'would be replaced' $r15d.Flat 'crlf stale: a genuinely stale CRLF block is still reported'
    # THE DRY-RUN CONTRACT ON A CRLF PAGE, asserted here because this is the one dry run this section
    # still spawns -- the 'current page' case above no longer needs one, and dropping the assert with
    # the spawn would have quietly taken this half of the coverage with it.
    Assert-Equal $stale15 ([System.IO.File]::ReadAllText($p15, [System.Text.Encoding]::UTF8)) `
        'crlf stale dry: and wrote nothing'
    $r15e = Invoke-Adopt -Dir $c15 -ScriptArgs @('-Apply')
    Assert-Match 'brought up to date' $r15e.Flat 'crlf stale: and replaced'
    $after15 = [System.IO.File]::ReadAllText($p15, [System.Text.Encoding]::UTF8)
    Assert-True ($after15 -notmatch 'development\.md') 'crlf stale: the stale content is gone'
    Assert-Equal 0 ([regex]::Matches($after15, "(?<!`r)`n").Count) 'crlf stale: the rewritten page carries no bare LF -- no mixed endings'
    Assert-True $after15.EndsWith("## Ours`r`n`r`nbelow the block, in CRLF.`r`n") 'crlf stale: and the repo''s own writing below the block survives'

    # STATE 4 ON A CRLF PAGE -- the append, which is where a consumer's FIRST adoption goes. It has no
    # verdict to get wrong, so nothing above reaches it: the state-2 asserts all need a page that
    # already carries both markers, and section 11's append fixture is pure LF. Without this, reverting
    # the append's $pageNl alone would pass every other assert in this suite (Victor, on this branch).
    $c16 = New-FixtureConsumer -Label 'crlf-append'
    New-Item -ItemType Directory -Path (Join-Path $c16 'dkj-policy') -Force | Out-Null
    $ownCrlf = "# ``dkj-policy/`` -- our folder`r`n`r`nWe wrote this ourselves, on Windows.`r`n"
    [System.IO.File]::WriteAllText((Join-Path $c16 'dkj-policy\README.md'), $ownCrlf, (New-Object System.Text.UTF8Encoding($false)))
    $r16 = Invoke-Adopt -Dir $c16 -ScriptArgs @('-Apply')
    Assert-Match "the plugin's block was appended" $r16.Flat 'crlf append: the block is appended to a CRLF page'
    $after16 = [System.IO.File]::ReadAllText((Join-Path $c16 'dkj-policy\README.md'), [System.Text.Encoding]::UTF8)
    Assert-True $after16.StartsWith($ownCrlf) 'crlf append: their own writing survives byte for byte and still leads'
    Assert-Match ([regex]::Escape($Marker)) $after16 'crlf append: the block is there'
    Assert-Equal 0 ([regex]::Matches($after16, "(?<!`r)`n").Count) 'crlf append: and the appended block carries no bare LF'
    # AND THE VERDICT IT LEAVES BEHIND IS 'CURRENT' -- the append and the compare have to agree about the
    # style, or a first adoption reports drift on its second run.
    $r16b = Invoke-Adopt -Dir $c16
    Assert-Match 'already carries the current block' $r16b.Flat 'crlf append: the page it just wrote reads as current'

    # THE OTHER HALF OF "not a one-platform fix" -- that an LF page is still judged current and still
    # written pure LF -- IS PINNED IN SECTION 11 AND NOT RE-SPAWNED HERE. Its re-run already applies the
    # repaired script to an LF page, reads the result off disk and compares it byte for byte; the only
    # thing missing was the CR count, which is an assert on bytes this suite already holds rather than a
    # reason to start a sixth process (Nolan, on this branch). A copy here would have been the same
    # fixture, in the same state, one process later.
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
