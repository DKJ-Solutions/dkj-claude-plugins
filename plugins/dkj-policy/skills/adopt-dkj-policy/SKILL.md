---
name: adopt-dkj-policy
description: Adopt the dkj-policy workflow in a consuming repo, in four independent parts that can run in any order or alone. Part 1 scaffolds the workflow's own root folder -- dkj-policy/ -- the folder docs (README and CONTRIBUTING), the releases root with this repo's release answers, the branch-entry CI gate, and the PR template open-pr fills in; use this right after installing the plugin, or when the script-contract session check reports the folder missing, since an install alone writes nothing into the repo. Part 2 adopts the source repo's workflow configuration from the shipped blueprint -- placing the values that state the shared way of working into this repo's own seam libs, and proposing the rest for a person to answer; use this after specialists-init has laid down scripts/repo-config.ps1 and scripts/lib/branch-info.ps1, or whenever the script-contract check reports functions this repo has never configured. Part 3 builds the CI floor -- it places the two runners that keep the fold and the resolves verification alive across a merge the shipping session never observes (a merge queue, or the GitHub UI merge button), and reports whether a required status check exists at all, which is the certificate ship-pr dates its staleness guard from; use it after installing the plugin, when ship-pr says the staleness guard is off because no required check is known, or when a merge landed and nothing folded. A merge queue is optional and is not this workflow policy: most repos cannot have one, so a missing queue is reported as the ordinary state rather than as a gap. Part 4 puts the one issue label this workflow prescribes on the tracker -- the reach label, minor by default, which is the tier model read on an issue instead of on a changelog entry; use it after installing the plugin, or when a filing fails because the label does not exist. Parts 1 to 3 are strictly additive and dry-run by default; none overwrites anything, and part 4 is a person's gh call rather than a script.
---

# adopt-dkj-policy -- scaffold the folder, place the config seams, build the CI floor

An install writes nothing into your repo: it clones the plugin into your cache, and that is all. This
command is the four things that actually place `dkj-policy` on your side, and they are independent of
each other -- run them in any order, or run only the one you need:

- **Part 1** creates the workflow's own root folder and its CI gate.
- **Part 2** places or proposes the answers to the repo-owned config seam the shared scripts read.
- **Part 3** builds the CI floor: the two runners that survive a merge your session never sees, and
  whether a required check exists for the staleness guard to read. A merge queue is optional here.
- **Part 4** puts the one issue label this workflow prescribes on your tracker.

No part depends on another having run. Parts 1 to 3 are dry-run by default and never overwrite a file
that already exists. Part 1 makes exactly one write **into** an existing file -- it appends the folder
README's marked UPDATE section when that page does not carry it -- and it replaces nothing; see its
rules below.

## Part 1 -- scaffold the workflow folder

Everything portable about the `dkj-policy` workflow gathers in **one folder in your repo's
root** (Dave, August 14, 2026), instead of scattering through it -- `branch/` from the first
`new-branch` run here, a `releases/` tree from the first cut there, a `CONTRIBUTING.md` if somebody
wrote one. A plugin **install cannot create the folder**: an install is a clone into the plugin cache
and writes nothing into your repo. This part is what places it, and the script-contract session
check reports at session start while it is missing.

```text
dkj-policy/
  README.md              what this folder is, and where each page's portable half lives
  CONTRIBUTING.md        this repo's answers to CONTRIBUTING-portable.md
  releases/README.md     this repo's answers to RELEASES-portable.md (the release LIST is not here)
  (releases/audience/ is NOT placed -- your first cut creates it when it writes the note there)
  (<branch>.md is NOT placed -- one per branch, living only while that branch is open)
```

