<#
.SYNOPSIS
    Regression tests for the bootstrap adoption path: the skill bootstrap (bootstrap.ps1) and the
    persona drift detection in check-consumer-drift.ps1.

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. Integration style -- it runs the real scripts
    against a throwaway fixture consumer in the temp folder and asserts on their exit code + output.
    The scripts themselves call 'exit', so they are run in a CHILD PROCESS (powershell -File),
    otherwise 'exit' would abort the test runner itself.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bootstrap-drift.tests.ps1

    The bootstrap seeds the lenses on the PLUGIN PATH (.claude/plugins/<family>/<plugin>/) and the
    persona lenses are LENS-ONLY (no body copy; the body comes via @-import from the plugin install).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$Bootstrap  = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\skills\specialists-init\bootstrap.ps1'
$DriftLint  = Join-Path $RepoRoot 'scripts\lint\check-consumer-drift.ps1'
$Integrity  = Join-Path $RepoRoot 'scripts\lint\check-plugin-integrity.ps1'
$Fixture    = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
# Where a FRESH consumer's lenses land as of the seam (issue #221): one flat directory, no per-plugin
# segment, because <group>-<id> is unique family-wide.
$Pp         = '.claude\specialists\lenses'
$Seam       = '.claude\specialists'
$SeamInclusion = '.claude\specialists\SPECIALISTS.md'
$SeamImport = '@.claude/specialists/SPECIALISTS.md'
# The pre-seam plugin path (family = claude-specialists). Still READ by every reader, and still WRITTEN
# for a consumer that already has a lens tree there -- the bootstrap never relocates one.
$PpLegacy   = '.claude\plugins\claude-specialists\dkj-subagents-alpha'
$PersonaSrc = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\personas\01-01-persona.md'

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

