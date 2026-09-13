<#
.SYNOPSIS
    The decisions scripts/task/archive-theme.ps1 rests on. Dot-sourced, never run.

.DESCRIPTION
    WHY IT SHIPS HERE (issue #1886 candidate 4). Both BWJ stores had built a theme archive, and
    neither could find the other's: smartwatchbanden called it
    scripts/theme/archive-and-remove-theme.ps1 and xoxowildhearts called it
    scripts/theme/archive-theme.ps1. Only one exported name matched -- Get-ThemeListJson -- which is
    why the sibling check reported them as ALIASED and no grep in either repo would ever have found
    the other.

    IT IS dkj-subagents-shopify AND NOT dkj-policy-bwj, WHICH IS A DEPARTURE FROM THE #1881 RULING'S
    DEFAULT AND NOT FROM ITS REASONING. That ruling sends what the two stores share to dkj-policy-bwj
    unless it is obviously universal, and its test for the exception is a demonstrated reader outside
    the two stores. This bullet does not need that test, because the ruling's axis is the wrong axis
    for it: archiving a theme is not a BWJ practice, it is a Shopify one. The plugin that owns the
    live theme already owns every mechanism around it -- push-preview, sync-main, preview-theme,
    sync-rules, shopify-cli-lib and the live-theme guard this file's refusals are shaped by -- and two
    of those ship with exactly the same two readers. The precedent is the plugin's SUBJECT, not its
    reader count.

    THE SPLIT IS sync-rules.ps1's, AND FOR THE SAME REASON: the script around these functions is all
    Shopify CLI, which a test cannot reach, while the parts that can actually be WRONG are pure
    functions over a name, a role, a path and a text. Those live here so
    scripts/tests/theme-archive-rules.tests.ps1 can measure them.

    DEPENDENCY-FREE, and specifically NOT a reader of scripts/repo-config.ps1 -- the same rule
    sync-rules.ps1 states for itself. The live-theme guard dot-sources that file on every command
    inside a catch that returns no live theme id, so anything a lib in this plugin pulls in is a way
    to silently disarm the guard. Every seam answer is read by the script and passed in here as a
    parameter.

    THE FOUR THAT STOP THE SCRIPT DOING SOMETHING WRONG:

      1. Expand-ThemeIdList      -- what did the caller actually ask for? '-File' does not parse
         PowerShell, so a comma-separated list arrives as one string.
      2. Get-ThemeArchiveVerdict -- may this theme be archived at all? The live theme may not, and the
         check is doubled on purpose (see the function).
      3. Get-ArchiveFolderName   -- what is this theme called on disk? Real theme names are not
         filesystem-safe, and the failure is silent on Windows rather than loud.
      4. Test-ThemeArchive       -- did the pull actually land a theme? A half-finished pull leaves a
         directory that exists, which is why "does the folder exist" is not the question.

    All four were found by USING the script in a store, not by reading it. The comma one in particular
    reported success while doing nothing.

    THE SIX THAT MAKE THE SCRIPT LEAVE A RECORD are a different kind. Get-ArchiveManifestFileName,
    Get-ThemeArchiveFileRecords, Get-ThemeArchiveContentDigest, Get-ThemeArchiveEvents,
    Merge-ThemeArchiveEvent and Format-ThemeArchiveManifest answer a failure the script cannot commit
    at all: theme-archive/ is gitignored, so a correct archive stops being evidence the moment the
    machine holding it is not the machine asking. Their own banner below says why the answer was a
    receipt rather than durable bytes, and why the receipt is a LOG rather than a snapshot -- the first
    shape rewrote the one field the whole mechanism existed to record.

    THE TWO THAT ARE ABOUT SOMETHING OUTSIDE THE SCRIPT. Format-ThemeDeleteCommand renders the command
    the script's last line prints, and Get-ExternalThemeWarning decides whether a warning belongs above
    it. The first is a function rather than a format string because all three defects of the format
    string it replaced survived a repair pass over the very file they lived in. The second is this
    convergence's own addition, and the one place where NEITHER store's copy was right (see it).

    THE THREE THAT READ A RECEIPT BACK -- Get-ThemeArchiveManifestField,
    Get-ThemeArchiveManifestFileRecords and Compare-ThemeArchiveWithManifest -- have no caller in this
    plugin. They are here because they are part of this file, and a consumer that has written a
    verifier against them dot-sources this lib rather than keeping a copy. See the banner above them.

    Pure ASCII (repo convention for .ps1).
#>

function Expand-ThemeIdList {
    <#
    .SYNOPSIS
        Flatten whatever reached -ThemeId into a clean list of ids.

    .DESCRIPTION
        THIS EXISTS BECAUSE THE SCRIPT IS RUN WITH -File, AND -File DOES NOT PARSE POWERSHELL. Measured
        in a store on August 21, 2026: 'powershell -File archive-theme.ps1 -ThemeId 183398957397,184636047701'
        hands the [string[]] parameter ONE element -- the literal text '183398957397,184636047701' --
        because -File splits its arguments on whitespace and never evaluates them as an expression.
        Under -Command the same text becomes three elements. So a [string[]] parameter that does not
        split commas itself works in one invocation style and silently fails in the other.

        And the failure was silent in the worst way: the whole comma-joined string was looked up as a
        single theme id, was not found, and the run reported "Skipped: 1" as if one theme had been
        refused rather than six never attempted. Every gate in this workflow is invoked with -File, so
        -File is the style these repos actually use -- the parameter has to work there.
    #>
    param([AllowNull()][string[]]$ThemeId)

    $out = @()
    foreach ($item in @($ThemeId)) {
        if ($null -eq $item) { continue }
        foreach ($part in ([string]$item) -split ',') {
            $p = $part.Trim()
            if ($p) { $out += $p }
        }
    }
    # Duplicates collapse: archiving the same theme twice in one run is never intended, and -Refresh
    # would otherwise re-pull it twice.
    return @($out | Select-Object -Unique)
}

function Get-ThemeArchiveVerdict {
    <#
    .SYNOPSIS
        May this theme be archived? Returns an object with Allowed (bool) and Reason (string).

    .DESCRIPTION
        THE LIVE THEME IS REFUSED, AND THE REASON IS THE PULL RATHER THAN A REMOVAL. This script never
        removes anything, so the removal-driven guardrails of the copy it converges do not carry over
        -- but a pull of live is still a read of live, and a Shopify consumer running this workflow
        permits exactly two of those: the pre-task sync, and an explicit request to mirror live for
        reference. "Archive the old previews" is neither, so the archive script is not a third door
        into live.

        THE CHECK IS DOUBLED, AND THAT IS NOT REDUNDANCY. The id check catches the theme repo-config
        says is live. The role check catches whichever theme the STORE says is live. Those are the same
        theme today and the day they differ is the day one of them is the only thing standing between a
        wholesale pull and the live theme -- a publish by a third party moves the role without touching
        the repo, and an id in repo-config that lags reality is precisely what that looks like from
        here. Either one alone is a guard that is correct until the estate changes underneath it.

        THE PROTECTED-ID TABLE OF THE CONVERGED COPY IS DELIBERATELY NOT HERE, and this is a decision
        rather than an omission. smartwatchbanden's script carried a $ProtectedIds hashtable whose only
        entry was its own live theme, under a comment saying in as many words that the role check
        catches it anyway and the list is an explicit extra certainty. Both halves of that certainty
        are above, and by id as well as by role -- so a seam for it would be a knob every consumer has
        to read past for an answer they already have. This repo has written that rule down: a seam
        nobody can be shown to need comes back when somebody measures one.

        -Id TAKES [AllowEmptyString()] AND THAT IS A REPAIR, found by writing the first assert against
        it (September 13, 2026). The converged copy declared it Mandatory without it, so an empty id
        was rejected by the PARAMETER BINDER and the 'no theme id given' branch three lines down could
        never execute -- a refusal that reads as a guardrail and is dead code. Worse than dead in the
        caller's direction, too: a binder failure under archive-theme.ps1's 'Stop' is terminating, so
        it would have killed a whole multi-theme run, where the verdict it was standing in for skips
        one theme and carries on. A function whose entire job is returning a verdict must return one.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Id,
        [AllowEmptyString()][string]$Name = '',
        [AllowEmptyString()][string]$Role = '',
        [AllowEmptyString()][string]$LiveThemeId = ''
    )

    $id = ([string]$Id).Trim()
    if (-not $id) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'no theme id given' }
    }

    # An unanswered LiveThemeId is refused rather than treated as "nothing is live". The caller reads
    # it from Get-ShopifyLiveThemeId, and a repo-config fault there must not quietly widen what this
    # script may pull -- the same rule the pre-task sync applies to its reference point.
    if (-not ([string]$LiveThemeId).Trim()) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'no live theme id known -- refusing to guess which theme is live' }
    }

    if ($id -eq ([string]$LiveThemeId).Trim()) {
        return [pscustomobject]@{ Allowed = $false; Reason = "this is the live theme ($LiveThemeId); live is mirrored by the pre-task sync, not archived here" }
    }

    $r = ([string]$Role).Trim().ToLower()
    if ($r -eq 'live' -or $r -eq 'main') {
        return [pscustomobject]@{ Allowed = $false; Reason = "role is '$Role'; a live theme is never archived through this script" }
    }

    return [pscustomobject]@{ Allowed = $true; Reason = '' }
}

