<#
.SYNOPSIS
    Tests for specialists-teardown: the round-trip with the bootstrap, and the safety properties.

.DESCRIPTION
    The interesting assertions here are the NEGATIVE ones. A teardown that removes plenty is easy; one
    that can be trusted on somebody's repo has to demonstrably NOT touch authored content, NOT edit
    settings.json, and NOT eat an unrelated @-import that happens to share the line shape.

    Dependency-free (no Pester), exit 1 on the first failure, same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Plugin    = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha'
$Bootstrap = Join-Path $Plugin 'skills\specialists-init\bootstrap.ps1'
$Teardown  = Join-Path $Plugin 'skills\specialists-teardown\teardown.ps1'
$Fixture   = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-teardown-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Invoke-Script {
    param([string]$Path, [string[]]$ScriptArgs = @())
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ScriptArgs 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

# Builds a consumer with its OWN CLAUDE.md content, then bootstraps it. -ExtraClaudeMdLines lets a case
# add lines the bootstrap did not write, which is how the unrelated-@-import case is built.
# EVERY FIXTURE IN THIS SUITE ENABLES BOTH PLUGINS SINCE AUGUST 8, 2026. The suite is about a consumer
# that adopted the system and then disconnects, and its round trips turn on the script-config scaffolds:
# the [keep] lines for an already-occupied address, the "2 already present" count, and the scripts\lib\
# empty-directory pruning from #331. After the workflow split none of those exist for a consumer that
# never enabled the workflow plugin -- branch-info.ps1 is that pack's file and is not placed without it --
# so a single-plugin fixture would leave three assertions passing vacuously. The core-only shape is
# covered in bootstrap-drift.tests.ps1 instead of being folded in here.
function New-BootstrappedConsumer {
    param([string[]]$ExtraClaudeMdLines = @())
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true } }')
    $md = @('# CLAUDE.md - my own project', '', '## Conventions', '', '- Feature work goes on a branch.') + $ExtraClaudeMdLines
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), $md)
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    $env:CLAUDE_PLUGIN_ROOT = $Plugin
    try {
        $r = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture)
        if ($r.Code -ne 0) { throw "bootstrap failed (exit $($r.Code)): $($r.Out)" }
    } finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
    return $Fixture
}

function Get-LensCount {
    return @(Get-ChildItem -LiteralPath (Join-Path $Fixture '.claude') -Recurse -Filter '*-lens.md' -File -ErrorAction SilentlyContinue).Count
}
function Get-ImportCount {
    $p = Join-Path $Fixture 'CLAUDE.md'
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    return @([System.IO.File]::ReadAllLines($p) | Where-Object { $_ -match '^\s*@' }).Count
}

