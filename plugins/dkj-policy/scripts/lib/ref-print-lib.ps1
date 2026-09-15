<#
.SYNOPSIS
    Decides whether a git ref name may be interpolated into a PRINTED, PASTE-READY command -- and when
    it may not, supplies the placeholder to print instead plus the line that names the real branch away
    from any command.

.DESCRIPTION
    ISSUE #1594, September 8, 2026. Seven printed remedies across ship-pr.ps1 and sync-main.ps1 put a
    branch name into a command line meant to be copied and run verbatim, unquoted. git's own ref rules
    do not forbid the characters that matter: `git check-ref-format --branch` accepts every one of
    `fix/evil;touch`, `fix/evil&touch`, `fix/evil|touch`, `fix/evil$(touch)`, `` fix/evil`touch` `` and
    `fix/it's-fine` (exit 0, measured). What it DOES reject is ASCII control characters (\p{Cc}) and the
    space (exit 128) -- NOT the whole of the ANSI/OSC-repaint class remote-ahead-lib.ps1's sanitiser
    exists for (#1439, #1446), because that class is `[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]` (widened
    from `[\p{Cc}\p{Cf}]` by #2024) and git enforces only a sliver of the first half. A `\p{Cf}` run is
    accepted in a ref name and is a live display hazard; see the scope note at the foot of this block.
    What THIS lib is about is a different hole in the same wall: not display deception, but a command
    a reader is invited to run.

    WHY QUOTING IS NOT THE FIX, WHICH IS THE PART WORTH RECORDING. The obvious repair -- wrap the value
    in quotes -- fails in both spellings, and it fails in both shells this workflow's readers actually
    use:
      - DOUBLE QUOTES do not close it. Command substitution runs inside them in bash AND in PowerShell,
        so `git checkout "x$(id -un)"` executes the substitution in either. Measured on a branch named
        `x$(id -un)`: it resolved to the current user's name.
      - SINGLE QUOTES do not close it either, because `fix/it's-fine` is a legal branch name (above), so
        the value can terminate its own quoting.
    A shell-correct escape exists per shell ('' doubling in PowerShell, '\'' in bash) and that is
    precisely the problem: a printed line does not know which shell will receive it, and this repo's
    remedies are pasted into PowerShell, Git Bash and cmd alike. So the answer is not to escape the
    value but to REFUSE TO PUT IT IN A COMMAND AT ALL, which is what this lib does.

    THE ALLOWLIST RATHER THAN A DENYLIST, and its first character is pinned. A denylist of shell
    metacharacters has to be right about four shells at once; an allowlist has to be right about the
    characters it admits. Admitted: ASCII letters, digits, `.`, `_`, `-` and `/`, with the FIRST
    character held to a letter or a digit so a name cannot read as a flag. Everything else -- `;`, `&`,
    `|`, `` ` ``, `$`, `(`, `)`, `'`, `"`, `<`, `>`, `!`, `#`, `%`, `^`, `*`, `?`, `[`, `]`, `{`, `}`,
    `~`, `=`, `+`, `,`, `:`, `@`, `\`, whitespace and every control character -- is refused. `!`, `%`
    and `^` are in that list for cmd's sake (history/delayed expansion, variable expansion, escape)
    even though bash and PowerShell would pass two of them.

    MEASURED AGAINST THIS REPO'S OWN HISTORY BEFORE IT WAS ADOPTED: all 994 pull-request head refs this
    repo has ever had match the pattern, so the rule refuses nothing anybody here has wanted. That is
    the whole argument for an allowlist this narrow -- it costs nothing real.

    THE DISPLAY AXIS, AND WHY IT IS A SECOND FUNCTION RATHER THAN A WIDER ALLOWLIST. `'$branch'` quoted
    inside a prose sentence ("this checkout is still on 'x;y'") is not a command, and the shell
    metacharacters this lib refuses are inert there. THAT IS NOT THE SAME AS SAFE (#1617). The deceptive
    class is `[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]` (#2024 widened it past `[\p{Cc}\p{Cf}]`, to also
    catch U+2028/U+2029 and stacking combining marks) and `git check-ref-format` enforces only the
    `\p{Cc}` half, so a ref carrying a `\p{Cf}` character is accepted, creatable and checkout-able, and
    `git rev-parse --abbrev-ref HEAD` hands it back verbatim. Measured, September 8, 2026, `--branch`
    exit codes:
    U+202E RIGHT-TO-LEFT OVERRIDE 0, U+200D ZERO WIDTH JOINER 0, U+200B ZERO WIDTH SPACE 0, U+2066
    LEFT-TO-RIGHT ISOLATE 0 -- against 128 for BEL and ESC. Those first two are the exact code points
    #1446 was filed for, where they bypassed the #1439 tip sanitiser, which is why
    remote-ahead-lib.ps1 strips `\p{Cf}` deliberately and this lib's own refusal note (below) does the
    same.

    THAT GAP WAS LEFT OPEN KNOWINGLY FOR A DAY, AND #1623 CLOSED IT. Get-DisplayRef below is the one
    definition of the strip, and the thirty-two prose sites across ship-pr.ps1, sync-main.ps1,
    remote-ahead-lib.ps1 and worktree-lib.ps1 go through it. The two axes stay distinct because the
    right answer differs: a name refused for PASTE is replaced by a placeholder, because a command
    carrying it would RUN, while a name printed as PROSE is stripped and still reads, because the reader
    is standing on that branch and has to recognise it -- a sentence that will not name the branch has
    nothing left to say. The narrow path the measurement above names (Test-BranchName refuses these at
    creation, so it takes a branch created by hand, cloned or fetched) is now the argument for why the
    strip COSTS nothing rather than for why the gap could be weighed and left.

    IT IS NOT ONLY ABOUT REF NAMES ANY MORE, AND THE ALLOWLIST DID NOT HAVE TO CHANGE FOR THAT (issues
    #1637, #1638, September 8, 2026). Both axes were open one class further out, at a FILE PATH: the
    take / hold-back / conflict listings in sync-main.ps1 printed one as prose through a padded '-f'
    format, and its conflict remedy printed one into a paste-ready `git diff --no-index` -- twice per
    line, since the mirror path is derived from the repo path, so one hostile path poisoned both
    operands. That command was double-quoted, which is precisely the spelling the paragraph above was
    written to reject; it read as a guard, which is worse than a bare interpolation, because a later
    reader sees quotes and stops looking.

    THE PROVENANCE IS THE ARGUMENT, not a theory about what a filesystem allows. Those paths come from
    this repo's own HEAD via `git ls-tree`, and from a filesystem walk of the pulled LIVE theme -- which
    third parties edit through the Shopify theme editor, outside this repo's review, and which is the
    reason that sync exists at all. Measured, September 8, 2026, git 2.55.0.windows.5: a tree built with
    `git mktree` carrying `assets/x$(id -un).js`, `` assets/y`id -un`.js `` and `assets/z;touch owned.js`
    comes back from `git diff --name-only` and `git ls-tree -r` unquoted, and `core.quotePath` is
    irrelevant to all three -- git quotes control characters and high bytes, not shell metacharacters.
    The mirror image of the display result: git's incidental quoting covers the \p{Cc} class and none of
    the paste class.

    SO THE TWO AXES STAY TWO, AND EACH GAINED ITS PATH SHAPE RATHER THAN A WIDER RULE. Get-PasteableRef
    -Kind Path changes the noun its note speaks in, the strip that renders the value there, and -- since
    #1762 -- the pattern it is judged against. Get-DisplayPath is a second display function rather than a
    parameter on the first, because it must NOT collapse or trim -- a path may legitimately carry a space
    where a ref may not. And Get-DisplayRef is the wrong answer for a command at either axis: a stripped
    path would hand the reader a `git diff` aimed at a different file than the one on screen.

    THE PATH PATTERN IS ITS OWN, BECAUSE A REPO-RELATIVE PATH WAS THE ONLY KIND THE REF ALLOWLIST COULD
    EXPRESS (issue #1762, September 10, 2026). $RefPasteSafePattern admits neither `:` nor `\`, so
    -Kind Path refused every ABSOLUTE path outright -- and an absolute path is exactly what a lane, a
    worktree or a scratch tree always is. The one -Kind Path caller that carries such a path today,
    check-plugin-integrity.ps1's nested-worktree remedy (`git worktree remove <the absolute path>`),
    therefore always printed the placeholder for the very path it exists to hand the reader; tidy-machine
    and worktree-lane want the same and could not have it. The measured path was an ordinary lane
    directory this workflow's own `worktree-lane.ps1` had just created.
      WIDENING THE SHARED ALLOWLIST WAS THE WRONG REPAIR. `:` and `\` in $RefPasteSafePattern would also
    widen what a REF may carry, which is the axis #1594 and #1617 narrowed on purpose. The two nouns want
    two allowlists. $PathPasteSafePattern adds exactly the two characters an absolute path needs -- a
    drive/scheme colon and a leading `/` for a POSIX root -- and NOTHING else: a space, `$`, a backtick, a
    quote, `;`, `&`, `|` are refused here identically to the ref axis and fall through to the same note.
      AND `\` IS ADMITTED ONLY AFTER IT IS FOLDED TO `/` (ConvertTo-PastePath). `\` is bash's escape
    character, so a token carrying it (`git diff --no-index -- C:\a\b`) loses its separators in Git Bash
    -- one of the three shells this lib's header commits to -- while surviving in PowerShell and cmd. `/`
    is literal in all three and git accepts it on Windows, so the folded form is the one printed value
    that is correct everywhere. The fold touches only the .Token; the refusal note still shows the path
    the reader actually has, backslashes and all, so they can recognise it.

    A SECOND ANSWER TO THE PATH AXIS EXISTED FOR ONE DAY, AND THIS ONE IS THE SURVIVOR (issue #1768,
    September 10, 2026). Two branches answered #1762 eleven minutes apart and both landed. The other was
    Format-PasteablePathToken in tidy-lib.ps1: it did not judge the path at all, it wrapped it in
    PowerShell single quotes -- literal by that language's own rules -- and refused only what would
    misrender when READ. On its own terms that is a stronger guarantee than an allowlist, and it is why
    the choice was worth measuring rather than asserting.
      IT LOST ON THE DESTINATION, WHICH IS THE ONE THING A PRINTED REMEDY DOES NOT KNOW. This header
    commits to three shells, and a single-quoted literal is exact in one of them. Measured, git
    2.55.0.windows.5: the token for `C:\it's\here` is `'C:\it''s\here'`, and bash reads a doubled quote
    as a close followed by an open, so Git Bash resolves it to `C:\its\here` -- a different, entirely
    plausible path, silently and with no error to notice. In cmd, where single quotes do not quote,
    every spaced path splits into two arguments. A guard that is correct in one shell and silently
    wrong in another is the same failure this lib's own header rejects double quotes for: it reads as
    protection, so the next reader stops looking.
      AND ITS PREMISE HAD EXPIRED BEFORE IT WAS READ. It argued that -Kind Path judged against
    $RefPasteSafePattern and so refused every absolute path -- true until #1765, which is the change
    directly above this paragraph. The noise it was built to remove was already gone.
      SO A SPACE STAYS OUT OF $PathPasteSafePattern, AND THAT IS THE ANSWER RATHER THAN A GAP. #1768
    proposed admitting one if the allowlist won. It must not be: the .Token is printed UNQUOTED, so
    `git worktree remove C:/Program Files/x` splits into two arguments in bash, PowerShell and cmd
    alike -- a space is the one character an allowlist over an unquoted token can never admit, whatever
    the destination. The refusal is the correct answer and the note carries the reader the rest of the
    way; the suite has asserted exactly that verdict for 'C:\Program Files\a b\x' since #1762.

    WHAT THIS LIB DOES NOT DO. It is not the creation-side
    guard -- Test-BranchName in the repo-owned scripts\lib\branch-info.ps1 holds the same allowlist so a
    branch this workflow CREATES is safe by construction. Neither half closes the hole alone: that file
    is repo-owned and per-consumer, and a branch cloned, fetched or created by hand reaches these print
    sites having never met it. This lib is the half that travels.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script. No
    dependencies -- deliberately, so a caller can load it before anything else.
#>

# The one definition of "safe to paste". Anchored at both ends, first character pinned to alphanumeric.
$script:RefPasteSafePattern = '^[A-Za-z0-9][A-Za-z0-9._/-]*$'

# The path variant (issue #1762). The ref pattern plus exactly the two characters an ABSOLUTE path
# needs and a ref never has: a drive/scheme `:`, and a leading `/` for a POSIX root. `\` is NOT in it --
# it is folded to `/` before the match (ConvertTo-PastePath). Everything the ref pattern refuses, this
# refuses too. The reasoning is in this file's header block, under THE PATH PATTERN IS ITS OWN.
$script:PathPasteSafePattern = '^[A-Za-z0-9/][A-Za-z0-9._/:-]*$'

function Test-RefPasteSafe {
    <#
        Ref -- the ref name to judge.

        Returns $true when the name may be interpolated into a printed command line as-is. An empty or
        null name is NOT safe: a caller that lost its branch would otherwise print a command with a hole
        in it, which is the one outcome worse than a placeholder.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Ref)

    if ([string]::IsNullOrEmpty($Ref)) { return $false }
    return [bool]($Ref -match $script:RefPasteSafePattern)
}

