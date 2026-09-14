<#
.SYNOPSIS
    One answer to "which plugins does this repo publish, and where do they live".

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')

    THE MARKETPLACE IS THE ONLY PLACE THAT KNOWS. A repo that publishes plugins declares them in
    .claude-plugin/marketplace.json -- a name and a repo-relative source per plugin -- and every other
    statement about the set is a copy of that one. Before this lib there were five such copies, each
    with its own failure mode:

      * a hand-maintained list of four agents/ directories in check-consumer-drift.ps1, which had
        already drifted: specialists-ecomm was listed under agents and NOT under personas, so a
        consumer's drift check silently never covered that group's personas. Item 4 of the README's
        'Adding a new team' checklist existed only to keep that list current by hand;
      * a regex '^plugins/([a-z0-9][a-z0-9-]*)/' in Get-TouchedPlugins, which had to carry an explicit
        exception for the one sibling directory that is plugin SOURCE but not a plugin;
      * a path segment index, ($p.Mirror -split '[\\/]')[1], in the shared-scripts registry;
      * three Split-Path calls upward from a plugin.json in cut-release.ps1;
      * Join-Path <pluginsRoot> <name> in check-connectors.ps1.

    All five encode the same two assumptions -- that a plugin folder is named after the plugin, and
    that it sits exactly one level under plugins/ -- and neither is a fact about plugins. They are
    facts about one particular layout, which this repo has already changed twice.

    AND ONE READING OF ONE MANIFEST FIELD, for the same reason: Get-ManifestAgentEntries normalises the
    'agents' key (string|string[], where a bare string is ONE entry). It is the same failure one layer in
    -- two callers each carrying their own reading of a field neither owns -- so it lives beside the
    location answers rather than in a lib of its own. See its own header for the two copies it replaced.

    Pure where it can be: Get-PluginRoots takes the JSON text and returns objects, so it is testable
    without a tree. Get-RepoPluginRoots is the one function that touches disk, and it returns an empty
    set rather than throwing when there is no marketplace.json -- a consumer that publishes nothing is
    not a broken repo, it is the normal case.

    EVERY $PluginRoots PARAMETER ACCEPTS $null AND RE-WRAPS WITH @(), and that is load-bearing rather
    than defensive habit. An empty set is the ORDINARY input here -- a repo that publishes no plugins --
    and PowerShell unrolls an empty array on the way through a call, so Get-RepoPluginRoots's @() arrives
    at the next function as $null and a [Parameter(Mandatory)] rejects it even behind
    AllowEmptyCollection. Measured the first time the fold ran against a fixture with no
    marketplace.json: 'Cannot bind argument to parameter PluginRoots because it is null'. This repo has
    paid for the same unrolling before -- the "outer @() is load-bearing" notes in
    check-plugin-integrity.ps1 and build-agent-defs.ps1, and the follow-up commit that made the widened
    collections survive a single-element repo. Same trap, one layer down: a function whose empty case is
    normal must not be able to fail on it.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.

    No dependencies, deliberately. One caller runs at SessionStart -- check-connectors.ps1, via the
    connector-sessioncheck hook -- where pulling a heavyweight lib in to resolve a handful of paths is a
    cost paid on every single session. The other reason is the fold: fold-changelog-entry.ps1 needs
    Get-TouchedPlugins and runs immediately after a merge, directly on the trunk, and reaching it
    through release-lib would load thousands of lines of entry-scaffold-lib behind it.

    ONE ASSEMBLY IS LOADED, AND ONLY AFTER A PARSE HAS ALREADY FAILED. ConvertFrom-MarketplaceJson falls
    back to System.Web.Extensions for the documents 5.1's own JSON reader refuses (issue #1993, its own
    header below). Nothing is loaded on the path any of the callers above take, so the sentence holds
    where it was written to hold: on the ordinary run.

    Pure ASCII (repo convention for .ps1).
#>

