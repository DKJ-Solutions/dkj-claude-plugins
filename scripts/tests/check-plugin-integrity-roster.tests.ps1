<#
.SYNOPSIS
    check-plugin-integrity.ps1, the roster and manifest checks: a manual backed by an agent def OR a
    persona (6b), the 'agents' key -- the installer's shape and every def named (38), a verdict
    marker at the START of the line a hook-read check writes (45), each specialist kind's written
    spelling against the names on disk (3d) -- and the -SkipCheck parameter itself.

    The -SkipCheck scenarios at the end are the guard on this suite family's own speed valve: a
    skipped check must announce itself and must never be reported as 'checked 0', an unknown name
    must be refused rather than ignored, and no gate that guards main may pass the parameter at all.

    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

# CHECK-REPORT-LIB INTO THE RUNNER TOO, for check 3d's scenarios: they compose the lens file names from
# Get-SpecialistFileName and Get-SpecialistFileNameCandidates rather than typing them. Same reason the
# fixture dot-sources entry-scaffold-lib and pr-body-lib, and through the $...Src path it already
# resolves for the copy -- a name typed here would be a second definition of the very shape the check
# under test holds, and it would pass on the day the row and the files come apart, which IS the defect
# (#2168).
. $CheckReportLibSrc

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-roster-$PID-$([guid]::NewGuid().ToString('n'))")

