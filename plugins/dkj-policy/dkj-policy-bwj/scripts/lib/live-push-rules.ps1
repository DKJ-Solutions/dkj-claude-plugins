<#
.SYNOPSIS
    The rules behind the LIVE PUSH's preflight: which of a release's changed files actually exist on a
    theme, which release tag the range starts at, what the push command looks like, and whether the
    checklist as a whole allows the push to be made. Pure -- no CLI, no network, no git, no seam read.

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot:

        . (Join-Path $PSScriptRoot '..\lib\live-push-rules.ps1')

    WHY IT IS A LIB OF PURE FUNCTIONS AND NOT LOGIC INSIDE live-preflight.ps1. Same split, and the same
    reason, as theme-lifecycle-rules.ps1 and preview-theme.ps1 beside it: every path in the task script
    either shells out to git, invokes the Shopify CLI against a real store, or reads a consumer's
    repo-config, and a suite must not be able to reach any of the three. What CAN be judged without a
    network lives here, where scripts/tests/live-push-rules.tests.ps1 asserts exact answers against it.

    THE SOURCE OF THE RULES IS INBOUND #2228, filed from a BWJ store on September 21, 2026. Every figure
    attributed to "the consumer" below was measured THERE, in a store this repo cannot reach -- it
    publishes plugins and has no theme estate. They are cited as that consumer's measurements rather
    than restated as facts of this tree, because the difference matters when somebody re-checks them.

    ------------------------------------------------------------------------------------------------
    WHAT THIS FILE IS FOR: THE PUSH LIST IS NOT THE CHANGELOG, AND NOTHING USED TO ENFORCE THAT.

    Between "the trunk is merged and green" and "bytes are on a live theme" there was no shared step at
    all. Everything this plugin ships sits either BEFORE the merge (push-preview, sync-main) or AFTER
    the push (backup-live-theme, archive-theme, sweep-preview-themes), so the one moment in the cycle
    where a mistake is visible to paying customers was assembled by hand, per release, from prose.

    Measured in the consumer preparing v2.44.0: the range v2.43.0..HEAD held 61 changed files, of which
    11 lived in the eight theme directories. The other 50 were scripts, tests and docs that DO NOT EXIST
    on a theme. That consumer's own CLAUDE.md warns about exactly this in words -- "de pushlijst is niet
    de changelog" -- which is what a rule looks like when nothing enforces it.

    SO THE LIST IS DERIVED AND NOT TYPED, and it is derived HERE so that it can be asserted.
    ------------------------------------------------------------------------------------------------

    AND THE SECOND HALF OF THE SAME FAILURE: THE LIST HAS TO ARRIVE AS AN ARRAY. The consumer's drift
    check takes -Only. At v2.39.0 that list reached it through `powershell -File`, which delivers every
    argument as a single string that never splits on commas -- so the script snapshotted ZERO files and
    printed a green "safe to push". The rollback artefact for that release did not exist and nothing
    said so. A caller that OWNS the list cannot make that mistake, which is the argument for this being
    a script rather than a checklist line, exactly as the verify step is backup-live-theme's.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# THE DIRECTORIES A SHOPIFY THEME HAS, IN ONE PLACE. This set is defined by the PLATFORM and not by any
# repo, which is why it is a constant here rather than a seam -- the same reasoning sync-main.ps1 stated
# beside its own copy of this list, and that copy now reads this one (issue #2228). Two definitions of
# one platform fact are free to drift, and they would drift in the direction that costs most: a list
# that has lost a directory silently drops that directory's files out of a push list, and a push list
# that is short is invisible until a customer sees the half-updated page.
#
# A repo whose theme does not sit at the repository root is out of scope for these rules rather than a
# knob nobody has asked for -- the same bound sync-main draws.
$script:ShopifyThemeDirectoryNames = @('assets', 'blocks', 'config', 'layout', 'locales', 'sections', 'snippets', 'templates')

function Get-ShopifyThemeDirectoryNames {
    <# The eight platform directories themselves, so every caller and every test reads one source. #>
    return @($script:ShopifyThemeDirectoryNames)
}

