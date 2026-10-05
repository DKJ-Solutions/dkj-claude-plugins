<#
.SYNOPSIS
    The comparison behind check-consumer-siblings.ps1: given two or more consumers' tooling
    inventories, which mechanisms does one have that the other does not. Issue #1869.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\sibling-divergence-lib.ps1')

    WHY THIS EXISTS. The connectors register already records which repos consume this plugin, and
    connectors/xoxowildhearts.json states in its own notes what it was asked for: "the register is
    where the two Shopify consumers diverging can be seen." It was never given the check that reads
    it that way, and #1869 measured the cost -- of 48 tooling paths the two BWJ stores share, 47 have
    diverged, and the one that has not is a verbatim plugin template.

    THE FAILURE IS NOT DRIFT BETWEEN A SOURCE AND A COPY, which is what check-consumer-drift.ps1
    already reports. It is two consumers independently building the same mechanism, each ahead of the
    other on different things, with nothing carrying either way. The measured instance is
    scripts/task/prune-merged.ps1: inbound #815 asked for it centrally, dkj-policy 4.21.0 shipped it,
    one consumer replaced its copy with a forwarder and the other still carried its own three weeks
    later. So "shipped centrally" and "used centrally" are different facts, and nothing was watching
    the gap between them.

    WHY IT CANNOT BE SEEN FROM INSIDE ONE CONSUMER, which is the reason the check belongs here:

      1. The question a consumer's own rules ask is "does the plugin provide this?" -- a one-repo
         question. It never asks "does the sibling consumer have this too?", and the sibling is a repo
         that session never opens.
      2. The names drift apart, so no grep finds the pair. market-domains.ps1 against market-urls.ps1;
         archive-and-remove-theme.ps1 against archive-theme.ps1 + verify-archive.ps1. Neither pair
         shares a path, so a path comparison alone reports them as two unrelated absences rather than
         as one capability with two spellings -- which is what Find-AliasedCapability is for.

    THREE FINDING CLASSES, and they answer different questions:

      ONLY-IN   a comparable path present in exactly one member of the group. The prune-merged case.
      DRIFTED   a comparable path present in every member, with differing content. The 47.
      ALIASED   a capability (an exported function name) present in two or more members at DIFFERENT
                paths. The market-domains/market-urls case -- the one no path comparison can see.

    ALIASED IS COMPUTED OVER THE ONLY-IN SET ALONE, and that is a scoping property rather than a
    shortcut: a path present in every member is by definition not aliased, whatever its content, so
    the files whose content has to be read are exactly the ones already reported as ONLY-IN. That is
    what keeps the content reads bounded when a member is read over the network rather than off a
    disk.

    WHAT IS DELIBERATELY NOT COMPARED. Some paths are repo-specific BY DESIGN, and reporting them as
    divergence is not a false positive -- it is a category error that would bury the real findings
    under noise that can never be actioned. The lenses are the clearest case: a repo lens exists to
    say what THIS repo differs on, so two consumers' lenses agreeing would be the defect. Same for
    the seam (repo-config.ps1), whose entire job is to hold the answers that differ. This mirrors the
    carve-out #1869's own measurement made by hand when it excluded theme content.

    THE EXCLUSIONS ARE A DEFAULT, NOT A LAW. Get-SiblingExcludedPathPattern states them in one place
    so a caller can widen or narrow them, and the entry point prints how many paths each exclusion
    removed -- because an exclusion that silently eats a class is indistinguishable from a class with
    nothing in it.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

function Get-SiblingComparableRoot {
    <#
        The tooling layer, and only it. Theme content, brains, docs and assets are store-specific by
        definition and are not what this check is about -- #1869 drew the same boundary by hand.

        A prefix match, so 'scripts/' covers everything under it. Slash-normalized: every path this
        lib handles is normalized to forward slashes on the way in, because one member may be read
        off a Windows disk and another out of a git tree listing, and those two spell the same path
        differently. That is not hypothetical -- it is the exact defect #1869 records in the
        consumers' own plugin-scripts.ps1, where one repo has the normalization and the other does not.
    #>
    @('scripts/', '.github/', '.claude/')
}

