---
name: specialists-teardown
description: >-
  Remove what specialists-init put into a consuming repo, so the repo can stand free of the plugin:
  the generated lens scaffolds, the one @-import in CLAUDE.md plus the two inside the seam, the
  untouched script-config scaffolds and the settings proposal. Strictly subtractive and the mirror image of the bootstrap --
  it never deletes anything the repo owner filled in, and never edits settings.json. Dry run by
  default. Use this when a consumer is being disconnected from the plugin, or to verify that
  adoption is genuinely reversible before relying on it.
disable-model-invocation: true
---

# specialists-teardown -- give the repo back

The counterpart to [`specialists-init`](../specialists-init/SKILL.md). Adoption is reversible by
design (Dave's requirement, July 29, 2026): a consumer must be able to install **and uninstall** at
any moment, and afterwards carry no *live* reference to a specialist, manual, persona or roster --
nothing a session loads, a script resolves, or a gate depends on. Its own changelog history is
exempt, and stays as written.

**This skill is only the repo half of leaving, and the other half is not in this payload.** The machine
half -- the `claude plugin uninstall`/`marketplace remove` commands, the settings keys to take back out,
and the order the two halves have to run in -- is in the undo section of
[`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#undoing-it--the-half-that-is-yours). The pointer is here because it was
measured to be missing exactly here: a reader who wanted to leave found this skill without trouble and
reached the machine half **only by grepping blindly** (inbound
[#338](https://github.com/DaveKJohn/claude-code-specialists/issues/338)). Read that page before running this
one -- the order is not free, and it is the page that says why.

## Run it

**First establish that PowerShell exists on this machine.** This skill is a wrapper around a `.ps1`,
and there are environments where that command is not there at all -- a Linux cloud container, a
colleague's Mac, the Claude app with no repo connected. Ask once:

```powershell
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
```

If that answers `command not found` (exit 127), **say so and stop**. Nothing has been removed at that
point -- the script never started -- so the repo is exactly as it was; what is gone is the reversibility
this page promises, and a reader deserves to know that before they plan a disconnection around it.
`pwsh` is not a substitute to reach for: these scripts target Windows PowerShell 5.1, which is why this
repo's own CI runs them on `shell: powershell`. Measured in an environment with no repo at all, inbound
[#669](https://github.com/DaveKJohn/claude-code-specialists/issues/669) B2.

From the root of the consuming repo:

```powershell
# Preview -- nothing is removed
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/skills/specialists-teardown/teardown.ps1"

# Act
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/skills/specialists-teardown/teardown.ps1" -Apply

# Act, and keep a working git workflow afterwards (see the runtime dependency below)
powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/skills/specialists-teardown/teardown.ps1" -Apply -VendorScripts
```

**Dry run by default.** A destructive script that runs on somebody's repo should have to be asked
twice, and the preview doubles as the inventory a reader needs in order to say yes.

**The preview and the apply run report the same total** (inbound #275). They used to differ by two: the
directories the run cleans up (`lenses/`, then `dkj-subagents-alpha/`) were pruned, listed and tallied only under
`-Apply`, so the same work read as "29 item(s) to remove" and then "31 item(s) removed". A preview that
undercounts its own execution weakens exactly the property it exists to provide, so both modes now list
those directories under `[remove]`. On a dry run the emptiness is predicted -- a directory counts as empty
when every file still in it is already on the remove list -- which is the question `-Apply` answers by
looking, off one shared code path.

## What it classifies, and why that is the whole design

Consumer-side content is three things and only one is disposable. Deleting indiscriminately would
destroy governance and repo knowledge the owner authored -- a worse outcome than leaving clutter. So
the script classifies before it removes:

| category | what it is | what happens |
|---|---|---|
| **Generated and untouched** | a lens still carrying its `VUL-IN` marker, an unfilled script scaffold, the `@`-imports, both settings proposals (`settings.suggested.jsonc` and `settings.proposed.json`) | **removed** |
| **Authored by the owner** | a filled-in lens -- repo knowledge somebody wrote | **reported, never touched** |
| **Owned by the repo anyway** | a `repo-config.ps1` with real values, a filled branch table: this repo's own conventions | **reported as yours to keep or drop** |

The signals are the scaffold shapes **this plugin writes**: a `(VUL-IN)` slot heading for a lens, a
`VUL-IN` in an assignment's *value* for `repo-config.ps1`, an empty prefix table for `branch-info.ps1`.
Deliberately a content test rather than a timestamp or hash: a reformat or a merge does not make content
authored.

> **It only recognises its own conventions, and says so rather than guessing.** A round-trip in
> `davekokbwj/smartwatchbanden` (July 29, 2026) found 20 of its 22 lenses empty under **that repo's own**
> "clean slate" convention — a closing sentence, no `(VUL-IN)` heading anywhere. All 22 were kept, and the
> report claimed they were "filled in". Right answer, wrong reason, and adoption was less reversible than
> this skill implied. Two changes followed: the report no longer asserts authorship it cannot establish
> (it says the file is *not recognised as a scaffold*, which is all it knows), and a consumer can declare
> its own convention with **`-EmptyLensPattern <regex>`**, e.g.
> `-EmptyLensPattern 'Nothing recorded yet'`. Without it those lenses are kept — the safe direction,
> since a false keep leaves clutter while a false remove destroys someone's work.

## What it deliberately will not do

- **This script never edits `.claude/settings.json`.** Disabling or uninstalling the plugin is the
  owner's act, and the bootstrap never wrote that file either -- the symmetry that makes this safe to run
  cuts both ways. It is reported instead, with the note that the subagents and session hooks stay active
  until the entry is gone and the session restarted.

  > **The scripts keep that promise; the CLI commands around them do not** (inbound
  > [#295](https://github.com/DaveKJohn/claude-code-specialists/issues/295)). This bullet used to say "it
  > never edits" without naming the *it*, and a reader two paragraphs later is told to run
  > `claude plugin uninstall`, which **does** edit that file. Both halves were measured on July 31, 2026
  > in throwaway repos: with `bootstrap.ps1` and `teardown.ps1 -Apply` run and **no** `claude` command at
  > all, `git diff .claude/settings.json` stays empty -- so the symmetry above holds exactly as claimed.
  > But `claude plugin install … --scope project` re-serialises the whole file (key order, nested-object
  > indentation, and in two fixtures a removed UTF-8 BOM and an added final newline), and
  > `claude plugin uninstall … --scope project` removes your plugin's entry and leaves
  > `"enabledPlugins": {}`. In both real consumers that file is **tracked**, so this shows up as a diff in
  > a governance file the reader has just been told this procedure never touches. Naming the actor makes
  > the promise stronger rather than weaker: it is a statement about what these scripts do, and it is
  > exact.
- **It never removes roster rows or repo-specific prose from `CLAUDE.md`.** Those are authored text in a
  file full of other authored text, and no rule this script could apply safely tells where a roster row
  ends and your own prose begins. The only line it touches there is the **single** seam `@`-import, which is
  knowably bootstrap-written and cannot be anything else -- the same property that let
  `check-roster-sync` stop counting them as roster rows. (The other two imports -- the persona body and the
  lens -- live inside `.claude/specialists/SPECIALISTS.md`, which this script removes whole, so they need no
  line-level handling. This page and the skill description said "the two `@`-imports in `CLAUDE.md`" until
  August 1, 2026: a description left behind on the pre-seam layout, where both did sit in `CLAUDE.md`. It set
  a false expectation for the very step the `[create]` -> `[remove]` table rests on, inbound
  [#337](https://github.com/DaveKJohn/claude-code-specialists/issues/337).)
- **It never touches the plugin install or cache.** `claude plugin uninstall <plugin>@<marketplace>
  --scope project`, run from this repo's root, is a separate step. Keep the scope flag: like `plugin
  install` and `plugin update`, `uninstall` defaults to `--scope user` and will not find a
  project-scoped install without it (inbound
  [#279](https://github.com/DaveKJohn/claude-code-specialists/issues/279)).

## Verifying a round-trip — and why `git status` is not enough

The first real round-trip (`davekokbwj/smartwatchbanden`, July 29, 2026) was verified with
`git status` / `git diff`, and that method turned out to be **partly blind**: that repo ignores
`.claude/*`, so `settings.suggested.jsonc` never appeared in `git status` and `git checkout .` did not
clean it up. Since `.claude/` is where most of what the bootstrap writes lives, git can miss the bulk of
it. Worse, in such a repo git cannot **restore** a wrongly deleted lens either — so establish whether
`.claude/` is tracked *before* running with `-Apply`.

### Pre-flight: is your lens tree actually under version control?

Two commands, because one cannot decide it. They answer different questions, and only the first is
about whether this procedure *can* have an undo:

```powershell
# 1. Can this repo track the lens tree at all?
#    A line that SURVIVES the filter = ignored -> there is NO undo, stop here
git check-ignore -v .claude/specialists/lenses/ |
  Where-Object { ($_ -split '\t')[0] -notmatch ':$' }   # keep only hits with a filled pattern field

# 2. Is it COMMITTED right now? Staged does not count -- this reads the commit, not the index
git ls-tree -r --name-only HEAD .claude | Select-String 'extension\.md|SPECIALISTS\.md'
#    empty output      = not committed yet
#    "fatal: ... HEAD" = no commits in this repo at all, so also not committed
```

**Command 1 filters its own output, and leaving that filter off is what makes it lie.** `check-ignore
-v` prints `<source>:<line>:<pattern>` + TAB + `<path>`, and in a `.gitignore` with **CRLF line endings
and at least one blank line** that blank line is read as a pattern of a single `\r` — which matches
**every** path with a trailing slash. The result is a hit whose **pattern field is empty**, and only
someone who knows the field should be filled can tell it from a real one. Measured in
`DaveKJohn/life-hub` on July 30, 2026 (git 2.54.0.windows.1): `.gitignore:19:` + TAB +
`.claude/specialists/lenses/`, exit `0` — while **the lens tree** was not ignored at all (no `claude`
line anywhere in `.gitignore`, 16 files under `.claude` tracked, no `core.excludesFile`, a default
`info/exclude`), and line 19 of that file is blank.

> **Scoped to the lens tree on purpose, because the broader claim is not true on this machine.** An
> earlier wording said nothing under `.claude` was ignored, and a later round found that git reads a
> global ignore file from the XDG default location **even with no `core.excludesFile` set** — here
> `~/.config/git/ignore`, which does ignore `**/.claude/settings.local.json`. That changes nothing about
> the measurement above (the lens tree is demonstrably tracked), but the paragraph is written to be
> reused as evidence, and "nothing under `.claude` is ignored" was a step stronger than what was
> checked. If you reuse the pre-flight's reasoning elsewhere, remember that an absent
> `core.excludesFile` does not mean an absent global ignore. A CRLF `.gitignore` with a blank line is the
**normal** state of a repo on Windows and both real consumers are Windows repos, so unfiltered this
command hands the loudest verdict in the section — *stop here* — to the repo the table below lists as
the safe one.

**Do not reach for "just drop the trailing slash" instead: that trades the false positive for a false
negative.** Measured on July 31, 2026 across the six fixtures now carried as a regression suite in the
source repo (`scripts/tests/teardown-protocol.tests.ps1`, which runs *this* filter, extracted from this
page): in a CRLF repo that genuinely ignores
`node_modules/`, `git check-ignore -v node_modules` (no slash, directory absent from disk) exits `1` —
a real ignore rule, missed. Filtering is the safe half of that trade, because the artefact never
outranks a real pattern: with a genuine rule placed **before** and **after** the blank line, git
reported the genuine one, pattern field filled, in both orders. Dropping empty-pattern lines can
therefore only ever remove a false hit — never suppress a true one.

**Why not the second command on its own — it used to be, and it gave the alarming answer for the safe
repo.** Measured in `DaveKJohn/life-hub` on July 30, 2026, immediately after the bootstrap and before
`-Apply`, which is exactly when this section tells you to look: the command came back **empty**
while `.claude/` was genuinely under version control — 16 files tracked, `settings.json` among them,
nothing about the path ignored, and 19 freshly written lenses sitting in `git status` as `??`. The
lenses the bootstrap has just written are new, so a command that reports what is *recorded* says nothing
about whether the repo *can* record them. That is command 1's question, and only command 1 answers it.

> **This command was `git ls-files` until August 1, 2026, and that was the third generation of one defect**
> (inbound [#332](https://github.com/DaveKJohn/claude-code-specialists/issues/332)). `ls-files` reports the
> **index**, not the commits — so a `git add` with a *failed* commit behind it made the command flip from
> empty to 20 lines with zero commits in the repository, and the paragraph above explained the emptiness by
> saying `ls-files` "lists committed files only", which was itself wrong. Both are corrected: the command is
> now `git ls-tree -r --name-only HEAD`, which reads the commit. The lineage is #280 (`ls-files` cannot tell
> *"this repo cannot"* from *"you have not yet"*), #283 (the CRLF artefact in command 1) and this one, which
> is why the fix arrived with a seventh fixture in the suite below rather than as a third correction to the
> prose: staged-but-not-committed, asserting the command stays empty.

So an empty result collapses two states that call for opposite responses:

| state | what it means | what to do |
|---|---|---|
| `.claude/*` is **ignored** (the `smartwatchbanden` row below) | this repo can never protect its lenses | stop — this is what the section exists to catch |
| `.claude/` is **tracked, lenses not committed yet** (the normal state right after any bootstrap) | the undo is available, you have not claimed it | commit the lens tree, *then* proceed |

Read strictly, "empty = not tracked" is not wrong about that second row — an uncommitted file has no
git copy either. But only the first row is a reason not to proceed, and a verdict that fires loudest
in the safe case is one an operator learns to ignore. Command 1 separates them: it asks the
`.gitignore` question directly and answers it whether or not anything has been committed.

**And note where the undo actually begins: at the commit, not at the bootstrap.** The table below
says a wrongly removed lens in `life-hub` is one `git checkout` away — true of a *committed* lens
tree, and of nothing else. In a repo that tracks `.claude/`, committing the lens tree before `-Apply`
is the step that buys the safety net. As this section already argues about ignore rules: *a rule
written against a path is a bet that the path will not move.* A tracking claim written against files
that are not committed yet is the same kind of bet.

**And the answer can change when you migrate to the seam, which is the trap.** Measured across the two
real consumers on July 30, 2026:

| repo | `.gitignore` | consequence |
|---|---|---|
| `DaveKJohn/life-hub` | no `.claude` entry at all | the whole tree is tracked — a wrongly removed lens is one `git checkout` away |
| `davekokbwj/smartwatchbanden` | `.claude/*` with `!.claude/plugins/` | tracked **only** on the pre-seam path |

That second row is fine today and breaks silently on migration: the exception un-ignores
`.claude/plugins/`, the **pre-seam** location. Move the lenses to `.claude/specialists/` and they match
`.claude/*` with no exception covering them — so the tree leaves version control **without a single line
of the migration looking wrong.** Every gate stays green (the readers accept the seam, which is the
point), `git status` shows nothing (they are ignored), and the teardown's undo is gone.

**So the two ignore-critical acts inside step 0 have an order:** add the `!.claude/specialists/`
exception (and commit it), *then* move the files. Reversed, the move lands untracked and the commit that
would have captured it has nothing to capture.

> **Two acts here, out of the five steps (0–4) a full seam migration takes — a different unit, not a
> different path.** The numbered list lives in
> [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#the-seam-specified); this page zooms in on step 0, the one that
> can lose files. Said explicitly because the family now counts this procedure in four places, and
> inbound [#305](https://github.com/DaveKJohn/claude-code-specialists/issues/305) found this one had been
> left out of the sweep that aligned the other three.

More generally: **an ignore rule written against a path is a bet that the path will not move.** The
migration is exactly the moment that bet is called in, and nothing in this family's tooling can see the
consumer's `.gitignore` for you — which is why this is a pre-flight step for the operator rather than a
check.

Take a **filesystem** inventory at each stage instead, and compare the numbers:

```powershell
# count of lenses, imports, lone LFs, scaffolds, and the settings proposal
$root = (Get-Location).Path
$text = Get-Content (Join-Path $root 'CLAUDE.md') -Raw
@(Get-ChildItem .claude -Recurse -Filter '*-extension.md' -File).Count
@($text -split '\r?\n' | Where-Object { $_ -match '^\s*@' }).Count
([regex]::Matches($text, '(?<!\r)\n')).Count
Test-Path scripts\repo-config.ps1; Test-Path scripts\lib\branch-info.ps1
Test-Path .claude\settings.suggested.jsonc; Test-Path .claude\settings.proposed.json
```

**Read `CLAUDE.md` once, into `$text`, from a path anchored to the repo root — the two lines that skip
that both fail to green.** This block used to count the imports with
`[System.IO.File]::ReadAllLines('CLAUDE.md')` and the lone LFs against a bare `$text`, and both were
silently measuring nothing:

- **A .NET static method with a relative path does not follow `Set-Location`.** It resolves against
  `[Environment]::CurrentDirectory`, which `cd` leaves untouched — so in one and the same block the
  cmdlet lines measured the repo you are standing in while that one line measured whatever directory
  the process started in. Measured in a fresh consumer on July 30, 2026: `19` lenses from the
  disposable folder and `0` imports read out of **`life-hub`'s** `CLAUDE.md`, with
  `[System.IO.Path]::GetFullPath('CLAUDE.md')` confirming the other repo. Nothing in the output names
  a path, so the block looks internally consistent while one line reports on a repo that plays no part
  in the measurement — and this goes wrong in exactly the fresh disposable folder step 1 of the test
  protocol prescribes.
- **`[regex]::Matches($null, …)` does not throw, it returns zero matches.** `$text` was never assigned
  anywhere in this document, so the lone-LF line printed `0` without reading a byte; the same file read
  properly gave `8`.

Both wrong answers are the **green** one: a `0` reads as "the import was removed cleanly" and as "no
line-ending pollution" — precisely the two defects this protocol exists to catch. Hence the two setup
lines at the top, and hence `Get-Content -Raw`, which follows the PowerShell location like every other
line here.

**Read the two scaffold lines correctly, or the whole protocol tells you the wrong thing.** They are an
*inventory*, not an expectation — and what the right answer is depends on something the numbers cannot
show you: **whether the repo already had those files.** This tripped up the first real adoption attempt
(life-hub, July 30, 2026), which stopped before installing and was right to:

| the repo before adoption | after bootstrap | after teardown `-Apply` |
|---|---|---|
| the addresses were **empty** | placed as `VUL-IN` scaffolds | **removed** — nobody filled them in |
| the addresses were **occupied** (a real `repo-config.ps1`, a filled prefix table) | `[keep] ... already exists -- not overwritten` | **kept** — the teardown never removes what it did not write |

So "both scaffolds present after the bootstrap" is trivially true in an occupied repo and measures
nothing, and "both scaffolds gone after the teardown" can only go green there by deleting two
load-bearing files. **Check the report lines, not just the `Test-Path` results:** `[create]` versus
`[keep]` on the way in, and `[remove]` versus `[KEEP]` on the way out, are what actually tell you which
of the two rows above you are in.

This is not a special case. The plugin scaffolds precisely the files that were *extracted from* repos
like these, so on a fresh fixture the addresses are free and in any real consumer they are inhabited —
which is why the round-trip suite now carries an explicit *occupied consumer* scenario.

**And a `[KEEP]` line can name a directory, not only a file** (issue #2192). The run prunes a directory
it emptied — the lens trees, `.claude/specialists/`, `scripts/lib/`, `scripts/` — and keeps any that
still holds a file this run does not remove. Keeping it is right; being silent about it was not, and
until that issue the leftover arm was a bare `continue`, so the directory appeared in no marker and no
count. The occupied consumer above is exactly where that bites, and a repo running `dkj-policy` keeps
its always-on baseline at `.claude/specialists/always-on-baseline.json`, inside the seam directory — so
there the directory survives a teardown while the reader watches its files go.

**Read the count as *what is left*, not as *what the plugin did not put there*.** A lens you filled in
was placed by the bootstrap and survives because it is no longer a scaffold; it is already reported by
name, on its own line, with that reason. The directory's line cannot restate a reason per file, so it
states the one thing true of all of them. And a parent whose leftovers are all inside a child directory
that already has its own `[KEEP]` line is not reported twice — the counts never overlap, and the child's
path names the parent anyway.

Two further checks the hooks will not do for you, both of which caught real defects:

- **Count the bootstrap's note on its head line — and know what the report says instead.** The note is
  a **two-line block**, so "count the note" only means something once you name the unit: count the
  **head** line, in `CLAUDE.md` itself. A `teardown` → `init` cycle used to add one copy per cycle
  (measured 1 → 2 → 3 on that head line) while all three session hooks reported "in sync". Run the
  cycle **twice**: once cannot distinguish "does not accumulate" from "accumulates once". Do **not**
  take this count from the teardown report, which is the tempting source because the word is right
  there: the report lists the block **per line**, so a healthy repo shows **two** `[remove]` lines —
  the first value of the defective series, dressed as the normal case.
- **Count lone LFs in `CLAUDE.md`** — the third counter in the block above. The bootstrap used to paste
  LF into a CRLF file, invisible to every gate.

And declare your own empty-lens convention if you have one, or the report will keep files it cannot
recognise: `-EmptyLensPattern '<your marker>'`.

## What is left over afterwards, honestly

A repo that ran the bootstrap, filled in its lenses, and then tore down is **not** blank. The remaining
distance was measured by hand in `davekokbwj/smartwatchbanden` (July 29, 2026) rather than estimated,
and it is four different kinds of leftover. Only the second is this skill's own limitation. Note that
the target is **no *live* reference, not zero references** -- see
[what is correctly left standing](#and-what-is-correctly-left-standing) at the end of this section, and
the requirement itself in [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#what-the-ideal-shape-looks-like).

**1. A runtime dependency no teardown can undo -- the one that actually hurts.** The plugin is the
single source of truth for the operational scripts (`new-branch.ps1`, `park-branch.ps1`,
`new-branch.ps1`, `open-pr.ps1`, `fold-changelog-entry.ps1`;
[issue #81](https://github.com/DaveKJohn/claude-code-specialists/issues/81)), and a consumer reaches them
through a resolver of its own that locates the marketplace cache and **throws** when that cache is gone.
In the measured consumer that resolver is `scripts/lib/plugin-paths.ps1`, and three operational scripts
dot-source it: `start-task.ps1`, `open-pr.ps1`, `fold-changelog-entry.ps1`. So after a teardown plus a
`claude plugin uninstall`, the repo does not merely carry clutter -- **its daily git workflow stops
working.** No option to this script can fix that: adopting the shared-script model is what creates the
dependency, and undoing it means the consumer holding local copies of those scripts (or its resolver
degrading instead of throwing). State the promise precisely, then: what the bootstrap *wrote* is
reversible; what the consumer *built on top of the plugin* is not, and a consumer that relies on the
shared scripts has to plan that step itself.

**What the script does about it, first: warn.** Any `.ps1` under `scripts/` that references the
marketplace cache or `CLAUDE_PLUGIN_ROOT` is reported as a `[WARN]` line, together with the scripts that
depend on it, and is **never removed** -- it is your code. Everything else in the report answers "what
did the bootstrap put here"; this answers "what breaks after you uninstall", which is the question a
reader actually has before trusting the word *reversible*. The scan covers `scripts/` only, so a resolver
living elsewhere is still yours to spot.

**And second: `-VendorScripts` hands the scripts back, which is the actual way out.** It copies the
plugin's shared script payload (`scripts/task`, `scripts/release`, `scripts/lib`, `scripts/sync`) into
your own `scripts/`, structure preserved, so the workflow keeps running with the plugin gone. This works
because the payload was built to travel: the scripts locate the repo through `CLAUDE_PROJECT_DIR` /
`git rev-parse --show-toplevel` -- never their own location -- and dot-source their siblings
`$PSScriptRoot`-relative, so a copy behaves identically anywhere inside the repo. The source repo is the
standing proof: its `scripts/` copies are byte-identical to the plugin's, and that is asserted on every
vendor test run.

Three things to know before using it:

- **It is the one additive act in a subtractive script**, which is why it is opt-in rather than default.
- **It never overwrites.** A destination that exists and differs is reported and left alone -- that file
  is typically your own wrapper around the shared script, so the rule protecting a filled-in lens
  protects it too. Reconciling those is yours; an identical destination is reported as already current,
  so re-running is safe.
- **The vendored scripts still need the repo-owned script contract** they dot-source
  (`scripts/lib/branch-info.ps1`, `scripts/repo-config.ps1`). Keep those whatever else you drop. If the
  same run removed them because they were still unfilled scaffolds, the report says so outright: that
  repo never had a working workflow to preserve.

**2. Authored text this script refuses to touch.** By design, per
[the section above](#what-it-deliberately-will-not-do) -- and measured, so the size of the hand work is
known. `CLAUDE.md` carried the roster table (22 rows), the work-division block, the loading-strategy
paragraph, and the safety cross-references into the orchestrator's lens: roughly 43 lines across some 6
sections. Outside that file the mentions are loose and few -- `README.md` (5),
`research/plugin-sharing/README.md` (14), `releases/README.md` (1),
`.github/pull_request_template.md` (1). As long as specialist content is woven through `CLAUDE.md`
rather than sitting behind a single inclusion, a script cannot finish this without guessing where a
roster row ends and the owner's prose begins. Closing it is the seam in
[issue #221](https://github.com/DaveKJohn/claude-code-specialists/issues/221) -- this skill is the half that
can be built and tested today.

**3. A lens that outlives the import which loaded it.** The orchestrator's lens
(`01-01-extension.md`) is authored content, so it is kept -- while the `@`-import that loaded it is
removed, being knowably bootstrap-written. The file therefore survives as an orphan: present, tracked,
and read by nothing. Both halves are correct, and the combination is worth naming, because a `[KEEP]`
line reads as "still working" when all it means is "still there".

**On a seam consumer this leftover shrinks to one named file.** Where the specialist surface sits behind
`.claude/specialists/` (issue #221), a teardown removes that whole directory and the single import line.
If `SPECIALISTS.md` still carries its `## The roster (VUL-IN)` slot it goes with the rest; if the owner
filled the roster in, it is kept, the import is still removed -- that line is what made the content
*live* -- and the report says outright that nothing loads it any more. So the orphan is not gone, but it
is **one file with a name, holding the roster in one piece**, instead of 43 lines scattered through six
sections of `CLAUDE.md`. That trade is what the seam actually buys.

**4. A consumer gate that goes blind rather than red.** A consumer that lints its own lens files keeps
that check afterwards, and in the measured repo the lens category **silently skips** once the directory
is gone: nothing errors, nothing is reported, and the gate stays green while checking nothing. That is
the right outcome for a deliberate teardown and the wrong one for an accidental loss -- a silent skip
cannot tell an operator's removal from a bad merge or a mistyped path, so the one case it must warn about
is the one case it stays quiet in. Not this script's to fix (the gate is the consumer's own), but worth
knowing before you rely on a green gate to tell you the repo is intact: a skip that *says* it skipped
costs one line.

And `.claude/settings.json` is unchanged -- that is the refusal above rather than a leftover. The plugin
stays enabled, subagents and session hooks included, until the owner removes the entry and restarts.

### And what is correctly left standing

Some references are supposed to survive, and counting them as debt would be a mistake. In the measured
repo, `CHANGELOG.md` (3) and `releases/development/*` (43) mention specialists -- 46 references that are
each an accurate record of something that happened. **History is finished business: it is never
rewritten, and a teardown must not touch it.**

Which is why the goal is *no live reference* rather than *no reference*: nothing a **session loads**, a
**script resolves**, or a **gate depends on** may still point at the plugin. Read that way the four
leftovers sort by what they actually cost -- (1) breaks a run, (2) and (3) mislead a reader, (4) misleads
a gate, and the changelog is simply the record of having adopted the plugin in the first place.

## The free-standing audit -- the run proves it instead of claiming it

Every section above answers *"what did the bootstrap put here, and what did I take away"*. None of them
answers the question the requirement actually poses: **after this, does the repo stand free?** So the run
closes with an audit that goes looking, and lists what it finds by **file and line**:

```
-- free-standing audit: LIVE references left after this teardown --
   scanned 24 file(s) under CLAUDE.md, .claude/ and scripts/ against 19 known specialist name(s)
  [LIVE]   CLAUDE.md:3 -- name 'Derek'
  [LIVE]   CLAUDE.md:6 -- specialist id + name 'Derek'
  [LIVE]   scripts\repo-config.ps1:3 -- plugin-only contract function
```

**Report-only, unconditional, and it runs on a dry run too** -- it removes nothing, so it needs no
`-Apply`, and a preview that cannot tell you what would still be left is not the inventory a reader needs
in order to say yes. A clean repo gets `[FREE]` instead, and that line is the requirement met *verified
rather than assumed*.

**Why it finds rather than fixes.** The target shape's second item is *"reword category 3 plugin-neutrally
so it stays true after an uninstall"* -- turning *"Derek opens the PR"* back into *"changes go in via a
branch and a PR"*, a rule that stays true with the plugin gone. That was never something a script could
do: it is the owner's governance prose, and a plugin rewriting it would be the exact damage the
[classification](#what-it-classifies-and-why-that-is-the-whole-design) exists to prevent. What a script
*can* do is turn an unbounded hand-audit into a checklist. Three kinds of hit, each with a different
answer:

| hit | what it means | what to do |
|---|---|---|
| a **specialist id** (`05-05`) | a roster row, a routing table, a chain | usually **delete** -- it only ever existed for the plugin |
| a **name** (`Derek`, `Tessa`) | a still-valid rule phrased through a character | usually **reword** -- keep the rule, drop the name |
| a **plugin-only contract function** (`Get-RosterPath`, `Get-RosterIgnoredIds`) | a line inside a file that is otherwise yours | **delete the line**, keep the file |

The choice is per line, not per file -- which is why the audit reports lines.

**Three deliberate boundaries, so the output can be trusted:**

- **The names come from the plugin's own payload**, never a hardcoded list that would rot on the next
  rename: an agent def's `name:` frontmatter, and a persona's H1. But this skill ships inside **one**
  plugin and can only see that plugin's specialists -- a consumer that also enables a domain plugin has
  names this scan does not know. The **id scan is the general net** (a `<gg>-<ii>` token is
  name-independent and catches a specialist from any plugin); the name scan is the extra pass on top.
- **Matching is case-insensitive and covers possessives, biased toward over-reporting.** The expensive
  failure for an audit whose purpose is proving nothing was missed is a reference it did not find, not one
  a reader dismisses in five seconds -- and every hit carries `file:line`, which makes a false positive
  cheap and a false negative silent. **Possessive forms count as the name**: Dutch takes no apostrophe, so
  a trailing word boundary silently rejected `Dereks` and a live reference in a non-English consumer's own
  prose went unreported (found in a Dutch consumer, inbound #271 -- and it applies to every non-English
  repo, not to an edge case). The hit reports the text **as it appears in the file**, possessive included,
  so a reader can search for what they were shown.
- **Files this run is about to delete are excluded, and the exclusion is stated.** A reference inside a file
  that is going away is not a surviving reference. Without this, a dry run's list was filled entirely by the
  lens files the same run had just put on the `[remove]` list -- they all mention a specialist -- and the
  handful of hits that actually matter only appeared after `-Apply`. That inverts the purpose of a preview
  that is explicitly the inventory you say yes to.
- **And so are the *lines* it is about to delete, in a file that stays** (inbound #275). The exclusion above
  is per file; the bootstrap's orchestrator note and the `@`-import(s) are lines removed from a `CLAUDE.md`
  that survives. A dry run used to report the note as a live `name 'Chris'` hit on the very run that lists it
  under `[remove]`, so the audit dropped from 5 live references to 4 after `-Apply` on a consumer that had
  changed nothing in between. Same defect as the lens-file one, one order of granularity smaller, and the
  line count is stated in the scan line exactly like the file count.
- **History is out of scope and never rewritten.** `CHANGELOG.md` and `releases/` are excluded entirely.
  Other root prose (`README.md`, `CONTRIBUTING.md`) is outside the live set by the reading above, so it is
  **counted, not listed** -- a pointer, not a work queue.
