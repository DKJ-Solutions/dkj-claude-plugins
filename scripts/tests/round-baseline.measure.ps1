<#
.SYNOPSIS
    Measures a test round's baseline (the "ijkpunt" table) on a checkout and prints it as markdown,
    with every row naming HOW it was measured.

.DESCRIPTION
    A test round's papers open with a baseline table: the size, the line count, the commit count and
    the HEAD of the fixture repo, so a consumer can tell "I cloned the wrong thing" apart from "the
    table is stale". Round v12 typed that table by hand and got the line count wrong -- 23 where the
    file has 22 -- in the papers of the round that was verifying the very repair about naming a
    figure's convention (issue #371). Both numbers are defensible: 22 is the count of line
    terminators, 23 is the number of line positions an editor gutter shows. What was missing is the
    column that says which one is meant.

    So this script does two things a hand-typed table cannot:
      1. It computes every figure, so the number cannot be a typo.
      2. It prints BOTH line conventions as separate rows, each with its rule, so a consumer who
         measures the other one is not left deciding whether they mis-cloned.

    Deliberately a MEASUREMENT, not a test suite -- hence the .measure.ps1 suffix rather than
    .tests.ps1, so CI's `scripts/tests/*.tests.ps1` glob does not pick it up. It reports; it asserts
    nothing about whether the numbers are "right", because on a fresh clone whatever it finds IS the
    baseline. Its own correctness is pinned by scripts/tests/round-baseline.tests.ps1, which does run
    in CI.

    Read-only: it runs `git cat-file`/`rev-list`/`rev-parse`/`status` against -RepoPath and reads the
    files on disk. It writes nothing anywhere.

    Three states it will not report as an ordinary baseline, because each would produce a plausible
    table describing something other than a fresh clone:
      - a dirty working tree ([WARN]: the disk rows may not match the ref),
      - a shallow clone ([WARN]: the commit count is the fetch depth, not the history), and
      - an on-disk file whose content differs from the ref's (a hard error: the blob rows and the
        disk rows would then describe two different files).
    The two warnings are named in the table's provenance line rather than dropped, so a round that
    deliberately measures such a checkout still gets a table that says so.

    The table goes to STDOUT via Write-Output, so it can be redirected to a file or piped; warnings
    go to the host. Paste the block into the round's OPDRACHT.md instead of retyping the numbers.

.PARAMETER RepoPath
    The checkout to measure -- for a round, a freshly cloned fixture repo.

.PARAMETER Ref
    The git ref the figures describe. Default HEAD.

.PARAMETER Path
    Repo-relative file(s) to measure, comma-separated. Default README.md, the fixture's only file.
    With more than one, each row names its file.

    Deliberately a single [string] rather than [string[]]: `powershell -File` cannot bind an array
    parameter, so `-Path a,b` would arrive as the one string 'a,b' and be treated as a filename --
    the same trap that made pr-issues-lib's -Resolves a parsed string (Sylvester #15's lens). Parsing
    it here means the script behaves identically whether it is dot-run or invoked over -File.

.EXAMPLE
    # Stage a round: clone the fixture fresh, then measure it
    git clone https://github.com/DaveKJohn/specialists-adoptietest.git C:\tmp\fixture
    ./scripts/tests/round-baseline.measure.ps1 -RepoPath C:\tmp\fixture

.EXAMPLE
    # Capture the block for pasting into the papers
    ./scripts/tests/round-baseline.measure.ps1 -RepoPath C:\tmp\fixture > baseline.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [string]$Ref = 'HEAD',
    [string]$Path = 'README.md'
)
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

function Invoke-GitHere {
    <#
        git against $RepoPath, via the shared capture helper so a stderr line cannot terminate the
        script before $LASTEXITCODE is judged (Sylvester #15's rule). Returns the trimmed first
        output line; throws with git's own text on a non-zero exit.
    #>
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)

    $r = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $RepoPath) + $GitArgs)
    if ($r.ExitCode -ne 0) {
        $text = (@($r.Output) -join ' ').Trim()
        throw ("git " + ($GitArgs -join ' ') + " failed (exit $($r.ExitCode)): $text")
    }
    # Capture in full first, then slice -- never pipe the native command itself.
    $lines = @($r.Output)
    if ($lines.Count -eq 0) { return '' }
    return ([string]$lines[0]).Trim()
}

