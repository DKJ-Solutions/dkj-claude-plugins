<#
.SYNOPSIS
    Regression tests for the roster-sync RECOVERY (LAYER 3):
    plugins/dkj-subagents/dkj-subagents-alpha/skills/sync-roster/sync-roster.ps1.

.DESCRIPTION
    Dependency-free: no Pester, plain PowerShell. Integration-style -- runs the real sync-roster.ps1
    in a CHILD PROCESS against throwaway fixtures in the temp dir and asserts on exit-code, on the
    files it did (or did not) create, and on its stdout.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/sync-roster.tests.ps1

    Pure ASCII (repo convention for .ps1).

    Detection is delegated to check-roster-sync.ps1. Most cases drive the REAL check (via its
    plugin mirror, resolved relative to sync-roster.ps1) against a fixture cache + consumer, so the
    delegation + [ERROR]-parsing is exercised end-to-end. The never-overwrite guard is driven with a
    STUB check (via -CheckScriptOverride) so a lens can be reported "missing" while the file already
    exists -- the only way to force sync-roster's own additive guard.

    Test-gaps (honest):
      - The dual-context repo-root fallback (git rev-parse) and the CLAUDE_PLUGIN_ROOT resolution
        branches are not exercised: the tests pin -ConsumerPathOverride and clear CLAUDE_PLUGIN_ROOT,
        matching how roster-sync.tests.ps1 pins its inputs.
      - The best-effort "list" roster style is covered; matching an arbitrary real table's exact
        column layout is inherently best-effort and only the row content (id + name + description) is
        asserted, not column alignment.
      - The Split-PluginId guardrail (malformed plugin id -> skip) is unreachable via the real check
        (which validates ids first); case 2b forces it with a stub feeding a bad plugin id.
#>
$ErrorActionPreference = 'Stop'

