<#
.SYNOPSIS
    Get-GitTopLevelPath: the repository root, asked for in a way the console code page cannot
    corrupt (issue #2115).

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot 'repo-root-lib.ps1')

    ONE DEFINITION FOR "WHERE IS THE REPO ROOT", and the reason it exists is that the repair
    .claude/rules/language-layers.md prescribes for this class does not reach it.

    THE MEASUREMENT (September 18, 2026). That rule says to hold a git path read to ASCII on the wire
    and decode it yourself -- `core.quotePath=true` plus Convert-GitQuotedPath -- because every
    candidate code page agrees below 0x80. core.quotePath governs the path OUTPUT of the porcelain
    that consults it, and `rev-parse` is not such a porcelain. In a repo at ...\caf<e9>-repo, both
    calls under the forced flag:

        git -c core.quotePath=true ls-files         ->  "caf\303\251.md"     (ASCII, quoted)
        git -c core.quotePath=true rev-parse --show-toplevel
                                                    ->  ...\caf<C3><A9>-repo (RAW UTF-8 bytes)

    So every unguarded `rev-parse --show-toplevel` hands raw bytes to Windows PowerShell 5.1, which
    decodes a native child's stdout with [Console]::OutputEncoding -- cp850 here, cp1252 elsewhere,
    cp65001 in a UTF-8 terminal. Measured across all three, resolving the same root: Test-Path on the
    result is False on cp850 and cp1252 and True only on cp65001. The failure that follows is a
    Test-Path miss reported as "cannot determine the repo root", or -- in the branch of a session hook
    that has no CLAUDE_PROJECT_DIR to fall back on -- a silent skip.

    IT IS LATENT IN THE SOURCE REPO AND LIVE IN A CONSUMER. This checkout's path is ASCII, so nothing
    here has ever failed on it. A consumer whose checkout sits under an accented directory name is the
    ordinary case on a non-English Windows box (C:\Users\<name>\Bureaublad\..., a company folder with
    a diacritic), and the shared scripts this workflow mirrors into their plugin cache are the ones
    that would fail there.

    WHY --show-cdup AND NOT -Utf8, which is the repair #2115 proposed. -Utf8 is correct in mechanism:
    Invoke-NativeCapture -Utf8 redirects to a file and decodes it explicitly, which is provably immune.
    It is unavailable at the call sites that matter most. A script resolves the repo root in order to
    FIND scripts\lib\, so the dot-source that would supply Invoke-NativeCapture runs after the line
    that needs it -- measure-always-on.ps1 says exactly that in a comment of its own, and the five
    lint checks carry the same read as a lib-free degraded fallback by design. A repair that cannot be
    applied at the bootstrap is not a repair for this class.

    --show-cdup removes the problem rather than decoding around it. It reports the root as a path
    RELATIVE to the directory git was asked about, which is a run of '../' segments and nothing else
    -- no filename ever appears in it, so there is nothing in the output for a code page to corrupt.
    Measured from a directory whose own name carries accents (caf<e9>-repo\na<ef>ve\sub): the output is
    the seven bytes '../../\n'. The base it is joined onto is a string PowerShell already holds
    correctly ($From, or the current location), so the composed root is right on every code page --
    measured True on cp850, cp1252 and cp65001. It needs no lib, no capture file and no child process
    beyond the one git call, which is what lets the bootstrap sites use it.

    AND IT IS ASKED TOGETHER WITH --is-inside-work-tree, IN ONE CALL, because the two flags do not
    fail together. Inside the .git directory, --show-toplevel exits 128 with "this operation must be
    run in a work tree" while --show-cdup exits 0 and prints nothing -- so a naive swap would resolve
    the .git directory itself as the repo root and report success. That is a regression -Utf8 would
    not have had, and it is the one thing this function has to get right that the old form got right
    for free. `git rev-parse --is-inside-work-tree --show-cdup` answers both in a single invocation,
    and both lines are pure ASCII:

        in a subdirectory  ->  'true'  then '../../'
        at the root        ->  'true'  then ''
        inside .git        ->  'false' and NO cdup line at all
        outside a repo     ->  exit 128, nothing on stdout

    WHAT IT DOES NOT PROMISE, deliberately. --show-toplevel resolves symlinks; this composes a path
    from the base it was given, so on a symlinked checkout the two can name the same directory
    differently. Every caller here either hands the result to Resolve-Path or uses it as a prefix for
    Join-Path, both of which are indifferent to that -- and a caller that genuinely needs the
    canonical spelling should Resolve-Path it, which is what Resolve-CheckRoot already does.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