function ConvertFrom-MarketplaceJson {
    <#
        THE MARKETPLACE DOCUMENT, PARSED -- with a fallback for the one shape Windows PowerShell 5.1
        cannot read at all.

        5.1's ConvertFrom-Json folds object keys CASE-INSENSITIVELY and then refuses the collision it
        made itself:

            Cannot convert the JSON string because a dictionary that was converted from the string
            contains the duplicated keys '.c' and '.C'.

        The document is valid JSON; the defect is on this side. It is not hypothetical either -- the
        official marketplace carries such a pair, an lspServers.clangd extensionToLanguage map listing
        '.c' beside '.C' (measured 2026-09-14, issue #1993). Before this fallback every plugin from that
        marketplace was permanently 'cannot determine' in plugin-versions, update-plugins' step-3 receipt
        could never verify what step 2 had done for them, and nothing a consumer ran changed it: the state
        was stable, not transient.

        REPARSING FAITHFULLY IS NOT ON THE TABLE, which is what decides the shape below rather than taste.
        -AsHashtable does not exist on 5.1, and a PSObject rejects the second key for the same reason the
        hashtable does -- 'Cannot add a member with the name ".C" because a member with that name already
        exists' -- so there is no 5.1 container that can hold the document as written. The fallback
        therefore does not pretend to return the document. It reads the THREE fields this repo consumes --
        the document's own 'name', and plugins[].name and plugins[].source -- with a case-sensitive
        reader, and hands them back in the same shape so that its callers run unchanged.

        EVERYTHING ELSE IS DROPPED BY DESIGN, NOT LOST BY ACCIDENT, and that is checkable rather than
        asserted: exactly two functions parse a marketplace document anywhere in this repo -- Get-PluginRoots
        below and Get-MarketplaceName in release-lib.ps1 -- and between them they read those three fields
        and nothing else. Every other reader takes the roots Get-PluginRoots returns. A future caller that
        needs a fourth field has to widen this projection, and its absence will be a null rather than a
        wrong answer.

        BOTH OF THEM ROUTE THROUGH HERE, which is the half that is easy to leave undone: cut-release.ps1
        calls them one after the other on the SAME document text, so fixing only the first would move the
        symptom four lines down its own function rather than remove it (Victor, on this branch).

        THE FALLBACK IS LAZY, which is what keeps the header's no-dependencies rule intact. The Add-Type
        for System.Web.Extensions sits after ConvertFrom-Json has already refused, so the ordinary run --
        including check-connectors.ps1 on every SessionStart -- loads exactly what it loaded before. The
        assembly is .NET Framework only, so on PowerShell 7 the Add-Type fails and the original error
        stands; that is correct rather than a gap, because 7's reader does not fold case in the first
        place.

        AND IT TRIGGERS ON ANY ConvertFrom-Json FAILURE, never on the message above -- an exception message
        is not a contract, and this one is a resource string that may be translated. The reason matching is
        not merely risky but UNNECESSARY is what makes this cheap: a failure that is not a case collision
        fails in the second reader too, and then the ORIGINAL error is rethrown, so a caller sees the parse
        error it would always have seen and never a second one about a fallback it did not ask for. The
        discriminating is done by trying, which cannot go stale in a language this repo does not read.

        (plugin-versions.ps1 DOES match that message, on the branch reachable only where this fallback is
        itself unavailable, and its own comment records what was measured about the wording: on a Dutch
        machine the duplicated-keys text comes back in English while the neighbouring malformed-JSON text
        comes back in Dutch, because the two are raised from different resource sets. That is an argument
        for not depending on either, which is what this function does.)
    #>
    param([Parameter(Mandatory)][string]$MarketplaceJson)
    try { return ($MarketplaceJson | ConvertFrom-Json) } catch { $primaryError = $_ }

    $doc = $null
    try {
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $reader = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        # The default cap is 2 MB and a marketplace document is a catalogue, not a record -- the official
        # one was 175 KB over 296 plugins when this was written, and nothing bounds how many a marketplace
        # may list. BOUNDED BY THE DOCUMENT ITSELF rather than raised to [int]::MaxValue (Sebastian, on
        # this branch): the text is already wholly in memory by the time we get here, so its own length is
        # the one ceiling that is neither arbitrary nor a guardrail traded away for nothing. RecursionLimit
        # is deliberately left at its default, which is what bounds a deeply nested document.
        $reader.MaxJsonLength = [Math]::Max(1, $MarketplaceJson.Length)
        $doc = $reader.DeserializeObject($MarketplaceJson)
    } catch { throw $primaryError }
    if ($doc -isnot [System.Collections.IDictionary]) { throw $primaryError }

    $docName = $(if ($doc.ContainsKey('name')) { $doc['name'] } else { $null })

    # A missing or null 'plugins' key is handed back AS SUCH rather than rethrown: Get-PluginRoots already
    # has the right sentence for both, and the duplicate-key error would be a worse answer to a document
    # whose real defect is that it declares nothing.
    if (-not $doc.ContainsKey('plugins')) { return [pscustomobject]@{ name = $docName } }
    $entries = $doc['plugins']
    if ($null -eq $entries) { return [pscustomobject]@{ name = $docName; plugins = $null } }

    $plugins = foreach ($e in @($entries)) {
        if ($e -is [System.Collections.IDictionary]) {
            [pscustomobject]@{
                name   = $(if ($e.ContainsKey('name'))   { $e['name'] }   else { $null })
                source = $(if ($e.ContainsKey('source')) { $e['source'] } else { $null })
            }
        } else {
            # Not an object -- handed through untouched so Get-PluginRoots refuses it with its own
            # message, exactly as it would have on the ConvertFrom-Json path.
            $e
        }
    }
    return [pscustomobject]@{ name = $docName; plugins = @($plugins) }
}

function Get-PluginRoots {
    <#
        Pure: the plugin set as declared in the marketplace JSON. Input is the raw JSON text plus the
        repo root; output is one object per plugin with

            Name          the plugin's name, as the marketplace declares it
            Source        the source string exactly as written (e.g. './plugins/dkj-subagents/dkj-subagents-alpha')
            RelativeRoot  the plugin root relative to the repo, backslash-separated, no leading '.\'
            Root          the plugin root as a full path
            ManifestPath  <Root>\.claude-plugin\plugin.json, as a full path
            IsLocal       $true -- always, unless -IncludeRemote was given (see the skip rule below)

        Throws on a missing plugins list, a missing source, and -- containment, Sean's advice -- on a
        source that leaves the repo root by an absolute path or a '..' segment. The version bump and
        the mirror writer both act on these paths, so a source pointing outside the repo has to stop
        here rather than one layer further down.

        SKIPS -- rather than throwing -- an entry whose source is an OBJECT instead of a path, i.e. a
        plugin fetched from a url. It does not live in this tree, so this function has nothing to say
        about it; the reasoning, and why that is not the silent drop it looks like, is at the branch
        itself below.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$MarketplaceJson,
        [switch]$IncludeRemote
    )
    $marketplace = ConvertFrom-MarketplaceJson -MarketplaceJson $MarketplaceJson
    if (-not ($marketplace.PSObject.Properties.Name -contains 'plugins') -or -not $marketplace.plugins) {
        throw "marketplace.json has no 'plugins' list."
    }
    $fullRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $rootPrefix = $fullRoot + '\'
    foreach ($p in $marketplace.plugins) {
        if (-not $p.source) { throw "plugin '$($p.name)' is missing a 'source'." }
        # A SOURCE THAT IS NOT A STRING IS A PLUGIN THAT DOES NOT LIVE IN THIS TREE, so this function --
        # whose whole question is "where does it live here" -- has no answer for it and skips it.
        #
        # The form is { "source": "url", "url": "...", "sha": "..." }, and it is the MAJORITY shape in a
        # real catalogue rather than an oddity: 244 of the official marketplace's 296 entries, measured
        # 2026-09-14. This branch was unreachable for that document until ConvertFrom-MarketplaceJson
        # above made it readable at all (#1993), which is why it had never had to be decided.
        #
        # SKIPPED, NOT THROWN, because one remotely-sourced plugin must not cost the whole catalogue --
        # that is the very symptom #1993 was filed about, and throwing here would restore it in a new
        # costume for every marketplace that mixes the two forms.
        #
        # AND SKIPPED RATHER THAN HANDED BACK, which is the opposite of what Get-ManifestAgentEntries
        # below does with an entry it cannot use. The two are different jobs: that one NORMALISES a field
        # for a validator whose job is to refuse it, so a silent drop there would defeat the gate. This
        # one RESOLVES a filesystem path, and it already throws on the sources it cannot resolve. There is
        # no path to hand back -- stringifying an object produces a type name that reads as one, which is
        # worse than an absent answer because a caller cannot tell it apart from a real root.
        #
        # THE SILENT-DROP HAZARD IS GUARDED WHERE IT MATTERS, one layer up rather than here: this repo's
        # OWN manifest is walked by check-plugin-integrity.ps1's check 1, which reports an object source
        # as a folder that does not exist. So a plugin cannot fall out of a release cut without the lint
        # gate going red first -- which is also why that second implementation is worth keeping.
        #
        # -IncludeRemote EMITS IT ANYWAY, WITH EVERY PATH FIELD NULL, for the one caller that has to tell
        # "declared, but its payload is elsewhere" from "not declared at all". Skipping alone made those
        # two indistinguishable, and plugin-versions answers them with opposite advice -- it prescribed a
        # marketplace refresh for the absent case, which for a remotely-sourced plugin is the same advice
        # that provably cannot help that #1987 had just finished removing from the neighbouring branch.
        # Off by default, so every other caller sees exactly the set it always saw.
        if ($p.source -isnot [string]) {
            if ($IncludeRemote) {
                [pscustomobject]@{
                    Name         = [string]$p.name
                    Source       = $null
                    RelativeRoot = $null
                    Root         = $null
                    ManifestPath = $null
                    IsLocal      = $false
                }
            }
            continue
        }
        # An absolute source is by definition outside the repo convention -- report explicitly
        # instead of the confusing Join-Path/GetFullPath error that would otherwise roll out.
        if ([System.IO.Path]::IsPathRooted($p.source)) {
            throw "plugin '$($p.name)': source '$($p.source)' points outside the repo (absolute path)."
        }
        $root = $null
        try {
            $root = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $p.source))
        } catch {
            throw "plugin '$($p.name)': source '$($p.source)' is not a valid path."
        }
        $root = $root.TrimEnd('\')
        if (-not ($root + '\').StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "plugin '$($p.name)': source '$($p.source)' points outside the repo ($root)."
        }
        [pscustomobject]@{
            Name         = [string]$p.name
            Source       = [string]$p.source
            RelativeRoot = $root.Substring($fullRoot.Length).TrimStart('\')
            Root         = $root
            ManifestPath = Join-Path $root '.claude-plugin\plugin.json'
            IsLocal      = $true
        }
    }
}

function Get-ManifestAgentEntries {
    <#
        ONE READING OF THE 'agents' KEY. The field is string|string[] over paths to .md files, and a BARE
        STRING IS ONE ENTRY -- the form a naive count gets wrong. In Windows PowerShell 5.1 a string's
        .Count is 1 only by accident of scalar unrolling, and .Length is its character count, so a caller
        that reaches for either is right for the wrong reason or simply wrong.

        Before this function there were two independent readings of that one field (issue #1781):

          * check-plugin-integrity.ps1's check 38 [agents-key], normalising to a list in order to
            validate each entry;
          * measure-skill-lib.ps1's Get-DeclaredAgentCount, normalising to a count.

        They agreed, and both were asserted. What was unguarded is that they could not DISAGREE: if the
        installer ever accepts a third form, one copy learns it and the other does not, and the failure is
        silent in OPPOSITE directions -- the gate passes a manifest it should refuse, or measure-skill
        reports an agent count that is not the plugin's. Same class as the five copies this lib was built
        to replace, and the same answer.

        TAKES THE PARSED MANIFEST, NOT A PATH, so it is pure and testable without a tree -- like
        Get-PluginRoots above, and unlike the disk-reading callers. The property is PROBED rather than
        read: Set-StrictMode throws on an absent one, and a manifest with no 'agents' key at all is the
        ordinary case for every plugin that ships none.

        RETURNS AN ARRAY, ALWAYS, and the outer @() at every call site is load-bearing for the reason the
        header above gives -- an empty array unrolls to $null on the way out. A key that is absent, $null,
        or an empty array all come back as an empty set: 'declares none'. Anything a caller must REFUSE --
        an entry that is not a non-empty string -- is handed back untouched rather than filtered, because
        deciding that is the validator's job and a silent drop here would make the gate pass what it
        exists to catch.
    #>
    param([Parameter(Mandatory)][AllowNull()]$Manifest)
    if ($null -eq $Manifest) { return @() }
    if (-not $Manifest.PSObject.Properties['agents']) { return @() }
    if ($null -eq $Manifest.agents) { return @() }
    if ($Manifest.agents -is [string]) { return @([string]$Manifest.agents) }
    return @($Manifest.agents)
}

function Get-MarketplacePath {
    <# Where a repo declares its plugins, if it declares any. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return (Join-Path $RepoRoot '.claude-plugin\marketplace.json')
}

function Get-RepoPluginRoots {
    <#
        Get-PluginRoots against the repo's own marketplace.json. The one function here that reads disk.

        RETURNS AN EMPTY SET WHEN THERE IS NO marketplace.json, rather than throwing. Every caller but
        the release cut runs in consumers too, and a consumer that publishes no plugins is the ordinary
        case -- not a misconfiguration. A malformed marketplace.json still throws, because that IS one.

        -IncludeRemote is passed straight through to Get-PluginRoots; see the skip rule there.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [switch]$IncludeRemote
    )
    $path = Get-MarketplacePath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $json = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    return @(Get-PluginRoots -RepoRoot $RepoRoot -MarketplaceJson $json -IncludeRemote:$IncludeRemote)
}

function Get-PluginRootByName {
    <#
        The one plugin with this name, or $null. Name comparison is ORDINAL and case-sensitive: a
        plugin name is a path segment on a case-sensitive filesystem and an install id, so 'Specialists'
        is a different plugin from 'specialists' -- Get-TouchedPlugins has always taken that position
        (its -cmatch, Sean's advice) and it is stated once here instead.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$PluginRoots = @(),
        [Parameter(Mandatory)][string]$Name
    )
    foreach ($p in @($PluginRoots)) {
        if ([string]::Equals($p.Name, $Name, [System.StringComparison]::Ordinal)) { return $p }
    }
    return $null
}

function Get-PluginNameForPath {
    <#
        Which plugin does this repo-relative path belong to? Returns the plugin name, or $null when the
        path is under no plugin root at all.

        This replaces the depth-and-name regex it was extracted from, and it answers a question that
        regex could only approximate. Two things fall out rather than needing to be written:

          * plugins/dkj-subagents/subagent-shared/ is not a plugin, so it is not matched -- no name has to be
            excluded by hand. Under the previous shape the excluded sibling had to be rewritten every
            time the layout moved (it named connectors/ until August 3, 2026, by which point
            connectors/ had left plugins/ entirely and the real sibling went uncounted). That sibling
            moved AGAIN on August 17, 2026, from plugins/ down into plugins/dkj-subagents/ beside the only
            plugins that consume it, and this function needed no edit for it -- which is the property
            it was extracted to have;
          * a plugin root at any depth matches, so plugins/dkj-subagents/dkj-subagents-alpha/ works without this
            function knowing that 'dkj-subagents' exists.

        Accepts either separator in $Path, since callers hand it both: gh supplies forward slashes and
        Get-ChildItem supplies backslashes. The comparison is ordinal and case-sensitive for the reason
        given at Get-PluginRootByName; the longest matching root wins, so a plugin nested inside
        another plugin's directory would still be attributed to the inner one.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$PluginRoots = @(),
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path
    )
    if (-not $Path) { return $null }
    $needle = ($Path -replace '/', '\').TrimStart('.', '\')
    $best = $null
    foreach ($p in @($PluginRoots)) {
        $prefix = $p.RelativeRoot.TrimEnd('\') + '\'
        if ($needle.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            if (-not $best -or $p.RelativeRoot.Length -gt $best.RelativeRoot.Length) { $best = $p }
        }
    }
    if ($best) { return $best.Name }
    return $null
}

function Get-TouchedPlugins {
    <#
        Pure: derives the touched plugin names from a list of PR file paths (repo-root-relative, as
        gh pr list --json files supplies -- $Files here are already flat path strings, not the gh
        objects themselves), against the plugin roots the marketplace declares. Returns a sorted,
        deduplicated array of plugin names (empty if nothing touches a plugin). Separately testable
        rather than inline in fold-changelog-entry.ps1 (#103, Victor #3).

        IT ASKS THE MARKETPLACE NOW, INSTEAD OF MATCHING A PATH SHAPE. This used to be the regex
        '^plugins/([a-z0-9][a-z0-9-]*)/' with 'subagent-shared' excluded by name, and the comment above it
        recorded that the excluded sibling had already had to be rewritten once: it named connectors/
        until August 3, 2026, by which point connectors/ had moved to the repo root -- so the exclusion
        was guarding nothing while the real sibling, subagent-shared/, went uncounted. That is the failure
        mode of encoding a layout in a pattern. Reading the roots removes both halves at once:
        subagent-shared/ is not in the marketplace so it cannot match, and a plugin at any depth does.
        Both halves were exercised on August 17, 2026, when subagent-shared/ moved to
        plugins/dkj-subagents/subagent-shared/ -- a path the old regex would have captured as the plugin 'teams'.

        LIVED IN release-lib.ps1 UNTIL AUGUST 9, 2026, where a note now points here. It reads plugin
        roots, so it belongs beside them -- and the fold script, which is its one caller, can now reach
        it without dot-sourcing a lib that pulls thousands more lines in behind it.

        $PluginRoots comes from Get-RepoPluginRoots, which returns an empty set in a repo with no
        marketplace.json -- so a consumer folds without a 'Plugins:' line, which is the right answer
        there rather than a degraded one.
    #>
    param(
        [string[]]$Files = @(),
        [AllowNull()][AllowEmptyCollection()][object[]]$PluginRoots = @()
    )
    $touched = @()
    foreach ($f in @($Files)) {
        $name = Get-PluginNameForPath -PluginRoots $PluginRoots -Path $f
        if ($name -and $touched -notcontains $name) { $touched += $name }
    }
    return @($touched | Sort-Object)
}

function Get-PluginSubdirs {
    <#
        The <Leaf> directory of every plugin that has one -- e.g. every 'agents' directory across the
        whole set, as full paths. Existence-filtered, because not every plugin carries every kind.

        Exists so the consumer-drift check stops keeping a hand-written list of directories per kind.
        That list is where the measured asymmetry lived.

        Existence-filtered because not every plugin carries every kind: measured August 9, 2026, one of
        the five ships personas/ and three ship skills/.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$PluginRoots = @(),
        [Parameter(Mandatory)][string]$Leaf
    )
    $out = @()
    foreach ($p in @($PluginRoots)) {
        $dir = Join-Path $p.Root $Leaf
        if (Test-Path -LiteralPath $dir -PathType Container) { $out += $dir }
    }
    return @($out)
}
