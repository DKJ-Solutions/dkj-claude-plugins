# `dkj-subagents-shopify` — the Shopify add-on team

Three specialists for a Shopify store repo, five skills, and an **operational floor**: the part that is
not advice.

| what | who / where |
|---|---|
| **Liam** 💧 `04-20` | Liquid Developer — features and fixes in the theme code, plus `assets/` and `locales/` |
| **Sandra** 🛍️ `05-21` | Store Manager — read-only admin reconnaissance and the pre-push checklist |
| **Steven** 🗂️ `05-22` | Configuration Manager — theme estate, cleanup policy, CLI and auth reference |
| `start-task` | the skill that opens a task: the branch. The preview theme is no longer part of it — see `push-preview` |
| `push-preview` | the skill that pushes the current branch to its own **unpublished** preview theme, creating that theme on the first push rather than at branch creation |
| `adopt-shopify-floor` | the skill that **places** the floor in your repo: the guard's seams, a starter `.theme-check.yml`, and the CI workflow over it |
| `sync-main` | the **pre-task sync**: mirror the live theme into the trunk without letting live overwrite what the trunk has done since |
| `archive-theme` | the backup that makes removing a spent preview theme recoverable: a verified local copy plus a **committed receipt**. It never removes a theme — see below |
| `hooks/guard-live-theme.ps1` | **the floor** — a `PreToolUse` guard on the live theme |
| `hooks/shopify-floor-sessioncheck.ps1` | says when that guard is only half armed, and when a second one is registered beside it |

Teams stack: this one adds to `dkj-subagents-alpha`, and a commercial store typically enables `dkj-subagents-ecomm` beside
it. Which store a repo *is* belongs to that repo's lenses, never to this plugin.

## The floor: why a guard and not a rule

This team exists because a live theme serves real money and Shopify has no locking. The manuals state
that in prose, in three places — and **prose does not stop a command**. Two things make a written rule
insufficient here rather than merely weak:

- **A permission deny list matches a command prefix.** A rule that forbids the CLI never sees the same
  command wrapped in a shell invocation, and a settings file that allows both the CLI and a
  `powershell -Command "…"` wrapper leaves the exact forbidden command reachable by wrapping it. That is
  the default state of a repo, not a misconfiguration.
