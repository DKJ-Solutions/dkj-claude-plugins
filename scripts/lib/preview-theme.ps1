<#
.SYNOPSIS
    The 'shopify theme push' argument lists push-preview.ps1 hands to the CLI, the flag whitelist in
    front of them, the two pure readers of the CLI's own output, and the two composers that turn a theme
    id into what the operator actually reads -- the preview URL and the handover note under a list of
    them. Since #2348 also the 'shopify theme duplicate' call a new preview is created with, and the
    notice about the per-market settings files no push can deliver.

.DESCRIPTION
    WHY THIS LIB EXISTS AT ALL. A consumer's push-preview built its create call inline as
    '--unpublished --theme-name <name>'. There is no --theme-name flag in the Shopify CLI -- the name of
    a new unpublished theme is passed with --theme, the same flag an existing theme's id uses. The call
    failed with 'Nonexistent flag: --theme-name' the FIRST time anybody needed a preview theme created,
    on 2026-08-21: the lazy-create path had been written the day before and no branch had wanted a preview
    theme in between. Nothing was wrong with the reasoning; the code had simply never run. A script whose
    only untested path is the one that runs once per branch breaks in front of the person who needed it
    most. Inbound #805.

    SO THE ARGUMENT LIST IS BUILT HERE, BY A FUNCTION, and checked against a flag whitelist measured off
    'shopify theme push --help'. A misspelled or invented flag now fails with a message that names the
    flag and says where the list came from, instead of a CLI error halfway through a run. The whitelist
    earned its place on its first run in the consumer: it refused the lib's own call because --unpublished
    had been left out of the list. Same class of error, caught in three seconds instead of a day.

    WHAT THE WHITELIST ANSWERS, AND WHAT IT DELIBERATELY DOES NOT. It answers "is this a real CLI flag",
    never "may this repo use it" -- so it ADMITS --allow-live. Refusing a live push is the live-theme
    guard's job (dkj-subagents-shopify's PreToolUse hook), and a validator answering both questions would give two
    different answers to the same one.

    WHAT THIS DELIBERATELY DOES NOT DO. It runs nothing. It builds and validates argument lists and reads
    the CLI's output; push-preview.ps1 invokes them. That split is the whole reason it is testable without
    a store, a network or a theme -- see scripts/tests/push-preview.tests.ps1.

    WHAT STAYS IN THE CONSUMER. Which theme is live (Get-ShopifyLiveThemeId), the store domain
    (Get-ShopifyStoreDomain), the branch-to-theme-name mapping, and the market/locale table a
    multi-market store prints preview URLs from (the optional Get-ShopifyPreviewUrls seam). The last of
    those is genuinely per-store rather than merely unshared: one consumer runs one domain with
    locale-prefixed paths, another runs five separate domains, so a shared table would have produced four
    domains that do not exist.

    No Set-StrictMode here: dot-sourcing would modify the calling script's strict mode.
    Pure ASCII (repo convention for .ps1).
#>

# Measured from 'shopify theme push --help' on 2026-08-21, CLI 3.94.3. Long forms only: the scripts never
# write short forms, and accepting '-t' here would let a typo like '-tt' through on a technicality.
# WHEN THE CLI CHANGES, RE-MEASURE RATHER THAN EDIT FROM MEMORY -- that command prints the whole set:
#   shopify theme push --help
# A test cannot tell a stale whitelist from a correct one, which is why the instruction lives here.
$script:ThemePushFlags = @(
    '--allow-live',
    '--development',
    '--development-context',
    '--environment',
    '--ignore',
    '--json',
    '--listing',
    '--live',
    '--no-color',
    '--nodelete',
    '--only',
    '--password',
    '--path',
    '--publish',
    '--store',
    '--strict',
    '--theme',
    '--unpublished',
    '--verbose'
)

# The three query parameters the Shopify admin itself hangs on a preview link. Without them the preview
# holds only through the cookie and is lost at the first internal link -- and then you are silently
# looking at live while believing you are looking at the preview. A consumer lost a whole review to that
# on 2026-08-05, which is why these travel with the plugin rather than being each repo's discovery.
$script:ThemePreviewQuery = '_ab=0&_fd=0&_sc=1'

function Get-ThemePushFlags {
    <# The whitelist itself, so a test can hold it against the CLI rather than against a copy. #>
    $script:ThemePushFlags
}

