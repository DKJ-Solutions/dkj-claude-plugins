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

# --- THE CLAIM TAG -- A SECOND CLAIM PRIMITIVE, FOR A SWEEP (issue #2243) -------------------------
#
# EVERYTHING ABOVE CLAIMS BY WRITING AN ASSIGNEE, AND THAT IS THE RIGHT CLAIM FOR ONE SESSION PICKING
# UP ONE ISSUE. It stops being the right one the moment SEVERAL MACHINES work one backlog at once,
# which is what a sweep is, and it fails on both halves:
#
#   THE WRITE CANNOT NAME THE MACHINE. Two checkouts authenticated as the same account write the same
#   assignee, and neither can tell its own claim from the other's afterwards. The orchestrator body
#   names this case in so many words -- "where both sessions run under one account the assignee cannot
#   name the machine" -- and a sweep is exactly where it stops being hypothetical: three accounts over
#   six machines means two machines share a name by construction.
#
#   AND THE READ REFUSES WORK THAT IS FREE. Get-ClaimVerdict's 'taken' is correct for a pickup and
#   wrong for a sweep: an assignee put on an issue months ago by the colleague who owns the ticket is
#   not a worker mid-flight. Measured on the BWJ board, September 17, 2026: three of fourteen open
#   issues carried such a name, and a claim test reading the assignee would have skipped those three
#   for good while they were the ordinary work of that round.
#
# SO THE SWEEP CLAIMS WITH A TAG: 'hostname/account', written as a MARKER COMMENT on the issue. The
# hostname names the machine, the account names who a second session reads as the comment's author, and
# the pair is what neither half is alone -- measured September 17, 2026 (#701): two accounts shared the
# hostname DAVE-KOK-BWJ, and two machines shared the hostname DAVE under different accounts, so three
# sessions of that round produced an identical or ambiguous string from the hostname alone.
#
# THE ASSIGNEE IS STILL WRITTEN BESIDE IT. It is what the tracker's own views show, and a sweep that
# left every issue unassigned would read as an untouched backlog to anybody not reading comments. It is
# the SUPPLEMENT here rather than the claim, which is the whole inversion this section carries.
#
# AND THE WORD 'LANE' IS DELIBERATELY NOT USED. It already means a git worktree in this workflow
# (worktree-lane), and a sweep's tag is not a worktree: one machine sweeping serially has one checkout
# and many tags over time. The prompt this replaces called it a lane, which is the collision.

function Get-ClaimTag {
    <#
        .SYNOPSIS
            The tag this session claims under -- 'hostname/account' -- or an incomplete record saying
            which half is missing.

        .DESCRIPTION
            BOTH HALVES OR NOTHING, and the refusal that follows from an incomplete tag is the point.
            A tag missing its account is the ambiguous string #701 measured; a tag missing its hostname
            cannot tell two machines apart under one login. Either way the safe answer is to refuse the
            claim rather than to write a string that reads like a claim and settles nothing.

            THE ACCOUNT HALF IS THE GH ACCOUNT, NOT THE GIT NAME, and this is the one place in this lib
            where the two diverge on purpose. Resolve-ClaimAccount answers "who should own this issue"
            and picks the git name, because the commits are the half nothing can rewrite. This answers
            "what will another session read as the AUTHOR of my comment", and gh writes the comment as
            the gh account -- so a tag carrying the git name on a split checkout would disagree with the
            metadata beside it, which is the ambiguity the tag exists to remove.

            THE COMPARISON IS CASE-INSENSITIVE AND THE STORED FORM IS AS READ. A hostname arrives from
            the environment in whatever case that machine reports, and normalising it to one case would
            make a tag written by an older session unrecognisable to a newer one.

        .PARAMETER MachineName
            The machine name -- $env:COMPUTERNAME on Windows, `hostname` elsewhere. '' when unknown.

        .PARAMETER Account
            The account gh acts as (Get-ActiveGhAccount). '' when gh is absent or logged out.

        .OUTPUTS
            Tag         -- 'machine/account', or '' when either half is missing.
            MachineName -- as read, trimmed.
            Account     -- as read, trimmed.
            Complete    -- $true when both halves are present.
            Missing     -- 'none' | 'machine' | 'account' | 'both'.
    #>
    param(
        [string]$MachineName = '',
        [string]$Account = ''
    )

    $machine = if ($MachineName) { $MachineName.Trim() } else { '' }
    $acct    = if ($Account) { $Account.Trim() } else { '' }

    # A half carrying the separator would split into a tag that parses back as something else, so it is
    # treated as unusable rather than silently rewritten -- the same argument as the missing halves
    # above, one character further in.
    if ($machine -match '/') { $machine = '' }
    if ($acct -match '/')    { $acct = '' }

    $missing = if (-not $machine -and -not $acct) { 'both' }
               elseif (-not $machine) { 'machine' }
               elseif (-not $acct) { 'account' }
               else { 'none' }

    [pscustomobject]@{
        Tag         = if ($missing -eq 'none') { "$machine/$acct" } else { '' }
        MachineName = $machine
        Account     = $acct
        Complete    = ($missing -eq 'none')
        Missing     = $missing
    }
}

