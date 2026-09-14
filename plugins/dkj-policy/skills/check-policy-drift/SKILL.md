---
name: check-policy-drift
description: Lay out every document that legislates in this repo in RANK ORDER -- the installed plugins' portable pages above this repo's own workflow folder, above its always-on CLAUDE.md closure -- and then read them against each other for contradictions. Use it when adopting this workflow into a repo that already had its own rules, when a session and a page disagree about how the cycle works, or before folding a shared rule into a root CLAUDE.md. The script locates and hands over; the judgement is yours, and nothing is ever edited.
---

# check-policy-drift -- does this repo's own prose contradict the plugin?

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/check-policy-drift.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

**Read-only, and it never refuses.** It opens files, prints a manifest and exits 0. Nothing is written,
nothing is pushed, and no consumer document is edited -- see *"What it deliberately does not do"* below.

## What it is for

`CONTRIBUTING-portable.md`'s **"A third rank sits above both"** states the order and the corollary that
keeps it:

```
the plugin's portable pages + skills        (the shared law)
        >  dkj-policy/CONTRIBUTING.md   (this repo's answers to its seams)
        >  the floor                        (root CONTRIBUTING.md, or CLAUDE.md where the repo keeps its floor there)
```

> a consumer document may **point** at a shared law, **answer a seam** that law names, or **say nothing**
> about it. It may not **restate** the law in its own words.

A restatement is a copy, and a copy does not fail on the day it is written -- only on the day the
plugin's answer moves under it and the copy does not move with it. The measured instance is
[#1378](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1378): `cut-release`'s own mechanics
fix a cut-then-push order, a consumer's `CLAUDE.md` documented push-then-cut, and the disagreement did
not read as drift -- it read as that repo's constitution exercising a supremacy it had declared in
writing.

**This skill is the delivery of that corollary as a whole.** Read the ranking section itself before you
run it; this page assumes it.

## What it is NOT -- and read this before comparing it to #1380

[#1380](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1380) measured a manifest-driven
prose check and **declined** it: a section restating a law almost always also names the mechanism it is
talking about, so a pointer test cannot tell correct deference from restatement-with-citation-and-
override. **That decline is about a script deciding what a sentence means, and it stands.**

This skill never reads a sentence. The script does the half a script is good at:

| the script | the session |
|---|---|
| which documents sit at which rank **on this machine** | what each of them *says* |
| which of them exist, and how long each is | whether a statement is a pointer, a seam answer, or a copy |
| which plugins are enabled and where their pages live | which side wins when two of them disagree |
| echoing the two slices that are already gated | filing what it found |

So the script's output is an **agenda**, not a verdict. It ends by printing exactly that hand-over.

## The two slices that are already mechanical

#1380 recorded two greps as proportionate, and both shipped. The report **echoes** them by calling the
same two functions rather than rebuilding either -- one definition each, the way `check-branch-entry`
calls `open-pr`'s own:

| detector | what it reads | its caller |
|---|---|---|
| `Get-RetiredDocNameMention` ([#1389](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1389)) | a **filename** this workflow's branch document has been renamed away from | the `consumer-prose-sessioncheck` hook |
| `Get-SupremacyDeclaration` ([#1415](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1415)) | `CLAUDE.md` sitting **directly beside** `wins`/`wint` -- the rank order stated upside down | the `consumer-prose-sessioncheck` hook |

**One caller for both, because there is one script.** Each detector was built with its own entry script
and its own hook -- `check-retired-doc-name.ps1` / `retired-doc-name-sessioncheck` and
`check-supremacy-declaration.ps1` / `supremacy-declaration-sessioncheck` -- and
[#1421](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1421) folded the pair into a
single `check-consumer-prose.ps1` behind one hook, one day later and before either had shipped. So those
four names are history: `consumer-prose-sessioncheck` is the only one a consumer has ever seen.

They are labelled as already-gated in the output, so a clean line here is not read as coverage that
hook does not give. **In the repo that publishes the workflow both are skipped**, exactly as their own
entry script skips it -- its pages narrate a rename history and state the rank correctly, so the
detectors would be right about the strings and wrong about the repo.

## What it prints

Four blocks, in this order:

1. **RANK 1** -- the `*-portable.md` pages of every plugin **enabled here**, `dkj-policy`
   first. That order is the top rung's own: where two plugin pages speak to the same question, this
   plugin's page wins and a companion's (`dkj-policy-bwj`) is an extension, never an override. Plugins are
   **discovered, not listed** -- a plugin shipping no portable page is not a legislator and drops out
   silently; one that could not be located at all gets a `[not located]` line, because whatever it
   legislates was not read.
2. **RANK 2** -- this repo's own `dkj-policy/` pages.
3. **RANK 3** -- the always-on closure: `CLAUDE.md` and everything it `@`-imports.
4. The two echoed slices, then the hand-over.

Ranks 2 and 3 are the **#1380 corpus**, and it is not re-derived here: `Get-CheckProseCorpus` supplies
the closure and `Get-ConsumerProseDocuments` decides which of those documents a prose check may read.
Every exclusion in there is load-bearing -- the changelog and `releases/` (a folded entry correctly
names the rule of its own day), plugin-shipped payload, and the per-branch document.

**Everything printed out of your files is sanitized**
([#1419](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1419)): this output is read back
into a session, so a raw echo would let untrusted text choose how loudly it is reported. A quoted
phrase is a preview -- square brackets show as round ones -- and the output says so when it quotes one.

## What you do with it

For every statement in a rank 2 or rank 3 document that speaks to something rank 1 legislates -- the
branch and PR mechanics, the branch document, the gates, the tier model, the fold, the release cut --
classify it:

- **POINTER** -- it names the page that owns the answer and stops. Correct; leave it.
- **SEAM ANSWER** -- it states *this* repo's answer to a seam a rank 1 page asks about. Correct.
- **RESTATEMENT** -- it says the law again in its own words. A copy. **Report it whether or not it
  currently agrees**, because agreeing today is what a copy does.

Where a restatement **contradicts** the page above it, say which side wins by the rank order and quote
both lines.

**And check the fourth move before you report anything.** A law a rank 1 page explicitly **declines** to
answer -- `cut-release`'s *"No seam, deliberately"* is the measured instance
([#1388](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1388)) -- is not a copy of
anything: the plugin asked the consumer to write that answer down, and its prose is the only place it is
ever written. The two are told apart by asking whether a plugin page states the law's answer *anywhere*.

## What it deliberately does not do

| | |
|---|---|
| **it never edits your `CLAUDE.md`** | repairing a contradiction is an ordinary branch + PR in the repo that owns the file. A script rewriting always-on prose on its own would be making exactly the unreviewed change this ranking exists to prevent. |
| **it does not read the plugin pages for you** | it prints their paths. A run that summarised them would be a third copy of the law, in the one place nobody looks for it. |
| **it does not refuse** | the verdict is not the script's. It exits 0 once it can answer at all, and exits 1 only when there is no checkout to point at. |
| **no `gh`, no network** | every input is a file on this machine, so it answers in a consumer with no token. |

**Not to be confused with `check-consumer-drift.ps1`**, which is source-repo-only and compares copies of
**agent defs** against the canonical ones. Same word, different subject: that one is about files that
were duplicated, this one about laws that were paraphrased.

## Parameters

The script takes none you would type. `-RootOverride` and `-RootDocument` exist for the test suite --
a fixture root, and an always-on root the suite can point at a scratch document tree.
