---
name: adopt-dkj-policy
description: Adopt the dkj-policy workflow in a consuming repo, in five independent parts that can run in any order or alone. Part 1 scaffolds the workflow's own root folder -- dkj-policy/ -- the releases root with this repo's release answers, the branch-entry CI gate, the always-on budget CI gate that holds every PR to not growing what every session pays before a single assignment is given, and the PR template open-pr fills in; use this right after installing the plugin, or when the script-contract session check reports the folder missing, since an install alone writes nothing into the repo. Part 2 adopts the source repo's workflow configuration from the shipped blueprint -- placing the values that state the shared way of working into this repo's own seam libs, and proposing the rest for a person to answer; use this after specialists-init has laid down scripts/repo-config.ps1 and scripts/lib/branch-info.ps1, or whenever the script-contract check reports functions this repo has never configured. Part 3 builds the CI floor -- it places the runners that keep the fold and the resolves verification alive across a merge the shipping session never observes (a merge queue, or the GitHub UI merge button), places a scheduled runner that checks whether a GitHub-side repo setting still matches what this repo declares, and reports whether a required status check exists at all, which is the certificate ship-pr dates its staleness guard from; use it after installing the plugin, when ship-pr says the staleness guard is off because no required check is known, when a merge landed and nothing folded, or when a repo setting may have drifted. A merge queue is optional and is not this workflow policy: most repos cannot have one, so a missing queue is reported as the ordinary state rather than as a gap. Part 4 puts the one issue label this workflow prescribes on the tracker -- the reach label, minor by default, which is the tier model read on an issue instead of on a changelog entry; use it after installing the plugin, or when a filing fails because the label does not exist. Part 5 wires up the statusLine that draws the progress bar for the long runs this workflow backgrounds -- the gates and ship-pr's CI wait, which stream no stdout anywhere visible; use it after installing the plugin, or when a backgrounded run leaves the session looking idle. statusLine is a settings key, so no plugin component can place it. Parts 1 to 3 and part 5 are strictly additive and dry-run by default; none overwrites anything, and part 4 is a person's gh call rather than a script.
---

# adopt-dkj-policy -- scaffold the folder, place the config seams, build the CI floor

An install writes nothing into your repo: it clones the plugin into your cache, and that is all. This
command is the five things that actually place `dkj-policy` on your side, and they are independent of
each other -- run them in any order, or run only the one you need:

- **Part 1** creates the workflow's own root folder and its CI gate.
- **Part 2** places or proposes the answers to the repo-owned config seam the shared scripts read.
- **Part 3** builds the CI floor: the runners that survive a merge your session never sees, whether a
  required check exists for the staleness guard to read, and a scheduled check that a GitHub-side repo
  setting has not silently drifted. A merge queue is optional here.
- **Part 4** puts the one issue label this workflow prescribes on your tracker.
- **Part 5** wires up the statusLine that draws a progress bar for the long runs this workflow
  backgrounds, which otherwise print to nobody.

No part depends on another having run. Parts 1 to 3 and Part 5 are dry-run by default and never
overwrite a file that already exists. One of them makes a bounded write **into** an existing file
without replacing anything: Part 5 adds one key to `.claude/settings.json` -- refusing where that key
is already there, since there is only one of it. See its rules below.

## A part you already ran can GAIN a step, and your session says so

