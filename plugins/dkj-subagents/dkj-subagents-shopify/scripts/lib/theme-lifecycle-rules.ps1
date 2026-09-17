<#
.SYNOPSIS
    The rules behind the theme ESTATE's lifecycle: which themes this repo owns, what a backup is
    called, when a duplicate has finished filling, which backup rotates out, and which preview themes
    a sweep may remove. Pure -- no CLI, no network, no seam read.

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot:

        . (Join-Path $PSScriptRoot '..\lib\theme-lifecycle-rules.ps1')

    WHY IT IS A LIB OF PURE FUNCTIONS AND NOT LOGIC INSIDE THE TASK SCRIPTS. Every path in those
    scripts either invokes the Shopify CLI against a real store or reads a consumer's repo-config, and
    a suite must not be able to reach a store. preview-theme.ps1 made the same split for the same
    reason and states it in its own header: the parts that CAN be judged without a network live here,
    where scripts/tests/theme-lifecycle-rules.tests.ps1 asserts exact answers.

    THE SOURCE OF THE RULES IS INBOUND #1965, filed from a BWJ store on September 13, 2026. Every
    figure attributed to "the consumer" below was measured THERE, in a store this repo cannot reach --
    it publishes plugins and has no theme estate. They are cited as that consumer's measurements
    rather than restated as facts of this tree, because the difference matters when somebody re-checks
    them.

    ------------------------------------------------------------------------------------------------
    THE ONE THING THAT MAKES THIS FILE DANGEROUS TO GET WRONG: A SWEEP IS A DELETE.

    The consumer's store carries 61 themes -- 1 live and 60 unpublished -- and only about 21 of those
    were created by the repo. The other ~39 belong to other people: a third-party agency's working
    themes under a shared name prefix, CRO test branches created by an external experimentation tool,
    themes an installed app generates under a machine-generated pattern, individual colleagues'
    sandboxes, and a hand-made duplicate of live. A sweep keyed on `role -eq 'unpublished'` would
    destroy every one of them, and it would look CORRECT in a dry run that only counted themes.

    SO THE DELETE SET IS DEFINED BY SOMETHING THIS REPO WROTE, NEVER BY SOMETHING IT RECOGNISES.
    Get-RepoThemePrefix is a reserved namespace the repo puts on the themes it creates; the sweep
    matches on that and on nothing else. The previous key -- "the name looks like a flattened branch
    name" -- cannot serve, and that is measured rather than cautious: several third-party themes on
    that same store are plain hyphenated words, indistinguishable in shape from a branch-derived name,
    and others are branch-shaped but keep the slash, so they look like ours and are not. Identifying a
    delete set by resemblance is guesswork on a destructive operation.

    AND CROSS-CHECKING AGAINST THE REPO'S BRANCH LIST CANNOT BE THE FIRST GATE EITHER, although it is
    a useful second one: a branch deleted after its merge no longer exists locally, which is exactly
    the moment its preview becomes due for sweeping. A key that goes stale in the direction of
    "sweep it" is the wrong way round.
    ------------------------------------------------------------------------------------------------

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# THE RESERVED NAMESPACE, IN ONE PLACE. Every theme this plugin's scripts create carries it, and the
# sweep matches on it -- so a literal spelled at either site would be free to drift, and it would drift
# in the direction that costs most: a sweep that stops recognising its own themes leaves them standing
# (harmless, visible), while a sweep that recognises somebody else's deletes them (irreversible).
#
# A HYPHEN AND NOT A SLASH, because Shopify refuses a theme name containing '/' -- Get-ThemeCreateArgs
# in preview-theme.ps1 throws on exactly that, which is why a branch name has to be flattened before it
# can be one. So the obvious 'dkj/' spelling is unavailable and this is not a style choice.
#
# NOT A SEAM, deliberately, and this repo has written that rule down: a seam nobody can be shown to need
# is a knob every consumer has to read past for an answer they already have. The two stores this serves
# share one plugin and can share one namespace -- that is what the plugin is FOR -- and a per-store
# prefix would let the two drift on the one string the whole guard rests on. It comes back as a seam the
# day somebody measures a store that cannot use it.
$script:RepoThemePrefix = 'dkj-'