# Deterministic: the resolution branches must not depend on an ambient hook env var.
$env:CLAUDE_PLUGIN_ROOT = $null

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\skills\sync-roster\sync-roster.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "sync-roster-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$Marketplace = 'dkj-claude-plugins'
$PluginName  = 'dkj-subagents-alpha'
$PluginId    = "$PluginName@$Marketplace"

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -match $Pattern) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         pattern not found: '$Pattern'" -ForegroundColor Red }
}
function Assert-NotMatch {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -notmatch $Pattern) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         pattern present but should not be: '$Pattern'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Invoke-Ps {
    param([string[]]$ScriptArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script @ScriptArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Get-B64 { param([string]$Path) return [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) }

# Fixture cache. -Agents: @{ '06-24' = @{ Name = 'ravi'; Desc = 'Refactoring Specialist. More.' } }.
# -Personas: @('01-01') -- persona-only specialists, which carry id/group but deliberately NO name or
# description (that is the real file shape, and the reason a proposed row for a persona degrades to the
# id plus a placeholder).
function New-FixtureCache {
    param([hashtable]$Agents, [string[]]$Personas = @(), [string]$Version = '1.11.0')
    $cache = Join-Path $Fixture 'cache'
    if (Test-Path -LiteralPath $cache) { Remove-Item -Recurse -Force -LiteralPath $cache }
    $adir = Join-Path $cache "$Marketplace\$PluginName\$Version\agents"
    New-Item -ItemType Directory -Path $adir -Force | Out-Null
    foreach ($id in $Agents.Keys) {
        $g = $id.Split('-')[0]; $i = $id.Split('-')[1]
        $nm = $Agents[$id].Name; $ds = $Agents[$id].Desc
        $fm = "---`nname: $nm`nid: $i`ngroup: $g`ndescription: >`n  $ds`n---`nbody"
        [System.IO.File]::WriteAllText((Join-Path $adir "$id-agent.md"), $fm)
    }
    if ($Personas.Count -gt 0) {
        $pdir = Join-Path $cache "$Marketplace\$PluginName\$Version\personas"
        New-Item -ItemType Directory -Path $pdir -Force | Out-Null
        foreach ($id in $Personas) {
            $g = $id.Split('-')[0]; $i = $id.Split('-')[1]
            [System.IO.File]::WriteAllText((Join-Path $pdir "specialist-$id-persona.md"), "---`nid: $i`ngroup: $g`n---`nbody")
        }
    }
    return $cache
}

# Fixture consumer. RosterIds -> written into CLAUDE.md; LensIds -> lens files on the PRE-SEAM plugin
# path; SeamLensIds -> lens files in the seam (.claude/specialists/lenses/).
#
# THE TEST GAP THIS PARAMETER CLOSES (issue #221). Every scenario below used to hand the fixture a
# pre-seam lens tree, and Get-LensWriteDir follows an existing tree by design -- so the suite only ever
# exercised an ALREADY-ADOPTED consumer, and stayed green while sync-roster hardcoded the pre-seam path
# for the fresh and migrated cases it never covered. A fixture that always arrives in one state tests
# one branch, however many asserts hang off it.
function New-FixtureConsumer {
    param([string[]]$RosterIds = @(), [string[]]$LensIds = @(), [string]$RosterStyle = 'table', [hashtable]$LensContent = @{},
          [string[]]$SeamLensIds = @())
    $root = Join-Path $Fixture 'consumer'
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path (Join-Path $root '.claude') -Force | Out-Null
    $settings = '{ "enabledPlugins": { "' + $PluginId + '": true } }'
    [System.IO.File]::WriteAllText((Join-Path $root '.claude\settings.json'), $settings)

    $lines = @('# Roster', '')
    foreach ($id in $RosterIds) {
        if ($RosterStyle -eq 'list') { $lines += "- $id ([$id-extension.md](x))" }
        else { $lines += "| $id | [$id-extension.md](x) |" }
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'CLAUDE.md'), ($lines -join "`n"))

    if ($LensIds.Count -gt 0) {
        $pdir = Join-Path $root ".claude\plugins\claude-specialists\$PluginName"
        New-Item -ItemType Directory -Path $pdir -Force | Out-Null
        foreach ($id in $LensIds) {
            $body = if ($LensContent.ContainsKey($id)) { $LensContent[$id] } else { "existing-lens-$id" }
            [System.IO.File]::WriteAllText((Join-Path $pdir "$id-extension.md"), $body)
        }
    }
    if ($SeamLensIds.Count -gt 0) {
        $sdir = Join-Path $root '.claude\specialists\lenses'
        New-Item -ItemType Directory -Path $sdir -Force | Out-Null
        foreach ($id in $SeamLensIds) {
            $body = if ($LensContent.ContainsKey($id)) { $LensContent[$id] } else { "existing-lens-$id" }
            [System.IO.File]::WriteAllText((Join-Path $sdir "$id-extension.md"), $body)
        }
    }
    return $root
}

# A stub check-roster-sync that emits fixed [ERROR] lines + exit code (isolates sync-roster).
function New-StubCheck {
    param([string]$Name, [string[]]$OutputLines, [int]$ExitCode = 1)
    $p = Join-Path $Fixture "$Name.ps1"
    if (-not (Test-Path -LiteralPath $Fixture)) { New-Item -ItemType Directory -Path $Fixture -Force | Out-Null }
    # The stub must accept (and ignore) the args sync-roster passes it.
    $head = 'param([string]$ConsumerPathOverride = "", [string]$CacheRootOverride = "")' + "`r`n"
    $body = (($OutputLines | ForEach-Object { 'Write-Host "' + $_ + '"' }) -join "`r`n") + "`r`nexit $ExitCode`r`n"
    [System.IO.File]::WriteAllText($p, ($head + $body))
    return $p
}

try {
    Write-Host "== sync-roster.tests ==" -ForegroundColor Cyan

    $lensRel = ".claude\plugins\claude-specialists\$PluginName"

    # --- 1. Real-check integration: missing-lens -> scaffold; missing-roster -> proposed row --------
    #   06-16: in roster + lens present            -> OK (nothing).
    #   06-17: NOT in roster, lens present         -> missing roster row -> row proposed, NO scaffold.
    #   06-24: in roster, NO lens                  -> missing lens -> scaffold created, NO row.
    $cache = New-FixtureCache -Agents @{
        '06-16' = @{ Name = 'victor';    Desc = 'Code Reviewer here.' }
        '06-17' = @{ Name = 'edith';     Desc = 'Final Editor. The last look before a PR.' }
        '06-24' = @{ Name = 'ravi';      Desc = 'Refactoring Specialist. The DRY guardian.' }
    }
    $c = New-FixtureConsumer -RosterIds @('06-16', '06-24') -LensIds @('06-16', '06-17')
    $rosterPath = Join-Path $c 'CLAUDE.md'
    $rosterBefore = Get-B64 $rosterPath

    $r = Invoke-Ps @('-ConsumerPathOverride', $c, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'integration: exit-code 0'

    # 06-24 lens scaffold created, with the VUL-IN slot.
    $scaffold24 = Join-Path $c "$lensRel\specialist-06-24-lens.md"
    Assert-True (Test-Path -LiteralPath $scaffold24 -PathType Leaf) 'integration: 06-24 lens scaffold file created'
    if (Test-Path -LiteralPath $scaffold24) {
        $s24 = [System.IO.File]::ReadAllText($scaffold24, [System.Text.Encoding]::UTF8)
        Assert-Match '## Specific to this repo \(VUL-IN\)' $s24 'integration: scaffold has the VUL-IN slot'
        # Rename-proof (issue #145): the header carries the stable g-id slug, NOT the persona name.
        Assert-Match '(?m)^# 06-24 .* repo-lens \(VUL-IN\)' $s24 'integration: scaffold header is the nameless g-id form'
        Assert-NotMatch 'Ravi' $s24 'integration: scaffold does NOT bake the persona name (Ravi) in'
    }
    Assert-Match 'created lens scaffold.*06-24' $r.Out 'integration: output reports the created scaffold'

    # 06-17 proposed as a roster row (id + name appear); NO scaffold created for it (lens present).
    Assert-Match '06-17' $r.Out 'integration: proposed row names the id 06-17'
    Assert-Match 'Edith' $r.Out 'integration: proposed row names the agent Edith'
    Assert-Match 'Final Editor' $r.Out 'integration: proposed row carries the description'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c "$lensRel\06-17-extension.md") -PathType Leaf) -or `
                 (([System.IO.File]::ReadAllText((Join-Path $c "$lensRel\06-17-extension.md"))) -eq 'existing-lens-06-17')) `
                'integration: 06-17 existing lens not turned into a scaffold'

    # 06-24 must NOT also be proposed as a roster row (it IS in the roster).
    Assert-NotMatch 'proposed row names the id.*06-24' $r.Out 'integration: 06-24 not proposed as a roster row'

    # CLAUDE.md / the roster is NEVER modified.
    Assert-Equal $rosterBefore (Get-B64 $rosterPath) 'integration: CLAUDE.md bytes unchanged'

    # --- 1b. Persona-only specialists are staged too (inbound #204) ---------------------------------
    #     check-roster-sync now reports a missing PERSONA as [ERROR] too, and both its own report and
    #     the session hook point the reader at this skill to stage the catch-up. This suite is what
    #     stops that pointer from being hollow: the [ERROR]-parsing regex used to match only the literal
    #     word 'agent', so it would have staged NOTHING for exactly the findings that change introduced
    #     -- advice that looks helpful and quietly does nothing.
    #       01-01: persona, NOT in roster, NO lens -> both a proposed row AND a scaffold.
    #       05-05: persona, in roster + lens       -> nothing.
    $cache = New-FixtureCache -Agents @{ '06-16' = @{ Name = 'victor'; Desc = 'Code Reviewer here.' } } `
                              -Personas @('01-01', '05-05')
    $c = New-FixtureConsumer -RosterIds @('06-16', '05-05') -LensIds @('06-16', '05-05')
    $rosterBefore = Get-B64 (Join-Path $c 'CLAUDE.md')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'persona staging: exit-code 0'

    $scaffold0101 = Join-Path $c "$lensRel\specialist-01-01-lens.md"
    Assert-True (Test-Path -LiteralPath $scaffold0101 -PathType Leaf) 'persona staging: a missing PERSONA lens gets a scaffold'
    if (Test-Path -LiteralPath $scaffold0101) {
        $s0101 = [System.IO.File]::ReadAllText($scaffold0101, [System.Text.Encoding]::UTF8)
        # The scaffold has been nameless since #145, which is exactly why it needs no persona-specific
        # branch: there is no name to look up in a file that does not have one.
        Assert-Match '(?m)^# 01-01 .* repo-lens \(VUL-IN\)' $s0101 'persona staging: the nameless scaffold shape works unchanged for a persona'
    }
    Assert-Match '01-01' $r.Out 'persona staging: a proposed roster row names the persona id'
    # Degraded but honest: a persona file carries no name/description, so Get-AgentInfo returns $null and
    # the row falls back to the id plus a placeholder rather than inventing a name.
    Assert-Match 'add a short description' $r.Out 'persona staging: the row carries the placeholder description a persona cannot supply'
    # A satisfied persona must not be staged at all -- the skill stays as quiet as the check.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c "$lensRel\05-05-extension.md")) -or `
                 (([System.IO.File]::ReadAllText((Join-Path $c "$lensRel\05-05-extension.md"))) -eq 'existing-lens-05-05')) `
                'persona staging: a satisfied persona lens is left untouched'
    Assert-Equal $rosterBefore (Get-B64 (Join-Path $c 'CLAUDE.md')) 'persona staging: CLAUDE.md bytes unchanged (propose-only)'

    # --- 2. Additive guard: an existing lens is NEVER overwritten -----------------------------------
    #   The stub reports 06-16 as missing-lens WHILE the plugin-path lens already exists -- the only
    #   way to force sync-roster's own never-overwrite branch. Assert the file's bytes are unchanged.
    $c2 = New-FixtureConsumer -RosterIds @('06-16') -LensIds @('06-16')
    $lens16 = Join-Path $c2 "$lensRel\06-16-extension.md"
    $lensBefore = Get-B64 $lens16
    $rosterPath2 = Join-Path $c2 'CLAUDE.md'
    $rosterBefore2 = Get-B64 $rosterPath2
    $stub = New-StubCheck -Name 'stub-missing-lens' -OutputLines @(
        "  [ERROR] agent '06-16' ($PluginId) has no repo-lens (.claude/plugins/... path).")
    $emptyCache = Join-Path $Fixture 'empty-cache'
    New-Item -ItemType Directory -Path $emptyCache -Force | Out-Null
    $r = Invoke-Ps @('-ConsumerPathOverride', $c2, '-CacheRootOverride', $emptyCache, '-CheckScriptOverride', $stub)
    Assert-Equal 0 $r.Code 'additive: exit-code 0'
    Assert-Match 'already exists.*left untouched' $r.Out 'additive: existing lens reported as untouched'
    Assert-Equal $lensBefore (Get-B64 $lens16) 'additive: existing lens bytes unchanged (not overwritten)'
    Assert-Equal $rosterBefore2 (Get-B64 $rosterPath2) 'additive: CLAUDE.md bytes unchanged'

    # --- 2b. Guardrail: a malformed plugin id in an [ERROR] line is skipped, not turned into a path --
    #   Defense-in-depth: check-roster-sync validates plugin ids before it emits per-agent errors, so
    #   this is unreachable via the real check -- forced here with a stub feeding a bad plugin id.
    $c2b = New-FixtureConsumer -RosterIds @('06-16') -LensIds @('06-16')
    $rosterBefore2b = Get-B64 (Join-Path $c2b 'CLAUDE.md')
    $stub = New-StubCheck -Name 'stub-bad-plugin' -OutputLines @(
        "  [ERROR] agent '06-24' (Bad_Name@dkj-claude-plugins) has no roster row in CLAUDE.md -- add it to the roster.")
    $r = Invoke-Ps @('-ConsumerPathOverride', $c2b, '-CacheRootOverride', $emptyCache, '-CheckScriptOverride', $stub)
    Assert-Equal 0 $r.Code 'guardrail: exit-code 0'
    Assert-Match 'invalid plugin id' $r.Out 'guardrail: malformed plugin id skipped'
    Assert-Equal $rosterBefore2b (Get-B64 (Join-Path $c2b 'CLAUDE.md')) 'guardrail: CLAUDE.md bytes unchanged'

    # --- 3. Clean repo: nothing missing -> nothing staged, exit 0 -----------------------------------
    $cache = New-FixtureCache -Agents @{ '06-16' = @{ Name = 'victor'; Desc = 'Code Reviewer.' } }
    $c3 = New-FixtureConsumer -RosterIds @('06-16') -LensIds @('06-16')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c3, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'clean: exit-code 0'
    Assert-Match 'nothing to stage' $r.Out 'clean: reports nothing to stage'
    Assert-NotMatch 'created lens scaffold' $r.Out 'clean: no scaffold created'

    # --- 4. List-style roster: proposed row uses the list form --------------------------------------
    #   06-24 missing from roster (list style), lens present -> a list-form proposed row.
    $cache = New-FixtureCache -Agents @{
        '06-16' = @{ Name = 'victor'; Desc = 'Code Reviewer.' }
        '06-24' = @{ Name = 'ravi';   Desc = 'Refactoring Specialist.' }
    }
    $c4 = New-FixtureConsumer -RosterIds @('06-16') -LensIds @('06-16', '06-24') -RosterStyle 'list'
    $r = Invoke-Ps @('-ConsumerPathOverride', $c4, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'list style: exit-code 0'
    Assert-Match 'style: list' $r.Out 'list style: detected as a list roster'
    Assert-Match '- \*\*Ravi\*\* #24' $r.Out 'list style: proposed row uses the list form'

    # --- 5. Reminder that main is sacred / nothing was committed ------------------------------------
    Assert-Match 'wrote NOTHING to.*CLAUDE.md or any lens, and committed nothing' $r.Out 'reminder: sacred-main notice present'

    # --- 6. Stale lens header (rename): a paste-ready nameless reconcile is proposed (issue #145) ----
    #   Real check drives detection. 06-16's agent is now 'sebastian', but its lens header still names
    #   'Sean' (an older scaffold) -> a header reconcile is staged. 06-17's header names 'Edith', which
    #   MATCHES its agent -> no reconcile. The lens files are NEVER rewritten (propose-only).
    $midDot = [char]0x00B7
    $cache = New-FixtureCache -Agents @{
        '06-16' = @{ Name = 'sebastian'; Desc = 'Security Engineer.' }
        '06-17' = @{ Name = 'edith';     Desc = 'Copy Editor.' }
    }
    $staleHdr = "---`nid: 16`ngroup: 06`n---`n`n# Sean $midDot repo-lens`n`n> Repo-lens for Sean.`nfilled body"
    $freshHdr = "---`nid: 17`ngroup: 06`n---`n`n# Edith $midDot repo-lens`n`nbody"
    $c6 = New-FixtureConsumer -RosterIds @('06-16', '06-17') -LensIds @('06-16', '06-17') `
        -LensContent @{ '06-16' = $staleHdr; '06-17' = $freshHdr }
    $lens16Path = Join-Path $c6 "$lensRel\06-16-extension.md"
    $lens16Before = Get-B64 $lens16Path
    $r = Invoke-Ps @('-ConsumerPathOverride', $c6, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'header reconcile: exit-code 0'
    Assert-Match "header names 'Sean'.*is now 'Sebastian'" $r.Out 'header reconcile: stale 06-16 header detected'
    Assert-Match "(?m)^\s*# 06-16 .* repo-lens\s*$" $r.Out 'header reconcile: nameless replacement header printed'
    Assert-Match '1 header reconcile' $r.Out 'header reconcile: counted in the summary'
    Assert-NotMatch "'06-17'.*header still names" $r.Out 'header reconcile: matching header (06-17=Edith) not flagged'
    Assert-Equal $lens16Before (Get-B64 $lens16Path) 'header reconcile: lens file bytes unchanged (propose-only)'

    # --- 7. WHERE the scaffold lands: the seam for a fresh/migrated consumer (issue #221) ------------
    #   The branch the suite above never reached. sync-roster must resolve its destination through the
    #   same Get-LensWriteDir the bootstrap uses, so the two writers cannot disagree about a repo's
    #   layout. Three cases, because each one used to be answered by a hardcoded literal:
    #     7a. fresh consumer  (no lens tree at all)      -> the seam
    #     7b. migrated consumer (lenses in the seam)     -> the seam, alongside them
    #     7c. pre-seam consumer (lenses on the old path) -> that tree, NOT the seam (never relocate)
    $seamRel    = '.claude\specialists\lenses'
    $preSeamRel = ".claude\plugins\claude-specialists\$PluginName"
    $cache = New-FixtureCache -Agents @{
        '06-16' = @{ Name = 'victor'; Desc = 'Code Reviewer.' }
        '06-24' = @{ Name = 'ravi';   Desc = 'Refactoring Specialist.' }
    }

    # 7a. Fresh: nothing anywhere. 06-24 is in the roster but has no lens -> scaffold expected.
    $c7a = New-FixtureConsumer -RosterIds @('06-16', '06-24')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c7a, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'seam 7a: exit-code 0'
    Assert-True (Test-Path -LiteralPath (Join-Path $c7a "$seamRel\specialist-06-24-lens.md") -PathType Leaf) `
        'seam 7a: a fresh consumer gets the scaffold in the seam'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c7a "$preSeamRel\specialist-06-24-lens.md") -PathType Leaf)) `
        'seam 7a: nothing written to the pre-seam plugin path -- the defect this test exists for'
    Assert-Match '\.claude/specialists/lenses/specialist-06-24-lens\.md' $r.Out `
        'seam 7a: the reported path is the seam, forward-slashed'

    # 7b. Migrated: a lens already sits in the seam, so the writer must stay there.
    $c7b = New-FixtureConsumer -RosterIds @('06-24') -SeamLensIds @('06-16')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c7b, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'seam 7b: exit-code 0'
    Assert-True (Test-Path -LiteralPath (Join-Path $c7b "$seamRel\specialist-06-24-lens.md") -PathType Leaf) `
        'seam 7b: a migrated consumer keeps its lenses together in the seam'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c7b "$preSeamRel\specialist-06-24-lens.md") -PathType Leaf)) `
        'seam 7b: the lens surface is NOT split across two layouts'

    # 7c. Pre-seam: an un-migrated consumer is followed, never relocated. This is the case the old
    #     literal got right by accident, and it must keep working -- migrating is the owner's act.
    $c7c = New-FixtureConsumer -RosterIds @('06-24') -LensIds @('06-16')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c7c, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'seam 7c: exit-code 0'
    Assert-True (Test-Path -LiteralPath (Join-Path $c7c "$preSeamRel\specialist-06-24-lens.md") -PathType Leaf) `
        'seam 7c: an un-migrated consumer keeps writing to its own tree'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c7c "$seamRel\specialist-06-24-lens.md") -PathType Leaf)) `
        'seam 7c: no seam copy created next to it -- the writer follows, it does not migrate'

    # 7d. The PROPOSED ROSTER ROW's link is the second site the literal was hardcoded in. A row a human
    #     pastes with a path that does not exist is worse than no row: it looks authoritative.
    $c7d = New-FixtureConsumer -RosterIds @() -SeamLensIds @('06-16')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c7d, '-CacheRootOverride', $cache)
    Assert-Equal 0 $r.Code 'seam 7d: exit-code 0'
    Assert-Match '\(\.claude/specialists/lenses/06-16-extension\.md\)' $r.Out `
        'seam 7d: the proposed roster row links into the seam, not the pre-seam path'
    Assert-NotMatch '\.claude/plugins/claude-specialists' $r.Out `
        'seam 7d: no pre-seam path anywhere in the output of a migrated consumer'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
}

Write-Host "`nResult: $($script:pass) pass, $($script:fail) fail." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
