# CLAUDE.md — the dkj-policy constitution

**This is the one `CLAUDE.md` every repo running `dkj-policy` reads its rules from** (Dave, issue
[#2374](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2374), September 23, 2026). A
repo's own `CLAUDE.md` holds **only** the `@`-import lines — this file, plus a companion extension
`CLAUDE.md` where one is installed, plus any other plugin import — **and nothing else**. It carries no
rules of its own, and no facts about the repo either: **facts about the repo (its trunk, whether it is
public, who owns it, what it is for) go in an unscoped rule your own tooling loads every session** —
e.g. `.claude/rules/<name>.md` — **and a fact that belongs to one specialist alone goes in that
specialist's own lens.** That split exists because a consumer's hand-written constitution kept
contradicting the plugin it had installed, and two copies of one rule always drift; keeping `CLAUDE.md`
down to imports alone is what makes that drift structurally impossible rather than merely discouraged.

**So nothing outside the imports restates or overrides a rule here.** Where a repo genuinely needs a
rule to read differently, the route is an `inbound` issue on this plugin's source repo, not a local
edit. A local override is exactly the drift this file replaces. The mechanics these rules name (the
branch document, the gates, the fold, the cut) are on
[`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md), which sits beside this file and at the same
rank. A companion plugin may ship an extension `CLAUDE.md` of its own. It extends this file and never
overrides it.

**"The owner" below means the person the repo's own facts name as its decision-maker.**

---

## Safety rules

These rules take precedence over any convenience.

### Never without the owner's explicit permission

- **Merging work with a visible result.** If a change produces something the owner has to judge by
  eye (a frontend, styling, rendered output, an artifact), the branch stops and reports instead of
  merging. No automated gate can prove that something *looks* right.
- **A release or version bump** (raising a plugin or package `version`, creating a tag) is done only
  on explicit request. **The closing steps of a cut that was asked for are covered by that request**,
  up to and including publishing the release document. The bump and the tag are the irreversible act,
  and stopping again at the last step of the same checklist is a rubber stamp. A separate **live stage**,
  where a repo has one, is not part of this: a release document describes a version, while a live push
  changes what customers see. The same request also covers the **preparation a cut cannot run without**
  (opening a new major's section, and repointing the test that pins it). It covers only that
  preparation, and only once a cut has actually been asked for.
- **`git push --force`** on any branch, **`git reset --hard`**, and **`git rebase`** on a shared
  branch.
- **Publishing anything externally** beyond the normal PR flow: a gist, an external post, an issue on
  somebody else's repository. **The inbound route is carved out of that by name.** Filing an `inbound`
  issue on the source repo of a plugin this repo consumes needs nobody's permission. It is the one
  outward-facing act a session performs unprompted, and the only way a defect found in a consumer
  reaches the tree that can repair it. What applies to it is the ordinary filing bar: verify the
  finding still stands, search that tracker first, one subject per issue.

### Never directly on the trunk — via branch + PR

All changes go through a branch and a pull request, one change per branch. **Whether that PR waits for
the owner depends on one question: does the owner's own look add something the gates cannot?**

- **By default, it does not wait.** Once the work is finished, committed and the gates are green, the
  whole movement runs in one go (open, merge, fold) with no intermediate question. This covers the bulk
  of the work: scripts, tests, config, docs, agent defs, research. The gates prove that kind of change,
  and anything that does turn out wrong is one revert PR away.
- **The exceptions stop and wait for the owner's word.** There are two: a **visible result** (see
  above), and anything **irreversible or outward-facing** (a release, a version bump, a tag, repo
  settings or rulesets, publishing outside the PR flow).
- **The owner keeps the wheel in both directions.** They can pull any single piece of work under the
  exception when assigning it ("this one I want to see first"). An explicit PR command ("open the PR",
  "take it live") counts as approval for the whole movement.

The reasoning: substantive approval is given in the conversation *before* the work is built, not at
the merge button afterwards. A merge button that stops every PR is a rubber stamp, so it is a
checkpoint only where it genuinely buys something (Dave, July 27, 2026).

**Three bounded exceptions land directly on the trunk.** Read end to end they are one procedure: the
**fold commit** after a merge, the **release commit**, and the **release-notes commit**, the last two
only on explicit request. Each is bounded to the paths it names, and the bounds and how each runs are on
[`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md). An exception is only safe while it stays the
size it was granted at.

---

## General working practices

- **Lessons learned are secured in the docs, not just in memory.** When a session learns something
  that must hold next time, it goes into the layer that owns the rule. Where the lesson is about the
  shared system, that layer is the plugin's source, reached through the inbound route. Where it is
  about this repo alone, it goes in the repo's own lens. A memory note alone is too noncommittal.
- **A reported finding's *reason* is verified before it is repaired, not just its symptom.** A report
  says what went wrong and why, and the *why* is an inference by someone looking from the outside. Read
  the code, doc or output that would have to be true for that explanation to hold. A fix built on an
  unverified reason satisfies the report and is still wrong, and now it carries a citation.
- **Within a branch, be proactive about structure.** Create new folders and files as a topic arrives,
  without asking about the file structure itself. Do ask about the content if it is sensitive or
  uncertain.
- **Split a file wherever the split keeps loaded context smaller** (Dave, September 24, 2026). What
  every session pays for is whatever loads before the work is known, so a document is divided by
  **when** its content is needed, not by topic or importance. What governs every turn stays on the
  always-on path. What applies only once a particular file, situation or task is in front of you moves
  to where it loads on demand: a `paths:`-scoped rule, a manual read at the handover, a skill page. Split
  as far as that helps, and no further. Halves that always load together save nothing and cost a hop, and
  a rule that must hold whichever files a turn touches stays always-on, because an on-demand rule is gone
  after a compaction until something reloads it. Each half names the other, so neither becomes a file
  nothing reads.
- **When priority is unclear, ask about deadlines or urgency** instead of guessing.
- **Approval questions are rare, not the norm.** Interrupt the owner only for what is irreversible,
  outward-facing or genuinely risky. Routine work (git, bash, config, branches, commits, tooling,
  handing a deliverable to the next link of an agreed chain) is executed and reported, not asked about
  first. When in doubt, pick a sensible default, execute it and report it. The PR exceptions above are
  the named cases where waiting is the rule.
- **Nothing confidential in a public repo.** Where the repo's own block says it is public, no personal
  information, credentials or secrets go in it.