function Get-ArchiveFolderName {
    <#
    .SYNOPSIS
        '<sanitised theme name>-<theme id>' -- the folder one theme's backup lives in.

    .DESCRIPTION
        One shape across every consumer, so an archive taken in one store reads the same as an archive
        taken in another: 'Impact-168310735124'. Both converged copies already agreed on it.

        REAL THEME NAMES ARE THE REASON THIS IS A FUNCTION AND NOT AN INTERPOLATION. Measured on one
        store on August 21, 2026, over 20 themes:
          - five carry SLASHES from an old git integration ('theme-<vendor>/feat/upsell-options');
          - one has a TRAILING space ('Kopie <store> 9-7-2021 - DO NOT DELETE ');
          - one has a LEADING space (' <STORE> THEME Live 15-5-2023 (no testing)').
        On Windows a slash is not a rename, it is a path: 'theme-<vendor>/feat/...' would have
        scattered one theme across three nested directories. A trailing space or dot is worse than an
        error, because Windows DROPS it silently -- the folder is created under a name that no longer
        round-trips, so the "does this archive already exist" check misses it and every run re-pulls.

        The id is appended last and is never sanitised away, so two themes that sanitise to the same
        name still get their own folder.
    #>
    param(
        [AllowEmptyString()][string]$Name,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $safe = [string]$Name
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace($c, '-') }
    # TrimEnd('.') before the final Trim(): 'name. ' has to lose both, and in that order.
    $safe = $safe.Trim().TrimEnd('.').Trim()
    if (-not $safe) { $safe = 'theme' }
    return ('{0}-{1}' -f $safe, ([string]$Id).Trim())
}

function Test-ThemeArchive {
    <#
    .SYNOPSIS
        Does this path hold something that is actually a theme?

    .DESCRIPTION
        "The directory exists" is not the question, because archive-theme.ps1 CREATES the directory
        before it pulls -- 'theme pull --path' requires that. So a pull that fails on the first file
        leaves an empty, existing folder, and a verification that only checked Test-Path would call it
        archived and then print a removal command for a theme with no backup. That is the one failure
        in this script that is not recoverable.

        A theme cannot be without at least one of these five directories, so one of them present is the
        cheapest honest signal that content landed.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($d in 'layout', 'config', 'templates', 'sections', 'snippets') {
        if (Test-Path -LiteralPath (Join-Path $Path $d)) { return $true }
    }
    return $false
}

