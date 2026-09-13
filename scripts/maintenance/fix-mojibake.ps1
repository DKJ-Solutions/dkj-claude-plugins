<#
.SYNOPSIS
    Repairs double-encoded characters (mojibake) in text files.

.DESCRIPTION
    Repairs mojibake -- UTF-8 that was once read as Windows-1252 and then saved as UTF-8 again -- by
    running that operation backwards: each run of non-ASCII text is re-encoded to Windows-1252 and
    decoded as UTF-8, repeatedly, for as long as the result gets shorter. Correctly encoded characters
    (em dash, arrow, accents) fail that round trip and are left alone, which is what makes it safe.
    Idempotent.

    IT USED TO WORK OFF A TABLE OF KNOWN SEQUENCES, and that is why this section leads with the method.
    A table repairs the characters somebody thought to write down; on August 2, 2026 this repo held 517
    doubly-encoded runs -- em dashes, arrows, ellipses, en dashes -- that matched no rule in it, in files
    the gate beside this tool reported as clean. The table survives below as a net for the cases the
    round trip cannot reach, but it is no longer the method.

    HOW THE DAMAGE HAPPENS, because knowing this is what prevents it. Windows PowerShell 5.1's
    Get-Content reads a BOM-less UTF-8 file as ANSI unless told otherwise, so a middot (U+00B7, bytes
    C2 B7) comes back as two characters. Writing that back as UTF-8 stores the mangled pair. One
    Get-Content-plus-write round trip is enough, and nothing errors -- the file stays valid UTF-8, it
    just says something else.

    Measured here on August 1, 2026: demoting four headings in CHANGELOG.md with
    Get-Content + WriteAllLines mangled 35 separators, and because the separator IS the field delimiter
    in an entry heading, cut-release.ps1 could no longer read the entry TYPE. Eleven entries fell into a
    catch-all category instead of Features/Fixes/Documentation. Caught by inspecting the notes before
    pushing (-NoPush), which is exactly what that flag is for.

    Prevention, in order of preference: (1) use the Read/Edit tooling or
    [System.IO.File]::ReadAllText(<path>, [Text.Encoding]::UTF8) -- never bare Get-Content -- when a
    file may hold non-ASCII; (2) let the lint gate catch it (check 14 in
    scripts/lint/check-plugin-integrity.ps1); (3) run this script.

    THIS SOURCE IS PURE ASCII, via [char]0x.. codepoints, so the repair tool cannot itself be mangled
    by the very round trip it repairs. That is not decoration -- a mojibake table written as literal
    characters corrupts on the first careless edit and then silently repairs nothing.

    WHY BOTH THE ROUND TRIP AND THE TABLE REPEAT TO A FIXPOINT. Text can have been through the mangle
    twice; the middot from a changelog heading then comes out as four characters rather than two. A
    single pass peels one layer and leaves a remainder -- which is what cost life-hub a manual fix in
    PR #106 at its v2.1.0, and what hid the 517 sequences here. Both loops repeat until nothing changes,
    and termination is guaranteed the same way in both: every accepted step makes the text strictly
    shorter.

    A UTF-8 BOM on the file is preserved; a file without one does not gain one.

    Ported from life-hub (scripts/maintenance/fix-mojibake.ps1), which took it from smartwatchbanden.
    This is the third repo to need it, which is the argument for the gate beside it rather than for
    remembering to run it -- and, since issue #413, the argument for mirroring this file into the plugin
    instead of each repo keeping a copy. Three copies of a repair tool drift, and the one that drifts is
    the one nobody reads until the day it matters. The workshop copy is the source; the plugin mirror is
    what a consumer runs (see scripts/lib/shared-scripts-lib.ps1).

