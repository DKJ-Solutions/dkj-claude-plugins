<#
.SYNOPSIS
    Judging a test fixture's own ACTING SCRIPT invocation -- the runtime sibling of fixture-git-lib.ps1,
    dot-sourced by the suites under scripts/tests/ (issue #1934).

.DESCRIPTION
    Dot-source this file from a suite:

        . (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')

    WHY THIS EXISTS. A suite here copies an acting script into a fixture tree and runs it in a child
    process. Since #1917 those scripts dot-source check-report-lib.ps1 UNGUARDED, so a fixture that does
    not carry a lib the script loads kills the child during LOAD -- before it writes anything at all. What
    the suite then reports is the absence of the document the script was supposed to write:

        Kan een gedeelte van het pad ...\dkj-policy\feat-my-task-v1.md niet vinden

    Nothing in that names the absent lib, the dot-source, or load failure at all. Measured on the #1917
    branch (#1924), where six suites failed this way: fold-changelog 155 asserts red, prune-merged 73,
    park-branch 18, and new-branch, worktree-lane and entry-scaffold dead on load.

    AND THE MEASUREMENT THAT DECIDED THE SHAPE IS THAT THE DIAGNOSIS WAS ALREADY THERE. #1934 proposed
    two repairs -- a fixture builder probing its own copy list, or the suite re-running the script with
    output captured -- and neither is needed, because both rest on a premise that does not hold.
    Reproduced September 13, 2026 on a scratch fixture holding fold-changelog-entry.ps1 without
    check-report-lib.ps1, invoked exactly as Invoke-Fold invokes it:

        '...\..\lib\check-report-lib.ps1' is not recognized as the name of a cmdlet, function,
        script file, or operable program.
        At ...\fold-changelog-entry.ps1:204 char:3
        + . (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

    The absent lib, the dot-source and the exact line are all in there, the child exits 1, and FIVE of the
    six suites ALREADY capture both -- fold-changelog, prune-merged, park-branch and worktree-lane with
    2>&1 into a variable, new-branch with Start-Process redirect files. They simply never look. So
    nothing has to be probed and nothing has to be re-run: what was missing is a reader. That is cheaper
    than either filed candidate, and it does not reintroduce the hand-listed copy list that #1693 and
    #1924 both exist because nobody maintains.

    THE SIXTH IS THE EXCEPTION, AND IT IS THE ONE WITH THE SCAR. entry-scaffold.tests.ps1 invokes its
    child as `... 2>$null | Out-Null` at two call sites and reads only $LASTEXITCODE -- so there the
    diagnosis really is destroyed rather than merely ignored. Its own comment at that spot already
    records this exact class from the other side (inbound #1046: that fixture was missing
    native-capture-lib.ps1, new-branch dot-sourced it unconditionally, and the resulting exit 1 went
    unnoticed for two weeks). Capturing instead of discarding is one line there, and still not a re-run.

    THE SIGNATURE IS THE ERROR ID, NEVER THE ENGLISH PROSE. 'is not recognized as the name of a cmdlet'
    is localized -- the symptom #1934 quotes is Dutch, off the same class -- so keying on it would give a
    reader on a localized Windows exactly the silence this lib exists to remove. FullyQualifiedErrorId
    values are not localized, so CommandNotFoundException is what is matched.

    SILENT ON AN EXPECTED REFUSAL, WHICH IS WHAT MAKES IT SAFE TO CALL EVERYWHERE. Many cases in this
    directory assert a NON-ZERO exit on purpose -- a refusal is the behaviour under test. A refusal
    carries 'REFUSED' and no CommandNotFoundException, so it is not a subject here. A load failure is
    never an expected refusal: it means the FIXTURE is broken, not that the script declined. That
    distinction is why this can be wired into an invocation helper that serves both kinds of case
    without any call site having to say which kind it is.

    IT COUNTS AND PRINTS; IT DOES NOT THROW. Same reasoning as fixture-git-lib: a suite that dies at the
    first hiccup reports less than one that runs on and names what broke. Write-FixtureScriptSummary at
    the foot of a suite turns the count into an exit code, including on a run where every assert passed
    -- a load failure the asserts happened not to notice is still a run that proved nothing.

    THE STATE LIVES IN THE CALLING SUITE'S SCRIPT SCOPE, which is what dot-sourcing means. Each suite is
    its own process under the gate, so there is nothing to share and nothing to reset between suites.

    Workshop-only -- scripts/tests/ is not mirrored into any plugin, so this lib is not registered in
    shared-scripts-lib.ps1 and has no mirror to drift from.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# EVERY FIXTURE CHILD THAT DIED ON LOAD in the suite that dot-sourced this file. Initialized here rather
# than in each suite, so a suite cannot adopt the helper and forget the counter it reads.
$script:FixtureScriptLoadFailures = 0

# The one locale-independent marker of the class. PowerShell localizes an error's MESSAGE and never its
# FullyQualifiedErrorId, and a dot-source of a path that is not there raises exactly this id.
$script:FixtureScriptLoadErrorId = 'CommandNotFoundException'

# A '<name>.ps1' THAT IS PRECEDED BY A PATH SEPARATOR OR A QUOTE, which is what tells a real reference
# from a fragment. Deliberately a LEAF rather than a whole path: a CategoryInfo line truncates a long
# target in the middle, so the full path is not reliably readable out of the output while the leaf is.
#
# THE PRECEDING CHARACTER IS THE WHOLE GUARD, and it is there because the child's host WRAPS. The error
# text arrives already rendered by the child at ITS console width, with a hard break wherever the line
# ran out -- measured here, '...\scripts\task\pretend-acting.ps1' broke after 'preten' and the next line
# began 'd-acting.ps1'. Out-String -Width in this process cannot undo a wrap that was baked in upstream,
# so the fragment has to be told apart by SHAPE: a genuine reference in one of these messages always sits
# behind a '\', a '/' or a quote, and a wrap-orphan sits at the start of a line. The cost is that a wrap
# landing exactly on a separator makes this find nothing -- which is the right way to be wrong, because
# the full captured output is printed underneath regardless, and a headline naming a file that does not
# exist is #1936's defect one layer over.
$script:FixtureScriptPs1Leaf = '[\\/''"]([A-Za-z0-9_.-]+\.ps1)'

function Get-FixtureScriptLoadFailure {
    <#
        Did this child die on LOAD, and if so which .ps1 did it fail to find?

        Returns $null when the output carries no load-failure signature -- which covers a clean run, an
        ordinary refusal, and any other non-zero exit. Otherwise a small object naming the leaves the
        child could not load, so the caller can print one headline instead of asking a reader to find
        the cause in a stack trace.

        -Script is the script under test. Its own leaf is subtracted from the answer: the failing
        dot-source is reported against the file that CONTAINS it, so that name is in the output too, and
        naming it as the missing dependency would send the reader to the one file that is present.
    #>
    param(
        [string]$Output = '',
        [string]$Script = ''
    )
    # -Width 4096 IS LOAD-BEARING, NOT TIDINESS. Out-String renders at the host's line width and WRAPS,
    # and a wrapped line breaks in the middle of the path this function is about to read: measured here,
    # '...\scripts\task\pretend-acting.ps1' wrapped after 'preten' and the next line began 'd-acting.ps1',
    # which the leaf pattern then matched as a file. A headline naming a file that does not exist is the
    # same defect as #1936's refusal naming a flag that does not exist -- so the wrap is removed at the
    # source rather than filtered afterwards.
    $text = ($Output | Out-String -Width 4096)
    if ($text -notmatch [regex]::Escape($script:FixtureScriptLoadErrorId)) { return $null }

    $ownLeaf = ''
    if ($Script) { $ownLeaf = Split-Path -Leaf $Script }

    $leaves = @()
    foreach ($m in [regex]::Matches($text, $script:FixtureScriptPs1Leaf)) {
        $leaf = $m.Groups[1].Value
        if ($ownLeaf -and $leaf -eq $ownLeaf) { continue }
        # A LEADING DOT IS POWERSHELL'S OWN ELLIPSIS, never a filename. The CategoryInfo line truncates a
        # long target in the middle -- '(C:\Users\maike\...-helper-lib.ps1:String)' -- and the tail of that
        # matches the leaf pattern cleanly. Reported, it sends a reader looking for a file nobody named.
        if ($leaf -like '.*') { continue }
        if ($leaves -notcontains $leaf) { $leaves += $leaf }
    }
    return [pscustomobject]@{
        MissingLeaves = $leaves
        Text          = $text
    }
}

function Assert-FixtureScriptLoaded {
    <#
        Judge ONE fixture child-script invocation: if it died during LOAD, say so, name the .ps1 it could
        not find, print what the child actually said, and count it. Silent and free on every other path,
        including a deliberate refusal.

        The caller keeps its own signature and its own EAP handling -- this function is only the verdict,
        exactly as Assert-FixtureGitOk is for git, because the suites here invoke their child in several
        different shapes and rewriting every call site was never the point.

        -Code is the child's exit code and -Output its combined output, captured by the caller with 2>&1.
        Both are needed: the id is in the output, and the exit code is what says the child did not merely
        MENTION the class while running normally.

        -Code IS DELIBERATELY UNTYPED, where Assert-FixtureGitOk's is [int]. Its callers pass
        $LASTEXITCODE, which is always a number; one of this lib's callers passes $proc.ExitCode from
        Start-Process -PassThru, which comes back ABSENT often enough to have its own measurement
        (#1920: 27 of 960 captures at 16 lanes). Typed [int], that $null would arrive as 0 and this
        function would return early -- reporting nothing precisely where the run is already strange.
        Untyped, $null is not 0, so an unknown exit code still gets read for the signature.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Code,
        [string]$Script = '',
        $Output = $null
    )
    if ($Code -eq 0) { return }
    if ($null -eq $Output) { return }

    $found = Get-FixtureScriptLoadFailure -Output $Output -Script $Script
    if ($null -eq $found) { return }

    $script:FixtureScriptLoadFailures++
    $who = $(if ($Script) { Split-Path -Leaf $Script } else { 'the fixture script' })

    # TWO HEADLINES, BECAUSE THE SIGNATURE IS BROADER THAN THE DIAGNOSIS. CommandNotFoundException says
    # PowerShell could not resolve SOME command name. With a .ps1 behind it that is this issue's class --
    # an unguarded dot-source of a lib the fixture does not carry, which kills the child during load. With
    # NO .ps1 behind it, the likeliest cause is a mistyped cmdlet or function INSIDE the acting script,
    # which can be raised long after load and is a bug in that script rather than a gap in the copy list.
    # Claiming 'never ran' there would be false, and pointing at the copy list would send the reader to
    # repair the one thing that is not broken -- #1936's defect, one layer over. Caught in review.
    if ($found.MissingLeaves.Count -gt 0) {
        Write-Host "  [FIXTURE SCRIPT DIED ON LOAD] exit $Code -- $who never ran" -ForegroundColor Magenta
        Write-Host "      it could not load: $($found.MissingLeaves -join ', ')" -ForegroundColor Magenta
        Write-Host "      the fixture does not carry that file -- add it to this suite's copy list" -ForegroundColor Magenta
    } else {
        Write-Host "  [FIXTURE SCRIPT: UNRESOLVED COMMAND] exit $Code -- $who could not resolve a command name" -ForegroundColor Magenta
        Write-Host "      no .ps1 is named, so this is probably NOT a missing fixture lib -- read the text below" -ForegroundColor Magenta
    }
    foreach ($line in ($found.Text -split "`r?`n")) {
        if ("$line".Trim()) { Write-Host "      $line" -ForegroundColor Magenta }
    }
}

function Get-FixtureScriptLoadFailureCount {
    <# How many fixture children died on load so far. For a suite that wants to say so mid-run, and for
       this lib's own tests. #>
    return $script:FixtureScriptLoadFailures
}

function Write-FixtureScriptSummary {
    <#
        Print the broken-fixture block if any child died on load, and return $true when one did -- which
        the caller turns into an exit code.

        WHY EVEN ON A GREEN RUN. A child that never ran wrote nothing, so every assert reading what it
        should have written is measuring the fixture rather than the script. Where those asserts happen
        to pass anyway -- because the case only checks that something is ABSENT, say -- the run proved
        nothing and looks like it proved something, which is the worse of the two failures.

        -Subject names the script under test, so the line says what the asserts are NOT a verdict on.
    #>
    param([string]$Subject = 'the script under test')
    if ($script:FixtureScriptLoadFailures -le 0) { return $false }
    Write-Host "FIXTURE: $($script:FixtureScriptLoadFailures) child script(s) DIED ON LOAD this run -- see the [FIXTURE SCRIPT DIED ON LOAD] lines above." -ForegroundColor Magenta
    Write-Host "         Whatever the asserts say, they are not a verdict on $Subject`: the script never reached its first statement." -ForegroundColor Magenta
    Write-Host "         This is the #1917 class: the fixture is missing a lib the copied script dot-sources UNGUARDED." -ForegroundColor Magenta
    Write-Host ''
    return $true
}