# ==================================================================================================
# THE MANIFEST
#
# WHY THERE IS A MANIFEST AT ALL, because the archive itself was working as designed. theme-archive/
# is gitignored on purpose, so a verified archive proves a removal is recoverable ON THE DAY IT IS
# TAKEN and nothing keeps that true afterwards. In one store on August 28, 2026 that came due: eight
# themes archived on August 21 had left the store, theme-archive/ did not exist in the checkout, and
# the only evidence the 2,934 files had ever existed was one sentence in a changelog entry. Nobody
# could say WHICH eight, what was in them, or which of two machines the copy landed on.
#
# THE DECISION WAS NOT TO MAKE THE BYTES DURABLE. For every theme this workflow actually removes -- a
# spent branch preview -- the durable copy is git: the branch that produced it, merged into the trunk.
# Durability of the bytes would only matter for a theme whose content exists nowhere but the store,
# and every one of those is already off the cleanup list and needs the owner's own word besides. So
# the archive stays a same-day local net, and what becomes durable is the RECEIPT: a small committed
# text file naming the theme, the day, the machine, and every file with its size and hash.
#
# WHAT THAT BUYS, stated narrowly so nobody reads more into it than is there. It does NOT restore a
# theme -- a manifest is not a backup, and no amount of hashes brings a removed theme back. It answers
# the three questions the repo could not answer at all: was this theme archived, what was in it, and
# where would a surviving copy be. And it makes a recovered copy VERIFIABLE, which a folder of bytes
# with no reference never is.
#
# THE RECEIPT IS A LOG OF EVENTS, NOT A SNAPSHOT -- rewritten the same day, because the first shape
# got the third of those three questions exactly backwards.
#
# WHAT WAS MEASURED. A run with no -Refresh over a theme that already had a committed receipt reported
# '[new]', pulled 636 files and overwrote the receipt: one changed line, 'archived-utc'. Same machine,
# same files, identical hashes. The reuse branch is 'archive already on disk AND not -Refresh', so
# -Refresh was never the only way to miss it -- AN ABSENT theme-archive/ IS THE OTHER, AND IT IS THE
# COMMON ONE, because that folder is gitignored and does not survive the machine. So on any machine
# that is not the one that took the archive, every run was a fresh pull that rewrote the receipt.
#
# WHY THAT WAS WORSE THAN A WRONG DATE. The field it rewrote is 'machine' -- the one field the receipt
# was built to establish, because the owner works from two and "the bytes are on the other one" was
# unanswerable. A re-run on the second machine would have relabelled every receipt to that machine,
# after which the repo asserts with a committed file and no way to tell that the bytes are somewhere
# they are not. The receipt would still look right. It cost nothing only because the measured run
# happened to be the same machine on the same day.
#
# THE REPAIR IS THE MIDDLE OF THE THREE THAT WERE ON THE TABLE, and the two it rejected are worth
# naming because each is the obvious answer from one end:
#
#   KEEP THE EARLIEST receipt -- preserves 'machine' as intended, and buys it by letting the hashes
#     describe a pull that is not the bytes on disk. That trades one silent lie for another, in the
#     half of the file whose whole job is proving a recovered copy intact.
#   KEEP THE OVERWRITE and correct the prose -- cheapest, and it gives up the thing the receipt wanted.
#     It would close the second issue by documenting away the one that preceded it.
#
# SO THE FILE APPENDS, AND WHAT IT APPENDS IS ONE EVENT PER MACHINE RATHER THAN ONE PER RUN. That
# distinction is what answers the obvious objection to appending ("truthful, and makes the file
# grow"): a pull writes over the same folder, so A MACHINE HOLDS ONE COPY, NOT A HISTORY. Two machines
# means two lines, forever. And an event is touched only when the content it describes actually
# changed -- a re-pull landing identical bytes leaves the receipt alone, so the recorded day stays the
# day those bytes landed, which is what the prose promised all along and the code did not.
#
# EVERY EVENT CARRIES THE DIGEST OF THE LIST IT LANDED, which is what makes the body honest for events
# it does not describe. The body can only be one pull's file list. With a digest on each line a reader
# can see at a glance whether an older machine's copy is the same bytes; without one, a second machine
# with different content would be silently claimed by a body that never described it. In practice the
# digests agree, because a theme this workflow archives is one that is about to leave the store and
# stops changing -- but "in practice" is exactly the assurance this block exists to stop relying on.
# ==================================================================================================

function Get-ArchiveManifestFileName {
    <#
    .SYNOPSIS
        '<archive folder name>.txt' -- the committed receipt for one archived theme.

    .DESCRIPTION
        Deliberately derived from Get-ArchiveFolderName's answer rather than rebuilt from the name and
        id, so the two can never disagree about which manifest belongs to which folder. That matters
        because the folder is the thing that vanishes and the manifest is the thing that stays: a
        receipt whose name does not match the folder it describes is worse than no receipt, since it
        reads as evidence for a theme it does not cover.

        Every hazard Get-ArchiveFolderName handles -- slashes, trailing spaces, trailing dots -- is
        therefore already handled by the time this is called, and this adds an extension and nothing
        else.
    #>
    param([Parameter(Mandatory = $true)][string]$Folder)
    return ('{0}.txt' -f ([string]$Folder).Trim())
}

function Get-ThemeArchiveFileRecords {
    <#
    .SYNOPSIS
        Walk an archived theme and return one record per file: RelativePath, Bytes, Sha256.

    .DESCRIPTION
        FORWARD SLASHES AND AN ORDINAL SORT, both on purpose. The archive is written on Windows and the
        manifest is committed, so a backslash would make the receipt read as a Windows artefact of a
        Shopify theme whose own paths are 'sections/foo.liquid' -- and would stop it lining up against
        a 'git ls-files' or against a theme pull taken anywhere else.

        THE SORT IS ORDINAL, AND 'Sort-Object -CaseSensitive' IS NOT THE SAME THING. That was the first
        spelling here and it is a real trap: -CaseSensitive makes the comparison case-sensitive and
        leaves it CULTURE-AWARE, so the order still depends on the machine's locale. The property this
        file needs is that two machines produce byte-identical manifests for identical content --
        otherwise a re-archive shows as a diff of a few hundred reordered lines with nothing actually
        changed, which is how a reader learns to stop reading it. Only an ordinal comparison gives
        that, and the discriminating case is asserted in the suite ('B' before 'a' ordinally, the other
        way round in most cultures).

        SHA-256 rather than a size alone, because a size is what a truncated pull still gets right.
        The cost is one read of ~400-700 small files, which is nothing beside the theme pull that has
        just fetched them over the network.

        A missing directory returns an empty array rather than throwing. The caller has already run
        Test-ThemeArchive, and the manifest step must never be the thing that fails a run whose archive
        is fine -- the receipt is worth having, but not at the price of the backup it describes.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    $root = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    $records = @()
    foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'
        $records += [pscustomobject]@{
            RelativePath = $rel
            Bytes        = [int64]$f.Length
            Sha256       = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
        }
    }
    $items = @($records)
    if ($items.Count -lt 2) { return $items }

    # SORT THE KEYS, THEN LOOK THE RECORDS BACK UP. Four spellings of this sort were written before
    # this one. Every one of them looked right, three were silently wrong, and the order in which they
    # failed is the useful part -- so they are named rather than summarised:
    #
    #   1. Sort-Object -Property RelativePath -CaseSensitive
    #      Case-sensitive and still CULTURE-aware, so the order stays a property of the machine's
    #      locale -- exactly the property this file must not have. Silent.
    #   2. [Array]::Sort($keys, $values, [StringComparer]::Ordinal)
    #      PowerShell binds an overload that sorts $keys and leaves $values IN ITS ORIGINAL ORDER, so
    #      the function returns unsorted records while every line of it reads as a sort. Silent, and
    #      the worst of the four: the first two receipts were committed in that state.
    #   3. List[object].Sort([Comparison[object]]{ ... }) written inline
    #      Throws at the call: PowerShell resolves the Sort overload against a raw ScriptBlock, which
    #      is convertible to more than one candidate, before the cast is applied.
    #   4. The same with the delegate assigned to a variable first, returning '@($list)'
    #      Correct under a suite's 'Continue' and FATAL under the 'Stop' archive-theme.ps1 sets --
    #      '@(...)' over a generic List of PSCustomObjects raises a non-terminating error that Continue
    #      swallows. So the units were green on a path the caller could not execute, which is the one
    #      failure a unit suite is supposed to be immune to. The suite flips the preference for this
    #      call on purpose.
    #
    # WHAT IS LEFT USES NEITHER A DELEGATE NOR A GENERIC COLLECTION IN A RETURN. Two-arg [Array]::Sort
    # over a plain string[] takes the comparer with no overload ambiguity; the Dictionary is given
    # StringComparer::Ordinal too, so two paths differing only in case cannot collide the way
    # PowerShell's case-insensitive hashtable would let them; and the rebuilt array is a plain array.
    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
    foreach ($r in $items) { $map[[string]$r.RelativePath] = $r }
    $keys = [string[]]@($items | ForEach-Object { [string]$_.RelativePath })
    [Array]::Sort($keys, [System.StringComparer]::Ordinal)

    $out = @()
    foreach ($k in $keys) { $out += $map[$k] }
    return $out
}

