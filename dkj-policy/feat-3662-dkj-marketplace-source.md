## feat/3662-dkj-marketplace-source

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Step 2 of #3660: the source-side rename to `dkj-marketplace`, the role #1819 played for #1769.

#### Parked with no PR until the flag day

This was decided by davekokbwj on October 29, 2026, and recorded on #3662. Merging before the GitHub
rename (#3663) would point `Get-RepoName` at a repo that does not exist yet, and every PR in between
would fail. So the branch is built now, parked on origin, and merged on the flag day together with step
3. The two open steps under TEST are the flag day's.

#### What changed, and what deliberately did not

- **Changed:** the marketplace `name`; `Get-RepoName`; `dkj-claude-plugins` added to the front of
  `Get-RetiredRepoNames`; every `<plugin>@…` id, every `marketplaces/…` and `cache/…` path, and every
  `DKJ-Solutions/…` slug outside issue and PR links. Also every lookup of the marketplace name in code
  (release-freshness, connector-sessioncheck, session-start-lib, the claude-md-import fallback), the CLI
  commands in the docs, and the BWJ extension's admitted-repo name, which it matches against `origin`.
- **Widened, not replaced:** the regexes that recognise this repo in a consumer's runner
  (`adopt-ci-floor`, `teardown`, house-style pins, the Asana gate). They now take `dkj-marketplace` as
  well as both older names, because consumers keep the old spelling until step 4.
- **Kept:** issue and PR links (#1526); `dkj-policy/releases/**` and `CHANGELOG.md`; the five consumer
  manifests in `connectors/` (a renamed id is written only after the consumer has migrated, which is
  step 4); the local folder name, which stays `dkj-claude-plugins` (#3661), so the folder candidates,
  `Get-HubRepoName` and the hub's `%LOCALAPPDATA%\dkj-claude-plugins` stores keep it; and dated history
  that cites the old name.

### CREATE

- [x] Scripted pass: plugin ids, install paths, and the slug outside issue and PR links, with the
      migration section in ADOPTION.md restored where it has to name the old name
- [x] Hand pass over the 160 remaining occurrences of the bare name, sorted as above
- [x] `repo-config.ps1`: `Get-RepoName`, `Get-RetiredRepoNames`; `this-repo.md`'s citation rule;
      the third rename in Sylvester's lens

### TEST

- [x] Built state, October 29, 2026: `open-pr -GatesOnly` passed lint; 5 of 171 suites failed, every one
      pinning the old name. After the fix, those five were run again and all pass.
- [ ] Flag day: catch-up merge from `main`, then `git grep` again for new `@dkj-claude-plugins`, `marketplaces/dkj-claude-plugins` and slug literals
- [ ] Flag day: gates and CI green on the caught-up branch, after the GitHub rename

### DEPLOY: feat/3662-dkj-marketplace-source

The marketplace and its source repository are now called `dkj-marketplace`
([#3660](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3660)). Plugin ids read
`<plugin>@dkj-marketplace`, the clone sits at `~/.claude/plugins/marketplaces/dkj-marketplace/`, and
the repo is `DKJ-Solutions/dkj-marketplace`. A marketplace name has no redirect. So every consuming repo
and every machine moves over once, by the procedure in
[`ADOPTION.md`](../plugins/ADOPTION.md#moving-to-dkj-marketplace). Until a consumer does, its plugins
stop loading, and nothing reports that. The tooling still recognises the two older names wherever a
consumer may carry them
([#3662](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3662)).

**Score:** 5

#### What makes this deploy extra special

Every consumer has to act: rewrite the settings keys and the `@`-imports, remove the old marketplace
once per machine, and install again in every checkout. Skipped, the plugins silently stop loading.

**Score:** 5

#### Pull Request

Rename the marketplace and the repo name to dkj-marketplace in the source

