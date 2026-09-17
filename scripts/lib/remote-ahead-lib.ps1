<#
.SYNOPSIS
    Composes the "'<branch>' is N commit(s) behind <remote>..." sentence a caller prints when a local ref
    has fallen behind its own remote-tracking ref -- the signal that another session or device has pushed
    work this checkout does not have.

.DESCRIPTION
    EXTRACTED FROM new-branch.ps1 (issue #1450, September 5, 2026), the ONLY place this composition
    existed until open-pr.ps1 needed the same question answered at a second door -- see that script's
    own remote-ahead gate for why a second door was needed at all. A second hand-typed copy was rejected
    on sight: what this composes is free text SOMEBODY ELSE CHOSE (a commit's %an and %s), and stripping
    the control/format characters out of it is exactly the class of subtle, security-relevant text a
    fork is free to drift from. It already had: -Utf8 on the git log call below was added earlier the
    SAME DAY (issue #1446) after an RTL-override in a commit subject passed a non-UTF-8 console's default
    decoding undetected. One definition means that fix cannot exist in one copy and not the other.

    Returns '' when there is nothing to report: no divergence, or the count could not be read. Callers
    compose their own trailing sentence (what to do about it), because new-branch and open-pr point the
    reader at two different next actions -- one a fast-forward on the happy path, the other a refusal.

    THE SENTENCE HAS TWO SHAPES ONCE A DIVERGENCE IS FOUND, and a caller needs no knowledge of which it
    got: the tip's author and subject where they could be read, and an explicit "whose tip could NOT be
    read (<reason>)" where they could not (issue #1676). What it never does any more is fall back to the
    bare count in silence -- that is the sentence #1439 exists because it is insufficient, so producing
    it without saying so turned a load failure into a guard that looked like it had nothing to add.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script. Depends on
    Invoke-NativeCapture (native-capture-lib.ps1), which every caller of this file already loads, and on
    Get-DisplayRef (ref-print-lib.ps1), which it loads itself -- see the dot-source below.
#>

# THE STRIP HAS ONE DEFINITION, AND IT IS NOT HERE (issue #1623). This file held the tree's second copy of
# the control-and-format strip pattern -- described rather than written, because this file's own suite
# counts the literal here and expects none -- while that same suite already policed the pattern's copies
# in new-branch.ps1 and open-pr.ps1. Policing a rule across the callers while keeping a private copy in
# the lib is the shape this repo keeps repairing. Unconditional, and $PSScriptRoot-relative rather than repo-relative, so
# it resolves in the plugin mirror as well as here; release-lib.ps1 loads its two siblings the same way.
# ref-print-lib.ps1 is a leaf with no dependencies of its own, which is what makes it safe to load first.
. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

function Get-RemoteAheadNote {
    <#
        RepoRoot     -- the repo to run git in.
        LocalRef     -- the ref this checkout actually holds (e.g. 'HEAD', or "refs/heads/$Name").
        RemoteRef    -- the remote-tracking ref to compare against (e.g. "refs/remotes/origin/$Name").
        BranchLabel  -- the branch name as it should read in the sentence.
        FreshLabel   -- how to name RemoteRef when it is known to be current (a fetch just succeeded).
        StaleLabel   -- how to name it when it is not (whatever the last fetch left on disk).
        Fresh        -- which of the two labels applies.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$LocalRef,
        [Parameter(Mandatory = $true)][string]$RemoteRef,
        [Parameter(Mandatory = $true)][string]$BranchLabel,
        [Parameter(Mandatory = $true)][string]$FreshLabel,
        [Parameter(Mandatory = $true)][string]$StaleLabel,
        [Parameter(Mandatory = $true)][bool]$Fresh
    )

    $aheadProbe = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-list', '--count', "$LocalRef..$RemoteRef") -DiscardStderr
    $ahead = 0
    if ($aheadProbe.ExitCode -ne 0 -or -not ([int]::TryParse((($aheadProbe.Output -join '').Trim()), [ref]$ahead)) -or $ahead -le 0) {
        return ''
    }

    # THE SUBJECT AND THE AUTHOR ARE THE POINT, not the count -- see new-branch.ps1's own history of this
    # line for why. -Utf8 IS LOAD-BEARING (issue #1446): without it Windows PowerShell 5.1 decodes git's
    # stdout with [Console]::OutputEncoding, so on a non-UTF-8 console an RTL-override or a zero-width
    # run in someone else's commit subject passes the sanitiser below undetected.
    $tip = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'log', '-1', '--format=%h %an: %s', $RemoteRef) -DiscardStderr -Utf8
    $tipRaw = if ($tip.ExitCode -eq 0) { (($tip.Output -join ' ').Trim()) } else { '' }

    # STRIPPED BEFORE IT IS PRINTED: control and format characters go, the words stay. This is the one
    # piece of text here that somebody else wrote, and it is read by both a terminal and an agent session
    # -- an ANSI/OSC escape or an RTL override would deceive either reader, and a crafted subject wearing
    # this script's own warning prefix is an injection surface rather than a display bug.
    $tipLine = Get-DisplayRef -Ref $tipRaw
    if ($tipLine.Length -gt 120) { $tipLine = $tipLine.Substring(0, 120).TrimEnd() + '...' }

    # A TIP THIS RUN COULD NOT READ IS SAID, NOT DROPPED (issue #1676). Until now an empty capture fell
    # through the `if ($tipLine)` below and the sentence came out as the bare count -- which is the exact
    # sentence #1439 was filed for being insufficient: "1 commit(s) behind" reads identically for another
    # session's push and for a fast-forward of your own autopark, and the author and the subject are what
    # separate them. So the guard degraded, in silence, to the shape it was built to replace.
    #
    # AND AN EMPTY CAPTURE HERE IS NEVER "NOTHING TO REPORT", which is what makes stating it honest rather
    # than defensive. The rev-list above has already returned a count above zero, so $RemoteRef resolves
    # and has at least one commit behind it -- and `--format=%h ...` always yields the abbreviated hash for
    # such a commit. There is no third reading in which git legitimately answers nothing.
    #
    # WHAT PRODUCES IT: THE -Utf8 ARM CAN RETURN A SHORT READ WITH EXIT CODE 0. That arm redirects to files
    # and Read-NativeCaptureFile opens them with FileShare.ReadWrite deliberately (issue #1252), so a
    # grandchild still holding the handle past a clean exit yields whatever was flushed -- a truncated or
    # empty document, reported as success. That trade is right where it was made (a killed tree's tail
    # beats an unrelated IO exception) and is not weakened here: the repair is this caller no longer
    # reading "empty" as "absent". Observed under the test gate on a loaded machine, where the count
    # survived and the tip did not -- the two captures take different code paths, which is why one can
    # fail alone.
    #
    # SINCE #1679 THE LIB SAYS THIS OUTRIGHT -- $tip.ShortRead -- so the inference below is no longer the
    # only way to reach it. It is kept as an inference on purpose: an empty capture here provably cannot
    # be legitimate (the rev-list above already counted the commit, and `--format=%h` always yields its
    # abbreviated hash), so this caller is correct WITHOUT the field and stays correct if a future arm
    # cannot supply it. What the field would buy is a sharper sentence, not a different verdict.
    #
    # THREE REASONS, NAMED SEPARATELY, because the reader's next move differs: a non-zero git is a repo
    # or ref problem, an empty capture on exit 0 is this run's own read, and a tip that strips to nothing
    # is a hostile subject rather than a failure. The third is unreachable while %h holds, and it is here
    # so that the arm below cannot print "whose tip is: " with nothing after it.
    #
    # A FOURTH ONE JOINED THEM UNDER #2081, and it is first because the arm below would otherwise take
    # it: an unmeasurable exit code (#1931) is `-ne 0`, so it printed "git log exited " -- the reason
    # sentence with the number missing out of it, sending the reader after a repo or ref problem that
    # was never measured. It is a fact about this run, like the empty capture one line down, and it
    # resolves the same way.
    $tipUnread = ''
    if (-not (Test-NativeExitMeasured -Capture $tip)) {
        $tipUnread = 'git log ran and its exit code came back unmeasurable (issue #1931) -- a fact about this run rather than about the branch, and it normally settles on a re-run'
    }
    elseif ($tip.ExitCode -ne 0) { $tipUnread = "git log exited $($tip.ExitCode)" }
    elseif (-not $tipRaw)    { $tipUnread = 'git log exited 0 and its capture came back empty' }
    elseif (-not $tipLine)   { $tipUnread = 'its author and subject carry no printable characters at all' }

    # AND THE BRANCH LABEL GOES THROUGH THE SAME STRIP (issue #1623). Two lines above, the commit subject
    # is sanitised for exactly the reason that applies word for word to the name interpolated here -- and
    # this line printed it raw, which is the sharpest instance the issue found. It is not belt-and-braces:
    # `git check-ref-format` accepts \p{Cf}, so a fetched or hand-made branch really can carry U+202E or a
    # zero-width run into this sentence, and open-pr.ps1 hands this function whatever HEAD reads as. The
    # sentence exists to tell the reader WHOSE WORK is on the other side of a divergence, so a label that
    # prints as a different name than it is defeats the whole line.
    $seenRef = if ($Fresh) { $FreshLabel } else { $StaleLabel }
    $shownLabel = Get-DisplayRef -Ref $BranchLabel
    $note = "'$shownLabel' is $ahead commit(s) behind $seenRef"
    if ($tipUnread) {
        # MISSING FROM THE WARNING, NOT ABSENT FROM THE BRANCH -- said in those words because the reader's
        # own inference from a short sentence is that there was nothing to say. The remedy is deliberately
        # not printed here: all three callers append their own next action (`git pull --ff-only` twice, a
        # refusal once), and a paste-ready `git log` composed here would have to go through Get-PasteableRef
        # for a ref name this function is handed rather than reads -- a second axis for no gain.
        $note += ", whose tip could NOT be read ($tipUnread) -- so the author and subject that would say WHOSE work this is are missing from this warning, not absent from the branch"
    } else {
        $note += ", whose tip is: $tipLine"
    }
    $note += '.'
    return $note
}