function Get-RepoThemePrefix {
    <# The reserved prefix itself, so a test and every caller read one source rather than a copy. #>
    $script:RepoThemePrefix
}

# SHOPIFY'S OWN CEILING ON A THEME NAME (inbound #2055). 50 characters, refused by the platform and not
# by the CLI's argument parsing -- so a name one character over reaches the network and comes back as
# 'Name is too long (maximum is 50 characters)', AFTER the run has already announced which theme it is
# creating. Measured in the consumer that filed it, on branch
# 'liquid/477-continue-browsing-below-model-picker': the composed name is 51 characters.
#
# HERE RATHER THAN AT THE CALLER, for the same reason the prefix is: three call sites compose this name
# and they MUST agree on one string -- push-preview creates the theme, the sweep composes it again for
# the current branch and for every branch still alive in order to SPARE it. A ceiling applied outside
# the builder puts the bound on one of the three and lets the others drift, and that drift is silent in
# the direction that costs most: a preview the sweep composes differently is a preview it does not
# recognise as spared, on a destructive operation.
$script:ShopifyThemeNameMaxLength = 50

# The characters of the discriminator appended to a truncated name, and the reason there is one at all
# is in Get-RepoPreviewThemeName's own docstring.
$script:RepoThemeNameHashChars = 6

function Test-RepoOwnedThemeName {
    <#
    .SYNOPSIS
        Did THIS REPO create the theme with this name? $true only for a name carrying the reserved
        prefix.

    .DESCRIPTION
        CASE-SENSITIVE, AND THAT IS THE OPPOSITE OF Get-ExternalThemeWarning's RULE ONE FILE OVER --
        deliberately, because the two answer opposite questions. That one asks "might this belong to a
        third party?" over names people typed by hand, where capitalisation is noise and a miss means
        a missing warning. This one asks "may I DELETE this?", where the name was written by a script
        that always writes it the same way, and a loose match is what lets somebody else's
        'DKJ-something' into the delete set. When the answers differ, the destructive one takes the
        strict reading.

        A NAME THAT IS NOTHING BUT THE PREFIX IS NOT OWNED. 'dkj-' alone carries no label, so it is
        not a name this repo's composers can ever have produced -- and a bare-prefix theme is far more
        likely to be somebody experimenting than something to delete.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Name)

    $n = ([string]$Name).Trim()
    if (-not $n) { return $false }
    if (-not $n.StartsWith($script:RepoThemePrefix, [System.StringComparison]::Ordinal)) { return $false }
    return ($n.Length -gt $script:RepoThemePrefix.Length)
}

