## fix/2664-measure-skill-dmi-not-always-on

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

#2664: `measure-skill` counted the descriptions of `disable-model-invocation: true` skills as always-on,
though a session never lists them. `measure-session-start` already splits those rows out, so reuse its
functions rather than writing a second reader.

### CREATE

- [x] Move `Test-SkillModelInvocationDisabled`, `Get-PayloadDirForPlugin` and `Split-SkillRowsByInvocation`
      from `session-start-lib.ps1` to `measure-skill-lib.ps1` (the #2670 arrangement), so both reports split
      the same way
- [x] `measure-skill.ps1` reads the flag from the priced copy, prices a not-listed row at 0 with its priced
      figure beside it, and names both the printed total and what a session pays
- [x] Skill page and script header document the rule; mirrors regenerated

### TEST

- [x] `measure-skill.tests.ps1` (104 pass) pins the split from `measure-skill-lib` alone;
      `measure-session-start.tests.ps1` 198 pass; `check-plugin-integrity.ps1` no findings
- [x] Live run, v5.11.0: `dkj-policy` printed 5,710, of which 2,710 is 12 not-listed skills; a session pays
      3,000. `dkj-subagents-alpha` printed 821, of which 600 is 3 not-listed skills

### DEPLOY: fix/2664-measure-skill-dmi-not-always-on

`measure-skill` no longer counts a skill whose frontmatter sets `disable-model-invocation: true` as
always-on cost. A session never lists such a skill, so its description was in the printed total but in no
context. Such a skill now reads `0 (not listed; priced N)`, and each plugin line gives the printed total
next to what a session actually pays (#2664). For `dkj-policy` at v5.11.0 that is 3,000 of the 5,710 printed.

**Score:** 2

#### What makes this deploy extra special

If you use `measure-skill` to judge what your plugins cost a session, the always-on figures now match what
a session loads. Skills that only run when typed no longer inflate the total.

**Score:** 1

#### Pull Request

measure-skill prices disable-model-invocation skills at 0 always-on, since a session never lists them

Plugins: dkj-policy
