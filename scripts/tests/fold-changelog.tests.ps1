<#
.SYNOPSIS
    Regression tests for scripts/release/fold-changelog-entry.ps1 -- which files it folds, where in
    CHANGELOG.md's flat list it puts them, and what it does and does not strip on the way.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL fold
    script (copied into a throwaway temp repo root, so nothing touches the own working copy) and
    asserts on exit code + which files survive + CHANGELOG content.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fold-changelog.tests.ps1

    THE FIXTURE CHANGELOG HAS NO SECTION HEADINGS, and that is the change this suite was rewritten for
    (August 5, 2026). CHANGELOG.md used to carry one '## Tier N - Pull Requests' section per tier, named by
    a repo-owned seam, and most of this file's fixture machinery existed to model which sections a consumer
    had declared. The document is a FLAT RANKED LIST now: intro, then one '## ' per change. So the seam, the
    Keep-a-Changelog variant, the "wrong heading stops cleanly" refusal and the three-section fixture are all
    gone -- not relaxed, but structurally unreachable, because there is no heading name left to get wrong.

    What replaces them is the assert those tests were standing in for: the entry lands BELOW the intro and
    at its RANKED position, and the intro is never written over.

    Two guards worth keeping in mind while reading:

      * the original bug this file was written for -- fold-all folding any root *.md that was not in a tiny
        denylist, so CONTRIBUTING.md and SECURITY.md got folded and removed. The fix keys off the entry
        format itself: a heading at the entry level (or the second level the range accepts, for a file
        written under an older one) against a meta doc's H1.
      * the pre-pass: a fold-all run writes one entry at a time, so a refusal has to happen before the
        first write or it leaves a half-state to unpick by hand on main.

    The fold script calls `gh pr list` per folded entry for PR-number enrichment; with no matching
    PR that simply returns nothing and the entry folds without a #NN -- so these tests do not depend
    on a PR existing. Everything under test here happens regardless of gh.

    Pure ASCII (repo convention for .ps1). The middot in a pre-format entry heading is built from its
    codepoint.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot         = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$FoldSrc          = Join-Path $RepoRoot 'scripts\release\fold-changelog-entry.ps1'
$RepoConfigSrc    = Join-Path $RepoRoot 'scripts\repo-config.ps1'
$NativeCaptureSrc = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
# The entry format: the heading levels the fold recognises and normalises to, the impact table it reads the
# rank from, and the ranked insert offset. A $PSScriptRoot-relative sibling of the fold script, so the
# fixture has to carry it.
$EntryScaffoldSrc = Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1'
# And entry-scaffold-lib.ps1's own sibling, since #1650: it dot-sources this one for Get-DisplayRef.
$RefPrintLibSrc   = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'
# The plugin tree: Get-TouchedPlugins and the roots it reads, for the 'Plugins:' line. Also a
# $PSScriptRoot-relative sibling of the fold script, so the fixture carries it for the same reason.
$PluginTreeSrc    = Join-Path $RepoRoot 'scripts\lib\plugin-tree-lib.ps1'
# Get-SeamValue + Get-DefaultChangelogPath (issue #885, group A): the changelog path itself is now read
# through this seam. Same $PSScriptRoot-relative sibling reasoning as the three above -- unconditionally
# dot-sourced by the fold script, so a fixture missing it fails not with a wrong answer but with a raw
# "term not recognized" error at the dot-source line.
$SeamLibSrc       = Join-Path $RepoRoot 'scripts\lib\seam-lib.ps1'
# Dot-sourced into the RUNNER as well, not only copied into each fixture: the branch/ cases build their
# fixture files with the real formatters and assert with the real predicates, so a change to the format
# breaks the script and its test together instead of leaving the test asserting a shape nothing writes.
. $EntryScaffoldSrc

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

$script:fixtures = @()
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# The entry format's levels, composed from the lib rather than typed. Both pairs shifted one deeper on
# August 26, 2026, and the fixtures below state the format the fold reads -- so a literal here is a second
# definition of it, which is exactly what turned 57 assertions in this file red on the day of the shift.
$foldEntryH = '#' * (Get-EntryHeadingLevel)
$foldSectH  = '#' * (Get-EntrySectionLevel)
$foldPendH  = Get-ChangelogUnreleasedHeading

# The fixture changelog's intro, kept as one variable so the tests can assert it came through untouched
# rather than re-describing it. Deliberately contains NO '## ' line: in the flat model the intro is
# everything above the first entry heading, so an intro that carried one would move the boundary.
$script:FixtureIntro = @(
    '# Changelog',
    '',
    'Everything merged since the last release, furthest reach first. Every release ever cut is listed',
    'in releases/README.md.',
    ''
) -join "`n"

function Get-FixtureChangelogRel {
    <#
        Where a fixture's CHANGELOG.md sits: at the root for the repointed default, or inside the branch-
        document folder for -CoLocated, which is this repo's own layout since #1437.

        THE CO-LOCATED PATH IS COMPOSED FROM THE INTERFACE, not typed. Directory is where the sweep looks
        and ReservedNames is what the sweep must skip, so a fixture built from those two cannot end up
        modelling a layout the script no longer has. It throws rather than falling back if CHANGELOG.md
        ever leaves that list -- a fixture that quietly stopped modelling the co-location would keep
        passing while testing nothing, which is the state #1497 was already in.
    #>
    param([switch]$CoLocated)
    if (-not $CoLocated) { return 'CHANGELOG.md' }
    $paths = Get-BranchFilePaths
    if (@($paths.ReservedNames) -notcontains 'CHANGELOG.md') {
        throw "fixture: CHANGELOG.md is no longer in Get-BranchFilePaths().ReservedNames -- the co-located layout modelled here has changed shape."
    }
    return "$([string]$paths.Directory)/CHANGELOG.md"
}

function New-FoldFixture {
    <#
        A throwaway repo root with the real fold script + its repo-owned/sibling dependencies
        (repo-config.ps1 for Get-RepoName, native-capture-lib.ps1 for the gh call, entry-scaffold-lib.ps1
        for the entry format, plugin-tree-lib.ps1 for the 'Plugins:' line) and a CHANGELOG holding only
        its intro.

        THE FIXTURE CARRIES EVERY SIBLING THE SCRIPT DOT-SOURCES, which is a change from what stood here:
        release-lib.ps1 was deliberately left out so the 'Plugins:' detection would be "simply skipped".
        That was testing a deployment state that had stopped existing -- release-lib became a mirrored
        sibling on August 8, 2026, so it is present everywhere the fold runs. A fixture that omits a
        sibling is not a lean fixture, it is a different program.

        NO marketplace.json HERE, and that is what the absent 'Plugins:' line now proves. The fold asks
        the marketplace which plugins exist; a repo that declares none yields none, so the line is absent
        because the repo has no plugins rather than because a file was withheld from the fixture. Same
        observable outcome, a reason that is actually the script's.

        repo-config.ps1 is copied VERBATIM now. It used to be rewritten per fixture -- stripping the tier
        map, adding back the legacy single-heading getter -- because which changelog sections a repo declared
        was the subject of half these tests. The fold reads no section seam at all any more, so there is
        nothing left to vary.
        -CoLocated LEAVES THE SEAM ALONE, which is this repo's own production layout (#1437): CHANGELOG.md
        sits INSIDE the branch-document folder, beside the dossiers the fold-all sweep lists. Every other
        fixture here repoints the seam to the root for the reasons above, and that is what kept #1497
        invisible -- with the changelog at the root, the folder scan could not reach it, so no test in this
        suite ever asked what the sweep does with a reserved page sitting in the folder it sweeps. Pass this
        switch when the co-location IS the subject; the fixture then writes its intro to the seam's own path
        and Get-Changelog is given that path.
    #>
    param([Parameter(Mandatory = $true)][string]$Label, [switch]$CoLocated)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("fold-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\release') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib')     -Force | Out-Null
    Copy-Item -LiteralPath $FoldSrc          -Destination (Join-Path $dir 'scripts\release\fold-changelog-entry.ps1') -Force
    Copy-Item -LiteralPath $NativeCaptureSrc -Destination (Join-Path $dir 'scripts\lib\native-capture-lib.ps1')       -Force
    Copy-Item -LiteralPath $EntryScaffoldSrc -Destination (Join-Path $dir 'scripts\lib\entry-scaffold-lib.ps1')       -Force
    # A sibling of a sibling since #1650: entry-scaffold-lib.ps1 dot-sources ref-print-lib.ps1 for
    # Get-DisplayRef, so a fixture carrying the one and not the other loads a lib that throws.
    Copy-Item -LiteralPath $RefPrintLibSrc   -Destination (Join-Path $dir 'scripts\lib\ref-print-lib.ps1')            -Force
    Copy-Item -LiteralPath $PluginTreeSrc    -Destination (Join-Path $dir 'scripts\lib\plugin-tree-lib.ps1')          -Force
    Copy-Item -LiteralPath $SeamLibSrc       -Destination (Join-Path $dir 'scripts\lib\seam-lib.ps1')                 -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    Copy-Item -LiteralPath $RepoConfigSrc    -Destination (Join-Path $dir 'scripts\repo-config.ps1')                  -Force

    # .claude-plugin/marketplace.json (issue #885): every assertion in this suite is about the FOLD
    # MECHANISM against a flat, root-level CHANGELOG.md -- the isolation feature that repoints the
    # default for a consumer is tested on its own fixture, not here. Get-DefaultChangelogPath tests
    # exactly this file's presence, so this fixture reads as the workflow's SOURCE and keeps
    # everything at root, matching every path this suite already asserts on.
    New-Item -ItemType Directory -Path (Join-Path $dir '.claude-plugin') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir '.claude-plugin\marketplace.json'), '{}', $Utf8NoBom)

    # AND THE SEAM IS PATCHED BACK OUT OF THE COPIED CONFIG (August 27, 2026). The marketplace file above
    # settles what the COMPUTED default answers, and that was enough while this repo stated no changelog
    # seam. It now states one -- dkj-policy/CHANGELOG.md -- and a verbatim copy of
    # repo-config.ps1 brings that answer into the fixture, where it beats the default and points every
    # assertion in this suite at a file the fixture never wrote. Patched rather than worked around,
    # following the precedent in cut-release-drive.tests.ps1: the intent stated above is the root layout,
    # so the fixture says so in the one place that decides it. Throws if the literal changes shape, so this
    # never degrades into a silently ineffective patch.
    $foldCfgPath = Join-Path $dir 'scripts\repo-config.ps1'
    if (-not $CoLocated) {
        $foldCfg = [System.IO.File]::ReadAllText($foldCfgPath)
        $foldCfgPatched = $foldCfg -replace "(?m)^\`$script:ChangelogPath\s*=.*$", "`$script:ChangelogPath = 'CHANGELOG.md'"
        if ($foldCfgPatched -eq $foldCfg) {
            throw "fixture: could not repoint ChangelogPath to the root -- the seam literal in repo-config.ps1 changed shape."
        }
        [System.IO.File]::WriteAllText($foldCfgPath, $foldCfgPatched, $Utf8NoBom)
    }

    $clRel = Get-FixtureChangelogRel -CoLocated:$CoLocated
    $clAbs = Join-Path $dir ($clRel -replace '/', '\')
    New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($clAbs)) -Force | Out-Null
    [System.IO.File]::WriteAllText($clAbs, $script:FixtureIntro, $Utf8NoBom)
    $script:fixtures += $dir
    return $dir
}

function New-EntryFile {
    <#
        An entry file in the current shape: the change's own heading at the entry level, then its named
        sections one level under it -- both composed from the seams rather than typed, so this fixture
        cannot become a second definition of the format. -Rows sets the impact table's data rows (the
        scaffold's own tier-0 row by default), so a test can declare a reach and a significance without
        hand-building the file.
    #>
    param(
        [string]$Dir, [string]$Name, [string]$Title,
        [string]$Rows = '| 0 | - | - |',
        [string]$Type = 'Feat',
        [string]$ExtraBody = ''
    )
    $lines = @("$foldEntryH $Title", '', "$foldSectH What does this change do?", '', 'Demo entry body.')
    if ($ExtraBody) { $lines += @('', $ExtraBody) }
    $lines += @(
        '', "$foldSectH Who is this for", '',
        '| Tier | Significance | Why |', '|---|---|---|', $Rows,
        '', "$foldSectH Type of change", '', $Type
    )
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), (($lines -join "`n") + "`n"), $Utf8NoBom)
}

function New-LegacyEntryFile {
    <#
        An entry file in the shape written BEFORE this format: a heading carrying the type (and a
        scaffolded date) as middot fields, with a 'Tier: N' line under it instead of an impact table.
        Why the heading sits one level BELOW an entry rather than at the digit it was written at is at
        the composition below.

        NOT A HISTORICAL CURIOSITY. An entry file lives only on a branch, so any branch created before this
        change still carries one -- this repo had exactly such a branch parked on the remote when the change
        was written. -NoTierLine leaves the line out, which is the undeclared (= tier 0) case.
    #>
    param([string]$Dir, [string]$Name, [string]$Title, [string]$Tier = '0', [switch]$NoTierLine, [string]$ExtraBody = '')
    $md = [char]0x00B7
    $tierLine = if ($NoTierLine) { '' } else { "Tier: $Tier`n`n" }
    # ONE LEVEL SHALLOWER THAN AN ENTRY -- the flat-window level (August 5-26, 2026), expressed as that
    # relationship rather than as a number. What makes this shape legacy is not a digit but that it is NOT the
    # entry level, so the fold has to re-level it before pasting or it would be absorbed into the entry above
    # and inherit its PR link. It was '(Get-EntryHeadingLevel) + 1' from August 26, 2026 until issue #1344 --
    # an H4 no entry has ever opened with, chosen to keep "one deeper than the entry" true after the level
    # moved to 3. That followed the old detector range rather than the tree: the shape that actually sits on
    # parked branches is the flat-window H2, and 'entryLevel - 1' is both a real level and the one
    # Test-IsChangelogEntryFile recognises after #1344.
    $legacyH = '#' * ((Get-EntryHeadingLevel) - 1)
    $body = "$legacyH $Title $md Feat $md 2026-01-01`n`n$tierLine" + "Demo entry body.`n" + $ExtraBody
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), $body, $Utf8NoBom)
}

function New-FlatWindowEntryFile {
    <#
        An entry file in the shape a consumer carries RIGHT NOW: the current sections and impact table, but
        one level shallower -- the entry at H2 with its sections at H3, which is what every entry written in
        the flat window (August 5-26, 2026) looks like.

        THE SHAPE #953 WAS FILED FOR, and the one New-LegacyEntryFile cannot stand in for. That fixture is a
        heading plus prose, so re-levelling its first line was always enough; this one has sections BELOW its
        heading, and they have to travel with it. Lift only the heading and the entry and its own sections sit
        at ONE level, which Split-EntryBlocks reads as four entries -- a worse defect than the stray heading
        it was fixing.

        EXPRESSED AS 'one shallower than the entry level' rather than as the literal '##', deliberately. The
        levels have moved twice; what makes this shape the interesting one is the RELATIONSHIP -- sections
        exactly where the current entry heading sits -- and that survives the next move.
    #>
    param([string]$Dir, [string]$Name, [string]$Title, [string]$Rows = '| 0 | - | - |', [string]$Type = 'Feat')
    $entryH = '#' * ((Get-EntryHeadingLevel) - 1)
    $sectH  = '#' * (Get-EntryHeadingLevel)
    $lines = @(
        "$entryH $Title", '',
        "$sectH What does this change do?", '', 'Demo entry body.',
        '', "$sectH Who is this for", '',
        '| Tier | Significance | Why |', '|---|---|---|', $Rows,
        '', "$sectH Type of change", '', $Type
    )
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), (($lines -join "`n") + "`n"), $Utf8NoBom)
}

function New-DocFile {
    # An H1 markdown doc (a meta file), NOT an entry.
    param([string]$Dir, [string]$Name, [string]$Heading)
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), "# $Heading`n`nSome prose.`n", $Utf8NoBom)
}

