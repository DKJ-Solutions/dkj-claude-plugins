<#
.SYNOPSIS
    The decisions behind prepare-release.ps1 -- what is pending, what each entry obliges once it is
    live, which entries' scores are worth a second look, and the release-day runbook the whole run
    prints. Pure: no network, no filesystem, no repo-config, no gh, no git.

.DESCRIPTION
    Dot-sourced by prepare-release.ps1 beside it, for the split golive-block-rules.ps1 and
    backlog-page-rules.ps1 already make in this plugin: everything that touches git, gh or the Shopify
    CLI cannot be exercised by a suite, while the parts that can be WRONG -- which entries are pending,
    which sentence is a go-live obligation, which command reaches live -- are pure functions over values
    the caller has already read.

    INBOUND #2509 (from BWJ-Development/smartwatchbanden, September 26, 2026). The chain had tools for
    the moment of release -- live-preflight, the push, cut-release, theme-lifecycle, golive-block -- and
    nothing for "release is on Monday, get me ready now". Measured in that store on the Friday before:
    21 pending entries, 3 of them touching the theme, 15 theme files in the range, and at least two
    go-live obligations (stop an experiment in the CRO tool) buried in entry prose. Answering the
    question meant reading five lens sections and running the diff by hand.

    WHAT THIS FILE DOES NOT DECIDE, AND WHERE THAT LIVES INSTEAD:

      the bump      the fold's pending tally already names it (Get-PendingBumpFromTally, in
                    golive-block-rules.ps1). Re-deriving it would be a second copy of a release gate's
                    arithmetic, and the tier parser that produces it lives in dkj-policy's libs, which
                    this plugin's scripts may not reach.
      the push list live-push-rules.ps1, mirrored into this plugin from its one source (#2509) so the
                    list prepared on Friday is derived by the same rules as the one pushed on Monday.

    NEEDS ref-print-lib.ps1 LOADED FIRST -- the driver and the suite both dot-source it -- for
    Test-PathPasteSafe and ConvertTo-ConsoleStrippedText, which the runbook applies to every path and
    every piece of entry prose it prints.

    Pure ASCII (repo convention for .ps1).
#>

# The one heading word the machine reads in a pending entry. Every entry opens with it; see
# entry-scaffold-lib.ps1 in dkj-policy, which writes it.
$script:PrepareDeployWord = 'DEPLOY:'

function Get-PendingChangelogEntries {
    <#
        Pure: the entries under a changelog's pending heading, one row each -- Branch, Heading, Body,
        Tier0Score, HigherScore.

        THE PENDING SECTION IS STRUCTURAL: the first '## ' heading that reads '[Unreleased]', up to the
        next '## ' heading. Each '### ' heading under it opens one entry. That is the shape the fold
        writes, and it is the same boundary entry-scaffold-lib reads -- restated structurally rather than
        borrowed, because that lib is dkj-policy's.

        THE TWO SCORES ARE READ BY POSITION, NOT BY HEADING TEXT. The audience section's heading has
        been retexted several times and every retired wording is still in somebody's changelog, so the
        text before the first '####' is the entry's own tier and the first '####' that is not the Pull
        Request section is its reach. Each score is the first '**Score:**' line in its section, trimmed;
        '' where the section or the line is absent.

        THE BRANCH IS WHAT FOLLOWS 'DEPLOY:', up to the timestamp's middle dot. Backticks are stripped:
        an older heading form quoted the branch name.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Changelog)

    $inPending = $false
    $entries = New-Object System.Collections.Generic.List[object]
    $body = $null
    foreach ($line in @($Changelog -split "`r?`n")) {
        if ($line -match '^##\s+(?!#)') {
            if ($inPending) { break }
            if ($line -match '^##\s+\[Unreleased\]') { $inPending = $true }
            continue
        }
        if (-not $inPending) { continue }
        if ($line -match '^###\s+(?!#)(.*)$') {
            $heading = $Matches[1].Trim()
            $branch = $heading
            $at = $branch.IndexOf($script:PrepareDeployWord)
            if ($at -ge 0) { $branch = $branch.Substring($at + $script:PrepareDeployWord.Length) }
            $dot = $branch.IndexOf([char]0x00B7)
            if ($dot -ge 0) { $branch = $branch.Substring(0, $dot) }
            $body = New-Object System.Collections.Generic.List[string]
            $entries.Add([pscustomobject]@{
                Branch = ($branch -replace '`', '').Trim(); Heading = $heading; Lines = $body
                Body = ''; Tier0Score = ''; HigherScore = ''
            })
            continue
        }
        if ($null -ne $body) { $body.Add($line) }
    }

    foreach ($e in $entries) {
        $e.Body = ($e.Lines -join "`n").Trim()
        $e.PSObject.Properties.Remove('Lines')
        $sections = @([regex]::Split($e.Body, '(?m)^####\s+'))
        $e.Tier0Score = Get-FirstScore -Text $sections[0]
        for ($i = 1; $i -lt $sections.Count; $i++) {
            $title = ($sections[$i] -split "`n", 2)[0].Trim()
            if ($title -match '^(?i)pull request\b') { continue }
            $e.HigherScore = Get-FirstScore -Text $sections[$i]
            break
        }
    }
    return @($entries.ToArray())
}