function Get-SiblingExcludedPathPattern {
    <#
        Paths inside the comparable roots that are repo-specific BY DESIGN. Regex, matched against
        the normalized path.

        Each one is here because agreement would be the defect, not because divergence is tolerable:

          - the specialist lenses and SPECIALISTS.md: a lens states what this repo differs on. Two
            consumers' lenses being identical would mean one of them is describing the other's repo.
          - scripts/repo-config.ps1: the seam. Its whole purpose is to hold the answers that differ
            per repo -- the store's theme ids, its board gid, its domains. It is the mechanism that
            makes sharing possible, so reporting it as unshared inverts the finding.
          - the branch/PR templates and dependabot config: GitHub-facing boilerplate that says
            nothing about whether a mechanism is duplicated.
          - .claude/memory/: a session's own notes about the repo it was written in. Two repos'
            memory notes agreeing would mean one of them remembers the other's machine.

        WHAT IS NOT EXCLUDED, so nobody adds it on instinct: the test suites. A test suite is
        mechanism -- #1869's largest single divergence is plugin-scripts.tests.ps1 at 1791 differing
        lines -- and two consumers testing the same shared lib twice is precisely the duplication
        this check exists to surface.
    #>
    @(
        '^\.claude/specialists/lenses/',
        '^\.claude/specialists/SPECIALISTS\.md$',
        '^\.claude/memory/',
        '^scripts/repo-config\.ps1$',
        '^\.github/pull_request_template\.md$',
        '^\.github/dependabot\.yml$'
    )
}

function ConvertTo-SiblingPath {
    <#
        One spelling for a path, whatever read it. Backslashes to forward slashes, any leading './'
        or '/' removed. Everything else in this lib assumes it has been through here.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)

    $p = $Path -replace '\\', '/'
    while ($p.StartsWith('./')) { $p = $p.Substring(2) }
    $p = $p.TrimStart('/')
    return $p
}

function Test-IsSiblingComparablePath {
    <#
        Is this path part of the layer two sibling consumers are expected to share?

        Two questions in order: is it inside a comparable root, and is it exempt. Returns $false for
        anything outside the roots, which is most of a store repo.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [string[]]$Roots           = @(),
        [string[]]$ExcludedPattern = @()
    )

    $p = ConvertTo-SiblingPath -Path $Path
    if ($p -eq '') { return $false }

    if ($Roots.Count           -eq 0) { $Roots           = @(Get-SiblingComparableRoot) }
    if ($ExcludedPattern.Count -eq 0) { $ExcludedPattern = @(Get-SiblingExcludedPathPattern) }

    $inRoot = $false
    foreach ($r in $Roots) { if ($p.StartsWith($r)) { $inRoot = $true; break } }
    if (-not $inRoot) { return $false }

    foreach ($x in $ExcludedPattern) { if ($p -match $x) { return $false } }

    return $true
}

function Group-SiblingConsumer {
    <#
        Which consumers are siblings of which.

        DECLARED, NEVER INFERRED. A group is read from the manifest's own 'siblingGroup' field, and a
        manifest without one is in no group and is never compared. Inferring the grouping -- from a
        shared plugin set, say, or a shared owner -- was the obvious alternative and is wrong for a
        measurable reason: every consumer of this marketplace shares dkj-policy, so a plugin-set
        inference puts life-hub in a group with a Shopify store and then reports a personal-life repo
        as missing a theme-archive mechanism. The grouping is a statement about INTENT (these two
        repos are meant to run the same floor), and intent is data somebody writes down.

        Input: the parsed manifest objects. Output: an ordered hashtable of group name -> member
        objects, holding only groups with two or more members -- a group of one has nothing to
        compare and is not a finding.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Manifest)

    $byGroup = [ordered]@{}
    foreach ($m in $Manifest) {
        if ($null -eq $m) { continue }
        $g = ''
        if ($m.PSObject.Properties['siblingGroup']) { $g = [string]$m.siblingGroup }
        if ([string]::IsNullOrWhiteSpace($g)) { continue }
        if (-not $byGroup.Contains($g)) { $byGroup[$g] = @() }
        $byGroup[$g] = @($byGroup[$g]) + @($m)
    }

    $out = [ordered]@{}
    foreach ($k in $byGroup.Keys) { if (@($byGroup[$k]).Count -ge 2) { $out[$k] = @($byGroup[$k]) } }
    return $out
}

