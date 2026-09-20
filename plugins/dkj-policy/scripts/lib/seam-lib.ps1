<#
.SYNOPSIS
    Get-SeamValue: read an optional repo-config seam function, falling back to a default when the repo
    does not define it. Get-Default*: the computed defaults for the changelog and release-note-root seams
    (issue #885) -- source keeps its root files, consumer is isolated inside the workflow's own root
    folder by default. That folder is NAMED by Get-WorkflowFolderName below and never written out here:
    it renamed once already (#886), and a docstring that states the answer instead of the function goes
    stale the next time it does.

.DESCRIPTION
    ONE DEFINITION, WHERE THERE WERE TWO PLUS THREE INLINE PROBES (issue #885, group A). cut-release.ps1
    and new-internal-note.ps1 each carried a private copy of Get-SeamValue -- byte-different, since only
    the first supported more than one name for a renamed seam -- and fold-changelog-entry.ps1, open-pr.ps1
    and session-status.ps1 each probed inline with `Get-Command Get-X -ErrorAction SilentlyContinue`
    instead of calling either copy. The changelog seam this branch adds is read at three of those sites
    (cut-release.ps1, fold-changelog-entry.ps1 and session-status.ps1 -- the last of which #957 removed
    with /lock and /handover), so it is the one they read through rather than adding a third idiom for one
    seam.

    ARRAY-CAPABLE ON PURPOSE, kept from cut-release.ps1's copy rather than new-internal-note.ps1's
    single-name one: $Name takes MORE THAN ONE NAME where a seam has been renamed, tried in order, so the
    current name is preferred and a retired one still answers -- a repo that defined the old name receives
    the rename through a plugin update rather than by choosing to, and without the fallback it would drop
    to $Default in silence.

    Dot-source this file:

        . (Join-Path $PSScriptRoot 'seam-lib.ps1')

    Pure ASCII (repo convention for .ps1).
#>

# THE FUNCTION-TABLE PROBE (issue #1729). Get-SeamValue below IS the probe this repo tells callers to
# use instead of an inline Get-Command, so it is the one place that most had to stop being one itself.
# Unconditional and $PSScriptRoot-relative, so it resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')

function Get-SeamValue {
    <#
        Calls an optional repo-config function, or returns $Default when the repo does not define it.
        See the file synopsis for why $Name is an array.
    #>
    param([Parameter(Mandatory)][string[]]$Name, $Default)
    foreach ($n in $Name) {
        if (Test-FunctionDefined $n) { return (& $n) }
    }
    return $Default
}

function Get-DefaultChangelogPath {
    <#
        The changelog seam's computed default, so a repo that configures nothing still gets the right
        answer instead of needing to remember a setting: '<workflow folder>/CHANGELOG.md', the folder name
        coming from Get-WorkflowFolderName. ONE ANSWER FOR EVERY REPO, and the Get-ChangelogPath seam
        exists for the repo that wants to differ from it.

        IT USED TO BRANCH, returning a root 'CHANGELOG.md' for a repo with a marketplace manifest, and the
        branch is retired rather than repointed (issue #998, August 27, 2026) -- the same move #914 made
        to Get-DefaultReleaseChangelogNotesRoot and Get-DefaultReleaseGithubNotesRoot, on the same
        reasoning: this file exists BECAUSE the workflow does, so it belongs in the workflow's folder in
        every repo. Two things had to be true before it could go, and by August 27 both were. The source
        stopped wanting the root answer -- #980 moved its CHANGELOG.md into dkj-policy/ and
        STATED the seam to say so, making the branch inert in the one repo it was written for. And the
        test it branched on turned out to detect "publishes plugins" rather than "is this workflow's
        source", so the surviving effect was to hand a root CHANGELOG.md to some future repo for a reason
        that has nothing to do with changelogs.

        ACCEPTED COST, the same shape every relocated seam here records: a repo that publishes plugins,
        has never stated Get-ChangelogPath, and folds into a root CHANGELOG.md today would see the default
        move under it. No such repo exists -- the source states the seam and no consumer publishes plugins
        -- and one that appears later is caught rather than clobbered: Assert-WorkflowIsolatedSeamPath
        accepts 'CHANGELOG.md' as this seam's pre-isolation answer, so a fold there is refused with the
        seam named instead of writing to a second file.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return "$(Get-WorkflowFolderName -RepoRoot $RepoRoot)/CHANGELOG.md"
}
function Test-IsWorkflowSourceRepo {
    <#
        IS THIS REPO THE SOURCE OF *THIS* WORKFLOW -- which is what the name says, and since issue #998
        (August 27, 2026) also what the test does. It used to be `Test-Path .claude-plugin/marketplace.json`
        and nothing more, which answers a different question: DOES THIS REPO PUBLISH PLUGINS. The two
        coincided while this was the only repo with a marketplace manifest, and Dave's own
        one-product-one-repository rule guarantees they come apart -- the next product gets its own
        repository AND its own marketplace, so a repo that consumes this workflow while publishing
        something else answered $true here and was handed this repo's layout and this repo's refusals.

        SO THE MANIFEST IS READ RATHER THAN COUNTED: the repo is this workflow's source when its
        marketplace publishes a plugin named after the workflow folder. The two strings are the same by
        construction -- a consumer's folder is named after the plugin that scaffolds it -- and the one case
        where they differ resolves correctly for free: a repo carrying the PRE-RENAME 'workflow-davekjohn'
        folder (#886) is by definition a consumer that adopted before the rename, and a consumer is not
        the source, so $false is the right answer there rather than a missed match.

        UNREADABLE JSON IS $false, NOT AN EXCEPTION. Somebody else's broken manifest is somebody else's
        message, and every caller here is asking "is this the source" in order to be MORE careful, so the
        safe answer when it cannot tell is "treat this as a consumer".

        WHO STILL USES THE BROAD `Test-Path` TEST INLINE, DELIBERATELY, AND WHY IT IS NOT DUPLICATION.
        The one-file check still appears inline at the sites below, asking a different question at each.
        It is not factored in here because factoring it would suggest they all mean this:

          * `Get-ReleasePluginTier`'s fallback (cut-release.ps1) -- "does this repo publish plugins whose
            versions the cut must bump in lockstep". Broad is exactly right; that IS the question.
          * `Assert-OwnCopy` (source-repo-guard-lib.ps1) -- its own comment says it: "only a repo that
            publishes plugins can be the repo a shared script is maintained in". A cheap necessary
            condition in front of an expensive path comparison, not a claim about which workflow.
          * push-preview.ps1, sync-main.ps1, adopt-shopify-floor.ps1 -- a THIRD meaning again: "this repo
            is not a Shopify store, so there is no theme estate here". Publishing plugins is a proxy for
            that and a loose one, but it is not this function's question and narrowing them here would
            answer it wrongly rather than better.

        adopt-workflow-folder.ps1 DID mean this one and now calls it: refusing a genuine consumer the
        folder scaffold because it happens to publish plugins is the concrete harm #998 was filed about.

        AND SO DID THE PROSE CHECK, since #1422. check-retired-doc-name.ps1 and
        check-supremacy-declaration.ps1 arrived in September 2026 -- AFTER the census above was written --
        each carrying its own inline `Test-Path .claude-plugin/marketplace.json` skip with its own comment.
        #1421 then folded the pair into a single check-consumer-prose.ps1, so it is ONE caller now and both
        detectors sit behind one skip. Their question is this one: the skip exists because THIS WORKFLOW'S
        conventions are authored here, which is what makes the rename narration and the supremacy sentences
        correct prose rather than consumer drift. Under the broad test a repo publishing another product
        while consuming this workflow was skipped in silence -- #998's harm in the mirror direction, since
        here it costs a check that never runs rather than a scaffold that is refused. It calls this function
        now, so the bullets above are unchanged: it was never among them.

        WHICH IS THE PART WORTH TAKING FROM THIS. The census did not go wrong, it went INCOMPLETE, silently,
        because a census in a docstring is a snapshot and the tree kept being written. Two authors reached
        for the inline one-file test while the named function sat one dot-source away -- each following the
        sibling in front of them, which is precisely the choice this list exists to arbitrate and precisely
        the reader it never reached. So read the bullets as evidence of a distinction rather than as a
        current inventory, and when you add a site, decide which question you are asking before copying
        whichever idiom is nearest.

        WHICH IS ALSO WHY THERE IS NO LONGER A COUNT HERE (#1432). That first sentence used to open with
        one -- "at six further sites" -- and the figure was wrong on the day it was written: the census
        stood at five, the bullets named five, and the sixth was adopt-workflow-folder.ps1, which the
        paragraph below already describes as having STOPPED being an inline site. It then drifted to seven
        as the two prose checks arrived and back to five when #1422 pointed them here, so in nine days it
        was wrong at three different values while the bullets stayed correct throughout. A number is an
        inventory claim, which is the one thing the paragraph above tells you not to read this list as --
        and the bullets do the arbitrating regardless, because what a new author needs is the question,
        never the total. `grep` is the inventory and it is always current.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $manifest = Join-Path $RepoRoot '.claude-plugin\marketplace.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { return $false }
    $workflow = Get-WorkflowFolderName -RepoRoot $RepoRoot
    try {
        $json = Get-Content -LiteralPath $manifest -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch { return $false }
    # -contains against the property NAMES rather than reaching for $json.plugins: under Set-StrictMode a
    # missing property THROWS, and a manifest with no plugins array is a real shape -- the fixture in
    # adopt-workflow-folder.tests.ps1 writes '{}' and caught this the first time the suite ran. Same
    # idiom, same reason, as the settings walk in dkj-subagents-shopify's floor session check.
    if ($null -eq $json) { return $false }
    if (-not ($json.PSObject.Properties.Name -contains 'plugins')) { return $false }
    foreach ($plugin in @($json.plugins)) {
        if ($null -eq $plugin) { continue }
        if (-not ($plugin.PSObject.Properties.Name -contains 'name')) { continue }
        if (([string]$plugin.name) -eq $workflow) { return $true }
    }
    return $false
}
function Get-WorkflowFolderName {
    <#
        The name of the workflow's own root folder in $RepoRoot: 'dkj-policy' normally, and whichever
        earlier name is present where a repo has not migrated yet -- 'contributing-davekjohn', then
        'workflow-davekjohn'.

        WHY THIS EXISTS (#886, August 26, 2026). The folder renamed, and the five seam DEFAULTS below all
        compose a path out of it. Hardcoding the new name would point a consumer's changelog and release
        roots at a directory they do not have, and the fold would then create a second changelog beside the
        one holding their history rather than failing loudly. Hardcoding the old name would send every NEW
        consumer to a folder the scaffolder no longer writes. Neither is a default worth shipping.

        AND IT HAS NOW RENAMED TWICE (#1437, September 5, 2026): 'contributing-davekjohn' became
        'dkj-policy' when the plugin did, because the folder is named after the plugin that legislates it.
        That is the argument above holding rather than a new one -- which is why the list grew by an entry
        instead of the function being rewritten. THE ORDER IS NEWEST FIRST and the walk stops at the first
        hit, so a repo mid-migration that briefly has two of them gets the newer, which is the one a writer
        would have made.

        SO: PREFER WHAT EXISTS, which is the same answer Resolve-BranchFilePath gives one level down for the
        documents inside this folder. A repo with none of them gets the current name, so a writer creates the
        current one.

        Deliberately NOT a seam. A repo that wants to differ already has Get-ChangelogPath and the four
        release-root seams to say so; a sixth answer for "what is the folder called" would let those five
        disagree with each other.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    foreach ($name in @('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')) {
        if (Test-Path -LiteralPath (Join-Path $RepoRoot $name) -PathType Container) { return $name }
    }
    return 'dkj-policy'
}

function Get-DefaultReleaseHistoryPath {
    <#
        The release-history seam's computed default (issue #885, group E): '<workflow folder>/releases/history.md'
        for every repo, the folder name from Get-WorkflowFolderName.

        history.md, NOT README.md: that same folder's 'releases/README.md' already names its
        seam-ANSWERS page (adopt-workflow-folder.ps1's own scaffold target). The list and the answers are
        two different documents that happen to share a filename in the source repo only because they sit at
        different directory levels there; folded into one directory they need different names.

        THE SOURCE BRANCH IS GONE (issue #998, August 27, 2026), and it is retired rather than repointed --
        read Get-DefaultChangelogPath above for the full argument, which applies here unchanged. In short:
        #980 moved this repo's own release list into dkj-policy/ and STATED the seam, so the
        root answer was already inert here; and the test the branch rested on detects "publishes plugins"
        rather than "is this workflow's source", so all it could still do was hand some future repo a
        'releases/README.md' for an unrelated reason. This REVERSES the August 19, 2026 answer that sent
        the list back to the root, and reverses it a second time rather than quietly -- see
        script-contract-lib.ps1's Get-ReleaseHistoryPath record for why that premise had already expired.

        ACCEPTED COST, unchanged in shape: an existing consumer's history splits at the point this default
        starts applying to them -- old rows stay at their root file, new rows land here -- rather than the
        seam moving under them silently forever. Repointing the seam back to the old path keeps a single
        list for a consumer who would rather have that, and Assert-WorkflowIsolatedSeamPath accepts
        'releases/README.md' as this seam's pre-isolation answer, so that repo is told rather than moved.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return "$(Get-WorkflowFolderName -RepoRoot $RepoRoot)/releases/history.md"
}
function Get-DefaultReleaseChangelogNotesRoot {
    <#
        The generated tier-0 notes' (always written) computed default (issue #885, group E; renamed and
        relocated by issue #914, August 26, 2026).

        'changelog', NOT 'development'. The name says what the document IS -- the changelog for that
        version, the entries as the fold left them, which is literally what CHANGELOG.md held before the
        cut emptied it -- rather than which stage of the work produced it. 'development/' named the stage,
        the same mistake 'notes/' and 'highlights/' made in the sibling root that became 'audience/' (see
        Get-ReleaseNoteRoot's own record), and it is the only root under releases/ that still named
        something other than its reader or its content.

        AND IT IS ONE ANSWER FOR BOTH KINDS OF REPO, where every other computed default in this file
        branches on Test-IsWorkflowSourceRepo. Those branch because the source keeps its ROOT files: a
        repo's changelog and its release history exist whichever tooling cut them, so a plugin folder is
        the wrong home for them. This tree is the opposite -- nothing writes it but a cut, so it exists
        only BECAUSE the workflow does, exactly like the hand-written note that already lived in the
        folder. #914 is the decision that the source stops being special here, which REVERSES the
        August 14, 2026 answer recorded at Get-ReleaseNoteRoot ("the generated development/ and github/
        trees stay at the repo root deliberately"). What changed is not that argument's force but its
        subject: it was made while those roots had no seam at all and their location was a fact about
        this repo, and #885 turned them into a seam every consumer answers.

        SO THE BRANCH IS GONE RATHER THAN LEFT RETURNING THE SAME STRING TWICE. A vestigial branch reads
        as a distinction somebody still relies on, and the next reader repairs one half of it.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return "$(Get-WorkflowFolderName -RepoRoot $RepoRoot)/releases/changelog"
}


function Get-DefaultReleaseGithubNotesRoot {
    <# The generated GitHub Release body's computed default (issue #885, group E), relocated into the
       workflow folder by #914 on the same reasoning as Get-DefaultReleaseChangelogNotesRoot above -- read
       that one first, including why it no longer branches on the source. Its NAME was already right: the
       root says who reads it. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return "$(Get-WorkflowFolderName -RepoRoot $RepoRoot)/releases/github"
}

function Get-DefaultReleaseInternalNotesRoot {
    <# The generated internal note's (tier 1) computed default (issue #885, group E). Same reasoning and
       same "no prior seam to redefine" argument as Get-DefaultReleaseChangelogNotesRoot -- read that one
       first. Read by new-internal-note.ps1, which is why it exists as its own function rather than being
       folded into the changelog-notes one: the two roots are read by different scripts on different days
       (the cut writes the changelog note at every release; the internal note is a separate, later run). #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    return "$(Get-WorkflowFolderName -RepoRoot $RepoRoot)/releases/internal"
}

function Get-PreIsolationSeamPath {
    <#
        THE ANSWER EACH ISOLATED SEAM GAVE BEFORE IT ISOLATED (issue #956, August 27, 2026), and the only
        value Assert-WorkflowIsolatedSeamPath below accepts outside the workflow folder. One entry per
        seam in that assert's set, and nothing else: this is a lookup of history, not a list of
        preferences.

        WHY IT EXISTS. #885 and #914 moved these seams' defaults into the workflow folder, and a consumer
        meets that through a plugin update rather than by choosing to -- exactly the situation the assert
        already tolerates for the FOLDER's own rename. A consumer that keeps its CHANGELOG.md at the repo
        root is not an un-migrated state to be corrected but a layout, and both Shopify consumers answered
        the seam that way independently (#956: smartwatchbanden and xoxowildhearts, 14 and 24 pending
        entries). The assert refused it with exit 1, so the fold failed AFTER the merge had landed and the
        entry had to be folded by hand.

        THE ARGUMENT IS NOT NEW, ONLY APPLIED IN A SECOND PLACE. Get-ReleaseNoteRoot is exempt from the
        assert outright, and its stated reason is that it is "the one seam whose whole point is to keep
        meaning what it meant yesterday." That is true of every seam here for the repo that was already
        folding into the root before the folder existed. So the tolerance is written per seam INSIDE the
        guard rather than as a second blanket exemption: a typo'd 'README.md' is still refused for every
        one of them, which an exemption would not do.

        TWO NAMES FOR THE CHANGELOG NOTES ROOT. #914 relocated that tree and renamed it in one move
        (releases/development -> <folder>/releases/changelog), so a consumer sitting at the root may carry
        either the pre-rename directory or the renamed one beside its siblings. Both are the same layout
        answered at the same place, so both are recognised.

        NOT KEYED ON THE SEAM'S CURRENT DEFAULT, deliberately: that default is computed and will move
        again. These strings are what the tooling wrote before the move, which is a fact about the past
        and therefore does not go stale.
    #>
    param([Parameter(Mandatory)][string]$SeamName)
    switch ($SeamName) {
        'Get-ChangelogPath'             { return @('CHANGELOG.md') }
        'Get-ReleaseHistoryPath'        { return @('releases/README.md') }
        'Get-ReleaseChangelogNotesRoot' { return @('releases/development', 'releases/changelog') }
        'Get-ReleaseGithubNotesRoot'    { return @('releases/github') }
        'Get-ReleaseInternalNotesRoot'  { return @('releases/internal') }
    }
    return @()
}

function Assert-WorkflowIsolatedSeamPath {
    <#
        THE PROVENANCE PREFLIGHT (issue #885, group D): the backstop under the four seams groups A and E
        made isolate-by-default (Get-ChangelogPath, Get-ReleaseHistoryPath,
        Get-ReleaseChangelogNotesRoot, Get-ReleaseGithubNotesRoot) plus the internal-note root read the
        same way -- not a replacement for them. Their COMPUTED defaults are already proven isolated; what
        this catches is a repo's own EXPLICIT override resolving somewhere it should not, e.g. a typo'd
        Get-ChangelogPath pointing at 'README.md' and the cut truncating a file it does not own. Call this
        right after a seam of that kind resolves, before anything is read from or written to the path.

        TWO ANSWERS PASS, NOT ONE (issue #956, August 27, 2026): the workflow folder, and the seam's own
        PRE-ISOLATION answer from Get-PreIsolationSeamPath above -- read that function for why a root
        CHANGELOG.md is a layout rather than a mistake, and for the measurement that forced it. Before
        this, the guard could not tell a typo from a layout and treated both as a typo: it refused with
        exit 1 and had no opt-out, so the fold and the cut were hard-blocked in a consumer that had been
        folding into a root CHANGELOG.md since before the folder existed.

        THE SHAPE #956 PROPOSED FIRST WAS DECLINED, and the reason is worth keeping. It offered warning
        instead of refusing "where the resolved path exists and is non-empty", on the grounds that a
        typo'd README.md and a real 24-entry CHANGELOG.md are distinguishable by looking at the target.
        By that test they are not: README.md exists and is non-empty in every repo, so the one case this
        guard's own docstring names as its reason would have passed with a warning while the cut went on
        to truncate it. What separates the two is not whether the target has content but whether the seam
        is pointing where it used to point, which is what the lookup above answers.

        SILENT ON THE LEGACY MATCH, deliberately. A recognised layout is not a finding, and this runs at
        every fold and every cut -- a line printed there would be noise in a repo that has answered the
        seam the same way for months. Telling an existing consumer that a default moved under them
        belongs to the adoption run, which is where re-adoption warnings already live (issue #955).

        DELIBERATELY NOT UNIVERSAL. Get-ReleaseNoteRoot is read the same way but is NOT checked here and
        must never be: its own contract record argues, on purpose, that its default stays at the root
        ('releases/notes') rather than moving into the folder, because real consumers already configure it
        or rely on that literal fallback -- forcing it through this assert would refuse the one seam whose
        whole point is to keep meaning what it meant yesterday.

        THE SOURCE REPO IS NO LONGER EXEMPT, and losing that exemption is the point rather than a side
        effect (issue #998, August 27, 2026). The exemption read: "it deliberately keeps these roots at its
        own root by its own decision (Dave, August 14, 2026), and Get-Default*'s own computed answer for a
        source IS that root". BOTH halves are gone. #980 moved this repo's changelog and release list into
        dkj-policy/ and stated the seams to say so, and #998 retired the source branch from the
        computed defaults -- so there is no repo left whose computed answer is a root file, and nothing for
        an exemption to protect.

        WHAT IT COST TO KEEP: a blanket pass. This guard exists to catch a repo's own seam resolving
        somewhere it should not -- the docstring's own example is a typo'd Get-ChangelogPath pointing at
        'README.md' and the cut truncating a file it does not own -- and the repo that MAINTAINS the guard
        was the one repo it never ran against. It runs against this one now.

        MEASURED BEFORE IT WAS REMOVED, because removing a guard's escape hatch is only safe if the repo
        underneath it passes: all five seams this assert covers resolve inside the folder here. Three are
        stated in scripts/repo-config.ps1 (Get-ChangelogPath, Get-ReleaseHistoryPath,
        Get-ReleaseInternalNotesRoot, all under dkj-policy/) and the other two run on computed
        defaults that #914 already put there. A plugin-publishing repo that really does keep a root file is
        still covered, by the pre-isolation lookup below rather than by a blanket pass -- which is the
        difference between recognising a layout and waving a repo through.

        Refuses (Write-Error + exit 1) rather than returning a bool, matching every other guardrail in
        cut-release.ps1: a caller that reaches this call is about to read or write the path, so a silent
        return leaves the mistake to be discovered in the write itself, at which point it may already have
        clobbered something.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$SeamName
    )
    $normalized = $RelativePath -replace '\\', '/'
    # EVERY FOLDER NAME IS ALLOWED WHILE CONSUMERS MIGRATE (#886, August 26, 2026; #1437, September 5,
    # 2026). The folder renamed 'workflow-davekjohn/' -> 'contributing-davekjohn/' -> 'dkj-policy/', and a
    # consumer meets that through a plugin update
    # rather than by choosing to -- so their existing folder is still where their seams resolve. Allowing
    # only the new name would turn this guard from an isolation check into a hard stop on every seam call in
    # every unmigrated consumer, and it REFUSES with exit 1 rather than warning. Same answer as
    # Get-BranchFilePaths gives for the documents inside it: recognise the old name, write the new one.
    $allowedRoots = @('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')
    foreach ($root in $allowedRoots) {
        if ($normalized -eq $root -or $normalized -like "$root/*") { return }
    }
    # AND THE SEAM'S OWN PRE-ISOLATION ANSWER, EXACT MATCH ONLY (#956). Exact, not prefix: every call site
    # passes the resolved seam value itself, so the legacy layout is that value or it is not that layout --
    # a prefix match would additionally wave through paths BELOW a legacy file, which no caller produces
    # and which a typo could.
    $legacyRoots = @(Get-PreIsolationSeamPath -SeamName $SeamName)
    foreach ($legacy in $legacyRoots) {
        if ($normalized -eq $legacy) { return }
    }
    if ($legacyRoots.Count -gt 0) {
        $legacyList = ($legacyRoots | ForEach-Object { "'$_'" }) -join ' or '
        $allowedClause = "the only answer accepted outside that folder is $legacyList, which is where this seam pointed before it isolated"
    } else {
        $allowedClause = 'no answer outside that folder is accepted for it'
    }
    Write-Error "$SeamName resolved to '$RelativePath'. This repo is a workflow consumer (issue #885) and this seam isolates into dkj-policy/ by default; $allowedClause. Nothing was read or written. If '$RelativePath' is genuinely where this belongs, move it under dkj-policy/ instead of pointing the seam outside it."
    exit 1
}