function Get-ThemeArchiveContentDigest {
    <#
    .SYNOPSIS
        One SHA-256 over a whole file list, so an archive's content has a single comparable name.

    .DESCRIPTION
        WHAT IT IS FOR. An event line has room for one fingerprint, and the question a reader asks of
        an older event is "is that machine's copy the same bytes as the list in this file?". A count of
        files and a total of bytes cannot answer it -- those are what a truncated or reordered pull
        still gets right, which is the same reason Get-ThemeArchiveFileRecords hashes each file rather
        than sizing it.

        IT HASHES THE RENDERED LINES, not the files again. The records have already been hashed once by
        the time this is called; re-reading 636 files to fold them together would cost a second pass
        for no additional evidence. So the input is the canonical '<sha256>  <bytes>  <path>' text --
        exactly the body Format-ThemeArchiveManifest writes -- which makes the digest reproducible by
        hand from a committed receipt with no access to the bytes at all. That property is the point: a
        reader in five months can verify the digest against the body they are holding.

        LF, NOT THE PLATFORM'S NEWLINE, and a trailing one. The manifest is committed and
        .gitattributes governs what lands in the working tree, so a digest folded over CRLF would
        differ between two checkouts of the same file and the comparison it exists for would fail on a
        machine difference.

        Empty in, empty out -- deliberately the empty string rather than the SHA-256 of nothing. An
        archive with no files has not been verified (Test-ThemeArchive would have refused it), so it
        must not acquire a digest that reads like a fingerprint of something.

        THE NULLS ARE FILTERED, AND IT IS THE SAME MEASURED UNROLL Merge-ThemeArchiveEvent's own banner
        describes -- found here by the first assert written against this contract (September 13, 2026).
        'Get-ThemeArchiveFileRecords -Path <absent>' returns @(), an EMPTY pipeline, which binds to
        this parameter as $null; and '@($null)' is a ONE-element array holding $null. So the count was
        1, the loop rendered a phantom '    ' line, and the function returned a real-looking SHA-256
        for an archive with no files -- which is precisely the "fingerprint of something" the paragraph
        above says must never happen, and it happened on the path that reaches this with nothing.
    #>
    param([AllowNull()][array]$Records = @())

    $recs = @()
    foreach ($r in @($Records)) { if ($null -ne $r) { $recs += $r } }
    if ($recs.Count -eq 0) { return '' }

    $lines = @()
    foreach ($r in $recs) { $lines += ('{0}  {1}  {2}' -f $r.Sha256, $r.Bytes, $r.RelativePath) }
    $text  = ($lines -join "`n") + "`n"

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($text)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}

function Get-ThemeArchiveEvents {
    <#
    .SYNOPSIS
        Read the archive events out of an existing manifest's text. Returns an array, possibly empty.

    .DESCRIPTION
        THE PARSE IS WHY THE MERGE IS SAFE. Every run reads the committed receipt before it writes one,
        so the facts already in the file survive a run on a machine that knows nothing about them. A
        parser that came back empty on a file it could not read would silently reintroduce the whole of
        the lost-machine failure -- the recorded machine would vanish and the run would write its own
        in its place. So this is written to find something rather than to validate: it takes the lines
        it recognises and ignores everything else, and the caller merges rather than replaces.

        IT READS THE PRE-EVENT-LOG SHAPE TOO, WHICH IS WHAT MAKES THE MIGRATION AUTOMATIC. A v1 receipt
        has single 'archived-utc:' and 'machine:' header fields and no event lines at all; two of those
        were committed before the log existed. Rather than a one-off conversion script, a v1 file is
        read as exactly one event -- with no digest, because v1 recorded none -- and the first ordinary
        run over that theme writes it forward. There is nothing to remember to do.

        A DIGEST-LESS EVENT IS A DISTINCT STATE, not a missing field to be filled in with a guess. It
        means "this machine held this many files of this size on this day, and nothing recorded what
        they hashed to". Merge-ThemeArchiveEvent decides what may be concluded from it; this function's
        only job is not to invent one.

        Order is not trusted from the file: the caller sorts. A hand-edited receipt with its lines the
        wrong way round must not produce a different merge than the same facts in the right order.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Text)

    $t = [string]$Text
    if (-not $t) { return @() }

    $events = @()
    foreach ($line in ($t -split "`r?`n")) {
        # Five positional fields after the key. The last is optional so a hand-written line naming a
        # machine and a day is still read rather than discarded for lacking a digest -- and it also
        # accepts the literal '-' that Format-ThemeArchiveManifest writes for a digest-less event.
        # WITHOUT THE '-' ALTERNATION THIS DID NOT ROUND-TRIP: the formatter renders a pre-log event's
        # absent digest as '-', which is not [0-9a-fA-F]+, so the whole line failed to match and the
        # event vanished on the next run -- exactly the lost-machine failure the log exists to prevent,
        # reappearing one migration later. A '-' is read as no digest.
        $m = [regex]::Match($line, '^archived:\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)(?:\s+([0-9a-fA-F]+|-))?\s*$')
        if (-not $m.Success) { continue }
        $sha = $m.Groups[5].Value
        if ($sha -eq '-') { $sha = '' }
        $events += [pscustomobject]@{
            ArchivedUtc = $m.Groups[1].Value
            Machine     = $m.Groups[2].Value
            Files       = [int]$m.Groups[3].Value
            Bytes       = [int64]$m.Groups[4].Value
            ContentSha  = $sha.ToLower()
        }
    }
    if ($events.Count -gt 0) { return @($events) }

    # THE v1 FALLBACK, and it only runs when no event line was found -- so a v2 file's own 'files:' and
    # 'bytes:' body totals can never be mistaken for an event. 'machine:' is allowed to be blank: an
    # unnamed machine is still a recorded day, and losing the day as well would be the worse outcome.
    $utc = [regex]::Match($t, '(?m)^archived-utc:\s*(\S+)\s*$')
    if (-not $utc.Success) { return @() }

    # Assigned to variables first, then placed. 'if' is not an expression inside a hashtable literal in
    # Windows PowerShell 5.1 -- it parses in 7 and is a parse error here, which would take the whole lib
    # down at dot-source time and with it every gate that reads it.
    $mach  = [regex]::Match($t, '(?m)^machine:\s*(\S*)\s*$')
    $files = [regex]::Match($t, '(?m)^files:\s*(\d+)\s*$')
    $bytes = [regex]::Match($t, '(?m)^bytes:\s*(\d+)\s*$')

    $vMach  = ''
    $vFiles = 0
    $vBytes = [int64]0
    if ($mach.Success)  { $vMach  = $mach.Groups[1].Value }
    if ($files.Success) { $vFiles = [int]$files.Groups[1].Value }
    if ($bytes.Success) { $vBytes = [int64]$bytes.Groups[1].Value }

    return @([pscustomobject]@{
        ArchivedUtc = $utc.Groups[1].Value
        Machine     = $vMach
        Files       = $vFiles
        Bytes       = $vBytes
        ContentSha  = ''
    })
}

