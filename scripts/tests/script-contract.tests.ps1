<#
.SYNOPSIS
    Regression tests for the script-contract check (scripts/sync/check-script-contract.ps1, issue
    #147) and its SessionStart hook
    (plugins/dkj-policy/hooks/script-contract-sessioncheck.ps1).

.DESCRIPTION
    Dependency-free: no Pester, plain PowerShell. Integration-style -- runs the REAL check script (and
    the real hook) in a CHILD PROCESS against throwaway fixture repo roots in the temp dir, and
    asserts on exit-code + output, mirroring roster-sync.tests.ps1 (the closest analogue: same
    -ConsumerPathOverride pattern, same Assert-* helpers, same fixture-setup/teardown style).

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/script-contract.tests.ps1

    Fixture strategy: the POSITIVE fixtures copy the REAL scripts/lib/branch-info.ps1 and
    scripts/repo-config.ps1 verbatim (same idea as new-branch.tests.ps1 copying branch-info.ps1 for
    its real prefix table) -- so a passing suite here is grounded in this repo's actual contract, not
    a hand-rolled stand-in that could silently diverge from it. NEGATIVE fixtures start from that
    same real content and surgically remove one function's definition (Remove-PsFunction, a
    brace-counting cut -- a plain regex could not reliably find the matching closing brace) so the
    rest of the file (helper variables, other functions) stays exactly as-is and the only difference
    from the positive fixture is the one missing function.

    Pure ASCII (repo convention for .ps1).

    Test-gaps (honest):
      - The dual-context repo-root fallback of check-script-contract.ps1 (CLAUDE_PROJECT_DIR / git
        rev-parse when -ConsumerPathOverride is absent) is not exercised here -- every scenario pins
        the root explicitly, the same choice roster-sync.tests.ps1 documents for its own check.
      - Only branch-info.ps1 / repo-config.ps1 syntax-error-via-throw is exercised for the "lib throws
        on load" scenario (a deliberate `throw` statement) -- a genuine PowerShell PARSE error (e.g. an
        unbalanced brace) would also be caught by the same try/catch in the product script, but is not
        separately exercised here; the caught-exception code path is identical either way.
      - The hook's own $env:CLAUDE_PLUGIN_ROOT resolution branch (picking up
        ${CLAUDE_PLUGIN_ROOT}/scripts/sync/check-script-contract.ps1 when -CheckScriptOverride is
        omitted) is not exercised -- every hook scenario here pins -CheckScriptOverride explicitly, so
        the hook is tested end-to-end against the REAL check script rather than a stub, but always via
        the override path, not the plugin-root default.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot      = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script        = Join-Path $RepoRoot 'scripts\sync\check-script-contract.ps1'
# The registry moved out of the check on August 8, 2026 (#456), once a third reader appeared -- the
# blueprint generator. The scenarios below still run the real CHECK; the asserts about how records are
# DECLARED read the lib, which is where they are now.
$ContractLib   = Join-Path $RepoRoot 'scripts\lib\script-contract-lib.ps1'
$Hook          = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\script-contract-sessioncheck.ps1'
$BranchInfoSrc = Join-Path $RepoRoot 'scripts\lib\branch-info.ps1'
$RepoConfigSrc = Join-Path $RepoRoot 'scripts\repo-config.ps1'
$Fixture       = Join-Path ([System.IO.Path]::GetTempPath()) "script-contract-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

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

function Assert-NotMatch {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -notmatch $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern present but should not be: '$Pattern'" -ForegroundColor Red
    }
}