function Split-CommaListArgument {
    <#
        .SYNOPSIS
            Turn whatever a caller passed for a list parameter into a clean list of values.

        .DESCRIPTION
            IT SPLITS ON ',' AND THAT SPLIT IS THE POINT, not the [string[]] parameter it sits behind
            (#2358). The documented route runs through powershell.exe -File, and -File binds its
            arguments as LITERAL strings -- so -Marker claim-tag,xoxo-lane arrives as ONE element
            'claim-tag,xoxo-lane' even though the parameter is declared an array. The same -File lesson
            Get-NormalizedPaths (market-urls.ps1) already carries: declaring the array is necessary and
            NOT sufficient.

            Every list this script takes -- marker names, labels, issue numbers -- has no legitimate
            comma inside one value, so the split cannot cut a real value in two. Blanks are dropped and
            a value given twice is kept once, first spelling first, because for -Marker the FIRST name
            is the one a claim writes.

        .OUTPUTS
            The values, in order. Empty when nothing usable was given.
    #>
    param([AllowNull()][string[]]$Value)

    $seen = @{}
    foreach ($raw in @($Value)) {
        foreach ($part in ("$raw" -split ',')) {
            $item = $part.Trim()
            if (-not $item -or $seen.ContainsKey($item)) { continue }
            $seen[$item] = $true
            $item
        }
    }
}

function Split-ClaimMarkerNames {
    <#
        .SYNOPSIS
            The marker names in whatever a caller passed for -Marker (Split-CommaListArgument).

        .DESCRIPTION
            Unsplit, a comma list under -File was written as ONE marker name and read as one, so a
            machine passing a predecessor list was blind to every ordinary 'claim-tag' marker and its
            own claims were invisible to every machine that passed none (#2358). A marker name sits
            between '<!--' and ':' in an HTML comment and so never holds a comma of its own.
    #>
    param([AllowNull()][string[]]$Marker)
    Split-CommaListArgument -Value $Marker
}

function Get-ClaimMarkerPattern {
    <#
        .SYNOPSIS
            The regex that finds a claim marker in a comment body, for one or several marker names.

        .DESCRIPTION
            THE MARKER IS AN HTML COMMENT so that it is invisible in the rendered issue, and the name is
            a PARAMETER so that a repo which already has claim comments under an older name can keep
            reading them. That is not hypothetical: the BWJ prompt this replaces wrote 'swb-lane:', and
            a sweep that could not see those would hand out a second claim on work already in flight.

            SEVERAL NAMES READ, ONE NAME WRITTEN. Format-ClaimComment takes a single name, so the
            predecessor is something a sweep RECOGNISES and never something it produces -- otherwise the
            older name never dies.

            AND A COMPOUND NAME ALREADY WRITTEN IS READ, for the transition (#2358). Before the split
            above existed, a comma list under -File was written verbatim -- '<!-- claim-tag,xoxo-lane:
            TAG -->' sits on real issues. Such a marker is recognised when ANY of its comma-separated
            parts is a name this sweep reads, so those in-flight claims hold without every consumer
            having to list the compound spelling by hand. Nothing writes that shape any more.

        .PARAMETER Marker
            One or more marker names, without the angle brackets or the colon. A comma list in one
            element is split (Split-ClaimMarkerNames).

        .OUTPUTS
            The pattern string, with the tag in a named group 'tag'. '' when no usable name was given.
    #>
    param([AllowNull()][string[]]$Marker = @('claim-tag'))

    $names = @(Split-ClaimMarkerNames -Marker $Marker | ForEach-Object { [regex]::Escape($_) })
    if ($names.Count -eq 0) { return '' }

    # [^>]* rather than .*? because a marker is a single HTML comment on one line: bounding it at the
    # first '>' means a malformed body cannot make one marker swallow the next one. The optional
    # '<part>,' runs either side of the known name are the compound spellings described above; a part
    # excludes whitespace, ',', ':' and '>', so it cannot reach past the marker's own colon.
    $part = '[^\s,:>]+'
    '<!--\s*(?:' + $part + '\s*,\s*)*(?:' + ($names -join '|') + ')(?:\s*,\s*' + $part + ')*\s*:\s*(?<tag>[^>]*?)\s*-->'
}

function Format-ClaimComment {
    <#
        .SYNOPSIS
            The comment body a claim writes: one readable sentence, and the marker that machines read.

        .DESCRIPTION
            THE SENTENCE IS FOR THE COLLEAGUE WHOSE TICKET THIS IS. A bare marker is invisible in the
            rendered issue, so an issue claimed by a sweep would show a comment that appears to say
            nothing -- which reads as a glitch on somebody else's board rather than as work starting.

            THE MARKER IS FOR EVERY OTHER SESSION, and it is the whole claim. It carries the tag
            verbatim so that reading it back is a string comparison rather than a parse of prose.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Tag,
        [string]$Marker = 'claim-tag'
    )

    $tag = $Tag.Trim()
    # The first NAME, never the whole string: a comma list handed over whole must not be written as one
    # compound marker name nobody else reads (#2358).
    $first = @(Split-ClaimMarkerNames -Marker $Marker) | Select-Object -First 1
    $name = if ($first) { $first } else { 'claim-tag' }
    "Picked up by $tag -- an automated sweep of the open issues. <!-- ${name}: $tag -->"
}

function Get-ClaimRecords {
    <#
        .SYNOPSIS
            Every claim marker on an issue, from a `gh issue view --json comments` payload: the tag, who
            wrote it, when, and the comment's id.

        .DESCRIPTION
            SAME PARSE DISCIPLINE AS Get-AssigneeLogins one screen up, and for the same two 5.1 traps: a
            field gh was never asked for is ABSENT rather than empty, and a dot-read of an absent
            property throws under Set-StrictMode -Version Latest. So every record is probed before it is
            read and a malformed one is skipped rather than taking the run down.

            EMPTY IS "NOBODY HAS CLAIMED IT" ONLY IF THE READ SUCCEEDED, which is the caller's check and
            not this function's. Read the other way round -- an unreachable tracker presenting as a free
            backlog -- a sweep would claim and rebuild work that six machines are already holding.

            THE BODY IS NEVER RETURNED. An issue comment is untrusted text of unbounded length written
            by anybody with access to the tracker; what leaves here is a tag matched against a bounded
            pattern, an author login, a timestamp and an id.

        .PARAMETER Json
            The payload text of `gh issue view --json comments` (or one element of `gh issue list`'s).

        .PARAMETER Marker
            The marker names to recognise. Several: see Get-ClaimMarkerPattern.

        .OUTPUTS
            An array of records -- Tag, Author, CreatedAt, Id -- in the order the tracker returned them.
            EMPTY for empty input, unparseable JSON, or a payload with no marker in it.
    #>
    param(
        [string]$Json,
        [AllowNull()][string[]]$Marker = @('claim-tag')
    )

    if (-not $Json -or -not $Json.Trim()) { return @() }
    $pattern = Get-ClaimMarkerPattern -Marker $Marker
    if (-not $pattern) { return @() }

    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }
    if (-not $parsed.PSObject.Properties['comments']) { return @() }

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($comment in @(@($parsed.comments) | Where-Object { $_ })) {
        if (-not $comment.PSObject.Properties['body']) { continue }
        $body = [string]$comment.body
        if (-not $body) { continue }
        $match = [regex]::Match($body, $pattern)
        if (-not $match.Success) { continue }

        $tag = $match.Groups['tag'].Value.Trim()
        if (-not $tag) { continue }

        $author = ''
        if ($comment.PSObject.Properties['author'] -and $comment.author -and $comment.author.PSObject.Properties['login']) {
            $author = ([string]$comment.author.login).Trim()
        }
        $created = ''
        if ($comment.PSObject.Properties['createdAt']) { $created = ([string]$comment.createdAt).Trim() }
        $id = ''
        if ($comment.PSObject.Properties['id']) { $id = ([string]$comment.id).Trim() }

        $records.Add([pscustomobject]@{
            Tag       = $tag
            Author    = $author
            CreatedAt = $created
            Id        = $id
        }) | Out-Null
    }
    # .ToArray() rather than @($records), and it is measured rather than stylistic: in 5.1 the wrap
    # throws ArgumentException on a List[object] holding PSCustomObjects, while the same wrap on the
    # List[string] Get-AssigneeLogins builds is fine. pr-issues-lib.ps1 carries the same note.
    return @($records.ToArray())
}

function Get-TagClaimVerdict {
    <#
        .SYNOPSIS
            Whether the issue in front of a sweep may be claimed by this tag -- read before anything is
            written.

        .DESCRIPTION
            FOUR VERDICTS, AND THEY ARE THE ASSIGNEE VERDICTS ONE AXIS OVER. Get-ClaimVerdict asks who
            is ASSIGNED; this asks who has CLAIMED, and the two disagree on purpose -- see the section
            header above for the measurement that separated them.

              1. NO TAG. There is no complete 'machine/account' to claim under, so there is nobody to
                 be. Refused rather than worked around, for the same reason an anonymous assignee claim
                 is: a claim that cannot say who made it settles nothing for the next session to read.

              2. THE ISSUE IS CLOSED. Same refusal, same reason, as the assignee path: writing a claim
                 on finished work gives a sweep every signal of having started something real.

              3. SOMEBODY ELSE HOLDS IT. One or more markers, none of them this tag. Refused -- and
                 unlike the assignee path this refusal has no override, because in a sweep it is not a
                 judgement call: a machine is mid-flight on that issue and its branch is somewhere this
                 session cannot see. The one way past it is not a flag on this verdict but a separate,
                 visible act whose preconditions check both halves of that sentence instead of assuming
                 them -- Get-TakeOverVerdict (#2387).

              4. IT IS ALREADY THIS TAG'S. A resume -- a crashed session, a second pass, the approval
                 coming back hours later. Nothing to write, and it is the verdict A SWEEP'S RESUME STEP
                 TURNS ON: resuming asks to continue on the tag's OWN work, so a tag that cannot tell
                 itself apart from another session's picks up somebody else's branch.

            A TAG PRESENT ALONGSIDE OTHERS IS STILL A RESUME HERE. That collision is settled by
            Resolve-ClaimRace after the write, on the timestamps, and not by a pre-write read that
            cannot see who was first.

        .PARAMETER Tag
            This session's tag (Get-ClaimTag's Tag). '' when incomplete.

        .PARAMETER State
            The issue's state -- 'OPEN' or 'CLOSED'. Compared case-insensitively.

        .PARAMETER Records
            The markers already on the issue (Get-ClaimRecords).

        .OUTPUTS
            Action  -- 'claim' | 'resume' | 'refuse'.
            Code    -- 'free' | 'already-yours' | 'no-tag' | 'closed' | 'held'.
            Holders -- the tags that are not this one. Always an array.
    #>
    param(
        [string]$Tag = '',
        [string]$State = '',
        [AllowNull()][object[]]$Records = @()
    )

    $all = @(@($Records) | Where-Object { $_ -and $_.PSObject.Properties['Tag'] -and ([string]$_.Tag).Trim() })
    $others = @($all | Where-Object { ([string]$_.Tag).Trim() -ine $Tag } | ForEach-Object { ([string]$_.Tag).Trim() } | Select-Object -Unique)
    $mine   = @($all | Where-Object { $Tag -and (([string]$_.Tag).Trim() -ieq $Tag) })

    if (-not $Tag) {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'no-tag'; Holders = $others }
    }
    if ($State -ieq 'CLOSED') {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'closed'; Holders = $others }
    }
    if ($mine.Count -gt 0) {
        return [pscustomobject]@{ Action = 'resume'; Code = 'already-yours'; Holders = $others }
    }
    if ($others.Count -gt 0) {
        return [pscustomobject]@{ Action = 'refuse'; Code = 'held'; Holders = $others }
    }
    return [pscustomobject]@{ Action = 'claim'; Code = 'free'; Holders = $others }
}

