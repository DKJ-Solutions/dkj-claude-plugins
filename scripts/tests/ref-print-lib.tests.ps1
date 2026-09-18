<#
.SYNOPSIS
    Tests for scripts/lib/ref-print-lib.ps1 -- the two verdicts on a ref name about to be printed: may it
    be interpolated into a paste-ready COMMAND (issue #1594), and what does it look like as PROSE (issue
    #1623).

.DESCRIPTION
    THE HOSTILE NAMES ARE SPLIT ON GIT'S OWN ACCEPTANCE, measured rather than assumed, because the two
    halves prove different things:

      - REACHABLE -- `git check-ref-format --branch` returns 0, so a repo can genuinely hold the name and
        nothing upstream of the print site refuses it. This half carries the finding, and each case
        asserts git's acceptance as an explicit premise: if a future git tightened its rules, that assert
        is the one that should go red, because at that point the case has stopped testing anything real.
      - UNREACHABLE -- git rejects the name ('^', '*', '~', ':', '[', '\', '?', whitespace and every
        ASCII control character). Asserted anyway, and not as padding: the guard has to be a property of
        the STRING, not an inference from git's rules. sync-main.ps1 hands it a name built from a seam
        answer a consumer wrote, which git has never seen.

    THE SPLIT IS ON `\p{Cc}` VERSUS `\p{Cf}`, AND THAT IS THE #1617 CORRECTION. git enforces only the
    ASCII control class, so the format characters -- U+202E, U+200D, U+200B, U+2066 -- are REACHABLE
    and belong in the first half. They sat in the second until September 8, 2026, under a header
    saying git refuses them, which mirrored the same wrong claim in the lib's own scope note.

    THE STRUCTURAL HALF IS AS LOAD-BEARING AS THE UNIT HALF. The lib is correct and unreachable if a call
    site still interpolates the raw ref, so all seven sites #1594 measured are asserted to name the token
    -- and asserted to carry no remaining raw `$branch` inside a printed command. That assert is what
    would catch the eighth site somebody adds next year, which is the failure mode the issue itself
    demonstrated: it reported three of the seven.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'

$script:pass = 0
$script:fail = 0
# Premises git could not be asked about on this run -- see Assert-GitRefPremise (issue #2107). Counted
# and reported rather than folded into either of the two above, because an unmeasured premise is
# neither a pass nor a failure and printing it as one of them is the defect that issue records.
$script:unmeasured = 0

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

Assert-True (Test-Path -LiteralPath $LibPath) 'ref-print-lib.ps1 exists at its registered source path'
. $LibPath
# For the premise checks below. `git check-ref-format` writes its refusal to stderr, and a bare native
# call under $ErrorActionPreference = 'Stop' turns that into a NativeCommandError in Windows PowerShell
# 5.1 -- the exact pitfall this repo's own guidance names. -DiscardStderr is the answer already in the
# tree, so the premise check reads an exit code rather than fighting the host.
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

function Test-GitAcceptsRef {
    <#
        -Utf8 IS LOAD-BEARING HERE, NOT AN ENCODING PREFERENCE (issue #1966). The & operator cannot hand
        a quote-bearing argument to a child faithfully: measured September 14, 2026, this same call with
        'fix/a"b' asked git about 'fix/ab' and git answered about 'fix/ab' -- exit 0, echoing the
        stripped name. So the one assert in this file that proves git accepts a QUOTE in a ref name had
        never tested a quote, and passed for a reason that had nothing to do with its subject.

        -Utf8 routes to Start-Process, which quotes the arguments itself, so every name below now
        reaches git as written. The premise re-measured under that faithful delivery: all seventeen
        hostile names are genuinely accepted by git (exit 0, each echoed back intact), so the block below
        asserts the same thing it always claimed to -- for the first time.

        Invoke-NativeCapture REFUSES the old spelling now rather than mis-delivering it, so this is not a
        convention anybody has to remember: the & arm throws on the three shapes it cannot pass.

        THREE STATES, BECAUSE TWO OF THEM ARE OPPOSITE FACTS (issue #2107). -Utf8 routes to
        Start-Process, and that arm can hand back an ExitCode which is LITERALLY $null -- the child ran,
        but the value is not a measurement of it. #1931 measured 27 of 960 captures (2.8%) under 16
        lanes of fresh PowerShell children, confined to the FIRST Start-Process in a fresh process, and
        Invoke-NativeCapture reports it as ExitCodeUnknown for exactly this reason.

        `$r.ExitCode -eq 0` cannot see that: $null -eq 0 is $false, so an exit code nobody measured
        reads as "git refused this ref" -- the premise assert then fails, and it fails claiming the
        opposite of what happened. Measured in CI on 18 September 2026, twice out of two runs: the
        first of seventeen hostile names failed while the sixteen after it passed, which is that
        confinement exactly. Green standalone on the same tree, 461 asserts.

        So this returns $true / $false / $null, and $null means "this run could not measure it". The
        caller reports that instead of asserting on it -- the same three-state repair claim-issue's
        read-back got in #1628, for the same reason: a check that cannot tell silence from a clean
        answer teaches its reader to trust the wrong one.

        NOT A RETRY, deliberately. native-capture-lib's own header declines that on measurement --
        #1931 found a 200ms re-read budget still leaves 7 of 240 unresolved -- so a loop here would buy
        an unreliable recovery with wall-clock on every capture. Reporting the state honestly is what
        the field was built for.

        THE PROPERTY IS PROBED, NOT READ BARE: under Set-StrictMode -Version Latest a bare
        $r.ExitCodeUnknown throws on a capture that predates the field, so this is the idiom
        native-capture-lib uses on itself.
    #>
    param([string]$Ref)
    $r = Invoke-NativeCapture -FilePath 'git' -Arguments @('check-ref-format', '--branch', $Ref) -DiscardStderr -Utf8
    if ($r.PSObject.Properties['ExitCodeUnknown'] -and $r.ExitCodeUnknown) { return $null }
    if ($null -eq $r.ExitCode) { return $null }
    return ($r.ExitCode -eq 0)
}

function Assert-GitRefPremise {
    <#
        Assert what git does with a ref name, in whichever direction the case needs -- and report
        rather than assert when this run could not measure it (issue #2107).

        EVERY PREMISE IN THIS FILE GOES THROUGH HERE, in both directions, and the negative direction is
        why it had to be a helper rather than a rule to remember. The eight call sites were split:

            Assert-True (Test-GitAcceptsRef -Ref $x)          -- $null is falsy, so it FAILED wrongly
            Assert-True (-not (Test-GitAcceptsRef -Ref $x))   -- -not $null is $true, so it PASSED wrongly

        The second is the worse half and the one nothing would have caught: a silent green on a premise
        nobody established. The red in CI was only ever the louder symptom of the same missing state.

        -Expect $true  : git must accept the name (the reachable half carries the finding).
        -Expect $false : git must reject it (the unreachable half -- defence in depth, since the guard
                         has to be a property of the STRING rather than an inference from git's rules).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Ref,
        [Parameter(Mandatory = $true)][bool]$Expect,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $actual = Test-GitAcceptsRef -Ref $Ref
    if ($null -eq $actual) {
        $script:unmeasured++
        # NOT A FAILURE AND NOT A PASS. The capture came back with an ExitCode that is not a
        # measurement, so the only honest thing to say is that git was not asked. Yellow, named, and
        # carried to the footer so a run cannot quietly contain a premise nobody established.
        Write-Host "  [UNMEASURED] $Label -- the capture returned no usable exit code (#1931/#2107)" -ForegroundColor Yellow
        return
    }
    Assert-True ($actual -eq $Expect) $Label
}

# --- the names this workflow actually uses are all safe -------------------------------------------
# THE REGRESSION THAT MATTERS MOST. A guard that refused an ordinary branch name would break every
# remedy in the workflow, so the ordinary shapes are asserted first and explicitly.
Write-Host ''
Write-Host 'Safe names -- every shape this workflow creates' -ForegroundColor Cyan

foreach ($ok in @(
    'fix/1594-printed-command-ref-safety',
    'feat/branch-document-name-and-headings',
    'docs/prose-phase-heading-levels',
    'sync/live-2026-09-08',
    'sync/live-2026-09-08-2',
    'fix/template-newline-v2',
    'main',
    'release/4.32.0',
    'a',
    '9lives/thing_one.two-three'
)) {
    Assert-True (Test-RefPasteSafe -Ref $ok) "safe: '$ok'"
    $v = Get-PasteableRef -Ref $ok
    Assert-Equal $ok $v.Token "...and its token is the name itself: '$ok'"
    Assert-Equal '' $v.Note   "...and it carries no note: '$ok'"
    Assert-True $v.IsSafe     "...and IsSafe is true: '$ok'"
}

# --- the hostile names, each one legal to git ------------------------------------------------------
Write-Host ''
Write-Host 'Refused names -- and git accepts every one of them, which is the finding' -ForegroundColor Cyan

# MEASURED, September 8, 2026, and split on the measurement rather than on intuition. git rejects
# '^', '*', '~', ':', '[', '\' and '?' in a branch name (exit 128) and ACCEPTS everything below -- so
# only these are reachable through a real ref, and only these carry the finding. The rejected set is
# exercised separately further down, because the guard must not depend on git having filtered first.
#
# `.Contains()` RATHER THAN -like, and the backtick case is why. In a -like pattern the backtick is the
# escape character and '*', '?' and '[' are wildcards, so "*$bad*" silently stops being a substring test
# for exactly the names this suite exists to cover: the first run of this file passed every case except
# the backtick one, for that reason and not because the lib was wrong.
$hostileReachable = @(
    'fix/evil;touch',
    'fix/evil&touch',
    'fix/evil|touch',
    'fix/evil$(touch)',
    'fix/evil`touch`',
    "fix/it's-fine",
    'fix/a"b',
    'fix/a>b',
    'fix/a<b',
    'fix/a!b',
    'fix/a%b',
    'fix/a{b}',
    'fix/a(b)',
    'fix/a=b',
    'fix/a,b',
    'fix/a@b',
    'fix/a+b'
)

$gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
foreach ($bad in $hostileReachable) {
    if ($gitAvailable) {
        # THE PREMISE, CHECKED RATHER THAN ASSUMED. If a future git tightened its ref rules this assert is
        # the one that should fail, and it should fail LOUDLY -- at that point the character is no longer
        # reachable and the case below has stopped testing anything real.
        Assert-GitRefPremise -Ref $bad -Expect $true -Label "git accepts '$bad' as a branch name (the premise of this whole guard)"
    }
    Assert-True (-not (Test-RefPasteSafe -Ref $bad)) "refused: '$bad'"
    $v = Get-PasteableRef -Ref $bad
    Assert-Equal '<branch>' $v.Token "...and its token is the placeholder, so the name never enters the command: '$bad'"
    Assert-True (-not $v.IsSafe) "...and IsSafe is false: '$bad'"
    Assert-True ([bool]$v.Note) "...and it carries a note: '$bad'"
    Assert-True ($v.Note.Contains($bad)) "...whose note names the real branch, so the reader can still act: '$bad'"
    Assert-True ($v.Note.Contains('1594')) "...and cites the issue: '$bad'"
}

# --- the characters git itself refuses, refused here too ------------------------------------------
# BELT AND BRACES, ASSERTED ON PURPOSE. None of these can arrive through `git rev-parse`, so this block
# is not about reachability -- it is about the guard being a property of the STRING rather than an
# inference from git's rules. sync-main.ps1 hands it a name built from a seam answer a consumer wrote,
# which git has never seen, so a guard that leaned on "git filtered it already" would be wrong there.
Write-Host ''
Write-Host 'Characters git rejects in a ref -- refused here independently of git' -ForegroundColor Cyan

foreach ($unreachable in @('fix/a^b', 'fix/a*b', 'fix/a~b', 'fix/a:b', 'fix/a[b]', 'fix/a\b', 'fix/a?b')) {
    if ($gitAvailable) {
        Assert-GitRefPremise -Ref $unreachable -Expect $false -Label "git itself rejects '$unreachable' (so this case is defence in depth, not a hole)"
    }
    Assert-True (-not (Test-RefPasteSafe -Ref $unreachable)) "refused here anyway: '$unreachable'"
}

# --- the space and the CONTROL characters: git refuses them, and so does this ---------------------
# NOT REACHABLE THROUGH A REF, and asserted anyway. Get-PasteableRef takes a string, and a caller that
# hands it something other than `git rev-parse`'s output (a seam answer, a -Name parameter) is not bound
# by git's rules at all -- so the guard must not depend on git having filtered first.
#
# THE FORMAT CHARACTERS ARE NOT IN THIS GROUP AND USED TO BE (#1617). U+202E sat here under a header
# saying git refuses it, which is false: git enforces `\p{Cc}` and not `\p{Cf}`. It has moved to the
# reachable block below, where its premise is measured like every other reachable case.
Write-Host ''
Write-Host 'Whitespace and ASCII control characters -- refused here too, independently of git' -ForegroundColor Cyan

foreach ($ws in @('fix/a b', "fix/a`tb", "fix/a`nb", "fix/a$([char]0x1B)[31mb")) {
    if ($gitAvailable) {
        Assert-GitRefPremise -Ref $ws -Expect $false -Label "git itself rejects this whitespace/control name (so this case is defence in depth, not a hole)"
    }
    Assert-True (-not (Test-RefPasteSafe -Ref $ws)) 'refused: a name carrying whitespace or an ASCII control character'
}

# --- the FORMAT characters: git ACCEPTS them, which is the #1617 finding --------------------------
# MEASURED, September 8, 2026. `git check-ref-format --branch` returns 0 for every code point below, a
# branch so named is creatable and checkout-able, and `git rev-parse --abbrev-ref HEAD` returns it
# verbatim -- which is the source every print site reads its branch from. They are `\p{Cf}` (format),
# not `\p{Cc}` (control), and git enforces only the second class. U+202E and U+200D are the two #1446
# was filed for, where they bypassed the #1439 tip sanitiser on a non-UTF-8 console.
#
# THE PREMISE IS ASSERTED THE SAME WAY THE SHELL-METACHARACTER CASES ASSERT THEIRS: if a future git
# tightened its ref rules this is the assert that should go red, because at that point ref-print-lib's
# scope note has stopped describing a live gap and should be re-read.
Write-Host ''
Write-Host 'Format characters -- git accepts them in a ref, and this guard refuses them anyway' -ForegroundColor Cyan

foreach ($cf in @(
    @{ Ref = "fix/a$([char]0x202E)b"; Label = 'U+202E RIGHT-TO-LEFT OVERRIDE' },
    @{ Ref = "fix/a$([char]0x200D)b"; Label = 'U+200D ZERO WIDTH JOINER' },
    @{ Ref = "fix/a$([char]0x200B)b"; Label = 'U+200B ZERO WIDTH SPACE' },
    @{ Ref = "fix/a$([char]0x2066)b"; Label = 'U+2066 LEFT-TO-RIGHT ISOLATE' }
)) {
    if ($gitAvailable) {
        Assert-GitRefPremise -Ref $cf.Ref -Expect $true -Label "git ACCEPTS $($cf.Label) in a branch name (the #1617 premise)"
    }
    Assert-True (-not (Test-RefPasteSafe -Ref $cf.Ref)) "refused on the paste axis anyway: $($cf.Label)"
    $v = Get-PasteableRef -Ref $cf.Ref
    Assert-Equal '<branch>' $v.Token "...and its token is the placeholder: $($cf.Label)"
    Assert-True ($v.Note -notmatch '[\p{Cf}]') "...and the format character does not survive into the note: $($cf.Label)"
}

# AND THE SCOPE NOTE SAYS SO, rather than claiming git closed this class. The lib's own reasoning is
# what #1617 was filed against -- the guard was already right and the sentence explaining it was not --
# so the correction is pinned here, where a rewrite that quietly restores the old claim goes red.
$libText = [System.IO.File]::ReadAllText($LibPath)
Assert-True ($libText -match [regex]::Escape('1617')) 'ref-print-lib.ps1 cites #1617 where it scopes display out'
Assert-True ($libText -notmatch [regex]::Escape('git already rejects the control characters that would make prose deceptive')) 'and no longer claims git closes the deceptive class for a ref name'

# AND THE NOTE ITSELF IS NOT AN INJECTION SURFACE. The one place this lib prints is the refusal path, so
# a control or format character surviving into it would mean the guard's own output could repaint a
# terminal or wear this workflow's warning prefix -- remote-ahead-lib.ps1's lesson (#1439, #1446) applied
# to this lib's output. Belt-and-braces for a name from `git rev-parse`, load-bearing for sync-main's
# seam-derived one, which git has never filtered.
foreach ($esc in @("fix/a$([char]0x1B)[31mb", "fix/a$([char]0x202E)b", "fix/a$([char]0x0D)b", "fix/a$([char]0x07)b")) {
    $n = (Get-PasteableRef -Ref $esc).Note
    Assert-True ([bool]$n) 'the refusal still carries a note for a control-character name'
    # THE NOTE'S OWN LINE BREAKS ARE NOT THE SUBJECT -- it is a multi-line message and CR/LF are control
    # characters, so they come out before the assert. What must not survive is a control or format
    # character carried in from the NAME.
    $body = $n -replace "`r", '' -replace "`n", ''
    Assert-True ($body -notmatch '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]') 'and no control, format, line/paragraph separator or combining-mark character from the name survives into it'
}

# --- the empty case ------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The empty ref -- a caller that lost its branch' -ForegroundColor Cyan

foreach ($empty in @('', $null)) {
    Assert-True (-not (Test-RefPasteSafe -Ref $empty)) 'an empty or null ref is NOT paste-safe'
    $v = Get-PasteableRef -Ref $empty
    Assert-Equal '<branch>' $v.Token 'an empty ref yields the placeholder rather than a command with a hole in it'
    Assert-True ($v.Note -like '*could not read it*') 'and its note says the run could not read the name, not that the name is ""'
}

# --- the placeholder is caller-chosen ------------------------------------------------------------
Write-Host ''
Write-Host 'The placeholder' -ForegroundColor Cyan

$custom = Get-PasteableRef -Ref 'fix/evil;touch' -Placeholder '<your branch>'
Assert-Equal '<your branch>' $custom.Token 'a caller may choose the placeholder'
Assert-True ($custom.Note -like '*<your branch>*') 'and the note quotes the placeholder it actually used, so the two agree'

# --- the DISPLAY axis: Get-DisplayRef (issue #1623) -----------------------------------------------
# THE SECOND HALF OF THE SAME WALL. #1594 scoped display out because "git already rejects the control
# characters that would make prose deceptive"; #1617 measured that git rejects \p{Cc} and ACCEPTS \p{Cf},
# which is the half that deceives. So these cases assert git's acceptance as an explicit premise, exactly
# as the paste half above does: if a future git tightened its ref rules, THAT assert is the one that
# should go red, because the case has then stopped testing anything real.
Write-Host ''
Write-Host 'Get-DisplayRef -- the prose strip, on names git itself accepts' -ForegroundColor Cyan

foreach ($cf in @(
    @{ Cp = 0x202E; Name = 'U+202E RIGHT-TO-LEFT OVERRIDE' },
    @{ Cp = 0x200D; Name = 'U+200D ZERO WIDTH JOINER' },
    @{ Cp = 0x200B; Name = 'U+200B ZERO WIDTH SPACE' },
    @{ Cp = 0x2066; Name = 'U+2066 LEFT-TO-RIGHT ISOLATE' }
)) {
    $ref = 'fix/a' + [char]$cf.Cp + 'b'
    Assert-GitRefPremise -Ref $ref -Expect $true -Label "premise: git accepts a branch carrying $($cf.Name)"
    Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $ref) "and the prose strip turns it into a visible space -- $($cf.Name)"
}

# THE CONTROL CLASS IS ASSERTED TOO, and not as padding. git refuses these in a ref, but Get-DisplayRef
# takes a STRING: sync-main.ps1 hands it a name built from a seam answer a consumer wrote, and this lib's
# own refusal note hands it whatever Get-PasteableRef was called with. The guard must be a property of the
# string rather than an inference from git's rules.
foreach ($cc in @(0x1B, 0x0D, 0x07, 0x00)) {
    $ref = 'fix/a' + [char]$cc + 'b'
    Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $ref) "a control character is stripped too: 0x$('{0:X2}' -f $cc)"
}

# ISSUE #2024. Zl/Zp and Mn/Me are neither Cc nor Cf, so both survived this strip untouched until now.
foreach ($sep in @(
    @{ Cp = 0x2028; Name = 'U+2028 LINE SEPARATOR' },
    @{ Cp = 0x2029; Name = 'U+2029 PARAGRAPH SEPARATOR' }
)) {
    $ref = 'fix/a' + [char]$sep.Cp + 'b'
    Assert-GitRefPremise -Ref $ref -Expect $true -Label "premise: git accepts a branch carrying $($sep.Name)"
    Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $ref) "and the prose strip turns it into a visible space -- $($sep.Name), which could otherwise make one printed line read as two"
}
$refZalgo = 'fix/a' + [char]0x0301 + [char]0x0301 + 'b'
Assert-GitRefPremise -Ref $refZalgo -Expect $true -Label 'premise: git accepts a branch carrying stacking combining marks'
Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $refZalgo) 'and the prose strip removes a run of stacking combining marks ("Zalgo text") the same way it removes a run of format characters'

# ISSUE #2024'S SECOND HALF, MEASURED WHILE REPAIRING #2025. A regex class over these six categories is
# silently wrong twice on Windows PowerShell 5.1 -- these two are exactly the cases it misses.
$refSoftHyphen = 'fix/a' + [char]0xAD + 'b'
Assert-GitRefPremise -Ref $refSoftHyphen -Expect $true -Label 'premise: git accepts a branch carrying U+00AD SOFT HYPHEN'
Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $refSoftHyphen) 'U+00AD reads as Format to the runtime and Dash Punctuation to the regex engine -- a regex [\p{Cf}] class does not match it, and this strip does'
$refTagBlock = 'fix/a' + [char]::ConvertFromUtf32(0xE0074) + 'b'
Assert-Equal 'fix/a b' (Get-DisplayRef -Ref $refTagBlock) 'a format character above the BMP (the TAG block, a surrogate pair) is invisible to a regex [\p{Cf}] class outright -- this strip catches it, and the two spaces it emits collapse to one here, same as any other run'