function Get-LivePushRows {
    <#
    .SYNOPSIS
        Classify a release's changed paths into the ones that belong on a live push and the ones that
        do not. Returns one row per path -- Path, Push ($true/$false), Kind, Reason -- never only the
        keepers.

    .DESCRIPTION
        EVERY PATH GETS A ROW, INCLUDING THE ONES THAT STAY BEHIND, and that is the design rather than
        verbosity. It is the same property the preview sweep's report has for the same reason: a summary
        that printed only the push list would be unfalsifiable, because the 50 files it must never push
        are exactly the rows it would not print. A reader checking this list by eye needs to see that
        scripts/, the tests and CLAUDE.md were CONSIDERED and refused, not merely absent.

        THREE VERDICTS, EACH ITS OWN REFUSAL RATHER THAN ONE RULE STRETCHED OVER SEVERAL CASES:

          theme-file        the path sits under one of the eight theme directories. It is pushed.
          not-a-theme-path  it does not. Scripts, tests, docs, CI config, the changelog: real changes,
                            with no counterpart on a theme, so pushing them is not "extra safety" --
                            the CLI has nowhere to put them.
          sync-owned        it sits under a theme directory AND its provenance is a sync branch. A sync
                            is ONE-WAY: sync-main mirrors what a third party already wrote on live INTO
                            the repo, so those bytes are on live by definition. Pushing them back is a
                            no-op on a good day and, on the day that third party has edited again since,
                            it silently reverts their work. The caller establishes provenance from git
                            and passes the set in; deciding it is not this function's job, asserting the
                            consequence is.

        THE ORDER OF THE TWO REFUSALS IS LOAD-BEARING. A path is tested for being a theme path FIRST, so
        a sync-owned path outside the theme directories is reported as what it primarily is rather than
        as a sync artefact.

        CASE. Theme directory names are lowercase on the platform, and Windows checkouts are not
        case-sensitive, so the prefix test is case-insensitive and the path is reported back exactly as
        it arrived. Reporting a normalised spelling would hand the caller a string the CLI has not been
        given, which is the class of defect Format-ThemeDeleteCommand's own header names: a documented
        command and the command that runs are the same bytes or they are not the same command.

        SEPARATORS. git reports forward slashes whatever the platform, and a caller reading paths off
        anything else may not. Both are accepted on the way in; neither is rewritten on the way out.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$ChangedPaths,
        [AllowNull()][AllowEmptyCollection()][string[]]$SyncOwnedPaths = @(),
        [AllowNull()][AllowEmptyCollection()][string[]]$ThemeDirectories = $null
    )

    # THROUGH A PIPELINE, NOT @($ThemeDirectories). Under Windows PowerShell 5.1 a [string[]] parameter
    # left at $null stays $null inside @(), and '.Count' on $null throws under a StrictMode caller --
    # measured the first time prepare-release.ps1 (which runs strict) called this with no directories.
    $dirs = @($ThemeDirectories | Where-Object { $_ })
    if ($dirs.Count -eq 0) { $dirs = Get-ShopifyThemeDirectoryNames }

    # A HASHSET FOR THE SYNC SET, KEYED ON THE NORMALISED SPELLING. A caller may have read those paths
    # from a different git command than the changed paths, so the two sides are compared on '/' with a
    # case-insensitive comparer rather than on whatever each string happens to carry.
    $syncSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in @($SyncOwnedPaths)) {
        if ($null -eq $p) { continue }
        $t = ([string]$p).Trim()
        if (-not $t) { continue }
        [void]$syncSet.Add(($t -replace '\\', '/'))
    }

    $rows = @()
    foreach ($raw in @($ChangedPaths)) {
        if ($null -eq $raw) { continue }
        $path = ([string]$raw).Trim()
        if (-not $path) { continue }
        $norm = $path -replace '\\', '/'

        $hit = ''
        foreach ($d in $dirs) {
            $name = ([string]$d).Trim().TrimEnd('/')
            if (-not $name) { continue }
            $prefix = $name + '/'
            if ($norm.Length -gt $prefix.Length -and $norm.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $hit = $name
                break
            }
        }

        if (-not $hit) {
            $rows += [pscustomobject]@{
                Path   = $path
                Push   = $false
                Kind   = 'not-a-theme-path'
                Reason = 'not under any of the eight theme directories -- it does not exist on a theme'
            }
            continue
        }

        if ($syncSet.Contains($norm)) {
            $rows += [pscustomobject]@{
                Path   = $path
                Push   = $false
                Kind   = 'sync-owned'
                Reason = "in $hit/, but a sync mirrored it FROM live -- those bytes are already there, and pushing them back can revert a third party's later edit"
            }
            continue
        }

        $rows += [pscustomobject]@{
            Path   = $path
            Push   = $true
            Kind   = 'theme-file'
            Reason = "in $hit/ -- a theme file this repo changed"
        }
    }

    return @($rows)
}