function Resolve-ClaimRace {
    <#
        .SYNOPSIS
            Who won, when two sessions claimed the same issue within the same breath: read the markers
            back after the write and name the WINNER.

        .DESCRIPTION
            THE PROMPT THIS REPLACES NAMED THE LOSER AND THAT DOES NOT CLOSE. Its rule was "read the
            comments back, and if there is a claim that is not yours, let go" -- under which two sessions
            that claim inside the same second both see two markers, both recognise the other, and BOTH
            let go. The issue is then released by everybody who wanted it, and the next pass repeats the
            race with the same outcome. A rule that resolves a race has to name a winner, so that
            exactly one session keeps it.

            EARLIEST COMMENT WINS. It is the only ordering both sessions can read the same way: each one
            sees both timestamps, written by the tracker rather than by either machine, so the verdict
            does not depend on which session is asking.

            AND THE TIE IS BROKEN ON THE COMMENT ID, which is arbitrary and DETERMINISTIC -- the two
            properties a tie-break needs, in that order. GitHub stamps createdAt to the second, so two
            claims can genuinely share one; the node id is opaque and says nothing about time, but every
            session compares the same two strings and reaches the same answer. A tie-break that read as
            meaningful (the "lower" machine, the "first" account) would invite somebody to rely on it.

            A TAG THAT CLAIMED TWICE IS JUDGED ON ITS EARLIEST MARKER. A resumed session can leave a
            second comment, and the claim it is resuming is the first one.

            ABSENT IS ITS OWN ANSWER AND NOT A LOSS. Where the read-back carries no marker for this tag
            at all, the write did not land -- which says nothing about who holds the issue, so the caller
            reports it rather than releasing something it never had.

        .PARAMETER Tag
            This session's tag.

        .PARAMETER Records
            Every marker on the issue AFTER the write (Get-ClaimRecords).

        .OUTPUTS
            Action  -- 'keep' | 'release' | 'absent'.
            Winner  -- the tag that holds the issue. '' when Action is 'absent'.
            Mine    -- this tag's earliest record, or $null.
            Rivals  -- the other tags present. Always an array.
            Reason  -- 'sole' | 'earliest' | 'tie-id' | 'later' | 'not-written'.
    #>
    param(
        [string]$Tag = '',
        [AllowNull()][object[]]$Records = @()
    )

    $all = @(@($Records) | Where-Object { $_ -and $_.PSObject.Properties['Tag'] -and ([string]$_.Tag).Trim() })

    # Earliest record per tag: a tag is in the race once, at the moment it first claimed.
    $firstByTag = @{}
    foreach ($record in $all) {
        $recordTag = ([string]$record.Tag).Trim()
        $key = $recordTag.ToLowerInvariant()
        $created = if ($record.PSObject.Properties['CreatedAt']) { [string]$record.CreatedAt } else { '' }
        $id = if ($record.PSObject.Properties['Id']) { [string]$record.Id } else { '' }
        if (-not $firstByTag.ContainsKey($key)) {
            $firstByTag[$key] = [pscustomobject]@{ Tag = $recordTag; CreatedAt = $created; Id = $id }
            continue
        }
        $held = $firstByTag[$key]
        if (($created -lt $held.CreatedAt) -or (($created -eq $held.CreatedAt) -and ($id -lt $held.Id))) {
            $firstByTag[$key] = [pscustomobject]@{ Tag = $recordTag; CreatedAt = $created; Id = $id }
        }
    }

    $mineKey = if ($Tag) { $Tag.Trim().ToLowerInvariant() } else { '' }
    $rivals = @($firstByTag.Keys | Where-Object { $_ -ne $mineKey } | ForEach-Object { $firstByTag[$_].Tag })

    if (-not $mineKey -or -not $firstByTag.ContainsKey($mineKey)) {
        return [pscustomobject]@{ Action = 'absent'; Winner = ''; Mine = $null; Rivals = $rivals; Reason = 'not-written' }
    }

    $mine = $firstByTag[$mineKey]
    if ($rivals.Count -eq 0) {
        return [pscustomobject]@{ Action = 'keep'; Winner = $mine.Tag; Mine = $mine; Rivals = @(); Reason = 'sole' }
    }

    # An ISO 8601 timestamp in UTC ('2026-09-21T10:02:03Z') sorts correctly as a STRING -- fixed width,
    # most significant field first, one timezone. Parsing it to a DateTime would introduce the local
    # zone into a comparison two machines in different zones have to agree on.
    $winner = $mine
    $reason = 'earliest'
    foreach ($key in $firstByTag.Keys) {
        if ($key -eq $mineKey) { continue }
        $rival = $firstByTag[$key]
        $earlier = ($rival.CreatedAt -lt $winner.CreatedAt) -or
                   (($rival.CreatedAt -eq $winner.CreatedAt) -and ($rival.Id -lt $winner.Id))
        if ($earlier) {
            $winner = $rival
            $reason = if ($rival.CreatedAt -eq $mine.CreatedAt) { 'tie-id' } else { 'later' }
        }
    }

    if ($winner.Tag -ieq $mine.Tag) {
        return [pscustomobject]@{ Action = 'keep'; Winner = $mine.Tag; Mine = $mine; Rivals = $rivals; Reason = $reason }
    }
    [pscustomobject]@{ Action = 'release'; Winner = $winner.Tag; Mine = $mine; Rivals = $rivals; Reason = $reason }
}

