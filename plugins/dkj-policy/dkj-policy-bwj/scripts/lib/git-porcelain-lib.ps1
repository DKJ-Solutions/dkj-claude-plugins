<#
.SYNOPSIS
    One reading of `git status --porcelain`: the command with its two flags, and the line parse.

.DESCRIPTION
    Dot-source this file from another lib in scripts/lib/, or from a script in scripts/task/:

        . (Join-Path $PSScriptRoot 'git-porcelain-lib.ps1')

    Supplies ConvertFrom-GitPorcelainLine (one line -> {Path, Index, Worktree, From}, or $null for a
    line carrying no path), Get-GitPorcelainStatus (the whole read: the command, its two flags, every
    line parsed, plus a Known flag saying whether it could be taken at all), and
    ConvertTo-GitPorcelainPath, which the first uses for each path half and which is exposed because
    lesson 4 below is entirely its business.

    WHY THIS EXISTS (issue #1682, September 9, 2026). Two libs parsed a porcelain line into a path plus
    its status halves, near-verbatim and comment for comment: park-lib.ps1's Get-GitParkBacking, which
    needs a COUNT of uncommitted files excluding a pathspec, and fanout-lib.ps1's
    Get-WorkingCopySnapshot, which needs a per-path MAP of {Index, Worktree, From}. The return shapes
    genuinely differ, so neither could reuse the other wholesale -- what was duplicated is the
    git-quirks knowledge underneath, and every piece of it was learned the hard way. fanout-lib's own
    header said "Same lesson, same reason, as Get-GitParkBacking in park-lib.ps1", which is the
    citation that stood in for this extraction.

    THE DIVERGENCE WAS ALREADY VISIBLE rather than hypothetical, which is why this is a defect and not
    tidiness. The #1670 branch had to repair the rename half of ITS copy -- a `git mv` inside the
    window read as a lost edit -- while park-lib's copy still discarded the old path. That is correct
    for a count and wrong for anything that follows a file, so the two were not in conflict yet; they
    were one requirement change away from it. This repo has extracted merged-pr-lib.ps1 and
    git-identity-lib.ps1 for exactly this shape, the first of them after the same fix landed twice in
    one day in two branches that did not know about each other.

    THE FOUR LESSONS, DOCUMENTED ONCE. The first three arrived with the two copies and every one of them
    was separately measured; the fourth is a defect the extraction itself exposed, which is the shortest
    argument for having done it. Two of the four are properties of the COMMAND rather than of the parse
    -- which is why this file owns the read as well as the line, instead of only the ConvertFrom half.
    Extracting the parse alone would have left the two flags, and the reasons for them, in both callers.

      1. --untracked-files=all, BECAUSE THE DEFAULT IS MEASURABLY WRONG FOR BOTH CALLERS. git's default
         collapses an untracked DIRECTORY to a single entry naming the directory ('?? some/dir/'). For a
         count that reports 2 uncommitted files where there is 1 (park-lib measured exactly that on the
         ordinary happy path); for a snapshot it means a subagent's `git clean` inside that directory
         removes files the snapshot never listed. Per-file still respects .gitignore, so a build
         directory does not flood the list.

      2. core.quotePath IS FORCED ON, and it is the language rule about reading a native command's
         output rather than a preference. Both callers COMPARE these paths -- park-lib against an
         excluded pathspec, fanout-lib against a second snapshot -- and PowerShell 5.1 decodes a child
         process's stdout with whatever console code page the run inherited. Quoting holds the wire to
         ASCII, where every candidate code page agrees, so a filename with an accent cannot decode into
         something that accidentally matches, or fails to match, the path it is held against. A repo may
         set core.quotepath in its own config, hence -c rather than trusting the default.

      3. THE RENAME'S OLD PATH IS RETURNED, NOT DISCARDED. A rename reads 'old -> new'. The new path is
         the one that exists on disk and is what a map keys on, but discarding the old one made an
         ordinary `git mv` during a snapshot window look exactly like a loss: the baseline's key
         disappeared, no commit carried it, and the comparison reported the edit gone while it sat
         intact under the new name. Returning both lets a caller follow the file; a caller that only
         counts simply ignores From, which is what park-lib does.

      4. A QUOTED PATH IS NOT SEPARATOR-NORMALISED, and this one was found BY the extraction rather
         than carried into it. Both copies normalised backslashes to forward slashes unconditionally,
         which rewrote lesson 2's own escapes into path segments: '"caf\303\251.txt"' read back as
         'caf/303/251.txt'. Latent in both callers -- a count still counts it and a comparison still
         matches because both readings mangle it the same way -- and the first thing that goes looking
         for the actual FILE would have found nothing. See ConvertTo-GitPorcelainPath.

    AND IT DECODES THE ESCAPE, SINCE #1689 -- one owner for reading a git path, not two. #1682 shipped
    this file stopping one step short: it stripped the quotes and left '\303\251' standing, because the
    decoder existed in sync-rules.ps1 and a porcelain parse must not dot-source the Shopify sync rules.
    #1689 moved the decoder in here instead, which is the direction that works, and the reason it works
    is that sync-rules.ps1 never CALLED the function it defined -- so it lost it outright and kept the
    dependency-free property its own registry entry demands. sync-main.ps1 takes this file directly and
    unguarded, exactly as it already takes merged-pr-lib.ps1 and native-capture-lib.ps1, with its own
    comment saying why neither went into sync-rules.ps1.

    SO THIS FILE IS MIRRORED TWICE -- into dkj-policy for park-lib and fanout-lib, and into
    dkj-subagents-shopify for sync-main -- on native-capture-lib's and merged-pr-lib's precedent. One file
    mirrored into both plugins rather than reached across from one to the other: they are separately
    versioned and separately installed, so a cross-plugin path is a dependency a version mismatch
    breaks silently.

    WHAT THE DECODE CHANGED FOR THE TWO ORIGINAL CALLERS. park-lib is unaffected in practice: it counts,
    and its exclusion is compared against caller-supplied paths that are ASCII in every current caller.
    fanout-lib gains the readable filename and LOSES A DOCUMENTED LIMIT -- its header used to state the
    escaped form as a deliberate trade ("correct for the comparison and poor for the reader"), and that
    trade was between escaped and CONSOLE-DECODED, which is the choice inbound #821 was filed about. A
    byte-level decode is a third option that was not on the table then, and it is not exposed to the code
    page the trade guards against. Get-WorkingCopySnapshotFormat is bumped for it: the shape is
    unchanged, the entry KEYS are not, and a baseline written on either side of this must be refused
    rather than differenced.

    THE STATUS HALVES ARE KEPT APART, for fanout-lib's reason: porcelain reports 'XY path', X is the
    index and Y is the worktree, and only one of them is a loss. `git reset` moves a change from X to Y
    and destroys nothing; `git checkout -- <path>` clears Y and destroys the edit. Handing back the
    two-character code as one string would make every caller re-learn which column is which.

    IT ANSWERS $null FOR A LINE WITH NO PATH rather than an object with an empty Path, so a caller's
    loop can `continue` on the falsy result and never has to know which of the two guards fired -- a
    line too short to carry a path at all, or one whose path is empty once trimmed.

    NO CONTRACT ROW FOLLOWS. Nothing here is repo-owned: it takes lines and a repo root and returns
    paths and status characters, the same reason worktree-lib.ps1's registry entry gives.

    ITS OWN FILE RATHER THAN native-capture-lib.ps1, following park-lib's and worktree-lib's precedent:
    that file's own header says it took an imperfect fit deliberately and asks the next person not to
    widen it again. Reading `git status --porcelain` is not a capture helper.

    Pure ASCII (repo convention for .ps1).
#>

# Guarded, on fanout-lib's precedent: dot-sourcing twice is harmless, and a tree whose mirror predates
# this lib must not crash on load.
$gpCaptureLib = Join-Path $PSScriptRoot 'native-capture-lib.ps1'
if (Test-Path -LiteralPath $gpCaptureLib -PathType Leaf) { . $gpCaptureLib }

# THE DECODER, MOVED HERE FROM sync-rules.ps1 ON SEPTEMBER 9, 2026 (issue #1689). It was written for
# inbound #821 and mirrored into dkj-subagents-shopify; sync-main.ps1 is its caller, at three sites, and now
# dot-sources this file directly and unguarded, the same way it takes merged-pr-lib.ps1. It did NOT move
# by having sync-rules.ps1 dot-source this file, which is what #1689 originally proposed: that file is
# dependency-free on purpose, because the live-theme guard dot-sources it on every command inside a catch
# that returns no live theme id -- so anything it pulls in is a way to silently disarm that guard. It never
# called the function it defined, so it could simply lose it.
function Convert-GitQuotedPath {
    <#
    .SYNOPSIS
        A path exactly as git printed it -- C-quoted when it carries a byte above 0x7F -- as the correct
        .NET string, decided by the bytes on the wire rather than by the console code page.

    .DESCRIPTION
        WHY THIS EXISTS, AND WHY THE PREVIOUS FIX WAS ONLY HALF OF ONE (inbound #821, August 21, 2026).
        git quotes a path containing a high byte by default: 'sections/cafe.liquid' with an accent comes
        out as '"sections/caf\303\251.liquid"'. The repair that shipped for that was
        'core.quotePath=false', which makes git emit the RAW UTF-8 bytes instead -- and PowerShell then
        decodes those bytes with [Console]::OutputEncoding, i.e. with whatever console code page the run
        happened to inherit. Measured on git 2.54:

            core.quotePath=true   ->  "sections/caf\303\251.liquid"   (pure ASCII on the wire)
            core.quotePath=false  ->  sections/caf<C3><A9>.liquid     (raw bytes, decoder-dependent)

        On cp850 -- the default OEM console on a Dutch Windows box -- the second form decodes to two
        wrong characters, the path then matches nothing the mirror walk produced, and the sync reaches
        the exact failure the flag was added to prevent: the trunk's copy reads as a path live does not
        have while live's IDENTICAL file reads as content the trunk has never held. Foreign, taken, the
        trunk's version overwritten. The flag fixed the quoting half and left the decoding half.

        SO THE WIRE IS HELD TO ASCII INSTEAD, and this function does the decoding, where no environment
        can reach it: every candidate code page agrees on bytes below 0x80, so the string arrives intact
        however the console is configured, and the escapes are unpacked into bytes here and read as UTF-8
        once. Quoting is FORCED ON at the call site ('-c core.quotePath=true') rather than left to git's
        default, because a repo is free to set core.quotepath in its own config and would otherwise put
        the answer back at the mercy of the decoder.

        THE UNQUOTED FORM PASSES THROUGH UNTOUCHED, which is what makes this safe to apply to every line:
        git quotes only when it must, so an ordinary ASCII path is not wrapped in quotes and is returned
        as it came. A path that is not quoted needs no decoding by definition -- there is nothing above
        0x7F in it.

        Escapes handled: the octal '\NNN' form git uses for high bytes, plus the C escapes it uses for a
        quote, a backslash and the control characters (\a \b \f \n \r \t \v). A backslash before anything
        else is kept as a literal backslash -- git would have escaped it if it meant one, and swallowing
        it would silently shorten a Windows-shaped path.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path)

    if ($Path.Length -lt 2 -or $Path[0] -ne '"' -or $Path[$Path.Length - 1] -ne '"') { return $Path }

    $inner = $Path.Substring(1, $Path.Length - 2)
    $bytes = New-Object System.Collections.Generic.List[byte]
    $i = 0
    while ($i -lt $inner.Length) {
        $c = $inner[$i]
        if ($c -ne '\') {
            # A quoted path is ASCII by construction, so this cast is the whole story for every real
            # line. The UTF-8 fallback is for a character that cannot be one byte -- unreachable from
            # git and cheap to be right about, rather than a silent truncation if it ever is.
            if ([int][char]$c -lt 0x80) { $bytes.Add([byte][char]$c) }
            else { foreach ($b in [System.Text.Encoding]::UTF8.GetBytes([string]$c)) { $bytes.Add($b) } }
            $i++
            continue
        }
        $i++
        if ($i -ge $inner.Length) { $bytes.Add(0x5C); break }
        $e = $inner[$i]
        if ($e -ge '0' -and $e -le '7') {
            # Exactly three octal digits, which is the only form git writes. Fewer than three left means
            # this is not one of git's escapes, so the backslash is kept literally rather than guessed at.
            if (($i + 2) -lt $inner.Length -and
                $inner[$i + 1] -ge '0' -and $inner[$i + 1] -le '7' -and
                $inner[$i + 2] -ge '0' -and $inner[$i + 2] -le '7') {
                $bytes.Add([byte][Convert]::ToInt32($inner.Substring($i, 3), 8))
                $i += 3
            } else {
                $bytes.Add(0x5C)
            }
            continue
        }
        switch ($e) {
            '"'     { $bytes.Add(0x22); $i++ }
            '\'     { $bytes.Add(0x5C); $i++ }
            'a'     { $bytes.Add(0x07); $i++ }
            'b'     { $bytes.Add(0x08); $i++ }
            'f'     { $bytes.Add(0x0C); $i++ }
            'n'     { $bytes.Add(0x0A); $i++ }
            'r'     { $bytes.Add(0x0D); $i++ }
            't'     { $bytes.Add(0x09); $i++ }
            'v'     { $bytes.Add(0x0B); $i++ }
            default { $bytes.Add(0x5C) }
        }
    }

    return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
}

function ConvertTo-GitPorcelainPath {
    <#
        One path half of a porcelain line -- the whole path, or one side of a rename's arrow -- with its
        quotes off and its separators settled. Empty string where there is no path.

        A QUOTED PATH IS DECODED, by Convert-GitQuotedPath above -- so what comes back is the real
        filename and not git's escape of it. Since #1689 that decoder lives in this file, which is what
        makes this one line possible; before it, this function stripped the quotes and left the escape
        standing, on the ground that the decoder was in a file this one must not depend on.

        WHAT IT MUST NOT DO IS NORMALISE SEPARATORS OVER IT, AND THAT IS LESSON 4 (found by this
        extraction, September 9, 2026). Both original copies ran `-replace '\\', '/'` over every path
        unconditionally, and that is wrong for exactly the paths core.quotePath exists to produce: git
        quotes a path precisely WHEN it has to escape something in it, and inside those quotes a byte
        outside ASCII is printed as a backslash-octal escape. So the normalisation rewrote git's own
        escapes into path segments -- '"caf\303\251.txt"' came back as 'caf/303/251.txt', a path with
        two directories in it that exists nowhere.

        It was latent rather than live in both callers, which is why it survived two implementations: a
        count still counts the mangled entry, and a comparison still matches because both snapshots
        mangle it identically. What it would break is anything that takes one of these paths and goes
        looking for the FILE -- and the near miss is real, because park-lib compares its paths against
        an exclusion the caller supplies.

        AN UNQUOTED PATH IS STILL SEPARATOR-NORMALISED, which is what the normalisation was always for.
        git reports forward slashes and never uses a backslash as a separator, so this cannot be
        repairing git's side; it exists so a CALLER holding a Windows-shaped path can compare against
        what comes back without remembering to normalise first. park-lib's exclusion map depends on it.

        THE TWO ARMS ARE MUTUALLY EXCLUSIVE, WHICH IS WHY NEITHER RULE FIGHTS THE OTHER. git quotes a
        path exactly when it has to escape something in it, so a quoted path is the decoder's business
        and an unquoted one is the separator rule's -- and no path is ever both. Running the
        normalisation after the decode would put lesson 4 straight back, because the decode's output can
        legitimately contain a backslash: git escapes a real one as '\\', and Convert-GitQuotedPath
        unpacks it to a literal backslash that IS part of the filename.
    #>
    param([string]$Raw)

    if ($null -eq $Raw) { return '' }
    $t = $Raw.Trim()
    if (-not $t) { return '' }
    # Convert-GitQuotedPath decides for itself whether this is quoted -- it returns an unquoted string
    # untouched -- but the separator rule must NOT run over a decoded path, so the two arms are split
    # here rather than chained. Both ends checked, because git quotes a path by wrapping the whole of
    # it; a lone quote at one end is not git's quoting and is left where it is rather than guessed at.
    if ($t.Length -ge 2 -and $t.StartsWith('"') -and $t.EndsWith('"')) {
        return (Convert-GitQuotedPath -Path $t)
    }
    return ($t -replace '\\', '/')
}

function ConvertFrom-GitPorcelainLine {
    <#
        One `git status --porcelain` line as an object -- {Path, Index, Worktree, From} -- or $null
        where the line carries no path. See the file header for all three lessons; this function owns
        the third (the rename's old path) and the status-halves split.

        PATHS COME BACK FORWARD-SLASHED, on both halves. git reports forward slashes already, but a
        caller comparing against a path IT holds may have either separator, and normalising in one
        place means neither caller has to remember to.
    #>
    param([string]$Line)

    # 'XY path' -- under four characters there is no path to read, which also skips the empty line the
    # output's trailing newline produces.
    if ($null -eq $Line -or $Line.Length -lt 4) { return $null }

    $index = $Line.Substring(0, 1)
    $worktree = $Line.Substring(1, 1)
    $raw = $Line.Substring(3)

    $from = ''
    $arrow = $raw.IndexOf(' -> ')
    if ($arrow -ge 0) {
        $from = ConvertTo-GitPorcelainPath -Raw $raw.Substring(0, $arrow)
        $raw = $raw.Substring($arrow + 4)
    }
    $path = ConvertTo-GitPorcelainPath -Raw $raw
    if (-not $path) { return $null }

    return [pscustomobject]@{
        Path     = $path
        Index    = $index
        Worktree = $worktree
        From     = $from
    }
}

function Get-GitPorcelainStatus {
    <#
        What this working copy holds right now, as an object: Entries (one parsed record per changed or
        untracked path, in the order git reported them) and Known (whether the read succeeded at all).

        KNOWN IS SEPARATE FROM AN EMPTY LIST, and both callers depend on the distinction. Zero entries
        is an answer -- 'nothing outstanding' -- and handing it back for a git call that failed would
        report a clean working copy on a repo that could not be read.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $entries = @()
    $res = Invoke-NativeCapture -FilePath 'git' -Arguments @('-c', 'core.quotePath=true', '-C', $RepoRoot, 'status', '--porcelain', '--untracked-files=all')
    if ($res.ExitCode -ne 0) {
        return [pscustomobject]@{ Entries = @(); Known = $false }
    }
    foreach ($line in (($res.Output | Out-String) -split '\r?\n')) {
        $e = ConvertFrom-GitPorcelainLine -Line $line
        if ($e) { $entries += $e }
    }
    return [pscustomobject]@{ Entries = @($entries); Known = $true }
}
