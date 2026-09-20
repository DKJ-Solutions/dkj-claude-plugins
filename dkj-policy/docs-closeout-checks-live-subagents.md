## docs/closeout-checks-live-subagents

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

Dave, September 20, 2026, after reading a close-out that said *"the session can be cleared"* while a
subagent this session had dispatched was still running: **"leg het vast in Chris's body"**.

#### What happened, in one paragraph

Six agents were dispatched across the #2179 migration -- four to move a retired page into the lenses,
then a copy editor and a code reviewer in parallel on the diff. Five sent a report and a
`task-notification` saying *completed*. The sixth reported and kept running: its own report said it had
launched `code-review`, that the skill had forked to the background, and that it was not going to sit on
that clock -- which is the whose-clock rule on the persona page being obeyed correctly. The report was
the longest and most complete of the six and arrived in the same shape as the five that were done, so it
was read as the end of that agent's work. `ListAgents` said `running`; the completion notice was still 37
minutes out. The requester caught it; the session did not.

#### Where each half goes, and why they are not in the same file

The **rule** goes in the persona body, which every consumer's orchestrator loads on every turn: read the
agent list before the word *cleared*, rather than inferring it from the last message received. The
**evidence** goes in the manual, which is read on demand -- this repo's own convention, and the
always-on budget gate's own instruction: *"the decision belongs on the always-on path; the evidence for
it does not."*

**It is deliberately not a rule about waiting.** The whose-clock rule is untouched, and an orchestrator
that starts sitting through its own subagents' background work has traded a wrong receipt for a wasted
session. What changes is the sentence, not the schedule.

### CREATE

- [x] The rule, in `specialist-01-01-persona.md`, beside the two paragraphs that already govern the word *cleared*
- [x] The measured instance, in `specialist-01-01-manual.md`, under the delegation section

### TEST

- [x] `check-plugin-integrity.ps1` green -- including the shared-block check over all 30 agent defs and
      personas, which is what proves the new paragraph did not land inside a generated block
- [x] The suites, via `open-pr`'s own gate
- [x] The always-on budget gate -- **and reading its answer rather than trusting it.** It reported
      `NOT growing` on a branch that adds 621 B to a persona body, because it measures the marketplace
      CLONE and the clone only advances at a release. Filed as
      [#2187](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2187); the weight is deferred
      rather than cancelled, and the branch that meets the refusal later will be one that added nothing.

### DEPLOY: docs/closeout-checks-live-subagents

The orchestrator now checks whether its own subagents are still alive before it says the session can be
cleared. A delegated agent announces its **report**, and a report is not a finish -- it can hand back
while work it forked is still running -- so the persona body says to read the agent list rather than
infer it from the last message received: a completion notice is the signal, a hand-back is not.

**It is deliberately not a rule about waiting.** The whose-clock rule is untouched, and an orchestrator
that starts sitting through its own subagents' background work has traded a wrong receipt for a wasted
session. What changes is the sentence, not the schedule: name the agent that is still running and what
its death would cost, and let the requester decide.

The measured instance behind it -- six agents on one assignment, five of them done and reporting alike,
the sixth reporting identically with 37 minutes still to run -- is in Chris's manual, which is read on
demand. That split is this repo's own convention and the budget gate's own instruction: the decision
belongs on the always-on path, the evidence for it does not.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-subagents-alpha` gets this on its next release, and it lands on the one line a
requester acts on without re-checking. The failure it removes is cheap almost every time -- a
backgrounded review dies with the harness and usually had nothing to say -- which is exactly why it
survives: a receipt that is wrong for free is a receipt nobody corrects. Here it was caught by the
requester rather than by the session.

**Score:** 2

#### Pull Request

The close-out checks whether its own subagents are still alive before it says cleared