function Test-ThemePushArgs {
    <# Throws when an argument that LOOKS like a flag is not one 'shopify theme push' accepts. Returns
       $true otherwise, so a caller can write '$null = Test-ThemePushArgs -Arguments $a' and have the run
       stop before the CLI is invoked. Only '--*' tokens are judged: a VALUE that happens to start with a
       dash is a value. #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Arguments)

    $unknown = @($Arguments | Where-Object { $_ -like '--*' } |
        Where-Object { $script:ThemePushFlags -notcontains $_ })

    if ($unknown.Count -gt 0) {
        throw ("Not a 'shopify theme push' flag: " + ($unknown -join ', ') +
            ". The accepted set was measured from 'shopify theme push --help' (CLI 3.94.3) and lives in " +
            "the preview-theme lib; re-measure with that command rather than guessing.")
    }
    $true
}

function Get-ThemeCreateArgs {
    <# The call that CREATES a new unpublished theme and pushes the working tree to it in one go.
       --unpublished creates it; --theme carries the NAME (not an id) for a theme that has none yet.
       That double duty of --theme is exactly what the retired --theme-name spelling got wrong.

       THE FALLBACK SINCE #2348, NOT THE ROUTE. A theme created this way never receives
       config/settings_data.context.*.json (see Get-ThemeDuplicateArgs), so push-preview creates by
       duplicating live and reaches for this only where the live id is unanswered and there is nothing
       to copy from -- saying so, rather than refusing a preview over it. #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeName
    )

    # Shopify rejects a theme name containing '/', which is the whole reason a branch name has to be
    # flattened before it can be one. A caller that passes the raw branch name would otherwise get an
    # opaque CLI error, so the remedy is named here instead.
    if ($ThemeName.Contains('/')) {
        throw ("A Shopify theme name may not contain '/': '$ThemeName'. Pass the flattened form -- the " +
            "branch with its slashes replaced by dashes (Get-BranchInfo's SafeName, where the repo has it).")
    }
    if ([string]::IsNullOrWhiteSpace($ThemeName)) { throw "Get-ThemeCreateArgs: -ThemeName must not be blank." }

    $a = @('theme', 'push', '--store', $Store, '--unpublished', '--theme', $ThemeName, '--json')
    $null = Test-ThemePushArgs -Arguments $a
    $a
}

function Get-ThemeUpdateArgs {
    <# The call that pushes to a theme that ALREADY exists, by id. No --json: the caller reads the exit
       code and prints the preview URLs itself, and --json here would only hide the CLI's progress. #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId
    )

    # A NAME PASSED WHERE AN ID BELONGS is the mistake that would silently create a SECOND theme, so this
    # insists on digits rather than trusting the caller.
    if ($ThemeId -notmatch '^\d+$') {
        throw ("Get-ThemeUpdateArgs: -ThemeId must be all digits, got '$ThemeId'. A NAME goes through " +
            "Get-ThemeCreateArgs; this function is for an id that already exists.")
    }

    $a = @('theme', 'push', '--store', $Store, '--theme', $ThemeId)
    $null = Test-ThemePushArgs -Arguments $a
    $a
}

# Measured from 'shopify theme duplicate --help' on 2026-09-23, CLI 4.8.0. The same rule as the push list
# above: long forms only, and re-measure with that command rather than editing from memory.
$script:ThemeDuplicateFlags = @(
    '--auth-alias',
    '--environment',
    '--force',
    '--json',
    '--name',
    '--no-color',
    '--password',
    '--store',
    '--theme',
    '--verbose'
)

# THE FILES 'theme push' CANNOT DELIVER (#2348). Relative, with '/', the form 'git diff --name-only' gives.
$script:ContextSettingsPattern = '^config/settings_data\.context\.([^./]+)\.json$'

function Get-ThemeDuplicateFlags {
    <# The duplicate whitelist itself, so a test can hold it against the CLI rather than against a copy. #>
    $script:ThemeDuplicateFlags
}

