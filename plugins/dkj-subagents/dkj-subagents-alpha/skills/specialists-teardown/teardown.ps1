<#
.SYNOPSIS
    Removes what specialists-init put into a consuming repo, so the repo can stand free of the plugin.

.DESCRIPTION
    The counterpart to bootstrap.ps1, and deliberately its mirror image: where the bootstrap is
    strictly ADDITIVE and never overwrites, the teardown is strictly SUBTRACTIVE and never deletes
    anything the repo owner wrote. Adoption is reversible by design (Dave's requirement, July 29, 2026):
    a consumer must be able to install and uninstall at any moment and afterwards carry no lingering
    reference to a specialist, manual, persona or roster.

    THE CENTRAL RULE. Consumer-side content is three things and only one is disposable, so this script
    classifies before it removes:
      1. Generated and untouched  -> REMOVED. A lens still carrying its VUL-IN marker, a script scaffold
         still carrying its placeholders, the @-imports the bootstrap wrote, settings.suggested.jsonc.
      2. Authored by the owner    -> REPORTED, never touched. A filled-in lens holds repo knowledge
         somebody wrote; deleting it to leave a tidy tree is a worse outcome than leaving clutter.
      3. Owned by the repo anyway -> REPORTED as "yours to keep or drop". A repo-config with real values
         and a filled branch table describe THIS repo's conventions and stay useful with the plugin gone.

    WHAT IT DELIBERATELY DOES NOT DO:
      - It never edits .claude/settings.json. Disabling/uninstalling the plugin is the owner's act, and
        the bootstrap never wrote that file either -- symmetry cuts both ways. It is reported instead.
      - It never removes roster rows or repo-specific prose from CLAUDE.md. Those are authored text in a
        file full of other authored text; the only lines it touches there are the two @-imports, which
        are knowably bootstrap-written and can never be anything else.
      - It never touches the plugin install or cache.

    DRY RUN BY DEFAULT. Nothing is removed unless -Apply is passed. A destructive script that runs on a
    consumer's repo should have to be asked twice, and the preview doubles as the inventory a reader
    needs in order to say yes.

.PARAMETER ConsumerRoot
    Repo root to tear down. Defaults to the current directory.

.PARAMETER Apply
    Actually remove. Without it the script only reports what it would do.

.PARAMETER VendorScripts
    Hand back working copies of the plugin's shared script payload (scripts/task, scripts/release,
    scripts/lib, scripts/sync) into the consumer's own scripts/, structure preserved.

    THE ONE ADDITIVE THING THIS SCRIPT DOES, and opt-in for exactly that reason. Everything else here
    is subtractive; this writes files. It earns the exception because it is the only answer to the
    leftover that section 6 can otherwise only warn about: the consumer's resolver locates the
    marketplace cache and throws once the plugin is gone, so an uninstall does not leave clutter, it
    stops the repo's daily git workflow. Vendoring turns "reversible except for the part that breaks"
    into an actual exit.

    It works because the shared scripts were built to travel as a payload: they locate the repo via
    CLAUDE_PROJECT_DIR / `git rev-parse --show-toplevel` (never their own location) and dot-source
    their siblings $PSScriptRoot-relative, so a copy runs identically from anywhere inside the repo.
    The source repo is the proof: its scripts/ copies are byte-identical to the plugin's.

    NEVER OVERWRITES. A destination that exists and differs is reported and left alone -- it is
    typically the consumer's own wrapper around the shared script, i.e. authored content, and the rule
    that protects a filled-in lens protects this too. Identical destinations are reported as already
    current. Combine with -Apply to write; on its own it previews, like every other part of this
    script.

.EXAMPLE
    ./teardown.ps1
    # Preview: what would be removed, what is authored, what is yours to decide.

.EXAMPLE
    ./teardown.ps1 -Apply
#>
[CmdletBinding()]
param(
    [string]$ConsumerRoot = (Get-Location).Path,
    [switch]$Apply,
    # Regex identifying THIS repo's own "nothing recorded here yet" convention for an empty lens.
    # Left empty on purpose: the plugin recognises the scaffold shapes IT writes and must not guess at
    # a convention it did not create. Measured in a real consumer (davekokbwj/smartwatchbanden,
    # 2026-07-29): 20 of its 22 lenses are empty under that repo's own "schone lei" convention -- a
    # closing sentence in Dutch, no '(VUL-IN)' heading anywhere -- so the teardown kept all 22 and
    # reported them as authored. The prediction "all 22 kept" came out for the WRONG reason, and
    # adoption was therefore less reversible than this skill claimed.
    # Pass e.g. -EmptyLensPattern 'Nog niets vastgelegd' to have those recognised as removable.
    [string]$EmptyLensPattern = '',
    # Copy the plugin's shared script payload into the consumer's scripts/ (see .PARAMETER above).
    # The only additive act in a subtractive script, hence opt-in, and it never overwrites.
    [switch]$VendorScripts
)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $ConsumerRoot).Path
$midDot = [char]0x00B7

# THE SEAM (issue #221). The literals come from Get-SeamPaths rather than being retyped here, because
# the bootstrap WRITES them and this script MATCHES them: a drift between the two leaves a consumer with
# a dangling import that nothing errors on. Same $PSScriptRoot-relative dot-source the bootstrap uses --
# the lib travels in this plugin's own payload. A missing lib must not stop a teardown either, so the
# fallback is the same literal the lib returns.
$seamLib = Join-Path $PSScriptRoot '../../scripts/lib/check-report-lib.ps1'
if (Test-Path -LiteralPath $seamLib -PathType Leaf) { . $seamLib }
$seam = if (Get-Command Get-SeamPaths -ErrorAction SilentlyContinue) {
    Get-SeamPaths -RepoRoot $root
} else {
    [pscustomobject]@{
        Dir        = (Join-Path $root '.claude\specialists')
        LensDir    = (Join-Path $root '.claude\specialists\lenses')
        Inclusion  = (Join-Path $root '.claude\specialists\SPECIALISTS.md')
        ImportLine = '@.claude/specialists/SPECIALISTS.md'
        RelDir     = '.claude/specialists'
    }
}

Write-Host "== specialists-teardown $midDot $root ==" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host "   DRY RUN -- nothing will be removed. Re-run with -Apply to act." -ForegroundColor Yellow
}

# Tallies. $kept is the interesting one: it is what makes this safe to run, and it is reported rather
# than silently skipped, because a reader has to know what the script chose NOT to do.
$removed = @()
$kept    = @()
$notes   = @()

# WHAT COUNTS AS ONE OF OUR OWN LINES IN CLAUDE.md. Defined here rather than inside section 2, because
# two sections need the same answer: section 2 REMOVES these lines, and the free-standing audit in
# section 8 must not report them as surviving references (inbound #275). A predicate mirrored by hand in
# two places is exactly what produced both instances of the orphaned-note defect, so there is one.
#
# Matching on CONTENT rather than on line numbers is deliberate: after -Apply the file has been rewritten
# and every number has shifted, so a number-based exclusion would silently skip the wrong lines on the
# very run where the check matters least. Content-based, the exclusion simply finds nothing after -Apply,
# because the lines are gone.
$isSpecialistImport = {
    param($line)
    if ($line.Trim() -eq $seam.ImportLine) { return $true }   # the seam: one line, knowably ours
    ($line -match '^\s*@') -and ($line -match '(-persona\.md|-extension\.md)\s*$')
}
$isOurClaudeMdLine = {
    param($line)
    (& $isSpecialistImport $line) -or (Test-IsOrchestratorNoteLine -Line $line)
}

