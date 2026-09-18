<#
.SYNOPSIS
    Tests for scripts/lib/repo-root-lib.ps1 -- the repo-root read that the console code page cannot
    corrupt (issue #2115).

.DESCRIPTION
    THE PROPERTY THAT WOULD BREAK SILENTLY IS THAT THE ANSWER IS A PATH THAT EXISTS. Every caller
    uses this root as a prefix: Join-Path for a lib, a Test-Path that decides whether a check has
    anything to judge, a Resolve-Path that throws. A mis-decoded root does not look wrong -- it is a
    well-formed string of the right shape that simply matches nothing, so the failure surfaces two
    frames later as "cannot determine the repo root" about a tree that is right there, or as a silent
    skip in the branch of a session hook that has no CLAUDE_PROJECT_DIR to fall back on.

    CASE 5 IS THE ONE THE ISSUE WAS ABOUT, AND IT IS ASSERTED ON RAW BYTES RATHER THAN ON A CONSOLE.
    The obvious test -- set [Console]::OutputEncoding to cp850 and watch the old form fail -- is
    FORBIDDEN here, and by the rule this defect belongs to: that setter is SetConsoleOutputCP, which
    is console-WIDE, and the gate runs every suite on one shared console. A sibling suite holding
    UTF-8 is precisely how inbound #821 stayed invisible, an assert going green under the gate while
    it was red on its own. So the suite never touches it. What it asserts instead is the MECHANISM,
    which is console-independent and therefore a stronger test than any single code page: in a
    repository whose path carries an accent, --show-toplevel's stdout contains bytes >= 0x80 while
    --is-inside-work-tree --show-cdup's stdout is pure ASCII. The first half is what makes the old
    form decoder-dependent; the second is what makes this one immune. Both are read as BYTES, from a
    child process writing to a file, so no decoding happens anywhere in the measurement.

    CASE 6 IS THE REGRESSION THE OBVIOUS REPAIR WOULD HAVE INTRODUCED, and it is why this lib asks
    two flags rather than one. --show-cdup ALONE exits 0 inside the .git directory and prints nothing,
    where --show-toplevel exits 128 with "this operation must be run in a work tree" -- so a
    straight flag swap would have resolved the .git directory itself as the repo root and reported
    success. Nothing downstream would have caught it: .git exists, so every Test-Path passes.

    CASE 10 IS STRUCTURAL, and it is here because cases 1-9 all pass against a tree in which the
    three canonical resolvers still do their own raw read. This defect's whole shape was ~20 call
    sites agreeing on a wrong idiom, so the assert that matters for the NEXT one is that the
    resolvers route through this lib rather than that this lib is correct in isolation.

    Dependency-free (no Pester), same style as the rest of the suite. Fixtures are real git repos
    under the temp root, one of them deliberately named with a non-ASCII character.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\repo-root-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Write-Host "== repo-root-lib ==" -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LibPath) 'repo-root-lib.ps1 exists at its registered source path'
. $LibPath

$FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "repo-root-lib-tests-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding $false