function Merge-ThemeArchiveEvent {
    <#
    .SYNOPSIS
        Fold one archive run into the events already recorded. Returns @{ Events; Change }.

    .DESCRIPTION
        THE WHOLE OF THE REPAIR IS THIS FUNCTION'S FIRST BRANCH: an event whose content has not changed
        is returned untouched, so the recorded day stays the day those bytes landed. The old code had
        the reuse path keep the receipt and the fresh-pull path overwrite it, which reads as the same
        rule from two ends and is not -- 'the archive is on disk' and 'the content is the same' are
        different questions, and on a second machine the first is false while the second is true.

        ONE EVENT PER MACHINE. A pull writes over the same folder, so a machine holds one copy and the
        event describing it is replaced when that copy changes. Keeping a per-run history would grow
        the file with lines that describe bytes no longer anywhere.

        THE MACHINE COMPARISON IS CASE-INSENSITIVE AND THE RECORDED SPELLING IS KEPT. Windows computer
        names are case-insensitive, so 'DAVE-KOK-BWJ' and 'dave-kok-bwj' are one machine and must not
        become two events claiming two copies. The spelling already in the file wins on a match, so a
        receipt does not churn over a difference that means nothing.

        FOUR OUTCOMES, and each says something different to the caller:
          kept      -- this machine already recorded this exact content. Nothing written.
          added     -- a machine not previously recorded now holds a copy. This is the answer growing,
                       and the only outcome that makes the file longer.
          replaced  -- this machine's copy changed. Its old event described bytes that are gone.
          migrated  -- a pre-log event on this machine gained the digest it never recorded, KEEPING ITS
                       RECORDED DAY. Allowed only when the file count and byte total both still match,
                       which is the available evidence that the content is the same content. Where they
                       do not match this is a 'replaced' instead, because then the day is not the day
                       the bytes on disk landed and the whole point is not to claim otherwise.

        THE EVENTS COME BACK SORTED ORDINALLY BY TIMESTAMP, so the log reads oldest-first and the same
        facts always render the same bytes whatever order they arrived in. ISO-8601 UTC sorts lexically
        as it sorts chronologically, which is the only reason a string sort is honest here.
    #>
    param(
        [AllowNull()][array]$Events = @(),
        [Parameter(Mandatory = $true)][string]$ArchivedUtc,
        [AllowEmptyString()][string]$Machine = '',
        [Parameter(Mandatory = $true)][int]$Files,
        [Parameter(Mandatory = $true)][int64]$Bytes,
        [AllowEmptyString()][string]$ContentSha = ''
    )

    # THE NULLS ARE FILTERED, AND THAT IS NOT DEFENSIVENESS -- IT IS A MEASURED BUG.
    # 'Get-ThemeArchiveEvents -Text ""' returns @(), an EMPTY pipeline, which PowerShell binds to this
    # parameter as $null; and '@($null)' is a ONE-ELEMENT array holding $null. So the first archive of
    # a theme -- the path with no receipt yet, which is every theme once -- folded a phantom blank
    # event into the log and rendered it as 'archived:         -'.
    #
    # WHAT MAKES IT WORTH THIS MANY LINES IS HOW IT HID. The unit assert
    # 'Assert-Equal 0 @(Get-ThemeArchiveEvents -Text "").Count' passes, because the unroll happens at
    # the PARAMETER BOUNDARY and not inside '@(...)' over an expression. Every function was green and
    # the composition of two of them was wrong -- caught only by the round-trip case that renders,
    # reads back and re-merges. A unit can be measuring a shape the caller never passes it.
    $existing = @()
    foreach ($e in @($Events)) { if ($null -ne $e) { $existing += $e } }
    $machine  = ([string]$Machine).Trim()
    $sha      = ([string]$ContentSha).Trim().ToLower()

    $out    = @()
    $mine   = $null
    foreach ($e in $existing) {
        if (-not $mine -and $machine -and ([string]$e.Machine).Trim().ToLower() -eq $machine.ToLower()) {
            $mine = $e
            continue
        }
        $out += $e
    }

    if (-not $mine) {
        $change = 'added'
        $out += [pscustomobject]@{
            ArchivedUtc = $ArchivedUtc; Machine = $machine
            Files = $Files; Bytes = $Bytes; ContentSha = $sha
        }
    } elseif ($sha -and ([string]$mine.ContentSha) -eq $sha) {
        $change = 'kept'
        $out += $mine
    } elseif (-not ([string]$mine.ContentSha) -and [int]$mine.Files -eq $Files -and [int64]$mine.Bytes -eq $Bytes) {
        $change = 'migrated'
        $out += [pscustomobject]@{
            ArchivedUtc = [string]$mine.ArchivedUtc      # the day the bytes landed, which is the durable fact
            Machine     = ([string]$mine.Machine).Trim() # and its recorded spelling
            Files = $Files; Bytes = $Bytes; ContentSha = $sha
        }
    } else {
        $change = 'replaced'
        # Keep the recorded spelling where there is one; see the note in the v1 fallback above on why
        # this is a variable rather than an inline 'if'.
        $keepMachine = ([string]$mine.Machine).Trim()
        if (-not $keepMachine) { $keepMachine = $machine }
        $out += [pscustomobject]@{
            ArchivedUtc = $ArchivedUtc
            Machine     = $keepMachine
            Files = $Files; Bytes = $Bytes; ContentSha = $sha
        }
    }

    $sorted = @($out)
    if ($sorted.Count -gt 1) {
        # Same trap as Get-ThemeArchiveFileRecords', same shape of answer: sort a plain string[] of
        # keys with the ordinal comparer, then look the records back up. A timestamp collision between
        # two machines is possible, so the key carries the machine as a tie-break and stays unique.
        $map  = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
        foreach ($e in $sorted) { $map[('{0}|{1}' -f $e.ArchivedUtc, $e.Machine)] = $e }
        $keys = [string[]]@($map.Keys)
        [Array]::Sort($keys, [System.StringComparer]::Ordinal)
        $rebuilt = @()
        foreach ($k in $keys) { $rebuilt += $map[$k] }
        $sorted = $rebuilt
    }

    return [pscustomobject]@{ Events = @($sorted); Change = $change }
}

