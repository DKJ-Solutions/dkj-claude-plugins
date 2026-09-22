## feat/avatars-assets-folder

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

Move the three account avatar PNGs out of the repo root into assets/avatars/, so every machine can reach them at a fixed path via the marketplace clone.

#### Why the root is not the place

Three avatar PNGs sat untracked in the repo root, beside `README.md` and `CLAUDE.md`. The root is
reserved for the entry documents, so they needed a home -- and the home had to be reachable from
every machine, because their whole function is to say which GitHub account a machine is set up as.

`assets/avatars/` answers both. It is at the root rather than under `plugins/` for the reason
`connectors/` is: the marketplace clone is the whole repository, so anything at the root is on every
machine at `~/.claude/plugins/marketplaces/dkj-claude-plugins/assets/…` after a marketplace update --
no release, no version bump. Under `plugins/` the same files would wait for a cut and then land in
the payload of every consuming repo, none of which has any use for them.

Scope is the placement only, by Dave's word: no rename to the exact GitHub login, and nothing in the
tree reads these files.

### CREATE

- [x] `assets/avatars/` created and the three PNGs moved there from the repo root
- [x] `assets/avatars/README.md` written: what the folder is, the fixed path every machine reaches it
      at, why it is not plugin payload, and the file/tile/account table
- [x] `README.md`: an `assets/` bullet added to **Repo layout**, beside `connectors/`

### TEST

- [x] `check-plugin-integrity.ps1` + the full suite via `open-pr.ps1` -- manifests, frontmatter and
      the dead-link scan, which is what reads the two new relative links in `README.md`
- [x] `.gitattributes` already carries `*.png binary`, so the three files need no handling of their
      own -- verified before the move rather than added by it

### DEPLOY: feat/avatars-assets-folder

The three GitHub-account avatars move out of the repo root into `assets/avatars/`, with a README
stating the fixed path every machine reaches them at and why the folder is root material rather than
plugin payload. `README.md`'s **Repo layout** gains the matching bullet.

Small, and noticed the moment somebody looks for those images or at the root listing: the root is
back to its entry documents, and "where are the avatars" has an answer that holds on every machine
instead of per download folder.

**Score:** 2

#### What makes this deploy extra special

Nothing reaches the subscriber of this workflow. The folder is this repo's own material, deliberately
outside the plugin payload, so no consuming repo receives it in a cut or has anything to adopt.

**Score:** N/A

#### Pull Request

GitHub-account avatars in assets/avatars/

