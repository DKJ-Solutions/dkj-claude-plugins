# Changelog

## [Unreleased]

**8 / 10 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3658-connector-check-skip-drift · 20261029-193134Z

A session start in this source checkout no longer waits on the agent-def drift lint: `connector-sessioncheck` now passes `-SkipDrift` to `check-connectors.ps1` by default, which took the hook from about 5.0 s to 2.3 s and the whole session start from 5.9 s to 3.0 s (one machine). The drift step ran one `check-consumer-drift.ps1` per registered consumer in sequence and found nothing on any of the three. It still runs in a manual `scripts/sync/check-connectors.ps1`, and `-IncludeDrift` puts it back in the hook. Consumer machines never took that path, so nothing changes there.

**Score:** 3

#### What makes this deploy extra special

N/A -- only the workshop path ran the drift step, and that path exists only in this source checkout; a plugin user's session start is unchanged.

**Score:** N/A

#### Pull Request

The connector session check skips the drift lint, so a session start here takes about half the time

Plugins: dkj-policy

[PR #3668](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3668)

---

### DEPLOY: fix/3657-product-server-restart-after-trunk-move · 20261029-192014Z

The dev-preview hook no longer hands out a product that serves stale code. On every session start, `/clear`
included, it starts the toolbox first and then waits (up to 20 s) for the dispatcher's trunk sync to finish
before it starts or reuses the product. A product the hook itself started before HEAD last moved (a trunk
sync or a checkout) is stopped and started again on its port, and the line reads `(restarted: the checkout
moved after it started)`. A plain commit does not count, since the server already serves that tree, and a
server somebody started by hand is reused as before.

**Score:** 2

#### What makes this deploy extra special

In every repo with a product port, a merge pulled in by the session-start sync now shows up on that port
right after `/clear`, without restarting the server by hand.

**Score:** 2

#### Pull Request

dev-preview restarts a product server older than the trunk sync

Plugins: dkj-policy

[PR #3667](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3667)

---

### DEPLOY: feat/sessionstart-spinner-timing · 20261029-185628Z

A session start now says what it is waiting on and how long it took. Every SessionStart hook of the
enabled plugins carries a `statusMessage`, so the spinner names the step, and the session-check
dispatcher ends its message with one line such as `sessionstart: 5.9 s in the dispatcher -- prep 0.5 s
(trunk-sync), checks 5.4 s (slowest: connector 5.0 s, ...)`. The line goes to the person only, never into
the model's context. The first measurement already names the slow step: the connector check.

**Score:** 3

#### What makes this deploy extra special

Whoever runs these plugins now sees a named spinner while a session starts and a measured duration once
it has, instead of a silent pause.

**Score:** 3

#### Pull Request

SessionStart shows a spinner message and reports how long it took

Plugins: dkj-policy, dkj-solutions, dkj-subagents-alpha

[PR #3659](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3659)

---

### DEPLOY: feat/plugins-cards-installed-vs-marketplace · 20261029-182230Z

The toolbox's Plugins card and page are now **Installed plugins**, drawn as a plug in its socket. The
product port's Plugins card and page are now **Marketplace**, drawn as a storefront. Connectors draws
a chain link. The two pages kept their `/plugins` URLs, and the three cards no longer share one plug.

**Score:** 2

#### What makes this deploy extra special

Every repo running dkj-policy shows the toolbox card and page as Installed plugins instead of Plugins.
That is a rename the user will notice, and nothing for them to do.

**Score:** 2

#### Pull Request

Name the two Plugins cards apart: Installed plugins and Marketplace

Plugins: dkj-policy

[PR #3656](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3656)

---

### DEPLOY: feat/3649-btn-primary-bold · 20261029-173129Z

The label of a house `.btn--primary` is bold (700) instead of semibold (600), the touch variant
`.btn--touch.btn--primary` included, so the filled main action stands out further from an outline button.

**Score:** 2

#### What makes this deploy extra special

An app built on the house style shows every primary button in bold once it takes this version, with
nothing to change in its own layer (asked for from `dkj-music-library`).

**Score:** 2

#### Pull Request

House style: the .btn--primary label in bold

Plugins: dkj-policy

[PR #3655](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3655)

---

### DEPLOY: feat/3648-btn-hover · 20261029-172607Z

A house `.btn` now answers the pointer: an outline button takes the `--paper-3` hover tint with a
`--paper-4` edge, and a `.btn--primary` fill moves 15% toward `--fg-1` -- darker on a light theme,
lighter on a dark one, so its label gains contrast either way. A disabled button keeps still. The plain
`.btn` also gets the `--muted` keyboard focus ring the primary and touch variants already had, now one
rule for every variant.

**Score:** 2

#### What makes this deploy extra special

An app built on the house style shows hover feedback on every button once it takes this version, with
nothing to change in its own layer (asked for from `dkj-music-library`).

**Score:** 2

#### Pull Request

House style: a hover and focus state for .btn and .btn--primary

Plugins: dkj-policy

[PR #3654](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3654)

---

### DEPLOY: feat/3645-cut-certified-round-one · 20261029-145512Z

A release cut whose `main` already equals `origin/main` now asks the CI run that the push to the
trunk started whether it has proved that exact commit green, before running the lint and test gates
locally. On green it skips both and says so; a run still in flight is waited on for up to five
minutes; anything else runs the gates as before. On the v5.36.0 cut the local gate was about half of
the 15 minutes. The certificate reader is now one function, shared with the catch-up (#3155).

**Score:** 3

#### What makes this deploy extra special

A maintainer cutting a release in a repo that names its CI check (`Get-CiTestCheckName`) and slug
sees the cut skip the local gate when CI already proved the commit, and finish several minutes
sooner.

**Score:** 2

#### Pull Request

cut-release: skip the round-one local gate when the main-push CI run certified HEAD

Plugins: dkj-policy

[PR #3652](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3652)

---

### DEPLOY: feat/3646-cut-release-step-marks · 20261029-144441Z

The Stopwatch now splits a release cut into its steps instead of filing most of it under "Other tool calls"
([#3646](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3646)). `cut-release.ps1` marks each step it
enters in the opt-in step log, the way `ship-pr.ps1` already did (#3338): the origin check and guardrails, the
lint gate, the test gate, the origin check after the gates, the release builds, the notes, overview and version
bumps, the commit and tag, and the push. A cut's call is now a phase of its own, `Release cut`, and a run's page
cuts it at those marks, so a change meant to make the next cut faster shows which step it moved. Runs already
read stay as they were cached. A cut from before this release, or on a machine without the step log, stays one
`Release cut` phase.

**Score:** 3

#### What makes this deploy extra special

The step log is opt-in (`DKJ_RUN_STEP_LOG`), and this repo is the one that turns it on, so a consumer sees no
change unless it does the same.

**Score:** N/A

#### Pull Request

cut-release marks its steps, and the Stopwatch splits a cut by them

Plugins: dkj-policy

[PR #3653](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3653)

---

### DEPLOY: fix/3647-cut-release-notes-subject · 20261029-143052Z

The release cut's closing output now prints the release-notes commit to run, with the version filled in:
`git commit -m "release: vX.Y.Z release notes"`, beside the `git add` and `git push` around it
([#3647](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3647)). The Stopwatch ends a release run
only on that exact subject and stays silent on any other. At v5.37.0 the notes were committed under a
different subject and the run had to be closed by hand. A guardrail test holds the printed subject to the
Stopwatch's own regex, so the two cannot drift apart.

**Score:** 2

#### What makes this deploy extra special

A maintainer cutting a release copies one printed line instead of composing the subject. The Stopwatch then
times the cut to its end without a manual repair.

**Score:** 1

#### Pull Request

cut-release prints the release-notes commit line

Plugins: dkj-policy

[PR #3651](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3651)

---

### DEPLOY: fix/card-grid-padding · 20261029-141612Z

The release-notes, stopwatch and test-gate pages put their card grid in the house `.card-grid`, so the
group under the h1 gets the same padding and surface as every other toolbox page instead of cards that
touch its edge. On release-notes the version and its date now stand `--spacing-1` apart, as a title
over its sub line does everywhere else, and the LIVE chip takes the house tag's size, so it sits inside
the card's padding without making its row taller -- which had left an empty strip at the bottom of
every other card in it.

**Score:** 2

#### What makes this deploy extra special

A user of the toolbox sees three pages line up with the rest of the hub; nothing to act on.

**Score:** 2

#### Pull Request

Put the house card-grid on the three page grids that lacked it

Plugins: dkj-policy

[PR #3650](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3650)

---

