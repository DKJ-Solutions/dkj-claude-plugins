<#
.SYNOPSIS
    The shared helpers for measuring the ALWAYS-ON DOCUMENT PATH: the '@'-import walk, the byte-exact
    section split, and the one place the calibrated chars-per-token factor lives.

.DESCRIPTION
    WHY THIS EXISTS. The always-on path -- CLAUDE.md plus everything it '@'-imports -- is paid by every
    session before a single assignment is given, and until this lib the figure was produced BY HAND. It
    had been hand-run four times (July 28, August 14, August 15 and August 24, 2026), and the
    performance lens records the consequence three separate times in its own words: a measurement in a
    document that nothing regenerates goes stale silently. It went stale in the worst possible way once
    already -- the conversion factor below was inherited unexamined at 3.70 through three
    re-measurements and turned out to be ~19% too generous, so every token figure derived from it was
    under-stated.

    WHAT IT DELIBERATELY DOES NOT DO. It reaches no verdict. It says what a document costs and where the
    mass sits; it does not say what should go. That boundary is the outcome of issue #861, where a skill
    that WOULD have judged block by block was argued down: the judgement is one already-written sentence
    (the decision belongs on the always-on path, the evidence for it does not), while a portable skill
    would have carried always-on cost into consumers that do not share this repo's condition.

    THE PROVENANCE RULE, WHICH IS NOT DECORATION. `measure-skill` owns the authoritative token figure by
    driving `claude plugin details`, whose numbers come from the count_tokens API, and its standing rule
    is DO NOT ESTIMATE FROM FILE SIZES. That rule is about a subject the API prices. It does not price
    DOCUMENTS -- there is no API path here -- so a calibrated estimate is the only answer available, and
    the honest move is to label it as one rather than to refuse. Hence: the BYTE column is a
    measurement, the TOKEN column is an estimate at a named factor, and every consumer of this lib is
    expected to print that distinction. A number that looks authoritative and is not is the failure this
    repo has the most scar tissue from.

    THE LOAD PATH IS RESOLVED, NOT ASSUMED. `.claude/specialists/SPECIALISTS.md` imports the
    orchestrator's persona from the MARKETPLACE CLONE, not from `plugins/` in the tree. Those two files
    differ by however many merges have landed since the last `claude plugin marketplace update`, and the
    difference is not error to smooth away: it is queued always-on cost that arrives at the next plugin
    update. Measured August 24, 2026: 16,585 B loaded against 21,860 B in the tree -- 5,275 B waiting.
    So the walk reports the copy that ACTUALLY LOADS and names its tree counterpart beside it.

    BYTES ARE COUNTED AS BYTES. Every size here is the file's length on disk, and the section split
    works on the raw byte array rather than on decoded text, so the sections sum EXACTLY to the file
    length. That is not fussiness: this repo's own encoding history (Windows PowerShell 5.1 reading a
    BOM-less UTF-8 file as ANSI) is a long record of decoded-text arithmetic producing well-formed wrong
    answers, and a byte count sidesteps the question entirely.

    AND THE BYTE COUNT IS THE WORKING COPY, LINE ENDINGS AND ALL. `Get-Item .Length` is the file as it
    sits on disk, which is the copy a session actually loads -- so that is the figure to report, and
    reading it is not the bug. But on a CRLF checkout (Windows, `core.autocrlf`, a consumer with no
    `.gitattributes` pinning `eol=lf`) that is one byte per LINE above the LF form the repository
    stores. A reader who takes a baseline from a fresh checkout (CRLF) and a later reading from an
    editor-rewritten (LF) copy is then silently comparing two units -- ~1.4% on a 1,346-line file,
    plausible and wrong. So each row also carries CrlfLines and LfBytes, and the caller names the LF
    size beside the on-disk one wherever they differ: the same treatment this lib gives a tree/clone
    divergence, for the same reason -- it is the number the next reader will compare against, not noise
    to smooth away. Inbound issue #1162.

    THIS FILE IS PURE ASCII, per the [script-ascii] gate.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script, which is
    the standing convention for every lib in this directory.
#>