if (-not (Test-Path -LiteralPath $RepoPath)) {
    Write-Error "No such checkout: '$RepoPath'."
    exit 1
}
$repoFull = (Resolve-Path -LiteralPath $RepoPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $repoFull '.git'))) {
    Write-Error "'$repoFull' is not a git checkout (no .git) -- a baseline is measured on a clone."
    exit 1
}

# --- repo-level facts ------------------------------------------------------------------------------
try {
    $refSha      = Invoke-GitHere -GitArgs @('rev-parse', $Ref)
    $refShort    = Invoke-GitHere -GitArgs @('rev-parse', '--short', $Ref)
    $commitCount = Invoke-GitHere -GitArgs @('rev-list', '--count', $Ref)
    $isShallow   = (Invoke-GitHere -GitArgs @('rev-parse', '--is-shallow-repository')) -eq 'true'

    # Judged on the exit code, not on whether there was output: a failing `git status` writes text
    # too, and reading that as "dirty" would put a warning on the table for the wrong reason.
    $statusRun = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoFull, 'status', '--porcelain')
    if ($statusRun.ExitCode -ne 0) {
        throw ('git status failed (exit ' + $statusRun.ExitCode + '): ' + ((@($statusRun.Output) -join ' ').Trim()))
    }
    $porcelain = @(@($statusRun.Output) | Where-Object { $_ })
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

# core.autocrlf decides whether the disk bytes differ from the blob at all, so it belongs in the
# provenance rather than in a reader's head. `--get` exits 1 when the key is unset: not an error.
$autocrlfRun = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoFull, 'config', '--get', 'core.autocrlf') -DiscardStderr
$autocrlf    = if ($autocrlfRun.ExitCode -eq 0) { ([string]@($autocrlfRun.Output)[0]).Trim() } else { 'unset' }
if (-not $autocrlf) { $autocrlf = 'unset' }

