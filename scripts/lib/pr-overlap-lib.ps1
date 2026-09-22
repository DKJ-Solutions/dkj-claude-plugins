<#
.SYNOPSIS
    The overlap scan behind open-pr.ps1's advisory note (issue #2315): which OTHER open pull requests
    change a file this branch also changes, and how that is worded.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\pr-overlap-lib.ps1')

    WHAT NOTHING IN THIS WORKFLOW USED TO SAY. Two branches editing one file is ordinary and is not
    prevented anywhere. What was missing was that NOBODY WAS TOLD: the first thing that reported the
    collision was ship-pr's forward lap learning it from GitHub as
    '422 merge conflict between base and head' -- after the branch had been built, reviewed, pushed and
    certified by CI one or more times.

    MEASURED ON PR #2300, SEPTEMBER 22, 2026. The 422 arrived at forward lap 3, roughly forty minutes
    of CI waits in; resolving the conflict took about five minutes. Two other pull requests -- #2308
    (opened 15:01Z) and #2310 (15:22Z) -- were changing .github/workflows/ci.yml at that moment, both
    listed in `gh pr list` the whole time, and #2300 merged at 16:17Z. So the fact was public and
    readable for over an hour before the tooling met it as a refusal.

    IT IS A DIFFERENT QUESTION FROM THE CONFLICT GUARD, NOT THAT GUARD FIRING LATE. ship-pr already
    refuses a CONFLICTING pull request up front, before the CI wait (#1584), and that guard was correct
    and silent here: when the run started, 'main' had not yet gained the commit that would collide, so
    the PR genuinely read MERGEABLE. The conflict came into existence DURING the run.

      #1584 asks  "is this PR conflicting now?"          -- a fact about the trunk as it stands.
      this asks   "is somebody else editing what I edit?" -- a fact about other open BRANCHES,
                                                            knowable before the trunk has moved at all.

    A WARNING, NEVER A REFUSAL, and no -Force valve -- the same shape as open-pr's machine-local path
    gate (#1559) and for the same stated reason: two branches touching one file is ordinary and usually
    harmless, and this repo declines findings-list gates on their false-positive rate (the stale-path
    check, 124 findings, all false). What it buys is not prevention -- the conflict is still coming --
    but that somebody knows about it before CI is spent on a head that cannot merge.

    THERE IS NO EXCLUSION LIST, AND THAT IS A MEASURED ANSWER RATHER THAN AN OMISSION. #2315 predicted
    that plain path equality would be noisy on the files every branch touches, named
    dkj-policy/CHANGELOG.md as the case, and proposed an exclusion list while noting it as the obvious
    way for this to go stale. Held against this repo's last 60 pull requests (#2195-#2316, measured
    September 22, 2026): 40 of them had at least one concurrently open PR, 11 of those would have seen
    this note, 13 overlapping pairs in all -- and filtering CHANGELOG.md and the branch document out
    changed NOTHING, 13 against 13. Neither path appears in a single PR's changed-file set:
    CHANGELOG.md is written by the FOLD, which happens on the trunk after the merge, and #1255 gave
    every branch its own dkj-policy/<branch>.md, so no two of them share one. All 13 pairs were genuine
    same-file collisions on real source. An exclusion list here would be a mechanism with nothing to
    exclude, carrying the staleness the issue warned about and buying none of the quiet it was for.

    WHAT THE MEASUREMENT DID SURFACE IS MIRRORED PATHS. A change to a shared workflow script lands in
    the root copy and in each plugin mirror, so scripts/lib/native-capture-lib.ps1 and its two mirrors
    count as three overlapping paths for one fact -- 5 of the 13 pairs are that shape. They are NOT
    collapsed: they really are three files and each one really can conflict. What answers it is the
    per-PR path cap in Format-PrOverlapNote, which keeps one shared capability from filling the screen.

    Pure functions only: no git, no gh, no disk. The two calls this scan needs -- the branch's own
    changed paths and the open pull requests' -- are made by open-pr.ps1, which is the one place they
    can be, and which is also why they cannot be covered by a suite while everything here can.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

function Get-OpenPrPathRecords {
    <#
    .SYNOPSIS
        The pull requests in a `gh pr list --json number,title,headRefName,files` payload, as records
        carrying Number, Title, HeadRefName and Paths. An EMPTY array for empty input, unparseable
        JSON, or a payload with no readable record.

    .DESCRIPTION
        EMPTY IS "COULD NOT BE ASKED" AND NOT "NOBODY ELSE IS EDITING ANYTHING", which is the one thing
        this contract has to make unambiguous -- the same distinction Get-LabelNames draws in
        pr-issues-lib.ps1. The caller checks gh's exit code first and says so; here an unreadable
        payload simply produces no findings, which is the silent direction and the safe one for an
        advisory note.

        THE 5.1 PARSE TRAPS ARE THE PART WORTH TESTING, and they are the same two that file records:
        a parsed JSON array reaches the pipeline as a SINGLE object, so the assign-first/wrap-second
        shape is required; and a field gh was never asked for is ABSENT rather than empty, so every
        record is probed before it is read.

        PATHS ARE FORWARD-SLASHED AND DE-DUPLICATED, because the other side of the comparison comes
        from `git diff --name-only` and has to be normalised the same way or an overlap that exists is
        reported as none. A record with no readable number is dropped -- the number is what the note
        cites, and a finding nobody can look up is worse than no finding.
    #>
    param([string]$Json)

    if (-not $Json -or -not $Json.Trim()) { return @() }
    try { $parsed = $Json | ConvertFrom-Json } catch { return @() }
    if ($null -eq $parsed) { return @() }

    # List[psobject] AND NOT List[object], WHICH IS A 5.1 TRAP RATHER THAN A PREFERENCE -- see
    # claim-issue-lib.ps1's ConvertFrom-CommitScanLog for the measurement. Windows PowerShell 5.1 throws
    # ArgumentException on the array subexpression @() over a List[object], whatever the list holds, and
    # reports it at the 'return @($records)' line, which sends a reader to the wrong statement entirely.
    $records = New-Object 'System.Collections.Generic.List[psobject]'
    foreach ($record in @(@($parsed) | Where-Object { $_ })) {
        if (-not $record.PSObject.Properties['number']) { continue }
        $number = 0
        if (-not [int]::TryParse(([string]$record.number).Trim(), [ref]$number)) { continue }
        if ($number -le 0) { continue }

        $paths = New-Object System.Collections.Generic.List[string]
        if ($record.PSObject.Properties['files']) {
            foreach ($file in @(@($record.files) | Where-Object { $_ })) {
                if (-not $file.PSObject.Properties['path']) { continue }
                $path = ConvertTo-ComparablePath -Path ([string]$file.path)
                if ($path -and -not $paths.Contains($path)) { $paths.Add($path) | Out-Null }
            }
        }

        $records.Add([pscustomobject]@{
            Number      = $number
            Title       = if ($record.PSObject.Properties['title']) { ([string]$record.title).Trim() } else { '' }
            HeadRefName = if ($record.PSObject.Properties['headRefName']) { ([string]$record.headRefName).Trim() } else { '' }
            Paths       = @($paths)
        }) | Out-Null
    }
    return @($records)
}

function ConvertTo-ComparablePath {
    <#
    .SYNOPSIS
        One repo path, normalised so the two sides of this comparison can be compared at all: trimmed,
        stripped of the quotes `git diff --name-only` puts round a path it C-quotes, and forward-slashed.
        '' for anything that normalises to nothing.

    .DESCRIPTION
        THE COMPARISON IS ORDINAL AND CASE-SENSITIVE, deliberately. Both sides originate in git, which
        stores one spelling of a path, so a case difference between them is not a near-miss to be
        forgiven -- it is two different files, or a checkout whose case-insensitive filesystem has
        already lost the distinction. Forgiving it would invent overlaps on a repo that legitimately
        holds Foo.ps1 and foo.ps1, which is the direction an advisory note must not err in.

        THE QUOTE STRIP MATTERS BECAUSE THE CALLER PASSES -c core.quotePath=true, exactly as park-lib
        and check-fanout already do: a path with a non-ASCII byte then arrives wrapped in double quotes
        while the gh payload's copy of the same path does not, and the pair would never match.
    #>
    param([string]$Path)

    if ($null -eq $Path) { return '' }
    $value = $Path.Trim()
    if (-not $value) { return '' }
    if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    return ($value -replace '\\', '/').Trim()
}

function Get-PrOverlapFindings {
    <#
    .SYNOPSIS
        Which of the open pull requests change a path this branch also changes: one finding per such
        PR, carrying its number, title, head ref and the shared paths. An EMPTY array when there is
        nothing to report -- including when either side is unknown.

    .DESCRIPTION
        SELF IS EXCLUDED BY NUMBER AND BY HEAD REF, because which of the two is available depends on
        when this runs. On a fresh branch there is no PR yet and only the ref name identifies it; on a
        re-run -- and on every ship-pr, whose step 1 is this script -- the branch's own PR is in the
        list and would otherwise be reported as a stranger sharing every path with itself, which is
        both the loudest possible finding and always wrong.

        SORTED BY SHARED-PATH COUNT, THEN BY NUMBER. The PR sharing four files is the one worth reading
        first, and the number breaks the tie so two runs against one state print in one order -- a note
        whose lines move between runs reads as new information when it is not.

        FINDINGS, NOT A VERDICT. This function answers what overlaps; whether that matters is the
        reader's call, and the wording that says so is Format-PrOverlapNote's. Keeping them apart is
        what lets the suite assert the SET without asserting the prose, which is the half that gets
        rewritten.
    #>
    param(
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][AllowNull()][string[]]$ChangedPaths,
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][AllowNull()][object[]]$OpenPrs,
        [Parameter(Mandatory = $false)][int]$SelfNumber = 0,
        [Parameter(Mandatory = $false)][string]$SelfBranch = ''
    )

    # AN ORDINAL SET AND NOT A HASHTABLE, WHICH IS THE WHOLE OF THE CASE RULE. A PowerShell hashtable
    # keys case-INSENSITIVELY by default, so 'scripts/Foo.ps1' would look up 'scripts/foo.ps1' and the
    # comparison ConvertTo-ComparablePath's header promises would quietly not be the one being made.
    # Caught by this lib's own suite, which asserts the two spellings are two files.
    $mine = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($path in @(@($ChangedPaths) | Where-Object { $_ })) {
        $normalised = ConvertTo-ComparablePath -Path ([string]$path)
        if ($normalised) { $mine.Add($normalised) | Out-Null }
    }
    if ($mine.Count -eq 0) { return @() }

    $selfRef = ([string]$SelfBranch).Trim()
    # List[psobject], for the 5.1 trap documented at Get-OpenPrPathRecords's own list above.
    $findings = New-Object 'System.Collections.Generic.List[psobject]'
    foreach ($pr in @(@($OpenPrs) | Where-Object { $_ })) {
        if (-not $pr.PSObject.Properties['Number']) { continue }
        if ($SelfNumber -gt 0 -and [int]$pr.Number -eq $SelfNumber) { continue }
        if ($selfRef -and $pr.PSObject.Properties['HeadRefName'] -and
            [string]::Equals(([string]$pr.HeadRefName).Trim(), $selfRef, [System.StringComparison]::Ordinal)) { continue }

        $shared = New-Object System.Collections.Generic.List[string]
        if ($pr.PSObject.Properties['Paths']) {
            foreach ($path in @(@($pr.Paths) | Where-Object { $_ })) {
                $normalised = ConvertTo-ComparablePath -Path ([string]$path)
                if ($normalised -and $mine.Contains($normalised) -and -not $shared.Contains($normalised)) {
                    $shared.Add($normalised) | Out-Null
                }
            }
        }
        if ($shared.Count -eq 0) { continue }

        $findings.Add([pscustomobject]@{
            Number      = [int]$pr.Number
            Title       = if ($pr.PSObject.Properties['Title']) { [string]$pr.Title } else { '' }
            HeadRefName = if ($pr.PSObject.Properties['HeadRefName']) { [string]$pr.HeadRefName } else { '' }
            SharedPaths = @($shared | Sort-Object)
        }) | Out-Null
    }

    return @($findings | Sort-Object -Property @{ Expression = { $_.SharedPaths.Count }; Descending = $true },
                                               @{ Expression = { $_.Number }; Descending = $false })
}