function Get-RepoPreviewThemeName {
    <#
    .SYNOPSIS
        The reserved name for a branch's preview theme: '<prefix><flattened branch name>', shortened
        to Shopify's 50-character ceiling where that does not fit.

    .DESCRIPTION
        THE FLATTENING IS THE CALLER'S AND IS NOT REDONE HERE -- push-preview already has it, from
        Get-BranchInfo's SafeName where the repo has it and a '/'->'-' replace where it does not. What
        this adds is the namespace, and it refuses a name that would be illegal at the CLI rather than
        letting the caller find out from an opaque Shopify error, exactly as Get-ThemeCreateArgs does.

        THE CEILING IS THE SAME CLASS OF RULE AS THE SLASH, FROM THE SAME VENDOR (inbound #2055), and
        it was the one case this function did not cover: an over-long name was composed, handed to the
        creating push, and refused by the platform. It is enforced HERE and not at the caller because
        three call sites compose this name and all three have to agree on one string -- see
        $script:ShopifyThemeNameMaxLength above for what disagreement costs.

        A NAME THAT FITS IS RETURNED UNCHANGED, which is what keeps every preview theme created before
        this landed findable by the lookup and sparable by the sweep. Only an over-long name is
        rewritten, and it is rewritten as:

            <prefix> + <branch part, truncated> + '-' + <6 hex of SHA256(the full over-long name)>

        THE DISCRIMINATOR IS NOT DECORATION. Truncation alone maps every branch sharing a long enough
        head onto ONE theme name, so two branches would push over each other onto a preview that looks
        correct from both -- a wrong theme reviewed as if it were the right one, which is worse than
        the failed push this repairs. Taking the hash from the FULL name rather than from the truncated
        head is what keeps it discriminating; hashing the head would collide exactly where the
        truncation does. SHA256 here is a discriminator and not a security primitive -- the same
        shortened-hex idiom Get-SessionCacheFileName uses one lib over, for the same "short
        deterministic tail in a name" reason.

        IDEMPOTENT ON ITS OWN OUTPUT, which the already-prefixed branch below depends on: what this
        composes fits the ceiling by construction, so handing it back returns it unchanged rather than
        truncating and hashing a second time.

    .PARAMETER MaxLength
        The ceiling, so a consumer can pin the number if Shopify ever moves it. Defaults to the 50 that
        the platform enforces today.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FlatBranchName,
        [int]$MaxLength = $script:ShopifyThemeNameMaxLength
    )

    $n = ([string]$FlatBranchName).Trim()
    if (-not $n) { throw 'Get-RepoPreviewThemeName: -FlatBranchName must not be blank.' }
    if ($n.Contains('/')) {
        throw ("Get-RepoPreviewThemeName: a Shopify theme name may not contain '/': '$n'. Pass the " +
            "FLATTENED branch name -- slashes replaced by dashes.")
    }

    $prefix = $script:RepoThemePrefix
    $hashChars = $script:RepoThemeNameHashChars
    # A CEILING TOO SMALL TO HOLD THE NAMESPACE AND THE DISCRIMINATOR CANNOT BE HONOURED, and silently
    # returning something over it would defeat the whole point of the parameter. At least one character
    # of the branch part has to survive, or the name carries no label at all and Test-RepoOwnedThemeName
    # would not even call it ours.
    $floor = $prefix.Length + $hashChars + 2
    if ($MaxLength -lt $floor) {
        throw ("Get-RepoPreviewThemeName: -MaxLength $MaxLength cannot hold the reserved prefix " +
            "'$prefix' plus a $hashChars-character discriminator and at least one character of the " +
            "branch name; $floor is the smallest workable ceiling.")
    }

    # ALREADY-PREFIXED IS NOT PREFIXED TWICE. A caller that has been through a name lookup may hand back
    # the name it found, and 'dkj-dkj-feat-x' would be a theme neither the lookup nor the sweep
    # recognises -- an orphan, on a store with a finite ceiling.
    $full = if (Test-RepoOwnedThemeName -Name $n) { $n } else { $prefix + $n }
    if ($full.Length -le $MaxLength) { return $full }

    $keep = $MaxLength - $prefix.Length - 1 - $hashChars
    $head = $full.Substring($prefix.Length, $keep)
    # A TRUNCATION LANDING ON A SEPARATOR would produce 'dkj-feat-x--a1b2c3'. Trimming is cosmetic and
    # deterministic, and it is skipped where it would leave nothing, so the name always keeps a label.
    $trimmed = $head.TrimEnd('-')
    if ($trimmed) { $head = $trimmed }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($full))
    } finally {
        $sha.Dispose()
    }
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return ($prefix + $head + '-' + $hex.Substring(0, $hashChars))
}

function Get-BackupThemeName {
    <#
    .SYNOPSIS
        The reserved name for a backup of the live theme: '<prefix>backup-<yyyyMMdd-HHmmss>'.

    .DESCRIPTION
        THE TIMESTAMP IS IN THE NAME AND IS NOT DECORATION. Rotation keeps exactly one backup, so the
        two that exist during a rotation have to be distinguishable by name alone at the moment the
        second is created -- before either has an id the caller has read back. It is also the only
        thing that says WHEN the baseline was taken, which is the whole content of the answer "what
        did live look like at the last release".

        SORTABLE RATHER THAN READABLE, and that is the trade taken on purpose: 'yyyyMMdd-HHmmss' sorts
        lexically in time order, so Get-BackupRotationPlan can order candidates without parsing a date
        out of a name a person may have edited.

        -Timestamp IS A PARAMETER AND NOT A [datetime]::Now CALL. A function that reads the clock
        cannot be asserted against an exact string, and this one's whole output is a string a
        destructive rotation then matches on.
    #>
    param([Parameter(Mandatory = $true)][datetime]$Timestamp)
    return ('{0}backup-{1}' -f $script:RepoThemePrefix, $Timestamp.ToString('yyyyMMdd-HHmmss'))
}