function Get-Changelog {
    param([string]$Dir, [switch]$CoLocated)
    $rel = Get-FixtureChangelogRel -CoLocated:$CoLocated
    return [System.IO.File]::ReadAllText((Join-Path $Dir ($rel -replace '/', '\')))
}

function Get-EntryOrder {
    <#
        The entry headings in document order -- which is the ONE thing the fold decides now that there are no
        sections to file into. Asserted as an ordered list rather than as "the title appears somewhere",
        because the latter passes on every possible ordering, including the reverse.
    #>
    param([string]$Changelog)
    return @([regex]::Matches($Changelog, ('(?m)^' + $foldEntryH + ' (.+)$')) | ForEach-Object { $_.Groups[1].Value.Trim() })
}

function Get-ChangelogIntro {
    <#
        The intro's PROSE: everything above the first entry heading, with the pending tally taken back
        out. The fold must never write into the prose.

        THE TALLY IS THE ONE THING IT MAY WRITE THERE (issue #1515), and excluding it here is what keeps
        the two asserts below saying what they were written to say. That line lives in the document's head
        by design -- it is derived from the entries and refreshed on every fold, so a byte-identical head
        would mean the fold had NOT refreshed it. Stripping it leaves the original guarantee exactly as
        strong: the repo's own intro paragraphs come back unchanged, and an entry written into the middle
        of them still fails. The tally's own correctness is asserted separately, right after each caller,
        so nothing about it is merely tolerated here.
    #>
    param([string]$Changelog)
    $m = ([regex]('(?m)^' + $foldEntryH + ' ')).Match($Changelog)
    $intro = if ($m.Success) { $Changelog.Substring(0, $m.Index) } else { $Changelog }
    $markerRx = [regex]::Escape((Get-ChangelogPendingSummaryMarker))
    return ((@($intro -split "`r?`n") | Where-Object { $_ -notmatch $markerRx }) -join "`n")
}

function Initialize-FoldGitRepo {
    <# Turn a fixture into a real git repo with the baseline committed, so -Commit has something to
       commit ONTO.

       Identity, autocrlf and commit.gpgsign are all set LOCALLY. Identity, because a machine without a
       global user.email would otherwise fail inside the script under test and read as a defect in it.
       autocrlf, because git's "LF will be replaced by CRLF" warning goes to stderr, and on Windows
       PowerShell that is enough to fail the suite for a reason that has nothing to do with folding.
       commit.gpgsign false, because a machine with global signing on and a locked signing agent
       (op-ssh-sign, gpg) would otherwise fail the baseline commit for the same unrelated reason (#1287).

       NO '2>&1' ON A NATIVE COMMAND -- the #107 pitfall this repo documents and that its own shared-
       scripts guard exists to catch. Under ErrorActionPreference=Stop a single stderr line from git
       becomes a terminating NativeCommandError before any exit code is read. EAP is dropped to Continue
       for the duration instead. #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    # EACH CALL IS JUDGED rather than piped to Out-Null (issue #1635). The EAP is still lowered -- inside
    # the helper now -- for exactly the reason the paragraph above gives; what changed is that the exit
    # code no longer goes to Out-Null with the output. A baseline commit that fails leaves a repo with no
    # HEAD to fold onto, and every -Commit case below then fails naming the script under test.
    Invoke-FixtureGitIn $Dir init --quiet
    Invoke-FixtureGitIn $Dir config user.name  'fold test'
    Invoke-FixtureGitIn $Dir config user.email 'fold@test.invalid'
    Invoke-FixtureGitIn $Dir config core.autocrlf false
    Invoke-FixtureGitIn $Dir config commit.gpgsign false
    Invoke-FixtureGitIn $Dir add -A
    Invoke-FixtureGitIn $Dir commit -m 'baseline' --quiet
}

function Invoke-Git {
    <# Read a fact back out of a fixture repo. Same EAP discipline as above, for the same reason. #>
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return @(& git -C $Dir @GitArgs)
    } finally { $ErrorActionPreference = $prevEap }
}

function Invoke-Fold {
    # -Root: the tree the fold WRITES to, when that is not the tree its script was copied into. ship-pr.ps1
    # runs the PRIMARY checkout's copy against a throwaway worktree in exactly this shape (issue #972), so
    # the two are deliberately separable here instead of always naming the same directory.
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$Branch, [string[]]$ExtraArgs = @(), [string]$Root)
    $scriptPath = Join-Path $Dir 'scripts\release\fold-changelog-entry.ps1'
    $callArgs = @('-RepoRoot', $(if ($Root) { $Root } else { $Dir }))

    if ($PSBoundParameters.ContainsKey('Branch')) { $callArgs += @('-Branch', $Branch) }
    $callArgs += $ExtraArgs
    $prevPd  = $env:CLAUDE_PROJECT_DIR
    $prevEap = $ErrorActionPreference
    try {
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @callArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        if ($null -ne $prevPd) { $env:CLAUDE_PROJECT_DIR = $prevPd }
        $ErrorActionPreference = $prevEap
    }
    return [pscustomobject]@{ ExitCode = $code; Output = ($out -join "`n") }
}

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -- meta docs survive, real entry folds" -ForegroundColor Cyan
$dir = New-FoldFixture -Label 'metasafe'
New-EntryFile -Dir $dir -Name 'feat-demo-thing.md' -Title 'Demo thing'
New-DocFile   -Dir $dir -Name 'CONTRIBUTING.md'     -Heading 'Contributing'
New-DocFile   -Dir $dir -Name 'SECURITY.md'         -Heading 'Security Policy'
New-DocFile   -Dir $dir -Name 'CLAUDE.md'           -Heading 'Project guide'
$r = Invoke-Fold -Dir $dir
$changelogText = Get-Changelog -Dir $dir

Assert-True ($r.ExitCode -eq 0)                                              'fold-all exits 0'
Assert-True (-not (Test-Path (Join-Path $dir 'feat-demo-thing.md')))        'the genuine entry file is removed'
Assert-True ($changelogText -match 'Demo thing')                            'the entry is folded into CHANGELOG'
Assert-True (Test-Path (Join-Path $dir 'CONTRIBUTING.md'))                  'CONTRIBUTING.md survives (not folded)'
Assert-True (Test-Path (Join-Path $dir 'SECURITY.md'))                      'SECURITY.md survives (not folded)'
Assert-True (Test-Path (Join-Path $dir 'CLAUDE.md'))                        'CLAUDE.md survives (reserved)'
Assert-True ($changelogText -notmatch 'Security Policy')                    'meta content did NOT leak into CHANGELOG'
Assert-True ($changelogText -notmatch '(?m)^# Contributing')               'CONTRIBUTING body did NOT leak into CHANGELOG'
# THE ENTRY'S OWN SECTIONS CAME THROUGH AT THEIR OWN LEVEL. A replace-all rather than a count-1 would have
# lifted these three to the entry level and turned one entry into four.
Assert-Equal 1 @(Get-EntryOrder -Changelog $changelogText).Count 'the folded entry is exactly ONE entry heading, not four'
foreach ($section in @('What does this change do?', 'Who is this for', 'Type of change')) {
    Assert-True ($changelogText -match ('(?m)^' + $foldSectH + ' ' + [regex]::Escape($section) + '\s*$')) "the '$section' section kept its own level"
}
# THE HEADING IS LEFT EXACTLY AS THE AUTHOR WROTE IT (Dave, August 5, 2026). The fold used to prepend
# '#NN <midDot> ' to the title; the number is on the closing line now, where the url makes it clickable.
# Asserted as the WHOLE heading line, anchored: a prefix match would pass with anything prepended.
Assert-Equal 'Demo thing' @(Get-EntryOrder -Changelog $changelogText)[0] 'the heading is exactly the title -- nothing is prepended to it'
Assert-True ($changelogText -notmatch ('(?m)^' + $foldEntryH + ' #\d+ ' + [regex]::Escape([char]0x00B7))) 'no entry heading carries a PR number'
# And the number is not LOST, which is the whole reason it could leave the heading. This fixture has no PR
# (the fold's gh call finds nothing by design here), so the assert is on the mechanism rather than a number:
# the fold writes the number in exactly one place, and that place is the closing line.
$foldSrcText = [System.IO.File]::ReadAllText($FoldSrc, [System.Text.Encoding]::UTF8)
Assert-True ($foldSrcText -match 'Format-EntryFoldFooter') 'the closing line is still what carries the PR number'
Assert-True ($foldSrcText -match 'Set-EntryMergeStamp') 'and the merge moment is stamped on the Pull Request heading beside it'
Assert-True ($foldSrcText -notmatch '\$entryHashes #\$num') 'and the heading prepend is gone from the source, not merely unused'

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -Commit -- a reserved page never enters the commit's pathspec (#1493)" -ForegroundColor Cyan
#      Since #1437 CHANGELOG.md, CONTRIBUTING.md and README.md all live in the SAME directory
#      (dkj-policy/) the fold-all discovery loop scans for per-branch dossiers, and that loop's own
#      '*.md' glob does not know the difference on its own -- the test above covers the LEGACY root
#      scan's denylist, which this directory has its own copy of (Get-BranchFilePaths.ReservedNames)
#      that nothing exercised until this bug was found the expensive way.
#
#      TWO REAL FALSE POSITIVES, REPRODUCED AGAINST THIS REPO'S OWN TREE BEFORE THIS FIX, not a
#      hypothetical either of them: CHANGELOG.md's own newest '### DEPLOY: <branch>' heading satisfies
#      Get-BranchFileDeclaredBranch's widest pattern (built for a genuine single-branch dossier, never
#      asked whether a document holding MANY such headings might be handed to it too), so the whole
#      file read as one unfolded entry and every one of its already-folded 'Score:' pairs came back as
#      the same tier declared twice -- modelled below by the pre-existing entry in $rnChangelog.
#      dkj-policy/README.md's own title carries a backtick-quoted term with a slash in it -- exactly
#      the shape that same pattern is built to recognise -- and was folded and DELETED outright.
#
#      -CoLocated RATHER THAN UN-PATCHING THE SEAM BY HAND. This block used to re-patch repo-config.ps1
#      itself, undoing what New-FoldFixture had just written -- correct, but a second copy of the one
#      substitution that knows the seam's literal shape, in the same file that already owns it. The switch
#      says "do not repoint it" instead, so the fixture helper stays the only place that literal appears.
$dirRC = New-FoldFixture -Label 'reservedcommit' -CoLocated
$rnPaths = Get-BranchFilePaths
$rnDir = Join-Path $dirRC $rnPaths.Directory
New-Item -ItemType Directory -Path $rnDir -Force | Out-Null

# A CHANGELOG.md that already looks like production: the standard fixture intro, plus one
# already-folded entry carrying both 'Score:' lines a real folded entry always has -- same shape
# the "duplicate" fixture further down in this file already builds and proves correct.
$rnMidDot = [char]0x00B7
$rnChangelog = $script:FixtureIntro.TrimEnd() + "`n`n" + ((@(
    "$foldEntryH DEPLOY: fix/already-folded $rnMidDot 20260101-000000", '',
    'Some already-folded change.', '',
    '**Score:** 3', '',
    "$foldSectH What makes this deploy extra special", '',
    'N/A', '',
    '**Score:** N/A', ''
) -join "`n"))
[System.IO.File]::WriteAllText((Join-Path $rnDir 'CHANGELOG.md'), $rnChangelog, $Utf8NoBom)
# A backtick-quoted, slash-carrying title -- the exact shape that fooled Get-BranchFileDeclaredBranch.
New-DocFile -Dir $rnDir -Name 'README.md'       -Heading ('`dkj-policy/` -- the workflow folder')
New-DocFile -Dir $rnDir -Name 'CONTRIBUTING.md' -Heading 'Contributing'

# The one REAL unfolded dossier this run should actually fold.
$rnRows = @([pscustomobject]@{ Tier = 1; Score = 4; Why = 'the real one' })
[System.IO.File]::WriteAllText((Join-Path $dirRC $rnPaths.File),
    ((Format-Development -Branch 'feat/reserved-names-v1' -Id '20260102-000000' `
        -Description 'The genuine pending change' -Type 'feat' -ImpactRows $rnRows) -join "`n") + "`n", $Utf8NoBom)

# -Commit, not a dry run: the CI workflow issue #1493 adds runs this exact fold-all mode with
# -Commit -Push, so proving the reserved files survive ON DISK is not the same proof as showing
# they never entered the commit's own pathspec (Sebastian #23's pre-merge review of this branch).
Initialize-FoldGitRepo -Dir $dirRC
$rRC = Invoke-Fold -Dir $dirRC -ExtraArgs @('-Commit')
Assert-True ($rRC.ExitCode -eq 0) 'reserved commit: exits 0 -- CHANGELOG/README/CONTRIBUTING do not choke the pre-pass'
$rnChangelogAfter = [System.IO.File]::ReadAllText((Join-Path $rnDir 'CHANGELOG.md'))
Assert-True ($rnChangelogAfter -match 'The genuine pending change')        'reserved commit: the real dossier still folds'
Assert-True ($rnChangelogAfter -match 'Some already-folded change')        'reserved commit: the pre-existing entry survives untouched'
Assert-True (Test-Path -LiteralPath (Join-Path $rnDir 'CHANGELOG.md'))     'reserved commit: CHANGELOG.md itself survives -- not folded away as an entry'
Assert-True (Test-Path -LiteralPath (Join-Path $rnDir 'README.md'))       'reserved commit: README.md survives'
$rnCommitFiles = @(Invoke-Git -Dir $dirRC -GitArgs @('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'))
Assert-True ($rnCommitFiles -contains "$($rnPaths.Directory)/CHANGELOG.md") 'reserved commit: -Commit -- CHANGELOG.md is in the commit (the real fold)'
Assert-True (-not ($rnCommitFiles -contains "$($rnPaths.Directory)/README.md"))       'reserved commit: -Commit -- README.md is NOT in the commit'
Assert-True (-not ($rnCommitFiles -contains "$($rnPaths.Directory)/CONTRIBUTING.md")) 'reserved commit: -Commit -- CONTRIBUTING.md is NOT in the commit'
Assert-True (Test-Path -LiteralPath (Join-Path $rnDir 'CONTRIBUTING.md')) 'reserved commit: CONTRIBUTING.md survives'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dirRC $rnPaths.File))) 'reserved commit: the real dossier is removed after folding'

# ---------------------------------------------------------------------------------------------------
Write-Host "The intro is written below, never over" -ForegroundColor Cyan
#      There is no configured heading to insert after any more, so the boundary between the intro and the
#      list is derived structurally -- the first entry heading. Getting that wrong writes an entry into the
#      middle of the intro, which is why it is asserted rather than assumed.
Assert-True ((Get-ChangelogIntro -Changelog $changelogText).TrimEnd() -eq $script:FixtureIntro.TrimEnd()) `
    'the intro is byte-identical after the fold'

# AND THE ONE LINE THE FOLD MAY WRITE INTO THE HEAD IS THERE, AND COUNTS (issue #1515). The assert above
# proves the prose survives; this proves the tally was actually refreshed rather than merely tolerated by
# the strip. Asserted from the REAL fold's output, which is the half the pure suite cannot give: it is the
# only proof the call site runs at all, in a script whose own suite is the one that would notice.
$tallyLines = @(@($changelogText -split "`r?`n") | Where-Object { $_ -match [regex]::Escape((Get-ChangelogPendingSummaryMarker)) })
Assert-Equal 1 $tallyLines.Count 'the fold writes exactly one pending tally'
# THE TOTAL IS THE NUMBER DIRECTLY BEFORE THE BUMP WORD, in both shapes the line has (#1545): with an
# audience tier it reads '**4 / 9 minor entries**' and without one '**9 minor entries**'. Matching that
# position rather than either whole shape is deliberate -- this suite's subject is that the fold CALLED
# the tally at all, and the shapes themselves are entry-scaffold.tests.ps1's to pin.
$tallyTotalRx = '(\d+) \S+ (?:entry|entries)\*\*'
Assert-True ($tallyLines[0] -match $tallyTotalRx) 'and it states how many entries are pending'
Assert-Equal (@(Get-ChangelogEntryBlocks -Content $changelogText).Count) ([int]([regex]::Match($tallyLines[0], $tallyTotalRx).Groups[1].Value)) `
    'and the number it states is the number of entries actually in the document'
Assert-True ((Get-Changelog -Dir $dir).IndexOf('Demo thing') -gt $script:FixtureIntro.TrimEnd().Length) `
    'and the entry sits below all of it'

# ---------------------------------------------------------------------------------------------------
Write-Host "A changelog with nothing pending yet -- the first entry opens the list" -ForegroundColor Cyan
#      This replaces the retired "could not find the '## Pull Requests' heading -- stopping" refusal. That
#      path existed because the fold needed a configured heading to exist in the file; it now needs none, so
#      the case it refused over is the ordinary empty-list case and must simply work.
$dirE = New-FoldFixture -Label 'emptylist'
New-EntryFile -Dir $dirE -Name 'feat-first-ever.md' -Title 'The first one'
$rE = Invoke-Fold -Dir $dirE
$clE = Get-Changelog -Dir $dirE
Assert-True ($rE.ExitCode -eq 0)                     'empty list: exits 0 rather than refusing over a missing heading'
Assert-Equal 'The first one' (@(Get-EntryOrder -Changelog $clE))[0] 'empty list: the entry becomes the list'
# THE BLANK LINE IS ENSURED, NOT ASSUMED. An intro whose last line had no blank line after it would leave
# '...releases/README.md.## The first one' -- which markdown renders as one paragraph and no heading at all,
# so nothing would look broken until a parser went looking for the entry.
Assert-True ($clE -match ('(?m)^\s*$[\r\n]+' + $foldEntryH + ' The first one')) 'empty list: with a blank line between the intro and the heading'

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -- a consumer-extended prefix still folds" -ForegroundColor Cyan
$dir2 = New-FoldFixture -Label 'extprefix'
New-EntryFile -Dir $dir2 -Name 'style-tweak-colors.md' -Title 'Tweak colors'
$r2 = Invoke-Fold -Dir $dir2
Assert-True ($r2.ExitCode -eq 0)                                            'fold-all (ext prefix) exits 0'
Assert-True (-not (Test-Path (Join-Path $dir2 'style-tweak-colors.md')))    'extended-prefix entry is folded (not prefix-gated)'
Assert-True ((Get-Changelog -Dir $dir2) -match 'Tweak colors')             'extended-prefix entry lands in CHANGELOG'

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -- an H1 doc with a hyphenated name is NOT folded" -ForegroundColor Cyan
$dir3 = New-FoldFixture -Label 'hyphendoc'
New-DocFile -Dir $dir3 -Name 'my-loose-notes.md' -Heading 'My loose notes'
$r3 = Invoke-Fold -Dir $dir3
Assert-True ($r3.ExitCode -eq 0)                                            'fold-all (hyphen doc) exits 0'
Assert-True (Test-Path (Join-Path $dir3 'my-loose-notes.md'))               'a hyphenated H1 doc is not treated as an entry'

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -- a flat-window entry file (one level below the entry level) IS folded (issue #1344)" -ForegroundColor Cyan
#      Test-IsChangelogEntryFile ranged UP from the entry level ('#{level,level+1}'), so once the level
#      reached 3 fold-all recognised H3-or-H4 and no longer the H2 every flat-window entry (August 5-26,
#      2026) carries -- and a root entry file at that level was skipped SILENTLY, never folded, nothing said.
$dir3b = New-FoldFixture -Label 'flatwindow-foldall'
New-LegacyEntryFile -Dir $dir3b -Name 'feat-parked-in-the-flat-window.md' -Title 'Parked in the flat window' -Tier '1'
$r3b = Invoke-Fold -Dir $dir3b
Assert-True ($r3b.ExitCode -eq 0)                                           'fold-all (flat-window entry) exits 0'
Assert-True (-not (Test-Path (Join-Path $dir3b 'feat-parked-in-the-flat-window.md'))) 'the flat-window entry file is recognised and removed'
Assert-True ((Get-Changelog -Dir $dir3b) -match 'Parked in the flat window') 'and its content lands in CHANGELOG.md'
Assert-Equal 1 @(Get-EntryOrder -Changelog (Get-Changelog -Dir $dir3b)).Count 'folded as exactly one entry -- the block was re-levelled whole, not split'

# ---------------------------------------------------------------------------------------------------
Write-Host "-Branch mode -- folds exactly the named entry" -ForegroundColor Cyan
$dir4 = New-FoldFixture -Label 'branchmode'
New-EntryFile -Dir $dir4 -Name 'fix-explicit-target.md' -Title 'Explicit target'
New-DocFile   -Dir $dir4 -Name 'CONTRIBUTING.md'        -Heading 'Contributing'
$r4 = Invoke-Fold -Dir $dir4 -Branch 'fix/explicit-target'
Assert-True ($r4.ExitCode -eq 0)                                            '-Branch mode exits 0'
Assert-True (-not (Test-Path (Join-Path $dir4 'fix-explicit-target.md')))   '-Branch folds the named entry'
Assert-True ((Get-Changelog -Dir $dir4) -match 'Explicit target')          '-Branch entry lands in CHANGELOG'
Assert-True (Test-Path (Join-Path $dir4 'CONTRIBUTING.md'))                'CONTRIBUTING.md untouched in -Branch mode'

# ---------------------------------------------------------------------------------------------------
Write-Host "Committing is opt-in, and the default is unchanged" -ForegroundColor Cyan
#      The fold has always left its result uncommitted. That stays the default: this commit lands on the
#      main branch under a named exception, so it has to be asked for.
$dir8 = New-FoldFixture -Label 'nocommit'
Initialize-FoldGitRepo -Dir $dir8
New-EntryFile -Dir $dir8 -Name 'fix-no-commit.md' -Title 'Not committed'
$r8 = Invoke-Fold -Dir $dir8
Assert-True ($r8.ExitCode -eq 0)                                            'default: exits 0'
$status8 = (Invoke-Git -Dir $dir8 -GitArgs @('status', '--porcelain')) -join "`n"
Assert-True ($status8 -match 'CHANGELOG\.md')                              'default: the fold is left in the working tree, uncommitted'
Assert-True (@(Invoke-Git -Dir $dir8 -GitArgs @('log', '--oneline')).Count -eq 1) 'default: no commit was made'

# ---------------------------------------------------------------------------------------------------
Write-Host "-Commit commits the fold, and names the branch and PR in the subject" -ForegroundColor Cyan
#      Entry file created BEFORE the repo is initialised, so it is tracked -- which mirrors the real
#      flow, where the entry was committed on the branch and arrived on main with the merge.
$dir9 = New-FoldFixture -Label 'commit'
New-EntryFile -Dir $dir9 -Name 'fix-commits-itself.md' -Title 'Commits itself'
Initialize-FoldGitRepo -Dir $dir9
$r9 = Invoke-Fold -Dir $dir9 -ExtraArgs @('-Commit')
Assert-True ($r9.ExitCode -eq 0)                                            '-Commit: exits 0'
$subject9 = ((Invoke-Git -Dir $dir9 -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()
Assert-True ($subject9 -match '^fold: fix/commits-itself changelog') `
    '-Commit: the subject follows the established format and names the branch'
# The type is asserted on its own, because it is the half a rename would silently take away: this
# fixture has no PR to look up, so the branch name alone would still match a subject typed anything.
Assert-True ($subject9 -notmatch '^chore:') `
    '-Commit: the fold is typed as a fold, not as generic housekeeping'
Assert-True ((((Invoke-Git -Dir $dir9 -GitArgs @('status', '--porcelain')) -join '').Trim()) -eq '') `
    '-Commit: the working tree is clean afterwards -- nothing half-done is left behind'

# ---------------------------------------------------------------------------------------------------
Write-Host "-Commit on a fold-all run names every entry it folded" -ForegroundColor Cyan
#      THE RARE HALF, AND THE ONE NOBODY WATCHES. Measured on August 10, 2026: of 410 fold commits in
#      this repo's history exactly ONE folded more than one entry, and it did so under wording that has
#      been replaced twice since -- so the plural subject the script writes today has never been produced
#      by a real run. That is precisely why it needs a test: it is a commit that lands directly on main
#      under a named exception, written by a code path no reviewer has ever seen the output of.
#
#      "We only ever merge one PR at a time" is true and does not close it. Two entries reach one fold
#      two ways that have nothing to do with merging twice: a fold-all run (no -Branch) picks up every
#      legacy root entry, which is the normal state of a consumer that has not migrated to branch/; and
#      even -Branch mode folds branch/branch-deployment.md AND a legacy <branch>.md together when both
#      exist.
$dir11 = New-FoldFixture -Label 'commitplural'
New-EntryFile -Dir $dir11 -Name 'fix-plural-one.md' -Title 'First of two'
New-EntryFile -Dir $dir11 -Name 'docs-plural-two.md' -Title 'Second of two'
Initialize-FoldGitRepo -Dir $dir11
$r11 = Invoke-Fold -Dir $dir11 -ExtraArgs @('-Commit')
Assert-True ($r11.ExitCode -eq 0)                                           '-Commit fold-all: exits 0'
$subject11 = ((Invoke-Git -Dir $dir11 -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()
Assert-True ($subject11 -match '^fold: 2 changelogs: ') `
    '-Commit fold-all: the plural subject counts the entries and is typed as a fold'
# Both names, not just the first: a subject that silently described half of what the commit did would be
# worse than one that described none of it, because it reads as complete.
Assert-True ($subject11 -match 'plural-one') `
    '-Commit fold-all: the first entry is named in the subject'
Assert-True ($subject11 -match 'plural-two') `
    '-Commit fold-all: the second entry is named too, so the subject describes the whole commit'
Assert-True ((Get-Changelog -Dir $dir11) -match 'First of two') `
    '-Commit fold-all: the first entry really landed in CHANGELOG.md'
Assert-True ((Get-Changelog -Dir $dir11) -match 'Second of two') `
    '-Commit fold-all: the second entry landed too'
Assert-True ((((Invoke-Git -Dir $dir11 -GitArgs @('status', '--porcelain')) -join '').Trim()) -eq '') `
    '-Commit fold-all: the working tree is clean afterwards'

# THE SCOPE PROPERTY, which is the whole reason this may commit to main at all. An unrelated modified
# file -- and one already STAGED, which is the case a plain 'git commit' would sweep in -- must not end
# up in the fold commit.
$dir10 = New-FoldFixture -Label 'commitscope'
New-EntryFile -Dir $dir10 -Name 'fix-scope.md' -Title 'Scoped'
Initialize-FoldGitRepo -Dir $dir10
[System.IO.File]::WriteAllText((Join-Path $dir10 'UNRELATED.md'), "# Not part of the fold`n", $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $dir10 'STAGED.md'),    "# Staged before the fold ran`n", $Utf8NoBom)
Invoke-Git -Dir $dir10 -GitArgs @('add', 'STAGED.md') | Out-Null
$r10 = Invoke-Fold -Dir $dir10 -ExtraArgs @('-Commit')
Assert-True ($r10.ExitCode -eq 0)                                           'scope: exits 0'
$touched10 = @((Invoke-Git -Dir $dir10 -GitArgs @('show', '--name-only', '--pretty=format:', 'HEAD')) | Where-Object { $_ })
Assert-True ($touched10.Count -eq 2)                                        'scope: the commit holds exactly two paths'
Assert-True (($touched10 -contains 'CHANGELOG.md') -and ($touched10 -contains 'fix-scope.md')) `
    'scope: and they are CHANGELOG.md plus the entry file'
Assert-True ($touched10 -notcontains 'STAGED.md')                          'scope: a file staged before the run is NOT swept into the fold commit'
Assert-True ($touched10 -notcontains 'UNRELATED.md')                       'scope: and neither is an unrelated modified file'

# ---------------------------------------------------------------------------------------------------
Write-Host "The entry file's deletion is part of the commit, not left dangling" -ForegroundColor Cyan
#      The fold removes the entry file from disk. If the commit recorded only CHANGELOG.md, the deletion
#      would sit unstaged afterwards -- an unfolded-looking entry file returning on the next checkout,
#      which is exactly the silent half-state this repo keeps rediscovering.
$statusKind10 = (Invoke-Git -Dir $dir10 -GitArgs @('show', '--name-status', '--pretty=format:', 'HEAD')) -join "`n"
Assert-True ($statusKind10 -match '(?m)^D\s+fix-scope\.md')                'the entry file is recorded as deleted in the commit'

# ---------------------------------------------------------------------------------------------------
Write-Host "The FIRST fold after a release cut -- into an empty '## [Unreleased]' -- folds and commits (issue #1564)" -ForegroundColor Cyan
#      THE ONE CHANGELOG STATE NO OTHER CASE IN THIS SUITE REACHES: '## [Unreleased]' present, its list
#      empty, and the pending tally still the post-cut sentence. fold-changelog-entry.ps1 read $insertPos
#      (a byte offset) against the pre-tally content, then Set-ChangelogPendingSummary rebuilt the document
#      into a NEW string -- shorter, because the sentinel sentence is the longest tally this repo writes and
#      a counted one replacing it shrinks the file -- and the console-line code one step later ran
#      $changelogContent.Substring($insertPos + $entryBlock.Length) against the now-stale offset and threw
#      'startIndex cannot be larger than the length of the string'. It threw AFTER the write and the
#      entry-file delete and BEFORE the commit block, so '-Commit -Push' silently did neither and the fold
#      sat uncommitted on the trunk -- with the entry file gone, so check-unfolded-entry.ps1 saw nothing.
#
#      THE FIXTURE IS THE POST-CUT DOCUMENT, composed from the libs so it cannot drift from what
#      cut-release.ps1 actually leaves: the '## [Unreleased]' heading and Format-ChangelogPendingSummary's
#      own empty-list sentence, marker and all.
$dirEU = New-FoldFixture -Label 'empty-unreleased'
$emptyTally = Format-ChangelogPendingSummary -Content ''
$postCutDoc = $script:FixtureIntro.TrimEnd() + "`n`n" + ((@($foldPendH, '', $emptyTally, '')) -join "`n")
[System.IO.File]::WriteAllText((Join-Path $dirEU 'CHANGELOG.md'), $postCutDoc, $Utf8NoBom)
New-EntryFile -Dir $dirEU -Name 'fix-first-after-cut.md' -Title 'The first entry of the cycle' -Rows '| 0 | - | - |'
Initialize-FoldGitRepo -Dir $dirEU
$rEU = Invoke-Fold -Dir $dirEU -ExtraArgs @('-Commit')

Assert-True ($rEU.ExitCode -eq 0)                                          'empty unreleased: the run exits 0 rather than dying in Substring'
Assert-True ($rEU.Output -notmatch 'startIndex')                           'empty unreleased: no startIndex range error reaches the output'
Assert-True ($rEU.Output -notmatch 'Substring')                            'empty unreleased: nothing throws out of the console-line block'
$clEU = (Get-Changelog -Dir $dirEU) -replace "`r`n", "`n"
Assert-Equal 'The first entry of the cycle' (@(Get-EntryOrder -Changelog $clEU)[0]) 'empty unreleased: the entry landed in the list'
Assert-Equal 1 @(Get-EntryOrder -Changelog $clEU).Count                    'empty unreleased: exactly one entry, not a stray heading'
Assert-True ($clEU -match '(?m)^## \[Unreleased\]\s*$')                    'empty unreleased: the pending heading survived the fold'
Assert-True ($clEU -notmatch [regex]::Escape($emptyTally))                 'empty unreleased: the post-cut sentence was replaced, not left standing'
Assert-True ($clEU -match ([regex]::Escape((Get-ChangelogPendingSummaryMarker)))) 'empty unreleased: the refreshed tally still carries the marker'
Assert-True ($rEU.Output -match 'placed above 0 existing entries')         'empty unreleased: the position line -- the one that threw -- now prints'
# THE HALF THAT MATTERS: the crash sat between the write and the commit, so exit 0 alone is not the proof --
# the fold must actually be committed, with a clean tree behind it.
Assert-True ((((Invoke-Git -Dir $dirEU -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()) -match '^fold: fix/first-after-cut changelog') `
    'empty unreleased: -Commit really committed the fold'
Assert-True ((((Invoke-Git -Dir $dirEU -GitArgs @('status', '--porcelain')) -join '').Trim()) -eq '') `
    'empty unreleased: and the working tree is clean afterwards -- nothing left uncommitted'
Assert-True (-not (Test-Path (Join-Path $dirEU 'fix-first-after-cut.md'))) 'empty unreleased: the entry file was removed as part of the fold'

# ---------------------------------------------------------------------------------------------------
Write-Host "An entry git never tracked does not break the commit" -ForegroundColor Cyan
#      Found by this suite before it reached anyone: naming an untracked path makes 'git commit' fail on
#      the pathspec -- and by then the fold has already deleted the file, so the run ends with the
#      changelog updated, the entry gone and nothing committed. The normal flow never hits it (the entry
#      arrives on main with the merge), which is precisely why it would have waited for the one time
#      somebody folded an entry they had not committed.
$dir11 = New-FoldFixture -Label 'untracked'
Initialize-FoldGitRepo -Dir $dir11
New-EntryFile -Dir $dir11 -Name 'fix-never-committed.md' -Title 'Never committed'
$r11 = Invoke-Fold -Dir $dir11 -ExtraArgs @('-Commit')
Assert-True ($r11.ExitCode -eq 0)                                          'untracked entry: exits 0 rather than failing on the pathspec'
Assert-True ($r11.Output -match 'git never tracked them')                  'untracked entry: and says which file was left out of the commit'
$touched11 = @((Invoke-Git -Dir $dir11 -GitArgs @('show', '--name-only', '--pretty=format:', 'HEAD')) | Where-Object { $_ })
Assert-True ($touched11 -contains 'CHANGELOG.md')                          'untracked entry: the changelog is still committed'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dir11 'fix-never-committed.md'))) `
    'untracked entry: and the entry file is still folded away'

# ===================================================================================================
# THE ORDER OF THE FLAT LIST: tier first, significance second (Dave, August 5, 2026; issue #467)
# ===================================================================================================
# This is what the three '## Tier N - Pull Requests' headings used to communicate visually, kept as an
# ordering rather than as structure. The unit tests in entry-scaffold.tests.ps1 prove the offset function;
# these prove the FOLD uses it, through the real script, against a real file.

Write-Host "Significance orders entries within a tier" -ForegroundColor Cyan
$dirS = New-FoldFixture -Label 'impact-order'
# Folded LOW first, then middling, then HIGH -- so a fold that merely prepends (the pre-ranking behaviour)
# would leave them in exactly the reverse of the wanted order. Only real ordering can pass this.
New-EntryFile -Dir $dirS -Name 'feat-low.md'  -Title 'Least consequential' -Rows '| 1 | 1 | cosmetic |'
$rLow = Invoke-Fold -Dir $dirS -Branch 'feat/low'
New-EntryFile -Dir $dirS -Name 'feat-mid.md'  -Title 'Middling'            -Rows '| 1 | 3 | a clear improvement |'
$rMid = Invoke-Fold -Dir $dirS -Branch 'feat/mid'
New-EntryFile -Dir $dirS -Name 'feat-high.md' -Title 'Most consequential'  -Rows '| 1 | 5 | the reader must act |'
$rHigh = Invoke-Fold -Dir $dirS -Branch 'feat/high'
Assert-True (($rLow.ExitCode -eq 0) -and ($rMid.ExitCode -eq 0) -and ($rHigh.ExitCode -eq 0)) 'impact order: all three folds exit 0'
$orderS = @(Get-EntryOrder -Changelog (Get-Changelog -Dir $dirS))
Assert-Equal 'Most consequential' $orderS[0] 'impact order: significance 5 leads'
Assert-Equal 'Middling'           $orderS[1] 'impact order: then 3'
Assert-Equal 'Least consequential' $orderS[2] 'impact order: then 1 -- so the fold ordered, not prepended'

Write-Host "The tier is the FIRST key -- reach beats weight" -ForegroundColor Cyan
#      The failure this guards is the one measured on the offset function's first run: a repo-internal change
#      leading the document. A tier-0 entry with the top score must still sink below a tier-1 entry with the
#      bottom one, or the flat list has lost the distinction the three headings used to make.
$dirT = New-FoldFixture -Label 'tier-order'
New-EntryFile -Dir $dirT -Name 'chore-internal.md' -Title 'Repo internal only' -Rows '| 0 | - | - |'
Invoke-Fold -Dir $dirT -Branch 'chore/internal' | Out-Null
New-EntryFile -Dir $dirT -Name 'docs-colleague.md' -Title 'For colleagues' -Rows '| 1 | 1 | barely anything |'
Invoke-Fold -Dir $dirT -Branch 'docs/colleague' | Out-Null
New-EntryFile -Dir $dirT -Name 'feat-consumer.md' -Title 'Consumer facing' -Rows "| 2 | 2 | small |`n| 1 | 2 | small |"
$rT = Invoke-Fold -Dir $dirT -Branch 'feat/consumer'
Assert-True ($rT.ExitCode -eq 0) 'tier order: exits 0'
$orderT = @(Get-EntryOrder -Changelog (Get-Changelog -Dir $dirT))
Assert-Equal 'Consumer facing'    $orderT[0] 'tier order: the tier-2 entry leads on a score of 2'
Assert-Equal 'For colleagues'     $orderT[1] 'tier order: the tier-1 entry follows on a score of 1'
Assert-Equal 'Repo internal only' $orderT[2] 'tier order: and the tier-0 entry sinks, whatever it scores'

# ===================================================================================================
# WHAT THE FOLD CARRIES, AND WHAT IT NO LONGER CONSUMES
# ===================================================================================================
# A REVERSAL, not a relaxation, and the asserts below are inverted from what they were the day before.
# While the changelog had one section per tier, the heading above an entry stated its reach -- so the
# entry's own 'Tier: N' line was the same fact twice, and an unscored table was a question nobody had put.
# With the sections gone the entry is the only carrier of both.

Write-Host "A scored impact table is carried into the record" -ForegroundColor Cyan
#      Unchanged behaviour, and the reason is the two-moment property: the cut empties the pending list, so a
#      score consumed here would not exist when the release documents are built days later, and the ordering
#      could not be reproduced without re-estimating it.
$clS = Get-Changelog -Dir $dirS
Assert-True ($clS -match '(?m)^\|\s*1\s*\|\s*5\s*\|') 'scored table: the row survives the fold'
Assert-True ($clS -match 'the reader must act')        'scored table: including its Why, which is the lasting half'

Write-Host "An UNSCORED table is carried too, because its section names a question" -ForegroundColor Cyan
#      This is the inversion. The scaffold row used to be stripped as "a question nobody was asked", which was
#      right while a heading stated the tier. Now '### Who is this for' is a named section of the entry, and a
#      heading with its answer cut out is worse than a placeholder: the reader cannot tell "nobody was asked"
#      from "somebody deleted it". Worse, stripping it would leave the entry declaring no reach at all.
$dirU = New-FoldFixture -Label 'impact-unscored'
New-EntryFile -Dir $dirU -Name 'chore-internal.md' -Title 'Repo internal' -Rows '| 0 | - | - |'
$rU = Invoke-Fold -Dir $dirU
Assert-True ($rU.ExitCode -eq 0) 'unscored table: exits 0'
$clU = Get-Changelog -Dir $dirU
Assert-True ($clU -match 'Repo internal')                        'unscored table: the entry is folded'
Assert-True ($clU -match '(?m)^\|\s*Tier\s*\|\s*Significance\s*\|') 'unscored table: and its table is still there'
Assert-True ($clU -match '(?m)^\|\s*0\s*\|\s*-\s*\|\s*-\s*\|')   'unscored table: scaffold row and all, so the reach is still declared'

Write-Host "A pre-format entry keeps its Tier: line and is re-levelled to the entry level" -ForegroundColor Cyan
#      Both halves matter, and both are inversions of the old behaviour. The line SURVIVES because nothing
#      above the entry states the tier any more -- consuming it would make the entry read back as tier 0 and
#      drop silently out of the release documents. And the heading is RE-LEVELLED, because a heading below the
#      entry level is not an entry boundary in that list: it would be absorbed into the block above and
#      inherit its PR link.
$dirL = New-FoldFixture -Label 'impact-legacy'
New-EntryFile       -Dir $dirL -Name 'feat-current.md' -Title 'Written in the new format' -Rows '| 1 | 3 | fine |'
Invoke-Fold -Dir $dirL -Branch 'feat/current' | Out-Null
New-LegacyEntryFile -Dir $dirL -Name 'feat-old.md' -Title 'Written before the table' -Tier '2'
$rL = Invoke-Fold -Dir $dirL -Branch 'feat/old'
Assert-True ($rL.ExitCode -eq 0) 'legacy entry: exits 0'
$clL = Get-Changelog -Dir $dirL
Assert-True ($clL -match '(?m)^Tier: 2$') 'legacy entry: its Tier: line is CARRIED, so its reach survives the fold'
$orderL = @(Get-EntryOrder -Changelog $clL)
Assert-Equal 2 $orderL.Count 'legacy entry: it is an entry boundary in its own right'
Assert-True ($orderL[0] -match 'Written before the table') 'legacy entry: and its tier-2 line still ranks it above the tier-1 entry'
Assert-True ($clL -notmatch ('(?m)^' + ('#' * ((Get-EntryHeadingLevel) - 1)) + ' Written before the table')) 'legacy entry: nothing is left at the old level'
Assert-True ($rL.Output -match ('written with its entry heading at H' + ((Get-EntryHeadingLevel) - 1))) 'legacy entry: the re-levelling is reported, and it names the level the author actually wrote'

Write-Host "A stray 'Plugins:' line in the entry does not survive the fold, and the fold says so (issue #1015)" -ForegroundColor Cyan
#      THE DOUBLING THIS FIXES. fold-changelog-entry.ps1 appends the ONE authoritative 'Plugins:' line,
#      derived from the PR's touched files. An author who mirrored a folded entry's shape into the branch
#      document's '#### Pull Request' section left a second one, and the unconditional append doubled it --
#      22 reached the changelog, 8 in a single cut. This fixture declares no plugins and matches no PR, so
#      nothing is recomputed; the point is that the hand-written line is gone from the record either way,
#      and that the strip is reported rather than silent (a branch opened before the branch-entry gate
#      still reaches this line).
$dirPL = New-FoldFixture -Label 'stray-plugins'
New-EntryFile -Dir $dirPL -Name 'fix-carries-a-plugins-line.md' -Title 'Carries a stray Plugins line' -ExtraBody 'Plugins: hand-written-value'
$rPL = Invoke-Fold -Dir $dirPL -Branch 'fix/carries-a-plugins-line'
Assert-True ($rPL.ExitCode -eq 0)                              'stray Plugins: exits 0'
$clPL = Get-Changelog -Dir $dirPL
Assert-True ($clPL -match 'Carries a stray Plugins line')      'stray Plugins: the entry is folded'
Assert-True ($clPL -notmatch '(?m)^Plugins:')                  'stray Plugins: no Plugins: line survives into the changelog'
Assert-True ($clPL -notmatch 'hand-written-value')             'stray Plugins: and its value is gone with it'
Assert-True ($rPL.Output -match "carried a 'Plugins:' line")   'stray Plugins: the fold NAMES what it dropped rather than doing it silently'

Write-Host "A flat-window entry is re-levelled WHOLE -- its sections move with its heading (inbound #953)" -ForegroundColor Cyan
#      THE REGRESSION THIS SUITE COULD NOT CATCH BEFORE. The fold derived its promotion range from today's
#      entry level ('#{level,level+1}'), so once the level reached 3 it recognised H3-or-H4 and no longer H2 --
#      the level every flat-window entry carries. Measured in a consumer: the entry landed as a SIBLING of
#      '## [Unreleased]' instead of a child of it. And the near-miss repair was worse than the defect: widening
#      the range would have lifted the heading alone, leaving its H3 sections at the heading's new level, so one
#      entry reads as four. Both halves are asserted below.
$dirF = New-FoldFixture -Label 'flat-window'
New-EntryFile           -Dir $dirF -Name 'feat-current.md' -Title 'Written at the current level' -Rows '| 1 | 3 | fine |'
Invoke-Fold -Dir $dirF -Branch 'feat/current' | Out-Null
New-FlatWindowEntryFile -Dir $dirF -Name 'feat-flat.md' -Title 'Written in the flat window' -Rows '| 1 | 4 | flat |'
$rF = Invoke-Fold -Dir $dirF -Branch 'feat/flat'
Assert-True ($rF.ExitCode -eq 0) 'flat-window: exits 0'
$clF = Get-Changelog -Dir $dirF
$orderF = @(Get-EntryOrder -Changelog $clF)
Assert-Equal 2 $orderF.Count 'flat-window: TWO entries in the list -- the folded one is one entry, not four'
Assert-True ($orderF -contains 'Written in the flat window') 'flat-window: and it is an entry boundary at the current level'
Assert-True ($clF -notmatch ('(?m)^' + ('#' * ((Get-EntryHeadingLevel) - 1)) + ' Written in the flat window')) 'flat-window: nothing is left at the level it was written at'
# COUNTED, NOT MATCHED, and the count is what makes it evidence. Written as a bare -match this assert PASSED
# on the broken code: the fixture's OTHER entry was folded at the current level, so ITS '#### ' section
# satisfied the pattern while the flat entry's sections had not moved at all. Two entries, two sections.
Assert-Equal 2 (@([regex]::Matches($clF, ('(?m)^' + $foldSectH + ' What does this change do\?'))).Count) 'flat-window: its sections moved WITH it -- BOTH entries now carry one at the section level'
Assert-True ($clF -notmatch ('(?m)^' + $foldEntryH + ' What does this change do\?')) 'flat-window: so no section of it is readable as an entry of its own'
Assert-True ($rF.Output -match ('written with its entry heading at H' + ((Get-EntryHeadingLevel) - 1))) 'flat-window: the re-levelling is reported rather than done silently'

Write-Host "An entry with no declaration at all is tier 0, and says so" -ForegroundColor Cyan
$dirD = New-FoldFixture -Label 'undeclared'
New-LegacyEntryFile -Dir $dirD -Name 'chore-undeclared.md' -Title 'Nothing declared' -NoTierLine
$rD = Invoke-Fold -Dir $dirD
Assert-True ($rD.ExitCode -eq 0) 'undeclared: exits 0 -- the default is a valid answer, not an error'
Assert-True ((Get-Changelog -Dir $dirD) -match 'Nothing declared') 'undeclared: the entry is folded as tier 0, the harmless end'
# Said out loud rather than absorbed: an author who simply forgot has produced work that cannot carry a
# release on its own, and the moment to learn that is now rather than at the cut.
Assert-True ($rD.Output -match 'declares no tier') 'undeclared: the run reports that it defaulted'

Write-Host "A missing significance is reported, and folded anyway" -ForegroundColor Cyan
#      Deliberately not a refusal. Refusing the fold of an ALREADY-MERGED branch produces the silent
#      half-state this repo has measured -- an unfolded entry file in the repo root the morning after its
#      merge, with main looking finished. cut-release.ps1 is the refusal point Dave chose instead.
$dirM = New-FoldFixture -Label 'impact-noscore'
New-EntryFile -Dir $dirM -Name 'feat-unscored.md' -Title 'Reaches but unweighed' -Rows '| 1 | - | - |'
$rM = Invoke-Fold -Dir $dirM
Assert-True ($rM.ExitCode -eq 0) 'missing score: exits 0 -- the fold is not the refusal point'
Assert-True ($rM.Output -match 'declares no significance for tier 1') 'missing score: but it is said out loud'
Assert-True ($rM.Output -match 'release cut will refuse') 'missing score: and names where it WILL be refused'
Assert-True ((Get-Changelog -Dir $dirM) -match 'Reaches but unweighed') 'missing score: the entry landed'

Write-Host "A malformed table stops the run before anything is written" -ForegroundColor Cyan
$dirB = New-FoldFixture -Label 'impact-malformed'
$clBefore = Get-Changelog -Dir $dirB
New-EntryFile -Dir $dirB -Name 'feat-bad.md' -Title 'Off the scale' -Rows '| 1 | 9 | too high |'
$rB = Invoke-Fold -Dir $dirB
Assert-True ($rB.ExitCode -ne 0) 'malformed table: refuses'
Assert-True ($rB.Output -match 'off the scale') 'malformed table: and says which cell'
Assert-True ((Get-Changelog -Dir $dirB) -eq $clBefore) 'malformed table: CHANGELOG.md is untouched -- this script commits straight to main'
Assert-True (Test-Path (Join-Path $dirB 'feat-bad.md')) 'malformed table: and the entry file still exists, so nothing has to be unpicked'

Write-Host "THE PRE-PASS: one bad entry folds none of the good ones" -ForegroundColor Cyan
#      Folding writes one entry at a time, so a problem found on the second file would leave the first already
#      folded and its source file deleted -- a half-state to unpick by hand on main. So NOTHING may have
#      happened, including to the entry that was fine.
$dirP = New-FoldFixture -Label 'prepass'
$clP0 = Get-Changelog -Dir $dirP
New-EntryFile -Dir $dirP -Name 'feat-good.md' -Title 'Perfectly fine' -Rows '| 1 | 3 | fine |'
New-EntryFile -Dir $dirP -Name 'feat-worse.md' -Title 'Bad tier'      -Rows '| 5 | 3 | nonexistent tier |'
$rP = Invoke-Fold -Dir $dirP
Assert-True ($rP.ExitCode -eq 1) 'pre-pass: exits 1'
Assert-True ($rP.Output -match 'tier 5') 'pre-pass: the reason names the value'
Assert-True ((Get-Changelog -Dir $dirP) -eq $clP0) 'pre-pass: the changelog is byte-identical -- it ran before any write'
Assert-True (Test-Path -LiteralPath (Join-Path $dirP 'feat-good.md')) 'pre-pass: the VALID entry file still exists, rather than being folded first'
Assert-True (Test-Path -LiteralPath (Join-Path $dirP 'feat-worse.md')) 'pre-pass: as does the invalid one'

Write-Host "A declaration QUOTED inside a fence is not the declaration" -ForegroundColor Cyan
#      An entry documenting this format writes the thing it is explaining -- this repo's own entries for the
#      tier model and for this change both do. A blind regex would read the quoted value as the declaration.
$dirF = New-FoldFixture -Label 'fenced'
$fence = "``````text`n" + "| Tier | Significance | Why |`n|---|---|---|`n| 2 | 5 | quoted, not declared |`n" + '```' + "`n"
New-EntryFile -Dir $dirF -Name 'docs-explains.md' -Title 'Explains the format' -Rows '| 1 | 2 | the real one |' -ExtraBody "An example:`n`n$fence"
$rF = Invoke-Fold -Dir $dirF
Assert-True ($rF.ExitCode -eq 0) 'fenced: exits 0'
$clF = Get-Changelog -Dir $dirF
Assert-True ($clF -match 'the real one')            'fenced: the REAL declaration is the one folded in'
Assert-True ($clF -match 'quoted, not declared')    'fenced: and the quoted table survives inside its fence'
Assert-True ($rF.Output -notmatch 'no significance') 'fenced: the real row was read, so nothing is reported missing'

Write-Host "The branch document: folded from the branch's own path, then REMOVED" -ForegroundColor Cyan
#      The split (Dave, August 6, 2026) made the entry findable at a fixed path instead of one named after
#      the branch. Clearing it then meant rewriting it to an empty state, because deleting it would have left
#      the trunk missing a file the next branch expected.
# THAT SECOND HALF WAS REVERSED ON AUGUST 23, 2026 (Dave): the document exists for the lifetime of a branch,
# so the fold DELETES it and the trunk carries no copy between branches. AND THE FIRST HALF WAS REVERSED ON
# SEPTEMBER 3, 2026 (#1255): the name carries the branch again, so the path is one per branch rather than
# fixed. What the fixed path was defended with -- "two branches in flight cannot collide" -- is true of
# CHECKOUT and says nothing about MERGE, which is where the collision lives: every merge to the trunk left
# every OTHER open PR conflicting on that one path, and a conflicting PR gets no check suite at all, so it
# could never go green and could never merge.
# ONE DOCUMENT SINCE AUGUST 23 TOO, and writing it through the real formatter is the point: the fold has
# to find the entry as a SECTION of the branch's plan rather than as a file of its own. Writing an entry
# file and then a cycle file to the same path -- which is what this fixture did the moment the two paths
# became one -- silently left only the second, and the fold then correctly found nothing to fold.
$dirBF = New-FoldFixture -Label 'branchfiles'
$bfPaths = Get-BranchFilePaths
New-Item -ItemType Directory -Path (Join-Path $dirBF $bfPaths.Directory) -Force | Out-Null
$bfRows = @([pscustomobject]@{ Tier = 1; Score = 4; Why = 'the split' })
[System.IO.File]::WriteAllText((Join-Path $dirBF $bfPaths.File),
    ((Format-Development -Branch 'feat/branch-folder-v1' -Id '20260823-090000' `
        -Description 'Written in the branch folder' -Type 'feat' -ImpactRows $bfRows) -join "`n") + "`n", $Utf8NoBom)

$rBF = Invoke-Fold -Dir $dirBF
Assert-True ($rBF.ExitCode -eq 0) 'branch files: exits 0'
Assert-True ((Get-Changelog -Dir $dirBF) -match 'Written in the branch folder') 'branch files: the entry landed in CHANGELOG.md'

$bfChangelogPath = Join-Path $dirBF $bfPaths.Deployment
$bfProgressPath  = Join-Path $dirBF $bfPaths.Cycle
Assert-True (-not (Test-Path -LiteralPath $bfChangelogPath)) 'branch files: the document is GONE -- it lives only while a branch is open'
Assert-True (-not (Test-Path -LiteralPath $bfProgressPath)) 'branch files: which takes the step list with it, since they are sections of one file'
Assert-True ($rBF.Output -match 'Folded and removed') 'branch files: the run says it removed the file, so the reader is not sent looking for a reset copy'
Assert-True (-not ($rBF.Output -match 'reset')) 'branch files: and never says reset -- that word describes the behaviour this replaced'
# inbound #817: the fold used to be the SECOND of two out-of-band write events per cycle and said so. It
# writes nothing now, so there is nothing left to re-read and the note belongs to new-branch alone.
Assert-True (-not ($rBF.Output -match [regex]::Escape((Get-BranchFilesRereadNote)))) 'branch files: and NO re-read note -- the document is gone, so there is nothing to read again'

Write-Host "A RESET branch-deployment.md is not an entry, and is not folded" -ForegroundColor Cyan
#      The reset state opens with an H1, exactly as CONTRIBUTING.md does. This is what makes a double fold
#      impossible and what stops the trunk's own empty file being pasted into CHANGELOG.md as a change.
$dirBR = New-FoldFixture -Label 'branchreset'
New-Item -ItemType Directory -Path (Join-Path $dirBR $bfPaths.Directory) -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dirBR $bfPaths.Deployment),
    ((Format-Development -Branch '') -join "`n") + "`n", $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $dirBR $bfPaths.Cycle),
    ((Format-Development -Branch '') -join "`n") + "`n", $Utf8NoBom)
$clBR0 = Get-Changelog -Dir $dirBR
$rBR = Invoke-Fold -Dir $dirBR
Assert-True ($rBR.ExitCode -eq 0) 'reset pair: exits 0 -- nothing to fold is not an error'
Assert-True ($rBR.Output -match 'No entry files found') 'reset pair: and it says there was nothing to fold'
Assert-True ((Get-Changelog -Dir $dirBR) -eq $clBR0) 'reset pair: CHANGELOG.md is byte-identical'
Assert-True (-not ($rBR.Output -match [regex]::Escape((Get-BranchFilesRereadNote)))) 'reset pair: and NO re-read note -- this run rewrote nothing, so nothing went stale (inbound #817)'

Write-Host "fold-all -- the folder's own reserved pages are not dossiers (issue #1497)" -ForegroundColor Cyan
#      THE FOLDER SCAN SWEPT ITS OWN PERMANENT PAGES. Get-BranchFilePaths().Pattern was 'development-*.md'
#      until #1335 and carried its guard in that prefix, so the glob could not reach README.md,
#      CONTRIBUTING.md or CHANGELOG.md. #1335 widened it to '*.md' and moved the narrowing into
#      ReservedNames; the four callers Get-PerBranchDocumentRels names were converted, and this script's
#      fold-all loop was a fifth nobody counted. Then #1437 moved all three reserved pages INTO that same
#      folder, and the sweep has been reading them as unfolded dossiers ever since.
#
#      ALL THREE PASS BOTH REMAINING TESTS -- measured against this repo's live tree, September 6, 2026 --
#      which is why this fixture writes all three rather than the two the report named. CHANGELOG.md
#      declares a branch by every test here because every folded entry in it carries a '### DEPLOY: <branch>'
#      heading; README.md and CONTRIBUTING.md declare one off an ordinary backtick-quoted path in a heading.
#      The fold moves a document into the changelog and then DELETES it, so with '-Commit -Push' this
#      succeeds: it splices a real page into CHANGELOG.md, removes the page, and says nothing. #1493's CI
#      workflow runs exactly this mode on every push to the trunk.
#
#      -CoLocated IS LOAD-BEARING. With the seam repointed to the root (every other fixture in this suite)
#      the folder scan cannot reach the changelog at all, and the sharpest half of this regression -- the
#      sweep handing the fold the very file it is writing into -- is unreproducible. This fixture is the
#      production layout since #1437.
$dirRN = New-FoldFixture -Label 'reservednames' -CoLocated
New-Item -ItemType Directory -Path (Join-Path $dirRN $bfPaths.Directory) -Force | Out-Null
$rnChangelogRel = Get-FixtureChangelogRel -CoLocated
$rnChangelogAbs = Join-Path $dirRN ($rnChangelogRel -replace '/', '\')

function New-RnDossier {
    # One dossier at the branch document's own path, written through the REAL formatter -- the fixture must
    # not become a second definition of the shape the sweep reads.
    param([string]$Branch, [string]$Id, [string]$Description, [int]$Tier, [int]$Score)
    $rows = @([pscustomobject]@{ Tier = $Tier; Score = $Score; Why = 'the sweep' })
    [System.IO.File]::WriteAllText((Join-Path $dirRN $bfPaths.File),
        ((Format-Development -Branch $Branch -Id $Id -Description $Description -Type 'fix' -ImpactRows $rows) -join "`n") + "`n", $Utf8NoBom)
}

# THE CHANGELOG IS BUILT BY THE FOLD ITSELF, two entries deep, rather than hand-written. A hand-written
# stand-in is a guess at the shape the sweep reads, and a guess that drifts leaves this test passing while
# reproducing nothing -- which is the failure mode #1497 already is. Two entries, because ONE is not enough
# to reach the refusal half: each folded entry carries its own legitimate significance sections, so it takes
# two before the whole file, read as a single dossier, declares the same tier twice.
New-RnDossier -Branch 'fix/folded-the-week-before' -Id '20260901-090000' -Description 'Folded the week before' -Tier 1 -Score 3
Invoke-Fold -Dir $dirRN | Out-Null
New-RnDossier -Branch 'fix/folded-yesterday' -Id '20260905-090000' -Description 'Folded yesterday' -Tier 1 -Score 3
Invoke-Fold -Dir $dirRN | Out-Null

# The other two reserved pages, carrying the heading shapes the LIVE pages carry: an ordinary heading with
# a backtick-quoted path in it. Neither is about a branch, and both declare one by every test the sweep has.
[System.IO.File]::WriteAllText((Join-Path $dirRN ($bfPaths.Directory + '\README.md')),
    "# ``dkj-policy/`` -- the workflow's own folder in this repo`n`nSome prose.`n", $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $dirRN ($bfPaths.Directory + '\CONTRIBUTING.md')),
    "# Contributing`n`n### 2.1. Create the branch and the empty ``<branch>.md```n`nSome prose.`n", $Utf8NoBom)

# THE FIXTURE PROVES ITSELF BEFORE IT PROVES THE FIX. All three pages must pass BOTH tests the sweep applies
# after the name check -- otherwise the name check is not what is saving them here and every assert below is
# green for the wrong reason. Asserted with the real predicates, so a change to either one breaks this
# reproduction loudly instead of quietly retiring it.
#
# AND THE READ IS GUARDED, because on the unfixed script this file is already GONE by now: the two setup
# folds above swept the folder, found CHANGELOG.md declaring the branch of the entry just folded into it,
# folded it into itself and deleted it. That is #1497 in its plainest form and it happens before the run
# under test even starts -- so an unguarded read here aborts the whole suite with a FileNotFoundException
# instead of reporting a failure, and every assert after this point goes unreported too.
foreach ($rnName in @('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md')) {
    $rnPath = Join-Path $dirRN ($bfPaths.Directory + "\$rnName")
    Assert-True (Test-Path -LiteralPath $rnPath) "reserved names: fixture check -- $rnName is still there after two ordinary folds"
    if (-not (Test-Path -LiteralPath $rnPath)) { continue }
    $rnText = [System.IO.File]::ReadAllText($rnPath, [System.Text.Encoding]::UTF8)
    $rnDeclared = Get-BranchFileDeclaredBranch -Text $rnText
    Assert-True ($rnDeclared -and $rnDeclared -ne (Get-BranchTrunkName)) "reserved names: fixture check -- $rnName DECLARES a non-trunk branch, so only its name can save it"
    Assert-True (Test-BranchChangelogIsFilled -Text $rnText) "reserved names: fixture check -- $rnName reads as FILLED too, so both content tests pass it"
}

# Every reserved page's bytes BEFORE the run, so survival is asserted on content rather than on existence
# alone -- the fold rewrites as well as deletes, and a page left behind with an entry spliced out of it
# would pass a bare Test-Path.
$rnBefore = @{}
foreach ($rnName in @('README.md', 'CONTRIBUTING.md')) {
    $rnBefore[$rnName] = [System.IO.File]::ReadAllText((Join-Path $dirRN ($bfPaths.Directory + "\$rnName")))
}

# The run under test: a third, real dossier beside the three pages.
New-RnDossier -Branch 'fix/a-real-dossier' -Id '20260906-090000' -Description 'A real dossier beside the reserved pages' -Tier 2 -Score 3
$rRN = Invoke-Fold -Dir $dirRN
# Same guard, same reason: on the unfixed script there is no changelog left to read here.
$clRN = if (Test-Path -LiteralPath $rnChangelogAbs) { Get-Changelog -Dir $dirRN -CoLocated } else { '' }

Assert-True ($rRN.ExitCode -eq 0) 'reserved names: exits 0 -- the co-located pages do not make the run refuse'
Assert-True (Test-Path -LiteralPath $rnChangelogAbs) 'reserved names: CHANGELOG.md was never folded into itself and deleted'
# The real dossier still folds. Without this the fix could be "skip the whole folder" and every assert below
# would still pass while fold-all had quietly stopped doing its job.
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dirRN $bfPaths.File))) 'reserved names: the REAL dossier is still folded and removed'
Assert-True ($clRN -match 'A real dossier beside the reserved pages') 'reserved names: and its entry landed in CHANGELOG.md'
# The three pages survive, with their content untouched.
foreach ($rnName in @('README.md', 'CONTRIBUTING.md')) {
    $rnPath = Join-Path $dirRN ($bfPaths.Directory + "\$rnName")
    Assert-True (Test-Path -LiteralPath $rnPath) "reserved names: $rnName survives the sweep"
    Assert-True ((Test-Path -LiteralPath $rnPath) -and ([System.IO.File]::ReadAllText($rnPath) -eq $rnBefore[$rnName])) `
        "reserved names: $rnName is byte-identical -- not folded, and not partly rewritten either"
}
# CHANGELOG.md is the file the fold WRITES to, so it is not byte-identical and must not be. What it must
# be is grown by the one real entry and otherwise intact: its pre-existing folded entry still there, and
# no trace of itself or of the other two pages having been folded INTO it.
Assert-True ($clRN -match 'Folded the week before') 'reserved names: CHANGELOG.md keeps the entries it already held'
Assert-True ($clRN -match 'Folded yesterday') 'reserved names: both of them'
Assert-True ((Get-ChangelogIntro -Changelog $clRN).TrimEnd() -eq $script:FixtureIntro.TrimEnd()) 'reserved names: and its intro is untouched'
Assert-Equal 3 @(Get-EntryOrder -Changelog $clRN).Count 'reserved names: exactly THREE entries -- the two it held plus the one real dossier, and nothing else'
Assert-True ($clRN -notmatch "the workflow's own folder in this repo") 'reserved names: README.md was not spliced into CHANGELOG.md'
Assert-True ($clRN -notmatch '2\.1\. Create the branch') 'reserved names: nor CONTRIBUTING.md'
# The refusal half of #1497: read as ONE dossier, CHANGELOG.md's many legitimate per-entry score lines
# looked like one entry declaring a tier repeatedly, and the run died before folding anything at all.
Assert-True (-not ($rRN.Output -match 'a second time')) 'reserved names: no duplicate-tier refusal -- the changelog was never read as a single dossier'
# And the guard is the shared one rather than a sixth copy. The three-line inline sweep is what went stale
# here; asserting on the source keeps the next reader from reintroducing it and passing every assert above.
$foldSrcTextRN = [System.IO.File]::ReadAllText($FoldSrc, [System.Text.Encoding]::UTF8)
Assert-True ($foldSrcTextRN -match 'Get-PerBranchDocumentRels') 'reserved names: the fold-all sweep is Get-PerBranchDocumentRels, the one guarded listing'
Assert-True ($foldSrcTextRN -notmatch '\$foldAllPaths\.Pattern') 'reserved names: and the unguarded inline glob is gone from the source, not merely bypassed'

# ---------------------------------------------------------------------------------------------------
Write-Host "fold-all -- a reserved page is not folded even when the changelog is elsewhere (issue #1497)" -ForegroundColor Cyan
#      THE SECOND HALF OF #1497, AND THE DANGEROUS ONE. Above, CHANGELOG.md is folded into ITSELF, which is
#      loud: the run errors and the rest of the sweep never happens, so README.md survives for the wrong
#      reason. Take the changelog out of the swept folder and nothing is loud any more -- the sweep folds
#      README.md into a changelog it is not part of, deletes it, and EXITS 0. With '-Commit -Push' that is a
#      real page removed from the trunk and a corrupted changelog, reported as success.
#
#      NOT AN ARTIFICIAL LAYOUT. It is the repointed-seam layout every other fixture in this suite uses, and
#      the one a consumer folding into a root CHANGELOG.md has -- the layout Get-PreIsolationSeamPath exists
#      to keep working. So this case is live in the tree AND in every consumer that predates the folder.
$dirRE = New-FoldFixture -Label 'reservedelsewhere'
New-Item -ItemType Directory -Path (Join-Path $dirRE $bfPaths.Directory) -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dirRE ($bfPaths.Directory + '\README.md')),
    "# ``dkj-policy/`` -- the workflow's own folder in this repo`n`nSome prose.`n", $Utf8NoBom)
$reRows = @([pscustomobject]@{ Tier = 1; Score = 3; Why = 'the sweep' })
[System.IO.File]::WriteAllText((Join-Path $dirRE $bfPaths.File),
    ((Format-Development -Branch 'fix/the-only-real-one' -Id '20260906-090000' `
        -Description 'The only real dossier here' -Type 'fix' -ImpactRows $reRows) -join "`n") + "`n", $Utf8NoBom)
$reReadmePath = Join-Path $dirRE ($bfPaths.Directory + '\README.md')
$reReadmeBefore = [System.IO.File]::ReadAllText($reReadmePath)

$rRE = Invoke-Fold -Dir $dirRE
$clRE = Get-Changelog -Dir $dirRE

Assert-True ($rRE.ExitCode -eq 0) 'reserved elsewhere: exits 0'
Assert-True (Test-Path -LiteralPath $reReadmePath) 'reserved elsewhere: README.md is NOT deleted -- the silent-success case'
Assert-True ((Test-Path -LiteralPath $reReadmePath) -and ([System.IO.File]::ReadAllText($reReadmePath) -eq $reReadmeBefore)) 'reserved elsewhere: and is byte-identical'
Assert-True ($clRE -notmatch "the workflow's own folder in this repo") 'reserved elsewhere: its title was not spliced into CHANGELOG.md as an entry'
Assert-True ($clRE -match 'The only real dossier here') 'reserved elsewhere: while the real dossier still folds'
Assert-Equal 1 @(Get-EntryOrder -Changelog $clRE).Count 'reserved elsewhere: exactly ONE entry -- the dossier, and not the page beside it'
# The run said what it did, and it did not claim to have folded the page. A fold that names a reserved page
# in its output is the fold that removed it, so this catches the defect even if a future layout change made
# the deletion assert above unreachable.
Assert-True ($rRE.Output -notmatch 'README\.md') 'reserved elsewhere: and the run never names README.md at all'

Write-Host "The fold commit names both branch files" -ForegroundColor Cyan
#      The entry is modified rather than deleted now, and the step list rides along because this run
#      rewrote it. Leaving either out produces a commit that resets half the pair.
$dirBC = New-FoldFixture -Label 'branchcommit'
New-Item -ItemType Directory -Path (Join-Path $dirBC $bfPaths.Directory) -Force | Out-Null
New-EntryFile -Dir $dirBC -Name $bfPaths.Deployment -Title 'Committed from the branch folder' -Rows '| 1 | 2 | commit scope |'
[System.IO.File]::WriteAllText((Join-Path $dirBC $bfPaths.Cycle),
    ((Format-Development -Branch 'feat/commit-scope') -join "`n") + "`n", $Utf8NoBom)
Initialize-FoldGitRepo -Dir $dirBC
# An unrelated staged file, to prove the enforced scope did not widen along with the path change.
[System.IO.File]::WriteAllText((Join-Path $dirBC 'stray.txt'), "unrelated`n", $Utf8NoBom)
Invoke-Git -Dir $dirBC -GitArgs @('add', 'stray.txt') | Out-Null

$rBC = Invoke-Fold -Dir $dirBC -ExtraArgs @('-Commit')
Assert-True ($rBC.ExitCode -eq 0) 'fold commit: exits 0'
$bcFiles = @(Invoke-Git -Dir $dirBC -GitArgs @('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'))
Assert-True ($bcFiles -contains 'CHANGELOG.md')        'fold commit: CHANGELOG.md is in it'
Assert-True ($bcFiles -contains $bfPaths.Deployment)    'fold commit: the reset entry file is in it'
Assert-True ($bcFiles -contains $bfPaths.Cycle)     'fold commit: and the reset step list, so the pair lands together'
Assert-True (-not ($bcFiles -contains 'stray.txt'))    'fold commit: the unrelated staged file is NOT swept in -- the pathspec scope is unchanged'

# ---------------------------------------------------------------------------------------------------
Write-Host "A changelog with no trailing newline does not swallow the entry appended to its end" -ForegroundColor Cyan
#      Get-EntryInsertOffset returns the slice's LENGTH for the lowest-ranked entry -- the common case, since
#      tier 0 sinks to the bottom -- so the insert lands at the very end of the content. Ending on '---' with
#      nothing after it, that produces '---## <title>' on ONE line: '^## ' stops matching, so the cut never
#      sees the entry, and the entry FILE is deleted by then. Nothing errors and the markdown stays
#      well-formed, which is exactly why only a test catches it.
#
#      THE CONDITION IS NOT HYPOTHETICAL AND THE LOSS IS NOT RECORDED, which is why this test exists in this
#      shape. The branch behind PR #486 was handed over with the final newline stripped by an editor and
#      repaired before its commit, so no commit, PR or fold ever carried it -- the condition is ordinary
#      editing, and everything below is what proves the loss follows from it.
#
#      WHICH FOLD REACHES THE END OF THE LIST CHANGED ON AUGUST 16, 2026, and the scenario had to follow it
#      rather than be deleted. The end used to be where the LOWEST-ranked entry landed -- the common case,
#      since tier 0 sank to the bottom -- so a seeded tier-1 entry plus a tier-0 newcomer reproduced it. With
#      the list newest-first, every entry lands at the top and the only fold that still reaches the end is
#      the one into a list with NO entries yet. So the damage is applied before the FIRST fold instead of
#      between two, and the guard it pins is unchanged.
#
#      AND #1280 GAVE THE END A SECOND WAY TO BE REACHED (September 3, 2026), which is why the guard matters
#      more now rather than less: an entry placed by its landing stamp that is OLDER than everything pending
#      lands at the list's end. That is a held fold, the exact case #1280 exists for. This scenario still
#      reproduces through the empty list, deliberately -- these fixtures have no gh and therefore no PR, so
#      the fold writes no stamp and every entry here still lands at the top. Placing by the stamp is
#      asserted where it is a pure function, in entry-scaffold.tests.ps1.
$dirN = New-FoldFixture -Label 'tail-noeol'
# The editor's damage, reproduced exactly: every trailing line break gone, so the file ends on its intro
# with nothing after it -- and the first entry folded in has to land against that.
$clNpath = Join-Path $dirN 'CHANGELOG.md'
[System.IO.File]::WriteAllText($clNpath, ([System.IO.File]::ReadAllText($clNpath)).TrimEnd(), $Utf8NoBom)
Assert-True (-not ([System.IO.File]::ReadAllText($clNpath)).EndsWith("`n")) 'tail no-eol: the fixture really has no trailing newline'
New-EntryFile -Dir $dirN -Name 'feat-lands-at-end.md' -Title 'Lands against the damaged tail' -Rows '| 1 | 3 | a clear improvement |'
Invoke-Fold -Dir $dirN -Branch 'feat/lands-at-end' | Out-Null
New-EntryFile -Dir $dirN -Name 'chore-sinks-to-bottom.md' -Title 'Sinks to the bottom' -Rows '| 0 | - | - |'
$rN = Invoke-Fold -Dir $dirN -Branch 'chore/sinks-to-bottom'
$clN = Get-Changelog -Dir $dirN
# WHICH ASSERTS PIN THE GUARD AND WHICH DO NOT, written down because the defect is SILENT and the difference
# is therefore invisible. Verified by removing the guard: the three marked below fail, and these two pass
# either way -- the fold succeeds whichever side of the bug it is on, so an exit code cannot see it.
Assert-True ($rN.ExitCode -eq 0) 'tail no-eol: exits 0 (an invariant -- the defect never threw)'
# THE THREE THAT PIN IT.
$orderN = @(Get-EntryOrder -Changelog $clN)
Assert-Equal 2 $orderN.Count 'tail no-eol: the appended entry is still an entry heading, not glued onto the separator'
# NEWEST FIRST: the second fold leads, and the entry that landed against the damaged tail is still there
# below it. Both halves matter -- an entry welded onto the separator would drop OUT of this count, which is
# the silent loss this scenario exists to catch.
Assert-Equal 'Sinks to the bottom' $orderN[0] 'tail no-eol: the newest entry leads'
Assert-Equal 'Lands against the damaged tail' $orderN[1] 'tail no-eol: and the one folded against the damaged tail survived, rather than being swallowed'
# The defect shape itself, asserted directly: a heading welded to the separator above it.
Assert-True ($clN -notmatch '---##') 'tail no-eol: no separator carries a heading on its own line'
# THE SECOND INVARIANT: the appended entry block ends in a separator plus a blank line by construction, so
# this passes with the guard removed too. It is here to pin the NEXT fold's precondition rather than this one.
Assert-True ($clN.EndsWith("`n")) 'tail no-eol: and the document is left ending on a line break (an invariant)'

Write-Host "The tail is normalised rather than merely repaired -- accumulated blanks are capped" -ForegroundColor Cyan
#      Same one line does both jobs. Split-Changelog already strips this accumulation from the HEAD, for the
#      reason that applies here too: it renders identically, so nothing looks wrong until somebody opens the
#      raw file years in.
$dirNB = New-FoldFixture -Label 'tail-blanks'
New-EntryFile -Dir $dirNB -Name 'feat-first.md' -Title 'The seeded one' -Rows '| 1 | 3 | a clear improvement |'
Invoke-Fold -Dir $dirNB -Branch 'feat/first' | Out-Null
$clNBpath = Join-Path $dirNB 'CHANGELOG.md'
[System.IO.File]::WriteAllText($clNBpath, (([System.IO.File]::ReadAllText($clNBpath)).TrimEnd() + "`n`n`n`n`n"), $Utf8NoBom)
New-EntryFile -Dir $dirNB -Name 'chore-second.md' -Title 'The appended one' -Rows '| 0 | - | - |'
$rNB = Invoke-Fold -Dir $dirNB -Branch 'chore/second'
# Both invariants, as in the block above: neither can see this behaviour, and they are labelled so that the
# one assert that CAN is not read as three.
Assert-True ($rNB.ExitCode -eq 0) 'tail blanks: exits 0 (an invariant)'
$clNB = (Get-Changelog -Dir $dirNB) -replace "`r`n", "`n"
Assert-Equal 2 @(Get-EntryOrder -Changelog $clNB).Count 'tail blanks: both entries are headings (an invariant)'
# Asserted as "nowhere in the document", not as "not at the end". The appended entry block ends in
# '---' + blank line by construction, so an end-of-file assertion passes whether the guard ran or not --
# the four blanks end up in the MIDDLE, above the entry that was appended after them.
Assert-True ($clNB -notmatch "`n`n`n") 'tail blanks: the run of blank lines is capped, not merely pushed up the document'

# ---------------------------------------------------------------------------------------------------
Write-Host "A PRE-FLAT CHANGELOG.md is refused, not written into (inbound #561)" -ForegroundColor Cyan
#      THE MEASURED CONSUMER DEFECT. A repo whose changelog still carries section headings has '## ' blocks
#      at exactly the level an entry now occupies, so the fold took the first one as the top of the list and
#      inserted above it -- outside the section they keep their entries in -- and reported success. Their
#      real output, 2026-08-09: "placed above 2 existing entries", where the 2 were '## Pull Requests' and
#      '## Releases'. cut-release.ps1 has refused over the same assumption since August 5; the fold had no
#      check at all.
#
#      THE FIXTURE IS THE CONSUMER'S DOCUMENT, not a minimal one: both section headings, with a real entry
#      already filed under the first. That way "refused" cannot be an artifact of an empty list.
$dirPF = New-FoldFixture -Label 'preflat'
$preFlatDoc = @(
    '# Changelog', '',
    'Everything merged since the last release.', '',
    '## Pull Requests', '',
    'Merged PRs land here.', '',
    '### An older change ' + [char]0x00B7 + ' Feat', '',
    'Something that was folded before the flat model.', '',
    '## Releases', '',
    'The recorded versions.', ''
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $dirPF 'CHANGELOG.md'), $preFlatDoc, $Utf8NoBom)
New-EntryFile -Dir $dirPF -Name 'feat-refused.md' -Title 'Must not land here' -Rows '| 1 | 3 | a clear improvement |'
$rPF = Invoke-Fold -Dir $dirPF -Branch 'feat/refused'

Assert-Equal 1 $rPF.ExitCode                                                    'pre-flat: the run exits 1 instead of reporting success'
# BOTH offending blocks are named. Naming one would leave the reader migrating half a document, and the
# consumer's report turned on the count being visibly wrong ("2 existing entries").
Assert-True ($rPF.Output -match "'## Pull Requests'")                           'pre-flat: the section heading it cannot read is named'
Assert-True ($rPF.Output -match "'## Releases'")                                'pre-flat: and so is the second one -- the scan did not stop at the first'
Assert-True ($rPF.Output -match 'Migrate the')                                  'pre-flat: the refusal says how to get out of it, not only what is wrong'
# The half-state this refusal deliberately accepts is the one it has to REPORT: the fold runs after a merge,
# so the entry is still sitting there and the caller has to be told so by name.
Assert-True ($rPF.Output -match [regex]::Escape('feat-refused.md'))             'pre-flat: the entry still waiting to be folded is named'
# NOTHING WAS WRITTEN. Byte-identical, not "still contains the headings": the whole failure being repaired
# is a write that leaves a well-formed document with the entry in the wrong place.
Assert-Equal $preFlatDoc ([System.IO.File]::ReadAllText((Join-Path $dirPF 'CHANGELOG.md')))  'pre-flat: CHANGELOG.md is byte-identical -- the refusal came before the write'
Assert-True (Test-Path (Join-Path $dirPF 'feat-refused.md'))                     'pre-flat: and the entry file survives, so nothing has to be reconstructed'
# The pre-pass placement, asserted where it can be seen: an entry ALREADY under the section is not touched
# either, which is what would go wrong if the check ran per file inside the loop instead of once before it.
Assert-True ($preFlatDoc -match 'An older change')                              'pre-flat: (fixture) a real entry sat under the section heading'

Write-Host "A quoted section heading does not make a flat document pre-flat" -ForegroundColor Cyan
#      The same fence rule every reader of this format has. This repo's own changelog intro quotes an entry
#      heading to document the format, and a consumer documenting their migration quotes the section headings
#      they are removing -- so a refusal blind to fences would refuse the very document that describes it.
$dirPFQ = New-FoldFixture -Label 'preflat-fenced'
$fencedIntro = @(
    '# Changelog', '',
    'The pre-flat shape this repo migrated away from looked like:', '',
    '```text', '## Pull Requests', '', '### A change ' + [char]0x00B7 + ' Feat', '```', ''
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $dirPFQ 'CHANGELOG.md'), $fencedIntro, $Utf8NoBom)
New-EntryFile -Dir $dirPFQ -Name 'feat-allowed.md' -Title 'Lands normally' -Rows '| 0 | - | - |'
$rPFQ = Invoke-Fold -Dir $dirPFQ -Branch 'feat/allowed'
Assert-Equal 0 $rPFQ.ExitCode                                                   'fenced: the fold runs'
Assert-True ((Get-Changelog -Dir $dirPFQ) -match 'Lands normally')              'fenced: and the entry lands'
Assert-True ((Get-Changelog -Dir $dirPFQ) -match '(?m)^## Pull Requests\s*$')   'fenced: the quoted heading is still there, untouched inside its fence'

# ---------------------------------------------------------------------------------------------------
Write-Host "-RepoRoot on a git WORKTREE folds and pushes, and the primary checkout is untouched" -ForegroundColor Cyan
#      THE MECHANISM ship-pr.ps1's STEP 5 REACHES FOR WHEN THE SESSION'S CHECKOUT HAS MOVED (Dave, issue
#      #972, August 27, 2026). That step used to run `git checkout main` unconditionally one line after the
#      merge. Measured on git 2.54.0.windows.1, that has exactly two outcomes on a backgrounded ship: it
#      REFUSES when the session's uncommitted edit collides ("Your local changes ... would be overwritten"),
#      leaving the PR merged and unfolded; or it SUCCEEDS and drags HEAD -- and the uncommitted work with it
#      -- onto the trunk. Step 5 now reads HEAD first and folds in a throwaway worktree when it has moved.
#      This case is that claim end to end: the REAL fold script, run from the primary's copy exactly as
#      ship-pr runs it, against a worktree on main, with the primary parked on another branch holding an
#      uncommitted edit.
#
#      -Push IS PART OF THE CLAIM RATHER THAN DECORATION. The detached-worktree alternative was rejected on
#      a measurement: from a detached HEAD the fold's bare `git push` dies with "fatal: You are not
#      currently on a branch" (exit 128), and repairing that would mean writing a HEAD:main push into a
#      script #972 has no business touching. Pushing here is what proves the worktree has main properly
#      checked out rather than merely pointing at its commit.
$dirWT = New-FoldFixture -Label 'worktree'
New-EntryFile -Dir $dirWT -Name 'fix-folds-from-a-worktree.md' -Title 'Folds from a worktree'
Initialize-FoldGitRepo -Dir $dirWT
# -M main regardless of the machine's init.defaultBranch: every assertion below names main, and a fixture
# that happened to init as 'master' would fail on the branch name rather than on the behaviour.
Invoke-Git -Dir $dirWT -GitArgs @('branch', '-M', 'main')                          | Out-Null
$bareWT = "$dirWT.git"
if (Test-Path -LiteralPath $bareWT) { Remove-Item -Recurse -Force -LiteralPath $bareWT }
$script:fixtures += $bareWT
Invoke-Git -Dir $dirWT -GitArgs @('init', '--bare', '--quiet', $bareWT)            | Out-Null
Invoke-Git -Dir $dirWT -GitArgs @('remote', 'add', 'origin', $bareWT)              | Out-Null
Invoke-Git -Dir $dirWT -GitArgs @('push', '--quiet', '-u', 'origin', 'main')       | Out-Null

# The #972 window, reproduced: the primary moves to the next piece of work and carries an uncommitted edit
# to a TRACKED file, which is the half that makes the old `git checkout main` either refuse or steal it.
Invoke-Git -Dir $dirWT -GitArgs @('checkout', '--quiet', '-b', 'feat/next-thing')  | Out-Null
$wipPath = Join-Path $dirWT 'WIP.md'
[System.IO.File]::WriteAllText($wipPath, "committed on the branch`n", $Utf8NoBom)
Invoke-Git -Dir $dirWT -GitArgs @('add', 'WIP.md')                                 | Out-Null
Invoke-Git -Dir $dirWT -GitArgs @('commit', '--quiet', '-m', 'branch work')        | Out-Null
$wipText = "UNCOMMITTED, and it has to survive the fold`n"
[System.IO.File]::WriteAllText($wipPath, $wipText, $Utf8NoBom)

$wtTree = Join-Path ([System.IO.Path]::GetTempPath()) "fold-test-$PID-worktree-tree-$([guid]::NewGuid().ToString('n'))"
if (Test-Path -LiteralPath $wtTree) { Remove-Item -Recurse -Force -LiteralPath $wtTree }
$script:fixtures += $wtTree
Invoke-Git -Dir $dirWT -GitArgs @('worktree', 'add', $wtTree, 'main')              | Out-Null
Assert-True (Test-Path -LiteralPath (Join-Path $wtTree 'CHANGELOG.md')) `
    'worktree: (fixture) a tree with main checked out stands beside the primary'

$rWT = Invoke-Fold -Dir $dirWT -Branch 'fix/folds-from-a-worktree' -Root $wtTree -ExtraArgs @('-Push')
Assert-Equal 0 $rWT.ExitCode                                                       'worktree: the fold exits 0'
$wtChangelog = [System.IO.File]::ReadAllText((Join-Path $wtTree 'CHANGELOG.md'))
Assert-True ($wtChangelog -match 'Folds from a worktree')                          'worktree: the entry landed in the worktree CHANGELOG.md'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $wtTree 'fix-folds-from-a-worktree.md'))) `
    'worktree: and the entry file is gone from the worktree'
$subjectWT = ((Invoke-Git -Dir $wtTree -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()
Assert-True ($subjectWT -match '^fold: fix/folds-from-a-worktree changelog') `
    'worktree: the fold commit is on main and typed as a fold'
$remoteWT = ((Invoke-Git -Dir $wtTree -GitArgs @('log', '-1', '--pretty=%s', 'origin/main')) -join '').Trim()
Assert-Equal $subjectWT $remoteWT `
    'worktree: -Push reached origin/main -- the bare push works from an ATTACHED worktree'

#      THE TWO ASSERTS THE WHOLE CHANGE EXISTS FOR. Everything above would also pass for a fold that had
#      quietly checked the primary out to main first, which is precisely the defect.
Assert-Equal 'feat/next-thing' (((Invoke-Git -Dir $dirWT -GitArgs @('rev-parse', '--abbrev-ref', 'HEAD')) -join '').Trim()) `
    'worktree: the PRIMARY HEAD never moved'
Assert-Equal $wipText ([System.IO.File]::ReadAllText($wipPath)) `
    'worktree: and its uncommitted edit survived byte for byte'

Invoke-Git -Dir $dirWT -GitArgs @('worktree', 'remove', $wtTree)                   | Out-Null
$wtCount = @((Invoke-Git -Dir $dirWT -GitArgs @('worktree', 'list', '--porcelain')) | Where-Object { $_ -match '^worktree\s+' }).Count
Assert-Equal 1 $wtCount                                                            'worktree: it comes back down, leaving only the primary registered'

# ---------------------------------------------------------------------------------------------------
foreach ($f in $script:fixtures) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }


# ---------------------------------------------------------------------------------------------------
Write-Host "A branch the changelog already carries is refused, not folded a second time" -ForegroundColor Cyan
#      INBOUND #1082, measured in a consumer: two entries, same branch, same text, two PR numbers, both
#      folds reported as a success. The route in was #1077 (open-pr's open-only lookup letting a re-run of
#      ship-pr open a second PR for an already-merged branch); this is the second line of defence, and it
#      exists because the step that WRITES the record had nothing to say about writing it twice.
#
#      REFUSING IS SAFE HERE FOR A REASON THAT DOES NOT GENERALISE, which is why this suite states it: an
#      unscored entry that is refused leaves merged work with NO record, while a duplicate that is refused
#      leaves the record already standing.
$dirD = New-FoldFixture -Label 'duplicate'
$dupMd = [char]0x00B7
$seeded = $script:FixtureIntro.TrimEnd() + "`n`n" + ((@(
    "$foldEntryH DEPLOY: ``feat/dup-thing-v1`` $dupMd 20260101-000000", '',
    'The entry this branch already has.', '',
    '[PR #7](https://example.invalid/pull/7)', ''
)) -join "`n")
[System.IO.File]::WriteAllText((Join-Path $dirD 'CHANGELOG.md'), $seeded, $Utf8NoBom)
New-EntryFile -Dir $dirD -Name 'feat-dup-thing-v1.md' -Title 'Second time round'
$rD = Invoke-Fold -Dir $dirD
$clD = Get-Changelog -Dir $dirD

Assert-True ($rD.ExitCode -eq 1)                                        'duplicate: the run ends non-zero, so ship-pr sees it'
Assert-True (Test-Path (Join-Path $dirD 'feat-dup-thing-v1.md'))        'duplicate: the entry file is NOT removed'
Assert-True ($clD -notmatch 'Second time round')                        'duplicate: and nothing was written to CHANGELOG.md'
Assert-Equal 1 @(Get-EntryOrder -Changelog $clD).Count                  'duplicate: the list still holds exactly the one entry'
Assert-True ($rD.Output -match 'PR #7')                                 'duplicate: the refusal names the PR of the entry already there'
Assert-True ($rD.Output -notmatch 'CHANGELOG\.md updated')              'duplicate: and does not claim the changelog was updated'

# -Force IS THE ESCAPE VALVE, and it is asserted because a gate whose way past is untested is a gate
# nobody can get past when it is wrong.
$rF = Invoke-Fold -Dir $dirD -ExtraArgs @('-Force')
$clF = Get-Changelog -Dir $dirD
Assert-True ($rF.ExitCode -eq 0)                                        'duplicate: -Force folds it after all'
Assert-True (-not (Test-Path (Join-Path $dirD 'feat-dup-thing-v1.md'))) 'duplicate: -Force removes the entry file as any fold does'
Assert-True ($clF -match 'Second time round')                           'duplicate: -Force writes the entry'

# A DIFFERENT BRANCH IS NOT A DUPLICATE, which is the false positive that would wedge every fold in a repo
# whose changelog is not empty.
$dirN = New-FoldFixture -Label 'notduplicate'
[System.IO.File]::WriteAllText((Join-Path $dirN 'CHANGELOG.md'), $seeded, $Utf8NoBom)
New-EntryFile -Dir $dirN -Name 'feat-other-thing-v1.md' -Title 'A different branch'
$rN = Invoke-Fold -Dir $dirN
Assert-True ($rN.ExitCode -eq 0)                                        'not a duplicate: a branch with no entry of its own folds normally'
Assert-True ((Get-Changelog -Dir $dirN) -match 'A different branch')    'not a duplicate: and lands in the list'

# ---------------------------------------------------------------------------------------------------
# THE TRUNK IS READ ACROSS DEVICES, NOT JUST LOCALLY (inbound #1405)
#
# Dave works one repo from more than one device at the same time, deliberately and permanently, so two
# checkouts holding the same trunk is the normal case rather than an accident. The duplicate gate above
# reads the WORKING COPY of CHANGELOG.md and nothing else, which on a second device is a snapshot of
# whatever that checkout last pulled. Two halves are covered here, and they fail independently:
#
#   * the pre-pass, which refuses to fold onto a trunk that is already behind its upstream; and
#   * the push-rejection diagnosis, which is the half that matters, because the measured failure was a
#     RACE -- the trunk was current when the gate read it, and the other device folded the same branch
#     inside the window between that read and the push. No check at the top of a run can close a window
#     that opens after it.
#
# EVERY FIXTURE HERE NEEDS A REAL REMOTE, which is why these cases build a bare repo and clone it rather
# than using the plain fold fixture. That is also the assert underneath the first case below: a fixture
# WITHOUT an origin must be unaffected, or this gate would refuse every other fold in this suite.
function New-RemoteFoldFixture {
    <#
        A fold fixture wired to its own bare remote, on main, with the baseline pushed -- and the bare
        repo registered for cleanup. Returns the bare repo's path so a second clone can be made from it.
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    Initialize-FoldGitRepo -Dir $Dir
    # -M main regardless of the machine's init.defaultBranch, for the same reason the worktree case above
    # gives: every assertion here names main, and a fixture that happened to init as 'master' would fail
    # on the branch name rather than on the behaviour.
    Invoke-Git -Dir $Dir -GitArgs @('branch', '-M', 'main')                    | Out-Null
    $bare = "$Dir.git"
    if (Test-Path -LiteralPath $bare) { Remove-Item -Recurse -Force -LiteralPath $bare }
    $script:fixtures += $bare
    Invoke-Git -Dir $Dir -GitArgs @('init', '--bare', '--quiet', $bare)        | Out-Null
    Invoke-Git -Dir $Dir -GitArgs @('remote', 'add', 'origin', $bare)          | Out-Null
    Invoke-Git -Dir $Dir -GitArgs @('push', '--quiet', '-u', 'origin', 'main') | Out-Null
    # AND THE BARE REPO'S HEAD IS POINTED AT THAT BRANCH, which a push does NOT do. `git init --bare` sets
    # HEAD from the machine's init.defaultBranch, so on a machine still defaulting to 'master' the bare is
    # left with HEAD on a ref that does not exist -- and `git clone` of it checks out NOTHING, silently,
    # with only a warning. Every assertion that needs the second device then fails on an empty directory
    # rather than on the behaviour under test. A real remote has its default branch set; this is that.
    Invoke-Git -Dir $bare -GitArgs @('symbolic-ref', 'HEAD', 'refs/heads/main') | Out-Null
    return $bare
}

function Initialize-SecondDevice {
    <# The other device: a real clone of the same bare remote, with the identity and autocrlf settings
       Initialize-FoldGitRepo explains, since a clone inherits none of them. #>
    param([Parameter(Mandatory = $true)][string]$Bare, [Parameter(Mandatory = $true)][string]$Dir)
    if (Test-Path -LiteralPath $Dir) { Remove-Item -Recurse -Force -LiteralPath $Dir }
    $script:fixtures += $Dir
    Invoke-FixtureGitJudged @('clone', '--quiet', $Bare, $Dir)
    Invoke-FixtureGitIn $Dir config user.name  'fold test 2'
    Invoke-FixtureGitIn $Dir config user.email 'fold2@test.invalid'
    Invoke-FixtureGitIn $Dir config core.autocrlf false
    Invoke-FixtureGitIn $Dir config commit.gpgsign false
    # LOUD RATHER THAN EMPTY. A clone that checks nothing out leaves a directory with no fold script in it,
    # and every fold invoked against it then dies in the PowerShell launcher -- an exit code that names no
    # cause, on assertions about behaviour that never ran. This is a fixture precondition, so it throws.
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'scripts\release\fold-changelog-entry.ps1'))) {
        throw "second device: the clone of '$Bare' checked out an empty tree -- its HEAD does not name a branch that exists."
    }
}

Write-Host "A trunk behind its upstream is refused before the gate reads it (#1405)" -ForegroundColor Cyan
$dirS = New-FoldFixture -Label 'staletrunk'
New-EntryFile -Dir $dirS -Name 'feat-stale-thing-v1.md' -Title 'Folded on a stale trunk'
$bareS = New-RemoteFoldFixture -Dir $dirS

# The other device moves the trunk on. This checkout's refs/remotes/origin/main still points at the old
# commit, so the gap only becomes visible once the fold FETCHES -- which is the first of the three things
# the report asked for, and it is under test here rather than assumed.
$devS = Join-Path ([System.IO.Path]::GetTempPath()) "fold-test-$PID-staletrunk-dev2-$([guid]::NewGuid().ToString('n'))"
Initialize-SecondDevice -Bare $bareS -Dir $devS
[System.IO.File]::WriteAllText((Join-Path $devS 'OTHER.md'), "the other device moved main on`n", $Utf8NoBom)
Invoke-Git -Dir $devS -GitArgs @('add', 'OTHER.md')                       | Out-Null
Invoke-Git -Dir $devS -GitArgs @('commit', '--quiet', '-m', 'other work') | Out-Null
Invoke-Git -Dir $devS -GitArgs @('push', '--quiet')                       | Out-Null

$rS = Invoke-Fold -Dir $dirS -Branch 'feat/stale-thing-v1' -ExtraArgs @('-Push')
# EXIT CODE 2, AND THE NUMBER IS THE POINT (inbound #1586). fold-on-merge.yml translates exactly this
# code into a stood-down green, because a job re-triggered by the very push that made the checkout stale
# has a successor run already queued to answer the same question. Pinned here rather than left as
# "non-zero" -- which is what this assert said while pinning 1 -- because the workflow and the
# adopt-ci-floor template now BOTH read it, across a release boundary each.
Assert-Equal 2 $rS.ExitCode                                             'stale trunk: the run ends on 2 -- the code fold-on-merge.yml stands down on (#1586)'
Assert-True ($rS.Output -match 'Refused')                               'stale trunk: and says it refused rather than half-folding'
Assert-True ($rS.Output -match '1 behind origin/main')                  'stale trunk: naming HOW FAR behind, as a number'
Assert-True (Test-Path (Join-Path $dirS 'feat-stale-thing-v1.md'))      'stale trunk: the entry file is left exactly where it was'
Assert-True ((Get-Changelog -Dir $dirS) -notmatch 'Folded on a stale trunk') `
    'stale trunk: and nothing was written to CHANGELOG.md'
$headS = ((Invoke-Git -Dir $dirS -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()
Assert-True ($headS -notmatch '^fold:')                                 'stale trunk: no fold commit was made on the trunk'

# THE ESCAPE VALVE, asserted for the reason -Force is: a gate whose way past is untested is a gate nobody
# can get past on the day it is wrong. It is a SEPARATE flag from -Force deliberately -- this one waves
# through a measurement of the checkout, -Force waves through a judgement about content.
$rSF = Invoke-Fold -Dir $dirS -Branch 'feat/stale-thing-v1' -ExtraArgs @('-SkipTrunkCheck')
Assert-Equal 0 $rSF.ExitCode                                            'stale trunk: -SkipTrunkCheck folds anyway'
Assert-True ((Get-Changelog -Dir $dirS) -match 'Folded on a stale trunk') `
    'stale trunk: -SkipTrunkCheck writes the entry'

# AND NO SECOND PATH MAY REACH THAT CODE (inbound #1586). fold-on-merge.yml reads exit 2 as "nothing was
# written, a successor run will fold it" and exits GREEN on it -- so a refusal that CAN follow a partial
# fold, or one no successor run answers, must never return it. Every other refusal in this suite is
# pinned at 1 above (the pre-pass, the flat window, the duplicate gate); this asserts the property at its
# source, which is the only place that stays true when a new refusal is added tomorrow.
# $foldSrcText<x>, never $foldSrc: $FoldSrc is the PATH this suite copies into every fixture, and
# PowerShell variable names are case-insensitive -- so a read into $foldSrc replaces that path with the
# script's own text and every later fixture dies in Copy-Item on a filename made of source code. The two
# asserts above at 417 and 1081 already use the $foldSrcText<x> shape for exactly this reason.
$foldSrcTextExit = [System.IO.File]::ReadAllText($FoldSrc, [System.Text.Encoding]::UTF8)
$exit2Count = ([regex]::Matches($foldSrcTextExit, '(?m)^\s*exit\s+2\s*$')).Count
Assert-Equal 1 $exit2Count 'stale trunk: exit 2 is returned from exactly ONE place in the fold script'
Assert-True ($foldSrcTextExit -match '(?ms)Refused: this checkout is.*?exit 2') `
    'stale trunk: and that one place is the trunk-freshness refusal itself, not some later failure'
Assert-True ($foldSrcTextExit -like '*#1586*') 'stale trunk: the refusal cites the issue that explains why its code is its own'

# A REPO WITH NO ORIGIN CANNOT BE BEHIND ONE, and this is the assert that keeps the gate from refusing
# every other fold in this suite: Get-TrunkGap reports "could not measure", which a caller must never
# read as "behind".
Write-Host "A repo with no origin is not refused -- unmeasurable is not behind (#1405)" -ForegroundColor Cyan
$dirNo = New-FoldFixture -Label 'noorigin'
New-EntryFile -Dir $dirNo -Name 'feat-no-origin-v1.md' -Title 'Folded without a remote'
Initialize-FoldGitRepo -Dir $dirNo
$rNo = Invoke-Fold -Dir $dirNo -Branch 'feat/no-origin-v1'
Assert-Equal 0 $rNo.ExitCode                                            'no origin: the fold is not refused'
Assert-True ($rNo.Output -notmatch 'behind origin')                     'no origin: and claims no gap it could not measure'
Assert-True ((Get-Changelog -Dir $dirNo) -match 'Folded without a remote') `
    'no origin: the entry lands as it always did'

# ---------------------------------------------------------------------------------------------------
Write-Host "A rejected push is diagnosed against the fetched remote (#1405)" -ForegroundColor Cyan
#
# THE RACE, REPRODUCED FROM ITS FAR SIDE. The measured sequence had a trunk that was CURRENT when the
# duplicate gate read it -- checkout, pull --ff-only, gate read, all correct -- and the other device
# folded the same branch inside the window before the push. -SkipTrunkCheck is what stands in for that
# window here: it puts this run exactly where the real one was, past a gate that answered honestly on the
# state it could see. That it ALSO proves the two guards are independent is deliberate -- skipping the
# pre-pass must not switch off the diagnosis, which is the guard that catches what the pre-pass cannot.
$dirR = New-FoldFixture -Label 'racedfold'
# THE HEADING NAMES THE BRANCH, which is what makes this a real test rather than a trivially
# passing one. Get-FoldedEntryForBranch keys on the branch name in the DEPLOY heading and says so in its
# own header: an entry whose heading names no branch cannot be matched. A fixture titled only 'Raced by
# two devices' would therefore report `not upstream` no matter what the other device had done -- the
# diverged case below would still pass, and it would be proving nothing.
New-EntryFile -Dir $dirR -Name 'feat-raced-thing-v1.md' -Title 'DEPLOY: `feat/raced-thing-v1`'
$bareR = New-RemoteFoldFixture -Dir $dirR

# The other device folds the SAME branch first and gets its push in.
$devR = Join-Path ([System.IO.Path]::GetTempPath()) "fold-test-$PID-racedfold-dev2-$([guid]::NewGuid().ToString('n'))"
Initialize-SecondDevice -Bare $bareR -Dir $devR
$rOther = Invoke-Fold -Dir $devR -Branch 'feat/raced-thing-v1' -ExtraArgs @('-Push')
Assert-Equal 0 $rOther.ExitCode                                         'raced fold: (fixture) the other device folds and pushes cleanly'

$rR = Invoke-Fold -Dir $dirR -Branch 'feat/raced-thing-v1' -ExtraArgs @('-Push', '-SkipTrunkCheck')
# EXIT CODE 3, AND THE NUMBER IS THE POINT (issue #1792), for the same reason the pre-pass's 2 is. Every
# assert below establishes that the fold HAPPENED -- upstream, once, with a matching body -- and the one
# caller standing on the far side of this race is ship-pr.ps1, which merged the PR seconds earlier. It
# has no other way to tell "somebody else folded it" from "the fold refused or crashed", so reading 1
# there reported a hard failure over a correct ship and left the session's trunk diverged. It was pinned
# at 1 here, which is what made that the tested behaviour rather than an oversight.
#
# AND IT HAS A SECOND READER, WHICH IS WHY THE PIN MATTERS MORE THAN ITS FIRST OWNER SAID (issue #1796).
# fold-on-merge.yml loses the SAME race from the other side and stands down on the same code -- so this
# one number is now read across two independent boundaries, ship-pr's and adopt-ci-floor.ps1's emitted
# template, each reaching consumers by its own route. Both readers are asserted below.
Assert-Equal 3 $rR.ExitCode                                             'raced fold: the run ends on 3 -- the code ship-pr.ps1 (#1792) and fold-on-merge.yml (#1796) both stand down on'
# The five facts that had to be established BY HAND in the measured incident -- a fetch, a log of
# HEAD..origin/main, a grep of the remote changelog, a count, and a body diff -- are each asserted here,
# because each one is separately derivable and each was separately missing.
Assert-True ($rR.Output -match 'moved 1 commit')                        'raced fold: it names how far origin/main moved'
Assert-True ($rR.Output -match 'fold: feat/raced-thing-v1')             'raced fold: and shows WHICH commit moved it'
Assert-True ($rR.Output -match 'ALREADY folded on')                     'raced fold: it establishes the entry is already upstream'
Assert-True ($rR.Output -match 'present once')                          'raced fold: counted, so a duplicate upstream would read differently'
Assert-True ($rR.Output -match 'body is identical')                     'raced fold: and the bodies are compared, not merely the headings'
Assert-True ($rR.Output -match 'Do NOT push this commit by hand')       'raced fold: the advice is inverted -- pushing would duplicate the entry'
Assert-True ($rR.Output -notmatch 'the state this flag exists to avoid') `
    'raced fold: and the old generic "push by hand" verdict is NOT what it ends on'

# IT DIAGNOSES AND STOPS. Every route off a trunk is a history operation the consumer's own safety rules
# reserve to the operator, so the one thing this script must never do here is tidy up after itself.
$headR = ((Invoke-Git -Dir $dirR -GitArgs @('log', '-1', '--pretty=%s')) -join '').Trim()
Assert-True ($headR -match '^fold: feat/raced-thing-v1')                'raced fold: the local fold commit is left exactly where it is'
# AND THAT COMMIT IS EXACTLY WHY 3 IS ITS OWN CODE RATHER THAN A SECOND WAY TO SPELL 2. Standing down on
# 3 means ACCEPTING a local commit that will not be pushed -- which is why the two readers answer it
# differently rather than identically: ship-pr.ps1 tells the operator about it (#1792, step 5c), because
# it is sitting on a trunk they have to live with, while fold-on-merge.yml simply exits 0 (#1796),
# because its workspace is thrown away when the run ends. Exit 2 leaves nothing at all, asserted at 'no
# fold commit was made' above; the pair of asserts is what keeps the two codes from being merged by a
# later reader who sees only that both are "the race".

# AND NO SECOND PATH MAY REACH CODE 3 EITHER (issue #1792), the same property the exit-2 block above
# asserts and for a sharper reason: ship-pr.ps1 reads 3 as "the fold happened, carry on shipping". A
# refusal that borrowed it would turn a genuinely unfolded trunk into a reported success -- the one
# outcome worse than the hard failure this change removes. The two codes also have to stay distinct: 2
# says nothing was written, 3 says a commit is sitting on the local trunk.
$exit3Count = ([regex]::Matches($foldSrcTextExit, '(?m)^\s*exit\s+3\s*$')).Count
Assert-Equal 1 $exit3Count 'raced fold: exit 3 is returned from exactly ONE place in the fold script'
Assert-True ($foldSrcTextExit -match '(?ms)Do NOT push this commit by hand.*?exit 3') `
    'raced fold: and that one place is the redundant-commit verdict, not some later failure'
Assert-True ($foldSrcTextExit -match '(?ms)EXIT CODES\..*?3 folded and committed') `
    'raced fold: the header documents 3 alongside the other two, so a caller can read the contract'

# THE READER OF THAT CODE, PINNED ACROSS THE FILE BOUNDARY. ship-pr.ps1 drives live git/gh and has no
# suite of its own (its own header says so), so its half of this contract is asserted here as text --
# exactly what the exit-2 asserts above do for fold-on-merge.yml's half. Without it the contract has one
# testable end, which is how `-ne 0` stayed the tested behaviour on the caller side through #1586.
$shipSrcText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'), [System.Text.Encoding]::UTF8)
Assert-True ($shipSrcText -match '\$foldExit\s+-eq\s+3')                'raced fold: ship-pr.ps1 reads exit 3 specifically'
Assert-True ($shipSrcText -match '(?ms)\$foldExit\s+-eq\s+3.*?\}\s*elseif\s*\(\s*\$foldExit\s+-ne\s+0\s*\)') `
    'raced fold: and its hard-failure arm is an elseif, so 3 cannot fall through into it'
Assert-True ($shipSrcText -like '*#1792*')                              'raced fold: ship-pr.ps1 cites the issue that explains why 3 is not a failure'

# AND THE SECOND READER OF THAT SAME CODE, ACROSS A DIFFERENT BOUNDARY (issue #1796). ship-pr.ps1 loses
# this race from the session's side; fold-on-merge.yml loses it from the runner's, and stands down on the
# same 3. Its half was asserted nowhere -- only the emitted template in adopt-ci-floor.tests.ps1 was,
# and that reaches consumers by a plugin release while THIS file reaches them by that template, so the two
# ends drift independently. A code is only a contract while every end that reads it is pinned.
$foldYml = Join-Path $RepoRoot '.github\workflows\fold-on-merge.yml'
if (Test-Path -LiteralPath $foldYml) {
    $foldYmlText = [System.IO.File]::ReadAllText($foldYml, [System.Text.Encoding]::UTF8)
    Assert-True ($foldYmlText -match '(?ms)if \(\$foldExitCode -eq 2\) \{.*?exit 0') `
        'raced fold: fold-on-merge.yml stands down on exit 2 (#1586)'
    Assert-True ($foldYmlText -match '(?ms)if \(\$foldExitCode -eq 3\) \{.*?exit 0') `
        'raced fold: and on exit 3 too (#1796)'
    Assert-Equal 2 (@([regex]::Matches($foldYmlText, '\$foldExitCode -eq \d')).Count) `
        'raced fold: on exactly those two codes -- a third would need its own ground, so the count is pinned'
    Assert-True ($foldYmlText -notmatch '\$foldExitCode -ne 0') `
        'raced fold: and neither stand-down is a blanket "any non-zero is fine"'
} else {
    # Stated rather than skipped in silence: a consumer running this suite has no such workflow, and a
    # pass over a file that is not there proves nothing about the one that is.
    Write-Host "  (no .github/workflows/fold-on-merge.yml in this checkout -- that reader is unasserted here.)" -ForegroundColor DarkYellow
}

# THE FALSE POSITIVE THAT WOULD BE WORSE THAN THE DEFECT. A push refused by an ORDINARY divergence must
# still get the ordinary advice: that commit is real work, and telling its author not to push it would
# strand the entry for good.
Write-Host "An ordinary divergence is NOT reported as a duplicate (#1405)" -ForegroundColor Cyan
$dirV = New-FoldFixture -Label 'divergedfold'
# Same branch-naming heading as the raced case, deliberately: the ONLY difference between the two cases
# is what the other device pushed, so 'has NO entry' here is a measurement rather than a shape that could
# never have matched.
New-EntryFile -Dir $dirV -Name 'feat-diverged-thing-v1.md' -Title 'DEPLOY: `feat/diverged-thing-v1`'
$bareV = New-RemoteFoldFixture -Dir $dirV
$devV = Join-Path ([System.IO.Path]::GetTempPath()) "fold-test-$PID-divergedfold-dev2-$([guid]::NewGuid().ToString('n'))"
Initialize-SecondDevice -Bare $bareV -Dir $devV
[System.IO.File]::WriteAllText((Join-Path $devV 'UNRELATED.md'), "nothing to do with the fold`n", $Utf8NoBom)
Invoke-Git -Dir $devV -GitArgs @('add', 'UNRELATED.md')                       | Out-Null
Invoke-Git -Dir $devV -GitArgs @('commit', '--quiet', '-m', 'unrelated work') | Out-Null
Invoke-Git -Dir $devV -GitArgs @('push', '--quiet')                           | Out-Null

$rV = Invoke-Fold -Dir $dirV -Branch 'feat/diverged-thing-v1' -ExtraArgs @('-Push', '-SkipTrunkCheck')
# PINNED AT 1, NOT MERELY NON-ZERO (issue #1792). This is the case that must NOT borrow the raced fold's
# 3: the entry is not upstream, so the commit carries work, and a caller standing down on it would report
# a successful ship over a trunk that never got the entry -- or, in fold-on-merge.yml's case (#1796),
# report green over a trunk the entry never reached. Both readers depend on this staying 1.
Assert-Equal 1 $rV.ExitCode                                             'diverged: the run still ends on 1 -- NOT the stand-down code'
Assert-True ($rV.Output -match 'has NO entry on')                       'diverged: it says the entry is NOT upstream'
Assert-True ($rV.Output -match 'the state this flag exists to avoid')   'diverged: so the ordinary "push by hand" advice stands'
Assert-True ($rV.Output -notmatch 'Do NOT push this commit by hand')    'diverged: and it is NOT called a duplicate'

# The teardown above runs mid-file, so everything registered after it -- the duplicate cases and the
# remote-backed fixtures here -- is swept once more on the way out.
foreach ($f in $script:fixtures) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
Write-Host ""
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'fold-changelog-entry.ps1'
if ($script:fail -gt 0) { exit 1 }
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