function Get-SyncMergeCommits {
    <#
    .SYNOPSIS
        Out of a range's log, the commits that name a sync branch in their subject. Returns one row per
        such commit -- Sha, FirstParent, IsMerge -- and nothing for the rest.

    .DESCRIPTION
        THE FIRST HALF OF SYNC PROVENANCE, and a lib function rather than a loop inside a script since
        #2509: live-preflight.ps1 and dkj-policy-bwj's prepare-release.ps1 both derive a push list, and
        two copies of "which commits came in through a sync" are free to disagree about which files the
        push leaves out.

        -LogLines IS `git log --format=%H%x09%P%x09%s` OUTPUT, one commit per line. The caller runs git;
        this only reads what came back.

        TWO MERGE SHAPES, BECAUSE TWO WORKFLOWS EXIST. A merge commit carries the branch name in its
        subject ('merge: sync/2026-09-20 (#123)'), and a squash merge has no merge commit at all -- there
        the single commit's own subject is what names the branch. IsMerge tells the caller which: for a
        merge, the commits it brought in are FirstParent..Sha, which only git can list; for a squash, the
        commit is the whole of it. A repo using neither shape gets no rows, and then nothing is excluded
        -- the safe direction, since a push list one file too LONG re-pushes bytes that are already right.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$LogLines,
        [string]$SyncPrefix = ''
    )

    $rows = @()
    if (-not $SyncPrefix) { return $rows }
    foreach ($line in @($LogLines)) {
        if ($null -eq $line) { continue }
        $f = ([string]$line) -split "`t", 3
        if ($f.Count -lt 3) { continue }
        if ($f[2] -notmatch [regex]::Escape($SyncPrefix)) { continue }
        $parents = @(($f[1] -split '\s+') | Where-Object { $_ })
        $rows += [pscustomobject]@{
            Sha         = $f[0].Trim()
            FirstParent = $(if ($parents.Count -ge 1) { $parents[0] } else { '' })
            IsMerge     = ($parents.Count -ge 2)
        }
    }
    return @($rows)
}

function Get-SyncOwnedPaths {
    <#
    .SYNOPSIS
        The paths a range touched ONLY through sync commits. Returns them '/'-separated.

    .DESCRIPTION
        THE SECOND HALF OF SYNC PROVENANCE (#2509, out of live-preflight.ps1 for the reason
        Get-SyncMergeCommits gives). -WalkLines is `git log --format=COMMIT%x09%H --name-only` output,
        with any quoted paths ALREADY DECODED by the caller -- this file reads no git and decodes nothing,
        so it stays dependency-free like the rest of it.

        EVERY TOUCHING COMMIT, NOT ANY. A file a sync mirrored AND this repo then changed itself is this
        repo's to push. The direction of that asymmetry is deliberate: treating it as sync-owned would
        drop a real change out of the push list silently, and a short push list is the failure nobody
        sees until a customer does.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$WalkLines,
        [AllowNull()][AllowEmptyCollection()][string[]]$SyncCommits
    )

    $sync = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in @($SyncCommits)) { if ($s) { [void]$sync.Add(([string]$s).Trim()) } }
    if ($sync.Count -eq 0) { return @() }

    $bySync = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $byUs   = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $current = ''
    foreach ($raw in @($WalkLines)) {
        if ($null -eq $raw) { continue }
        $line = ([string]$raw).Trim()
        if (-not $line) { continue }
        if ($line.StartsWith("COMMIT`t")) { $current = $line.Substring(7).Trim(); continue }
        if (-not $current) { continue }
        $p = $line -replace '\\', '/'
        if ($sync.Contains($current)) { [void]$bySync.Add($p) } else { [void]$byUs.Add($p) }
    }
    return @($bySync | Where-Object { -not $byUs.Contains($_) })
}