function Get-FirstScore {
    <# Pure: the value on the first '**Score:**' line of -Text, trimmed; '' where there is none. #>
    param([AllowEmptyString()][string]$Text)
    $m = [regex]::Match([string]$Text, '(?m)^\*\*Score:\*\*[ \t]*(.*?)[ \t]*$')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Test-ScoreIsNone {
    <# Pure: true where a score says the tier is not reached -- N/A in any spelling, or nothing at all. #>
    param([AllowEmptyString()][string]$Score)
    $s = ([string]$Score).Trim()
    if (-not $s) { return $true }
    return [bool]($s -match '^(?i)n\s*/?\s*a\b')
}

function Get-EntryScoreNotes {
    <#
        Pure: the pending entries whose score is worth a second look before the cut, one row each --
        Branch, Note.

        ONE RULE, AND IT IS A QUESTION RATHER THAN A VERDICT. In a repo whose audience is tier 1 --
        management and the employer, which is what a store answers -- a fix/ branch that scores its reach
        is flagged: a fix normally restores what that audience already had, so a reach score on one is
        either a deliberate call or a copy-paste from a feature entry, and the Friday is when that costs a
        sentence to settle rather than a mis-sized release. It is ADVISORY -- the release's tier gate is
        cut-release's, and a fix that genuinely reaches management is legitimate.

        ONLY AT AUDIENCE TIER 1, AND THAT WAS MEASURED. In a tier-2 repo a fix reaches the subscriber the
        moment they upgrade, so a reach score on one is ordinary: run over this plugin's own source repo
        (audience 2) on September 26, 2026, the rule flagged 6 of 23 pending entries, every one of them
        correctly scored. So -AudienceTier other than 1 -- or unstated -- returns nothing.

        WHAT #2509 ALSO ASKED, AND WHY IT IS NOT HERE. It proposed flagging "a tier-2 score where the seam
        says tier 2 is off". An entry does not carry a tier number this file can read: there is ONE
        reach section, and whether a score there counts as tier 1 or tier 2 is decided by
        Get-ReleaseAudienceTier inside dkj-policy's parser. Guessing that here would be a second copy of
        the rule, so the fold's tally stays the authority on what the pending entries add up to.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()]$Entries,
        [AllowNull()]$AudienceTier = $null
    )
    $notes = @()
    if ("$AudienceTier" -ne '1') { return $notes }
    foreach ($e in @($Entries)) {
        if ($null -eq $e) { continue }
        if ($e.Branch -match '^fix/' -and -not (Test-ScoreIsNone -Score $e.HigherScore)) {
            $notes += [pscustomobject]@{
                Branch = $e.Branch
                Note   = "a fix/ entry scores its reach beyond the repo ('$($e.HigherScore)') -- a fix usually restores what that audience already had; confirm the score is deliberate before the cut."
            }
        }
    }
    return @($notes)
}

# THE PHRASES THAT MARK A GO-LIVE OBLIGATION. English, because the repo's own language rule covers the
# script layer; a store whose entries are written in another language passes its own with
# -ObligationPattern on the driver, which REPLACES this list rather than extending it -- a repo knows its
# own wording better than a default does.
#
# NO BARE 'go-live' PHRASE, and that was measured: against this repo's own pending entries it matched the
# skill NAME golive-block twice, in sentences obliging nobody to do anything. 'after go-live' is still
# caught, by the 'after' phrase.
$script:GoLiveObligationPatterns = @(
    '(?i)\bonce\s+(this|it)\s+(is|goes)\s+live\b',
    '(?i)\bonce\s+live\b',
    '(?i)\bafter\s+(the\s+)?(live\s+push|go-?live|release)\b',
    '(?i)\bwhen\s+(this|it)\s+goes\s+live\b',
    '(?i)\bon\s+release\s+day\b',
    '(?i)\b(stop|pause|end|disable)\b[^.]{0,60}\b(experience|experiment|campaign|test)\b',
    '(?i)\b(switch|turn)\s+(off|on)\b',
    '(?i)\bapp\s+setting'
)