# The documented ceiling on '@'-import nesting. The seam spends two hops (CLAUDE.md -> SPECIALISTS.md
# -> body/lens), so a lens may still import something of its own and stay inside it.
$script:MeasureContextMaxHops = 4

# EVERY NUMBER THIS LIB FORMATS IS FORMATTED INVARIANTLY, and that is not tidiness. PowerShell's '-f'
# and ':N0' follow the CURRENT CULTURE, so on this machine (nl-NL) a first draft of the report printed
# '29.044' for 29,044 bytes and '3,12' for the factor. That is the exact ambiguity measure-skill-lib's
# ConvertTo-TokenCount exists to document -- "'~3.031' -> 3031, the dot is a THOUSANDS separator" -- so
# the measurement tool would have been emitting the notation the parsing tool warns about, in a layer
# this repo requires to be English throughout. measure-skill met this first and its suite pins it by
# setting the culture to nl-NL on purpose; this lib follows that precedent rather than inventing a
# second answer.
$script:MeasureContextInvariant = [System.Globalization.CultureInfo]::InvariantCulture

function Format-MeasuredNumber {
    <# One number, one format string, invariant culture. 'n/a' for $null, because a blank cell and a
       zero are different findings. #>
    param(
        $Value,
        [string]$Format = '{0:N0}'
    )
    if ($null -eq $Value) { return 'n/a' }
    return [string]::Format($script:MeasureContextInvariant, $Format, $Value)
}

function Format-MeasuredBytes {
    <# A byte count with thousands separators, invariantly. #>
    param($Value)
    return (Format-MeasuredNumber -Value $Value -Format '{0:N0}')
}

function Format-MeasuredShare {
    <# A percentage to one decimal, invariantly -- '40.5', never '40,5'. #>
    param($Value)
    return (Format-MeasuredNumber -Value $Value -Format '{0:0.0}')
}

function Get-CalibratedCharsPerToken {
    <#
        THE ONE PLACE THE FACTOR LIVES, with its provenance attached so a reader never has to trust a
        bare number.

        Calibrated August 15, 2026 over 10 of this repo's own skill pages, each sized on disk and
        token-counted by the count_tokens API behind `claude plugin details`, spanning 5,002 B to
        47,434 B:

            n=10   min 2.95   median 3.12   mean 3.07   max 3.23

        The median is the factor to use. The spread is tight enough to decide on, but the reported
        on-invoke figures it was derived from are rounded to two significant figures, so the ratio is
        good to a few percent -- NOT to three digits. Anything computed at the older 3.70 is low by
        ~19%.

        It is returned as an object rather than a scalar on purpose: a caller that prints the estimate
        without the basis reintroduces exactly the problem this lib exists to close.
    #>
    return [pscustomobject]@{
        Value      = 3.12
        Calibrated = '2026-08-15'
        SampleSize = 10
        Min        = 2.95
        Median     = 3.12
        Mean       = 3.07
        Max        = 3.23
        Basis      = 'median of 10 skill pages sized on disk and token-counted by the count_tokens API behind `claude plugin details`'
        Caveat     = 'an ESTIMATE, not an API count: no API prices documents. Good to a few percent, not to three digits.'
    }
}

function ConvertTo-EstimatedTokens {
    <# Bytes -> estimated tokens at the calibrated factor. Rounded to a whole token, because a
       fractional token is a false precision the caveat above already warns about. #>
    param(
        [Parameter(Mandatory = $true)][int64]$Bytes,
        [double]$CharsPerToken = 0
    )
    if ($CharsPerToken -le 0) { $CharsPerToken = (Get-CalibratedCharsPerToken).Value }
    return [int][math]::Round($Bytes / $CharsPerToken)
}