try {
    Write-Host "== teardown.tests: specialists-teardown ==" -ForegroundColor Cyan

    # --- 1. Dry run is genuinely dry -----------------------------------------------------------------
    #     The default. A destructive script that runs on somebody's repo must not act unasked, and the
    #     preview is also the inventory a reader needs in order to say yes.
    New-BootstrappedConsumer | Out-Null
    $lensesBefore = Get-LensCount
    Assert-True ($lensesBefore -gt 0) "setup: the bootstrap placed lenses ($lensesBefore)"
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $r.Code 'dry run: exit-code 0'
    Assert-True ($r.Out -match 'DRY RUN') 'dry run: says so up front'
    Assert-True ($r.Out -match 'to remove') 'dry run: reports items as "to remove", not "removed"'
    Assert-Equal $lensesBefore (Get-LensCount) 'dry run: removed NOTHING -- lens count unchanged'
    Assert-Equal 1 (Get-ImportCount) 'dry run: the seam import is still there'
    Assert-True ($r.Out -match 'Re-run with -Apply') 'dry run: tells the reader how to act'
    # The dry run IS the inventory a reader says yes to, so a file missing from it is a file removed
    # without consent -- which is why both proposals are asserted here and not only after -Apply.
    foreach ($artifact in @('settings.suggested.jsonc', 'settings.proposed.json')) {
        Assert-True ($r.Out -match [regex]::Escape($artifact)) "dry run: $artifact is listed in the preview (#1124)"
    }

    # --- 2. -Apply removes the generated set ---------------------------------------------------------
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'apply: exit-code 0'
    Assert-Equal 0 (Get-LensCount) 'apply: every generated lens is gone'
    Assert-Equal 0 (Get-ImportCount) 'apply: the seam import is gone from CLAUDE.md'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1'))) 'apply: the untouched repo-config scaffold is gone'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1'))) 'apply: the untouched branch-info scaffold is gone'
    # BOTH proposals, and the second one is the point (inbound #1124). The bootstrap now places a merged
    # settings.proposed.json beside the annotated .jsonc, and an artifact one script writes under a name
    # the other does not know is an orphan nobody is ever told about: '.claude/*' is gitignored in many
    # consumers, so it shows up neither in 'git status' nor in this teardown -- the only two places
    # anyone would look. Both names come from Get-SettingsArtifactNames precisely so that cannot happen,
    # and this pair of asserts is what proves the second one is actually wired up.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture '.claude\settings.suggested.jsonc'))) 'apply: the annotated settings proposal is gone'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture '.claude\settings.proposed.json'))) 'apply: the MERGED settings proposal is gone too (#1124)'
    # The owner's own file must survive having two lines cut out of it.
    $md = [System.IO.File]::ReadAllText((Join-Path $Fixture 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($md -match 'Feature work goes on a branch') "apply: the owner's own CLAUDE.md prose is intact"
    Assert-True ($md -match '# CLAUDE.md - my own project') "apply: the owner's heading is intact"

    # --- 3. settings.json is never edited -----------------------------------------------------------
    #     Disabling the plugin is the owner's act, and the bootstrap never wrote this file either. The
    #     symmetry that makes the teardown safe to run cuts both ways.
    $settings = [System.IO.File]::ReadAllText((Join-Path $Fixture '.claude\settings.json'), [System.Text.Encoding]::UTF8)
    Assert-True ($settings -match 'dkj-subagents-alpha@dkj-claude-plugins') 'settings.json: still enables the plugin -- never edited'
    Assert-True ($r.Out -match 'That file is yours') "settings.json: reported as the owner's to change"
    Assert-True ($r.Out -match 'restart') 'settings.json: the note says a restart is needed'

    # --- 3b. THE UNMIGRATED CONSUMER: the retired marketplace name alone still triggers the note (#1769) -
    #     The matcher added for #1769 is 'dkj-claude-plugins|claude-code-specialists', so that a consumer
    #     who has not yet done the flag-day re-install -- and whose settings.json therefore still carries
    #     the OLD marketplace name in every 'enabledPlugins' key -- still gets told the plugin is enabled.
    #     Every other case in this suite builds its settings.json through New-BootstrappedConsumer, which
    #     writes ONLY the current name ('dkj-claude-plugins'), so the retired half of that alternation was
    #     never exercised. This fixture carries the retired name and nothing else.
    Write-Host "#1769 -- the retired marketplace name alone still triggers the settings.json note" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@claude-code-specialists": true }, "extraKnownMarketplaces": { "claude-code-specialists": { "source": { "source": "github", "repo": "DKJ-Solutions/claude-code-specialists" } } } }')
    $ru = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $ru.Code 'unmigrated: exit-code 0'
    Assert-True ($ru.Out -match 'still enables the plugin') 'unmigrated: the settings.json note fires on the retired name alone (#1769)'
    Assert-True ($ru.Out -match 'That file is yours') "unmigrated: reported as the owner's to change, same as the migrated case"

    # --- 4. Idempotent: a second run finds nothing and does not fail ---------------------------------
    #     3b swapped $Fixture for a raw settings.json-only fixture, so restore the bootstrapped-then-
    #     applied-once state this idempotency check depends on before running -Apply a second time.
    New-BootstrappedConsumer | Out-Null
    Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply') | Out-Null
    $r2 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r2.Code 'second run: exit-code 0 (idempotent, like the bootstrap)'
    Assert-True ($r2.Out -match 'Summary: 0 item') 'second run: nothing left to remove'

    # --- 5. THE SAFETY PROPERTY: authored content is kept, not deleted ------------------------------
    #     The assertion this whole script exists to earn. Deleting a filled-in lens to leave a tidy tree
    #     destroys repo knowledge somebody wrote -- a worse outcome than leaving clutter.
    New-BootstrappedConsumer | Out-Null
    $authoredLens = Join-Path $Fixture '.claude\specialists\lenses\specialist-06-16-lens.md'
    [System.IO.File]::WriteAllText($authoredLens, "# 06-16 repo lens`n`n## Specific to this repo`n`nTessa guards our API docs under docs/api/.")
    $authoredRc = Join-Path $Fixture 'scripts\repo-config.ps1'
    [System.IO.File]::WriteAllText($authoredRc, "function Get-RepoName { return 'someone/my-repo' }`nfunction Get-LintScript { return 'scripts/lint.ps1' }")
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'authored content: exit-code 0'
    Assert-True (Test-Path -LiteralPath $authoredLens) 'authored content: the filled-in lens is KEPT'
    Assert-True (Test-Path -LiteralPath $authoredRc) 'authored content: the filled-in repo-config is KEPT'
    Assert-Equal 1 (Get-LensCount) 'authored content: exactly the authored lens remains'
    Assert-True ($r.Out -match '\[KEEP\]') 'authored content: reported as kept, not silently skipped'
    # Asserts the SUBSTANCE -- the reader is pointed at both ways to finish the job -- rather than one
    # brittle phrase. The wording changed once already, when the blanket "authored" claim was dropped.
    Assert-True ($r.Out -match 'yours to delete') 'authored content: the reader is told the kept files are theirs to remove'
    Assert-True ($r.Out -match 'EmptyLensPattern') 'authored content: the reader is pointed at the declared-convention escape hatch'
    Assert-True (-not ($r.Out -match 'kept \(authored\)')) 'authored content: no blanket authorship claim in the summary'
    # The directory must survive too -- pruning it would take the authored lens with it.
    Assert-True (Test-Path -LiteralPath (Join-Path $Fixture '.claude\specialists\lenses')) 'authored content: the lens directory is not pruned while a kept file lives in it'
    # And the branch-info scaffold was still untouched, so it must still have gone.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1'))) 'authored content: the still-untouched scaffold is removed as normal'

    # --- 5b. MENTION vs USE: a filled-in file that merely NAMES VUL-IN must be kept ------------------
    #     The bug a dry run against a real consumer found on 2026-07-29, which no fixture had caught.
    #     davekokbwj/smartwatchbanden's repo-config.ps1 carries real values for all eight contract
    #     functions -- and the scaffold's own DOCSTRING still says "Fill in remaining VUL-IN values",
    #     because a consumer has no reason to strip a docstring. The naive test ('VUL-IN' anywhere in
    #     the file) therefore classified a fully configured, actively used file as an untouched scaffold
    #     and would have deleted it, breaking open-pr, fold-changelog, new-branch and check-roster-sync
    #     in that repo. Not an edge case: it is the NORMAL state of a filled-in scaffold.
    #     The fixture below reproduces that exact shape -- real values, docstring mention retained.
    New-BootstrappedConsumer | Out-Null
    $filledRc = Join-Path $Fixture 'scripts\repo-config.ps1'
    [System.IO.File]::WriteAllText($filledRc, @"
<#
.DESCRIPTION
    Placed by specialists-init as a VUL-IN scaffold. Fill in remaining VUL-IN values
    below and remove VUL-IN markers.
#>
`$script:RepoName = 'someone/my-repo'
function Get-RepoName { return `$script:RepoName }
`$script:LintScript = 'scripts/lint.ps1'
function Get-LintScript { return `$script:LintScript }
"@)
    # Same shape on the lens side: an authored lens that happens to explain the scaffold convention.
    $filledLens = Join-Path $Fixture '.claude\specialists\lenses\specialist-06-16-lens.md'
    [System.IO.File]::WriteAllText($filledLens, "# 06-16 repo lens`n`n## Specific to this repo`n`nTessa guards the docs. A lens may stay a VUL-IN scaffold until that specialist has work here.")
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'mention vs use: exit-code 0'
    Assert-True (Test-Path -LiteralPath $filledRc) 'mention vs use: a filled repo-config whose DOCSTRING says VUL-IN is KEPT'
    Assert-True (Test-Path -LiteralPath $filledLens) 'mention vs use: a filled lens whose PROSE says VUL-IN is KEPT'
    # Its content must be byte-identical -- kept means untouched, not rewritten.
    Assert-True ([System.IO.File]::ReadAllText($filledRc) -match 'someone/my-repo') 'mention vs use: the kept repo-config still holds its real value'
    # And the genuinely unfilled branch-info scaffold must still go, so this did not simply stop removing.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1'))) 'mention vs use: the genuinely unfilled branch-info scaffold is still removed'

    # --- 5b-2. THE BOOTSTRAP->FILL->TEARDOWN SEAM (inbound #451) --------------------------------------
    #     The previous case hand-writes its filled lens, and that is exactly why it missed this one: it
    #     wrote a title of its own ('# 06-16 repo lens') instead of the title the BOOTSTRAP writes. The
    #     bootstrap used to mark the title too -- '# 06-16 <dot> repo lens (VUL-IN)' -- and filling a lens
    #     replaces only the SLOT heading, so that marker outlived the filling and Test-LooksGenerated,
    #     which matches '(VUL-IN)' at ANY heading level, read authored repo knowledge as a scaffold.
    #     Measured in a consumer with 24 lenses: three filled specialist lenses holding 153 lines between
    #     them printed [remove], and -Apply would have taken them.
    #
    #     So this fixture does NOT invent the boilerplate. It takes the lens the real bootstrap produced
    #     and edits it the way a consumer does -- slot heading replaced, everything above it untouched --
    #     which is the only version of this test that can catch the template regressing again.
    New-BootstrappedConsumer | Out-Null
    $seamLens = Join-Path $Fixture '.claude\specialists\lenses\specialist-06-16-lens.md'
    $asGenerated = [System.IO.File]::ReadAllText($seamLens, [System.Text.Encoding]::UTF8)
    Assert-True ($asGenerated -match '(?m)^##\sSpecific to this repo \(VUL-IN\)\s*$') 'seam: the freshly bootstrapped lens carries the marker on its SLOT'
    Assert-True (-not ($asGenerated -match '(?m)^#\s[^\r\n]*\(VUL-IN\)')) 'seam: the freshly bootstrapped lens carries NO marker on its TITLE'
    # Fill it exactly as a consumer would: the slot heading becomes theirs, the title is never touched.
    $filledSeamLens = [regex]::Replace($asGenerated, '(?m)^##\sSpecific to this repo \(VUL-IN\)\s*$', '## Specific to this repo (my-repo)')
    $filledSeamLens = $filledSeamLens.TrimEnd() + "`n`nTessa owns CLAUDE.md and the manuals in this repo, and reviews every doc diff before the PR.`n"
    [System.IO.File]::WriteAllText($seamLens, $filledSeamLens)
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'seam: exit-code 0'
    Assert-True (Test-Path -LiteralPath $seamLens) 'seam: a bootstrap-generated lens that was FILLED IN survives -Apply'
    Assert-True ([System.IO.File]::ReadAllText($seamLens) -match 'Tessa owns CLAUDE\.md') 'seam: the kept lens still holds the repo knowledge somebody wrote'

    # --- 5c. The positive side of each signal still fires -------------------------------------------
    #     Guard against 5b being "fixed" by never removing anything. Each kind keeps its own signal:
    #     a placeholder VALUE for repo-config, an EMPTY prefix table for branch-info, an unfilled slot
    #     HEADING for a lens.
    New-BootstrappedConsumer | Out-Null
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1'))) 'signals: an unfilled repo-config (placeholder VALUE) is removed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1'))) 'signals: an unfilled branch-info (empty prefix table) is removed'
    Assert-Equal 0 (Get-LensCount) 'signals: unfilled lenses (slot heading) are removed'

    # --- 6. An unrelated @-import is NOT eaten ------------------------------------------------------
    #     The sharpest risk in the design. The matcher must key on the specialist shape
    #     (-persona.md / -lens.md), not merely on a line starting with '@' -- a consumer's own
    #     '@docs/git-instructions.md' import is exactly the kind of line that a sloppy rule destroys,
    #     and the consumer would have no idea why their instructions stopped loading.
    New-BootstrappedConsumer -ExtraClaudeMdLines @('', '@docs/git-instructions.md', '@~/.claude/my-notes.md') | Out-Null
    Assert-Equal 3 (Get-ImportCount) "unrelated imports: setup has 3 imports (1 seam + 2 of the owner's)"
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'unrelated imports: exit-code 0'
    Assert-Equal 2 (Get-ImportCount) "unrelated imports: only the seam import was removed -- the owner's 2 survive"
    $md = [System.IO.File]::ReadAllText((Join-Path $Fixture 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($md -match [regex]::Escape('@docs/git-instructions.md')) "unrelated imports: the owner's own import survives"
    Assert-True ($md -match [regex]::Escape('@~/.claude/my-notes.md')) "unrelated imports: the owner's home-dir import survives"
    Assert-True (-not ($md -match '01-01-persona\.md')) 'unrelated imports: the persona import is gone'
    Assert-True (-not ($md -match '01-01-extension\.md')) 'unrelated imports: the lens import is gone'

    # --- 6b. THE ROUND-TRIP DOES NOT ACCUMULATE ------------------------------------------------------
    #     Measured in davekokbwj/smartwatchbanden on 2026-07-29: the bootstrap's note line survived a
    #     teardown (which removes '@' lines and deliberately nothing else), so the bootstrap's guard --
    #     which only tested for the lens import -- read "not present" and re-appended the WHOLE block.
    #     One extra copy of the note per teardown->init cycle, counted 1 -> 2 -> 3, with all three
    #     session hooks reporting "in sync" throughout. Two runs of the cycle here, since one cycle
    #     cannot distinguish "does not accumulate" from "accumulates once".
    #
    #     AND THE SECOND TIME, ONE LINE LOWER (inbound #271, DaveKJohn/life-hub, 2026-07-30). The note is
    #     a sentence wrapped over TWO lines, and everything -- both removers AND this test -- keyed on the
    #     head. So the tail orphaned, the next bootstrap wrote a fresh note above it, and CLAUDE.md grew
    #     by 4 lines over a round trip that should return to zero. Get-NoteCount read 1 / 0 / 1 / 0
    #     throughout: exactly the healthy values.
    #
    #     THAT is why the counters below are split. Get-NoteHeadCount is the old measurement, kept
    #     because the head must still behave; Get-NoteTailCount is the one that was missing, and it is
    #     asserted at every step. A counter that watches one line of a two-line block certifies half a
    #     file. Both derive from the shared source (Get-OrchestratorNote) rather than re-typing the
    #     literal -- re-typing is what produced both instances of this bug.
    . (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')
    $noteSrc = Get-OrchestratorNote
    function Get-NoteHeadCount {
        $p = Join-Path $Fixture 'CLAUDE.md'
        if (-not (Test-Path -LiteralPath $p)) { return 0 }
        return @([System.IO.File]::ReadAllLines($p) | Where-Object { $_.Trim() -eq $noteSrc.Head }).Count
    }
    function Get-NoteTailCount {
        $p = Join-Path $Fixture 'CLAUDE.md'
        if (-not (Test-Path -LiteralPath $p)) { return 0 }
        return @([System.IO.File]::ReadAllLines($p) | Where-Object { $_.Trim() -match $noteSrc.TailPattern }).Count
    }
    # Kept as an alias so the surrounding assertions read unchanged; it now means "head", explicitly.
    function Get-NoteCount { return (Get-NoteHeadCount) }
    New-BootstrappedConsumer | Out-Null
    $mdBaseline = [System.IO.File]::ReadAllLines((Join-Path $Fixture 'CLAUDE.md')).Count
    Assert-Equal 1 (Get-NoteHeadCount) 'round-trip: one note HEAD after the first init'
    Assert-Equal 1 (Get-NoteTailCount) 'round-trip: one note TAIL after the first init -- the line inbound #271 found nobody was counting'
    foreach ($cycle in 1, 2) {
        $null = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
        Assert-Equal 0 (Get-NoteHeadCount) "round-trip cycle ${cycle}: the teardown removes the note head"
        Assert-Equal 0 (Get-NoteTailCount) "round-trip cycle ${cycle}: and the TAIL with it -- a half-removed note is what accumulated"
        $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
        $env:CLAUDE_PLUGIN_ROOT = $Plugin
        try { $ri = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture) }
        finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
        Assert-Equal 0 $ri.Code "round-trip cycle ${cycle}: re-init exit 0"
        Assert-Equal 1 (Get-NoteHeadCount) "round-trip cycle ${cycle}: STILL exactly one note head -- no accumulation"
        Assert-Equal 1 (Get-NoteTailCount) "round-trip cycle ${cycle}: STILL exactly one note tail -- no orphan left to grow on"
        Assert-Equal 1 (Get-ImportCount) "round-trip cycle ${cycle}: exactly one import restored"
        # The measurement that catches ANY leftover, named or not: the file must be the same length as
        # after the first bootstrap. Counting known lines only ever finds the leak you already know about,
        # which is exactly how this bug survived its own regression test.
        Assert-Equal $mdBaseline ([System.IO.File]::ReadAllLines((Join-Path $Fixture 'CLAUDE.md')).Count) `
            "round-trip cycle ${cycle}: CLAUDE.md is the same LENGTH as after the first init -- nothing accumulated under any name"
    }

    # --- 6b2. The bootstrap's own guard, ISOLATED ----------------------------------------------------
    #     6b passes even with the bootstrap fix reverted, because the teardown now removes the note and
    #     the cycle needed BOTH defects. Verified by reverting it. So 6b does not cover the bootstrap
    #     half at all, and the scenario it actually defends is a repo whose imports were removed by
    #     hand -- or by an older teardown -- while the note stayed. Without the guard, re-init appends
    #     a second copy.
    New-BootstrappedConsumer | Out-Null
    $mdP = Join-Path $Fixture 'CLAUDE.md'
    $handEdited = @([System.IO.File]::ReadAllLines($mdP) | Where-Object { $_ -notmatch '^\s*@' })
    [System.IO.File]::WriteAllLines($mdP, $handEdited)
    Assert-Equal 1 (Get-NoteCount) 'isolated guard: setup leaves the note but no imports'
    Assert-Equal 0 (Get-ImportCount) 'isolated guard: setup really removed the imports'
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    $env:CLAUDE_PLUGIN_ROOT = $Plugin
    try { $rg = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture) }
    finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
    Assert-Equal 0 $rg.Code 'isolated guard: re-init exit 0'
    Assert-Equal 1 (Get-NoteCount) 'isolated guard: STILL one note -- the bootstrap tidied the leftover'
    Assert-Equal 1 (Get-ImportCount) 'isolated guard: the import is restored'

    # --- 6c. NO LINE-ENDING DRIFT ---------------------------------------------------------------------
    #     Also measured there: the bootstrap pasted a "`n"-built block into a CRLF file, leaving 8 lone
    #     LFs. Invisible to every gate, and the kind of thing that turns a later diff into noise.
    New-BootstrappedConsumer | Out-Null
    $mdPath = Join-Path $Fixture 'CLAUDE.md'
    # Force the consumer's file to CRLF, the realistic Windows case, then run a full cycle.
    $crlf = ([System.IO.File]::ReadAllText($mdPath) -replace "`r`n", "`n") -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($mdPath, $crlf)
    $null = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    $afterTeardown = [System.IO.File]::ReadAllText($mdPath)
    $loneAfterTeardown = ([regex]::Matches($afterTeardown, "(?<!`r)`n")).Count
    Assert-Equal 0 $loneAfterTeardown 'line endings: the teardown leaves no lone LF in a CRLF file'
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    $env:CLAUDE_PLUGIN_ROOT = $Plugin
    try { $null = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture) }
    finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
    $afterInit = [System.IO.File]::ReadAllText($mdPath)
    $loneAfterInit = ([regex]::Matches($afterInit, "(?<!`r)`n")).Count
    Assert-Equal 0 $loneAfterInit 'line endings: re-init appends CRLF into a CRLF file, not lone LF'

    # --- 6d. A CONSUMER'S OWN EMPTY-LENS CONVENTION, only when declared ----------------------------
    #     The blindness this skill shipped with: 20 of smartwatchbanden's 22 lenses are empty under
    #     that repo's own convention (a closing sentence, no '(VUL-IN)' heading), so all 22 were kept
    #     and reported as authored -- right answer, wrong reason, and adoption was less reversible than
    #     claimed. The plugin must not GUESS at a convention it did not create, so the consumer
    #     declares it. Default (no pattern) keeps them, which is the safe direction.
    New-BootstrappedConsumer | Out-Null
    $emptyByConvention = Join-Path $Fixture '.claude\specialists\lenses\specialist-06-16-lens.md'
    [System.IO.File]::WriteAllText($emptyByConvention, "---`nid: 16`ngroup: 06`n---`n`n# 06-16 repo-lens`n`n## Eigen aan deze repo`n`nSchone lei: hier staan alleen repo-eigen regels. Nog niets vastgelegd.")
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-True ($r.Out -match [regex]::Escape('specialist-06-16-lens.md') ) 'own convention: the lens appears in the report'
    Assert-True (Test-Path -LiteralPath $emptyByConvention) 'own convention: WITHOUT a declared pattern it is kept (safe default)'
    Assert-True (-not ($r.Out -match 'filled in')) 'own convention: the report no longer claims the file was filled in'
    Assert-True ($r.Out -match 'does not judge it') 'own convention: it states what it actually knows'
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply', '-EmptyLensPattern', 'Nog niets vastgelegd')
    Assert-True (-not (Test-Path -LiteralPath $emptyByConvention)) 'own convention: WITH the pattern declared it is removed'

    # --- 7. A repo that never adopted is a no-op, not an error --------------------------------------
    $bare = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-teardown-bare-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $bare) { Remove-Item -Recurse -Force -LiteralPath $bare }
    New-Item -ItemType Directory -Path $bare -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $bare 'CLAUDE.md'), "# plain project`n`nnothing to do with specialists.")
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $bare, '-Apply')
    Assert-Equal 0 $r.Code 'never adopted: exit-code 0'
    Assert-True ($r.Out -match 'Summary: 0 item') 'never adopted: nothing to remove'
    $md = [System.IO.File]::ReadAllText((Join-Path $bare 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($md -match 'nothing to do with specialists') 'never adopted: the file is untouched'
    Remove-Item -Recurse -Force -LiteralPath $bare -ErrorAction SilentlyContinue

    # --- 8. A RUNTIME DEPENDENCY ON THE PLUGIN: warned about, never removed -------------------------
    #     The one leftover a teardown cannot classify away (measured in davekokbwj/smartwatchbanden,
    #     2026-07-29): the consumer's own resolver locates the marketplace cache and throws once it is
    #     gone, and three operational scripts dot-source it -- so the uninstall took the daily git
    #     workflow down rather than leaving debris. Two properties are asserted here, and the second
    #     matters more than the first: the report NAMES it, and -Apply still does not TOUCH it. A check
    #     that deleted the consumer's own scripts to make its summary look clean would be doing exactly
    #     the damage the whole classification exists to prevent.
    New-BootstrappedConsumer | Out-Null
    $resolver = Join-Path $Fixture 'scripts\lib\plugin-paths.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $resolver) -Force | Out-Null
    [System.IO.File]::WriteAllText($resolver, (@(
        '# Resolves the shared scripts in the marketplace cache.',
        '$cache = Join-Path $env:USERPROFILE ''.claude\plugins\marketplaces\claude-code-specialists''',
        'if (-not (Test-Path $cache)) { throw ''the specialists plugin is not installed'' }'
    ) -join "`n"))
    $starter = Join-Path $Fixture 'scripts\task\start-task.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $starter) -Force | Out-Null
    [System.IO.File]::WriteAllText($starter, (@(
        '. "$PSScriptRoot\..\lib\plugin-paths.ps1"',
        'Write-Host ''starting a task'''
    ) -join "`n"))
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $r.Code 'runtime dependency: exit-code 0 -- a warning is not a failure'
    Assert-True ($r.Out -match 'resolves the plugin cache') 'runtime dependency: the resolver is named'
    Assert-True ($r.Out -match [regex]::Escape('start-task.ps1')) 'runtime dependency: what depends on it is named too'
    Assert-True ($r.Out -match 'No teardown can fix this') 'runtime dependency: says plainly that no teardown fixes it'
    Assert-True ($r.Out -match 'keep local copies') 'runtime dependency: offers the way out before the uninstall'
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-True (Test-Path -LiteralPath $resolver) "runtime dependency: -Apply leaves the consumer's resolver alone"
    Assert-True (Test-Path -LiteralPath $starter) "runtime dependency: -Apply leaves the dependent script alone"

    # No false alarm: a consumer whose scripts never reach into the plugin hears nothing about it.
    New-BootstrappedConsumer | Out-Null
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-True (-not ($r.Out -match 'resolves the plugin cache')) 'no false alarm: no resolver, no warning'

    # --- 9. -VendorScripts: the way out, and the one additive act in a subtractive script -----------
    #     Warning about the runtime dependency was half the answer; this is the other half. Three
    #     properties, and the middle one is the important one: the payload lands with its STRUCTURE
    #     intact (the scripts dot-source siblings $PSScriptRoot-relative, so a flattened copy would
    #     break at the next branch rather than here), it is BYTE-IDENTICAL to the plugin's (a copy that
    #     drifts is worse than no copy), and a destination that already exists and DIFFERS is left
    #     alone -- that file is the consumer's own wrapper, i.e. authored content.
    New-BootstrappedConsumer | Out-Null
    $pluginPayload = Join-Path $Plugin 'scripts'
    # RETARGETED AUGUST 8, 2026, and the two roles had to swap files. Since the branch/release scripts
    # moved to dkj-policy, this plugin's payload is check-roster-sync.ps1 plus the
    # lib it dot-sources -- so the collision case and the copied-correctly case can no longer share one
    # file. The operational script is now the wrapper's address, and the lib carries the copy assertions.
    $wrapper = Join-Path $Fixture 'scripts\sync\check-roster-sync.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $wrapper) -Force | Out-Null
    [System.IO.File]::WriteAllText($wrapper, "# my own wrapper around the shared roster check`nWrite-Host 'wrapping'")
    $wrapperBefore = [System.IO.File]::ReadAllText($wrapper, [System.Text.Encoding]::UTF8)

    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-VendorScripts')
    Assert-Equal 0 $r.Code 'vendor dry run: exit-code 0'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\check-report-lib.ps1'))) 'vendor dry run: writes NOTHING without -Apply'
    Assert-True ($r.Out -match 'would be written') 'vendor dry run: says what it would write'

    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply', '-VendorScripts')
    Assert-Equal 0 $r.Code 'vendor: exit-code 0'
    $vendoredLib = Join-Path $Fixture 'scripts\lib\check-report-lib.ps1'
    Assert-True (Test-Path -LiteralPath $vendoredLib) 'vendor: the operational script is now local'
    Assert-Equal (Get-FileHash -LiteralPath (Join-Path $pluginPayload 'lib\check-report-lib.ps1')).Hash `
                 (Get-FileHash -LiteralPath $vendoredLib).Hash `
                 "vendor: byte-identical to the plugin's copy -- no drift on arrival"
    # Structure preserved: the payload's own subdirectories arrive as subdirectories, because the
    # scripts reach their siblings $PSScriptRoot-relative.
    Assert-True ($vendoredLib -like '*\scripts\lib\*') 'vendor: the tree structure the dot-sources depend on is preserved'
    # The cap is stated, not silent: a run listing four files must not read as "that was all of it".
    Assert-True ($r.Out -match 'dkj-policy') 'vendor: names the pack whose scripts this run does NOT cover'
    # THE SAFETY PROPERTY, same family as "an authored lens is kept".
    Assert-Equal $wrapperBefore ([System.IO.File]::ReadAllText($wrapper, [System.Text.Encoding]::UTF8)) "vendor: the consumer's own wrapper is NOT overwritten"
    Assert-True ($r.Out -match 'yours, not overwritten') 'vendor: the collision is reported, not silent'

    # Idempotent, and honest about it: a second run recognises its own work instead of rewriting it.
    $r2 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply', '-VendorScripts')
    Assert-Equal 0 $r2.Code 'vendor: second run exit-code 0'
    Assert-True ($r2.Out -match 'already current') 'vendor: a second run reports the copies as already current'

    # Default behaviour is untouched: no switch, no writing.
    New-BootstrappedConsumer | Out-Null
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\task\new-branch.ps1'))) 'vendor: nothing is vendored without the switch'

    # --- 10. THE SEAM: one directory and one line (issue #221) ---------------------------------------
    #     The claim the whole seam exists to make good on, asserted as an absolute rather than a count:
    #     after a teardown of an untouched consumer, the specialist surface is GONE -- not "smaller".
    Write-Host "the seam -- an untouched consumer tears down to nothing" -ForegroundColor Cyan
    New-BootstrappedConsumer | Out-Null
    $seamDir = Join-Path $Fixture '.claude\specialists'
    Assert-True (Test-Path -LiteralPath (Join-Path $seamDir 'SPECIALISTS.md')) 'seam: the bootstrap placed the inclusion'
    Assert-Equal 1 (Get-ImportCount) 'seam: CLAUDE.md carries exactly one import'
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'seam: exit-code 0'
    Assert-True (-not (Test-Path -LiteralPath $seamDir)) 'seam: the whole .claude/specialists directory is gone -- one directory'
    Assert-Equal 0 (Get-ImportCount) 'seam: CLAUDE.md has no import left -- one line'
    $ownMd = [System.IO.File]::ReadAllText((Join-Path $Fixture 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($ownMd -match 'Feature work goes on a branch') "seam: the owner's own prose is untouched"

    # --- 10b. An AUTHORED inclusion is kept, and the report says it is now loaded by nothing ---------
    #     The safety property from section 5, applied to the file that now holds the roster. And the
    #     honest half: the import is still removed, so the file survives as an orphan -- but ONE named
    #     orphan holding the roster in one piece, instead of 43 lines scattered through CLAUDE.md. That
    #     trade is the seam's actual payoff, so the report has to say it out loud.
    Write-Host "the seam -- an authored SPECIALISTS.md is kept and reported" -ForegroundColor Cyan
    New-BootstrappedConsumer | Out-Null
    $inclusion = Join-Path $Fixture '.claude\specialists\SPECIALISTS.md'
    # A roster somebody wrote: the VUL-IN slot heading is gone, which is exactly the signal.
    [System.IO.File]::WriteAllText($inclusion, "# The Claude Specialists`n`n## Our roster`n`n| signal | specialist |`n|---|---|`n| branches | Derek |`n")
    $r = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $r.Code 'authored inclusion: exit-code 0'
    Assert-True (Test-Path -LiteralPath $inclusion) 'authored inclusion: kept, never deleted'
    Assert-True ([System.IO.File]::ReadAllText($inclusion) -match 'branches \| Derek') 'authored inclusion: the roster somebody wrote is intact'
    Assert-Equal 0 (Get-ImportCount) 'authored inclusion: the import is STILL removed -- that line is what made it live'
    Assert-True ($r.Out -match 'nothing loads it') 'authored inclusion: the report says outright that nothing loads it any more'
    Assert-True ($r.Out -match 'one named file to decide about') 'authored inclusion: the report names the trade the seam makes'

    # --- The free-standing audit: proving it, not claiming it (issue #221) ---------------------------
    # Everything above answers "what did the bootstrap put here". The audit answers the question the
    # requirement actually poses -- after this, does the repo STAND FREE? -- and it is the only half of
    # target-shape item 2 a script may legitimately do: find the references, never reword the owner's
    # governance prose.
    Write-Host "the free-standing audit -- live references are named, by file and line" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts') -Force | Out-Null
    # A category-3 CLAUDE.md: every rule below still holds after an uninstall, but two of them are
    # PHRASED in specialist terms, which is precisely what turns a valid rule into a reference to a
    # character that no longer exists.
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), @(
        '# My repo',
        '',
        '- Never directly on main -- Derek opens the PR and merges it.',
        '- All changes go via a branch.',
        '',
        '| Derek 05-05 | DevOps | lens |'
    ))
    # A filled-in repo-config: the file is the repo's own (category 3, kept), but two of its contract
    # functions exist ONLY to serve the roster check.
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\repo-config.ps1'), @(
        '$script:RepoName = "me/mine"',
        'function Get-RepoName { return $script:RepoName }',
        '$script:RosterPath = "CLAUDE.md"',
        'function Get-RosterPath { return $script:RosterPath }'
    ))
    $a = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $a.Code 'audit: exit-code 0 -- the audit reports, it never fails a run'
    Assert-True ($a.Out -match 'free-standing audit') 'audit: the section runs on a DRY RUN too -- a preview that cannot say what is left is not an inventory'
    Assert-True ($a.Out -match "CLAUDE\.md:3 -- name 'Derek'") "audit: 'Derek opens the PR' is named with its line number -- the category-3 reword case"
    Assert-True ($a.Out -match 'CLAUDE\.md:6 -- specialist id') 'audit: the roster row is found by id, which works for a specialist from any plugin'
    # The regression that made this test worth writing: '\b' before '\$' never matches at the start of a
    # line, so an assignment on line 3 was missed while the function on line 4 was found.
    Assert-True ($a.Out -match 'repo-config\.ps1:3 -- plugin-only contract function') 'audit: the $script:RosterPath ASSIGNMENT is caught, not just the function (the \b\$ anchor bug)'
    Assert-True ($a.Out -match 'repo-config\.ps1:4 -- plugin-only contract function') 'audit: the Get-RosterPath function is caught too'
    Assert-True ($a.Out -match 'REWORD it if the rule still holds without the character') 'audit: the note tells the owner HOW to clear a hit, per line rather than per file'
    Assert-True (-not ($a.Out -match '(?m)^\s*\[LIVE\]\s+CHANGELOG')) 'audit: history is excluded -- CHANGELOG.md is never a finding, and never rewritten'

    # The closed loop: apply the advice the note gives, and the audit says FREE. Without this the audit
    # could name references that no reasonable edit ever clears, which would make it noise.
    Write-Host "the free-standing audit -- the reword it advises actually reaches FREE" -ForegroundColor Cyan
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), @(
        '# My repo',
        '',
        '- Never directly on main -- changes go in via a branch and a PR.',
        '- All changes go via a branch.'
    ))
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\repo-config.ps1'), @(
        '$script:RepoName = "me/mine"',
        'function Get-RepoName { return $script:RepoName }'
    ))
    $a2 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $a2.Code 'audit (reworded): exit-code 0'
    Assert-True ($a2.Out -match '\[FREE\]') 'audit (reworded): the repo now reports FREE -- the advice is reachable, so the findings are actionable rather than noise'
    Assert-True (-not ($a2.Out -match '(?m)^\s*\[LIVE\]')) 'audit (reworded): no live reference is left at all'
    Assert-True ($a2.Out -match 'verified rather than assumed') 'audit (reworded): the clean verdict says it was verified, which is the whole point of the requirement'

    # --- The audit walk is extension-agnostic, and that is the decision (issue #421) ------------------
    # The walk used to carry `-Include '*.md','*.ps1','*.json','*.jsonc'` beside `-LiteralPath`, which
    # PowerShell silently ignores -- so the code read every file while naming four extensions. #421 asked
    # which of the two was right before anyone touched it, and the answer is the superset: a live
    # reference is live regardless of the extension it sits in, and an allowlist here is a false-negative
    # generator in a section whose whole bias is that a miss is the expensive failure.
    #
    # ASSERTED ON THE RESULT, NOT ON THE CODE -- deliberately, because that is the only reason the sibling
    # instance in Get-MojibakePaths was ever found (#413): a test asserting on the OUTPUT caught it, while
    # the line itself read correctly for years. A test that greps this script for '-Include' would pass
    # against a rewrite that reintroduced the same blindness by another route.
    Write-Host "issue #421 -- the audit reads every file under the roots, not four extensions" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), @('# My repo', '', 'Nothing of theirs here.'))
    # Neither extension is on the old four-name list, and both hold a genuine live reference: a deploy
    # script that names a specialist as the actor, and a note under .claude/ that a session reads.
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\deploy.js'), @(
        '// Derek opens the PR for every change',
        'const roster = "05-05";'
    ))
    [System.IO.File]::WriteAllLines((Join-Path $Fixture '.claude\notes.txt'), @('Tessa maintains the manuals here.'))
    $a3 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $a3.Code 'audit (#421): exit-code 0'
    Assert-True ($a3.Out -match "deploy\.js:1 -- name 'Derek'") 'audit (#421): a .js file under scripts/ is scanned -- with the filter working this hit would not exist'
    Assert-True ($a3.Out -match 'deploy\.js:2 -- specialist id') 'audit (#421): and the id scan reaches it too, not only the name scan'
    Assert-True ($a3.Out -match "notes\.txt:1 -- name 'Tessa'") 'audit (#421): a .txt note under .claude/ is scanned as well -- the roots decide the scope, not the extension'

    # --- THE OCCUPIED CONSUMER: the scaffold paths are already inhabited ------------------------------
    # Reported from the first real adoption attempt (life-hub, 2026-07-30), which stopped before
    # installing and was right to. Both scaffold addresses this plugin writes to were live, tracked
    # files there: scripts/repo-config.ps1 (55 lines) and scripts/lib/branch-info.ps1 (88 lines, named
    # by that repo's own CLAUDE.md as its single source of truth for the branch taxonomy).
    #
    # WHY NO FIXTURE COULD HAVE TOLD US: every scenario above starts from an address that is EMPTY. The
    # plugin scaffolds precisely the files that were extracted FROM repos like these, so on a fixture
    # they are free real estate and in a real consumer they are occupied. Same shape as the sync-roster
    # gap (#262) -- a fixture that always arrives in one state tests one branch.
    #
    # The measured answer is that the behaviour was already right on both ends, and the defect was in
    # the TEST's expectations. This scenario pins that down so the question cannot be reopened by guess:
    # the bootstrap must not place over an occupied address, and the teardown must not remove what it
    # therefore never wrote.
    Write-Host "the occupied consumer -- scaffold addresses that were already inhabited" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\lib') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true } }')
    # The consumer's OWN CLAUDE.md, which is also what triggers the report path that used to be broken:
    # this block only runs when a CLAUDE.md exists and does not yet carry the guard import.
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), @(
        '# My own project', '', '## Conventions', '', '- Feature work goes on a branch.'))
    $ownConfig = @('$script:RepoName = "me/mine"', 'function Get-RepoName { return $script:RepoName }')
    $ownBranch = @('$script:BranchPrefixTable = @{', '  feat = @{ Label = "enhancement"; Type = "Feat" }', '}')
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\repo-config.ps1'), $ownConfig)
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\lib\branch-info.ps1'), $ownBranch)
    $hashConfig = (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1')).Hash
    $hashBranch = (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1')).Hash

    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    $env:CLAUDE_PLUGIN_ROOT = $Plugin
    try { $ob = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture) }
    finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }

    Assert-Equal 0 $ob.Code 'occupied: bootstrap exit 0'
    Assert-True ($ob.Out -match '\[keep\]\s+scripts/repo-config\.ps1 already exists') 'occupied: the bootstrap says outright it did not overwrite the repo-config'
    Assert-True ($ob.Out -match '\[keep\]\s+scripts/lib/branch-info\.ps1 already exists') 'occupied: same for the branch taxonomy -- the file this repo calls its single source of truth'
    Assert-Equal $hashConfig (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1')).Hash 'occupied: the repo-config is byte-identical after the bootstrap'
    Assert-Equal $hashBranch (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1')).Hash 'occupied: the branch taxonomy is byte-identical after the bootstrap'
    Assert-True ($ob.Out -match '0 script-scaffold\(s\) created, 2 already present') 'occupied: the report counts both addresses as already present, so an operator can see nothing was placed'
    # THE REGRESSION. $kept was the persona-lens counter AND, from 2026-07-30, an array of CLAUDE.md
    # lines assigned in the note-tidy block -- so this line printed the whole of CLAUDE.md where a
    # number belonged. Only on this path: a fixture without its own CLAUDE.md never reaches it.
    Assert-True ($ob.Out -match 'Done: \d+ persona-lens\(es\) created, \d+ already present;') 'occupied: the report line carries NUMBERS -- the persona counter is not clobbered by the note-tidy block'
    Assert-True (-not ($ob.Out -match 'My own project.*already present')) 'occupied: the consumer CLAUDE.md content does not leak into the report'

    $ot = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $ot.Code 'occupied: teardown exit 0'
    Assert-True (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1')) 'occupied: the teardown did NOT remove a file it never wrote'
    Assert-True (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1')) 'occupied: nor the branch taxonomy -- removing it would take the repo workflow with it'
    Assert-Equal $hashConfig (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\repo-config.ps1')).Hash 'occupied: repo-config still byte-identical after the full round trip'
    Assert-Equal $hashBranch (Get-FileHash -LiteralPath (Join-Path $Fixture 'scripts\lib\branch-info.ps1')).Hash 'occupied: branch taxonomy still byte-identical after the full round trip'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture '.claude\specialists'))) 'occupied: what the plugin DID write is gone -- the seam directory'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $Fixture 'CLAUDE.md')) -match 'Feature work goes on a branch') "occupied: the consumer's own prose survived both directions"
    # The occupied repo-config has Get-RepoName but none of the plugin's own contract functions -- which
    # is normal for a file that predates the plugin. Keeping it is right; saying nothing about it left the
    # consumer with [ERROR] lines at every session start and nothing tying them to this moment.
    Assert-True ($ob.Out -match 'it does not define .*Get-RosterPath') 'occupied: the bootstrap names the contract functions the kept file lacks'
    Assert-True (-not ($ob.Out -match 'it does not define .*Get-RepoName')) 'occupied: and names ONLY the missing ones -- Get-RepoName is present, so it is not listed'

    # --- The four secondary findings from inbound #271 ------------------------------------------------
    Write-Host "inbound #271 secondaries -- possessives, preview scope, and an authorship claim" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\lib') -Force | Out-Null
    # A Dutch possessive takes no apostrophe, so the old trailing \b rejected it -- a false NEGATIVE in a
    # scan that documents itself as biased toward over-reporting. Every non-English consumer, not an edge.
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'CLAUDE.md'), @(
        '# My repo', '',
        '- Dereks taak is de PR openen.',
        "- Tessa's manual is leidend.",
        '- Niets over specialisten in deze regel.'))
    [System.IO.File]::WriteAllLines((Join-Path $Fixture 'scripts\repo-config.ps1'), @(
        '$script:RepoName = "me/mine"', 'function Get-RepoName { return $script:RepoName }'))
    $s1 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $s1.Code 'secondaries: exit-code 0'
    Assert-True ($s1.Out -match "CLAUDE\.md:3 -- name 'Dereks'") "secondaries: the Dutch possessive 'Dereks' is found -- it was invisible behind the trailing word boundary"
    Assert-True ($s1.Out -match "CLAUDE\.md:4 -- name 'Tessa's'") "secondaries: the English possessive is found too"
    Assert-True (-not ($s1.Out -match 'CLAUDE\.md:5')) 'secondaries: a line naming no specialist is still not a hit -- the looser boundary did not make it match everything'
    Assert-True ($s1.Out -match "not recognised as an unfilled scaffold; it holds this repo's repo config") 'secondaries: the per-item KEEP line no longer claims the file was "filled in"'
    Assert-True (-not ($s1.Out -match '\[KEEP\].*filled in')) 'secondaries: no KEEP line asserts authorship the script cannot establish'

    # The dry-run preview used to be swamped by the lens files the SAME run listed under [remove]: they
    # all mention a specialist, they filled the 40-line cap, and the hits that matter only appeared after
    # -Apply. A reference inside a file that is going away is not a surviving reference.
    Write-Host "inbound #271 -- the dry-run audit excludes what the same run is about to delete" -ForegroundColor Cyan
    New-BootstrappedConsumer | Out-Null
    $prev = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $prev.Code 'preview scope: exit-code 0'
    Assert-True (-not ($prev.Out -match '(?m)^\s*\[LIVE\]\s+\.claude')) 'preview scope: no lens file appears as a LIVE hit -- every one of them is on the [remove] list'
    Assert-True ($prev.Out -match 'were excluded -- a reference inside a file that is going away is not a leftover') 'preview scope: the exclusion is stated, not silent'
    Assert-True ($prev.Out -match 'would remove') 'preview scope: on a dry run it says "would remove", not "removed"'

    # --- inbound #275: the preview and the apply run must report the SAME total ---------------------
    #     Measured in a consumer over two full cycles: "29 item(s) to remove" against "31 item(s)
    #     removed", for the same work and with identical [remove] lines. The gap was the two directories
    #     the run cleans up, pruned and tallied only under -Apply. A preview that undercounts its own
    #     execution is the one thing the dry run exists not to do.
    #
    #     Both counts are read out of the real output, deliberately -- asserting a literal (29, 31) would
    #     pin the test to today's lens inventory and break on the next added specialist, which is the
    #     opposite of what this guards.
    Write-Host "inbound #275 -- the dry run and the apply run count the same items" -ForegroundColor Cyan
    New-BootstrappedConsumer | Out-Null
    $pv = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    $ap = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $pv.Code 'same total: preview exit-code 0'
    Assert-Equal 0 $ap.Code 'same total: apply exit-code 0'
    $mPrev  = [regex]::Match($pv.Out, 'Summary:\s+(\d+) item\(s\) to remove')
    $mApply = [regex]::Match($ap.Out, 'Summary:\s+(\d+) item\(s\) removed')
    Assert-True ($mPrev.Success -and $mApply.Success) 'same total: both runs print a summary count'
    Assert-Equal $mPrev.Groups[1].Value $mApply.Groups[1].Value 'same total: the preview count equals the apply count'
    # And the two directories are visible in BOTH, because a directory disappearing is something a reader
    # should see coming rather than discover in the tally afterwards.
    Assert-True ($pv.Out -match '(?m)^\s*\[remove\].*lenses\\ \(empty directory\)') 'same total: the preview lists the emptied lens directory'
    Assert-True ($ap.Out -match '(?m)^\s*\[remove\].*lenses\\ \(empty directory\)') 'same total: so does the apply run'
    Assert-True ($pv.Out -match '(?m)^\s*\[remove\].*specialists\\ \(empty directory\)') 'same total: and the seam directory'

    # --- inbound #275: the audit excludes the LINES the same run removes, not just whole files -------
    #     The bootstrap's orchestrator note is on the [remove] list AND was reported as a surviving
    #     "name 'Chris'" hit in the same preview -- so the audit dropped from 5 live references to 4 after
    #     -Apply on a consumer that changed nothing in between. The fixture carries one genuinely authored
    #     reference, so "no CLAUDE.md hits at all" cannot make this pass for the wrong reason: the
    #     authored line must still be found while the bootstrap's own lines must not.
    Write-Host "inbound #275 -- the audit excludes removed CLAUDE.md LINES (line granularity)" -ForegroundColor Cyan
    New-BootstrappedConsumer -ExtraClaudeMdLines @('', '- Derek opens the PR for every change.') | Out-Null
    $lp = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $lp.Code 'line scope: preview exit-code 0'
    $lpHits = @([regex]::Matches($lp.Out, '(?m)^\s*\[LIVE\]\s+CLAUDE\.md:'))
    Assert-Equal 1 $lpHits.Count 'line scope: exactly one CLAUDE.md hit -- the authored line, not the bootstrap note'
    Assert-True ($lp.Out -match "(?m)^\s*\[LIVE\]\s+CLAUDE\.md:\d+ -- name 'Derek'") 'line scope: and it IS the authored line'
    Assert-True ($lp.Out -match 'at line granularity') 'line scope: the line-level exclusion is stated, not silent'
    # The number the finding was actually about: the same audit, before and after -Apply, over a repo whose
    # own text did not change. It used to fall by one.
    $la = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $la.Code 'line scope: apply exit-code 0'
    $laHits = @([regex]::Matches($la.Out, '(?m)^\s*\[LIVE\]\s+CLAUDE\.md:'))
    Assert-Equal $lpHits.Count $laHits.Count 'line scope: the live count is the same before and after -Apply'

    # --- inbound #286: the note's two [remove] lines are DISTINGUISHABLE ------------------------------
    #     Removing per line is correct -- both lines must go -- but the report printed the same sentence
    #     twice, so a HEALTHY repo showed "2" for a check SKILL.md frames as the defective series
    #     1 -> 2 -> 3. The loudest reading of a clean run was therefore the accumulation defect itself,
    #     and two identical lines carried no information about WHICH of the block's two lines was meant.
    #     Asserted against the file: a line number that does not resolve to a note line is a label that
    #     looks precise and is not, which would be a worse failure than the vague one it replaced.
    Write-Host "inbound #286 -- the note's [remove] lines name which line they mean" -ForegroundColor Cyan
    New-BootstrappedConsumer | Out-Null
    $np = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $np.Code 'note report: preview exit-code 0'
    $noteRx    = "(?m)^\s*\[remove\]\s+CLAUDE\.md:(?<line>\d+) -- the bootstrap's orchestrator note \((?<part>head|tail)\)\s*$"
    $noteLines = @([regex]::Matches($np.Out, $noteRx))
    Assert-Equal 2 $noteLines.Count 'note report: two [remove] lines for the two-line note block'
    Assert-Equal 2 (@($noteLines | ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique).Count) `
        'note report: and they are DISTINCT -- the finding was two byte-identical lines'
    Assert-Equal 'head,tail' ((@($noteLines | ForEach-Object { $_.Groups['part'].Value } | Sort-Object) -join ',')) `
        'note report: one is labelled head, the other tail'
    # The line numbers must be real. Resolved against the file the run was about to edit.
    $fxLines = [System.IO.File]::ReadAllLines((Join-Path $Fixture 'CLAUDE.md'))
    foreach ($m in $noteLines) {
        $n = [int]$m.Groups['line'].Value
        $ok = ($n -ge 1 -and $n -le $fxLines.Count) -and (Test-IsOrchestratorNoteLine -Line $fxLines[$n - 1])
        Assert-True $ok "note report: CLAUDE.md:$n really is a note line in the file"
        $expected = if ($fxLines[$n - 1].Trim() -eq $noteSrc.Head) { 'head' } else { 'tail' }
        Assert-Equal $expected $m.Groups['part'].Value "note report: CLAUDE.md:$n is labelled with the half it actually is"
    }
    # Preview and apply must agree here too, for the same reason the totals must: the reader says yes to
    # the preview.
    $na = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $na.Code 'note report: apply exit-code 0'
    $naLines = @([regex]::Matches($na.Out, $noteRx))
    Assert-Equal (@($noteLines | ForEach-Object { $_.Value.Trim() }) -join '|') (@($naLines | ForEach-Object { $_.Value.Trim() }) -join '|') `
        'note report: the apply run prints the same two lines as the preview'

    # --- inbound #331: the FRESH consumer -- no CLAUDE.md before adoption ----------------------------
    #     Every fixture above hands the bootstrap a CLAUDE.md it already has, so the branch that CREATES
    #     one -- scaffold heading plus two prose lines -- was never exercised by this suite at all. On that
    #     path every byte of the file is bootstrap-written, and after -Apply those two lines were the only
    #     thing left in it while being reported as NEITHER [remove] nor [KEEP], with the audit printing
    #     [FREE]. The audit was narrowly right (the lines name no specialist), which is what made the
    #     silence the finding: this script's contract is that [remove] versus [KEEP] tells the reader which
    #     case they were in. Same blind-spot shape the bootstrap documents about itself one file over: the
    #     path a real adoption takes was the path no fixture took.
    Write-Host "inbound #331 -- the fresh consumer: scaffold prose and the emptied scripts dir" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true } }')
    # Deliberately NO CLAUDE.md. That is the whole fixture.
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    $env:CLAUDE_PLUGIN_ROOT = $Plugin
    try {
        $fb = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture)
        if ($fb.Code -ne 0) { throw "fresh bootstrap failed (exit $($fb.Code)): $($fb.Out)" }
    } finally { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }

    $scaffold = Get-ClaudeMdScaffold
    $freshMd  = [System.IO.File]::ReadAllLines((Join-Path $Fixture 'CLAUDE.md'))
    Assert-True (@($freshMd | Where-Object { Test-IsClaudeMdScaffoldProseLine -Line $_ }).Count -eq $scaffold.Prose.Count) `
        'fresh: the bootstrap wrote the scaffold prose from the shared source (so the literal is not mirrored by hand)'

    $fp = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $fp.Code 'fresh: preview exit-code 0'
    $keepRx    = "(?m)^\s*\[KEEP\]\s+CLAUDE\.md:(?<line>\d+) -- the bootstrap's scaffold prose"
    $keepPrev  = @([regex]::Matches($fp.Out, $keepRx))
    Assert-Equal $scaffold.Prose.Count $keepPrev.Count 'fresh: every scaffold prose line is REPORTED as [KEEP] -- it was neither before'
    # The line numbers must resolve, for the same reason #286 required it of the note: a label that looks
    # precise and is not would be worse than the silence it replaced.
    foreach ($m in $keepPrev) {
        $n = [int]$m.Groups['line'].Value
        Assert-True (($n -ge 1 -and $n -le $freshMd.Count) -and (Test-IsClaudeMdScaffoldProseLine -Line $freshMd[$n - 1])) `
            "fresh: CLAUDE.md:$n really is a scaffold prose line in the file"
    }

    $fa = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture, '-Apply')
    Assert-Equal 0 $fa.Code 'fresh: apply exit-code 0'
    Assert-Equal $keepPrev.Count @([regex]::Matches($fa.Out, $keepRx)).Count 'fresh: the apply run reports them identically'
    # Reported, NOT removed -- deleting prose out of somebody's governance file is the other side of this
    # script's boundary, so the lines must still be on disk after -Apply.
    $afterMd = [System.IO.File]::ReadAllLines((Join-Path $Fixture 'CLAUDE.md'))
    Assert-Equal $scaffold.Prose.Count @($afterMd | Where-Object { Test-IsClaudeMdScaffoldProseLine -Line $_ }).Count `
        'fresh: and they are KEPT on disk -- reporting them is the fix, deleting prose is not this script''s job'

    # --- inbound #356: the summary's figure must equal the markers printed above it ------------------
    # This exact fixture is where they diverged, on the row #331 was filed for: two [KEEP] lines, a
    # [note] saying "2 line(s)", and a summary saying "0 kept" -- because the scaffold-prose loop printed
    # its own marker straight to the host and never touched $kept.
    #
    # Asserted as the INVARIANT (every marker is counted) rather than against the literal 2. Two reasons,
    # and the second is the load-bearing one: a fixture that grows a third prose line must not need this
    # test rewritten, and a hardcoded expectation could pass while both sides carried the same error --
    # which is the failure this test exists to catch. Both modes, because #275 was preview and apply
    # disagreeing over the other counter.
    foreach ($run in @(@{ N = 'preview'; R = $fp }, @{ N = 'apply'; R = $fa })) {
        $markers = @([regex]::Matches($run.R.Out, '(?m)^\s*\[KEEP\]\s')).Count
        $sm = [regex]::Match($run.R.Out, 'Summary:\s+\d+ item\(s\) (?:to remove|removed),\s+(?<kept>\d+) kept\.')
        Assert-True $sm.Success "fresh/$($run.N): the summary line is present and parseable"
        Assert-Equal $markers ([int]$sm.Groups['kept'].Value) `
            "fresh/$($run.N): the summary's kept figure equals the [KEEP] markers above it (#356)"
        Assert-True ($markers -gt 0) "fresh/$($run.N): and it is a real check -- this fixture does print [KEEP] markers"
    }
    # The remedy is grouped, because the -EmptyLensPattern escape hatch is true of an unrecognised
    # scaffold and false of a prose line in a governance file.
    Assert-True ($fp.Out -match '(?m)^\s+Kept -- generated prose in a governance file') `
        'fresh: kept prose is listed under its own remedy, not under the -EmptyLensPattern advice'
    Assert-True (-not ($fp.Out -match "(?s)Kept -- generated prose in a governance file.*?EmptyLensPattern")) `
        'fresh: and that advice is not repeated underneath it'

    # The second half of #331: scripts\lib\ survived every round as an empty directory, because the single
    # pruning pass ran before the only file in it was planned for removal.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib'))) `
        'fresh: scripts\lib\ is gone rather than left behind as an empty directory'
    Assert-True ($fp.Out -match '(?m)^\s*\[remove\].*scripts\\lib\\ \(empty directory\)') `
        'fresh: and the preview said it would go -- same rule as the lens directory (#275)'

    # --- inbound #381: the untouched-install note is a READING, not an assertion ---------------------
    # Round v13 reached this note by the route UNINSTALL.md Step 4 now offers -- re-run the audit from
    # the cache AFTER the uninstall -- and was told the install was untouched one step after seeing
    # "Successfully uninstalled". So the three states are pinned separately, because "no record" and
    # "could not look" are different claims and the old code could make neither.
    Write-Host "-- inbound #381: the install-record gate --" -ForegroundColor Cyan
    $null = New-BootstrappedConsumer
    $fakeHome = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-teardown-claudehome-$PID-$([guid]::NewGuid().ToString('n'))"
    $prevCfg  = $env:CLAUDE_CONFIG_DIR
    try {
        New-Item -ItemType Directory -Path (Join-Path $fakeHome 'plugins') -Force | Out-Null
        $recordsFile = Join-Path $fakeHome 'plugins\installed_plugins.json'
        $env:CLAUDE_CONFIG_DIR = $fakeHome

        # State 1 -- a record points here. The note names it, with the scope off the record rather than
        # an assumed 'project': an uninstall aimed at the wrong scope is the failure UNINSTALL.md spends
        # a paragraph on, and a session start can put a record in 'local' by itself.
        [System.IO.File]::WriteAllText($recordsFile, (@{
            plugins = @{ 'dkj-subagents-alpha@dkj-claude-plugins' = @(@{
                scope = 'local'; projectPath = $Fixture; version = '3.1.2'
            }) }
        } | ConvertTo-Json -Depth 6))
        $g1 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
        Assert-True ($g1.Out -match 'still has a record: dkj-subagents-alpha@dkj-claude-plugins \(scope local\)') `
            'gate/record: the note names the plugin and the scope the record is actually in'
        Assert-True ($g1.Out -match 'claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins --scope local') `
            'gate/record: and the command it prints carries that same scope'
        Assert-True (-not ($g1.Out -match 'No install record points at this repo')) `
            'gate/record: it does not also claim the repo is clean'

        # State 2 -- readable, nothing points here. THE case from #381: this is what the Step 4 re-run
        # must read like, and the old note said the opposite.
        [System.IO.File]::WriteAllText($recordsFile, (@{
            plugins = @{ 'dkj-subagents-alpha@dkj-claude-plugins' = @(@{
                scope = 'project'; projectPath = 'C:\somewhere\else'; version = '3.1.2'
            }) }
        } | ConvertTo-Json -Depth 6))
        $g2 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
        Assert-True ($g2.Out -match 'No install record points at this repo any more') `
            'gate/clean: a record for another repo does not count as one for this one'
        Assert-True (-not ($g2.Out -match 'The plugin install itself is untouched')) `
            'gate/clean: and the untouched-install claim is gone rather than merely reworded (#381)'
        Assert-True (-not ($g2.Out -match 'claude plugin uninstall')) `
            'gate/clean: it does not advise a command the reader has already run'

        # State 3 -- no file to read. Reported as "could not look", never as state 2: a teardown that
        # cannot measure must not report clean, which is the whole point of gating this note.
        Remove-Item -LiteralPath $recordsFile -Force
        $g3 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
        Assert-True ($g3.Out -match 'could not read .*installed_plugins\.json \(missing or not parseable\)') `
            'gate/blind: a missing records file is named as a gap in the reading'
        Assert-True (-not ($g3.Out -match 'No install record points at this repo')) `
            'gate/blind: and is NOT reported as a clean machine'

        # State 3 again, via the other route into it: a file that exists but is not JSON. Same claim,
        # because the honest answer to both is "I did not measure this".
        [System.IO.File]::WriteAllText($recordsFile, 'not json at all {{{')
        $g4 = Invoke-Script -Path $Teardown -ScriptArgs @('-ConsumerRoot', $Fixture)
        Assert-True ($g4.Out -match 'could not read .*installed_plugins\.json \(missing or not parseable\)') `
            'gate/blind: an unparseable records file reads the same way, and does not crash the teardown'
        Assert-Equal 0 $g4.Code 'gate/blind: the teardown still exits 0 on a broken records file'
    }
    finally {
        $env:CLAUDE_CONFIG_DIR = $prevCfg
        if (Test-Path -LiteralPath $fakeHome) { Remove-Item -Recurse -Force -LiteralPath $fakeHome -ErrorAction SilentlyContinue }
    }
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