function Get-GoLiveObligationPatterns {
    <# The default obligation phrases, so the driver and the suite read one list. #>
    return @($script:GoLiveObligationPatterns)
}

function Get-GoLiveObligations {
    <#
        Pure: the sentences in the pending entries that read as something that must happen once the
        release is live, one row each -- Branch, Sentence.

        A CANDIDATE LIST, AND IT SAYS SO. The obligations #2509 measured -- "stop Convert experience
        1004205630", "change an app setting" -- are free prose, not a field, so this matches phrases
        and cannot be complete. What it buys is that 21 entries of prose become a short list somebody
        reads on Friday instead of rediscovering on Monday. The driver prints it under that caveat.

        ONLY THE ENTRY'S OWN TEXT IS READ -- the part above its first '####'. The reach section argues a
        score and the Pull Request section is a title; neither is where somebody writes "turn X off".
        Markdown is stripped to the words, and a sentence is matched at most once, however many phrases
        hit it.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()]$Entries,
        [AllowNull()][AllowEmptyCollection()][string[]]$Patterns = $null
    )
    $pats = @($Patterns | Where-Object { $_ })
    if ($pats.Count -eq 0) { $pats = Get-GoLiveObligationPatterns }

    $rows = @()
    foreach ($e in @($Entries)) {
        if ($null -eq $e) { continue }
        $own = @([regex]::Split([string]$e.Body, '(?m)^####\s+'))[0]
        $text = ($own -split "`r?`n" | Where-Object { $_ -notmatch '^\*\*Score:\*\*' }) -join ' '
        $text = $text -replace '\[([^\]]*)\]\([^)]*\)', '$1'
        $text = $text -replace '[`*]', ''
        $text = ($text -replace '\s+', ' ').Trim()
        if (-not $text) { continue }
        foreach ($sentence in ([regex]::Split($text, '(?<=[.!?])\s+(?=[A-Z(])'))) {
            $s = $sentence.Trim()
            if (-not $s) { continue }
            foreach ($p in $pats) {
                if ($s -match $p) { $rows += [pscustomobject]@{ Branch = $e.Branch; Sentence = $s }; break }
            }
        }
    }
    return @($rows)
}

function Format-VerificationPullCommand {
    <#
        Pure: the `shopify theme pull` that reads the pushed files back off live into a FRESH folder, so
        what landed can be compared with what was meant to. '' for an empty list.

        A PULL, NEVER A PUSH, AND NEVER WITHOUT --only. A pull from live changes nothing on the store,
        which is why it may be printed without the authorisation marker. It is bounded to the push list
        for the same reason the push is: a whole-theme pull is minutes of files nobody asked about.
        THE FOLDER IS FRESH so that nothing already in it can pass for something the pull wrote.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][AllowEmptyCollection()][string[]]$Only
    )
    $files = @(@($Only) | ForEach-Object { if ($null -ne $_) { ([string]$_).Trim() } } | Where-Object { $_ })
    if ($files.Count -eq 0) { return '' }
    $parts = @('shopify', 'theme', 'pull', '--store', $Store, '--theme', $ThemeId, '--path', $Path)
    foreach ($f in $files) { $parts += @('--only', $f) }
    return ($parts -join ' ')
}