- **It was built twice.** Two consumers of this plugin independently wrote this same guard before it
  shipped here (inbound [#769](https://github.com/DaveKJohn/claude-code-specialists/issues/769)), and the
  second had to learn the false-positive lesson below from scratch while the first still carries it.

### What it refuses

| | rule | needs configuration? |
|---|---|---|
| 1 | a theme **publish** — always | no |
| 2 | a theme **delete** — always | no |
| 3 | a theme **push** aimed at live — unless authorised | the id half does |

Rules 1 and 2 have **no escape hatch at all**, and that is deliberate: publishing makes a theme the
customer-facing one and a delete cannot be undone, so both stay the store owner's own keystroke rather
than something a marker in a command line can stand in for.

**Untouched:** every form of `theme pull`, including `--live` — reading is how a pre-task sync works —
pushes to an unpublished preview theme, and every other command.

### Authorising the deliberate live push

Add the marker to that exact command, as a shell comment:

```bash
shopify theme push --store yours.myshopify.com --theme <live id> --only assets/x.css --allow-live # LIVE-PUSH-AUTHORIZED
```

It is a comment in both shells, so it changes nothing about what runs. **A marker rather than an
environment variable**, because the hook runs as its own process and would not inherit an inline env
prefix — a variable would have to be set session-wide, which is exactly the state that makes a stray push
dangerous. A marker authorises **one** command, visibly, in the transcript.

## What your repo has to answer

Functions in your own `scripts/repo-config.ps1` — the file `specialists-init` already scaffolds. **Three
belong to the guard**, and one of those is the only one worth answering on day one:

```powershell
function Get-ShopifyLiveThemeId    { return '190793613653' }   # shopify theme list names it
function Get-ShopifyLivePushMarker { return 'SWB-LIVE-PUSH-AUTHORIZED' }
```

| function | absent — or answered non-numerically, which counts as the same thing |
|---|---|
| `Get-ShopifyLiveThemeId` | the **id half of rule 3 cannot fire**: `--allow-live` still blocks, and a push aimed at live *by id* passes. A real hole, so the session check reports it once per session rather than leaving it silent. |
| `Get-ShopifyLivePushMarker` | any marker **ending in** `LIVE-PUSH-AUTHORIZED` is accepted — which is what both existing consumers already write (`SWB-…`, `XOXO-…`). Setting it **narrows** to your spelling alone. |
| `Get-ShopifyThemeDeleteMarker` | **rule 2 stays absolute** — a theme delete is refused and no marker exists that could pass it. That is how the guard behaved before this seam, and an unstated seam has to keep meaning what it meant yesterday. See below. |

The guard reads them on every command, so a change takes effect immediately; nothing needs restarting.

### Letting a session clear away its own spent preview themes

**Opt-in, and off unless you ask for it.** A theme delete is blocked outright by default. A repo whose
preview themes are created and thrown away by the same workflow can hand that cleanup to a session by
naming a marker of its own:

```powershell
function Get-ShopifyThemeDeleteMarker { return 'SWB-THEME-DELETE-AUTHORIZED' }
```

A delete then needs that exact marker on that exact command — the same shape as the live-push
authorisation, and for the same reason: it authorises **one** command, visibly, in the transcript.

```sh
shopify theme delete --store x.myshopify.com --theme 198933086549  # SWB-THEME-DELETE-AUTHORIZED
```

Three things this deliberately does **not** do:

- **The live theme is refused even with the marker.** That check runs *before* the authorisation path, so
  no marker reaches past it. Shopify will not delete a published theme either — this is the belt to that
  braces, and it is the one outcome nothing else in the hook could undo.
- **It does not open deletes generally.** Answering the seam changes nothing about a delete command that
  does not carry the marker.
- **One marker may not do two jobs.** Answer this with the *same* string as `Get-ShopifyLivePushMarker`
  and the delete capability stays **off**. A live-push marker gets written as a matter of routine — it is
  in the step list — so accepting it here would turn every documented live push into standing
  authorisation to delete. It fails safe: the cost of the collision is one word of config, the cost of
  allowing it is a theme.

**Why the default is not simply "allow anything that is not live".** A real Shopify estate is not just the
live theme and this week's preview. It carries dated backups, themes named `DO NOT DELETE`, and abandoned
work from previous agencies — measured on a live store in August 2026: nineteen themes, of which one was
a current preview. Nothing in a command distinguishes a spent preview from any of the rest, so the marker
is what makes the deletion deliberate; being merely non-live is not enough.

### The archive is the other half of that marker, and it does not remove anything

`archive-theme` is the step that makes a removal *recoverable*: it pulls the theme into
`theme-archive/`, verifies the pull landed something that is actually a theme, writes a **committed
receipt** for it, and then **prints** the removal command — with the theme's name and role beside it,
and the marker in place where the seam above is answered — for somebody to run as its own visible act.

**It never runs that command itself, and that is a property of the guard rather than caution.** The
guard is a `PreToolUse` hook: it reads the *command string* of a tool call. A destructive theme command
buried inside a `.ps1` is invisible to it — the tool call reads `powershell -File … -Execute`, which
holds nothing to match. So a script that removed a theme itself would not be a rule broken in the open;
it would be a silent hole in the one mechanism that closes the wrapper vector. One of the two stores
this skill converges had exactly that shape, and closing it is half of what converging bought.

**The receipt is the half that survives the machine.** `theme-archive/` belongs in `.gitignore`, so a
verified archive proves a removal recoverable *on the day it is taken* and nothing keeps that true
afterwards — measured in a store: eight themes archived, all eight gone a week later, the archive
folder absent from the checkout, and the only evidence the 2,934 files had ever existed was one
sentence in a changelog entry. Making the *bytes* durable was rejected (for a spent branch preview the
durable copy is git). What is committed instead is one small text file per theme, naming every file
with its size and SHA-256, and **one event per machine that has held a copy**.

**Two optional seams**, both unanswered by default and both harmless unanswered:

| function | what it decides |
|---|---|
| `Get-ShopifyExternalThemePrefixes` | theme-name prefixes belonging to an outside integration. Matching themes are still archived — a read-only local copy harms nobody — but the printed removal command carries a warning, because removing one breaks that party's integration. |
| `Get-ShopifyArchiveVerifierPath` | a consumer's own receipt verifier, named in the receipt so a reader knows how to check a recovered copy. Unanswered, the receipt says what it can prove without pointing at a tool that is not there. |

**Six more belong to the pre-task sync** (`sync-main`), and only the store is required beside the theme
id — the other five have defaults that are right for both existing Shopify consumers:

| function | default | what it decides |
|---|---|---|
| `Get-ShopifyStoreDomain` | **required** | the store the sync pulls from. It refuses rather than guessing; the skill's `-Store` gets you through one run. |
| `Get-ShopifySyncReferencePattern` | `^[Ss]ync` | the pattern that recognises a sync commit, matched against the commit **subject** read as its own field — a .NET regex, not git's `--grep`, which the lookup no longer uses. It applies to the repo-wide answer and to each path's own base alike. **Narrow it if your history says so, never widen it:** a base is the *most recent* match, so a looser pattern can only move it forward and protect fewer files. |
| `Get-ShopifySyncBranchPrefix` | `sync/live-` | the drift branch's prefix. Yours to set because it has to line up with whatever your PR guardrails and CI exempt. |
| `Get-ShopifySyncMerges` | `$false` | `$true` opens the PR and merges once CI is green. The default pushes and stops, so somebody *looks* at what third parties changed before it becomes the base of new branches. |
| `Get-ShopifySyncPrBody` | *(none)* | the PR body, given the classified rows and the body the script already composed. Answer it only where the PR body **is** your review policy — a template, a checkbox, a fixed wording. Unanswered, the default already names both halves and every path with its kind. |
| `Get-ShopifySyncPrLabels` | *(none)* | the label(s) the sync PR carries — a string or an array of them. Answer it where a guardrail workflow **fails an unlabelled PR**: without one the sync PR goes red on CI and cannot merge. They go on the `gh pr create` *and* on the line the non-merging path prints, so whichever route you take carries them. |
| `Get-TrunkBranchName` | `main` | the trunk. Not a Shopify seam — the sync simply reads it if your repo has answered it. |

**And one more belongs to the preview push** (`push-preview`), which otherwise reuses the store domain,
the live theme id and the trunk from the two tables above:

| function | default | what it decides |
|---|---|---|
| `Get-ShopifyPreviewUrls` | one URL on the store's own domain | the preview URL(s) printed after a push. Answer it in a **multi-market** store to get one per market or locale. |

**That one is a seam because the market table genuinely is per-store, and the rest of the job is not.** One
consumer runs a single domain with locale-prefixed paths (`/`, `/en`, `/de`, `/nl-gb`, …); another runs five
separate domains. A shipped table would have produced four domains that do not exist. What *is* shared is
that a preview link needs `_ab=0&_fd=0&_sc=1` to survive the first internal click — without them the
preview holds only through the cookie, and you are then looking at **live** while believing you are looking
at the preview. A consumer lost a whole review to that. The built-in single URL carries them; a seam answer
has to carry them itself.

**`Get-ShopifyLiveThemeId` is recommended rather than required here**, unlike for `sync-main`, and the
difference is which direction the risk runs. `sync-main` reads *from* live, so not knowing which theme is
live means it cannot work at all. `push-preview` pushes to an *unpublished* theme and wants the live id
only for a belt-and-braces refusal — and the guard hook blocks a live-aimed push whether or not the script
recognised the target. So an unanswered seam costs one of two independent refusals, and the script says so
out loud instead of blocking a preview.

Every one of them is read through `Get-Command`, so **this plugin depends on no workflow plugin at all**: a
repo on `dkj-policy` and a repo on none get identical behaviour. That includes
the branch-name flattening `push-preview` needs — Shopify rejects a theme name containing `/`, so the
branch name is taken from `Get-BranchInfo`'s `SafeName` where the repo has it and falls back to replacing
`/` with `-`, which is the same answer.

**You do not have to place any of that by hand** — the `adopt-shopify-floor` skill writes the block, and
takes the theme id and the store as parameters so both are answered in the same move. It also places the
two items every Shopify consumer of this plugin has otherwise written from scratch: a starter
`.theme-check.yml` and the CI workflow over it.

**A placeholder does not count as an answer, on purpose.** `Get-ShopifyLiveThemeId` returning anything
non-numeric — a `VUL-IN` left in place, most likely — is read by both the guard and the session check as
*unanswered*. A theme id is numeric, and the alternative is worse than an absent function: a stub would
silence the report while leaving the id half exactly as inert as before. That is the shape this README
warns about two sections down — a hole with a comment on it.

**A repo with no store says so — and only then does the session check go quiet.** A repo that enables
this team **without a Shopify store** — the plugin's own source repo, or any repo that turns the team on
purely to check that its manifests, frontmatter and hooks still resolve — has no truthful theme id to
give, and a placeholder reads as forgotten. It answers one function instead:

```powershell
function Get-ShopifyRepoHasNoStore { return $true }
```

The floor session check then stays silent on the half-armed finding, exactly as it does once a store
repo has answered the live id — because this is a deliberate, self-authored **declaration**, not
something the check inferred from the tree (a theme directory, a `shopify.theme.toml`). Everything else
is unchanged: the guard hook still runs, with the id half of rule 3 inert, which costs nothing when
there is no store to push to; every other seam behaves as before; and the duplicate-guard finding stays
independent. **Absent — the ordinary case — still means a store repo**, so no real store is ever
silenced by it.

## The one thing to know before you read a `git status` here

**Every pull from live reports files as modified that nobody modified**, and this team's whole safety
model rests on reading that output. The CLI writes each file with the line endings **live** holds, live
holds both, and git checks out according to `core.autocrlf` — two writers, different habits. Measured on
a real store theme: **37 files** reported as modified with **zero changed lines**.

- **Read the drift after a `git add -A`, never off the raw `git status`.** Staging costs nothing for
  exactly those files and leaves only real content standing.
- **Do not pin `eol=lf` in `.gitattributes`.** It is the obvious fix and it makes this **permanent** —
  the same files come back after every pull, forever, converting the one signal that spots a third
  party's in-flight edit into standing noise. What that file should carry is `* text=auto` plus explicit
  `binary` declarations, and nothing else.

Both halves, with the three measurements behind them, are in
[Steven's manual](manuals/05-22-manual.md#the-cli-rewrites-line-endings-and-that-is-a-property-of-the-tool).
This is a property of the **CLI**, not of any one store, so any Windows Shopify consumer meets it —
which is exactly why it is here rather than in a repo lens (inbound
[#788](https://github.com/DaveKJohn/claude-code-specialists/issues/788), reported by two consumers
independently, one of which had to invert its own first conclusion).

## Converging off a hand-written guard

Read this if your repo wrote its own live-theme guard **before** this plugin shipped one. Both existing
consumers did, and inbound
[#777](https://github.com/DaveKJohn/claude-code-specialists/issues/777) is what that cost the second of
them.

**A plugin refresh does not replace your file. It registers a second hook beside it.** The plugin's guard
comes in through the plugin's own `hooks/hooks.json`; yours sits in your `.claude/settings.json`. Both are
live, both fire on every command, and they agree on their verdict — so two hooks block the same command
twice and nothing looks broken. What made it invisible in practice is worth knowing: that refresh happened
*inside* one version, so there was no bump to prompt anyone to read a changelog.

The floor session check now says so once per session. The route off it:

**0. Answer `Get-ShopifyLiveThemeId` first, if you have not.** This step is numbered zero because it
comes before the other three, and it is the one that makes the rest safe. The shipped guard's third rule
has two triggers, and only `--allow-live` is self-declaring: a push aimed at live **by id** is
recognised only where the repo has said which id that is. So in a repo that has not answered the seam,
the shipped guard is *not* a superset of a hand-written one that does know the id — the two are
complementary, and converging first would remove the only cover that case has. The floor session check
says which of the two situations you are in.

1. **Remove your own `PreToolUse` entry** from `.claude/settings.json`, and then your own script. The
   plugin's guard needs no registration from you — enabling `dkj-subagents-shopify` is the registration.
2. **Keep your test suite**, pointed at the shipped copy. It is the part of a hand-written guard that
   does not become redundant, and the shipped guard's own suite lives in the source repo where you
   cannot run it against your theme.
3. **Your authorisation marker keeps working.** Any marker *ending in* `LIVE-PUSH-AUTHORIZED` is
   accepted, so `SWB-LIVE-PUSH-AUTHORIZED` and `XOXO-LIVE-PUSH-AUTHORIZED` both pass unconfigured.
   Confirm that before you delete anything; set `Get-ShopifyLivePushMarker` only if you want to narrow
   to your spelling alone.

**Converging is a safety improvement, not housekeeping, ONCE THE SEAM IS ANSWERED** — which is why it is
written down rather than tolerated: the shipped guard matches `Bash|PowerShell` where a hand-written one
typically matches `Bash` only, and it carries the false-positive lesson below that the first hand-written
version had to learn on its own. It is a superset in what it catches.

**That sentence used to carry no condition** (inbound #994, August 27, 2026), and the reason it needed
one is worth keeping: the superset argument is about the **matcher**, and the id trigger is about the
**rules**. A guard can be narrower in the first and wider in the second at the same time, which is
exactly the state an unanswered seam produces. The failure direction is silent — the hook keeps
running, everything keeps working, and only a push naming live by its number starts getting through.

The removal stays **your** keystroke. `adopt-shopify-floor` will not do it: taking a `PreToolUse` entry
out of somebody's settings is a deletion, and a consumer who ends up with *no* guard because a script
was confident is worse off than one running two.

## Mentioning a rule is not performing it

This is the part that decides whether a guard survives contact with a repo, so it is worth reading before
changing the matching.

The first version of this guard, in the consumer that wrote it, matched the forbidden words **anywhere**
in the command string. On its first day it blocked, in order: the heredoc that wrote the rule into that
repo's `CLAUDE.md`, and the `perl` one-liner that later edited the same sentence. Neither would have
touched the store.

> A guard that makes its own rule impossible to write down is a guard somebody eventually switches off,
> which is worse than no guard.

So the matching asks **where** the words sit rather than whether they occur:

- **Heredoc bodies are stripped** — `cat > file <<EOF … EOF` writes data and the body never runs. *Unless*
  an interpreter is consuming it (`bash <<EOF`), in which case the body **is** a script.
- **Here-string bodies are stripped** for the same reason — a PowerShell `@' … '@` body is assigned or
  piped somewhere and nothing in it runs. *Unless* the command also shows an execution vector
  (`Invoke-Expression`, `iex`, `[scriptblock]::Create`, or the `eval`/`xargs`/pipe-into-a-shell forms).
- **Text tools are skipped** — a segment led by `grep`, `sed`, `perl`, `awk`, `cat`, `echo`, `git`,
  `Out-File`, `Set-Content`, `Get-Content`, `Select-String` and friends is handling the words, not
  obeying them. *Unless* the command pipes into an interpreter or uses `eval`/`xargs`/`iex`:
  `echo "…" | bash` really does execute.
- **Everything else is matched per shell segment**, so a real command after a heredoc, after a semicolon,
  or inside a wrapper is still caught.

**Every one of those exemptions has a counter-case in the suite** (`scripts/tests/guard-live-theme.tests.ps1`
in the source repo, 102 asserts), because an exemption without one is a hole with a comment on it.

### The two PowerShell halves arrived late, and the asymmetry was not a decision

Inbound #1032, from a consumer moving a printed `shopify theme delete` command out of a format string into
a function its test suite could assert. The matcher has covered **both** shells since the first day — that
breadth is what closes the wrapper vector — while both exemptions above knew only the POSIX spellings. So
the same file, written by the same session, was permitted through Bash and refused through PowerShell:
whether you were allowed to write this rule down depended on which shell your platform uses, which is not
a security boundary.

Of the two repairs, the here-string stripping is the one that matters. The segment split is on **newlines**,
so an unstripped body turns each of its own lines into a segment — the line that matches is the body line,
and the cmdlet that would have earned it the text-tool exemption sits a segment away. Adding the write
cmdlets alone would not have fixed the reported case.

**And the refusal text was the sharper half of the same defect.** What that consumer met told them to
*"add the marker `# …-THEME-DELETE-AUTHORIZED` to this exact command"* — and on a command that writes a
**file**, following that advice **works**, because the marker is matched over the whole command string. A
reader doing as they were told would mark a non-delete as an authorised delete, which is precisely the
erosion the marker exists to prevent. The quote above says a guard making its own rule impossible to write
down gets switched off; this was the sharper version, a guard that made its own rule *hazardous* to write
down. Every refusal now carries one extra line saying that a marker authorises a **command**, never a file
write, and pointing at an editor instead — and the suite asserts that line is there, because a sentence
nothing asserts is a sentence the next edit removes.

### The two limits, stated rather than hidden

- **A text tool asked to execute** — `perl -e` with a `system()` call, say — is exempted and is not
  caught. A deliberate trade: that vector needs somebody to go out of their way, while the false
  positives it would otherwise cause happen every time a repo documents its own safety rules.
- **The MCP vector is not covered.** This guard holds the CLI reached through the Bash and PowerShell
  tools. A publish issued through a Shopify MCP connector is a different path, held by that server's own
  permission prompt.
