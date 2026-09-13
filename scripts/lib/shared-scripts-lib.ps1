<#
.SYNOPSIS
    Registry + helpers for the shared workflow scripts (root copy <-> plugin mirror).

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')

    Some workflow scripts are repo-agnostic and are mirrored into the plugin as a shared source, so
    consumers do not duplicate them (issue #81). The model: the **workshop root copy is the
    canonical, tested source**; the **plugin mirror** is what a consumer runs via a skill. Both are
    LF-normalized identical -- made possible because the scripts resolve their repo root
    dual-context (CLAUDE_PROJECT_DIR for a consumer, otherwise the git root).

    Supplies Get-SharedScriptPairs (the registry) and Get-NormalizedScriptContent (LF-normalized
    read). The generator (scripts/sync/build-shared-scripts.ps1), the lint gate
    (check-plugin-integrity.ps1), and the test (scripts/tests/shared-scripts.tests.ps1) share this
    one source.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# WHERE THE PLUGINS ARE, so this registry does not have to know. A pair names the plugin it travels in
# and nothing about the layout; Get-PluginRootByName turns that name into a folder. Unconditional and
# unguarded: this lib is workshop-only (it is not itself mirrored), so the sibling is always there.
. (Join-Path $PSScriptRoot 'plugin-tree-lib.ps1')

function Get-SharedScriptPairs {
    <#
        The registry of shared scripts. Each pair: the canonical root source (Source) and the
        plugin mirror (Mirror), both repo-root-relative. Extend per centralized script.

        LibOnly = $true marks a DOT-SOURCED library rather than a standalone entry point. Such a
        file never resolves a repo root of its own -- it is reached via a $PSScriptRoot-relative
        dot-source from a caller that already resolved one -- so the dual-context invariant does not
        apply to it. The flag lives HERE, next to the registration, because the test used to keep
        its own hand-written list of lib names: a second literal that a new lib silently fell out of
        (the accumulation shape of #275/#331). Registering a lib now declares its own exception.

        Skill names the plugin skill that DOCUMENTS this script for a consumer, and it is REQUIRED on
        every non-LibOnly entry -- '' means "no skill documents this", which is a declaration rather
        than an omission. The lint gate's parameter check (check 18) reads it: a consumer who only has
        the mirror plus its skill cannot use a parameter the skill never names. Measured August 4,
        2026: three were missing that way, and -NoPush -- the one inspection step before a release is
        pushed -- was among them. Same reasoning as LibOnly: declared next to the registration, so a
        newly shared script cannot fall out of the check silently.

        SkillParamsExempt lists parameters that deliberately do NOT belong in a skill, each with a
        reason at the registration. Without it the check would be bypassed wholesale the first time it
        fired on a test-only override, and a gate that gets bypassed guards nothing.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # The plugin set, when the caller has already resolved it. Optional, and it exists for exactly
        # one caller: the lint gate derives the set once at its top, inside a try/catch, so that a
        # marketplace.json it cannot parse degrades to an empty set instead of aborting a run that has
        # nineteen more checks to report. Without this it would resolve the set a SECOND time in here,
        # unguarded -- measured before the parameter was added: a corrupt marketplace killed the gate at
        # check 8, so checks 9 through 22 never ran and no Summary was printed at all. One read per run,
        # one place that decides what a parse failure means.
        [AllowNull()][AllowEmptyCollection()][object[]]$PluginRoots
    )

    $pairs = @(
        @{
            Name   = 'fold-changelog-entry'
            Source = 'scripts\release\fold-changelog-entry.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'fold-changelog'
        },
        @{
            Name   = 'open-pr'
            Source = 'scripts\release\open-pr.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'open-pr'
        },
        @{
            Name   = 'check-roster-sync'
            Source = 'scripts\sync\check-roster-sync.ps1'
            Plugin = 'dkj-subagents-alpha'
            Skill  = 'sync-roster'
            # All three exist so the test suite can point the check at a fixture instead of the real
            # machine. A consumer never types them, and documenting them would invite someone to.
            SkillParamsExempt = @('ConsumerPathOverride', 'CacheRootOverride', 'UserHomeOverride')
        },
        @{
            # Travels in the WORKFLOW plugin, not the core team (August 8, 2026). What it checks is that the
            # consumer's branch-info.ps1 and repo-config.ps1 expose every function the branch/release
            # scripts call -- so a repo that never enabled the workflow plugin was being told at every
            # session start to configure scripts it does not have. That is the exact defect the
            # plugin-serves-the-consumer doctrine names, arriving from the checker rather than the
            # scripts.
            Name   = 'check-script-contract'
            Source = 'scripts\sync\check-script-contract.ps1'
            Plugin = 'dkj-policy'
            # No skill, and none is wanted: this runs from a SessionStart hook and reports. Nobody
            # invokes it as a procedure, so there is no procedure to write down.
            Skill  = ''
        },
        # RETIRED, AUGUST 7, 2026: 'new-changelog-entry'. It was new-branch's child step, and this entry
        # noted that it had no skill of its own because that skill documented both. The name stopped being
        # true when the branch/ split gave it a step list to write, and again when it gained the templates
        # -- it described one of four outputs. Merged into new-branch.ps1, which is the one concept it was
        # ever a half of. Nothing else called it and no document told anyone to run it.
        @{
            Name   = 'new-branch'
            Source = 'scripts\task\new-branch.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'new-branch'
        },
        @{
            # Shared for the same reason new-branch is: the `git checkout main` collision that makes a
            # lane necessary is a property of ship-pr.ps1, which every consumer of this workflow runs.
            # A repo-local copy would be a copy of the answer to a shared problem.
            Name   = 'worktree-lane'
            Source = 'scripts\task\worktree-lane.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'worktree-lane'
        },
        @{
            Name   = 'park-branch'
            Source = 'scripts\task\park-branch.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'park'
        },
        @{
            # THE AUTOMATIC HALF OF PARKING (#900, August 26, 2026), invoked by the Stop hook
            # cycle-autopark.ps1 -- which is why this row exists at all: the hook runs from
            # ${CLAUDE_PLUGIN_ROOT}, so a consumer whose plugin carried the hook but not this script
            # would have a hook that silently does nothing.
            #
            # DOCUMENTED IN THE 'park' SKILL RATHER THAN ITS OWN, beside park-branch. The three parking
            # moments -- at creation, deliberately mid-work, and automatically -- are one subject, and a
            # reader deciding between them wants them on one page. It also means the model does not
            # reach for this: the page carries disable-model-invocation, and the hook is what runs it.
            Name   = 'park-cycle'
            Source = 'scripts\task\park-cycle.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'park'
        },
        @{
            # CENTRALIZED FROM TWO CONSUMER COPIES (inbound #815, August 21, 2026) -- the #81 argument
            # again: a mechanism several repos need, living as a hand-written copy in each, is a
            # mechanism that will drift. Nothing in the plugin deleted a branch anywhere before this.
            Name   = 'prune-merged'
            Source = 'scripts\task\prune-merged.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'prune-merged'
        },
        @{
            # PER-DEVICE PLUGIN VERSION OVERVIEW (Dave, September 8, 2026). "Which plugin version is
            # installed in this checkout, on this machine, and is a plugin update due?" -- a question
            # no existing check answers: check-connectors' check 4 goes inert on a plain consumer with
            # no sibling source checkout. Reads the install record for this checkout's path
            # (Get-InstallRecord) against the marketplace clone's plugin.json .version + git HEAD --
            # both present on every consumer machine -- and prints a verdict per plugin.
            #
            # SHARED for the ordinary reason: it is a consumer's question far more than this repo's,
            # and the alternative is every consumer hand-deriving the same two reads. It reuses
            # check-report-lib (already mirrored to dkj-policy as check-report-lib-workflow),
            # plugin-tree-lib and native-capture-lib -- all plugin-carried already, so the payload
            # gains only this file.
            Name   = 'plugin-versions'
            Source = 'scripts\task\plugin-versions.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'plugin-versions'
            # Fixtures: a scratch repo root and a scratch ~/.claude home, so the suite can put a whole
            # install-record + marketplace-clone state in front of the script. A consumer never types
            # either.
            SkillParamsExempt = @('RootOverride', 'UserHomeOverride')
            # Timeable with no arguments: it reads two JSON files and shells to git in a clone, and
            # writes nothing anywhere.
            MeasureArgs = @()
        },
        @{
            # #1890's buildable half: the 1 + N commands a checkout's own plugin update always was,
            # run as one. Shares plugin-versions.ps1's own Get-EnabledPlugins/slug-check helpers
            # (check-report-lib) and Invoke-NativeCapture (native-capture-lib), both already
            # plugin-carried, and runs plugin-versions.ps1 itself as its step-3 receipt -- so the
            # payload this adds is this one file.
            Name   = 'update-plugins'
            Source = 'scripts\task\update-plugins.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'update-plugins'
            # Fixtures: a scratch repo root, a scratch ~/.claude home, and a fixture receipt script --
            # the last one so the suite is not required to make plugin-versions.ps1's own full
            # install-record + marketplace-clone state exist just to prove step 3 was invoked. A
            # consumer never types any of the three.
            SkillParamsExempt = @('RootOverride', 'UserHomeOverride', 'ReceiptScriptOverride')
            # -DryRun: reads the enable state and prints, calls the CLI for nothing and writes
            # nothing anywhere -- the one arg-shape worth timing without a live 'claude' on PATH.
            MeasureArgs = @('-DryRun')
        },
        @{
            # THE POLICY-DRIFT REPORT. The corollary in CONTRIBUTING-portable.md's "A third rank sits
            # above both" -- a consumer document may point at a shared law or answer a seam it names,
            # never restate it -- had two narrow deliveries (check-retired-doc-name, a filename;
            # check-supremacy-declaration, an adjacency) and nothing that covered the rule as a whole.
            #
            # IT IS NOT THE CHECK #1380 DECLINED, and the row says so here because the decline is the
            # first thing a reader will reach for. That decline is about a SCRIPT deciding what a
            # sentence means, and it stands: this one never reads a sentence. It resolves WHICH
            # documents sit at which rank on this machine, echoes the two gated slices, and hands the
            # judgement to the session -- which is the half #1380 said only a reader can do.
            #
            # ON-DEMAND AND REPORT-ONLY, so unlike the two prose checks it HAS a skill and has no hook
            # and no CI leg. It always exits 0 once it can answer; an exit code would be a verdict it
            # has not earned, and a gate here would be the declined check wearing a different hat.
            #
            # IT INVENTS NO SECOND ANSWER TO "WHICH PLUGINS ARE HERE". The enable comes from
            # Get-EnabledPlugins and the install record from Get-InstallRecord / Test-PluginInstalledHere
            # -- the same lib, and the same two questions, check-roster-sync and check-script-contract
            # already read. What it does not reuse is Resolve-PluginDir, and its own docstring says why:
            # that function requires an agents/ dir at every return path, so on a WORKFLOW plugin it
            # answers $null on every machine, always.
            Name   = 'check-policy-drift'
            Source = 'scripts\task\check-policy-drift.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'check-policy-drift'
            # A fixture root, plus an always-on root the suite can point at a scratch document tree.
            # A consumer never types either.
            SkillParamsExempt = @('RootOverride', 'RootDocument')
            # Timeable with no arguments: it reads files and prints, and writes nothing anywhere.
            MeasureArgs = @()
            # Step 4a ascends two levels off $PSScriptRoot to find the sibling plugin folders, so the
            # mirror has to be RUN from its own depth and not only compared with the source (#1857).
            MirrorRun = 'policy-drift-report.tests.ps1'
        },
        @{
            # Issue #411. Was excluded as "workshop-only" on the reasoning that merge policy and the CI
            # check name are repo-specific. Only the first half held: the check NAME never entered the
            # logic (step 3 watches whatever checks exist and reads the exit code), and the merge METHOD
            # moved into the seam as the optional Get-PrMergeMethod. Without this mirror, merge + fold is
            # hand work in every consumer -- and it is the one sequence classified safety-critical,
            # because it merges to main and then commits directly to main.
            Name   = 'ship-pr'
            Source = 'scripts\release\ship-pr.ps1'
            Plugin = 'dkj-policy'
            # The gap declared here on August 4, 2026 is closed: the route the cut-release skill sends
            # the reader to ("the normal new-branch -> ship-pr route") now has a page. It documents
            # verify-resolved-issues too, which is why that entry points here rather than at one of
            # its own.
            Skill  = 'ship-pr'
        },
        @{
            # Travels with ship-pr rather than on its own merit: it IS ship-pr's step 6, and a consumer
            # whose ship-pr calls a file that is not in the mirror would fail at the last step of a
            # sequence that has already merged. Portable as it stands -- dual-context root, Get-RepoName,
            # and pr-issues-lib/native-capture-lib are both mirrored already.
            Name   = 'verify-resolved-issues'
            Source = 'scripts\release\verify-resolved-issues.ps1'
            Plugin = 'dkj-policy'
            # No skill of its own, and that is right: it IS ship-pr's step 6 and runs from there, so
            # whatever documents ship-pr documents this. That page now exists and carries a section for
            # running this step on its own, so the inherited gap is closed with ship-pr's rather than
            # by giving a step of a sequence a procedure page of its own.
            Skill  = 'ship-pr'
        },
        @{
            # Travels for the same reason verify-resolved-issues above does, one step further out: it is
            # that script running from the MERGE instead of from the shipping session (#1511), which is
            # what a merge queue forces. Registered here by #1516, which is the issue that made the queue
            # a policy for every consumer rather than a setting on one trunk -- a consumer's
            # verify-resolved.yml calls THIS file out of the plugin tree, so a copy that stayed behind in
            # the source would leave the scaffolded runner pointing at a path they do not have.
            #
            # Portable as it stands: dual-context root, both API calls go through gh with an explicit
            # -Repo, the trunk arrives as a parameter, and verify-resolved-issues (which it drives) is
            # already mirrored beside it.
            Name   = 'verify-pushed-merges'
            Source = 'scripts\release\verify-pushed-merges.ps1'
            Plugin = 'dkj-policy'
            # No skill of its own, on verify-resolved-issues' reasoning exactly: it is a step of the ship
            # sequence relocated to a CI trigger, and nobody invokes it as a procedure. Its one caller is
            # a workflow file, which is the same call check-unfolded-entry gets.
            Skill  = ''
            # NO MeasureArgs, and it is a declaration rather than an omission: with no -Before/-Sha this
            # script has no push to resolve and refuses, so a timed bare run would measure the refusal
            # rather than the work. Every argument that WOULD make it do something names a real merge.
        },
        @{
            # Issue #413. Three repos had written their own copy of this repair tool, which is the
            # argument for one source rather than for a fourth. Its workshop-shaped default file set --
            # the part that made it unusable elsewhere -- moved into the seam as Get-MojibakePaths.
            Name   = 'fix-mojibake'
            Source = 'scripts\maintenance\fix-mojibake.ps1'
            Plugin = 'dkj-policy'
            # The gap declared here on August 4, 2026 is closed. It was mirrored because three repos had
            # each written their own copy -- three people needing it and none with a page to read -- and
            # that same argument is why the page had to follow the mirror rather than wait for someone to
            # ask for it. With this, check 18 covers every shared entry point except check-script-contract,
            # whose empty Skill is a statement rather than a gap.
            Skill  = 'fix-mojibake'
            # -Check is this script's documented report-only mode ("change nothing, exit 1 if any file
            # would change"), so it can be timed without repairing anything.
            MeasureArgs = @('-Check')
        },
        @{
            # What a skill COSTS and how fast the script behind it runs. It drives `claude plugin
            # details` (the count_tokens API) rather than counting anything itself, so the figure it
            # reports is the authoritative one and not a second, disagreeing estimate.
            #
            # IT TRAVELS IN dkj-policy, and the alternative was cheaper: a repo-level skill
            # would cost every consumer nothing, since only the repo that AUTHORS skills ever runs
            # this. Dave chose the plugin on August 22, 2026 -- the standing portable-first rule for
            # ways of working, against a precisely known ~200 always-on tokens, and against
            # .claude/skills/ being a pattern no gate here scans.
            #
            # NO MeasureArgs, deliberately, and it is the one entry where that is worth a sentence:
            # a plain run shells out to `claude plugin details` once per enabled plugin, so timing it
            # would measure the CLI and the network rather than this script. It is also the only
            # registered script that could time itself, which is a good enough reason on its own.
            # ---------------------------------------------------------------------------------------
            # The whole-machine tidy (September 10, 2026). A CONDUCTOR: six of its eleven lanes call a
            # script that is already registered here and already has its own suite, so mirroring it
            # adds one entry point rather than ten mechanisms. It is registered for the ordinary
            # reason every consumer accumulates the same residue -- finished branches, lanes that
            # outlived their branch, install records pointing at a checkout that has moved -- and the
            # source repo is where the classification is maintained.
            #
            # -DryRun IS THE MeasureArgs, and it is the honest timing rather than a cheap one: every
            # lane still runs and still reads, including both gh lookups and the delegations. What it
            # skips is the deletions, which are prune-merged's and are timed in prune-merged's own row.
            Name   = 'tidy-machine'
            Source = 'scripts\maintenance\tidy-machine.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'tidy-machine'
            MeasureArgs = @('-DryRun')
            # Fixture seams, so the suite can drive the machine-wide lanes against a scratch tree. A
            # consumer never types either, and documenting them would invite someone to.
            SkillParamsExempt = @('UserHomeOverride', 'ScratchRoot')
        },
        @{
            Name   = 'measure-skill'
            Source = 'scripts\maintenance\measure-skill.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'measure-skill'
            # A fixture root, so the suite can drive the script against a scratch tree. A consumer
            # never types it, and documenting it would invite someone to.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # measure-skill's parsing and formatting half. It is a lib for one reason: the parse reads a
            # human-formatted table whose shape the CLI owns, and a parser that cannot be tested without
            # shelling out to `claude` is one nobody pins. Pinned by
            # scripts/tests/measure-skill.tests.ps1 against captured output.
            Name    = 'measure-skill-lib'
            Source  = 'scripts\lib\measure-skill-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The ALWAYS-ON DOCUMENT PATH -- CLAUDE.md plus everything it '@'-imports -- measured per
            # document and per section, so the figure stops being produced by hand.
            #
            # IT IS REGISTERED UNDER measure-skill's PAGE, not one of its own (issue #875). Same
            # subject (what a session pays), same owner (the performance specialist), and only a
            # skill's DESCRIPTION is paid by every session -- so an existing page adds nothing to what
            # a consumer pays for it. That is the "which skill, not whether" half of the shared
            # automation-first rule, applied to the first script the rule was written against.
            #
            # THE #876 ENTRY IN CHANGELOG.md SAID THE OPPOSITE, and was corrected on this branch: it
            # declared the script deliberately repo-local because consumers do not share this repo's
            # condition. That argument was #861's, and #861 was about a SKILL -- a new always-on
            # description that would have judged an instruction document block by block. Packaging
            # deterministic code under a description that already exists is a different act, and the
            # boundary it drew (portable-first applies to rules, not to tooling with a per-session
            # cost) is not crossed by a mirror that costs nothing per session.
            #
            # NO MeasureArgs, and the reason is not safety: a plain run only reads. What it would time
            # is a repo reading its OWN documents, so the median would move with the repo measured
            # rather than with this script -- a figure nobody could reproduce, which is exactly what
            # pass 2 refuses to store.
            Name   = 'measure-always-on'
            Source = 'scripts\maintenance\measure-always-on.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'measure-skill'
        },
        @{
            # measure-always-on's engine: the import walk, the section split, and the calibrated
            # chars-per-token factor. A lib because the factor is the thing that went wrong -- it was
            # inherited unexamined at 3.70 through three hand measurements and was ~19% too generous,
            # so every token figure derived from it was under-stated while looking precise. A constant
            # nothing pins is a constant that drifts again; pinned by
            # scripts/tests/measure-always-on.tests.ps1.
            Name    = 'measure-context-lib'
            Source  = 'scripts\lib\measure-context-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The preamble every consumer-facing lint check opens with (issue #1422): the dual-context
            # root resolution and the always-on prose corpus, in one definition where five entry points
            # carried near-copies. IT HAS TO TRAVEL for the ordinary lib reason -- all five callers are
            # mirrored, so a lib that stayed behind would leave every consumer's copy dot-sourcing a file
            # they do not have.
            #
            # DEPENDENCY-FREE for Resolve-CheckRepoRoot, like plugin-tree-lib and source-repo-guard-lib:
            # it is dot-sourced on the first line that resolves anything. Get-CheckProseCorpus loads
            # measure-context-lib itself, guarded, from its own directory -- already mirrored here.
            #
            # NO CONTRACT ROW FOLLOWS: nothing in it is repo-owned. It reads an env var and asks git
            # where it is, so there is no seam a consumer has to answer.
            Name    = 'consumer-check-lib'
            Source  = 'scripts\lib\consumer-check-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            Name    = 'check-report-lib'
            Source  = 'scripts\lib\check-report-lib.ps1'
            Plugin  = 'dkj-subagents-alpha'
            LibOnly = $true
        },
        @{
            # THE LIB WITH A READER IN MORE THAN ONE PLUGIN, and therefore the entry with a second
            # mirror of the same source (August 8, 2026). check-roster-sync stays in the core while
            # check-script-contract went to the workflow plugin, and both dot-source this file as a
            # $PSScriptRoot-relative sibling. The alternative -- the workflow mirror reaching into the
            # core plugin's cache directory -- was rejected on sight: the two plugins are separately
            # versioned and separately installed, so that builds a runtime dependency on a path a
            # version mismatch silently breaks.
            #
            # A SECOND ENTRY RATHER THAN A LIST OF MIRRORS, because every consumer of this registry
            # already loops per pair and copies Source -> Mirror; two entries need no new machinery in
            # the generator, in the lint's check 8, or in check 18 (which skips LibOnly entirely). What
            # the loops do NOT tolerate is a duplicate Name: the test suite looks pairs up with
            # Where-Object { $_.Name -eq ... } and would get an array back, so the second entry carries
            # the plugin in its name. That was verified against all three readers before it was written,
            # not assumed from the absence of a uniqueness assertion.
            Name    = 'check-report-lib-workflow'
            Source  = 'scripts\lib\check-report-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            Name    = 'native-capture-lib'
            Source  = 'scripts\lib\native-capture-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE FALSE-POSITIVE MACHINERY A PreToolUse COMMAND GUARD NEEDS (issue #1669), dot-sourced
            # by hooks/guard-working-copy.ps1. It exists as a lib rather than inside that hook because
            # this repo already ships a second command guard -- dkj-subagents-shopify's guard-live-theme.ps1 --
            # whose header records what learning these exemptions the hard way cost it, and #1669's
            # point is that the second guard must not pay that price again.
            #
            # THE SECOND MIRROR IS TAKEN, and the entry for it sits directly below (issue #1734). #1669
            # introduced this lib and deliberately left guard-live-theme.ps1 carrying its own copy of
            # the same logic: that guard protects a live customer-facing theme, so putting its refactor
            # in the branch that introduced a brand-new hook would have doubled the review surface of
            # both, and the half with money behind it would have got the less careful attention.
            #
            # NO CONTRACT ROW FOLLOWS: nothing in it is repo-owned. It reads a payload it is handed and
            # takes its exempt-command set from its caller, so there is no seam a consumer answers.
            Name    = 'command-guard-lib'
            Source  = 'scripts\lib\command-guard-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE (issue #1734), on check-report-lib-workflow's
            # precedent -- read its two banners for why a second entry rather than a list of mirrors,
            # and why the name carries the plugin. Nothing here needs restating.
            #
            # WHY dkj-subagents-shopify NEEDS ITS OWN COPY: hooks/guard-live-theme.ps1 dot-sources this
            # lib instead of carrying the heredoc stripping, the here-string stripping, the
            # leading-command reader and the segment split itself -- which is where all of it was
            # learned, and which is why #1669 extracted it from that file in the first place. A plugin
            # must not reach into another plugin's tree: dkj-policy and dkj-subagents-shopify are
            # separately versioned and separately installed, and a Shopify consumer may run this team
            # without the workflow plugin, so a cross-plugin dot-source is a dependency a version
            # mismatch breaks silently.
            #
            # THAT DOT-SOURCE IS GUARDED, unlike sync-main.ps1's on native-capture-lib, and the two
            # are right for opposite reasons. A payload missing THAT file must fail at load rather than
            # push unbounded; a payload missing THIS one must not brick every shell command in a
            # consumer, so the hook degrades to matching the whole payload and says so on stderr.
            Name    = 'command-guard-lib-shopify'
            Source  = 'scripts\lib\command-guard-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # THE JUDGEMENT BEHIND hooks/guard-working-copy.ps1 (issue #1669), split off from the hook
            # for the reason fanout-lib.ps1 states for its own split: it can then be tested -- and
            # MEASURED over a corpus of thousands of real commands -- without a payload and a process
            # per case. #1669 asks for a measured false-positive rate, and the measuring script has to
            # run the SAME decision the hook makes rather than a second copy of it.
            #
            # It dot-sources command-guard-lib.ps1 as a $PSScriptRoot-relative sibling, which the entry
            # above mirrors into the same directory.
            Name    = 'working-copy-guard-lib'
            Source  = 'scripts\lib\working-copy-guard-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE, on check-report-lib-workflow's precedent five entries
            # up -- read its two banners for why a second entry rather than a list of mirrors, and why the
            # name carries the plugin. Nothing here needs restating.
            #
            # WHY dkj-subagents-shopify NEEDS ITS OWN COPY (inbound #1181, September 1, 2026): sync-main.ps1 became
            # a caller. Its five git network calls ran unguarded and unbounded -- the same hang #1179
            # measured, in the script that pushes a commit holding a third party's in-flight edits -- and
            # the guard lives in this lib. dkj-subagents-shopify and dkj-policy are separately
            # versioned and separately installed, and a Shopify consumer may run the first without the
            # second, so reaching into the workflow plugin's cache would be a dependency a version
            # mismatch breaks silently. sync-main.ps1's dot-source is UNGUARDED for the matching reason:
            # a payload missing this file must fail at load, not push unbounded.
            Name    = 'native-capture-lib-shopify'
            Source  = 'scripts\lib\native-capture-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # THE IN-PROCESS SIBLING OF native-capture-lib (issue #1625, September 8, 2026). The six
            # SessionStart hooks in this family each spawned a second powershell.exe to run their own
            # check script, on top of the one the harness had already started to run the hook. This lib
            # holds the one call that replaces it, and its header carries the measurement: 219 ms of
            # interpreter start-up against 6 ms in-process, and 311-443 ms of real wall-clock across the
            # six once the harness's PARALLEL hook execution is accounted for rather than assumed away.
            #
            # A LIB RATHER THAN FOUR LINES IN EACH HOOK, because the pattern has three traps that all
            # fail SILENTLY -- an array splats positionally in-process, Write-Host never reaches the
            # pipeline without 6>&1, and one Write-Host can carry several lines. A drifted sixth copy
            # would not crash; it would forward the wrong thing, or nothing, into the session context.
            # Each is written out in hook-check-lib.ps1's own header with what it measured.
            Name    = 'hook-check-lib'
            Source  = 'scripts\lib\hook-check-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE, on native-capture-lib-shopify's precedent above --
            # read check-report-lib-workflow's banner for why a second entry rather than a list of
            # mirrors, and why the name carries the plugin. roster-sessioncheck.ps1 is the caller here:
            # it is the one hook in this family that ships in the core team rather than in the workflow
            # plugin, and the two are separately versioned and separately installed, so reaching into
            # dkj-policy's cache would be a dependency a version mismatch breaks silently.
            Name    = 'hook-check-lib-alpha'
            Source  = 'scripts\lib\hook-check-lib.ps1'
            Plugin  = 'dkj-subagents-alpha'
            LibOnly = $true
        },
        @{
            # THE OTHER HALF OF THE SAME COST (issue #1605, September 8, 2026). hook-check-lib above
            # removed the second interpreter a hook starts; this one removes the REPEAT -- the
            # 'startup|resume|clear|compact' matcher means a session with four compactions runs every
            # check five times, and connector-sessioncheck's #1591 fallback cannot be run in-process
            # at all (it is bounded by a 30 s timeout, which an in-process call cannot be abandoned
            # under). So its verdict is held for the life of the session instead, keyed on the
            # session_id the harness writes to the hook's stdin.
            #
            # MIRRORED INTO dkj-policy ONLY, and only that, because connector-sessioncheck.ps1 is its
            # one caller and ships there. A consumer's hook dot-sources it as a $PSScriptRoot sibling,
            # so a payload without it would find nothing -- which the hook handles by measuring, the
            # same way it did before this lib existed, but the pair is registered so that never
            # becomes the normal case. No contract row follows: nothing in it is repo-owned. It reads
            # a payload the harness sends and writes under temp.
            Name    = 'session-cache-lib'
            Source  = 'scripts\lib\session-cache-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE MERGED-PR PROOF (issue #1194, September 1, 2026) -- was THIS ref merged, or only a
            # branch that once wore its name? A THIRD lib with a reader in more than one plugin, and it
            # arrived the way the argument for sharing is usually only made in hindsight: the same
            # mechanism was repaired TWICE on one day, in two neighbouring scripts, by two branches that
            # were open at the same time and did not know about each other -- inbound #1190 in
            # dkj-subagents-shopify's sync-main.ps1 and #1191 in the workflow plugin's prune-merged.ps1. Both
            # repairs were correct. By the evening the copies had already diverged, over the comparer the
            # map is keyed with: one ordinal with a comment saying why git refs are case-sensitive, the
            # other a bare '@{}'. That is #81's and #815's argument arriving from the inside, so it is
            # registered rather than left as two.
            #
            # THE TRANSPORT STAYS WITH EACH CALLER and only the map and the test are here -- see the lib's
            # header for why neither caller's gh transport is the other's. Read check-report-lib-workflow's
            # two banners above for why this is a SECOND ENTRY rather than a list of mirrors, and why the
            # second entry carries its plugin in its name; nothing about that needs restating.
            Name    = 'merged-pr-lib'
            Source  = 'scripts\lib\merged-pr-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The second mirror of merged-pr-lib. dkj-subagents-shopify and dkj-policy are separately
            # versioned and separately installed, and a Shopify consumer may run the first without the
            # second, so reaching into the workflow plugin's cache would be a dependency a version
            # mismatch breaks silently -- the same reason native-capture-lib is registered twice five
            # lines up. sync-main.ps1's dot-source is UNGUARDED for the matching reason: a payload
            # missing this file must fail at load, not fall through to a guard that then reports nothing
            # standing.
            Name    = 'merged-pr-lib-shopify'
            Source  = 'scripts\lib\merged-pr-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # Get-SeamValue + Get-DefaultChangelogPath (issue #885, group A): the one definition
            # cut-release.ps1, new-internal-note.ps1 and fold-changelog-entry.ps1 all read an optional
            # repo-config seam through now, where two of them used to carry their own private copy of the
            # function and the third probed inline instead of calling either. session-status.ps1 was a
            # fourth until #957 removed it with /lock and /handover.
            # TWO MORE READERS SINCE INBOUND #967: new-branch.ps1 and open-pr.ps1, both for the changelog
            # seam and both for the same reason -- the base an entry's relative links resolve from is the
            # directory that seam names, and both used to assume the repo root. Already mirrored, so
            # nothing about the payload changed; what changed is that a consumer running either one
            # without this lib present would now fail, which is why the list is kept current.
            Name    = 'seam-lib'
            Source  = 'scripts\lib\seam-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # Gate evidence (August 16, 2026): what the gates proved, and against which exact working
            # state. Mirrored because open-pr.ps1 dot-sources it as a $PSScriptRoot sibling, and the
            # redundancy it removes -- ship-pr calling open-pr, which re-gates a commit nothing has
            # touched -- is the consumer's redundancy just as much as this repo's.
            #
            # ITS OWN FILE RATHER THAN native-capture-lib.ps1, following park-lib's precedent and
            # native-capture-lib's own request not to be widened again. NO CONTRACT ROW FOLLOWS:
            # nothing in it is repo-owned -- it asks git about the tree and writes inside the git
            # directory, so there is no seam a consumer has to answer.
            Name    = 'gate-lib'
            Source  = 'scripts\lib\gate-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE LAST FETCH ATTEMPT PER REMOTE (issue #1860, September 11, 2026) -- what was asked for
            # and how it went. claim-issue.ps1 and new-branch.ps1 both fetch the same remote at the
            # opening of an assignment, seconds apart by design, so against an UNREACHABLE remote a
            # session that has nothing on screen yet used to wait out two full network bounds instead
            # of one. A recorded failure is reported rather than repeated, which halves that.
            #
            # ONLY A FAILURE, AND THE SUITE IS WHY. The symmetric seam -- skip on a recent success too,
            # which is what would have removed the duplicated ~700ms #1860 also reports -- was built
            # first and refused by new-branch.tests.ps1 cases (v) and (y1): both reproduce two runs
            # seconds apart with another session's push between them, which is the interval such a
            # window covers and the event #1139 and #1439 exist to see. A failed attempt refreshed
            # nothing, so reporting it costs nothing; a successful one is exactly what those probes read.
            #
            # ITS OWN FILE RATHER THAN gate-lib.ps1, whose arrangement it otherwise copies. That one
            # records per-worktree because a gate judges a working tree; this one records in the git
            # COMMON directory because whether a REMOTE answered is a property of the clone. Merging
            # them would mean one file with two scopes, which is the bug rather than the saving. NO
            # CONTRACT ROW FOLLOWS, for gate-lib's own reason: nothing in it is repo-owned.
            #
            # Mirrored because both callers are -- and because entry-scaffold-lib.ps1 dot-sources it as
            # a $PSScriptRoot sibling, so a consumer running the mirror would otherwise lose Get-TrunkGap.
            Name    = 'fetch-attempt-lib'
            Source  = 'scripts\lib\fetch-attempt-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The remote-ahead note composer (issue #1450), extracted out of new-branch.ps1 the day
            # open-pr.ps1 became a second reader of the same question. Mirrored because both callers
            # are: a consumer running the mirror would otherwise dot-source a file it does not have.
            Name    = 'remote-ahead-lib'
            Source  = 'scripts\lib\remote-ahead-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE PASTE-SAFETY VERDICT ON A REF NAME (issue #1594, September 8, 2026) -- may this branch
            # name go into a printed command a reader will run verbatim? ship-pr.ps1 carries five such
            # remedies and sync-main.ps1 two, and the lib is the single answer for all seven. It is the
            # NEIGHBOUR of remote-ahead-lib above rather than a section of it: that one sanitises text
            # somebody else wrote for DISPLAY (a commit's %an/%s, where an RTL override deceives a
            # reader), this one decides whether a name may enter a COMMAND. git's ref rules already
            # reject the control characters the display case is about, and admit every shell
            # metacharacter this case is about, so the two guards have disjoint subjects and neither
            # implies the other.
            Name    = 'ref-print-lib'
            Source  = 'scripts\lib\ref-print-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE, on native-capture-lib-shopify's precedent -- read its
            # banner for why a second entry rather than a list of mirrors, and why the name carries the
            # plugin. sync-main.ps1 is the caller here: two of #1594's seven sites are its own printed
            # remedies (the by-hand push, and the 'gh pr create' line the default non-merging path
            # prints). Neither is attacker-reachable -- sync-main composes its own branch name from a
            # prefix and a timestamp -- but they are the same defect and they get the same one
            # definition, because a second hand-typed copy of a security predicate is exactly what #1194
            # measured drifting within a day.
            Name    = 'ref-print-lib-shopify'
            Source  = 'scripts\lib\ref-print-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # THE FUNCTION-TABLE PROBE (issue #1729). A leaf with no dependencies of its own, like
            # ref-print-lib above, which is what makes it safe for the three libs below it to load
            # first. It is mirrored because those three are: entry-scaffold-lib, native-capture-lib and
            # seam-lib all dot-source it, and a consumer runs the mirror -- so an unmirrored source
            # would leave Test-FunctionDefined undefined in exactly the repos that never see this one.
            Name    = 'command-probe-lib'
            Source  = 'scripts\lib\command-probe-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE, on ref-print-lib-shopify's precedent above -- read
            # native-capture-lib-shopify's banner for why a second entry rather than a list of mirrors.
            # The caller here is that plugin's own native-capture-lib copy, which dot-sources this one.
            Name    = 'command-probe-lib-shopify'
            Source  = 'scripts\lib\command-probe-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # THE THIRD MIRROR OF THE SAME SOURCE. check-roster-sync.ps1 lives in the core team plugin
            # rather than in the workflow one, and it probes two seams (Get-RosterPath,
            # Get-RosterIgnoredIds) -- so the lib has to travel there too, exactly as check-report-lib
            # already does for the same caller.
            Name    = 'command-probe-lib-alpha'
            Source  = 'scripts\lib\command-probe-lib.ps1'
            Plugin  = 'dkj-subagents-alpha'
            LibOnly = $true
        },
        @{
            # THE DOCUMENT-NEWLINE READING (issue #1832). A leaf with no dependencies of its own, like
            # ref-print-lib and command-probe-lib above, which is what makes it safe for the two libs
            # that dot-source it to load it first. It is mirrored because those two are:
            # entry-scaffold-lib and pr-body-lib both dot-source it, and between them they reach every
            # caller -- release-lib, cut-release, fold-changelog-entry and adopt-workflow-folder all
            # already load entry-scaffold-lib. An unmirrored source would leave Get-DocumentNewline
            # undefined in exactly the repos that only ever see the mirror.
            #
            # ITS OWN FILE RATHER THAN command-probe-lib.ps1, on park-lib's precedent below: a newline
            # reading is not a function-table probe, and the cost of keeping them apart is this entry
            # and one mirror. Nothing in it is repo-owned, so no contract row follows.
            Name    = 'document-newline-lib'
            Source  = 'scripts\lib\document-newline-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },        @{
            Name    = 'pr-issues-lib'
            Source  = 'scripts\lib\pr-issues-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The PR-body helpers open-pr.ps1 dot-sources: Get-EntryDescription (shared by the fresh and
            # the -RefreshBody path) and Update-PrBodySection. Mirrored for the same reason as the two libs
            # above -- open-pr is mirrored and would otherwise dot-source a file the consumer does not have.
            Name    = 'pr-body-lib'
            Source  = 'scripts\lib\pr-body-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The one implementation of parking (#507): Invoke-GitPark, dot-sourced by BOTH parking entry
            # points -- park-branch.ps1 and new-branch.ps1 -Park. Mirrored for the same reason as the libs
            # above: both callers are mirrored and would otherwise dot-source a file the consumer does not
            # have.
            #
            # ITS OWN FILE RATHER THAN native-capture-lib.ps1, where Invoke-TestSuiteGate landed the same
            # week. That one documents its fit as imperfect and asks the next person not to widen the file
            # again; a park is not a gate, and the cost here is this entry and one mirror -- nothing in it
            # is repo-owned, so no contract row follows.
            Name    = 'park-lib'
            Source  = 'scripts\lib\park-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # Issue #1884, September 11, 2026. The close-out receipt shape, printed as the last line of a
            # chain-ending script. Mirrored because EVERY caller is -- ship-pr, open-pr, park-branch,
            # fold-changelog-entry and cut-release -- and the whole point of the file is that a consumer's
            # session meets the shape at the same moment this repo's does. A mirror that did not carry it
            # would leave every consumer on the memory-only rule that has now lost four times.
            #
            # THE DOT-SOURCE IS GUARDED IN ALL FIVE CALLERS, on git-porcelain-lib's grounds one entry down:
            # a consumer whose mirror predates this entry must not crash on load, and each call site tests
            # for the function rather than assuming the dot-source took. The guard buys an ordered release,
            # not an optional file.
            #
            # ITS OWN FILE, not a function in one of the libs above. Its subject is neither a park, a
            # capture, a porcelain read nor a PR body -- it is the one thing in this workflow addressed to
            # the READER of the run rather than to the run. Nothing in it is repo-owned (it takes two
            # strings and prints), so no contract row follows.
            Name    = 'closeout-lib'
            Source  = 'scripts\lib\closeout-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # Issue #1682, September 9, 2026. The one reading of `git status --porcelain`: the command
            # with its two flags, and the line parse. Mirrored because BOTH its callers are, and each
            # dot-sources it by name -- park-lib.ps1 (the uncommitted count behind the backing gate) and
            # fanout-lib.ps1 (the per-path snapshot behind check-fanout). A consumer whose park-cycle
            # Stop hook dot-sources a file the mirror does not carry would fail on every turn.
            #
            # THE DOT-SOURCE IS GUARDED IN BOTH CALLERS, so a mirror that predates this entry loads
            # without crashing -- but the function is then missing, which is why it is registered rather
            # than left to the guard. The guard buys an ordered release, not an optional file.
            #
            # ITS OWN FILE, for the reason park-lib's entry gives one line up: native-capture-lib asks
            # not to be widened again, and a porcelain parse is neither a capture helper nor a park.
            # Nothing in it is repo-owned -- it takes lines and a repo root and returns paths and status
            # characters -- so no contract row follows.
            Name    = 'git-porcelain-lib'
            Source  = 'scripts\lib\git-porcelain-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE SECOND MIRROR OF THE SAME SOURCE (issue #1689, September 9, 2026), on
            # native-capture-lib-shopify's and merged-pr-lib-shopify's precedent -- read either of those for
            # the argument in full. Convert-GitQuotedPath moved in here from sync-rules.ps1, and sync-main.ps1
            # dot-sources this file directly and unguarded for it, so dkj-subagents-shopify needs its own copy:
            # the two plugins are separately versioned and separately installed, and a cross-plugin path is a
            # dependency a version mismatch breaks silently.
            #
            # NOT REACHED THROUGH sync-rules.ps1, which is the file the decoder came OUT of and the one place
            # it must not go back into: that entry's own note says it is dependency-free on purpose, because
            # the live-theme guard dot-sources it on every command inside a catch that returns no live theme
            # id. It never called the function it defined, so losing it cost that file nothing.
            Name    = 'git-porcelain-lib-shopify'
            Source  = 'scripts\lib\git-porcelain-lib.ps1'
            Plugin = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # Issue #1069, August 29, 2026. Mirrored because BOTH its callers are: ship-pr.ps1 asks it
            # whether another worktree holds the trunk (before the merge, and again when handing the trunk
            # back afterwards), and prune-merged.ps1 asks it which worktree to name when its fast-forward
            # is refused. A consumer whose ship-pr dot-sources a file the mirror does not carry would fail
            # at the step that has just merged.
            #
            # ITS OWN FILE, for the reason park-lib's entry gives one line up: native-capture-lib asks not
            # to be widened again, and reading `git worktree list --porcelain` is neither a capture helper
            # nor a park. Nothing in it is repo-owned -- it takes lines and returns strings -- so no
            # contract row follows.
            Name    = 'worktree-lib'
            Source  = 'scripts\lib\worktree-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The pure classification behind tidy-machine.ps1 (September 10, 2026): which local clutter
            # is provably finished, which is merely finished-LOOKING, and which is live work. Mirrored
            # because its only caller is, and dot-sourced rather than inlined for the ordinary reason --
            # a consumer's tidy-machine loading a file the mirror does not carry would fail on its first
            # lane.
            #
            # ITS OWN FILE rather than a widening of merged-pr-lib, whose two functions it REUSES. That
            # lib answers one question (is this name+tip pair in a PR listing) and this one asks it of a
            # second listing; folding the classifier in would make a lib that is currently about one
            # comparison into a lib about a taxonomy. Nothing in it is repo-owned -- every input is a
            # parameter, which is also what lets its suite drive states no machine here has been in --
            # so no contract row follows.
            Name    = 'tidy-lib'
            Source  = 'scripts\lib\tidy-lib.ps1'
            Plugin  = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The third release tier (August 3, 2026). Its own script rather than part of cut-release, and
            # the reason changed on the way: the source repo kept it separate because cut-release was
            # "temporarily diverged" and must not be extended, which #417 settled. What holds instead is
            # that cut-release COMMITS AND TAGS in one motion, so a skeleton generated there would put an
            # empty document inside the release tag while the written version landed afterwards anyway.
            Name   = 'new-internal-note'
            Source = 'scripts\release\new-internal-note.ps1'
            Plugin = 'dkj-policy'
            # Documented inside the cut-release skill (step 2) rather than separately: it is a step of
            # cutting a release, and it cannot run before the cut has produced its input.
            Skill  = 'cut-release'
        },
        @{
            # The changelog entry's scaffold wording, needed by TWO shared scripts that must not be able
            # to disagree about it: new-changelog-entry.ps1 writes it, open-pr.ps1's scaffold gate refuses
            # to ship it. A copy in each would make the gate silently miss whatever the writer changed --
            # a drift guard that drifts. So it travels with both rather than living in either.
            Name    = 'entry-scaffold-lib'
            Source  = 'scripts\lib\entry-scaffold-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The contract registry, extracted from check-script-contract.ps1 on August 8, 2026 (#456)
            # once a THIRD reader appeared: the check reports what a consumer is missing, the blueprint
            # generator ships what the source answered, and the test suite holds the registry to its own
            # rules. Mirrored because the check that dot-sources it is mirrored -- a consumer running the
            # mirror would otherwise load a file it does not have.
            Name    = 'script-contract-lib'
            Source  = 'scripts\lib\script-contract-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The consumer's side of the blueprint (#456): it reads the artefact this repo generates and
            # places what is safe to copy, proposing the rest. Shared for the reason every script here is
            # -- the alternative is each consumer hand-deriving the source's answers, which is what the
            # issue measured them doing.
            #
            # THE GENERATOR IS NOT REGISTERED, deliberately: scripts/sync/build-config-blueprint.ps1 reads
            # THIS repo's libs to produce the artefact, so it is the source's own tool. A consumer running
            # it would generate a blueprint of itself and overwrite the one it adopts from.
            # SKILL-LEVEL MERGE, SEPTEMBER 5, 2026: this script and adopt-workflow-folder below now
            # share ONE skill page, 'adopt-dkj-policy' -- Part 2 of it. The two scripts themselves are
            # untouched (different files, different tests, different behaviour); only the documenting
            # page merged, for the same reason adopt-bwj-asana was renamed to adopt-dkj-policy-bwj
            # earlier the same day: a name naming one plugin should not leave a sibling operation for
            # that plugin looking unrelated. check-plugin-integrity's skill-param check (18) already
            # supports several scripts sharing one Skill -- see verify-resolved-issues below, which has
            # shared ship-pr's page since before this merge.
            Name   = 'adopt-config'
            Source = 'scripts\task\adopt-config.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'adopt-dkj-policy'
            # A test points the command at a fixture blueprint instead of the shipped one. A consumer
            # never types it, and documenting it would invite someone to.
            SkillParamsExempt = @('BlueprintPath')
            # Resolve-Blueprint's FIRST candidate is '..\..\blueprint\config-blueprint.json', which is
            # the plugin root from the mirror and the repo root from the source -- the candidate a
            # consumer actually hits, and the one the source copy can never exercise (#1857).
            MirrorRun = 'config-blueprint.tests.ps1'
        },
        @{
            # The workflow's own root folder (Dave, August 14, 2026): a plugin install writes nothing
            # into a consumer's repo, so the folder that gathers everything portable arrives through
            # this command -- and check-script-contract reports at session start while it is missing.
            # Additive-only sibling of adopt-config: that one fills the seam libs, this one puts the
            # folder down. Documented as Part 1 of 'adopt-dkj-policy' -- see the merge note above.
            Name   = 'adopt-workflow-folder'
            Source = 'scripts\task\adopt-workflow-folder.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'adopt-dkj-policy'
            # THE RESOLUTION #1857 WAS FILED ABOUT. The shipped PR template reference is read from
            # '..\..\templates\pull_request_template.md' with a second candidate one level deeper for
            # the source copy -- so candidate 1 is the plugin root from the mirror and a
            # <repo>\templates that does not exist from here. Only the mirror can prove candidate 1,
            # and it is the one that fires in every released install.
            MirrorRun = 'adopt-workflow-folder.tests.ps1'
        },
        @{
            # The merge-queue floor (issue #1516). The queue went live on this workflow's source repo on
            # September 6, 2026 (#1492) and the policy is that every repo running this workflow adopts
            # one -- but the SETTING is the last step, not the first. A queue takes the fold (#1493) and
            # the resolves verification (#1511) away from the shipping session, and demands a merge_group
            # trigger on every required check before it is switched on at all (#1325). None of that
            # travelled: a consumer flipping the setting today gets an outage or a trunk quietly
            # collecting unfolded entries. This command is the floor, and it is shared for the reason
            # every entry here is -- the alternative is each consumer deriving three CI files and a
            # prerequisite from the source's tree, which is what they did for the branch-entry gate.
            #
            # THIRD SIBLING OF adopt-config AND adopt-workflow-folder, and Part 3 of the same skill page.
            # A page rather than a skill of its own, deliberately: a fourth always-on skill description
            # is paid by every session in every consumer, and this operation is run about once per repo.
            Name   = 'adopt-merge-queue'
            Source = 'scripts\task\adopt-merge-queue.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'adopt-dkj-policy'
            # A test points the command at a fixture rules payload instead of calling gh, which is the
            # only way to reach the queue-is-active arm without a network and a trunk. A consumer never
            # types it, and documenting it would invite someone to.
            SkillParamsExempt = @('RulesJsonOverride')
            # Timeable with no arguments: the default is a dry run that writes nothing. It does make one
            # gh call, so the figure carries a network leg -- which is the honest cost of this command.
            MeasureArgs = @()
        },
        @{
            # The triage-priority label adopter (issue #1895, split from #1843). Print-only, the same
            # shape Get-MissingLabelNote already established for a PR label: composes a paste-ready
            # `gh label create` for whichever of the four canonical 'prio-*' labels this repo's tracker
            # is missing, and never runs it. Shared for the same reason every entry here is -- the
            # alternative is each consumer retyping four names and four colours out of a page instead
            # of a seam.
            #
            # NO SKILL, DELIBERATELY, AND FOR A DIFFERENT REASON THAN check-unfolded-entry's ABOVE. That
            # one has no skill because both its callers are automatic and nobody invokes it as a
            # procedure; this one genuinely is a procedure a person runs, but #1895 scoped OUT both of
            # its obvious homes -- a new "Part 5" of the already-four-part adopt-dkj-policy skill, and a
            # skill page of its own -- as bigger than the issue asked for. Documented instead by its own
            # .SYNOPSIS run line, the shared-scripts table row below, and one sentence in
            # CONTRIBUTING-portable.md. A future issue that outgrows this may still give it one.
            #
            # NOT REFUSED IN THE WORKFLOW'S SOURCE REPO, unlike adopt-merge-queue and
            # adopt-workflow-folder above: those write local files that would collide with the hand-kept
            # originals they are derived from. This script writes nothing at all -- it only reads
            # `gh label list` and prints -- so running it here checks this repo against its own
            # canonical answer instead of conflicting with anything.
            Name   = 'adopt-triage-labels'
            Source = 'scripts\task\adopt-triage-labels.ps1'
            Plugin = 'dkj-policy'
            # Skill = '', so the parameter check (check 18) never runs for this entry -- there is no
            # skill page to hold -LabelJsonOverride against. See the comment above for why.
            Skill  = ''
            # Timeable with no arguments: it only reads and prints, never writes.
            MeasureArgs = @()
        },
        @{
            # Issue #417, phase 1. Two repos ran two independently evolved files of this name, and the
            # owner's goal is one release workflow rather than two that resemble each other. The audit
            # that produced the issue named three divergences; reading both files found six, and the
            # largest -- the whole plugin/marketplace half -- was not among them. All six now sit in the
            # seam (scripts\repo-config.ps1), each optional, each falling back to what this script did
            # unshared, so registering it here changes nothing about how the workshop cuts a release.
            #
            # The consumer tier the other repo generates is NOT part of this entry: porting it is
            # phase 2, and it renders stakeholder-facing HTML, which under the safety rules is work that
            # waits for Dave's own eye rather than merging on the gates.
            Name   = 'cut-release'
            Source = 'scripts\release\cut-release.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'cut-release'
        },
        @{
            # Travels with cut-release for the same reason verify-resolved-issues travels with ship-pr:
            # cut-release dot-sources it as a $PSScriptRoot sibling, so a mirror without it would fail
            # on the first line that matters. Its one repo-owned dependency, branch-info.ps1, does NOT
            # travel -- the branch table differs per repo -- so the dot-source of that sibling is
            # guarded and Get-ReleaseChangeTypes probes for Get-BranchTypes, which cut-release loads
            # from the consumer's own root before calling in.
            Name    = 'release-lib'
            Source  = 'scripts\lib\release-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The hosted reading copy of the hand-written notes (Dave, August 15, 2026). Shared rather
            # than workshop-only because nothing in it is repo-specific: it reads the release history and
            # the note root through seams that already exist, and the two knobs it adds are optional with
            # working fallbacks. The consumer this was ported from had written its own, which is the
            # argument for one source rather than for a second.
            Name   = 'build-release-notes-page'
            Source = 'scripts\release\build-release-notes-page.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'release-notes-page'
            # A fixture root, so the suite can build a page from a synthetic tree instead of this repo's
            # real notes. A consumer never types it.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # THE ONE PAIR WHOSE SOURCE IS NOT A SCRIPT, and the flag is a stretch that is worth naming
            # rather than hiding. LibOnly is documented as marking a DOT-SOURCED library, and this is an
            # HTML template -- but what the flag actually declares is "this file never resolves a repo
            # root of its own", which is the invariant the test enforces and which a template satisfies
            # more completely than a lib does. The alternative was a third flag whose only member would
            # be this entry.
            #
            # A PAIR RATHER THAN A PLUGIN-ONLY FILE, because the script reaches the template as a
            # $PSScriptRoot sibling: it has to exist beside BOTH copies, which is precisely what this
            # registry is for. Without it the mirror would build a page from a template it does not have.
            Name    = 'release-notes-page-template'
            Source  = 'scripts\release\release-notes-page-template.html'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # Which plugins a repo publishes, and where each one's folder is (August 9, 2026). Travels
            # because release-lib dot-sources it as a $PSScriptRoot sibling: Get-PluginManifestPaths --
            # which cut-release calls in a consumer that publishes plugins -- is a wrapper over it, and
            # Get-TouchedPlugins reads the roots it returns.
            #
            # DEPENDENCY-FREE ON PURPOSE, and that is what makes it cheap enough to sit this low. The
            # alternative was putting these functions in check-report-lib, which every SessionStart check
            # already loads -- but that lib is about a CONSUMER's install state (the settings chain, the
            # plugin cache), while this one is about a repo that PUBLISHES plugins. Two different
            # questions that happen to both say 'plugin', and merging them would have put a marketplace
            # reader into every consumer session that has no marketplace.
            Name    = 'plugin-tree-lib'
            Source  = 'scripts\lib\plugin-tree-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The source-repo guard (August 12, 2026). IT HAS TO TRAVEL, and that is the whole reason it is
            # a pair rather than a source-only helper: the guard fires from inside the copy a reader
            # wrongly ran, so one that stayed behind in this tree could never fire. Eleven entry points
            # dot-source it $PSScriptRoot-relative and GUARDED, so a mirror built before this pair existed
            # degrades to the previous behaviour instead of throwing.
            #
            # DEPENDENCY-FREE, like plugin-tree-lib and for the same reason: it is dot-sourced on the first
            # line that runs, before any script has resolved anything, so it can rely on nothing being
            # loaded yet.
            Name    = 'source-repo-guard-lib'
            Source  = 'scripts\lib\source-repo-guard-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The Shopify floor's install path (inbound #769 + #776, August 20, 2026). The guard shipped
            # in 4.15.0 and started working on its own for two of its three rules; the third needs the
            # consumer to name the live theme, and NO INSTALL STEP OWNED THAT ANSWER -- an install is a
            # clone into the plugin cache and writes nothing into a repo. So every refreshed consumer met
            # a standing [ERROR] and a guard with a known hole in it.
            #
            # IT TRAVELS IN dkj-subagents-shopify RATHER THAN IN THE CORE TEAM, and that is the same call issue
            # #776 argued from both directions: specialists-init is dkj-subagents-alpha's skill, so teaching it the
            # two Shopify seam functions would give the core team knowledge of an add-on it must not
            # depend on. The plugin that owns the guard owns the answer to the guard.
            Name   = 'adopt-shopify-floor'
            Source = 'scripts\task\adopt-shopify-floor.ps1'
            Plugin = 'dkj-subagents-shopify'
            Skill  = 'adopt-shopify-floor'
            # A fixture root, so the suite can adopt into a scratch tree instead of a real Shopify repo --
            # and so the marketplace refusal can be bypassed in a repo that is one. A consumer never types
            # it, and documenting it would invite someone to.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # THE GUARD LIB HAS TO REACH dkj-subagents-shopify TOO, now that a shared script travels there. It only
            # ever fires from inside the copy a reader wrongly ran, so a version that stayed behind in
            # dkj-policy's mirror could never fire for adopt-shopify-floor. Registered per plugin
            # rather than per script for the same reason check-report-lib is: the pair names a destination,
            # and one destination cannot serve two.
            Name    = 'source-repo-guard-lib'
            Source  = 'scripts\lib\source-repo-guard-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # The branch-entry CI gate (inbound #789, August 20, 2026). The convention shipped with
            # nothing enforcing it: open-pr and ship-pr both refuse locally, and a branch pushed by hand
            # or a PR opened in the GitHub UI meets neither. So both consumers wrote one from scratch --
            # a second definition of the format in every consumer, and both had already drifted, refusing
            # a merge over a missing significance score that Dave placed at the release cut instead.
            #
            # IT DECLARES A SKILL, and it was registered without one until the suite refused: every shared
            # entry point must name a documenting page, and shared-scripts.tests.ps1 asserts exactly that.
            # The reasoning against was "nothing types this command, a workflow runs it" -- which is true
            # of the CI route and beside the point for the question a person does ask on a finished branch,
            # "is my entry written?". A page that answers it before the push is worth more than the
            # exemption was.
            Name   = 'check-branch-entry'
            Source = 'scripts\lint\check-branch-entry.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'check-branch-entry'
            # A fixture root, so the suite can judge scratch trees. A consumer never types it.
            SkillParamsExempt = @('RootOverride')
            # Timeable with no arguments: this script reads the branch dossier and reports. Verified
            # rather than assumed from its check- prefix -- it contains no write of any kind.
            MeasureArgs = @()
        },
        @{
            # The skipped-fold gate (issue #1270). The fold runs from ship-pr.ps1, as the shipping
            # session's own step, so a merge that session never observes -- from the GitHub UI, or via
            # the merge queue since #1492 -- never folds, and nothing downstream reported the leftover.
            # This runs from .github/workflows/unfolded-entry.yml on every push to main
            # (merger-independent) and from the SessionStart hook unfolded-entry-sessioncheck.ps1 in
            # every consumer. Since #1493 fold-on-merge.yml runs this same check on a push to main and
            # folds on a find; this one still only reports.
            #
            # NO SKILL, and none is wanted: both callers are automatic (a CI trigger, a session hook)
            # and nobody invokes it as a procedure. Same call check-script-contract gets, for the same
            # reason -- a person who wants the answer early runs the one command in its .SYNOPSIS.
            Name   = 'check-unfolded-entry'
            Source = 'scripts\lint\check-unfolded-entry.ps1'
            Plugin = 'dkj-policy'
            Skill  = ''
            # A fixture root, so the suite (and the hook) can judge a tree other than the checkout.
            SkillParamsExempt = @('RootOverride')
            # Timeable with no arguments: reads dkj-policy/ and reports, no write of any kind.
            MeasureArgs = @()
        },
        @{
            # The consumer-prose check: TWO detectors over ONE corpus, read once (issue #1421). It was two
            # registry rows, two mirrored scripts and two hooks for one day -- #1389's retired-name grep
            # and #1415's supremacy-declaration grep, the two narrow literal greps the prose-contract
            # decline (#1380) recorded as proportionate after declining the framework at 12.5% precision.
            #
            # WHAT EACH HALF CATCHES, because the pair is one hole with two shapes. #1389: a renamed
            # convention reaches a consumer through nothing -- no gate reads a consumer's CLAUDE.md, and
            # check-script-contract covers FUNCTIONS, so a renamed FILE CONVENTION is outside it by
            # construction. Measured: both BWJ consumers still restated the retired single
            # 'development.md' in their always-on documents, one day and six days after the rename, while
            # the tooling around it had been made rename-proof on purpose. #1415: the one defect #1380
            # called STRUCTURALLY invisible -- a pointer test flags sections carrying NO citation, so
            # cites-then-contradicts can only appear among the SUPPRESSED findings. Measured in
            # smartwatchbanden: two standing inversions of LAW-THIRD-RANK-ORDER, one of which #1380's own
            # census never counted. Its recorded three-term shape was measured and REPLACED -- it scored 0
            # findings and 0 recall on its own target, where adjacency of 'CLAUDE.md' and 'wins'/'wint'
            # scores 3 raw / 2 reported / 2 true / 100%. The table is in Get-SupremacyDeclaration.
            #
            # WHY ONE ROW. Sharing Get-ConsumerProseDocuments removed the duplicated CORPUS and nothing
            # else: the pair still cost two hook launches, two nested spawns, two dot-sources of
            # entry-scaffold-lib.ps1 and measure-context-lib.ps1, and two walks of the same ~8-document
            # closure, on every session start in every consumer. Measured on a consumer fixture carrying
            # both defects: 492 + 498 = 990 ms for the pair, against 533 ms merged -- ~457 ms saved per
            # session start, against ~155 ms for a bare hook launch. Neither hook had ever been released
            # -- both landed after v4.29.0 and sat in [Unreleased] -- so the rename #1421 deferred the
            # merge over cost no consumer anything.
            #
            # ITS ONLY CALLER IS THE HOOK, and there is no CI leg on purpose: a consumer's CI is not this
            # repo's to add, and in the publishing repo the check skips itself. So unlike
            # check-unfolded-entry, which has a CI half, the SessionStart hook consumer-prose-sessioncheck.ps1
            # IS the route rather than a convenience on top of one.
            #
            # NO SKILL, on the same reasoning check-unfolded-entry and check-git-identity give: the
            # caller is automatic and nobody invokes it as a procedure. One command in its .SYNOPSIS
            # answers it early.
            Name   = 'check-consumer-prose'
            Source = 'scripts\lint\check-consumer-prose.ps1'
            Plugin = 'dkj-policy'
            Skill  = ''
            # A fixture root, plus an always-on root the suite can point at a scratch document tree.
            # A consumer never types either.
            SkillParamsExempt = @('RootOverride', 'RootDocument')
            # Timeable with no arguments: reads the always-on closure and reports, no write of any kind.
            MeasureArgs = @()
        },
        @{
            # The split-identity check (issue #1315). `@me` in the claim rule resolves through the
            # GitHub API, so it writes whichever account gh holds -- and nothing compared that against
            # the identity git commits as. Measured: gh authenticated as DaveKJohn while
            # git config user.name read davekokbwj, so the documented claim idiom put the wrong account
            # on #1314. Its one automatic caller is the SessionStart hook
            # git-identity-sessioncheck.ps1, which reports it before the session claims anything.
            #
            # ADVISORY, AND DELIBERATELY IN NO GATE: it reports a fact about the MACHINE rather than
            # about the diff, and a CI runner acts and commits as a bot -- a mismatch by design.
            #
            #
            # AND SINCE INBOUND #1867 IT ANSWERS A BLUNTER QUESTION FIRST: can this checkout commit at
            # all? That state used to reach the silent "user.name unset" skip, on the ground that git
            # refuses such a commit itself -- true about whether, wrong about when, since the cycle's
            # first commit is inside new-branch.ps1 after HEAD has moved.
            # NO SKILL, on the same reasoning check-unfolded-entry gives above: the caller is automatic
            # and nobody invokes it as a procedure. One command in its .SYNOPSIS answers it early.
            Name   = 'check-git-identity'
            Source = 'scripts\lint\check-git-identity.ps1'
            Plugin = 'dkj-policy'
            Skill  = ''
            # A fixture root, plus the two identity overrides the suite needs to put this in front of
            # every state without a keyring or a git identity of its own.
            SkillParamsExempt = @('RootOverride', 'GhAccountOverride', 'GitUserNameOverride')
            # Timeable with no arguments: two local process reads and a report, no write and no network.
            MeasureArgs = @()
            # DECLARED THOUGH NOT REQUIRED: this script resolves nothing above its own scripts\ folder,
            # so the depth check would not ask. It is registered because it is the precedent -- the
            # first suite in the tree to run a mirror from its own directory, four weeks before #1857
            # named the class -- and because the registry should be able to answer "which mirrors are
            # executed" without anyone grepping the suites for it.
            MirrorRun = 'git-identity-gate.tests.ps1'
        },
        @{
            # The repo-settings drift detector, now shared (issue #1843). Built here first (#1726) after
            # three drifts in eight days that nothing in the tree would otherwise have caught: the org
            # transfer emptying `bypass_actors` (#1244, every direct-on-main exception dead for a day),
            # `merge_queue` added to the ruleset and removed with no trace (#1499, #1720), and
            # `allow_auto_merge` left on against four records in this tree saying `false` (#1730).
            #
            # A CONSUMER'S GITHUB-SIDE STATE DRIFTS THE SAME WAY, with nothing in their own tree saying
            # so -- #1843 is the wider question #1726 was declined on the ground of not asking ("#1726
            # asked about this repo"), and Dave's scope decision on it is what travels: identical
            # SCRIPTS available, not identical RULES enforced. So the values a consumer declares stay
            # theirs (see Get-ExpectedRepoSettings's 'decide' record in script-contract-lib.ps1) while
            # the mechanism that compares them against GitHub is now shared, at no cost, because it was
            # already reading those values through a seam rather than a literal.
            #
            # ITS TWO CALLERS ARE A SCHEDULED WORKFLOW AND A PERSON, on the same reasoning
            # check-unfolded-entry and check-git-identity give above: nobody invokes this as a procedure,
            # so there is no skill, and the one command in its .SYNOPSIS answers it early for whoever
            # wants it before the next cron.
            Name   = 'check-repo-settings'
            Source = 'scripts\lint\check-repo-settings.ps1'
            Plugin = 'dkj-policy'
            Skill  = ''
            # Four fixture-only overrides: the three payload files that stand in for a `gh api` call the
            # suite cannot make against a moving target, plus the root override that points the read at
            # a fixture tree instead of the checkout. A consumer never types any of them.
            SkillParamsExempt = @('RootOverride', 'BranchRulesJsonOverride', 'RepoJsonOverride', 'RulesetJsonOverride')
            # Timeable with no arguments: it reads GitHub and this tree's own declaration and reports,
            # no write of any kind -- confirmed against the script itself rather than assumed from its
            # check- prefix.
            MeasureArgs = @()
            MirrorRun = 'repo-settings-gate.tests.ps1'
        },
        @{
            # The fixture-pollution check (issue #1609). A throwaway debug script ran without
            # redirecting $env:USERPROFILE and overwrote ~/.claude/plugins/installed_plugins.json with
            # two fixture records, losing the install record of this checkout and both registered
            # consumers -- with no backup, no error, and nothing anywhere that reported it. Its one
            # automatic caller is the SessionStart hook claude-home-sessioncheck.ps1.
            #
            # IT TRAVELS IN dkj-policy with the other machine-fact session checks, and not in the team
            # plugin whose roster check the damage actually broke. The subject is the plugin
            # administration itself, which is harness state rather than a roster: plugin-versions.ps1
            # -- the other script that reads it as its whole subject -- ships here too.
            #
            # ADVISORY, AND DELIBERATELY IN NO GATE, for the reason check-git-identity gives above: a
            # CI runner has no plugin administration at all, so a workflow leg would report the empty
            # state on every push.
            #
            # NO SKILL, on the same reasoning the three entries above give: the caller is automatic and
            # nobody invokes it as a procedure. One command in its .SYNOPSIS answers it early.
            Name   = 'check-claude-home'
            Source = 'scripts\lint\check-claude-home.ps1'
            Plugin = 'dkj-policy'
            Skill  = ''
            # The fixture home and the fixture's definition of "scratch", both of which the suite MUST
            # pass -- a suite for this check that used the real home would be the defect under test.
            # -NoSnapshot is exempt for the same reason: it exists so a case that is not about the
            # snapshot writes nothing at all.
            SkillParamsExempt = @('HomeOverride', 'ScratchRootOverride', 'NoSnapshot')
            # NO MeasureArgs, and that is a declaration rather than an omission: the no-argument form
            # reads the REAL administration and may refresh the snapshot beside it. A timing harness
            # must not write to the user's plugin administration as a side effect of measuring, and
            # this is the one check in the family that could.
        },
        @{
            # THE CLAIM ITSELF -- the step both always-on documents prescribe and neither performs. The
            # claim rule has been written down since Chris's persona body carried it and enforced by
            # nothing: `gh issue edit <n> --add-assignee @me`, left to a session to remember, to type,
            # and to read the result of. The entry above REPORTS the identity hazard; this one is what
            # acts on it, and on the two the one-liner cannot see -- a closed issue (which it claims
            # silently) and an issue somebody else holds (which it joins).
            #
            # IT TRAVELS IN dkj-policy because a claim is tracker mechanics, which is that plugin's
            # subject: it sits with new-branch, open-pr and ship-pr, one step earlier in the same
            # sequence. Nothing in it is Shopify-specific or repo-specific -- Get-RepoName is read
            # defensively and gh's own resolution stands without it.
            #
            # AND IT IS MODEL-INVOCABLE, unlike start-task and sync-roster. The pain it removes is that
            # a session hears "fix issue 1234" and starts fixing; a skill nobody may invoke until it is
            # typed leaves exactly that path open.
            Name   = 'claim-issue'
            Source = 'scripts\task\claim-issue.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'claim-issue'
            # A fixture root, so the suite can point the repo-config read at a scratch tree. A consumer
            # never types it, and documenting it would invite someone to.
            SkillParamsExempt = @('RootOverride')
            # NO MeasureArgs, and that is the declaration rather than an omission: the script's only
            # no-argument form does not exist (-Issue is mandatory) and every form it does have either
            # writes to a live tracker or spends two network round trips on one. A timing harness must
            # not claim an issue as a side effect of measuring.
        },
        @{
            # The identity a checkout ACTS as versus the one it COMMITS as, read once for both callers
            # (issue #1315). It was written inside check-git-identity.ps1, which reports the split;
            # claim-issue.ps1 has to ACT under the right name and cannot dot-source that file, which
            # runs its comparison and exits on load. Extracting beat a second copy of
            # Get-ActiveGhAccount's multi-account parse -- the subtle one, and the one a repo whose
            # branch-prefix table says "do it here -- and nowhere else" does not get to keep two of.
            # Test-GitCanCommit joined them for inbound #1867 -- a third question, and a blocker rather
            # than an advisory read: whether git will accept a commit here at all. Two callers on day
            # one, check-git-identity.ps1 reporting it and new-branch.ps1 refusing on it.
            Name    = 'git-identity-lib'
            Source  = 'scripts\lib\git-identity-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # claim-issue's two decisions -- which account, and whether this issue may be claimed at
            # all. A lib for the reason measure-skill-lib is one: everything around them is a gh
            # round-trip a suite cannot run, so the decisions are the half that CAN be pinned, and they
            # are where all four refusals live. Pinned by scripts/tests/claim-issue.tests.ps1.
            Name    = 'claim-issue-lib'
            Source  = 'scripts\lib\claim-issue-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # THE DETECTION HALF of the working-copy boundary (issue #1670). #1665 measured a dispatched
            # review specialist discarding three files of the orchestrator's uncommitted work with a
            # `git checkout HEAD --` it was never asked to run -- no error, no notice, and a clean
            # `git status` afterwards, which the reviewer cited as proof it had changed nothing. That was
            # repaired with an INSTRUCTION (the shared block working-copy-boundary, carried by every
            # agent def holding Bash), and #1670's finding was that nothing anywhere DETECTED it, so a
            # repeat would be exactly as invisible as the first.
            #
            # IT TRAVELS IN dkj-policy for the reason claim-issue does, and it is the same split: the
            # RULE lives in the orchestrator's manual in dkj-subagents-alpha (Chris owes a reconciliation
            # step after a fan-out), the MECHANISM sits here with the other git mechanics -- new-branch,
            # park-cycle, prune-merged. Nothing in it knows what a specialist is.
            #
            # INVOKED RATHER THAN AUTOMATIC, and the choice is recorded because this repo's laziness rule
            # points the other way: a step that must happen every time belongs in a hook. #1670 left the
            # home open between a hook, tooling and a documented step, and the invoked script shipped
            # first because a Pre/PostToolUse pair around the dispatch rests on the matcher name of the
            # dispatch tool, which had not been measured. The hook variant stays open on #1670 and is
            # cheap to add, because the judgement it needs is already the shared lib below.
            Name   = 'check-fanout'
            Source = 'scripts\task\check-fanout.ps1'
            Plugin = 'dkj-policy'
            Skill  = 'check-fanout'
            # A fixture root, so the suite can put this script in front of throwaway repos -- including
            # the one where it reproduces the #1665 command for real. A caller never types it.
            SkillParamsExempt = @('RootOverride')
            # NO MeasureArgs, and that is a declaration rather than an omission: -Capture WRITES a
            # baseline file to the temp directory, and -Compare DELETES the one it was given. A timing
            # harness must not leave scratch files behind or consume somebody's baseline as a side
            # effect of measuring, and there is no third, read-only form.
        },
        @{
            # The snapshot and the whole shrinkage judgement behind check-fanout.ps1. A lib for the
            # reason park-lib's own comparison is one: what can be got WRONG here is a decision -- growth
            # must stay silent, a committed path is not a loss, `git reset` is not a loss, a branch change
            # refuses instead of differencing -- and each of those is three lines in a suite against
            # hand-built snapshots, where the same case through the script would need a fixture repo.
            # Pinned by scripts/tests/fanout-lib.tests.ps1, which also drives the script end to end.
            Name    = 'fanout-lib'
            Source  = 'scripts\lib\fanout-lib.ps1'
            Plugin = 'dkj-policy'
            LibOnly = $true
        },
        @{
            # The pre-task sync (inbound #787, August 20, 2026). THE HIGHEST-RISK SCRIPT IN A SHOPIFY
            # CONSUMER, and it was written twice by hand before it shipped -- destructively the first
            # time, in both repos. A live theme has no locking and no merge, so work starts by mirroring
            # live into the trunk, and the obvious wholesale implementation overwrites whatever the trunk
            # has done since. One consumer recorded that procedure reverting merged work three times in
            # one week.
            #
            # IT TRAVELS IN dkj-subagents-shopify, like adopt-shopify-floor and for the same reason: the plugin
            # that owns the live theme owns the step that reads from it. It depends on NO workflow plugin
            # at all -- every seam it reads is fetched through Get-Command, so a consumer that enables no
            # workflow gets identical behaviour. That was written when a second workflow existed to name
            # as the comparison; the guarantee is the same one, stated against the case that remains.
            Name   = 'sync-main'
            Source = 'scripts\task\sync-main.ps1'
            Plugin = 'dkj-subagents-shopify'
            Skill  = 'sync-main'
            # A fixture root, so the suite can drive the script against a scratch tree instead of a real
            # store -- and so the marketplace refusal can be bypassed in a repo that is one. A consumer
            # never types it, and documenting it would invite someone to.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # The sync's QUERIES, as a lib of their own (inbound #787). The policy is one sentence; what
            # the risk sits in is when it fires -- whether a path has ever held live's bytes (inbound
            # #807, which is what decides now), whether a line-ending difference is a difference at all,
            # and where to measure a both-sides-moved conflict from. A deletion is also a touch, and that
            # is the case BOTH hand-written implementations got wrong. Every one of them is testable only
            # if it loads without running a sync, which is the whole reason this is a separate file rather
            # than a handful of functions at the top of sync-main.ps1.
            #
            # DEPENDENCY-FREE, and specifically NOT a reader of repo-config.ps1: the live-theme guard
            # dot-sources that file on every command inside a catch that returns no live theme id, so
            # anything it pulls in is a way to silently disarm the guard. The seam answers are read by the
            # script and passed in.
            Name    = 'sync-rules'
            Source  = 'scripts\lib\sync-rules.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # The preview push (inbound #805, August 21, 2026). IT TRAVELS IN dkj-subagents-shopify for the same
            # reason sync-main does: the plugin that owns the live theme owns the estate around it. It
            # depends on NEITHER workflow plugin -- every seam it reads, the branch-name flattening
            # included, is fetched through Get-Command.
            #
            # THE CASE FOR SHARING IT WAS MADE BY THE FAILURE. A consumer's own copy built its create call
            # as '--unpublished --theme-name <name>'; there is no --theme-name flag in the Shopify CLI, and
            # the call failed the FIRST time anybody needed a preview theme created -- the path had been
            # written the day before and no branch had wanted one in between. Nothing was wrong with the
            # reasoning; the code had simply never run, and a per-consumer copy means every consumer gets
            # to discover that independently.
            #
            # start-task DELIBERATELY REMAINS UNSHIPPED, and that is not inconsistent with this. Its page
            # declines to ship a script because creating a preview theme was bound up with the store
            # estate -- and lazy creation is what separated the two: the branch step no longer touches a
            # theme at all, so what is left to share is a push, which is the same call everywhere.
            Name   = 'push-preview'
            Source = 'scripts\task\push-preview.ps1'
            Plugin = 'dkj-subagents-shopify'
            Skill  = 'push-preview'
            # A fixture root, as for sync-main: a consumer never types it, and documenting it would invite
            # someone to.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # The preview push's ARGUMENT LISTS and the two readers of the CLI's own output, as a lib of
            # its own (inbound #805) -- for the same reason sync-rules is one: they are the only halves
            # that can be judged without a store, a network or a theme, and they are exactly the halves
            # that were wrong. The flag whitelist earned its place on its first run in the consumer, by
            # refusing the lib's own call because '--unpublished' had been left out of the list.
            #
            # THE WHITELIST ANSWERS 'IS THIS A REAL CLI FLAG', NEVER 'MAY THIS REPO USE IT' -- so it admits
            # --allow-live. Refusing a live push is the guard hook's job, and a validator answering both
            # questions would give two different answers to the same one.
            Name    = 'preview-theme'
            Source  = 'scripts\lib\preview-theme.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # The one place the Shopify CLI is invoked (inbound #1183, September 1, 2026). Both scripts in
            # this plugin that reach the CLI dot-source it, so it is registered per plugin like
            # source-repo-guard-lib rather than per script: the pair names a destination, and one
            # destination cannot serve two.
            #
            # ITS OWN FILE RATHER THAN native-capture-lib.ps1, which is already mirrored here since
            # inbound #1181 and was the first thing tried. It captures, and a theme pull or push has to
            # STREAM -- minutes of silence over a call that can stop to ask for authentication is the same
            # silent hang #1179 closed. And its bounded arm starts the child with Start-Process, which
            # cannot run the npm .ps1 shim 'shopify' actually resolves to. Reasons in the lib's header.
            Name    = 'shopify-cli-lib'
            Source  = 'scripts\lib\shopify-cli-lib.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        },
        @{
            # The theme archive (issue #1886 candidate 4, September 13, 2026). IT TRAVELS IN
            # dkj-subagents-shopify for the same reason sync-main and push-preview do: the plugin that
            # owns the live theme owns the estate around it. That is a DEPARTURE from the #1881
            # ruling's default -- which sends what the two BWJ stores share to dkj-policy-bwj -- and
            # the reason is that the ruling's axis is the wrong axis here. Archiving a theme is not a
            # BWJ practice, it is a Shopify one, and the two scripts already registered above ship
            # with exactly the same two readers.
            #
            # THE CASE FOR SHARING IT WAS MADE BY THE ALIASING. Both stores built it, under two
            # different filenames -- archive-and-remove-theme.ps1 and archive-theme.ps1 -- so the
            # sibling check could only see it through ONE shared function name and no grep in either
            # repo would ever have found the other. Everything either copy had learned stayed where it
            # was learned: one had the receipts, the multi-theme run and the refusal to remove
            # anything; the other had the third-party integration it must not break.
            #
            # IT NEVER REMOVES A THEME, and that is a guard property rather than a preference. The copy
            # that did removed it from inside a .ps1, and this plugin's live-theme guard is a PreToolUse
            # hook reading the COMMAND STRING of a tool call -- so a destructive theme command buried in
            # a script is invisible to it. That was a live wrapper vector in one store for as long as
            # that script was. The command is printed for the caller to run as its own visible act.
            Name   = 'archive-theme'
            Source = 'scripts\task\archive-theme.ps1'
            Plugin = 'dkj-subagents-shopify'
            Skill  = 'archive-theme'
            # A fixture root, as for sync-main and push-preview: a consumer never types it, and
            # documenting it would invite someone to.
            SkillParamsExempt = @('RootOverride')
        },
        @{
            # The archive's DECISIONS, as a lib of its own (issue #1886) -- for the same reason
            # sync-rules is one: the script around them is all Shopify CLI, which a test cannot reach,
            # while the parts that can be WRONG are pure functions over a name, a role, a path and a
            # text. Every one of the four oldest was found by USING the script in a store rather than
            # by reading it, and the comma one reported success while doing nothing.
            #
            # THREE FUNCTIONS IN IT HAVE NO CALLER IN THIS PLUGIN, deliberately. They read a receipt
            # back and measure a folder against it, which is a script only ONE of the two converged
            # stores has -- and #1886's own bar is that a mechanism only one store has is not a
            # convergence candidate. They travel because they live in this file; stranding them would
            # leave that consumer dot-sourcing a lib that had lost the three functions it calls.
            #
            # DEPENDENCY-FREE, and specifically NOT a reader of repo-config.ps1: the live-theme guard
            # dot-sources that file on every command inside a catch that returns no live theme id, so
            # anything it pulls in is a way to silently disarm the guard. The seam answers are read by
            # the script and passed in.
            Name    = 'theme-archive-rules'
            Source  = 'scripts\lib\theme-archive-rules.ps1'
            Plugin  = 'dkj-subagents-shopify'
            LibOnly = $true
        }
    )

    # WHERE EACH PLUGIN'S FOLDER IS, asked of the marketplace rather than spelled out per pair.
    #
    # TWO DIFFERENT ABSENCES, AND THEY GET DIFFERENT ANSWERS. A repo that declares NO plugins at all
    # mirrors nothing -- an empty registry is the correct answer there, and it is what the lint's
    # minimal fixture is: a synthetic tree with no marketplace.json, where check 8 then reports
    # 'checked 0' through the note it already carries for exactly this case. But a repo that DOES
    # publish plugins and does not have the one a pair names is a defect in this registry, and it has to
    # stop the run: the generator would otherwise compose a mirror path under a folder nobody publishes
    # and create it, which is a copy of a shared script in a place no consumer will ever receive.
    #
    # That every pair resolves in THIS repo is asserted in scripts/tests/shared-scripts.tests.ps1 rather
    # than left to the throw, so a typo is caught where the claim is actually checkable.
    # THE OUTER @() IS LOAD-BEARING, and an @() inside each branch is not enough: the output of an if
    # STATEMENT is unrolled on assignment, so the inner wrap is undone on the way out and an empty set
    # arrives as $null -- which then fails .Count under StrictMode. Same unrolling this lib's own
    # $PluginRoots parameters guard against, one level up.
    $pluginRoots = @(
        if ($PSBoundParameters.ContainsKey('PluginRoots')) { $PluginRoots }
        else { Get-RepoPluginRoots -RepoRoot $RepoRoot }
    )
    if ($pluginRoots.Count -eq 0) { return }

    foreach ($p in $pairs) {
        # THE PLUGIN IS THE ONE THING A PAIR STATES ABOUT ITS DESTINATION, and the mirror path is
        # composed from it. This is the inverse of what stood here until August 9, 2026, and the
        # reasoning is the one that was already written down: the plugin used to be read OFF a full
        # mirror literal, precisely so a second field naming it could not disagree with the path beside
        # it. That instinct was right and the direction was wrong -- every one of the 21 mirrors was
        # exactly '<plugin root>\<Source>', verified across all of them before this was changed, so the
        # literal restated the source path and the layout on every line. Naming the plugin and deriving
        # the rest keeps one statement per fact and removes the layout from this file altogether: the
        # plugin tree moved twice in 2026, and neither move should be legible here.
        $root = Get-PluginRootByName -PluginRoots $pluginRoots -Name $p.Plugin
        if (-not $root) {
            # THE MESSAGE LISTS THE WHOLE SET, and that is the repair for a trap rather than politeness
            # (Tycho, August 9, 2026). This throw is deliberate and stops the run -- see above -- but its
            # commonest reader is not someone who made a typo: it is someone building a fixture
            # marketplace, who has to declare every plugin the registry names and has no way to know
            # what those are except by reading this file. Tycho hit it, went looking with a grep for
            # "Plugin = '" and missed the entries written with two spaces, which is precisely the sort
            # of near-miss a list in the error makes impossible.
            $needed = (@($pairs | ForEach-Object { $_.Plugin } | Sort-Object -Unique) -join ', ')
            $have = (@($pluginRoots | ForEach-Object { $_.Name } | Sort-Object) -join ', ')
            throw ("shared-scripts registry: pair '$($p.Name)' names plugin '$($p.Plugin)', which " +
                   ".claude-plugin/marketplace.json does not declare. This registry needs all of: $needed. " +
                   "The marketplace declares: $have.")
        }
        $mirrorRel = Join-Path $root.RelativeRoot $p.Source
        [pscustomobject]@{
            Name       = $p.Name
            SourceRel  = $p.Source
            MirrorRel  = $mirrorRel
            SourcePath = Join-Path $RepoRoot $p.Source
            MirrorPath = Join-Path $RepoRoot $mirrorRel
            # The plugin whose payload this pair travels in (the core, or the workflow plugin).
            Plugin     = $p.Plugin
            # Where the documenting skill lives, under the same resolved root so a plugin that moves
            # takes its page lookup along. $null when there is no skill to document (LibOnly, or
            # Skill = '').
            SkillRel   = if ($p.ContainsKey('Skill') -and -not [string]::IsNullOrEmpty($p.Skill)) {
                             Join-Path $root.RelativeRoot "skills\$($p.Skill)\SKILL.md"
                         } else { $null }
            # Absent on an entry-point script -- normalized to $false so a caller can test the
            # property without ContainsKey gymnastics under StrictMode.
            LibOnly    = [bool]($p.ContainsKey('LibOnly') -and $p.LibOnly)
            # Normalized for the same reason. A LibOnly entry carries no Skill at all: it is never
            # invoked, so there is nothing for a skill to document. $null therefore means "not
            # applicable", while '' on an entry point means "declared as having none" -- and check 18
            # tells those two apart rather than treating both as nothing to do.
            Skill      = if ($p.ContainsKey('Skill')) { [string]$p.Skill } else { $null }
            SkillParamsExempt = if ($p.ContainsKey('SkillParamsExempt')) { [string[]]$p.SkillParamsExempt } else { @() }
            # HOW THIS SCRIPT MAY BE INVOKED HARMLESSLY, for measure-skill.ps1's wall-clock pass. Three
            # states, and the middle one is why this is $null rather than @() when absent: $null means
            # "no read-only invocation is declared, so it is NEVER RUN to be timed", while @() means
            # "declared safe with no arguments at all" (a check-* script that writes nothing). Same
            # $null-vs-empty distinction Skill above already makes, for the same reason -- a
            # not-applicable and a declared-none are different answers.
            #
            # It lives HERE, beside the registration, rather than in a table inside measure-skill.ps1:
            # a second hand-written list is one a newly shared script falls out of silently, which is
            # the accumulation shape of #275/#331 that LibOnly and Skill above were both moved here to
            # escape. And the safety is the whole point -- timing cut-release by running it would cut a
            # release, so the default of "not declared" must mean "not executed".
            # DECLARED-ness is its own boolean, and it has to be: an `if` expression returning @()
            # unrolls to nothing, so the property below would be $null for BOTH "not declared" and
            # "declared safe with no arguments" -- collapsing exactly the distinction this key exists
            # to make. Measured the first time it ran: check-branch-entry, declared with @(), was
            # reported as undeclared and skipped. Same reasoning as LibOnly being normalized to [bool].
            MeasureDeclared = [bool]$p.ContainsKey('MeasureArgs')
            MeasureArgs = if ($p.ContainsKey('MeasureArgs')) { [string[]]$p.MeasureArgs } else { $null }
            # WHICH SUITE RUNS THE MIRROR COPY, for the depth check (#1857). Check 8 holds the two
            # copies byte-identical, which proves they are the same TEXT and says nothing about them
            # behaving the same -- and they sit at different depths, so a $PSScriptRoot resolution that
            # ascends two levels means the repo root in one copy and the plugin root in the other.
            # Get-DepthSensitiveResolutions finds exactly that class; a pair that has one must name the
            # suite that executes its mirror, or declare why it does not.
            #
            # Here rather than in a list inside the gate, for the reason every other key on this object
            # is here: a hand-written second list is one a newly shared script falls out of silently
            # (#275/#331), and this key's whole job is to catch the script somebody has not thought
            # about yet.
            MirrorRun = if ($p.ContainsKey('MirrorRun')) { [string]$p.MirrorRun } else { $null }
            # The valve, and it is not politeness. A gate with no declared exception gets bypassed
            # wholesale the first time it fires on something legitimate, and a gate that gets bypassed
            # guards nothing -- the reasoning SkillParamsExempt above already carries. A reason is
            # required rather than a bare $true, so the exception is readable where it is taken.
            MirrorRunExempt = if ($p.ContainsKey('MirrorRunExempt')) { [string]$p.MirrorRunExempt } else { $null }
        }
    }
}

function Get-ScriptParameterNames {
    <#
        The parameter names of a script's top-level param() block, via the PowerShell parser rather
        than a regex. That is not fussiness: a regex over the param block missed a parameter carrying
        a [Parameter(Mandatory = $true)] attribute when this was first measured, which would have left
        the gate with a blind spot of exactly the kind it exists to close. Returns @() for a file with
        no param block (every LibOnly entry) and for a file that cannot be parsed.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    if (-not $ast -or -not $ast.ParamBlock) { return @() }
    return @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
}

function Get-NormalizedScriptContent {
    <# Reads a script LF-normalized (CRLF -> LF); $null if the file is missing. #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($raw -replace "`r`n", "`n")
}

function Get-DepthSensitiveResolutions {
    <#
        Every place a script resolves a path off $PSScriptRoot that ASCENDS TWO OR MORE LEVELS -- the
        only class of code where a mirrored script's two copies can behave differently while being
        byte-identical.

        WHY TWO AND NOT ONE. A shared entry point sits at <x>\scripts\<area>\<name>.ps1 in both
        copies, where <x> is the repo root for the workshop source and the PLUGIN root for the mirror.
        One hop reaches <x>\scripts\ -- the same folder relative to the file in both copies, which is
        why '..\lib\...' is depth-invariant and needs no proof. Two hops reach <x> itself, and there
        the two copies part: the source lands on the repo root, the mirror on the plugin root. Same
        characters, different folder, and check 8's byte-equality cannot see it because there is
        nothing to see -- the text IS identical. That is the whole gap (#1857).

        TWO FORMS, because the tree uses both:
          * a string literal with two or more leading '..' segments, in the same statement as a
            $PSScriptRoot reference -- 'Join-Path $PSScriptRoot ''..\..\blueprint\x.json'''
          * two or more nested Split-Path -Parent calls over $PSScriptRoot -- the same ascent written
            without a literal, which a scan for '..' would miss entirely

        VIA THE AST, NOT A LINE SCAN. The statement is the unit, so a Join-Path whose literal sits on
        the next line is seen exactly like one that fits on a line -- the blind spot a 140-character
        window after the variable would have had, and a gate with a silent blind spot is worse than no
        gate. Returns @() for a file that is missing or does not parse.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    if (-not $ast) { return @() }

    $vars = @($ast.FindAll({
        param($n)
        ($n -is [System.Management.Automation.Language.VariableExpressionAst]) -and
        ($n.VariablePath.UserPath -eq 'PSScriptRoot')
    }, $true))

    $findings = New-Object System.Collections.Generic.List[string]
    foreach ($v in $vars) {
        # Up to the enclosing TOP-LEVEL statement: the unit a resolution is written in, and what makes
        # a multi-line Join-Path readable to this function.
        #
        # NOT "the nearest StatementAst", which was the first attempt and silently halved the second
        # form. A PipelineAst is itself a statement, so a nested call --
        # `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` -- stops the climb at the INNER
        # pipeline, where exactly one Split-Path is in scope and the ascent therefore reads as one
        # level. check-policy-drift's own resolution is written that way, so the detector found
        # nothing there while reporting adopt-config correctly. Climbing to the statement that sits
        # directly in a block sees the whole expression.
        $stmt = $v
        while ($stmt.Parent -and -not (
            ($stmt -is [System.Management.Automation.Language.StatementAst]) -and
            (($stmt.Parent -is [System.Management.Automation.Language.StatementBlockAst]) -or
             ($stmt.Parent -is [System.Management.Automation.Language.NamedBlockAst]))
        )) {
            $stmt = $stmt.Parent
        }
        if (-not $stmt) { continue }

        foreach ($s in @($stmt.FindAll({
            param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $true))) {
            $segments = @(($s.Value -split '[\\/]+') | Where-Object { $_ -ne '' })
            $leading = 0
            foreach ($seg in $segments) { if ($seg -eq '..') { $leading++ } else { break } }
            if ($leading -ge 2) {
                $text = $stmt.Extent.Text -replace '\s+', ' '
                if (-not $findings.Contains($text)) { $findings.Add($text) | Out-Null }
            }
        }

        $parentHops = @($stmt.FindAll({
            param($n)
            ($n -is [System.Management.Automation.Language.CommandAst]) -and
            ($n.GetCommandName() -eq 'Split-Path')
        }, $true))
        if ($parentHops.Count -ge 2) {
            $text = $stmt.Extent.Text -replace '\s+', ' '
            if (-not $findings.Contains($text)) { $findings.Add($text) | Out-Null }
        }
    }
    return @($findings)
}
