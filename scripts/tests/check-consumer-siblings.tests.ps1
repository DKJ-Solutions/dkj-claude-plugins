<#
.SYNOPSIS
    Tests for scripts/sync/check-consumer-siblings.ps1's OWN console lines (issue #2248).

.DESCRIPTION
    WHY THIS SUITE EXISTS AND WHAT IT DOES NOT COVER. sibling-divergence.tests.ps1 already exercises
    Compare-SiblingInventory, Group-SiblingConsumer and Find-ShippedMechanism thoroughly -- the pure
    lib the entry point sits on top of. Nothing anywhere ran the SCRIPT ITSELF before this file: the
    reading (gh / disk), the grouping, and the Write-Host/Write-Info lines that print a manifest's own
    'repo' field and a sibling's own file paths were untested end to end. That gap is what #2248 and its
    #2272 follow-up closed in production and what this suite pins against reopening.

    THE SUBJECT IS THE GUARD, NOT THE COMPARISON. Crafted manifest 'repo' values -- one deceptive, one
    plain, per sibling group below -- are run through the real script with -Source disk (no network, no
    gh) and the captured console text is checked for
    what #2248's commit message names as the risk: a manifest-supplied value reaching the console (and,
    via Write-Info, session context) with its control characters and brackets intact.

    A DELIBERATE CHOICE OF CHARACTER CLASS. Format-SafePathToken's docstring and
    check-report-lib.tests.ps1 already pin exactly what it strips (control characters via \p{C}, square
    brackets, run-length capping) against the function directly -- U+202E and friends included. Nothing
    here re-proves that; see check-report-lib.tests.ps1 for the function-level pin. This suite proves
    the CALL SITE, which is a different failure mode: the function was never in doubt, whether the
    script's own print lines actually route their value through it was. A bracket and an embedded
    newline are used because they are the two properties Format-SafePathToken's docstring names as
    load-bearing (a bracket a hook could count as a marker, a newline that could forge a line) AND
    because both are plain ASCII -- unlike a bidi override or a zero-width run, neither can be mangled
    by the console's own code page on the way through a child-process capture (see the language-layers.md note on
    native-command output decoding), so a false pass here cannot be an artefact of the terminal rather
    than of the guard.

    FORMAT-SAFEPATHTOKEN WELDS RATHER THAN SPACES (unlike Get-DisplayRef/Get-DisplayPath, ref-print-lib.ps1):
    it replaces a control character with nothing, not a space, so 'a<ESC>b' becomes 'ab' --
    check-report-lib.tests.ps1 already asserts exactly that. The strings below are chosen so the welded
    result is still a legible, assertable literal rather than an accident to work around.

    NO GIT, NO gh, NO NETWORK. -Source disk reads plain files off two fixture "consumer checkout"
    directories; the comparison never touches GitHub. The only filesystem quirk worth flagging: the
    script resolves its OWN repo root from $PSScriptRoot (it takes no -RepoRoot override) and refuses
    an absolute localCheckout candidate, so a fixture checkout has to be a real directory reachable by a
    RELATIVE path from this repo's actual root -- exactly the shape every real connectors/*.json
    manifest already uses ('../life-hub', '../../bwjecommerce/smartwatchbanden'). The two fixture
    checkouts below are therefore created as siblings of this checkout, not under %TEMP%, and removed
    in a finally block.

    WHAT IS DELIBERATELY NOT COVERED HERE, named rather than left silent:
      - The -Source github route (Get-GitHubInventory) is not exercised at all -- it needs gh and a
        network, same boundary sync-main.tests.ps1 already draws for the Shopify pull. The guard on
        $label/$f.Member/$f.Path is identical on that route (same Write-Host/Write-Info call sites), so
        this is asymmetric coverage rather than an untested code path, not a second guard nobody pinned.
      - The SHIPPED lane's $f.Class and $where text (Find-ShippedMechanism's Plugin/Path) are, per the
        #2248 commit, this repo's OWN data and deliberately unguarded -- nothing here asserts that
        either, since asserting an absence of stripping on trusted data is not what this suite is for.
      - A malformed connectors/*.json is not exercised -- the 'is not valid JSON -- skipped' line
        prints the manifest FILE's own on-disk name (Get-ChildItem's $mf.Name), never a value read out
        of a manifest's FIELDS, so it carries nothing #2248 or #2272 was ever about.

    #2272, A FOLLOW-UP LANDED ON THIS SAME BRANCH, AND THE BULLET IT RETIRES. The 'read $label : N
    comparable path(s) via ...' line and the 'group ... not compared' line an unreadable member feeds
    used to print the manifest 'repo' field completely raw -- found BY this suite's own fixture (it
    forged exactly the two-line console split the guard exists to prevent) and filed as #2272. Both are
    now guarded ($label via Format-SafePathToken, $inv.Reason via Format-SafeProseToken) and both are
    exercised below, by a SECOND sibling group: one unreadable member skips its WHOLE group's
    comparison ('ONE SCHEME PER GROUP' in the script), so reaching the not-compared line needs a
    member whose localCheckout never resolves, and reusing group 1 for that would have silently
    stopped the ONLY-IN asserts above from ever firing. $inv.Reason's own STRIPPING is deliberately not
    separately asserted: on -Source disk it is always this script's own literal sentence ('disk', or the
    unreadable branch's fixed reason) -- never manifest-supplied. The only arms that build it from
    foreign text (a sibling's own default-branch name off gh's API) sit in Get-GitHubInventory, reachable
    only via -Source github, the first bullet above -- so an assert on Reason's stripping here would pin
    nothing that could ever break on this route. What IS checked is that the line composes correctly
    end to end, reason text included.

    Dependency-free (no Pester). Pure ASCII (repo convention for .ps1), and deliberately so here: the
    two deceptive strings are composed from '[', ']' and "`n", never a literal non-ASCII code point.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\sync\check-consumer-siblings.ps1'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

# --- Fixture: two consumer checkouts, siblings of THIS repo root, exactly the shape a real
#     connectors/*.json localCheckout already uses ('../life-hub'). Not under %TEMP% -- see the
#     docstring above for why a relative-only field forces this. --------------------------------------
$siblingParent = Split-Path -Parent $RepoRoot
$tag = "$PID-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$nameA = "zz-check-consumer-siblings-fixture-$tag-a"
$nameB = "zz-check-consumer-siblings-fixture-$tag-b"
$dirA  = Join-Path $siblingParent $nameA
$dirB  = Join-Path $siblingParent $nameB
$ConnectorDir = Join-Path ([System.IO.Path]::GetTempPath()) "check-consumer-siblings-manifests-$tag"

try {
    Write-Host '== check-consumer-siblings.tests: scripts/sync/check-consumer-siblings.ps1 (#2248) ==' -ForegroundColor Cyan

    # A's own file, ONLY-IN A: a bracket in the FILENAME itself, which is legal on NTFS and is exactly
    # the "a bracket in a path would be COUNTED by the hook" case Format-SafePathToken's docstring names.
    New-Item -ItemType Directory -Path (Join-Path $dirA 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dirA 'scripts\on[MARKER]ly-a.ps1'), "# fixture`n")
    # B carries nothing under a comparable root, so A's file above is reported ONLY-IN A.
    New-Item -ItemType Directory -Path $dirB -Force | Out-Null

    New-Item -ItemType Directory -Path $ConnectorDir -Force | Out-Null

    # A control character CANNOT survive in a Windows filename or in JSON without escaping, but it CAN
    # be a manifest field's VALUE -- exactly the #2248 class (a repo's 'repo' field, its own text, never
    # validated against a path or ref charset). An embedded newline immediately followed by a bracketed
    # marker is the sharpest version of the two named risks at once: a forged extra console line AND a
    # forged hook marker, back to back.
    $deceptiveRepo = "acme/repo`n[INJECTED]"
    $plainRepoB    = 'acme/repo-b'

    $manifestA = [ordered]@{
        repo          = $deceptiveRepo
        siblingGroup  = 'check-consumer-siblings-2248-test'
        localCheckout = "..\$nameA"
    }
    $manifestB = [ordered]@{
        repo          = $plainRepoB
        siblingGroup  = 'check-consumer-siblings-2248-test'
        localCheckout = "..\$nameB"
    }
    ($manifestA | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $ConnectorDir 'fixture-a.json') -Encoding utf8
    ($manifestB | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $ConnectorDir 'fixture-b.json') -Encoding utf8

    # A SECOND, INDEPENDENT sibling group (#2272), to reach the 'read $label : ...' line every readable
    # member prints and the 'group ... not compared' line an UNREADABLE one feeds.
    # C's localCheckout is deliberately a path that will never exist, so C is unreadable and D -- readable
    # -- still prints its own 'read' line before the group-level check sees C and skips the comparison.
    # A second group rather than adding a third, unreadable member to group 1: ONE unreadable member
    # skips its WHOLE group's comparison, which would have silently stopped every ONLY-IN assert above
    # from ever firing. D's localCheckout reuses $dirB -- already built above, and only ever read here.
    $deceptiveRepoUnreadable = "beta/repo`n[UNREADABLE-MARKER]"
    $plainRepoD              = 'beta/repo-d'
    $nameCMissing            = "zz-check-consumer-siblings-fixture-$tag-c-does-not-exist"

    $manifestC = [ordered]@{
        repo          = $deceptiveRepoUnreadable
        siblingGroup  = 'check-consumer-siblings-2248-unreadable-test'
        localCheckout = "..\$nameCMissing"
    }
    $manifestD = [ordered]@{
        repo          = $plainRepoD
        siblingGroup  = 'check-consumer-siblings-2248-unreadable-test'
        localCheckout = "..\$nameB"
    }
    ($manifestC | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $ConnectorDir 'fixture-c.json') -Encoding utf8
    ($manifestD | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $ConnectorDir 'fixture-d.json') -Encoding utf8

    # No 2>&1: this run's own stdout is all that is asserted, and a native-command stderr reformat is
    # exactly the trap scripts/tests/*.tests.ps1's own conventions (Tycho's lens) warn against copying.
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script `
        -ConnectorDir $ConnectorDir -Source disk -SkipAliasCheck
    $code = $LASTEXITCODE
    $joined = ($out -join "`n")

    Assert-True ($code -eq 0) 'the run itself exits 0 -- a finding is not a script error'
    Assert-True ($joined -match 'ONLY-IN') 'the fixture reaches the ONLY-IN branch at all, so the asserts below are testing something'

    # SCOPED TO THE ONLY-IN LINES DELIBERATELY, NOT THE WHOLE REPORT -- kept scoped even after #2272,
    # rather than widened to a blob-wide assert, because the group-2 asserts below already cover the
    # 'read'/'not compared' lines by name and a blob-wide assert here would duplicate them rather than
    # add anything. #2248's own diff guarded $label only in the ONLY-IN/PARTIAL/DRIFTED/SHIPPED loop;
    # the 'read $label : N comparable path(s) via ...' line and the 'group ... not compared' line it
    # feeds print the SAME manifest 'repo' field, and were UNGUARDED until this branch's own #2272
    # follow-up, found BY this very fixture. See the docstring's '#2272' paragraph and the group-2
    # asserts further down for what closed that gap and how it is pinned.
    $onlyInHeader = @($out | Where-Object { $_ -match '^\s*ONLY-IN\s' })
    $onlyInFinding = @($out | Where-Object { $_ -match '^\s*\[INFO\]\s+ONLY-IN\s' })
    Assert-True ($onlyInHeader.Count -eq 1) 'exactly one ONLY-IN header line is printed'
    Assert-True ($onlyInFinding.Count -eq 1) 'exactly one ONLY-IN finding line is printed'

    # THE GUARD, NOT THE FUNCTION (see docstring). Format-SafePathToken strips a control character by
    # DELETING it (not spacing it, unlike Get-DisplayRef/Path) and deletes '[' and ']' outright, so the
    # untouched pair becomes the welded, bracket-free literal below -- proven directly against the
    # function in check-report-lib.tests.ps1, and reproduced here only as the shape a caller sees.
    Assert-True (-not ($onlyInHeader[0] -match '\[INJECTED\]')) `
        "the manifest 'repo' field's bracketed marker text does not survive AS A MARKER in the ONLY-IN header -- no raw '[INJECTED]'"
    Assert-True ($onlyInHeader[0] -match 'acme/repoINJECTED') `
        "and the header's embedded newline is removed rather than spaced (Format-SafePathToken's own behaviour), so it reads as one welded, single-line token"
    Assert-True (-not ($onlyInFinding[0] -match '\[INJECTED\]')) `
        "the manifest 'repo' field's bracketed marker text does not survive AS A MARKER in the ONLY-IN finding line either -- no raw '[INJECTED]'"
    Assert-True (-not ($onlyInFinding[0] -match '\[MARKER\]')) `
        "and neither does the deceptive FILENAME's own bracketed marker -- no raw '[MARKER]'"
    Assert-True ($onlyInFinding[0] -match 'acme/repoINJECTED') `
        'the finding line repeats the same welded repo label (it prints $f.Member, guarded the same way as $label)'
    Assert-True ($onlyInFinding[0] -match 'onMARKERly-a\.ps1') `
        "the deceptive filename survives with its brackets stripped -- welded (only the two brackets are removed, nothing sits between 'on' and 'MARKER')"

    # THE NEGATIVE THAT WOULD HAVE CAUGHT #2248 BEFORE IT SHIPPED, scoped the same way: the raw,
    # untouched value must never appear verbatim in either ONLY-IN line -- if it does, that call site
    # stopped calling the guard.
    Assert-True (-not ($onlyInHeader[0].Contains($deceptiveRepo))) `
        'the raw, unguarded manifest repo value never appears verbatim in the ONLY-IN header'
    Assert-True (-not ($onlyInFinding[0].Contains($deceptiveRepo))) `
        'the raw, unguarded manifest repo value never appears verbatim in the ONLY-IN finding line'

    # #2272: THE 'read' LINE, printed for every READABLE member. Three fire this run --
    # group 1's A and B, and group 2's D (D is readable; only C is not, and C's own unreadability is
    # what triggers the 'not compared' line below rather than a 'read' line of its own).
    $readLines = @($out | Where-Object { $_ -match '^\s*read\s' })
    Assert-True ($readLines.Count -eq 3) 'three readable members (A, B, D) each produce exactly one read line'
    # Matched on the welded marker text, not on 'acme' -- B's plain label is 'acme/repo-b' and would
    # match 'acme' too, which is exactly the kind of loose filter that silently tests the wrong line.
    $readLineA = @($readLines | Where-Object { $_ -match 'INJECTED' })
    Assert-True ($readLineA.Count -eq 1) 'exactly one read line names the deceptive-label member'
    Assert-True (-not ($readLineA[0] -match '\[INJECTED\]')) `
        "the manifest 'repo' field's bracketed marker text does not survive on the read line either -- no raw '[INJECTED]'"
    Assert-True ($readLineA[0] -match 'acme/repoINJECTED') `
        "and the read line's embedded newline is removed the same way as the ONLY-IN lines -- Format-SafePathToken, the same welded result"
    Assert-True (-not ($readLineA[0].Contains($deceptiveRepo))) `
        'the raw, unguarded manifest repo value never appears verbatim on the read line'

    # #2272: THE 'group ... not compared' LINE, fed by $unreadable when a member's checkout
    # does not resolve -- group 2 (C+D) exists only to reach this branch; C's localCheckout is
    # deliberately a path that will never exist, so the group is read but never compared.
    $notComparedLines = @($out | Where-Object { $_ -match 'not compared' })
    Assert-True ($notComparedLines.Count -eq 1) 'the unreadable-member group reaches the not-compared branch exactly once'
    Assert-True (-not ($notComparedLines[0] -match '\[UNREADABLE-MARKER\]')) `
        "the manifest 'repo' field's bracketed marker text does not survive on the not-compared line -- no raw '[UNREADABLE-MARKER]'"
    Assert-True ($notComparedLines[0] -match 'beta/repoUNREADABLE-MARKER') `
        "and its embedded newline is removed the same way -- Format-SafePathToken on the label"
    Assert-True (-not ($notComparedLines[0].Contains($deceptiveRepoUnreadable))) `
        'the raw, unguarded manifest repo value never appears verbatim on the not-compared line'
    # $inv.Reason's own stripping is deliberately NOT separately asserted here -- see the docstring's
    # '#2272' paragraph for why (on -Source disk it is always this script's own literal text, never
    # manifest-supplied, so an assert on ITS stripping would pin nothing that could ever break on this
    # route). What this assert DOES check is that the line composes correctly end to end, reason text
    # included -- a genuine property (Format-SafeProseToken must not mangle the plain sentence it is
    # actually given here), not a restatement of the assert above.
    Assert-True ($notComparedLines[0] -match 'no localCheckout candidate resolves on this machine') `
        'and the plain-English reason text (never foreign on this route) still reaches the line unmangled'
} finally {
    foreach ($d in @($dirA, $dirB, $ConnectorDir)) {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:pass) passed, $($script:fail) failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($script:pass) passed." -ForegroundColor Green