function Invoke-Ps {
    param([string[]]$ScriptArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script @ScriptArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Invoke-Hook {
    param([string[]]$HookArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @HookArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

# Removes one PowerShell function definition ('function <Name> { ... }') from $Content, by counting
# braces from the first '{' after the 'function <Name>' token until the matching close -- a plain
# regex cannot reliably find the RIGHT closing brace once the body itself contains nested braces
# (both branch-info.ps1's and repo-config.ps1's functions do, e.g. an inline hashtable literal), so
# this walks the text char-by-char instead. Throws (a fixture-builder bug, not a product bug) if the
# function name is not found, so a typo in a test scenario fails loudly instead of silently keeping
# the "positive" content.
function Remove-PsFunction {
    param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][string]$FunctionName)
    $m = [regex]::Match($Content, "function\s+$([regex]::Escape($FunctionName))\b")
    if (-not $m.Success) {
        throw "Remove-PsFunction: '$FunctionName' not found in the given content -- fixture-builder bug."
    }
    $braceIdx = $Content.IndexOf('{', $m.Index)
    if ($braceIdx -lt 0) {
        throw "Remove-PsFunction: no opening brace found after 'function $FunctionName'."
    }
    $depth = 0
    $i = $braceIdx
    for (; $i -lt $Content.Length; $i++) {
        if ($Content[$i] -eq '{') { $depth++ }
        elseif ($Content[$i] -eq '}') { $depth--; if ($depth -eq 0) { break } }
    }
    if ($i -ge $Content.Length) {
        throw "Remove-PsFunction: no matching closing brace found for '$FunctionName'."
    }
    return $Content.Substring(0, $m.Index) + $Content.Substring($i + 1)
}

$script:RealBranchInfo = [System.IO.File]::ReadAllText($BranchInfoSrc)
$script:RealRepoConfig = [System.IO.File]::ReadAllText($RepoConfigSrc)

# Builds a fixture consumer repo-root with scripts/lib/branch-info.ps1 and/or scripts/repo-config.ps1.
# By default both are the REAL, unmodified content (the positive case). -StripFromBranchInfo /
# -StripFromRepoConfig surgically remove named functions (the negative cases). -OmitBranchInfo /
# -OmitRepoConfig skip writing the file entirely (the "missing lib" cases). -BranchInfoContentOverride
# replaces the whole branch-info.ps1 content outright (the "lib throws on load" case).
function New-FixtureConsumer {
    param(
        [switch]$OmitBranchInfo,
        [switch]$OmitRepoConfig,
        [switch]$OmitWorkflowFolder,
        [string[]]$StripFromBranchInfo = @(),
        [string[]]$StripFromRepoConfig = @(),
        [string]$BranchInfoContentOverride,
        [string]$RepoConfigContentOverride,
        # Repo-relative files to create, for the adoption inventory (issue #2236). Empty by default, so
        # every scenario above keeps testing the record it is about: the adoption section reports three
        # [UNADOPTED] lines against a fixture that has none of them, which is the ordinary state of a
        # throwaway consumer and is asserted deliberately in 12a rather than leaking in as noise.
        [string[]]$PlaceAdoptionFiles = @()
    )
    $root = Join-Path $Fixture 'consumer'
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts\lib') -Force | Out-Null
    # The workflow's own root folder (August 14, 2026): present by default so every scenario below keeps
    # testing the record it is about -- the check reports the folder missing as its own [ERROR], which
    # would otherwise leak into every fixture. -OmitWorkflowFolder is the dedicated negative case.
    if (-not $OmitWorkflowFolder) {
        New-Item -ItemType Directory -Path (Join-Path $root 'dkj-policy') -Force | Out-Null
    }

    # Empty files: the adoption inventory answers on PRESENCE only, exactly as the workflow-folder line
    # above does, and for the same stated reason -- the contents of a scaffolded runner differ
    # legitimately per repo, so anything finer would need the per-repo exemption list this repo declines.
    foreach ($rel in $PlaceAdoptionFiles) {
        $abs = Join-Path $root ($rel -replace '/', '\')
        $dir = Split-Path -Parent $abs
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($abs, '')
    }

    if (-not $OmitBranchInfo) {
        $content = if ($PSBoundParameters.ContainsKey('BranchInfoContentOverride')) { $BranchInfoContentOverride } else { $script:RealBranchInfo }
        foreach ($fn in $StripFromBranchInfo) { $content = Remove-PsFunction -Content $content -FunctionName $fn }
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\lib\branch-info.ps1'), $content)
    }
    if (-not $OmitRepoConfig) {
        $content = if ($PSBoundParameters.ContainsKey('RepoConfigContentOverride')) { $RepoConfigContentOverride } else { $script:RealRepoConfig }
        foreach ($fn in $StripFromRepoConfig) { $content = Remove-PsFunction -Content $content -FunctionName $fn }
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), $content)
    }
    return $root
}

try {
    Write-Host "== script-contract.tests: check-script-contract.ps1 ==" -ForegroundColor Cyan

    # --- 1. Positive: complete, valid branch-info.ps1 + repo-config.ps1 -> all [OK], exit 0 --------
    $c = New-FixtureConsumer
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'happy path: exit-code 0'
    Assert-NotMatch '\[ERROR\]' $r.Out 'happy path: no errors'
    foreach ($fn in @('Get-BranchInfo', 'Test-BranchName', 'Get-RepoName', 'Get-LintScript', 'Get-RosterPath', 'Get-RosterIgnoredIds', 'Get-LiveStage', 'Get-EntryTitlePlaceholder', 'Get-EntryBodyHeading', 'Get-EntryBodyPlaceholder', 'Get-EntryFallbackType', 'Get-PrMergeMethod', 'Get-MojibakePaths', 'Get-ReservedRootMd', 'Get-ReleaseNotesGrouping', 'Get-ReleaseHistoryPath', 'Get-ReleasePluginTier', 'Get-ReleaseConsumerBumps', 'Get-ReleaseMajorMinMinors', 'Get-ReleaseNoteWording', 'Get-InternalNoteWording', 'Get-TriageLabels')) {
        Assert-Match "\[OK\]\s+'$fn' present in" $r.Out "happy path: '$fn' reported OK"
    }
    # FOUR RECORDS RETIRED ON AUGUST 5, 2026, all of them to the flat changelog rather than four separate
    # decisions: Get-ChangelogTierHeadings and the legacy Get-ChangelogHeading (no sections left to name),
    # Get-ReleaseLiveMarker and Get-ReleaseHistoryMode (no release block for a marker to sit on or a mode to
    # select), Get-ReleaseCategoryTitles (no category headings to label) and Get-ChangelogReleaseWording (no
    # release-block text to override). Each is now asserted on ABSENCE from the register, further down.
    # A FLOOR, NOT A PIN (August 15, 2026, #709). This assert used to name an exact number, which meant
    # a hand-edit on almost every change that touched the contract -- measured over the file's history,
    # the record-count literal below had been bumped by hand 21 times, in the sequence 6, 7, 8, 12, 14,
    # 19, 22, 25, 27, 29. A test that must be "fixed" on nearly every ordinary change teaches people to
    # write the assertion to match the code, which is the opposite of what an assertion is for.
    # A floor keeps the property that actually mattered -- a record silently DISAPPEARING still fails
    # the suite -- and costs nothing when one is added. The known gap is stated rather than hidden:
    # adding and removing in the same change can net out above the floor. That gap is narrow, and it is
    # the price of the 21 edits it removes. The number is a high-water mark; raising it is optional
    # tightening, never required maintenance.
    $okCount = @([regex]::Matches($r.Out, '\[OK\]')).Count
    Assert-True ($okCount -ge 27) 'happy path: at least twenty-seven [OK] lines -- every declared record this repo defines (four mandatory functions plus every optional: Get-LiveStage, the two Get-Roster* made optional by #445, the four Get-Entry* stub-wording knobs, Get-PrMergeMethod, Get-MojibakePaths, the cut-release knobs from #417 plus Get-ReleaseMajorMinMinors, Get-ReleaseHistoryPath and Get-ReleaseNoteRoot (inbound #616), BOTH note-wording maps (Get-ReleaseNoteWording, which the cut reads first, and Get-InternalNoteWording, its fallback -- inbound #605), Get-BranchTypes from inbound #580, Get-ReleaseAudienceTier from inbound #620, and the two release-notes-page knobs from August 15, 2026 -- Get-ReleasePageTitle and Get-ReleasePageWorkerName, both answered here) plus the workflow-folder existence line (August 14, 2026), nothing else'
    Assert-Match '\[OK\]\s+workflow folder: dkj-policy/ exists' $r.Out 'happy path: the workflow folder is reported present'
    # inbound #203: the run names the root it inspected and how it resolved it. Asserted on the clean
    # run too, not only on a drifted one -- the [SCOPE] line is context that must always be emitted, so
    # that the hook has something to surface the moment a finding does appear.
    Assert-Match '\[SCOPE\].*check-script-contract inspected' $r.Out 'happy path: a [SCOPE] line names the inspected root'
    Assert-Match ([regex]::Escape($c)) $r.Out 'happy path: the [SCOPE] line names the ACTUAL fixture root, not the session/git root'
    Assert-Match '\[SCOPE\].*-ConsumerPathOverride' $r.Out 'happy path: the [SCOPE] line names HOW the root was resolved (override)'
    # Non-counting, like [OK]/[SKIP]: context must never move the error/info tallies or the exit code. The
    # infos counted here are correct on a healthy repo rather than gaps -- the seams an ENGLISH repo
    # deliberately leaves undefined because the defaults are already its own words. So this assert still
    # proves the [SCOPE] line added nothing, which is what it is for.
    #
    # TWO, DOWN FROM FOUR: the superseded Get-ChangelogHeading and Get-ChangelogReleaseWording were both
    # among them, and both records retired with the flat changelog. Counted rather than named, deliberately
    # -- the number is what catches a record quietly gaining or losing an [INFO].
    #
    # FOUR SINCE INBOUND #580, and the extra two are worth reading carefully, because the same check run
    # against THIS repo prints only one of them. A fixture consumer is a separate repo root, so the
    # release-lib that new-internal-note loads is still the WORKSHOP's -- and the branch-info.ps1 sitting
    # next to it is the workshop's too, not the fixture's. Its Get-BranchTypes is therefore genuinely not
    # the one this consumer wrote, which is exactly the answer a real consumer needs and exactly what a
    # walk over leaf NAMES would have got wrong.
    Assert-Match 'Summary: 0 error\(s\), 12 info signal\(s\)' $r.Out 'happy path: [SCOPE] is non-counting (0 errors; the five deliberately-undefined seams -- the two impact-table ones, Get-TestCommands since inbound #644, Get-EntryGateExemptPrefixes since inbound #789, and Get-ReleasePageMasthead since inbound #809 -- plus two reachability signals: neither fold-changelog-entry nor new-internal-note can see this consumer''s Get-BranchTypes, which is the ordinary state for a repo that has not chained branch-info.ps1 into its repo-config -- plus the TWO of the four optional seams issue #885 added that are still undefined here (Get-ReleaseChangelogNotesRoot, Get-ReleaseGithubNotesRoot), each with a computed default this fixture does not define -- Get-ChangelogPath and Get-ReleaseInternalNotesRoot came off this list on August 27, 2026, when this repo moved those documents into contributing-davekjohn/ and had to STATE both seams to say so -- plus Get-ReachLabel since #1870, September 11, 2026, whose default ''minor'' is what this repo''s own label is called, so stating it would restate the default -- plus Get-ResolvesExemptMatchers since inbound #2120, September 18, 2026: this repo mirrors its issues into no second tracker, so it carves out no class of issue from the resolves gate and its default IS its answer -- plus Get-DeclinedAdoptions since #2236, September 21, 2026, which this repo deliberately leaves undefined: the adoption section that reads it is SKIPPED in the repo that publishes this workflow, so an answer here would be dead text arguing for a silence nothing is asking for)'

    # --- 1b. The workflow folder is missing -> its own [ERROR], naming the scaffold skill ----------
    #     (August 14, 2026.) A plugin install writes nothing into a consumer's repo, so this line is
    #     the one signal a consumer gets that the folder everything portable gathers in does not exist
    #     yet. [ERROR] deliberately: the session hook forwards [ERROR] lines only. Existence only --
    #     the folder's contents differ legitimately per repo.
    $c = New-FixtureConsumer -OmitWorkflowFolder
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'missing workflow folder: exit-code 1'
    Assert-Match "\[ERROR\].*'dkj-policy/' does not exist" $r.Out 'missing workflow folder: the ERROR names the folder'
    Assert-Match 'adopt-dkj-policy' $r.Out 'missing workflow folder: the finding names the skill that scaffolds it'
    $errCountWf = @([regex]::Matches($r.Out, '\[ERROR\]')).Count
    Assert-Equal 1 $errCountWf 'missing workflow folder: exactly one error -- every contract record is still satisfied'

    # --- 2. Missing function in branch-info.ps1 (the exact #147 incident): Test-BranchName ---------
    #     new-branch crashed at runtime with "The term 'Test-BranchName' is not recognized" because
    #     the consumer's branch-info.ps1 predated that helper. Get-BranchInfo stays intact, so this
    #     must be the ONLY error, naming both the function and the shared script it breaks.
    $c = New-FixtureConsumer -StripFromBranchInfo @('Test-BranchName')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'missing Test-BranchName: exit-code 1'
    # The finding must be actionable on its own (Dave, July 28, 2026: a consumer is served by the
    # plugin, not put to work for it). It used to end with "update it from the workshop's own
    # scripts\lib\branch-info.ps1" -- useless to the reader most likely to hit it: someone who installed
    # the plugin, has no copy of that source repo, and no reason to know it exists.
    Assert-Match 'It must return' $r.Out 'missing function: the finding states what the function must return'
    Assert-NotMatch "workshop's own" $r.Out 'missing function: the finding no longer points at a repo the reader may not have'
    Assert-NotMatch 'workshop' $r.Out 'missing function: no internal "workshop" jargon in a consumer-facing finding'
    Assert-Match "\[ERROR\].*'Test-BranchName' missing from scripts\\lib\\branch-info\.ps1.*required by: new-branch" $r.Out 'missing Test-BranchName: ERROR names the function, the lib, and new-branch'
    $errCount1 = @([regex]::Matches($r.Out, '\[ERROR\]')).Count
    Assert-Equal 1 $errCount1 'missing Test-BranchName: exactly one error (Get-BranchInfo unaffected)'
    Assert-Match "\[OK\]\s+'Get-BranchInfo' present in" $r.Out 'missing Test-BranchName: Get-BranchInfo still OK'

    # --- 3. Missing Get-RosterPath is an INFO, not an error (inbound #445) --------------------------
    #     It was the only kind of required entry a consumer could not decline: its sole caller,
    #     check-roster-sync, runs from a SessionStart hook. And check-roster-sync never actually required
    #     it -- it defaults the roster to CLAUDE.md and runs to completion -- so the [ERROR] was this
    #     table declaring a requirement the reading script does not have. Same shape as 6c below.
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-RosterPath')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'missing Get-RosterPath: exit-code 0 -- an optional entry is not a failure'
    Assert-Match "\[INFO\].*'Get-RosterPath'.*falls back to 'CLAUDE\.md'" $r.Out 'missing Get-RosterPath: INFO naming the default the reading script actually uses'
    $errCount2 = @([regex]::Matches($r.Out, '\[ERROR\]')).Count
    Assert-Equal 0 $errCount2 'missing Get-RosterPath: no error at all'
    # The same for its sibling, and both at once -- the pair is what a scripts-only consumer strips.
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-RosterPath', 'Get-RosterIgnoredIds')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'both roster entries missing: exit-code 0'
    Assert-Match "\[INFO\].*'Get-RosterIgnoredIds'.*falls back to 'no ignored ids'" $r.Out 'missing Get-RosterIgnoredIds: INFO naming its default'
    Assert-Equal 0 @([regex]::Matches($r.Out, '\[ERROR\]')).Count 'both roster entries missing: still no error'
    # And the guard that keeps this from being a blanket downgrade: a genuinely required entry from the
    # same lib still errors. Without this, "optional" could have been applied to the whole file.
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-RepoName')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'missing Get-RepoName: still exit-code 1 -- the downgrade is scoped to the two roster entries'
    Assert-Match "\[ERROR\].*'Get-RepoName' missing" $r.Out 'missing Get-RepoName: still an ERROR'

    # --- 4. Missing lib file entirely: no scripts/repo-config.ps1 at all ---------------------------
    #     All four repo-config functions are unreachable -> one [ERROR] per function, and the check
    #     itself must not crash (branch-info.ps1 stays valid, so its two functions still report OK).
    $c = New-FixtureConsumer -OmitRepoConfig
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'missing repo-config.ps1: exit-code 1'
    Assert-Match "\[ERROR\].*'scripts\\repo-config\.ps1' not found" $r.Out 'missing repo-config.ps1: ERROR names the missing file'
    foreach ($fn in @('Get-RepoName', 'Get-LintScript')) {
        Assert-Match "\[ERROR\].*'$fn'.*cannot be checked" $r.Out "missing repo-config.ps1: '$fn' reported as unreachable"
    }
    # The two roster entries became Optional on August 4, 2026 (inbound #445), so an absent lib no longer
    # errors over them. Asserted in both directions -- present as INFO, absent from the errors -- because
    # "no error" alone would also pass if the check had stopped examining them altogether.
    foreach ($fn in @('Get-RosterPath', 'Get-RosterIgnoredIds')) {
        Assert-NotMatch "\[ERROR\].*'$fn'" $r.Out "missing repo-config.ps1: '$fn' is optional, so not an error"
        Assert-Match "\[INFO\].*'$fn'" $r.Out "missing repo-config.ps1: '$fn' still reported, as an INFO -- examined, not dropped"
    }
    $errCount3 = @([regex]::Matches($r.Out, '\[ERROR\]')).Count
    Assert-Equal 2 $errCount3 'missing repo-config.ps1: exactly two errors (one per MANDATORY repo-config function)'
    # An OPTIONAL repo-config seam is an INFO naming its fallback rather than an ERROR, even when the whole
    # lib is missing. Get-ChangelogHeading (#178) was the subject here until its record retired with the
    # flat changelog; Get-ReleaseHistoryPath now carries the same property and is the better subject for it
    # anyway, being the seam a missing answer would silently mis-file a release row against.
    Assert-Match "\[INFO\].*'Get-ReleaseHistoryPath'.*releases/README\.md" $r.Out 'missing repo-config.ps1: an optional seam is INFO with its fallback named, not ERROR'
    Assert-Match "\[OK\]\s+'Get-BranchInfo' present in" $r.Out 'missing repo-config.ps1: branch-info.ps1 unaffected, still OK'

    # --- 4b. ALL libs absent -> one non-counting [BOOTSTRAP] marker, no per-function errors ---------
    #     Issue #225. When no contract lib exists at all, the repo has not been through
    #     specialists-init -- these files are exactly what its bootstrap puts down. Reporting each
    #     required function then produces errors about files that were never meant to exist yet (6 on a
    #     real fresh consumer), phrased as "this lib predates the contract", which is the wrong story
    #     for a repo that has no lib at all. A missing lib is only drift once the repo is set up.
    $c = New-FixtureConsumer -OmitBranchInfo -OmitRepoConfig
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'all libs absent: exit-code 0 -- an unbootstrapped repo is not a failure'
    Assert-Match '\[BOOTSTRAP\]' $r.Out 'all libs absent: the non-counting marker is emitted'
    Assert-Match 'specialists-init' $r.Out 'all libs absent: the marker names the skill that resolves it'
    Assert-Match 'Nothing is broken' $r.Out 'all libs absent: states plainly that the install is fine'
    Assert-NotMatch '\[ERROR\]' $r.Out 'all libs absent: NOT one error per required function'
    # Both lib names belong in the message -- a reader should not have to guess which files are meant.
    Assert-Match 'branch-info\.ps1' $r.Out 'all libs absent: the marker names branch-info.ps1'
    Assert-Match 'repo-config\.ps1' $r.Out 'all libs absent: the marker names repo-config.ps1'

    # --- 4c. The predicate is strict: ONE lib present means real drift, not an unbootstrapped repo ---
    #     Guard against 4b swallowing case 4. Covered there for repo-config; asserted here from the
    #     other side so neither direction can regress into the bootstrap branch.
    $c = New-FixtureConsumer -OmitBranchInfo
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'one lib present: exit-code 1 -- real drift'
    Assert-Match "\[ERROR\].*'scripts\\lib\\branch-info\.ps1' not found" $r.Out 'one lib present: the missing lib is still an ERROR'
    Assert-NotMatch '\[BOOTSTRAP\]' $r.Out 'one lib present: NOT reported as an unbootstrapped repo'

    # --- 5. Lib throws on load: branch-info.ps1 content that raises on dot-source ------------------
    #     Caught, not a crash -- one [ERROR] per function that lib was supposed to provide, naming the
    #     lib and surfacing the underlying exception message.
    $c = New-FixtureConsumer -BranchInfoContentOverride "throw 'fixture: deliberate load failure'"
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 1 $r.Code 'lib throws: exit-code 1'
    Assert-Match "\[ERROR\].*scripts\\lib\\branch-info\.ps1' failed to load.*deliberate load failure" $r.Out 'lib throws: ERROR names the lib and surfaces the exception message'
    $errCount4 = @([regex]::Matches($r.Out, '\[ERROR\]')).Count
    Assert-Equal 2 $errCount4 'lib throws: exactly two errors (Get-BranchInfo + Test-BranchName, both unreachable)'
    Assert-Match "\[OK\]\s+'Get-RepoName' present in" $r.Out 'lib throws: repo-config.ps1 unaffected, still OK'

    # --- 6. Optional Get-Pr* functions are never flagged -------------------------------------------
    #     The real repo-config.ps1 already has none of the four optional Get-Pr* functions (verified:
    #     the check is against this repo's OWN file) -- proving they are correctly excluded from the
    #     contract, not merely absent from a hand-written fixture that forgot them.
    $c = New-FixtureConsumer
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'optional Get-Pr*: exit-code 0'
    foreach ($optFn in @('Get-PrDescriptionPlaceholder', 'Get-PrApprovalPattern', 'Get-PrAssignee', 'Get-PrMilestone')) {
        Assert-NotMatch $optFn $r.Out "optional Get-Pr*: '$optFn' never mentioned (not in the contract)"
    }
    $okCount6 = @([regex]::Matches($r.Out, '\[OK\]')).Count
    Assert-True ($okCount6 -ge 27) 'optional Get-Pr*: still at least twenty-seven [OK] (the mandatory four + the declared optionals this repo defines + the workflow-folder line; the four UNdeclared Get-Pr* excluded)'

    # --- 6c. An optional contract function that is ABSENT -> [INFO] naming the fallback, exit 0 -----
    #     Get-ReleaseHistoryPath is declared Optional: the shared scripts fall back to 'releases/README.md',
    #     so a consumer that never defined it is NOT drifted. It must still be mentioned -- silence would
    #     leave a repo that keeps its history elsewhere to discover at release time that the row went into a
    #     file it does not use.
    #
    #     THE SUBJECT HAS MOVED TWICE, and both moves were forced the same way: this fixture STRIPS a
    #     function from this repo's real repo-config, so it can only strip one that is there. It was
    #     Get-ChangelogHeading, then Get-ChangelogTierHeadings when the real file stopped defining that, and
    #     now this -- both of those records retired with the flat changelog. Not a weaker test each time:
    #     the subject is always a seam a consumer would actually be missing, and it is the two-caller case,
    #     which is what makes the "used by:" half of the message worth asserting.
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-ReleaseHistoryPath')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'optional absent: exit-code 0 (a fallback exists, so not a breach)'
    Assert-NotMatch '\[ERROR\]' $r.Out 'optional absent: no error'
    # THE FALLBACK TEXT ITSELF CHANGED (issue #885): the literal 'releases/README.md' became the short
    # computed-default description Get-ReleasePluginTier already set the precedent for, since the real
    # default now differs between a source repo and a consumer.
    Assert-Match "\[INFO\].*'Get-ReleaseHistoryPath' missing from scripts\\repo-config\.ps1.*used by: cut-release, new-internal-note.*optional.*falls back to 'releases/README\.md \(source\) or dkj-policy/releases/history\.md \(consumer\), computed'" $r.Out 'optional absent: INFO names the function, both callers and the fallback'

    # --- 6d. Get-LiveStage: absent -> [INFO] naming the empty-string fallback, exit 0 (issue #177) ----
    #     Mirrors test 6c above (Get-ChangelogHeading, issue #178): Get-LiveStage is Optional in the
    #     contract, so a consumer's repo-config.ps1 without it is not drifted -- the cut-release skill's
    #     Block 2 simply never applies (empty default = no separate live stage). Still surfaced, not
    #     silent: a repo that DOES have a live stage needs to learn the getter is missing, or the skill
    #     would silently never print Block 2. Its Default ('') is falsy, so Write-ContractGap's INFO
    #     message uses the "built-in fallback" phrasing rather than naming a quoted default value --
    #     asserted explicitly below (distinct from the "falls back to '...'" phrasing in 6c, whose subject
    #     has a non-empty Default).
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-LiveStage')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'Get-LiveStage absent: exit-code 0 (empty-string fallback, not a breach)'
    Assert-NotMatch '\[ERROR\]' $r.Out 'Get-LiveStage absent: no error'
    Assert-Match "\[INFO\].*'Get-LiveStage' missing from scripts\\repo-config\.ps1.*used by: cut-release skill.*optional; the shared script has a built-in fallback\." $r.Out 'Get-LiveStage absent: INFO names the function, the caller, and the built-in (empty) fallback'
    # Still present -> [OK], not INFO or ERROR (already covered generically by the happy path in test 1;
    # made explicit here too, for direct traceability with the absent-case scenario just above).
    $c2 = New-FixtureConsumer
    $r2 = Invoke-Ps @('-ConsumerPathOverride', $c2)
    Assert-Equal 0 $r2.Code 'Get-LiveStage present: exit-code 0'
    Assert-Match "\[OK\]\s+'Get-LiveStage' present in" $r2.Out 'Get-LiveStage present: reported OK, not INFO or ERROR'

    # --- 6e. The four stub-wording knobs: absent -> four [INFO]s naming their defaults, exit 0 (#410) --
    #     Third instance of the 6c/6d pattern, and the one where "not broken" is most misleading: a
    #     consumer without these gets a perfectly working entry file in the wrong language, every
    #     branch, indefinitely. Nothing crashes, so the [INFO] is the ONLY signal that exists -- which
    #     is precisely the argument for declaring them optional rather than leaving them undeclared.
    #     All four stripped at once, because the failure they guard against is the set being unknown,
    #     not any single one of them.
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-EntryTitlePlaceholder', 'Get-EntryBodyHeading', 'Get-EntryBodyPlaceholder', 'Get-EntryFallbackType')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'stub wording absent: exit-code 0 (every string has a fallback, not a breach)'
    Assert-NotMatch '\[ERROR\]' $r.Out 'stub wording absent: no error'
    # 'used by: open-pr' ALONE since August 7, 2026, and the change is the point rather than a detail. The
    # scaffolder stopped WRITING the placeholders when the dossier form gave every field an empty space
    # under a comment; only open-pr's gate still reads them, to refuse an entry written by an older
    # scaffolder. Declaring new-branch as a caller would announce a dependency it no longer has.
    Assert-Match "\[INFO\].*'Get-EntryTitlePlaceholder' missing from scripts\\repo-config\.ps1.*used by: open-pr.*optional.*falls back to 'TODO: title'" $r.Out 'stub wording absent: INFO for Get-EntryTitlePlaceholder names the gate as its only caller'
    Assert-Match ("\[INFO\].*'Get-EntryBodyHeading' missing.*falls back to '" + [regex]::Escape('**To do / where I left off:**') + "'") $r.Out 'stub wording absent: INFO for Get-EntryBodyHeading quotes the literal default heading'
    Assert-Match "\[INFO\].*'Get-EntryFallbackType' missing.*falls back to 'Chore'" $r.Out 'stub wording absent: INFO for Get-EntryFallbackType names the Chore default'
    $infoCount6e = @([regex]::Matches($r.Out, '\[INFO\]')).Count
    Assert-Equal 16 $infoCount6e 'stub wording absent: exactly sixteen [INFO] lines -- one per stripped knob, plus the six seams this repo deliberately never defines (the two impact-table ones, Get-TestCommands since inbound #644, Get-EntryGateExemptPrefixes since inbound #789 -- this repo runs no mirror branches, so its default IS its answer -- Get-ReleasePageMasthead since inbound #809, this repo having no wordmark, and Get-ResolvesExemptMatchers since inbound #2120, this repo mirroring its issues into no second tracker), the two reachability signals on Get-BranchTypes, and the two of the four optional seams issue #885 added that this repo still leaves undefined (Get-ReleaseChangelogNotesRoot, Get-ReleaseGithubNotesRoot), and nothing else downgraded along with them. Was eight until the flat changelog retired the superseded Get-ChangelogHeading and Get-ChangelogReleaseWording records, then six until inbound #580 added a record whose seam a consumer leaves unreachable, then eight until #644, then nine until #789, then ten until #809, then eleven until #885, and back to nine on August 27, 2026, when this repo stated Get-ChangelogPath and Get-ReleaseInternalNotesRoot to move those documents into contributing-davekjohn/, and one more on September 11, 2026 (#1870) for Get-ReachLabel, whose default is the name this repo''s own reach label already carries. THAT RUNNING COUNT IS THE UNDEFINED-SEAM SUBSET AND NOT THE ASSERTED TOTAL, which is worth saying because the two sit in one sentence and were read as one number: the subset reaches eleven (six original seams + two reachability signals + two of #885''s four + Get-ReachLabel) while the assert counts one [INFO] per stripped knob as well, four of them, hence fifteen. They have never been the same figure; naming them apart is the repair, reconciling them to one would be wrong. SIXTEEN SINCE #2236, SEPTEMBER 21, 2026, and the subset twelve: Get-DeclinedAdoptions joined the undefined seams, and this repo will never answer it -- the adoption section that reads it is SKIPPED in the repo that publishes this workflow, so an answer here would be dead text declining commands that refuse anyway.'

    # --- 6g. Get-TriageLabels: absent -> [INFO] naming its built-in fallback, exit 0 (issue #1895) ---
    #     Mirrors 6c/6d: Optional in the contract, so a consumer's repo-config.ps1 without it is not
    #     drifted -- adopt-triage-labels.ps1 already carries the same canonical triage labels as its own
    #     built-in fallback (see that script's tests for the duality between the two copies).
    $c = New-FixtureConsumer -StripFromRepoConfig @('Get-TriageLabels')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'Get-TriageLabels absent: exit-code 0 (a built-in fallback exists, not a breach)'
    Assert-NotMatch '\[ERROR\]' $r.Out 'Get-TriageLabels absent: no error'
    Assert-Match "\[INFO\].*'Get-TriageLabels' missing from scripts\\repo-config\.ps1.*used by: adopt-triage-labels.*optional.*falls back to 'the same five labels, built into adopt-triage-labels\.ps1 as its own fallback" $r.Out `
        'Get-TriageLabels absent: INFO names the function, the caller, and the built-in-fallback default'
    # Still present -> [OK] (already covered generically by the happy path in test 1; made explicit
    # here too, for direct traceability with the absent-case scenario just above).
    $c2 = New-FixtureConsumer
    $r2 = Invoke-Ps @('-ConsumerPathOverride', $c2)
    Assert-Equal 0 $r2.Code 'Get-TriageLabels present: exit-code 0'
    Assert-Match "\[OK\]\s+'Get-TriageLabels' present in" $r2.Out 'Get-TriageLabels present: reported OK, not INFO or ERROR'

    # --- 6f. NO CONTRACT RECORD MAY SPELL A REPORT MARKER IN ITS OWN TEXT --------------------------
    #     Measured while adding the tier records: a Returns line that mentioned the info marker made the
    #     check print it twice on one finding, so five findings counted as six and three asserts in this
    #     file went red for a reason nothing in them pointed at. The same mistake with the ERROR marker
    #     would be worse than a red test -- the SessionStart hook decides whether to surface a run by
    #     counting those markers, so a repo with nothing wrong would report a blocking signal.
    #
    #     Checked against the record TEXT rather than against the output: the output is where the damage
    #     shows, but the source is where it can be pointed at, and a finding here should name the record to
    #     fix. Fenced code is not a concern -- these are single-quoted PowerShell strings, not prose.
    # Both quote styles: these records use single and double quotes interchangeably, and a pattern that
    # knew only one would report "0 offenders" while never looking at half of them.
    $markerSrc = [System.IO.File]::ReadAllText($ContractLib)
    $recordText = @([regex]::Matches($markerSrc, "(?:Returns|Default)\s*=\s*(['""])(.*?)\1") | ForEach-Object { $_.Groups[2].Value })
    Assert-True ($recordText.Count -gt 20) "the marker guard really read the records (found $($recordText.Count) Returns/Default strings)"
    $withMarker = @($recordText | Where-Object { $_ -cmatch '\[(OK|INFO|ERROR|SCOPE|BOOTSTRAP)\]' })
    Assert-Equal 0 $withMarker.Count "no record's Returns/Default text spells a report marker (offenders: $($withMarker -join ' | '))"

    # --- 6b. Regression guard: legacy pre-strict-mode top-level code must not false-positive --------
    #     Victor's finding (fixed by Sylvester): the check used to dot-source consumer libs under this
    #     script's own `Set-StrictMode -Version Latest`. A repo-config.ps1 that defines every required
    #     function but ALSO carries harmless loose top-level code referencing an unset variable (the
    #     kind of pre-strict-mode code branch-info.ps1/repo-config.ps1 are documented as written on,
    #     and that the real non-strict runtime callers load without error) used to THROW during that
    #     strict-mode dot-source, producing a false [ERROR] for every function in the lib -- even
    #     though nothing is actually missing. The fix dot-sources/probes each consumer lib in a child
    #     scope with `Set-StrictMode -Off`, matching the real runtime. Do NOT delete this scenario when
    #     touching the strict-mode handling again -- it is the guard against that exact regression.
    $legacyRepoConfig = @'
# Fixture repo-config.ps1: a legacy consumer lib that defines all four required functions but also
# has a harmless loose top-level statement referencing an unset variable -- pre-strict-mode code an
# older consumer repo legitimately carries.
if ($LegacyDebugFlag) { Write-Host 'legacy debug mode' }

function Get-RepoName { return 'fixture-repo' }
function Get-LintScript { return 'scripts/lint/check-plugin-integrity.ps1' }
function Get-RosterPath { return 'ROSTER.md' }
function Get-RosterIgnoredIds { return @() }
'@
    $c = New-FixtureConsumer -RepoConfigContentOverride $legacyRepoConfig
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'strict-mode regression: exit-code 0 (loose legacy code must not trip a false failure)'
    Assert-NotMatch '\[ERROR\]' $r.Out 'strict-mode regression: zero [ERROR] lines'
    foreach ($fn in @('Get-BranchInfo', 'Test-BranchName', 'Get-RepoName', 'Get-LintScript', 'Get-RosterPath', 'Get-RosterIgnoredIds')) {
        Assert-Match "\[OK\]\s+'$fn' present in" $r.Out "strict-mode regression: '$fn' still reported OK"
    }
    $okCount6b = @([regex]::Matches($r.Out, '\[OK\]')).Count
    Assert-Equal 8 $okCount6b 'strict-mode regression: exactly eight [OK] lines (all functions detected despite the loose top-level code -- seven since inbound #580 declared Get-BranchTypes, which this fixture''s branch-info.ps1 also defines, plus the workflow-folder line since August 14, 2026)'

    Write-Host "`n== script-contract.tests: contract-completeness drift guard ==" -ForegroundColor Cyan
    # Two-layered defense against the declared $script:Contract array in check-script-contract.ps1
    # silently going stale, chosen over the weaker "just re-type the pairs here" option because
    # that would only catch an accidental REMOVAL and would drift itself the moment a maintainer edits
    # the contract without updating this test:
    #   (a) parse the (Lib, Function, Scripts) records straight out of the check script's OWN
    #       source text (not re-typed here) and assert the exact set/attribution still matches what
    #       issue #147 (and #178, #177) declared -- catches a silent removal or a changed Scripts
    #       attribution.
    #   (b) for every (Function, Scripts) pair found, verify the function is really referenced where
    #       the contract claims it is used -- catches a contract entry going STALE (e.g. a refactor
    #       that stops calling the function while the contract still lists it), which a simple
    #       re-typed-list assertion could never catch.
    #
    # Design decision for Tycho (issue #177): the eighth record, Get-LiveStage, is checked by a
    # SEPARATE, dedicated block right after this loop rather than being folded into $expectedContract.
    # Reason: its Scripts attribution names the cut-release SKILL ('cut-release skill'), not a
    # mirrored shared script -- Get-SharedScriptPairs (the shared-script registry) genuinely does not
    # know it and should not, so the loop's per-script "is this a registered shared script" assertion
    # does not apply to it. Get-LiveStage instead gets its own literal/regex assertion for the record's
    # declaration AND its own staleness check against the real source of the cut-release SKILL.md it is
    # attributed to (the skill-file analogue of the loop's shared-script check) -- see the dedicated
    # block right after the loop. Both records are covered end to end, just by two different, fitting
    # mechanisms. The guard against a FUTURE ninth record silently falling outside coverage is
    # $totalRecordCount below (parsed from the check script's own source): a new record bumps that
    # count and this test goes red until a maintainer adds either a new $expectedContract entry (a real
    # shared script) or a new dedicated block (a skill or other non-mirrored attribution).
    . (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
    # The reachability walk (inbound #580) -- the ViaLib guard below asks it whether a script really
    # reaches the lib its route runs through, instead of matching the file name in the script's text.
    . $ContractLib
    $pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
    $pairsByName = @{}
    foreach ($p in $pairs) { $pairsByName[$p.Name] = $p }

    $expectedContract = @(
        @{ Function = 'Get-BranchInfo';      Lib = 'scripts\lib\branch-info.ps1'; Scripts = @('new-branch', 'open-pr') },
        @{ Function = 'Test-BranchName';      Lib = 'scripts\lib\branch-info.ps1'; Scripts = @('new-branch') },
        # INBOUND #580. The first record for a function nothing calls DIRECTLY -- entry-scaffold-lib probes
        # for it with Get-Command and falls back to the canonical four -- so it carries a ViaLib, and it is
        # the record whose route made that guard transitive: new-internal-note reaches entry-scaffold-lib
        # through release-lib and names it nowhere in its own source.
        @{ Function = 'Get-BranchTypes';      Lib = 'scripts\lib\branch-info.ps1'; Scripts = @('fold-changelog-entry', 'cut-release', 'new-internal-note'); ViaLib = 'entry-scaffold-lib' },
        @{ Function = 'Get-RepoName';         Lib = 'scripts\repo-config.ps1';     Scripts = @('open-pr', 'fold-changelog-entry', 'ship-pr', 'verify-resolved-issues') },
        # TWO CALLERS SINCE AUGUST 5, 2026 (inbound #464). cut-release resolved its gate by a fixed path
        # into the source repo, so a consumer's release ran without a lint gate at all -- and the release
        # route is precisely the one that does NOT pass open-pr's copy of it. Both routes ask this
        # function now, so the attribution has to say so: a record that named one caller while two call it
        # is the staleness this loop exists to catch.
        @{ Function = 'Get-LintScript';       Lib = 'scripts\repo-config.ps1';     Scripts = @('open-pr', 'cut-release') },
        @{ Function = 'Get-RosterPath';       Lib = 'scripts\repo-config.ps1';     Scripts = @('check-roster-sync') },
        @{ Function = 'Get-RosterIgnoredIds'; Lib = 'scripts\repo-config.ps1';     Scripts = @('check-roster-sync') },
        # BOTH CHANGELOG-SECTION SEAMS ARE GONE (August 5, 2026) -- Get-ChangelogTierHeadings and the legacy
        # single Get-ChangelogHeading (#178). They named which '## ' heading a merged entry was filed under,
        # and the changelog has no section headings any more: an entry IS an H3, and the fold and release-lib
        # derive the intro/list boundary from that structurally. Their absence from this list is the point --
        # if either came back, the count assert below would have to change too, which is the conversation
        # that should happen.
        # AND THE SEAM THAT NAMES THE CHANGELOG ITSELF (issue #983, August 27, 2026). It was declared in
        # the lib and absent from THIS table, which is why its Scripts list could go stale in silence:
        # inbound #967 gave it two more readers -- new-branch and open-pr, neither of which touches the
        # file and both of which need the DIRECTORY it names, that being the base an entry's relative
        # links resolve from once the entry folds into it -- and registered them against seam-lib without
        # adding them here or to the record. Nothing went red, because nothing was pinned. This row is the
        # pin, and it is exactly the staleness the Get-LintScript comment above describes: a record that
        # named two callers while four call them.
        @{ Function = 'Get-ChangelogPath';    Lib = 'scripts\repo-config.ps1';     Scripts = @('cut-release', 'fold-changelog-entry', 'new-branch', 'open-pr') },
        # The four stub-wording knobs (issue #410). These DO belong in this loop, unlike Get-LiveStage:
        # they are attributed to 'new-branch', a genuinely registered shared script, so the
        # per-script assertions below apply to them unchanged.
        # THREE OF THE FOUR ARE NOW open-pr's ALONE. They were the writer's placeholders and gained the
        # gate as a second reader; then the dossier form stopped WRITING them altogether -- every field is
        # a heading with an empty space under it, and the gate measures emptiness instead of matching
        # prose. What survives is refusal: an entry written by an older scaffolder still carries this
        # wording, here and in every consumer, and open-pr still has to recognise it.
        #
        # ATTRIBUTED TO THE GATE ONLY, deliberately. Leaving 'new-branch' in the list would promise a
        # dependency it does not have, and this loop's per-script assertion would then demand that the
        # writer reference a knob it never reads -- a contract asserting a fiction.
        @{ Function = 'Get-EntryTitlePlaceholder'; Lib = 'scripts\repo-config.ps1'; Scripts = @('open-pr'); ViaLib = 'entry-scaffold-lib' },
        @{ Function = 'Get-EntryBodyHeading';      Lib = 'scripts\repo-config.ps1'; Scripts = @('open-pr'); ViaLib = 'entry-scaffold-lib' },
        @{ Function = 'Get-EntryBodyPlaceholder';  Lib = 'scripts\repo-config.ps1'; Scripts = @('open-pr'); ViaLib = 'entry-scaffold-lib' },
        # The fourth stays single-reader on purpose: a changelog TYPE is not scaffold prose, so 'Chore' is a
        # legitimate final value and can never be evidence of an unedited entry.
        @{ Function = 'Get-EntryFallbackType';     Lib = 'scripts\repo-config.ps1'; Scripts = @('new-branch') },
        # The two knobs the newly mirrored scripts brought with them (issues #411 and #413). Both belong
        # in this loop for the same reason the Get-Entry* four do: they are attributed to real registered
        # shared scripts, so the per-script assertions below apply unchanged -- and those assertions are
        # exactly what would have caught the mirror being forgotten.
        @{ Function = 'Get-PrMergeMethod';         Lib = 'scripts\repo-config.ps1'; Scripts = @('ship-pr') },
        @{ Function = 'Get-MojibakePaths';         Lib = 'scripts\repo-config.ps1'; Scripts = @('fix-mojibake') },
        # The eight cut-release knobs (issue #417): five from phase 1, then the three the consumer tier
        # tier brought in phase 2. Same reasoning again: all attributed to 'cut-release', a registered
        # shared script, so the per-script assertions below cover them -- and those assertions are what
        # would catch the mirror or the seam being forgotten. The last of them is load-bearing for the
        # cut-release must really reference each of these, which is what separates a ported feature from a
        # knob nothing reads.
        @{ Function = 'Get-ReservedRootMd';        Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') },
        @{ Function = 'Get-ReleaseNotesGrouping';  Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') },
        @{ Function = 'Get-ReleasePluginTier';     Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') },
        # THREE MORE OF THE #417 KNOBS RETIRED WITH THE FLAT CHANGELOG (August 5, 2026), and all three for
        # one reason rather than three: Get-ReleaseLiveMarker marked the live row of a release section the
        # changelog no longer has, Get-ReleaseHistoryMode chose whether that section accumulated, and
        # Get-ReleaseCategoryTitles labelled category headings the release documents no longer have.
        # Get-ReleaseHistoryPath is the survivor and gained a second caller, below.
        @{ Function = 'Get-ReleaseHistoryPath';    Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release', 'new-internal-note') },
        @{ Function = 'Get-ReleaseConsumerBumps';            Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') },
        # WHERE that document goes, beside the knob saying WHETHER it is written (inbound #616). Two
        # scripts, and the pair is the point: the cut writes the note, build-release-notes-page reads the
        # newest one back. A seam reaching only the writer would have a repointed root written to and looked
        # for in two different places, reported as "no release note was found". The reading half was
        # session-status until #957 removed it with /lock and /handover -- a change of identity, not of shape.
        @{ Function = 'Get-ReleaseNoteRoot';                 Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release', 'build-release-notes-page') },
        # The two knobs that configured the retired remove-before-publishing marker are gone with it
        # (August 5, 2026): the consumer document is the tier-2 entries now, so there is nothing to
        # promote and nothing to label. Their absence from this list is the point -- if they came back,
        # the count assert below would have to change too, which is the conversation that should happen.
        @{ Function = 'Get-ReleaseMajorMinMinors';              Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') },
        # The third tier (August 3, 2026), attributed to its own script rather than to cut-release: the
        # internal note is generated AFTER the cut, because the development notes are its input.
        # Get-ReleaseNoteWording is the name cut-release reads FIRST; Get-InternalNoteWording is the
        # fallback and belongs to new-internal-note. Both declared, because the two maps have different key
        # sets and serve different documents -- inbound #605, where being undeclared meant a consumer was
        # served by the retired name and could never find out the canonical one had changed.
        @{ Function = 'Get-ReleaseNoteWording';                Lib = 'scripts\repo-config.ps1'; Scripts = @('cut-release') }
        @{ Function = 'Get-InternalNoteWording';               Lib = 'scripts\repo-config.ps1'; Scripts = @('new-internal-note') }
        # THE TRIAGE-PRIORITY LABELS (issue #1895, split from #1843, September 12, 2026). The neighbouring
        # axis to Get-ReachLabel, one row up in script-contract-lib.ps1 -- but unlike that record, this one
        # DOES belong in this loop: 'adopt-triage-labels' is a real registered shared script (unlike
        # 'report-issue skill'/'adopt-dkj-policy skill', which is why Get-ReachLabel gets no entry here at
        # all), so the per-script assertions below apply to it unchanged.
        @{ Function = 'Get-TriageLabels';                      Lib = 'scripts\repo-config.ps1'; Scripts = @('adopt-triage-labels') }
        # THE REPO-SETTINGS DECLARATION (issue #1843, September 13, 2026), read by the now-shared
        # check-repo-settings.ps1 -- a real registered shared script, so it belongs in this loop exactly
        # as Get-TriageLabels does above.
        @{ Function = 'Get-ExpectedRepoSettings';              Lib = 'scripts\repo-config.ps1'; Scripts = @('check-repo-settings') }
        # Get-ChangelogReleaseWording (inbound #462) USED TO BE THE LAST RECORD HERE, and the only one read
        # by two release scripts: the cut wrote the release block's intro and notes line, the internal note
        # rewrote that same line once it existed. There is no release block, so there is no paragraph for
        # either to write. Get-ReleaseHistoryPath above has inherited both the two-caller shape and the
        # per-script assertions that shape is what tests.
    )

    $contractSrc = [System.IO.File]::ReadAllText($ContractLib)
    $totalRecordCount = @([regex]::Matches($contractSrc, "Lib\s*=\s*'[^']+';\s*Function\s*=\s*'[^']+';\s*Scripts\s*=\s*@\(")).Count
    Assert-Equal 44 $totalRecordCount 'contract: exactly forty-four (lib, function) records are declared in script-contract-lib.ps1 -- EVERY record the regex above matches, Get-LiveStage''s included. EXACT RATHER THAN A FLOOR SINCE ISSUE #999 (August 27, 2026), and the floor is why that issue exists: this read `-ge 29` against an actual 36, so seven records could have been deleted without a word, while the comments in the table below promise that a retired record `would have to change the count assert too, which is the conversation that should happen`. A floor cannot force that conversation in either direction; an equality does. Change this number in the same commit that adds or retires a record, and say which in the branch entry. IT COUNTS THE LIB, NOT THE TABLE -- the two are different sets and the old message conflated them: the `$expectedContract` table below pins 25 of these by name and Get-LiveStage gets its own assert after the loop, so the test file names 26 of the 43 and the rest are covered by the Returns assert alone -- that inner figure said 36 against a real 37 before September 11, 2026, having been left behind by an earlier record, and is corrected here rather than drifted one further. Was twenty-eight until the flat changelog retired six: both section seams, the live marker, the history mode, the category labels and the release-block wording; Get-BranchTypes joined on August 10, 2026 (inbound #580), Get-ReleaseNoteWording on August 11 (inbound #605), Get-ReleaseNoteRoot on August 12 (inbound #616), Get-ReleaseAudienceTier the same day (inbound #620, one audience tier per repo), Get-TestCommands on August 13 (inbound #644, the test gate runs the repo''s own test commands), and Get-ReleasePageTitle + Get-ReleasePageWorkerName on August 15 (the release-notes page and the worker that hosts it), and Get-CiTestCheckName on September 9, 2026 (#1715, the check whose green lets open-pr skip its local test gate -- NAMED rather than inferred, because two reviews found that trusting any required check certifies on a CLA bot''s green, and on a neighbour check that went green while the test check had not registered at all), Get-ReachLabel on September 11, 2026 (#1870, the name a tracker stores for the reach label -- the one issue label this workflow prescribes), Get-TriageLabels on September 12, 2026 (#1895, the neighbouring priority axis, print-only and shared across ordinary dkj-policy consumers), and Get-ExpectedRepoSettings on September 13, 2026 (#1843, the repo-settings declaration check-repo-settings.ps1 reads, now that the check itself is a shared script rather than repo-local), and Get-AlwaysOnBudget on September 16, 2026 (#2037, the ceiling in bytes on the always-on document path -- the one seam here whose VALUE Dave asked to hold in every consumer rather than in the repo that ships it, which is why it is ''copy'' and not ''decide''), and Get-CloseOutGateBand on September 17, 2026 (#2050, the band a close-out may not exceed before the closeout-gate Stop hook refuses the turn -- the clearest ''decide'' in the table and for a reason no other record has: every other ''decide'' is about a FACT only the consumer can state, while this one is about CONSENT, since answering it arms a hook that refuses to let a turn end), and Get-ResolvesExemptMatchers on September 18, 2026 (inbound #2120, the matchers that name the class of issue a merge must NOT close -- the first record whose absence buys a consumer a gh call they never make, since the seam is asked before any lookup and answers empty by default), and Get-DeclinedAdoptions on September 21, 2026 (#2236, the adopt-* commands a repo has deliberately not run -- the one record in the table whose whole purpose is to SILENCE a report, which is why it is the consumer''s own declaration rather than an exemption list kept here)'

    # Every record must carry a 'Returns' line, so a finding is actionable without any reference to this
    # source repo (Dave, July 28, 2026). Counted against $totalRecordCount rather than listed per record:
    # a ninth record added without a Returns then turns this red, which is exactly the drift to catch --
    # Get-RecordReturns degrades silently to the shorter message, so nothing else would notice.
    $returnsCount = @([regex]::Matches($contractSrc, "(?m)^\s*Returns\s*=\s*")).Count
    Assert-Equal $totalRecordCount $returnsCount 'contract: every declared record carries a Returns line (a finding must be actionable without the source repo)'

    foreach ($e in $expectedContract) {
        # Pitfall for whoever adds a record 9 here: this capture -- @\(([^)]*)\) -- stops at the FIRST
        # ')' it meets, so a Scripts value carrying its own parenthesis (e.g. 'foo (bar)') gets truncated
        # before the record's real closing paren. Keep every Scripts entry parenthesis-free; a record
        # attributed to something that needs a parenthetical name is a sign it does not belong in this
        # loop at all (see the design-decision comment above for Get-LiveStage, whose own dedicated
        # block below sidesteps this capture entirely).
        $pattern = "Lib\s*=\s*'([^']+)';\s*Function\s*=\s*'" + [regex]::Escape($e.Function) + "';\s*Scripts\s*=\s*@\(([^)]*)\)"
        $m = [regex]::Match($contractSrc, $pattern)
        Assert-True $m.Success "contract: record for '$($e.Function)' still declared"
        if ($m.Success) {
            Assert-Equal $e.Lib $m.Groups[1].Value "contract: '$($e.Function)' still attributed to $($e.Lib)"
            $actualScripts = @($m.Groups[2].Value -split ',' | ForEach-Object { $_.Trim().Trim("'") } | Where-Object { $_ })
            $expectedSorted = ($e.Scripts | Sort-Object) -join ','
            $actualSorted   = ($actualScripts | Sort-Object) -join ','
            Assert-Equal $expectedSorted $actualSorted "contract: '$($e.Function)' still required by exactly {$($e.Scripts -join ', ')}"

            # A record may reach its function INDIRECTLY, through a shared library both callers dot-source
            # (ViaLib). Then the proof is two-part and stricter than the direct match: the script must
            # really dot-source that lib, and the lib must really name the function. The direct form was
            # satisfiable by a mention in a docstring; this one is not, because a dot-source line is code.
            #
            # THE FIRST HALF IS THE REAL WALK SINCE INBOUND #580, and it had to become one for a route this
            # tree already contains: new-internal-note reaches entry-scaffold-lib THROUGH release-lib, two
            # hops, and names it nowhere in its own source. The text match this replaces would have called
            # that a stale record. It also had the failure it was written to avoid, one level up -- a
            # dot-source line is code, but a COMMENT naming the same file is not, and $srcText could not
            # tell them apart. Test-ContractLibReachable reads the AST and follows the chain.
            $viaLib = if ($e.ContainsKey('ViaLib')) { $e.ViaLib } else { $null }
            if ($viaLib) {
                Assert-True $pairsByName.ContainsKey($viaLib) "contract: '$viaLib' is a registered shared lib (Get-SharedScriptPairs)"
            }
            foreach ($scriptName in $actualScripts) {
                Assert-True $pairsByName.ContainsKey($scriptName) "contract: '$scriptName' is a registered shared script (Get-SharedScriptPairs)"
                if ($pairsByName.ContainsKey($scriptName)) {
                    $srcText = [System.IO.File]::ReadAllText($pairsByName[$scriptName].SourcePath)
                    if ($viaLib -and $pairsByName.ContainsKey($viaLib)) {
                        $libLeaf = Split-Path $pairsByName[$viaLib].SourcePath -Leaf
                        $viaRel = $pairsByName[$viaLib].SourceRel
                        Assert-True (Test-ContractLibReachable -ScriptPath $pairsByName[$scriptName].SourcePath -RepoRoot $RepoRoot -LibRelPath $viaRel) `
                            "contract: shared script '$scriptName' really reaches '$libLeaf' (the route to '$($e.Function)'), directly or through a lib it loads"
                        $libText = [System.IO.File]::ReadAllText($pairsByName[$viaLib].SourcePath)
                        Assert-True ($libText -match [regex]::Escape($e.Function)) "contract: shared lib '$libLeaf' really references '$($e.Function)' (not a stale entry)"
                    } else {
                        Assert-True ($srcText -match [regex]::Escape($e.Function)) "contract: shared script '$scriptName' really references '$($e.Function)' in its own real source (not a stale entry)"
                    }
                }
            }
        }
    }

    # --- Get-LiveStage (record 8, issue #177): its own dedicated check -- see the design-decision -----
    #     comment above this loop for why it is not folded into $expectedContract. Verified by hand
    #     (scratch script, not checked in) before writing this pattern: it correctly matches the real
    #     record and correctly fails to match if the Lib/Scripts/Optional/Default attribution changes.
    #     THE GAP BEFORE 'Optional' IS DELIBERATE, and bounded so it cannot wander into the next record:
    #     records gained Adopt/AdoptWhy on August 8, 2026 (#456), which sit between Scripts and Optional.
    #     A '\s*' here would report a correct record as missing the moment any key is added between the
    #     two -- the assert would be testing the key ORDER, which is not what it is for. '(?!Lib\s*=)'
    #     keeps the gap inside one record, so the attribution being tested is still this record's.
    $liveStagePattern = 'Lib\s*=\s*''scripts\\repo-config\.ps1'';\s*Function\s*=\s*''Get-LiveStage'';\s*Scripts\s*=\s*@\(''cut-release skill''\);(?:(?!Lib\s*=)[\s\S])*?Optional\s*=\s*\$true;\s*Default\s*=\s*'''''
    Assert-True ([regex]::IsMatch($contractSrc, $liveStagePattern)) "contract: record for 'Get-LiveStage' still declared, attributed to scripts\repo-config.ps1 / 'cut-release skill', Optional with an empty-string Default"

    $cutReleaseSkillPath = Join-Path $RepoRoot 'plugins\dkj-policy\skills\cut-release\SKILL.md'
    Assert-True (Test-Path -LiteralPath $cutReleaseSkillPath) 'contract: cut-release SKILL.md exists at the path the Get-LiveStage record is attributed to'
    if (Test-Path -LiteralPath $cutReleaseSkillPath) {
        $skillText = [System.IO.File]::ReadAllText($cutReleaseSkillPath)
        Assert-True ($skillText -match 'Get-LiveStage') "contract: cut-release SKILL.md really references 'Get-LiveStage' in its own real source (not a stale entry)"
    }

    Write-Host "`n== script-contract.tests: reachability (inbound #580) ==" -ForegroundColor Cyan
    # A record claims a shared script CALLS a repo-owned function. Presence was checked; whether the lib
    # is ever in scope for that script was not, so a declared-and-present function could be answered by
    # the built-in fallback with the check reporting [OK]. These asserts pin the walk that closes it.
    #
    # THE SHAPES ARE ASSERTED INDIVIDUALLY because each one is a way a real script in this tree writes a
    # dot-source, and a walk that handles three of the four is not partially right -- it is wrong on
    # whichever scripts use the fourth. The measurement that produced this list found exactly that: an
    # AST walk reading literals and named variables missed the child-scope idiom and reported three
    # findings, all three false.
    $shapes = @(
        @{ Script = 'scripts\task\new-branch.ps1';          Lib = 'scripts\lib\branch-info.ps1'; Shape = 'a named variable built from $repoRoot' },
        @{ Script = 'scripts\release\cut-release.ps1';       Lib = 'scripts\lib\branch-info.ps1'; Shape = 'a literal Join-Path in the dot-source itself' },
        @{ Script = 'scripts\sync\check-roster-sync.ps1';    Lib = 'scripts\repo-config.ps1';     Shape = 'the "& { . $args[0] }" child-scope idiom' },
        @{ Script = 'scripts\maintenance\fix-mojibake.ps1';  Lib = 'scripts\repo-config.ps1';     Shape = 'the child-scope idiom inside a function' },
        @{ Script = 'scripts\lib\release-lib.ps1';           Lib = 'scripts\lib\branch-info.ps1'; Shape = 'a guarded $PSScriptRoot sibling' }
    )
    foreach ($s in $shapes) {
        Assert-True (Test-ContractLibReachable -ScriptPath (Join-Path $RepoRoot $s.Script) -RepoRoot $RepoRoot -LibRelPath $s.Lib) `
            "reachability: '$(Split-Path $s.Script -Leaf)' reaches '$(Split-Path $s.Lib -Leaf)' -- $($s.Shape)"
    }

    # NAMING A LIB IS NOT LOADING IT, and this is the assert that separates the built rule from the
    # cheapest candidate. fold-changelog-entry.ps1 mentions branch-info.ps1 in a comment about branch
    # names; a text match reads that as a dot-source and reports the reported defect as green.
    $foldPath = Join-Path $RepoRoot 'scripts\release\fold-changelog-entry.ps1'
    Assert-True ([System.IO.File]::ReadAllText($foldPath) -match 'branch-info\.ps1') `
        'reachability: fold-changelog-entry.ps1 does mention branch-info.ps1 in its text (the premise of the next assert)'
    Assert-True (-not (Test-ContractLibReachable -ScriptPath $foldPath -RepoRoot $RepoRoot -LibRelPath 'scripts\lib\branch-info.ps1')) `
        'reachability: ...and still does not REACH it -- a comment is not a dot-source (the text-match candidate failed here)'

    # Transitive, which is not a nicety: this exact route is in the tree today and the ViaLib guard above
    # depends on it. new-internal-note names entry-scaffold-lib nowhere in its own source.
    $noteText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\new-internal-note.ps1'))
    Assert-True (-not ($noteText -match 'entry-scaffold-lib')) `
        'reachability: new-internal-note.ps1 names entry-scaffold-lib nowhere in its own source (the premise of the next assert)'
    Assert-True (Test-ContractLibReachable -ScriptPath (Join-Path $RepoRoot 'scripts\release\new-internal-note.ps1') -RepoRoot $RepoRoot -LibRelPath 'scripts\lib\entry-scaffold-lib.ps1') `
        'reachability: ...and still reaches it, through release-lib.ps1 -- the walk follows the chain'

    # A NAME THAT RESOLVES TO NO SCRIPT MAKES NO CLAIM. check-roster-sync ships in the OTHER plugin and
    # 'cut-release skill' is not a script at all, so from the workflow mirror both resolve to nothing --
    # and a file this check cannot find is not evidence that a lib goes unloaded. Guessing here would put
    # false findings in every consumer's session, which is how a check gets ignored rather than heeded.
    Assert-Equal '' (Resolve-SharedScriptPath -Name 'cut-release skill' -ScriptsRoot (Join-Path $RepoRoot 'scripts')) `
        "reachability: 'cut-release skill' resolves to no script, so no reachability claim is made about it"
    Assert-Equal '' (Resolve-SharedScriptPath -Name 'no-such-script-anywhere' -ScriptsRoot (Join-Path $RepoRoot 'scripts')) `
        'reachability: an unknown script name resolves to nothing rather than throwing'

    # --- The consumer-facing half: the reported defect, and the repair that closes it ---------------
    # This is inbound #580 end to end. The fixture consumer has Get-BranchTypes present and its
    # repo-config does not chain branch-info.ps1, which is the state the reporting consumer was in and
    # the state this workshop is in. Chaining the lib -- their repair -- must turn the finding green,
    # because a check nobody can satisfy teaches nothing.
    $c = New-FixtureConsumer
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'reachability: an unreachable seam is never an error -- the caller falls back by design'
    Assert-Match "\[OK\]\s+'Get-BranchTypes' present in" $r.Out 'reachability: the presence half still reports OK'
    Assert-Match "NOT IN SCOPE for 'fold-changelog-entry'" $r.Out 'reachability: ...and the reachability half names the script that cannot see it'
    Assert-Match 'REFUSES the fold' $r.Out 'reachability: the finding states what the fallback COSTS, not merely that there is one'

    # -SkipReachability, which the SessionStart hook passes. The walk adds ~1,470 ms to a ~510 ms check
    # and the hook filters its output to [ERROR]/[SCOPE], so an always-[INFO] finding could never reach
    # the session context anyway. Asserted rather than trusted: the switch must drop the reachability
    # half and NOTHING else, or a session start would quietly stop reporting real contract gaps.
    $r = Invoke-Ps @('-ConsumerPathOverride', $c, '-SkipReachability')
    Assert-Equal 0 $r.Code 'skip-reachability: exit-code 0'
    Assert-NotMatch 'NOT IN SCOPE' $r.Out 'skip-reachability: no reachability findings are produced'
    Assert-Match "\[OK\]\s+'Get-BranchTypes' present in" $r.Out 'skip-reachability: the presence half is untouched'
    Assert-Match 'Summary: 0 error\(s\), 10 info signal\(s\)' $r.Out 'skip-reachability: only the deliberately-undefined seams remain (six original, plus the two of the four issue #885 added that this repo still leaves undefined, plus Get-ReachLabel since #1870 and Get-DeclinedAdoptions since #2236) -- the switch drops the reachability half and nothing else'

    $fixtureConfig = Join-Path $c 'scripts\repo-config.ps1'
    [System.IO.File]::AppendAllText($fixtureConfig, "`r`n. (Join-Path `$PSScriptRoot 'lib\branch-info.ps1')`r`n")
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'reachability: exit code still 0 after the repair'
    Assert-NotMatch "NOT IN SCOPE for 'fold-changelog-entry'" $r.Out 'reachability: chaining branch-info from repo-config closes the finding -- the consumer repair really works'
    Assert-Match "\[OK\]\s+'Get-BranchTypes' present in" $r.Out 'reachability: and the record is still reported present'

    Write-Host "`n== script-contract.tests: script-contract-sessioncheck.ps1 (hook) ==" -ForegroundColor Cyan

    # --- 7. Clean repo -> "in sync" line, exit 0, no [ERROR] surfaced ------------------------------
    $c = New-FixtureConsumer
    $r = Invoke-Hook @('-CheckScriptOverride', $Script, '-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'hook clean: exit 0'
    Assert-Match 'script contract in sync' $r.Out 'hook clean: in-sync message'
    Assert-NotMatch '\[ERROR\]' $r.Out 'hook clean: no [ERROR] surfaced'
    Assert-NotMatch 'drift found' $r.Out 'hook clean: no drift summary'

    # --- 8. Drifted repo (missing Test-BranchName) -> [ERROR] surfaced, exit 0 (hook always exits 0) --
    $c = New-FixtureConsumer -StripFromBranchInfo @('Test-BranchName')
    $r = Invoke-Hook @('-CheckScriptOverride', $Script, '-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'hook drifted: exit 0 (never blocks the session)'
    Assert-Match 'script-contract drift found' $r.Out 'hook drifted: drift summary shown'
    Assert-Match "\[ERROR\].*Test-BranchName" $r.Out 'hook drifted: the [ERROR] line is surfaced verbatim'
    # The end-to-end version of inbound #203, against the REAL check rather than a stub: a finding that
    # reaches the session must arrive with the repo it is about. The 2026-07-27 incident was exactly
    # this line going missing -- a true Test-BranchName finding, read as being about the wrong repo.
    Assert-Match '\[SCOPE\].*check-script-contract inspected' $r.Out 'hook drifted: the [SCOPE] line survives the [ERROR] filter'
    Assert-Match ([regex]::Escape($c)) $r.Out 'hook drifted: the surfaced scope is the fixture root the check really inspected'
    Assert-NotMatch 'may be partial' $r.Out 'hook drifted: a complete real check run is not flagged as partial'
    # [OK] lines must still stay out: widening the filter for [SCOPE] must not have widened it further.
    Assert-NotMatch '\[OK\]' $r.Out 'hook drifted: [OK] lines still stay out of the session context'

    # --- 9. Check script not found (-CheckScriptOverride to a nonexistent path) --------------------
    $missing = Join-Path $Fixture 'does-not-exist.ps1'
    $r = Invoke-Hook @('-CheckScriptOverride', $missing)
    Assert-Equal 0 $r.Code 'hook missing check script: exit 0'
    Assert-Match 'not found -- check skipped' $r.Out 'hook missing check script: notice'

    # --- 10. Get-ScriptDotSourceTargets' memo is keyed on the FILE, not the path (issue #1693) ----
    #
    # THE ASSERT LIVES HERE BECAUSE THIS IS THE LIB THAT OWNS THE MEMO. It was keyed on
    # "$Path|$RepoRoot", which is correct for this suite's own caller -- a SessionStart check reading
    # repo files nothing rewrites mid-run -- and wrong for any caller that writes a file, reads it,
    # rewrites it and reads again. fixture-dep-lib.ps1 became exactly that caller when it stopped
    # carrying a second AST walker of its own, and on the path-only key two of its asserts went red on
    # a stale answer, reading as a bug in the walk rather than in the cache.
    #
    # Asserted from the shared lib's side as well as from that caller's, because whoever edits this
    # memo next reads this file, and an assert two libs away is one nobody will find.
    $memoDir = Join-Path $Fixture 'memo'
    New-Item -ItemType Directory -Path (Join-Path $memoDir 'scripts\lib') -Force | Out-Null
    $memoLib = Join-Path $memoDir 'scripts\lib\memo-probe-lib.ps1'
    $memoDep = Join-Path $memoDir 'scripts\lib\memo-dep-lib.ps1'
    [System.IO.File]::WriteAllText($memoDep, "function Get-MemoDep { 'dep' }`n")
    [System.IO.File]::WriteAllText($memoLib, @'
$memoProbeDep = Join-Path $PSScriptRoot 'memo-dep-lib.ps1'
if (Test-Path -LiteralPath $memoProbeDep -PathType Leaf) { . $memoProbeDep }
'@)
    $firstRead = @(Get-ScriptDotSourceTargets -Path $memoLib -RepoRoot $memoDir)
    Assert-Equal 1 $firstRead.Count 'memo key: the first read finds the dot-sourced sibling'

    # A different last-write tick is what the key must notice; the sleep is what guarantees one.
    Start-Sleep -Milliseconds 20
    [System.IO.File]::WriteAllText($memoLib, "function Get-MemoProbe { 'nothing dot-sourced now' }`n")
    $secondRead = @(Get-ScriptDotSourceTargets -Path $memoLib -RepoRoot $memoDir)
    Assert-Equal 0 $secondRead.Count 'memo key: a rewrite at the SAME path is read again rather than served from the memo'

    # --- 11. -UnconditionalOnly: the dot-sources that run AT LOAD (issue #1924) -------------------
    #
    # ASSERTED HERE FOR THE SAME REASON AS THE MEMO ABOVE: the switch lives in this lib, it travels to
    # every consumer in the mirror, and an assert two libs away in the caller that asked for it is one
    # nobody editing this walk will find. The caller's own suite (fixture-lib-deps.tests.ps1) proves what
    # the narrower answer is FOR; this proves what it IS.
    #
    # THE DEFAULT MUST NOT MOVE. This function's standing question is "is this lib in scope at runtime",
    # for which a guarded or in-function dot-source counts -- check-script-contract.ps1 runs from a
    # SessionStart hook on that answer, so the switch being additive is the whole safety of it.
    $uncondDir = Join-Path $Fixture 'uncond'
    New-Item -ItemType Directory -Path (Join-Path $uncondDir 'scripts\lib') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $uncondDir 'scripts\task') -Force | Out-Null
    foreach ($n in @('top-lib', 'guarded-lib', 'infunc-lib', 'inloop-lib', 'inblock-lib', 'blockinif-lib')) {
        [System.IO.File]::WriteAllText((Join-Path $uncondDir "scripts\lib\$n.ps1"), "function Get-$n { }`n")
    }
    $uncondScript = Join-Path $uncondDir 'scripts\task\uncond-probe.ps1'
    [System.IO.File]::WriteAllText($uncondScript, @'
. (Join-Path $PSScriptRoot '..\lib\top-lib.ps1')
$guarded = Join-Path $PSScriptRoot '..\lib\guarded-lib.ps1'
if (Test-Path -LiteralPath $guarded -PathType Leaf) { . $guarded }
function Invoke-Later {
    . (Join-Path $PSScriptRoot '..\lib\infunc-lib.ps1')
}
foreach ($i in 1..2) {
    . (Join-Path $PSScriptRoot '..\lib\inloop-lib.ps1')
}
$scoped = & {
    . (Join-Path $PSScriptRoot '..\lib\inblock-lib.ps1')
    'value'
}
if ($scoped -eq 'never') {
    $null = & {
        . (Join-Path $PSScriptRoot '..\lib\blockinif-lib.ps1')
    }
}
'@)
    $allSix = @(Get-ScriptDotSourceTargets -Path $uncondScript -RepoRoot $uncondDir |
                    ForEach-Object { Split-Path -Leaf $_ } | Sort-Object)
    Assert-Equal 'blockinif-lib.ps1,guarded-lib.ps1,inblock-lib.ps1,infunc-lib.ps1,inloop-lib.ps1,top-lib.ps1' `
        ($allSix -join ',') 'unconditional: the default answer is unchanged -- all six shapes are dot-sources'

    $loadOnly = @(Get-ScriptDotSourceTargets -Path $uncondScript -RepoRoot $uncondDir -UnconditionalOnly |
                    ForEach-Object { Split-Path -Leaf $_ } | Sort-Object)

    # THE IMMEDIATELY-INVOKED BLOCK IS LOAD-TIME, and this assert exists because the first version got it
    # wrong. A script block is normally NOT load-time -- its statements run when something calls it -- so
    # the type was in the conditional list outright, and `& { ... }` fell through the gap. That idiom is in
    # this tree on purpose: check-plugin-integrity.ps1 resolves its changelog seam that way at top level,
    # with an unguarded `. seam-lib.ps1` inside, and the hand-written comment above it describes the exact
    # fixture failure this gate is meant to catch. Found by the code review on this branch.
    Assert-Equal 'inblock-lib.ps1,top-lib.ps1' ($loadOnly -join ',') `
        'unconditional: the top-level one AND an immediately-invoked `& { }` -- guard, function and loop drop out'

    # And the exception does not swallow the rule: the SAME idiom inside an `if` is still conditional,
    # because the block is stepped through and the invocation's own ancestry decides. That shape is in the
    # same real file, one check further down.
    Assert-True ($loadOnly -notcontains 'blockinif-lib.ps1') `
        'unconditional: an `& { }` inside an if stays conditional -- the block is stepped through, not stopped at'

    # AND THE MEMO MUST TELL THE TWO QUESTIONS APART. Both calls above read the same file at the same
    # timestamp, so on a key that did not carry the mode the second would have been served the first's
    # answer -- silently, and to the caller that asked for the other one. Asserted by asking in the
    # REVERSE order, which is the order that was never exercised above.
    $reverseLoadOnly = @(Get-ScriptDotSourceTargets -Path $uncondScript -RepoRoot $uncondDir -UnconditionalOnly)
    $reverseAll = @(Get-ScriptDotSourceTargets -Path $uncondScript -RepoRoot $uncondDir)
    Assert-Equal 2 $reverseLoadOnly.Count 'unconditional: the memo carries the mode -- the narrow answer stays narrow'
    Assert-Equal 6 $reverseAll.Count 'unconditional: and the wide answer stays wide, at the same timestamp'

    # --- 12. The adoption inventory: which adopt-* commands' files this tree is missing (#2236) -----
    #
    # WHAT THESE COVER THAT NOTHING ELSE COULD. The gap reported from a consumer was not that a check
    # was wrong but that no check existed: every adopt-* command is safe to re-run and correctly finds
    # nothing to do, so an already-adopted consumer was never told one of them had gained a file. The
    # scenarios below pin the four states apart, because a report that cannot tell "never run" from "run
    # and since grown" writes the wrong sentence in the case the whole thing exists for.
    #
    # THE FILES ARE EMPTY, on purpose: the inventory answers on PRESENCE, exactly like the
    # workflow-folder line, so a fixture that wrote plausible YAML would be testing something the
    # product does not read.
    . $ContractLib

    # --- 12a. Nothing adopted -> one [UNADOPTED] per command, and it counts toward NOTHING ----------
    $c = New-FixtureConsumer
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'adoption absent: exit-code 0 -- an unbuilt floor is a to-do, not a breach'
    Assert-Equal 0 @([regex]::Matches($r.Out, '\[ERROR\]')).Count 'adoption absent: no [ERROR] at all'
    $unad = @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count
    Assert-Equal 3 $unad 'adoption absent: one [UNADOPTED] per inventory record, and no more'
    foreach ($cmd in @('adopt-workflow-folder', 'adopt-ci-floor', 'adopt-statusline')) {
        Assert-Match "\[UNADOPTED\] $cmd " $r.Out "adoption absent: '$cmd' is named"
    }
    Assert-Match '\[UNADOPTED\].*has none of them' $r.Out 'adoption absent: the line says the tree has none of that command''s files'
    Assert-Match "\[UNADOPTED\].*name 'adopt-ci-floor' in Get-DeclinedAdoptions" $r.Out `
        'adoption absent: the line hands over the opt-out seam -- an advisory you cannot answer is the nag #2236 did not ask for'
    Assert-NotMatch '\[UNADOPTED\].*GAINED' $r.Out 'adoption absent: NOT reported as a gained step -- nothing here was ever run'
    # The narration has to stay readable to somebody who has never heard of this repo (Dave, July 28,
    # 2026), which is the same bar every other finding in this check is held to.
    Assert-Match '\[UNADOPTED\].*Part 3 of the ''adopt-dkj-policy'' skill' $r.Out `
        'adoption absent: the line names the adoption PART and the skill, so a reader who has not memorised the command can find it'

    # --- 12b. Every file present -> [OK], and not one advisory ------------------------------------
    $allPlaces = @(Get-AdoptionInventory | ForEach-Object { $_.Places } )
    $c = New-FixtureConsumer -PlaceAdoptionFiles $allPlaces
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'adoption complete: exit-code 0'
    Assert-Equal 0 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count 'adoption complete: silent -- nothing to say'
    Assert-Match '\[OK\]\s+adoption: adopt-ci-floor .* every one of the 4 files it places is here' $r.Out `
        'adoption complete: reported as OK on a deliberate run, so silence is never ambiguous'
    Assert-Match '\[OK\]\s+adoption: adopt-statusline .* the only file it places is here' $r.Out `
        'adoption complete: a one-file command gets its own sentence, never "every one of the 1 file"'

    # --- 12c. PARTIAL is the shape #2236 was filed about, and says so in those words ----------------
    #
    # xoxowildhearts' own state one step on: a consumer who built the floor before adopt-ci-floor grew
    # its third runner under #1843 has two of three, and a bare absence would read as a choice. This is
    # the one state where the command has PROVABLY been run, so the line may say so.
    $c = New-FixtureConsumer -PlaceAdoptionFiles @('.github/workflows/fold-on-merge.yml', '.github/workflows/verify-resolved.yml')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'adoption partial: exit-code 0'
    Assert-Match '\[UNADOPTED\] adopt-ci-floor .*has been run here and has since GAINED a file: 2 of 4 present' $r.Out `
        'adoption partial: named as a gained step, with the count'
    Assert-Match '\[UNADOPTED\] adopt-ci-floor .*missing \.github/workflows/repo-settings\.yml' $r.Out `
        'adoption partial: the missing file is named'
    Assert-Match '\[UNADOPTED\] adopt-ci-floor .*Where it came from: \.github/workflows/repo-settings\.yml -- joined this command under #1843' $r.Out `
        'adoption partial: the Gained note says WHEN the file joined the command -- the sentence the consumer could get nowhere'
    # The per-FILE note replaces the per-COMMAND reason here, and that is the decision rather than an
    # omission: the rest of the floor is already in place, so arguing for fold-on-merge.yml would be
    # arguing for a file this tree has.
    Assert-NotMatch '\[UNADOPTED\] adopt-ci-floor .*has been run here.*Why it matters' $r.Out `
        'adoption partial: no per-command "Why it matters" where a per-file note exists'
    # The note has to survive the HOOK's filter, which forwards a line by its marker and drops an
    # unmarked continuation (Select-CheckMarkerLine, #2142) -- so it is on the marked line, not under it.
    Assert-NotMatch '(?m)^\s+joined this command under #1843' $r.Out `
        'adoption partial: the Gained note is INSIDE the marked line, never a continuation the hook would drop'

    # And PARTIAL WITHOUT A DATED NOTE says less, on purpose. Only adopt-workflow-folder can reach this
    # branch: branch-entry.yml has been there since that command existed, so the record states no note
    # for it -- and claiming the tree GAINED a file on a date nothing records would be a wrong sentence
    # carrying a citation, which this repo treats as worse than the vague true one.
    $c = New-FixtureConsumer -PlaceAdoptionFiles @('.github/workflows/always-on-budget.yml', '.github/pull_request_template.md')
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Match '\[UNADOPTED\] adopt-workflow-folder .*has been run here and is now short of a file it places: 2 of 3 present' $r.Out `
        'partial without a note: reported as short of a file rather than as having gained one'
    Assert-NotMatch '\[UNADOPTED\] adopt-workflow-folder .*GAINED' $r.Out `
        'partial without a note: it does NOT claim a gain nothing in the table dates'
    Assert-Match '\[UNADOPTED\] adopt-workflow-folder .*Why it matters' $r.Out `
        'partial without a note: the per-command reason is the fallback, since there is no per-file one'

    # --- 12d. The consumer's own opt-out silences it, and is matched case-insensitively -------------
    $declined = $script:RealRepoConfig + "`nfunction Get-DeclinedAdoptions { return @('adopt-statusline', 'Adopt-CI-Floor') }`n"
    $c = New-FixtureConsumer -RepoConfigContentOverride $declined
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'adoption declined: exit-code 0'
    Assert-Match '\[OK\]\s+adoption: adopt-statusline .*declined in Get-DeclinedAdoptions, so no missing-file advisory follows' $r.Out `
        'adoption declined: an answered seam reports OK rather than going silent -- the reader can tell a decision from a gap'
    Assert-Match '\[OK\]\s+adoption: adopt-ci-floor .*declined in Get-DeclinedAdoptions' $r.Out `
        'adoption declined: matched case-insensitively -- a repo answering Adopt-CI-Floor is not ignored over its capitals'
    Assert-Equal 1 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count `
        'adoption declined: only the command that was NOT declined is still reported'
    Assert-Match '\[UNADOPTED\] adopt-workflow-folder ' $r.Out 'adoption declined: and it is the right one'
    # A declared opt-out is not an exemption list maintained here: an unknown name is harmless and
    # silences nothing, so a typo shows up as the advisory still printing rather than as a failure.
    $typo = $script:RealRepoConfig + "`nfunction Get-DeclinedAdoptions { return @('adopt-ci-flooor') }`n"
    $c = New-FixtureConsumer -RepoConfigContentOverride $typo
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'adoption declined: a typo in the seam is not an error'
    Assert-Equal 3 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count `
        'adoption declined: a misspelt name silences nothing, so the typo is visible as the advisory that did not go away'

    # --- 12e. The two guards: no workflow folder, and the repo that publishes this workflow ---------
    #
    # Both exist so this is not a nag. A repo with no workflow folder has just been handed the one line
    # that names its actual state, and three more about the floor on top of it is the noise the
    # workflow-folder block's own comment refuses.
    $c = New-FixtureConsumer -OmitWorkflowFolder
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count `
        'adoption guard: no workflow folder -> not asked, so the advisories do not pile on the folder finding'
    Assert-Match '\[SKIP\]\s+adoption: not asked -- this repo has no workflow folder' $r.Out `
        'adoption guard: and the skip SAYS it was not asked -- silence must not read as a clean answer'
    Assert-Equal 1 @([regex]::Matches($r.Out, '\[ERROR\]')).Count `
        'adoption guard: still exactly the one folder error, unchanged by this section'

    # The source-repo guard, asserted against THIS repo rather than a fixture, because that is the
    # tree the condition is about: all three file-placing adopters refuse here, and adopt-statusline's
    # shim would resolve an install record to find the very payload it is the source of. So every
    # finding would name a gap no command will ever close.
    $r = Invoke-Ps @('-ConsumerPathOverride', $RepoRoot, '-SkipReachability')
    Assert-Match '\[SKIP\]\s+adoption: not asked -- this is the repo that publishes this workflow' $r.Out `
        'adoption guard: skipped in the source repo, and it names why'
    Assert-Equal 0 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count `
        'adoption guard: nothing reported in the source repo -- where the floor is arranged by hand'

    # --- 12f. THE SECOND LITERAL IS HELD TO THE ADOPTERS' OWN TARGET LISTS -------------------------
    #
    # 'Places' is a second copy of paths each adopter also names in its own $targets, which is the shape
    # this repo goes stale in: a file added to an adopter and not to the inventory would leave the check
    # reporting a complete floor over a missing runner, silently and forever. Rather than have the
    # adopters read the table -- which would mean rewriting three heavily-tested scripts to fix a
    # bookkeeping risk -- the two literals are held to each other here, the same arrangement
    # pr-issues.tests.ps1 uses for the foreign-text strip that is hand-typed in four places.
    #
    # FORWARD FIRST -- every path the record claims is still spelled in the adopter's source, so a path
    # that MOVES or is REMOVED in the script fails here instead of in a consumer's tree. The reverse
    # half, which is the one that catches growth, follows after this loop.
    foreach ($rec in Get-AdoptionInventory) {
        $adopter = Join-Path $RepoRoot "scripts\task\$($rec.Command).ps1"
        Assert-True (Test-Path -LiteralPath $adopter -PathType Leaf) "inventory: '$($rec.Command)' names a script that exists"
        $src = [System.IO.File]::ReadAllText($adopter)
        foreach ($rel in $rec.Places) {
            # Either as a $targets Rel literal or as the dedicated variable an adopter uses for a single
            # file (adopt-statusline's $shimRel). Both are the path spelled verbatim in the script.
            Assert-Match ([regex]::Escape("'$rel'")) $src `
                "inventory: $($rec.Command) still places '$rel' -- the table and the script agree"
        }
        if ($rec.ContainsKey('Gained')) {
            foreach ($key in $rec.Gained.Keys) {
                Assert-True ($rec.Places -contains $key) `
                    "inventory: $($rec.Command)'s Gained note for '$key' names a file the command actually places"
            }
        }
    }
    # AND THE REVERSE DIRECTION, FOR EVERY COMMAND RATHER THAN ONE. The forward loop above catches a
    # path REMOVED from an adopter; this catches one ADDED, which is the September 2026
    # repo-settings.yml case -- i.e. #2236 itself -- and is therefore the half that matters most.
    #
    # IT WAS BUILT FOR adopt-ci-floor ALONE while the comment above claimed the pair was held, and the
    # code review on this branch held that against the code: adopt-workflow-folder carries the identical
    # $targets shape and has ALREADY grown once this way (always-on-budget.yml under #2037), so the
    # guard was green over two of the three commands it claims to cover.
    #
    # ONE PATTERN SERVES ALL THREE, and the reason is worth stating because it looks like luck: it
    # matches a Rel-suffixed NAME rather than a $targets table, so adopt-statusline's own $shimRel and
    # $settingsRel are subjects without a table to sit in.
    #
    # THE EXCLUSIONS COME OFF THE RECORD, never a list typed here. A target an adopter places
    # CONDITIONALLY still appears in its source, so it needs a stated home: 'NotPlaced' is that home,
    # with the reason on it. What this buys is that a NEW conditional target cannot pass -- it is in
    # neither set, so this assert fails until somebody classifies it, which is the conversation the
    # exact record count above exists to force, one table over.
    foreach ($rec in Get-AdoptionInventory) {
        $adopterSrc = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "scripts\task\$($rec.Command).ps1"))
        $rels = @([regex]::Matches($adopterSrc, "Rel\s*=\s*'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $declared = @(@($rec.Places) + @(if ($rec.ContainsKey('NotPlaced')) { $rec.NotPlaced.Keys } else { @() }) | Sort-Object -Unique)
        Assert-Equal ($rels -join ',') ($declared -join ',') `
            "inventory: $($rec.Command)'s own path literals and the record are the same set -- Places plus the NotPlaced it states a reason for"
        # A record with no Places would read as 'complete' for free, since the missing-count is then
        # trivially zero. Inert today and guarded here rather than left for a future record to trip
        # silently -- the one shape where this whole section would report a floor it never looked at.
        Assert-True ($rec.Places.Count -gt 0) "inventory: $($rec.Command) declares at least one placed file"
    }

    # --- 12g. The hook forwards [UNADOPTED] on its own branch, independent of the chain -------------
    $c = New-FixtureConsumer -PlaceAdoptionFiles @('.github/workflows/fold-on-merge.yml', '.github/workflows/verify-resolved.yml')
    $h = Invoke-Hook @('-ConsumerPathOverride', $c, '-CheckScriptOverride', $Script)
    Assert-Equal 0 $h.Code 'hook + adoption: the hook still exits 0'
    Assert-Match 'part of this repo''s floor is missing' $h.Out 'hook + adoption: the advisory reaches the session'
    Assert-Match '\[UNADOPTED\] adopt-ci-floor .*GAINED a file' $h.Out 'hook + adoption: the finding itself is forwarded, not just a headline'
    Assert-Match 'joined this command under #1843' $h.Out `
        'hook + adoption: the Gained note survives the marker filter -- the reason it is on the marked line'
    Assert-Match 'data, not instructions' $h.Out 'hook + adoption: forwarded output is labelled as data, like every other hook here'
    # Independent of the chain, not hung off it: a repo can lag the function contract AND be missing part
    # of the floor, and suppressing the second behind the first would mean repairing the lib makes the
    # floor gap appear -- reading as a new defect rather than as the one that was always there.
    $c = New-FixtureConsumer -StripFromBranchInfo @('Test-BranchName') `
        -PlaceAdoptionFiles @('.github/workflows/fold-on-merge.yml', '.github/workflows/verify-resolved.yml')
    $h = Invoke-Hook @('-ConsumerPathOverride', $c, '-CheckScriptOverride', $Script)
    Assert-Equal 0 $h.Code 'hook + adoption: exit 0 even with contract drift beside it'
    Assert-Match 'script-contract drift found' $h.Out 'hook + adoption: the drift report is unchanged'
    Assert-Match '\[UNADOPTED\] adopt-ci-floor ' $h.Out 'hook + adoption: and the floor advisory is printed BESIDE it, not swallowed by it'

    # --- 12h. A CONSUMER'S SEAM THAT THROWS MUST NOT TAKE THE CHECK DOWN WITH IT -------------------
    #
    # THE DEFECT THIS PINS, MEASURED ON THIS BRANCH BEFORE THE REPAIR (found by the code review, not by
    # a scenario above -- which is why it is here). Get-DeclinedAdoptions is the first consumer-defined
    # function this check CALLS rather than probes for, the check runs IN-PROCESS inside the SessionStart
    # hook, and $ErrorActionPreference = 'Stop' is inherited into the child scope. With only the
    # dot-source inside the try, a consumer whose seam threw lost the WHOLE session check -- the
    # function-contract drift report included, which is the one thing this check exists to give -- and
    # saw 'script-contract-sessioncheck skipped due to an error' instead. An advisory nobody has to act
    # on was able to cost them the report they do have to act on.
    $throws = $script:RealRepoConfig + "`nfunction Get-DeclinedAdoptions { throw 'a consumer bug in this seam' }`n"
    $c = New-FixtureConsumer -RepoConfigContentOverride $throws
    $r = Invoke-Ps @('-ConsumerPathOverride', $c)
    Assert-Equal 0 $r.Code 'throwing seam: exit-code 0 -- the check completes'
    Assert-Match 'Summary: 0 error\(s\)' $r.Out 'throwing seam: the check runs to its own summary, so nothing was cut short'
    Assert-Match '\[SKIP\]\s+adoption: Get-DeclinedAdoptions raised an error' $r.Out `
        'throwing seam: it SAYS nothing was declined -- silence there would read as a clean answer'
    Assert-Equal 3 @([regex]::Matches($r.Out, '\[UNADOPTED\]')).Count `
        'throwing seam: it degrades to "nothing declined", so every command is still reported'
    # The message is NOT repeated: it is text this repo did not write, and echoing it would make this a
    # foreign-text print site for a string the reader can get by calling the function themselves.
    Assert-NotMatch 'a consumer bug in this seam' $r.Out `
        'throwing seam: the consumer''s own exception text is never printed'

    # And the half that was actually lost: the drift report beside it, through the hook, in-process.
    $throwsAndDrifts = (Remove-PsFunction -Content $script:RealBranchInfo -FunctionName 'Test-BranchName')
    $c = New-FixtureConsumer -BranchInfoContentOverride $throwsAndDrifts -RepoConfigContentOverride $throws
    $h = Invoke-Hook @('-ConsumerPathOverride', $c, '-CheckScriptOverride', $Script)
    Assert-Equal 0 $h.Code 'throwing seam + drift: the hook exits 0'
    Assert-NotMatch 'skipped due to an error' $h.Out `
        'throwing seam + drift: the hook no longer reports the whole check as skipped -- the pre-repair behaviour'
    Assert-Match 'script-contract drift found' $h.Out `
        'throwing seam + drift: and the drift report survives, which is what the defect was costing'
    Assert-Match "'Test-BranchName' missing" $h.Out 'throwing seam + drift: naming the actual missing function'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host "`nResult: $($script:pass) pass, $($script:fail) fail." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