function Test-BackupThemeName {
    <# Is this one of OUR backups? Owned by this repo AND carrying the backup label. A repo-owned
       preview is not a backup and must never rotate out under one. #>
    param([AllowEmptyString()][AllowNull()][string]$Name)

    if (-not (Test-RepoOwnedThemeName -Name $Name)) { return $false }
    $rest = ([string]$Name).Trim().Substring($script:RepoThemePrefix.Length)
    return $rest.StartsWith('backup-', [System.StringComparison]::Ordinal)
}

function Get-ThemeFillVerdict {
    <#
    .SYNOPSIS
        Has a freshly duplicated theme finished filling? Returns an object with Verdict
        ('complete' / 'filling' / 'short' / 'unknown'), Reason, and the file count it settled on.

    .DESCRIPTION
        THIS IS THE SINGLE MOST IMPORTANT CORRECTNESS POINT IN #1965, AND IT IS THE ONE A CALLER
        WOULD NOT THINK TO ASK. 'shopify theme duplicate' returns LONG BEFORE the copy is complete.
        Measured in the consumer on September 13, 2026 while preparing an unrelated procedure: a
        duplicate of the live theme grew 38 -> 538 -> 738 -> 833 files over roughly eight minutes.

        So a backup step that creates the duplicate and reports success is reporting on a theme that
        may hold a fraction of the files it is meant to protect -- and the failure is SILENT, because
        the theme exists, is correctly named, and has the right role. Nothing about it looks wrong
        until somebody needs it. A backup nobody verified is worse than no backup, because it is
        relied on.

        TWO CONDITIONS, AND BOTH ARE REQUIRED. Stability alone is not completeness: the count is also
        stable in the first seconds, before the copy has started moving. Completeness alone is not
        stability either, since a count can pass through the source's number on its way somewhere
        else. So the verdict is 'complete' only when the last samples AGREE and the settled count has
        reached the source's.

        'short' IS A REFUSAL AND NOT A WARNING, and the caller is expected to treat it as one. A
        stable count BELOW the source means the copy stopped early -- the one state where the theme
        looks finished and is not, which is precisely what this function exists to name.

        THE SOURCE COUNT MAY BE UNKNOWN, and then the honest answer is 'unknown' rather than a
        cheerful 'complete'. A caller that could not read the source's file count has not measured
        anything, and a verdict that pretended otherwise would put this function's name on a guess.

        SAMPLES COME IN OLDEST-FIRST, and the two compared are the LAST two -- the caller polls and
        appends, so the newest is the end of the list.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][int[]]$Samples,
        [int]$SourceFileCount = -1,
        [int]$StableSamples = 2
    )

    $s = @($Samples)
    if ($s.Count -eq 0) {
        return [pscustomobject]@{ Verdict = 'unknown'; Reason = 'no file counts were sampled'; Count = -1 }
    }

    $count = $s[$s.Count - 1]

    if ($StableSamples -lt 2) { $StableSamples = 2 }
    if ($s.Count -lt $StableSamples) {
        return [pscustomobject]@{ Verdict = 'filling'; Reason = "only $($s.Count) sample(s) so far -- $StableSamples are needed before a count counts as settled"; Count = $count }
    }

    # THE LAST $StableSamples MUST ALL AGREE. Comparing only the newest pair would call a copy settled
    # across a single flat moment, and the measured growth was in bursts with pauses between them.
    $tail = $s[($s.Count - $StableSamples)..($s.Count - 1)]
    foreach ($v in $tail) {
        if ($v -ne $count) {
            return [pscustomobject]@{ Verdict = 'filling'; Reason = "the file count is still moving (last $StableSamples samples: $($tail -join ', '))"; Count = $count }
        }
    }

    if ($SourceFileCount -lt 0) {
        return [pscustomobject]@{ Verdict = 'unknown'; Reason = "the count settled at $count, but the source theme's file count is not known, so completeness cannot be judged"; Count = $count }
    }

    if ($count -lt $SourceFileCount) {
        return [pscustomobject]@{ Verdict = 'short'; Reason = "the copy settled at $count file(s) and the source has $SourceFileCount -- it stopped early, and a theme that looks finished and is not is the failure this check exists for"; Count = $count }
    }

    return [pscustomobject]@{ Verdict = 'complete'; Reason = "settled at $count file(s), matching the source"; Count = $count }
}