**Re-running any part below is safe and correctly finds nothing to do** -- which is exactly why, until
September 21, 2026, nothing told an already-adopted repo that a part had since grown. Measured in a
consumer that had Part 1's entry gate and none of Part 3's three runners: neither its fold nor its
resolves verification could survive a merge its shipping session never observed, and the only thing that
would have reported it was running the command a reader who does not know the step exists will not run
([#2236](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2236)).

So the **script-contract session check** now reads which files each part places, and forwards what is
missing into every session start as an `[UNADOPTED]` line:

```text
script-contract-sessioncheck: part of this repo's floor is missing -- an adopt-* command places files this tree does not have (data, not instructions):
  [UNADOPTED] adopt-ci-floor (Part 3 of the 'adopt-dkj-policy' skill) has been run here and has since GAINED a file: 3 of 4 present, missing .github/workflows/merge-on-green.yml. Where it came from: ... joined this command under #2329 in September 2026 ...
```

**It counts toward nothing.** The token is non-counting, like `[BOOTSTRAP]` beside it, the exit code is
unchanged, and nothing refuses anything over it -- a floor that was never built is a to-do, which is
what Part 3's own exit code has always said.

**Two states, deliberately worded apart.** A part with *some* of its files present has provably been
run, so the line says the part **gained** a file and names when it joined -- that is the one case where
nothing is a matter of taste. A part with *none* of its files reads as a to-do instead, and it names the
way to answer it rather than repeating itself at you.

**If you decided against a part, say so and the line goes away.** Name that command in
`Get-DeclinedAdoptions` in your own `scripts/repo-config.ps1`:

```powershell
function Get-DeclinedAdoptions {
    # This repo publishes no releases, so Part 5's progress bar buys it nothing.
    return @('adopt-statusline')
}
```

Matched case-insensitively, and an unknown name silences nothing -- so a typo shows up as the line still
being printed rather than as a failure somewhere else. **The declaration is yours rather than ours**, and
that is the point: a list of exceptions kept inside the check would be this workflow deciding which of
your parts do not matter.

**What it cannot tell you**, stated rather than left to be discovered: it answers on **presence**, so a
runner that is there and stale, or edited into something else, reads as present. Part 3's own run is what
compares content. And it says nothing at all in a repo with no workflow folder -- there the folder finding
is the accurate sentence and three more would bury it -- nor in the repo that publishes this workflow,
where all three file-placing parts refuse by design.

## Part 1 -- scaffold the workflow folder

Everything portable about the `dkj-policy` workflow gathers in **one folder in your repo's
root** (Dave, August 14, 2026), instead of scattering through it -- `branch/` from the first
`new-branch` run here, a `releases/` tree from the first cut there, a `CONTRIBUTING.md` if somebody
wrote one. A plugin **install cannot create the folder**: an install is a clone into the plugin cache
and writes nothing into your repo. This part is what places it, and the script-contract session
check reports at session start while it is missing.

```text
dkj-policy/
  CHANGELOG.md           this folder's own pending-changes list, isolated from any changelog you
                         already keep at your repo root
  (releases/audience/ is NOT placed -- your first cut creates it when it writes the note there)
  (<branch>.md is NOT placed -- one per branch, living only while that branch is open)
  (README.md, CONTRIBUTING.md and releases/README.md are NOT placed any more -- #2171 and #2196,
   September 20, 2026. An existing copy is reported as legacy further down and never touched;
   see the rules below. ONE file is placed, and it is the one above.)
```

**And three files outside it**, since August 20, 2026 (inbound
[#789](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/789)), September 11, 2026
([#1843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1843)) and September 16, 2026
([#2037](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2037)):

```text
.github/workflows/branch-entry.yml      the CI gate that holds every PR to carrying a written entry
.github/workflows/always-on-budget.yml  the CI gate that holds every PR to not growing the always-on
                                        document path -- CLAUDE.md plus everything it @-imports
.github/pull_request_template.md        the PR body open-pr fills in, copied from the plugin's reference
```

**Why the budget runner is here and not in Part 3.** Both of the first two fire on `pull_request` and
gate what is about to land; Part 3's runners repair what a merge nobody watched left behind, on `push`,
after CI, or on a schedule. The trigger is the difference. The gate itself also runs locally in `open-pr`, so this
runner is the half that catches a branch pushed by hand or a PR opened in the GitHub UI -- exactly the
hole `branch-entry.yml` exists for, on the one thing in your repo whose cost is paid by every future
session rather than by whoever merged.

The last is a **copy** where the first two are calls, and it has to be: GitHub reads a PR template only
from that path in your own repo, so it is the one file in this cycle that cannot be imported. It used to
be the one file you copied by hand -- and the cost of forgetting was invisible, because `open-pr` builds
its body only when that path exists and says nothing when it does not. **A repo without it got PRs with
no body at all.** Like everything else here it is never overwritten, so a template you already have --
your checkboxes, your sections, even an older placeholder the matcher still recognises on purpose --
is left exactly as it is.

### Run it

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-workflow-folder.ps1"
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

- **Strictly additive, never overwrites, and now without qualification.** Every file that already
  exists is left exactly as it is, whatever it contains -- so a re-run finds nothing to do, and
  everything you wrote past the `VUL-IN` markers is yours. **No FILE is ever rewritten**, which is new
  since August 23, 2026: `new-branch` used to refresh the generated `branch/templates/` on drift, and
  the merged development document carries its own guidance, so there is no reference beside it left to
  keep current.
- **One exception stood between then and #2171 (Dave, September 20, 2026), and it is gone with the
  page it was written into.** Issue #1766 gave the folder README a fenced region --
  `<!-- dkj-policy:update-section -->` to `<!-- /dkj-policy:update-section -->` -- that `-Apply`
  rewrote on every run, because a page the plugin owns has to be a page the plugin can correct: it
  named what this workflow is, where the portable pages live, how to update the plugins, and how to ask
  which version you are on, and a block appended once and never corrected had already gone stale in the
  field, naming a retired branch-document filename and two pre-rename plugin ids. **This command no
  longer scaffolds the folder's `README.md` or `CONTRIBUTING.md` at all**, so there is nothing left for
  it to own a region of, and "nothing that already exists is ever touched" is true without
  qualification now.

  **There is one `CONTRIBUTING` for a consumer to read, and it is the plugin's own
  `CONTRIBUTING-portable.md`.** Two pages in your own tree only made a repo more complicated and
  produced more inconsistency than they removed; what your repo answers for itself goes into your
  specialist lens instead, beside the rest of what that lens already carries.

  **An existing copy is reported as legacy and never touched -- no delete command is printed.** A copy
  already on your disk may carry the only written statement of something your repo answered, and
  nothing here can tell that from a stale scaffold; pushing you toward deleting it for the sake of
  tidiness is not this command's business. The report names the file and says this run no longer writes
  or refreshes it -- read it from here on as your own writing, not as something the plugin keeps
  current.

  **The gates that read either page are deliberately unchanged.** `check-consumer-prose.ps1` still
  greps both names and `check-policy-drift.ps1` still lists a surviving copy at its own rank 2, so a
  page that is still there keeps exactly the standing its repo gives it. What stopped is the
  *authoring*, not the *reading* -- narrowing either gate to match this change would retire it in every
  repo whose page is the reason it exists.
- **The branch document comes from the shared formatter** -- the same one `new-branch` and the fold
  call -- so the scaffold cannot write a shape of its own.
- **Refused in a repo that publishes plugins** (`.claude-plugin/marketplace.json` present). The source
  repo of this workflow arranges that folder by hand -- it is the product's home, not a consumer -- so
  this command refuses there rather than writing a layout over one its owner composed deliberately.
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

### And one line in your `CLAUDE.md`: the constitution (#2374)

**The rules this repo runs under ship with the plugin, in [`../../CLAUDE.md`](../../CLAUDE.md).** Your own
`CLAUDE.md` loads them with one absolute `@`-line, placed directly below its first heading:

```
@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md
```

Below that line, your `CLAUDE.md` holds **facts about this repo only**: its trunk, whether it is public,
who its owner is, and what it is for. **Remove any rule the constitution already states.** A copy of a
rule does not fail on the day it is written. It fails on the day the plugin's answer moves and the copy
stays behind, and that is the contradiction #2374 was filed about.

This run does not write the line, because it never edits a file that already exists. The
`consumer-prose-sessioncheck` hook raises a `[WARNING]` at every session start until the line is there,
and that warning prints the exact line for **your** marketplace name. A consumer registered before the
September 10, 2026 rename still has its clone under `claude-code-specialists`. The line resolves after a
`claude plugin marketplace update`: an `@`-import reads the marketplace clone, not the plugin cache.

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

**This part scaffolded a `dkj-policy/releases/README.md` until #2196 and no longer does**, so there is no
page here for a history table to be wrongly promised on. What that page went through is worth keeping,
because the failure is one any repo-local copy of a portable page can repeat: until August 20, 2026 it
carried a `## Release history` heading, a table, and a `VUL-IN` promising that the cut would insert its
rows there -- in the same run whose closing advice told you to leave the seam pointing at your repo root.
Two statements that cannot both be true, and a consumer who followed the advice was left with a table that
stays empty forever (inbound
[#786](https://github.com/DaveKJohn/claude-code-specialists/issues/786)). That was repaired by having the
page point at whatever `Get-ReleaseHistoryPath` answers; #2196 removed the page instead, which is the same
repair one level up.

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
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-config.ps1"
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
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/sync/check-script-contract.ps1"
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

### The fold and resolves runners are every repo's, queue or no queue

**What breaks the fold is a merge your shipping session does not observe** -- and the GitHub UI merge
button produces one in every repo. A queue only makes it the normal case:

| what an unobserved merge takes | what happens if nothing replaces it | who replaces it |
|---|---|---|
| **the fold** -- it ran as `ship-pr`'s step right after its own merge returned | the branch document sits on your trunk unfolded; the changelog never gets the entry; a release cut in that window misses the change | `.github/workflows/fold-on-merge.yml`, **placed by this command** |
| **the resolves verification** -- `ship-pr`'s step 6 | the issues still close (GitHub honours the keywords), but nothing verifies it and nothing repairs a body that carried a plain mention | `.github/workflows/verify-resolved.yml`, **placed by this command** |
| **the merge itself** -- under a queue `gh pr merge` *enqueues* and exits 0 | -- | `ship-pr` already handles this; it travels with the plugin |

**This command places a third file too, and it answers a different question entirely** -- see
[below](#a-third-runner-this-command-places-repo-settingsyml-issue-1843): `.github/workflows/repo-settings.yml`
checks a GitHub-side setting against your own declaration on a schedule, not on a merge, and needs
neither a queue nor an unobserved merge to matter. **And a fourth**,
[`merge-on-green.yml`](#a-fourth-runner-merge-on-greenyml-issue-2329), finishes a merge `ship-pr`
refused on CI once that check turns green.

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
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-ci-floor.ps1"
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
| `-Apply` | write the runners this repo does not have. Without it the command is a dry run that prints the plan and touches nothing -- the same default Parts 1 and 2 use. |

### What it will not do, and why

**It never switches the queue on, and the queue is the one arm that composes nothing at all.** Where no
required check is named, the command composes the exact `gh api` call that would create one and stops
there, because reading a ruleset needs only a token that can read while writing one needs a token that
can administer the repo, and a command that quietly held the second would be a different kind of tool.
The merge-queue switch gets no such call and stays a UI pointer instead: a `merge_queue` rule asserts
seven scheduling parameters -- merge method, grouping strategy, three limits, two timeouts -- that are
policy nobody here has chosen, on a control GitHub does not even render outside the plans that may have
one.

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

### A third runner this command places: repo-settings.yml (issue #1843)

**Not about an unobserved merge at all.** `.github/workflows/repo-settings.yml` is a **scheduled** leg
that asks whether a GitHub-side repo setting -- a bypass actor, `allow_auto_merge`, which check is
required -- still matches what your own `scripts/repo-config.ps1` declares
(`Get-ExpectedRepoSettings`). It rides along in this same command because this is already the one place
you build your CI floor, not because it needs a queue or a merge to matter: a ruleset drifts on its own,
with nothing in your tree saying so, exactly as the source repo measured three times in eight days
before it built the check this places (`check-repo-settings.ps1`).

**"The reachable goal is identical scripts available, not identical rules enforced"** (Dave, September 12,
2026, on #1843) is why the *values* stay yours to declare -- an empty or absent
`Get-ExpectedRepoSettings` is a harmless `[SKIP]`, never a refusal -- while the *script* that compares
them against GitHub is shared. Adopting it costs nothing you have not already paid: the values it reads
were behind a seam before this command existed.

It never needs `FOLD_PUSH_TOKEN` or any other secret -- it only reads, on `contents: read`, and passes
`-RequireRead` so a token that cannot read reports a failure instead of a green run that checked nothing.
A queue being active elsewhere in your repo does not make a missing `repo-settings.yml` a live defect:
its exit code and its `[create]`/`[MISSING]` marker are independent of Part 3's queue-floor verdict.

### A fourth runner: merge-on-green.yml (issue #2329)

**It closes a promise `ship-pr` already makes in your repo.** When `ship-pr` refuses to merge on a red or
pending required check, it labels the pull request `merge-when-green` and says a sweep will finish the
merge once the check turns green. `.github/workflows/merge-on-green.yml` is that sweep. Without it the
label is set and nothing reads it, so the merge stays owed to a session exactly as before.

It wakes on your CI completing (`workflow_run`, naming your own pull_request workflows by their
top-level `name:`), on a half-hourly schedule, and on `workflow_dispatch`. None of the three is trusted
to say *which* pull request is owed a merge: the plugin's `pick-merge-on-green.ps1` asks your tracker,
and the plugin's own `ship-pr.ps1` does the merge. So every gate a session's ship runs is the gate
this runner runs, and it folds and verifies the resolves too. Both scripts come out of a checkout of the
plugin tree and act on **your** workspace through `CLAUDE_PROJECT_DIR`. Where none of your
pull_request workflows declares a top-level `name:`, the `workflow_run` trigger is left out rather than
guessed, and the schedule wakes the sweep on its own.

**It uses the same `FOLD_PUSH_TOKEN`, with one more scope: `Pull requests: Read and write`.** A merge
made with the job-scoped `GITHUB_TOKEN` starts no workflow runs, so it would land the pull request and
silence your CI on the trunk and the fold and resolves runners, all at once. Without the scope the merge
fails with a 403, loudly, and nothing is merged. It is not queue machinery: under a queue `ship-pr`
enqueues instead of refusing, so nothing gets armed.

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

## Part 5 -- the progress bar's statusline

A run this session **backgrounds prints to nobody**. Measured and stated in Claude Code's own
documentation: a Bash call made with `run_in_background` streams no stdout to any visible surface,
in the terminal CLI and in the VS Code extension alike. Its output is retrievable afterwards, which
is a different thing from watching a run. So this workflow's long waits -- the lint gate, the test gate, and
`ship-pr` waiting on CI -- print a progress line for a reader who, in the one case they were written
for, is not there.

The **statusLine** is the one surface that keeps rendering while that is true. This part wires it up:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-statusline.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-statusline.ps1" -Apply
```

Dry run by default, like Parts 1 to 3: the first run prints exactly what it would place and touches
nothing.

### Why this is a command and not payload

`statusLine` is a **settings** key, so nothing a plugin ships can place it. That is the one claim this
part turns on, and it is verified against the plugin reference rather than assumed:

- `plugin.json` carries no `statusLine` key.
- A plugin-root `settings.json` supports only `agent` and `subagentStatusLine`.
- `${CLAUDE_PLUGIN_ROOT}` is **not** expanded in a statusLine command, and is not exported to it.

An install clones the plugin into your cache and writes nothing into your repo, so a command is the
only route there is.

### What it places, and why one of them is a shim

Two files:

| path | what it is |
|---|---|
| `.claude/statusline/dkj-progress.ps1` | a small shim that resolves the **currently installed** payload and hands over to it |
| `.claude/settings.json` | the `statusLine` key, pointing at that shim |

**The shim is the whole design decision, so it is worth one paragraph.** The obvious thing is to write
today's plugin-cache path straight into your settings. That fails in the worst available way: the cache
is keyed **by version**, so a machine holds `dkj-policy/5.0.0` through `5.5.0` side by side, and the next
`claude plugin update` leaves the old payload exactly where it was. Your statusline goes on rendering it
-- it keeps working, it renders stale code, and nothing reports it. Copying the two scripts into your
repo instead trades that for two live copies drifting at every release with no lint over them. The shim
is the third answer: one file that never changes, resolving the payload at render time, so the path in
your settings cannot go stale and the logic stays in the plugin where a release can reach it.

It reads `~/.claude/plugins/installed_plugins.json` itself rather than through the shared lib that
already does, because that lib lives in the payload the shim is looking for. It prefers a record naming
**this** repo, falls back to a pathless (user-scope) one, and never uses a record naming somebody else's
repo. Every failure path -- no administration, one it cannot parse, a payload that is gone -- prints
nothing and exits 0: a status line runs every couple of seconds for as long as a session is open, so a
failure there is not an error report, it is a broken status line repeated forever.

### An existing statusLine is never replaced

There is **one** `statusLine` key per settings file, so placing this one over yours would take your
status line away without asking. This part leaves it exactly as it is and prints the block for you to
place by hand -- the additive-and-never-overwrites rule the rest of this page follows. The shim is
placed either way, so wiring it up later is a settings edit and nothing else.

A settings file that does not **parse** is refused outright rather than repaired: the run exits 1, the
file is left byte for byte as it was, and the block is printed.

### Afterwards

With something running you get a bar; with nothing running, the directory, the branch and the model:

```
[#####-------] 37/84  test gate (12 running)  +6m12s
my-repo  feat/1234-something  Opus 5
```

Nothing else has to be switched on. The two producers publish from inside their own process, and they
are already in the payload you installed.

**If no bar ever appears**, run [`plugin-versions`](../plugin-versions/SKILL.md): a payload released
before this landed carries no `scripts/task/show-progress.ps1` at all, and the shim then prints
nothing, by design.

### What it costs, measured

A status line is a command Claude Code runs as a **fresh process** on every render, so at a 2-second
refresh this is about **0.3 s of CPU per tick, or roughly 9 minutes per hour of open session**,
measured on a Windows machine (September 18, 2026). Around 70-90% of that is the PowerShell process
spawn and its cold start; the shim's own work -- the `installed_plugins.json` read, the parse and the
record scan -- is **~1.4 ms**, under half a percent of the tick.

**Which is why the shim does not cache that read, and the numbers are here so nobody 'fixes' it.**
Caching would save one or two milliseconds out of three hundred, and it would buy that by holding on
to a resolved `installPath` -- which is precisely the stale, invisible, unreported state this whole
part is built to avoid. The cost is inherent to `statusLine` being a process per render rather than to
anything in this design, so the honest answer to finding it too expensive is to not run a status line,
not to make this one lie about which payload it is rendering.

**This part is refused in the repo that publishes this workflow.** That repo runs the statusline script
from its own tree by a repo-relative path, and a shim there would resolve an install record to find the
payload it is itself the source of.