# A SPACE RATHER THAN NOTHING, which is the case the choice was made for: deleting a zero-width joiner
# welds 'fix/relea' + 'se' into 'fix/release', a legitimate name that is not the branch you are on.
Assert-Equal 'fix/relea se' (Get-DisplayRef -Ref ('fix/relea' + [char]0x200D + 'se')) 'a zero-width joiner does not weld two halves into a different legitimate name'

# RUNS COLLAPSE AND THE RESULT IS TRIMMED, so a long invisible run does not become a long visible gap and
# a name that was ENTIRELY invisible comes back as '' rather than as a cloud of blanks.
Assert-Equal 'fix/a b' (Get-DisplayRef -Ref ('fix/a' + [char]0x200B + [char]0x200B + [char]0x202E + 'b')) 'a run of format characters collapses to one space'
Assert-Equal '' (Get-DisplayRef -Ref ([char]0x200B + [char]0x200D + [char]0x2066)) 'a name made entirely of format characters has no display at all'
Assert-Equal '' (Get-DisplayRef -Ref '') 'the empty name stays empty'
Assert-Equal '' (Get-DisplayRef -Ref $null) 'a null name is the empty name'

# AND A NAME THIS WORKFLOW ACTUALLY USES IS RETURNED UNTOUCHED, which is the assert that would catch a
# strip pattern widened by accident into the ordinary case.
foreach ($ok in @('main', 'fix/1623-ref-display-strip', 'feat/x_y.z-2', 'sync/live-2026-09-08-2')) {
    Assert-Equal $ok (Get-DisplayRef -Ref $ok) "an ordinary branch name is returned unchanged: '$ok'"
}