function Get-ThemeSweepPlan {
    <#
    .SYNOPSIS
        Which of these themes may a preview sweep remove? Returns one verdict object per theme --
        Id, Name, Sweep (bool) and Reason -- for EVERY theme handed in, not only the removable ones.

    .DESCRIPTION
        EVERY THEME GETS A ROW, INCLUDING THE ONES THAT STAY, and that is the design rather than
        verbosity. A destructive step's dry run has to be readable as "here is what I looked at and
        why each one lives", because a summary that lists only the delete set is unfalsifiable: the
        39 third-party themes it must never touch are exactly the rows it would not print.

        THE ORDER OF THE TESTS IS THE SAFETY PROPERTY. Ownership is asked FIRST, so a theme this repo
        did not create never reaches the live-id or role questions at all -- it is out on the one
        ground that cannot go stale. The live checks then run on what is left, doubled by id and by
        role for the reason theme-archive-rules.ps1 already gives: the id is what repo-config says is
        live and the role is what the STORE says is live, and the day they disagree is the day one of
        them is the only thing standing in the way.

        A BACKUP IS NEVER SWEPT HERE, and that is a bound rather than an oversight. The backup is
        repo-owned, so ownership alone would admit it -- and rotation is the ONLY thing permitted to
        remove one, at the cut, after its replacement has been verified. Two mechanisms allowed to
        delete the same theme is how a store ends up with no backup at all.

        -KeepNames IS THE CURRENT BRANCH'S OWN PREVIEW (plus whatever an operator names by hand with
        -Keep), and it is a parameter rather than a lookup because this file reads nothing. Sweeping
        the preview of the branch you are standing on is legal by every other rule here and is almost
        never what was meant.

        -LivingBranchNames IS EVERY OTHER BRANCH THAT IS STILL ALIVE, and it is deliberately a second,
        separate parameter rather than folded into -KeepNames. INBOUND #2032: the original design spared
        only the branch the run happens to stand on, so a parked branch on the remote -- carrying work
        that exists nowhere else -- had its preview swept exactly like a merged one, the one round where
        that is not recoverable. "Still exists" is read deliberately WIDE by the caller (local ref or
        remote ref, without asking whether a PR merged), because `deleteBranchOnMerge` already removes a
        merged branch's ref -- a branch still standing is parked work or a cleanup that has not run yet,
        and sparing it one round too long costs a theme slot rather than a branch's only copy of its
        work. Kept as its own test with its own reason so a kept row here reads as "this branch is still
        alive" and not as "this is the branch you are standing on", which would be false for every row
        but one.

        THE THIRD-PARTY PREFIXES ARE READ TOO, even though ownership already excludes those themes.
        It is belt and braces on the one class where being wrong is unrecoverable, and it costs a
        string compare: if a third party ever adopts a name that starts with this repo's reserved
        prefix, the sweep refuses instead of resolving the collision in favour of deletion.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Themes,
        [AllowEmptyString()][string]$LiveThemeId = '',
        [AllowNull()][string[]]$KeepNames = @(),
        [AllowNull()][string[]]$LivingBranchNames = @(),
        [AllowNull()][string[]]$ExternalPrefixes = @()
    )

    $live = ([string]$LiveThemeId).Trim()
    $keep = @(@($KeepNames) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim() })
    $living = @(@($LivingBranchNames) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim() })
    $plan = @()

    foreach ($t in @($Themes)) {
        if ($null -eq $t) { continue }

        $id   = ([string]$t.id).Trim()
        $name = ([string]$t.name).Trim()
        $role = ([string]$t.role).Trim().ToLower()

        $verdict = {
            param($Sweep, $Reason)
            [pscustomobject]@{ Id = $id; Name = $name; Role = $role; Sweep = $Sweep; Reason = $Reason }
        }

        if (-not $id) { $plan += (& $verdict $false 'no theme id -- nothing that cannot be named can be deleted'); continue }

        # 1. OWNERSHIP FIRST. The ~39 themes this repo did not create leave here.
        if (-not (Test-RepoOwnedThemeName -Name $name)) {
            $plan += (& $verdict $false "not created by this repo -- no '$($script:RepoThemePrefix)' prefix")
            continue
        }

        # 2. A BACKUP IS ROTATION'S, NEVER THE SWEEP'S.
        if (Test-BackupThemeName -Name $name) {
            $plan += (& $verdict $false 'this is the live-theme backup -- only the release cut rotates it, and only after its replacement is verified')
            continue
        }

        # 3. THE LIVE THEME, BY ID AND BY ROLE. Neither alone survives an estate that changed.
        if (-not $live) {
            $plan += (& $verdict $false 'no live theme id known -- refusing to sweep while it is unknown which theme is live')
            continue
        }
        if ($id -eq $live) {
            $plan += (& $verdict $false "this is the live theme ($live)")
            continue
        }
        if ($role -eq 'live' -or $role -eq 'main') {
            $plan += (& $verdict $false "the STORE reports role '$role' -- live by the store's own answer, whatever the configured id says")
            continue
        }

        # 4. ROLE MUST BE THE ONE WE EXPECT. Not-unpublished is not merely unexpected: a development
        #    theme belongs to whoever is running `shopify theme dev` right now.
        if ($role -ne 'unpublished') {
            $plan += (& $verdict $false "role is '$role', not 'unpublished' -- the sweep removes spent previews, and anything else is somebody's working theme")
            continue
        }

        # 5. THE BRANCH YOU ARE STANDING ON.
        if ($keep -contains $name) {
            $plan += (& $verdict $false 'this is the current branch''s own preview')
            continue
        }

        # 6. ANY OTHER BRANCH THAT IS STILL ALIVE. Inbound #2032: a parked branch on the remote, with no
        #    PR and no other copy of its work, is exactly the kind of preview a current-branch-only spare
        #    swept.
        if ($living -contains $name) {
            $plan += (& $verdict $false 'the branch still exists')
            continue
        }

        # 7. BELT AND BRACES on the unrecoverable class.
        $external = Get-ExternalPrefixHit -Name $name -ExternalPrefixes $ExternalPrefixes
        if ($external) {
            $plan += (& $verdict $false "the name also matches the third-party prefix '$external' -- refusing rather than resolving a namespace collision in favour of deleting")
            continue
        }

        $plan += (& $verdict $true 'a spent preview theme created by this repo')
    }

    return ,@($plan)
}