function ConvertTo-PastePath {
    <#
        Path -- a filesystem path about to be judged for, or carried into, a printed command.

        Returns it with every `\` folded to `/`. That is the whole transform, and it exists so ONE
        printed form is correct in all three shells this lib's header commits to: `\` is bash's escape
        character and `C:\a\b` loses its separators in Git Bash, while `/` is literal in bash, PowerShell
        and cmd alike and git accepts it on Windows. An empty or null path is returned unchanged.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Path)

    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    return ($Path -replace '\\', '/')
}

function Test-PathPasteSafe {
    <#
        Path -- the filesystem path to judge.

        Returns $true when the path -- after its backslashes are folded to forward slashes -- may be
        interpolated into a printed command line as-is. Same contract as Test-RefPasteSafe: an empty or
        null path is NOT safe. Differs from it only in admitting `:` and a leading `/`, the two things an
        absolute path carries and a ref cannot (issue #1762).
    #>
    param([AllowEmptyString()][AllowNull()][string]$Path)

    if ([string]::IsNullOrEmpty($Path)) { return $false }
    return [bool]((ConvertTo-PastePath -Path $Path) -match $script:PathPasteSafePattern)
}

$script:ConsoleDeceptiveCategories = @(
    [System.Globalization.UnicodeCategory]::Control,
    [System.Globalization.UnicodeCategory]::Format,
    [System.Globalization.UnicodeCategory]::LineSeparator,
    [System.Globalization.UnicodeCategory]::ParagraphSeparator,
    [System.Globalization.UnicodeCategory]::NonSpacingMark,
    [System.Globalization.UnicodeCategory]::EnclosingMark
)

function ConvertTo-ConsoleStrippedText {
    <#
        .SYNOPSIS
            One line of foreign text, with every character that could make it read as something other
            than what it says replaced by a space -- Cc, Cf, Zl, Zp, Mn and Me, read a CODE POINT AT A
            TIME rather than through a regex character class.

        .DESCRIPTION
            ISSUE #2024'S SECOND HALF. Every caller of this function used to type the class directly, as
            a regex: '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]'. On this runtime (Windows PowerShell 5.1 /
            .NET Framework, measured while repairing #2025) that class is silently wrong twice:

              1. U+00AD SOFT HYPHEN is Format (Cf) in the CURRENT Unicode table and Dash Punctuation (Pd)
                 to the REGEX ENGINE, whose category tables predate the Unicode 4.0 reclassification --
                 the only such divergence in the whole BMP, all 65,536 code points compared one by one.
                 [regex]::IsMatch([string][char]0xAD, '[\p{Cf}]') is $false on this runtime.
              2. EVERY FORMAT CHARACTER ABOVE THE BMP is invisible to the class outright, because a .NET
                 character class matches one UTF-16 CODE UNIT and those characters are surrogate PAIRS.
                 That is the U+E0020..U+E007F TAG block -- an invisible-text channel that can carry a
                 whole hidden ASCII message and render as nothing -- plus U+E0001, U+1D173..U+1D17A and
                 U+110BD/U+110CD.

            So the category is read from [CharUnicodeInfo]::GetUnicodeCategory(string, index), which uses
            the CURRENT table and resolves a surrogate pair to the single code point it names. On an
            UNPAIRED surrogate it answers Surrogate, none of the six categories above, so a broken pair
            is copied through rather than silently eaten.

            A SPACE PER UTF-16 CODE UNIT CONSUMED, not one space per code point. Get-DisplayPath
            (ref-print-lib.ps1, #1638) measures its output in .Length to preserve a padded column's
            alignment, and .Length counts UTF-16 units -- so a two-unit surrogate pair becomes two
            spaces, keeping format width and display width in agreement exactly as a one-unit character
            already does. Every other caller collapses and trims afterward and is indifferent to the
            count, so the one convention serves them all.

            SIX CATEGORIES AND NO EXCEPTIONS -- unlike ConvertTo-BacklogVisibleText (#2025,
            dkj-policy-bwj's backlog-page-rules.ps1), which keeps eight invisible code points an HTML
            page can afford to render (three bidi MARKS, two joiners) because an HTML element can be
            told a text direction and a console line cannot. That is why this is not a reuse of that
            function -- only of its LOOKUP; the policy differs; the code-point walk does not.

            THIS IS THE THIRD LIB-INDEPENDENT COPY -- claim-issue-lib.ps1, pr-issues-lib.ps1 and
            ref-print-lib.ps1, identical byte for byte, the same three libs and the same DISAGREE rule
            that used to hold one regex literal in agreement now holds one function definition in
            agreement instead (pr-issues.tests.ps1). ref-print-lib.ps1 defines it once for both
            Get-DisplayRef and Get-DisplayPath, since both live in that file; the other two libs each
            carry their own copy, for the reason their docstrings already give for not sharing a
            dot-source.
    #>
    param([string]$Text)
    if (-not $Text) { return $Text }

    $sb = New-Object System.Text.StringBuilder
    $i  = 0
    while ($i -lt $Text.Length) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($Text, $i)
        $paired   = ([char]::IsHighSurrogate($Text[$i]) -and ($i + 1) -lt $Text.Length -and
                     [char]::IsLowSurrogate($Text[$i + 1]))
        $width    = if ($paired) { 2 } else { 1 }

        if ($script:ConsoleDeceptiveCategories -contains $category) {
            [void]$sb.Append(' ' * $width)
        } else {
            [void]$sb.Append($Text.Substring($i, $width))
        }
        $i += $width
    }
    return $sb.ToString()
}

function Get-DisplayRef {
    <#
        Ref -- the ref name, or any other single-line label, about to be printed as PROSE.

        Returns that name with every control and format character replaced by a space, runs of spaces
        collapsed, and the result trimmed. Nothing is refused and nothing is quoted: the words stay,
        because a reader has to recognise the branch they are standing on, and only the characters that
        make the printed line say something other than what it is are removed.

        WHY A SPACE RATHER THAN NOTHING. Deleting a zero-width joiner silently welds the two halves of a
        name into one word that reads as a different, legitimate branch -- which is the deception rather
        than the repair. A space cannot do that, and git forbids one in a ref, so a space in the output
        is itself the signal that something was taken out.

        WHY IT TRIMS, AND WHAT AN EMPTY RETURN MEANS. A name made ENTIRELY of format characters strips to
        blanks and comes back as ''. That is the honest answer -- the name has no display at all -- and it
        hands callers that already word an empty name ("on its branch", "this run could not read it") the
        wording they have rather than a pair of quotes around nothing.

        THE SAME CALL THIS REPO ALREADY MADE FOR A COMMIT SUBJECT, at #1439 and #1446, now stated once:
        remote-ahead-lib.ps1 carried the second copy of this pattern until #1623 and reads it from here.

        #2024 WIDENED THE POLICY, THEN THE MECHANISM. U+2028 LINE SEPARATOR and U+2029 PARAGRAPH
        SEPARATOR (Zl/Zp -- neither is Cc or Cf) can make one printed line read as two, the same harm
        '\n' already exists to prevent, and stacking combining marks (Mn/Me, "Zalgo text" -- not Cc/Cf
        either) visually obscure the printable text around them, the same deception this class already
        guards against for RTL overrides and zero-width runs. The class also stopped being a regex --
        see ConvertTo-ConsoleStrippedText above for why.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Ref)

    if ([string]::IsNullOrEmpty($Ref)) { return '' }
    return (((ConvertTo-ConsoleStrippedText -Text $Ref) -replace ' {2,}', ' ').Trim())
}

function Get-DisplayPath {
    <#
        Path -- a FILE PATH about to be printed as PROSE: a repository-relative one out of a git read,
                or an absolute one off a filesystem walk.

        Returns that path with every control and format character replaced by a space -- and, unlike
        Get-DisplayRef, WITHOUT collapsing runs of spaces and WITHOUT trimming the ends.

        WHY THE COLLAPSE AND THE TRIM ARE DROPPED, WHICH IS THE WHOLE REASON THIS IS A SECOND FUNCTION
        (issue #1638). Get-DisplayRef may collapse and trim because git forbids a space in a ref name
        outright -- `git check-ref-format` exits 128 on one -- so every space in its output is one the
        strip itself put there and no information is lost. A path is the opposite: git, NTFS and
        Shopify's own asset names all accept a space, a leading, trailing and doubled one included, so
        collapsing would report a path that is not the path. These rows are what a reader compares
        against live before merging by hand, and a path is the one thing here that has to survive being
        read off the screen and typed back.

        AND PRESERVING THE LENGTH IS WHAT FIXES THE ALIGNMENT #1638 NAMES. sync-main.ps1 prints these
        through '{1,-46}'. A stripped character is zero-width, so it consumes format width without
        consuming display columns and the row shifts against its neighbours -- in a list whose columns
        are how a reader scans it at all. One space per removed UTF-16 unit (ConvertTo-ConsoleStrippedText
        above) makes format width and display width agree again, which a collapse would undo.

        A PATH WITH NOTHING VISIBLE LEFT IS NAMED RATHER THAN BLANKED. Without the trim, the
        all-format-character case reaches the column as spaces: a row whose path is silently not there.
        Get-DisplayRef answers that case with '', which its callers already have wording for ("on its
        branch"); a row in a padded table has no such wording available, so this says what happened
        instead. It is short enough to leave the padding intact.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Path)

    if ([string]::IsNullOrEmpty($Path)) { return '' }
    $shown = ConvertTo-ConsoleStrippedText -Text $Path
    if ([string]::IsNullOrWhiteSpace($shown)) { return '(no printable path)' }
    return $shown
}

function Get-PasteableRef {
    <#
        Ref         -- the ref name a printed command wants to carry. Or, with -Kind Path, the file
                       path one wants to carry: the judgement is a property of the string, not of what
                       the string names.
        Kind        -- 'Ref' (the default) or 'Path'. It selects the pattern the value is judged
                       against ($PathPasteSafePattern also admits `:` and folds `\` to `/`, so an
                       absolute path can pass -- issue #1762), the noun the refusal note speaks in, and
                       the strip that renders the value in it. A caller passing a path also wants
                       -Placeholder, since '<branch>' would be the wrong hole to fill in.
        Placeholder -- what to print in the command's place when the name is refused. Defaults to
                       '<branch>', the angle-bracket convention every other printed remedy in this
                       workflow already uses for "fill this in yourself" (see ship-pr's own
                       '<that worktree>' and '<push, wait for CI...>').

        Returns one object with three fields, and it is ONE call on purpose: a caller cannot obtain the
        placeholder and forget the sentence that explains it.
          .Token  -- what to put in the command. The name itself when safe, else the placeholder.
          .IsSafe -- the verdict, for a caller that wants to branch on it.
          .Note   -- '' when safe. Otherwise the line to print BENEATH the command, naming the real
                     branch outside any command context so its characters are inert.

        THE NOTE NAMES THE BRANCH RATHER THAN HIDING IT. A remedy that says only "your branch name is
        unsafe" leaves the reader unable to act at all, which is a worse failure than the one this
        guards: they are standing on that branch and need it in the command. So the name is printed --
        as prose, where the shell metacharacters are inert, and STRIPPED OF
        `[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]` on the way (see the implementation note below) so that
        it cannot repaint a terminal. The strip is what
        makes that safe, NOT git's own rules: git rejects only the `\p{Cc}` half and accepts a
        `\p{Cf}` run in a ref name (#1617). Printed with it is what the reader has to do about the
        name, which is quote it for whichever shell they are actually in.
    #>
    param(
        [AllowEmptyString()][AllowNull()][string]$Ref,
        [string]$Placeholder = '<branch>',
        [ValidateSet('Ref', 'Path')][string]$Kind = 'Ref'
    )

    # THE JUDGEMENT, AND THE SAFE TOKEN, ARE BOTH PER-KIND (issue #1762). A ref is carried verbatim; a
    # path is carried in its slash-folded form, because that is the one spelling correct in all three
    # shells (see ConvertTo-PastePath). A repo-relative path has no backslash, so the fold is a no-op for
    # every caller that passed one before this change.
    $isSafe = if ($Kind -eq 'Path') { Test-PathPasteSafe -Path $Ref } else { Test-RefPasteSafe -Ref $Ref }
    if ($isSafe) {
        $token = if ($Kind -eq 'Path') { ConvertTo-PastePath -Path $Ref } else { $Ref }
        return [pscustomobject]@{ Token = $token; IsSafe = $true; Note = '' }
    }

    # THE NAME IS SHOWN IN THE NOTE, and the empty case is spelled out rather than printing '' into a
    # sentence: a caller with no branch at all is a different problem from a caller with a hostile one,
    # and a note reading "the branch name is: ." tells the reader nothing.
    #
    # AND IT IS STRIPPED OF CONTROL AND FORMAT CHARACTERS FIRST, which is remote-ahead-lib.ps1's
    # sanitiser applied to this lib's own output. IT IS LOAD-BEARING ON BOTH INPUTS, not belt-and-braces
    # on either (#1617). git rejects only `\p{Cc}` in a ref, so a name straight from `git rev-parse` can
    # still carry a `\p{Cf}` character -- U+202E and U+200D among them, the two #1446 was filed for --
    # and Get-PasteableRef additionally takes a STRING, which sync-main.ps1 builds from a seam answer a
    # consumer wrote and git has never seen. Without this, the one place this lib prints is a place an
    # ANSI/OSC escape or an RTL override could repaint a terminal or wear this workflow's own warning
    # prefix, and a guard whose refusal path is itself an injection surface is worse than no guard. The
    # same reasoning as #1439 and #1446, at a new site.
    #
    # THE STRIP ITSELF MOVED TO Get-DisplayRef (issue #1623) -- it was written out here, which made this
    # the tree's third copy of one pattern. Two things followed. The wording above is now the WHY and the
    # function is the WHAT, so a future correction to either lands in one place; and a case this line got
    # wrong is repaired, because Get-DisplayRef trims: a name made ENTIRELY of format characters used to
    # strip to blanks and produce a note reading "The branch name is:" with nothing after it, which is
    # the "tells the reader nothing" failure the paragraph above exists to prevent, arriving through the
    # strip instead of through the empty case. It now falls through to the empty wording, which is what
    # it is once the invisible characters are gone.
    #
    # AND -Kind Path DOES NOT INHERIT THAT REPAIR THROUGH THIS LINE, WHICH IS DELIBERATE (issue #1638).
    # Get-DisplayPath does not trim, so an all-format-character path does not arrive here as '' and
    # does not fall through to the empty wording -- it arrives already named, as '(no printable path)'.
    # The two answers differ because the questions do: an unreadable BRANCH is a caller that has lost
    # track of where it is standing, which its own wording covers; an unreadable PATH is one row of a
    # list whose other rows are fine, and it has to stay a row.
    # WHAT -Kind CHANGES (issues #1637, #1638, #1762). The placeholder and the quotes reasoning are
    # already right for a file path -- a printed command does not care which kind of name it was handed.
    # Three things differ, and carrying them on one parameter is why there is no near-copy of this
    # function sitting beside it. The PATTERN (#1762), because $RefPasteSafePattern has neither `:` nor
    # `\`, so it can express only a REPO-RELATIVE path ('assets/foo.js') and refuses every absolute one --
    # the kind a lane, a worktree or a scratch tree always is; $PathPasteSafePattern adds exactly those
    # two, folding `\` to `/` first. The NOUN, because a note reading "the branch name is" about a path
    # sends the reader looking for the wrong kind of thing. And the STRIP: a path is rendered by
    # Get-DisplayPath, which does not collapse or trim, because this note is the only place the real path
    # appears and the reader is being told to put it in the command themselves -- so a path reported with
    # its doubled or trailing spaces removed would aim them at a different file. #1638 carries the full
    # reasoning for that difference.
    $noun  = if ($Kind -eq 'Path') { 'file path' } else { 'branch name' }
    $shown = if ($Kind -eq 'Path') { Get-DisplayPath -Path $Ref } else { Get-DisplayRef -Ref $Ref }
    if (-not $shown) { $shown = '(this run could not read it)' }

    $note = @"
  NOTE: the $noun is not safe to paste into the line above, so it reads '$Placeholder' instead.
  The $noun is: $shown
  It carries characters your shell would interpret (issue #1594), and neither single nor double quotes
  close that -- put it in the command yourself, escaped for the shell you are actually in.
"@

    return [pscustomobject]@{ Token = $Placeholder; IsSafe = $false; Note = $note.TrimEnd() }
}