function Compare-SiblingInventory {
    <#
        The path-level comparison. Input: a hashtable of member label -> (hashtable of normalized
        path -> content fingerprint). Output: an object carrying the ONLY-IN and DRIFTED findings
        plus the counts the report needs.

        THE FINGERPRINT IS OPAQUE HERE. The entry point supplies a git blob sha where it read a git
        tree and a content hash where it read a disk, and this function only ever asks whether two
        fingerprints are equal -- so it never has to know which. What it must never do is compare a
        sha against a hash, which is why the entry point is required to use ONE scheme across a
        group and says out loud which it used.

        ONLY-IN is reported per path with the single member that has it. A path held by two members
        of a three-member group is neither only-in nor shared by all; it is reported as PARTIAL, so
        a group larger than two does not silently lose findings to a binary vocabulary.
    #>
    param([Parameter(Mandatory)][hashtable]$Inventory)

    $labels = @($Inventory.Keys)
    $allPaths = @{}
    foreach ($l in $labels) { foreach ($p in @($Inventory[$l].Keys)) { $allPaths[$p] = $true } }

    $onlyIn  = @()
    $partial = @()
    $drifted = @()
    $agreed  = 0

    foreach ($p in (@($allPaths.Keys) | Sort-Object)) {
        $have = @($labels | Where-Object { $Inventory[$_].ContainsKey($p) })

        if ($have.Count -eq 1) {
            $onlyIn = @($onlyIn) + @([pscustomobject]@{ Path = $p; Member = $have[0] })
            continue
        }
        if ($have.Count -lt $labels.Count) {
            $partial = @($partial) + @([pscustomobject]@{ Path = $p; Members = $have })
            continue
        }

        $prints = @($labels | ForEach-Object { [string]$Inventory[$_][$p] } | Sort-Object -Unique)
        if ($prints.Count -eq 1) { $agreed++ }
        else { $drifted = @($drifted) + @([pscustomobject]@{ Path = $p; Members = $labels }) }
    }

    return [pscustomobject]@{
        Members      = $labels
        OnlyIn       = @($onlyIn)
        Partial      = @($partial)
        Drifted      = @($drifted)
        AgreedCount  = $agreed
        SharedCount  = $agreed + @($drifted).Count
        ComparedPath = @($allPaths.Keys).Count
    }
}

function Get-PowerShellFunctionName {
    <#
        The function names a PowerShell file defines. A deliberately shallow read: the 'function'
        keyword at the start of a line, its name, and nothing else.

        WHY NOT THE PARSER. [System.Management.Automation.Language.Parser] would be exact, and it
        also parses -- which means a file this check never runs is still handed to a language parser.
        These files come from another repo, so the shallow read is the one that cannot be talked into
        doing anything. The cost of being shallow is a missed nested or dynamically-named function,
        and a missed name only ever costs an ALIASED finding that a human would still find by the
        ONLY-IN pair sitting beside it.

        Case is folded, because PowerShell's is.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $names = @()
    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match '^\s*function\s+([A-Za-z_][A-Za-z0-9_\-]*)') {
            $names = @($names) + @($Matches[1].ToLowerInvariant())
        }
    }
    return @($names | Sort-Object -Unique)
}