function Invoke-FixtureGit {
    <#
        Git MUTATIONS inside a fixture, run under EAP=Continue -- the repo's standing pitfall: `git
        add` writes the autocrlf notice to stderr, which under 'Stop' is a TERMINATING
        NativeCommandError even though git exits 0.
    #>
    param([string]$Dir, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & git -C $Dir @GitArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ("fixture git failed ({0}): git {1} -- {2}" -f $LASTEXITCODE, ($GitArgs -join ' '), (($out | Out-String).Trim()))
        }
    } finally { $ErrorActionPreference = $prev }
}

function New-GitFixture {
    <#
        A real repository with one committed file, at a caller-chosen directory NAME -- which is the
        whole point here, since one case needs that name to carry a non-ASCII character.
    #>
    param([string]$Name)
    $dir = Join-Path $FixtureRoot $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-FixtureGit -Dir $dir 'init' '-q'
    Invoke-FixtureGit -Dir $dir 'config' 'core.autocrlf' 'false'
    Invoke-FixtureGit -Dir $dir 'config' 'user.email' 'tycho@example.test'
    Invoke-FixtureGit -Dir $dir 'config' 'user.name'  'Tycho'
    # Pinned for the reason #1287 records: a machine with commit.gpgsign=true and a locked signing
    # agent would otherwise fail every fixture commit, naming the script under test.
    Invoke-FixtureGit -Dir $dir 'config' 'commit.gpgsign' 'false'
    [System.IO.File]::WriteAllText((Join-Path $dir 'tracked.txt'), "one`n", $Utf8NoBom)
    Invoke-FixtureGit -Dir $dir 'add' '-A'
    Invoke-FixtureGit -Dir $dir 'commit' '-qm' 'init'
    return (Resolve-Path -LiteralPath $dir).ProviderPath
}