function Get-ExternalPrefixHit {
    <# Which third-party prefix this name starts with, or '' for none. Internal to this lib.

       Get-ExternalThemeWarning in theme-archive-rules.ps1 answers the same question and returns a
       SENTENCE, which is right for the warning it prints above a command a person is about to paste.
       A verdict row needs the prefix itself, so this returns that rather than parsing it back out of
       prose. Case-insensitive, matching that function: these prefixes name vendors and are typed by
       people. #>
    param(
        [AllowEmptyString()][string]$Name = '',
        [AllowNull()][string[]]$ExternalPrefixes = @()
    )

    $n = ([string]$Name).Trim()
    if (-not $n) { return '' }
    foreach ($raw in @($ExternalPrefixes)) {
        if ($null -eq $raw) { continue }
        $p = ([string]$raw).Trim()
        if (-not $p) { continue }
        if ($n.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $p }
    }
    return ''
}

function Get-BackupRotationPlan {
    <#
    .SYNOPSIS
        Which backups rotate out now that -KeepId has been created and verified? Returns one row per
        backup theme -- Id, Name, Delete (bool), Reason.

    .DESCRIPTION
        EXACTLY ONE BACKUP IS RETAINED, and the cut is what rotates it. The ORDER is create -> verify
        -> only then delete, so there is never a window in which the store holds no backup at all;
        that costs one theme slot transiently and is the whole reason rotation is a separate step
        from creation rather than a flag on it.

        SO THIS FUNCTION REFUSES TO PLAN ANYTHING WITHOUT -KeepId. An empty keep-id is the signature
        of a caller whose create or verify step did not reach a usable theme, and the tempting
        reading -- "nothing to keep, so rotate everything" -- is the one that empties the store's only
        backup after a failed run. Refusing costs a stale backup; proceeding costs every backup.

        IT ALSO REFUSES WHEN -KeepId IS NOT AMONG THE BACKUPS IT WAS GIVEN. That means the caller and
        the store disagree about what exists, and a delete list computed from a list that does not
        contain the survivor is a delete list for everything.

        A THEME THAT IS NOT ONE OF OUR BACKUPS IS NOT IN THE PLAN AT ALL -- not as a 'keep' row, not
        as anything. Rotation's subject is the backup namespace and nothing else; previews are the
        sweep's, and every other theme is somebody's.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Themes,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$KeepId
    )

    $keep = ([string]$KeepId).Trim()
    if (-not $keep) {
        throw ('Get-BackupRotationPlan: -KeepId is empty. Nothing rotates until the replacement backup ' +
            'exists and has been VERIFIED complete -- an empty keep-id is what a failed create or a ' +
            'short copy looks like from here, and rotating on it would leave the store with no backup.')
    }

    $backups = @(@($Themes) | Where-Object { $_ -and (Test-BackupThemeName -Name ([string]$_.name)) })
    $survivor = @($backups | Where-Object { ([string]$_.id).Trim() -eq $keep })
    if ($survivor.Count -eq 0) {
        throw ("Get-BackupRotationPlan: -KeepId '$keep' is not among the backup themes given. The caller " +
            'and the store disagree about what exists, and a rotation computed from that list would ' +
            'delete every backup there is. Re-read the theme list before rotating.')
    }

    $plan = @()
    foreach ($b in $backups) {
        $id   = ([string]$b.id).Trim()
        $name = ([string]$b.name).Trim()
        if ($id -eq $keep) {
            $plan += [pscustomobject]@{ Id = $id; Name = $name; Delete = $false; Reason = 'the backup just created and verified -- this is the one that is retained' }
        } else {
            $plan += [pscustomobject]@{ Id = $id; Name = $name; Delete = $true; Reason = 'the previous backup -- exactly one is retained, and the cut is what rotates it' }
        }
    }

    return ,@($plan)
}