function Format-ThemeArchiveManifest {
    <#
    .SYNOPSIS
        Render one theme's manifest as text. Pure: no disk, no clock, no environment.

    .DESCRIPTION
        PURE ON PURPOSE, AND THE CLOCK IS THE REASON. Every value that varies -- the timestamp, the
        machine name -- is a parameter rather than something read in here, so the suite can assert the
        exact bytes this produces. A formatter that read Get-Date could only ever be tested for 'looks
        about right', which is precisely the level of confidence the archive already had and the reason
        this function exists at all.

        NO ABSOLUTE PATHS, and that is a rule rather than an oversight. A consumer's owner may work
        from two machines with different user profiles, and this workflow refuses an absolute path into
        a user profile repo-wide. 'C:\Users\<somebody>\...' in a committed file would be both a leak
        and a lie on the other machine. The machine NAME is recorded instead, which is the field that
        answers the question a bare archive could not: this may simply be the other machine -- which
        one?

        The header is comment lines so the file explains itself to whoever opens it in five months
        looking for a theme that is no longer on the store, which is the only moment this file is ever
        read.

        THE MACHINE AND THE DAY ARE NOT SINGLE FIELDS. They arrive as -Events, one per machine that has
        held a copy, and there is deliberately NO 'archived-utc:' or 'machine:' line beside them -- a
        second copy of a fact is drift, and here it would be worse than drift: the single field WAS the
        bug, since whichever run wrote last relabelled it. A reader wanting "when and where" reads the
        event log, which is the only place the answer lives.

        THE CONTENT DIGEST IS COMPUTED HERE FROM THE RECORDS THIS CALL RENDERS, never accepted as a
        parameter. It names the body written directly below it, so deriving it in the same call is what
        makes it impossible for the two to disagree. The caller computes the same digest with the same
        function for the event it merges; a test asserts the two agree.

        -VerifierPath IS A PARAMETER BECAUSE THE VERIFIER IS NOT THIS PLUGIN'S. Reading a receipt back
        and measuring a folder against it is a consumer-side script today (see the banner above the
        three reader functions), so the receipt names it only where a caller says it has one. Unset,
        the line is left out rather than pointing at a path that does not exist -- a receipt that names
        a missing tool is a receipt a reader stops trusting.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [AllowEmptyString()][string]$ThemeName = '',
        [AllowEmptyString()][string]$Role = '',
        [AllowEmptyString()][string]$Store = '',
        [Parameter(Mandatory = $true)][string]$Folder,
        [AllowNull()][array]$Events = @(),
        [AllowNull()][array]$Records = @(),
        [AllowEmptyString()][string]$VerifierPath = ''
    )

    # Nulls filtered for the same reason Get-ThemeArchiveContentDigest filters them, and it matters
    # more here: an unrolled $null would render a phantom '    ' line INTO the committed body and count
    # itself in 'files:', so the receipt would assert one file that is nowhere and a total that does
    # not add up. The digest below is taken over the same filtered list, so header and body agree.
    $recs  = @()
    foreach ($r in @($Records)) { if ($null -ne $r) { $recs += $r } }
    $bytes = [int64]0
    foreach ($r in $recs) { $bytes += [int64]$r.Bytes }

    $verifier = ([string]$VerifierPath).Trim()

    $lines = @()
    $lines += '# Shopify theme archive manifest -- written by dkj-subagents-shopify''s archive-theme.'
    $lines += '#'
    $lines += '# THIS FILE IS THE RECEIPT, NOT THE BACKUP. The bytes live in theme-archive/, which is'
    $lines += '# gitignored and does not survive the machines named below. This file is committed, so'
    $lines += '# the repo can always say what was archived, when, and where a surviving copy would be.'
    if ($verifier) {
        $lines += '# It cannot restore a theme. It can prove a recovered copy is intact -- run'
        $lines += ('# {0} to do exactly that, against any copy.' -f $verifier)
    } else {
        $lines += '# It cannot restore a theme. It can prove a recovered copy is intact, by walking a'
        $lines += '# copy and comparing it against the file list below.'
    }
    $lines += '#'
    $lines += ('theme-name:   {0}' -f $ThemeName)
    $lines += ('theme-id:     {0}' -f $ThemeId)
    $lines += ('role:         {0}' -f $Role)
    $lines += ('store:        {0}' -f $Store)
    $lines += ('folder:       {0}' -f $Folder)
    $lines += ('files:        {0}' -f $recs.Count)
    $lines += ('bytes:        {0}' -f $bytes)
    $lines += ('content-sha256: {0}' -f (Get-ThemeArchiveContentDigest -Records $recs))
    $lines += '#'
    $lines += '# ARCHIVE EVENTS -- one line per PLACE that has held a copy, oldest first. Usually a machine'
    $lines += '# name; a durable destination outside any one machine is named by its own label instead,'
    $lines += '# because "where would a surviving copy be" is the question this log answers and a backed-up'
    $lines += '# folder is a legitimate answer to it. A pull writes over the same folder, so a place holds'
    $lines += '# one copy and its line is replaced when that copy changes; a run landing identical bytes'
    $lines += '# leaves the line alone, so the day recorded is the day those bytes landed. A line whose'
    $lines += '# digest equals content-sha256 above describes the file list below; one that differs'
    $lines += '# described other bytes, and this file does not list them.'
    $lines += '# A digest of "-" is a receipt written before the digest was recorded at all.'
    $lines += '#'
    $lines += '# archived: <utc>  <place>  <files>  <bytes>  <content-sha256>'
    foreach ($e in @($Events)) {
        # Skipped for the same reason Merge-ThemeArchiveEvent filters them: an empty event list arrives
        # here as $null, and '@($null)' iterates once. A blank 'archived:' line in a committed receipt
        # would read as a machine nobody can name.
        if ($null -eq $e) { continue }
        $sha = ([string]$e.ContentSha).Trim()
        if (-not $sha) { $sha = '-' }
        $lines += ('archived: {0}  {1}  {2}  {3}  {4}' -f $e.ArchivedUtc, $e.Machine, $e.Files, $e.Bytes, $sha)
    }
    $lines += '#'
    $lines += '# sha256  bytes  path'
    foreach ($r in $recs) {
        $lines += ('{0}  {1}  {2}' -f $r.Sha256, $r.Bytes, $r.RelativePath)
    }
    return ($lines -join "`n") + "`n"
}

