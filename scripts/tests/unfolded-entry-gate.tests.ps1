<#
.SYNOPSIS
    Regression tests for the skipped-fold guard (issue #1270): Get-UnfoldedTrunkEntry in
    entry-scaffold-lib.ps1, the check script scripts/lint/check-unfolded-entry.ps1, and the
    SessionStart hook unfolded-entry-sessioncheck.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell and git.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/unfolded-entry-gate.tests.ps1

    THE DOCUMENT STATES COME FROM THE REAL FORMATTER, never from a literal here. Format-Development
    -Branch 'feat/x' IS a written branch document and Format-Development -Branch '' IS the trunk/reset
    state -- so a change to either shape reaches these cases automatically, instead of a third
    definition of the format going stale in the file whose job is to prove there are not two.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    THE #1585 CASES NEED A REAL git FIXTURE, unlike every case above them, and that is the point rather
    than an inconvenience: the question they exercise -- has this fold already landed on origin? -- is
    only answerable against a remote-tracking ref. So Initialize-GitTree builds a repo with a bare
    'origin' beside it, and Push-UpstreamFold advances that origin PAST the fixture from a second clone,
    exactly as fold-on-merge.yml advances the real one. The fixture then fetches; the check under test
    never does.

    AND SINCE #1601 THAT UPSTREAM COMMIT IS A WHOLE FOLD, not half of one. It used to only DELETE the
    branch document, which was enough while the check asked whether the document was gone upstream; the
    check asks whether the ENTRY is in CHANGELOG.md on that ref now, so Push-UpstreamFold writes it as
    well -- through Format-BranchFileHeadingLine, the same formatter the fold itself writes it with. A
    fixture that models half a commit cannot prove anything about the other half.

    THE #1601 CASE IS THE ONE FIXTURE BUILT THE LONG WAY ROUND, because it needs a checkout that is
    AHEAD as well as behind: origin gains an unrelated commit (Push-UpstreamUnrelated) while the branch
    document arrives here as a local-only commit. Everything else in this file commits and pushes in one
    go, which can never reach that state.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$Script   = Join-Path $RepoRoot 'scripts/lint/check-unfolded-entry.ps1'
$Hook     = Join-Path $RepoRoot 'plugins/dkj-policy/hooks/unfolded-entry-sessioncheck.ps1'
. (Join-Path $RepoRoot 'scripts/lib/entry-scaffold-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("unfoldedgate-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path (Join-Path $dir 'dkj-policy') -Force | Out-Null
    # A CHANGELOG.md IN EVERY TREE SINCE #1601, because that is now the file the upstream question is
    # asked of. Without one 'git show <ref>:...' fails and Test-BranchFoldedOnRef answers $null -- the
    # right VERDICT for a stranded document, reached for the wrong reason, which is exactly the kind of
    # accidental pass a fixture must not hand out.
    Set-Changelog -Dir $dir
    $script:trees += $dir
    return $dir
}

function Set-Changelog {
    # The changelog's pending head, and optionally a folded entry per branch -- headings from the REAL
    # formatter, never a literal here, for the same reason the documents come from Format-Development.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string[]]$FoldedBranch = @()
    )
    $lines = @('# Changelog', '', (Get-ChangelogUnreleasedHeading), '')
    foreach ($b in $FoldedBranch) {
        $lines += (Format-BranchFileHeadingLine -Branch $b -Title (Get-BranchFileWording).ChangelogTitle -Level (Get-EntryHeadingLevel))
        $lines += @('', "Folded entry for $b.", '')
    }
    $target = Join-Path $Dir 'dkj-policy/CHANGELOG.md'
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($target, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Set-Doc {
    # Write a development document at its per-branch path (or the shared name), content from the real
    # formatter. -Branch '' writes the trunk/reset state.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [switch]$SharedName
    )
    $rel = if ($SharedName) { (Get-BranchFilePaths).SharedFile } else { (Get-BranchFilePaths -Branch $Branch).File }
    if (-not $Branch -and -not $SharedName) { $rel = (Get-BranchFilePaths).SharedFile }
    $target = Join-Path $Dir $rel
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $text = (Format-Development -Branch $Branch) -join "`n"
    [System.IO.File]::WriteAllText($target, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-GitStep {
    <# One fixture-building git command, and it THROWS on a non-zero exit rather than swallowing it.
       A fixture that half-built is the worst outcome here: the check under test then reads a repo with
       no origin, takes its "could not measure" arm, and the assert fails for a reason that has nothing
       to do with the behaviour being tested.

       NO '2>&1' ON A NATIVE COMMAND -- the #107 pitfall: under EAP=Stop one stderr line from git becomes
       a terminating NativeCommandError before any exit code is read. EAP drops to Continue instead, and
       the exit code is what is judged. #>
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & git @GitArgs 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "fixture git failed (exit $LASTEXITCODE): git $($GitArgs -join ' ')`n$($out -join "`n")"
        }
    } finally { $ErrorActionPreference = $prevEap }
}

function Initialize-GitTree {
    <# Turn a fixture into a real git repo on 'main', with an 'origin' bare beside it and everything
       already committed and pushed -- the baseline every #1585 case starts from.

       Identity, autocrlf and commit.gpgsign are set LOCALLY, for the three reasons
       Initialize-FoldGitRepo in fold-changelog.tests.ps1 gives: a machine with no global user.email, a
       CRLF warning on stderr, and a locked signing agent (#1287) each fail the fixture for a reason
       that has nothing to do with the check under test.

       '-M main' EXPLICITLY, regardless of the machine's init.defaultBranch: every assert below reads
       'refs/remotes/origin/main', which Get-BranchTrunkName resolves to, and a fixture on 'master'
       would measure Behind=0 and quietly take the pre-#1585 arm instead of the one being tested.

       NO '2>&1' ON A NATIVE COMMAND -- the #107 pitfall: under EAP=Stop one stderr line from git
       becomes a terminating NativeCommandError before any exit code is read. EAP drops to Continue. #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $bare = "$Dir.origin.git"
    Invoke-GitStep -GitArgs @('-C', $Dir, 'init', '--quiet')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'config', 'user.name', 'unfolded test')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'config', 'user.email', 'unfolded@test.invalid')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'config', 'core.autocrlf', 'false')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'config', 'commit.gpgsign', 'false')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'add', '-A')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'commit', '-m', 'baseline', '--quiet')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'branch', '-M', 'main')
    Invoke-GitStep -GitArgs @('init', '--bare', '--quiet', $bare)
    Invoke-GitStep -GitArgs @('-C', $Dir, 'remote', 'add', 'origin', $bare)
    Invoke-GitStep -GitArgs @('-C', $Dir, 'push', '--quiet', '-u', 'origin', 'main')
    # POINT THE BARE'S OWN HEAD AT main. 'git init --bare' writes whatever the machine's
    # init.defaultBranch says, so on a machine still defaulting to 'master' the bare ends up with a HEAD
    # naming a branch that was never pushed -- and the clone in Push-UpstreamFold then checks nothing out
    # ("warning: remote HEAD refers to nonexistent ref"), leaving 'git rm' with no working tree to remove
    # from. Set here rather than via 'init -b main', which needs git >= 2.28.
    Invoke-GitStep -GitArgs @('-C', $bare, 'symbolic-ref', 'HEAD', 'refs/heads/main')
    $script:trees += $bare
    return $bare
}

function Push-UpstreamFold {
    <# Advance origin/main PAST this checkout, the way fold-on-merge.yml does: delete the branch
       document(s), ADD their entries to CHANGELOG.md, and commit. Done in a second clone so the fixture
       under test stays BEHIND -- which is the whole condition #1585 is about. The fixture then fetches,
       because the check reads the remote-tracking ref from disk and deliberately never fetches for itself.

       IT WROTE ONLY THE DELETION UNTIL #1601, which was half a fold commit. That was enough while the
       check asked whether the document was gone upstream; it is not enough now that the check asks
       whether the ENTRY is there, and a fixture that models half a commit cannot prove anything about
       the other half. -FoldBranch is the branch each removed document belonged to. #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Bare,
        [Parameter(Mandatory = $true)][string[]]$RemoveRel,
        [Parameter(Mandatory = $true)][string[]]$FoldBranch
    )
    $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("unfoldedgate-$PID-upstream-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $script:trees += $clone
    Invoke-GitStep -GitArgs @('clone', '--quiet', $Bare, $clone)
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'user.name', 'fold on merge')
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'user.email', 'fold@test.invalid')
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'commit.gpgsign', 'false')
    foreach ($rel in $RemoveRel) { Invoke-GitStep -GitArgs @('-C', $clone, 'rm', '--quiet', $rel) }
    Set-Changelog -Dir $clone -FoldedBranch $FoldBranch
    Invoke-GitStep -GitArgs @('-C', $clone, 'add', '-A')
    Invoke-GitStep -GitArgs @('-C', $clone, 'commit', '-m', 'fold: upstream', '--quiet')
    Invoke-GitStep -GitArgs @('-C', $clone, 'push', '--quiet', 'origin', 'main')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'fetch', '--quiet', 'origin')
}

function Push-UpstreamUnrelated {
    <# Advance origin/main by a commit that has NOTHING to do with any fold -- somebody else's work
       landing on the trunk. The #1601 fixture needs it: that state is a checkout AHEAD and BEHIND, and
       the "behind" half must not itself be a fold, or the case being tested would be resolved by the
       upstream commit rather than reported by the check. #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Bare
    )
    $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("unfoldedgate-$PID-unrelated-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $script:trees += $clone
    Invoke-GitStep -GitArgs @('clone', '--quiet', $Bare, $clone)
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'user.name', 'somebody else')
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'user.email', 'other@test.invalid')
    Invoke-GitStep -GitArgs @('-C', $clone, 'config', 'commit.gpgsign', 'false')
    [System.IO.File]::WriteAllText((Join-Path $clone 'upstream.txt'), "unrelated`n", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-GitStep -GitArgs @('-C', $clone, 'add', '-A')
    Invoke-GitStep -GitArgs @('-C', $clone, 'commit', '-m', 'unrelated upstream work', '--quiet')
    Invoke-GitStep -GitArgs @('-C', $clone, 'push', '--quiet', 'origin', 'main')
    Invoke-GitStep -GitArgs @('-C', $Dir, 'fetch', '--quiet', 'origin')
}

function Invoke-Script {
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$Branch = '')
    $args = @('-RootOverride', $Dir)
    if ($Branch) { $args += @('-Branch', $Branch) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script @args 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

function Invoke-Hook {
    # -CheckScriptOverride defaults to the source check script: a bare test run has no
    # CLAUDE_PLUGIN_ROOT, which is the hook's only other way to find it. Pass an explicit path to
    # exercise the "not found" branch.
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$CheckScriptOverride = $Script)
    $args = @('-ConsumerPathOverride', $Dir)
    if ($CheckScriptOverride) { $args += @('-CheckScriptOverride', $CheckScriptOverride) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @args 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

try {
    # --- Get-UnfoldedTrunkEntry, the detector ------------------------------------------------------
    Write-Host 'Get-UnfoldedTrunkEntry'

    $empty = New-Tree -Label 'empty'
    Assert-True (@(Get-UnfoldedTrunkEntry -RepoRoot $empty -CurrentBranch 'main').Count -eq 0) `
        'empty dkj-policy/ -- no findings'

    $nodir = Join-Path ([System.IO.Path]::GetTempPath()) ("unfoldedgate-$PID-nodir-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    Assert-True (@(Get-UnfoldedTrunkEntry -RepoRoot $nodir -CurrentBranch 'main').Count -eq 0) `
        'no dkj-policy/ directory at all -- no findings, no throw'

    $onMain = New-Tree -Label 'onmain'
    Set-Doc -Dir $onMain -Branch 'feat/alpha'
    $f = @(Get-UnfoldedTrunkEntry -RepoRoot $onMain -CurrentBranch 'main')
    Assert-True ($f.Count -eq 1 -and $f[0].DeclaredBranch -eq 'feat/alpha' -and $f[0].Rel -match 'dkj-policy/feat-alpha\.md$') `
        'a written per-branch doc, HEAD = main -- one finding naming the file and the branch it declares'

    $onOwn = New-Tree -Label 'onown'
    Set-Doc -Dir $onOwn -Branch 'feat/alpha'
    Assert-True (@(Get-UnfoldedTrunkEntry -RepoRoot $onOwn -CurrentBranch 'feat/alpha').Count -eq 0) `
        "the branch's own document is not a leftover when HEAD is that branch"

    $mixed = New-Tree -Label 'mixed'
    Set-Doc -Dir $mixed -Branch 'feat/alpha'
    Set-Doc -Dir $mixed -Branch 'fix/beta'
    $f = @(Get-UnfoldedTrunkEntry -RepoRoot $mixed -CurrentBranch 'feat/alpha')
    Assert-True ($f.Count -eq 1 -and $f[0].DeclaredBranch -eq 'fix/beta') `
        "on feat/alpha with a fix/beta leftover beside it -- only the leftover is reported"

    $reset = New-Tree -Label 'reset'
    Set-Doc -Dir $reset -Branch ''
    Assert-True (@(Get-UnfoldedTrunkEntry -RepoRoot $reset -CurrentBranch 'main').Count -eq 0) `
        'a reset-state development.md (declares the trunk) is not a leftover'

    $shared = New-Tree -Label 'shared'
    Set-Doc -Dir $shared -Branch 'feat/gamma' -SharedName
    $f = @(Get-UnfoldedTrunkEntry -RepoRoot $shared -CurrentBranch 'main')
    Assert-True ($f.Count -eq 1 -and $f[0].DeclaredBranch -eq 'feat/gamma' -and $f[0].Rel -match 'development\.md$') `
        'the pre-#1255 shared name development.md is checked too, though the glob would miss it'

    # --- check-unfolded-entry.ps1, the gate ------------------------------------------------------
    Write-Host ''
    Write-Host 'check-unfolded-entry.ps1'

    $r = Invoke-Script -Dir (New-Tree -Label 'gate-clean') -Branch 'main'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\] no unfolded changelog entry') `
        'clean trunk fixture -- [OK], exit 0'

    $gd = New-Tree -Label 'gate-dirty'
    Set-Doc -Dir $gd -Branch 'feat/alpha'
    $r = Invoke-Script -Dir $gd -Branch 'main'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match 'feat/alpha' -and $r.Out -match 'fold-changelog-entry\.ps1 -Branch feat/alpha') `
        'leftover present, -Branch main -- [ERROR] exit 1, names the file, the branch and the fold command'

    $r = Invoke-Script -Dir $gd -Branch 'feat/alpha'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]') `
        'same tree, -Branch feat/alpha -- its own document is expected, [OK] exit 0'

    # --- a checkout that is merely BEHIND origin/main (issue #1585) -------------------------------
    Write-Host ''
    Write-Host 'check-unfolded-entry.ps1 -- stale checkout vs. skipped fold (#1585)'

    # A tree with no remote at all must not change: the pre-#1585 answer, no pull line anywhere. Every
    # other fixture in this suite is such a tree, so this asserts what the rest silently rely on.
    $noRemote = New-Tree -Label 'noremote'
    Set-Doc -Dir $noRemote -Branch 'feat/alpha'
    $r = Invoke-Script -Dir $noRemote -Branch 'main'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -notmatch 'git pull --ff-only') `
        'no origin to measure against -- unchanged [ERROR], and no pull is claimed on an unanswerable question'

    # Behind by 0: origin carries the document too, so the fold really is owed.
    $current = New-Tree -Label 'current'
    Set-Doc -Dir $current -Branch 'feat/alpha'
    Initialize-GitTree -Dir $current | Out-Null
    $r = Invoke-Script -Dir $current -Branch 'main'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match 'fold-changelog-entry\.ps1 -Branch feat/alpha' -and $r.Out -notmatch 'git pull --ff-only') `
        'a real origin, in sync -- the fold is genuinely owed, [ERROR] exit 1, still no pull line'

    # The measured case: origin folded it, this checkout has not caught up.
    $stale = New-Tree -Label 'stale'
    Set-Doc -Dir $stale -Branch 'feat/alpha'
    $bare = Initialize-GitTree -Dir $stale
    Push-UpstreamFold -Dir $stale -Bare $bare -RemoveRel @((Get-BranchFilePaths -Branch 'feat/alpha').File) -FoldBranch @('feat/alpha')
    $r = Invoke-Script -Dir $stale -Branch 'main'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[WARN\]' -and $r.Out -notmatch '\[ERROR\]') `
        'the fold already landed on origin -- [WARN] and exit 0, never the skipped-fold [ERROR]'
    Assert-True ($r.Out -match 'ALREADY been folded' -and $r.Out -match 'git pull --ff-only' -and $r.Out -notmatch 'fold-changelog-entry\.ps1 -Branch') `
        'and the remedy it prints is the pull, not the fold that would refuse on a stale trunk'

    # Mixed: origin folded one and still carries the other. The second is a real defect, so exit 1 --
    # and the pull is named too, because fold-changelog-entry.ps1 refuses on this stale trunk (#1405).
    $mix = New-Tree -Label 'mixedremote'
    Set-Doc -Dir $mix -Branch 'feat/alpha'
    Set-Doc -Dir $mix -Branch 'fix/beta'
    $bareMix = Initialize-GitTree -Dir $mix
    Push-UpstreamFold -Dir $mix -Bare $bareMix -RemoveRel @((Get-BranchFilePaths -Branch 'feat/alpha').File) -FoldBranch @('feat/alpha')
    $r = Invoke-Script -Dir $mix -Branch 'main'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match 'fold-changelog-entry\.ps1 -Branch fix/beta' -and $r.Out -notmatch 'fold-changelog-entry\.ps1 -Branch feat/alpha') `
        'one folded upstream, one genuinely stranded -- exit 1, and only the stranded one is offered a fold'
    Assert-True ($r.Out -match 'git pull --ff-only' -and $r.Out -match 'Already folded on origin.*feat-alpha') `
        'and the mixed report names the gap and says the pull clears the other document'

    # --- a checkout that is BOTH ahead and behind (issue #1601) -----------------------------------
    Write-Host ''
    Write-Host 'check-unfolded-entry.ps1 -- a DIVERGED checkout (#1601)'

    # THE STATE #1585 LEFT MISREAD, and the one case in this file whose fixture has to be built the long
    # way round: New-Tree + Initialize-GitTree commit everything at once, and this needs the document to
    # arrive as a LOCAL-ONLY commit while origin moves on independently. Ahead 1, behind 1 -- so
    # HEAD..origin/main is non-zero, the gap gate #1585 used would open, and the document is absent from
    # origin's tree for a reason that has nothing to do with a fold.
    $div = New-Tree -Label 'diverged'
    $divBare = Initialize-GitTree -Dir $div
    # origin gains a commit of its own -- this checkout is now BEHIND.
    Push-UpstreamUnrelated -Dir $div -Bare $divBare
    # ...and gains a merged-but-unfolded document that is only ever committed locally -- now AHEAD too.
    Set-Doc -Dir $div -Branch 'feat/alpha'
    Invoke-GitStep -GitArgs @('-C', $div, 'add', '-A')
    Invoke-GitStep -GitArgs @('-C', $div, 'commit', '-m', 'merge: feat/alpha (fold never ran)', '--quiet')
    Invoke-GitStep -GitArgs @('-C', $div, 'fetch', '--quiet', 'origin')
    $r = Invoke-Script -Dir $div -Branch 'main'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match 'fold-changelog-entry\.ps1 -Branch feat/alpha') `
        'ahead AND behind, entry not in origin CHANGELOG.md -- the fold is owed, [ERROR] exit 1'
    Assert-True ($r.Out -notmatch 'ALREADY been folded') `
        'and it is never called already folded -- the pull it used to prescribe cannot fast-forward here'

    # --- Test-BranchFoldedOnRef, the lib function ------------------------------------------------
    Write-Host ''
    Write-Host 'Test-BranchFoldedOnRef'

    . (Join-Path $RepoRoot 'scripts/lib/native-capture-lib.ps1')
    $refMain = 'refs/remotes/origin/main'
    Assert-True ((Test-BranchFoldedOnRef -RepoRoot $stale -Ref $refMain -Branch 'feat/alpha') -eq $true) `
        'origin carries the entry -- $true'
    Assert-True ((Test-BranchFoldedOnRef -RepoRoot $div -Ref $refMain -Branch 'feat/alpha') -eq $false) `
        'origin readable and does not name the branch -- $false, not $null'
    Assert-True ($null -eq (Test-BranchFoldedOnRef -RepoRoot $stale -Ref $refMain -Branch '')) `
        'no branch to key on -- $null'
    Assert-True ($null -eq (Test-BranchFoldedOnRef -RepoRoot $stale -Ref '' -Branch 'feat/alpha')) `
        'no ref -- $null'
    Assert-True ($null -eq (Test-BranchFoldedOnRef -RepoRoot $stale -Ref $refMain -Branch 'feat/alpha' -ChangelogRel 'dkj-policy/no-such-file.md')) `
        'no changelog at that ref -- $null, which the check reads as NOT folded'
    Assert-True ((Test-BranchFoldedOnRef -RepoRoot $stale -Ref $refMain -Branch 'feat/alph') -eq $false) `
        'a prefix of the folded branch does not answer for it -- matched as a whole name'

    # --- unfolded-entry-sessioncheck.ps1, the hook (always exit 0) --------------------------------
    Write-Host ''
    Write-Host 'unfolded-entry-sessioncheck.ps1'

    $r = Invoke-Hook -Dir (New-Tree -Label 'hook-clean')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no unfolded changelog entry on the trunk') `
        'clean trunk -- the in-sync line, exit 0'

    $hd = New-Tree -Label 'hook-dirty'
    Set-Doc -Dir $hd -Branch 'feat/alpha'
    $r = Invoke-Hook -Dir $hd
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'an unfolded changelog entry is sitting on the trunk' -and $r.Out -match 'feat/alpha') `
        'leftover on the trunk -- a compact summary carrying the [ERROR] detail, still exit 0'

    # #1585: the [WARN] arm reaches the session under its OWN headline. The error sentence -- "a merge
    # landed but its fold never ran" -- is precisely the mis-statement the issue reported, so its
    # absence is the assert that matters here.
    $hs = New-Tree -Label 'hook-stale'
    Set-Doc -Dir $hs -Branch 'feat/alpha'
    $bareHs = Initialize-GitTree -Dir $hs
    Push-UpstreamFold -Dir $hs -Bare $bareHs -RemoveRel @((Get-BranchFilePaths -Branch 'feat/alpha').File) -FoldBranch @('feat/alpha')
    $r = Invoke-Hook -Dir $hs
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'this checkout is just behind origin' -and $r.Out -match 'git pull --ff-only' -and $r.Out -notmatch 'its fold never ran') `
        'the fold already landed on origin -- the hook reports the stale checkout, never the skipped-fold sentence'

    $r = Invoke-Hook -Dir (New-Tree -Label 'hook-nocheck') -CheckScriptOverride (Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1")
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') `
        'check script missing -- a notice, exit 0, never a strand'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