# The entry format's levels, composed from the lib rather than typed -- the same rule the entries suite
# follows. Both pairs shifted one deeper on August 26, 2026, and a fixture stating them in literals is a
# second definition of the format that the check under test does not read.
#
# THE BACKTICK COMES FROM ITS CODE POINT, because it is PowerShell's own escape character: written literally
# inside a double-quoted string it escapes the next character instead of appearing.
$docTick      = [char]0x60
$docEntryHash = '#' * (Get-EntryHeadingLevel)
$docSectHash  = '#' * (Get-EntrySectionLevel)
$docEntryH    = $docTick + $docEntryHash + $docTick
$docSectH     = $docTick + $docSectHash + $docTick

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- check 6b: a manual is backed by an agent def OR a persona ------------------------------------
    # ADDED WITH #1017 (August 28, 2026), which relaxed 6b -- and found check 6 had no coverage at all,
    # in any of the four suites. The relaxation is the kind that fails silently in the direction that
    # matters: a gate that now accepts MORE cannot be seen to have started accepting everything. So all
    # four states are asserted, not just the new one.
    #
    # The fixture's dkj-subagents-alpha carries no specialists, so this scenario builds its own pair and removes
    # them again -- every other check in this file reads that plugin too, and a stray agent def would
    # change what checks 7 and 26 walk for the scenarios below.
    Write-Host "check 6b: a manual may be backed by a persona, and must then be named by it" -ForegroundColor Cyan
    $spAgents   = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\subagents'
    $spManuals  = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\manuals'
    $spPersonas = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\personas'
    New-Item -ItemType Directory -Path $spManuals  -Force | Out-Null
    New-Item -ItemType Directory -Path $spPersonas -Force | Out-Null
    $spManualPath  = Join-Path $spManuals  'specialist-99-99-manual.md'
    $spPersonaPath = Join-Path $spPersonas '99-99-persona.md'
    $spAgentPath   = Join-Path $spAgents   '99-99-agent.md'
    [System.IO.File]::WriteAllText($spManualPath, "---`nid: 99`ngroup: 99`n---`n`n# Fixture manual`n", $Utf8NoBom)

    # 1. Neither backer: still an orphan. The check's whole reason for existing survives the relaxation.
    $b1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($b1.Out -match 'orphan manual') `
        'check 6b: a manual with neither an agent def nor a persona is still an orphan'
    Assert-True ($b1.Out -match 'personas/99-99-persona\.md') `
        'check 6b: and the finding names the persona path too, so the reader learns the second way out'

    # 2. A persona that does NOT name the manual: accepted as a backer, refused for being silent. This is
    #    the half that can break -- a persona is the only file that gets loaded, so an unnamed manual is
    #    a file nothing will ever read, which is indistinguishable from not having written it.
    [System.IO.File]::WriteAllText($spPersonaPath, "---`nid: 99`ngroup: 99`n---`n`n# Fixture persona`n", $Utf8NoBom)
    $b2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b2.Out -match 'orphan manual')) `
        'check 6b: a persona backs the manual, so it is no longer an orphan'
    Assert-True ($b2.Out -match 'does not name it') `
        'check 6b: but a persona that never names its manual is refused -- nothing would read it'

    # 3. A persona that names it: clean.
    [System.IO.File]::WriteAllText($spPersonaPath,
        "---`nid: 99`ngroup: 99`n---`n`n# Fixture persona`n`nPlaybook: manuals/specialist-99-99-manual.md`n", $Utf8NoBom)
    $b3 = Invoke-Integrity -FixtureRoot $Fixture
    # ASSERTED ON THE FINDING TEXT, not on '[specialist]'. That bracket also opens the coverage line
    # ('[specialist] checked 1'), which this check prints on every run including a clean one -- so the
    # obvious absence assert passes only while the check is silent about everything, including itself.
    Assert-True (-not ($b3.Out -match 'orphan manual')) `
        'check 6b: a persona that names its manual passes -- the pairing #1017 asked for'
    Assert-True (-not ($b3.Out -match 'does not name it')) `
        'check 6b: and naming it is what clears the second finding, nothing else about the file changed'

    # 4. A persona with NO manual is the normal case and is asserted about in neither direction. Bianca,
    #    Derek and Rendall are all in this state, so a rule that read a bare persona as a finding would
    #    fail the real repo on three files.
    Remove-Item -LiteralPath $spManualPath -Force
    $b4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b4.Out -match 'orphan manual|does not name it')) `
        'check 6b: a persona with no manual at all is untouched -- three real specialists live there'

    Remove-Item -LiteralPath $spPersonaPath -Force
    if (Test-Path -LiteralPath $spAgentPath) { Remove-Item -LiteralPath $spAgentPath -Force }
    Remove-Item -LiteralPath $spManuals -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $spPersonas -Recurse -Force -ErrorAction SilentlyContinue

    # --- check 38: the 'agents' key -- the installer's shape, and every def named -------------------
    # THE PRE-REPAIR TREE IS THE FIRST SCENARIO, deliberately. #1764's whole point is that the gate
    # reported 0 error(s) over four manifests 'claude plugin install' refuses outright, so a suite that
    # only proved the repaired shape passes would prove nothing about the defect. Scenario 1 below writes
    # exactly what v4.33.0 shipped.
    #
    # BOTH DIRECTIONS ARE EXERCISED because they fail differently and only one is reachable by
    # 'claude plugin validate': a bad element makes the installer refuse the whole plugin, an omitted def
    # installs fine and never loads.
    #
    # NO -Full IS NEEDED even though this check reads agent defs: it does its own discovery rather than
    # reusing $agentDefs, so -SkipCheck agent-def (this suite's default) does not narrow it. Asserted
    # below rather than assumed -- that is exactly the shape the fixture header warns about.
    Write-Host "check 38: the 'agents' key -- shape and completeness" -ForegroundColor Cyan
    $akManifest = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\.claude-plugin\plugin.json'
    $akSubagents = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\subagents'
    $akManifestOrig = [System.IO.File]::ReadAllText($akManifest, [System.Text.Encoding]::UTF8)
    New-Item -ItemType Directory -Path $akSubagents -Force | Out-Null
    $akDefA = Join-Path $akSubagents '01-01-agent.md'
    $akDefB = Join-Path $akSubagents '02-02-agent.md'
    foreach ($akDef in @($akDefA, $akDefB)) {
        [System.IO.File]::WriteAllText($akDef, "---`nname: fixture`nid: 01`ngroup: 01`n---`n`n# Fixture def`n", $Utf8NoBom)
    }
    function Set-AkManifest { param([string]$AgentsJson)
        $body = if ($AgentsJson) { ", `"agents`": $AgentsJson" } else { '' }
        [System.IO.File]::WriteAllText($akManifest,
            "{ `"name`": `"dkj-subagents-alpha`", `"version`": `"0.0.1`"$body }`n", $Utf8NoBom)
    }

    # 1. THE #1764 STATE: a directory as a bare string. The installer answers 'agents: Invalid input'
    #    and installs nothing; this gate said 0 error(s).
    Set-AkManifest -AgentsJson '"./subagents/"'
    $ak1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak1.Out -match '\[agents-key\].*does not name a \.md file') `
        'check 38: a directory as the agents string is reported -- the exact manifest v4.33.0 shipped'
    Assert-True ($ak1.Out -match '\[agents-key\].*#1764') `
        'check 38: and the finding cites the issue, so a reader gets the measurement without the source'
    Assert-True ($ak1.Code -ne 0) 'check 38: the run fails, so the gate would have refused the release'

    # 2. THE ARRAY FORM OF THE SAME MISTAKE. The validator distinguishes them ('agents.0' rather than
    #    'agents'), so a check that only knew the string form would pass the obvious next attempt --
    #    which is the one #1764 measured second.
    Set-AkManifest -AgentsJson '["./subagents/"]'
    $ak2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak2.Out -match '\[agents-key\].*does not name a \.md file') `
        'check 38: a directory INSIDE the array is reported too -- the array is legal, the element is not'

    # 3. A GLOB, which reads as the obvious way out of a hand-maintained list and is not expanded.
    Set-AkManifest -AgentsJson '["./subagents/*.md"]'
    $ak3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak3.Out -match '\[agents-key\].*subagents/\*\.md') `
        'check 38: a glob is reported -- nothing expands it, so it names no file'

    # 4. A PATH THAT ENDS IN .md AND NAMES NOTHING. Distinct from 1-3: the shape is right and the file is
    #    absent, which is what a renamed def leaves behind -- and it takes the whole install down.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md", "./subagents/99-99-agent.md"]'
    $ak4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak4.Out -match '\[agents-key\].*99-99-agent\.md.*names no file that exists') `
        'check 38: an entry naming a missing file is reported, naming the entry'

    # 5. CONTAINMENT: a path leaving the plugin cannot travel with it, the same rule check 1 holds a
    #    marketplace source to.
    Set-AkManifest -AgentsJson '["../dkj-subagents-shopify/subagents/01-01-agent.md"]'
    $ak5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak5.Out -match '\[agents-key\].*resolves outside the plugin root') `
        'check 38: an entry escaping the plugin root is reported -- what is registered here gets published'

    # 6. THE COMPLETENESS DIRECTION, and the one 'claude plugin validate' cannot reach: a correct,
    #    installable list that omits a def the plugin ships. This is the drift Dave's chosen repair
    #    (keep subagents/, list the files) is exposed to, and the reason the check exists as a gate.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md"]'
    $ak6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak6.Out -match '\[agents-key\].*02-02-agent\.md.*no .agents. entry names it') `
        'check 38: a def the list omits is reported -- it installs fine and loads for nobody'
    Assert-True (-not ($ak6.Out -match 'does not name a \.md file|names no file that exists')) `
        'check 38: and only that finding -- the shape of the entry it DOES carry is sound'

    # 7. THE COMPLETE LIST IS CLEAN. The absence assert is anchored on the '.' that opens every finding's
    #    relative manifest path, NOT on '[agents-key]' and not on any word: that bracket also opens the
    #    coverage line this check prints on every run, so '[agents-key] <lowercase>' matches
    #    '[agents-key] checked 6 -- ...' and passes only while the check says nothing at all, itself
    #    included. Written that way first and it failed here on scenarios 7 and 9 -- the trap check 6b's
    #    scenario 3 documents, met head-on.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md", "./subagents/02-02-agent.md"]'
    $ak7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($ak7.Out -match '\[agents-key\] \.')) `
        'check 38: a list naming every def, each an existing file, is clean'
    Assert-True ($ak7.Out -match "\[agents-key\] checked") `
        'check 38: and the check reports its coverage, so a silent pass cannot hide an empty scan'
    Assert-True ($ak7.Out -match "\[agents-key\] checked \d+ -- published plugin\(s\) read, [1-9]") `
        'check 38: with a non-zero entry count -- proof -SkipCheck agent-def did not narrow this check'

    # 8. NO KEY AT ALL, with defs outside agents/: #1698's defect stated as a rule. Convention discovery
    #    reads agents/ and nothing else, so these are declared by nothing -- and it reads as a clean gate.
    Set-AkManifest -AgentsJson $null
    $ak8 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak8.Out -match "\[agents-key\].*declares no .agents. key") `
        'check 38: no key plus defs outside agents/ is reported -- nothing discovers them'
    Assert-True ($ak8.Out -match '\[agents-key\].*2 def\(s\) outside it') `
        'check 38: and the finding counts them, so the reader knows the size of what is not loading'

    # 9. NO KEY AND THE DEFS IN agents/: the convention, and silent. This is the state the repo was in
    #    before #1698 and the one the check must never accuse -- five of six real plugins rely on the
    #    silence half of this rule.
    $akConvention = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\agents'
    New-Item -ItemType Directory -Path $akConvention -Force | Out-Null
    Move-Item -LiteralPath $akDefA -Destination (Join-Path $akConvention '01-01-agent.md') -Force
    Move-Item -LiteralPath $akDefB -Destination (Join-Path $akConvention '02-02-agent.md') -Force
    $ak9 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($ak9.Out -match '\[agents-key\] \.')) `
        'check 38: no key with every def under agents/ is the convention and is silent'

    # 10. A NESTED PLUGIN ROOT IS NOT ITS PARENT'S CONTENT. plugins/dkj-policy/dkj-policy-bwj really sits
    #     inside plugins/dkj-policy in this repo, and neither ships a def today -- so nothing would fire
    #     if this were wrong, which is precisely why it is exercised here rather than left to the tree.
    #     The marketplace is rewritten for this scenario and restored immediately after: every later
    #     assert in this suite reads it.
    $akMpPath = Join-Path $Fixture '.claude-plugin\marketplace.json'
    $akMpOrig = [System.IO.File]::ReadAllText($akMpPath, [System.Text.Encoding]::UTF8)
    $akChildRoot = Join-Path $Fixture 'plugins\dkj-policy\dkj-policy-bwj'
    try {
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot '.claude-plugin') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot 'agents') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $akChildRoot '.claude-plugin\plugin.json'),
            "{ `"name`": `"dkj-policy-bwj`", `"version`": `"0.0.1`" }`n", $Utf8NoBom)
        # The child's def sits OUTSIDE its own agents/ dir on purpose: the child must be accused and the
        # parent must not. One file separates the two readings.
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot 'subagents-stray') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $akChildRoot 'subagents-stray\03-03-agent.md'),
            "---`nname: fixture`nid: 03`ngroup: 03`n---`n`n# Child def`n", $Utf8NoBom)
        [System.IO.File]::WriteAllText($akMpPath, (@'
{
  "name": "fixture-marketplace",
  "plugins": [
    { "name": "dkj-subagents-alpha",         "source": "./plugins/dkj-subagents/dkj-subagents-alpha" },
    { "name": "dkj-subagents-shopify",       "source": "./plugins/dkj-subagents/dkj-subagents-shopify" },
    { "name": "dkj-policy", "source": "./plugins/dkj-policy" },
    { "name": "dkj-policy-bwj", "source": "./plugins/dkj-policy/dkj-policy-bwj" }
  ]
}
'@), $Utf8NoBom)
        $ak10 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-True ($ak10.Out -match "\[agents-key\] \./plugins/dkj-policy/dkj-policy-bwj.*declares no .agents. key|\[agents-key\] \.\\plugins\\dkj-policy\\dkj-policy-bwj.*declares no .agents. key") `
            'check 38: the nested plugin is accused of its own stray def'
        Assert-True (-not ($ak10.Out -match "\[agents-key\] \.[\\/]plugins[\\/]dkj-policy[\\/]\.claude-plugin")) `
            'check 38: and its PARENT is not -- a nested root is not its parent content'
    } finally {
        [System.IO.File]::WriteAllText($akMpPath, $akMpOrig, $Utf8NoBom)
        Remove-Item -LiteralPath $akChildRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Back to the canonical fixture: the manifest exactly as New-IntegrityFixture wrote it, and no defs.
    [System.IO.File]::WriteAllText($akManifest, $akManifestOrig, $Utf8NoBom)
    Remove-Item -LiteralPath $akConvention -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $akSubagents -Recurse -Force -ErrorAction SilentlyContinue

    # --- check 45: a verdict marker sits at the START of the line a hook-read check writes ------------
    #     THE RULE IS BORN GREEN ON THE REAL TREE (issue #2150), which is exactly why it needs scenarios:
    #     a guard that has never been seen to fire is indistinguishable from one that cannot. So the
    #     fixture builds the whole derivation -- a hook that SELECTS a marker, and the check script that
    #     hook names -- and then asserts both directions over it.
    #
    #     THE NEGATIVE CASES ARE THE POINT HERE, more than the positive one. Three separate narrowings
    #     make this check born green, and each of them is a way for it to be silently inert: the writer
    #     narrowing, the per-subject marker set, and the derivation that only admits a script some hook
    #     actually reads. A positive-only suite would pass against a check that reported everything.
    Write-Host "check 45: a verdict marker must open the line a hook-read check writes" -ForegroundColor Cyan
    $mcHookDir   = Join-Path $Fixture 'plugins\dkj-policy\hooks'
    $mcCheckDir  = Join-Path $Fixture 'plugins\dkj-policy\scripts\lint'
    New-Item -ItemType Directory -Path $mcHookDir -Force | Out-Null
    New-Item -ItemType Directory -Path $mcCheckDir -Force | Out-Null
    $mcHookPath   = Join-Path $mcHookDir 'mc-sessioncheck.ps1'
    $mcCheckPath  = Join-Path $mcCheckDir 'check-mc-fixture.ps1'
    $mcQuietHook  = Join-Path $mcHookDir 'mc-quiet-hook.ps1'
    $mcQuietCheck = Join-Path $mcCheckDir 'check-mc-unread.ps1'

    # The hook: it names its check by a relative path and selects ONE marker from it. Both facts are read
    # off this file by the check under test -- nothing here is a list the test planted for it to find.
    [System.IO.File]::WriteAllText($mcHookPath, (@(
                '$checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT ''scripts\lint\check-mc-fixture.ps1''',
                '$signals = @(Select-CheckMarkerLine -Output $out -Marker ''[ERROR]'')'
            ) -join "`n") + "`n", $Utf8NoBom)

    # A second hook that reads a check and selects NOTHING -- the Stop hooks and the verbatim relays are
    # this shape. Its check carries a mid-line marker, and must stay unreported: a script no anchored
    # selector reads cannot have a finding dropped by one.
    [System.IO.File]::WriteAllText($mcQuietHook,
        '$checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT ''scripts\lint\check-mc-unread.ps1''' + "`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($mcQuietCheck,
        'Write-Host "note: [ERROR] nothing anchored reads this script"' + "`n", $Utf8NoBom)

    # 45a. THE CLEAN SHAPE. Column 0, an indented continuation (which the '^\s*' anchor allows), and a
    #      marker no hook selects from this script -- none of the three may be reported.
    [System.IO.File]::WriteAllText($mcCheckPath, (@(
                'Write-Host "[ERROR] the check wrote this at column 0"',
                'Write-Host "  [ERROR] and this behind its own indentation"',
                'Write-Host "reported value: [SKIP] which no hook selects from here"'
            ) -join "`n") + "`n", $Utf8NoBom)
    $mc1 = Invoke-Integrity -FixtureRoot $Fixture
    # MATCHED ON THE FINDING'S OWN SENTENCE, not on the category tag. Every run prints a
    # '[marker-column] checked N' coverage line, so an absence assert written against the tag alone can
    # never pass -- which is exactly how this scenario failed first time round, reporting the check as
    # broken when the test was.
    Assert-True (-not ($mc1.Out -match 'writes the verdict marker')) `
        'marker-column: a marker at column 0, an indented one, and one no hook selects are all clean'
    Assert-True ($mc1.Out -match '\[marker-column\] checked [1-9]') `
        'marker-column: and the emissions were actually counted, so the clean verdict is not an empty scan'
    Assert-True (-not ($mc1.Out -match 'check-mc-unread')) `
        'marker-column: a check no anchored selector reads is not a subject, mid-line marker and all'

    # 45b. THE DEFECT ITSELF -- the line #2150 was filed about. It must name the file, the marker, the
    #      column and the hook that would drop it, because a finding that says only "wrong" leaves the
    #      author to rediscover which of the eight hooks is affected.
    [System.IO.File]::WriteAllText($mcCheckPath,
        'Write-Host "note: [ERROR] a finding the hook will silently drop"' + "`n", $Utf8NoBom)
    $mc2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($mc2.Out -match '\[marker-column\].*check-mc-fixture\.ps1') `
        'marker-column: a marker written mid-line is reported, naming the script'
    Assert-True ($mc2.Out -match "\[marker-column\].*'\[ERROR\]'") `
        'marker-column: and the marker it found'
    Assert-True ($mc2.Out -match '\[marker-column\].*mc-sessioncheck') `
        'marker-column: and the hook that selects it, so the author is not left to find which one'
    Assert-True ($mc2.Code -eq 1) 'marker-column: and the finding fails the gate rather than only printing'

    # 45c. THE RECONSTRUCTION, which is the whole reason the unit is the emitted line rather than the
    #      string literal. Here the marker DOES open its own literal and does NOT open the printed line.
    #      A per-literal rule -- the shape #2150 proposed -- passes this, so this scenario is what
    #      separates the two.
    [System.IO.File]::WriteAllText($mcCheckPath,
        'Write-Host ("note: " + "[ERROR] opens its literal but not its line")' + "`n", $Utf8NoBom)
    $mc3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($mc3.Out -match '\[marker-column\].*check-mc-fixture\.ps1') `
        'marker-column: a marker opening the SECOND half of a concatenation is judged on what the line prints'

    # 45d. And the same over '-f', where the format string is kept and its arguments dropped: a '{0}'
    #      standing in front of the marker is itself non-whitespace, so the line is still off the anchor.
    [System.IO.File]::WriteAllText($mcCheckPath,
        'Write-Host ("{0}: [ERROR] behind a format placeholder" -f $thing)' + "`n", $Utf8NoBom)
    $mc4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($mc4.Out -match '\[marker-column\].*check-mc-fixture\.ps1') `
        'marker-column: a marker behind a -f placeholder is reported too'

    # 45e. THE WRITER NARROWING, asserted rather than trusted. A marker mid-string in a DATA field is
    #      what check-script-contract.ps1 really carries, and it reaches no hook -- so it must stay clean
    #      or the check is born needing an exemption for the tree it was measured against.
    [System.IO.File]::WriteAllText($mcCheckPath, (@(
                '$record = @{ Default = ''an absent declaration is a [ERROR] here, stated as a choice'' }',
                'Write-Host "[ERROR] the only line this script actually writes"'
            ) -join "`n") + "`n", $Utf8NoBom)
    $mc5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($mc5.Out -match 'writes the verdict marker')) `
        'marker-column: a marker in a data field, outside any writer, is not an emitted line and is clean'

    Remove-Item -LiteralPath $mcHookPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $mcQuietHook -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $mcCheckPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $mcQuietCheck -Force -ErrorAction SilentlyContinue

    # --- check 3d: a kind's WRITTEN spelling, against the names actually on disk ----------------------
    #     BORN GREEN ON THE REAL TREE (issue #2168), so the scenarios are what make it distinguishable
    #     from a check that cannot fire. All four kinds agree with their Current row today -- the whole
    #     point of the check is the window in which one of them does not, and that window has been open
    #     twice without anything reporting it.
    #
    #     THE LENS IS THE SUBJECT, for one reason and it is not convenience: it is the only one of the
    #     four kinds that lives OUTSIDE a plugin folder, so writing it needs no manifest, no frontmatter
    #     and no agent def to satisfy checks 3b, 3c and 6 alongside. The assertion under test is about a
    #     file NAME, which is the same assertion for every kind -- the code loops one table over all
    #     four -- so pinning it on the cheapest kind is the whole coverage, not a sample of it.
    #
    #     BOTH HALVES AND BOTH WORDINGS. Files moved without the row and a row flipped without the files
    #     reach this check identically; what differs is whether EVERY file of the kind is on the other
    #     spelling or only some, and those have different repairs. The negative cases are the point as
    #     much as the positives: a check that reported every file it walked would satisfy a
    #     positive-only suite.
    Write-Host "check 3d: a kind's written spelling vs. the names on disk" -ForegroundColor Cyan
    $wnDir = Join-Path $Fixture '.claude\specialists\lenses'
    New-Item -ItemType Directory -Path $wnDir -Force | Out-Null
    # THE NAMES COME FROM THE LIB, NEVER FROM A LITERAL HERE. A test that typed 'specialist-01-01-lens.md'
    # would pass the day the Lens row flips and the files do not -- which is the exact defect this check
    # exists to refuse, reproduced inside its own guard. bootstrap-drift.tests.ps1 pins the literal on
    # purpose and says why; this suite is the opposite side of that pair and must derive.
    $wnWritten = Get-SpecialistFileName -Kind Lens -Id '01-01'
    $wnRetired = @(Get-SpecialistFileNameCandidates -Kind Lens -Id '01-01' | Where-Object { $_ -ne $wnWritten })[0]
    $wnWritten2 = Get-SpecialistFileName -Kind Lens -Id '02-09'
    $wnRetired2 = @(Get-SpecialistFileNameCandidates -Kind Lens -Id '02-09' | Where-Object { $_ -ne $wnWritten2 })[0]
    $wnBody = "# Fixture lens`n"

    # THE ABSENCE ASSERTS MATCH THE FINDING, NOT THE TOKEN, and that distinction is not fussiness: the
    # [COVERAGE] line carries the SAME '[written-name]' token, so '\[written-name\] ' is satisfied by a
    # perfectly clean run and both clean cases below failed on it first time out. It is the trap check
    # 13's own scenarios already note for '[entry-shape]' and README.md. 'carry a spelling' is wording
    # only a finding has -- both the stray and the whole-kind lead use it -- so the pattern discriminates
    # what these two asserts are actually about.
    $wnFinding = '\[written-name\] .*carry a spelling'

    # 1. THE WRITTEN SPELLING IS SILENT. Without this the three cases below would all pass against a
    #    check that reported every lens it found.
    [System.IO.File]::WriteAllText((Join-Path $wnDir $wnWritten), $wnBody, $Utf8NoBom)
    $wn1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($wn1.Out -match $wnFinding)) `
        'written-name: a lens on the spelling the table WRITES is clean'
    Assert-True ($wn1.Out -match '\[written-name\] checked 1\b') `
        'written-name: and it was actually examined -- the clean verdict carries its count'

    # 2. A STRAY: one file on the retired spelling beside one on the written one. The half-finished move,
    #    which is a different repair from a row that never flipped -- so the wording has to differ too.
    [System.IO.File]::WriteAllText((Join-Path $wnDir $wnRetired2), $wnBody, $Utf8NoBom)
    $wn2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($wn2.Out -match '\[written-name\] 1 of 2 Lens file') `
        'written-name: one file on the retired spelling is reported as a stray, with the count'
    Assert-True ($wn2.Out -match [regex]::Escape($wnRetired2)) `
        'written-name: and the finding names the offending file'
    Assert-True ($wn2.Out -match [regex]::Escape($wnWritten2)) `
        'written-name: and the name it should carry, so the repair needs no source reading'

    # 3. THE WHOLE KIND: every lens on the retired spelling. This is the shape both shipped steps had --
    #    the files moved, the Current row did not -- and it must read as a row that came apart rather
    #    than as two strays.
    Remove-Item -LiteralPath (Join-Path $wnDir $wnWritten) -Force
    [System.IO.File]::WriteAllText((Join-Path $wnDir $wnRetired), $wnBody, $Utf8NoBom)
    $wn3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($wn3.Out -match '\[written-name\] all 2 Lens file') `
        'written-name: a whole kind on the other spelling reads as the row and the files coming apart'
    Assert-True ($wn3.Out -match 'ONE commit') `
        'written-name: and the finding says the two halves belong in one commit -- the rule, not just the diff'
    Assert-True ($wn3.Code -ne 0) `
        'written-name: it is an ERROR and fails the gate -- a mid-rename tree is what this refuses'

    # 4. A NAME MATCHING NEITHER SPELLING IS NOT THIS CHECK'S FINDING. Its id does not resolve, so checks
    #    3b/3c/6 own it and this one passes over it. Without this assert the check could grow into
    #    reporting every *-lens.md in the tree, and one file would get two owners with two repairs.
    Remove-Item -LiteralPath (Join-Path $wnDir $wnRetired) -Force
    Remove-Item -LiteralPath (Join-Path $wnDir $wnRetired2) -Force
    [System.IO.File]::WriteAllText((Join-Path $wnDir 'notes-lens.md'), $wnBody, $Utf8NoBom)
    $wn4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($wn4.Out -match $wnFinding)) `
        'written-name: a file whose id resolves under NEITHER spelling is left to 3b/3c/6, not reported twice'
    Assert-True ($wn4.Out -match '\[written-name\] checked 0\b') `
        'written-name: and the coverage says 0 rather than 1 -- it was passed over, not silently accepted'

    Remove-Item -Recurse -Force -LiteralPath (Join-Path $Fixture '.claude') -ErrorAction SilentlyContinue

    # --- -SkipCheck: the guard rails around the one parameter that can make this gate check less ------
    #     The parameter exists for THIS suite and nothing else. Its failure mode is silence -- a gate
    #     that ran fewer checks and still said "0 errors" -- so the three things that make it safe are
    #     asserted here rather than trusted: a skip announces itself, an unknown name is refused, and no
    #     production caller passes it at all.
    Write-Host "-SkipCheck: a skipped check announces itself and is never reported as 'checked 0'" -ForegroundColor Cyan
    $skipRun = Invoke-Integrity -FixtureRoot $Fixture
    foreach ($cat in @('agent-def', 'parse', 'branch-template')) {
        Assert-True ($skipRun.Out -match ("\[SKIP\]\s+" + [regex]::Escape($cat) + "\b")) `
            "-SkipCheck: '$cat' prints a [SKIP] line saying nothing was asserted about it"
        # THE ONE THAT MATTERS MOST. This gate makes an empty scan visible on purpose -- 'checked 0' is a
        # finding-shaped statement. If a skip printed that instead, a reader (and an assert) could not
        # tell "there was nothing to check" from "this check did not run".
        Assert-True (-not ($skipRun.Out -match ("\[" + [regex]::Escape($cat) + "\] checked"))) `
            "-SkipCheck: and '$cat' prints NO coverage line, so a skip cannot be misread as an empty scan"
    }

    Write-Host "-SkipCheck: an unknown check name is refused rather than ignored" -ForegroundColor Cyan
    $badSkipPath = Join-Path $Fixture 'scripts\lint\check-plugin-integrity.ps1'
    $prevEapSkip = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $badOut  = & powershell -NoProfile -ExecutionPolicy Bypass -File $badSkipPath -SkipCheck 'agentdef' 2>&1
        $badCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEapSkip }
    Assert-True ($badCode -ne 0) '-SkipCheck: a misspelled name fails the run instead of quietly skipping nothing'
    Assert-True ($badCode -ne 1) '-SkipCheck: and its exit code is distinct from 1, so bad usage is not read as findings'
    Assert-True ((($badOut | Out-String) -match 'not a skippable check')) '-SkipCheck: the refusal says what was wrong'
    Assert-True ((($badOut | Out-String) -match 'agent-def')) '-SkipCheck: and names the ones that ARE skippable, so the fix needs no source reading'

    Write-Host "-SkipCheck: no gate that guards main passes it" -ForegroundColor Cyan
    # A reduced gate must never run where a merge depends on it. Asserted on the callers rather than on
    # the parameter, because the parameter cannot know who invoked it -- and these three are the whole
    # set of places this script runs outside its own suite.
    foreach ($caller in @('scripts\release\open-pr.ps1', 'scripts\release\cut-release.ps1', '.github\workflows\ci.yml')) {
        $callerPath = Join-Path $RepoRoot $caller
        Assert-True (Test-Path -LiteralPath $callerPath) "-SkipCheck: $caller exists to be checked"
        if (Test-Path -LiteralPath $callerPath) {
            $callerText = [System.IO.File]::ReadAllText($callerPath, [System.Text.Encoding]::UTF8)
            Assert-True (-not ($callerText -match '-SkipCheck')) `
                "-SkipCheck: $caller runs the FULL gate -- it never reduces the check set"
        }
    }
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