# --- HANDING A HELD ISSUE OVER (issue #2387) -------------------------------------------------------
#
# 'held' HAS NO FLAG PAST IT, AND ON ITS OWN TERMS THAT IS RIGHT: a machine is mid-flight and its branch
# is somewhere this session cannot see (#2243). Both halves of that sentence are checkable, though, and
# measured September 23, 2026 on machine DAVE neither held: 9 of 11 open issues read 'held', 7 of them by
# the SAME gh account on two other machines, and every one of the 9 had its branch on origin -- which the
# cycle-autopark Stop hook guarantees for a session that ended. The only way through was deleting the
# other machine's marker by hand through `gh api`, the one act the sweep page forbids.
#
# SO THE HANDOVER IS A DELIBERATE, VISIBLE ACT WITH TWO PRECONDITIONS, and each refusal below is one of
# the two halves of #2243's reasoning read instead of assumed:
#
#   THE WORK IS NOT TRAPPED ON THE OTHER MACHINE. Exactly one branch for the issue must be on origin.
#   None means the work may exist only over there; several means this run cannot say which one to
#   resume, and guessing is how a session resumes the wrong one.
#
#   THE HOLDER IS THIS SAME ACCOUNT. Taking over your own issue from another of your machines is
#   bookkeeping; taking over a colleague's is a conversation, and a switch cannot have one -- the same
#   line the default mode's 'taken' refusal draws.
#
# WHAT IT DOES NOT MEASURE is whether the other session is still alive. Nothing on the tracker can say
# so; what the handover does instead is make the other side FIND OUT: its marker is gone, so its own
# `-Verify` answers [NO] and a sweep's resume step stops there.