function Test-LooksGenerated {
    <# Is this file still an unfilled scaffold?

       A content test rather than a timestamp or hash, deliberately: a consumer may have reformatted
       line endings or been through a merge, and neither makes the content authored.

       CRITICAL: the test keys on an UNFILLED PLACEHOLDER, not on the string 'VUL-IN' appearing
       anywhere. The first version did the latter and would have deleted a fully configured
       repo-config.ps1 in a real consumer -- found by a dry run against davekokbwj/smartwatchbanden on
       2026-07-29, where all eight contract functions carry real values and the only 'VUL-IN' left is
       in the scaffold's own DOCSTRING, which a consumer has no reason to strip. That is not an edge
       case, it is the normal state of a filled-in scaffold, so the naive rule would have removed the
       file that open-pr, fold-changelog, new-branch and check-roster-sync all depend on.

       Third instance of one pattern in a single day -- a content test that matches a MENTION rather
       than a USE. The roster check counted an '@'-import path as a roster row (#227); the lint gate
       read a marker quoted in changelog prose as a real enumeration (#235); this one read a docstring
       explaining placeholders as a placeholder. When a check's evidence is "this string appears in the
       file", ask what else in that file legitimately contains it -- and for a script that DELETES,
       resolve every doubt toward keeping. #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        # 'lens'        -> the scaffold's unfilled slot heading, e.g. '## Specific to this repo (VUL-IN)'
        #                  or the nameless '# 06-16 <dot> repo lens (VUL-IN)' header.
        # 'repo-config' -> an assignment whose VALUE is still a placeholder ($script:LintScript = 'VUL-IN').
        # 'branch-info' -> the empty prefix table the bootstrap writes; a repo that filled its taxonomy
        #                  has entries there, and that is the only signal that cannot be faked by prose.
        [Parameter(Mandatory = $true)][ValidateSet('lens', 'repo-config', 'branch-info')][string]$Kind
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    switch ($Kind) {
        'lens' {
            # The scaffold shape this plugin writes.
            if ($text -match '(?m)^#{1,6}\s.*\(VUL-IN\)\s*$') { return $true }
            # The consumer's own empty-lens convention, only if they told us what it looks like.
            if ($EmptyLensPattern -and ($text -match $EmptyLensPattern)) { return $true }
            return $false
        }
        'repo-config' {
            # An unfilled placeholder VALUE -- the shape a consumer WITH the workflow plugin receives,
            # whose RepoName/LintScript are theirs to fill in.
            if ($text -match "=\s*'[^']*VUL-IN") { return $true }
            # SECOND SHAPE SINCE AUGUST 8, 2026, and it exists because the split created a scaffold with
            # nothing to fill in. A consumer that did NOT enable the workflow plugin gets the roster half
            # alone: RosterPath derived from the seam, RosterIgnoredIds empty. It is complete as
            # generated, so it carries no placeholder -- and the rule above would therefore have read it
            # as authored and kept it forever, making adoption exactly as irreversible as this skill
            # promises it is not.
            #
            # KEYED ON "STILL EXACTLY WHAT THE BOOTSTRAP WROTE", which is conservative in the direction
            # this file requires: every way an owner can touch this file ADDS something -- an ignored id,
            # a workflow function when they later enable the pack, a helper of their own. Any of those
            # fails one of the three tests below and the file is kept. Only the untouched shape matches.
            # FOUR TESTS, AND THE FIRST IS THE ONE THAT MAKES THIS SAFE. The other three establish that
            # the file LOOKS like the generated shape; this one establishes that the bootstrap SAYS it
            # wrote it. Without it, a consumer who happened to hand-write a repo-config holding exactly
            # these two functions and an empty ignore list would have it deleted -- "resembles ours"
            # is not "is ours", and for a script that removes, every remaining doubt resolves toward
            # keeping.
            $claimsGenerated = $text -match 'Placed by specialists-init'
            $hasRosterPair = ($text -match '(?m)^\s*function\s+Get-RosterPath\b') -and
                             ($text -match '(?m)^\s*function\s+Get-RosterIgnoredIds\b')
            $ignoredStillEmpty = $text -match '(?m)^\s*\$script:RosterIgnoredIds\s*=\s*@\(\s*\)\s*$'
            $noOtherFunctions = @([regex]::Matches($text, '(?m)^\s*function\s+([A-Za-z-]+)')).Count -eq 2
            return ($claimsGenerated -and $hasRosterPair -and $ignoredStillEmpty -and $noOtherFunctions)
        }
        'branch-info' { return ($text -match '(?m)\$script:BranchPrefixTable\s*=\s*@\{\s*\}') }
    }
    return $false
}

function Remove-IfApplying {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if ($Apply) { Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction Stop }
    $script:removed += $Label
    Write-Host ("  [remove] " + $Label) -ForegroundColor Green
}

function Add-Kept {
    <# THE ONE DOOR EVERY [KEEP] MARKER GOES THROUGH, so the markers a reader sees and the figure they
       skim to cannot disagree. They did: the scaffold-prose lines in section 2 printed their own
       [KEEP] line straight to the host and never touched $kept, so a run that printed two [KEEP]
       markers and a [note] saying "2 line(s)" summarised itself as "0 kept" (inbound #356, test round
       v11). Measured on the fresh-consumer row -- a repo with no CLAUDE.md before adoption -- which is
       exactly the case #331 added that reporting for.

       The same shape as the #275 preview/apply drift one category over: a second, private tally kept
       beside the real one. The lesson there was one list, one number, one label per item; this applies
       it to the kept side, which is the half that lesson did not reach.

       $Advice groups the listing in the summary rather than describing the item. It has to: the
       -EmptyLensPattern remedy is true of a file whose shape this script did not recognise, and simply
       false of a prose line inside CLAUDE.md. One blanket paragraph over both would have to be wrong
       for one of them, and the wrong half would be the advice to delete lines out of a governance
       file. #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Detail,
        [Parameter(Mandatory = $true)][ValidateSet('scaffold-shape', 'claude-md-prose')][string]$Advice
    )
    $script:kept += [pscustomobject]@{ Label = $Label; Detail = $Detail; Advice = $Advice }
    Write-Host ("  [KEEP]   $Label -- $Detail") -ForegroundColor Yellow
}

# --- 1. Lens files on the plugin path ------------------------------------------------------------
# Both layouts the bootstrap has ever used, so a repo adopted before #179 is torn down too.
$lensDirs = @(
    $seam.LensDir,
    (Join-Path $root '.claude\plugins'),
    (Join-Path $root '.claude\extensions')
)
foreach ($dir in $lensDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    # Both spellings (#2130), on the same guarded-lib pattern as $seam above: a teardown that knows one
    # spelling leaves the other behind, silently, and "remove one directory and one line" stops being
    # true of exactly the consumers that kept up with the rename.
    $lenses = if (Get-Command Get-SpecialistFiles -ErrorAction SilentlyContinue) {
        @(Get-SpecialistFiles -Path $dir -Kind Lens -Recurse)
    } else {
        @(Get-ChildItem -LiteralPath $dir -Recurse -Filter '*-extension.md' -File -ErrorAction SilentlyContinue)
    }
    foreach ($lens in $lenses) {
        $rel = $lens.FullName.Substring($root.Length).TrimStart('\', '/')
        if (Test-LooksGenerated -Path $lens.FullName -Kind 'lens') {
            Remove-IfApplying -Path $lens.FullName -Label $rel
        } else {
            # Deliberately does NOT say "filled in" or "somebody wrote this". The script cannot
            # establish authorship -- it can only say the file does not match a scaffold shape it
            # recognises. Claiming otherwise was measurably false in a real consumer, where 20 empty
            # lenses were reported as repo knowledge because they used that repo's own convention.
            Add-Kept -Label $rel -Advice 'scaffold-shape' `
                -Detail 'not recognised as an unfilled scaffold; this script does not judge it'
        }
    }
}

# --- 1b. The seam's inclusion file -----------------------------------------------------------------
# SPECIALISTS.md is classified exactly like a lens, and for the same reason: an unfilled slot heading
# means the bootstrap wrote it and nobody touched it; a filled-in roster is the owner's work.
#
# THE ONE ORPHAN, AND WHY IT IS AN IMPROVEMENT. When it IS authored it is kept while the import line
# that loaded it is removed -- so it survives as a file nothing reads. That is the same shape as the
# orphaned orchestrator lens the pre-seam layout left behind, with one decisive difference: it is ONE
# file with a name, holding the roster in one piece, instead of 43 lines scattered through six sections
# of CLAUDE.md. An unbounded hand-editing job becomes one file and one decision, which is the whole
# point of the seam. The import is still removed either way: that line is what makes the content LIVE,
# and a live reference is exactly what the requirement bites on.
if (Test-Path -LiteralPath $seam.Inclusion -PathType Leaf) {
    $inclRel = $seam.Inclusion.Substring($root.Length).TrimStart('\', '/')
    if (Test-LooksGenerated -Path $seam.Inclusion -Kind 'lens') {
        Remove-IfApplying -Path $seam.Inclusion -Label $inclRel
    } else {
        Add-Kept -Label $inclRel -Advice 'scaffold-shape' `
            -Detail 'not recognised as an unfilled scaffold; this script does not judge it'
        $notes += "$inclRel is kept, and after this run nothing loads it: the import line in CLAUDE.md is gone. It holds whatever roster/routing you wrote there -- move what you still want into CLAUDE.md by hand, or delete the file. This is the seam paying off: one named file to decide about, instead of a roster woven through CLAUDE.md."
    }
}

# Prune the lens trees and the seam directory only when genuinely empty -- an authored lens or a kept
# SPECIALISTS.md must not lose its directory out from under it.
#
# REPORTED AND TALLIED IN BOTH MODES (inbound #275). This whole block used to sit inside `if ($Apply)`,
# so the directories it cleans up were counted on the apply run and never mentioned in the preview: the
# same run, over the same work, reported "29 item(s) to remove" and then "31 item(s) removed", while both
# outputs listed identical [remove] lines. The dry run is explicitly the inventory a reader needs in order
# to say yes, so a preview that undercounts its own execution weakens exactly the property it exists to
# provide. Either count them in both or in neither -- and a directory that disappears is something a
# reader should see coming, so: both.
#
# On a dry run the emptiness is PREDICTED rather than observed: a directory counts as empty when every
# file still in it is already on the remove list. That is the same question -Apply answers by looking,
# because by then those files are gone -- which is why one code path serves both and the two counts
# cannot drift apart again.
# ONE code path, called twice (inbound #331). It used to be a loop right here over the lens trees and the
# seam only -- and `scripts\lib\` was therefore left behind as an empty directory after -Apply, because the
# file inside it is not planned for removal until section 3, further down. Rather than copy the loop, it
# became a callable: here for the lens/seam directories, and again after section 3 for the script-config
# ones. Deepest first in both calls, because a parent only reads as empty once its child is gone.
#
# It RETURNS the labels it handled instead of appending to $removed itself: a scriptblock cannot append to
# its caller's variable, and quietly keeping a second tally is exactly how the preview/apply drift in #275
# started. One list, one number, one label per item.
$pruneEmptyDirs = {
    param([string[]]$Dirs, [string[]]$PlannedSoFar)
    $planned = [System.Collections.Generic.HashSet[string]]::new([string[]]$PlannedSoFar, [System.StringComparer]::OrdinalIgnoreCase)
    $handled = @()
    foreach ($dir in $Dirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $leftovers = @(
            Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { -not $planned.Contains($_.FullName.Substring($root.Length).TrimStart('\', '/')) }
        )
        if ($leftovers.Count -gt 0) { continue }
        # One label for the printed line and the tally, so the list a reader reads and the number they are
        # given cannot describe the same item differently.
        $dirLabel = $dir.Substring($root.Length).TrimStart('\', '/') + '\ (empty directory)'
        if ($Apply) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        $handled += $dirLabel
        Write-Host ("  [remove] " + $dirLabel) -ForegroundColor Green
    }
    return $handled
}
$removed += @(& $pruneEmptyDirs -Dirs ($lensDirs + @($seam.Dir)) -PlannedSoFar $removed)

# --- 2. The @-imports in CLAUDE.md ---------------------------------------------------------------
# The only lines in that file this script will touch. Safe precisely because an @-import naming a
# persona body or an extension lens is bootstrap-written and cannot be anything else -- the same
# property that let check-roster-sync stop counting them as roster rows (issue #227).
$claudeMd = Join-Path $root 'CLAUDE.md'
if (Test-Path -LiteralPath $claudeMd -PathType Leaf) {
    $text0 = [System.IO.File]::ReadAllText($claudeMd, [System.Text.Encoding]::UTF8)
    $lines = [System.IO.File]::ReadAllLines($claudeMd)
    # The explanatory note the bootstrap writes above the imports. Removed too, and matched on its
    # LITERAL generated wording only -- a consumer who reworded or translated it has authored that
    # text. Leaving it behind is what made the round-trip accumulate a copy per cycle: the bootstrap's
    # guard saw the paragraph gone-but-not-gone and re-appended the whole block (measured 1 -> 2 -> 3
    # in davekokbwj/smartwatchbanden, 2026-07-29, with every gate reporting "in sync").
    #
    # AND THEN IT HAPPENED AGAIN ONE LINE LOWER (inbound #271, DaveKJohn/life-hub, 2026-07-30). The note
    # is a sentence wrapped over TWO lines, and this matched only the first: every teardown left the tail
    # behind, and the next bootstrap wrote a fresh two-line note above the orphan. Measured 1 orphan
    # after cycle 1, 2 after cycle 2, CLAUDE.md +4 lines from a round trip that should return to zero --
    # while every counter, including the regression test for the FIRST version of this bug, keyed on the
    # head and read healthy throughout. Test-IsOrchestratorNoteLine (check-report-lib.ps1) now matches
    # the whole block and is the single source shared with the bootstrap's own tidy guard, because a
    # literal mirrored by hand in two scripts is what produced both instances.
    #
    # AND THE REPORT NAMES WHICH LINE (inbound #286, test round v5). Removing per line is right -- both
    # lines must go -- but printing the same sentence twice told a reader nothing about which half of the
    # block was meant, and made a HEALTHY repo print "2" for a check the doc frames as the series
    # 1 -> 2 -> 3. So the loudest reading of a clean run was the accumulation defect itself. The audit
    # below already names file:line for this exact reason (the choice is per line, not per file); this
    # follows its format. head/tail comes from the shared source rather than a re-typed literal, because
    # re-typing that literal is what produced both instances of the accumulation bug.
    $noteSrc  = Get-OrchestratorNote
    $noteHits = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not (Test-IsOrchestratorNoteLine -Line $lines[$i])) { continue }
        $part  = if ($lines[$i].Trim() -eq $noteSrc.Head) { 'head' } else { 'tail' }
        $label = "CLAUDE.md:$($i + 1) -- the bootstrap's orchestrator note ($part)"
        $noteHits += $lines[$i]
        Write-Host ("  [remove] " + $label) -ForegroundColor Green
        $removed += $label
    }

    $hits = @($lines | Where-Object { & $isSpecialistImport $_ })
    if ($hits.Count -gt 0 -or $noteHits.Count -gt 0) {
        foreach ($hit in $hits) {
            Write-Host ("  [remove] CLAUDE.md import: " + $hit.Trim()) -ForegroundColor Green
            $removed += ('CLAUDE.md import: ' + $hit.Trim())
        }
        if ($Apply) {
            $keptLines = @($lines | Where-Object {
                (-not (& $isSpecialistImport $_)) -and (-not (Test-IsOrchestratorNoteLine -Line $_))
            })
            # Trailing blank lines the imports left behind, so the file does not end in a growing gap.
            while ($keptLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($keptLines[-1])) {
                $keptLines = $keptLines[0..($keptLines.Count - 2)]
            }
            # Preserve the file's own line endings. WriteAllLines uses Environment.NewLine, which is
            # right on Windows/CRLF and wrong for an LF-normalised repo; the sibling defect on the
            # bootstrap side pasted LF into a CRLF file and no gate saw it.
            $nl = if ($text0 -match "`r`n") { "`r`n" } else { "`n" }
            [System.IO.File]::WriteAllText($claudeMd, (($keptLines -join $nl) + $nl))
        }
    }
    # The scaffold prose the bootstrap writes when it CREATES CLAUDE.md. REPORTED, never removed -- and it
    # is here because being reported as neither was the defect (inbound #331, test round v10). On a consumer
    # that had no CLAUDE.md before adoption, every byte of the file is bootstrap-written, so after a full
    # teardown these lines are all that is left in it -- and they appeared as neither [remove] nor [KEEP]
    # while the audit below printed [FREE]. That audit was narrowly right (the lines name no specialist,
    # persona, roster or lens, so nothing loads because of them), which is what made the silence the real
    # finding: this script's contract with the reader is that [remove] versus [KEEP] tells them which case
    # they were in, and here it was neither.
    #
    # Not removed, deliberately: the boundary this script keeps is that it takes out lines whose authorship
    # is knowable AND whose removal cannot cost the owner anything -- an @-import loads something, prose
    # does not. Deleting sentences out of somebody's governance file to satisfy a counter is the wrong side
    # of that line. Per LINE rather than per file, following the same reasoning as the note above (#286):
    # the choice a reader makes here is per line. Literal from the shared source, never re-typed.
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not (Test-IsClaudeMdScaffoldProseLine -Line $lines[$i])) { continue }
        Add-Kept -Label "CLAUDE.md:$($i + 1)" -Advice 'claude-md-prose' `
            -Detail 'the bootstrap''s scaffold prose; generated, but this script does not delete prose from a governance file'
    }
    # DERIVED from the one list, never counted alongside it. The note below and the summary's figure are
    # two readings of the same thing, and the whole of #356 was them disagreeing.
    $scaffoldKept = @($kept | Where-Object { $_.Advice -eq 'claude-md-prose' }).Count
    if ($scaffoldKept -gt 0) {
        $notes += "CLAUDE.md still holds $scaffoldKept line(s) of the scaffold prose specialists-init wrote when it CREATED that file. Generated rather than yours, but reported instead of removed: this script does not delete prose from a governance file. If your CLAUDE.md exists only because of the bootstrap, those line(s) plus the '# CLAUDE.md' heading are now all that is in it, and deleting the file outright is yours to decide."
    }

    # Everything else in CLAUDE.md is authored text, and a roster row is not distinguishable from
    # ordinary prose by any rule this script could apply safely. Reported as the owner's call.
    # The shared pattern where the lib loaded, the literal otherwise (#2130) -- the same guarded shape
    # the second copy of this pattern already used 300 lines down, which is why only ONE of the two
    # would have picked up the lookbehind repair. A hand-copy that happens to be correct today is still
    # the drift #182 is about; both copies now ask the same function.
    $rosterIdPattern = if (Get-Command Get-RosterIdTokenPattern -ErrorAction SilentlyContinue) {
        Get-RosterIdTokenPattern
    } else {
        '(?<!\d)(?<!\d-)\d{2}-\d{2}(?!\d)'
    }
    $rosterish = @($lines | Where-Object { $_ -match $rosterIdPattern -and $_ -notmatch '^\s*@' })
    if ($rosterish.Count -gt 0) {
        $notes += "CLAUDE.md still holds $($rosterish.Count) line(s) mentioning a specialist id (the roster table, the routing, the chains). Authored text -- remove the sections you no longer want by hand. This script will not guess where a roster row ends and your own prose begins."
    }
}

# --- 3. Script-config scaffolds ------------------------------------------------------------------
# Category 3: these describe THIS repo's conventions (its branch taxonomy, its lint gate) and stay
# useful with the plugin gone. Removed only while still untouched placeholders.
foreach ($pair in @(
    @{ Rel = 'scripts\repo-config.ps1';     What = 'repo config';      Kind = 'repo-config' },
    @{ Rel = 'scripts\lib\branch-info.ps1'; What = 'branch taxonomy';  Kind = 'branch-info' }
)) {
    $path = Join-Path $root $pair.Rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    if (Test-LooksGenerated -Path $path -Kind $pair.Kind) {
        Remove-IfApplying -Path $path -Label $pair.Rel
    } else {
        # "not recognised as an unfilled scaffold", NOT "filled in" (inbound #271). The summary block at
        # the end was corrected after davekokbwj/smartwatchbanden -- where 20 genuinely empty lenses were
        # reported as authored because they used that repo's own convention -- but this per-item line kept
        # the old claim, so the run asserted authorship in one place and hedged in the other. The script
        # cannot establish who wrote a file; it can only say the content does not match a shape it knows.
        Add-Kept -Label $pair.Rel -Advice 'scaffold-shape' `
            -Detail "not recognised as an unfilled scaffold; it holds this repo's $($pair.What), which outlives the plugin"
    }
}

# The second call of the pruner above, now that section 3's files are on the list. `scripts\lib\` survived
# every round up to v10 as an empty directory for exactly this reason: its only file leaves here, and the
# single pruning pass had already run. A repo that keeps a filled-in branch table or has scripts of its own
# fails the emptiness test and is untouched, which is why this can be unconditional.
$removed += @(& $pruneEmptyDirs -Dirs @((Join-Path $root 'scripts\lib'), (Join-Path $root 'scripts')) -PlannedSoFar $removed)

# --- 4. The settings proposals ---------------------------------------------------------------------
# Proposals the bootstrap places for the owner to adopt. If either is still lying around it was never
# adopted, so it is pure leftover.
#
# BOTH NAMES COME FROM Get-SettingsArtifactNames, the same function the bootstrap writes them with, so a
# second artifact cannot be added on one side and forgotten on the other. That is not hypothetical
# tidiness: '.claude/*' is gitignored in many consumers, so a leftover this script does not know about is
# invisible to git status AND to the teardown -- the two places anyone would look. The fallback mirrors
# the bootstrap's own, for the same reason it has one.
$settingsArtifacts = if (Get-Command Get-SettingsArtifactNames -ErrorAction SilentlyContinue) {
    Get-SettingsArtifactNames
} else {
    [pscustomobject]@{ Suggested = '.claude\settings.suggested.jsonc'; Proposed = '.claude\settings.proposed.json' }
}
foreach ($artifact in @($settingsArtifacts.Suggested, $settingsArtifacts.Proposed)) {
    $artifactPath = Join-Path $root $artifact
    if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
        Remove-IfApplying -Path $artifactPath -Label $artifact
    }
}

function Get-InstallRecordState {
    <# Does the CLI still hold an install record pointing at THIS repo?

       The same question UNINSTALL.md asks twice (Step 2 to find the record, Step 4 to prove it is
       gone), asked here so a note can be gated on the answer instead of asserting one (inbound #381).

       Three outcomes, and the caller has to distinguish all three, because "no record" and "could not
       look" are not the same claim:
         Readable = $false          -> no file, or unparseable. Say so; do not report it as clean.
         Readable, 0 records        -> nothing points here. That IS the post-uninstall reading.
         Readable, >= 1 record      -> name them, with the scope each one is actually in.

       The scope comes off the record rather than being assumed to be 'project': a session start can
       write a record in 'local' scope by itself, and an uninstall aimed at the wrong scope is exactly
       the failure UNINSTALL.md spends a paragraph on.

       Path comparison is trailing-separator and case insensitive: $root is a resolved path and
       projectPath is whatever the CLI wrote, and on Windows those differ in ways that mean nothing. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
    $path       = Join-Path $claudeHome 'plugins\installed_plugins.json'
    $state      = [pscustomobject]@{ Path = $path; Readable = $false; Records = @() }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $state }

    # A teardown must not die on its bookkeeping. An unreadable or reshaped file is reported as
    # "could not look", never as "nothing there" -- the whole point of this gate is to stop the
    # script claiming things about a state it did not measure.
    try {
        $data = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    } catch { return $state }
    $state.Readable = $true
    if (-not $data -or -not $data.plugins) { return $state }

    $want = $RepoRoot.TrimEnd('\', '/')
    $hits = @()
    foreach ($entry in @($data.plugins.PSObject.Properties)) {
        foreach ($record in @($entry.Value)) {
            if (-not $record.projectPath) { continue }
            if ("$($record.projectPath)".TrimEnd('\', '/') -ieq $want) {
                $hits += [pscustomobject]@{
                    Name  = $entry.Name
                    Scope = if ($record.scope) { $record.scope } else { 'project' }
                }
            }
        }
    }
    $state.Records = $hits
    return $state
}

# --- 5. What only the owner can do ---------------------------------------------------------------
# Reported, never done. Disabling the plugin is the actual uninstall, and the bootstrap never wrote
# settings.json either -- the symmetry that keeps this script safe to run cuts both ways.
#
# THE TWO NOTES BELOW ARE ONE INSTRUCTION, AND USED TO READ AS TWO (inbound #295). They print in this
# order in the same output: note 1 told the reader to remove the 'enabledPlugins' entry by hand, and note
# 2 -- one line later -- told them to run 'claude plugin uninstall ... --scope project', which was
# measured on 2026-07-31 to remove that very entry itself and leave "enabledPlugins": {} behind. Anyone
# following them in order therefore hand-edited a file that the next command was about to edit anyway,
# and then found a diff in a tracked governance file two paragraphs after reading that this procedure
# never touches it. So note 1 now says when the hand-edit is actually needed, and points forward.
$settings = Join-Path $root '.claude\settings.json'
if (Test-Path -LiteralPath $settings -PathType Leaf) {
    $text = [System.IO.File]::ReadAllText($settings, [System.Text.Encoding]::UTF8)
    # The marketplace name appears in every 'enabledPlugins' key ('<plugin>@<marketplace>') and in the
    # marketplace-source key. Match both the current name and the retired one, so a consumer that has
    # not yet migrated off 'claude-code-specialists' still gets the note (#1769).
    if ($text -match 'dkj-claude-plugins|claude-code-specialists') {
        $notes += ".claude/settings.json still enables the plugin. That file is yours -- THIS SCRIPT never edits it. The uninstall command in the next note removes the 'enabledPlugins' entry for you (it leaves 'enabledPlugins': {} behind), so edit this file by hand only if you are NOT running that command, or to drop the marketplace source when nothing else uses it. Either way the subagents and the session hooks stay active until the entry is gone and the session has been restarted."
    }
}
# The scope flag is not decoration: 'claude plugin uninstall' defaults to --scope user (verified via
# its own --help, July 30, 2026), so on a project-scoped install -- which is the model this family
# documents -- the bare command targets a record that is not there. Same default, and same failure,
# as 'plugin install' and 'plugin update' (inbound #279).
#
# GATED, like the settings note above it, and for the same reason (inbound #381). This note used to
# print unconditionally, which the Step 4 re-run in UNINSTALL.md turned into a falsehood: that re-run
# happens AFTER the uninstall, so a reader who had just seen 'Successfully uninstalled' was told one
# step later that the install was untouched, with the advice to go and do it again. The settings note
# had already gone quiet by then, which made the contradiction louder rather than softer -- the script
# visibly knew things about the state, just not this one. The condition was lying around: it is the
# same projectPath query UNINSTALL.md prints twice, in Step 2 and again in Step 4.
$install = Get-InstallRecordState -RepoRoot $root
if ($install.Records.Count -gt 0) {
    $which = @($install.Records | ForEach-Object { "$($_.Name) (scope $($_.Scope))" } | Sort-Object -Unique) -join ', '
    $cmds  = @($install.Records | ForEach-Object { "claude plugin uninstall $($_.Name) --scope $($_.Scope)" } | Sort-Object -Unique) -join ' ; '
    $notes += "The plugin install itself is untouched, and this repo still has a record: $which. Run '$cmds' from this repo's root if you want it gone here as well. The scope flag matters -- the command defaults to user scope and will not find a project-scoped install without it. Expect it to edit .claude/settings.json: it removes the 'enabledPlugins' entry and leaves 'enabledPlugins': {}, so a diff there is the command working, not a fault (inbound #295)."
} elseif ($install.Readable) {
    $notes += "No install record points at this repo any more, so there is nothing left to uninstall here. Checked on projectPath against $($install.Path) -- the same query UNINSTALL.md runs in Step 2 and again in Step 4. If you are re-running this audit after the uninstall, this line IS the expected reading, not a step you skipped."
} else {
    $notes += "The plugin install itself is untouched -- though this run could not read $($install.Path) (missing or not parseable), so take that as the general case and not as a reading of your machine. Run 'claude plugin uninstall <plugin>@<marketplace> --scope project' from this repo's root if you want it gone here as well. The scope flag matters -- the command defaults to user scope and will not find a project-scoped install without it. Expect it to edit .claude/settings.json: it removes the 'enabledPlugins' entry and leaves 'enabledPlugins': {}, so a diff there is the command working, not a fault (inbound #295)."
}

# --- 6. Runtime dependencies on the plugin: reported loudly, never removed ------------------------
# The finding that made this section necessary (measured by hand in davekokbwj/smartwatchbanden,
# 2026-07-29). The plugin owns the operational scripts as their single source of truth (issue #81), and
# a consumer reaches them through a resolver of its OWN that locates the marketplace cache -- and
# THROWS once that cache is gone. In the measured repo, scripts/lib/plugin-paths.ps1 was that resolver
# and three operational scripts dot-sourced it (start-task, open-pr, fold-changelog-entry), so a
# teardown plus uninstall did not leave clutter behind: it took the repo's daily git workflow down.
#
# No option to this script can fix that, because adopting the shared-script model is what creates the
# dependency. What it CAN stop doing is being silent about it. Everything above answers "what did the
# bootstrap put here"; this answers "what will break after you uninstall", which is the question a
# reader actually has before trusting the word REVERSIBLE. So this section is REPORT-ONLY by
# construction -- these files are the consumer's own code, and a script that deletes them to make its
# own summary look clean would be doing the exact damage the classification above exists to prevent.
$resolverFindings = @()
$scriptsDir = Join-Path $root 'scripts'
if (Test-Path -LiteralPath $scriptsDir) {
    # Two ways a consumer script can reach into the plugin: the marketplace cache path, or the
    # CLAUDE_PLUGIN_ROOT the harness only sets while the plugin is installed. Both stop working at the
    # same moment, and neither leaves a trace in git.
    $cacheRefPattern = 'plugins[\\/]marketplaces|CLAUDE_PLUGIN_ROOT'
    $ps1Files = @(Get-ChildItem -LiteralPath $scriptsDir -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
    $texts = @{}
    foreach ($f in $ps1Files) {
        $texts[$f.FullName] = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    }
    foreach ($f in $ps1Files) {
        if ($texts[$f.FullName] -notmatch $cacheRefPattern) { continue }
        # Who leans on this resolver? Named by filename rather than by parsing the dot-source syntax:
        # a consumer may reach it via $PSScriptRoot, a variable, or Join-Path, and this report only has
        # to point a human at the right files -- not resolve them.
        $dependents = @(
            $ps1Files |
                Where-Object { $_.FullName -ne $f.FullName -and $texts[$_.FullName] -match [regex]::Escape($f.Name) } |
                ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') }
        )
        $resolverFindings += [pscustomobject]@{
            Rel        = $f.FullName.Substring($root.Length).TrimStart('\', '/')
            Dependents = $dependents
        }
    }
}
if ($resolverFindings.Count -gt 0) {
    Write-Host ''
    foreach ($finding in $resolverFindings) {
        Write-Host ("  [WARN]   " + $finding.Rel + " resolves the plugin cache -- it throws once the plugin is uninstalled") -ForegroundColor Red
        if ($finding.Dependents.Count -gt 0) {
            Write-Host ("           depended on by: " + ($finding.Dependents -join ', ')) -ForegroundColor Red
        }
    }
    $notes += "$($resolverFindings.Count) script(s) under scripts/ resolve the plugin install at runtime and stop working after 'claude plugin uninstall' -- listed above as [WARN], and deliberately NOT removed: they are your code. No teardown can fix this, because the shared-script model (#81) is what creates the dependency. Two ways out, both yours to pick BEFORE you uninstall: keep local copies of the operational scripts (re-run with -VendorScripts and this script writes them for you, overwriting nothing), or make the resolver degrade to one clear, actionable failure instead of a throw. Note this scan covers scripts/ only, so a resolver living elsewhere is not counted."
}

# --- 7. -VendorScripts: hand back working copies of the shared scripts ----------------------------
# The way out of section 6, and the only place this script writes rather than deletes -- opt-in for
# exactly that reason (see .PARAMETER VendorScripts). Without it, a teardown can describe the runtime
# dependency and nothing more; with it, the consumer keeps a working git workflow after the plugin is
# gone, which is what "reversible" was supposed to mean in the first place.
#
# Structure is preserved, because the payload depends on it: the scripts dot-source their siblings
# $PSScriptRoot-relative (scripts/release/* reaching ..\lib\native-capture-lib.ps1, and so on) while
# locating the REPO via CLAUDE_PROJECT_DIR / git rev-parse. Flattening the tree would break the first
# without touching the second -- the failure would surface at the next branch, not here.
if ($VendorScripts) {
    $payloadDir = Join-Path $PSScriptRoot '..\..\scripts'
    $payloadRoot = if (Test-Path -LiteralPath $payloadDir) { (Resolve-Path -LiteralPath $payloadDir).Path } else { $null }
    if (-not $payloadRoot) {
        # Reported rather than thrown: a teardown that already removed things must not die on its last
        # step, and the reader needs to know the vendoring did NOT happen.
        $notes += "-VendorScripts: the plugin's shared scripts are not reachable from this script's location ($payloadDir), so nothing was vendored. Run the teardown from the installed plugin, or copy the scripts by hand."
    } else {
        Write-Host ''
        $vendored = @(); $vendorCurrent = @(); $vendorSkipped = @()
        foreach ($src in @(Get-ChildItem -LiteralPath $payloadRoot -Recurse -Filter '*.ps1' -File)) {
            $rel     = $src.FullName.Substring($payloadRoot.Length).TrimStart('\', '/')
            $dest    = Join-Path (Join-Path $root 'scripts') $rel
            $destRel = Join-Path 'scripts' $rel
            if (Test-Path -LiteralPath $dest -PathType Leaf) {
                if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $src.FullName).Hash) {
                    $vendorCurrent += $destRel
                    Write-Host ("  [vendor] " + $destRel + " -- already current") -ForegroundColor DarkGray
                } else {
                    # The collision that matters: typically the consumer's own thin wrapper around the
                    # shared script. Authored content, so the same rule that protects a filled-in lens
                    # protects it here -- named, never replaced.
                    $vendorSkipped += $destRel
                    Write-Host ("  [SKIP]   " + $destRel + " -- exists and differs; yours, not overwritten") -ForegroundColor Yellow
                }
                continue
            }
            if ($Apply) {
                $destDir = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -LiteralPath $src.FullName -Destination $dest -Force
            }
            $vendored += $destRel
            Write-Host ("  [vendor] " + $destRel + $(if ($Apply) { '' } else { ' (would be written)' })) -ForegroundColor Green
        }
        # NO SILENT CAP (August 8, 2026). Since the branch/release workflow became its own plugin, this
        # payload is the CORE's only -- the sync/check scripts and their lib. new-branch, open-pr,
        # ship-pr, fold-changelog and cut-release ship in dkj-policy and are not
        # reachable from here: the two plugins are separately versioned and separately installed, so
        # copying across their cache directories would be a runtime dependency on a path a version
        # mismatch silently breaks. Stated rather than left to be discovered, because a vendor run that
        # lists four files reads as "that was all of it".
        $notes += "-VendorScripts covers this plugin's payload only. If you also run dkj-policy, its scripts (new-branch, open-pr, ship-pr, fold-changelog-entry, cut-release and the libs they dot-source) are NOT in this list -- copy them out of that plugin's own scripts/ directory before you uninstall it."
        $verb = if ($Apply) { 'vendored' } else { 'to vendor' }
        $note = "-VendorScripts: $($vendored.Count) script(s) $verb into scripts/, $($vendorCurrent.Count) already current"
        if ($vendorSkipped.Count -gt 0) {
            $note += ", $($vendorSkipped.Count) skipped because a different file already sits there ($($vendorSkipped -join ', ')) -- those are yours to reconcile: compare them against the vendored copy and decide which one you keep."
        } else { $note += '.' }
        $notes += $note
        if ($vendored.Count -gt 0 -or $vendorCurrent.Count -gt 0) {
            $notes += "The vendored scripts are yours now: a later teardown will not remove them (it only knows the bootstrap's own inventory), and they no longer need the plugin to run. What they DO still need is the repo-owned script contract they dot-source -- scripts/lib/branch-info.ps1 and scripts/repo-config.ps1 -- so keep those, whatever else you drop."
            # The one combination that hands back scripts with nothing to dot-source. Said out loud
            # rather than left to be discovered at the next branch: a repo whose contract was still an
            # unfilled scaffold never had a working workflow to preserve, so this is a statement of
            # where it stands, not a failure.
            $contractGone = @($removed | Where-Object { $_ -match 'repo-config\.ps1|branch-info\.ps1' })
            if ($contractGone.Count -gt 0) {
                $notes += "Heads-up: this same run also $(if ($Apply) { 'removed' } else { 'would remove' }) $($contractGone -join ' and ') -- still an unfilled scaffold, so it counted as generated. The scripts just vendored dot-source exactly that contract, so they cannot run until you provide it. A repo in this state had no working workflow to keep in the first place."
            }
        }
    }
}

# --- 8. The free-standing audit: what LIVE references are left ------------------------------------
# THE HALF THE REQUIREMENT WAS MISSING (issue #221). Everything above answers "what did the bootstrap
# put here, and what did I take away". None of it answers the question Dave's requirement actually
# poses: after this, does the repo STAND FREE? Section 2 gets closest with a count of CLAUDE.md lines
# holding a specialist id -- one narrow slice of one file -- and the target shape's second item,
# "reword category 3 plugin-neutrally", was never something a script could do: that prose belongs to
# the repo owner, and a plugin rewriting an owner's governance text would be the exact damage the
# classification in this script exists to prevent.
#
# So this section does the part a script legitimately CAN do: it finds the references and lists them by
# file and line, turning an unbounded hand-audit into a checklist. Reword-or-delete stays the owner's
# call, on evidence instead of on faith.
#
# REPORT-ONLY AND UNCONDITIONAL, including on a dry run. It removes nothing and so needs no -Apply, and
# a preview that cannot tell you what would still be left is not the inventory a reader needs in order
# to say yes.
#
# WHAT "LIVE" MEANS HERE, and why the scope is what it is. The family README settles the reading: the
# requirement bites on what a session LOADS, a script RESOLVES, or a gate DEPENDS ON -- not on every
# occurrence of a name. So the scanned set is CLAUDE.md, everything under .claude/, and everything
# under scripts/. History is deliberately excluded and never rewritten: CHANGELOG.md and releases/
# record that the adoption happened, which is accurate. Other tracked prose (README.md,
# CONTRIBUTING.md) is outside the live set by that same reading, so it is COUNTED rather than listed --
# a pointer, not a work item, and labelled as such instead of quietly dropped.
$auditRoots = @(
    @{ Rel = 'CLAUDE.md'; Recurse = $false },
    @{ Rel = '.claude';   Recurse = $true },
    @{ Rel = 'scripts';   Recurse = $true }
)
# The names come from THIS plugin's own payload -- never a hardcoded list, which would be a guess that
# rots on the next rename. Two sources, matching the two shapes a specialist ships in: an agent def's
# `name:` frontmatter, and a persona's H1 (personas deliberately have no agent def).
#
# HONEST LIMIT, stated because it changes how the output should be read: this skill ships inside ONE
# plugin and can only see that plugin's specialists. A consumer that also enables a domain plugin has
# names this scan does not know. The ID scan below is the general net -- '<gg>-<ii>' tokens are
# name-independent and catch a specialist from any plugin -- and the name scan is the extra pass on top.
$knownNames = @()
foreach ($dir in @('subagents', 'agents', 'personas')) {
    $srcDir = Join-Path $PSScriptRoot "../../$dir"
    if (-not (Test-Path -LiteralPath $srcDir)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $srcDir -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
        $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $m = [regex]::Match($txt, '(?m)^name:\s*([A-Za-z0-9_-]+)\s*$')
        if ($m.Success) { $knownNames += (Get-DisplayName -RawName $m.Groups[1].Value); continue }
        # Persona: the display name is the first word of the H1 ('# Derek <emoji> -- the DevOps ...').
        $h = [regex]::Match($txt, '(?m)^#\s+([A-Za-z][A-Za-z0-9_-]*)')
        if ($h.Success) { $knownNames += (Get-DisplayName -RawName $h.Groups[1].Value) }
    }
}
$knownNames = @($knownNames | Where-Object { $_ } | Sort-Object -Unique)

$idPattern = if (Get-Command Get-RosterIdTokenPattern -ErrorAction SilentlyContinue) {
    Get-RosterIdTokenPattern
} else {
    '(?<!\d)(?<!\d-)\d{2}-\d{2}(?!\d)'
}
# Word-bounded, so 'Cody' does not match inside 'Codyssey' and a name is never reported off a substring.
#
# Matching stays CASE-INSENSITIVE (PowerShell's -match default), and that is a deliberate bias toward
# OVER-reporting. This is an audit whose whole purpose is establishing that nothing was missed, so its
# expensive failure is a reference it did not find, not one a reader dismisses in five seconds. Every hit
# carries file:line, which makes a false positive cheap and a false negative silent -- so the doubt is
# resolved toward reporting, the same direction Test-LooksGenerated resolves its doubt toward keeping.
#
# POSSESSIVE FORMS ARE PART OF THE NAME (inbound #271). The trailing \b used to reject 'Dereks' -- the
# Dutch possessive, which takes no apostrophe -- so a genuinely live reference in a non-English consumer's
# own tracked prose went unreported. That is a false NEGATIVE in a scan that documents itself as biased
# toward over-reporting precisely because a miss is the expensive failure. Reported from a Dutch consumer,
# and it is not an edge case: it applies to every non-English repo.
#
# The optional group covers Dutch ('Dereks'), English ("Derek's"), and the apostrophe-only form Dutch uses
# after s/x/z ("Alex'"). Bare 's' risks nothing here: these are specialist first names, and 'Codys' or
# 'Veras' is not a word that appears by accident -- and if it did, the hit carries file:line and costs a
# reader five seconds.
$namePattern = if ($knownNames.Count -gt 0) {
    '\b(' + (($knownNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ")(?:'s|s'|'|s)?\b"
} else { $null }

$auditFiles = @()
foreach ($r in $auditRoots) {
    $p = Join-Path $root $r.Rel
    if (-not (Test-Path -LiteralPath $p)) { continue }
    if ($r.Recurse) {
        # EVERY FILE, DELIBERATELY -- no extension filter, and the absence of one is the decision (#421).
        #
        # This call used to carry `-Include '*.md','*.ps1','*.json','*.jsonc'` beside `-LiteralPath`, and
        # PowerShell SILENTLY IGNORES -Include when the path is given as -LiteralPath. So the walk has
        # always read every file under these roots while its own code named four extensions -- the same
        # defect found in Get-MojibakePaths (#413), reported together with it. Repaired in the other
        # direction here: the four-name list is gone rather than made to work.
        #
        # MEASURED BEFORE DECIDING, because #421 asked two questions the line cannot answer by itself.
        #   1. Does any documented teardown figure change? No. Across the three repos on hand
        #      (claude-code-specialists, life-hub, djcylow-react) the ONLY files outside the four
        #      extensions were two .js files under djcylow-react/scripts, and both scan to zero hits. No
        #      round's number was measured against something the strict list would have excluded.
        #   2. Is the superset the better behaviour? Yes, and not by luck. A purpose-built fixture with
        #      `// Derek opens the PR` in scripts/deploy.js and `Tessa maintains the manuals` in
        #      .claude/notes.txt yields 4 live references today and would yield 1 with the filter
        #      working -- so "repairing" it would blind the audit to exactly the class it exists to
        #      catch. A live reference is live regardless of the extension it sits in: a deploy script,
        #      a .yml, a .txt note under .claude/ are all things a session loads, a script resolves, or
        #      a gate depends on.
        #
        # It is also the only reading consistent with this section's own bias, stated twice above: a
        # false positive is cheap and a false negative silent, so the doubt is resolved toward reporting.
        # An extension allowlist is a false-negative generator by construction.
        #
        # The one cost, named rather than left to be discovered: a non-text file under these roots
        # (an image in .claude/) is read too, and could match the id pattern on decoded bytes. That
        # costs one [LIVE] line with a file:line the reader dismisses at a glance -- the output prints
        # the path and what matched, never the matched text, so no binary content can reach the console.
        $auditFiles += @(Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue)
    } else {
        $auditFiles += @(Get-Item -LiteralPath $p)
    }
}
$auditFiles = @($auditFiles | Sort-Object -Property FullName -Unique)

# FILES THIS RUN IS ABOUT TO DELETE ARE NOT LEFTOVERS (inbound #271). On a dry run the audit used to be
# swamped by the ~20 lens files the same run had just listed under [remove]: every one of them mentions a
# specialist, they filled the 40-line cap entirely, and the handful of hits that actually matter only
# became visible AFTER -Apply. That inverts the purpose -- the preview is explicitly the inventory a
# reader says yes to, and it was showing them the one category that is guaranteed to be gone.
#
# Excluded rather than sorted last: a reference inside a file that is being removed is not a surviving
# reference at all, so listing it would be wrong, not merely noisy. $removed carries rel paths for files
# (plus a few non-path labels for imports, which simply never match an audit path).
#
# AND THE SAME RULE AT LINE GRANULARITY (inbound #275). The exclusion above covers files this run
# DELETES; the bootstrap's orchestrator note and the `@`-imports are lines this run deletes inside a file
# that STAYS. Without them excluded, a dry run reported `CLAUDE.md:<n> -- name 'Chris'` as a surviving
# live reference on the very run that lists that same line under [remove] -- and the audit dropped from 5
# live references to 4 after -Apply, on a consumer whose CLAUDE.md held nothing but its own governance
# text plus the bootstrap's output. One order of granularity smaller than the 40-lens defect fixed in
# 3.0.0, and identical in kind: over-reporting by exactly what the run is about to remove, in the mode
# where a reader is least able to tell. $isOurClaudeMdLine (hoisted to the top) is the shared predicate,
# so what section 2 removes and what this section discounts cannot drift apart.
$removedPaths = [System.Collections.Generic.HashSet[string]]::new([string[]]$removed, [System.StringComparer]::OrdinalIgnoreCase)

$liveHits = @()
$skippedBecauseRemoved = 0
$skippedLines = 0
foreach ($f in $auditFiles) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')
    if ($removedPaths.Contains($rel)) { $skippedBecauseRemoved++; continue }
    $isClaudeMd = ($rel -eq 'CLAUDE.md')
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
        $lineNo++
        $what = @()
        if ($line -match $idPattern) { $what += 'specialist id' }
        # $Matches[0], not [1]: report the text as it appears in the FILE, possessive included. The
        # capture group holds the bare name, so a hit on 'Dereks' used to be reported as 'Derek' -- a
        # reader then searches for a string that is not on that line. An audit exists to point at real
        # text.
        if ($namePattern -and ($line -match $namePattern)) { $what += "name '$($Matches[0])'" }
        # A repo-config that survives is category 3 -- the repo's own conventions -- but two of the
        # contract functions in it exist ONLY for the plugin. Named separately, because "keep this file"
        # and "keep every line in this file" are different answers.
        # The '$script:' variants must NOT sit behind a shared leading \b: '$' is not a word character,
        # so '\b\$' demands a word char immediately before the dollar and therefore never matches an
        # assignment at the start of a line -- which is exactly where these live. Caught by running the
        # audit against a hand-built fixture, where '$script:RosterPath = ...' on line 3 was missed while
        # 'function Get-RosterPath' on line 4 was found. Each alternative now carries its own anchor.
        if ($line -match '(?:\bGet-RosterPath\b|\bGet-RosterIgnoredIds\b|\$script:Roster(?:Path|IgnoredIds)\b)') {
            $what += 'plugin-only contract function'
        }
        if ($what.Count -eq 0) { continue }
        # LINE GRANULARITY: ours, and going away, so not a leftover. Tested AFTER the match rather than
        # before it, deliberately -- that way the number the scan line states is references excluded, not
        # lines skipped. Most of the removed lines (a bare seam import) carry no reference at all, and
        # counting those would inflate an exclusion notice into a claim about references that never were.
        if ($isClaudeMd -and (& $isOurClaudeMdLine $line)) { $skippedLines++; continue }
        $liveHits += [pscustomobject]@{ Rel = $rel; Line = $lineNo; What = ($what -join ' + '); Text = $line.Trim() }
    }
}

Write-Host ''
Write-Host "-- free-standing audit: LIVE references left after this teardown --" -ForegroundColor Cyan
# The count states what was SCANNED, not what was found in the tree -- and the excluded files are named,
# because a silent exclusion is exactly the kind of quiet narrowing this audit exists to prevent.
$scannedCount = $auditFiles.Count - $skippedBecauseRemoved
$didOrWould = if ($Apply) { 'removed' } else { 'would remove' }
$skipNote = if ($skippedBecauseRemoved -gt 0) { " $skippedBecauseRemoved file(s) this run $didOrWould were excluded -- a reference inside a file that is going away is not a leftover." } else { '' }
# Stated, never silent -- for the same reason the file-level exclusion is stated. On -Apply this is 0
# because the lines are already gone, which is the honest number rather than a missing one.
if ($skippedLines -gt 0) { $skipNote += " $skippedLines reference(s) on CLAUDE.md line(s) this run $didOrWould (the bootstrap's orchestrator note, its @-import(s)) were excluded for the same reason, at line granularity." }
Write-Host ("   scanned $scannedCount file(s) under CLAUDE.md, .claude/ and scripts/ against $($knownNames.Count) known specialist name(s); history (CHANGELOG.md, releases/) is excluded on purpose and never rewritten.$skipNote") -ForegroundColor DarkGray
if ($liveHits.Count -eq 0) {
    Write-Host "  [FREE]   no live reference to a specialist, persona, roster or lens is left in the scanned set." -ForegroundColor Green
    $notes += "Free-standing audit: clean. Nothing a session loads, a script resolves, or a gate depends on still points at the plugin. That is the requirement met, verified rather than assumed."
} else {
    # No silent caps: a bounded list must say what it bounded, or a truncated report reads as a complete
    # one -- the same rule the release notes and the connector summary follow.
    $show = 40
    foreach ($h in ($liveHits | Select-Object -First $show)) {
        Write-Host ("  [LIVE]   " + $h.Rel + ":" + $h.Line + " -- " + $h.What) -ForegroundColor Yellow
    }
    if ($liveHits.Count -gt $show) {
        Write-Host ("  ... and $($liveHits.Count - $show) more, not listed (showing the first $show)") -ForegroundColor Yellow
    }
    $byFile = @($liveHits | Group-Object Rel | Sort-Object Count -Descending)
    $notes += "Free-standing audit: $($liveHits.Count) live reference(s) across $($byFile.Count) file(s) -- densest: $(($byFile | Select-Object -First 3 | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '). These are YOURS: authored governance text, not bootstrap leftovers, so this script names them and changes nothing. Two ways to clear one, and the choice is per line rather than per file: DELETE it if the rule only ever existed for the plugin, or REWORD it if the rule still holds without the character -- 'Derek opens the PR' becomes 'changes go in via a branch and a PR', which stays true with the plugin gone. A 'plugin-only contract function' hit is the third case: the surrounding file is yours to keep, but that particular function existed only to serve the roster check."
}

# Outside the live set: counted, not listed. Prose and history are not what the requirement bites on,
# and an owner deciding what to do with their own README should get a pointer, not a work queue.
$proseHits = 0
foreach ($f in @(Get-ChildItem -LiteralPath $root -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
    if ($f.Name -eq 'CLAUDE.md' -or $f.Name -eq 'CHANGELOG.md') { continue }
    $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    foreach ($line in ($txt -split "`r?`n")) {
        if (($line -match $idPattern) -or ($namePattern -and $line -match $namePattern)) { $proseHits++ }
    }
}
if ($proseHits -gt 0) {
    $notes += "Outside the live set: $proseHits line(s) in other root markdown (README.md, CONTRIBUTING.md, ...) mention a specialist or an id. Counted, not listed, and not part of the requirement: nothing loads, resolves or gates on them. Yours to reword whenever you feel like it. CHANGELOG.md and releases/ are excluded entirely -- they record that the adoption happened, which stays true."
}

# --- Summary --------------------------------------------------------------------------------------
Write-Host ''
# "kept", not "kept (authored)". The script cannot establish authorship, and saying so was measurably
# wrong: 20 empty lenses in a real consumer were reported as authored because they used that repo's own
# convention rather than this plugin's scaffold shape.
#
# THE NUMBER IS NOW THE MARKERS, because it was not (inbound #356). Every [KEEP] line goes through
# Add-Kept, so this figure counts exactly what the run printed. A reader skims to this line before they
# read anything above it, which is why a summary contradicting its own markers is worse than a missing
# one: it is the failure mode #331 was filed about, occurring inside the repair for it.
Write-Host ("Summary: " + $removed.Count + " item(s) " + $(if ($Apply) { 'removed' } else { 'to remove' }) + ", " + $kept.Count + " kept.") -ForegroundColor Cyan
# Grouped by remedy rather than listed flat. The -EmptyLensPattern escape hatch answers "this file is
# empty under a convention you do not know"; it says nothing useful about a prose line in CLAUDE.md, and
# printing it over both would advise deleting sentences out of a governance file -- the one thing this
# script refuses to do itself.
$keptScaffold = @($kept | Where-Object { $_.Advice -eq 'scaffold-shape' })
$keptProse    = @($kept | Where-Object { $_.Advice -eq 'claude-md-prose' })
if ($keptScaffold.Count -gt 0) {
    Write-Host "  Kept -- not recognised as an unfilled scaffold. Review them: some may be empty under a" -ForegroundColor Yellow
    Write-Host "  convention this plugin does not know, in which case they are yours to delete (or re-run" -ForegroundColor Yellow
    Write-Host "  with -EmptyLensPattern '<your marker>' to have them recognised):" -ForegroundColor Yellow
    foreach ($k in $keptScaffold) { Write-Host "    $($k.Label)" }
}
if ($keptProse.Count -gt 0) {
    Write-Host "  Kept -- generated prose in a governance file. Reported rather than removed; deleting" -ForegroundColor Yellow
    Write-Host "  sentences out of your CLAUDE.md is your call, not this script's:" -ForegroundColor Yellow
    foreach ($k in $keptProse) { Write-Host "    $($k.Label)" }
}
foreach ($n in $notes) { Write-Host "  [note] $n" }
if (-not $Apply -and $removed.Count -gt 0) {
    Write-Host "  Re-run with -Apply to remove the $($removed.Count) item(s) above." -ForegroundColor Yellow
}
exit 0
