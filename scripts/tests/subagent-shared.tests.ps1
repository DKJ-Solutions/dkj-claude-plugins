<#
.SYNOPSIS
    Regression tests for the shared agent-def blocks: the lib (subagent-shared-lib.ps1), the generator
    (build-agent-defs.ps1) and the drift gate in check-plugin-integrity.ps1.

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. The unit tests dot-source the lib and run
    Expand-AgentDefShared against in-memory fixtures; the smoke tests run the real scripts as a
    CHILD PROCESS (powershell -File) because they call 'exit' themselves.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/subagent-shared.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Lib       = Join-Path $RepoRoot 'scripts\lib\subagent-shared-lib.ps1'
$Build     = Join-Path $RepoRoot 'scripts\agents\build-agent-defs.ps1'
$Integrity = Join-Path $RepoRoot 'scripts\lint\check-plugin-integrity.ps1'
$Fixture   = Join-Path ([System.IO.Path]::GetTempPath()) "subagent-shared-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

. $Lib

$script:pass = 0
$script:fail = 0
function Assert-Equal { param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True { param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Invoke-Script { param([string]$Path, [string[]]$ScriptArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ScriptArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}
function New-Problems { New-Object System.Collections.Generic.List[string] }

try {
    # --- Fixture source: a shared block 'greeting' ---------------------------------------------------
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
    $blockText = "- hello world`n- second line"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'greeting.md'), "$blockText`n", (New-Object System.Text.UTF8Encoding($false)))

    # THE FIXTURE ASKS THE LIB FOR THE SENTINEL rather than repeating its text. That is the point of the
    # change this covers: the wording has one source, so a test carrying its own copy would be the 179th
    # hand-typed instance and would keep passing after the canonical one was reworded.
    $begin = Format-SharedBeginSentinel -Name 'greeting'
    $end   = '<!-- END shared:greeting -->'
    $inSync = "before`n$begin`n$blockText`n$end`nafter"

    # --- 1. In-sync content stays the same; no problems ---------------------------------------------
    Write-Host "Expand-AgentDefShared -- in sync" -ForegroundColor Cyan
    $p1 = New-Problems
    $o1 = Expand-AgentDefShared -Content $inSync -SharedDir $Fixture -Problems $p1
    Assert-Equal $inSync $o1 'in-sync content stays byte-equal'
    Assert-Equal 0 $p1.Count 'no problems on in-sync content'

    # --- 2. Drift is detected and restored from the source ----------------------------------------
    Write-Host "Expand-AgentDefShared -- drift" -ForegroundColor Cyan
    $stale = "before`n$begin`n- MANUALLY CHANGED`n$end`nafter"
    $p2 = New-Problems
    $o2 = Expand-AgentDefShared -Content $stale -SharedDir $Fixture -Problems $p2
    Assert-True ($o2 -ne $stale) 'drift detected (expand deviates from the input)'
    Assert-Equal $inSync $o2 'expand restores the region from the canonical source'

    # --- 2b. The BEGIN SENTINEL is owned too, not copied through (#669 C2) --------------------------
    # The wording used to be hand-maintained in 178 places, because Expand-AgentDefShared replaced the
    # content between the sentinels and passed the BEGIN line along untouched. These asserts are what
    # makes it single-source: they must fail if that line ever goes back to being copied.
    Write-Host "Expand-AgentDefShared -- the BEGIN sentinel is rebuilt, not copied" -ForegroundColor Cyan
    $retired = '<!-- BEGIN shared:greeting -- GENERATED, edit subagent-shared/greeting.md -->'
    $withRetired = "before`n$retired`n$blockText`n$end`nafter"
    $p2b = New-Problems
    $o2b = Expand-AgentDefShared -Content $withRetired -SharedDir $Fixture -Problems $p2b
    Assert-Equal $inSync $o2b 'the retired sentinel wording is rewritten to the canonical one'
    Assert-True (-not ($o2b -match 'edit subagent-shared/greeting\.md')) 'the dead pointer is gone from the output'
    Assert-Equal 0 $p2b.Count 'and a drifted sentinel is a rewrite, not a reported problem -- the builder fixes it'
    # Any wording at all, not just the one retired string: the rule is that this line is generated.
    $invented = "before`n<!-- BEGIN shared:greeting -- whatever somebody typed here -->`n$blockText`n$end`nafter"
    Assert-Equal $inSync (Expand-AgentDefShared -Content $invented -SharedDir $Fixture -Problems (New-Problems)) 'an invented sentinel wording is normalized too'
    # Indentation survives. No sentinel in this tree is indented today, so this guards the case a nested
    # shared block would create -- silently unindenting it would change markdown around content the
    # expander is not allowed to touch.
    $indented = "before`n    $retired`n$blockText`n    $end`nafter"
    $oInd = Expand-AgentDefShared -Content $indented -SharedDir $Fixture -Problems (New-Problems)
    Assert-True ($oInd -match "(?m)^    <!-- BEGIN shared:greeting -- GENERATED, do not edit here -->$") 'the indent of a nested sentinel is carried through'

    # --- 3. BEGIN without END is reported ------------------------------------------------------------
    Write-Host "Expand-AgentDefShared -- BEGIN without END" -ForegroundColor Cyan
    $noEnd = "before`n$begin`n- something"
    $p3 = New-Problems
    $null = Expand-AgentDefShared -Content $noEnd -SharedDir $Fixture -Problems $p3
    Assert-True ($p3.Count -ge 1) 'BEGIN without END is reported as a problem'

    # --- 4. Unknown block (missing source) is reported ----------------------------------------------
    Write-Host "Expand-AgentDefShared -- unknown block" -ForegroundColor Cyan
    $unknown = "before`n<!-- BEGIN shared:doesnotexist -->`n- x`n<!-- END shared:doesnotexist -->`nafter"
    $p4 = New-Problems
    $null = Expand-AgentDefShared -Content $unknown -SharedDir $Fixture -Problems $p4
    Assert-True ($p4.Count -ge 1) 'unknown block (missing source) is reported'

    # --- 5. Multiple blocks in ONE agent-def all get filled -------------------------------------
    Write-Host "Expand-AgentDefShared -- multiple blocks" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'second.md'), "- block two`n", (New-Object System.Text.UTF8Encoding($false)))
    $b2 = '<!-- BEGIN shared:second -->'; $e2 = '<!-- END shared:second -->'
    $multiStale = "top`n$begin`n- old`n$end`nmiddle`n$b2`n- old2`n$e2`nbottom"
    $p5 = New-Problems
    $o5 = Expand-AgentDefShared -Content $multiStale -SharedDir $Fixture -Problems $p5
    Assert-True ($o5 -match 'hello world' -and $o5 -match 'block two') 'both blocks filled from their source'
    Assert-True (-not ($o5 -match 'old2')) 'stale content of the second block replaced'

    # --- 6. Smoke: the real repo is in sync ----------------------------------------------------------
    Write-Host "build-agent-defs.ps1 -Check + check-plugin-integrity.ps1 -- repo in sync" -ForegroundColor Cyan
    $rb = Invoke-Script -Path $Build -ScriptArgs @('-Check')
    Assert-Equal 0 $rb.Code 'build -Check: all shared blocks in sync on the repo'
    $ri = Invoke-Script -Path $Integrity -ScriptArgs @()
    Assert-Equal 0 $ri.Code 'lint gate green on the repo (incl. shared check)'
    # The findings, on failure only -- same reason as the twin assert in bootstrap-drift.tests.ps1: this
    # one runs the gate over the LIVE repo, so it can fail from a collision with a concurrent suite, and
    # 'expected 0, got 1' cannot tell that apart from a real finding in the branch under test.
    if ($ri.Code -ne 0) {
        @($ri.Out -split "`r?`n" | Where-Object { $_ -match '^\s*\[' -and $_ -notmatch 'checked \d' } | Select-Object -First 10) |
            ForEach-Object { Write-Host ("         gate said: " + $_.Trim()) -ForegroundColor DarkYellow }
    }

    # --- 7. THE GENERATOR AND THE GATE WALK THE PERSONAS TOO ----------------------------------------
    # The widening of August 8, 2026. Both halves are tested, because a generator that writes a file the
    # gate does not read is the exact shape in which a shared block goes quietly stale: the build keeps
    # reporting "in sync" and the gate keeps reporting green, while nothing has compared that file with
    # its source since the day it was placed.
    Write-Host "the personas are in scope, not just the agent defs" -ForegroundColor Cyan
    $realAgents = @(Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-subagent.md' -File |
        Where-Object { $_.FullName -match '\\subagents\\' })
    $realPersonas = @(Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-persona.md' -File |
        Where-Object { $_.FullName -match '\\personas\\' })
    Assert-True ($realPersonas.Count -gt 0) 'there are personas to cover in the first place'

    # The gate's own coverage line is the measurement: it states what it walked, so a gate that quietly
    # narrowed back to agents/ fails here instead of staying green on a smaller surface.
    $sharedCoverage = ($ri.Out -split "`n" | Where-Object { $_ -match '\[shared\]\s+checked\s+(\d+)' } | Select-Object -First 1)
    Assert-True ($sharedCoverage -match '\[shared\]\s+checked\s+(\d+)') 'the lint reports a [shared] coverage count'
    $sharedCount = if ($sharedCoverage -match '\[shared\]\s+checked\s+(\d+)') { [int]$Matches[1] } else { -1 }
    Assert-Equal ($realAgents.Count + $realPersonas.Count) $sharedCount 'the gate walks every agent def AND every persona'
    Assert-True ($sharedCount -gt $realAgents.Count) 'and that is strictly more than the agent defs alone -- the widening really happened'

    # The generator's scope. A source assertion rather than a drift run, deliberately: build-agent-defs
    # resolves its own repo root and cannot be pointed at a fixture, so drifting a real persona to prove
    # the point would mean editing a shipped file inside a test.
    $buildSrc = [System.IO.File]::ReadAllText($Build, [System.Text.Encoding]::UTF8)
    Assert-True ($buildSrc -match "'\*-persona\.md'") 'the generator collects *-persona.md'
    Assert-True ($buildSrc -match "personas") 'and filters on the personas directory'

    # --- 8. Every specialist actually carries the way-of-working block ------------------------------
    # A block whose whole purpose is "adapt to the repo you are installed in" is worth nothing in the
    # files it was never placed in, and placement is a one-off editorial act that no gate re-runs.
    Write-Host "repo-way-of-working reaches every specialist" -ForegroundColor Cyan
    $missing = @()
    foreach ($f in ($realAgents + $realPersonas)) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($text -notmatch 'BEGIN shared:repo-way-of-working') { $missing += $f.Name }
    }
    Assert-Equal '' ($missing -join ', ') 'no agent def or persona is missing the block'
    $srcBlock = Join-Path $RepoRoot 'plugins\dkj-subagents\subagent-shared\repo-way-of-working.md'
    Assert-True (Test-Path -LiteralPath $srcBlock) 'the canonical source file exists'

    # --- lens-optional: every agent def, no persona, and the pointer it answers (#669 C1) ----------
    # ASSERTED IN BOTH DIRECTIONS ON PURPOSE. The block tells a specialist that a missing repo lens is a
    # normal state; a persona is loaded THROUGH the consuming repo's CLAUDE.md, so it can never be in
    # that position and carrying the block would reassure it about something impossible. A test that
    # only checked the agent defs would let it spread to the personas unnoticed -- which is how a
    # per-block scope decision quietly becomes "everyone".
    Write-Host "lens-optional reaches every agent def and no persona" -ForegroundColor Cyan
    $lensMissing = @(); $lensStray = @(); $pointerUnqualified = @()
    foreach ($f in $realAgents) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($text -notmatch 'BEGIN shared:lens-optional') { $lensMissing += $f.Name }
        # The per-file half. Both are needed: without this the block would sit under Boundaries
        # contradicting an opening sentence that still promises a lens is there to be read.
        if ($text -match 'of the consuming repo(?!, if it has one)') { $pointerUnqualified += $f.Name }
    }
    foreach ($f in $realPersonas) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($text -match 'BEGIN shared:lens-optional') { $lensStray += $f.Name }
    }
    Assert-Equal '' ($lensMissing -join ', ') 'no agent def is missing lens-optional'
    Assert-Equal '' ($lensStray -join ', ') 'and no persona carries it -- the scope is a decision, not a default'
    Assert-Equal '' ($pointerUnqualified -join ', ') 'every lens pointer says the repo has one only "if it has one"'
    Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-subagents\subagent-shared\lens-optional.md')) 'the canonical source file exists'

    # --- 9. THE CAPABILITY CIRCLE: a tool that obliges a shared block (issue #1665) ------------------
    # working-copy-boundary is the first block placed by CAPABILITY rather than by craft, and lint check
    # 36 is what keeps that circle complete as the roster changes. These asserts cover the two halves
    # that can fail independently: the lib deciding WHO is obliged, and the gate actually LOOKING.
    Write-Host "the tool -> block obligation (check 36)" -ForegroundColor Cyan

    $map = Get-ToolRequiredSharedBlocks
    Assert-Equal 'working-copy-boundary' $map['Bash'] 'Bash obliges working-copy-boundary'

    # THE FOLDED description: IS THE CASE THAT BROKE THIS. Every agent def in this tree writes its
    # description as a multi-line '>' block, so a frontmatter pattern whose '.' does not span newlines
    # matches nothing and reports every def as tool-less. That shipped as '[tool-block] checked 0' -- a
    # SILENT PASS -- and was caught only because the gate prints what it walked. Hence a fixture whose
    # frontmatter is multi-line rather than the one-line shape that would have passed either way.
    $folded = @(
        '---'
        'name: fixture'
        'description: >'
        '  A description that spans'
        '  more than one line.'
        'tools: Read, Grep, Glob, Bash, Skill'
        'model: sonnet'
        '---'
        ''
        'Body text that mentions tools: Read, Write in prose.'
    ) -join "`n"
    $foldedTools = @(Get-AgentDefTools -Content $folded)
    Assert-True ($foldedTools -contains 'Bash') 'Bash is read through a multi-line folded description'
    Assert-Equal 5 $foldedTools.Count 'and the whole list is read, not just the matched tool'

    # The body's own 'tools:' line must not answer for the file: an agent def may discuss a colleague's
    # tools, and a body match would oblige (or excuse) the wrong specialist.
    $bodyOnly = "---`nname: fixture`n---`n`ntools: Read, Bash`n"
    Assert-Equal 0 (@(Get-AgentDefTools -Content $bodyOnly).Count) 'a tools line in the BODY is not read'

    # THE REFUSAL, which is the only thing that makes this a gate rather than a description. The fixture
    # above names Bash and carries no block, so it is precisely what check 36 must report; asserted on
    # the two readings the check ands together, since a live agent def cannot be broken to prove it.
    Assert-True (($foldedTools -contains 'Bash') -and ($folded -notmatch 'BEGIN shared:working-copy-boundary')) `
        'an obliged def with no block satisfies both halves of the finding -- the check fires'
    # And the mirror: a def that does NOT name the tool is not obliged, so the same missing block is
    # silence rather than a finding. Without this the check would demand the block of all 26.
    $noBash = $folded -replace ', Bash', ''
    Assert-True (@(Get-AgentDefTools -Content $noBash) -notcontains 'Bash') 'and a def without the tool is not obliged'

    # A persona is unaffected without an exemption -- it carries no tools line at all. Asserted on the
    # real personas rather than a fixture, because the claim in subagent-shared/README.md is about them.
    $personaWithTools = @($realPersonas | Where-Object {
        @(Get-AgentDefTools -Content ([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8))).Count -gt 0
    })
    Assert-Equal '' (($personaWithTools | ForEach-Object { $_.Name }) -join ', ') 'no persona declares tools, so none is ever obliged'

    # The real tree, both directions of the circle.
    $obligedDefs = @()
    $obligedMissing = @()
    foreach ($f in $realAgents) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if (@(Get-AgentDefTools -Content $text) -notcontains 'Bash') { continue }
        $obligedDefs += $f.Name
        if ($text -notmatch 'BEGIN shared:working-copy-boundary') { $obligedMissing += $f.Name }
    }
    Assert-True ($obligedDefs.Count -gt 0) 'some agent def holds Bash -- otherwise this check proves nothing'
    Assert-Equal '' ($obligedMissing -join ', ') 'every agent def holding Bash carries working-copy-boundary'
    Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-subagents\subagent-shared\working-copy-boundary.md')) 'the canonical source file exists'

    # AND THE GATE MUST BE LOOKING AT THEM. This is the assert that would have failed on the silent pass:
    # the coverage line's own count, held against the set derived here. A check that walks nothing reports
    # zero findings exactly like a check that walks everything and finds nothing.
    if ($ri.Out -match '\[tool-block\]\s+checked\s+(\d+)') {
        Assert-Equal $obligedDefs.Count ([int]$Matches[1]) 'the gate walked every obliged agent def, not zero of them'
    } else {
        Assert-True $false 'the gate printed a [tool-block] coverage line'
    }
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