function Format-ThemeDeleteCommand {
    <#
    .SYNOPSIS
        Render the removal command the script prints for an archived theme. Pure: no disk, no seam read.

    .DESCRIPTION
        WHY THIS IS A FUNCTION AND NOT A FORMAT STRING IN THE CALLER. It was one, and all three of its
        defects survived a repair pass to the very file it lived in. On August 21, 2026 the removal
        marker seam was answered in a store, which changed what a working command looks like; on
        August 28 the script HEADER was corrected for exactly that, and the Write-Host block twenty
        lines further down was not. It went on printing a command with no marker and no --force, under
        a sentence saying the guard refuses the command from a session -- so the one part of the script
        a caller actually reads told them the thing was impossible and then handed them a command that
        fails.

        THE FAILURE MODE IS WHAT MAKES IT WORTH A SEAM RATHER THAN CARE: the command is refused by the
        GUARD, and a guard refusal reads as the rule rather than as a typo. Somebody meeting it goes
        editing config that was already correct. So the command is built here, where the suite can
        assert it, instead of in a format string that nothing measures.

        FOUR PROPERTIES, and each is a way this one line has been or could be wrong:

          1. THE MARKER COMES FROM THE SEAM, never a literal. Get-ShopifyThemeDeleteMarker is what the
             guard hook itself reads on every command; a second copy spelled in here would be free to
             drift, and it would drift silently in the direction that costs most -- a printed command
             that looks authorised and is refused. It arrives as a PARAMETER rather than a call,
             because that is what lets the suite measure the answered AND the unanswered repo without
             editing config.
          2. --force IS ALWAYS PRESENT. Without it the CLI prompts, and a session cannot answer a
             prompt. It is printed in the unanswered branch too, where a human runs the command and
             could answer one: two spellings of the same documented command is how the two drift apart
             again.
          3. THE NAME CANNOT DISPLACE THE MARKER. It used to BE the comment -- "# <theme name>" --
             which is how defect 1 happened. It now trails the marker inside the comment, and the guard
             matches with Contains() over the whole command string, so trailing text is harmless.
             Measured against the loaded guard rather than assumed.
          4. WHITESPACE COMES OUT OF THE NAME. A comment is terminated by a line break, so a name
             carrying one would split the command in two and leave the caller pasting the garbage half.
             Real theme names already carry slashes and leading and trailing spaces (see
             Get-ArchiveFolderName), so "no theme is named like that" is not an assumption this file
             gets to make.

        WITH THE SEAM UNANSWERED there is no marker to print and no "# " left dangling: the comment
        holds the theme name alone. That branch is not dead code -- it is what a repo that has not
        answered the seam sees, and an empty marker must never render as an authorisation that is not
        one.

        The returned string carries NO leading indentation. The caller owns its own layout.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [AllowEmptyString()][string]$ThemeName = '',
        [AllowEmptyString()][string]$DeleteMarker = ''
    )

    $marker = ([string]$DeleteMarker).Trim()

    # Property 4. Any run of whitespace -- CR, LF, tab -- collapses to a single space, so whatever the
    # store calls this theme, what comes back is exactly one line.
    $name = [regex]::Replace(([string]$ThemeName), '\s+', ' ').Trim()

    $cmd = 'shopify theme delete --store {0} --theme {1} --force' -f $Store, $ThemeId

    if ($marker -and $name) { return ('{0}  # {1}   ({2})' -f $cmd, $marker, $name) }
    if ($marker)            { return ('{0}  # {1}' -f $cmd, $marker) }
    if ($name)              { return ('{0}  # ({1})' -f $cmd, $name) }
    return $cmd
}

function Get-ExternalThemeWarning {
    <#
    .SYNOPSIS
        Does this theme belong to a third party, so that removing it would break their integration?
        Returns the warning line to print above the command, or '' when it does not.

    .DESCRIPTION
        THIS IS THE ONE PLACE NEITHER CONVERGED COPY WAS RIGHT, and it is the reason this convergence
        is a superset rather than a move.

        smartwatchbanden's script REFUSED to touch a theme whose name began with a third party's
        prefix unless -AllowExternal was passed, because removing one breaks that party's integration.
        xoxowildhearts' script dropped the gate outright, and its note gave a sound reason: that script
        never removes anything, and a local read-only backup of somebody else's theme harms nobody, so
        the gate had no subject. Copying it across would have left a guardrail whose stated reason was
        false, and a guardrail nobody can write the rule down for is one somebody eventually switches
        off.

        BOTH ARE RIGHT ABOUT THE ARCHIVE AND BOTH MISS THE PRINTED COMMAND. The converged script ends
        by printing a removal command for every theme it archived. For a store with no third-party
        themes that is harmless, which is why the store that dropped the gate never met this. For a
        store that has them it hands the caller, without a word, the exact command that breaks a live
        integration -- and it does so under a heading saying the archive makes the removal recoverable,
        which is true of the theme's FILES and says nothing about the integration.

        SO THE ARCHIVE IS NEVER GATED AND THE COMMAND IS NEVER SUPPRESSED. Refusing the archive was the
        strictness that had no subject; suppressing the command would hide a line the caller may
        legitimately need after talking to the third party, and a command that silently goes missing is
        read as a bug in the script. What is added is the one thing that was absent from both: the
        caller is told, at the moment they are about to paste it, whose theme this is.

        THE PREFIXES ARE A SEAM AND NOT A LITERAL. 'theme-<vendor>/' is one store's integration, and
        spelling it here would be a fact about one consumer sitting in a shipped lib. Unanswered -- the
        ordinary case, and the case for every store with no third-party themes -- there is nothing to
        match and this returns '' on every theme, so a consumer that answers nothing sees exactly what
        it sees today.

        THE MATCH IS ON A PREFIX AND IS CASE-INSENSITIVE. A prefix because that is the shape a Shopify
        git integration actually produces -- '<prefix>/<branch>' -- and case-insensitive because the
        store's own theme names are typed by people and this must not depend on how one of them
        capitalised a vendor.
    #>
    param(
        [AllowEmptyString()][string]$Name = '',
        [AllowNull()][string[]]$ExternalPrefixes = @()
    )

    $name = ([string]$Name).Trim()
    if (-not $name) { return '' }

    foreach ($raw in @($ExternalPrefixes)) {
        if ($null -eq $raw) { continue }
        $prefix = ([string]$raw).Trim()
        if (-not $prefix) { continue }
        if ($name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ("THIRD-PARTY THEME ('{0}'): this theme belongs to an outside integration. The archive is safe and is already taken; running the command below breaks their integration. Agree it with them first." -f $prefix)
        }
    }
    return ''
}

# --------------------------------------------------------------------------------------------------
# READING A RECEIPT BACK, AND MEASURING A FOLDER AGAINST IT
# --------------------------------------------------------------------------------------------------
# THE RECEIPT WAS ONLY EVER WRITTEN, NEVER READ, AND THAT IS THE GAP. The manifest was built so a repo
# could always say what an archive held and prove a recovered copy intact -- and the second half was
# never implemented. So "the archive's bytes are gone" was something a person discovered at the moment
# they needed them, rather than something anybody could find out. The three functions below are that
# second half, and they are pure for the same reason the formatter is: the suite can assert exact
# answers instead of "looks about right".
#
# WHY THEY PARSE THE FILE INSTEAD OF RE-DERIVING FROM THE STORE. Every theme these matter for is one
# that has LEFT the store -- it is not in 'shopify theme list' and never will be again. The committed
# receipt is the only surviving description of it, which is exactly what it was built to be.
#
# NO CALLER IN THIS PLUGIN, AND THAT IS THE BOUND OF ISSUE #1886 CANDIDATE 4 RATHER THAN AN OVERSIGHT.
# The verifier that drives these is a script only ONE of the two converged consumers has, and the
# issue's own bar is that a mechanism only one store has is not a convergence candidate. So it stays
# that consumer's script; these rules travel because they live in this file, and stranding them here
# would leave that consumer dot-sourcing a lib that had lost the three functions it calls. A consumer
# with a verifier reaches them through this lib rather than keeping a second copy.