# THE REFUSAL NOTE READS THE SAME WAY FOR AN ALL-INVISIBLE NAME AS FOR NO NAME AT ALL. Before #1623 this
# produced a note saying "The branch is:" with blanks after it -- the "tells the reader nothing" failure
# the note's own comment warns about, arriving through the strip rather than through the empty case.
$invisible = Get-PasteableRef -Ref ([char]0x200B + [char]0x200D)
Assert-Equal '<branch>' $invisible.Token 'a name made entirely of format characters is not paste-safe either'
Assert-True ($invisible.Note -like '*could not read it*') 'and its note falls through to the empty wording rather than printing blanks'

# --- the seven call sites #1594 measured ----------------------------------------------------------
Write-Host ''
Write-Host 'The call sites -- the lib is unreachable if one still interpolates the raw ref' -ForegroundColor Cyan

$shipPath = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'
$syncPath = Join-Path $RepoRoot 'scripts\task\sync-main.ps1'
Assert-True (Test-Path -LiteralPath $shipPath) 'ship-pr.ps1 exists'
Assert-True (Test-Path -LiteralPath $syncPath) 'sync-main.ps1 exists'

$shipText = [System.IO.File]::ReadAllText($shipPath)
$syncText = [System.IO.File]::ReadAllText($syncPath)