function Get-GitStdoutBytes {
    <#
        git's stdout as RAW BYTES, captured by a child process writing straight to a file -- so
        nothing in this measurement is decoded by anything. PowerShell's own '>' would re-encode the
        already-decoded string, which is the very step under test.
    #>
    param([string]$WorkingDirectory, [string[]]$GitArgs)
    $out = Join-Path $FixtureRoot ("stdout-" + [guid]::NewGuid().ToString('n') + '.bin')
    $p = Start-Process -FilePath 'git' -ArgumentList $GitArgs -WorkingDirectory $WorkingDirectory `
                       -RedirectStandardOutput $out -NoNewWindow -Wait -PassThru
    $bytes = [System.IO.File]::ReadAllBytes($out)
    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Bytes = $bytes; ExitCode = $p.ExitCode }
}

try {
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null

    $plain    = New-GitFixture -Name 'plain-repo'
    # U+00E9 composed rather than typed, so this file stays pure ASCII (repo convention for .ps1) and
    # cannot itself be mangled by whatever wrote or read it.
    $accented = New-GitFixture -Name ('caf' + [char]0x00E9 + '-repo')

    # (1) THE ORDINARY CASE, from the root itself. cdup is empty here, so this also pins that an empty
    #     cdup means "the base IS the root" rather than "no answer".
    Push-Location $plain
    try { $fromRoot = Get-GitTopLevelPath } finally { Pop-Location }
    Assert-Equal $plain $fromRoot.Path 'resolves the root when standing on it'
    Assert-Equal 0 $fromRoot.ExitCode 'and reports git exit code 0'

    # (2) FROM A NESTED SUBDIRECTORY -- the case cdup actually walks. Same answer as (1), which is
    #     what makes the composition trustworthy rather than a coincidence of being at the root.
    $nested = Join-Path $plain 'a\b\c'
    New-Item -ItemType Directory -Path $nested -Force | Out-Null
    Push-Location $nested
    try { $fromNested = Get-GitTopLevelPath } finally { Pop-Location }
    Assert-Equal $plain $fromNested.Path 'resolves the same root from a nested subdirectory'

    # (3) NO TRAILING SEPARATOR. '../' composes one and --show-toplevel never returned one, so a
    #     caller comparing this against a stored root would otherwise see two spellings of one path.
    Assert-True (-not ($fromNested.Path.EndsWith('\') -or $fromNested.Path.EndsWith('/'))) `
        'the composed root carries no trailing separator'

    # (4) THE ACCENTED CHECKOUT -- the consumer case. The answer must be the path that exists, not a
    #     well-formed string of the right shape.
    Push-Location $accented
    try { $fromAccented = Get-GitTopLevelPath } finally { Pop-Location }
    Assert-Equal $accented $fromAccented.Path 'resolves a root whose path carries a non-ASCII character'
    Assert-True ($fromAccented.Path -and (Test-Path -LiteralPath $fromAccented.Path)) `
        'and the path it returns actually exists (the assert a mis-decoded root fails)'

    # (5) THE MECHANISM, ON RAW BYTES -- see the header for why this is not a console test. The first
    #     half proves the fixture really is non-ASCII and that the OLD flag really does put raw bytes
    #     on the wire for the console code page to mangle; the second is the property this lib rests
    #     on. Neither depends on which code page the gate happens to be running under.
    $topBytes  = Get-GitStdoutBytes -WorkingDirectory $accented -GitArgs @('rev-parse', '--show-toplevel')
    $cdupBytes = Get-GitStdoutBytes -WorkingDirectory $accented -GitArgs @('rev-parse', '--is-inside-work-tree', '--show-cdup')
    Assert-True (@($topBytes.Bytes | Where-Object { $_ -ge 0x80 }).Count -gt 0) `
        '--show-toplevel puts bytes >= 0x80 on the wire in an accented checkout (the defect)'
    Assert-True (@($cdupBytes.Bytes | Where-Object { $_ -ge 0x80 }).Count -eq 0) `
        '--is-inside-work-tree --show-cdup is pure ASCII in that same checkout (the repair)'

    # (6) INSIDE .git -- the regression a straight flag swap would have introduced. --show-cdup exits
    #     0 here and prints nothing; only the work-tree flag separates this from "the root".
    Push-Location (Join-Path $plain '.git')
    try { $fromGitDir = Get-GitTopLevelPath } finally { Pop-Location }
    Assert-Equal $null $fromGitDir.Path 'refuses inside the .git directory, where --show-cdup alone would answer'

    # (7) OUTSIDE A REPOSITORY. $FixtureRoot is a plain directory, and the temp root above it is not
    #     a checkout on any machine this runs on.
    Push-Location $FixtureRoot
    try { $outside = Get-GitTopLevelPath } finally { Pop-Location }
    Assert-Equal $null $outside.Path 'returns no path outside a repository'
    Assert-True ($outside.ExitCode -ne 0) 'and reports git''s non-zero exit code rather than 0'

    # (8) -From ANCHORS THE QUESTION without moving the process. Asserted from a directory that is
    #     NOT the subject, which is the only way to tell an anchored read from a lucky cwd.
    Push-Location $FixtureRoot
    try { $anchored = Get-GitTopLevelPath -From $accented } finally { Pop-Location }
    Assert-Equal $accented $anchored.Path '-From resolves another tree without changing the current directory'

    # (9) -From ON A NESTED DIRECTORY walks up, exactly as the cwd form does.
    Push-Location $FixtureRoot
    try { $anchoredNested = Get-GitTopLevelPath -From $nested } finally { Pop-Location }
    Assert-Equal $plain $anchoredNested.Path '-From on a subdirectory resolves that tree''s root'

    # (10) THE THREE CANONICAL RESOLVERS ROUTE THROUGH THIS LIB. See the header: the defect was ~20
    #      call sites agreeing on a wrong idiom, so what has to be pinned is the routing, not only the
    #      lib. A raw read coming back into any of these is what this assert refuses.
    foreach ($pair in @(
        @{ File = 'scripts\lib\check-report-lib.ps1';      Fn = 'Resolve-CheckRoot' },
        @{ File = 'scripts\lib\consumer-check-lib.ps1';    Fn = 'Resolve-CheckRepoRoot' },
        @{ File = 'scripts\lib\source-repo-guard-lib.ps1'; Fn = 'Resolve-GuardRepoRoot' }
    )) {
        $text = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $pair.File))
        Assert-True ($text -match 'Get-GitTopLevelPath') `
            ("$($pair.File) resolves its root through Get-GitTopLevelPath ($($pair.Fn))")
    }
} finally {
    if (Test-Path -LiteralPath $FixtureRoot) {
        Remove-Item -LiteralPath $FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:pass) passed, $($script:fail) failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($script:pass) passed." -ForegroundColor Green
exit 0
