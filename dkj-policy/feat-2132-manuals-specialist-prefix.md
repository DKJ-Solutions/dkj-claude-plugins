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

#### The hold on the PR is lifted -- steps A and B have landed

The work was built before either predecessor was on the trunk, on Dave's instruction at pickup: no pull
request until [#2130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2130)
(step A, the dual-name readers) and [#2131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2131)
(step B, the subagent defs) had landed. Both closed on September 19, 2026, and the trunk is **merged in
here rather than rebased onto**: this branch is already pushed, so a rebase would need the force push
the safety rules reserve for Dave's explicit word. Where step A's dual-name layer replaced a literal this
branch had rewritten, A's resolver won and the literal went -- that is every edit this branch had made to
lint checks 3b, 6a and 6b, and it is why the CREATE list below is shorter than the one that was built.

### CREATE

- [x] The 27 files renamed with `git mv` -- `-alpha` (16), `-ecomm` (3), `-lifehub` (5), `-shopify` (3).
- [x] `Get-SpecialistFileShapes`'s **Manual row** flipped in `scripts/lib/check-report-lib.ps1` (and its
      three plugin mirrors, via `build-shared-scripts.ps1`): Current takes the `specialist-` prefix,
      AlsoRead keeps the bare spelling a consumer's cache may still be carrying. That row is the whole
      code change step C needs -- step A built the table as the flip point precisely so that no reader
      moves with a rename.
- [~] Dropped at the merge with the trunk: the literal rewrites this branch had made to lint checks 3b,
      6a and 6b. Step A replaced the same literals with the resolver, and the resolver wins. The
      loose-glob question those edits turned on is answered one layer down as well --
      `Get-SpecialistFileFilters` derives the filter list from the table, so a file left behind on the
      old name is still enumerated and still refused rather than silently unscanned.
- [x] The 26 agent defs and Chris's persona body now name their manual at the new path.
- [x] The prose that names a manual: `README.md`, `CLAUDE.md`, `.claude/rules/language-layers.md`, the
      specialists handbook, 11 repo lenses, three plugin READMEs, three SKILL pages, and the three manuals
      that cross-link each other.
- [x] The check 6b fixture in `scripts/tests/check-plugin-integrity-docs.tests.ps1`.
- [x] The 23 manual links in the archived release documents under `dkj-policy/releases/**` -- see the
      note under TEST; the issue had placed this out of scope.

### TEST

- [x] `check-plugin-integrity.ps1` green -- `[manual] checked 27`, `[specialist] checked 53`, 0 errors.
- [ ] Every suite under `scripts/tests/` green.
- [ ] The #1757 check: `git diff origin/main...HEAD | grep '^+' | grep -v '^+++' | grep -- '-manual\.md'`
      names only the new spelling, the two protected citations excepted.

#### The historical carve-out covers wording, not link targets

The issue put `dkj-policy/releases/**` out of scope on the historical carve-out. That reading does not
survive the gate: check 4 scans `releases/**/*.md`, so the rename left 8 dead links there, and the three
previous renames of this kind all rewrote the same links -- `e262121d` (#1698) is the nearest, moving
`plugins/dkj-teams/dkj-team-shopify/manuals/05-21-manual.md` to its `dkj-subagents` spelling inside
`1.15.0.md`. So the carve-out is about what those documents SAY, which is left exactly as written; a link
target is a pointer, and a pointer that no longer resolves records nothing. Steps D and F inherit this.

#### Two citations are deliberately left on the old name

`.claude/specialists/lenses/05-15-extension.md` and `check-plugin-integrity.ps1`'s check-30 comment both
quote `../../../../teams/team-alpha/manuals/06-25-manual.md` as it stood in the installed v4.22.0 copy,
verified on disk. Renaming those would rewrite the evidence rather than the convention. A third,
`scripts/tests/release-lib.tests.ps1:1328`, is a synthetic path against a fake root whose own comment says
the shape is deliberately not this repo's.

### DEPLOY: feat/2132-manuals-specialist-prefix

Every portable manual is now named `specialist-<group>-<id>-manual.md`, and what makes that the WRITTEN
name is a single row: `Get-SpecialistFileShapes`'s Manual entry, where Current takes the `specialist-`
prefix and AlsoRead keeps the bare spelling a consumer's cache may still be carrying. **No reader moved
with it** -- step A (#2130) had already put every one of them behind that table, which is the property
the table exists for, and a file left behind on the old name is still enumerated and still refused
because the filter list is derived from the same row. Step C of the rename plan in #2128.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. A manual is read through
`${CLAUDE_PLUGIN_ROOT}/manuals/...`, which resolves into the version-pinned plugin cache, so the agent def
and the manual it names travel together in one release and never disagree between two of them.

**Score:** N/A

#### Pull Request

The manuals are renamed to specialist-NN-NN-manual.md