function Get-IssueBranchNames {
    <#
        .SYNOPSIS
            The branches on a remote that belong to one issue, out of `git ls-remote --heads` text.

        .DESCRIPTION
            THE CONVENTION IS '<prefix>/<n>-<short-name>', which is what sweep-issues' step 3 names and
            what every branch on this tracker's origin carries. Only the segment right after the prefix
            is read: '<n>' followed by a dash or the end. A number that merely APPEARS later in a name --
            'fix/2338-pin-12' against issue 12 -- is a different issue's branch and must not match.

            REFS ONLY UNDER refs/heads/, so a tag or a pull-request ref in a wider listing is not read as
            a branch.

        .PARAMETER Text
            The output of `git ls-remote --heads <remote>`: '<sha><TAB>refs/heads/<name>' per line.

        .PARAMETER Issue
            The issue number.

        .OUTPUTS
            The branch names, without 'refs/heads/', in the order given. Empty when none match.
    #>
    param(
        [AllowNull()][string]$Text,
        [Parameter(Mandatory = $true)][int]$Issue
    )

    if (-not $Text) { return @() }
    $pattern = '^[^/]+/' + $Issue + '(-|$)'
    foreach ($line in ($Text -split "`r?`n")) {
        $m = [regex]::Match($line, '\srefs/heads/(?<name>\S+)\s*$')
        if (-not $m.Success) { continue }
        $name = $m.Groups['name'].Value
        if ($name -match $pattern) { $name }
    }
}