Assert-True ($shipText -match [regex]::Escape("ref-print-lib.ps1")) 'ship-pr.ps1 dot-sources the lib'
Assert-True ($syncText -match [regex]::Escape("ref-print-lib.ps1")) 'sync-main.ps1 dot-sources the lib'
Assert-True ($shipText -match [regex]::Escape('$branchPaste = Get-PasteableRef -Ref $branch')) 'ship-pr.ps1 judges the ref once, beside the read that produced it'
Assert-True ($syncText -match [regex]::Escape('$branchPaste = Get-PasteableRef -Ref $branch')) 'sync-main.ps1 judges the ref once, beside the composition that produced it'

# Site by site, by the exact printed text -- five in ship-pr, two in sync-main.
foreach ($site in @(
    @{ Text = $shipText; Needle = '  git checkout $($branchPaste.Token)'; Label = 'ship-pr: the stale-CI remedy checkout' },
    @{ Text = $shipText; Needle = 'fold-changelog-entry.ps1 -Branch $($branchPaste.Token) -Commit -Push'; Label = 'ship-pr: the under-a-queue fold-by-hand line' },
    @{ Text = $shipText; Needle = '& "$foldScript" -Branch $($branchPaste.Token) -RepoRoot <that worktree> -Push'; Label = 'ship-pr: the fold-from-the-worktree-that-holds-main line' },
    @{ Text = $shipText; Needle = '& "$foldScript" -Branch $($branchPaste.Token) -Push'; Label = 'ship-pr: the fold-by-hand line after a failed worktree add' },
    @{ Text = $shipText; Needle = 'checkout $($branchPaste.Token)"'; Label = 'ship-pr: the "move this tree off main" warning' },
    @{ Text = $syncText; Needle = 'git push -u origin $($branchPaste.Token)'; Label = 'sync-main: the push-by-hand remedy' },
    @{ Text = $syncText; Needle = 'gh pr create --base $($trunkPaste.Token) --head $($branchPaste.Token)'; Label = 'sync-main: the gh pr create hand-over line, BOTH halves judged (#1627)' },
    @{ Text = $syncText; Needle = 'gh pr list --head $($sPaste.Token) --state open'; Label = 'sync-main: the per-predecessor pr list line (#1627)' }
)) {
    Assert-True ($site.Text.Contains($site.Needle)) "names the token, not the raw ref -- $($site.Label)"
}

# AND THE NOTE IS PRINTED AT EVERY ONE OF THEM. A placeholder with no explanation is worse than the
# original defect: the reader is handed a command that cannot work and told nothing about why.
Assert-True (([regex]::Matches($shipText, [regex]::Escape('$branchPaste.Note'))).Count -ge 3) 'ship-pr.ps1 prints the note at its Write-Host/Write-Warning sites'
Assert-True ($shipText -match [regex]::Escape('$branchPasteNoteBlock = if ($branchPaste.Note)')) 'ship-pr.ps1 defines the here-string note block once'
Assert-True (([regex]::Matches($shipText, [regex]::Escape('$branchPasteNoteBlock'))).Count -ge 4) 'and appends it to each of its three here-string remedies'
Assert-True (([regex]::Matches($syncText, [regex]::Escape('$branchPaste.Note'))).Count -ge 2) 'sync-main.ps1 prints the note at both of its sites'

# THE EIGHTH SITE, WHICH IS THE ONE THIS ASSERT EXISTS FOR. #1594 reported three of seven, so the guard
# against the next one is a scan rather than a list: no printed line in either script may put the raw
# $branch straight after a command word. Prose that merely QUOTES the name is a subject too since #1623 --
# it was scoped out here on the ground that git rejects the characters that make prose deceptive, and it
# rejects only half of them -- but it is a DIFFERENT subject with a different answer, so it has its own
# block below rather than being folded into this scan.
Write-Host ''
Write-Host 'No raw ref left in a printed command, in either script' -ForegroundColor Cyan

# AND THE TRUNK JOINED THE SCAN ON #1627, which is the same lesson a second time: #1594 reported three of
# seven sites and this scan exists because a list goes stale. It read for `$branch` only, so the raw
# `--base $trunk` sat beside a judged `--head` in ONE printed command and no assert saw it. `--head
# $($s.Branch)` is the other half of that blind spot -- a ref this script never composed.
$rawInCommand = @(
    'git checkout $branch',
    'git push -u origin $branch',
    '--head $branch',
    '--base $trunk',
    '--head $($s.Branch)',
    '-Branch $branch -Commit',
    '-Branch $branch -Push',
    '-Branch $branch -RepoRoot'
)
foreach ($raw in $rawInCommand) {
    Assert-True (-not $shipText.Contains($raw)) "ship-pr.ps1 no longer carries the raw interpolation: '$raw'"
    Assert-True (-not $syncText.Contains($raw)) "sync-main.ps1 no longer carries the raw interpolation: '$raw'"
}

# --- the prose sites (issue #1623) ----------------------------------------------------------------
# THE SAME STRUCTURAL ARGUMENT AS THE PASTE HALF: the function is correct and unreachable if a call site
# still interpolates the raw ref. And the same failure mode too -- #1594 reported three of seven sites and
# #1623 reported eighteen of the thirty-one these asserts now hold, so the guard is a scan and a
# judged-once assert rather than a list of sentences somebody has to keep current.
Write-Host ''
Write-Host 'The prose sites -- judged once, beside the read that produced the name' -ForegroundColor Cyan

Assert-True ($shipText -match [regex]::Escape('$branchShown = Get-DisplayRef -Ref $branch')) 'ship-pr.ps1 strips the branch once, beside the read that produced it'
Assert-True ($syncText -match [regex]::Escape('$branchShown = Get-DisplayRef -Ref $branch')) 'sync-main.ps1 strips the branch once, beside the composition that produced it'
Assert-True ($syncText -match [regex]::Escape('$trunkShown   = Get-DisplayRef -Ref $trunk')) 'sync-main.ps1 strips the trunk name too -- same seam, and it is printed in nine sentences'

