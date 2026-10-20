## feat/3231-hub-repo-sessions

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

#3231: the owner wants this repo to be the DKJ hub -- look into the other repos from here and start work in
one (a new dossier in the lifehub) without first starting that repo by hand. Assessed first: work done in
another repo FROM a session here would run under this repo's rules and could carry a private repo's content
into this public one. So the hub looks in and hands the work over, by opening Claude Code in that checkout.

The hub server stays GET-only and starts no process: a page that could launch a Claude session with a
prompt would be a cross-site route into whatever mode that session runs in. It shows the command to copy.

#### Visible result

The `/connectors` page gains a line per checked-out repo, so this branch stops for the owner's look.

### CREATE

- [x] `scripts/lib/connector-dashboard-lib.ps1`: `Resolve-ConnectorCheckout` (the server's inline resolver,
      moved here so both callers share it), `Resolve-ConnectorRepo`, `ConvertTo-PowerShellLiteral` and
      `Format-RepoSessionCommand`; the `/connectors` mini-card shows the session command with a Copy button.
- [x] `scripts/dashboard/serve-connector-dashboard.ps1` uses `Resolve-ConnectorCheckout` and hands the
      resolved path to the page.
- [x] `scripts/dashboard/repo-session.ps1`: `-List`, the status of one repo, and `-Open [-Prompt] [-WhatIf]`.
- [x] `.claude/skills/repo-session/SKILL.md`: the repo-local skill, beside `harvest-artifacts`.

### TEST

- [x] `connector-dashboard.tests.ps1`: name resolution, the literal PowerShell reads back unchanged (the
      typographic quotes included), the command, and the script against a fixture tree -- 196 pass.
- [x] Review: Victor, Sebastian and Edith, nothing blocking. Applied: a prompt opening with `-` (which
      `claude` would read as an option, `--dangerously-skip-permissions` among them) and one over 8000
      characters are refused, the wt title is used only when it is a plain name, and two prose mismatches
      are corrected. Left as is: the manifest loop the script and the server each run (the resolver they
      share is the part that must agree).
- [x] Run against this machine: `-List`, `lifehub`, and `lifehub -Open -WhatIf` resolve `dkj-lifehub`.

### DEPLOY: feat/3231-hub-repo-sessions

The Repo hub now looks into every repo registered under `connectors/` and opens Claude Code in its checkout
([#3231](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3231)). The new repo-local
`repo-session` skill shows a repo's checkout, branch and open issues, and opens a session in that checkout
in a window of its own, optionally with a first prompt. The `/connectors` page shows that command per
checked-out repo, to copy. The work then runs under that repo's own rules, and an issue for it is filed
there.

**Score:** 1

#### What makes this deploy extra special

N/A: the hub and the skill are this repo's own, and no consumer takes them.

**Score:** N/A

#### Pull Request

Hub: look into every registered repo and open a Claude session in its checkout