function Get-ImportLinePath {
    <#
        Returns the raw import target of a line, or $null when the line is not an import.

        An '@'-import sits at the START of a line and takes the rest of the line as its path. Two things
        this deliberately does NOT treat as an import:
          - an '@' anywhere but column 0 (an email address, a persona's `@dkj-subagents-alpha:name`);
          - a line inside a fenced code block -- the caller tracks fences and does not ask.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
    if ($Line -notmatch '^@(\S.*)$') { return $null }
    return $Matches[1].Trim()
}

function Resolve-ImportPath {
    <#
        Resolves one import target to a filesystem path.

        THREE FORMS, and the third is the one that catches people out:
          '~/...'      -> the USER HOME, which is where a plugin marketplace clone lives;
          rooted        -> taken as given;
          anything else -> relative to the DIRECTORY OF THE IMPORTING FILE, not to the repo root.

        The last rule is why `@.claude/specialists/SPECIALISTS.md` in a root CLAUDE.md and
        `@lenses/specialist-01-01-lens.md` in `.claude/specialists/SPECIALISTS.md` both resolve correctly under
        ONE rule: CLAUDE.md's own directory IS the repo root, so the root-relative reading is a special
        case of the file-relative one rather than a second rule. Reading the second line as root-relative
        would silently resolve to a path that does not exist, and a missing import is reported as absent
        rather than as zero -- see Get-AlwaysOnDocuments.

        Returns $null for an empty target. Does NOT test existence: the caller reports that.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Target,
        [Parameter(Mandatory = $true)][string]$ImportingFile
    )
    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    $t = $Target.Trim()

    if ($t -match '^~[\\/](.*)$') {
        # NOT $home: that is a read-only automatic variable, and assigning to it throws a
        # NON-TERMINATING error while the built-in value -- the user profile, i.e. usually the right
        # answer -- stays in place. So the first version of this line failed loudly and returned the
        # correct path anyway, which is the well-formed-wrong-output shape this lib's docstring warns
        # about, arriving through the front door.
        $userHome = Get-UserHomeDirectory
        return [System.IO.Path]::GetFullPath((Join-Path $userHome ($Matches[1] -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    }
    if ([System.IO.Path]::IsPathRooted($t)) {
        return [System.IO.Path]::GetFullPath($t)
    }
    $dir = Split-Path -Parent $ImportingFile
    if ([string]::IsNullOrEmpty($dir)) { $dir = '.' }
    $native = $t -replace '/', [System.IO.Path]::DirectorySeparatorChar
    return [System.IO.Path]::GetFullPath((Join-Path $dir $native))
}

function Get-UserHomeDirectory {
    <# The user home, resolved the same way on every host this runs on. USERPROFILE is the Windows
       answer and HOME the POSIX one; the .NET fallback covers a host that sets neither. Factored out
       so a test can override it, and so the '~' rule has exactly one implementation. #>
    if ($env:MEASURE_CONTEXT_HOME) { return $env:MEASURE_CONTEXT_HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    return [System.Environment]::GetFolderPath('UserProfile')
}

function Get-PluginMarketplaceRoot {
    <# Where a plugin marketplace clone lives on this machine: '<home>/.claude/plugins/marketplaces'.
       Named once, here, because two different questions are asked of it -- Resolve-ImportPath turns a
       '~/' target into a path under it without caring whether it exists, and Get-ImportAbsenceKind
       asks whether it exists at all. It goes through Get-UserHomeDirectory, so a test overriding the
       home overrides this too. #>
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $rel = '.claude/plugins/marketplaces' -replace '/', $sep
    return [System.IO.Path]::GetFullPath((Join-Path (Get-UserHomeDirectory) $rel))
}

function Test-PathIsUnder {
    <#
        Is $Path inside $Parent -- the containment test, with the separator appended before the prefix
        comparison so a SIBLING whose name merely starts with the parent's is not read as being inside
        it ('C:\x\repo-dead' vs 'C:\x\repo-deadXYZ').

        ONE DEFINITION BECAUSE THE TRAP IS ASYMMETRIC, not because two lines were repeated. The first
        draft of Get-ImportAbsenceKind guarded its marketplace-root branch and left the repo-root branch
        three lines above it bare -- with a test pinning the guarded half and nothing pinning the other,
        so the asymmetry was invisible in a green suite. A comparison written twice is a comparison that
        can be right once (code review of #2138).

        The parent itself counts as inside: a target that resolves to the directory rather than to a file
        in it is still a target this tree owns, and answering 'no' there would send it down the branch
        for somewhere else entirely.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $sep   = [System.IO.Path]::DirectorySeparatorChar
    $child = [System.IO.Path]::GetFullPath($Path)
    $root  = [System.IO.Path]::GetFullPath($Parent).TrimEnd($sep)
    if ($child.TrimEnd($sep).Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $child.StartsWith(($root + $sep), [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ImportAbsenceKind {
    <#
        An import target that does not exist is one of TWO DIFFERENT FACTS, and telling them apart is
        the whole difference between "repair this line" and "re-run this somewhere else".

          'dead'       -- the absence is PROVABLE here. The directory that would hold the file is on
                          this machine, so nothing is missing except the file itself: Claude Code drops
                          an import it cannot resolve WITHOUT erroring, so every session in this repo
                          silently loads one document fewer and nothing says so.
          'unprovable' -- this run can conclude nothing. A CI runner has no marketplace clone at all,
                          so an import into one legitimately does not resolve there; erroring on it
                          would fail every PR for a correct file. That is issue #874's own reasoning
                          for excluding an external import, and it is kept rather than narrowed --
                          what is added is that the reasoning is CONDITIONAL, and this function is
                          where the condition is tested instead of assumed.

        TWO PROOFS, AND DELIBERATELY ONLY TWO:
          - the target is IN THE REPO, which is present by definition -- this run is reading it;
          - the target is under the plugin marketplace root AND THAT ROOT EXISTS. A machine holding a
            plugin administration that does not contain the named marketplace is not a machine that
            cannot see; it is a machine where the import is broken.

        Everything else is 'unprovable'. The absence of a proof is not a proof of absence, and keeping
        those two apart is this function's only job.

        Measured, issue #2138: a registered consumer had imported the ORCHESTRATOR's body from a
        marketplace path retired ten days earlier. The budget gate saw the unresolved import and
        reported it as "not measured and not recorded -- run this once on a machine where the import
        resolves", which is the one instruction that cannot help: it was already on such a machine.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )
    # BOTH CONTAINMENT TESTS GO THROUGH ONE FUNCTION, which is the repair code review made to the first
    # draft of this one: it guarded the second test against the sibling-prefix trap and left the first
    # bare, and the suite pinned only the guarded half. See Test-PathIsUnder's own header.
    if (Test-PathIsUnder -Path $Path -Parent $RepoRoot) { return 'dead' }

    $root = Get-PluginMarketplaceRoot
    if (Test-PathIsUnder -Path $Path -Parent $root) {
        if (Test-Path -LiteralPath $root -PathType Container) { return 'dead' }
    }
    return 'unprovable'
}

function Split-FileIntoByteLines {
    <#
        Splits a file into lines WITH their byte lengths, working on the raw byte array.

        Each returned line carries the byte count INCLUDING its terminator, so the lines sum exactly to
        the file length -- which is the property the section split rests on. Text is decoded per line, as
        UTF-8, only so headings and fences can be recognised; no arithmetic is done on decoded text.

        Why not Get-Content: on Windows PowerShell 5.1 it decodes a BOM-less UTF-8 file with the system
        ANSI code page, so a multi-byte character comes back as two characters and NOTHING ERRORS. Any
        size derived from that is wrong and looks fine. This repo has met that class in three separate
        places (the middot in a changelog heading, a dash class in a regex, a git path on the wire).
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $lines = New-Object System.Collections.Generic.List[object]
    $start = 0
    $utf8 = New-Object System.Text.UTF8Encoding $false

    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -ne 0x0A) { continue }
        $len = $i - $start + 1
        # Decode without the LF and without a preceding CR, so a CRLF file reads the same as an LF one.
        $textLen = $len - 1
        if ($textLen -gt 0 -and $bytes[$start + $textLen - 1] -eq 0x0D) { $textLen-- }
        $lines.Add([pscustomobject]@{
            Text  = $utf8.GetString($bytes, $start, $textLen)
            Bytes = [int64]$len
        })
        $start = $i + 1
    }
    if ($start -lt $bytes.Length) {
        $len = $bytes.Length - $start
        $lines.Add([pscustomobject]@{
            Text  = $utf8.GetString($bytes, $start, $len)
            Bytes = [int64]$len
        })
    }
    return $lines
}

function Test-IsFenceLine {
    <# A code-fence delimiter: three or more backticks or tildes at the start of a line, optionally with
       an info string. Tracked because a fenced block in these documents routinely CONTAINS lines that
       start with '#' -- a skill page showing a document's shape, a README showing a heading tree. Read
       as headings, those invent sections that do not exist and move bytes into them. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
    return [bool]($Line -match '^\s{0,3}(?:`{3,}|~{3,})')
}

function Get-DocumentSections {
    <#
        Splits one document into sections at its ATX headings, byte-exact.

        A section runs from its heading line to the line before the next heading AT ANY LEVEL, so the
        sections tile the file with no overlap and no gap. Bytes before the first heading are returned as
        a leading section named '(preamble)' -- it is real cost and dropping it would make the parts fail
        to sum to the whole, which is the check a caller should run.

        -MaxLevel bounds how deep a heading still opens a section of its own: at 3, a '####' block counts
        toward the '###' it sits under. That is the level the useful readings of this repo happened at --
        the finding that one sub-item of a two-item list was 56% of CLAUDE.md came from reading at depth,
        while the finding that one section was 80% of it came from reading shallow.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(1, 6)][int]$MaxLevel = 3
    )

    $lines = Split-FileIntoByteLines -Path $Path
    $sections = New-Object System.Collections.Generic.List[object]
    $inFence = $false
    $lineNo = 0

    $current = [pscustomobject]@{
        Heading = '(preamble)'
        Level   = 0
        Line    = 1
        Bytes   = [int64]0
    }

    foreach ($line in $lines) {
        $lineNo++
        if (Test-IsFenceLine $line.Text) { $inFence = -not $inFence }

        $isHeading = $false
        if (-not $inFence -and $line.Text -match '^(#{1,6})\s+(\S.*?)\s*$') {
            $level = $Matches[1].Length
            if ($level -le $MaxLevel) { $isHeading = $true }
        }

        if ($isHeading) {
            if ($current.Bytes -gt 0 -or $current.Level -gt 0) { $sections.Add($current) }
            $current = [pscustomobject]@{
                Heading = $Matches[2]
                Level   = $Matches[1].Length
                Line    = $lineNo
                Bytes   = [int64]0
            }
        }
        $current.Bytes += $line.Bytes
    }
    if ($current.Bytes -gt 0 -or $current.Level -gt 0) { $sections.Add($current) }

    return $sections
}

function Get-TreeCounterpart {
    <#
        For a document loaded from a plugin MARKETPLACE CLONE, the path of the same file in this tree --
        or $null when there is none.

        This only has an answer because of a fact peculiar to the source repo: it consumes itself, so the
        clone under `.../marketplaces/<name>/` mirrors this very tree. The tail after the marketplace name
        is therefore a repo-relative path. Returns $null unless that file actually EXISTS, because a
        computed-but-absent counterpart would be reported as a divergence of the whole file size, which is
        a wrong answer dressed as a finding -- the shape this lib's docstring warns about.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )
    # Deliberately a positive -match: $Matches after a -notmatch is a trap, since the automatic variable
    # is populated when the REGEX matches, i.e. exactly when -notmatch returns false.
    $norm = $Path -replace '\\', '/'
    if (-not ($norm -match '/plugins/marketplaces/[^/]+/(.+)$')) { return $null }
    $candidate = Join-Path $RepoRoot ($Matches[1] -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
    return [System.IO.Path]::GetFullPath($candidate)
}

function Get-CrlfPairCount {
    <#
        The number of CR-LF pairs in a file: how many bytes its on-disk form carries ABOVE the same
        content stored with LF line endings. Zero on a file already LF.

        Counts a 0x0D only when it immediately precedes a 0x0A, so a lone CR (old-Mac, or a CR inside
        content) is not mistaken for a line ending. Works on the raw byte array, like the rest of this
        lib -- a decoded-text scan would meet the ANSI-misread class the docstring warns about.

        See Get-AlwaysOnDocuments and the byte-count note in this file's docstring for why the caller
        reports LfBytes = Bytes - (this) beside the on-disk Bytes. Inbound issue #1162.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $pairs = 0
    for ($i = 1; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 0x0A -and $bytes[$i - 1] -eq 0x0D) { $pairs++ }
    }
    return $pairs
}

function Get-AlwaysOnDocuments {
    <#
        Walks the always-on document path from a root document and returns every document on it, in load
        order.

        THE WALK, and what each guard is for:
          - a document is visited ONCE. A cycle (A imports B imports A) would otherwise never terminate,
            and a diamond (two documents importing one third) would double-count cost that is paid once.
          - the walk stops at -MaxHops, defaulting to the documented ceiling of four. A hop budget that is
            silently exceeded is the difference between "this is the path" and "this is some of the path".
          - a missing import is RETURNED with Exists=$false and Bytes=0 rather than skipped. An import
            that does not resolve is the most consequential thing this walk can find -- the seam is
            assembled by scripts, and a path that stopped resolving means a document the session believes
            it is loading and is not. Skipping it would report a smaller, healthier-looking path.

        Each row carries Hop, ImportedBy and Source ('tree' or 'external'), plus the tree counterpart and
        its size where the loaded copy came from a marketplace clone -- the queued cost this repo's own
        rule requires be named rather than smoothed away. It also carries CrlfLines and LfBytes: Bytes is
        the working copy on disk (CRLF and all), LfBytes is what it would be stored LF, and the caller
        names the difference wherever it is non-zero -- inbound issue #1162.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RootDocument,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [int]$MaxHops = 0
    )
    if ($MaxHops -le 0) { $MaxHops = $script:MeasureContextMaxHops }

    $root = [System.IO.Path]::GetFullPath($RootDocument)
    $repo = [System.IO.Path]::GetFullPath($RepoRoot)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $documents = New-Object System.Collections.Generic.List[object]

    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Path = $root; Hop = 0; ImportedBy = $null; Target = $null })

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        if (-not $seen.Add($item.Path)) { continue }

        $exists = Test-Path -LiteralPath $item.Path -PathType Leaf
        $bytes = [int64]0
        $crlfLines = [int64]0
        if ($exists) {
            $bytes = (Get-Item -LiteralPath $item.Path).Length
            $crlfLines = [int64](Get-CrlfPairCount -Path $item.Path)
        }

        $inTree = $item.Path.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)
        $counterpart = $null
        $counterpartBytes = $null
        if ($exists -and -not $inTree) {
            $counterpart = Get-TreeCounterpart -Path $item.Path -RepoRoot $repo
            if ($counterpart) { $counterpartBytes = (Get-Item -LiteralPath $counterpart).Length }
        }

        # Computed before the literal, not inside it: PowerShell 5.1 does not accept an `if` as an
        # expression in a hashtable value position, and the parse error it raises names the line rather
        # than the construct.
        $display = $item.Path -replace '\\', '/'
        $sourceKind = 'external'
        if ($inTree) {
            $sourceKind = 'tree'
            $display = ($item.Path.Substring($repo.Length) -replace '\\', '/').TrimStart('/')
        }

        $documents.Add([pscustomobject]@{
            Path            = $item.Path
            Display         = $display
            Hop             = $item.Hop
            ImportedBy      = $item.ImportedBy
            Target          = $item.Target
            Exists          = $exists
            Bytes           = $bytes
            CrlfLines       = $crlfLines
            LfBytes         = $bytes - $crlfLines
            Source          = $sourceKind
            TreeCounterpart = $counterpart
            TreeBytes       = $counterpartBytes
        })

        if (-not $exists) { continue }
        if ($item.Hop -ge $MaxHops) { continue }

        $inFence = $false
        foreach ($line in (Split-FileIntoByteLines -Path $item.Path)) {
            if (Test-IsFenceLine $line.Text) { $inFence = -not $inFence; continue }
            if ($inFence) { continue }
            $target = Get-ImportLinePath -Line $line.Text
            if (-not $target) { continue }
            $resolved = Resolve-ImportPath -Target $target -ImportingFile $item.Path
            if (-not $resolved) { continue }
            $queue.Enqueue([pscustomobject]@{
                Path       = $resolved
                Hop        = $item.Hop + 1
                ImportedBy = $item.Path
                Target     = $target
            })
        }
    }

    return $documents
}
