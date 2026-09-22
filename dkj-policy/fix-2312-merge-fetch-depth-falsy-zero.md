## fix/2312-merge-fetch-depth-falsy-zero

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

Closes #2312. Measured on the merge commit that landed #2303 itself (`4819ec02`, run 35749674281):
the checkout step printed `fetch-depth: 1` even though the push subject matched `startsWith(...,
'merge: ')`, so the deepened checkout never happened and the new "Merge-commit certificate" step
answered `skip=false` on every shard with `'git log HEAD^1' failed ... history too shallow`.
Fail-closed, so no trunk safety issue -- the full suites ran, exactly as before #2303 -- but the
whole saving that issue was written for has never actually fired.

Root cause: GitHub Actions expressions use JS-like truthiness, where the NUMBER `0` is falsy. The
line read `cond && 0 || 1`; `cond && 0` evaluates to `0`, itself falsy, so `||` falls through to
`1` regardless of `cond`. The classic ternary-idiom trap, firing exactly because the "true" branch
value (a fetch depth of zero) is itself falsy.

### CREATE

- [x] .github/workflows/ci.yml -- quote both arms as strings (`'0'` / `'1'`) instead of bare
      numbers. A non-empty string is never falsy in this expression language (including the string
      `"0"`), and `with:` values are passed to the action as strings regardless, so this is the
      fix rather than a cosmetic change. Comment added explaining the trap for the next reader.

### TEST

- [x] scripts/tests/ci-shard.tests.ps1 -- updated the existing fetch-depth assert to match the
      quoted string literals, and added a new guard asserting the true branch is never a bare,
      unquoted `0` -- so a future edit that reintroduces the trap fails the suite instead of
      silently no-op'ing on the one push it exists for.
- [x] `npx js-yaml .github/workflows/ci.yml` -- parses cleanly.
- [x] Full lint gate (`check-plugin-integrity.ps1`): 0 errors.
- [~] A live CI run on a real 'merge: ' push proving `fetch-depth: 0` actually lands and the
      suites skip fires -- can only be proved once this lands and the next branch merges through
      ship-pr; not reproducible locally since GitHub Actions expression evaluation only happens on
      GitHub's own runners.

### DEPLOY: fix/2312-merge-fetch-depth-falsy-zero

`ci.yml`'s conditional `fetch-depth` on the merge-commit checkout (#2303) never actually reached
`0`: GitHub Actions expressions treat the number `0` as falsy, so `cond && 0 || 1` silently fell
through to `1` on every push, regardless of `cond`. Fail-closed, so this cost no safety margin --
the full suite ran on every merge commit exactly as it did before #2303 -- but it meant the
suite-skip #2303 was built for had never actually fired. Fixed by quoting both arms as strings
(`'0'` / `'1'`), which GitHub Actions never treats as falsy, plus a new assert pinning that a bare
unquoted `0` cannot return to this line unnoticed.

**Score:** 2

#### What makes this deploy extra special

N/A -- a CI-internal fix to this repo's own `.github/workflows/ci.yml`; nothing here is mirrored
to a consumer.

**Score:** N/A

#### Pull Request

ci.yml's merge-commit fetch-depth no longer falls through the falsy-zero && / || trap

