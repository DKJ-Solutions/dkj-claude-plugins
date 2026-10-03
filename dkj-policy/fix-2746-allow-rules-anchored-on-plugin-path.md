## fix/2746-allow-rules-anchored-on-plugin-path

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

Inbound #2746, verified on pickup: `bootstrap.ps1` generated `*dkj-policy*new-branch.ps1*` (and the
same for open-pr/ship-pr, both tool shapes). That matches the consumer's own root `dkj-policy/` folder
too, which `adopt-dkj-policy` Part 1 scaffolds. The proposed repair, anchoring on the install path,
names a real mechanism. Separator-agnostic `*` between the literal segments keeps it valid for both
slashes. The trailing
`*` stays because the entry points take `-Name` and `-Title`.

Review (Victor, Sebastian): a leading-`*` glob narrows a path's shape but cannot pin its location, so a
planted in-repo `.claude/plugins/cache/...` tree, or the anchor smuggled into the arguments, still
matches. Closing that class is a decision between a pinned root and a prompt, filed as #2752. `cache`
was added to the anchor here, and the wording says "narrows".

### CREATE

- [x] Sylvester: anchor the six entry-point rules on `*.claude*plugins*cache*<plugin>*scripts*<entry>*`, make the gh rule exact, comments say why
- [x] Tessa: one sentence in the specialists-init SKILL.md on what the wildcard keeps literal
- [x] Tycho: bootstrap-drift asserts the new spelling, the exact gh rule, and the rule's BEHAVIOUR (matches the installed copy with either slash, refuses `-File dkj-policy/new-branch.ps1`, `dkj-policy/scripts/...` and a `.claude/plugins/` path outside the cache)

### TEST

- [x] Copy edit (Edith): stale test comment and "the wildcard keeps literal" fixed
- [x] Code review (Victor) + security review (Sebastian): the residual location class filed as #2752; `cache` added, wording narrowed, two more negative asserts

### DEPLOY: fix/2746-allow-rules-anchored-on-plugin-path

The `settings.suggested.jsonc` that `specialists-init` proposes no longer allows a `new-branch`,
`open-pr` or `ship-pr` script just because its path contains `dkj-policy`. Each rule now requires the
install path's shape (`.claude`, `plugins`, `cache`, the plugin, `scripts`, the script), so a script
placed in your repo's own `dkj-policy/` folder through a pull request prompts like any other. This
narrows the rule rather than pinning a location: a pull request that adds a `.claude/plugins/` tree to
your repo still deserves a careful look (#2752). The
`gh repo edit --delete-branch-on-merge` rule is now exact, so it no longer allows `--visibility` or other
flags. Rules you already pasted are unchanged: re-run `specialists-init` and paste the new allow lines
to pick this up.

**Score:** 3

#### What makes this deploy extra special

The drift suite now reads each generated rule back as a pattern and runs it against real commands, so
it pins what the rule allows rather than how it is spelled.

**Score:** 2

#### Pull Request

specialists-init: anchor the allow rules on the plugin install path, make the gh rule exact