function Find-AliasedCapability {
    <#
        The finding no path comparison can make: one capability, two spellings.

        Input: a hashtable of member label -> (hashtable of normalized path -> file content), holding
        ONLY the paths already reported as ONLY-IN. Output: one finding per function name that two or
        more members define at different paths.

        WHY THE FUNCTION NAME IS THE UNIT. It is the only thing the two spellings of a duplicated
        mechanism reliably keep: market-domains.ps1 and market-urls.ps1 share no path, no filename
        and no line, and both export Get-MarketPreviewUrls and Write-MarketPreviewUrls. A name that
        two independently-written files both chose is strong evidence they are the same capability --
        far stronger than a filename, which is exactly what drifted.

        WHAT IT WILL ALSO CATCH, and this is a feature rather than noise: a helper name generic enough
        that two repos arrived at it independently without meaning the same thing. The finding names
        the two paths, so that is one file open to dismiss -- and the alternative, filtering on a
        hand-kept list of "real" capability names, is a second literal for a new mechanism to fall
        silently out of.
    #>
    param([Parameter(Mandatory)][hashtable]$OnlyInContent)

    $byName = @{}
    foreach ($label in @($OnlyInContent.Keys)) {
        foreach ($path in @($OnlyInContent[$label].Keys)) {
            foreach ($fn in (Get-PowerShellFunctionName -Content ([string]$OnlyInContent[$label][$path]))) {
                if (-not $byName.ContainsKey($fn)) { $byName[$fn] = @() }
                $byName[$fn] = @($byName[$fn]) + @([pscustomobject]@{ Member = $label; Path = $path })
            }
        }
    }

    $findings = @()
    foreach ($fn in (@($byName.Keys) | Sort-Object)) {
        $sites = @($byName[$fn])
        if ((@($sites | ForEach-Object { $_.Member } | Sort-Object -Unique)).Count -lt 2) { continue }
        if ((@($sites | ForEach-Object { $_.Path   } | Sort-Object -Unique)).Count -lt 2) { continue }
        $findings = @($findings) + @([pscustomobject]@{ Function = $fn; Sites = $sites })
    }
    return @($findings)
}

function Group-AliasedCapability {
    <#
        The same aliasing, reported per PATH PAIR rather than per function name.

        Find-AliasedCapability answers "which names are duplicated", and a pair of files sharing six
        exported names produces six findings of the same fact. This folds them onto the pair of paths
        they sit in, which is the unit a reader acts on: two files, one decision. The function names
        travel along as the evidence for the pairing, because a pair backed by six shared names is a
        different claim from one backed by a single generic helper -- and the reader needs to be able
        to tell those apart without opening anything.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Aliased)

    $byPair = [ordered]@{}
    foreach ($f in $Aliased) {
        $sites = @($f.Sites)
        for ($i = 0; $i -lt $sites.Count; $i++) {
            for ($j = $i + 1; $j -lt $sites.Count; $j++) {
                if ($sites[$i].Member -eq $sites[$j].Member) { continue }
                $ends = @("$($sites[$i].Member):$($sites[$i].Path)", "$($sites[$j].Member):$($sites[$j].Path)") | Sort-Object
                $key  = $ends -join '  <->  '
                if (-not $byPair.Contains($key)) { $byPair[$key] = @() }
                $byPair[$key] = @($byPair[$key]) + @($f.Function)
            }
        }
    }

    $out = @()
    foreach ($k in $byPair.Keys) {
        $out = @($out) + @([pscustomobject]@{
            Pair      = $k
            Functions = @($byPair[$k] | Sort-Object -Unique)
        })
    }
    return @($out | Sort-Object -Property @{ Expression = { @($_.Functions).Count }; Descending = $true }, Pair)
}

