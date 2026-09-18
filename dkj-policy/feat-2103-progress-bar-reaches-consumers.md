## feat/2103-progress-bar-reaches-consumers

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Three parts from #2103: register run-progress-lib.ps1 as a LibOnly shared pair and mirror it; mirror show-progress.ps1 and decide its skill question; add a refuse-and-print statusLine seam to adopt-dkj-policy. NOTE: PR #2113 (feat/2104, maikel-bwj) touches scripts/lib/shared-scripts-lib.ps1 and scripts/lib/run-progress-lib.ps1 too -- whoever lands second rebases.

#### The premise was verified before anything was built

#2103's body asserts that `statusLine` is a settings key and that nothing else can place it. That is
the reason the whole third part exists, so it was read against the plugin reference rather than taken
on trust -- and it holds: `plugin.json` carries no `statusLine`, a plugin-root `settings.json` supports
only `agent` and `subagentStatusLine`, and `${CLAUDE_PLUGIN_ROOT}` is not expanded in a statusLine
command nor exported to it.

#### And verifying it surfaced the question the issue had not asked

If the path has to live in the consumer's settings, WHICH path. The plugin cache is keyed by version
-- this machine holds `dkj-policy/5.0.0` through `5.5.0` side by side -- so a cache path written at
adoption keeps working after an update and renders the payload installed that day, silently and
permanently. Three answers were put to Dave with their failure modes; he chose the shim.

### CREATE

- [x] Register `run-progress-lib.ps1` as a `LibOnly` shared pair, into `dkj-policy` AND into
      `dkj-subagents-shopify` -- the second mirror of `native-capture-lib.ps1` lives there and resolves
      its guarded dot-source inside its own plugin.
- [x] Register `show-progress.ps1`, with `Skill = ''`. #2103 asked the question outright and this is
      the answer: nobody invokes it as a procedure -- Claude Code runs it because settings.json names
      it, which is a hook's shape one key over. What a person invokes is the command that wires it up.
- [x] `MirrorRun = 'run-progress.tests.ps1'` on that entry: its context-line directory fallback
      ascends two levels off `$PSScriptRoot`, so it means the repo root here and the plugin root in the
      mirror, and check 8 cannot see the difference. The lint gate caught this rather than a reviewer.
- [x] `scripts/task/adopt-statusline.ps1` -- Part 5 of `adopt-dkj-policy`: places the shim, adds the
      settings key, refuses where one is already there, refuses a settings file that does not parse,
      refuses in the repo that publishes this workflow.
- [x] Generate the four mirrors.
- [x] Rows in `plugins/dkj-policy/scripts/README.md` for all three new mirrors.
- [x] Part 5 on the skill page, plus the frontmatter description and the intro that both said "four".
- [~] A `-UserHomeOverride` seam on the new command. Dropped after writing it: this command never
      reads the install administration -- resolving the payload is the shim's job at render time -- so
      it would have been a fixture knob over a read that does not happen. Removed from the registry's
      `SkillParamsExempt` with it, and the reason is recorded at both seams.

### TEST

- [x] `scripts/tests/adopt-statusline.tests.ps1` -- 38 asserts. Weighted towards the refusals and the
      shim's contract rather than the happy path: an existing statusLine survives, an unparseable
      settings file is untouched, a neighbouring settings key survives, a re-run rewrites nothing, and
      the shim prefers this repo's install record, falls back to a pathless one, never uses another
      repo's, and exits 0 on every missing thing.
- [x] `scripts/tests/run-progress.tests.ps1` -- the mirror block INVERTED. It asserted that
      run-progress-lib was absent beside both `native-capture-lib.ps1` mirrors and that
      `$script:RunProgressAvailable` was `False` there; it now asserts the lib is present and the value
      is `True`. Three asserts added beside it: the dot-source is still GUARDED, the statusline and its
      lib landed in the same plugin, and the mirror runs from its own depth. 51 asserts.
- [x] Lint gate green, script contract unchanged (no new seam).

### DEPLOY: feat/2103-progress-bar-reaches-consumers

The background progress bar reaches consumers. #2101 built it in this repo and deliberately mirrored
none of it: `native-capture-lib.ps1` reached `run-progress-lib.ps1` through a **guarded** dot-source,
so in a consumer the `Test-Path` failed and the gate behaved exactly as it had. That was a parked
state, not a destination. Registering the lib as a shared pair is what turns the guard's false arm
into its true one -- in `dkj-policy` and in `dkj-subagents-shopify`, which carries the second mirror of
the file that reaches for it -- without editing `native-capture-lib.ps1` again. The statusline that
draws the bar is mirrored beside it.

The third part is new machinery, because `statusLine` is a **settings** key: `plugin.json` has no such
key, a plugin-root `settings.json` supports only `agent` and `subagentStatusLine`, and
`${CLAUDE_PLUGIN_ROOT}` is not expanded there. Nothing a plugin ships can place it, so
`adopt-statusline.ps1` does -- Part 5 of `adopt-dkj-policy`, dry-run by default like its siblings.

**What it places is a shim rather than a path, and that is the decision the part is built around.**
The plugin cache is keyed by version, so writing today's cache path into a consumer's settings would
leave them rendering that payload after every future update: still working, still stale, and reported
by nothing. Copying the two scripts into the consumer trades it for two live copies drifting each
release with no lint over them. The shim is one file that never changes, resolving the installed
payload at render time -- so the settings path cannot go stale and the logic stays where a release can
reach it. An existing `statusLine` is never replaced: there is one per settings file, so the run leaves
it alone and prints the block.

**Score:** 3

#### What makes this deploy extra special

A subscriber of this workflow gets the progress bar at all, which until now existed only in the repo
that built it. The visible half is a status line that keeps rendering while a backgrounded gate or CI
wait shows nothing anywhere else; the durable half is that the path they adopt cannot be stranded by
the next plugin update. It needs one command -- `adopt-statusline.ps1 -Apply` -- and it takes nothing
away from a repo that already has a status line of its own.

**Score:** 3

#### Pull Request

The progress bar reaches consumers: run-progress-lib mirrored, show-progress shared, and the statusLine seam in adopt-dkj-policy
