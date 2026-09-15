## fix/2031-theme-duplicate-force

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

The Shopify CLI declares --force on 'theme duplicate' as 'Required if non interactive outside CI', so the backup step failed at 1/3 in every agent session. Add the flag, build the argument list once so the dry run cannot print a different command than the one that runs, and gate the whole class in the lint.

### CREATE

- [x] `backup-live-theme.ps1` step 1 passes `--force` to `theme duplicate`, and the argument list is
      built ONCE into `$dupArgs` so the dry run prints the command that actually runs.
- [x] The plugin mirror regenerated through `scripts/sync/build-shared-scripts.ps1` rather than edited
      by hand.
- [x] Lint check 44 (`shopify-force`) added to `check-plugin-integrity.ps1`, with its entry in the
      self-enumerating list check 37 holds this file to.
- [x] Check 44 resolves a `-Arguments` naming a VARIABLE, through one reader shared with the inline
      spelling -- the first cut had two readers, resolved 2 of 30 call sites and was green and blind.

### TEST

- [x] The flag contract MEASURED against Shopify CLI 4.8.0 rather than assumed: all seventeen `theme`
      subcommands read for a `-f/--force` flag. Exactly three declare one -- `delete`, `duplicate`,
      `publish` -- and all three document it as "Required if non interactive". `pull` and `push`
      accept no such flag, which is what puts the four `theme pull`/`theme push` call sites out of
      scope by measurement instead of by exemption.
- [x] Lint gate green: 0 errors, `[shopify-force] checked 30` call sites, 4 not reached and named.
- [x] The check proven to FIRE, not merely to pass: `--force` dropped from
      `sweep-preview-themes.ps1:220` produced exactly the expected finding at that line, and the file
      was restored.
- [x] Five scenarios (83-87) added to `check-plugin-integrity-commands.tests.ps1`, covering the
      inline finding, the clean call, the variable lane in both directions, `pull`/`push`/`list` as
      non-subjects, and an unreadable list being counted rather than accused.
- [x] Full test gate run.

### DEPLOY: fix/2031-theme-duplicate-force

`backup-live-theme.ps1` could not complete from an agent session. Its step 1 duplicated the live theme
without `--force`, and the Shopify CLI declares that flag **"Required if non interactive outside CI"** --
so the backup failed at 1/3 every time, while `CLAUDE.md` in both BWJ consumer repos names this script as
the closing step of a release cut. The failure was clean, which is why it survived: nothing was created,
nothing was rotated, and the message correctly said the previous backup still stood. A store following the
documented procedure simply never got a baseline, and every document said it had one.

The same file had passed `--force` to `theme delete` all along, 115 lines further down -- the delete path
had learned this and the create path had not, with nothing holding the two together.

Three things changed. The flag is there. The argument list is built **once**, into `$dupArgs`, because the
dry run hand-built a second spelling of the same command and printed the one that could not succeed -- so
the only mode a session could safely run reported the defect as the intended behaviour. And the class is
now gated: lint check 44 holds every `Invoke-ShopifyCli` call to carrying `--force` where the subcommand
prompts.

**The gated set is measured, not reasoned about.** All seventeen `shopify theme` subcommands were read
against CLI 4.8.0: exactly three declare a `-f/--force` flag -- `delete`, `duplicate`, `publish` -- and all
three document it as required when non-interactive. `theme pull` and `theme push` accept no such flag at
all, so the four call sites using them are out of scope by measurement rather than by exemption; a check
built on the intuition that "a mutating call can prompt" would have demanded an argument those commands
reject.

**Score:** 4

#### What makes this deploy extra special

A lint rather than a test, for the reason check 31 already carries one flag over: the subject is the call
site that does not exist yet. A test asserts about today's callers, while a new script in a plugin reaches
a consumer's install whether or not anybody remembered to extend a suite.

The check's own first cut is the part worth keeping. It read an inline `@(...)` as one AST node type and a
variable assignment as another, through two separate readers -- and `@(...)` written directly as an
argument parses as the *other* type. It resolved 2 of 30 real call sites, reported 0 findings, and was
blind to `theme delete --force`, the one call in the tree that proves the rule. It was green, and nothing
in the run said the reader was broken. What caught it was the coverage line naming what it had **not**
reached; what fixed it was one reader instead of two. Scenario 85 pins both directions so they cannot
diverge again.

**Score:** 2

#### Pull Request

backup-live-theme: the live duplicate carries --force, so it runs from a non-interactive session