function Format-PrOverlapNote {
    <#
    .SYNOPSIS
        The advisory note for a set of overlap findings, or '' when there are none.

    .DESCRIPTION
        WHAT IT DOES NOT SAY, AND WHY. #2315 proposed closing with "Merging the trunk in NOW costs one
        resolution instead of one per certification lap." That sentence is wrong at the moment this
        note is printed, and checking it was the whole of the repair: every PR named here is OPEN, so
        its work is not on the trunk and there is nothing to merge in yet. Printing it would send the
        reader to run a command that does nothing and then read the silence as reassurance.

        WHAT IS TRUE AT THIS MOMENT is that whoever merges SECOND resolves, and that the resolution is
        cheapest when it is expected rather than met as a 422 several certification laps in. So the
        note names the collision and the one decision that is actually available before either lands:
        ship them in a deliberate order instead of racing them, because two concurrent ships pay for
        the same resolution in CI time on top of the five minutes it actually takes.

        BOTH LISTS ARE CAPPED AND A TRUNCATION SAYS SO, on claim-issue's precedent: a note that silently
        stops is indistinguishable from one that found nothing more. The per-path cap is doing real work
        here rather than guarding a corner -- a change to a shared workflow script touches the root copy
        and every plugin mirror, so one shared capability arrives as three or four paths.

        THE PATHS ARE PRINTED AS THE COMPARISON SAW THEM -- repo-relative and forward-slashed. They are
        not shell-quoted, because nothing here composes a command for anybody to run: this note names
        files, it does not hand over a line to paste.
    #>
    param(
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][AllowNull()][object[]]$Findings,
        [Parameter(Mandatory = $false)][int]$MaxPrs = 5,
        [Parameter(Mandatory = $false)][int]$MaxPaths = 6
    )

    $all = @(@($Findings) | Where-Object { $_ })
    if ($all.Count -eq 0) { return '' }
    if ($MaxPrs -lt 1) { $MaxPrs = 1 }
    if ($MaxPaths -lt 1) { $MaxPaths = 1 }

    $shown = @($all | Select-Object -First $MaxPrs)
    $lines = New-Object System.Collections.Generic.List[string]
    $prWord = if ($all.Count -eq 1) { 'open PR changes' } else { 'open PRs change' }
    $lines.Add("overlap scan: $($all.Count) other $prWord a file this branch also changes --") | Out-Null

    foreach ($finding in $shown) {
        # THE HEAD REF AND THE TITLE BOTH, because they answer the two halves of the only decision this
        # note leaves open. The ref is what you check out; the title is how you tell a typo fix from a
        # refactor without spending a second gh call on it -- and the ordering question is exactly "which
        # of these two should land first". TRUNCATED, because a PR title in this house is a sentence: the
        # number is the citation and the full text is one `gh pr view` away.
        $head = if ($finding.HeadRefName) { "  ($($finding.HeadRefName))" } else { '' }
        $title = ([string]$finding.Title).Trim()
        if ($title.Length -gt 72) { $title = $title.Substring(0, 69) + '...' }
        if ($title) { $title = "  $title" }
        $lines.Add("  #$($finding.Number)$head$title") | Out-Null
        $paths = @($finding.SharedPaths)
        foreach ($path in @($paths | Select-Object -First $MaxPaths)) {
            $lines.Add("      $path") | Out-Null
        }
        if ($paths.Count -gt $MaxPaths) {
            $lines.Add("      ... and $($paths.Count - $MaxPaths) more shared path(s)") | Out-Null
        }
    }
    if ($all.Count -gt $shown.Count) {
        $lines.Add("  ... and $($all.Count - $shown.Count) more open PR(s) sharing a path") | Out-Null
    }

    $lines.Add('') | Out-Null
    $lines.Add('Whoever merges SECOND resolves. Nothing to do about it here and this is not a refusal --') | Out-Null
    $lines.Add('two branches touching one file is ordinary. What it buys is that you know now, instead of') | Out-Null
    $lines.Add("meeting it as ship-pr's '422 merge conflict between base and head' several certification") | Out-Null
    $lines.Add('laps in, with the CI those laps spent already paid for (issue #2315, measured on PR #2300).') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('The one decision available before either lands: ship them in a deliberate ORDER rather than') | Out-Null
    $lines.Add('racing them. Nothing can be merged in yet -- the PRs above are open, so their work is not on') | Out-Null
    $lines.Add('the trunk. Once one of them has landed, bring the trunk into the other before re-certifying.') | Out-Null

    return ($lines -join [Environment]::NewLine)
}