function Get-CutOrderWarning {
    <#
    .SYNOPSIS
        The warning a backup run prints when the estate says it is being run in the order that makes
        the backup mean something other than what the policy says it means. '' when it is not.

    .DESCRIPTION
        THE ORDER DECIDES WHAT THE BACKUP IS, AND THE TWO ANSWERS ARE BOTH DEFENSIBLE -- which is
        exactly why a run that cannot tell which one it is in is worth a line of output.

        THIS WORKFLOW RUNS PUSH-THEN-CUT, and cut-release's own skill page argues for it on this
        target type: a Shopify live theme has no locking, third parties edit it through the theme
        editor while you work, and a live push is per-file rather than wholesale -- so cutting first
        risks a STRANDED RELEASE, a tag and a Release describing a state no customer ever saw, which
        nothing detects. Under that order the backup taken at the cut is the clean BASELINE of what
        actually shipped, which is the thing sync-main's whole existence implies a store needs: the
        point third-party drift is measured from until the next release. Dave, September 14, 2026, on
        inbound #1965.

        SO THE SIGNATURE OF THE WRONG ORDER IS AN UNPUSHED TRUNK. If the trunk has not reached live,
        the cut is happening first, and the backup is then a rollback point for a push that has not
        happened -- a different and also useful thing, but not what the policy page describes and not
        what the next reader will assume the theme holds.

        IT WARNS AND DOES NOT REFUSE, and that asymmetry is deliberate. The backup itself is correct
        and useful under either order -- nothing about the copy is wrong -- so refusing would block a
        harmless act to enforce a sentence. What is at risk is only the READING of the artefact, and
        a line of output is the proportionate answer to that. The destructive halves of this
        mechanism -- rotation and the sweep -- refuse rather than warn, and they are the ones that
        can take something away.
    #>
    param([AllowNull()][bool]$TrunkIsLive = $true)

    if ($TrunkIsLive) { return '' }
    return ('ORDER: the trunk has NOT been pushed to live yet, so this backup is being taken BEFORE ' +
        'the push rather than as the closing step of it. It is still a valid copy -- but this workflow ' +
        'runs push-then-cut, where the backup is the baseline of WHAT SHIPPED. Taken now it is a ' +
        'rollback point for a push that has not happened, which is not what the policy page says this ' +
        'theme holds. See dkj-policy-bwj/THEME-LIFECYCLE-portable.md.')
}