function Get-ShippedScriptIndex {
    <#
        The marketplace's own scripts, indexed by FILENAME, so a consumer's path can be asked one
        question: does a plugin here already ship this?

        Input: objects carrying Plugin and Path (repo-relative, any slash spelling). Output: a
        hashtable of lower-cased basename -> the shipped sites with that name. The entry point
        supplies the set; composing it is a disk read and deciding with it is not, which is the same
        split every other function in this lib is built on.

        ONLY .ps1 IS INDEXED, and that bound is load-bearing rather than tidy. Every plugin ships a
        README.md and a SKILL.md, so a basename index over all files would answer "yes, shipped" for
        every README in every consumer -- a false positive on the single commonest filename in any
        repo. The .github/workflows templates are the same trap with the opposite cause: those are
        MEANT to be copied verbatim into a consumer (the CI runners adopt-dkj-policy places are), so
        a consumer holding one is the mechanism working, not an adoption gap.

        A NAME CAN BE SHIPPED FROM MORE THAN ONE PLACE, so the value is a list rather than one site.
        A registered mirror and the plugin file it is mirrored to are the same script by construction,
        and reporting either one alone would name a path the reader then has to go looking for.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Shipped)

    $index = @{}
    foreach ($s in @($Shipped)) {
        if ($null -eq $s) { continue }
        $p = ConvertTo-SiblingPath -Path ([string]$s.Path)
        if ($p -eq '') { continue }
        if ($p -notmatch '\.ps1$') { continue }

        $base = (@($p -split '/')[-1]).ToLowerInvariant()
        if (-not $index.ContainsKey($base)) { $index[$base] = @() }
        if (@($index[$base] | Where-Object { $_.Path -eq $p }).Count -gt 0) { continue }
        $index[$base] = @($index[$base]) + @([pscustomobject]@{ Plugin = [string]$s.Plugin; Path = $p })
    }
    return $index
}

function Find-ShippedMechanism {
    <#
        The adoption gap: a consumer carrying its own copy of a script the marketplace already
        publishes. Issue #1885.

        WHY NEITHER EXISTING LANE CAN SAY THIS. ONLY-IN and DRIFTED are consumer-to-consumer verdicts,
        so both stores holding a local copy reads as DRIFTED and one holding it reads as ONLY-IN --
        and neither sentence contains the fact that matters, which is that nobody has to own this
        mechanism because a plugin already does. The result was that the CHEAPEST convergence, adopt
        what exists, was the one the tooling could not see, while the expensive kind -- decide an
        owner, move the mechanism, release, adopt -- was the only kind it surfaced.

        IT ADDS, IT NEVER RECLASSIFIES, which is the ALIASED lane's precedent and here it is also the
        safety property. The match is on filename (see below), so a SHIPPED line that is wrong must
        cost the reader a file to open and nothing else. Were this to move a path OUT of DRIFTED, one
        coincidental name would delete a real divergence finding from the report -- the false negative
        this whole check exists to prevent, reintroduced by its newest lane.

        PARTIAL IS INCLUDED THOUGH #1885 NAMES ONLY ONLY-IN AND DRIFTED. A path held by two members of
        a three-member group is a local copy in exactly the same way; excluding it would put a silent
        hole in the lane that opens the first time a group gains a third member, which is the shape
        Compare-SiblingInventory already refuses for the same reason.

        THE MATCH IS ON FILENAME AND THE REPORT SAYS SO. Two files can share a name and not a
        capability, so this returns evidence rather than a verdict -- the reader is told what it
        matched on, exactly as the ALIASED lane is. The opposite bound is real too and no report can
        close it: a consumer that renamed its copy is invisible here, and it is the ALIASED pass, not
        this one, that has any chance of finding it.
    #>
    param(
        [Parameter(Mandatory)][object]$Comparison,
        [Parameter(Mandatory)][hashtable]$Index
    )

    $carried = @()
    foreach ($f in @($Comparison.OnlyIn))  { $carried += @([pscustomobject]@{ Path = $f.Path; Class = 'only-in'; Members = @($f.Member)  }) }
    foreach ($f in @($Comparison.Partial)) { $carried += @([pscustomobject]@{ Path = $f.Path; Class = 'partial'; Members = @($f.Members) }) }
    foreach ($f in @($Comparison.Drifted)) { $carried += @([pscustomobject]@{ Path = $f.Path; Class = 'drifted'; Members = @($f.Members) }) }

    $out = @()
    foreach ($f in $carried) {
        $p = ConvertTo-SiblingPath -Path ([string]$f.Path)
        if ($p -notmatch '\.ps1$') { continue }
        $base = (@($p -split '/')[-1]).ToLowerInvariant()
        if (-not $Index.ContainsKey($base)) { continue }
        $out += @([pscustomobject]@{
            Path    = $p
            Class   = [string]$f.Class
            Members = @($f.Members)
            Shipped = @($Index[$base])
        })
    }
    return @($out | Sort-Object Path)
}