**And two files outside it**, since August 20, 2026 (inbound
[#789](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/789)) and September 11, 2026
([#1843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1843)):

```text
.github/workflows/branch-entry.yml   the CI gate that holds every PR to carrying a written entry
.github/pull_request_template.md     the PR body open-pr fills in, copied from the plugin's reference
```

The second is a **copy** where the first is a call, and it has to be: GitHub reads a PR template only
from that path in your own repo, so it is the one file in this cycle that cannot be imported. It used to
be the one file you copied by hand -- and the cost of forgetting was invisible, because `open-pr` builds
its body only when that path exists and says nothing when it does not. **A repo without it got PRs with
no body at all.** Like everything else here it is never overwritten, so a template you already have --
your checkboxes, your sections, even an older placeholder the matcher still recognises on purpose --
is left exactly as it is.

### Run it

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-workflow-folder.ps1"
```

That is a **dry run**: it prints exactly what it would create and writes nothing. Add `-Apply` when
the list looks right.

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

### Parameters

| parameter | what it does |
|---|---|
| `-Apply` | write the files. Without it the command is a dry run that prints the plan and touches nothing -- the same default Part 2's command uses. |

### The rules it works under

- **Strictly additive, never overwrites.** Every file that already exists is left exactly as it is,
  whatever it contains -- so a re-run finds nothing to do, and everything you wrote past the `VUL-IN`
  markers is yours. **No FILE is ever rewritten**, which is new since August 23, 2026: `new-branch` used
  to refresh the generated `branch/templates/` on drift, and the merged development document carries its own
  guidance, so there is no reference beside it left to keep current. (Since #1766 one *region* of one
  file is -- the fenced block below. The file is still never rewritten as a whole, and nothing outside
  those two markers is so much as read.)
- **With one bounded exception: the fenced block in your folder README, which IS rewritten** (issue
  #1766). One region of one file -- everything between `<!-- dkj-policy:update-section -->` and
  `<!-- /dkj-policy:update-section -->` -- is the *plugin's* writing rather than yours, and `-Apply`
  replaces it with the current version. It holds what this workflow is, where the three portable pages
  live, how to update the plugins, and how to ask which version you are on. Nothing outside those two
  markers is read, compared or written, in that file or any other.

  **Why it is rewritten where nothing else is.** The block used to be appended once and then left
  forever, which closed *"a section added later never arrives"* and left *"a section that arrived is
  never corrected"* wide open. Everything in it is generated -- so a consumer's page went on naming the
  branch document `development.md`, and went on listing two pre-rename plugin ids, a year after both
  changed, with nothing to tell the reader whose sentence had gone stale. A block the plugin writes is
  a block the plugin has to be able to correct.

  **Three ways out, and they are all yours.** Write above or below the block and your words are never
  touched. **Delete both markers** and the paragraphs become ordinary text in your file that no run
  writes again. Or edit inside it -- and know that the next `-Apply` replaces what you wrote there,
  which is the one place in this whole command where that is true.

  **A page from before the fence is left exactly as it is.** An opening marker with no closing one has
  no machine-readable end, so cutting to the end of the file would take your own writing with it. The
  run says the section predates the fence and names the edit that opts in; it never guesses.
- **The branch document comes from the shared formatter** -- the same one `new-branch` and the fold
  call -- so the scaffold cannot write a shape of its own.
- **Refused in a repo that publishes plugins** (`.claude-plugin/marketplace.json` present). The source
  repo of this workflow arranges that folder by hand, and its answer differs from what this command
  writes: it keeps no root `CONTRIBUTING.md` at all, holding that floor in its `CLAUDE.md` instead
  (Dave, August 27, 2026), while the page scaffolded here assumes you have one.
- **A leftover root `branch/` from before the move is yours to remove by hand** -- the scripts read
  only the new location, deliberately without a dual-read fallback.
- **The folder itself is permanent** (issue #885). No command in this plugin removes
  `dkj-policy/`, and no future teardown may -- uninstalling the plugin takes the plugin, not the
  record that belongs to your repo. `<branch>.md` is the one file inside it that does not share
  that lifetime: it exists only while a branch is open, which is a precision on the rule rather than an
  exception to it.

### The CI gate it places, and the one choice inside it

The branch entry is a convention this plugin ships every reader of, and until August 20, 2026 **nothing
enforced it**: `open-pr` refuses to push an unwritten entry and `ship-pr` refuses to merge on an
unresolved step, but both are *local*. A branch pushed by hand, or a PR opened in the GitHub UI, meets
neither. So both existing consumers wrote a CI gate from scratch against the same convention -- a second
definition of the format in every repo, free to drift from the fold that reads the first one, and **both
had already drifted**: each refuses a merge over a missing significance score, which is a refusal this
workflow deliberately places at the *release cut* instead.

So the gate ships as a script, `check-branch-entry.ps1`, and this part places the six lines that call
it. It adds no rule of its own -- it calls the same functions `open-pr` calls -- and it reports the
significance rather than refusing on it.

**Which branches owe nothing** is a seam: `Get-EntryGateExemptPrefixes` in your `scripts/repo-config.ps1`,
defaulting to `sync`. A mirror branch carries somebody else's work rather than your repo's, so it has
nothing to declare -- both consumers reached that answer independently, with nothing recording that it was
the expected one. An **unknown** prefix is deliberately *not* exempt: a typo would otherwise skip the gate
in silence.

**The workflow pins `ref: main` rather than a tag, and that is the one choice worth arguing.** A pinned
gate keeps enforcing the shape it was pinned at -- and the entry's own path has moved twice, so a stale
pin does not fail loudly, it fails the *wrong way*: refusing branches that do carry an entry at the
current path. Tracking the tip means the gate follows the convention it enforces. Pin a tag instead if you
would rather own the bump.

**That argument was only ever half of the trade**
([#1805](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1805)). It weighs the **entry's**
path moving, correctly. What it never weighed is the **script's** own path moving -- and that is what
actually happened: `plugins/workflows/contributing-davekjohn/` became `plugins/dkj-policy/` on
September 5, 2026, and every repo scaffolded before that went on naming the old one. Tracking the tip
protects you from a stale convention and exposes you to a moved script, and only the first half was on
this page. Measured September 10, 2026: two consumer repos were red on **every** pull request, and
neither had been noticed, because neither had opened one since the break.

**The pin still stands, because the exposure is now covered at the other end.** The source repo's
`check-connectors.ps1` reads the runners its registered consumers actually have and reports a path that
tree no longer holds, naming where the script went; and its scaffolder suites derive the emitted path
from the emitted file and assert it exists, so a move goes red on the day it lands. Neither could be
built into this scaffolder: it writes your workflow once, at adoption, and nothing rewrites it
afterwards -- **a repair that must reach an already-adopted repo cannot live in the thing that is
written once.** What that leaves you is one thing worth knowing rather than an action: if this repo is
not in that register, nobody upstream can see your runner, and a tag you own the bump on is the
trade-off that puts the timing back in your hands.

**Making the check *required* is yours.** The file makes it run and report; whether a red gate blocks a
merge is a branch-protection setting, which is a repo decision rather than something a scaffolder should
reach into.

### After the scaffold: the note-root seam, which this run usually answers for you

The release machinery finds the folder through a `decide` seam in your `scripts/repo-config.ps1`
(Part 2 below explains the marker):

```powershell
Get-ReleaseNoteRoot     -> 'dkj-policy/releases/audience'
```

**Since [#1150](https://github.com/DaveKJohn/claude-code-specialists/issues/1150) the run writes that
line itself where it safely can, instead of printing it as an instruction** -- and only where all three
of these hold: your `scripts/repo-config.ps1` exists, it defines no answer of its own, and you have no
hand-written note at the shared `releases/notes` fallback. That is the fresh adoption and nothing else.
Whatever the run decides, it says which branch it took and why, so a seam left unanswered is never
silent.

**Why it is written rather than suggested.** The seam's default deliberately does not move with this
folder -- *a repo that answers nothing must keep meaning what it meant yesterday* -- and that argument is
about a consumer with notes **already on disk**. It does not reach a repo this command scaffolded a
minute ago. Measured in a fresh consumer following the documented path literally: one clean adoption plus
one clean release produced an empty committed `releases/audience/` and a release note at
`releases/notes/0.x/0.1.0.md`, outside the folder the adoption had just built, with the history table
linking back out of the folder to reach it. Every individual step behaved as documented; the two halves
of one run simply disagreed.

**Nothing is ever moved, and your own answer always wins.** A repo with notes at the fallback keeps them
and is told what repointing would cost -- the cut reports *"no release note was found"* against an empty
new root, which reads as a repo that has never cut one. A repo that already defines the function is left
exactly as it is, the same rule Part 2 follows.

**This is the one `decide` seam any command in this workflow answers for you**, and the narrowness is
the whole argument: Part 2 never places a `decide` record, because copying the source's answer
would assert something about a repo it merely *found*. This part **creates** the folder, so for a repo
with no answer and no notes it is not describing a tree -- it is making one.

**`Get-ReleaseHistoryPath` is isolated by default now too** (issue #885, group E, reversing the
August 19, 2026 answer below). That answer kept the list at the repo root on a durability argument:
a repo that has cut releases has a **history** whichever tooling cut it, so it should not live in a
folder a teardown could remove. #885 also settled that `dkj-policy/` is **permanent** -- see
[the rules above](#the-rules-it-works-under) -- which answers that same durability worry the other way:
the folder is now the safer place for the list, not the riskier one. So a fresh consumer gets
`dkj-policy/releases/history.md` without configuring anything, the same computed-default
treatment `Get-ChangelogPath` already gets. **A repo that adopted before August 25, 2026 keeps its
existing list at the root**: the computed default only isolates a *consumer*, and re-adopting an
existing one starts a *second* list here rather than moving the first one under it silently -- repoint
the seam back to your root file if you would rather keep one list. `Get-ReleaseNoteRoot` is isolated a
**different** way, for the separate reason its own contract record gives: it already has real consumers
relying on its literal fallback, which the three roots and the history path never had. So its *default*
still stays where it is, and the isolation happens by this run writing the answer into your lib -- an
explicit line in a file you own, rather than a default moving under an existing consumer's feet.

**So the page this part scaffolds at `dkj-policy/releases/README.md` carries no history
table**, and until August 20, 2026 it did -- a `## Release history` heading, a table, and a `VUL-IN`
promising that the cut would insert its rows there, in the same run whose closing advice told you to
leave the seam pointing at the repo root. Two statements that cannot both be true, and a consumer who
followed the advice was left with a table that stays empty forever (inbound
[#786](https://github.com/DaveKJohn/claude-code-specialists/issues/786)). The page now points at
whatever `Get-ReleaseHistoryPath` answers instead.

**The file that seam names is yours to create, before your first cut**, and this part deliberately
does not scaffold it:

```markdown
#### 1.x

| Version | Date | Type | Title |
|---|---|---|---|
```

Two reasons, and the first is the one that matters. A file that exists with a table but **no
`<major>.x` heading reads as done** to `cut-release`: the row lands in it, while the guardrail that
refuses to file a `v2` row under a `1.x` heading is silently off, because that check skips when it finds
no section. That is the same "hole with a comment on it" that keeps `adopt-shopify-floor` from writing a
`VUL-IN` stub. And the major in that heading is a version decision no scaffolder can make for you.

**Forgetting it is not silent, which is why an instruction is enough here.** With the file missing the
cut warns `<path> is missing -- row not added: <the row>` and cuts the release anyway, so the cost is
one row added by hand rather than a broken release.

The generated `releases/changelog/` and `releases/github/` trees belong in this folder too, beside
`releases/audience/` — nothing writes them but a cut, so they exist only because this workflow does
(#914, August 26, 2026). They are where the two root seams point by default, so a repo that answers
nothing gets them there; a repo whose notes already sit elsewhere repoints the seam at the tree it has.

And if your `Get-MojibakePaths` copy predates August 14, 2026, re-adopt it via Part 2: the old
copy still names the retired root `branch/` location, so the moved files sit outside its coverage --
nothing errors, the coverage is simply gone until the copy is refreshed.

## Part 2 -- the config seams

The shared workflow scripts (`open-pr`, `ship-pr`, `cut-release`, `new-branch`, ...) are repo-agnostic
and dot-source two **repo-owned** libs from your repo:

```text
scripts/repo-config.ps1        20 functions -- what this repo is and how it releases
scripts/lib/branch-info.ps1     2 functions -- the branch prefix table and its validator
```

`check-script-contract.ps1` already tells you which of those are missing and what the shared script
falls back to. What it cannot tell you is **what the source repo chose, and why** -- so every consumer
has been re-deriving those answers by hand, or not at all.

This part closes that gap. It reads the blueprint the plugin ships
(`blueprint/config-blueprint.json`), compares it against what your repo actually defines, and acts on
the marker each record carries.

### Run it

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-config.ps1"
```

That is a **dry run**: it prints exactly what it would do and writes nothing. Add `-Apply` when the plan
looks right.

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line. That
cache holds the last *released* mirror, which matters in the repo the scripts are **maintained** in: the
mirror lags its own source there by however many merges have landed since, so a maintainer runs the copy
under `scripts/`. The `adopt-config.ps1` command above is the one exception, since there is nothing for
the source repo to adopt from itself.

### The two markers, and why one of them never writes anything

| marker | what the value states | what happens |
|---|---|---|
| `copy` | the shared **way of working** -- it asserts nothing about your repo | the source's own function text, comments included, is written into the right lib |
| `decide` | **what a repo is** -- copying it would claim something about yours that may be false | it goes into a proposal document for a person to answer |

**A `decide` record is never written as a stub, and that is a mechanism rather than a preference.** A
stub returning a placeholder is *worse* than an absent function: absent means the shared script uses its
documented fallback, and for `Get-ReleasePluginTier` that fallback is computed from your tree and is
usually right. A stub returning `VUL-IN` would override a correct computation with a value nothing
checks.

**Nothing is ever overwritten.** A function you already define is left exactly as it is, whatever the
blueprint says. That makes the command safe to re-run -- a second run finds nothing to place.

**It is not a bootstrap.** If a seam lib is missing altogether, the command stops and points you at the
`specialists-init` skill: that skill owns whether the file exists, this one owns what is in it.

### Parameters

| parameter | what it does |
|---|---|
| `-Apply` | Actually write. Without it the command is a dry run that touches nothing -- the default, because the first run of a command that edits your config should show you the edit first. |
| `-ProposalPath` | Where the proposal document for the `decide` records is written, repo-root-relative. Default: `config-adoption-proposal.md` in the repo root. |

### What you get

- the `copy` functions appended to your seam libs under a header naming where they came from -- they
  are your files now, edit them freely;
- `config-adoption-proposal.md`, one section per decision, each with **why it is yours to answer**, what
  the function must return, what happens if you leave it out, and the source's own version quoted for
  reference. Delete the file once you have worked through it; re-running regenerates it.

Leaving a proposed value unanswered is a valid outcome. Every record in that document is optional or
has a documented fallback -- answer the ones where your repo genuinely differs from the source.

### Afterwards

Run the contract check to see the same seam from the shared scripts' side:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/sync/check-script-contract.ps1"
```

**In the source repo, run its own copy instead -- `scripts/sync/check-script-contract.ps1`.** That one is
a gate there rather than a one-off, and reading the seam through a lagging mirror is exactly the reading
it exists to prevent.

---

## Part 3 -- the CI floor

**Every pull request is certified by CI against the base it was branched from, and your trunk moves
after that.** The certificate then describes a merge that is no longer the merge about to happen. That
race is real in every repo, and this part is how you stand against it.

**Detect-and-rebase is this workflow's answer** (Dave, September 7, 2026,
[#1546](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1546)). `ship-pr` dates the run
behind your **required** check, counts what the trunk gained after it, and **refuses the merge** when
that is not zero -- naming the commits and the commands that bring the branch forward, the first of them
a `git checkout` back onto the branch, because this run returned your tree to the trunk the moment the PR
opened and the gate fires a whole CI wait later. It converges by repetition rather than by construction,
and it runs anywhere.

**So the one thing to close here is a required status check.** With none named, `ship-pr` prints *"no
required check name is known -- not checked"* and the staleness guard is simply **off**. Making one CI
check required on your trunk is what turns it on.

> **It cannot be the `branch-entry` gate Part 1 placed**
> ([#1538](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1538)). That gate reads
> `github.head_ref`, which is empty outside a pull request, so it stays a pull-request check. Use your
> own CI workflow. The source repo requires `lint-en-tests` -- its own, triggering on both
> `pull_request` and `merge_group` -- and deliberately does not require `branch-entry`.

### A merge queue is optional, and is no longer the policy

A queue removes the race by *construction* rather than by repetition, which is genuinely stronger. **It
was this workflow's policy from September 6 to September 7, 2026 (issue #1516), and it is not any
more**, because most repos running this workflow are not allowed to have one:

> GitHub's own GA terms -- merge queue is available on private repos **only on Enterprise Cloud**, and
> otherwise only on **public** repos owned by organizations. On Free, Pro or Team the *Require merge
> queue* rule is **not offered at all**: GitHub hides the checkbox rather than disabling it.

**The policy was set in the one repo where that cannot be felt.** This workflow's source repo is public
on plan `free`, so it qualifies through the public clause while every private consumer does not --
measured September 7, 2026 in `BWJ-Development/smartwatchbanden` (private, plan `team`), which built the
entire floor before the missing checkbox surfaced
([#1540](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1540)). A prescription its
reader cannot follow is worse than none: it turns a correct state into an open `[gap]` and sends
somebody hunting for a control that is not rendered. **So this command no longer reports a missing queue
as a gap.**

Everything short of a queue *within GitHub's own settings* was measured and rejected in the source repo:
`strict_required_status_checks_policy`, `allow_auto_merge` and `allow_update_branch` were switched on and
reverted the same day, because **GitHub performs no server-side base-sync of a PR branch outside a
queue.** That is why the answer is a refusal in `ship-pr` rather than a setting.

### The two runners are every repo's, queue or no queue

**What breaks the fold is a merge your shipping session does not observe** -- and the GitHub UI merge
button produces one in every repo. A queue only makes it the normal case:

| what an unobserved merge takes | what happens if nothing replaces it | who replaces it |
|---|---|---|
| **the fold** -- it ran as `ship-pr`'s step right after its own merge returned | the branch document sits on your trunk unfolded; the changelog never gets the entry; a release cut in that window misses the change | `.github/workflows/fold-on-merge.yml`, **placed by this command** |
| **the resolves verification** -- `ship-pr`'s step 6 | the issues still close (GitHub honours the keywords), but nothing verifies it and nothing repairs a body that carried a plain mention | `.github/workflows/verify-resolved.yml`, **placed by this command** |
| **the merge itself** -- under a queue `gh pr merge` *enqueues* and exits 0 | -- | `ship-pr` already handles this; it travels with the plugin |

**And one prerequisite belongs to a queue alone**: every workflow carrying a **required** check must
trigger on `merge_group`. Without it that check never runs for a queue entry, never reports, and **every
merge fails** -- a total merge outage, not a degradation, invisible until the first merge afterwards. In
a repo with no queue it is inert, so leaving it out costs nothing. This command reports it and cannot
place it: the workflow carrying your required check is yours, and adding a trigger to it is an edit to
your file rather than an addition beside it.

**Do not run the two instructions together without reading which is which.** Making a check required is
every repo's business and turns detect-and-rebase on. Adding `merge_group` to it is a queue repo's
business and does nothing anywhere else.

### Run it

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-ci-floor.ps1"
```

A **dry run**: it reads your trunk's rules, reads your workflow files, prints where you stand, and writes
nothing. Add `-Apply` when the list looks right.

**It was `adopt-merge-queue.ps1` until September 13, 2026**
([#1903](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1903)). The old path is **gone
rather than forwarded**: a note or a wrapper still naming it fails loudly on the next plugin update,
which is the cheaper outcome than a second name for one script. The rename is the last step of a
retirement that had already happened twice underneath it -- the queue stopped being the policy on
September 7 ([#1546](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1546)) and came off
the source's own ruleset on September 9
([#1720](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1720)) -- and this part has been
called *the CI floor* since before it.

**In the source repo there is nothing to run.** It arranges its own runners by hand -- they are the
originals these are derived from, they call its in-repo scripts rather than a checked-out mirror, and its
fold runner carries a push-credential decision no scaffold should make for somebody else. The command
refuses there, the same way Part 1's does and for the same reason.

### Parameters

| parameter | what it does |
|---|---|
| `-Apply` | write the two runners this repo does not have. Without it the command is a dry run that prints the plan and touches nothing -- the same default Parts 1 and 2 use. |

### What it will not do, and why

**It never switches the queue on.** It composes the change and stops. A ruleset changes what every
contributor's merge does, immediately, for everybody -- that is the repo owner's act, not a script's, and
reading a ruleset needs only a token that can read while writing one needs a token that can administer
the repo. A command that quietly held the second would be a different kind of tool.

### The secret you have to create yourself

**`FOLD_PUSH_TOKEN`, and the fold runner does not work without it.** A `merge_queue` rule blocks every
direct push to the trunk unless the pushing actor is a listed bypass actor, and the default
`GITHUB_TOKEN` pushes as the GitHub Actions app -- which **cannot** be added to that list: an Integration
bypass actor has to be an app installed on the org, and that one is not administered by yours (measured
in the source repo, September 6, 2026: `422 -- Actor GitHub Actions integration must be part of the
ruleset source or owner organization`).

So the fold job checks out with a fine-grained personal access token belonging to somebody who **already**
bypasses the ruleset, scoped to that repository only and to `Contents: Read and write` only, stored as the
repository secret `FOLD_PUSH_TOKEN`. Two things follow that are worth knowing before you create it:

- it is a **standing** credential -- usable from anywhere until it expires, unlike the hour-lived
  job-scoped token it replaces -- and `actions/checkout` writes it into the workspace git config, so
  **every step of that job holds it**. That is why the resolves check is a separate workflow rather than
  a step in the same job: it needs `issues: write`, and the two never meet;
- it **expires**, and when it does the job starts failing its push with no code-level cause. Rotate it
  before then.

An absent or under-scoped `FOLD_PUSH_TOKEN` fails `actions/checkout` -- the job never reaches the fold,
and every later step shows `skipped`. So create it **before** you merge the floor, not after. (A
fine-grained PAT lists repositories one by one, so a repo **created** rather than transferred -- which is
what an org move without a GitHub transfer produces -- silently falls outside an existing token's
selection.)

A red run of that job has **three** entirely different causes, and only the log tells them apart:

1. the **checkout** failing on the token -- rule this out first, it is the only one that leaves every
   later step `skipped` and the fold step with no last lines at all;
2. the fold **refusing** -- it ran and declined; its own last lines say why;
3. the fold **succeeding** and its push being rejected **by the ruleset** -- a clean fold above a `GH013`.
   Read the rejection rather than the exit code: a push refused as a **non-fast-forward** wears this
   cause's clothes and is not it -- that one is the race below. `GH013` names a rule and a ruleset; a
   non-fast-forward names a ref and tells you to fetch first.

**Read the fold step's own last lines before concluding anything** -- once there is a fold step to read.

**Two refusals are deliberately not on that list, because neither turns the job red any more.** They are
the two halves of one race -- another fold reaching your trunk while this job is folding the same entry --
and they are separate codes because what has been *written* by the time each fires is different:

- **exit `2`, the wide half** (inbound #1586). The other fold landed **before** the job's pre-pass read
  the trunk, so the fold's trunk-freshness guard refuses having written nothing at all. It is lossless
  because that guard fires in a pre-pass, before a single entry is folded, and because the push that moved
  your trunk queues its own run of the same job behind this one.
- **exit `3`, the narrow half** (inbound #1796). The other fold landed in the window **between** that
  pre-pass and this job's own push, which no check at the top of a run can close. Entries were folded, a
  commit was made, and the push came back a non-fast-forward. The fold earns this code by **measuring**
  that every entry it carried is already upstream with an identical body -- so your trunk holds exactly
  what the job exists to put there. The redundant commit is local to the runner's ephemeral workspace and
  dies with it, which is why the placed runner may stand down here while a session folding onto a real
  trunk may not.

A `Stood down:` line in the log is the job working, not a fold that went missing -- and every **other**
non-zero code still fails, including a non-fast-forward the fold could **not** prove redundant (one entry
upstream, another genuinely new), because that commit carries work your trunk does not have.

### Exit code

`0` while the queue is off and the floor is merely unbuilt -- that is a to-do, not a defect, and your
merges are fine today. `1` when a queue is **active** on your trunk and a piece of the floor is missing,
because that is a live defect: entries are being stranded, or merges are about to stop.

### Afterwards

`ship-pr` tells you the same thing from the other side. Under a queue with no fold runner in your tree, its
closing lines say so and print the fold command, instead of promising a fold that is not coming.

---

## Part 4 -- the reach label on your tracker

[`CONTRIBUTING-portable.md`](../../CONTRIBUTING-portable.md) prescribes exactly one issue label, and this
is the step that puts it on your tracker. It is a person's `gh` call rather than a script, for the same
reason the rest of your labels are: a tracker's settings are not a file this plugin writes.

**Why one label and no others.** The reach label is not a convention of its own -- it is
[the tier model](../../RELEASES-portable.md#the-same-scale-on-an-issue--the-reach-label) read on an issue
instead of on a changelog entry, and your repo already answers that scale on every entry it writes. An
issue whose landing will be written at tier 1 or 2 carries the label; one that will be written at tier 0
does not, and that absence is the answer rather than a missing field.

**Read `Get-ReachLabel` from `scripts/repo-config.ps1` first** and check for *that* name -- `minor` where
the repo has never answered it, which is most repos:

```bash
gh label list --repo <owner>/<repo> | grep -E '^<reach label>\b'
gh label create "<reach label>" --repo <owner>/<repo> --color fbca04 \
  --description "<see the two wordings below>"
```

**The description follows your `Get-ReleaseAudienceTier`, because the label names one audience and you
have exactly one.** Tier 1 and tier 2 are two kinds of audience rather than two rungs, so a repo copying
the other one's wording describes a reader it does not have:

| your audience tier | the description to use |
|---|---|
| **1** (management, the employer or commissioner) | `Reaches the business: management and the commissioner notice it. Sits on top of tier 0.` |
| **2** (subscribers of a service) | `Reaches beyond tier 0: subscribers of this service notice it. Sits on top of tier 0.` |

GitHub caps a label description at **100 characters**, so keep any wording of your own inside that --
`gh label create` refuses the whole call with `HTTP 422` over it, and the message names the length rather
than the label.

**A missing reach label is two different situations, and this step must not assume the harmless one.**
It can be missing because the repo never had it -- create it. It can also be missing because the repo
**renamed** it and has not answered the seam, and creating it then leaves two labels for one axis, one of
them empty, with every existing issue on the other. Nothing reports that, because the run is doing exactly
what it was written to do. So **before creating it, read the whole label list** (`gh label list --repo
<owner>/<repo>`) and look for the axis under another name: a label that carries issues and describes reach.
Where you find one, the answer is `Get-ReachLabel`, not a second label.

**A repo that already runs this axis under an older name needs no rename.** The name `tier-1` was this
workflow's default until September 11, 2026 ([#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870));
a repo still carrying it either renames the label on the tracker -- GitHub keeps it on every issue that
has it -- or answers `Get-ReachLabel` with `tier-1` and changes nothing. Both are correct, and the second
costs one function. Do not leave it at neither: the default is read at the moment of a filing, so a repo
whose label and seam disagree gets an `HTTP 422` from `gh issue create` instead of an issue.

### Afterwards

Nothing else reads this label -- no gate refuses on it and no script writes it. What it buys is the
worklist: `is:open label:<reach label>` is every open issue whose landing will be visible past this
repo's own developers.