.PARAMETER Path
    Files to repair. Without it, the set is REPO-OWNED: Get-MojibakePaths in the consumer's
    scripts/repo-config.ps1 names it (issue #413), and when that function is absent this script falls
    back to every *.md in the repo root -- the changelog, the root docs and any unfolded entry file,
    which is a defensible set in any repo.

    The list used to live in this file, and it was workshop-shaped: it walked plugins/** and
    releases/**, neither of which exists in a consumer, so the Test-Path filter below silently reduced
    the default to whatever root docs happened to be present. A gate that examines almost nothing while
    reporting "clean" is worse than no gate, which is the same argument the round-trip method further
    down replaced the lookup table for.

.PARAMETER Check
    Report only, change nothing, exit 1 if any file would change -- for a gate or a dry run.

.EXAMPLE
    ./scripts/maintenance/fix-mojibake.ps1

.EXAMPLE
    ./scripts/maintenance/fix-mojibake.ps1 -Check
#>
param(
    [string[]]$Path,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'fix-mojibake.ps1'

if (-not $Path -or @($Path).Count -eq 0) {
    # The repo-owned set (issue #413). repo-config.ps1 is OPTIONAL here, exactly as it is for
    # new-branch.ps1 (#410): a repair tool that refuses to run because a config file is missing
    # helps nobody, and the fallback below is a real answer rather than a degraded one.
    #
    # Dot-sourced and probed in a CHILD scope with StrictMode explicitly OFF -- this script runs under
    # Set-StrictMode -Version Latest, while repo-config.ps1 is documented as written on the no-strict-mode
    # assumption that its real runtime callers (open-pr, fold, ...) never enable it. Probing it under
    # strict mode is how check-script-contract.ps1 once produced false failures for legacy-but-working
    # consumer libs; the same trap, avoided the same way.
    $configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
    $configured = $null
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $configured = & {
            Set-StrictMode -Off
            try { . $args[0] } catch {
                Write-Warning "scripts\repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- using the built-in default file set."
                return $null
            }
            if (Test-FunctionDefined 'Get-MojibakePaths') {
                return @(Get-MojibakePaths -RepoRoot $args[1])
            }
            return $null
        } $configPath $repoRoot
    }

    if ($null -ne $configured -and @($configured).Count -gt 0) {
        $Path = @($configured)
    } else {
        # Repo-agnostic fallback: every markdown file in the repo root. That is the changelog, the root
        # docs, and any unfolded entry file -- the three kinds this damage is actually found in, in any
        # repo. Deliberately not a hand-listed set of file names: a root doc added later would fall out
        # of a list silently, which is the accumulation shape this repo keeps paying for.
        $Path = @(Get-ChildItem -LiteralPath $repoRoot -Filter '*.md' -File |
            Select-Object -ExpandProperty FullName)
    }
    $Path = @($Path | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique)
}

# Build a string from codepoints, so this source stays ASCII-only.
function C([int[]]$cp) { -join ($cp | ForEach-Object { [char]$_ }) }

# Mojibake sequence -> correct character.
$map = [ordered]@{
    (C 0xF0, 0x178, 0x2019, 0xA1) = [System.Char]::ConvertFromUtf32(0x1F4A1)  # bulb emoji
    (C 0xE2, 0x20AC, 0x201D)      = (C 0x2014)  # em dash
    (C 0xE2, 0x20AC, 0x201C)      = (C 0x2013)  # en dash
    (C 0xE2, 0x20AC, 0xA6)        = (C 0x2026)  # ellipsis
    (C 0xE2, 0x2020, 0x2019)      = (C 0x2192)  # arrow right
    (C 0xE2, 0x2020, 0x90)        = (C 0x2190)  # arrow left
    (C 0xE2, 0x2020, 0x201D)      = (C 0x2194)  # arrow left-right
    (C 0xC3, 0xA9)                = (C 0xE9)    # e acute
    (C 0xC3, 0xB3)                = (C 0xF3)    # o acute
    (C 0xC3, 0xAB)                = (C 0xEB)    # e diaeresis
    (C 0xC3, 0xA1)                = (C 0xE1)    # a acute
    (C 0xC3, 0xAD)                = (C 0xED)    # i acute
    (C 0xC3, 0xB6)                = (C 0xF6)    # o diaeresis
    (C 0xC3, 0x2030)              = (C 0xC9)    # E acute
    (C 0xC2, 0xA7)                = (C 0xA7)    # section sign
    (C 0xC2, 0xB7)                = (C 0xB7)    # MIDDOT -- the field separator in an entry heading
    (C 0xC3, 0x201A)              = (C 0xC2)    # outer layer of a doubly-encoded 0xC2 sequence
}

# THE GENERAL METHOD, and why the table above is no longer the primary one.
#
# Mojibake is one specific operation: UTF-8 bytes decoded as Windows-1252. So its inverse is equally
# specific -- encode the text back to Windows-1252 bytes and decode those as UTF-8 -- and running that
# inverse repairs ANY character, not the seventeen somebody happened to write down.
#
# The table was the whole method until August 2, 2026, and it was measurably not enough. It carries the
# single-layer form of the em dash, en dash, ellipsis and arrow, and one lone outer-layer peel rule
# (0xC3,0x201A -> 0xC2) added when double encoding first bit. Damage that is double-encoded in any OTHER
# character matches nothing: the fixpoint loop has no first rule to apply, so it exits on the first pass
# and the file is declared clean. Measured on this repo at v3.1.0: 1551 double-encoded sequences across
# CHANGELOG.md, the then-existing per-plugin CHANGELOG.md and RELEASE.md, and the 3.1.0 release notes
# -- 315 em dashes, 43 arrows, 10 ellipses, 4 en dashes -- while the gate that reads this tool reported
# "No findings" over three of those four files. A gate that cannot see the damage it exists to catch is
# worse than no gate, because it is also a claim.
#
# BOTH ENCODERS THROW ON ANYTHING UNEXPECTED, and that is the safety property the whole approach rests
# on. With the default fallbacks, a character Windows-1252 cannot represent becomes '?' and a byte
# sequence that is not valid UTF-8 becomes U+FFFD -- silently, which would turn a repair tool into a
# corruption tool on exactly the files it is pointed at. Strict, the round trip simply FAILS on text that
# was never mojibake, and failure means "leave this alone".
#
# Verified before adoption, because "it should be safe" is not a measurement: a correct em dash, arrow,
# middot, e-acute and a two-character run of u-diaeresis all fail the round trip and are left untouched,
# while the eight-character double-encoded em dash peels to three characters and then to U+2014. The
# undefined Windows-1252 positions (0x81, 0x8D, 0x8F, 0x90, 0x9D) round-trip byte-for-byte in .NET, which
# matters because 0x9D is the last byte of the double-encoded em dash -- the single most common sequence
# in the measured damage.
$cp1252 = [System.Text.Encoding]::GetEncoding(1252,
    [System.Text.EncoderExceptionFallback]::new(),
    [System.Text.DecoderExceptionFallback]::new())
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

# Maximal runs of non-ASCII characters. ASCII is a fixpoint of the round trip in both directions, so
# including it would only fuse every run in the file into one and make a single un-peelable character
# block the repair of everything else on that line.
$nonAsciiRun = [regex]'[^\x00-\x7F]+'

function Repair-Run([string]$Run) {
    <# One run, peeled to a fixpoint. Returns the text and how many layers came off (0 = not mojibake).

       STRICTLY SHORTER OR STOP. Every real peel collapses n UTF-8 bytes into one character, so a result
       that is not shorter is not a peel -- and the guard doubles as the termination proof, the same
       argument the table's loop uses. #>
    $cur = $Run
    $layers = 0
    while ($true) {
        try { $peeled = $utf8Strict.GetString($cp1252.GetBytes($cur)) } catch { break }
        if ($peeled.Length -ge $cur.Length) { break }
        $cur = $peeled
        $layers++
    }
    return [pscustomobject]@{ Text = $cur; Layers = $layers }
}

function Repair-Text([string]$Text) {
    <# The general inverse first, then the table as a net under it. Returns the repaired text and the
       number of damaged runs found. #>
    $n = 0
    $sb = [System.Text.StringBuilder]::new()
    $pos = 0
    foreach ($m in $nonAsciiRun.Matches($Text)) {
        [void]$sb.Append($Text, $pos, $m.Index - $pos)
        $r = Repair-Run -Run $m.Value
        if ($r.Layers -gt 0) { $n++ }
        [void]$sb.Append($r.Text)
        $pos = $m.Index + $m.Length
    }
    [void]$sb.Append($Text.Substring($pos))
    $Text = $sb.ToString()

    # THE TABLE, KEPT AS A NET rather than deleted. The general method needs every intermediate layer to
    # be valid UTF-8; a run where that chain breaks -- or where damaged text sits directly against a
    # legitimate non-ASCII character, so the run as a whole will not round-trip -- still matches a literal
    # rule here. It costs one pass over text that is almost always already clean, and the alternative is
    # discovering the gap the way this one was discovered.
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($k in $map.Keys) {
            $v = $map[$k]
            $c = ($Text.Length - $Text.Replace($k, '').Length) / $k.Length
            if ($c -gt 0) {
                $Text = $Text.Replace($k, $v)
                $n += [int]$c
                $changed = $true
            }
        }
    }
    return [pscustomobject]@{ Text = $Text; Count = $n }
}

$total = 0
$dirty = 0

foreach ($file in $Path) {
    if (-not (Test-Path -LiteralPath $file)) { Write-Error "File not found: $file"; exit 1 }
    # Separator-insensitive: git rev-parse --show-toplevel returns forward slashes while the paths above
    # are built with Join-Path (backslashes), so a naive StartsWith never matched and every finding named
    # an absolute path.
    $rel = $file
    $rootNorm = ($repoRoot -replace '/', '\').TrimEnd('\')
    $fileNorm = $file -replace '/', '\'
    if ($fileNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $fileNorm.Substring($rootNorm.Length).TrimStart('\')
    }

    # Respect the file's own BOM (this repo is largely BOM-less).
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encOut = New-Object System.Text.UTF8Encoding $hasBom

    $before = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    $r = Repair-Text -Text $before

    if ($r.Text -ne $before) {
        $dirty++
        $total += $r.Count
        if ($Check) {
            Write-Host "  [mojibake] ${rel}: $($r.Count) double-encoded sequence(s)" -ForegroundColor Red
        } else {
            [System.IO.File]::WriteAllText($file, $r.Text, $encOut)
            Write-Host "  repaired: $rel ($($r.Count) replacement(s))" -ForegroundColor Green
        }
    }
}

if ($Check) {
    if ($dirty -gt 0) {
        Write-Host "mojibake check: $total double-encoded sequence(s) across $dirty file(s) -- run scripts/maintenance/fix-mojibake.ps1 to repair." -ForegroundColor Red
        exit 1
    }
    Write-Host "mojibake check: clean ($($Path.Count) file(s) examined)." -ForegroundColor Green
    exit 0
}

if ($total -eq 0) {
    Write-Host "Nothing to repair ($($Path.Count) file(s) examined)." -ForegroundColor Green
} else {
    Write-Host "Repaired $total sequence(s) across $dirty file(s)." -ForegroundColor Cyan
}
exit 0