function Get-GitTopLevelPath {
    <#
        The work-tree root for $From (default: the current location), or $null.

        Returns a pscustomobject, never a bare string, because the caller that refuses needs to say
        WHY and git's own line is the only thing that says it (the reason check-report-lib's
        Resolve-CheckRoot captures stderr rather than letting it through, #1917):

          - Path     : the resolved root, or $null when git declined or this is not a work tree.
          - ExitCode : git's exit code, or $null when git could not be run at all. Those are
                       different facts and a refusal that prints one for the other misleads.
          - Error    : git's own stderr, joined; '' when it said nothing.

        -From ANCHORS THE QUESTION and is also the base the answer is composed from. It goes before
        the subcommand and only when non-empty -- an empty -C is not the same as no -C at all, git
        reads it as a path and fails.

        EAP IS NEUTRALISED AROUND THE NATIVE CALL, for the measured reason check-branch-entry.ps1
        records: under $ErrorActionPreference = 'Stop' a native command that SUCCEEDS and also writes
        to stderr throws non-deterministically, depending on how stdout and stderr interleave -- 7 of
        8 identical runs in that measurement -- which turns a perfectly resolvable root into a
        "could not tell". The catch is the backstop; the wrap is what stops it firing on a success.
    #>
    param([string]$From = '')

    $lines    = @()
    $exitCode = $null
    $errText  = ''

    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            if ($From) { $raw = @(& git -C $From rev-parse --is-inside-work-tree --show-cdup 2>&1) }
            else       { $raw = @(& git rev-parse --is-inside-work-tree --show-cdup 2>&1) }
            $exitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prevEap }

        $errLines = @($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $lines    = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
                        ForEach-Object { ([string]$_).Trim() })
        $errText  = (($errLines | ForEach-Object { [string]$_ }) -join '; ').Trim()
    } catch {
        $errText = $(if ($errText) { $errText } else { $_.Exception.Message })
    }

    $result = [pscustomobject]@{ Path = $null; ExitCode = $exitCode; Error = $errText }
    if ($exitCode -ne 0) { return $result }

    # LINE 0 IS THE WORK-TREE VERDICT AND IT IS CHECKED BEFORE THE cdup IS USED -- see the file
    # synopsis: inside .git this reads 'false' and no cdup line follows, which is exactly the state
    # --show-toplevel refused and this form would otherwise resolve to the .git directory.
    if ($lines.Count -lt 1 -or $lines[0] -ne 'true') { return $result }

    # THE BASE IS A STRING POWERSHELL ALREADY HOLDS, which is the whole mechanism. .ProviderPath
    # rather than .Path because a caller may be standing on a non-FileSystem PSDrive, where .Path
    # carries the provider-qualified spelling and Join-Path would compose nonsense from it.
    $base = $(if ($From) { $From } else { $PWD.ProviderPath })
    $cdup = $(if ($lines.Count -ge 2) { $lines[1] } else { '' })

    try {
        $full = $(if ($cdup) { [System.IO.Path]::GetFullPath((Join-Path $base $cdup)) }
                  else       { [System.IO.Path]::GetFullPath($base) })
    } catch {
        $result.Error = $(if ($errText) { $errText } else { $_.Exception.Message })
        return $result
    }

    # A TRAILING SEPARATOR IS TRIMMED, because '../' composes one and --show-toplevel never returned
    # one -- so a caller comparing this against a stored root would see two spellings of one path.
    # Guarded on length so a drive root ('C:\') keeps the separator that makes it a valid path.
    if ($full.Length -gt 3 -and ($full.EndsWith('\') -or $full.EndsWith('/'))) {
        $full = $full.TrimEnd('\', '/')
    }

    $result.Path = $full
    return $result
}
