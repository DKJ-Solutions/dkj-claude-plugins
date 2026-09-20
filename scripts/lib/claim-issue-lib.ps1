<#
.SYNOPSIS
    The two decisions claim-issue.ps1 makes -- WHICH account this checkout claims under, and WHETHER
    the issue in front of it may be claimed at all.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\claim-issue-lib.ps1')

    WHY THE DECISIONS ARE HERE AND THE COMMANDS ARE NOT. Everything claim-issue.ps1 does around these
    two functions is a `gh` round-trip, which a suite cannot run: it needs a live tracker, an account
    with write access, and an issue it is allowed to edit. The decisions are pure -- names in, verdict
    out -- so they are the half that CAN be tested, and they are the half that carries every refusal
    this step exists for. A test that could only cover the happy path is what let the split-identity
    hole stand (consumer-check-lib.tests.ps1's own lesson), so the pure half is deliberately as wide
    as it can be made and the impure half as thin.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.

    Pure ASCII, per this repo's script-layer convention.
#>

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

function Format-ForConsole {
    <#
        .SYNOPSIS
            Strip control AND format characters out of tracker-supplied text before it is printed.

        .DESCRIPTION
            An issue title is written by whoever opened the issue, and on a public tracker that is
            anybody. Echoed verbatim it reaches the terminal as control characters -- an ANSI escape
            run can move the cursor, repaint what is already on screen, or hide the lines around it,
            which in THIS script would be repainting a refusal. Display only, never execution, and the
            operator has to point the run at that exact number; the reason to strip anyway is that the
            output of this step is what a session then decides on.

            THE CLASS WAS ASCII-ONLY UNTIL #1858, AND THAT IS THE HALF WORTH RECORDING. It was
            '[\x00-\x1F\x7F]' -- C0 and DEL -- which neutralises an ANSI escape and nothing above
            0x7F. So a Trojan-Source-shaped spoof reached the terminal untouched: U+202E RIGHT-TO-LEFT
            OVERRIDE, the U+2066..U+2069 isolates, a zero-width run. Many terminals render those, and
            a line carrying one visually reorders itself without a single byte below 0x80. It also
            missed C1 (U+0080..U+009F), where some terminals read 0x9B as CSI. Both gaps close at once
            now: Cc is C0, DEL and C1, and Cf is the bidi and zero-width class.

            #2024 WIDENED THE POLICY, THEN THE MECHANISM. U+2028 LINE SEPARATOR and U+2029 PARAGRAPH
            SEPARATOR are category Zl/Zp, not Cc/Cf, and either can make a single printed line read as
            two -- the same harm '\n' (which IS Cc, and was already stripped) exists to prevent. A run
            of stacking combining marks (Mn/Me, "Zalgo text") is not Cc/Cf either, but visually obscures
            the printable text around it, the same "make the line say something other than what it
            says" harm the class already exists to prevent for RTL overrides and zero-width runs. And
            the class stopped being a regex: ConvertTo-ConsoleStrippedText above reads each category
            from the runtime's own Unicode table, because on this runtime the regex form of the class
            silently misses two things it claims to cover -- see that function's docstring.

            A SPACE, NOT A RENDERED CODE POINT, WHICH IS THE QUESTION #1858 LEFT OPEN. Rendering
            U+202E as '<U+202E>' keeps more evidence and was weighed: it loses, because the argument
            already in this function decides it. Each character becomes a space rather than vanishing,
            so a title cannot be made to read as a different sentence by deleting the separator between
            two words -- and a space is equally the answer to a bidi mark, which git forbids in a ref
            and which no title needs in order to be RECOGNISED. The cost is real and is accepted: a
            title written in Arabic or Hebrew loses the marks that order it, and an emoji sequence
            joined by U+200D prints as its parts. Everything printable stays exactly as written,
            because a title is quoted evidence and a mangled one is worse than a blunt one.

            THE SAME WALK THIS REPO ALREADY SHIPS, and this is the THIRD lib that types it -- see
            ConvertTo-ConsoleStrippedText above for the full account. Neither sibling's own function
            fits this one's contract either: Get-DisplayRef collapses runs of spaces and trims, and a
            title is evidence that must not be re-spaced; Get-DisplayPath answers the all-stripped case
            with '(no printable path)', the wrong noun for an issue title.

            A FOURTH COPY LIVES OUTSIDE THE LIBS, and it is not a fourth of these. The dkj-policy-bwj
            template asana-mirror.ps1 ships standalone into a consumer's .github/scripts/, where none
            of these libs exist -- so it could not call one even if a function fitted (#2019), and it
            carries its own copy of ConvertTo-ConsoleStrippedText for the same reason. What the four
            copies may not do is DISAGREE, so pr-issues.tests.ps1 compares the three here and
            dkj-policy-bwj.tests.ps1 holds the template to the same characters.

            IT IS IN THIS LIB RATHER THAN IN THE SCRIPT so that it can be tested at all: a lib is
            dot-sourceable and claim-issue.ps1 is not. Same reasoning as the two decisions below.
    #>
    param([string]$Text)
    if (-not $Text) { return '' }
    return (ConvertTo-ConsoleStrippedText -Text $Text)
}

function Get-AssigneeLogins {
    <#
        .SYNOPSIS
            The logins in a `gh issue view --json assignees` payload, as a string array. An EMPTY array
            for empty input, unparseable JSON, or a payload carrying no readable login.

        .DESCRIPTION
            THE SAME MOVE AND THE SAME REASONING AS Get-LabelNames in pr-issues-lib.ps1, whose docstring
            names both 5.1 parse traps this hits. The caller drives a live remote and cannot be covered
            by a suite; parsing the answer is a pure function of the JSON text and can be, so it lives
            here.

            A FIELD gh WAS NEVER ASKED FOR IS ABSENT RATHER THAN EMPTY, and under
            Set-StrictMode -Version Latest a dot-read of an absent property THROWS. So every record is
            probed for 'login' before it is read -- an assignee record without one (schema drift, a
            ghost account, a future gh) is skipped rather than crashing the run mid-way, which in this
            script would mean an unhandled exception where a clean refusal belongs.

            EMPTY IS "COULD NOT BE ASKED" AND NOT "UNASSIGNED", which is why the caller checks gh's
            exit code BEFORE it reaches this function. Read the other way round, a failed query would
            present as a free issue and this whole step would hand out claims on other people's work.

            The payload here is an OBJECT with an 'assignees' array, not the bare array Get-LabelNames
            reads -- `gh issue view --json assignees` wraps it -- so the wrapper is unwrapped first and
            probed for exactly the same reason each record is.
    #>
    param([string]$Json)

    if (-not $Json -or -not $Json.Trim()) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }
    if (-not $parsed.PSObject.Properties['assignees']) { return @() }

    $logins = New-Object System.Collections.Generic.List[string]
    foreach ($record in @(@($parsed.assignees) | Where-Object { $_ })) {
        if (-not $record.PSObject.Properties['login']) { continue }
        $login = ([string]$record.login).Trim()
        if ($login -and -not $logins.Contains($login)) { $logins.Add($login) | Out-Null }
    }
    return @($logins)
}

function Resolve-ClaimAccount {
    <#
        .SYNOPSIS
            Which GitHub account this checkout should put on an issue.

        .DESCRIPTION
            NOT '@me', AND THAT IS THE WHOLE POINT OF THIS FUNCTION. '@me' resolves through the GitHub
            API, so it binds to whatever gh is authenticated as -- while the branch a second session
            correlates the claim WITH carries the git identity. A machine can hold both (a personal
            login on the tracker, a work account on the commits), and then '@me' claims under one name
            while every commit lands under the other: nothing errors and the claim answers the wrong
            question. Measured on DAVE-KOK-BWJ, September 3, 2026 (issue #1315): gh authenticated as
            DaveKJohn while git config user.name read davekokbwj, so claiming #1314 with the documented
            idiom put the wrong account on it and it had to be corrected by hand.

            check-git-identity.ps1 already REPORTS that state, and its report ends with the instruction
            this function implements: "claim by NAME rather than with @me". So on a split checkout the
            answer is the GIT name -- the tracker is made to agree with the commits, because the commits
            are the half nothing can rewrite afterwards.

            THE LOGIN-SHAPE GUARD IS WHY THIS IS SAFE IN A NORMAL REPO. 'git config user.name' is free
            text and usually holds a display name ("Ada Lovelace"), which is not an account and cannot
            be assigned to anything. A value that fails GitHub's own username rule is therefore no
            evidence of a split at all, and the gh account stands -- the same guard, for the same
            reason, that keeps check-git-identity.ps1 silent in every consumer that spells its name
            normally.

        .PARAMETER GhAccount
            The account gh acts as (Get-ActiveGhAccount). '' when gh is absent or logged out.

        .PARAMETER GitUserName
            'git config user.name' for this checkout (Get-GitUserName). '' when unset.

        .OUTPUTS
            Account     -- the login to claim under, or '' when there is no account to claim as.
            GhAccount   -- as read.
            GitUserName -- as read.
            Split       -- $true when the two are provably different accounts.
            Reason      -- 'none' (nothing to claim as) | 'gh' (the two agree, or git names a person)
                           | 'split' (they differ; Account is the git one).
    #>
    param(
        [string]$GhAccount = '',
        [string]$GitUserName = ''
    )

    $gh  = if ($GhAccount) { $GhAccount.Trim() } else { '' }
    $git = if ($GitUserName) { $GitUserName.Trim() } else { '' }

    if (-not $gh) {
        return [pscustomobject]@{
            Account = ''; GhAccount = ''; GitUserName = $git; Split = $false; Reason = 'none'
        }
    }

    # A name that is not login-shaped names a PERSON, so it is not a second account and there is
    # nothing to be split about. GitHub logins are case-insensitive, so a difference in case is the
    # same account and must not be read as two.
    $split = (Test-GitHubLoginShape -Value $git) -and ($git -ine $gh)

    [pscustomobject]@{
        Account     = if ($split) { $git } else { $gh }
        GhAccount   = $gh
        GitUserName = $git
        Split       = $split
        Reason      = if ($split) { 'split' } else { 'gh' }
    }
}

function Get-ClaimVerdict {
    <#
        .SYNOPSIS
            Whether the issue in front of this checkout may be claimed, and what to do about it.

        .DESCRIPTION
            FOUR THINGS CAN BE WRONG, AND THEY ARE ORDERED BY WHAT THEY COST TO GET WRONG.

              1. NO ACCOUNT. gh is absent or logged out, so there is nobody to claim as. Reported
                 rather than worked around: a step whose whole job is to say who is working cannot
                 proceed anonymously.

              2. THE ISSUE IS CLOSED, and this is the refusal the step was built for. 'gh issue edit
                 <n> --add-assignee' SUCCEEDS SILENTLY on a closed issue -- so the claim rule's own
                 idiom gives a session every signal of having taken ownership of work that is already
                 done. Measured (the block at new-branch.ps1's stale-base refusal): a branch was cut,
                 committed, pushed and PR'd against an issue a second session had closed by a merged PR
                 FOUR MINUTES earlier, and the duplicate was found only when the PR sat without a
                 check suite. That is the most expensive of the four and it is the one nothing else
                 catches, because every gate downstream reads the branch and the branch is fine.

              3. SOMEBODY ELSE HOLDS IT. The tracker is the only thing two sessions share -- the same
                 owner on a second machine, a colleague on the same board -- so an assignee that is
                 not this checkout's own account stops the work. Not a judgement call and no valve:
                 the way past it is talking to whoever holds it, which a flag cannot do.

                 A CO-ASSIGNMENT STOPS IT TOO, including one this account is part of. Two people on
                 one issue is exactly the duplicate-work hazard the claim rule exists for, and being
                 one of the two is no evidence about what the other is building.

              4. NOTHING IS WRONG AND IT IS ALREADY YOURS. A resume -- a crash, a '--continue', a
                 second run on the same number. The claim is idempotent, so this is a skip rather
                 than an error: re-claiming would be a write that changes nothing, and reporting it
                 as a failure would teach a session to stop reading the output.

        .PARAMETER Account
            The login this checkout claims under (Resolve-ClaimAccount's Account).

        .PARAMETER State
            The issue's state as the tracker reports it -- 'OPEN' or 'CLOSED'. Compared
            case-insensitively, because 'gh --json state' and the REST API disagree on case.

        .PARAMETER Assignees
            The logins already on the issue. Empty or $null for an unassigned issue.

        .OUTPUTS
            Action -- 'claim' (write it) | 'skip' (already yours, nothing to write) | 'refuse'.
            Code   -- 'open-unassigned' | 'already-yours' | 'no-account' | 'closed' | 'taken'.
            Others -- the assignees that are not this account, for the message. Always an array.
    #>
    param(
        [string]$Account = '',
        [string]$State = '',
        [AllowNull()][string[]]$Assignees = @()
    )

    $others = @(@($Assignees) | Where-Object { $_ -and ([string]$_).Trim() -and ($_ -ine $Account) })
    $mine   = (@(@($Assignees) | Where-Object { $_ -and ($_ -ieq $Account) }).Count -gt 0)

    if (-not $Account) {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'no-account'; Others = $others }
    }
    if ($State -ieq 'CLOSED') {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'closed'; Others = $others }
    }
    if ($others.Count -gt 0) {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'taken'; Others = $others }
    }
    if ($mine) {
        return [pscustomobject]@{ Action = 'skip'; Code = 'already-yours'; Others = $others }
    }
    return [pscustomobject]@{ Action = 'claim'; Code = 'open-unassigned'; Others = $others }
}

# --- WHO THE HOLDER IS, WHEN THE HOLDER IS ALSO LOGGED IN HERE (issue #2207) ----------------------
#
# THE 'TAKEN' REFUSAL ABOVE IS CORRECT AND READS AS ONE SENTENCE IT DOES NOT MEAN. "Pick another
# issue, or ask whoever holds it" describes a colleague on another machine, and against a
# same-person/two-accounts setup that framing is the whole of what makes an override feel like
# bookkeeping rather than a rule break. Measured September 20, 2026, picking up #2197: the refusal
# fired correctly, the holder was reassigned away on the reasoning that both accounts belong to the
# one person who had just typed "fix issue 2197", and a CONCURRENT SESSION under that other account
# was live on the same machine -- finishing eight minutes later with a fuller measurement of the same
# issue. Two independent measurements of one issue, overlapping numbers identical.
#
# AND THE SIGNAL WAS IN HAND. `gh auth status` on that machine named BOTH accounts; the script read
# that output at its first line and kept one name. check-git-identity.ps1 does not cover it either --
# it reported "the gh account and the git identity agree", which is true of the ACTIVE account and
# silent about the other one.
#
# SO THIS ADDS A LINE TO A REFUSAL THAT ALREADY FIRES, on a value already read. The five verdicts are
# unchanged, nothing new is blocked, and no `gh` call is added anywhere -- Get-GhAuthAccounts is the
# read Get-ActiveGhAccount was making privately, with its other records kept.

function Get-LocalAccountHolders {
    <#
        .SYNOPSIS
            The holders of a taken issue that are ALSO authenticated in gh on this machine, as records
            with Holder and IsActive. An EMPTY array when none is -- which is the ordinary case, a
            colleague elsewhere.

        .DESCRIPTION
            CASE-INSENSITIVE, because GitHub logins are: 'DaveKJohn' and 'davekjohn' are one account,
            and a comparison that missed that would report the commonest spelling of this hazard as a
            stranger. The HOLDER's spelling is what is returned, because that is the name the refusal
            one line above has already printed and a second spelling of one account reads as two.

            IT DOES NOT NARROW TO NON-ACTIVE ACCOUNTS, and that is where this goes further than #2207
            proposed. The report's wording was "a non-active account on this machine", which is the
            shape it measured -- but the decisive fact is that the holder is authenticated HERE, and
            on a SPLIT-IDENTITY checkout the holder can be the ACTIVE gh account while this checkout
            claims under its git name. That is #1315's own configuration, which this workflow already
            knows it has, so narrowing to non-active would go blind on exactly the machines most
            likely to hit this. IsActive is carried instead of filtered on, and the wording says which
            it found.

            A HOLDER EQUAL TO THIS CHECKOUT'S OWN ACCOUNT CANNOT REACH HERE -- Get-ClaimVerdict's
            Others already excludes it -- so nothing is filtered for that, and passing an unfiltered
            assignee list would simply report the account back to itself, which is not a state the
            caller can produce.

        .PARAMETER Holders
            The verdict's Others -- the assignees that are not this checkout's account.

        .PARAMETER LocalAccounts
            ConvertFrom-GhAuthStatus records for this machine (Get-GhAuthAccounts).

        .OUTPUTS
            Holder   -- the login, spelled as the tracker spells it.
            IsActive -- $true where that account is the one gh currently acts as.
    #>
    param(
        [AllowNull()][string[]]$Holders,
        [AllowNull()][object[]]$LocalAccounts
    )

    $local = @(@($LocalAccounts) | Where-Object { $_ -and $_.Account })
    if ($local.Count -eq 0) { return @() }

    # List[psobject] for the reason ConvertFrom-CommitScanLog states below -- @() over a List[object]
    # throws on Windows PowerShell 5.1.
    $found = New-Object 'System.Collections.Generic.List[psobject]'
    foreach ($holder in @(@($Holders) | Where-Object { $_ -and ([string]$_).Trim() })) {
        $name  = ([string]$holder).Trim()
        $match = @($local | Where-Object { ([string]$_.Account).Trim() -ieq $name })
        if ($match.Count -eq 0) { continue }
        if (@($found | Where-Object { $_.Holder -ieq $name }).Count -gt 0) { continue }
        [void]$found.Add([pscustomobject]@{
            Holder   = $name
            IsActive = [bool](@($match | Where-Object { $_.IsActive }).Count -gt 0)
        })
    }
    return @($found)
}

function Format-ConcurrentSessionNote {
    <#
        .SYNOPSIS
            The lines the 'taken' refusal adds when a holder turns out to be authenticated in gh on
            this machine. An EMPTY array when none is, which is what keeps the ordinary refusal
            exactly as it was.

        .DESCRIPTION
            THE WORDING MATTERS MORE THAN THE DETECTION, and that is #2207's own finding rather than a
            flourish. The detection is three lines; what the note has to do is remove the ONE reading
            under which overriding the refusal looks reasonable -- "these are both my accounts, so
            this claim is stale bookkeeping". So it names the concurrent-session reading out loud and
            says, in words, that being the same person is the hazard rather than an exception to it.

            STILL A REFUSAL, NOT A NEW VERDICT. These lines are printed inside a refusal that has
            already fired and already exited 1. Nothing here decides anything, which is why it is a
            formatter and not a rule.

            THE NAMES ARE PROVABLY LOGIN-SHAPED, so they are not run through Format-ForConsole -- and
            that is an argument rather than an omission, since this lib's own header lists every place
            it prints foreign text. A value reaches here only by matching an assignee login the
            tracker returned, and GitHub logins are [A-Za-z0-9-]; a stray token off the `gh auth
            status` walk cannot reach print without first being equal to one of those. The refusal
            line directly above prints the same names the same way.

        .PARAMETER LocalHolders
            Get-LocalAccountHolders's output.

        .PARAMETER Account
            The account this checkout claims under, named only so the split-identity case reads as the
            sentence it is.
    #>
    param(
        [AllowNull()][object[]]$LocalHolders,
        [string]$Account = ''
    )

    $holders = @(@($LocalHolders) | Where-Object { $_ -and $_.Holder })
    if ($holders.Count -eq 0) { return @() }

    $lines = New-Object System.Collections.Generic.List[string]
    $lead  = if ($holders.Count -eq 1) { 'the holder is' } else { 'those holders are' }
    [void]$lines.Add("NOTE: $lead authenticated in gh ON THIS MACHINE:")
    foreach ($h in $holders) {
        $where = if ($h.IsActive) {
            if ($Account) { "the ACTIVE gh account here, while this checkout claims as '$Account'" }
            else          { 'the ACTIVE gh account here' }
        } else {
            'logged in here, not the active account'
        }
        [void]$lines.Add("        '$($h.Holder)' -- $where")
    }
    [void]$lines.Add('      A second authenticated account is how ONE PERSON RUNS TWO SESSIONS, so this is far more')
    [void]$lines.Add('      likely a CONCURRENT SESSION HERE than a colleague elsewhere. Do NOT reassign it to')
    [void]$lines.Add('      yourself on the reasoning that both accounts are yours -- that IS the duplicate-work')
    [void]$lines.Add('      case, not an exception to it. Go and find the other session before you touch this.')
    return @($lines)
}

# --- THE FOURTH PICKUP SIGNAL: A FIX ALREADY PUSHED ON A BRANCH WITH NO PR (issue #1853) ----------
#
# THE THREE SIGNALS ABOVE ALL READ 'UNTOUCHED' IN ONE SHAPE. Get-ClaimVerdict reads the issue's state
# and its assignees; Get-TargetIssueWarnings (pr-issues-lib.ps1) resolves an issue to a PULL REQUEST.
# Measured September 11, 2026: a session claimed #1847 -- OPEN, unassigned, correctly -- read the code,
# wrote the one-line fix, ran the lint gate and committed, and only then did open-pr.ps1's remote-ahead
# gate show that commit f686b0af on origin/feat/1842-unify-prio-labels-bwj had already made the
# identical repair and said so in its own message. Nothing earlier could have seen it: that branch is
# PARKED, so there was no PR for the PR-shaped check to find, and nothing had closed the issue.
#
# SO THE FOURTH SIGNAL IS THE COMMIT MESSAGE, which is where a parked fix announces itself and the only
# place it does. The functions below are the pure half of that read -- the pattern, the two parses, and
# the report -- with the git calls in claim-issue.ps1 for the same reason the gh calls are: a suite
# cannot run them.
#
# ADVISORY BY CONSTRUCTION, like Get-TargetIssueWarnings and for the same reason (#1485): the claim is
# the OPENING of the work, so a false stop here costs the whole assignment. An issue can be legitimately
# named in a commit on a branch that does not fix it -- the same run that produced this measurement saw
# open-pr warn about four such mentions, all correct as context -- so this reports and never refuses.

function Get-IssueMentionPattern {
    <#
        .SYNOPSIS
            The POSIX extended regex that finds a commit message naming this issue, for `git log -E
            --grep=`. '' for a non-positive number, which the caller reads as "nothing to scan".

        .DESCRIPTION
            THREE SPELLINGS, BECAUSE THIS WORKFLOW WRITES ALL THREE and a pattern that knows only one
            misses the commit that matters most. #1853's own proposal was hash-only ('#<n>'), and the
            commit it was measured against is 'fix(1842): apply the parallel review findings', whose
            issue number is in the CONVENTIONAL COMMIT SCOPE with no hash at all -- so hash-only would
            have found that branch's prose and not its subject lines.

              - '#1853'   -- a body reference, which is how one branch cites an issue it is not named for
              - '(1853)'  -- the scope of 'type(scope): subject', which is how it cites the one it is
              - '/1853-'  -- the branch name inside a commit SUBJECT, which is the one shape a PARKED
                             branch always has: new-branch.ps1's own creation commit is
                             'park: fix/1853-parked-fix-scan (the branch files only)', and a branch that
                             never got further than being cut has no other commit to be found by.

            THE TRAILING CLASS IS WHAT KEEPS #18530 OUT. '([^0-9]|$)' requires the number to end where it
            ends, so a longer number that merely starts with these digits does not match -- the trap a
            bare '#1853' walks straight into, and it gets noisier as a tracker grows. There is
            deliberately no LEADING boundary beyond the three characters themselves: each one IS the
            boundary, and demanding another would drop '(#1853)'.

            NOT '\b': git's grep engines are POSIX, where '\b' works under the GNU implementation and is
            undefined elsewhere -- exactly the kind of thing that behaves on the machine it was written
            on. This lib is mirrored into every consumer's plugin cache, so "here" is not the only place
            it runs.

        .PARAMETER Issue
            The issue number. Non-positive -> ''.
    #>
    param([int]$Issue = 0)

    if ($Issue -le 0) { return '' }
    # The backtick escapes '$' for PowerShell's string parser only -- what reaches git is a literal '$',
    # the regex end anchor.
    return "(#|\(|/)$Issue([^0-9]|`$)"
}

function ConvertFrom-CommitScanLog {
    <#
        .SYNOPSIS
            The commits in a 'git log --format=%H%x1f%an%x1f%at%x1f%s' capture, as records with Sha,
            Author, AuthorEpoch and Subject. An EMPTY array for empty input or a capture carrying no
            readable line.

        .DESCRIPTION
            THE UNIT SEPARATOR (0x1F) IS THE FIELD DELIMITER, and that is the whole reason the format
            string is what it is: a commit subject is free text written by anybody with push access, and
            every printable delimiter a reader might reach for -- a tab, a pipe, a colon -- appears in
            real subjects in this repo. 0x1F cannot, because git strips control characters out of the
            subject line it produces.

            FOUR FIELDS SINCE #1878, AND THE TWO NEW ONES CARRY THE JUDGEMENT. The report used to print
            a sha and a subject and leave the reader to decide; the two facts that decision actually
            turns on -- WHO pushed it and HOW LONG AGO -- were one git format field away and neither was
            asked for. Measured September 11, 2026: a 'park:' commit by another account, three minutes
            old, was read for its content, found empty, and dismissed, while its author was mid-flight
            on the same issue. A park commit is empty BY DESIGN, so content is the one thing that cannot
            report that collision.

            A LINE WITHOUT ALL FOUR FIELDS IS SKIPPED rather than guessed at. git writes progress and
            hints to stderr, and a caller that did not discard it would otherwise turn one of those lines
            into a commit with no sha. Same treatment Get-AssigneeLogins gives a record with no login,
            and for the same reason: this runs inside the step that OPENS an assignment, where an
            unhandled parse is a session that never starts.

            THE SUBJECT IS LAST, AND THE EPOCH IS VALIDATED, because two of these four fields are free
            text. The count on the split keeps everything after the third separator in the subject, so a
            subject may hold anything at all. An author NAME may in principle hold a separator too, and
            that is the one shape that would shift the fields -- so the epoch is read only when it is
            digits, and a shifted line therefore reports an age this function declines to state (0)
            rather than a wrong one. The sha is unaffected either way.

            NEITHER FREE FIELD IS STRIPPED HERE. The caller prints them and the caller runs them through
            Format-ForConsole, which keeps the one control-character policy in one place instead of two.

        .PARAMETER Text
            The capture, as one string or as the caller's joined line array.
    #>
    param([string]$Text)

    if (-not $Text -or -not $Text.Trim()) { return @() }

    # [string[]] IS LOAD-BEARING, NOT DECORATION. The overload that takes a count is
    # Split(String[], Int32, StringSplitOptions), and PowerShell's @() builds an Object[] -- which binds
    # to no overload at all. It does not fail at this line either: 5.1 reports it as an ArgumentException
    # at the `return` below, which sends a reader looking at the wrong statement entirely. The [char]
    # overload is not the way out: it takes no count, so a subject containing a further separator would
    # split into an extra field and lose its tail.
    $sep = [string[]]@([string][char]0x1F)
    # List[psobject] AND NOT List[object], WHICH IS A 5.1 TRAP RATHER THAN A PREFERENCE. Windows
    # PowerShell 5.1 throws ArgumentException ("argument types do not match") when the array
    # subexpression @() wraps a List[object] -- whatever the list actually holds, a string included --
    # and it reports the fault at the `return @($records)` line, which sends a reader looking at the
    # wrong statement entirely. List[psobject] and List[string] both wrap cleanly, which is why the
    # three sibling functions in this file never met it. Measured here, 5.1.26100.9444.
    $records = New-Object 'System.Collections.Generic.List[psobject]'
    foreach ($line in ($Text -split "`r?`n")) {
        if (-not $line -or -not $line.Trim()) { continue }
        $parts = $line.Split($sep, 4, [System.StringSplitOptions]::None)
        if ($parts.Count -lt 4) { continue }
        $sha = $parts[0].Trim()
        if (-not $sha) { continue }
        $epochText = $parts[2].Trim()
        # DIGITS OR NOTHING. %at is git's own author date in seconds, so anything else arriving here is
        # a line whose fields have shifted -- and an age printed off a shifted field is exactly the kind
        # of confident wrong fact this report was repaired to stop producing. 0 is the caller's signal
        # to say the age is unknown.
        $epoch = 0L
        if ($epochText -match '^\d+$') { $epoch = [long]$epochText }
        $records.Add([pscustomobject]@{
            Sha         = $sha
            Author      = $parts[1].Trim()
            AuthorEpoch = $epoch
            Subject     = $parts[3].Trim()
        }) | Out-Null
    }
    return @($records)
}

function Format-CommitAge {
    <#
        .SYNOPSIS
            'three minutes ago' for a number of seconds. 'at an unknown time' for a non-positive or
            unreadable one.

        .DESCRIPTION
            THE AGE IS HALF OF WHAT #1878 ADDED, and it is a separate function because it is the half
            with no git in it. A reader deciding whether somebody is mid-flight on their issue reads
            'three minutes ago' and 'four months ago' completely differently, and neither is derivable
            from a sha.

            COARSE ON PURPOSE. One unit, no decimals, largest that fits: the question this answers is
            'is this live?', which nothing finer than a unit ever changes. Days stop at 60 rather than
            running to 'ninety days ago', because past two months the exact count has stopped carrying
            any decision.

            A NEGATIVE AGE IS NOT AN ERROR, and it is the one case worth naming: a commit authored on a
            machine whose clock runs ahead arrives in the future, which is a fact about clocks rather
            than about the commit. It reads as 'just now' -- the honest end of the range, and the one
            that keeps a live collision from printing as something ancient.

        .PARAMETER Seconds
            Seconds elapsed since the commit was authored.
    #>
    param([long]$Seconds = 0)

    if ($Seconds -lt 0) { $Seconds = 0 }
    $unit = $null
    $count = 0
    if ($Seconds -lt 60) { return 'just now' }
    elseif ($Seconds -lt 3600) { $count = [long][math]::Floor($Seconds / 60); $unit = 'minute' }
    elseif ($Seconds -lt 86400) { $count = [long][math]::Floor($Seconds / 3600); $unit = 'hour' }
    elseif ($Seconds -lt 5184000) { $count = [long][math]::Floor($Seconds / 86400); $unit = 'day' }
    elseif ($Seconds -lt 31536000) { $count = [long][math]::Floor($Seconds / 2592000); $unit = 'month' }
    else { $count = [long][math]::Floor($Seconds / 31536000); $unit = 'year' }

    $plural = if ($count -eq 1) { '' } else { 's' }
    return "$count $unit$plural ago"
}

function Test-SelfAuthored {
    <#
        .SYNOPSIS
            $true when a commit's author name is one of the names THIS checkout commits or claims under.

        .DESCRIPTION
            THE COMPARISON IS AGAINST THE GIT AUTHOR NAME, NOT THE GITHUB LOGIN, and that is the whole
            reason this is not a one-line -eq at the call site. What the scan reads is '%an' -- what git
            wrote into somebody's commit -- so the only apples-to-apples question is whether THIS
            checkout would have written the same thing. A repo whose user.name is a display name ('Ada
            Lovelace') never matches its own login, so comparing against the login alone would report
            every one of that person's own parked commits as somebody else's.

            BOTH NAMES ARE ACCEPTED for the same reason in the other direction: on a split checkout
            (#1315) the claim is made under the git name, and on an ordinary one the two agree, so a
            match on either is a match. GitHub logins are case-insensitive and a display name typed
            twice is not reliably cased either, so the comparison is too.

            AN EMPTY SELF IS NOT A MATCH, AND NOT A MISMATCH EITHER. With no name to compare against
            there is no question to answer, so this returns $true -- which is the caller's 'say nothing'
            rather than its 'somebody else'. A check that cannot measure must not print a verdict, which
            is the same rule the scan's closing lines have carried since #1853.

        .PARAMETER Author
            The commit's author name, as git wrote it.

        .PARAMETER SelfNames
            The names this checkout answers to -- normally git config user.name and the claiming login.
    #>
    param(
        [string]$Author = '',
        [AllowNull()][string[]]$SelfNames = @()
    )

    $mine = @(@($SelfNames) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
    if ($mine.Count -eq 0) { return $true }
    $them = ([string]$Author).Trim()
    if (-not $them) { return $true }
    foreach ($name in $mine) { if ($them -ieq $name) { return $true } }
    return $false
}

function Get-ContainingBranchNames {
    <#
        .SYNOPSIS
            The branch names in a 'git branch -a --contains <sha>' (or a plain 'git branch -a', same
            output shape -- issue #2018's fifth signal reads every branch off the trunk, not only the
            ones a commit walk resolved) capture, cleaned and with the caller's own refs dropped. An
            EMPTY array when nothing survives.

        .DESCRIPTION
            NAMED FOR ITS FIRST CALLER; SERVES BOTH SHAPES because git prints one branch per line the
            same way whether the command was scoped to a commit or not, and every piece of cleaning
            below (markers, 'remotes/', a symbolic ref, a detached HEAD, the exclusions, the
            local/remote fold) is about the LISTING'S shape, never about how it was scoped. A second
            function repeating this cleaning for the unscoped form would be the exact duplication this
            repo's refactoring rule exists to catch.

            WHAT IT DROPS, AND WHY EACH ONE WOULD BE NOISE:

              - THE MARKERS. '* ' is the checked-out branch and '+ ' is one held by another worktree;
                both are decoration on the name rather than part of it.
              - 'remotes/'. git prints a remote branch as 'remotes/origin/foo' HERE and as 'origin/foo'
                everywhere else in this workflow. The short spelling is the one a reader can paste.
              - A SYMBOLIC REF ('origin/HEAD -> origin/main'). It points at a branch already in the list,
                so keeping it names the same branch twice under a name nobody checks out.
              - A DETACHED HEAD ('(HEAD detached at abc1234)'). Not a branch, and the parenthesis is how
                git says so even where the words inside it are translated.
              - -Exclude, which the caller fills with the trunk and the CURRENT branch. The trunk because
                the log that produced the sha already excluded it, so a match there is not parked work;
                the current branch because on a resume the session's OWN commits name the issue, and
                reporting a session's work back to it as somebody else's is the fastest way to teach it
                to stop reading this warning.
              - A LOCAL BRANCH WHOSE OWN REMOTE-TRACKING TWIN IS ALSO LISTED. `git branch -a --contains`
                names both 'feat/x' and 'origin/feat/x' when a checkout holds a local copy of a parked
                branch, and they are one piece of work, not two -- so counting both would inflate the
                one number this report exists to give ("how many places is this already being worked").
                The REMOTE spelling is the one kept, because it is the address that is true for anybody
                reading over your shoulder; a branch that exists only locally keeps its own name, having
                no twin to fold into.

            SORTED AND DEDUPED, so two runs on one repo print the same line in the same order -- a
            warning a reader cannot diff against the last one is a warning they read once.

        .PARAMETER Text
            The capture, as one string or as the caller's joined line array.

        .PARAMETER Exclude
            Branch names to drop, in the short spelling ('main', 'origin/main', 'fix/x'). Compared
            CASE-SENSITIVELY, because git refs are: 'Main' and 'main' are two branches.
    #>
    param(
        [string]$Text,
        [AllowNull()][string[]]$Exclude = @()
    )

    if (-not $Text -or -not $Text.Trim()) { return @() }
    $drop = @(@($Exclude) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "`r?`n")) {
        $name = ([string]$line).Trim()
        if (-not $name) { continue }
        $name = ($name -replace '^[*+]\s*', '').Trim()
        if (-not $name) { continue }
        if ($name.StartsWith('(')) { continue }
        if ($name -match '\s->\s') { continue }
        if ($name.StartsWith('remotes/')) { $name = $name.Substring('remotes/'.Length).Trim() }
        if (-not $name) { continue }
        if ($drop -ccontains $name) { continue }
        if (-not $names.Contains($name)) { $names.Add($name) | Out-Null }
    }

    # THE LOCAL/REMOTE FOLD, AFTER the whole list is known -- it cannot be decided one line at a time,
    # because git prints the local copy before the remote one and the twin is not yet in hand. Only a
    # 'remotes/' entry can be a twin, which is why the suffix is matched against the cleaned list rather
    # than against the raw text: 'origin/feat/x' folds 'feat/x' away, and a remote called anything else
    # ('upstream/feat/x') folds nothing, because a local branch tracking a second remote is a case this
    # cannot tell apart from two unrelated branches sharing a name.
    $remoteSuffixes = @{}
    foreach ($n in $names) {
        if ($n -match '^origin/(.+)$') { $remoteSuffixes[$Matches[1]] = $true }
    }
    $folded = @($names | Where-Object { -not $remoteSuffixes.ContainsKey($_) })

    return @($folded | Sort-Object)
}

function Get-ForeignParkedCommit {
    <#
        .SYNOPSIS
            The NEWEST of the scanned commits that this checkout did not write, or $null when every one
            of them is its own (or there is nothing to compare against).

        .DESCRIPTION
            THE VERDICT IS ITS OWN FUNCTION BECAUSE TWO CALLERS ASK IT. Format-ParkedFixReport prints
            the block, and claim-issue.ps1 needs the same answer for its closing line -- a run that
            prints 'ASK THEM BEFORE YOU WRITE ANYTHING' and then 'the work starts here' has told the
            reader both things and settled nothing. Deriving it twice, or scraping it back out of the
            printed lines, is how those two would drift apart.

            NEWEST FIRST IS THE CALLER'S ORDER, NOT AN ASSUMPTION MADE HERE. The findings arrive in git
            log's own order, so the first one that fails the self test is the newest that does. Nothing
            is re-sorted: an epoch is a field this function is told, and a commit can carry any date its
            author's machine claimed.

            A FINDING WITH NO SURVIVING BRANCH IS SKIPPED, the same one Format-ParkedFixReport drops --
            a commit whose every branch was excluded is the session's own work, and the verdict must
            agree with the listing about which commits are even in the report.

        .PARAMETER Findings
            The scan's records, newest first.

        .PARAMETER SelfNames
            The names this checkout commits and claims under. Empty means no verdict -- see
            Test-SelfAuthored.
    #>
    param(
        [AllowNull()][object[]]$Findings = @(),
        [AllowNull()][string[]]$SelfNames = @()
    )

    foreach ($f in @($Findings)) {
        if (-not $f -or -not $f.PSObject.Properties['Branches']) { continue }
        $branches = @(@($f.Branches) | Where-Object { $_ })
        if ($branches.Count -eq 0) { continue }
        $author = if ($f.PSObject.Properties['Author']) { ([string]$f.Author).Trim() } else { '' }
        if (Test-SelfAuthored -Author $author -SelfNames $SelfNames) { continue }
        return [pscustomobject]@{
            Sha         = if ($f.PSObject.Properties['Sha']) { [string]$f.Sha } else { '' }
            Author      = $author
            AuthorEpoch = if ($f.PSObject.Properties['AuthorEpoch']) { [long]$f.AuthorEpoch } else { 0L }
            Branch      = [string]$branches[0]
        }
    }
    return $null
}

function Format-ParkedFixReport {
    <#
        .SYNOPSIS
            The warning lines for the off-trunk commits naming this issue. An EMPTY array when there are
            none, which is the caller's signal to print nothing at all.

        .DESCRIPTION
            GROUPED BY BRANCH, BECAUSE THE BRANCH IS WHAT THE READER ACTS ON. A commit-first listing
            repeats the branch name under every commit and buries the one fact that decides what happens
            next -- how many places this issue is already being worked, and which. A commit appearing on
            two branches is listed under both: that is not duplication, it is the answer to "which of
            these do I look at", and both are true.

            A FINDING WHOSE BRANCHES WERE ALL EXCLUDED is dropped HERE rather than printed as a commit
            floating in no branch. The caller hands in what it measured; the decision about what is worth
            saying stays in the half a suite can hold.

            CAPPED AT -MaxCommitsPerBranch, and the cap is what keeps this a warning rather than a wall.
            A branch cut for this issue writes its number into EVERY commit subject -- 'fix(1853): ...'
            is the convention -- so a week-old branch matches thirty times and would push the closing
            advice off the screen it was written for. The overflow line names the count, so nothing is
            silently hidden; the reader who wants all of them has the branch name and one git command.

            EACH COMMIT CARRIES ITS AUTHOR AND ITS AGE, AHEAD OF ITS SUBJECT (#1878). The order is the
            order the decision is made in: which commit, whose, how fresh, and only then what it says.
            The subject comes last because it is the field that misled -- a 'park:' commit is empty by
            design, so a reader told to judge by content reads a live collision as nothing at all.

            AND WHERE THE NEWEST OF THEM IS NOT THIS CHECKOUT'S OWN, THAT IS SAID AS A VERDICT rather
            than left in the listing for a reader to assemble. Chris's own test for a locked door is a
            different account plus a branch that already exists; the second half is the premise of this
            whole scan, so the first half decides it. The verdict is refusal-SHAPED and refuses nothing,
            which is not a hedge but the precision of the measurement: this scan matches any commit
            NAMING the issue, and a colleague mentioning #N in a commit of their own is both ordinary and
            correct. A block there would be wrong far more often than right, and a claim that blocks
            costs the whole assignment (#1485).

            IT SAYS WHAT IT DOES NOT KNOW, in the closing lines, because this check cannot tell a fix
            from a mention and must not sound as though it can. The reader's next act is to look at the
            branch; the warning's whole job is to make that cost one command instead of a whole
            assignment.

            THE STALENESS NOTE IS NOT HERE, deliberately. "I found nothing" and "I could not refresh the
            refs I looked at" are different sentences, and a failed fetch must not be able to read as a
            clean scan -- so the caller prints that one whether or not this returns anything.

        .PARAMETER Issue
            The issue being claimed, for the lead line.

        .PARAMETER Findings
            Records with Sha, Subject, Branches (a string array) and -- since #1878 -- Author and
            AuthorEpoch. Anything else is ignored, and a record missing the two new fields still prints:
            an age this run could not read is stated as unknown rather than guessed at.

        .PARAMETER MaxCommitsPerBranch
            How many commits to list under one branch before the overflow line. Below 1 is treated as 1:
            a branch worth naming is worth one example, and a cap of zero would print a branch with
            nothing under it.

        .PARAMETER SelfNames
            The names this checkout commits and claims under. Empty means the verdict is not attempted,
            because a comparison with nothing to compare against is not evidence of anything.

        .PARAMETER NowEpoch
            The moment to measure the ages against, in Unix seconds. Defaults to now; a caller passes it
            only to make the output reproducible, which is what lets a suite hold these lines.

        .OUTPUTS
            String[] -- the lines in print order, with no colour and no prefix. The caller writes them.
            The verdict block, when there is one, is the LAST thing in it.
    #>
    param(
        [int]$Issue = 0,
        [AllowNull()][object[]]$Findings = @(),
        [int]$MaxCommitsPerBranch = 3,
        [AllowNull()][string[]]$SelfNames = @(),
        [long]$NowEpoch = 0
    )

    $real = @(@($Findings) | Where-Object {
        $_ -and $_.PSObject.Properties['Branches'] -and (@(@($_.Branches) | Where-Object { $_ }).Count -gt 0)
    })
    if ($real.Count -eq 0) { return @() }
    $cap = if ($MaxCommitsPerBranch -lt 1) { 1 } else { $MaxCommitsPerBranch }
    # THE CALLER'S CLOCK, NOT EACH LINE'S. One reading for the whole report, so two commits a second
    # apart cannot print as two different ages, and so a suite can pin it.
    $now = if ($NowEpoch -gt 0) { $NowEpoch } else { [long][System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

    # ORDERED, not a hashtable: PowerShell's plain @{} has no defined key order, so two runs over the
    # same repo would print the same branches in a different sequence and a reader could not diff one
    # warning against the last.
    $byBranch = [ordered]@{}
    $foreign = Get-ForeignParkedCommit -Findings $real -SelfNames $SelfNames
    foreach ($f in $real) {
        $sha = ([string]$f.Sha)
        $short = if ($sha.Length -gt 8) { $sha.Substring(0, 8) } else { $sha }
        $subject = if ($f.PSObject.Properties['Subject']) { ([string]$f.Subject).Trim() } else { '' }
        $author = if ($f.PSObject.Properties['Author']) { ([string]$f.Author).Trim() } else { '' }
        $epoch = if ($f.PSObject.Properties['AuthorEpoch']) { [long]$f.AuthorEpoch } else { 0L }
        $who = if ($author) { $author } else { 'author unknown' }
        $when = if ($epoch -gt 0) { Format-CommitAge -Seconds ($now - $epoch) } else { 'at an unknown time' }
        foreach ($branch in @(@($f.Branches) | Where-Object { $_ })) {
            $key = [string]$branch
            if (-not $byBranch.Contains($key)) { $byBranch[$key] = (New-Object System.Collections.Generic.List[string]) }
            # ATTRIBUTION AHEAD OF SUBJECT (#1878) -- see the description. Who and when decide what
            # happens next; the subject is the field that read as empty while a colleague was mid-flight.
            $tail = if ($subject) { " -- $subject" } else { '' }
            $byBranch[$key].Add("$short  $who, $when$tail".TrimEnd()) | Out-Null
        }
    }

    $branchNames = @($byBranch.Keys | Sort-Object)
    $lines = New-Object System.Collections.Generic.List[string]
    $commitWord = if ($real.Count -eq 1) { 'commit' } else { 'commits' }
    $branchWord = if ($branchNames.Count -eq 1) { 'branch' } else { 'branches' }
    $lines.Add("parked-fix scan: #$Issue is named by $($real.Count) $commitWord on $($branchNames.Count) $branchWord off the trunk --") | Out-Null
    foreach ($branch in $branchNames) {
        $commits = @($byBranch[$branch])
        $lines.Add("  $branch") | Out-Null
        foreach ($c in @($commits | Select-Object -First $cap)) { $lines.Add("      $c") | Out-Null }
        if ($commits.Count -gt $cap) { $lines.Add("      ... and $($commits.Count - $cap) more naming #$Issue") | Out-Null }
    }
    $lines.Add('  A branch with no pull request is invisible to every other pickup check, so READ THOSE') | Out-Null
    $lines.Add('  COMMITS before you write anything. This cannot tell a fix from a mention and does not') | Out-Null
    $lines.Add('  claim to -- the claim stands either way.') | Out-Null
    if ($foreign) {
        $foreignWhen = if ($foreign.AuthorEpoch -gt 0) { Format-CommitAge -Seconds ($now - [long]$foreign.AuthorEpoch) } else { 'at an unknown time' }
        $lines.Add('') | Out-Null
        $lines.Add("  NOT YOURS: the newest of those commits was written by '$($foreign.Author)', $foreignWhen, on") | Out-Null
        $lines.Add("  $($foreign.Branch)") | Out-Null
        $lines.Add('  That is the locked-door shape -- a different account, and a branch that already exists --') | Out-Null
        $lines.Add('  reaching you through the branch instead of through the assignee field, where nothing would') | Out-Null
        $lines.Add('  have reported it. ASK THEM BEFORE YOU WRITE ANYTHING.') | Out-Null
        $lines.Add('  Do NOT settle this by reading the commit: a park commit is empty by design, so its') | Out-Null
        $lines.Add('  content is the one thing that cannot tell you whether somebody is mid-flight.') | Out-Null
    }
    return @($lines)
}

# --- THE FIFTH PICKUP SIGNAL: A BRANCH NAMED FOR THE SUBJECT, NOT THE NUMBER (issue #2018) --------
#
# THE FOURTH SIGNAL ABOVE STILL READS 'UNTOUCHED' IN ONE SHAPE: a branch cut for the subject rather
# than the number. new-branch.ps1's own creation commit is 'park: <branch> (the branch files only)',
# which names the BRANCH and nothing else -- so a branch called 'fix/asana-stage-letter-codes' writes
# none of the three spellings Get-IssueMentionPattern looks for, on any commit it ever carries, however
# many more it grows. Measured September 15, 2026: claiming #2016 read clean -- open, unassigned, no
# rival PR, the fourth-signal scan silent -- while origin/fix/asana-stage-letter-codes already carried
# a parked, independent implementation of the same repair. Every one of the four signals above misses
# this by construction, because all four read either the tracker or a commit's CONTENT, and this
# branch's only trace of the issue is its own NAME.
#
# SO THE FIFTH SIGNAL IS THE ISSUE'S OWN TITLE, matched against every branch name off the trunk rather
# than against commit messages naming a number. It is weaker evidence than the fourth signal and is
# worded as such: a shared word is a coincidence a numbered mention cannot be, so this never joins the
# fourth signal's 'NOT YOURS' verdict and never sets $foreignParked -- it prints its own, separately
# hedged block. #2018's own text: "the scan's warn-never-refuse shape is unchanged: a name collision is
# weaker evidence than a number, not stronger."

function Get-SignificantWords {
    <#
        .SYNOPSIS
            The lowercase, deduplicated SIGNIFICANT words in a piece of free text -- an issue title or
            a branch's own slug -- for the title/branch-name overlap check (issue #2018). An EMPTY
            array for text with none.

        .DESCRIPTION
            THREE FILTERS, EACH THERE BECAUSE THE UNFILTERED FORM WAS MEASURED TOO NOISY TO USE
            (below). A word is kept only if it is at least $MinLength characters, is not on the
            built-in stop list of short/structural English words ('with', 'that', 'still', ...), and
            is not purely digits -- an issue number belongs to the fourth signal above, not this one,
            and letting it in here would have this scan rediscover exactly what that scan already
            reports, under a weaker verdict.

            SPLIT ON CAMELCASE TOO, not only on non-alphanumeric runs. An issue title routinely quotes
            an identifier verbatim -- 'Get-StageFromSectionName', 'AsanaStageMap' -- and a branch name
            never does (branch names are kebab-case by convention). Splitting only on punctuation would
            leave 'stagefromsectionname' as one token that can never match the branch words 'stage',
            'from', 'section', 'name' it was built out of; splitting the camelCase boundary first is
            what lets the two sides describe the same word the same way.

            THE THRESHOLD WAS MEASURED, NOT GUESSED (closing #2018's own "not measured" note). Run
            against this repo's branch history -- 21 branches off the trunk, matched against the 21
            issue titles behind them, 462 comparisons in total (scripts/tests/claim-issue.tests.ps1
            pins the corpus) -- with $MinLength at 4 and this stop list:

              MinSharedWords  self-hits (a branch vs. its OWN issue)  other cross-hits
                    1                        19                             27
                    2                        14                              3
                    3                         7                              0 (misses the real case too)

            2 is Get-TitleOverlapBranches' default for exactly this reason: it is the point where the
            three remaining cross-hits are themselves genuinely related work sharing a real word
            ('exit'+'code' between two exit-code issues, 'prio'+'labels' between two priority-label
            issues, 'update'+'plugins' between two update-plugins issues) rather than coincidence, and
            it is the last threshold that still catches the branch #2018 itself was measured against.

        .PARAMETER Text
            The free text to tokenize -- an issue title, or a branch's slug with its separators turned
            to spaces.

        .PARAMETER MinLength
            The shortest word kept, in characters. Below 4, common short words ('the', 'for', 'and')
            stop being filtered by the stop list alone and start matching by coincidence; 4 is what the
            measurement above was run at.
    #>
    param(
        [string]$Text = '',
        [int]$MinLength = 4
    )

    if (-not $Text -or -not $Text.Trim()) { return @() }

    # THE STOP LIST IS SHORT WORDS AND STRUCTURAL ENGLISH, NOT A GENERAL DICTIONARY. It exists to keep
    # sentence glue ('with', 'that', 'still') from being treated as a shared SUBJECT between two titles
    # that happen to both be sentences. It is not a grammar model and does not try to be one; the
    # $MinLength and $MinSharedWords floors below do the rest of the filtering the measurement needed.
    $stop = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            'this','that','with','from','into','onto','over','under','also','only','both','each',
            'every','once','here','there','than','then','which','whose','does','doesnt','have',
            'about','off','again','further','more','most','other','some','such','same','very','will',
            'just','dont','your','their','them','they','while','after','before','still','and',
            'the','for','are','was','were','been','being','when','what','who','how','why','its','not',
            'nor','own','too','can','all','any','because','across','per'
        ),
        [System.StringComparer]::OrdinalIgnoreCase
    )

    # CAMELCASE SPLIT BEFORE PUNCTUATION SPLIT (see DESCRIPTION): a lower-to-upper transition ('eName')
    # and the end of an acronym run ('URLRecord' -> 'URL Record') both become a space, so 'StageMap'
    # and 'stage-map' tokenize to the same two words.
    $spaced = [regex]::Replace($Text, '([a-z0-9])([A-Z])', '$1 $2')
    $spaced = [regex]::Replace($spaced, '([A-Z]+)([A-Z][a-z])', '$1 $2')

    $words = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($part in ($spaced -split '[^A-Za-z0-9]+')) {
        if (-not $part) { continue }
        $word = $part.ToLowerInvariant()
        if ($word.Length -lt $MinLength) { continue }
        if ($word -match '^[0-9]+$') { continue }
        if ($stop.Contains($word)) { continue }
        if ($seen.Add($word)) { $words.Add($word) | Out-Null }
    }
    return @($words)
}

function Get-BranchSlugWords {
    <#
        .SYNOPSIS
            A branch name's SIGNIFICANT words, with its type prefix and any leading issue number
            stripped first. An EMPTY array for a branch whose slug carries none.

        .DESCRIPTION
            THE PREFIX AND THE NUMBER ARE STRIPPED BEFORE TOKENIZING because neither describes the
            SUBJECT: 'fix/2016-compound-stage-code' and 'fix/asana-stage-letter-codes' should score
            identically against issue #2016's title, and a leading '2016' would not match a title's
            words anyway (Get-SignificantWords already drops pure-digit tokens) while the type prefix
            ('fix', 'feat', 'docs') is this workflow's own vocabulary, not the branch author's -- every
            branch has one, so leaving it in would inflate every comparison by one word nobody chose.

        .PARAMETER Branch
            The branch name, in the short form ('fix/2016-compound-stage-code' or
            'fix/asana-stage-letter-codes').
    #>
    param([string]$Branch = '')

    if (-not $Branch) { return @() }
    $slug = $Branch
    $slashIndex = $slug.IndexOf('/')
    if ($slashIndex -ge 0) { $slug = $slug.Substring($slashIndex + 1) }
    $slug = [regex]::Replace($slug, '^[0-9]+-', '')
    return @(Get-SignificantWords -Text ($slug -replace '[-_]', ' '))
}

function Get-TitleOverlapBranches {
    <#
        .SYNOPSIS
            The branches, from $Branches, whose OWN NAME shares at least $MinSharedWords significant
            words with $Title -- records with Branch and SharedWords (sorted). An EMPTY array when the
            title has no significant words, or none of the branches reach the threshold.

        .DESCRIPTION
            PURE, LIKE THE FOURTH SIGNAL'S OWN Get-ForeignParkedCommit -- this takes names in and
            returns a verdict, so the corpus measurement behind $MinSharedWords's default (2, see
            Get-SignificantWords) is something a suite can pin rather than something that only shows
            up as console noise on a live repo.

            $Branches IS EVERY BRANCH OFF THE TRUNK, not only the ones the fourth signal's commit scan
            already resolved -- that is the entire point: a branch this check exists for has NO commit
            naming the issue, so it never reaches that scan's containment loop at all. The caller
            builds $Branches from a plain 'git branch -a', cleaned the same way the fourth signal
            cleans its own 'git branch -a --contains' capture (Get-ContainingBranchNames serves both
            shapes -- see its own SYNOPSIS).

            SORTED BY BRANCH NAME, so two runs over an unchanged repo print the same order -- the same
            reason Format-ParkedFixReport sorts its own branch keys.

        .PARAMETER Title
            The issue's title, exactly as the tracker returned it.

        .PARAMETER Branches
            Branch names off the trunk, already cleaned and deduped (short form, no 'remotes/', no
            marker).

        .PARAMETER MinSharedWords
            The floor for a match. Measured at 2 (see Get-SignificantWords); below 1 is treated as 1,
            because a floor of 0 would match every branch against every title with any word in common
            with the trunk's own vocabulary.
    #>
    param(
        [string]$Title = '',
        [AllowNull()][string[]]$Branches = @(),
        [int]$MinSharedWords = 2
    )

    $titleWords = @(Get-SignificantWords -Text $Title)
    if ($titleWords.Count -eq 0) { return @() }
    $floor = if ($MinSharedWords -lt 1) { 1 } else { $MinSharedWords }
    $titleSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$titleWords, [System.StringComparer]::OrdinalIgnoreCase)

    $results = New-Object System.Collections.Generic.List[psobject]
    foreach ($branch in @(@($Branches) | Where-Object { $_ -and ([string]$_).Trim() })) {
        $branchWords = @(Get-BranchSlugWords -Branch ([string]$branch))
        $shared = @($branchWords | Where-Object { $titleSet.Contains($_) })
        if ($shared.Count -ge $floor) {
            $results.Add([pscustomobject]@{ Branch = [string]$branch; SharedWords = @($shared | Sort-Object) }) | Out-Null
        }
    }
    return @($results | Sort-Object -Property Branch)
}

function Format-TitleOverlapReport {
    <#
        .SYNOPSIS
            The warning lines for branches off the trunk whose NAME shares words with this issue's
            title even though no commit on them names its NUMBER (issue #2018). An EMPTY array when
            there is nothing to say.

        .DESCRIPTION
            NEVER FOLDED INTO THE FOURTH SIGNAL'S VERDICT, deliberately. Format-ParkedFixReport's
            'NOT YOURS' block and this one report two different strengths of evidence -- a number in a
            commit message versus a word shared with a title -- and #2018's own text is explicit that
            widening the fourth signal to catch this case is "not the fix": "a name collision is weaker
            evidence than a number, not stronger." So this prints its own block, under its own hedges,
            and never sets the caller's $foreignParked.

            IT SAYS WHAT IT CANNOT TELL, same shape as Format-ParkedFixReport's own closing lines: a
            shared word is not proof of the same subject, only a reason to look before writing.

        .PARAMETER Issue
            The issue being claimed, for the lead line.

        .PARAMETER Title
            The issue's title, for context -- not printed verbatim here (the caller already printed it
            once, at claim time); kept as a parameter so a future caller printing this block on its own
            is not left to re-fetch it.

        .PARAMETER Overlaps
            Records from Get-TitleOverlapBranches: Branch and SharedWords.
    #>
    param(
        [int]$Issue = 0,
        [string]$Title = '',
        [AllowNull()][object[]]$Overlaps = @()
    )

    $real = @(@($Overlaps) | Where-Object { $_ -and $_.PSObject.Properties['Branch'] -and ([string]$_.Branch).Trim() })
    if ($real.Count -eq 0) { return @() }

    $lines = New-Object System.Collections.Generic.List[string]
    # THE NOUN, THE VERB AND THE PRONOUN SWITCH TOGETHER (issue #2070). Only $branchWord did, so the
    # two words agreeing with it stayed at the plural and the SINGULAR case -- the common one, and the
    # one #2018 itself measured -- printed '1 branch ... share words ... though no commit on them'. The
    # fourth signal's neighbouring lead line switches every word its counts govern ($commitWord,
    # $branchWord), which is what made this one read as unfinished rather than as house style. It is
    # the FIRST line of a warning whose whole argument is that the reader should go and look before
    # writing anything, and it is shipped plugin payload -- a consumer reads it with nothing to compare
    # it against.
    $isOne = ($real.Count -eq 1)
    $branchWord = if ($isOne) { 'branch' } else { 'branches' }
    $shareWord = if ($isOne) { 'shares' } else { 'share' }
    $themWord = if ($isOne) { 'it' } else { 'them' }
    $lines.Add("title-overlap scan: $($real.Count) $branchWord off the trunk $shareWord words with #$Issue's title, though no commit on") | Out-Null
    $lines.Add("  $themWord names the number --") | Out-Null
    foreach ($o in $real) {
        $words = @($o.SharedWords) -join ', '
        $lines.Add("  $($o.Branch)  -- shares: $words") | Out-Null
    }
    $lines.Add('  A SHARED WORD IS NOT A MATCHED NUMBER: this cannot tell "about the same thing" from') | Out-Null
    $lines.Add('  "happens to use the same word", so read the branch before you write anything, and') | Out-Null
    $lines.Add('  before you dismiss this.') | Out-Null
    return @($lines)
}

# --- THE SIXTH PICKUP SIGNAL: A SURFACED BRANCH MAY BE A PREREQUISITE, NOT A COMPETITOR (#2064) ----
#
# THE FIVE SIGNALS ABOVE ALL ASK ONE QUESTION, in five ways: is somebody else mid-flight on this work?
# State, assignees, a pull request, a commit naming the number, a branch named for the subject -- every
# one of them is about OWNERSHIP, and the fourth signal's verdict says so in as many words: ASK THEM
# BEFORE YOU WRITE ANYTHING.
#
# A BRANCH CAN BE IN YOUR WAY WITHOUT BEING A RIVAL. Measured September 16, 2026 (#2064): picking up
# #2051, the fourth signal found origin/fix/2048-closeout-repair-strategy and printed the ownership
# verdict. Read, that verdict dissolved -- the commit MENTIONED #2051 because it filed it, which this
# lib's own text calls "both ordinary and correct". What nothing named was the fact that mattered:
# #2051's subject, scripts/maintenance/measure-closeouts.ps1, existed ONLY on that branch. Every route
# to the issue ran through that branch landing first, so the real choice was to ship somebody else's
# parked branch, stack their 29 commits under this PR, or stop -- a blocking question for the owner,
# and not the question the verdict asked.
#
# WHY NO OTHER CHECK CAN CATCH IT. triage-inbound's "the subject does not exist" (#660) is about a name
# that names NOTHING; a subject sitting on an unmerged branch greps, opens, and has history, so it
# reads as present to every check while blocking the work exactly as hard as absence. And
# Get-TargetIssueWarnings resolves an issue to a pull request, which a parked branch has none of by
# design -- the same blind spot #1853 measured one axis over.
#
# TWO MEASUREMENTS, AND THE SECOND IS THE DECISIVE ONE. The WEIGHT of a surfaced branch -- how far
# ahead of the trunk it is -- separates 29 commits of unlanded work from a one-commit stray mention,
# which print as the same line today. The OVERLAP -- a path the issue's own text cites that is absent
# from the trunk and present on that branch -- is what turns "may be a prerequisite" into "is one".
#
# IT WEIGHS ONLY WHAT THE SCANS ABOVE ALREADY SURFACED, so a claim those two are silent about pays
# nothing at all, which is the ordinary run.

function Get-IssuePathCitations {
    <#
        .SYNOPSIS
            The repo-relative file paths an issue's own text cites -- deduped, in the order they first
            appear, capped at -MaxPaths. An EMPTY array when it cites none.

        .DESCRIPTION
            TOKENS, NOT ONE BIG REGEX OVER THE PROSE. The text is split on whitespace and on the
            characters that wrap a path in a body -- backticks, quotes, brackets, parentheses -- and
            each token is then tested whole. The anchored test is what keeps 'scripts/foo.bar.ps1' from
            being read as 'scripts/foo.bar', which is what an unanchored scan does with the very
            filenames this repo writes.

            A PATH NEEDS A DIRECTORY AND AN EXTENSION. Requiring the slash is what keeps an ordinary
            English sentence out of the result; requiring the extension is what keeps
            'DKJ-Solutions/dkj-claude-plugins' -- an owner/name citation, not a file -- out of it. The
            cost is stated rather than hidden: a file cited bare at the repo root ('README.md') is not
            collected, because nothing distinguishes it from a word with a full stop after it.

            URLS ARE STRIPPED BEFORE ANY OF THAT. A GitHub link carries a path-shaped tail
            ('.../blob/main/scripts/task/claim-issue.ps1') that would otherwise be collected and then
            tested against a tree it does not belong to -- and an issue body in this family is mostly
            links.

            THE BODY IS UNTRUSTED TEXT -- anybody who can open an issue writes it. The character class
            here is the bound: what comes out carries only [A-Za-z0-9_.-] and slashes, so nothing
            reaching a git argument list can hold an option-looking prefix, a newline or a quote. A
            leading '-' is refused for exactly that reason, '..' because a path escaping the tree is
            not a citation of it, and -MaxPaths because a body is as long as somebody cares to make it.

        .PARAMETER Text
            The issue body, as the tracker returned it.

        .PARAMETER MaxPaths
            How many distinct paths to collect. Below 1 is treated as 1. The caller spends one git read
            per BRANCH only for the paths the trunk turns out to lack, but the first read passes every
            path at once, and an unbounded argument list is the thing that breaks rather than slows.

        .OUTPUTS
            String[] -- repo-relative paths, forward slashes, first-seen order.
    #>
    param(
        [AllowNull()][string]$Text = '',
        [int]$MaxPaths = 8
    )

    if (-not $Text) { return @() }
    $cap = if ($MaxPaths -lt 1) { 1 } else { $MaxPaths }

    # Scheme-relative ('//host/...') as well as 'https://', because both are links and neither is a
    # path in this tree.
    $stripped = [regex]::Replace([string]$Text, '(?i)(?:[a-z][a-z0-9+.-]*:)?//\S+', ' ')

    $results = New-Object System.Collections.Generic.List[string]
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($raw in ([regex]::Split($stripped, '[\s`"()\[\]{}<>,;:|*'']+'))) {
        if (-not $raw) { continue }
        # Sentence punctuation clings to a path in prose. Trimmed AFTER the split, because '.' is also
        # the character the extension test needs and the split must not eat it mid-token.
        $token = ([string]$raw).Trim().TrimEnd('.', '!', '?')
        if (-not $token -or $token.Length -gt 200) { continue }
        if ($token.StartsWith('-') -or $token.StartsWith('/')) { continue }
        if ($token.Contains('..')) { continue }
        if ($token -notmatch '^(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9]{1,6}$') { continue }
        if ($seen.Add($token)) {
            $results.Add($token) | Out-Null
            if ($results.Count -ge $cap) { break }
        }
    }
    return @($results)
}

function Get-LsTreePaths {
    <#
        .SYNOPSIS
            The paths in a `git ls-tree` capture -- the field after the TAB on each entry line. An
            EMPTY array for empty or unrecognisable output.

        .DESCRIPTION
            THE PARSE IS ITS OWN FUNCTION BECAUSE THE PARSE IS WHERE THE TRAP IS, the same reasoning
            ConvertFrom-CommitScanLog carries two signals up. ls-tree answers by OMISSION: a pathspec
            that is not in the tree simply does not appear, and the exit code is 0 either way -- so the
            caller's whole verdict is "which of the paths I asked for came back", and reading that off
            the text is the half a suite can hold.

            THE TAB IS THE ONLY SEPARATOR THAT COUNTS. Everything before it is mode, type and sha,
            separated by spaces; the path follows the tab and may itself contain spaces. Splitting on
            whitespace would truncate exactly the paths that are hardest to notice going wrong.

            A QUOTED PATH IS UNQUOTED, not skipped. git quotes an entry containing a special character,
            which no path Get-IssuePathCitations can produce ever needs -- but a path that came back and
            was read as absent is the one error this function must not make, so the quotes come off and
            the value stands.

        .PARAMETER Text
            The raw capture, newline-joined.

        .OUTPUTS
            String[] -- one path per entry line, in git's own order.
    #>
    param([AllowNull()][string]$Text = '')

    if (-not $Text) { return @() }
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($line in ([string]$Text -split "`r?`n")) {
        if (-not $line) { continue }
        $tab = $line.IndexOf("`t")
        if ($tab -lt 0) { continue }
        $path = $line.Substring($tab + 1).Trim()
        if (-not $path) { continue }
        if ($path.Length -gt 1 -and $path.StartsWith('"') -and $path.EndsWith('"')) {
            $path = $path.Substring(1, $path.Length - 2)
        }
        $paths.Add($path) | Out-Null
    }
    return @($paths)
}

function Format-PrerequisiteReport {
    <#
        .SYNOPSIS
            The lines weighing the branches the scans above surfaced, and naming any that carries a
            path this issue cites and the trunk does not. An EMPTY array when nothing was surfaced,
            which is the caller's signal to print nothing at all.

        .DESCRIPTION
            IT PRINTS EVEN WHEN IT FINDS NO DEPENDENCY, unlike the two reports above it, and that is
            the point rather than an oversight. The weight is the cheap half and it is never nothing: a
            branch 29 commits ahead and a branch carrying one stray mention print as the same line in
            the fourth signal's listing, and #2064's whole cost was working out which of the two was in
            front of it.

            THREE ENDINGS, AND EACH SAYS WHAT THIS RUN ACTUALLY ASKED. A prerequisite found; every
            cited path already on the trunk; or a body citing no path at all, where the overlap
            question could not be asked and the weight is all there is. Collapsing the last two --
            printing "not a dependency" where nothing was tested -- is the failure this signal exists to
            remove, one layer in: a check that cannot tell silence from a clean answer teaches a reader
            to trust the wrong one.

            ADVISORY, LIKE EVERY SIGNAL IN THIS FAMILY. A path missing from the trunk is strong evidence
            and still not proof of an ordering: the branch may be about to be abandoned, the file may be
            about to move, and the issue may be repairable without it. A claim that blocks costs the
            whole assignment (#1485), so this names the question and hands it over. Where it is a real
            dependency the decision is the owner's -- shipping somebody else's parked branch first is
            not a call a pickup check gets to make.

        .PARAMETER Issue
            The issue being claimed, for the lead line and the verdict.

        .PARAMETER Branches
            Records with Branch, Ahead (commits ahead of the trunk; -1 where it could not be read) and
            OnlyThere (the cited paths present there and absent from the trunk).

        .PARAMETER CitedPathCount
            How many paths the issue's text cited -- 0 meaning the overlap question was never asked.
            Passed rather than derived from OnlyThere, because "cited nothing" and "cited paths that are
            all on the trunk" are the two endings that must not read alike.

        .PARAMETER TrunkLabel
            The ref the weights were measured against, named in full: a reader who sees '29 commits
            ahead' with no ref cannot tell whether a stale local trunk inflated it.

        .PARAMETER MaxPathsPerBranch
            How many paths to list under one branch before the overflow line. Below 1 is treated as 1.

        .OUTPUTS
            String[] -- the lines in print order, no colour and no prefix. The caller writes them.
    #>
    param(
        [int]$Issue = 0,
        [AllowNull()][object[]]$Branches = @(),
        [int]$CitedPathCount = 0,
        [string]$TrunkLabel = 'the trunk',
        [int]$MaxPathsPerBranch = 4
    )

    $real = @(@($Branches) | Where-Object { $_ -and $_.PSObject.Properties['Branch'] -and ([string]$_.Branch).Trim() })
    if ($real.Count -eq 0) { return @() }
    $cap = if ($MaxPathsPerBranch -lt 1) { 1 } else { $MaxPathsPerBranch }
    $trunk = if ([string]$TrunkLabel) { [string]$TrunkLabel } else { 'the trunk' }

    $withPaths = @($real | Where-Object {
        $_.PSObject.Properties['OnlyThere'] -and (@(@($_.OnlyThere) | Where-Object { $_ }).Count -gt 0)
    })

    $lines = New-Object System.Collections.Generic.List[string]
    # SINGULAR AND PLURAL ARE BOTH WRITTEN OUT rather than hung off a count and an 's'. These lines are
    # the ones a reader acts on, and 'all 1 path names is' is the register in which a check stops being
    # believed -- the same reason Format-CommitAge spells its own units instead of printing a number.
    $branchWord = if ($real.Count -eq 1) { 'branch' } else { 'branches' }
    $branchPhrase = if ($real.Count -eq 1) { 'the branch named above' } else { "the $($real.Count) branches named above" }
    $lines.Add("branch-weight scan: $branchPhrase, measured against $trunk --") | Out-Null
    foreach ($b in $real) {
        $ahead = if ($b.PSObject.Properties['Ahead']) { [int]$b.Ahead } else { -1 }
        $weight = if ($ahead -lt 0) { 'ahead count unreadable' }
                  elseif ($ahead -eq 0) { "0 commits ahead -- already on $trunk" }
                  elseif ($ahead -eq 1) { '1 commit ahead' }
                  else { "$ahead commits ahead" }
        $lines.Add("  $([string]$b.Branch)  -- $weight") | Out-Null
        $only = @(@($b.OnlyThere) | Where-Object { $_ })
        foreach ($p in @($only | Select-Object -First $cap)) {
            $lines.Add("      $p  -- here, and NOT on $trunk") | Out-Null
        }
        if ($only.Count -gt $cap) {
            $lines.Add("      ... and $($only.Count - $cap) more that $trunk does not carry") | Out-Null
        }
    }

    $lines.Add('') | Out-Null
    if ($withPaths.Count -gt 0) {
        # AGREEMENT HERE TOO, and this ending is the one that most needs it: more than one branch can
        # carry a missing path, and one branch can carry several. DISTINCT paths, because the same file
        # sitting on two branches is one file the trunk lacks, not two.
        $prereqPaths = @($withPaths | ForEach-Object { @(@($_.OnlyThere) | Where-Object { $_ }) } | Select-Object -Unique)
        $filePhrase = if ($prereqPaths.Count -eq 1) { 'a file that exists' } else { "$($prereqPaths.Count) files that exist" }
        $wherePhrase = if ($withPaths.Count -eq 1) { 'a branch above' } else { "$($withPaths.Count) branches above" }
        $thosePhrase = if ($withPaths.Count -eq 1) { 'that branch' } else { 'those branches' }
        $lines.Add("PREREQUISITE, NOT A COMPETITOR: #$Issue names $filePhrase only on $wherePhrase, so every") | Out-Null
        $lines.Add("route to this issue runs through $thosePhrase landing first. The ownership verdict asks") | Out-Null
        $lines.Add('whether somebody is mid-flight on the same work; this asks whether YOUR route runs through') | Out-Null
        $lines.Add('theirs, and the two have different answers -- a branch you have to build ON is not a branch') | Out-Null
        $lines.Add('you are racing.') | Out-Null
        $lines.Add("That ordering is the OWNER'S call, not this check's and not yours: shipping their parked") | Out-Null
        $lines.Add('branch first, stacking your work on top of it, and waiting are three answers with three') | Out-Null
        $lines.Add('different costs. ASK BEFORE YOU BUILD ON IT OR AROUND IT.') | Out-Null
    }
    elseif ($CitedPathCount -gt 0) {
        $pathPhrase = if ($CitedPathCount -eq 1) { "the one path #$Issue names is" } else { "all $CitedPathCount paths #$Issue names are" }
        $themIt = if ($real.Count -eq 1) { 'it as a collision' } else { 'them as collisions' }
        $lines.Add("Not a dependency, as far as this can see: $pathPhrase already on $trunk, so your") | Out-Null
        $lines.Add("route to this issue does not run through the $branchWord above -- read $themIt,") | Out-Null
        $lines.Add('which is what the verdicts above are for. A branch far ahead is still a body of unlanded') | Out-Null
        $lines.Add('work, and this tested only the files the issue itself names.') | Out-Null
    }
    else {
        $lines.Add("The weight is all this can say: #$Issue's own text cites no file path, so there was nothing to") | Out-Null
        $lines.Add("hold against $trunk and the overlap question was never asked. A branch far ahead is a body of") | Out-Null
        $lines.Add('unlanded work rather than a stray mention -- whether YOUR route runs through it is the') | Out-Null
        $lines.Add('question, and this run could not ask it.') | Out-Null
    }
    return @($lines)
}