function Get-ThemeDuplicateArgs {
    <# The call that CREATES a new preview theme as a server-side copy of the live one (#2348).

       WHY A COPY AND NOT 'theme push --unpublished'. Measured in a consumer on 2026-09-23 against CLI
       4.8.0, and read in the CLI's own source: the push partitions files into upload buckets, and
       config/settings_data.context.<market>.json fits none of them -- configDataRegex is the exact
       '^config/settings_data\.json$' and jsonRegex is '^(?!config/).*\.json$', which excludes config/.
       So the file is listed under "Files to be uploaded", never sent, and the push reports success. That
       holds for EVERY push, not only the creating one, so no push can put those bytes on a theme; a
       duplicate copies every file server-side, and the full push that follows leaves the ones it cannot
       upload standing (it does not delete them either, since they exist locally). The preview then
       carries the branch plus live's per-market settings -- the state a reviewer compares against.

       --force AND --theme ARE BOTH REQUIRED WITHOUT A TTY ("Required if non interactive"), the lesson
       backup-live-theme.ps1 learned first (#2031). --json because the caller reads the new id out of it. #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$SourceThemeId,
        [Parameter(Mandatory = $true)][string]$ThemeName
    )
    if ($SourceThemeId -notmatch '^\d+$') {
        throw ("Get-ThemeDuplicateArgs: -SourceThemeId must be all digits, got '$SourceThemeId'. The source " +
            "is the live theme's id (Get-ShopifyLiveThemeId), never a name.")
    }
    if ([string]::IsNullOrWhiteSpace($ThemeName)) { throw "Get-ThemeDuplicateArgs: -ThemeName must not be blank." }
    if ($ThemeName.Contains('/')) {
        throw ("A Shopify theme name may not contain '/': '$ThemeName'. Pass the flattened form -- the " +
            "branch with its slashes replaced by dashes (Get-BranchInfo's SafeName, where the repo has it).")
    }

    $a = @('theme', 'duplicate', '--store', $Store, '--theme', $SourceThemeId, '--name', $ThemeName, '--force', '--json')
    $unknown = @($a | Where-Object { $_ -like '--*' } | Where-Object { $script:ThemeDuplicateFlags -notcontains $_ })
    if ($unknown.Count -gt 0) {
        throw ("Not a 'shopify theme duplicate' flag: " + ($unknown -join ', ') +
            ". The accepted set was measured from 'shopify theme duplicate --help' (CLI 4.8.0).")
    }
    $a
}

function Test-ContextSettingsPath {
    <# Is this one of the files 'theme push' silently skips -- config/settings_data.context.<market>.json? #>
    param([AllowEmptyString()][AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    return (($Path -replace '\\', '/') -match $script:ContextSettingsPattern)
}

function Get-ContextSettingsMarkets {
    <# The market names the working tree carries a config/settings_data.context.<market>.json for, sorted.
       Reads the disk and nothing else. Empty in a repo that runs no per-market settings, which is what
       keeps every notice below silent there. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $dir = Join-Path $RepoRoot 'config'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    $markets = foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Filter 'settings_data.context.*.json')) {
        $m = [regex]::Match("config/$($f.Name)", $script:ContextSettingsPattern)
        if ($m.Success) { $m.Groups[1].Value }
    }
    return @($markets | Sort-Object)
}

function Get-PreviewSettingsNotice {
    <# The lines push-preview prints after a push about the per-market settings; empty means nothing to say.

       -FillState is what this checkout's git config records about the preview theme:
         'complete' -- created here as a copy of live and verified filled;
         'short'    -- created as a copy, but the copy settled below live's file count;
         ''         -- no record: a theme created before #2348 (by 'push --unpublished'), created on
                       another machine, or created without a live id to copy from.
       -Markets are the markets the working tree carries a context-settings file for.
       -ChangedContextFiles are the context-settings files THIS branch changes against the trunk.

       TWO SEPARATE FACTS, AND EITHER CAN BE TRUE ALONE. A theme that lacks the per-market settings renders
       every market with the global ones, so a reviewer comparing it with live sees differences the branch
       did not cause. And a branch that changes such a file will not see that change on ANY preview,
       because no push can deliver it -- the preview shows live's values, or none. #>
    param(
        [AllowEmptyString()][AllowNull()][string]$FillState = '',
        [AllowEmptyCollection()][string[]]$Markets = @(),
        [AllowEmptyCollection()][string[]]$ChangedContextFiles = @()
    )
    $lines = @()
    $marketList = (@($Markets) -join ', ')

    if ($FillState -ne 'complete' -and @($Markets).Count -gt 0) {
        if (-not $FillState) {
            $lines += "NOTE: this checkout has no record that this preview was created as a copy of live, so it"
            $lines += "  may not carry the per-market settings ($marketList)."
            $lines += '  A preview created by a plain push never gets them: theme push silently skips'
            $lines += '  config/settings_data.context.*.json (#2348), so every market would render with the global'
            $lines += '  settings and may differ from live without this branch causing it. Say so in the handover,'
            $lines += '  or remove this preview and run push-preview again -- a new one is created as a copy of live.'
        } else {
            $lines += "NOTE: the copy of live was not verified complete ($FillState), so the per-market settings"
            $lines += "  ($marketList) may be missing from it. The branch itself was pushed in full; do not compare"
            $lines += '  the per-market behaviour with live blindly.'
        }
    }

    if (@($ChangedContextFiles).Count -gt 0) {
        $lines += 'NOTE: this branch changes per-market settings that theme push cannot upload:'
        foreach ($f in $ChangedContextFiles) { $lines += "  - $f" }
        $lines += '  The preview shows LIVE''s values for those markets, not this branch''s. Do not judge that'
        $lines += '  change on the preview; name it in the handover.'
    }
    return $lines
}