# THE PASTE HALF OF THE SAME SEAM ANSWER (#1627). #1623 judged the trunk for prose and left it raw in the
# one printed COMMAND that carries it, saying so in its own comment -- so the two axes are asserted side
# by side here, on one value, which is the clearest place to see that a seam answer needs both.
Assert-True ($syncText -match [regex]::Escape("`$trunkPaste   = Get-PasteableRef -Ref `$trunk -Placeholder '<trunk>'")) 'sync-main.ps1 judges the trunk for the printed command too, beside the display copy'
Assert-True ($syncText -match [regex]::Escape('$trunkPaste.Note')) 'and prints the trunk note, so a refused base is explained rather than silently a placeholder'
Assert-True ($syncText -match [regex]::Escape("Placeholder '<trunk>'")) "the trunk gets its OWN placeholder -- one command can print two, and '<branch>' twice is unreadable"
Assert-True ($syncText -match [regex]::Escape('$sPaste = Get-PasteableRef -Ref ([string]$s.Branch)')) 'sync-main.ps1 judges each standing predecessor separately, since one line is printed per branch'
Assert-True ($syncText -match [regex]::Escape('$sPaste.Note')) 'and prints that note beneath its own line, so two unsafe predecessors stay tellable apart'

# NOT A SINGLE QUOTED RAW REF LEFT IN EITHER SCRIPT. Every prose site in both files wraps the name in
# single quotes or drops it bare into a sentence; the quoted form is the one a scan can hold without false
# positives, because `$branch` on its own is also every git and gh argument -- which must stay raw.
Assert-True (-not $shipText.Contains("'`$branch'")) 'ship-pr.ps1 carries no quoted raw $branch in a printed sentence'
Assert-True (-not $syncText.Contains("'`$branch'")) 'sync-main.ps1 carries no quoted raw $branch in a printed sentence'

# THE GO-AHEAD LINE IS THE ONE THAT MATTERS MOST (#1616), and it is composed in a lib, so ship-pr can only
# be asserted to hand it the stripped name -- worktree-lib's own suite asserts the strip itself.
Assert-True ($shipText -match [regex]::Escape('Get-TrunkReturnGoAheadLine -Returned $treeOnTrunk -Branch $branchShown')) 'ship-pr.ps1 hands the go-ahead line a stripped name'

# THE TWO BRANCH-DERIVED PATHS IN ship-pr's REFUSALS. Both are built from $branch, so both are prose
# carrying a ref name; the raw pair stays raw because one is a git ref and the other is a file this script
# actually opens.
Assert-True ($shipText -match [regex]::Escape('$shipCycleRefShown    = Get-DisplayRef -Ref $shipCycleRef')) 'ship-pr.ps1 strips the branch ref it prints in the step-list and DEPLOY refusals'
Assert-True ($shipText -match [regex]::Escape('$shipProgressRelShown = Get-DisplayRef -Ref $shipProgressRel')) 'ship-pr.ps1 strips the branch document path it prints beside it'

# AND THE MOST EXTERNALLY-AUTHORED NAME OF ALL: sync-main's standing-predecessor rows come off
# `git ls-remote`, so whoever pushed a branch matching the prefix chose the text printed there.
Assert-True ($syncText -match [regex]::Escape('$branchRow = Get-DisplayRef -Ref ([string]$r.Branch)')) 'sync-main.ps1 strips the ls-remote branch names in its predecessor rows'
Assert-True ($syncText -match [regex]::Escape('STILL STANDING: $(Get-DisplayRef -Ref ([string]$s.Branch))')) 'and the standing-branch line the operator reads first, which prints the same names'

# THE PATHS UNDER THAT ROW (#1629) -- the last of this script's path prints, after #1637/#1638 closed the
# other three lists and the paste-ready remedy. Get-DisplayPath rather than Get-DisplayRef, asserted by
# NAME: these rows are compared against live and typed back, so a collapsed or trimmed path names a
# different file, which is exactly why #1638 made them two functions.
Assert-True ($syncText -match [regex]::Escape('foreach ($p in $u) { Write-Host "      $(Get-DisplayPath -Path $p)"')) 'sync-main.ps1 strips the predecessor file paths it prints under that row'
Assert-True (-not $syncText.Contains('foreach ($p in $u) { Write-Host "      $p"')) 'and no longer carries the raw interpolation those paths used to be printed with'
Assert-True (-not ($syncText -match [regex]::Escape('foreach ($p in $u) { Write-Host "      $(Get-DisplayRef'))) 'and does NOT reach for the ref-shaped strip, which would collapse a path with a real space in it'

# EVERY DISPLAY VARIABLE IS ASSIGNED ABOVE ITS FIRST USE, and this assert exists because the branch that
# added them got it wrong. Both scripts run under `Set-StrictMode -Version Latest`, where reading an
# unassigned variable does not print an empty string -- it THROWS, and the run dies at whatever line it
# reached. sync-main's own suite caught it at 50 failed asserts; ship-pr.ps1 has no suite at all, so the
# same slip there would only surface in a live ship, mid-merge. A textual index comparison is enough:
# both are straight-line scripts, and the sites in question are top-level statements.
# READ LINE BY LINE, AND COMMENTS SKIPPED, because the obvious spelling does not work. Comparing
# IndexOf('$branchShown =') against IndexOf('$branchShown') finds the assignment first whenever the
# earlier USE has no space after the name -- which is exactly how it is spelled inside a string
# ("      $branchShown"), i.e. precisely the case this assert exists for. Verified against the broken
# ordering before it was repaired: the index spelling passed, this one fails.
function Get-FirstMentionLine {
    param([string]$Text, [string]$Var)
    $i = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $i++
        $t = $line.TrimStart()
        if ($t.StartsWith('#')) { continue }
        if ($line.Contains($Var)) { return [pscustomobject]@{ Number = $i; Text = $line } }
    }
    return $null
}