function Format-ReleaseRunbook {
    <#
        Pure: the release-day runbook, as lines -- the sequence #2509 asked for, with every fact this run
        could derive filled in and every fact it could not named as missing rather than guessed.

        THE PUSH COMMAND CARRIES NO MARKER, and neither does anything else here. It is composed by
        Format-LivePushCommand, which cannot produce one; the runbook says the marker is a human act and
        never names it -- the same rule live-preflight's own closing lines keep.

        THE ORDER IS BWJ'S RELEASE DAY, and each step names the tool that owns it rather than restating
        what that tool does: preflight -> push -> verification pull -> go-live obligations -> preview
        sweep -> cut -> backup -> release-notes page. The preflight re-derives the push list and runs the
        drift check for real on the day; what this run printed on the Friday is the plan, not the proof.
    #>
    param(
        [string]$Store = '',
        [string]$LiveThemeId = '',
        [AllowNull()][AllowEmptyCollection()][string[]]$PushFiles = @(),
        [string]$Bump = '',
        [string]$TargetVersion = '',
        [string]$ReleaseDate = '',
        [AllowNull()][AllowEmptyCollection()]$Obligations = @()
    )

    $files = @(@($PushFiles) | Where-Object { $_ })
    # NO COMMAND IS COMPOSED AROUND A PATH THAT IS NOT PASTE-SAFE (this branch's security review). The
    # paths come out of git diff, and a theme file can reach the repo through a sync from the theme
    # editor, so a name holding `;` or `$(...)` would run the moment a person pastes the line. #1594
    # measured that quoting does not close that class in every shell; Test-PathPasteSafe (ref-print-lib,
    # which the driver loads) refuses the path instead. An accented theme name is refused too -- the
    # safe direction, since live-preflight composes the real command on the day.
    $unsafe = @($files | Where-Object { -not (Test-PathPasteSafe -Path $_) })
    $haveTarget = [bool]($Store -and $LiveThemeId -and $unsafe.Count -eq 0)
    $ver = if ($TargetVersion) { "v$TargetVersion" } else { 'the next version' }
    $out = @()
    $out += "# Release-day runbook -- $ver$(if ($ReleaseDate) { ", $ReleaseDate" })"
    $out += ''
    $out += 'Prepared ahead of the day. Every step below re-checks on the day; nothing here is authorised.'
    $out += ''

    $out += '1. Preflight, on the trunk -- the dkj-subagents-shopify `live-preflight` skill. It re-derives the push'
    $out += '   list, runs the drift check for real, takes the rollback backup, and prints the push command.'
    $out += ''

    $out += "2. The push -- $($files.Count) theme file(s), one --only each:"
    $push = ''
    if ($haveTarget) { $push = Format-LivePushCommand -Store $Store -ThemeId $LiveThemeId -Only $files }
    if ($push) {
        $out += "   $push"
        $out += '   Refused as it stands: the authorisation marker your repo states is added by a person, to this'
        $out += '   exact command, and no script writes it. Use the command live-preflight prints on the day.'
    } elseif ($unsafe.Count -gt 0) {
        $out += "   (not composed -- $($unsafe.Count) path(s) cannot be pasted safely into a command line:"
        foreach ($u in $unsafe) { $out += "    $(ConvertTo-ConsoleStrippedText -Text $u)" }
        $out += '    read them before the day; a name like that on a theme is itself worth a question)'
    } elseif (-not $haveTarget) {
        $out += '   (not composed -- no store domain or no live theme id is known to this run)'
    } else {
        $out += '   (nothing to push -- no theme file in the range; this release is code and docs only)'
    }
    $out += ''

    $out += '3. Verification pull -- read the pushed files back off live, into a folder nothing else wrote:'
    $pull = ''
    if ($haveTarget) { $pull = Format-VerificationPullCommand -Store $Store -ThemeId $LiveThemeId -Path "`$env:TEMP\live-verify-$($ver -replace '\s', '-')" -Only $files }
    $out += $(if ($pull) { "   $pull" } else { '   (not composed -- see step 2)' })
    $out += ''

    $obl = @($Obligations | Where-Object { $_ })
    $out += "4. Go-live obligations -- $($obl.Count) candidate(s) found in the entries' prose (a candidate list, not a complete one):"
    # Entry prose is foreign text in a document meant to be read beside commands, so a control or format
    # character is stripped before it can repaint what the reader sees (ref-print-lib, #2024).
    foreach ($o in $obl) { $out += "   - [ ] $(ConvertTo-ConsoleStrippedText -Text $o.Branch): $(ConvertTo-ConsoleStrippedText -Text $o.Sentence)" }
    if ($obl.Count -eq 0) { $out += '   (none found -- read the entries before assuming there are none)' }
    $out += ''

    $out += '5. Preview sweep -- the `theme-lifecycle` skill, sweep-preview-themes (dry run first).'
    $out += ''
    $bumpText = if ($Bump) { " -Bump $Bump" } else { '' }
    $out += "6. The cut -- the dkj-policy ``cut-release`` skill$(if ($Bump) { ", with$bumpText" } else { ' (the bump could not be read from the pending tally)' })."
    if ($Bump -eq 'minor') { $out += '   A minor owes the hand-written audience note (audience/<dir>/<X.Y.Z>.md) -- draft it before the day.' }
    $out += ''
    $out += '7. Backup -- the `theme-lifecycle` skill, backup-live-theme, at the moment THEME-LIFECYCLE-portable.md names.'
    $out += ''
    $out += '8. Release-notes page -- the dkj-policy `release-notes-page` skill: rebuild, then deploy as its own step.'
    return @($out)
}