function Get-ThemeIdFromPushOutput {
    <# The id of the theme 'theme push --unpublished --json' or 'theme duplicate --json' just created, or ''
       where the output carries none. Pure string in, string out.

       ITS OWN FUNCTION BECAUSE IT IS THE HALF THAT CANNOT BE RE-RUN. The create call pushes at the same
       time it creates, so a missed id means the next run cannot find the theme by id and falls back to a
       name lookup -- recoverable, but only because the fallback exists. Parsing it inline left the one
       expression nobody could test without a store. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Output)
    $m = ([regex]'"id"\s*:\s*(\d+)').Match($Output)
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Get-ThemeByName {
    <# The theme with this exact name out of 'shopify theme list --json' output, already parsed from JSON.
       Returns $null where none matches, and THROWS where more than one does -- two themes of one name is
       an estate problem the caller has to resolve with an explicit id, not a coin flip.

       THE WRAPPER TEST IS ON THE PROPERTY, NOT ON TRUTHINESS, and that is a measured trap rather than
       style. '$array.themes' does member enumeration in PowerShell 5.1 and yields an array with a $null
       per element; that array is not empty and is therefore truthy, so a bare 'if ($parsed.themes)'
       throws away the right list. A consumer hit exactly this on 2026-08-04 and its name lookup then
       always reported 'no preview theme found'. #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Parsed,
        [Parameter(Mandatory = $true)][string]$ThemeName
    )
    if ($null -eq $Parsed) { return $null }
    $themes = $Parsed
    if ($themes -isnot [System.Array] -and $themes.PSObject.Properties.Name -contains 'themes') {
        $themes = $themes.themes
    }
    $hit = @(@($themes) | Where-Object { $_ -and $_.name -eq $ThemeName })
    if ($hit.Count -gt 1) {
        throw "More than one theme is called '$ThemeName' -- pass an explicit -ThemeId rather than letting this guess."
    }
    if ($hit.Count -eq 0) { return $null }
    return $hit[0]
}

function Get-ThemePreviewUrl {
    <# The one preview URL every store has: the store's own domain with preview_theme_id, carrying the
       three parameters the admin itself adds.

       THIS IS THE GENERAL HALF OF A JOB WHOSE OTHER HALF IS NOT. A multi-market store wants one URL per
       market or locale, and that table is genuinely per-store -- so it stays behind the optional
       Get-ShopifyPreviewUrls seam. What is NOT per-store is that a preview link needs those three
       parameters to survive the first internal click, and a repo without the seam should still get a link
       that works rather than none at all. #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [string]$Path = '/'
    )
    if (-not $Path) { $Path = '/' }
    if (-not $Path.StartsWith('/')) { $Path = '/' + $Path }
    # A SEAM ANSWER IS TAKEN AS GIVEN AND NORMALISED ANYWAY: a repo may state its store as a bare domain,
    # with a scheme, or with a trailing slash, and none of those is wrong -- but concatenating them
    # unexamined yields 'https://https://x//'.
    $domain = ($Store -replace '^https?://', '') -replace '/+$', ''
    # Built by concatenation rather than interpolation: '$Path?' reads badly next to PowerShell's own '$?'
    # and the query is assembled from three parts anyway.
    return 'https://' + $domain + $Path + '?preview_theme_id=' + $ThemeId + '&' + $script:ThemePreviewQuery
}

function Get-PreviewHandoverNote {
    <# The closing note a MULTI-URL preview push prints under its list -- inbound #1873.

       WHY THE SCRIPT SAYS THIS AT ALL, rather than a policy page saying it somewhere. Both BWJ store
       repos handed a reviewer a markdown table of ten preview URLs (five markets by two page types) that
       the terminal wrapped into unreadability and a phone could not scan. A rule written on a page that
       nothing loads at the moment a preview is pushed loses to this printed list every time, because the
       list is what a session has in front of it when it composes the handover.

       AND IT STAYS GENERIC, naming no repo and no workflow. What is true in every multi-market Shopify
       repo is that a wrapped column of 90-character URLs is not a handover and that the reviewer is on a
       phone. What the handover IS instead is a house rule -- BWJ states it in dkj-policy-bwj's
       PREVIEW-HANDOVER-portable.md -- so this points at whatever the repo's own workflow says rather than
       at a page most consumers do not have.

       SILENT ON ONE URL, and the count is the honest trigger rather than a threshold picked for quiet: a
       single line in a terminal genuinely is a usable handover, and there is nothing to carry. #>
    param([Parameter(Mandatory = $true)][int]$Count)
    if ($Count -lt 2) { return $null }
    return @(
        "$Count preview URLs -- this list is raw material, not the handover.",
        "  A reviewer gets ONE link to a page carrying these, never a table: a terminal wraps URLs this",
        "  long and a phone cannot scan them, and storefront work is judged on a phone.",
        "  Where your workflow states how a preview is handed over, that page is the rule."
    )
}