function Get-RemoteIssueBranches {
    <#
        .SYNOPSIS
            Every remote-tracking branch that names an issue, out of one `git for-each-ref` listing --
            with the author and the time of its newest commit.

        .DESCRIPTION
            THE SWEEP'S HALF OF THE PARKED-FIX SCAN (issue #2392). -Candidates judged from the tracker
            alone, so an issue somebody was working WITHOUT a claim marker read 'free' -- measured
            September 23, 2026: 11 free of 11 open, while 9 of them had a live PR-less branch on origin.
            The only signal arrived after the claim was written, one issue at a time. One listing of
            refs/remotes/<remote> answers it for the whole backlog, so the one-read property of
            Get-SweepCandidates holds.

            THE CONVENTION IS THE SAME AS Get-IssueBranchNames': '<prefix>/<n>-<short-name>', the number read only
            from the segment right after the prefix. A branch named for the subject rather than the
            number is invisible here, as it is to that function; the claim's title-overlap scan is the
            check for that shape, and it runs at the claim.

            '<remote>/HEAD' IS SKIPPED -- it is a symbolic ref to the trunk, not somebody's branch.

        .PARAMETER Text
            The output of
            `git for-each-ref --format=%(refname:short)%1f%(authorname)%1f%(committerdate:unix) refs/remotes/<remote>`.
            Unit separator (0x1F), not a tab -- the author is free text, the reason ConvertFrom-CommitScanLog uses it.

        .PARAMETER Remote
            The remote the listing was taken from; its name is stripped from each ref. Default 'origin'.

        .OUTPUTS
            Records -- Issue, Branch (with the remote prefix), Author, CommitUnix -- in the order given.
            Empty when nothing matches.
    #>
    param(
        [AllowNull()][string]$Text,
        [string]$Remote = 'origin'
    )

    if (-not $Text) { return @() }
    $prefix = "$Remote/"
    foreach ($line in ($Text -split "`r?`n")) {
        $fields = $line -split [string][char]0x1F
        if ($fields.Count -lt 3) { continue }
        $ref = $fields[0].Trim()
        if (-not $ref.StartsWith($prefix) -or $ref -eq "$Remote/HEAD") { continue }
        $name = $ref.Substring($prefix.Length)
        $m = [regex]::Match($name, '^[^/]+/(?<n>\d+)(-|$)')
        if (-not $m.Success) { continue }
        $unix = [long]0
        [void][long]::TryParse($fields[2].Trim(), [ref]$unix)
        [pscustomobject]@{
            Issue      = [int]$m.Groups['n'].Value
            Branch     = $ref
            Author     = $fields[1].Trim()
            CommitUnix = $unix
        }
    }
}

function Get-TakeOverVerdict {
    <#
        .SYNOPSIS
            Whether this tag may take a held issue over from another machine -- read before anything is
            written.

        .DESCRIPTION
            Get-TagClaimVerdict FIRST, UNCHANGED. A take-over is only a question for a 'held' issue:
            every other verdict passes through under its own code, so the caller's existing handling of
            a closed, free or already-yours issue still applies and this function adds no second copy of
            it.

            THEN THE TWO PRECONDITIONS, in the order a reader would check them by hand -- whose claim it
            is before where the work is. A colleague's issue is refused whatever the branches say,
            because no branch state turns their work into this session's.

            THE ACCOUNT IS THE HALF AFTER THE FIRST '/'. Get-ClaimTag refuses a machine name carrying
            the separator, so the first one is always the boundary. Compared case-insensitively, like
            every other tag comparison in this lib.

        .PARAMETER Tag
            This session's tag (Get-ClaimTag's Tag).

        .PARAMETER State
            The issue's state -- 'OPEN' or 'CLOSED'.

        .PARAMETER Records
            The markers on the issue (Get-ClaimRecords).

        .PARAMETER Branches
            The issue's branches on origin (Get-IssueBranchNames).

        .OUTPUTS
            Code     -- Get-TagClaimVerdict's code for anything not 'held'; otherwise
                        'foreign-account' | 'no-branch' | 'ambiguous-branch' | 'take'.
            Holders  -- the tags that are not this one. Always an array.
            Branch   -- the one branch to resume, on 'take'. '' otherwise.
            Branches -- every branch that matched. Always an array.
            Rivals   -- the marker records the take-over removes, on 'take'. Always an array.
    #>
    param(
        [string]$Tag = '',
        [string]$State = '',
        [AllowNull()][object[]]$Records = @(),
        [AllowNull()][string[]]$Branches = @()
    )

    $base = Get-TagClaimVerdict -Tag $Tag -State $State -Records $Records
    $found = @(@($Branches) | Where-Object { $_ })
    $result = [pscustomobject]@{
        Code     = $base.Code
        Holders  = @($base.Holders)
        Branch   = ''
        Branches = $found
        Rivals   = @()
    }
    if ($base.Code -ne 'held') { return $result }

    $myAccount = ($Tag -split '/', 2)[1]
    $foreign = @(@($base.Holders) | Where-Object {
        $parts = ([string]$_) -split '/', 2
        $parts.Count -lt 2 -or ($parts[1] -ine $myAccount)
    })
    if ($foreign.Count -gt 0) { $result.Code = 'foreign-account'; return $result }
    if ($found.Count -eq 0) { $result.Code = 'no-branch'; return $result }
    if ($found.Count -gt 1) { $result.Code = 'ambiguous-branch'; return $result }

    $result.Code = 'take'
    $result.Branch = $found[0]
    $result.Rivals = @(@($Records) | Where-Object {
        $_ -and $_.PSObject.Properties['Tag'] -and (([string]$_.Tag).Trim() -ine $Tag)
    })
    return $result
}

