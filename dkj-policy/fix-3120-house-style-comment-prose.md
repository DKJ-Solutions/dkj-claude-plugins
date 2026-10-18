## fix/3120-house-style-comment-prose

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

#3120: `check-house-style` reported a house class named in a comment or an assert message as a
redefinition. Cause, verified in `Find-HouseStyleClassHit`: a rule's prelude runs back to the previous
`{`, `}` or `;`, so it takes in the code and comments before the rule, and the comma split turns the prose
before a comma into a "selector" whose subject is the house class.

### CREATE

- [x] `house-style-rules.ps1`: comments inside a prelude (`/* */`, a line opened by `# ` or `//`) are
  blanked to spaces, and a selector whose subject line -- after the last string quote -- holds a bare word
  that names no HTML or SVG element (`Get-HouseStyleElementNames`) is prose, not a rule.
- [x] `check-house-style.tests.ps1`: the two measured shapes, a `//` comment, and the real rules that still
  count.
- [x] Code review (Victor): a first cut that read only the subject's last line missed `<style>.card`, a
  rule after a block comment, an Allman brace and a domain class on the line above; reworked, and each of
  those is now an assert.

### TEST

- [x] The suite: 73 passed, 0 failed; this repo's own gate still holds at v0.4.0.

### DEPLOY: fix/3120-house-style-comment-prose

N/A -- the gate itself ships in `dkj-solutions`; the change is felt in the consumers, below.

**Score:** N/A

#### What makes this deploy extra special

`check-house-style` no longer fails a DKJ-Solutions repo's PR over a house class named in a comment or a
string before a comma (`# the same .grid-2, which ...`), which until now needed a reworded comment or an
allowlist entry that exempted the real class for the whole file.

**Score:** 2

#### Pull Request

check-house-style no longer reads prose before a comma as a selector