foreach ($v in @(
    @{ Text = $shipText; Var = '$branchShown';          Label = 'ship-pr: $branchShown' },
    @{ Text = $shipText; Var = '$shipCycleRefShown';    Label = 'ship-pr: $shipCycleRefShown' },
    @{ Text = $shipText; Var = '$shipProgressRelShown'; Label = 'ship-pr: $shipProgressRelShown' },
    @{ Text = $syncText; Var = '$branchShown';          Label = 'sync-main: $branchShown' },
    @{ Text = $syncText; Var = '$trunkShown';           Label = 'sync-main: $trunkShown' }
)) {
    $first = Get-FirstMentionLine -Text $v.Text -Var $v.Var
    Assert-True ($null -ne $first) "mentioned outside a comment at all -- $($v.Label)"
    if ($first) {
        Assert-True ($first.Text -match ([regex]::Escape($v.Var) + '\s*=\s*Get-DisplayRef')) `
            "the FIRST line naming it is its assignment, not a use -- strict mode makes the other order fatal rather than empty, line $($first.Number) -- $($v.Label)"
    }
}

# --- the mirrors carry it too --------------------------------------------------------------------
# A CONSUMER RUNS THE MIRROR, so a repair present only in the root copy is a repair no consumer has. The
# drift lint proves the copies match; these asserts prove the lib was REGISTERED in the first place,
# which is the failure the drift lint cannot see.
Write-Host ''
Write-Host 'The mirrors' -ForegroundColor Cyan

foreach ($m in @(
    @{ Path = 'plugins\dkj-policy\scripts\lib\ref-print-lib.ps1';      Label = 'dkj-policy (ship-pr)' },
    @{ Path = 'plugins\dkj-subagents\dkj-subagents-shopify\scripts\lib\ref-print-lib.ps1'; Label = 'dkj-subagents-shopify (sync-main)' }
)) {
    $full = Join-Path $RepoRoot $m.Path
    Assert-True (Test-Path -LiteralPath $full) "the lib is mirrored into $($m.Label)"
    if (Test-Path -LiteralPath $full) {
        $mirrorText = [System.IO.File]::ReadAllText($full)
        Assert-True ($mirrorText -match 'function Get-PasteableRef') "...and that mirror carries the paste verdict: $($m.Label)"
        Assert-True ($mirrorText -match 'function Get-DisplayRef') "...and the prose strip as well, which two other libs now dot-source: $($m.Label)"
        Assert-True ($mirrorText -match 'function Get-DisplayPath') "...and the path strip (#1638), which the paste verdict itself calls under -Kind Path: $($m.Label)"
        Assert-True ($mirrorText -match 'function ConvertTo-ConsoleStrippedText') "...and the code-point walk both strips share (#2024): $($m.Label)"
    }
}

# --- the PATH axis: Get-DisplayPath (issue #1638) -------------------------------------------------
# THE SAME WALL, ONE CLASS FURTHER OUT. These paths come from this repo's own HEAD (`git ls-tree`, then
# Convert-GitQuotedPath) and from a filesystem walk of the pulled LIVE theme, which third parties edit
# through the Shopify theme editor. git's incidental quoting is no help: measured in #1637, `ls-tree` and
# `diff --name-only` return shell metacharacters unquoted in every core.quotePath setting, because git
# quotes control characters and high bytes -- not this class.
Write-Host ''
Write-Host 'Get-DisplayPath -- the prose strip for a file path' -ForegroundColor Cyan

foreach ($cp in @(0x202E, 0x200D, 0x200B, 0x2066, 0x1B, 0x0D, 0x07, 0x00, 0x2028, 0x2029, 0x0301, 0x00AD)) {
    $path = 'assets/a' + [char]$cp + 'b.js'
    Assert-Equal 'assets/a b.js' (Get-DisplayPath -Path $path) "stripped to a visible space: U+$('{0:X4}' -f $cp)"
}

# ISSUE #2024'S SECOND HALF. A format character above the BMP is a surrogate PAIR, invisible to a regex
# [\p{Cf}] class outright -- this strip catches it, one space per UTF-16 unit consumed, which is what
# keeps a padded column's alignment (#1638) exact even for a two-unit code point.
$pathTagBlock = 'assets/a' + [char]::ConvertFromUtf32(0xE0074) + 'b.js'
Assert-Equal 'assets/a  b.js' (Get-DisplayPath -Path $pathTagBlock) 'the TAG block (a surrogate pair) becomes two spaces, not zero'
Assert-Equal $pathTagBlock.Length (Get-DisplayPath -Path $pathTagBlock).Length 'and the length is preserved exactly, same as for a one-unit character'

# THE THREE PROPERTIES THAT MAKE THIS A SECOND FUNCTION RATHER THAN A CALL TO Get-DisplayRef. Each one is
# a case where the ref strip is right for a ref and wrong for a path, so each is asserted against the ref
# strip's own answer -- if the two are ever collapsed into one function, these go red and say why.
$runPath = 'assets/a' + [char]0x200B + [char]0x200B + [char]0x202E + 'b.js'
Assert-Equal 'assets/a   b.js' (Get-DisplayPath -Path $runPath) 'a run is NOT collapsed: one space per removed character, so format width and display width agree again'
Assert-Equal 'assets/a b.js'   (Get-DisplayRef  -Ref  $runPath) '...where the ref strip collapses it, which is what would misalign a padded column'
Assert-Equal $runPath.Length   (Get-DisplayPath -Path $runPath).Length 'and the length is preserved exactly -- the alignment argument, asserted as the property it is'

Assert-Equal 'assets/a  b.js' (Get-DisplayPath -Path 'assets/a  b.js') 'a genuinely doubled space in a path survives'
Assert-Equal 'assets/my file.js' (Get-DisplayPath -Path 'assets/my file.js') 'and a single genuine space does too -- git and NTFS both allow one, where a ref may not'
Assert-Equal ' assets/a.js ' (Get-DisplayPath -Path ' assets/a.js ') 'the ends are NOT trimmed: a leading or trailing space is part of the path a reader has to type back'
Assert-Equal 'assets/a.js' (Get-DisplayRef -Ref ' assets/a.js ') '...where the ref strip trims, which would aim that reader at a different file'

# THE ALL-INVISIBLE PATH IS NAMED RATHER THAN BLANKED, which is the one place this function must NOT copy
# Get-DisplayRef's answer: '' is wording its callers already have ("on its branch"), and a row in a padded
# table has none -- it would print as an empty column, a row whose path is silently not there.
Assert-Equal '(no printable path)' (Get-DisplayPath -Path ([char]0x200B + [char]0x200D + [char]0x2066)) 'a path made entirely of format characters says so instead of coming back as blanks'
Assert-Equal '' (Get-DisplayRef -Ref ([char]0x200B + [char]0x200D + [char]0x2066)) '...where the ref strip answers the same input with the empty string, deliberately'
Assert-Equal '' (Get-DisplayPath -Path '') 'the empty path stays empty'
Assert-Equal '' (Get-DisplayPath -Path $null) 'a null path is the empty path'

# AND AN ORDINARY THEME PATH IS RETURNED UNTOUCHED -- the assert that catches a strip pattern widened by
# accident into the case every real run takes.
foreach ($ok in @('assets/theme.js', 'sections/main-product.liquid', 'locales/en.default.json', 'templates/customers/login.liquid', 'config/settings_schema.json')) {
    Assert-Equal $ok (Get-DisplayPath -Path $ok) "an ordinary theme path is returned unchanged: '$ok'"
}

# --- the PASTE axis for a path: Get-PasteableRef -Kind Path (issue #1637) --------------------------
Write-Host ''
Write-Host 'Get-PasteableRef -Kind Path -- a path-shaped allowlist and a path-shaped refusal' -ForegroundColor Cyan

# A REPO-RELATIVE THEME PATH STILL NEEDS NO WIDENING -- it passed the ref pattern and passes the path one
# unchanged, and the fold is a no-op on it (there is no backslash). This is the case every -Kind Path
# caller took before #1762, asserted so a pattern change cannot regress it.
foreach ($ok in @('assets/theme.js', 'sections/main-product.liquid', 'locales/en.default.json', 'config/settings_schema.json')) {
    $v = Get-PasteableRef -Ref $ok -Placeholder '<path>' -Kind Path
    Assert-True $v.IsSafe "an ordinary theme path passes: '$ok'"
    Assert-Equal $ok $v.Token '...and is carried into the command as itself'
    Assert-Equal '' $v.Note '...with no note, because there is nothing to explain'
}

# THE THREE PATHS MEASURED THROUGH git mktree IN #1637, plus the classes around them.
foreach ($bad in @('assets/x$(id -un).js', 'assets/y`id -un`.js', 'assets/z;touch owned.js', 'assets/a&b.js', 'assets/a|b.js', "assets/it's-fine.js", 'assets/a b.js', '-assets/leading-dash.js')) {
    $v = Get-PasteableRef -Ref $bad -Placeholder '<path>' -Kind Path
    Assert-True (-not $v.IsSafe) "refused on the paste axis: '$bad'"
    Assert-Equal '<path>' $v.Token "...and the placeholder is what reaches the command: '$bad'"
    Assert-True ($v.Note.Contains($bad)) "...while the note names the real path, so the reader can still act: '$bad'"
    Assert-True ($v.Note.Contains('1594')) "...and cites the issue: '$bad'"
}

# THE NOUN IS THE POINT OF -Kind, so it is asserted in both directions: a note about a path that says
# "branch name" sends the reader looking for the wrong kind of thing, and the default must not have moved.
$pathNote = (Get-PasteableRef -Ref 'assets/z;touch owned.js' -Placeholder '<path>' -Kind Path).Note
Assert-True ($pathNote -like '*the file path is not safe to paste*') 'the refusal speaks in the path noun'
Assert-True ($pathNote -like '*The file path is:*')                  '...and names it in the same noun'
Assert-True ($pathNote -notlike '*branch*')                          '...with no mention of a branch anywhere in it'

$refNote = (Get-PasteableRef -Ref 'fix/evil;touch').Note
Assert-True ($refNote -like '*the branch name is not safe to paste*') 'and the default is still the branch noun'
Assert-True ($refNote -like '*The branch name is:*')                  '...in both sentences'

# THE NOTE USES THE PATH STRIP, NOT THE REF STRIP. This is the one consequence of -Kind that a reader
# could not see from the noun: the note is the ONLY place the real path is printed, and the reader is being
# told to compose the command themselves from it, so a collapsed or trimmed path aims them at a different
# file than the one that conflicted.
$spacey = 'assets/a  b;touch.js'
Assert-True ((Get-PasteableRef -Ref $spacey -Placeholder '<path>' -Kind Path).Note.Contains($spacey)) 'the note carries the doubled space through verbatim'
Assert-True (-not ((Get-PasteableRef -Ref $spacey).Note.Contains($spacey))) '...where the ref default would have collapsed it, which is why -Kind selects the strip too'

# AND THE REFUSAL PATH IS STILL NOT AN INJECTION SURFACE at the new axis -- the same property #1439 and
# #1446 bought, asserted for a path rather than a ref.
foreach ($esc in @("assets/a$([char]0x1B)[31mb.js", "assets/a$([char]0x202E)b.js", "assets/a$([char]0x07)b.js")) {
    $n = (Get-PasteableRef -Ref $esc -Placeholder '<path>' -Kind Path).Note
    Assert-True ([bool]$n) 'a control-character path still carries a note'
    $body = $n -replace "`r", '' -replace "`n", ''
    Assert-True ($body -notmatch '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]') 'and no control, format, line/paragraph separator or combining-mark character from the path survives into it'
}

# THE ALL-INVISIBLE PATH DOES NOT FALL THROUGH TO THE BRANCH WORDING, which is the seam between the two
# strips showing up in the note: Get-DisplayPath does not trim, so this never arrives as '' and is named.
$invisiblePath = Get-PasteableRef -Ref ([char]0x200B + [char]0x200D) -Placeholder '<path>' -Kind Path
Assert-Equal '<path>' $invisiblePath.Token 'a path made entirely of format characters is not paste-safe either'
Assert-True ($invisiblePath.Note -like '*(no printable path)*') 'and its note names that state rather than reading "could not read it"'

# --- the absolute path: -Kind Path admits `:` and folds `\` (issue #1762) -------------------------
Write-Host ''
Write-Host 'Get-PasteableRef -Kind Path -- an absolute path can now pass (#1762)' -ForegroundColor Cyan

# THE CASE THE FUNCTION WAS ADDED FOR AND COULD NOT DO: an absolute path. A lane, a worktree and a
# scratch tree are always absolute; the ref pattern has neither `:` nor `\`, so every one of these was
# refused before #1762.
$lane = 'C:\Users\davek\GitHub\claude-code-specialists-lanes\fix--branch-doc-per-branch-path-v1'
$v = Get-PasteableRef -Ref $lane -Placeholder '<path>' -Kind Path
Assert-True $v.IsSafe 'an absolute Windows lane path is paste-safe'
Assert-Equal 'C:/Users/davek/GitHub/claude-code-specialists-lanes/fix--branch-doc-per-branch-path-v1' $v.Token '...carried in its slash-folded form -- the one spelling correct in bash, PowerShell and cmd'
Assert-Equal '' $v.Note '...with no note'

# ALREADY-FORWARD-SLASH, POSIX ROOT, AND A UNC PATH: the three other absolute shapes, all safe.
Assert-True (Get-PasteableRef -Ref 'C:/Users/davek/lanes/x' -Kind Path).IsSafe 'an absolute path that already uses forward slashes passes'
Assert-Equal 'C:/Users/davek/lanes/x' (Get-PasteableRef -Ref 'C:/Users/davek/lanes/x' -Kind Path).Token '...unchanged, because the fold is a no-op on it'
Assert-True (Get-PasteableRef -Ref '/home/dave/worktrees/fix-x' -Kind Path).IsSafe 'a POSIX absolute path passes on its leading /'
Assert-Equal '//server/share/lanes/x' (Get-PasteableRef -Ref '\\server\share\lanes\x' -Kind Path).Token 'a UNC path folds to a doubled leading slash and passes'

# THE FOLD DOES NOT RESCUE A DANGEROUS CHARACTER. Everything the ref pattern refuses, the path pattern
# refuses too -- the two new characters are the only difference.
#
# AND THE SPACE IN THIS LIST IS THE ONE TO READ TWICE (#1768). It looks like the pattern's weakest
# point -- 'C:\Program Files\...' is an ordinary Windows location, and #1768 proposed admitting a space
# if the allowlist won the path axis. It must not be admitted, and the reason is not about hostility:
# the .Token is printed UNQUOTED, on purpose, because this lib's header rejects quoting as the guard.
# `git worktree remove C:/Program Files/x` therefore splits into two arguments in bash, PowerShell and
# cmd alike. A space is the one character an allowlist over an unquoted token can never admit, whatever
# the destination shell turns out to be -- so the placeholder plus the note is the correct answer here,
# not a gap in it. The alternative that quoted instead of judging was retired by #1768 for being exact
# in PowerShell and silently wrong in Git Bash.
foreach ($bad in @('C:\a\b$(id -un).js', 'C:\Program Files\a b\x', "C:\a\it's.js", 'C:\a\b;touch.js', 'C:\a\b`id`.js')) {
    $r = Get-PasteableRef -Ref $bad -Placeholder '<path>' -Kind Path
    Assert-True (-not $r.IsSafe) "an absolute path carrying a shell metacharacter or space is still refused: '$bad'"
    Assert-Equal '<path>' $r.Token "...and the placeholder reaches the command: '$bad'"
    Assert-True ($r.Note.Contains($bad)) "...while the note shows the path the reader actually has, backslashes and all: '$bad'"
}

# THE REF AXIS IS UNTOUCHED -- #1594 and #1617 narrowed it on purpose, and neither new character leaks
# across. This is the whole reason the path pattern is its own and the shared one was not widened.
Assert-True (-not (Get-PasteableRef -Ref 'fix/a:b').IsSafe)  'a ref carrying `:` is still refused on the default axis'
Assert-True (-not (Get-PasteableRef -Ref 'fix/a\b').IsSafe)  'a ref carrying `\` is still refused on the default axis'
Assert-Equal '<branch>' (Get-PasteableRef -Ref 'fix/a\b').Token '...and the branch placeholder is what reaches the command'

# ConvertTo-PastePath and Test-PathPasteSafe on their own.
Assert-Equal 'a/b/c'   (ConvertTo-PastePath -Path 'a\b\c')  'ConvertTo-PastePath folds every backslash'
Assert-Equal 'a/b/c'   (ConvertTo-PastePath -Path 'a/b/c')  '...and leaves forward slashes alone'
Assert-Equal ''        (ConvertTo-PastePath -Path '')       'an empty path folds to empty'
Assert-Equal ''        (ConvertTo-PastePath -Path $null)    'a null path is the empty path'
Assert-True  (Test-PathPasteSafe -Path 'C:\Users\davek\lanes\x') 'Test-PathPasteSafe accepts an absolute Windows path'
Assert-True  (-not (Test-PathPasteSafe -Path 'C:\Users\Ada Lovelace\x')) '...and refuses one with a space in it'
Assert-True  (-not (Test-PathPasteSafe -Path '')) 'an empty path is not paste-safe'
Assert-True  (-not (Test-PathPasteSafe -Path $null)) 'a null path is not paste-safe'

# --- the four sync-main sites the two issues measured ---------------------------------------------
Write-Host ''
Write-Host 'The path call sites in sync-main.ps1' -ForegroundColor Cyan

# THE THREE PADDED LISTINGS (#1638). Asserted as a count rather than one by one: they are the same line
# three times, and what must hold is that none of the three was left behind.
Assert-Equal 3 ([regex]::Matches($syncText, [regex]::Escape('(Get-DisplayPath -Path $r.Path)')).Count) 'all three of the take / hold-back / conflict listings go through the path strip'
Assert-True (-not $syncText.Contains('-f $r.Status, $r.Path,')) 'and none of them still formats the raw path into the padded column'

# THE CONFLICT REMEDY (#1637). One judgement per row, both operands answered from it.
Assert-True ($syncText.Contains("`$pathPaste = Get-PasteableRef -Ref `$r.Path -Placeholder '<path>' -Kind Path")) 'the conflict remedy judges the path once, on the paste axis'
Assert-True ($syncText.Contains('git diff --no-index -- $($pathPaste.Token)')) '...and the printed command carries the token, never the raw path'
Assert-True ($syncText.Contains('$pathPaste.Note')) '...and prints the note, so a refused row explains its own placeholder'
Assert-True ($syncText.Contains('Join-Path $mirror $pathPaste.Token')) '...with the mirror operand answered from the SAME verdict, so the two holes are visibly one substitution'

# THE SPELLING THIS ISSUE WAS ABOUT, ASSERTED ABSENT. The old line double-quoted both operands, which is
# the exact repair ref-print-lib's own header was written to reject: substitution runs inside double
# quotes in bash and PowerShell alike, so it read as a guard while closing nothing -- worse than a bare
# interpolation, because the next reader sees quotes and stops looking.
Assert-True (-not $syncText.Contains('--no-index -- `"$($r.Path)`"')) 'the double-quoted raw path is gone from the conflict remedy'

# --- the creation-side half ----------------------------------------------------------------------
# THE OTHER HALF OF #1594, and it is asserted here rather than only in branch-info.tests.ps1 because the
# two halves are one decision: neither closes the hole alone, and a later reader removing one should see
# the other fail.
Write-Host ''
Write-Host 'Test-BranchName holds the same allowlist (the creation-side half)' -ForegroundColor Cyan

. (Join-Path $RepoRoot 'scripts\lib\branch-info.ps1')
foreach ($bad in @('fix/evil;touch', 'fix/evil$(touch)', "fix/it's-fine", 'fix/a b', '-fix/leading-dash')) {
    $r = Test-BranchName -Branch $bad
    Assert-True (-not $r.IsValid) "Test-BranchName refuses '$bad'"
    Assert-True ($r.Reason -like '*1594*') "...and its reason cites the issue: '$bad'"
}
foreach ($ok in @('fix/1594-printed-command-ref-safety', 'feat/a_b.c-d/e')) {
    Assert-True ((Test-BranchName -Branch $ok).IsValid) "Test-BranchName still accepts '$ok'"
}

# --- the three states, DRIVEN rather than argued (issue #2107) ------------------------------------
# THE REPAIR IS ONLY WORTH HAVING IF THE UNMEASURED PATH REALLY FIRES, and nothing above can prove
# that: the whole point is that the state appears once in roughly 300 fresh Start-Process children
# under load, so a suite that waited for it would never see it. So the capture is substituted and all
# three states are driven through the same helper the eight call sites use.
#
# WHY IT IS SUBSTITUTED HERE AND NOT MOCKED IN THE LIB: Test-GitAcceptsRef calls Invoke-NativeCapture
# by name, so shadowing that name in this scope is the smallest thing that reaches it, and it is put
# back immediately afterwards -- the asserts after this block still ask the real git.
Write-Host ''
Write-Host 'The three states of the premise helper -- driven (#2107)' -ForegroundColor Cyan

$realCapture = ${function:Invoke-NativeCapture}
$script:fakeCapture = $null
${function:Invoke-NativeCapture} = { param($FilePath, $Arguments, [switch]$DiscardStderr, [switch]$Utf8) return $script:fakeCapture }

# 1. An ordinary acceptance still reads as one.
$script:fakeCapture = [pscustomobject]@{ Output = @('x'); ExitCode = 0; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $false }
Assert-Equal $true (Test-GitAcceptsRef -Ref 'whatever') 'driven: exit 0 with a measured code is still an acceptance'

# 2. And an ordinary refusal still reads as one -- the negative direction the helper had to keep.
$script:fakeCapture = [pscustomobject]@{ Output = @(); ExitCode = 1; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $false }
Assert-Equal $false (Test-GitAcceptsRef -Ref 'whatever') 'driven: a non-zero measured code is still a refusal'

# 3. THE CASE THIS ISSUE IS ABOUT. ExitCodeUnknown set, ExitCode $null -- the shape #1931 documents.
$before = $script:unmeasured
$script:fakeCapture = [pscustomobject]@{ Output = @(); ExitCode = $null; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $true }
Assert-True ($null -eq (Test-GitAcceptsRef -Ref 'whatever')) 'driven: an unmeasured exit code is $null, NOT a refusal'

# ...and the helper reports it in BOTH directions without touching pass or fail. The negative case is
# the one that used to pass silently, so it is asserted first.
$failBefore = $script:fail
$passBefore = $script:pass
Assert-GitRefPremise -Ref 'whatever' -Expect $false -Label 'driven: negative premise, unmeasured'
Assert-GitRefPremise -Ref 'whatever' -Expect $true  -Label 'driven: positive premise, unmeasured'
${function:Invoke-NativeCapture} = $realCapture

# THE THREE COUNTERS ARE SNAPSHOTTED BEFORE ANY OF THEM IS ASSERTED ON. Assert-Equal increments
# $script:pass itself, so asserting the counters one after another reads a value the previous assert
# has already moved -- which is how the first draft of this block failed, expecting 464 and getting
# 466. Read all three, then judge all three.
$unmeasuredAfter = $script:unmeasured
$failAfter = $script:fail
$passAfter = $script:pass

Assert-Equal ($before + 2) $unmeasuredAfter 'driven: both unmeasured premises were COUNTED'
Assert-Equal $failBefore $failAfter 'driven: ...and neither was counted as a failure -- the red this issue was filed on'
Assert-Equal $passBefore $passAfter 'driven: ...nor as a pass -- which is how the negative direction used to go green on nothing'

# AND THE FIXTURE'S OWN TWO ARE GIVEN BACK, which is the whole reason the counter is snapshotted above
# rather than simply read at the end. These two were manufactured by substituting the capture, so
# leaving them in would print the footer's warning on every healthy run -- and a warning that is always
# there is exactly how a REAL unmeasured premise would go unnoticed. The counter must mean "git could
# not be asked about something this suite actually wanted to know".
$script:unmeasured = $before

# A capture that predates the field must not throw -- the Set-StrictMode idiom, asserted rather than
# trusted, because the probe is the kind of line a later edit simplifies away.
${function:Invoke-NativeCapture} = { param($FilePath, $Arguments, [switch]$DiscardStderr, [switch]$Utf8) return [pscustomobject]@{ Output = @('x'); ExitCode = 0; TimedOut = $false } }
Assert-Equal $true (Test-GitAcceptsRef -Ref 'whatever') 'driven: a capture with no ExitCodeUnknown property is read, not thrown on'
${function:Invoke-NativeCapture} = $realCapture

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
# THE UNMEASURED COUNT IS PRINTED, NEVER FOLDED INTO EITHER FIGURE ABOVE (issue #2107) -- and it does
# NOT fail the run. The premise could not be established, which is not the same as the premise being
# false, and a suite that exits 1 on it would hand back exactly the wrong diagnosis: a reader goes
# looking for a regression in ref-print-lib and finds nothing wrong there. Silence would be worse
# still, so it is named, counted, and visible on the line a reader actually reads.
if ($script:unmeasured -gt 0) {
    Write-Host "         $script:unmeasured premise(s) UNMEASURED -- git's exit code was not readable on this run (#1931); those cases proved nothing either way." -ForegroundColor Yellow
}
if ($script:fail -gt 0) { exit 1 }
exit 0