# Runs a .ps1 in a child process and returns [pscustomobject]@{ Code; Out }.
function Invoke-Script {
    param([string]$Path, [string[]]$ScriptArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ScriptArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Reset-Fixture {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Isolate the USER layer of the settings chain for every child process this suite starts (inbound #294).
# bootstrap.ps1 now reads enabledPlugins from ~/.claude/settings.json as well as the consumer's own two
# files, so without this the lens counts asserted below would depend on what the machine running the
# suite happens to have enabled globally -- green here, red elsewhere, for a reason no assertion names.
# $env:USERPROFILE is what Get-SettingsChainPaths resolves and what a child process inherits, so
# redirecting it once covers every Invoke-Script call (the same technique connectors.tests.ps1 uses).
$OldUserProfile = $env:USERPROFILE
$env:USERPROFILE = Join-Path $Fixture '..\bootstrap-drift-no-user-home'

try {
    # --- 1. Bootstrap against a fresh repo: lens-only personas in the seam --------------------------
    Write-Host "bootstrap.ps1 -- fresh repo (the seam + lens-only)" -ForegroundColor Cyan
    Reset-Fixture
    $r1 = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $r1.Code 'bootstrap exit 0 on a fresh repo'
    foreach ($f in 'specialist-01-01-lens.md', 'specialist-05-05-lens.md', 'specialist-05-06-lens.md') {
        Assert-True (Test-Path -LiteralPath (Join-Path $Fixture "$Pp\$f")) "persona lens $f in the seam"
    }
    foreach ($f in 'specialist-06-16-lens.md', 'specialist-06-23-lens.md') {
        Assert-True (Test-Path -LiteralPath (Join-Path $Fixture "$Pp\$f")) "lens scaffold $f in the seam"
    }
    # Nothing lands on the pre-seam path for a fresh consumer -- one surface, not two.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture $PpLegacy))) 'fresh repo: nothing written to the pre-seam plugin path'
    $lensText = [System.IO.File]::ReadAllText((Join-Path $Fixture "$Pp\specialist-06-16-lens.md"), [System.Text.Encoding]::UTF8)
    Assert-True ($lensText -match 'VUL-IN') 'lens scaffold carries the VUL-IN marker'
    # Still asserted, and now the load-bearing half: after the title lost its marker (inbound #451) the
    # SLOT is the only thing left carrying one, so this line is what proves an unfilled scaffold is still
    # RECOGNISABLE as unfilled. Drop it and the fix could silently become "no marker anywhere", which
    # makes the teardown keep every empty lens forever -- the opposite defect, same root.
    Assert-True ($lensText -match '(?m)^##\sSpecific to this repo \(VUL-IN\)\s*$') 'lens scaffold marks the SLOT heading -- the signal the teardown keys on'
    # Rename-proof (issue #145): the agent-lens header carries the stable g-id slug, not the persona
    # name -- so a later rename of the agent-def never drifts this generated header.
    Assert-True ($lensText -match '(?m)^# 06-16 .* repo lens\s*$') 'lens scaffold header is the nameless g-id form (issue #145)'
    # THE MIRROR OF THE SPECIALISTS.md ASSERTION BELOW (inbound #451), and the reason it exists: filling a
    # lens replaces the SLOT heading and never touches the title, while Test-LooksGenerated matches
    # '(VUL-IN)' at any heading level. A marked title therefore outlives the filling and makes
    # specialists-teardown list authored repo knowledge as removable. Measured in a consumer with 24
    # lenses: three filled ones holding 153 lines all printed [remove].
    Assert-True (-not ($lensText -match '(?m)^#\s[^\r\n]*\(VUL-IN\)')) 'lens TITLE carries NO VUL-IN -- only the slot does'
    Assert-True (-not ($lensText -match 'Victor')) 'lens scaffold does NOT bake the persona name (Victor) in (issue #145)'
    $claudeMd = Join-Path $Fixture 'CLAUDE.md'
    Assert-True (Test-Path -LiteralPath $claudeMd) 'CLAUDE.md scaffold created'
    $mdText = [System.IO.File]::ReadAllText($claudeMd, [System.Text.Encoding]::UTF8)
    # THE SEAM: CLAUDE.md carries exactly ONE specialist line, and the two imports it used to hold now
    # live in SPECIALISTS.md. That single-line property is the whole reason a teardown can be "remove one
    # directory and one line", so it is asserted as a COUNT, not just as a presence.
    Assert-True ($mdText -match [regex]::Escape($SeamImport)) 'CLAUDE.md carries the single seam import'
    Assert-Equal 1 (@([System.IO.File]::ReadAllLines($claudeMd) | Where-Object { $_ -match '^\s*@' }).Count) 'CLAUDE.md carries exactly ONE import line'
    $inclusion = Join-Path $Fixture $SeamInclusion
    Assert-True (Test-Path -LiteralPath $inclusion) 'the seam inclusion SPECIALISTS.md is placed'
    $inclText = [System.IO.File]::ReadAllText($inclusion, [System.Text.Encoding]::UTF8)
    Assert-True ($inclText -match '(?m)^@[^\r\n]*personas/01-01-persona\.md') 'SPECIALISTS.md carries the body @-import (from the plugin install)'
    # Relative, because "relative paths resolve relative to the file containing the import".
    Assert-True ($inclText -match '(?m)^@lenses/specialist-01-01-lens\.md') 'SPECIALISTS.md imports the lens relative to itself'
    # The roster slot carries the marker; the TITLE deliberately does not. Filling in the roster removes
    # the marker, so a teardown reads the file as authored instead of deleting somebody's roster.
    Assert-True ($inclText -match '(?m)^##\s.*\(VUL-IN\)\s*$') 'SPECIALISTS.md has a VUL-IN roster slot'
    Assert-True (-not ($inclText -match '(?m)^#\s[^\r\n]*\(VUL-IN\)')) 'SPECIALISTS.md title carries NO VUL-IN -- only the roster slot does'
    Assert-True (Test-Path -LiteralPath (Join-Path $Fixture '.claude\settings.suggested.jsonc')) 'settings.suggested.jsonc placed'
    # The FULL path, not the relative name (#241). Many consumers gitignore '.claude/*', so this file
    # never appears in 'git status' and 'git checkout .' does not clean it up -- an operator verifying a
    # round-trip with git alone cannot see it exists. The stdout line is the only pointer they get, so
    # it has to be a path they can act on.
    Assert-True ($r1.Out -match [regex]::Escape((Join-Path $Fixture '.claude\settings.suggested.jsonc'))) 'the proposal is announced by FULL path -- git cannot announce it in a repo that ignores .claude/*'

    # --- inbound #363: the proposal must not invite copying a hook that points at nothing -------------
    # The Stop hook names a script this bootstrap does not create and nothing else ships. The file itself
    # said "STUB" twice already; what it lacked was a path a reader could not mistake for a real one, and
    # a console step 3 that named the exception while inviting "copy desired parts". Both asserted,
    # because the warning being present somewhere is exactly what made this survive to v11.
    $suggestText = [System.IO.File]::ReadAllText((Join-Path $Fixture '.claude\settings.suggested.jsonc'))
    Assert-True ($suggestText -match 'scripts/maintenance/<[^>]+>\.ps1') `
        'the proposed hook path is visibly a placeholder, not a plausible-looking real path (#363)'
    Assert-True (-not ($suggestText -match 'lint-changed-hook\.ps1')) `
        'and the old copyable-looking name is gone'
    # REWORDED BY #1124, NOT WEAKENED. Step 3 used to open with "Copy desired parts", and it now opens
    # with the replacement, because there is a merged file to replace WITH -- but both #363 caveats have
    # to survive that rewording, which is exactly the kind of thing a rewrite drops. So the two halves
    # are asserted separately: the step names the one-move act, and the block caveat is still printed.
    Assert-True ($r1.Out -match "(?s)Replace \.claude/settings\.json with.*?one move, no merging") `
        'step 3 names the one-move replacement, not a hand-merge (#1124)'
    Assert-True ($r1.Out -match "(?s)'permissions' block is ready to use.*?'hooks' block is NOT") `
        'step 3 still names which block is ready to use and which is not -- the #363 caveat survived the rewording'
    # Trailing newline. The here-string ends at its closing brace and WriteAllText adds nothing; the
    # #337.2 warning covers CLAUDE.md and not this file, so nothing pointed at it.
    Assert-True ($suggestText.EndsWith("`n")) 'settings.suggested.jsonc ends in a newline (#363)'

    # --- inbound #1075: the proposal carries BOTH permission halves ---------------------------------
    # It used to carry one -- 'deny' -- so a consumer following the adoption to the letter got a repo
    # that forbids five things and permits nothing, and the only person who may widen a permissions
    # file was handed nothing to paste. This fixture enables NO workflow plugin, so the allow half is
    # empty here on purpose: what is asserted is that the emptiness is STATED rather than absent, which
    # is the difference between "nothing to permit" and "we forgot".
    Assert-True ($suggestText -match '"allow"\s*:\s*\[') 'core-only: the proposal has an allow half at all (#1075)'
    Assert-True ($suggestText -match '"allow"\s*:\s*\[\s*\]') 'core-only: and it is empty -- no workflow plugin, so no scripted entry point to permit'

    # --- inbound #1124: the ANNOTATED file must say the destination is not empty ---------------------
    # Two of this file's three copy traps were warned about (the comments, #1097; the hooks stub, #363).
    # The third -- that .claude/settings.json ALREADY HOLDS enabledPlugins and extraKnownMarketplaces,
    # so a whole-file paste deletes them -- was warned about nowhere, and it is the one that lands the
    # reader in #1076's zero-surface state through a file that parses perfectly. Asserted on the two key
    # NAMES rather than on prose: a reader needs to know which keys must survive, and a warning that
    # does not name them cannot be acted on.
    Assert-True ($suggestText -match 'DO NOT PASTE IT WHOLE') 'the annotated proposal says it is not a whole-file replacement (#1124)'
    foreach ($key in @('enabledPlugins', 'extraKnownMarketplaces')) {
        Assert-True ($suggestText -match "(?s)DO NOT PASTE IT WHOLE.*?$key") `
            "and it names '$key' as a key the destination already holds"
    }
    Assert-True ($suggestText -match 'settings\.proposed\.json') 'and it points at the merged file beside it'

    # --- inbound #1124: the MERGED file, on a consumer whose settings.json does not exist ------------
    # This fixture has no settings.json at all, which is the honest case for a repo whose enable sits in
    # the user layer or in settings.local.json. What must hold is that the merged file is still written
    # (replacing an absent file with it is correct and lossless), that it is STRICT json, and that the
    # announce line does not promise preservation of keys there were none of -- 'your keys are kept' is
    # reassuring, meaningless here, and stops a reader checking.
    $proposedCore = Join-Path $Fixture '.claude\settings.proposed.json'
    Assert-True (Test-Path -LiteralPath $proposedCore) 'core-only: settings.proposed.json placed (#1124)'
    $proposedCoreText = [System.IO.File]::ReadAllText($proposedCore, [System.Text.Encoding]::UTF8)
    Assert-True (-not ($proposedCoreText -match '(?m)^\s*//')) 'core-only: the merged file carries NO comments -- it is strict JSON, unlike the .jsonc beside it'
    Assert-True (-not ($proposedCoreText -match 'scripts/maintenance/<')) 'core-only: and no hooks stub -- a file whose promise is "paste this" must not ship a hook pointing at nothing'
    Assert-True ($proposedCoreText.EndsWith("`n")) 'core-only: the merged file ends in a newline (#363, one file over)'
    Assert-True ($r1.Out -match 'nothing to carry over') `
        'core-only: the announce line says there was nothing to preserve rather than claiming preservation'
    # It has to PARSE, which is the whole claim the file makes. ConvertFrom-Json is the same reader
    # Claude Code's own parse failure would stand in for.
    $proposedCoreObj = $null
    try { $proposedCoreObj = $proposedCoreText | ConvertFrom-Json } catch { $proposedCoreObj = $null }
    Assert-True ($null -ne $proposedCoreObj) 'core-only: the merged file parses as strict JSON'
    Assert-True ($null -ne $proposedCoreObj -and @($proposedCoreObj.permissions.deny).Count -eq 5) 'core-only: and it carries the five deny rules'
    Assert-True ($suggestText -match 'no workflow plugin is enabled here') 'core-only: the empty allow half says WHY it is empty'

    # --- 1b. Register proposal: the bootstrap points at the workshop register (gap found 2026-07-28) --
    #     Bootstrapping a consumer used to leave no trace towards the connector register, and nothing
    #     else filled that gap -- a third consumer ran unregistered for days while the workshop stayed
    #     blind to its plugin version, lens inventory and agent-def drift. The script cannot create the
    #     manifest (it lives in the workshop; the register never writes cross-repo), so it must hand one
    #     over. These assertions pin the handover, not the wording of the prose around it.
    Assert-True ($r1.Out -match 'connector register proposal') 'register proposal: the bootstrap prints a register block'
    Assert-True ($r1.Out -match '"repo"\s*:') 'register proposal: the block is a manifest with a repo field'
    # The inventory must cover BOTH lens kinds -- a persona-only specialist (01-01) and an agent
    # (06-16). Missing the personas would hand over a manifest that under-reports the repo, which is
    # exactly the class of bug inbound #204 was about.
    Assert-True ($r1.Out -match '"01-01"') 'register proposal: inventory includes a persona-only id'
    Assert-True ($r1.Out -match '"06-16"') 'register proposal: inventory includes an agent id'
    # The two fields this script genuinely cannot know stay VUL-IN rather than being guessed: it has no
    # idea where the workshop checkout sits relative to this repo, and a guessed path is what the
    # register's marker check exists to prevent.
    Assert-True ($r1.Out -match 'visibility.*VUL-IN') 'register proposal: visibility is left as VUL-IN, not guessed'
    Assert-True ($r1.Out -match 'localCheckout.*VUL-IN') 'register proposal: localCheckout is left as VUL-IN, not guessed'
    # Propose-only, like every other bootstrap output: nothing may be written into the consumer.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'connectors'))) 'register proposal: writes no connectors/ dir into the consumer'

    # --- 1c. scripts/ scaffolds (#86) -- THE CORE-ONLY SHAPE ---------------------------------------
    # SPLIT INTO TWO CASES ON AUGUST 8, 2026, when the branch/release workflow became its own opt-in
    # plugin. What the bootstrap writes now depends on whether the consumer enabled that pack, and this
    # fixture has no settings.json at all -- so it IS the plain consumer, which is the case the
    # plugin-serves-the-consumer doctrine is about. Asserting only the full shape here would have left
    # the case that matters most untested while looking thorough.
    Write-Host "bootstrap.ps1 -- script-config scaffolds (#86), core-only consumer" -ForegroundColor Cyan
    $rcScaffold = Join-Path $Fixture 'scripts\repo-config.ps1'
    $biScaffold = Join-Path $Fixture 'scripts\lib\branch-info.ps1'
    Assert-True (Test-Path -LiteralPath $rcScaffold) 'core-only: scripts/repo-config.ps1 placed -- check-roster-sync reads the roster half'
    Assert-True (-not (Test-Path -LiteralPath $biScaffold)) 'core-only: scripts/lib/branch-info.ps1 NOT placed -- both its functions serve scripts this consumer does not have'
    $rcText = [System.IO.File]::ReadAllText($rcScaffold, [System.Text.Encoding]::UTF8)
    Assert-True ($rcText -match 'function Get-RosterPath') 'core-only: the roster half is there -- Get-RosterPath'
    Assert-True ($rcText -match 'function Get-RosterIgnoredIds') 'core-only: the roster half is there -- Get-RosterIgnoredIds'
    foreach ($wf in 'Get-RepoName', 'Get-LintScript', 'Get-ChangelogHeading', 'Get-LiveStage') {
        Assert-True (-not ($rcText -match "function $wf\b")) "core-only: $wf is absent -- nothing in this repo would read it"
    }
    # The roster half has nothing to fill in, so it carries no placeholder VALUE. Asserted because the
    # teardown's classification turns on exactly that, and the case below proves it still recognises
    # this shape as generated rather than authored.
    Assert-True (-not ($rcText -match "=\s*'[^']*VUL-IN")) 'core-only: no placeholder value -- the roster half is complete as generated'
    Assert-True ($r1.Out -match 'dkj-policy') 'core-only: the run NAMES the pack the missing half belongs to, so the absence is legible'

    # --- 1c0. The core-only scaffold must stay REMOVABLE by the teardown ---------------------------
    # Without this, a file the bootstrap just wrote is classified as authored and kept forever --
    # adoption exactly as irreversible as specialists-teardown promises it is not.
    Write-Host "bootstrap.ps1 -- the core-only scaffold stays removable by the teardown" -ForegroundColor Cyan
    $teardownScript = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\skills\specialists-teardown\teardown.ps1'
    function Test-TeardownSeesGenerated {
        param([string]$Path)
        # The classifier alone, lifted out of the script text: running the whole teardown here would
        # need a fully staged consumer and would test far more than the one question being asked.
        & {
            Set-StrictMode -Off
            $EmptyLensPattern = ''
            $src = [System.IO.File]::ReadAllText($teardownScript, [System.Text.Encoding]::UTF8)
            $m = [regex]::Match($src, '(?ms)^function Test-LooksGenerated \{.*?\r?\n\}\r?\n')
            if (-not $m.Success) { return 'NO-MATCH' }
            . ([scriptblock]::Create($m.Value))
            return [bool](Test-LooksGenerated -Path $Path -Kind 'repo-config')
        }
    }
    Assert-Equal $true (Test-TeardownSeesGenerated $rcScaffold) 'teardown: an untouched core-only repo-config reads as generated (removable)'
    $touchedRc = Join-Path $Fixture 'scripts\repo-config-touched.ps1'
    [System.IO.File]::WriteAllText($touchedRc, $rcText.Replace('$script:RosterIgnoredIds = @()', "`$script:RosterIgnoredIds = @('06-16')"), $Utf8NoBom)
    Assert-Equal $false (Test-TeardownSeesGenerated $touchedRc) 'teardown: one ignored id added and it reads as authored (kept)'
    # THE LOOK-ALIKE. A consumer's own file can hold exactly these two functions and an empty ignore
    # list; only the bootstrap's own docstring says who wrote it. Without this test the shape test
    # alone would delete somebody's hand-written config -- the direction a removing script must never
    # resolve doubt in.
    [System.IO.File]::WriteAllText($touchedRc, $rcText.Replace('Placed by specialists-init', 'Written by hand for this repo'), $Utf8NoBom)
    Assert-Equal $false (Test-TeardownSeesGenerated $touchedRc) "teardown: a look-alike that never claims the bootstrap wrote it is KEPT"
    Remove-Item -LiteralPath $touchedRc -Force

    # --- 1c1. The SAME bootstrap against a consumer that DID enable the workflow plugin ---------------
    # Everything this suite used to assert on the single fixture lives here now: the shape a consumer
    # receives when they chose that way of working.
    Write-Host "bootstrap.ps1 -- script-config scaffolds (#86), workflow plugin enabled" -ForegroundColor Cyan
    $FixtureWf = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-wf-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $FixtureWf) { Remove-Item -Recurse -Force -LiteralPath $FixtureWf }
    New-Item -ItemType Directory -Path (Join-Path $FixtureWf '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $FixtureWf '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true } }', $Utf8NoBom)
    $rWf = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureWf)
    Assert-Equal 0 $rWf.Code 'workflow plugin: bootstrap exit 0'
    $rcScaffold = Join-Path $FixtureWf 'scripts\repo-config.ps1'
    $biScaffold = Join-Path $FixtureWf 'scripts\lib\branch-info.ps1'
    Assert-True (Test-Path -LiteralPath $rcScaffold) 'workflow plugin: scripts/repo-config.ps1 scaffold placed'
    Assert-True (Test-Path -LiteralPath $biScaffold) 'workflow plugin: scripts/lib/branch-info.ps1 scaffold placed'

    # --- inbound #1075: with a workflow enabled, the allow half names ITS entry points ---------------
    # The rules are asserted by SHAPE, not by literal path, and that is the finding rather than test
    # convenience: the report asked for the resolved plugin root, which is version-pinned
    # (.../cache/<marketplace>/<plugin>/<version>/), so a rule carrying today's path stops matching at
    # the consumer's next plugin update -- silently, while still reading as covered. The wildcard is
    # what makes the rule outlive an update, so what has to hold is that the path IS wildcarded and
    # that the plugin name and the script name are the literal parts anchoring it.
    $sugWf = [System.IO.File]::ReadAllText((Join-Path $FixtureWf '.claude\settings.suggested.jsonc'))
    foreach ($entry in @('new-branch.ps1', 'open-pr.ps1', 'ship-pr.ps1')) {
        Assert-True ($sugWf -match [regex]::Escape("`"Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *dkj-policy*$entry*)`"")) `
            "workflow plugin: allow half covers $entry through the Bash tool (#1075)"
        Assert-True ($sugWf -match [regex]::Escape("`"PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File *dkj-policy*$entry*)`"")) `
            "workflow plugin: allow half covers $entry through the PowerShell tool (#1075)"
    }
    Assert-True ($sugWf -match 'gh repo edit --delete-branch-on-merge') 'workflow plugin: allow half covers the one gh repo edit the workflow assumes'
    # THE EXCLUSION IS THE POINT, so it is pinned rather than left to the comment beside it: a release
    # is irreversible and outward-facing, and the whole value of a narrow allow half is that a reader
    # can see what it does NOT wave through. Matched against the RULES only, not the whole file --
    # the comment above them names those exclusions on purpose, and a whole-file match would read that
    # sentence as the very thing it warns against.
    $allowRules = ([regex]::Match($sugWf, '(?s)"allow"\s*:\s*\[(.*?)\]')).Groups[1].Value
    Assert-True ($allowRules -match 'new-branch\.ps1') 'workflow plugin: the extracted allow rules are the rules (guard on the extraction itself)'
    Assert-True (-not ($allowRules -match 'cut-release')) 'workflow plugin: cut-release is deliberately NOT allowed -- a release is worth a prompt'
    Assert-True (-not ($allowRules -match 'gh repo delete|gh repo archive')) 'workflow plugin: and neither is deleting or archiving the repo'
    # The next-steps line is where a reader is actually invited to copy the block, so the caveat lives
    # there too (the #363 rule, applied to the half #1075 added).
    Assert-True ($rWf.Out -match "(?s)'permissions' block is ready to use as-is.*BOTH halves.*allow.*new-branch") `
        'workflow plugin: step 3 says the block has both halves and what the allow half covers'

    # --- inbound #1124: the merged file on a POPULATED destination, which is the reported case --------
    # This fixture's settings.json carries enabledPlugins, which is what the whole-file paste deleted.
    # Everything below is one claim tested from several sides: replacing settings.json with the merged
    # file loses nothing. It is asserted through ConvertFrom-Json rather than by matching text, because
    # what has to hold is what CLAUDE CODE would read back, not what the bytes look like.
    $proposedWf = Join-Path $FixtureWf '.claude\settings.proposed.json'
    Assert-True (Test-Path -LiteralPath $proposedWf) 'workflow plugin: settings.proposed.json placed (#1124)'
    $proposedWfText = [System.IO.File]::ReadAllText($proposedWf, [System.Text.Encoding]::UTF8)
    $wfObj = $null
    try { $wfObj = $proposedWfText | ConvertFrom-Json } catch { $wfObj = $null }
    Assert-True ($null -ne $wfObj) 'workflow plugin: the merged file parses as strict JSON'
    if ($null -ne $wfObj) {
        # THE DEFECT ITSELF. Without this the paste produces a valid settings file with no plugin
        # surface at all -- 3 -> 0 SessionStart hooks, 6 -> 0 skills, 15 -> 0 subagents, and no message
        # (the state #1076 measured). Both plugins, because losing one is the same failure for that one.
        foreach ($id in @('dkj-subagents-alpha@dkj-claude-plugins', 'dkj-policy@dkj-claude-plugins')) {
            Assert-True (@($wfObj.enabledPlugins.PSObject.Properties | Where-Object { $_.Name -eq $id }).Count -eq 1) `
                "workflow plugin: the merged file KEEPS enabledPlugins['$id'] -- the key a whole-file paste deleted (#1124)"
        }
        # Both halves actually merged in, not merely mentioned.
        $wfAllow = @($wfObj.permissions.allow)
        $wfDeny  = @($wfObj.permissions.deny)
        Assert-True ($wfAllow.Count -eq 7) 'workflow plugin: the merged file carries all seven allow rules'
        Assert-True ($wfDeny.Count -eq 5)  'workflow plugin: and the five deny rules'
        Assert-True (@($wfAllow | Where-Object { $_ -match 'new-branch\.ps1' }).Count -eq 2) `
            'workflow plugin: new-branch is allowed through both tool shapes -- the array was not flattened into one string'
        # THE FLATTENING GUARD, and it is here because it actually happened. The merge was first written
        # with '$have = if (...) { @($x) } else { @() }'; an if-EXPRESSION returns through the output
        # pipeline, which unrolls a one-element array to the bare element, so '+' concatenated the new
        # rules onto it as TEXT. The file stayed valid JSON and permitted nothing.
        Assert-True (@($wfAllow | Where-Object { $_ -match 'new-branch.*open-pr' }).Count -eq 0) `
            'workflow plugin: no rule is two rules concatenated -- the one-element-array unroll trap'
        Assert-True (@($wfObj.PSObject.Properties | Where-Object { $_.Name -eq 'hooks' }).Count -eq 0) `
            'workflow plugin: the merged file omits the hooks STUB -- a paste-this file must not ship a hook pointing at nothing'
    }
    Assert-True ($rWf.Out -match 'it keeps .*enabledPlugins') `
        'workflow plugin: the announce line names the keys it carried over, so the reader can check the claim'

    # --- inbound #1124: rerunning must not duplicate rules, and must not lose the consumer's own ------
    # A consumer's own rules come first and ours are appended; a second run adds nothing. This matters
    # because specialists-init is explicitly safe to invoke repeatedly, and a merge that grew on every
    # run would quietly turn that promise into a defect.
    [System.IO.File]::WriteAllText((Join-Path $FixtureWf '.claude\settings.json'), $proposedWfText, $Utf8NoBom)
    $rWf2 = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureWf)
    Assert-Equal 0 $rWf2.Code 'workflow plugin: bootstrap exit 0 on the rerun'
    $wfObj2 = $null
    try { $wfObj2 = [System.IO.File]::ReadAllText($proposedWf, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $wfObj2 = $null }
    Assert-True ($null -ne $wfObj2 -and @($wfObj2.permissions.allow).Count -eq 7) `
        'workflow plugin: a rerun over the merged result adds no duplicate allow rules'
    Assert-True ($null -ne $wfObj2 -and @($wfObj2.permissions.deny).Count -eq 5) `
        'workflow plugin: nor duplicate deny rules'

    # --- inbound #1084: a plugin that ships no agents still reaches the register proposal ------------
    # The proposal used to be built from the lens inventory, which is filled ONLY while walking a
    # plugin's agents/ directory -- so the workflow plugin, which ships skills, scripts and hooks and
    # no agents, could not enter it. A consumer pasting the block registered a manifest with that row
    # missing, and check-connectors reports PER PLUGIN off that list: the version-gap [ERROR] that
    # exists to catch a stale consumer cannot fire for a plugin nobody listed. This fixture is the
    # exact shape that produced it, which is why the assertion lives here rather than in a fixture
    # written for it.
    Assert-True ($rWf.Out -match '(?s)"id":\s*"dkj-policy@dkj-claude-plugins",\s*\r?\n\s*"extensions":\s*\[\s*\]') `
        'workflow plugin: the agent-less plugin IS in the register proposal, with an empty extensions array (#1084)'
    Assert-True ($rWf.Out -match '(?s)"id":\s*"dkj-subagents-alpha@dkj-claude-plugins",\s*\r?\n\s*"extensions":\s*\["01-01"') `
        'workflow plugin: and the agent-bearing plugin still carries its ids -- the widening did not flatten the inventory'
    # The notice is the other half of the repair: it was worded as a missing DIRECTORY, so the reader
    # had to infer several hundred lines later what it meant for the manifest they were about to paste.
    Assert-True ($rWf.Out -match "plugin 'dkj-policy' has no agents/ directory.*register proposal below, with an empty") `
        'workflow plugin: the skip notice names what it means for the manifest, not just what was missing'

    $rcText = [System.IO.File]::ReadAllText($rcScaffold, [System.Text.Encoding]::UTF8)
    Assert-True ($rcText -match 'VUL-IN') 'repo-config scaffold carries the VUL-IN marker'
    Assert-True ($rcText -match 'function Get-RepoName') 'repo-config scaffold supplies Get-RepoName'
    # Both halves in one file: the assembly must not drop the roster pair when the workflow half joins.
    Assert-True ($rcText -match 'function Get-RosterPath') 'workflow plugin: the roster half is still there alongside the workflow half'
    # Get-LiveStage (#177) ships a concrete, non-VUL-IN default (unlike Get-RepoName/Get-LintScript
    # above, which are placeholders every consumer must fill in) -- it is Optional in the script
    # contract, so a consumer that never touches the line still gets a working fallback. Asserted on
    # the literal default value, not just function presence, so a future edit that accidentally
    # reintroduces a VUL-IN marker is caught.
    #
    # AND Get-ChangelogHeading IS ASSERTED ON ABSENCE (inbound #763, August 20, 2026), where it used to
    # be asserted on presence beside Get-LiveStage. It was RETIRED on August 5 with the flat changelog
    # (#178): the contract holds no record for it and nothing reads it. The scaffold kept writing it
    # anyway, with a comment presenting it as live -- and repo-config.tests.ps1 asserts the SOURCE's own
    # config must not define it, for the reason that applies just as well one layer out: a config still
    # answering it hands a value to a mechanism that no longer reads it. So the two asserts contradicted
    # each other for fifteen days, and a consumer paid for it -- xoxowildhearts, a repo with no
    # CHANGELOG.md at all, spent nine lines of comment reasoning about which false value was less
    # harmful. A scaffolded file is written once and never again, which is why the wrong default is
    # expensive rather than untidy: it cannot be corrected by a later release.
    Assert-True (-not ($rcText -match 'function Get-ChangelogHeading')) 'repo-config scaffold does NOT supply the retired Get-ChangelogHeading (#178, inbound #763)'
    Assert-True (-not ($rcText -match 'ChangelogHeading')) 'and not its backing variable or its comment either -- the whole block is gone, not just the function'
    Assert-True ($rcText -match 'function Get-LiveStage') 'repo-config scaffold supplies Get-LiveStage (#177)'
    Assert-True ($rcText -match "\`$script:LiveStage = ''") 'repo-config scaffold defaults LiveStage to empty (no live stage), not VUL-IN'
    $biText = [System.IO.File]::ReadAllText($biScaffold, [System.Text.Encoding]::UTF8)
    Assert-True ($biText -match '\$script:BranchPrefixTable = @\{\s*\}') 'branch-info scaffold has an EMPTY prefix table (no repo taxonomy baked in)'

    # --- 1c1b. The register proposal is THIS marketplace's, and only this one (inbound #1084) --------
    #     Its own fixture, because the widening above is what made this reachable: while the row set
    #     came from the lens inventory, a foreign plugin could not enter it either -- Get-PluginAgentsDir
    #     only ever looked beside this plugin's own root. So the old behaviour was right by accident,
    #     and building the rows from "every enabled plugin" removes the accident. A foreign row is not
    #     merely noise: check-connectors reads a name its marketplace does not declare as RETIRED and
    #     tells the maintainer "this consumer has not migrated to the current names yet" -- a false
    #     statement about a plugin that was never this family's. Measured on the machine this suite
    #     runs on, whose own chain enables figma@claude-plugins-official.
    Write-Host "bootstrap.ps1 -- the register proposal is scoped to this marketplace (#1084)" -ForegroundColor Cyan
    $FixtureMp = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-mp-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $FixtureMp) { Remove-Item -Recurse -Force -LiteralPath $FixtureMp }
    New-Item -ItemType Directory -Path (Join-Path $FixtureMp '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $FixtureMp '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true, "somewidget@some-other-marketplace": true } }', $Utf8NoBom)
    $rMp = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureMp)
    Assert-Equal 0 $rMp.Code 'marketplace scope: bootstrap exit 0 with a foreign plugin enabled'
    Assert-True ($rMp.Out -match 'dkj-subagents-alpha@dkj-claude-plugins') 'marketplace scope: our own plugins are in the proposal'
    Assert-True ($rMp.Out -match 'dkj-policy@dkj-claude-plugins') 'marketplace scope: including the agent-less one (#1084)'
    Assert-True (-not ($rMp.Out -match 'somewidget@some-other-marketplace')) 'marketplace scope: a plugin of ANOTHER marketplace is NOT in the proposal'
    # And it says so where the reader is, rather than dropping it in silence -- the same rule the skip
    # notice above follows: name the consequence for the manifest, not just the missing directory.
    Assert-True ($rMp.Out -match "plugin 'somewidget' has no agents/ directory.*not this marketplace's plugin") `
        'marketplace scope: and the run says WHY that plugin is not in it'
    Remove-Item -Recurse -Force -LiteralPath $FixtureMp -ErrorAction SilentlyContinue

    # --- 1c1b2. The merged file survives the contents a real settings.json can hold (#1124) ----------
    # Both of these were found by review AFTER the merge worked, and both produced a file that was
    # written, announced as 'ready to replace settings.json', and broken -- which is this feature's own
    # failure mode arriving through its formatting step.
    #
    # A Windows path like C:\uadded\check.ps1 is 'C:\\uadded\\check.ps1' in JSON, and the un-escape pass
    # that restores PowerShell 5.1's \u0026-style escapes matched the SECOND backslash of that pair,
    # folding '\uadde' into one character and leaving an invalid escape behind. Any '\' + 'u' + 4 hex
    # does it: \uadded, \ubeef, \ucafe. The fix counts the backslash run, so this asserts on the
    # ROUND TRIP rather than on the bytes -- what has to hold is what Claude Code would read back.
    #
    # And '"allow": null' means the key EXISTS with a null value, so a Contains() test says yes and
    # @($null) is an array holding one $null -- which shipped '"allow": [null, ...]'.
    Write-Host "bootstrap.ps1 -- a settings.json holding a backslash-u path and a null rule list (#1124)" -ForegroundColor Cyan
    $FixtureEsc = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-esc-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $FixtureEsc) { Remove-Item -Recurse -Force -LiteralPath $FixtureEsc }
    New-Item -ItemType Directory -Path (Join-Path $FixtureEsc '.claude') -Force | Out-Null
    $hookCmd = 'powershell -File C:\uadded\check.ps1 && echo <done>'
    [System.IO.File]::WriteAllText((Join-Path $FixtureEsc '.claude\settings.json'), (@'
{
  "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true },
  "permissions": { "allow": null },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "HOOKCMD" } ] } ] }
}
'@ -replace 'HOOKCMD', ($hookCmd -replace '\\', '\\')), $Utf8NoBom)
    $rEsc = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureEsc)
    Assert-Equal 0 $rEsc.Code 'escapes: bootstrap exit 0'
    $proposedEsc = Join-Path $FixtureEsc '.claude\settings.proposed.json'
    Assert-True (Test-Path -LiteralPath $proposedEsc) 'escapes: the merged file is written'
    $escObj = $null
    try { $escObj = [System.IO.File]::ReadAllText($proposedEsc, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $escObj = $null }
    Assert-True ($null -ne $escObj) 'escapes: it still PARSES with a backslash-u path in it -- the un-escape counts the backslash run'
    if ($null -ne $escObj) {
        Assert-Equal $hookCmd $escObj.hooks.Stop[0].hooks[0].command `
            "escapes: and the command survives the round trip byte for byte, '&&' and angle brackets included"
        Assert-True (@(@($escObj.permissions.allow) | Where-Object { $null -eq $_ }).Count -eq 0) `
            'escapes: a null allow list does not ship as [null, ...] -- null and absent are the same statement'
    }
    Remove-Item -Recurse -Force -LiteralPath $FixtureEsc -ErrorAction SilentlyContinue

    # --- 1c1b3. The merged file inherits what settings.json was HIDING, and says so (#1124) ----------
    # It is a copy of that file, so a repo that gitignores '.claude/settings.json' -- the usual reason
    # being an 'env' block with a token in it -- gets an untracked, un-ignored second copy of that token
    # dropped into the tree by an adoption step. The ignore rule names the old path and cannot match the
    # new one. The bootstrap cannot know what is in there and must not guess, so it reports the FACT and
    # only in the one combination where the two files disagree; asserted here so the notice cannot be
    # lost to a later rewording of this block.
    $FixtureIgn = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-ign-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $FixtureIgn) { Remove-Item -Recurse -Force -LiteralPath $FixtureIgn }
    New-Item -ItemType Directory -Path (Join-Path $FixtureIgn '.claude') -Force | Out-Null
    Invoke-FixtureGitIn $FixtureIgn init --quiet
    [System.IO.File]::WriteAllText((Join-Path $FixtureIgn '.gitignore'), ".claude/settings.json`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $FixtureIgn '.claude\settings.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true }, "env": { "SOME_TOKEN": "x" } }', $Utf8NoBom)
    $rIgn = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureIgn)
    Assert-Equal 0 $rIgn.Code 'ignore-gap: bootstrap exit 0'
    Assert-True ($rIgn.Out -match 'gitignored here and the merged copy beside it is NOT') `
        'ignore-gap: the run says the merged copy escapes the ignore rule that covered its source (#1124)'
    Remove-Item -Recurse -Force -LiteralPath $FixtureIgn -ErrorAction SilentlyContinue

    # --- 1c1c. A destination the merge cannot account for gets NO merged file (inbound #1124) --------
    # The merged file's entire promise is "replace settings.json with this and lose nothing". Composing
    # one from a destination that cannot be read whole would break exactly that promise while wearing
    # its label, which is worse than not writing it -- so the bootstrap refuses, says which shape it
    # refused, and step 3 falls back to the hand-merge wording WITH the trap-2 warning attached.
    #
    # Three shapes, because they fail at three different depths and an early return for one would look
    # like coverage for all: unparseable at all, parseable but not an object, and an object whose
    # 'permissions' is not one (that last is the merge's own blind spot -- it replaces that key
    # wholesale, so a non-object value there would be dropped by the fix itself).
    Write-Host "bootstrap.ps1 -- a destination the merge cannot account for (#1124)" -ForegroundColor Cyan
    foreach ($bad in @(
        [pscustomobject]@{ Name = 'trailing-comma'; Body = '{ "enabledPlugins": { "a@b": true }, }'; Says = 'does not parse as JSON' },
        [pscustomobject]@{ Name = 'array-root';     Body = '[1,2]';                                 Says = 'parses, but is not a JSON object' },
        [pscustomobject]@{ Name = 'perms-scalar';   Body = '{ "permissions": "nope" }';             Says = "has a 'permissions' key that is not an object" },
        [pscustomobject]@{ Name = 'allow-object';   Body = '{ "permissions": { "allow": [ { "x": 1 } ] } }'; Says = "has a 'permissions.allow' that is not a list of rules" },
        [pscustomobject]@{ Name = 'deny-number';    Body = '{ "permissions": { "deny": 7 } }';      Says = "has a 'permissions.deny' that is not a list of rules" }
    )) {
        $FixtureBad = Join-Path ([System.IO.Path]::GetTempPath()) "specialists-init-bad-$($bad.Name)-$PID-$([guid]::NewGuid().ToString('n'))"
        if (Test-Path -LiteralPath $FixtureBad) { Remove-Item -Recurse -Force -LiteralPath $FixtureBad }
        New-Item -ItemType Directory -Path (Join-Path $FixtureBad '.claude') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $FixtureBad '.claude\settings.json'), $bad.Body, $Utf8NoBom)
        $rBad = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $FixtureBad)
        Assert-Equal 0 $rBad.Code "$($bad.Name): an unmergeable settings.json is not a bootstrap failure"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $FixtureBad '.claude\settings.proposed.json'))) `
            "$($bad.Name): no merged file is written from a destination that cannot be read whole"
        Assert-True (Test-Path -LiteralPath (Join-Path $FixtureBad '.claude\settings.suggested.jsonc')) `
            "$($bad.Name): and the annotated proposal is still placed -- nothing is taken away from the reader"
        # The notice NAMES the shape. 'does not parse' sends a reader hunting for a syntax error in a
        # file that parses perfectly, which is two of these three cases.
        Assert-True ($rBad.Out -match [regex]::Escape($bad.Says)) `
            "$($bad.Name): the notice names which shape it refused, not just that it refused"
        # AND THE WARNING LANDS WHERE THE HAND-MERGE IS NOW UNAVOIDABLE. This is the trap the whole
        # issue is about, and this path is the only one that still asks the reader to perform it.
        Assert-True ($rBad.Out -match "(?s)Copy desired parts.*?Keep 'enabledPlugins' and 'extraKnownMarketplaces'") `
            "$($bad.Name): step 3 falls back to the hand-merge AND names the keys that must survive it"
        Remove-Item -Recurse -Force -LiteralPath $FixtureBad -ErrorAction SilentlyContinue
    }

    # --- 1c2. THE INVARIANT: the bootstrap's own scaffolds satisfy the plugin's own contract --------
    #     Issue #226. Every function assertion above is a spot-check against a hand-maintained list,
    #     and that is exactly how this drifted: the contract grew (Test-BranchName for new-branch,
    #     Get-RosterPath + Get-RosterIgnoredIds for check-roster-sync) while the scaffolds did not
    #     follow, so a freshly bootstrapped repo got 3 [ERROR] lines about files the bootstrap had
    #     just written -- phrased as "this lib predates the contract", which is the wrong story for a
    #     lib written seconds earlier by the current version of the plugin.
    #
    #     This case does not spot-check anything. It runs the REAL contract check against the REAL
    #     bootstrap output, so the invariant holds by construction: add a required contract entry
    #     without extending the scaffold and this fails, whatever the entry happens to be named.
    Write-Host "bootstrap.ps1 -- the scaffolds satisfy check-script-contract (#226)" -ForegroundColor Cyan
    # AGAINST THE WORKFLOW FIXTURE, not the core-only one, and that is the accurate scope rather than a
    # convenience: since August 8, 2026 check-script-contract SHIPS IN the workflow plugin, so the only
    # repos it ever runs in are the ones that enabled it. Pointing it at the core-only fixture would
    # assert a contract on a consumer that will never run the check -- and would fail on branch-info,
    # which that consumer is correct not to have.
    $contractCheck = Join-Path $RepoRoot 'scripts\sync\check-script-contract.ps1'
    $rc = Invoke-Script -Path $contractCheck -ScriptArgs @('-ConsumerPathOverride', $FixtureWf)
    # ONE [ERROR] IS THE DESIGNED STATE SINCE AUGUST 14, 2026, and it is not about anything the
    # bootstrap wrote: the workflow folder (dkj-policy/) arrives through the workflow plugin's
    # own adopt-dkj-policy skill (Part 1), a step AFTER the bootstrap -- the same split that keeps
    # specialists-init (dkj-subagents-alpha) out of workflow-specific territory. So the guarantee #226 bought is
    # asserted at its true width: every FUNCTION the bootstrap scaffolds satisfies the contract, and
    # the single finding left is the pointer at that next step.
    Assert-Equal 1 $rc.Code 'scaffolds vs contract: exit-code 1 -- the one finding is the workflow-folder pointer, by design'
    $rcErrors = @([regex]::Matches($rc.Out, '\[ERROR\]')).Count
    Assert-Equal 1 $rcErrors 'scaffolds vs contract: exactly one [ERROR] -- nothing about a file the bootstrap just wrote'
    Assert-True ($rc.Out -match "\[ERROR\].*'dkj-policy/' does not exist") 'scaffolds vs contract: and it is the workflow-folder pointer, naming the adopt-dkj-policy step'
    # And it must be reaching the real per-function verdicts, not passing because the [BOOTSTRAP]
    # short-circuit from #225 swallowed the run -- that would make this assertion worthless.
    Assert-True (-not ($rc.Out -match '\[BOOTSTRAP\]')) 'scaffolds vs contract: the libs exist, so the check really did probe them'
    Assert-True ($rc.Out -match "\[OK\]\s+'Test-BranchName'") 'scaffolds vs contract: Test-BranchName probed and present'
    Assert-True ($rc.Out -match "\[OK\]\s+'Get-RosterPath'") 'scaffolds vs contract: Get-RosterPath probed and present'

    # --- 1c3. Get-RosterPath must POINT AT THE SEAM, not merely exist (inbound #333) -----------------
    #     Present-and-wrong was the actual defect, and it was invisible to the assertion above. The
    #     scaffold said 'CLAUDE.md' -- where the roster lived before the seam existed -- while this same
    #     bootstrap writes the roster slot into .claude/specialists/SPECIALISTS.md and its own next-steps
    #     block says the roster does NOT go in CLAUDE.md. So on a freshly bootstrapped consumer the check
    #     read a file containing only the @-import, found no roster rows, and reported every specialist as
    #     missing -- naming the wrong file as the place to fix it. Measured on a virgin profile: nineteen
    #     [ERROR] lines on the documented happy path.
    Assert-True ($rcText -match [regex]::Escape("'.claude/specialists/SPECIALISTS.md'")) 'roster path: the scaffold points at the seam inclusion'
    Assert-True (-not ($rcText -match "RosterPath = 'CLAUDE\.md'")) 'roster path: and NOT at CLAUDE.md, which the bootstrap itself rules out'
    # The placeholder must be gone: a consumer receiving the literal token would be worse off than with the
    # wrong-but-real path this replaced.
    Assert-True (-not ($rcText -match '__SEAM_ROSTER_PATH__')) 'roster path: the template placeholder was substituted, not shipped'
    # And the value the scaffold writes must be the SAME literal the shared source hands out, so the writer
    # and the check that reads it back cannot drift apart again.
    . (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')
    $seamRel = (Get-SeamPaths -RepoRoot $Fixture).RelInclusion
    Assert-True ($rcText -match [regex]::Escape("'$seamRel'")) 'roster path: it is Get-SeamPaths'' own value, not a second hand-typed copy'
    Assert-True ($rc.Out -match "\[OK\]\s+'Get-RosterIgnoredIds'") 'scaffolds vs contract: Get-RosterIgnoredIds probed and present'
    # The two required functions that were never missing -- guards against a "fix" that adds the three
    # new ones while dropping an old one.
    Assert-True ($rc.Out -match "\[OK\]\s+'Get-BranchInfo'") 'scaffolds vs contract: Get-BranchInfo still present'
    Assert-True ($rc.Out -match "\[OK\]\s+'Get-RepoName'") 'scaffolds vs contract: Get-RepoName still present'

    # --- 1d. RepoName derived from the consumer's git remote (origin) (Gap B) -------------------
    # A consumer that is a git repo with a github.com origin gets RepoName pre-filled instead of
    # the VUL-IN placeholder; non-github or no remote -> falls back to VUL-IN. The git call must
    # never crash the bootstrap. Each case runs in its own throwaway git repo.
    Write-Host "bootstrap.ps1 -- RepoName derived from the git remote (origin)" -ForegroundColor Cyan
    function Test-DerivedRepoName {
        param([string]$OriginUrl, [string]$Expected, [bool]$ShouldDerive, [string]$Label)
        $gitFix = Join-Path ([System.IO.Path]::GetTempPath()) ("specialists-init-git-$PID-" + $Label + '-' + [guid]::NewGuid().ToString('n'))
        if (Test-Path -LiteralPath $gitFix) { Remove-Item -Recurse -Force -LiteralPath $gitFix }
        New-Item -ItemType Directory -Path $gitFix -Force | Out-Null
        try {
            Invoke-FixtureGitIn $gitFix init -q
            if ($OriginUrl) { Invoke-FixtureGitIn $gitFix remote add origin $OriginUrl }
            # The workflow plugin has to be enabled here: RepoName lives in that half of the scaffold since
            # August 8, 2026, so without it there is no line for the derivation to land in and every case
            # below would pass or fail for the wrong reason.
            New-Item -ItemType Directory -Path (Join-Path $gitFix '.claude') -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $gitFix '.claude\settings.json'),
                '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-policy@dkj-claude-plugins": true } }', $Utf8NoBom)
            $rg = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $gitFix)
            Assert-Equal 0 $rg.Code "git derivation ($Label): bootstrap exit 0"
            $txt = [System.IO.File]::ReadAllText((Join-Path $gitFix 'scripts\repo-config.ps1'), [System.Text.Encoding]::UTF8)
            if ($ShouldDerive) {
                Assert-True ($txt -match [regex]::Escape("`$script:RepoName = '$Expected'")) "git derivation ($Label): RepoName = $Expected"
                Assert-True (-not ($txt -match "RepoName = 'VUL-IN")) "git derivation ($Label): no VUL-IN on the RepoName line"
            } else {
                Assert-True ($txt -match "RepoName = 'VUL-IN/repo'") "git derivation ($Label): falls back to VUL-IN/repo"
            }
        } finally {
            if (Test-Path -LiteralPath $gitFix) { Remove-Item -Recurse -Force -LiteralPath $gitFix -ErrorAction SilentlyContinue }
        }
    }
    # The bootstrap reads the origin via `git config --get remote.origin.url`, which gives the RAW
    # stored URL and ignores `insteadOf` -- so what we set here with `remote add` arrives unchanged
    # at the derivation, regardless of the (CI) machine's git config. No isolation needed anymore.
    Test-DerivedRepoName -OriginUrl 'https://github.com/DaveKJohn/my-repo.git' -Expected 'DaveKJohn/my-repo' -ShouldDerive $true  -Label 'https'
    Test-DerivedRepoName -OriginUrl 'git@github.com:DaveKJohn/my-repo.git'    -Expected 'DaveKJohn/my-repo' -ShouldDerive $true  -Label 'ssh'
    Test-DerivedRepoName -OriginUrl 'ssh://git@github.com/DaveKJohn/my-repo.git' -Expected 'DaveKJohn/my-repo' -ShouldDerive $true -Label 'ssh-scheme'
    # Credential-embedded https (e.g. a token in the URL): owner/repo is derived, the userinfo discarded.
    Test-DerivedRepoName -OriginUrl 'https://x-access-token:SECRET@github.com/DaveKJohn/my-repo.git' -Expected 'DaveKJohn/my-repo' -ShouldDerive $true -Label 'https-cred'
    Test-DerivedRepoName -OriginUrl 'https://gitlab.com/DaveKJohn/my-repo.git' -Expected '' -ShouldDerive $false -Label 'non-github'
    Test-DerivedRepoName -OriginUrl ''                                          -Expected '' -ShouldDerive $false -Label 'no-remote'

    # --- 1b. Persona lens is LENS-ONLY: no body copy, but the VUL-IN slot -------------------------
    Write-Host "persona lens -- lens-only (no body copy)" -ForegroundColor Cyan
    $srcPersona = [System.IO.File]::ReadAllText($PersonaSrc, [System.Text.Encoding]::UTF8)
    Assert-True (-not ($srcPersona -match '(?m)^## (Eigen aan deze repo|Specific to this repo)')) 'persona template no longer carries a slot marker (neither language)'
    $lens = [System.IO.File]::ReadAllText((Join-Path $Fixture "$Pp\specialist-01-01-lens.md"), [System.Text.Encoding]::UTF8)
    Assert-True ($lens -match 'Repo-lens \(lens-only persona\)') 'persona lens opens with the lens-only blockquote'
    Assert-True ($lens -match '(?m)^## Specific to this repo \(VUL-IN\)') 'persona lens carries a fresh VUL-IN slot (English heading)'
    Assert-True (-not ($lens -match 'fixed ritual')) 'persona lens contains NO body copy'

    # --- 1c. The skill's prose must not undercount what the script places (inbound #275) ------------
    #     SKILL.md named three main-loop personas (01-01, 05-05, 05-06) while the bootstrap enumerates
    #     personas/ and places FOUR. Nothing miscounted -- the closing line reported 4 honestly and the
    #     total was right -- but the description was narrower than the behaviour, which costs a reader a
    #     detour to reconcile the prose with the counter. The doc now derives the set from the payload
    #     and lists it; this test is what keeps those two from drifting apart again when a release adds
    #     a persona.
    Write-Host "bootstrap.ps1 -- the skill doc lists every persona the payload ships (inbound #275)" -ForegroundColor Cyan
    $personaIds = @(
        Get-ChildItem -LiteralPath (Split-Path $PersonaSrc -Parent) -Filter '*-persona.md' -File |
            ForEach-Object { if ($_.BaseName -match '^(\d{2}-\d{2})-persona$') { $Matches[1] } }
    )
    Assert-True ($personaIds.Count -gt 0) "payload ships personas ($($personaIds.Count))"
    $initSkill = [System.IO.File]::ReadAllText(
        (Join-Path (Split-Path (Split-Path $PersonaSrc -Parent) -Parent) 'skills\specialists-init\SKILL.md'),
        [System.Text.Encoding]::UTF8)
    # NOT $pid: that is a read-only automatic variable (the process id), and assigning it in a foreach
    # aborts the suite with a runtime error rather than a failed assertion.
    foreach ($personaId in $personaIds) {
        Assert-True ($initSkill -match [regex]::Escape($personaId)) "specialists-init SKILL.md names persona $personaId"
    }
    # And the count the bootstrap reported for the fresh consumer above is that same number -- the run's
    # own counter stays the authority, so a doc claim can never be the only place a reader is told.
    Assert-True ($r1.Out -match "$($personaIds.Count) persona-lens\(es\) created") 'the run reports exactly the payload persona count'

    # --- 2. Idempotence: second run overwrites nothing ----------------------------------------------
    Write-Host "bootstrap.ps1 -- idempotent (second run)" -ForegroundColor Cyan
    $r2 = Invoke-Script -Path $Bootstrap -ScriptArgs @('-ConsumerRoot', $Fixture)
    Assert-Equal 0 $r2.Code 'second bootstrap exit 0'
    Assert-True ($r2.Out -match '0 persona-lens') 'second run creates 0 persona lenses (everything already present)'
    Assert-True ($r2.Out -match '0 lens-scaffold') 'second run creates 0 lens scaffolds (everything already present)'
    Assert-True ($r2.Out -match '0 script-scaffold') 'second run creates 0 script scaffolds (#86, everything already present)'
    Assert-True ($r2.Out -match 'already exists') 'second run leaves the existing lens alone'

    # --- 2b. Version-cache layout: the semantically highest version wins (Victor's finding) ------------
    # Mimicked version cache: the specialists plugin as 1.4.0, plus a sibling domain plugin with
    # 1.9.0 AND 1.10.0 side by side -- a string sort would pick 1.9.0, a [version] sort 1.10.0. This
    # layout (<marketplace>/<plugin>/<version>/, with no repo-side plugins/ directory in the path) is
    # also the one that used to derive the family from the install path and land the lenses under the
    # MARKETPLACE name -- where no reader looks (issue #179). The family is a constant now, so the
    # scaffolds must appear on the canonical path here too.
    Write-Host "bootstrap.ps1 -- version cache picks the semantically highest version" -ForegroundColor Cyan
    $cacheRoot = Join-Path $Fixture 'cache\dkj-claude-plugins'
    $ownCache  = Join-Path $cacheRoot 'specialists\1.4.0'
    New-Item -ItemType Directory -Path $ownCache -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\*') -Destination $ownCache -Recurse
    foreach ($v in '1.9.0', '1.10.0') {
        New-Item -ItemType Directory -Path (Join-Path $cacheRoot "dkj-subagents-lifehub\$v\agents") -Force | Out-Null
    }
    [System.IO.File]::WriteAllText((Join-Path $cacheRoot 'dkj-subagents-lifehub\1.9.0\agents\04-88-agent.md'), "---`nname: oldie`nid: 88`ngroup: 04`n---`nfixture")
    [System.IO.File]::WriteAllText((Join-Path $cacheRoot 'dkj-subagents-lifehub\1.10.0\agents\04-99-agent.md'), "---`nname: newest`nid: 99`ngroup: 04`n---`nfixture")
    $cacheConsumer = Join-Path $Fixture 'cache-consumer'
    New-Item -ItemType Directory -Path (Join-Path $cacheConsumer '.claude') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $cacheConsumer '.claude\settings.json'), '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true, "dkj-subagents-lifehub@dkj-claude-plugins": true } }')
    $cachedBootstrap = Join-Path $ownCache 'skills\specialists-init\bootstrap.ps1'
    $rc = Invoke-Script -Path $cachedBootstrap -ScriptArgs @('-ConsumerRoot', $cacheConsumer)
    Assert-Equal 0 $rc.Code 'version cache: bootstrap exit 0'
    # A second plugin's lenses land in the SAME flat seam directory -- no per-plugin segment, since
    # <group>-<id> is unique family-wide. That is what makes "remove one directory" true for a consumer
    # with several plugins enabled, not just for a single-plugin one.
    Assert-True (Test-Path -LiteralPath (Join-Path $cacheConsumer "$Pp\specialist-04-99-lens.md")) 'version cache: scaffold from the highest version (1.10.0)'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $cacheConsumer "$Pp\specialist-04-88-lens.md"))) 'version cache: older version (1.9.0) not used'
    # Regression #179: nothing may land under the MARKETPLACE name. The seam makes the family segment
    # moot for a fresh consumer, but the assertion is kept: it guards the fallback path that still
    # derives one, and a lens under 'dkj-claude-plugins' is invisible to every reader.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $cacheConsumer '.claude\plugins\dkj-claude-plugins'))) 'version cache: no lenses under the marketplace name (#179)'
    $cacheMd = [System.IO.File]::ReadAllText((Join-Path $cacheConsumer 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True ($cacheMd -match [regex]::Escape($SeamImport)) 'version cache: CLAUDE.md carries the single seam import'

    # --- 2c. Durable body path: cache install -> @-import points to the marketplaces clone (Gap C) -----
    # Mimics the real user-scope layout: .../plugins/cache/<mp>/<plugin>/<version>/ next to a
    # versionless .../plugins/marketplaces/<mp>/ clone. The @-import written into CLAUDE.md must point
    # to the clone (durable, survives an update), NOT to the version-pinned cache (which gets cleaned
    # up after an update -> Chris' body would no longer load).
    Write-Host "bootstrap.ps1 -- durable body path (cache -> marketplaces clone)" -ForegroundColor Cyan
    $pluginsRoot = Join-Path $Fixture 'plugins'
    $mp = 'mp-fixture'
    # The cache directory is named after the PLUGIN, and the bootstrap derives its own name from exactly
    # that segment -- so this has to be the same plugin the clone below carries. It said 'specialists'
    # while the clone said 'dkj-subagents-alpha' for the length of one rename sweep, and the symptom was precisely
    # what this scenario exists to catch: the @-import fell back to the version-pinned cache path,
    # because the durable clone it was looking for was under a name nothing had put there.
    $cacheInit = Join-Path $pluginsRoot "cache\$mp\dkj-subagents-alpha\9.9.9"
    New-Item -ItemType Directory -Path $cacheInit -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\*') -Destination $cacheInit -Recurse
    # Versionless marketplaces clone with (at minimum) the personas under plugins/<plugin>/.
    $cloneP = Join-Path $pluginsRoot "marketplaces\$mp\plugins\dkj-subagents\dkj-subagents-alpha\personas"
    New-Item -ItemType Directory -Path $cloneP -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\personas\*') -Destination $cloneP -Recurse
    $durConsumer = Join-Path $Fixture 'durable-consumer'
    New-Item -ItemType Directory -Path $durConsumer -Force | Out-Null
    $rd = Invoke-Script -Path (Join-Path $cacheInit 'skills\specialists-init\bootstrap.ps1') -ScriptArgs @('-ConsumerRoot', $durConsumer)
    Assert-Equal 0 $rd.Code 'durable body path: bootstrap exit 0'
    # The body import now lives in SPECIALISTS.md, not in CLAUDE.md -- so that is where the durability
    # property has to be asserted. Reading the wrong file here would make this pass vacuously.
    $durIncl = [System.IO.File]::ReadAllText((Join-Path $durConsumer $SeamInclusion), [System.Text.Encoding]::UTF8)
    Assert-True ($durIncl -match [regex]::Escape("marketplaces/$mp/plugins/dkj-subagents/dkj-subagents-alpha/personas/01-01-persona.md")) 'durable body path: @-import points to the marketplaces clone'
    Assert-True (-not ($durIncl -match '/cache/')) 'durable body path: @-import does NOT point to the version-pinned cache'
    # And CLAUDE.md itself must be free of the cache path too -- the one line it carries is repo-relative.
    $durMd = [System.IO.File]::ReadAllText((Join-Path $durConsumer 'CLAUDE.md'), [System.Text.Encoding]::UTF8)
    Assert-True (-not ($durMd -match '/cache/')) 'durable body path: CLAUDE.md carries no cache path at all'

    # --- 3. Drift on a fresh bootstrap: LENS-ONLY (no body to compare) --------------------
    Write-Host "check-consumer-drift.ps1 -- fresh lens-only bootstrap = LENS-ONLY" -ForegroundColor Cyan
    $d1 = Invoke-Script -Path $DriftLint -ScriptArgs @('-ConsumerPath', $Fixture, '-Quiet')
    Assert-Equal 0 $d1.Code 'drift exit 0 (no agent-def drift)'
    Assert-True ($d1.Out -match 'LENS-ONLY\] 01-01-persona') 'persona 01-01 reported as LENS-ONLY'
    Assert-True (-not ($d1.Out -match 'DRIFTED\]')) 'no DRIFTED at all on a fresh bootstrap'
    # A verdict travels with its coverage (issue #221): on a bootstrapped consumer the personas were
    # genuinely examined, so the count must say so rather than leaving "0 drifted" to be interpreted.
    Assert-True ($d1.Out -match '\[personas\] checked [1-9]') 'coverage: the personas it DID compare are counted'
    Assert-True ($d1.Out -match 'drifted of [1-9]\d* compared') 'coverage: the verdict names its own denominator'

    # --- 3a. The silent-skip case: a consumer with NO lens file at all (issue #221) ---------------
    # THE DEFECT THIS GUARDS, measured 2026-07-30. The persona section used to be wrapped in
    # `if ($personaResults.Count -gt 0)` and closed with "Persona drift is INFORMATIONAL: 0 drifted."
    # Against a repo holding no lens files -- a torn-down consumer, a bad merge, a wrong -ConsumerPath
    # -- that printed a clean persona verdict over personas it had never compared, and "0 drifted of 0
    # compared" was word-for-word the same sentence as "0 drifted of 4 compared". Right for a
    # deliberate teardown, wrong for an accidental loss, and indistinguishable between them.
    Write-Host "check-consumer-drift.ps1 -- a consumer with no lens tree says so (issue #221)" -ForegroundColor Cyan
    $bare = Join-Path ([System.IO.Path]::GetTempPath()) "drift-bare-consumer-$PID-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $bare) { Remove-Item -Recurse -Force -LiteralPath $bare }
    New-Item -ItemType Directory -Path $bare -Force | Out-Null
    try {
        [System.IO.File]::WriteAllText((Join-Path $bare 'CLAUDE.md'), "# A repo that never adopted, or just tore down`n", $Utf8NoBom)
        $d0 = Invoke-Script -Path $DriftLint -ScriptArgs @('-ConsumerPath', $bare, '-Quiet')
        Assert-Equal 0 $d0.Code 'bare consumer: exit 0 -- an empty category is not a failure'
        Assert-True ($d0.Out -match 'Personas \(portable body') 'bare consumer: the persona SECTION is printed at all -- it used to vanish entirely'
        Assert-True ($d0.Out -match '\[personas\] checked 0 of [1-9]') 'bare consumer: 0 compared out of the personas that exist -- the zero is stated, not implied'
        Assert-True ($d0.Out -match 'the consumer holds no lens file for any persona') 'bare consumer: the line says WHY, so a teardown is distinguishable from a loss'
        Assert-True ($d0.Out -match 'drifted of 0 compared') 'bare consumer: the verdict carries its denominator, so "0 drifted" cannot read as "all clean"'
    } finally {
        if (Test-Path -LiteralPath $bare) { Remove-Item -Recurse -Force -LiteralPath $bare -ErrorAction SilentlyContinue }
    }

    # --- 3b. Root fix #64: the index line is location-independent (no path-depth link) ------------
    Write-Host "persona index line -- location-independent (inbound #64)" -ForegroundColor Cyan
    Assert-True (-not ($srcPersona -match '\]\((?:\.\./)+CLAUDE\.md\)')) 'persona index line no longer carries a path-depth-dependent CLAUDE.md link'

    # --- 4. Drift comparison on a LEGACY body copy: IDENTICAL -> DRIFTED ------------------------
    # The drift check still supports a consumer with a full body copy (not lens-only).
    # We place one ourselves (template body + repo-lens marker) to test that comparison.
    Write-Host "check-consumer-drift.ps1 -- legacy body copy: IDENTICAL, then DRIFTED" -ForegroundColor Cyan
    $ext = Join-Path $Fixture "$Pp\specialist-01-01-lens.md"
    # Legacy Dutch slot marker: proves that an old Dutch consumer still splits correctly on the
    # marker (back-compat) -> the portable body is IDENTICAL to the source.
    $fullBody = $srcPersona.TrimEnd() + "`n`n## Eigen aan deze repo (test-fixture)`n`nrepo-eigen.`n"
    [System.IO.File]::WriteAllText($ext, $fullBody, $Utf8NoBom)
    $d2 = Invoke-Script -Path $DriftLint -ScriptArgs @('-ConsumerPath', $Fixture, '-Quiet')
    Assert-True ($d2.Out -match 'IDENTICAL\] 01-01-persona') 'legacy NL slot marker: body copy is IDENTICAL to the source'
    # Parallel: the new English slot marker splits identically -> also IDENTICAL.
    $fullBodyEn = $srcPersona.TrimEnd() + "`n`n## Specific to this repo (test-fixture)`n`nrepo-specific.`n"
    [System.IO.File]::WriteAllText($ext, $fullBodyEn, $Utf8NoBom)
    $d2en = Invoke-Script -Path $DriftLint -ScriptArgs @('-ConsumerPath', $Fixture, '-Quiet')
    Assert-True ($d2en.Out -match 'IDENTICAL\] 01-01-persona') 'new EN slot marker: splits identically (IDENTICAL)'
    $extText = [System.IO.File]::ReadAllText($ext, [System.Text.Encoding]::UTF8).Replace('Chief of Staff', 'CHIEF-OF-STAFF-TEST-CHANGE')
    [System.IO.File]::WriteAllText($ext, $extText, $Utf8NoBom)
    $d3 = Invoke-Script -Path $DriftLint -ScriptArgs @('-ConsumerPath', $Fixture, '-Quiet')
    Assert-Equal 0 $d3.Code 'drift exit stays 0 (persona drift is informational)'
    Assert-True ($d3.Out -match 'DRIFTED\]   01-01-persona') 'persona 01-01 DRIFTED after a body change'

    # --- 5. Lint smoke: the repo itself stays green ----------------------------------------------------
    Write-Host "check-plugin-integrity.ps1 -- smoke" -ForegroundColor Cyan
    $li = Invoke-Script -Path $Integrity -ScriptArgs @()
    Assert-Equal 0 $li.Code 'lint gate green on the repo'
    # AND IT PRINTS WHAT THE GATE SAID WHEN IT IS NOT (August 16, 2026). This assert runs the gate over the
    # LIVE repo, so it is one of the handful that can fail from a collision with a concurrently running
    # suite rather than from anything in the branch -- Sylvester's lens names it by name for exactly that.
    # Measured that day: it failed in one pooled run of 43 suites and passed in the next three, alongside
    # fix-mojibake's twin assert, and 'expected 0, got 1' was everything either of them said. A failure
    # that cannot distinguish a real finding from a collision sends the next reader to the wrong place, so
    # the findings themselves are printed here. Silent on success, deliberately: this is diagnosis, not
    # coverage.
    if ($li.Code -ne 0) {
        @($li.Out -split "`r?`n" | Where-Object { $_ -match '^\s*\[' -and $_ -notmatch 'checked \d' } | Select-Object -First 10) |
            ForEach-Object { Write-Host ("         gate said: " + $_.Trim()) -ForegroundColor DarkYellow }
    }
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
    # Declared in the try block, so it may not exist if the run failed before section 1c1.
    if ($FixtureWf -and (Test-Path -LiteralPath $FixtureWf)) { Remove-Item -Recurse -Force -LiteralPath $FixtureWf -ErrorAction SilentlyContinue }
    $env:USERPROFILE = $OldUserProfile
}

Write-Host ""
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'bootstrap.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
