<#
.SYNOPSIS
    Helpers for what a Pull Request's own machinery has to read: the issue-closing contract (the
    -Resolves gate in open-pr.ps1) and the check ordering behind ship-pr.ps1's merge wait.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')

    Why this exists: PRs #341, #342 and #343 each repaired issues and each referenced them as a
    PLAIN mention (`#332`) instead of a closing keyword (`Closes #332`). GitHub only auto-closes on
    the keyword, and the manual `gh issue close` was skipped all three times -- so eight repaired
    findings sat OPEN while the changelog said they were done. The instance was cleaned up by hand;
    this lib is the class being closed (Dave's standing rule: build the gate, not just the fixes).

    The second group (Get-CheckWaitReport and its three helpers) arrived for the same reason from the
    other end: ship-pr.ps1 drives `gh pr checks --watch` against a live remote, and issue #831 asked
    for the wait to SAY which check governed it. The query cannot be tested and the selection can, so
    the selection lives here -- see that function's own header for the measurement behind it.

    The third group (Get-RequiredCheckRunIds, Get-CertifyingRunCreatedAt and Get-StaleCertificateVerdict)
    is issue #1292's corrected mechanism: a required check tests GitHub's merge ref roughly as it stood
    when the run was created, and that ref is never refreshed if 'main' moves afterward -- so a green
    check can go STALE between the run and the merge. Anchored on the run's own `created_at` rather than
    a check's `startedAt` after a red-team caught the first version's bias the wrong way round (see
    Get-CertifyingRunCreatedAt's own header). Finding the run behind a check, selecting the earliest
    `created_at`, and deciding whether 'main' has since moved are all pure; only the git/gh reads that
    feed them are not.

    Everything here is a PURE function of its input -- no git, no gh, no filesystem -- so the suite
    (scripts/tests/pr-issues.tests.ps1) can assert the whole decision table without a live remote.
    The parts that cannot be pure (asking GitHub which issues are still open, and asking it for the
    check timestamps) stay in the callers.

    Shared with the plugin mirror (registered in scripts/lib/shared-scripts-lib.ps1), because
    open-pr.ps1 and ship-pr.ps1 are both mirrored and dot-source this file.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# GitHub's own closing keywords, as accepted in a PR body. Kept in one place so the writer
# (New-ResolvesBlock) and the recogniser (Test-HasClosingKeyword) cannot drift apart -- a
# hand-mirrored literal is exactly what produced the accumulation bugs this repo keeps finding.
$script:PrClosingKeywords = @(
    'close', 'closes', 'closed',
    'fix', 'fixes', 'fixed',
    'resolve', 'resolves', 'resolved'
)

function Get-PrClosingKeywords {
    <# The closing keywords GitHub honours in a PR body, lowercase. #>
    return $script:PrClosingKeywords
}

function Remove-MarkdownCodeSpans {
    <#
    .SYNOPSIS
        Blanks out fenced code blocks and inline code spans, so a reference inside them is not read
        as a live reference.

    .DESCRIPTION
        This is not a convenience -- it is what makes the recognisers AGREE WITH GITHUB. GitHub does
        not autolink `#332` inside a code span or fence, and a closing keyword only closes something
        it can link, so text inside backticks closes nothing there either.

        The bug that forced this: a document explaining the gate necessarily writes the pattern it is
        explaining. This repo's own changelog entry for the gate contains the literal
        "`Closes #331, #332`" as prose about GitHub's comma behaviour -- and open-pr.ps1 copies the
        whole entry body verbatim into the PR body. Without this stripping, the recogniser read that
        example as a real declaration: the PR would report "closes #331", and ship-pr.ps1's
        post-merge step would then force-close #331 with a comment crediting a PR that has nothing to
        do with it. Documenting a feature must not trigger it.

        Replaced with a run of '|' of the same length -- not removed, and deliberately not spaces.
        Removal would let the text on either side join into a new match, and SPACES would leave a
        keyword and a reference looking adjacent across the gap: 'Closes `x` #332' would blank to
        'Closes     #332' and read as a live declaration, while GitHub (which needs the keyword
        immediately before the reference) closes nothing there. '|' is neither a word character nor
        whitespace, so it blocks that false adjacency without hiding a reference that follows it
        directly.
    #>
    param([string]$Text)

    if (-not $Text) { return '' }

    $out = $Text
    # Fences first (``` ... ``` and ~~~ ... ~~~), then inline spans of any backtick run length.
    $out = [regex]::Replace($out, '(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[ \t]*$', { '|' * $args[0].Length })
    $out = [regex]::Replace($out, '(`+)[^`]*?\1', { '|' * $args[0].Length })
    return $out
}

function ConvertTo-IssueNumberList {
    <#
    .SYNOPSIS
        Parses a caller-supplied issue list ('331,332', '#331 #332') into a sorted unique int array.

    .DESCRIPTION
        Why the callers take a STRING and not an [int[]]: an [int[]] parameter is unusable across
        `powershell -File`, which is how ship-pr.ps1 invokes open-pr.ps1 and how the test fixtures
        run it. That parser hands every token over as a string and never builds an array, so
        `-Resolves 332,340` arrives as the single string '332,340' -- which PowerShell then casts to
        an int by reading the comma as a THOUSANDS SEPARATOR, yielding 332340. Not an error: a
        silently wrong single issue number, measured on Windows PowerShell 5.1 while building this
        gate. `-Resolves 332 340` is no better (it binds only the first token).

        So parsing is done here, deliberately, and it is liberal about the separator (comma,
        whitespace, semicolon) and about a leading '#'. Anything that is not a positive number is
        ignored, so a stray word cannot become issue 0.
    #>
    param([string]$Value)

    if (-not $Value) { return @() }

    $numbers = New-Object System.Collections.Generic.List[int]
    foreach ($m in [regex]::Matches($Value, '\d+')) {
        $n = 0
        if ([int]::TryParse($m.Value, [ref]$n) -and $n -gt 0) { $numbers.Add($n) }
    }
    return @($numbers | Sort-Object -Unique)
}

function Get-IssueMentions {
    <#
    .SYNOPSIS
        The issue numbers a text mentions, as a sorted unique int array.

    .DESCRIPTION
        Finds `#<n>` and `.../issues/<n>` references. Deliberately EXCLUDES pull-request
        references, because a changelog entry routinely cites the PR it follows on from
        ("as PR #341 established for this class") and treating those as issues would make the
        gate cry wolf on almost every branch:
          - `PR #341` / `pull request #341` (the prose form),
          - `PRs #341-#343` / `PRs #341, #342 and #343` (a PLURAL head followed by a list), and
          - `.../pull/341` (the link form).
        A bare `#341` IS returned: from the text alone it is indistinguishable from an issue, and
        the caller resolves the ambiguity by asking GitHub which numbers are open issues.

        Where the two error directions collide, this errs toward RETURNING a number. A missed mention
        means the gate never fires, which is the silent-open-issue bug the gate exists to prevent; a
        surplus mention only means the gate asks a question the author answers once. That is why the
        list scrub below requires a plural head -- see the comment on it.
    #>
    param([string]$Text)

    if (-not $Text) { return @() }

    # A reference inside backticks is not a live reference on GitHub either.
    $scrubbed = Remove-MarkdownCodeSpans -Text $Text

    # Blank out the forms that are demonstrably PRs before scanning for mentions, so a single
    # regex pass cannot pick them up again. ORDER MATTERS: the multi-number forms go first, because
    # scrubbing 'PRs #341' out of 'PRs #341-#343' would leave a bare '-#343' behind, which the
    # mention pass then reads as an issue -- a false positive the suite caught.
    #
    # The comma/'and' continuation is accepted ONLY after a PLURAL head ('PRs', 'pull requests').
    # After a singular head it is not: in 'PR #341 and #332' nothing marks #332 as a PR, and
    # swallowing it made a real open issue invisible to the gate (found in review). A dash range or
    # 'to'/'through' IS unambiguous, so that continuation is scrubbed after either head.
    #
    # THE DASH CLASS IS COMPOSED FROM CODE POINTS, so this source stays pure ASCII. That is the repo's
    # rule for the script layer, not a style choice: Windows PowerShell 5.1 reads a BOM-less .ps1 as the
    # system ANSI code page, so a literal U+2013 written here decodes as TWO CP1252 characters -- and it
    # does so silently, because a mis-decoded string is still a string. Inside a character class that
    # does not throw, it WIDENS the class, which is a wrong answer rather than a failure. These two
    # patterns are therefore double-quoted so the composed variable interpolates; neither carries a '$'
    # of its own, so nothing else does. check-plugin-integrity's [script-ascii] check holds every .ps1
    # in the tree to this, and scripts/tests/pr-issues.tests.ps1 exercises both dashes so a silent
    # regression in this composition cannot pass the gate.
    $dashes = '-' + [char]0x2013 + [char]0x2014
    $scrubbed = [regex]::Replace($scrubbed, "(?i)\b(pull\s*requests|PRs)\s*(#\s*\d+)(\s*(?:[$dashes,]|and|to|through)\s*#\s*\d+)+", ' ')
    $scrubbed = [regex]::Replace($scrubbed, "(?i)\b(pull\s*requests?|PRs?)\s*(#\s*\d+)(\s*(?:[$dashes]|to|through)\s*#\s*\d+)+", ' ')
    $scrubbed = [regex]::Replace($scrubbed, '(?i)\bpull\s*requests?\s*#\s*\d+', ' ')
    $scrubbed = [regex]::Replace($scrubbed, '(?i)\bPRs?\s*#\s*\d+', ' ')
    $scrubbed = [regex]::Replace($scrubbed, '(?i)/pull/\d+', ' ')

    $numbers = New-Object System.Collections.Generic.List[int]

    # The lookbehind excludes only a word character, NOT '/'. It used to exclude '/' as well, which
    # silently dropped every number after the first in a slash-separated list ('#334/#329/#335'
    # yielded 334 alone) -- found in review, and precisely the failure mode the gate is built to
    # prevent. URL forms are already handled: /pull/<n> is scrubbed above and /issues/<n> is matched
    # separately below, so '/' needs no guard here.
    foreach ($m in [regex]::Matches($scrubbed, '(?<!\w)#(\d+)\b')) {
        $numbers.Add([int]$m.Groups[1].Value)
    }
    foreach ($m in [regex]::Matches($scrubbed, '(?i)/issues/(\d+)\b')) {
        $numbers.Add([int]$m.Groups[1].Value)
    }

    return @($numbers | Sort-Object -Unique)
}

function Test-HasClosingKeyword {
    <#
    .SYNOPSIS
        $true when a text already carries a GitHub closing keyword against an issue number.

    .DESCRIPTION
        Lets a hand-written -Body that already says `Closes #332` satisfy the gate on its own,
        instead of forcing the author to repeat the decision as a parameter. Matches the keyword
        immediately before the reference, which is the only form GitHub itself honours -- so this
        recogniser cannot report a body as closing something GitHub will leave open.
    #>
    param([string]$Text)

    if (-not $Text) { return $false }
    # Code spans stripped first: GitHub does not link a reference inside backticks, so it closes
    # nothing there -- and a doc explaining this gate has to write the pattern it explains.
    $clean = Remove-MarkdownCodeSpans -Text $Text
    $kw = (Get-PrClosingKeywords) -join '|'
    return [bool][regex]::IsMatch($clean, "(?i)\b($kw)\s*:?\s+(#\d+|https?://\S+/issues/\d+)")
}

function Get-ClosedIssueNumbers {
    <#
    .SYNOPSIS
        The issue numbers a text closes via a closing keyword, as a sorted unique int array.

    .DESCRIPTION
        The counterpart of Test-HasClosingKeyword: not "does it close something" but "which ones".
        Used to report, after a merge, exactly which issues GitHub was asked to close -- so the
        verification step checks the same set the body actually declared, never a set assembled
        a second time (a second tally is how the #275 preview/apply drift started).
    #>
    param([string]$Text)

    if (-not $Text) { return @() }
    # Same code-span stripping as Test-HasClosingKeyword, and for the same reason: this function
    # decides which issues ship-pr.ps1 will force-close after a merge, so a prose example must never
    # reach it. Without this, the gate's own changelog entry made it credit a close to the wrong PR.
    $clean = Remove-MarkdownCodeSpans -Text $Text
    $kw = (Get-PrClosingKeywords) -join '|'
    $numbers = New-Object System.Collections.Generic.List[int]

    foreach ($m in [regex]::Matches($clean, "(?i)\b($kw)\s*:?\s+#(\d+)\b")) {
        $numbers.Add([int]$m.Groups[2].Value)
    }
    foreach ($m in [regex]::Matches($clean, "(?i)\b($kw)\s*:?\s+https?://\S+/issues/(\d+)\b")) {
        $numbers.Add([int]$m.Groups[2].Value)
    }

    return @($numbers | Sort-Object -Unique)
}

function Get-ExistingPrRecord {
    <#
    .SYNOPSIS
        The first PR record in a `gh pr list --json number,url,body` payload, or $null when there is none.

    .DESCRIPTION
        open-pr.ps1 asks gh whether the current branch already has an open PR, and the answer decides
        two things: whether an existing body's closing keywords count as a declaration, and whether
        `gh pr create` runs at all. Parsing it lives HERE, as a pure function of the JSON text, because
        the caller drives a live remote and cannot be covered by a suite -- while this can.

        THE PARSE IS THE PART THAT NEEDS A TEST, not the query. Windows PowerShell 5.1 hands a parsed
        JSON array to the pipeline as a SINGLE object, so `@($text | ConvertFrom-Json)` collects one
        element that IS the whole Object[]; and indexing the result with [0] returns $null on an empty
        list rather than failing, which is a wrong answer that looks like a right one. Both shapes have
        already cost this repo a silent bug (see Get-OpenIssueNumbers's caller). So: assign first, wrap
        second, and require a `number` before believing a record.

        Returns $null for empty input, an empty list, unparseable JSON, or records without a number --
        every one of which the caller must treat as "no existing PR", never as an error.
    #>
    param([string]$Json)

    if (-not $Json -or -not $Json.Trim()) { return $null }

    try {
        $parsed = $Json | ConvertFrom-Json
    } catch {
        return $null
    }

    return (@($parsed) | Where-Object { $_ -and $_.number } | Select-Object -First 1)
}

function Get-InterruptedShipCandidates {
    <#
    .SYNOPSIS
        The open PRs whose head branch is a branch of THIS checkout -- newest PR first, empty when
        there is none. What an interrupted ship leaves behind, read off a payload rather than guessed.

    .DESCRIPTION
        ISSUE #1620, September 8, 2026. ship-pr.ps1's step 2b hands the primary checkout back to the
        trunk the moment the PR exists (#1073), and the CI wait is the longest step in the run -- so for
        the whole of that wait HEAD says 'main' while the branch's merge and fold are still owed. A run
        that does not survive the wait therefore leaves a checkout whose HEAD names nothing about the
        work, and the front-door check answered the re-run with `You are on main; ship-pr runs from a
        branch`: a message about the wrong problem. Measured on PR #1618, where the backgrounded process
        was killed by the host for low memory and `git checkout <branch>` plus the same command resumed
        correctly.

        WHY THIS AND NOT THE REMEDY #1588 ALREADY ADDED. That repair put the checkout at the head of the
        stale-CI refusal's printed remedy, and it is correct, but it only reaches a run that gets as far
        as printing a remedy. AN INTERRUPTED PROCESS PRINTS NOTHING -- no refusal, no remedy, no next
        line -- and a kill usually takes the scrollback with it, so the front door is the only surface
        left to say it on.

        THE PAIR IS THE SIGNAL: an OPEN PR, whose head ref is a branch THIS checkout has. Neither half
        alone says anything. There are open PRs for branches that live on other machines, and there are
        local branches by the dozen whose PRs merged weeks ago -- measured in this repo on the day this
        was written, 26 local branches against 1 open PR whose head ref was NOT here, so the correct
        answer was "no candidate" and 25 merged leftovers produced no noise at all. The ceiling on the
        list is the number of open PRs whose branch is local, never the number of branches lying around.

        AND IT IS NOT AN ASSERTION THAT A SHIP WAS INTERRUPTED, which is why the caller's wording offers
        the checkout instead of claiming a history this cannot read. A branch parked with its PR open, or
        one another session is shipping in a lane, satisfies the same pair. The checkout is the right
        next move in all of them: ship-pr resumes an existing PR rather than opening a second one.

    .PARAMETER Json
        `gh pr list --state open --json number,headRefName` output. Empty, unparseable or field-less in,
        EMPTY OUT -- this feeds a diagnostic beside a refusal that must still be printable when gh cannot
        answer at all.

    .PARAMETER LocalBranches
        What `git for-each-ref --format=%(refname:short) refs/heads` gave. Compared exactly: git ref
        names are case-sensitive, and a near-match is not the branch a resume would check out.

    .PARAMETER TrunkBranch
        Excluded from the result. A PR whose head IS the trunk is not a branch to check out, and the
        caller has just refused for standing on it.
    #>
    param(
        [AllowEmptyString()][AllowNull()][string]$Json,
        [AllowNull()][string[]]$LocalBranches,
        [string]$TrunkBranch = 'main'
    )

    if (-not $Json -or -not $Json.Trim()) { return @() }
    if ($null -eq $LocalBranches) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }

    # ASSIGN FIRST, WRAP SECOND -- the 5.1 pitfall Get-ExistingPrRecord's own header records: piping the
    # parse straight into @() collects the whole array as ONE element, and every filter below would then
    # be reading a single Object[].
    $records = @($parsed | Where-Object { $_ })

    # AN ORDINAL SET, NOT A HASHTABLE, and that is the one line of this function a reader should not
    # simplify. PowerShell's `@{}` compares keys CASE-INSENSITIVELY, so with one a head ref named
    # `FEAT/Other` matched a local `feat/other` -- caught by this function's own suite, which asserts
    # the exact match. git ref names are case-sensitive, so those are two refs, and the printed remedy
    # would then be a `git checkout` of a name this checkout does not have. Silence is the safe answer
    # there: no candidate means the refusal stays the line it has always been.
    $local = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($name in $LocalBranches) {
        if ($null -eq $name) { continue }
        $trimmed = ([string]$name).Trim()
        if ($trimmed) { [void]$local.Add($trimmed) }
    }
    if ($local.Count -eq 0) { return @() }

    $trunk = ([string]$TrunkBranch).Trim()

    $out = New-Object System.Collections.ArrayList
    foreach ($record in $records) {
        # A field gh was never asked for is ABSENT, and absent is not empty under Set-StrictMode -- the
        # same guard Get-StalledRunNote applies to its own payload, for the same reason.
        if (-not $record.PSObject.Properties['number']) { continue }
        if (-not $record.PSObject.Properties['headRefName']) { continue }
        $number = 0
        if (-not [int]::TryParse(([string]$record.number).Trim(), [ref]$number)) { continue }
        if ($number -le 0) { continue }
        $head = ([string]$record.headRefName).Trim()
        if (-not $head) { continue }
        if ($trunk -and $head -ceq $trunk) { continue }
        if (-not $local.Contains($head)) { continue }
        [void]$out.Add([pscustomobject]@{ Number = $number; Branch = $head })
    }

    # NEWEST PR FIRST, because the interrupted ship is the most recent thing this checkout did. It is an
    # ordering rather than a choice: every candidate is listed, and the caller's wording asks the reader
    # which one they were shipping instead of picking for them.
    return @($out | Sort-Object -Property Number -Descending)
}

function Get-InterruptedShipResumeNote {
    <#
    .SYNOPSIS
        The block ship-pr.ps1 appends to its `You are on main` refusal when this checkout holds the
        branch of an open PR -- the resume instruction, or '' when there is nothing to resume.

    .DESCRIPTION
        THE OTHER HALF OF #1620. Get-InterruptedShipCandidates above decides; this words it. Same split,
        and for the same reason, as Get-TrunkReturnDecision and Get-TrunkReturnGoAheadLine in
        worktree-lib.ps1: the sentence a reader acts on is asserted in a suite rather than trusted to a
        live ship, and a wording that drifted from the decision that produced it is the defect #1616
        measured four rows apart in that same script.

        WHAT IT DOES NOT DO IS PRESCRIBE THE GATE. A resume re-runs the whole local gate against a
        commit CI is already testing, and whether that should be skipped by default is a separate
        question -- #1620 says so in as many words. So this names the checkout and the re-run and offers
        no flag: an operator who wants to skip has ship-pr's own switches in front of them.

    .PARAMETER Candidates
        Get-InterruptedShipCandidates' records, each additionally carrying the PASTE VERDICT for its
        branch: .Token is what goes into the printed command, .Note the line explaining a refused name
        (Get-PasteableRef, #1594). The caller resolves those, because ref-print-lib.ps1 owns that
        judgement -- and a head ref name is chosen by whoever opened the PR, which is the least
        trustworthy source any of that issue's print sites reads.

    .PARAMETER MaxShown
        How many candidates the list prints before it says how many it did not. A remedy whose first
        line is off the screen is what #1046 records for a warning printed at depth.
    #>
    param(
        [AllowNull()][object[]]$Candidates,
        [string]$TrunkBranch = 'main',
        [int]$MaxShown = 5
    )

    $records = @($Candidates | Where-Object { $_ })
    if ($records.Count -eq 0) { return '' }

    $shown = @($records | Select-Object -First $MaxShown)
    $lines = @($shown | ForEach-Object {
        $token = ''
        if ($_.PSObject.Properties['Token']) { $token = ([string]$_.Token).Trim() }
        # THE PLACEHOLDER IS THE FALLBACK RATHER THAN THE RAW NAME. A caller that forgot to resolve the
        # paste verdict gets '<branch>' -- the convention every printed remedy in this workflow already
        # uses -- and never a ref name in a command line that nothing judged (#1594).
        if (-not $token) { $token = '<branch>' }
        "  PR #$($_.Number) -- git checkout $token"
    })
    $hidden = $records.Count - $shown.Count
    if ($hidden -gt 0) {
        $lines += "  (and $hidden further open PR(s) whose branch is in this checkout, not listed.)"
    }

    # THE REFUSED-NAME NOTES COME AFTER THE WHOLE LIST rather than under their own line: they are prose
    # about a name, and interleaving them would break up the block of commands the reader copies from.
    $notes = @($shown | ForEach-Object {
        if ($_.PSObject.Properties['Note']) { ([string]$_.Note).TrimEnd() } else { '' }
    } | Where-Object { $_ })

    $trunk = if (([string]$TrunkBranch).Trim()) { ([string]$TrunkBranch).Trim() } else { 'main' }

    # TWO LEADING NEWLINES, so the block separates itself from whatever sentence the caller's refusal
    # ends with. The caller appends this to a one-line message; a single newline would run the two
    # together as a paragraph and the list below would read as part of the rule it is qualifying.
    $block = @"


BUT '$trunk' IS ALSO WHERE AN INTERRUPTED SHIP LEAVES THIS CHECKOUT (issue #1620). Step 2b hands the
tree back to the trunk the moment the PR exists (issue #1073), and the CI wait is the longest step in
the run -- so a ship that died in that wait owes a merge and a fold from a checkout whose HEAD no longer
names its branch, and it printed nothing on its way out. Open PR(s) whose branch is here:

$($lines -join "`n")

Check out the one you were shipping and run ship-pr again -- it RESUMES rather than starting over:
open-pr skips the create for a PR that already exists, and both merge gates read refs/heads/<branch>
(issue #970), so nothing was at risk while the tree stood on the trunk.
"@

    if ($notes.Count -gt 0) { $block += "`n" + ($notes -join "`n") }
    return $block.TrimEnd()
}

function Get-PrCreateFailureReason {
    <#
    .SYNOPSIS
        The reason `gh pr create` gave for failing, out of its captured output -- or '' when it gave none.

    .DESCRIPTION
        open-pr.ps1 replaced gh's own message with a fixed guess: "Creating the PR failed (is gh logged
        in?)". Measured in a consumer (inbound #1077) on a run where gh had just listed PRs, pushed and
        read the issue list in the same invocation -- so the one hypothesis the loudest line offered was
        the one thing that was demonstrably fine, while gh's actual answer ("No commits between main and
        <branch>") sat above it and got read as noise.

        THE LAST NON-EMPTY LINE IS THE REASON, and that is a fact about gh rather than a guess: it writes
        its progress line first ("Creating pull request for X into main in ...") and its failure last. A
        run that printed nothing at all -- gh missing, killed, or silent -- returns '', which is the one
        case where a hint about the environment is all the caller has.

        PURE, so the caller's message can be asserted without a remote. Same move and same reason as
        Get-ExistingPrRecord above it: the part that is a pure function of a command's answer becomes one.
    #>
    param([AllowNull()][string[]]$OutputLines)

    if ($null -eq $OutputLines) { return '' }
    $reason = ''
    foreach ($line in ($OutputLines | Where-Object { $_ -ne $null } | ForEach-Object { ([string]$_).Trim() })) {
        # Walked forwards and kept, rather than walked backwards: '@()' of a single string and of an
        # array behave differently enough under 5.1 that indexing from the end is the shape this repo has
        # already been bitten by. Keeping the last match needs no index at all.
        if ($line) { $reason = $line }
    }
    return $reason
}

function New-ResolvesBlock {
    <#
    .SYNOPSIS
        The markdown block that makes GitHub close the given issues when the PR merges.

    .DESCRIPTION
        ONE closing keyword per issue, one per line. This is not a style choice: GitHub does not
        distribute a single keyword over a list, so `Closes #331, #332` closes only #331 and leaves
        the second silently open -- the exact failure mode this whole gate exists to prevent.
        Returns '' for an empty set, so a caller can append unconditionally.

    .PARAMETER Issues
        The issue numbers this PR closes. Non-positive numbers are ignored; duplicates collapse.

    .PARAMETER Level
        The heading level of the block, defaulting to 2 -- what every body carried before the PR body's
        headings were promoted (Dave, August 9, 2026). It is a PARAMETER rather than a constant because
        the block must be a SIBLING of the description, not a child of it, and that is not decoration:
        -RefreshBody replaces the description section by scanning forward to the next heading at the
        description's level or shallower. A body whose description is H1 with a '## Resolved issues'
        under it would have its closing keywords SWALLOWED by the next refresh -- the block deleted,
        GitHub closing nothing at the merge, which is the #341-#343 failure arriving through the door
        that was built to prevent it. Add-ResolvesBlock reads the level off the body rather than making
        the caller state it, so a consumer whose template is still H2 keeps an H2 block.
    #>
    param(
        [int[]]$Issues,
        [ValidateRange(1, 6)][int]$Level = 2
    )

    $unique = @($Issues | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    if ($unique.Count -eq 0) { return '' }

    $lines = @((('#' * $Level) + ' Resolved issues'), '')
    foreach ($n in $unique) { $lines += "Closes #$n" }
    return ($lines -join "`n")
}

function Add-ResolvesBlock {
    <#
    .SYNOPSIS
        Appends the closing block to a PR body, separated by a blank line.

    .DESCRIPTION
        Idempotent per issue: a number the body already closes is not added a second time, so
        re-running against an already-annotated body is a no-op rather than a duplicate block.

        THE BLOCK MATCHES THE BODY'S OWN TOP LEVEL, read off its first heading outside a fence. Derived
        rather than passed, because this is called from three places on two paths (a fresh auto-filled
        template, a caller-supplied -Body, and an already-open PR's published body) and each of those can
        legitimately differ: this repo's template is H1 since August 9, 2026, a consumer's is still H2,
        and a hand-written -Body is whatever its author wrote. Reading the answer off the text is the
        only form that is right for all three without a knob anyone has to remember to set.

        Why it matters is in New-ResolvesBlock's -Level: a block deeper than the description is inside
        it, and the next -RefreshBody deletes it along with the description it replaces.
    #>
    param(
        [string]$Body,
        [int[]]$Issues
    )

    $already = @(Get-ClosedIssueNumbers -Text $Body)
    $missing = @($Issues | Where-Object { $_ -gt 0 -and $already -notcontains $_ } | Sort-Object -Unique)

    $level = 2
    $inFence = $false
    foreach ($line in ($Body -split "\r?\n")) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $m = [regex]::Match($line, '^(#+)\s+\S')
        if ($m.Success) { $level = [Math]::Min(6, $m.Groups[1].Value.Length); break }
    }

    $block = New-ResolvesBlock -Issues $missing -Level $level
    if (-not $block) { return $Body }
    if (-not $Body) { return $block }

    return ($Body.TrimEnd() + "`n`n" + $block + "`n")
}


function Get-NoResolvesMarker {
    <#
    .SYNOPSIS
        The literal line that records "this PR closes no issue" in a PR body.

    .DESCRIPTION
        THE OTHER ANSWER ALREADY PERSISTED AND THIS ONE DID NOT (issue #1912). Get-ResolvesDecision
        recognises a decision published on an open PR -- but only through the closing keywords in its
        body, and -NoResolves by definition writes none. So a branch whose author had answered the gate
        with -NoResolves was asked again by the very next run, on a PR where the answer was already
        settled, while the same branch answered with -Resolves was not. That asymmetry is the defect:
        one answer is durable and the other evaporates when the process ends.

        AN HTML COMMENT RATHER THAN A VISIBLE LINE. The closing block is functional text -- GitHub acts
        on it -- so it earns its heading. This is a record for the gate alone, and the absence of a
        'Resolved issues' block already tells a human reader that the PR closes nothing; a section
        saying so a second time would sit in every such body and inform nobody.

        Returned by a function rather than written as a literal at each site, for the same reason
        Get-PrClosingKeywords is one: three files recognise it and two write it, and a marker that is
        spelled out five times is a marker that drifts on the day somebody edits four of them.
    #>
    return '<!-- resolves: none -->'
}

function Test-NoResolvesMarker {
    <#
    .SYNOPSIS
        Does this text carry the "closes nothing" marker?

    .DESCRIPTION
        Tolerant of the whitespace a human editing the body on github.com may leave behind, and
        case-insensitive; strict about everything else, because this is a declaration the gate acts on.

        The same code-span stripping as Test-HasClosingKeyword and for the same measured reason: a
        document explaining the marker necessarily writes the marker, and this repo's own changelog
        entry for #1912 does. Without the stripping, that entry reaching a PR body verbatim would
        answer the gate on behalf of a branch that never declared anything.
    #>
    param([string]$Text)

    if (-not $Text) { return $false }
    $clean = Remove-MarkdownCodeSpans -Text $Text
    return [bool][regex]::IsMatch($clean, '(?i)<!--\s*resolves:\s*none\s*-->')
}

function Add-NoResolvesMarker {
    <#
    .SYNOPSIS
        Appends the "closes nothing" marker to a PR body. Idempotent.

    .DESCRIPTION
        Idempotent like Add-ResolvesBlock, and for the same reason: it is called after a -RefreshBody
        may already have rewritten the body, so it has to restore a marker the refresh swallowed and
        do nothing where it survived.

        Appended at the END, below any closing block. The marker is not a section, so it has no
        heading level to match and cannot be swallowed as a child of the description the way #919's
        closing block was -- but it CAN be swallowed by a refresh of a body whose description is the
        leading section, which is exactly why the caller re-appends it after every refresh.
    #>
    param([string]$Body)

    if (Test-NoResolvesMarker -Text $Body) { return $Body }
    $marker = Get-NoResolvesMarker
    if (-not $Body -or -not $Body.Trim()) { return $marker }
    return ($Body.TrimEnd() + "`n`n" + $marker + "`n")
}

function Remove-NoResolvesMarker {
    <#
    .SYNOPSIS
        Strips the "closes nothing" marker from a PR body. Idempotent.

    .DESCRIPTION
        The marker is a claim about the PR, so it must not outlive the claim. A branch that declared
        -NoResolves and later declares -Resolves would otherwise publish a body that both closes an
        issue and states it closes none -- and the gate, reading closing keywords first, would act on
        the truth while a human read the contradiction.

        Only the marker line goes; the blank line that separated it goes with it, so repeated
        add/remove cycles do not accumulate whitespace at the foot of the body.

        A BODY WITH NO MARKER IS RETURNED UNTOUCHED, byte for byte -- not trimmed, not normalised. The
        caller runs this unconditionally on every -Resolves run and decides whether to announce a body
        edit by comparing before with after, so a version that tidied trailing whitespace would report
        "removed the stale marker" about a body that never carried one, and send a PR update for it.
    #>
    param([string]$Body)

    if (-not $Body) { return $Body }
    if (-not (Test-NoResolvesMarker -Text $Body)) { return $Body }

    # A MARKER INSIDE A FENCE OR A CODE SPAN IS LEFT ALONE, and the mask is how that is known. It is not
    # a declaration -- Test-NoResolvesMarker says so -- so removing it would delete somebody's example
    # from a PR body while repairing nothing. Reached for because a body can carry BOTH: this repo's own
    # entry for #1912 writes the marker as prose, and open-pr copies an entry into the body verbatim.
    # Remove-MarkdownCodeSpans blanks with a run of the SAME LENGTH, deliberately and by its own
    # contract, so an offset in the cleaned text is the same offset in the original.
    $mask = Remove-MarkdownCodeSpans -Text $Body
    $pattern = '(?i)\r?\n?[ \t]*<!--\s*resolves:\s*none\s*-->[ \t]*\r?\n?'
    $stripped = [regex]::Replace($Body, $pattern, {
        param($m)
        if ([regex]::IsMatch($mask.Substring($m.Index, $m.Length), $pattern)) { "`n" } else { $m.Value }
    })
    return $stripped.TrimEnd() + "`n"
}
function Get-ResolvesDecision {
    <#
    .SYNOPSIS
        The gate's verdict: may this PR be opened, and with which closing block?

    .DESCRIPTION
        The whole decision table in one pure function, so the suite can assert every branch of it
        without a remote. The caller supplies what only it can know -- the explicit parameters, the
        body, and (optionally) which of the mentioned numbers GitHub reports as OPEN issues.

        Verdicts:
          - Explicit -Resolves          -> Allowed, Issues = those numbers.
          - Explicit -NoResolves        -> Allowed, Issues = @() (the author declared "closes nothing").
          - Body already closes issues  -> Allowed, Issues = the numbers the body declares.
          - Body carries the none-marker -> Allowed, Issues = @() (a "closes nothing" already published).
          - Open issues mentioned, no decision -> BLOCKED, naming them.
          - Nothing open mentioned      -> Allowed, Issues = @() (nothing to decide).

        BOTH PUBLISHED ANSWERS ARE READ, NOT ONLY ONE (issue #1912). The caller folds the body of an
        already open PR into -Body so that a resumed branch is not asked to repeat a decision GitHub
        already holds. That reasoning is about a decision PUBLISHED ON THE PR and is exactly as true of
        "closes nothing" -- but recognition used to be keyed on a closing keyword, which -NoResolves by
        definition never writes. So the same branch was durable under one answer and amnesiac under the
        other, and the second run was blocked for precisely the reason the caller's comment says it must
        not be. Get-NoResolvesMarker is what makes the second answer leave a trace to recognise.

        THE CLOSING KEYWORDS WIN WHERE A BODY CARRIES BOTH. They are what GitHub acts on at the merge,
        so reading them first is the only order under which this function and the merge agree. The
        caller strips a stale marker rather than relying on that precedence, but a body edited by hand
        on github.com can still arrive carrying both, and then this answers with what will actually
        happen.

    .PARAMETER OpenMentions
        The mentioned numbers that are OPEN issues right now. $null means "could not be determined"
        (gh unavailable or failing), which deliberately does NOT block: a gate that wedges the PR
        flow on a network hiccup would be worse than the bookkeeping slip it guards against. The
        caller warns in that case.
    #>
    param(
        [int[]]$Resolves = @(),
        [switch]$NoResolves,
        [string]$Body = '',
        [int[]]$OpenMentions = $null
    )

    $explicit = @($Resolves | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    $open = if ($null -eq $OpenMentions) { $null } else { @($OpenMentions | Where-Object { $_ -gt 0 } | Sort-Object -Unique) }

    # Undeclared = mentioned, open, and not covered by the decision. It never blocks -- deciding to
    # close only one of two mentioned issues is legitimate -- but it is REPORTED, because the whole
    # point of the gate is that an open issue never passes in silence. Found in review: a -Resolves
    # naming one of two open mentions used to make the second invisible, a partial recurrence of the
    # exact failure this gate was built for.
    function Get-Undeclared {
        param([int[]]$Declared)
        if ($null -eq $open) { return @() }
        return @($open | Where-Object { $Declared -notcontains $_ })
    }

    if ($explicit.Count -gt 0) {
        return [pscustomobject]@{
            Allowed    = $true
            Issues     = $explicit
            Reason     = 'explicit -Resolves'
            Blocked    = @()
            Undeclared = @(Get-Undeclared -Declared $explicit)
            # DeclaredNone: this verdict IS the author saying "this PR closes nothing", so the caller
            # should record it in the body. True on exactly the two answers that say so -- never on
            # "nothing open was mentioned", which is an absence of a question rather than an answer to
            # one, and never on "could not determine". Present on every verdict so a caller reads a
            # boolean rather than a missing property.
            DeclaredNone = $false
        }
    }

    if ($NoResolves) {
        return [pscustomobject]@{
            Allowed    = $true
            Issues     = @()
            Reason     = 'explicit -NoResolves'
            Blocked    = @()
            DeclaredNone = $true
            # Deliberately empty: -NoResolves IS the answer for every mentioned issue, so repeating
            # them as "undeclared" would turn an explicit decision back into a nag.
            Undeclared = @()
        }
    }

    $fromBody = @(Get-ClosedIssueNumbers -Text $Body)
    if ($fromBody.Count -gt 0) {
        return [pscustomobject]@{
            Allowed    = $true
            Issues     = $fromBody
            Reason     = 'the body already carries closing keywords'
            Blocked    = @()
            Undeclared = @(Get-Undeclared -Declared $fromBody)
            DeclaredNone = $false
        }
    }

    if (Test-NoResolvesMarker -Text $Body) {
        return [pscustomobject]@{
            Allowed    = $true
            Issues     = @()
            Reason     = 'the body already declares that this PR closes nothing'
            Blocked    = @()
            # Empty for the same reason the -NoResolves verdict above leaves it empty: the marker IS
            # the answer for every mentioned issue, so repeating them as "undeclared" would turn a
            # published decision back into a nag -- which is the whole complaint of #1912.
            Undeclared = @()
            DeclaredNone = $true
        }
    }

    if ($null -eq $open) {
        return [pscustomobject]@{
            Allowed    = $true
            Issues     = @()
            Reason     = 'the open-issue state could not be determined -- not blocking'
            Blocked    = @()
            Undeclared = @()
            DeclaredNone = $false
        }
    }

    if ($open.Count -gt 0) {
        return [pscustomobject]@{
            Allowed    = $false
            Issues     = @()
            Reason     = 'open issues are mentioned but the PR declares neither -Resolves nor -NoResolves'
            Blocked    = $open
            Undeclared = @()
            DeclaredNone = $false
        }
    }

    return [pscustomobject]@{
        Allowed    = $true
        Issues     = @()
        Reason     = 'no open issue is mentioned'
        Blocked    = @()
        Undeclared = @()
        DeclaredNone = $false
    }
}

function Get-TargetIssueWarnings {
    <#
    .SYNOPSIS
        Advisory notes that the issue(s) a branch targets may already be DONE -- the issue is
        CLOSED, or another PR already carries a closing keyword for it. One record per issue that
        has something to say; an empty array when there is nothing.

    .DESCRIPTION
        The blind spot Get-ResolvesDecision leaves, and the one issue #1282 measured. That gate
        answers "does this PR declare what it closes" and blocks ONLY on a mentioned issue that is
        still OPEN. The two states that mean the branch ITSELF may be a duplicate pass it in
        silence: the target issue CLOSED while the branch was in flight, or another open/merged PR
        that already says `Closes #<n>` for it. In #1282's own run a branch was cut to fix #1270,
        #1270 was closed by PR #1276 thirty-seven minutes later, and the duplicate reached a
        gate-green PR -- found only at the merge conflict.

        PURE, like everything else in this file: the caller asks GitHub which issues are open and
        for the candidate PRs' bodies, and hands both in. Two independent signals, reported
        together per issue:

          - IsClosed    -- OpenIssues was determinable AND this number is not in it.
          - ClaimingPrs -- other PRs (never this branch's own) in OPEN or MERGED state whose body
                           carries a closing keyword for this number. Read with the same
                           Get-ClosedIssueNumbers the resolves gate uses, so a bare mention of the
                           number in a PR body does NOT count, and a CLOSED rival PR -- an
                           abandoned attempt, which in #1282 was the duplicate itself -- does not
                           either.

        ADVISORY BY CONSTRUCTION: this returns facts, the caller writes warnings, and nothing here
        blocks. A shared number, an issue reopened after a wrong close, a PR body quoting
        `Closes #<n>` as prose: every false-match story ends with an author who reads one line and
        carries on, and none of them may wedge a real PR. That is the call #1282 asked for -- a
        warning, not a refusal -- and the same one the branch-entry CI gate makes.

    .PARAMETER TargetIssues
        The numbers this branch targets: what the development document mentions, plus any explicit
        -Resolves. Non-positive numbers and duplicates are dropped.

    .PARAMETER OpenIssues
        The open issue numbers, from the caller's single `gh issue list` query. $null means "could
        not be determined", and then IsClosed is never set on any record -- the same not-blocking
        treatment Get-ResolvesDecision gives an undeterminable state.

    .PARAMETER OtherPrsJson
        `gh pr list --search "<n> OR <n> ... in:body" --state all --json number,state,headRefName,body`
        output. Empty or unparseable -> no ClaimingPrs (the caller has already said the check could
        not run). Assign-first/wrap-second on the parse, the 5.1 trap every parse in this file
        navigates.

    .PARAMETER CurrentBranch
        This branch's name, so its own already-open PR -- whose body legitimately carries the
        closing keyword on a resumed run -- is not reported as a rival claimant.
    #>
    param(
        [int[]]$TargetIssues = @(),
        [int[]]$OpenIssues = $null,
        [string]$OtherPrsJson = '',
        [string]$CurrentBranch = ''
    )

    $targets = @($TargetIssues | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    if ($targets.Count -eq 0) { return @() }

    $open = if ($null -eq $OpenIssues) { $null } else { @($OpenIssues | Where-Object { $_ -gt 0 }) }

    $prs = @()
    if ($OtherPrsJson -and $OtherPrsJson.Trim()) {
        try {
            $parsedPrs = $OtherPrsJson | ConvertFrom-Json
            $prs = @(@($parsedPrs) | Where-Object { $_ -and $_.number })
        } catch {
            $prs = @()
        }
    }

    $warnings = @()
    foreach ($n in $targets) {
        $isClosed = ($null -ne $open) -and ($open -notcontains $n)

        $claiming = @()
        foreach ($pr in $prs) {
            $head = if ($pr.PSObject.Properties['headRefName']) { [string]$pr.headRefName } else { '' }
            if ($CurrentBranch -and $head -eq $CurrentBranch) { continue }
            $state = if ($pr.PSObject.Properties['state']) { ([string]$pr.state).Trim().ToUpperInvariant() } else { '' }
            if ($state -ne 'OPEN' -and $state -ne 'MERGED') { continue }
            $body = if ($pr.PSObject.Properties['body']) { [string]$pr.body } else { '' }
            if (@(Get-ClosedIssueNumbers -Text $body) -contains $n) {
                $claiming += [pscustomobject]@{ Number = [int]$pr.number; State = $state }
            }
        }
        $claiming = @($claiming | Sort-Object -Property Number -Unique)

        if ($isClosed -or $claiming.Count -gt 0) {
            $warnings += [pscustomobject]@{
                Issue       = $n
                IsClosed    = $isClosed
                ClaimingPrs = $claiming
            }
        }
    }
    return @($warnings)
}

function Format-CheckDuration {
    <#
    .SYNOPSIS
        A whole number of seconds as 'Xm YYs', or 'Ys' below a minute. '' for a negative input.

    .DESCRIPTION
        The shape every duration in this repo's release notes and measurements is already written in
        ('8m 37s', '14m 05s'), so a wait this script reports can be read next to those without anyone
        converting units. Seconds are zero-padded above a minute for the same reason: '9m 8s' and
        '9m 58s' do not line up in a column, '9m 08s' and '9m 58s' do.

        A negative input returns '' rather than a nonsense string, so a caller with nothing measured
        can concatenate unconditionally instead of branching. Zero returns '0s', because 0s is a real
        and (per issue #831) the MEDIAN answer here -- an empty string there would read as unmeasured.
    #>
    param([int]$Seconds)

    if ($Seconds -lt 0) { return '' }
    if ($Seconds -lt 60) { return "${Seconds}s" }
    return ('{0}m {1:d2}s' -f [int][math]::Floor($Seconds / 60), ($Seconds % 60))
}

function ConvertTo-CheckTimestamp {
    <#
    .SYNOPSIS
        One gh timestamp field as a UTC [datetime], or $null when it is absent or unreadable.

    .DESCRIPTION
        Deliberately accepts BOTH shapes, because which one arrives depends on the edition rather than
        on the payload: Windows PowerShell 5.1's ConvertFrom-Json converts an ISO-8601 string to a
        [datetime] on its own, while other editions can hand the string straight through. A caller that
        assumed either one would work on one machine and mis-read the ordering on the next -- and a
        mis-read ordering is exactly the defect the caller exists to correct.

        Parsed with InvariantCulture and AdjustToUniversal, so two checks are compared on the same clock
        regardless of the machine's locale. Returns $null rather than throwing: an unreadable timestamp
        means this record cannot take part in the ordering, which the caller handles.

        THE ZERO TIME IS UNREADABLE, and it is the third shape rather than a corner case. `gh pr checks
        --json completedAt` serialises a check that has NOT FINISHED YET as `0001-01-01T00:00:00Z` -- not
        as null, not as an empty string. Both branches below turn that into a real [datetime], which is
        not $null, so the caller's own "$null -eq $done" guard did not fire and the arithmetic after it
        ran against the floor of the type. Measured as issue #977 in a consumer repo: the [int] cast in
        Get-CheckWaitReport overflowed on -63,923,427,029 seconds and killed a ship-pr run AFTER it had
        printed `CI green.` and BEFORE the merge -- the PR unmerged, the entry unfolded, every check
        green. The wait step is the one place in the script that is guaranteed to be racing GitHub, so
        any check that registers while --watch is returning is in that window.

        Tested on the YEAR rather than on equality with [datetime]::MinValue, because the two are not the
        same test. A MinValue of Kind Unspecified sent through ToUniversalTime lands NEAR the floor and
        not on it -- clamped back to MinValue where the machine's offset is positive, shifted UP by the
        offset where it is negative -- so an equality test would hold in Amsterdam and miss in New York.
        No CI check ran in year 1.
    #>
    param($Value)

    if ($null -eq $Value) { return $null }

    $stamp = $null
    if ($Value -is [datetime]) {
        $stamp = $Value.ToUniversalTime()
    } else {
        $text = [string]$Value
        if (-not $text.Trim()) { return $null }
        try {
            $stamp = [datetime]::Parse(
                $text,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        } catch {
            return $null
        }
    }

    if ($stamp.Year -le 1) { return $null }
    return $stamp
}

function ConvertTo-CheckSeconds {
    <#
    .SYNOPSIS
        A [timespan] between two check timestamps as a whole number of seconds an [int] can hold, or -1
        when it cannot -- the value Get-CheckWaitReport and Format-CheckDuration both read as unmeasured.

    .DESCRIPTION
        ROUND FIRST, RANGE-CHECK, CAST LAST. Exists because the reverse order was written twice, at both
        arithmetic sites in Get-CheckWaitReport, and `[int][math]::Round(...)` throws on an out-of-range
        double before any guard on the next line can look at it -- so the sanity check that WAS there
        ("if ($ran -lt 0) { $ran = -1 }") was unreachable by construction (issue #977).

        ConvertTo-CheckTimestamp above closes the door that defect actually came through, and this closes
        the class: a payload carrying a readable but absurd timestamp (a far-future completedAt) is still
        a span no [int] holds, from the same untrusted field, and it would reach the same cast. Returning
        -1 keeps the failure in the vocabulary the callers already speak, so a duration this cannot
        render is simply left out of the line instead of aborting the run that was printing it.
    #>
    param([timespan]$Span)

    $seconds = [math]::Round($Span.TotalSeconds)
    if ($seconds -lt 0 -or $seconds -gt [int]::MaxValue) { return -1 }
    return [int]$seconds
}

function Get-CheckWaitReport {
    <#
    .SYNOPSIS
        One line saying WHICH check governed a PR's merge wait and for how long, from a
        `gh pr checks --json` payload. $null when the payload cannot answer that.

    .DESCRIPTION
        ship-pr.ps1 waits for every check a PR has and reads the exit code. That is deliberate and does
        not change here -- but it made the wait invisible: a run printed gh's own table and nothing
        about the ordering, so learning which check had held it up meant opening the Actions page
        afterwards. Measured over n=100 paired runs in the source repo (issue #831), the non-required
        check governs the wait 23% of the time at a median cost of 0s -- a different answer from the one
        two individual observations had suggested, and the reason those two became a policy question at
        all is that nobody could see the ordinary case. This report is the ordinary case, printed.

        THE SELECTION IS THE PART THAT NEEDS A TEST, not the query -- the same split as
        Get-ExistingPrRecord above, for the same reason: the caller drives a live remote and no suite
        can reach it, while this can.

        IT NAMES NO CHECK OF ITS OWN. The governing check is whichever one finished LAST in the payload,
        and 'required' comes from `gh pr checks --required`, i.e. from the repo's own ruleset. A
        hardcoded name here would be a claim about a consumer's CI that this script cannot keep, which
        is what the step-3 comment in ship-pr.ps1 has said since it was written.

        Degrades to $null rather than guessing: empty or unparseable JSON, no record carrying a name, or
        no record with a readable completedAt. Without -RequiredNamesJson the line omits the
        required/not-required label entirely, because an unknown answer stated either way is worse than
        an unstated one.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,startedAt,completedAt` output (state/bucket may ride along).

    .PARAMETER RequiredNamesJson
        `gh pr checks <pr> --required --json name` output. Optional.

    .PARAMETER WaitedSeconds
        The wall-clock this script itself spent on step 3. Negative means unmeasured, and is then left
        out of the line rather than reported as zero.

    .PARAMETER PostMerge
        Word the line for a report printed AFTER the merge (ship-pr's step 8, issue #1602): the
        governing check is named as having finished last, without the claim that it governed a merge
        that has already happened. Everything else about the line is identical. Omitted, the line is
        byte-for-byte the one #831 shipped.
    #>
    param(
        [string]$ChecksJson,
        [string]$RequiredNamesJson = '',
        [switch]$PostMerge,
        [int]$WaitedSeconds = -1
    )

    if (-not $ChecksJson -or -not $ChecksJson.Trim()) { return $null }

    try { $parsed = $ChecksJson | ConvertFrom-Json } catch { return $null }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object.
    $records = @(@($parsed) | Where-Object { $_ -and $_.name })
    if ($records.Count -eq 0) { return $null }

    $finished = @()
    foreach ($r in $records) {
        $done = ConvertTo-CheckTimestamp -Value $r.completedAt
        if ($null -eq $done) { continue }

        $ran = -1
        $began = ConvertTo-CheckTimestamp -Value $r.startedAt
        if ($null -ne $began) { $ran = ConvertTo-CheckSeconds -Span ($done - $began) }
        $finished += [pscustomobject]@{ Name = [string]$r.name; Completed = $done; Ran = $ran }
    }
    if ($finished.Count -eq 0) { return $null }

    $governing = @($finished | Sort-Object -Property Completed -Descending)[0]

    $required = @()
    if ($RequiredNamesJson -and $RequiredNamesJson.Trim()) {
        try {
            # ASSIGN FIRST, WRAP SECOND -- the same 5.1 rule the ChecksJson parse above already follows,
            # and this parse did not until August 26, 2026. Inlined as
            # `@(@($RequiredNamesJson | ConvertFrom-Json) | ...)` it collapsed the whole payload into ONE
            # element, whose `.name` member-enumerates to every name at once: two required checks became
            # the single bogus string 'a b', so `-contains` never matched and the label read ', NOT
            # required' for a check that was required. It survived unseen because this repo's ruleset
            # requires exactly ONE check, and a one-element JSON array is handed through as the object
            # itself -- so the only shape anybody ran was the one shape that happens to work. Measured
            # both ways when Get-MergeBlockVerdict below hit the identical trap.
            $parsedRequired = $RequiredNamesJson | ConvertFrom-Json
            $required = @(@($parsedRequired) |
                Where-Object { $_ -and $_.name } |
                ForEach-Object { [string]$_.name })
        } catch {
            $required = @()
        }
    }

    $parts = @()
    if ($WaitedSeconds -ge 0) { $parts += "waited $(Format-CheckDuration -Seconds $WaitedSeconds)" }

    $label = ''
    $isRequired = $false
    if ($required.Count -gt 0) {
        $isRequired = $required -contains $governing.Name
        $label = if ($isRequired) { ', required' } else { ', NOT required' }
    }

    $ran = if ($governing.Ran -ge 0) { Format-CheckDuration -Seconds $governing.Ran } else { 'duration unknown' }
    # "GOVERNED THE MERGE" IS ONLY TRUE BEFORE THE MERGE (issue #1602). Since ship-pr's step 8 the
    # same report is also printed AFTER the merge and the fold, over the full payload, once the
    # non-required checks have finally reported -- and there the phrase inverts the very fact the
    # report exists to carry. On a lap where the non-required check finishes last, post-merge, the
    # line would read `'claude-review' finished last and governed the merge (6m, NOT required)` about
    # a merge that had gone six minutes earlier precisely BECAUSE it no longer waits for that check.
    # A reader would conclude the opposite of what happened, in the one place they meet the fact --
    # and on the 21% of laps this whole change is about. Measured on PR #1614's own successful ship,
    # where the phrase was correct only because `lint-en-tests` happened to finish last that lap.
    #
    # THE REST OF THE LINE IS UNCHANGED AND STILL WANTED, which is why this is a wording switch and
    # not a second function: which check finished last, how long it ran, whether the ruleset requires
    # it, and how much later it finished than the last required check are all exactly as useful after
    # the merge as before it. Only the claim about causation moves.
    $governedPhrase = if ($PostMerge) { "finished last" } else { "finished last and governed the merge" }
    $parts += "'$($governing.Name)' $governedPhrase ($ran$label)"

    # What waiting on a non-required check actually cost on THIS run: the gap between it and the last
    # required check to finish. Stated only when both halves are known -- a figure assembled from a
    # guess is the defect this whole report exists to correct.
    if ($required.Count -gt 0 -and -not $isRequired) {
        $lastRequired = @($finished |
            Where-Object { $required -contains $_.Name } |
            Sort-Object -Property Completed -Descending)
        if ($lastRequired.Count -gt 0) {
            $excess = ConvertTo-CheckSeconds -Span ($governing.Completed - $lastRequired[0].Completed)
            if ($excess -gt 0) {
                $parts += "$(Format-CheckDuration -Seconds $excess) after the last required check ('$($lastRequired[0].Name)')"
            }
        }
    }

    return ($parts -join '; ')
}

function Format-CheckNameList {
    <#
    .SYNOPSIS
        A list of check names as readable prose: "'a'", "'a' and 'b'", "'a', 'b' and 'c'". '' when empty.

    .DESCRIPTION
        Exists because Get-MergeBlockVerdict's Reason is read by a human in a terminal at the moment a
        merge either happens or does not, so a bare PowerShell array rendering ('System.Object[]', or a
        space-joined run of names) is the wrong output for the one line that explains the decision.

        Quoted per name rather than around the whole list, so a check name containing a space cannot be
        mistaken for two. Empty in, empty out -- a caller with nothing to name concatenates it
        unconditionally instead of branching, the same tolerance Format-CheckDuration already applies.
    #>
    param([string[]]$Names)

    $clean = @(@($Names) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { "'$_'" })
    if ($clean.Count -eq 0) { return '' }
    if ($clean.Count -eq 1) { return $clean[0] }
    return (($clean[0..($clean.Count - 2)] -join ', ') + ' and ' + $clean[-1])
}

function Get-CheckOutcome {
    <#
    .SYNOPSIS
        One `gh pr checks --json` record reduced to 'pass', 'fail', 'pending' or 'unknown'.

    .DESCRIPTION
        Reads `bucket` first and `state` as the fallback, because which one a payload carries depends on
        what the caller asked for rather than on the check: `bucket` is a gh convenience field and
        `state` is the API's own word. A caller that asked for both gets the cheaper read; one that asked
        for only the second still gets an answer.

        'unknown' is a real answer and NOT a synonym for 'pass'. A record whose outcome cannot be read is
        a check nobody has proved green, and the only caller of this function is deciding whether a merge
        is safe -- so it needs the difference. That is also why the fail list is generous: cancelled,
        timed out and startup-failed are all "not green", and treating any of them as passing would let a
        merge through on a check that never ran.

        NEUTRAL and SKIPPED map to 'pass' because GitHub itself does not let either block a merge, and
        EXPECTED maps to 'pending' because it means a status that is awaited and has not arrived.
    #>
    param($Record)

    if ($null -eq $Record) { return 'unknown' }

    # A field the caller never asked gh for is absent, and absent is not empty under Set-StrictMode --
    # so ask the object whether it carries the property before reading it.
    $bucket = ''
    if ($Record.PSObject.Properties['bucket']) { $bucket = ([string]$Record.bucket).Trim().ToLowerInvariant() }
    switch ($bucket) {
        'pass'     { return 'pass' }
        'skipping' { return 'pass' }
        'fail'     { return 'fail' }
        'cancel'   { return 'fail' }
        'pending'  { return 'pending' }
    }

    $state = ''
    if ($Record.PSObject.Properties['state']) { $state = ([string]$Record.state).Trim().ToUpperInvariant() }
    switch ($state) {
        'SUCCESS'         { return 'pass' }
        'NEUTRAL'         { return 'pass' }
        'SKIPPED'         { return 'pass' }
        'FAILURE'         { return 'fail' }
        'ERROR'           { return 'fail' }
        'CANCELLED'       { return 'fail' }
        'TIMED_OUT'       { return 'fail' }
        'ACTION_REQUIRED' { return 'fail' }
        'STARTUP_FAILURE' { return 'fail' }
        'IN_PROGRESS'     { return 'pending' }
        'QUEUED'          { return 'pending' }
        'PENDING'         { return 'pending' }
        'WAITING'         { return 'pending' }
        'REQUESTED'       { return 'pending' }
        'EXPECTED'        { return 'pending' }
    }

    return 'unknown'
}

function Get-RequiredCheckNames {
    <#
    .SYNOPSIS
        The check names in a `gh pr checks --required --json name,...` payload, sorted and unique.
        Empty when the payload is absent, unparseable, or names nothing.

    .DESCRIPTION
        ONE PARSE, THREE CALLERS, AND IT WAS THREE PARSES UNTIL ISSUE #1602. `gh pr checks --required`
        is read at three points in ship-pr.ps1 -- to decide which checks the wait must block on
        (#1602), to name what the staleness gate is protecting (#1292), and inside
        Get-CheckWaitReport's own label -- and each had written out the same walk over the payload.
        That is the shape the 5.1 pitfall this file documents everywhere thrives in: the collapse
        Get-CheckWaitReport hit on August 26, 2026, where `@(@($json | ConvertFrom-Json) | ...)`
        member-enumerated two required names into the single bogus string 'a b', survived unseen for
        weeks precisely BECAUSE this repo's ruleset requires exactly one check and a one-element JSON
        array is handed through as the object itself. A repo with two required checks is the shape
        nobody here runs, so a fourth copy of the walk is a fourth chance to ship that bug to a
        consumer who does.

        EMPTY IS NOT AN ERROR AND MUST NOT BE READ AS ONE. `--required` exits non-zero on a repo whose
        ruleset requires nothing, which is a legitimate state -- GitHub Free with no ruleset is the
        documented case -- and it is indistinguishable from here from "the required checks have not
        reported yet". Every caller therefore has to choose its own tie-break and this function makes
        none for them: Get-MergeBlockVerdict refuses on the failure path and stays green on the green
        one, step 3b warns and skips, and the #1602 wait falls back to watching every check. What they
        share is only the walk.

        SORTED AND UNIQUE so a caller can compare two readings for equality without sorting first --
        the #1602 wait re-reads this list between watch attempts and only wants to know whether the
        answer changed.

    .PARAMETER RequiredChecksJson
        `gh pr checks <pr> --required --json name` output; any other fields may ride along and are
        ignored. Anything that will not parse yields an empty list rather than throwing: every caller
        of this treats "could not read" as a state to decide about, not as a failure to propagate.
    #>
    param([string]$RequiredChecksJson)

    if (-not $RequiredChecksJson -or -not $RequiredChecksJson.Trim()) { return @() }
    try { $parsed = $RequiredChecksJson | ConvertFrom-Json } catch { return @() }

    # Assign first, wrap second -- the 5.1 rule the docstring above gives the measured cost of.
    $records = @(@($parsed) | Where-Object { $_ -and $_.name })
    if ($records.Count -eq 0) { return @() }

    return @(@($records | ForEach-Object { [string]$_.name } | Where-Object { $_ -and $_.Trim() }) |
        Sort-Object -Unique)
}

function Get-MergeBlockVerdict {
    <#
    .SYNOPSIS
        Whether a failing CI run actually blocks the merge -- i.e. whether what failed is a check the
        repo's ruleset REQUIRES. Returns Blocked / Reason / FailedRequired / FailedOther /
        UnfinishedRequired.

    .DESCRIPTION
        ship-pr.ps1 waits for every check a PR has and used to read the exit code of
        `gh pr checks --watch` as its verdict. That exit code is non-zero when ANY check fails, and the
        comment above it justified the refusal with "branch protection blocks the merge until green" --
        which is true only of a REQUIRED check. So the script was stricter than the ruleset it exists to
        respect, and on August 26, 2026 that difference was the whole chain: `claude-review` went red on
        every PR (issue #942) while `lint-en-tests`, the only check the `main` ruleset requires, was
        green. GitHub reported those PRs as MERGEABLE / UNSTABLE -- its own word for "mergeable, with a
        non-required check failing" -- and the script read it as BLOCKED (issue #943).

        THE WAIT IS UNCHANGED, and deliberately so. Issue #831 measured over n=100 paired runs that the
        non-required check governs the wait 23% of the time at a median cost of 0s, and Dave's answer
        (August 24, 2026) was to keep the wait and make it legible instead. Waiting on a non-required
        check costs seconds; REFUSING on one costs the merge for as long as that workflow is broken, and
        nobody had measured that. So only the verdict moves here, which is also why this takes the
        issue's second direction rather than its first: switching the WATCH to `--required` would have
        stopped waiting on a pending non-required check too, a second change with no measurement behind
        it.

        THE SELECTION IS THE PART THAT NEEDS A TEST, not the query -- the same split as
        Get-CheckWaitReport and Get-ExistingPrRecord above, for the same reason: the caller drives a live
        remote no suite can reach, while this can be handed a payload.

        READ THE PAYLOAD, NEVER AN EXIT CODE. Measured on PR #937 (August 26, 2026):
        `gh pr checks 937 --json name,bucket,state` returns exit 0 while reporting `claude-review` as
        `fail`. JSON mode carries the outcome in the records and not in the exit status, so a caller that
        read the exit code of the JSON call would conclude everything passed.

        AND THE UNREADABLE CASE REFUSES. Without a readable required-check list this cannot tell a
        ruleset that requires nothing from one whose required checks have not reported yet, so it keeps
        the old behaviour rather than guessing: a script that lets a merge through on an unread ruleset
        is a worse defect than the one being repaired. `gh pr checks --required` prints nothing and exits
        non-zero where a ruleset requires nothing, which is exactly that case.

        AND SINCE INBOUND #1549 THE PENDING LIST IS RETURNED, NOT ONLY SPOKEN. `$unfinishedRequired` was
        already computed here and only ever reached the caller as prose inside `Reason`, so the one
        caller that needed to ACT on it -- ship-pr's step 3, deciding whether a green `--watch` exit is
        really green -- had no field to read and broke past this function entirely. That is the whole
        defect #1549 reported: `gh pr checks --watch` watches the checks registered when it STARTS, so a
        fast non-required check reporting first exits 0 while the required one is still pending, and the
        script called CI green after 5s and was refused by the base-branch policy at the merge. Measured
        in a consumer on September 7, 2026 (`dkj-policy` 4.31.0, BWJ-Development/smartwatchbanden PR
        #529): required `Shopify theme check` pending at 0s and green at 2m1s, and a plain
        `gh pr merge` succeeded unchanged once it finished.

        THE VERDICT ITSELF IS UNTOUCHED, which is the same sentence every sibling note here gives. This
        change adds a field; it does not move a single Blocked decision, and it cannot let a merge
        through -- the caller reading the new field only ever WAITS longer.

    .PARAMETER RequiredChecksJson
        `gh pr checks <pr> --required --json name,bucket,state` output. The verdict is made from this and
        from nothing else.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state` output, i.e. every check. Optional, and used only to
        NAME the not-required checks that failed -- never for the verdict. Left out, the verdict is
        identical and the reason simply does not list them.
    #>
    param(
        [string]$RequiredChecksJson,
        [string]$ChecksJson = ''
    )

    $unreadable = [pscustomobject]@{
        Blocked            = $true
        Reason             = 'the required-check list could not be read, so which checks this ruleset requires is unknown -- refusing on the CI failure, exactly as before'
        FailedRequired     = @()
        FailedOther        = @()
        # EMPTY BECAUSE NOTHING WAS READ, and the asymmetry that produces is deliberate (inbound
        # #1549). On the FAILURE path this shape still refuses, exactly as it always did. On the GREEN
        # path the caller waits only on a NON-EMPTY list, so an unreadable payload leaves a green run
        # green -- which is what keeps this function's founding invariant intact: an unreadable payload
        # can never turn a GREEN run red. "This ruleset requires nothing" and "the required checks have
        # not reported yet" are indistinguishable from here, and only one of the two is worth waiting
        # on, so the tie is broken towards not waiting.
        UnfinishedRequired = @()
    }

    if (-not $RequiredChecksJson -or -not $RequiredChecksJson.Trim()) { return $unreadable }
    try { $parsedRequired = $RequiredChecksJson | ConvertFrom-Json } catch { return $unreadable }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object.
    $requiredRecords = @(@($parsedRequired) | Where-Object { $_ -and $_.name })
    if ($requiredRecords.Count -eq 0) { return $unreadable }

    $failedRequired = @()
    $unfinishedRequired = @()
    $requiredNames = @()
    foreach ($r in $requiredRecords) {
        $name = [string]$r.name
        $requiredNames += $name
        switch (Get-CheckOutcome -Record $r) {
            'fail'    { $failedRequired += $name }
            'pending' { $unfinishedRequired += $name }
            'unknown' { $unfinishedRequired += $name }
        }
    }
    $failedRequired = @($failedRequired | Sort-Object -Unique)
    $unfinishedRequired = @($unfinishedRequired | Sort-Object -Unique)
    $requiredNames = @($requiredNames | Sort-Object -Unique)

    if ($failedRequired.Count -gt 0) {
        $it = if ($failedRequired.Count -eq 1) { 'it' } else { 'they' }
        return [pscustomobject]@{
            Blocked            = $true
            Reason             = "the ruleset REQUIRES $(Format-CheckNameList -Names $failedRequired), and $it failed"
            FailedRequired     = $failedRequired
            FailedOther        = @()
            UnfinishedRequired = $unfinishedRequired
        }
    }

    if ($unfinishedRequired.Count -gt 0) {
        $has = if ($unfinishedRequired.Count -eq 1) { 'has' } else { 'have' }
        return [pscustomobject]@{
            Blocked            = $true
            Reason             = "the required check $(Format-CheckNameList -Names $unfinishedRequired) $has not finished, or its state could not be read -- so the merge is not green"
            FailedRequired     = @()
            FailedOther        = @()
            UnfinishedRequired = $unfinishedRequired
        }
    }

    # Every required check passed, so the merge is not blocked. What remains is naming what DID fail,
    # which is presentation only -- an unreadable payload here costs the reader some detail and cannot
    # change the verdict above it.
    $failedOther = @()
    if ($ChecksJson -and $ChecksJson.Trim()) {
        try {
            # Assign first, wrap second -- see the note in Get-CheckWaitReport above.
            $parsedAll = $ChecksJson | ConvertFrom-Json
            $failedOther = @(@($parsedAll) |
                Where-Object { $_ -and $_.name } |
                Where-Object { $requiredNames -notcontains [string]$_.name } |
                Where-Object { (Get-CheckOutcome -Record $_) -eq 'fail' } |
                ForEach-Object { [string]$_.name })
        } catch {
            $failedOther = @()
        }
        $failedOther = @($failedOther | Sort-Object -Unique)
    }

    $what = if ($failedOther.Count -gt 0) {
        $them = if ($failedOther.Count -eq 1) { 'it' } else { 'them' }
        "$(Format-CheckNameList -Names $failedOther) failed, and the ruleset does not require $them"
    } else {
        'what failed is not a check the ruleset requires'
    }
    return [pscustomobject]@{
        Blocked            = $false
        Reason             = "every required check passed ($(Format-CheckNameList -Names $requiredNames)); $what"
        FailedRequired     = @()
        FailedOther        = $failedOther
        # Necessarily empty on this path -- reaching it means both lists above were empty -- and carried
        # anyway so every shape this function returns has the same fields. A caller that reads
        # UnfinishedRequired must not have to know which branch produced its verdict.
        UnfinishedRequired = $unfinishedRequired
    }
}

function Get-RequiredCheckRunIds {
    <#
    .SYNOPSIS
        The distinct GitHub Actions run ids behind a PR's NAMED checks (typically the required ones),
        read from a `gh pr checks --json` payload's `link` field, in payload order and without
        duplicates. Empty when none of the named checks carry a resolvable run link.

    .DESCRIPTION
        THE RE-ANCHOR ISSUE #1292's RED-TEAM FORCED (September 3, 2026): the retired
        Get-CertifyingRunTimestamp read a check's own `startedAt` directly out of the checks payload,
        reasoned as "conservative" on the claim that queueing only pushes it later than the moment the
        merge ref was fixed. That reasoning had the failure DIRECTION backwards -- see
        Get-CertifyingRunCreatedAt's own header for why -- and the fix needs the RUN behind the check
        rather than the check's own timestamp, because it is the run's `created_at` that stays anchored
        to the moment GitHub actually fixed the merge ref.

        Get-FailedCheckRunRefs already reads this same `link` field (`.../actions/runs/<runId>/job/
        <jobId>`) to find the run behind a FAILING check (#1103); this is the same read for a NAMED set
        instead of a failing one. Kept separate rather than generalising that function, because its
        callers want the JOB id too (for annotations) and this one never does -- asking gh for a run's
        `created_at` needs only the RUN id.

        A link that names no run (an external status check, or an unresolvable job/run URL) is skipped,
        the same restraint Get-FailedCheckRunRefs applies and for the same reason: a key scraped out of
        such a URL would address something that is not a GitHub Actions run at all. THAT SKIP IS WHY THE
        CALLER TREATS AN EMPTY RESULT DIFFERENTLY DEPENDING ON WHAT IT ALREADY KNOWS: a required check
        that is not a `pull_request`-triggered Actions run (an external CI service posting a commit
        status) has no merge-ref-goes-stale mechanism to protect in the first place, which is a
        different state from "the run exists and could not be read".

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state,startedAt,completedAt,link` output -- the same
        payload step 3 already reads for Get-CheckWaitReport and the failure diagnostics.

    .PARAMETER Names
        The check names to find a run id for -- typically the required check names, from whichever read
        named them in the first place.
    #>
    param(
        [string]$ChecksJson,
        [string[]]$Names = @()
    )

    $wanted = @($Names | Where-Object { $_ -and ([string]$_).Trim() })
    if ($wanted.Count -eq 0) { return @() }
    if (-not $ChecksJson -or -not $ChecksJson.Trim()) { return @() }

    try { $parsed = $ChecksJson | ConvertFrom-Json } catch { return @() }
    # Assign first, wrap second -- the 5.1 pitfall every parse in this file already avoids.
    $records = @(@($parsed) | Where-Object { $_ -and $_.name -and ($wanted -contains [string]$_.name) })

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($r in $records) {
        if (-not $r.PSObject.Properties['link']) { continue }
        $link = [string]$r.link
        if ($link -notmatch '/actions/runs/(\d+)') { continue }
        $runId = $Matches[1]
        if (-not $ids.Contains($runId)) { $ids.Add($runId) | Out-Null }
    }
    return @($ids)
}

function Get-CertifyingRunCreatedAt {
    <#
    .SYNOPSIS
        The earliest 'created_at' among a set of already-fetched GitHub Actions run records -- the
        moment (before any queueing, and stable across a re-run) closest to when GitHub fixed the merge
        ref a required check tested. $null when none is readable.

    .DESCRIPTION
        RE-ANCHORED SEPTEMBER 3, 2026 AFTER A RED-TEAM CAUGHT THE FIRST VERSION'S BIAS (issue #1292).
        The retired Get-CertifyingRunTimestamp read a required check's own `startedAt`, reasoned as
        "conservative because queueing only pushes it LATER than the true ref-fix moment, so a commit
        landing in that gap is rarely missed". That sentence had the DIRECTION right and the CHOICE
        backwards: a LATER anchor makes the caller's `git log --since=<anchor>` MISS commits that landed
        in the gap between the true ref-fix moment and the anchor -- so a genuinely stale certificate
        reads as SOUND, which is the one failure mode this whole gate exists to prevent (a false SOUND
        verdict lands a red trunk; a false STALE verdict only costs a re-run).

        THE GAP IS FAR LARGER THAN "SUB-MINUTE" IN THIS REPO, for two independent reasons neither the
        original 45-PR sample could see (that sample measured staleness AFTER anchoring on `startedAt`,
        so it was silent on the size of the gap between `startedAt` and the true ref-fix moment):
          - `windows-latest` runner provisioning, which every run here pays, routinely costs over a
            minute between a run's creation and a job's `startedAt`.
          - "Re-run failed jobs" against a flaky suite (ordinary practice in this repo) re-runs the SAME
            commit -- GitHub does not recompute the merge ref -- while `startedAt` jumps forward by
            however long the operator waited before re-running. The gap goes from seconds to hours.

        VERIFIED RATHER THAN ASSUMED, on a genuine re-run in this repo's own history (run `33652133970`,
        measured September 3, 2026): reading the RUN object (`GET .../actions/runs/<id>`, which is what
        the runs LIST endpoint also returns) after a re-run reports `created_at` = `2026-09-02T15:59:52Z`
        -- UNCHANGED from `run_attempt` 1 -- while `run_started_at` had moved to `2026-09-02T21:15:50Z`,
        over five hours later. Reading `.../attempts/2` directly (the per-attempt sub-resource) instead
        reports ITS OWN `created_at` of `2026-09-02T21:15:51Z`, matching its own late start -- which is
        the value that would have reintroduced the identical bias. So the run object (or the runs list),
        never the per-attempt one, is what a caller must read.

        THE ERROR DIRECTION NOW FAVOURS OVER-REFUSING, WHICH IS THE SAFE SIDE FOR THIS GATE. A run's
        `created_at` is at or before the moment it actually began work, so anchoring here can only make
        the caller see a WIDER window of 'main' than the one truly at risk: a certificate this predicate
        calls stale is never one that was actually still sound. The sole cost of being wrong is a rarer,
        occasionally unnecessary refusal -- the direction this gate is supposed to fail in.

        TWO THINGS THIS DOES NOT CLAIM, both worth stating plainly rather than assuming: a `pull_request`
        run exists at all only for a MERGEABLE pull request -- GitHub creates none for one with a merge
        conflict, which is harmless here because an unmergeable PR cannot be shipped by this script
        either way. And "GitHub fixes THE merge ref" is this repo's own practical experience with a
        single-job workflow, not a documented contract: different jobs of one triggering event have been
        observed resolving different merge commits in the wild (actions/checkout#27), so this reasons
        from "a run's created_at cannot postdate its own ref-fix moment" rather than from "there is
        exactly one ref every job of a run agrees on".

        PURE: the caller (ship-pr.ps1) finds which run(s) sit behind the required check(s) with
        Get-RequiredCheckRunIds, asks gh for each run's `created_at`
        (`gh api repos/<repo>/actions/runs/<id> --jq '.created_at'`), and hands the raw values here.
        More than one value arises only when a ruleset requires checks from more than one distinct
        triggering run; the earliest is the one closest to when ANY of them fixed a ref this branch is
        being merged against.

        THE ZERO-TIME CASE IS STILL GUARDED, via ConvertTo-CheckTimestamp, even though a run's
        `created_at` is a real timestamp in every payload GitHub has been observed to send: the guard
        costs nothing on the ordinary path and means an unreadable or placeholder value handed in by a
        caller can never win as the earliest -- the same discipline Get-CheckWaitReport and the retired
        Get-CertifyingRunTimestamp already applied, kept here because a zero anchor voiding EVERY
        certificate is the one wrong answer this function must never produce.

    .PARAMETER CreatedAtValues
        Raw `created_at` values already fetched for the run(s) behind the required check(s). Unreadable
        or zero-time entries are dropped rather than trusted.
    #>
    param([string[]]$CreatedAtValues = @())

    $timestamps = @()
    foreach ($v in @($CreatedAtValues | Where-Object { $_ -and ([string]$_).Trim() })) {
        $ts = ConvertTo-CheckTimestamp -Value $v
        if ($null -ne $ts) { $timestamps += $ts }
    }
    if ($timestamps.Count -eq 0) { return $null }
    return (@($timestamps | Sort-Object)[0])
}

function Test-IsFoldOnlyCommit {
    <#
    .SYNOPSIS
        Whether one commit 'main' gained is a FOLD COMMIT and nothing else -- the changelog plus the
        removal of a branch document, which is exactly the scope the fold exception is granted at.
        Issue #1592's narrowing of the staleness predicate below.

    .DESCRIPTION
        WHY A FOLD IS EXEMPT, AND WHY THAT IS NOT THE PATH FILTER #1292 DECLINED. Get-StaleCertificateVerdict's
        own docstring turns down filtering on which files a gained commit touched, on the ground that
        "predicting which file a future test depends on is not this script's to do". That reasoning holds and
        is untouched: it is about an ARBITRARY commit, whose content this script would have to guess the reach
        of. A fold is not arbitrary. It is written by fold-changelog-entry.ps1, under a named exception to
        "never commit directly on main" whose bound is stated as exactly two paths, and enforced by git
        rather than by care -- 'git commit -- <paths>' with the changelog and the entry files named, so
        nothing else can ride along. This function re-derives that bound from the commit's OWN diff rather
        than trusting the subject line, so a commit only reads as a fold if it provably has a fold's shape.
        The hazard #1292 exists to catch is a TEST BLOCK reaching 'main' that the shipping branch's CI never
        executed (its instance: PR #1268 removing a completion that a test block landed on 'main' asserts on).
        A commit carrying no script, no test, no manifest and no agent def cannot be that.

        MEASURED, September 8, 2026 (issue #1592). Shipping PR #1571 took four ship-pr attempts and about an
        hour, two of them ending at the stale-CI refusal. The three commits that voided those two certificates
        were 4ea4f31b, 437366a4 and 072bb6bd -- ALL THREE folds, each one 'dkj-policy/CHANGELOG.md' plus the
        deletion of one branch document, nothing else. Both refusals were therefore on commits that could not
        have turned the trunk red, and both would have passed with this exemption in place. Over the trunk's
        own history in that window (07:50Z-09:30Z, 19 first-parent commits) 10 were folds -- and 71 of 169
        (42%) over the four days to that morning -- so the exemption
        roughly halves the rate at which the trunk voids a certificate -- which is what decides whether
        detect-and-rebase converges at all, the certificate's window being about as long as CI itself takes.

        AND THE REPORTED REASON WAS NOT THIS ONE, which is why the repair is here and not at the wait.
        #1592 attributed the window to ship-pr waiting on the NON-required 'claude-review' check, reading
        "lint-en-tests finished in 2s" off the check table. That 2s is the AGGREGATOR job's own elapsed:
        'lint-en-tests' in ci.yml is a needs: [lint, suites] job on ubuntu that compares two strings, so it
        cannot conclude before the two windows-latest legs it waits on. Measured over the last 40 paired
        pull_request runs, CI itself takes 310-461s (median 374s) and the non-required check governs 8 of the
        40 -- 20%, median excess 0s across all of them and about 6 minutes in the 8 where it does govern
        -- which reconfirms #831's own n=100 finding of 23% rather than overturning it, and leaves the wait
        exactly where Dave left it. Of the two refusals, attempt 3's first voiding commit landed BEFORE its
        required check concluded, so it was lost before the certificate was ever valid.

        FAILS CLOSED, EVERY WAY IN. An unreadable diff, a shape with two paths (a rename or a copy, which the
        fold does not produce), a path outside the entry folder, a path NESTED below it, a branch document
        touched rather than removed, a changelog that is deleted rather than written, a missing seam, or no
        branch-document deletion at all: each returns $false, and a commit that
        does not read as a fold is counted exactly as it was before this function existed.

        ONE KNOWN FALSE NEGATIVE, AND IT IS THE SAFE DIRECTION. Folding a branch cut before the
        August 23, 2026 document merge can additionally remove Get-BranchFilePaths' LegacyCycle,
        'dkj-policy/branch/branch-cycle.md' -- nested one level down, so the flat-leaf test above
        disqualifies the whole commit and that fold is not exempted. The operator then gets the ordinary
        pre-#1592 refusal and its remedy, which is what they got for the fifteen days before this existed.
        Left as it is deliberately: admitting a subfolder to buy back a vanishingly rare shape widens the
        bound for every commit, and the bound is the only thing this function has to offer. The residual this
        leaves is named rather than engineered around: a fold's changelog text could link to a path the
        shipping branch deletes, and the dead-link scan would then go red on the trunk. It is the cheapest
        class of red there is, it is caught by the trunk's own CI within minutes, and the text was already on
        'main' -- and already scanned -- inside the branch document the fold moves it out of.

        PURE, like every other verdict in this file: the caller reads the diff (git show --name-status) and
        hands the lines here.

    .PARAMETER NameStatusLines
        'git show --name-status --format= <sha>' output for one commit: tab-separated '<status>' and '<path>'
        lines. Blank entries are dropped; an empty list reads as "not a fold", never as a vacuous yes.

    .PARAMETER ChangelogPath
        The repo-relative changelog path, as the caller's own seam answers it (Get-ChangelogPath). Empty
        means the caller could not resolve it, and nothing is exempted.

    .PARAMETER EntryDirectory
        The folder branch documents live in (Get-BranchFilePaths.Directory). A repo still carrying a
        pre-rename folder name simply gets no exemption, which is the same refusal it gets today.

    .PARAMETER ReservedNames
        The folder's own permanent pages (Get-BranchFilePaths.ReservedNames) -- README.md, CONTRIBUTING.md,
        CHANGELOG.md. A commit touching one of those is not a fold. Matched case-insensitively, for the
        reason that list itself gives: Windows hands back 'Readme.md' for a file committed as 'README.md'.
    #>
    param(
        [string[]]$NameStatusLines = @(),
        [string]$ChangelogPath = '',
        [string]$EntryDirectory = '',
        [string[]]$ReservedNames = @()
    )

    if (-not $ChangelogPath -or -not $ChangelogPath.Trim()) { return $false }
    if (-not $EntryDirectory -or -not $EntryDirectory.Trim()) { return $false }

    # Forward slashes both sides, and no leading or trailing one: git reports its own paths with forward
    # slashes while a seam on Windows may answer with backslashes, and comparing the two spellings is the
    # one way this could silently drop a real path out of the fold's bound.
    $changelog = (([string]$ChangelogPath) -replace '\\', '/').Trim().Trim('/')
    $entryDir = (([string]$EntryDirectory) -replace '\\', '/').Trim().Trim('/')
    if (-not $changelog -or -not $entryDir) { return $false }
    $reserved = @($ReservedNames | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim() })

    $lines = @($NameStatusLines | Where-Object { $_ -and ([string]$_).Trim() })
    if ($lines.Count -eq 0) { return $false }

    $sawChangelogWrite = $false
    $sawEntryDeletion = $false

    foreach ($line in $lines) {
        # Tab-separated, and EXACTLY a status and one path. A rename ('R100') and a copy ('C') both come
        # back with three fields; the fold produces neither, so they disqualify the commit rather than
        # being half-read into one of the two buckets below.
        $fields = @((([string]$line) -split "`t") | Where-Object { $_ -ne '' })
        if ($fields.Count -ne 2) { return $false }
        $status = $fields[0].Trim()
        $path = ($fields[1] -replace '\\', '/').Trim().Trim('/')
        if (-not $status -or -not $path) { return $false }

        if ($path -ieq $changelog) {
            # The fold WRITES the changelog: modified normally, added in a repo folding for the first time.
            # A deleted changelog is not a fold, and reading it as one would exempt the one commit that
            # could take the file this gate's whole cycle depends on off the trunk.
            if ($status -notmatch '^(M|A)') { return $false }
            $sawChangelogWrite = $true
            continue
        }

        # A branch document: directly inside the entry folder, markdown, and not one of that folder's own
        # permanent pages. StartsWith rather than -like, deliberately: a folder name is data here, and
        # -like would read a '[' in it as a character class.
        if (-not $path.StartsWith("$entryDir/", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        $leaf = $path.Substring($entryDir.Length + 1)
        if (-not $leaf -or $leaf.Contains('/')) { return $false }
        if ($leaf -notmatch '(?i)\.md$') { return $false }
        if (@($reserved | Where-Object { $_ -ieq $leaf }).Count -gt 0) { return $false }

        # EVERY BRANCH DOCUMENT IN THE DIFF IS A DELETION, NOT MERELY ONE OF THEM. Caught in review before
        # this merged: the first build set the flag on a 'D' and let any OTHER status inside the folder
        # through unremarked, so 'M CHANGELOG.md' + 'D fix-a.md' + 'A sneaky.md' classified as a fold. The
        # fold script cannot produce that shape -- every path it names beside the changelog is one it has
        # just removed -- but this function's whole job is to PROVE a commit was written by that script, and
        # a shape it accepts without proof is exactly the false positive it exists to refuse. The docstring
        # and this suite both claim "the bound is the two paths"; this is the line that makes that true.
        if ($status -notmatch '^D') { return $false }

        # THE DELETION IS ALSO THE SIGNATURE, and requiring at least one is what keeps an ordinary pull
        # request out of this exemption. A branch that edits the changelog's intro and nothing else would
        # otherwise arrive as a changelog-only commit and be waved through -- and this repo's own suites do
        # assert on that intro, so it is a commit whose reach this function cannot vouch for. Only the fold
        # removes a branch document, so only the fold has both halves.
        $sawEntryDeletion = $true
    }

    return ($sawChangelogWrite -and $sawEntryDeletion)
}

function Get-StaleCertificateVerdict {
    <#
    .SYNOPSIS
        Whether commits found on 'main' since the certifying run void this PR's CI certificate --
        issue #1292's corrected predicate, replacing "the branch is behind" with "did 'main' move
        since the run that certified it".

    .DESCRIPTION
        MEASURED, NOT GUESSED (issue #1292, September 3, 2026). The filed report proposed refusing a
        branch that is BEHIND 'main' at merge time; verification found that predicate over-fires --
        behind-ness at merge is the ordinary case in this repo (20 of the last 45 merged PRs, 44.4%)
        and is harmless whenever 'main' advanced BEFORE the certifying run started, which most of it
        did. The predicate that actually voids a certificate is narrower and strictly implied by
        behind-ness:

            has 'main' moved SINCE the run that went green?

        Measured on the same 45 merged PRs: 14 (31.1%) had 'main' gain a first-parent commit after
        their certifying run began -- the true fire rate of this gate -- with a median staleness of
        16.1 minutes and a max of 146.6 (PR #1268 itself: the test block its own branch predated
        reached 'main' 45s before #1268's run finished and 14m45s after that run started, and #1268
        then merged on that same certificate 2h11m later). Of the 14, only 2 carried a
        scripts/**/scripts/tests/** change in the commits 'main' gained -- the subset that could
        actually turn the trunk red -- but this verdict does NOT filter on that: predicting which file
        a future test depends on is not this script's to do, and the corrected predicate is already
        cheap enough (one fetch, one first-parent log) that narrowing it further would trade a real
        safety margin for a rarer refusal on no measured benefit.

        PURE: the caller does the reading (`git fetch origin main`, then `git log origin/main
        --first-parent --since=<Get-CertifyingRunCreatedAt's answer>`) and hands the resulting SHA list
        here. Nothing here touches git or gh, so the verdict is asserted without a live remote -- the
        same split Get-MergeBlockVerdict and Get-CheckWaitReport already follow in this file.

        AND ONE CLASS OF COMMIT IS DISCOUNTED SINCE #1592: the fold. Test-IsFoldOnlyCommit above decides
        that from a commit's own diff, and the caller hands the SHAs it recognised in -ExemptCommits. That
        is not the path filter the paragraph above declines -- read its header for why a commit written by
        fold-changelog-entry.ps1 under a two-path bound is a different question from an arbitrary one. The
        arithmetic here stays deliberately dumb: this function is handed a list and subtracts it, so the
        judgement lives in one place and this one still asserts without a live remote.

    .PARAMETER NewMainCommits
        The SHAs of first-parent commits on 'main' at or after the certifying run's own `created_at`
        (Get-CertifyingRunCreatedAt), newest first (the order `git log` already produces). Empty (not
        $null) means "main has not moved" -- the caller's own read decides that; this only counts what
        it is handed.

    .PARAMETER ExemptCommits
        The subset of those SHAs that provably cannot void the certificate -- today, the folds
        (Test-IsFoldOnlyCommit). Omitted, nothing is exempt and the verdict is exactly what it was before
        #1592. A SHA here that is not in -NewMainCommits is ignored rather than subtracted from the count,
        so a caller cannot talk the verdict below zero.
    #>
    param(
        [string[]]$NewMainCommits = @(),
        [string[]]$ExemptCommits = @()
    )

    $commits = @($NewMainCommits | Where-Object { $_ -and ([string]$_).Trim() } | Select-Object -Unique)
    $exemptAsked = @($ExemptCommits | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
    # Compared case-insensitively: a SHA is hex, and the caller reads it back out of two different git
    # invocations (the log for the list, the diff for the classification) rather than one.
    $exempt = @($commits | Where-Object { $sha = ([string]$_).Trim(); @($exemptAsked | Where-Object { $_ -ieq $sha }).Count -gt 0 })
    $remaining = @($commits | Where-Object { $sha = ([string]$_).Trim(); @($exemptAsked | Where-Object { $_ -ieq $sha }).Count -eq 0 })
    if ($remaining.Count -eq 0) {
        return [pscustomobject]@{ Stale = $false; Count = 0; Commits = @(); ExemptCount = $exempt.Count; ExemptCommits = $exempt }
    }
    return [pscustomobject]@{ Stale = $true; Count = $remaining.Count; Commits = $remaining; ExemptCount = $exempt.Count; ExemptCommits = $exempt }
}

function Get-FailedCheckRunRefs {
    <#
    .SYNOPSIS
        The failing records of a `gh pr checks --json` payload that name a GitHub Actions run, as
        { Name; RunId; JobId }, in payload order. Empty when nothing failed or nothing is readable.

    .DESCRIPTION
        ONE PARSE, TWO QUESTIONS. Get-FailedCheckRunIds below asks whether the RUN behind a failing
        check ever started (#1044); Get-AuthoredFailureNote's caller asks what the JOB said about why
        it went red (#1103). Both keys sit in the same field -- the `link`, whose Actions form is
        `https://github.com/<owner>/<repo>/actions/runs/<runId>/job/<jobId>` -- so they are read here
        once rather than by two parsers that would drift apart.

        A LINK THAT IS NOT AN ACTIONS RUN IS SKIPPED, DELIBERATELY, and that restraint is inherited
        rather than new: a commit status posted by an external service links wherever that service
        likes and has no run, no job and no annotations, so a key scraped out of such a URL would
        address something else entirely. A link that names a run but no job is KEPT, with an empty
        JobId -- the run question can still be asked of it, and the annotation question simply is not.

        Failing is read through Get-CheckOutcome, so 'cancel', 'timed out' and 'startup failure' come
        along for the same reason they do in the verdict above -- none of them is green.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state,link` output. Anything that will not parse yields
        an empty list: every caller of this is a diagnostic, and a diagnostic degrades rather than
        throws.
    #>
    param([string]$ChecksJson)

    if (-not $ChecksJson -or -not $ChecksJson.Trim()) { return @() }
    try { $parsed = $ChecksJson | ConvertFrom-Json } catch { return @() }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object; the
    # same trap the two parses in Get-MergeBlockVerdict walked into.
    $records = @(@($parsed) | Where-Object { $_ })

    # A plain array rather than a generic List, and that is measured rather than stylistic: in 5.1
    # `@($list)` on a `List[object]` holding PSCustomObjects throws ArgumentException, while the same
    # wrap on the `List[string]` Get-FailedCheckRunIds builds below is fine. Two or three records is
    # not a size that needed a List anyway.
    $refs = @()
    foreach ($r in $records) {
        if ((Get-CheckOutcome -Record $r) -ne 'fail') { continue }
        if (-not $r.PSObject.Properties['link']) { continue }
        $link = [string]$r.link
        if ($link -notmatch '/actions/runs/(\d+)') { continue }
        # Read before the second -match: $Matches is overwritten by it, not extended.
        $runId = $Matches[1]
        $jobId = ''
        if ($link -match '/actions/runs/\d+/job/(\d+)') { $jobId = $Matches[1] }
        $name = ''
        if ($r.PSObject.Properties['name']) { $name = [string]$r.name }
        $refs += [pscustomobject]@{ Name = $name; RunId = $runId; JobId = $jobId }
    }
    return @($refs)
}

function Get-FailedCheckRunIds {
    <#
    .SYNOPSIS
        The GitHub Actions run ids behind the FAILING records of a `gh pr checks --json` payload, in
        the order they appear and without duplicates. Empty when nothing failed or nothing is readable.

    .DESCRIPTION
        The lookup key for Get-StalledRunNote below. `gh pr checks` reports a check, not the run that
        produced it, and the fact that separates "the job never started" from "a check went red" lives
        on the RUN -- so the caller needs an id before it can ask.

        THE READING MOVED UP TO Get-FailedCheckRunRefs (#1103) AND THE ANSWER DID NOT CHANGE WITH IT.
        The link form, the external-status skip and the failing-outcome rule are all that function's
        now; this is the run-shaped view of it, and what it still owns is the DEDUPE -- two failing
        checks from one run are one question about that run, and asking it twice would print the note
        twice.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state,link` output. Anything that will not parse yields
        an empty list, because this only ever costs the caller a diagnostic line it can do without.
    #>
    param([string]$ChecksJson)

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($ref in @(Get-FailedCheckRunRefs -ChecksJson $ChecksJson)) {
        if (-not $ids.Contains($ref.RunId)) { $ids.Add($ref.RunId) | Out-Null }
    }
    return @($ids)
}

function Get-StalledRunNote {
    <#
    .SYNOPSIS
        One sentence for the operator when a workflow run FAILED TO START rather than failed -- i.e.
        when no job in it executed a single step. '' when something did run, which is the ordinary case
        and the case the caller's existing wording already covers.

    .DESCRIPTION
        Inbound #1044, measured August 28, 2026 in a consumer repo: GitHub Actions stopped starting
        jobs because an account payment had failed, every run ended in ~4s with zero steps, and
        ship-pr.ps1 reported it as

            CI did not pass for PR #N (exit 1) -- NOT merged: <verdict reason>.
            Fix CI and re-run, or merge manually once green.

        Every word of that is true and together they point at the wrong thing. "CI did not pass" reads
        as *a check ran and went red*, so the operator goes to their own code; the actual state was
        that nothing ran, which no branch can repair and no re-run will change. One PR was merged by
        hand as a result -- the habit this workflow exists to prevent.

        THE MERGE DECISION IS UNCHANGED, and deliberately. Refusing on an unreadable required-check
        list is the conservative half of #943 and stays exactly as it was: this adds no state to
        Get-MergeBlockVerdict and cannot let a merge through. What moves is the DIAGNOSIS handed to
        the operator alongside the refusal.

        WHY THE STEP COUNT AND NOT THE ANNOTATION. The reason text ("recent account payments have
        failed or your spending limit needs to be increased") sits on the check-run annotation, two API
        levels down and absent from the ordinary run page -- which is what made the state expensive to
        recognise. This does not go fetch it, for two reasons. The annotation is one CAUSE of a run
        that never started (a spending limit, Actions disabled for the org, and no runner able to take
        the job all produce the same shape), while "no step ran" is the FACT that makes "fix your code"
        wrong in every one of them. And the report measured the empty state two ways -- an empty jobs
        array and jobs with zero steps -- so the entry point to the annotation is not the same in both.
        Both shapes are recognised here; the note names the one command that prints the reason.

        A RUN THAT HAS NOT FINISHED IS NOT STALLED. A job still queued also has no steps, so a payload
        whose status is anything but 'completed' returns ''. ship-pr only reaches this after --watch,
        where that cannot happen -- asserted anyway, because "cannot happen" is how the premise this
        repo keeps replacing was justified.

    .PARAMETER RunJson
        `gh run view <runId> --json conclusion,status,url,jobs` output. Unreadable in, '' out: this is
        a diagnostic and must never be the reason a refusal cannot be printed.

    .PARAMETER RunId
        The run id, so the note can name the command that prints the reason. Optional; left out, the
        note ends after the URL it read from the payload.
    #>
    param(
        [string]$RunJson,
        [string]$RunId = ''
    )

    if (-not $RunJson -or -not $RunJson.Trim()) { return '' }
    try { $run = $RunJson | ConvertFrom-Json } catch { return '' }
    if ($null -eq $run) { return '' }

    # A field gh was never asked for is absent, and absent is not empty under Set-StrictMode -- the
    # same guard Get-CheckOutcome applies, for the same reason.
    $status = ''
    if ($run.PSObject.Properties['status']) { $status = ([string]$run.status).Trim().ToLowerInvariant() }
    if ($status -and $status -ne 'completed') { return '' }

    if (-not $run.PSObject.Properties['jobs']) { return '' }
    $jobs = @($run.jobs | Where-Object { $_ })

    $what = ''
    if ($jobs.Count -eq 0) {
        $what = 'the run created no job at all'
    } else {
        $ran = @($jobs | Where-Object {
            $_.PSObject.Properties['steps'] -and @($_.steps | Where-Object { $_ }).Count -gt 0
        })
        if ($ran.Count -gt 0) { return '' }
        $what = if ($jobs.Count -eq 1) {
            'its one job executed no step'
        } else {
            "none of its $($jobs.Count) jobs executed a step"
        }
    }

    $url = ''
    if ($run.PSObject.Properties['url']) { $url = ([string]$run.url).Trim() }

    $note = "The run did not FAIL, it never started: $what, so nothing was tested -- this is not a check that went red, and re-running the branch will not change it."
    $note += ' The cause is outside this repository (a failed account payment or a reached spending limit, Actions disabled for the org, or no runner able to take the job) and the reason text is not on the run page.'
    if ($RunId) {
        $note += " Print it with: gh run view $RunId"
    } elseif ($url) {
        $note += " The run is at $url"
    }
    return $note
}

function Get-LostWatchNote {
    <#
    .SYNOPSIS
        One sentence for the operator when a non-zero `gh pr checks --watch` exit is the WATCH dying
        rather than a check going red -- i.e. when nothing has reported a failure and at least one
        check is still running. '' when something actually failed, which is the ordinary case and the
        case the caller's existing wording already covers.

    .DESCRIPTION
        Issue #1219, measured on PR #1218 (September 2, 2026). `--watch` is one long-lived call against
        the GraphQL API, and after nine clean poll cycles it printed

            Post "https://api.github.com/graphql": read tcp ...: wsarecv: An existing connection was
            forcibly closed by the remote host.

        and exited non-zero. Get-MergeBlockVerdict blocked -- correctly, it could not see a green
        required check -- and ship-pr said "CI did not pass for PR #1218 (exit 1) ... Fix CI and
        re-run, or merge manually once green." Nothing about CI had failed. Read seconds later,
        `branch-entry` was pass, `lint-en-tests` was in_progress with its own lint step already green,
        and `claude-review` was pending; the run went green on its own minutes later.

        THE THIRD CASE OF A DISTINCTION THIS FILE ALREADY DRAWS TWICE. #943 separated "a check the
        ruleset REQUIRES went red" from "a check it does not"; #1044 separated "a check went red" from
        "the job never started". This is the same failure with a third cause, and it costs the same
        thing: "Fix CI and re-run" sends the reader into their own code for a state no branch can
        repair. It is the cheapest of the three to get wrong, because here CI is not even unhealthy --
        it is still going, and the only thing that broke was a socket the operator will never see again.

        Get-StalledRunNote does NOT cover it, and the report checked: that note fires on a run that
        never STARTED, and this run had started and was progressing. Which is precisely the fact read
        here, from the other side.

        THE MERGE DECISION IS UNCHANGED, deliberately and for the third time. This adds no state to
        Get-MergeBlockVerdict and cannot let a merge through -- refusing on an unreadable required-check
        list is the conservative half of #943 and stays as it is. What moves is the DIAGNOSIS, plus the
        caller's licence to re-enter the wait: the deadline is the operator's, not the socket's.

        THE FACT IS "NOTHING FAILED AND SOMETHING IS STILL RUNNING", NOT THE ERROR TEXT. gh's message
        is a transport detail that varies with platform, proxy and gh version, and it goes to stderr,
        where a caller may not have kept it. The payload carries the same conclusion more reliably: a
        non-zero `--watch` exit CLAIMS something failed, so a payload in which nothing has failed while
        a check is still pending contradicts that exit code -- and the exit code is the half that came
        over the wire.

        AN UNREADABLE PAYLOAD RETURNS '', which is the opposite of Get-MergeBlockVerdict's answer to
        the same input, and right in both places. There, silence must REFUSE, because it guards a
        merge. Here, silence must not NARRATE: claiming a dropped connection on a payload nobody could
        read would put "CI is still running" in front of an operator whose check went red, and
        mis-narrating a real failure is worse than the wording being repaired.

        A PAYLOAD IN WHICH EVERYTHING PASSED IS ALSO '', and no caller reaches this with one: with no
        failing required check the verdict is not Blocked, so the caller takes its merge-proceeds path
        instead of its refusal path. Left out rather than guessed at, because "all green and the watch
        exited non-zero" wants a different sentence from this one and no run has produced it yet.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state` output. Anything that will not parse yields '',
        because this only ever costs the caller a diagnostic line and a retry it can do without.

    .PARAMETER PrNumber
        The PR number, so the note can name the command that re-enters the wait. Optional; left out,
        the note ends after the state it read.
    #>
    param(
        [string]$ChecksJson,
        [string]$PrNumber = ''
    )

    if (-not $ChecksJson -or -not $ChecksJson.Trim()) { return '' }
    try { $parsed = $ChecksJson | ConvertFrom-Json } catch { return '' }
    if ($null -eq $parsed) { return '' }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object; the
    # same trap the two parses in Get-MergeBlockVerdict walked into.
    $records = @(@($parsed) | Where-Object { $_ -and $_.name })
    if ($records.Count -eq 0) { return '' }

    $failed = @()
    $pending = @()
    foreach ($r in $records) {
        switch (Get-CheckOutcome -Record $r) {
            'fail'    { $failed += [string]$r.name }
            'pending' { $pending += [string]$r.name }
        }
    }
    # ONE failing check and this is a verdict, whatever else the payload holds. Read through
    # Get-CheckOutcome, so 'cancel', 'timed out' and 'startup failure' end the question here for the
    # same reason they do in the verdict above -- none of them is green, and none of them is a socket.
    if ($failed.Count -gt 0) { return '' }
    # 'unknown' counts as neither. It is not a failure, and it is not proof that anything is running:
    # without a check provably still going the non-zero exit is not contradicted, and there is nothing
    # to say.
    $pending = @($pending | Sort-Object -Unique)
    if ($pending.Count -eq 0) { return '' }

    $is = if ($pending.Count -eq 1) { 'is' } else { 'are' }
    $note = "The WATCH dropped, CI did not: nothing has reported a failure and $(Format-CheckNameList -Names $pending) $is still running, so the non-zero exit came from the connection and not from a verdict."
    $note += ' There is nothing on the branch to fix and nothing to re-run -- the run is still going and may well go green on its own.'
    if ($PrNumber) {
        $note += " Re-enter the wait with: gh pr checks $PrNumber --watch"
    }
    return $note
}

function Format-AuthoredText {
    <#
    .SYNOPSIS
        One line of somebody else's free text, made printable: control and format characters become
        spaces, runs of spaces collapse, the ends are trimmed. BOUNDING IT IS THE CALLER'S JOB --
        the two relays that handle this class of text cap it at different, separately measured
        lengths, and neither number belongs in a shared helper.

    .DESCRIPTION
        Issue #1612. Get-AuthoredFailureNote below relays a sentence a WORKFLOW AUTHOR wrote, into
        the operator's console, under ship-pr's own warning prefix and its two-space indent -- and it
        is read by a terminal AND by an agent session. An ANSI or OSC escape repaints that terminal;
        an RTL override or a zero-width run makes the printed line read as something other than what
        it says, deceiving either reader by the very line that exists to explain the failure. So a
        crafted note wearing this script's prefix is an injection surface rather than a display bug.
        The relay's first-line cut removes the newline tricks and nothing else: an in-line ESC[ or an
        RTL override survives Trim() and the length cap untouched.

        THE WORDS STAY. The note only has to be READABLE; quoting the payload would keep it and add
        noise. Same choice and same reasoning as the sibling site.

        THREE LIBS CARRY THIS CLASS, AND THE COUNT IS STATED BECAUSE A WRONG ONE IS WHAT MADE THIS GAP
        HARD TO FIND (the second half of #1612). It was three until #1623, two until #1858, and the
        arrangement is worth reading before it is changed again:

          - THIS LIB types it, for the reason above.
          - ref-print-lib.ps1 types it, inside Get-DisplayRef -- the one definition of the prose strip
            since #1623, applied at thirty-two printed sentences across ship-pr.ps1, sync-main.ps1,
            remote-ahead-lib.ps1 and worktree-lib.ps1, and to this lib's sibling Get-PasteableRef note.
          - claim-issue-lib.ps1 types it, inside Format-ForConsole -- the issue title, the commit
            subjects and the branch names claim-issue.ps1 prints. It reached only '[\x00-\x1F\x7F]'
            until #1858, so a bidi override or a zero-width run in a title passed through it untouched,
            as did the whole C1 range.
          - remote-ahead-lib.ps1 typed the FIRST copy (a commit's %an and %s, #1439) and no longer does:
            #1623 gave it a caller's reason to load ref-print-lib anyway -- the branch label in its own
            sentence, which it had been printing raw beside the subject it sanitised -- and once the lib
            was loaded a private copy was pure drift surface.

        WHY THIS LIB STILL TYPES ITS OWN, which is the question the bullet above invites. The argument
        that kept three copies apart -- different bounds (120, 500 and none), different source processes,
        and no lib among them loaded by another's callers -- is still exactly true of THIS one: nothing
        here has a reason to load ref-print-lib, so lifting the class would cost a dot-source in every
        caller and a Copy-Item in every fixture suite to save one regex. remote-ahead-lib's case is the
        one that changed, and it changed because it acquired the dependency for its own sake.

        AND #1858's COPY HAS A SECOND REASON ON TOP OF THAT, THE STRONGER OF THE TWO: no existing
        function fits its contract. Get-DisplayRef collapses runs of spaces and trims, and an issue title
        is quoted evidence that must not be re-spaced; Get-DisplayPath answers the all-stripped case with
        '(no printable path)', the wrong noun for a title. Reuse there would have meant a FOURTH function
        in ref-print-lib rather than one regex fewer.

        What the remaining copies must never do is DISAGREE -- so pr-issues.tests.ps1 compares them to the
        same character class and asserts WHICH libs carry it, guarding the drift instead of designing it
        away. A fourth site appearing is not forbidden; it has to update that assert, this block and
        the new-branch skill page, which is the claim #1612 was filed about.
    #>
    param([string]$Text)

    if (-not $Text) { return '' }
    return ((($Text -replace '[\p{Cc}\p{Cf}]', ' ') -replace ' {2,}', ' ').Trim())
}

function Get-AuthoredFailureNote {
    <#
    .SYNOPSIS
        The sentence a failing workflow wrote about ITSELF, read from a check run's annotations:
        `<title> -- <message>`, with the check name prefixed where the title does not already carry
        it. '' when the job left no authored diagnosis behind, which is the ordinary case and the
        case the caller's existing wording already covers.

    .DESCRIPTION
        Issue #1103, and the seven threads before it -- #891, #913, #942, #962, #966, #974, #1055.
        `claude-review` is advisory in this repo, so ship-pr merges past it and prints "a check FAILED
        but the merge is not blocked ... nothing here fixes it". Both halves are true, and together
        they hand the reader a red mark and an invitation to go and chase it. What the chaser meets is
        the action's own `##[error]Claude result reported subtype success with is_error:true`, which
        names nothing, and a log tail that ends somewhere unrelated to the cause -- so the same
        signature keeps arriving as a NEW issue against a run whose own diagnostic step had already
        printed the answer. #966 is the expensive one: it was filed against a log reading
        `api_error_status: 429`, inferred an expired OAuth token instead, and concluded that a secret
        needed rotating.

        So the reason is fetched and printed where the operator already is. It adds no information the
        run did not carry -- the same move claude-code-review.yml itself made when it put its reason in
        an annotation rather than only in a log body.

        THE SELECTION RULE, AND WHY IT IS NOT A CHECK NAME. A failure annotation carrying a TITLE was
        written by somebody: the Actions runner emits its own with an EMPTY title ("Process completed
        with exit code 1", "Action failed with error: ..."), while `::error title=X::Y` is a sentence a
        workflow author chose to leave for exactly this reader. "Titled failure annotation" therefore
        needs no maintenance and works in a consumer repo whose workflows this repo has never seen,
        where a rule keyed on the name `claude-review` would report nothing at all.

        WARNINGS ARE NOT READ, and the first titled failure wins. `annotation_level` is failure /
        warning / notice; a run is being explained here because it went RED, and the Node-20
        deprecation warning riding along on every job of this repo is not why. Annotations arrive in
        the order the job emitted them, and a workflow that diagnoses itself does so before the
        runner's exit noise.

        BOUNDED AND STRIPPED, BECAUSE THIS IS FREE TEXT A WORKFLOW PRODUCED AND IT IS BEING PASTED
        INTO A CONSOLE: the title and the message go through Format-AuthoredText above (issue #1612 --
        control and format characters out, words in), and the message is cut to its FIRST LINE and 500
        characters. Not the 300 claude-code-review.yml writes its own annotation under -- that bounds
        the REASON it appends, and the headline explaining what the status means sits in front of it,
        so relaying at 300 would keep only the headline, which is the part a reader could already
        guess from the check being red. The two bounds overlap and #1116 measured the overlap rather
        than removing it; the arithmetic is in the comment beside the cut itself.

    .PARAMETER AnnotationsJson
        `gh api repos/<owner>/<repo>/check-runs/<jobId>/annotations` output. Unreadable in, '' out: a
        diagnostic must never be the reason the line beside it cannot be printed.

    .PARAMETER CheckName
        The check the annotations belong to, so the note names it. Optional; left out, the note is the
        authored sentence alone.
    #>
    param(
        [string]$AnnotationsJson,
        [string]$CheckName = ''
    )

    if (-not $AnnotationsJson -or -not $AnnotationsJson.Trim()) { return '' }
    try { $parsed = $AnnotationsJson | ConvertFrom-Json } catch { return '' }
    if ($null -eq $parsed) { return '' }

    # Assign first, wrap second -- see the note in Get-FailedCheckRunRefs above.
    foreach ($a in @(@($parsed) | Where-Object { $_ })) {
        # A field gh was never handed is absent, and absent is not empty under Set-StrictMode.
        if (-not $a.PSObject.Properties['annotation_level']) { continue }
        if (([string]$a.annotation_level).Trim().ToLowerInvariant() -ne 'failure') { continue }

        # STRIPPED BEFORE IT IS JUDGED, not merely before it is printed. Two things turn on that
        # order: a "title" of nothing but format characters is not a workflow diagnosing itself and
        # must fall through to the next annotation like any untitled one, and the CheckName test
        # below is a PREFIX match that a leading escape would defeat.
        $title = ''
        if ($a.PSObject.Properties['title']) { $title = Format-AuthoredText -Text ([string]$a.title) }
        if (-not $title) { continue }

        $message = ''
        if ($a.PSObject.Properties['message']) { $message = ([string]$a.message).Trim() }
        $message = @($message -split "`r?`n")[0]
        # AFTER THE CUT AND BEFORE THE CAP, and that order is load-bearing at both ends. A newline is
        # itself a control character, so stripping first would turn every one of them into a space and
        # leave no first line to take; capping first would count characters the reader never sees,
        # since an escape run becomes spaces that the collapse then removes.
        $message = Format-AuthoredText -Text $message
        # 500, NOT the 300 claude-code-review.yml writes its own annotation under, and measured
        # rather than guessed. That 300 bounds the REASON it appends; the headline explaining what
        # the status means sits in front of it, so relaying at 300 would cut the sentence in half and
        # keep only the half a reader could guess from the red mark. Measured on run 33267175141:
        # 400 characters, ending "resets Aug 31, 7am (UTC)".
        #
        # THAT NUMBER READ 460 UNTIL ISSUE #1116 CHECKED IT. The same run's note, put back through
        # this function, is 400: a 55-character title, the 4-character separator and a 341-character
        # message. The bound was never in question, but the measurement defending it was wrong by 60
        # -- and a comment that cites a run id invites exactly this check, which is the argument for
        # citing one.
        #
        # THE TWO CAPS DO OVERLAP, AND #1116 LEFT THEM THAT WAY ON PURPOSE. That workflow's headline
        # is 296 characters, so headline + reason can reach 597 against this 500 and the part cut is
        # the reason's TAIL. Lowering the workflow's 300 so the sum fits was built and withdrawn on
        # the arithmetic: 500 - 296 - 1 = 203 either way, so the operator's console gains nothing,
        # loses the "..." that marks the cut, and the GitHub annotation -- which no 500 bounds --
        # loses up to 97 characters. The only change that would give the console MORE is cutting
        # from a different END here, and that is not free either: this function relays workflows it
        # has never seen, and for one whose message is all content and no preamble, the front is the
        # part worth keeping. Sampled traffic says the case is hypothetical -- 45 annotations,
        # reasons of 51 to 55 characters against 203 of room -- so the bound stays where the
        # measurement put it.
        #
        # THE RELAY DOES NOT VOUCH FOR WHAT IT RELAYS, and that is the point of the rule -- issue
        # #1112. That measured note ended with a reset time roughly 2.5 DAYS later than the moment
        # the quota actually came back. Nothing is added here to caveat it: this function repeats
        # what an author wrote and cannot know which authors are reliable, so a hedge here would
        # hedge every workflow in every consuming repo. An over-claiming sentence is repaired in the
        # workflow that writes it, which is where #1112 was repaired.
        if ($message.Length -gt 500) { $message = $message.Substring(0, 500).TrimEnd() + '...' }

        # NAMED ONCE. A workflow that titles its own annotation usually leads with the job name --
        # `::error title=claude-review -- out of quota::` is exactly what this repo writes -- and
        # prefixing that again produces "claude-review: claude-review -- ...". The check name is here
        # for the payloads that do NOT carry it, so it is added only where it is missing.
        $note = if ($CheckName -and $title -notlike "$CheckName*") { "${CheckName}: $title" } else { $title }
        if ($message) { $note += " -- $message" }
        return $note
    }

    return ''
}

function Get-MissingCheckSuiteNote {
    <#
    .SYNOPSIS
        One sentence for the operator when the reason no check has registered is that GitHub created
        NO GitHub Actions check suite for the commit at all -- so no workflow of this repository was
        ever asked to run. '' when an Actions suite does exist, which is the ordinary case and the case
        the caller's existing sentence already covers, because that sentence really is about the
        workflow.

    .DESCRIPTION
        Issue #1234, measured on PR #1233 (September 2, 2026, head b09c71b2). ship-pr's step-3 probe
        polls `gh pr checks` for 180s and then refuses with

            No CI check registered for PR #N after 180s -- NOT merged. Check the workflow, or merge
            manually once it is green.

        The refusal is right and the second sentence is not. "Check the workflow" means *your
        .github/workflows/*.yml is wrong* -- a paths: filter, a bad trigger, a syntax error -- and the
        state that most often produces this has healthy workflows. On that PR `gh pr checks` reported
        nothing and `gh run list` was empty, while the commit's check-suite list held netlify and
        claude and NO github-actions suite. Actions itself was demonstrably fine: a sibling PR got its
        three runs minutes earlier, and two pushes to main either side of this one -- 13:07:32 and
        13:08:20 -- both created runs, while the push at 13:07:55 got none. No amount of reading YAML
        finds that, and the reader who goes looking spends the time before they read the suite list.

        THE FOURTH CASE OF A DISTINCTION THIS FILE ALREADY DRAWS THREE TIMES. #943 separated a red
        REQUIRED check from a red advisory one; #1044 separated a check that went red from a run that
        never started; #1219 separated a verdict from a dropped watch. Each time the sentence sent the
        reader somewhere no repair exists. This one has them auditing YAML that is fine.

        Get-StalledRunNote does NOT cover it, and the report checked: that note reads a RUN, and the
        whole finding here is that no run -- and no suite to hold one -- was ever created. There is
        nothing for it to be asked about.

        THE REFUSAL IS UNCHANGED, deliberately and for the fourth time. Refusing to merge on a commit
        no check has measured is the conservative half of that probe and stays exactly as it is: this
        adds no state to any decision and cannot let a merge through. What moves is the DIAGNOSIS.

        THE REMEDY IS NAMED BECAUSE IT IS NOT GUESSABLE. `gh pr close <n> && gh pr reopen <n>` re-fires
        the `pull_request` event, whose DEFAULT types include `reopened`, so every workflow that has not
        narrowed them with an explicit types: list is asked again -- and neither the head commit nor the
        PR body moves, which matters because the DEPLOY lock reads that body at the merge. Measured on
        #1233: the reopen produced three in_progress github-actions suites in about 20 seconds. It is
        stated as GitHub's default rather than as a fact about the caller's workflows, which this script
        does not read and must not claim to know -- the same restraint that keeps the probe from naming
        a check.

        WHAT THIS DOES NOT CLAIM IS A CAUSE. A missing suite has more than one (a dropped internal
        event, Actions disabled for the repository, a `paths:` filter that genuinely excludes every
        file in the push), and only the first is repaired by a reopen. So the note reports the FACT --
        no Actions suite exists for this commit -- and offers the reopen as the cheapest thing to try,
        never as a diagnosis. The reader who reopens and gets nothing has learned something the old
        sentence could not tell them either way.

        AND ONE CAUSE IS NOT A GUESS AT ALL, which is what issue #1247 turned out to be (measured
        September 2, 2026, on PR #1243). A `pull_request` workflow runs against `refs/pull/<n>/merge`,
        the commit GitHub builds by merging the head into the base -- so while the PR CONFLICTS there is
        no such commit, no check suite is created, and a required check can never be satisfied. Nothing
        went missing here: the event was never eligible to fire.

        THE MEASUREMENT, because #1247 read this state as an Actions outage and inferred runner
        entitlement at the newly transferred org:

          * #1243 (CONFLICTING): no `refs/pull/1243/merge`, 0 check suites -- and it stayed 0 through
            BOTH escalations, `gh pr close && gh pr reopen` and then a fresh head pushed to the branch.
          * #1249 and #1240, opened either side of it: `refs/pull/<n>/merge` present, three suites each,
            same repo, same hour, same workflows.

        That is why the conflict is named FIRST and the reopen is WITHHELD rather than reworded. Against
        a dropped event the reopen is the cheapest thing to try; against a conflict it is measured to do
        nothing, and printing it there sends the reader round a loop that cannot terminate. The repair is
        to make the merge commit computable -- merge the base in, or rebase -- after which the ordinary
        `synchronize` creates the suite.

        STILL A DIAGNOSIS AND NOT A CAUSE, and the refusal is untouched for the fifth time. A conflicting
        PR could also be missing its suite for one of the reasons above; what the conflict buys the reader
        is a repair they can carry out without guessing, never proof that it is the only one.

    .PARAMETER SuitesJson
        `gh api repos/<owner>/<repo>/commits/<sha>/check-suites` output. Unreadable in, '' out: a
        diagnostic must never be the reason a refusal cannot be printed.

    .PARAMETER PrNumber
        The PR number, so the note can name the reopen. Optional; left out, the note ends after the
        state it read.

    .PARAMETER Mergeable
        `gh pr view --json mergeable` -- GitHub's own word, one of CONFLICTING, MERGEABLE or UNKNOWN.
        Only CONFLICTING changes what the reader is told. UNKNOWN means GitHub has not finished computing
        the merge and is deliberately read as NO INFORMATION rather than as a conflict, because a note
        that guesses at a cause is the failure this whole function exists to end. Optional, and optional
        on purpose: the caller reads it best-effort like every other fact in this refusal, so a read that
        fails costs this clause and nothing else.
    #>
    param(
        [string]$SuitesJson,
        [string]$PrNumber = '',
        [string]$Mergeable = ''
    )

    if (-not $SuitesJson -or -not $SuitesJson.Trim()) { return '' }
    try { $parsed = $SuitesJson | ConvertFrom-Json } catch { return '' }
    if ($null -eq $parsed) { return '' }
    # A field gh was never asked for is absent, and absent is not empty under Set-StrictMode -- the
    # same guard every reader in this file applies.
    if (-not $parsed.PSObject.Properties['check_suites']) { return '' }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object; the
    # same trap the two parses in Get-MergeBlockVerdict walked into.
    $suites = @(@($parsed.check_suites) | Where-Object { $_ })

    $slugs = New-Object System.Collections.Generic.List[string]
    foreach ($s in $suites) {
        if (-not $s.PSObject.Properties['app']) { continue }
        if ($null -eq $s.app) { continue }
        if (-not $s.app.PSObject.Properties['slug']) { continue }
        $slug = ([string]$s.app.slug).Trim()
        if ($slug -and -not $slugs.Contains($slug)) { $slugs.Add($slug) | Out-Null }
    }
    # NEITHER BOUNDED NOR ESCAPED, UNLIKE Get-AuthoredFailureNote ABOVE, and that difference is the
    # point rather than an oversight. That function relays FREE TEXT a workflow author wrote, so it cuts
    # to one line and 500 characters and strips the control and format characters out of it -- which
    # this comment said before it was so, and #1612 is where that was closed; a `slug` is a
    # GitHub-assigned identifier -- lowercase, hyphenated, no newline -- validated by the side that
    # issues it. Written down rather than defended against: no payload has yet produced a slug this
    # could not print, and a bound built for one that has not arrived would be guessing at its shape.
    # THE ONE SLUG THAT MATTERS, and it is GitHub's own rather than a name this repo chose. Every other
    # app on the commit (netlify and claude on #1233, a consumer's own integration elsewhere) is a
    # different provider whose presence or absence says nothing about this repo's workflows -- which is
    # why they are NAMED in the note and never counted as an answer.
    if ($slugs.Contains('github-actions')) { return '' }

    # READ ONCE, IN A TERMINAL, AT THE MOMENT A MERGE IS REFUSED -- so every clause has to earn its
    # place. "only <list> registered" carries the same fact as naming the commit a second time and
    # takes no grammatical number with it, which is why there is no singular/plural branch here.
    $found = if ($slugs.Count -eq 0) {
        'nothing registered for it at all'
    } else {
        "only $(Format-CheckNameList -Names @($slugs)) registered"
    }

    $note = "GitHub created no Actions check suite for this commit -- $found, so no workflow of this repository was ever asked to run."
    # The enumeration IS the "do not go and read the YAML" instruction; saying that separately as well
    # states one conclusion twice in the longest sentence the operator has to read.
    $note += ' This is NOT a paths: filter, a wrong trigger or a syntax error: Actions is typically healthy elsewhere in the repo at the same moment.'

    # THE CONFLICT BRANCH, AND IT REPLACES THE REOPEN RATHER THAN JOINING IT (#1247). A pull_request
    # workflow runs against refs/pull/<n>/merge, which does not exist while the PR conflicts -- so the
    # suite is not late, it is ineligible, and the reopen measured on #1243 changed nothing twice over.
    # Printing both would leave the reader to pick, and the cheap one is the one that cannot work here.
    # Only CONFLICTING branches: UNKNOWN is GitHub still computing and must not be read as a conflict.
    if ($Mergeable -and $Mergeable.Trim().ToUpperInvariant() -eq 'CONFLICTING') {
        $note += ' AND THIS ONE IS NOT A MYSTERY: GitHub reports this PR as CONFLICTING, and a pull_request workflow runs against the merge commit (refs/pull/<n>/merge) that a conflicting PR has none of -- so no suite can be created for it at all. Resolve the conflict (merge the base branch in, or rebase) and the ordinary push creates it. A close/reopen does NOT repair this and was measured doing nothing.'
        return $note
    }

    $note += ' It is the event for THIS commit that went missing.'
    if ($PrNumber) {
        $note += " Cheapest thing to try, and it is not a diagnosis: gh pr close $PrNumber && gh pr reopen $PrNumber -- 'reopened' is one of the default pull_request types, so it re-asks every workflow that has not narrowed them, and it moves neither the head commit nor the PR body."
    }
    return $note
}

function Get-LabelNames {
    <#
    .SYNOPSIS
        The label names in a `gh label list --json name` payload, as a string array. An EMPTY array
        for empty input, unparseable JSON, or a payload with no readable name -- every one of which
        the caller must treat as "could not be asked", never as "the label is missing".

    .DESCRIPTION
        Inbound #1221. open-pr.ps1 handed the branch prefix's label straight to `gh pr create --label`
        and let gh be the one to discover it does not exist. gh refuses, so no PR is created -- and by
        then every gate has run and the branch is on origin. Parsing the answer lives HERE, as a pure
        function of the JSON text, because the caller drives a live remote and cannot be covered by a
        suite while this can. Same move and same reasoning as Get-ExistingPrRecord above.

        EMPTY IS "UNKNOWABLE" AND NOT "ABSENT", which is the one thing this function's contract has to
        make unambiguous: a caller that read an empty array as "no such label" would refuse every PR in
        a repo whose gh is too old for --json, or whose query returned something unexpected. The caller
        therefore checks gh's exit code first and treats an empty list as a warning it carries on from
        -- the same "a failed query is not an answer" the existing-PR lookup already applies.

        THE 5.1 PARSE TRAPS ARE THE PART WORTH TESTING: a parsed JSON array reaches the pipeline as a
        SINGLE object, so the assign-first/wrap-second shape is required; and a field gh was never asked
        for is absent rather than empty, so every record is probed for 'name' before it is read.
    #>
    param([string]$Json)

    if (-not $Json -or -not $Json.Trim()) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($record in @(@($parsed) | Where-Object { $_ })) {
        if (-not $record.PSObject.Properties['name']) { continue }
        $name = ([string]$record.name).Trim()
        if ($name -and -not $names.Contains($name)) { $names.Add($name) | Out-Null }
    }
    return @($names)
}

function Get-MissingLabelNote {
    <#
    .SYNOPSIS
        The refusal for a PR label that does not exist in the repository -- or '' when it does exist,
        and '' when there is no label list to judge against.

    .DESCRIPTION
        Inbound #1221, measured in BWJ-ecommerce/smartwatchbanden on September 1, 2026: the labels 'bug'
        and 'enhancement' were deleted org-wide because the issue TYPE now carries that classification,
        and the next PR died on

            could not add label: 'bug' not found

        AFTER the entry gate, the step gate and the resolves gate had all passed and the branch had been
        pushed. What makes that worth a round trip to GitHub is WHEN the failure lands rather than that
        it lands: everything expensive has already happened, the remedy is outside the script (create a
        label, or edit the seam table), and the state left behind is a pushed branch with no PR -- which
        reads exactly like a parked branch.

        IT IS NOT AN AUTHOR'S MISTAKE, which is why it is a gate and not a better error message. The
        seam table was correct the day before and nothing in the consumer changed; any repo that renames
        or retires a label breaks the same way, and the first sign of it is a failed create after a push.

        IT REFUSES AND DOES NOT FALL BACK, deliberately. Substituting 'question' would classify the PR
        wrongly and a repo that GATES on the label -- as that consumer does in pr-guardrails.yml -- would
        go green on a label that says nothing; dropping the label is worse still, because the gate would
        then go red after a successful create. So the two remedies are named and neither is taken.

        AND IT COVERS THE FALLBACK ITSELF, one layer down. open-pr substitutes 'question' for an unknown
        branch prefix, which is a GitHub DEFAULT label a repo may equally have deleted -- so the note
        says so when that is where the label came from. The check is on the label that would be sent,
        whatever produced it, rather than on the prefix table.

    .PARAMETER Labels
        The repository's label names, from Get-LabelNames. EMPTY means the query could not be read, and
        the answer is '' -- a diagnostic must never be the reason a PR cannot be opened.

    .PARAMETER Label
        The label `gh pr create --label` would be given.

    .PARAMETER Prefix
        The branch prefix the label came from, when the seam table backed one. Empty means the label is
        open-pr's unknown-prefix fallback, and the note says that instead.

    .PARAMETER SeamPath
        The repo-owned file that maps prefixes to labels, so the reader is sent to the edit rather than
        to a search.

    .PARAMETER Repo
        'owner/name', so the note can name the repository the label is missing from and print a
        paste-ready `gh label create`. Optional.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Labels,
        [string]$Label,
        [string]$Prefix = '',
        [string]$SeamPath = 'scripts\lib\branch-info.ps1',
        [string]$Repo = ''
    )

    $known = @(@($Labels) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
    if ($known.Count -eq 0) { return '' }
    if (-not $Label -or -not $Label.Trim()) { return '' }
    $wanted = $Label.Trim()
    # Case-INSENSITIVE, because that is how GitHub treats a label name: it refuses to create 'Bug'
    # beside 'bug', and `--label bug` attaches the existing 'Bug'. A case-sensitive compare here would
    # refuse a PR gh would have opened, which is the one direction this gate must never fail in.
    if (@($known | Where-Object { $_ -eq $wanted }).Count -gt 0) { return '' }

    $where = if ($Repo) { " in $Repo" } else { '' }
    $note = "'$wanted' is not a label$where, so 'gh pr create' would refuse this PR -- refused HERE instead, before the push."

    $note += if ($Prefix) {
        " The label comes from the branch prefix '$Prefix/' via $SeamPath, which is repo-owned: this script cannot validate it against a list of its own, so it asked GitHub."
    } else {
        " Nothing produced it but the unknown-prefix fallback: '$wanted' is a GitHub DEFAULT label, which a repo may equally have deleted."
    }

    # THE LABELS THAT DO EXIST, BOUNDED, and the bound is the point rather than tidiness. Naming them is
    # what turns a refusal into a repair when the answer is a rename ('bug' -> 'type: bug'), and it is
    # the same service Get-MissingCheckSuiteNote does by naming the suites that DID register. But a
    # label set is unbounded in a way a commit's check suites are not, so above ten the count plus the
    # command that lists them is the honest line for something read once in a terminal.
    $note += if ($known.Count -le 10) {
        " Labels that do exist: $(Format-CheckNameList -Names $known)."
    } else {
        $listCmd = if ($Repo) { "gh label list --repo $Repo" } else { 'gh label list' }
        " $($known.Count) labels do exist -- '$listCmd' names them."
    }

    $create = if ($Repo) { "gh label create '$wanted' --repo $Repo" } else { "gh label create '$wanted'" }
    $note += " Two remedies, and this script takes neither: create the label ($create), or point the prefix at a label that exists ($SeamPath)."
    # WHY NEITHER IS TAKEN, said in the refusal rather than left to the reader's judgement: both silent
    # options look like kindnesses and both break a repo that gates on the label.
    $note += " Not substituted and not dropped: a fallback label would classify this PR wrongly, and a repo whose own workflow gates on the label would then go green on a label that says nothing."
    return $note
}

function Get-DirectPushBlockingRules {
    <#
    .SYNOPSIS
        Which rulesets applying to the trunk carry a rule that a DIRECT PUSH cannot satisfy -- read from
        `gh api repos/<repo>/rules/branches/<trunk>`. Returns one record per such ruleset, for the caller
        to look the bypass up with.

    .DESCRIPTION
        THE FOLD IS A DIRECT PUSH BY DESIGN -- one of the three named exceptions to "never commit
        directly on main" (CLAUDE.md). A required status check cannot be satisfied by a direct push:
        the pushed commit has no checks yet, and GitHub refuses the ref update before any workflow could
        run. So on a trunk carrying such a rule the fold lands only for an account the ruleset lets
        bypass it, and for every other account ship-pr merges and then CANNOT push (issue #1278).

        THE PAYLOAD IS NOT FILTERED BY BYPASS, which is what makes this readable at all. Measured on
        this repo, September 3, 2026: `rules/branches/main` returns `required_status_checks` to an
        account whose `current_user_can_bypass` is `always`, so the rule list and the bypass are two
        independent reads and the second cannot be inferred from the first. This function does the
        first; Get-FoldPushVerdict makes the verdict from both.

        THREE RULE TYPES, and they are not a guess about GitHub's behaviour but the definition of each
        rule. `required_status_checks` is the measured one -- it produced the GH013 rejection in #1278,
        naming `lint-en-tests`. `pull_request` requires the change to arrive through a PR, and a fold
        commit does not. `update` restricts who may update the ref at all. Every other type either
        cannot fire on a fold (`deletion`; `non_fast_forward` and `required_linear_history`, which a
        commit on top of the trunk satisfies) or is satisfiable by the pusher rather than by bypass
        (`required_signatures`, the message patterns) -- so none of them is grounds to refuse a ship.

        `merge_queue` IS THE ONE OMISSION THAT IS NOT ABOUT THE RULE'S OWN BEHAVIOUR (issue #1506). It
        does block a direct push, so on the face of it it belongs in the list -- but a trunk behind a
        queue is one whose fold is not the shipping session's push to make at all: the queue merges the
        PR itself and `fold-on-merge.yml` folds off the resulting push (#1493). Its caller therefore
        asks Get-MergeQueueVerdict FIRST and never reaches this question. Listing the type here as well
        would add a branch no caller can reach, and a second answer to a question one function already
        owns. See that function for the measured GH013 text naming both refusals.

    .PARAMETER BranchRulesJson
        `gh api repos/<repo>/rules/branches/<trunk>` output. An unreadable or unparseable payload
        returns Readable = $false, and the caller warns rather than refusing -- see Get-FoldPushVerdict.

    .OUTPUTS
        [pscustomobject] Readable (bool) and Blocking (array of [pscustomobject] RulesetId / SourceType /
        Source / Rules / Contexts). An empty Blocking with Readable = $true is the ordinary answer in a
        repo whose trunk carries no such rule.
    #>
    param([string]$BranchRulesJson)

    $unreadable = [pscustomobject]@{ Readable = $false; Blocking = @() }
    if (-not $BranchRulesJson -or -not $BranchRulesJson.Trim()) { return $unreadable }
    try { $parsed = $BranchRulesJson | ConvertFrom-Json } catch { return $unreadable }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object. An empty
    # array parses to $null, which is the legitimate "this trunk has no rules" answer and NOT unreadable.
    $records = @(@($parsed) | Where-Object { $_ -and $_.PSObject.Properties['type'] })

    $blockingTypes = @('required_status_checks', 'pull_request', 'update')
    $byRuleset = [ordered]@{}
    foreach ($r in $records) {
        $type = ([string]$r.type).Trim().ToLowerInvariant()
        if ($blockingTypes -notcontains $type) { continue }

        # The id can be absent on a payload shape this function has not met; without it the caller has
        # nothing to look a bypass up with, so it is grouped under the empty key and reported as unknown.
        $id = ''
        if ($r.PSObject.Properties['ruleset_id']) { $id = [string]$r.ruleset_id }
        if (-not $byRuleset.Contains($id)) {
            $sourceType = ''
            if ($r.PSObject.Properties['ruleset_source_type']) { $sourceType = [string]$r.ruleset_source_type }
            $source = ''
            if ($r.PSObject.Properties['ruleset_source']) { $source = [string]$r.ruleset_source }
            $byRuleset[$id] = [pscustomobject]@{
                RulesetId  = $id
                SourceType = $sourceType
                Source     = $source
                Rules      = @()
                Contexts   = @()
            }
        }
        $byRuleset[$id].Rules += $type

        # The check CONTEXTS, so the refusal can name what the remote would have named. `lint-en-tests`
        # in the GH013 text of #1278 is this field, and quoting it is what makes the two messages
        # recognisably the same event.
        if ($type -eq 'required_status_checks' -and $r.PSObject.Properties['parameters'] -and $r.parameters) {
            $params = $r.parameters
            if ($params.PSObject.Properties['required_status_checks']) {
                foreach ($c in @($params.required_status_checks)) {
                    if ($c -and $c.PSObject.Properties['context']) { $byRuleset[$id].Contexts += [string]$c.context }
                }
            }
        }
    }

    $blocking = @()
    foreach ($key in $byRuleset.Keys) {
        $rec = $byRuleset[$key]
        $rec.Rules = @($rec.Rules | Sort-Object -Unique)
        $rec.Contexts = @($rec.Contexts | Sort-Object -Unique)
        $blocking += $rec
    }
    return [pscustomobject]@{ Readable = $true; Blocking = @($blocking) }
}

function Get-FoldPushVerdict {
    <#
    .SYNOPSIS
        Whether the fold commit will be pushable to the trunk by THIS account -- decided before the
        merge, from the trunk's rules and this account's bypass on each ruleset that carries one.
        Returns Blocked / Unknown / Reason / BlockedBy.

    .DESCRIPTION
        ISSUE #1278, AND IT IS STEP 0'S FAILURE MODE EXACTLY. ship-pr merged PR #1271, checked out main,
        folded, committed -- and the push was refused with GH013 ("Required status check
        'lint-en-tests' is expected"), leaving the trunk merged-but-unfolded: the changelog entry
        unfolded, the branch document still on main, every gate green until a release trips over it.
        That is the same half-state the worktree check at step 0 exists to prevent, reached by a
        different route, so the answer is the same one: refuse at step 0, where refusing is free.

        WHY IT CANNOT BE INFERRED FROM THE MERGE. A required status check gates the ref update, and the
        merge satisfies it (the PR's own check ran) while the fold cannot (a pushed commit has no
        checks). So a run can be fully entitled to merge and not entitled to fold, which is precisely
        what happened -- and why reading the CI verdict at step 3 says nothing about step 5.

        UNKNOWN IS A WARNING, NOT A REFUSAL -- the opposite posture to Get-MergeBlockVerdict above, and
        deliberately. There, an unreadable required-check list could let RED CODE onto the trunk, so it
        refuses. Here the thing at risk is a fold that can be redone by hand or by an account with
        bypass, while refusing on an unread ruleset would take ship-pr away from every consumer whose
        token cannot read one -- a blast radius far larger than the defect. Same reasoning, and the same
        answer, as step 0's own worktree arm: "an unreadable worktree list warns rather than refuses".

        `pull_requests_only` COUNTS AS NO BYPASS, because the fold is not a pull request. GitHub's three
        values answer "may this actor bypass"; only `always` answers yes for a direct push.

    .PARAMETER BranchRulesJson
        `gh api repos/<repo>/rules/branches/<trunk>` output -- the same payload Get-DirectPushBlockingRules
        reads, re-read here so the verdict is a pure function of what GitHub actually said.

    .PARAMETER BypassByRulesetId
        Ruleset id (as a string key) -> that ruleset's `current_user_can_bypass`. A ruleset missing from
        the map, or carrying an empty value, is the unreadable case for that ruleset alone.

    .PARAMETER NameByRulesetId
        Optional ruleset id -> `name`, used only to name the ruleset in the reason. Absent, the id is
        used instead and the verdict is identical.
    #>
    param(
        [string]$BranchRulesJson,
        [hashtable]$BypassByRulesetId = @{},
        [hashtable]$NameByRulesetId = @{}
    )

    $rules = Get-DirectPushBlockingRules -BranchRulesJson $BranchRulesJson
    if (-not $rules.Readable) {
        return [pscustomobject]@{
            Blocked   = $false
            Unknown   = $true
            Reason    = "the trunk's rules could not be read, so whether the fold can be pushed is unknown -- shipping anyway; step 5 will report it if the push turns out to be refused"
            BlockedBy = @()
        }
    }

    if ($rules.Blocking.Count -eq 0) {
        return [pscustomobject]@{
            Blocked   = $false
            Unknown   = $false
            Reason    = 'no rule on the trunk that a direct push cannot satisfy'
            BlockedBy = @()
        }
    }

    $blockedBy = @()
    $unknownOn = @()
    foreach ($rec in $rules.Blocking) {
        $label = $rec.RulesetId
        if ($NameByRulesetId -and $rec.RulesetId -and $NameByRulesetId.ContainsKey($rec.RulesetId)) {
            $label = "$($NameByRulesetId[$rec.RulesetId]) (id $($rec.RulesetId))"
        } elseif (-not $label) {
            $label = 'an unnamed ruleset'
        }

        $bypass = ''
        if ($BypassByRulesetId -and $rec.RulesetId -and $BypassByRulesetId.ContainsKey($rec.RulesetId)) {
            $bypass = ([string]$BypassByRulesetId[$rec.RulesetId]).Trim().ToLowerInvariant()
        }

        if ($bypass -eq 'always') { continue }
        if (-not $bypass) { $unknownOn += $label; continue }

        $what = "'" + ($rec.Rules -join "', '") + "'"
        if ($rec.Contexts.Count -gt 0) { $what += " ($($rec.Contexts -join ', '))" }
        $blockedBy += "$label applies $what to the trunk, and this account cannot bypass it (current_user_can_bypass = $bypass)"
    }

    if ($blockedBy.Count -gt 0) {
        return [pscustomobject]@{
            Blocked   = $true
            Unknown   = $false
            Reason    = ($blockedBy -join '; ')
            BlockedBy = @($blockedBy)
        }
    }

    if ($unknownOn.Count -gt 0) {
        return [pscustomobject]@{
            Blocked   = $false
            Unknown   = $true
            Reason    = "this account's bypass on $(Format-CheckNameList -Names $unknownOn) could not be read, so whether the fold can be pushed is unknown -- shipping anyway; step 5 will report it if the push turns out to be refused"
            BlockedBy = @()
        }
    }

    return [pscustomobject]@{
        Blocked   = $false
        Unknown   = $false
        Reason    = 'this account can bypass every trunk rule a direct push cannot satisfy'
        BlockedBy = @()
    }
}

function Get-MergeQueueVerdict {
    <#
    .SYNOPSIS
        Whether the trunk is behind a GITHUB MERGE QUEUE -- read from the same
        `gh api repos/<repo>/rules/branches/<trunk>` payload the two functions above already take.
        Returns Readable / Active.

    .DESCRIPTION
        ISSUE #1506, AND IT DECIDES WHO FOLDS. Under a queue `gh pr merge` does not merge: gh's own
        help says "When targeting a branch that requires a merge queue ... If required checks have
        passed, the pull request will be added to the merge queue." ADDED, exit 0, not merged. GitHub
        then merges it minutes later on a `gh-readonly-queue/**` branch, in a process the shipping
        session never observes -- so ship-pr's step 5 has nothing to fold onto and must not try. The
        fold is `fold-on-merge.yml`'s from that moment on (#1493), triggered by the push to the trunk
        that the queue's own merge produces.

        SO THIS IS NOT A DUPLICATE OF Get-DirectPushBlockingRules, WHICH DELIBERATELY OMITS
        `merge_queue` FROM ITS BLOCKING TYPES. A queue does block a direct push -- measured verbatim in
        the fold-on-merge run carrying the #1504 merge, where the rejection named BOTH rules:

            remote: - Required status check "lint-en-tests" is expected.
            remote: - Changes must be made through the merge queue

        -- but a caller that reads this verdict first never reaches the fold-push question at all,
        because under a queue the fold is not that session's push to make. Adding the type there as
        well would put a second answer to one question in the tree, and the branch it created would be
        unreachable from the only caller either function has. Named here so the omission reads as a
        decision rather than as the oversight #1499 was filed on.

        UNREADABLE IS NOT "NO QUEUE", and the caller must not collapse the two. Active = $false with
        Readable = $false means the question was not answered; treating that as "no queue" would send
        a run back down the direct-merge path on a trunk that has one, which is the #1325 half-state
        (a fold commit written for a PR that has not landed). Read Readable before Active.

    .PARAMETER BranchRulesJson
        `gh api repos/<repo>/rules/branches/<trunk>` output. Empty or unparseable -> Readable = $false.

    .OUTPUTS
        [pscustomobject] Readable (bool) and Active (bool).
    #>
    param([string]$BranchRulesJson)

    $unreadable = [pscustomobject]@{ Readable = $false; Active = $false }
    if (-not $BranchRulesJson -or -not $BranchRulesJson.Trim()) { return $unreadable }
    try { $parsed = $BranchRulesJson | ConvertFrom-Json } catch { return $unreadable }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object. An empty
    # array parses to $null, which is the legitimate "this trunk has no rules" answer and NOT unreadable.
    $records = @(@($parsed) | Where-Object { $_ -and $_.PSObject.Properties['type'] })

    $active = $false
    foreach ($r in $records) {
        if ((([string]$r.type).Trim().ToLowerInvariant()) -eq 'merge_queue') { $active = $true; break }
    }
    return [pscustomobject]@{ Readable = $true; Active = $active }
}

function Get-RequiredCheckContexts {
    <#
    .SYNOPSIS
        The check contexts a trunk's ruleset REQUIRES, read from the branch-rules payload. Returns
        Readable (bool) and Names (string[]), sorted and unique. Issue #1602.

    .DESCRIPTION
        WHY NOT `gh pr checks --required`, WHICH THIS FILE ALREADY READS EVERYWHERE. Because that
        endpoint answers a different question, and the difference is a RACE. It reports the required
        checks *that have registered on this PR*, so a required workflow which has not yet created its
        check run is simply absent from it -- indistinguishable from a ruleset that requires nothing.
        For the merge verdict that ambiguity is harmless and is resolved conservatively (refuse on the
        failure path, stay green on the green one). For deciding WHAT TO WAIT FOR it is fatal, because
        the decision is made at the one moment the answer is least likely to have arrived: seconds
        after open-pr pushed.

        MEASURED ON THIS CHANGE'S OWN FIRST SHIP, PR #1614 (September 8, 2026). The probe asked
        `gh pr checks --required` immediately after the registration wait, got nothing back --
        `branch-entry` and `claude-review` are separate workflows and register faster than ci.yml's
        jobs -- and the run fell back to watching every check, which is the correct fail-open. But
        `gh pr checks --watch` picks up checks that register after it starts, so the full watch then
        ran to completion, the re-entry the #1549 loop provides was never reached, and the narrowing
        never happened at all. The change was inert on the very first lap it ran.

        THE RULESET HAS NO RACE. It states which contexts are required whether or not anything has
        registered, and `required_status_checks` being absent is a positive answer: this trunk requires
        nothing. So this reads the payload ship-pr has ALREADY fetched for the fold-push and
        merge-queue verdicts -- no extra network call, and available before the wait begins rather
        than after it.

        READABLE IS SEPARATE FROM EMPTY, and the caller must not collapse the two -- the same
        distinction Get-MergeQueueVerdict above draws on the same payload, for the same reason.
        Readable = $false means the question was not answered (no token scope, an older gh, a repo
        whose rules cannot be read -- all states ship-pr's step 0b already tolerates), and the caller
        then falls back to the `gh pr checks --required` probe rather than assuming either way.
        Readable = $true with no names means the trunk genuinely requires nothing, which is the
        GitHub Free case, and the wait must then watch everything exactly as it always did.

    .PARAMETER BranchRulesJson
        `gh api repos/<repo>/rules/branches/<trunk>` output. Empty or unparseable -> Readable = $false.
        An empty JSON array parses to $null in 5.1 and is the legitimate "this trunk has no rules"
        answer, NOT unreadable -- the trap Get-MergeQueueVerdict documents beside its own parse.

    .OUTPUTS
        [pscustomobject] Readable (bool) and Names (string[]).
    #>
    param([string]$BranchRulesJson)

    $unreadable = [pscustomobject]@{ Readable = $false; Names = @() }
    if (-not $BranchRulesJson -or -not $BranchRulesJson.Trim()) { return $unreadable }
    try { $parsed = $BranchRulesJson | ConvertFrom-Json } catch { return $unreadable }

    # Assign first, wrap second -- 5.1 hands a parsed JSON array to the pipeline as ONE object.
    $records = @(@($parsed) | Where-Object { $_ -and $_.PSObject.Properties['type'] })

    $names = @()
    foreach ($r in $records) {
        if ((([string]$r.type).Trim().ToLowerInvariant()) -ne 'required_status_checks') { continue }
        if (-not $r.PSObject.Properties['parameters']) { continue }
        $p = $r.parameters
        if (-not $p -or -not $p.PSObject.Properties['required_status_checks']) { continue }
        # Wrapped for the same reason as above: one required check is handed through as the object
        # itself, and this repo's own ruleset requires exactly one -- so the collapse would be
        # invisible here and would surface only in a consumer with two.
        foreach ($c in @(@($p.required_status_checks) | Where-Object { $_ })) {
            if (-not $c.PSObject.Properties['context']) { continue }
            $ctx = ([string]$c.context).Trim()
            if ($ctx) { $names += $ctx }
        }
    }

    return [pscustomobject]@{ Readable = $true; Names = @(@($names) | Sort-Object -Unique) }
}