function Get-HighestReleaseTag {
    <#
    .SYNOPSIS
        The highest vX.Y.Z tag out of a list of tag names, compared as VERSIONS. Returns '' when the
        list holds none.

    .DESCRIPTION
        COMPARED NUMERICALLY, AND THAT IS THE WHOLE REASON THIS IS A FUNCTION. `git tag --list` sorts
        lexically, and so does PowerShell's Sort-Object on strings -- under which 'v2.9.0' is HIGHER
        than 'v2.44.0'. The consumer that filed #2228 was preparing exactly that pair: its previous
        release was v2.43.0 and the range it needed was v2.43.0..HEAD. A lexical pick would have handed
        the preflight a range starting somewhere in v2.9.x, which produces a push list that is far too
        LONG -- and a push list that is too long is the direction that overwrites live files nobody
        changed.

        A VERSION THAT DOES NOT PARSE IS IGNORED rather than sorted somewhere arbitrary: release
        candidates, date tags and a stray 'v2' are not this workflow's releases, and the honest answer
        for a repo holding only those is that there is no previous release tag.

        PRERELEASE SUFFIXES ARE NOT UNDERSTOOD, and that is stated rather than guessed at. The pattern
        is anchored on three numeric components exactly, so 'v2.44.0-rc1' does not match and does not
        win. A repo that cuts prereleases and wants them considered has a real question to answer about
        ordering, and answering it silently here would be the wrong place to answer it.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Tags
    )

    $best = ''
    $bestParts = $null
    foreach ($raw in @($Tags)) {
        if ($null -eq $raw) { continue }
        $tag = ([string]$raw).Trim()
        if ($tag -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { continue }
        $parts = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
        if ($null -eq $bestParts) { $best = $tag; $bestParts = $parts; continue }
        for ($i = 0; $i -lt 3; $i++) {
            if ($parts[$i] -gt $bestParts[$i]) { $best = $tag; $bestParts = $parts; break }
            if ($parts[$i] -lt $bestParts[$i]) { break }
        }
    }
    return $best
}

function Format-LivePushCommand {
    <#
    .SYNOPSIS
        The `shopify theme push` command for a derived push list -- WITHOUT the authorisation marker.

    .DESCRIPTION
        THE MISSING MARKER IS THE FEATURE, NOT AN OVERSIGHT, and it is one of the two boundaries #2228
        asked to have stated in the script's own docstring. A green preflight means THE CHECKLIST IS
        COMPLETE AND THE PUSH IS ALLOWED TO BE MADE. It never means the push is authorised. The marker
        is what authorises it, it authorises ONE command visibly in the transcript, and it stays a human
        act -- so a command printed with the marker already on it would convert a report into a standing
        authorisation, which is the exact property this plugin's live guard exists to hold.

        Whoever runs the push adds their own marker as a shell comment to this command, the way
        guard-live-theme.ps1's header documents it. A caller that wants to explain that final shape
        prints the guidance beside the command; it does not get it from here.

        ONE --only PER FILE. The plugin's README spells the single-file live push as
        `... --theme <live id> --only assets/x.css --allow-live`, and this is that spelling repeated --
        which is also the shape that cannot be flattened into one comma-joined string on its way through
        a process boundary. That flattening is the measured second half of #2228: the drift check
        received its list as a single argument, split nothing, snapshotted zero files, and reported
        green.

        EMPTY IS EMPTY. With no files this returns '' rather than a command with no --only, because a
        `theme push` without one pushes the WHOLE theme -- the single most destructive thing this file
        could ever produce by accident. A caller with an empty list has nothing to push and is told so
        by the verdict; it is never handed a command.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [AllowNull()][AllowEmptyCollection()][string[]]$Only
    )

    $files = @(@($Only) | ForEach-Object { if ($null -ne $_) { ([string]$_).Trim() } } | Where-Object { $_ })
    if ($files.Count -eq 0) { return '' }

    $parts = @('shopify', 'theme', 'push', '--store', $Store, '--theme', $ThemeId)
    foreach ($f in $files) { $parts += @('--only', $f) }
    $parts += '--allow-live'
    return ($parts -join ' ')
}