function Format-HandoverComment {
    <#
        .SYNOPSIS
            The visible comment a take-over leaves: which tag held the issue, which tag holds it now, and
            the branch the work continues on.

        .DESCRIPTION
            IT CARRIES NO MARKER, on purpose. The claim is the new marker the ordinary claim path writes;
            this is the record a person reads, and one that also parsed as a claim would give the issue
            two markers for one tag.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$OldTags,
        [Parameter(Mandatory = $true)][string]$NewTag,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][int]$Issue
    )
    $old = (@($OldTags) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }) -join ', '
    "Handed over from $old to $NewTag -- the work continues on ``$Branch``, which is on origin. " +
        "A session under $old that runs ``claim-issue.ps1 $Issue -Tag -Verify`` now reads [NO] and stops."
}

function Get-SweepCandidates {
    <#
        .SYNOPSIS
            Which open issues a sweep may pick up next, out of one `gh issue list` payload: free, this
            tag's already, held by another tag, or skipped -- with the reason.

        .DESCRIPTION
            ONE READ FOR THE WHOLE BACKLOG. The alternative is a per-issue query, which on a board of a
            hundred issues is a hundred round-trips before any work starts -- and a sweep that spends a
            minute choosing is a sweep nobody runs. `gh issue list --json number,title,labels,comments`
            answers all of it at once.

            THE ORDER IS THE ISSUE NUMBER, ASCENDING, and that is a decision rather than a default:
            oldest first is the only order six machines reading the same board agree on without
            coordinating, so two sessions starting at the same moment collide on ONE issue and then
            diverge, rather than racing down the list together.

            A SKIP IS NOT A VERDICT ABOUT THE WORK. A label the caller named (needs-info, blocked) means
            the issue is parked with somebody else, and an explicitly excluded number means a person
            said so. Both are reported with their reason rather than silently dropped, because a sweep
            that says "nothing to do" while it is hiding six issues has told the operator nothing.

            IT JUDGES AND NEVER WRITES. The claim is a separate step and stays one: between this read
            and that write a session may still find the issue is not its repo's work at all -- an
            external ticket owned by somebody outside the team is the case the BWJ board measured
            (#722) -- and a scan that claimed as it went would have taken those before anybody looked.

        .PARAMETER Json
            The payload text of `gh issue list --json number,title,labels,comments`.

        .PARAMETER Tag
            This session's tag, so its own claims read as 'mine' rather than 'held'.

        .PARAMETER Marker
            The marker names to recognise (see Get-ClaimMarkerPattern).

        .PARAMETER SkipLabel
            Label names that park an issue with somebody else. Compared case-insensitively.

        .PARAMETER SkipIssue
            Issue numbers held out of this round by hand.

        .PARAMETER Branches
            Get-RemoteIssueBranches' records (issue #2392). An issue no marker holds but a branch on the
            remote names reads 'branch', not 'free': somebody worked it without -Tag, and a marker is not
            the only way to be on an issue. A marker still wins over a branch -- 'mine' and 'held' are the
            stronger statement, and a take-over reads the branch for itself.

        .PARAMETER NowUnix
            The current time as unix seconds, for the branch's age. Defaults to now; a test pins it.

        .OUTPUTS
            An array of records, ascending by number -- Number, Title, Verdict, Holder, Reason --
            where Verdict is 'free' | 'mine' | 'held' | 'branch' | 'skipped'. EMPTY for empty or
            unparseable input.
    #>
    param(
        [string]$Json,
        [string]$Tag = '',
        [AllowNull()][string[]]$Marker = @('claim-tag'),
        [AllowNull()][string[]]$SkipLabel = @(),
        [AllowNull()][int[]]$SkipIssue = @(),
        [AllowNull()][object[]]$Branches = @(),
        [long]$NowUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    )

    if (-not $Json -or -not $Json.Trim()) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }

    $skipLabels = @(@($SkipLabel) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
    $skipIssues = @(@($SkipIssue) | Where-Object { $_ })

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($issue in @(@($parsed) | Where-Object { $_ })) {
        if (-not $issue.PSObject.Properties['number']) { continue }
        $number = [int]$issue.number
        $title = if ($issue.PSObject.Properties['title']) { [string]$issue.title } else { '' }

        $labels = @()
        if ($issue.PSObject.Properties['labels']) {
            foreach ($label in @(@($issue.labels) | Where-Object { $_ })) {
                if ($label.PSObject.Properties['name']) { $labels += ([string]$label.name).Trim() }
            }
        }

        $verdict = 'free'
        $holder = ''
        $reason = ''

        if ($skipIssues -contains $number) {
            $verdict = 'skipped'
            $reason = 'held out of this round by number'
        } else {
            $hit = @($labels | Where-Object { $lbl = $_; @($skipLabels | Where-Object { $_ -ieq $lbl }).Count -gt 0 })
            if ($hit.Count -gt 0) {
                $verdict = 'skipped'
                $reason = "label '$($hit[0])'"
            }
        }

        if ($verdict -eq 'free') {
            # The records come from this one element, re-serialised: Get-ClaimRecords reads the shape
            # `gh issue view` returns, and one element of a list payload carries the same 'comments'
            # array under a different root. Re-serialising is cheaper than a second parser, and it keeps
            # exactly one place where a comment body is read.
            $records = @()
            if ($issue.PSObject.Properties['comments']) {
                $records = @(Get-ClaimRecords -Json (([pscustomobject]@{ comments = @($issue.comments) }) | ConvertTo-Json -Depth 8) -Marker $Marker)
            }
            $verdictRecord = Get-TagClaimVerdict -Tag $Tag -State 'OPEN' -Records $records
            switch ($verdictRecord.Code) {
                'already-yours' { $verdict = 'mine';  $reason = 'this tag claimed it' }
                'held'          { $verdict = 'held';  $holder = @($verdictRecord.Holders)[0]; $reason = "claimed by $holder" }
                'no-tag'        { $verdict = 'free';  $reason = '' }
                default         { $verdict = 'free';  $reason = '' }
            }
        }

        if ($verdict -eq 'free') {
            # NEWEST BRANCH FIRST, because it is the one a reader deciding "is somebody on this now?"
            # needs; the count says whether there are more.
            $own = @(@($Branches) | Where-Object { $_ -and $_.PSObject.Properties['Issue'] -and [int]$_.Issue -eq $number } |
                     Sort-Object -Property CommitUnix -Descending)
            if ($own.Count -gt 0) {
                $newest = $own[0]
                $verdict = 'branch'
                $holder = [string]$newest.Author
                $age = if ([long]$newest.CommitUnix -gt 0) { Format-CommitAge -Seconds ($NowUnix - [long]$newest.CommitUnix) } else { 'at an unknown time' }
                $more = if ($own.Count -gt 1) { " (+$($own.Count - 1) more)" } else { '' }
                $reason = "no claim marker, but $($newest.Branch)$more is on the remote -- $holder, $age"
            }
        }

        $out.Add([pscustomobject]@{
            Number  = $number
            Title   = $title
            Verdict = $verdict
            Holder  = $holder
            Reason  = $reason
        }) | Out-Null
    }

    return @($out | Sort-Object -Property Number)
}

function Get-OwnTagClaims {
    <#
        .SYNOPSIS
            Which open issues carry a claim marker of THIS tag, out of one `gh issue list` payload -- the
            set -ReleaseAll acts on (issue #2395).

        .DESCRIPTION
            THIS TAG'S OWN MARKERS AND NOTHING ELSE, which is the whole bound. An issue another tag holds
            is not returned at all, and on an issue both hold only this tag's records are carried -- so
            the caller cannot delete another session's marker by construction rather than by care. The
            same bound -Release already keeps for one issue; the owner's first proposal (#2395) was a
            wipe of every marker and assignee, rejected because the other markers are other machines'
            and colleagues' live claims and deleting them recreates the duplicate-work hazard #2207 and
            #2243 closed.

            THE ASSIGNEE IS REPORTED, NEVER DECIDED ON. Assigned says whether -Account is among the
            issue's assignees, so the caller removes the assignee a tag claim wrote beside its marker. An
            issue with this account assigned and no marker of this tag is not returned: in tag mode a
            bare assignee is whose TICKET this is, not a claim, and it is not this function's to drop.

            ONE READ FOR THE WHOLE BACKLOG, for the reason Get-SweepCandidates gives: a per-issue query
            is a round-trip per issue before anything is released.

        .PARAMETER Json
            The payload text of `gh issue list --json number,title,assignees,comments`.

        .PARAMETER Tag
            This session's tag. Compared case-insensitively, as everywhere else a tag is.

        .PARAMETER Account
            The login a tag claim writes as its assignee (Resolve-ClaimAccount's answer).

        .PARAMETER Marker
            The marker names to recognise (see Get-ClaimMarkerPattern).

        .OUTPUTS
            An array of records, ascending by number -- Number, Title, Records, Assigned -- where
            Records holds only this tag's markers and is never empty. EMPTY for empty or unparseable
            input, or a backlog this tag holds nothing on.
    #>
    param(
        [string]$Json,
        [string]$Tag = '',
        [string]$Account = '',
        [AllowNull()][string[]]$Marker = @('claim-tag')
    )

    if (-not $Json -or -not $Json.Trim()) { return @() }
    $ownTag = $Tag.Trim()
    if (-not $ownTag) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($issue in @(@($parsed) | Where-Object { $_ })) {
        if (-not $issue.PSObject.Properties['number']) { continue }
        if (-not $issue.PSObject.Properties['comments']) { continue }
        # Re-serialised into the shape Get-ClaimRecords reads, as Get-SweepCandidates does, so a comment
        # body is still read in exactly one place.
        $records = @(Get-ClaimRecords -Json (([pscustomobject]@{ comments = @($issue.comments) }) | ConvertTo-Json -Depth 8) -Marker $Marker)
        $own = @($records | Where-Object { $_.Tag -ieq $ownTag })
        if ($own.Count -eq 0) { continue }

        $assigned = $false
        if ($Account.Trim()) {
            $logins = @(Get-AssigneeLogins -Json (([pscustomobject]@{ assignees = @($(if ($issue.PSObject.Properties['assignees']) { $issue.assignees })) }) | ConvertTo-Json -Depth 5))
            $assigned = @($logins | Where-Object { $_ -ieq $Account.Trim() }).Count -gt 0
        }

        $out.Add([pscustomobject]@{
            Number   = [int]$issue.number
            Title    = $(if ($issue.PSObject.Properties['title']) { [string]$issue.title } else { '' })
            Records  = $own
            Assigned = $assigned
        }) | Out-Null
    }
    return @($out | Sort-Object -Property Number)
}
