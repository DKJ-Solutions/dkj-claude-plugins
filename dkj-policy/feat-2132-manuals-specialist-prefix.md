## feat/2132-manuals-specialist-prefix

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

Step C of the rename plan in [#2128](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2128):
the 27 portable manuals become `specialist-<group>-<id>-manual.md`, and every reader that constructs or
judges that name moves with them.

#### The PR waits on steps A and B -- Dave's instruction at pickup

The work is built now; the pull request is not opened until [#2130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2130)
(step A, the dual-name readers) and [#2131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2131)
(step B, the subagent defs) have landed. This branch is cut from the trunk rather than stacked on either,
so it rebases onto them; where step A's dual-name layer replaces a literal this branch rewrote, A's
resolver wins and the literal goes.

### CREATE

- [x] The 27 files renamed with `git mv` -- `-alpha` (16), `-ecomm` (3), `-lifehub` (5), `-shopify` (3).
- [x] Lint check 3b: the id extraction is now `^specialist-(\d{2})-(\d{2})-manual$`, and the refusal names
      the new pattern. **The `*-manual.md` glob is deliberately left loose** -- it still matches both
      spellings, which is what keeps a file left behind on the old name visible to 3b's refusal instead of
      silently unscanned.
- [x] Lint check 6a: the constructed `$manualBase` carries the prefix, so an agent def is held to naming
      `manuals/specialist-<g>-<id>-manual.md`.
- [x] Lint check 6b: the orphan walk's own `^(\d{2})-(\d{2})-manual$` moved too -- left behind it would
      have matched nothing and skipped the whole check in silence -- and so did the persona-names-its-manual
      string.
- [x] The 26 agent defs and Chris's persona body now name their manual at the new path.
- [x] The prose that names a manual: `README.md`, `CLAUDE.md`, `.claude/rules/language-layers.md`, the
      specialists handbook, 11 repo lenses, two plugin READMEs, three SKILL pages, and the three manuals
      that cross-link each other.
- [x] The check 6b fixture in `scripts/tests/check-plugin-integrity-docs.tests.ps1`, and the synthetic
      manual path in `scripts/tests/release-lib.tests.ps1` -- that one is fake data against a fake root and
      no reader judges it, but left on the old spelling it reads as a spot the rename missed.
- [x] The 25 manual-path citations -- 8 of them live links -- in the archived release documents under `dkj-policy/releases/**` -- see the
      note under TEST; the issue had placed this out of scope.

### TEST

- [x] `check-plugin-integrity.ps1` green -- `[manual] checked 27`, `[specialist] checked 53`, 0 errors.
- [x] Every suite under `scripts/tests/` green -- 0 failing of the full set, run one by one as CI does.
- [x] The #1757 check: `git diff origin/main...HEAD | grep '^+' | grep -v '^+++' | grep -- '-manual\.md'`
      names only the new spelling, apart from the lines of this document that quote the old one.

#### The historical carve-out covers wording, not link targets

The issue put `dkj-policy/releases/**` out of scope on the historical carve-out. That reading does not
survive the gate: check 4 scans `releases/**/*.md`, so the rename left 8 dead links there, and the three
previous renames of this kind all rewrote the same links -- `e262121d` (#1698) is the nearest, moving
`plugins/dkj-teams/dkj-team-shopify/manuals/05-21-manual.md` to its `dkj-subagents` spelling inside
`1.15.0.md`. So the carve-out is about what those documents SAY, which is left exactly as written; a link
target is a pointer, and a pointer that no longer resolves records nothing. Steps D and F inherit this.

#### One citation is deliberately left on the old name -- and its twin turned out to be corrupt

Check 30's comment in `check-plugin-integrity.ps1` quotes `../../../../teams/team-alpha/manuals/06-25-manual.md`
as `cut-release/SKILL.md:123` read in the installed v4.22.0 copy, *verified on disk, not inferred*. Renaming
that rewrites the evidence rather than the convention, so it stays exactly as it is.

`.claude/specialists/lenses/05-15-extension.md:2161` writes the same sentence about the same measurement and
quotes `teams/dkj-subagents-alpha/...`. Both cannot be verbatim, and `git log -L` says which one moved: the
lens copy was swept by `eaeb832b` and then again by `e262121d` (#1698), so it now presents as a v4.22.0
quotation a string that did not exist when v4.22.0 was cut. That is a defect on the trunk rather than
anything this branch did; it is filed as
[#2139](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2139) and this branch leaves the line
exactly as it found it.

The general half is the seam every remaining step of #2128 sits on: a path sweep cannot tell a **pointer
somebody follows** from a **quotation somebody checks**, and both are spelled the same way.

### DEPLOY: feat/2132-manuals-specialist-prefix

Every portable manual is now named `specialist-<group>-<id>-manual.md`, and the readers that judge or
construct that name were moved in the same commit -- check 3b's id extraction, check 6a's constructed
path, check 6b's orphan walk and its persona-names-its-manual assert. The `*-manual.md` glob stayed loose
on purpose: it is what keeps a file left on the old name inside 3b's refusal instead of outside its scan.
Step C of the rename plan in #2128.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. A manual is read through
`${CLAUDE_PLUGIN_ROOT}/manuals/...`, which resolves into the version-pinned plugin cache, so the agent def
and the manual it names travel together in one release and never disagree between two of them.

**Score:** N/A

#### Pull Request

The manuals are renamed to specialist-NN-NN-manual.md