function Get-LivePreflightVerdict {
    <#
    .SYNOPSIS
        Fold a run's step results into one answer: may the push be made? Returns Allowed, Refusals,
        Skipped, Warnings, Passed and a one-line Summary.

    .DESCRIPTION
        FOUR STATES PER STEP, AND THE ASYMMETRY BETWEEN THEM IS THE DESIGN:

          pass    the step measured something and it was right.
          refuse  the step measured something and it was wrong. ANY refusal makes the whole run refuse,
                  and a later pass never cancels an earlier refusal.
          skip    the step could not measure, because the repo has not answered the seam it needs. This
                  is NOT a pass. A checklist that reported green while a step sat inert is the failure
                  the drift check's own green "safe to push" already demonstrated, on this exact
                  procedure, with nothing said.
          warn    the step measured something that is legal and worth saying out loud.

        A SKIP DOES NOT REFUSE, AND IT DOES NOT DISAPPEAR EITHER. Refusing on an unanswered seam would
        make a plugin update break a repo that never adopted the optional half; hiding it would let a
        repo believe a step ran. So it is carried into the summary by name and the caller prints it --
        the same treatment sync-main gives an unanswered sync log, one script over.

        ALLOWED IS ABOUT THE CHECKLIST AND NOT ABOUT THE PUSH. Read it as "nothing in this run says
        don't", never as "go" -- the marker is what says go, and no code writes it.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()]$Steps
    )

    $refusals = @()
    $skipped  = @()
    $warnings = @()
    $passed   = 0

    foreach ($s in @($Steps)) {
        if ($null -eq $s) { continue }
        # PSObject.Properties AND NOT A BARE READ, the same guard Test-ReleaseBumpEarned puts on its own
        # caller-built input: a step assembled by hand without one of these fields must not make this
        # throw under a strict caller, and must not read as a silent pass either.
        $name  = ''
        $state = ''
        $why   = ''
        if ($s.PSObject.Properties['Name'])   { $name  = [string]$s.Name }
        if ($s.PSObject.Properties['State'])  { $state = ([string]$s.State).Trim().ToLower() }
        if ($s.PSObject.Properties['Detail']) { $why   = [string]$s.Detail }
        if (-not $name) { $name = '(unnamed step)' }

        switch ($state) {
            'pass'   { $passed++ }
            'refuse' { $refusals += [pscustomobject]@{ Name = $name; Detail = $why } }
            'skip'   { $skipped  += [pscustomobject]@{ Name = $name; Detail = $why } }
            'warn'   { $warnings += [pscustomobject]@{ Name = $name; Detail = $why } }
            default  {
                # AN UNREADABLE STATE IS A REFUSAL, never a pass. A caller that mistyped a state has not
                # measured anything, and the safe direction on a live push is to stop.
                $refusals += [pscustomobject]@{ Name = $name; Detail = "reported an unrecognised state '$state' -- nothing was measured, so this run refuses rather than guessing" }
            }
        }
    }

    $allowed = ($refusals.Count -eq 0)
    if ($allowed) {
        $summary = "$passed step(s) passed"
        if ($skipped.Count -gt 0)  { $summary += ", $($skipped.Count) could not be measured" }
        if ($warnings.Count -gt 0) { $summary += ", $($warnings.Count) worth reading" }
        $summary += ' -- nothing here says do not push. The marker is still a human act.'
    } else {
        $summary = "$($refusals.Count) step(s) refused -- the push is not allowed to be made yet."
    }

    return [pscustomobject]@{
        Allowed  = $allowed
        Refusals = @($refusals)
        Skipped  = @($skipped)
        Warnings = @($warnings)
        Passed   = $passed
        Summary  = $summary
    }
}