$paths = @(($Path -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($paths.Count -eq 0) {
    Write-Error "-Path is empty -- pass one repo-relative file, or several separated by commas."
    exit 1
}

$warnings = @()
if ($porcelain.Count -gt 0) {
    $warnings += "the working tree is dirty ($($porcelain.Count) changed path(s)), so the on-disk rows may not match $Ref"
}
if ($isShallow) {
    $warnings += 'this is a SHALLOW clone, so the commit count is the fetch depth and not the history'
}

# --- per-file facts --------------------------------------------------------------------------------
$rows      = @()
$multiFile = $paths.Count -gt 1

foreach ($rel in $paths) {
    $relGit  = $rel -replace '\\', '/'
    $onDisk  = Join-Path $repoFull ($relGit -replace '/', '\')
    $label   = if ($multiFile) { " ``$relGit``" } else { '' }

    if (-not (Test-Path -LiteralPath $onDisk)) {
        Write-Error "'$relGit' does not exist in '$repoFull' -- measure a checkout of $Ref, or pass -Path."
        exit 1
    }

    try { $blobBytes = [int](Invoke-GitHere -GitArgs @('cat-file', '-s', "${Ref}:${relGit}")) }
    catch {
        Write-Error "'$relGit' is not in $Ref ($($_.Exception.Message))."
        exit 1
    }

    # The blob rows come from $Ref and the disk rows from the working tree, so they describe the same
    # file only while the worktree holds $Ref's content. Found by this script's own first smoke test:
    # it measured `main` in a checkout standing on another branch, and the table was right only
    # because that branch happened not to touch the file. Right by luck is the defect class #371 is
    # about, so this refuses rather than warns. `git diff`
    # compares NORMALIZED content, so a CRLF working tree against an LF blob is not a difference
    # here; that is the distinction the two size rows exist to report.
    $sameRun = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoFull, 'diff', '--quiet', $Ref, '--', $relGit)
    if ($sameRun.ExitCode -eq 1) {
        Write-Error ("'$relGit' on disk differs from its content in $Ref, so the blob rows and the " +
                     "disk rows would describe different files. Check out $Ref first (or pass -Ref for " +
                     'the commit this checkout is actually on).')
        exit 1
    } elseif ($sameRun.ExitCode -gt 1) {
        Write-Error ("git diff could not compare '$relGit' against ${Ref}: " + ((@($sameRun.Output) -join ' ').Trim()))
        exit 1
    }

    $bytes     = [System.IO.File]::ReadAllBytes($onDisk)
    $diskBytes = $bytes.Length

    # Count terminators on the raw bytes rather than via a text reader: Get-Content would hide the
    # difference between LF and CRLF, which is the whole point of the two size rows.
    $lf = 0; $crlf = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 0x0A) {
            $lf++
            if ($i -gt 0 -and $bytes[$i - 1] -eq 0x0D) { $crlf++ }
        }
    }
    $endsWithNewline = ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -eq 0x0A)

    # The two conventions #371 is about. contentLines is what (Get-Content).Count returns; positions
    # is what an editor gutter shows, which is one more whenever the file ends with a terminator.
    if ($bytes.Length -eq 0) {
        $contentLines = 0
        $positions    = 0
    } else {
        $contentLines = if ($endsWithNewline) { $lf } else { $lf + 1 }
        $positions    = $lf + 1
    }

    $measured = (Get-Content -LiteralPath $onDisk | Measure-Object -Line).Lines
    $delta    = $diskBytes - $blobBytes

    $eolOnDisk = if ($crlf -eq 0 -and $lf -gt 0) { 'LF' } elseif ($crlf -eq $lf -and $lf -gt 0) { 'CRLF' } else { 'mixed' }
    $deltaHow  =
        if ($delta -eq 0 -and $crlf -eq 0) {
            'disk minus blob; zero because the file is LF on disk too'
        } elseif ($delta -eq $crlf) {
            "disk minus blob; exactly the $crlf CRLF conversion(s), so $crlf terminator(s) is $contentLines line(s) either way"
        } else {
            "disk minus blob; NOT explained by the $crlf CRLF conversion(s) on disk -- the blob may not be LF-normalized"
        }
    if ($delta -ne 0 -and $delta -ne $crlf) {
        $warnings += "the size delta on '$relGit' ($delta bytes) does not match its $crlf CRLF conversion(s)"
    }

    $rows += ,@("size, repo side$label",              "$blobBytes bytes",  "``git cat-file -s ${Ref}:${relGit}`` -- the blob, so LF")
    $rows += ,@("size, on disk$label",                "$diskBytes bytes",  "the file's byte length; $eolOnDisk on disk, ``core.autocrlf=$autocrlf``")
    $rows += ,@("size delta$label",                   "$delta bytes",      $deltaHow)
    $rows += ,@("lines, terminated$label",            "$contentLines",     "count of LF terminators; what ``(Get-Content $relGit).Count`` returns")
    $rows += ,@("line positions$label",               "$positions",        $(if ($endsWithNewline) { "terminators + 1, because the file ends with a terminator; what an editor gutter shows" } else { "terminators + 1; the file does NOT end with a terminator, so this equals the terminated count" }))
    $rows += ,@("lines per ``Measure-Object -Line``$label", "$measured",    'that cmdlet skips empty lines')
}

$rows += ,@("commits on ``$Ref``", "$commitCount", "``git rev-list --count $Ref`` on a $(if ($isShallow) { 'SHALLOW' } else { 'non-shallow' }) clone")
$rows += ,@("``$Ref``",            "``$refShort``", "``git rev-parse --short $Ref``; in full ``$refSha``")

# --- print -----------------------------------------------------------------------------------------
foreach ($w in $warnings) { Write-Warning $w }

$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Output "<!-- generated by scripts/tests/round-baseline.measure.ps1 on $stamp -- regenerate, do not retype -->"
Write-Output ''
Write-Output "Measured on a checkout of ``$Ref`` (``$refSha``), ``core.autocrlf=$autocrlf``, shallow: $(if ($isShallow) { 'yes' } else { 'no' }), working tree: $(if ($porcelain.Count -gt 0) { "dirty ($($porcelain.Count) path(s))" } else { 'clean' })."
Write-Output ''
Write-Output '| measure | value | how measured |'
Write-Output '|---|---|---|'
foreach ($row in $rows) {
    Write-Output ("| {0} | **{1}** | {2} |" -f $row[0], $row[1], $row[2])
}

exit 0