function Get-ThemeArchiveManifestField {
    <#
    .SYNOPSIS
        Read one 'name: value' header field out of a manifest's text. '' when absent.

    .DESCRIPTION
        WRITTEN TO FIND RATHER THAN TO VALIDATE, the same choice as Get-ThemeArchiveEvents and for the
        same reason: a receipt is hand-readable and may have been hand-edited, and a parser that
        refused a file it did not fully understand would turn a legible receipt into no receipt.

        THE FIELD NAME IS MATCHED ANCHORED, and a comment line can never satisfy it: every header
        comment starts with '#', which the anchor excludes. That matters because the header PROSE
        contains the word 'folder' several times.
    #>
    param(
        [AllowEmptyString()][AllowNull()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $t = [string]$Text
    if (-not $t) { return '' }

    $pattern = '^' + [regex]::Escape($Name) + ':\s*(.*?)\s*$'
    foreach ($line in ($t -split "`r?`n")) {
        $m = [regex]::Match($line, $pattern)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return ''
}

function Get-ThemeArchiveManifestFileRecords {
    <#
    .SYNOPSIS
        Read the file list out of a manifest's text: one record per file, shaped like
        Get-ThemeArchiveFileRecords' output so the two can be compared directly.

    .DESCRIPTION
        THE TWO SHAPES ARE DELIBERATELY IDENTICAL -- RelativePath, Bytes, Sha256 -- because the whole
        point is to compare a receipt against a walk of a folder. A parser that returned its own shape
        would push the reconciling into every caller.

        A PATH MAY CONTAIN SPACES, so the path is "everything after the byte count" rather than a third
        whitespace-delimited field. Themes carry names with spaces and so do their assets; splitting on
        whitespace would silently truncate those and report them as changed.

        ONLY A FULL 64-CHARACTER SHA-256 IS ACCEPTED as the first field, which is what keeps the header
        comment '# sha256  bytes  path' and the 'archived:' event lines out of the result without
        needing to know where the list starts.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Text)

    $t = [string]$Text
    if (-not $t) { return @() }

    $records = @()
    foreach ($line in ($t -split "`r?`n")) {
        $m = [regex]::Match($line, '^([0-9a-fA-F]{64})\s+(\d+)\s+(.+?)\s*$')
        if (-not $m.Success) { continue }
        $records += [pscustomobject]@{
            RelativePath = $m.Groups[3].Value
            Bytes        = [int64]$m.Groups[2].Value
            Sha256       = $m.Groups[1].Value.ToLower()
        }
    }
    return @($records)
}

function Compare-ThemeArchiveWithManifest {
    <#
    .SYNOPSIS
        Measure a walked folder against what a receipt says it should hold. Returns an object carrying
        Verdict, Matched, Missing, Changed and Extra.

    .DESCRIPTION
        PURE: it compares two sets of records. The caller walks the disk and reads the file.

        THREE FINDINGS, AND THEY ARE NOT THE SAME KIND OF NEWS.
          Missing -- the receipt names a file the folder does not have. This is the failure the
                     verifier is about: an archive that has lost part of itself while still looking
                     like a backup.
          Changed -- the file is there and its bytes are not what was archived. Worse than missing in
                     one specific way: a restore from it would succeed and be wrong.
          Extra   -- the folder holds a file the receipt does not name. Reported, never a failure on
                     its own: it is what a partial re-pull or a stray editor file looks like, and it
                     does not put any archived byte at risk.

        SO THE VERDICT IS 'damaged' FOR MISSING OR CHANGED AND 'clean' OTHERWISE, extras included. A
        check that went red on an extra file would be red on a folder that has everything it promised,
        and what happens to a signal that cries wolf is written down in this repo three times over.

        THE PATH COMPARISON IS ORDINAL AND CASE-SENSITIVE, matching Get-ThemeArchiveFileRecords' sort
        and git's own behaviour. The failure direction is the safe one: two spellings differing only in
        case are reported as one missing and one extra -- loud, and inspectable -- rather than quietly
        treated as the same file when they are not.

        AN EMPTY RECEIPT IS NOT A CLEAN VERDICT. A manifest naming no files describes nothing, so there
        is nothing to have verified; 'unknown' says so instead of passing vacuously. Test-ThemeArchive
        already refuses to call an empty directory a backup, and this is the same rule read from the
        receipt's end.
    #>
    param(
        [AllowNull()][array]$Expected = @(),
        [AllowNull()][array]$Actual   = @()
    )

    $exp = @(@($Expected) | Where-Object { $_ })
    $act = @(@($Actual)   | Where-Object { $_ })

    if ($exp.Count -eq 0) {
        return [pscustomobject]@{
            Verdict = 'unknown'
            Matched = 0
            Missing = @()
            Changed = @()
            Extra   = @(@($act) | ForEach-Object { [string]$_.RelativePath })
        }
    }

    # NAMED $byPath, NOT $actual: PowerShell variable names are case-insensitive, so a local called
    # $actual IS the [array]$Actual parameter -- assigning a Dictionary to it coerces the whole thing
    # into an array, after which $actual[$p] indexes it with a STRING and every file reads as missing.
    # Found by the first fixture run; a clean archive reported "damaged, 1 missing" with the file right
    # there on disk.
    $byPath = New-Object 'System.Collections.Generic.Dictionary[string,object]' (
        [System.StringComparer]::Ordinal)
    foreach ($a in $act) {
        $p = [string]$a.RelativePath
        if ($p -and -not $byPath.ContainsKey($p)) { $byPath[$p] = $a }
    }

    $missing = New-Object System.Collections.ArrayList
    $changed = New-Object System.Collections.ArrayList
    $seen    = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $matched = 0

    foreach ($e in $exp) {
        $path = [string]$e.RelativePath
        if (-not $byPath.ContainsKey($path)) { [void]$missing.Add($path); continue }
        [void]$seen.Add($path)
        $onDisk  = $byPath[$path]
        $wantSha = ([string]$e.Sha256).ToLower()
        $gotSha  = ([string]$onDisk.Sha256).ToLower()
        # THE DIGEST DECIDES AND THE SIZE IS THE REASON PRINTED. A size alone is what a truncated pull
        # still gets right, which is why the receipt records hashes; but a reader chasing a changed
        # file wants to know it went from 9 MB to nothing.
        if ($wantSha -ne $gotSha) {
            [void]$changed.Add([pscustomobject]@{
                RelativePath  = $path
                ExpectedBytes = [int64]$e.Bytes
                ActualBytes   = [int64]$onDisk.Bytes
            })
            continue
        }
        $matched++
    }

    $extra = New-Object System.Collections.ArrayList
    foreach ($p in $byPath.Keys) { if (-not $seen.Contains($p)) { [void]$extra.Add($p) } }

    $verdict = 'clean'
    if ($missing.Count -gt 0 -or $changed.Count -gt 0) { $verdict = 'damaged' }

    return [pscustomobject]@{
        Verdict = $verdict
        Matched = $matched
        Missing = @($missing)
        Changed = @($changed)
        Extra   = @($extra | Sort-Object)
    }
}
