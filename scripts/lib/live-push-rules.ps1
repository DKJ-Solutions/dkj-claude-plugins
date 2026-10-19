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

        FOUR VERDICTS, EACH ITS OWN REFUSAL RATHER THAN ONE RULE STRETCHED OVER SEVERAL CASES:

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
          deleted           it sits under a theme directory AND the range deletes it (#2566). It is not a
                            row of the ordinary push, and the reason is visibility rather than capability:
                            `--only <path>` on a file that is NOT in the checkout DELETES that file on
                            the theme (#2641). The CLI's delete set is the remote files, filtered by the
                            same --only/--ignore filters, minus the local ones, skipped only under
                            --nodelete -- read in @shopify/cli 4.8.2, and its --nodelete help says the
                            same. So a deletion IS a push, one that destroys what live holds at that
                            path, and the caller composes it as its own, separately named command rather
                            than folding it into the list a person reads as "files to upload". Measured
                            in a BWJ store: 209 deletions in one range, every theme one of them listed
                            as `push` (#2566); #2566 then read them as uncarriable, which was the wrong
                            half of the same fact.

        THE ORDER OF THE REFUSALS IS LOAD-BEARING. A path is tested for being a theme path FIRST, so a
        sync-owned path outside the theme directories is reported as what it primarily is rather than
        as a sync artefact. Sync provenance is tested BEFORE deletion: a deletion a sync mirrored in came
        FROM live, so the file is already gone there, and "still on live" would be false.

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
        [AllowNull()][AllowEmptyCollection()][string[]]$ThemeDirectories = $null,
        [AllowNull()][AllowEmptyCollection()][string[]]$DeletedPaths = @()
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
    # The deleted set is keyed the same way, for the same reason.
    $deletedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in @($DeletedPaths)) {
        if ($null -eq $p) { continue }
        $t = ([string]$p).Trim()
        if (-not $t) { continue }
        [void]$deletedSet.Add(($t -replace '\\', '/'))
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

        if ($deletedSet.Contains($norm)) {
            $rows += [pscustomobject]@{
                Path   = $path
                Push   = $false
                Kind   = 'deleted'
                Reason = "in $hit/, but DELETED on the trunk -- an --only push of it REMOVES it from live, so it is its own, separately named deletion command rather than a row of the push"
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
        #2509: live-preflight.ps1 and bwj-development's prepare-release.ps1 both derive a push list, and
        two copies of "which commits came in through a sync" are free to disagree about which files the
        push leaves out.

        -LogLines IS `git log --first-parent --format=%H%x09%P%x09%s` OUTPUT, one commit per line. The
        caller runs git; this only reads what came back.

        --first-parent IS NOT OPTIONAL (#2912, BWJ-Development/xoxowildhearts, October 12, 2026). A
        trunk-into-sync merge ("Merge branch 'main' into sync/live-2026-10-05") names the sync branch in
        its subject too, and without the flag it was read as a head: its FirstParent..Sha is the TRUNK's
        work it brought over, so our own feature commits were counted as a sync's and their paths --
        theme.css halved in #358 among them -- dropped out of the push list as sync-owned. On the
        trunk's own line only the merge that brought the sync IN appears, and that is the one a head is.

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

# THE TWO SUBJECTS sync-main's -ReconcileBase writes, defined here so the writer and the readers below
# share one spelling (#3145). A reader matching a copy of these strings would go silently blind the day
# the writer's wording changed, and blind is the direction that pushes over a third party's work.
$script:ReconciliationBaseSubject    = 'sync: live verbatim as the reconciliation base'
$script:ReconciliationRestoreSubject = 'fix: put the trunk content back over the reconciliation base'

function Get-ReconciliationBaseSubjects {
    <# The subject prefixes of the base commit and the restore commit, in that order. #>
    return [pscustomobject]@{ Base = $script:ReconciliationBaseSubject; Restore = $script:ReconciliationRestoreSubject }
}

function Get-ReconciliationOwedPaths {
    <#
    .SYNOPSIS
        Out of a push list, the paths whose newest commit is a reconciliation base that nobody has
        reconciled since. Returns them in input order, exactly as they arrived; empty means none is owed.

    .DESCRIPTION
        INBOUND #3145, measured in a BWJ store (smartwatchbanden#958). -ReconcileBase puts live's exact
        bytes into a conflicted path's history and the trunk's straight back on top, which is what makes
        the path durable. But it also makes live's content "a version this repo has held before" -- the
        very test the drift check and sync-main's keep-trunk verdict use to call live harmless. So from
        that merge on, every reader reads the path as safe while the trunk still LACKS live's third-party
        content: there it would have reverted a raised free-shipping threshold and a noindex. The one step
        between that merge and the revert is the content reconciliation sync-main leaves to a person, and
        until this function nothing checked that it had happened.

        THE QUESTION IS PROVENANCE AGAIN, NOT CONTENT. A path is owed while the NEWEST non-merge commit in
        the walk that touched it is the base or the restore commit: nothing has changed the path since the
        base was written, so the reconciliation has not been done. Any later commit that changes the path
        settles it, in any spelling -- the same promise sync-main's finish text makes. A person who decides
        the trunk is right and live's edit should go has no commit to make, which is why the caller turns
        this into a refusal a switch can accept rather than into something only a commit can clear.

        -WalkLines IS `git log --no-merges --topo-order --format=COMMIT%x09%H%x09%s --name-only` OUTPUT over
        the range, NEWEST FIRST, quoted paths already decoded. --topo-order because "newest" here means
        "descends from", and a commit-date order can put a parent above its child on a skewed clock.
        --no-merges because a merge of the base branch touches nothing the walk needs: its commits are
        listed themselves. The caller runs git; this reads what came back, like Get-SyncOwnedPaths above.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$WalkLines,
        [AllowNull()][AllowEmptyCollection()][string[]]$Paths
    )

    # THE FIRST COMMIT EACH PATH IS SEEN UNDER IS ITS NEWEST, and whether that one was a base commit is the
    # whole answer -- so the walk records a verdict per path once and never overwrites it.
    $newestIsBase = New-Object 'System.Collections.Generic.Dictionary[string,bool]' ([System.StringComparer]::OrdinalIgnoreCase)
    $currentIsBase = $false
    $inCommit = $false
    foreach ($raw in @($WalkLines)) {
        if ($null -eq $raw) { continue }
        $line = ([string]$raw).Trim()
        if (-not $line) { continue }
        if ($line.StartsWith("COMMIT`t")) {
            $f = $line -split "`t", 3
            $subject = if ($f.Count -ge 3) { $f[2] } else { '' }
            $currentIsBase = $subject.StartsWith($script:ReconciliationBaseSubject, [System.StringComparison]::Ordinal) -or
                             $subject.StartsWith($script:ReconciliationRestoreSubject, [System.StringComparison]::Ordinal)
            $inCommit = $true
            continue
        }
        if (-not $inCommit) { continue }
        $p = $line -replace '\\', '/'
        if (-not $newestIsBase.ContainsKey($p)) { $newestIsBase[$p] = $currentIsBase }
    }

    $owed = @()
    foreach ($raw in @($Paths)) {
        if ($null -eq $raw) { continue }
        $t = ([string]$raw).Trim()
        if (-not $t) { continue }
        $norm = $t -replace '\\', '/'
        if ($newestIsBase.ContainsKey($norm) -and $newestIsBase[$norm]) { $owed += $t }
    }
    # Unwrapped on purpose, as Get-LivePushUnsafePaths below: every caller takes this as @(...).
    return $owed
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

# What a theme path may contain before it is printed inside a command a person pastes (#2514). The ref
# pattern of ref-print-lib.ps1 (letters, digits, '.', '_', '/', '-', first character alphanumeric) PLUS
# the Latin letters of U+00C0-U+017E, the multiplication and division signs excepted. Written as regex
# escapes so this file stays ASCII. The reasoning is in Get-LivePushUnsafePaths' docstring.
$script:LivePushPathPattern = '^[A-Za-z0-9\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u017E][A-Za-z0-9\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u017E._/-]*$'

function Get-LivePushUnsafePaths {
    <#
    .SYNOPSIS
        The paths of a push list that may NOT be printed inside the push command, in input order.
        Empty means every path is safe to paste.

    .DESCRIPTION
        THE PUSH COMMAND IS PRINTED FOR A PERSON TO PASTE, SO EVERY PATH IN IT IS TEXT A SHELL WILL
        PARSE (#2514). The paths come from `git diff --name-only`, and a theme file reaches the repo
        through a sync branch from the theme editor, so planting a name needs no push rights at all.
        Measured on the function extracted verbatim: `assets/$(calc.exe).css` is printed as-is and
        PowerShell evaluates the subexpression when the pasted line runs; a bare `;` splits the line
        into two statements; an embedded newline splits the printed command itself. git's own quoting
        never fires for these -- core.quotePath escapes only bytes above 0x7F, `"`, `\` and control
        characters -- and #1594 measured that quoting does not close the class anyway. Refusing to
        print the path does.

        WHY NOT Test-PathPasteSafe ITSELF. That pattern is ASCII only, and a theme filename with an
        accent is not hypothetical: #821 measured one in a consumer store, through sync-main. An
        ASCII-only check would refuse that store's live push for as long as the file is in the range,
        with nothing the operator could do short of renaming a file the theme editor created. So this
        admits the Latin letters of U+00C0-U+017E on top of the ref pattern's set. No letter is special
        to PowerShell, bash or cmd, so admitting them opens nothing that executes. The range stops
        inside Latin Extended-A on purpose, because a command a person reads before pasting must read
        as what it does: its last letter, U+017F LONG S, reads as an `f`, and past it are letters that
        DISPLAY as punctuation (U+01C0-U+01C3 read as `|` and `!`) and scripts that reorder a line. A decomposed accent (a letter plus a combining mark) is
        refused, which is the fail-safe direction. The match is case-SENSITIVE (-cmatch) so the
        Kelvin sign cannot pass as a `k` under case folding.

        NOT A DISPLAY GUARD. It decides what may go into a command; how a refused path is NAMED to the
        reader is the caller's concern.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Paths
    )

    $unsafe = @()
    foreach ($p in @($Paths)) {
        if ($null -eq $p) { continue }
        $t = ([string]$p).Trim()
        if (-not $t) { continue }
        if ($t -cnotmatch $script:LivePushPathPattern) { $unsafe += $t }
    }
    # Unwrapped on purpose: every caller takes this as @(...), and ', $unsafe' would hand an empty
    # result back as ONE item -- an empty array -- that @() then counts.
    return $unsafe
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

        IT COMPOSES THE DELETION COMMAND TOO (#2641), handed the trunk-deleted paths instead of the
        push list. Run from the trunk, where those files are absent, the same `--only` spelling removes
        them from live, so a second builder would only be a second copy of the paste and marker rules.

        A PATH THAT IS NOT SAFE TO PASTE IS A THROW, NOT A COMMAND (#2514). The check a caller should
        run first is Get-LivePushUnsafePaths, which lets it refuse with the paths named; this throw is
        the backstop that holds for a caller that did not, so no caller can print a command that runs
        something other than the push. The message carries a count, never the paths, because a path
        that failed the check is exactly the text that must not reach a console unguarded.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [AllowNull()][AllowEmptyCollection()][string[]]$Only
    )

    $files = @(@($Only) | ForEach-Object { if ($null -ne $_) { ([string]$_).Trim() } } | Where-Object { $_ })
    if ($files.Count -eq 0) { return '' }

    $unsafe = @(Get-LivePushUnsafePaths -Paths $files)
    if ($unsafe.Count -gt 0) {
        throw "Format-LivePushCommand: $($unsafe.Count) path(s) are not safe to paste into a command; run Get-LivePushUnsafePaths first and refuse with them named."
    }

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

# ---------------------------------------------------------------------------------------------------
# THE GIT-CONNECTED LIVE THEME (#2998, #3008). A second deploy mode beside the CLI push: the live theme is
# connected through Shopify's GitHub integration to a protected DEPLOY BRANCH, going live is a merge of
# the trunk into it, and Shopify's own bot commits editor and app saves straight onto it. The two
# functions below are the rules of that mode that can be judged without git; the caller measures, these
# decide. Measured in BWJ-Development/smartwatchbanden#943 (October 14, 2026), the consumer that asked:
# the deploy branch's ruleset carries a pull_request rule, so the promotion is a PULL REQUEST, never a
# push -- and the Shopify GitHub app needs an Always-allow bypass on that ruleset for its write-back.

# A branch name this file prints inside a command a person pastes. The same character set as
# ref-print-lib.ps1's ref pattern, restated because this file is dependency-free by registration.
# \A...\z AND -cmatch, BOTH MEASURED IN REVIEW (#3008): .NET's '$' also matches before a final newline,
# so 'live<LF>' passed and printed a two-line command; and a case-insensitive match lets the Kelvin sign
# (U+212A) satisfy [A-Za-z]. Live-record-lib's Test-LiveRecordPromotionValue holds the same pattern, and
# a test holds the two to the same answers.
$script:LivePromotionRefPattern = '\A[A-Za-z0-9][A-Za-z0-9._/-]*\z'

function Test-LivePromotionRef {
    <# Whether a branch name is safe to print in a pasted command: the ref pattern, and no '..'. #>
    param([AllowNull()][string]$Name)
    $n = [string]$Name
    return ([bool]($n -cmatch $script:LivePromotionRefPattern) -and ($n -notmatch '\.\.'))
}

function Get-LivePromotionStep {
    <#
    .SYNOPSIS
        The promotion step of a Git-connected live preflight, as a step Get-LivePreflightVerdict folds:
        { Name = 'promotion'; State = 'pass' | 'refuse'; Detail }.

    .DESCRIPTION
        TWO PATH LISTS, BECAUSE TWO DIFFERENT QUESTIONS ARE ASKED AND COMMIT COUNTS ANSWER NEITHER.

          -BackflowPaths   `git diff --name-only <trunk>...<deploy>` (THREE dots): what the deploy branch
                           changed since it last met the trunk. These are the Shopify bot's saves, which
                           are live and not yet on the trunk. Non-empty means a back-flow PR (deploy into
                           trunk) is owed before anything is promoted: the cut that follows a promotion
                           describes the trunk, and while the trunk lacks what live holds, the tag would
                           describe a theme that is not the live one.
          -PromotionPaths  `git diff --name-only <deploy> <trunk>` (TWO dots, tree against tree): exactly
                           the paths the promotion merge carries. Empty means there is nothing to promote.

        WHY NOT `git rev-list --count`. A promotion PR merges with a merge commit, and that commit sits
        on the deploy branch and nowhere else, so `trunk..deploy` is never empty again after the first
        promotion. Counting it as owed back-flow would refuse every release after the first. The
        three-dot diff measures content, and a merge commit that changed nothing has no paths.
        Symmetrically, a back-flow merge leaves a commit on the trunk alone, so `deploy..trunk` can
        hold commits while the trees are identical; the two-dot tree diff does not count them.

        THE ORDER OF THE REFUSALS. An unsafe branch name first, since every later sentence would print
        it. The owed back-flow before the empty promotion, because it is the one with something to do.
    #>
    param(
        [Parameter(Mandatory)][string]$Trunk,
        [Parameter(Mandatory)][string]$DeployBranch,
        [AllowNull()][AllowEmptyCollection()][string[]]$PromotionPaths = @(),
        [AllowNull()][AllowEmptyCollection()][string[]]$BackflowPaths = @()
    )
    $name = 'promotion'
    if (-not (Test-LivePromotionRef $Trunk) -or -not (Test-LivePromotionRef $DeployBranch)) {
        return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = 'the trunk or the deploy branch has a name that is not safe to print in a command, so no promotion is composed' }
    }
    if ($Trunk -ieq $DeployBranch) {
        return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = "the deploy branch is the trunk itself ('$Trunk'), so there is nothing to promote between them -- the deploy-branch seam should name the branch the live theme is connected to" }
    }
    $back = @(@($BackflowPaths) | Where-Object { $_ -and ([string]$_).Trim() })
    $prom = @(@($PromotionPaths) | Where-Object { $_ -and ([string]$_).Trim() })
    if ($back.Count -gt 0) {
        return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = "$DeployBranch holds $($back.Count) changed path(s) that are not on $Trunk yet (live edits) -- land the back-flow PR ($DeployBranch into $Trunk, sync-main) first" }
    }
    if ($prom.Count -eq 0) {
        return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = "$DeployBranch and $Trunk hold the same tree -- there is nothing to promote" }
    }
    return [pscustomobject]@{ Name = $name; State = 'pass'; Detail = "the promotion carries $($prom.Count) path(s) from $Trunk to $DeployBranch" }
}

function Format-LivePromotionCommand {
    <#
    .SYNOPSIS
        The `gh pr create` command that opens the promotion PR (trunk into the deploy branch). Never run.

    .DESCRIPTION
        A PULL REQUEST AND NOT `git push origin <trunk>:<deploy>`, because the consumer's deploy ruleset
        requires one (#943), and a direct push is rejected there. It is printed for the same reason
        Format-LivePushCommand prints rather than runs: a green preflight says the checklist is complete,
        never that going live is authorised, and the merge of this PR is that act.

        THE TITLE IS BUILT HERE FROM VALIDATED PARTS ONLY -- the two branch names under the ref pattern and
        a version of ASCII digits X.Y.Z -- so the double quotes around it hold in PowerShell, bash and cmd
        alike: nothing inside them can be a quote, a '$' or a backtick. An unsafe name is a throw, the
        backstop Format-LivePushCommand keeps; a caller should refuse through Get-LivePromotionStep first.
    #>
    param(
        [Parameter(Mandatory)][string]$Trunk,
        [Parameter(Mandatory)][string]$DeployBranch,
        [string]$Version = ''
    )
    if (-not (Test-LivePromotionRef $Trunk) -or -not (Test-LivePromotionRef $DeployBranch)) {
        throw 'Format-LivePromotionCommand: a branch name is not safe to paste into a command; refuse through Get-LivePromotionStep first.'
    }
    $v = ([string]$Version).Trim().TrimStart('v')
    # [0-9] and not \d: .NET's \d is every Unicode decimal digit, so U+0663 passed in review.
    if ($v -and $v -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') {
        throw 'Format-LivePromotionCommand: the version is not X.Y.Z, so it is not printed.'
    }
    $title = "promote: $Trunk to $DeployBranch" + $(if ($v) { " for v$v" } else { '' })
    return "gh pr create --base $DeployBranch --head $Trunk --title `"$title`" --body `"Promotes $Trunk to the live theme's deploy branch.`""
}

function Get-LiveWriteBackStep {
    <#
    .SYNOPSIS
        The write-back step of a Git-connected live preflight (#3009), as a step Get-LivePreflightVerdict
        folds: { Name = 'write-back'; State = 'pass' | 'refuse' | 'warn' | 'skip'; Detail }.

    .DESCRIPTION
        A REJECTED WRITE-BACK IS INVISIBLE ON THE SHOPIFY SIDE (measured in
        BWJ-Development/smartwatchbanden#943): when the deploy branch's ruleset refuses the Shopify bot's
        commit, the edit stays on the live theme and never reaches the branch, and only GitHub's rule-suite
        log records it. A promotion merged on top would then overwrite that edit with nobody told. So the
        caller reads the log (`rulesets/rule-suites?ref=refs/heads/<deploy>&rule_suite_result=fail`) and
        hands the suites in, with -Since set to the last promotion; this decides.

        EVERY FAILED SUITE COUNTS, NOT ONLY THE BOT'S. The bot's actor name is not something this repo has
        measured, and a filter on a guessed name is the one way to read a real rejection as none. A
        person's rejected push is cheap to recognise in the detail and wave through with -Accepted, which
        is the switch a person sets after reconciling, never a default.

        UNREADABLE IS A SKIP, NOT A PASS: the log needs admin access to the repo, which plenty of tokens
        lack, and a skip is named in the verdict's summary where a pass would vanish.

        THE ACTOR AND TIME ARE TEXT FROM THE API, printed for a person to read, so each is cut down to a
        plain character set first. This file is dependency-free, so it does not borrow check-report-lib.
    #>
    param(
        [Parameter(Mandatory)][string]$DeployBranch,
        [AllowNull()][AllowEmptyCollection()][object[]]$RuleSuites = @(),
        [switch]$Unreadable,
        [switch]$Accepted,
        [string]$Window = 'month',
        [AllowNull()][Nullable[datetime]]$Since = $null
    )
    $name = 'write-back'
    # The name is printed in every detail below, so it is held to the ref pattern here, not only by the caller.
    if (-not (Test-LivePromotionRef $DeployBranch)) {
        return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = 'the deploy branch has a name that is not safe to print, so its rule-suite log was not judged' }
    }
    if ($Unreadable) {
        return [pscustomobject]@{ Name = $name; State = 'skip'; Detail = "the rule-suite log of $DeployBranch could not be read (it needs admin access to the repo), so a rejected Shopify write-back -- visible only there -- is unverified" }
    }
    $failed = @(@($RuleSuites) | Where-Object { $_ -and ([string]$_.result).Trim() -ieq 'fail' })
    # -Since IS THE LAST PROMOTION (#3009's review): a rejection before it was there for the previous
    # preflight to refuse on, and counting it again would keep refusing until the window let go. A
    # pushed_at that does not parse is KEPT -- dropping it would read an unknown time as an old one.
    $scope = "the last $Window"
    if ($null -ne $Since) {
        # A CAST, NOT .Value: PowerShell unwraps a Nullable parameter to the plain [datetime].
        $cut = ([datetime]$Since).ToUniversalTime()
        $failed = @($failed | Where-Object {
            $t = [datetime]::MinValue
            $ok = [datetime]::TryParse([string]$_.pushed_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$t)
            (-not $ok) -or ($t -gt $cut)
        })
        $scope = 'the time since the last promotion'
    }
    if ($failed.Count -eq 0) {
        return [pscustomobject]@{ Name = $name; State = 'pass'; Detail = "the rule-suite log holds no rejected push to $DeployBranch in $scope" }
    }
    $named = @($failed | Select-Object -First 3 | ForEach-Object {
        $actor = ([string]$_.actor_name) -replace '[^A-Za-z0-9\[\]_.-]', '?'
        if ($actor.Length -gt 40) { $actor = $actor.Substring(0, 40) + '...' }
        $at    = ([string]$_.pushed_at) -replace '[^0-9A-Za-z:.+-]', '?'
        "$actor at $at"
    }) -join ', '
    $more = if ($failed.Count -gt 3) { ", and $($failed.Count - 3) more" } else { '' }
    $what = "$($failed.Count) push(es) to $DeployBranch were rejected by a ruleset in ${scope}: $named$more"
    if ($Accepted) {
        return [pscustomobject]@{ Name = $name; State = 'warn'; Detail = "$what -- accepted for this run (-AcceptRejectedWriteBacks)" }
    }
    return [pscustomobject]@{ Name = $name; State = 'refuse'; Detail = "$what. A rejected Shopify write-back leaves an edit on live that $DeployBranch does not hold, and the promotion would overwrite it. Reconcile it, then run again with -AcceptRejectedWriteBacks" }
}

# ---------------------------------------------------------------------------------------------------
# THE APP DEPLOY (#3174). A store repo can ship a Shopify APP beside its theme -- a discount function,
# checkout UI blocks -- under a root it names with Get-ShopifyAppRoot. Measured in BWJ-Development/
# smartwatchbanden (October 19, 2026): those files live under extensions/, Get-LivePushRows rightly holds
# them back as not-a-theme-path, and neither a theme push nor a promotion carries them. They reach the
# store only through `shopify app deploy` run against that root, and no release-day step printed it, so
# a merged extensions/ change (smartwatchbanden#978) had no route live. The three functions below list
# those files and print the command. Nothing here runs it: an app deploy is outward-facing exactly as a
# live push is, so it is a person's act.

function Test-ShopifyAppRoot {
    <#
        Whether -AppRoot may be printed inside a command a person pastes: a RELATIVE path of the ref
        characters only (Test-LivePromotionRef's pattern), with no empty, '.' or '..' segment. The answer
        comes from the consumer's repo-config.ps1, so it is text nobody in this repo typed -- the same
        reason the push list's paths are checked before they are printed (#2514).
    #>
    param([AllowNull()][AllowEmptyString()][string]$AppRoot)
    $r = (([string]$AppRoot).Trim() -replace '\\', '/').TrimEnd('/')
    if (-not $r) { return $false }
    if ($r -cnotmatch $script:LivePromotionRefPattern) { return $false }
    foreach ($seg in ($r -split '/')) { if (-not $seg -or $seg -eq '.' -or $seg -eq '..') { return $false } }
    return $true
}

function Get-ShopifyAppDeployPaths {
    <#
        The changed paths that sit under -AppRoot, in input order and exactly as they arrived. Empty
        where the root is unset or not printable (Test-ShopifyAppRoot), so a repo with no app sees
        nothing. Case-insensitive and either separator, the same treatment Get-LivePushRows gives the
        theme directories. A path equal to the root itself is not under it.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$ChangedPaths,
        [AllowNull()][AllowEmptyString()][string]$AppRoot
    )
    if (-not (Test-ShopifyAppRoot -AppRoot $AppRoot)) { return @() }
    $prefix = ((([string]$AppRoot).Trim() -replace '\\', '/').TrimEnd('/')) + '/'
    $out = @()
    foreach ($p in @($ChangedPaths)) {
        if ($null -eq $p) { continue }
        $t = ([string]$p).Trim()
        if (-not $t) { continue }
        if (($t -replace '\\', '/').StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { $out += $t }
    }
    # Unwrapped, as Get-LivePushUnsafePaths: every caller takes this as @(...).
    return $out
}

function Format-ShopifyAppDeployCommand {
    <#
        The `shopify app deploy` command for -AppRoot, for a person to run. It names the root with --path
        so it runs from the repo root, where every other release-day command is run. A root that is not
        printable is a throw, the backstop Format-LivePushCommand keeps for an unsafe path: a caller
        checks Test-ShopifyAppRoot first and reports instead.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$AppRoot)
    if (-not (Test-ShopifyAppRoot -AppRoot $AppRoot)) {
        throw 'Format-ShopifyAppDeployCommand: the app root is not safe to print in a command; check it with Test-ShopifyAppRoot first.'
    }
    $r = (([string]$AppRoot).Trim() -replace '\\', '/').TrimEnd('/')
    return "shopify app deploy --path $r"
}
