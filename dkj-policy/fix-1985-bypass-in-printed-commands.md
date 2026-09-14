## fix/1985-bypass-in-printed-commands

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

#### What was measured, and where

[#1985](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1985). Running this repo's own
`update-plugins` skill, the command its page prints failed twice before it ran once:

```
File ...\scripts\task\update-plugins.ps1 cannot be loaded because running scripts is disabled on
this system.
    + FullyQualifiedErrorId : UnauthorizedAccess
```

`Get-ExecutionPolicy -List` on this machine answers `Undefined` in all five scopes -- the Windows
client default, `Restricted`, which refuses every `.ps1`. The command succeeded unchanged the moment
`-ExecutionPolicy Bypass` was added.

#### The asymmetry, which is why nothing was ever red

Everywhere this tree controls the invocation it already passes `Bypass`: all 8 hook entries in the
plugins' `hooks.json`, all 7 CI workflows, every script-to-script call, and the allowlist in
`.claude/settings.json`. Only the lines a **reader** is told to type were bare. The gates never execute
those, so the session start here was entirely green while the first command of the skill page it had
just loaded could not run.

This is not [#334](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/334), which is about a
consumer's fresh profile and was repaired by naming the prerequisite
(`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`) in `../INSTALL.md`. That prerequisite is real
and, once applied, makes the bare form work. The defect here is one level over: the pages depend on it
having been applied while the machine-facing layer deliberately does not, and no page says so.

### CREATE

- [x] Every printed invocation in the live document set carries `-ExecutionPolicy Bypass` -- 85
      occurrences across 32 files: 28 `SKILL.md`, `../UNINSTALL.md`, `CONTRIBUTING.md`,
      `../plugins/dkj-policy/CONTRIBUTING-portable.md` and Sylvester's manual. The 16 occurrences in
      the archived release notes under `releases/` are left exactly as written -- they are history and
      are never rewritten.
- [x] `.claude/settings.json`'s one bare allowlist entry (the `cut-release` path) brought to the same
      form. It was the only entry in the tree that did not match what the pages now print.
- [x] `bootstrap.ps1` writes the Bypass form into a **consumer's** `settings.json` -- six allowlist
      patterns and the stub hook command. This is the functional half: a `permissions` pattern reading
      `powershell -NoProfile -File *` stops matching the moment the pages print the other form, and a
      hook command in the bare form is launched by the harness rather than from a shell that already
      carries the policy.
- [x] `record-suite-durations.ps1`'s help said `` `powershell -NoProfile -File` -- the form every doc
      in this repo uses``. True when written, false after the sweep above, so it names the current form.
- [x] Check 42 in `../scripts/lint/check-plugin-integrity.ps1`, so this cannot drift back: a printed
      invocation carrying `-NoProfile` must also name an `-ExecutionPolicy`.

#### Why the check has the shape it has

**The subject is an invocation that already carries `-NoProfile`**, and that narrowing is the whole
rule. Measured without it first: 12 findings over the tree, every one correct prose naming the
invocation *mode* rather than instructing anybody -- ``across `powershell -File` a comma list is cast
to a single number``. A check born needing an exemption list is the shape this repo declines, which is
check 22's own measurement one argument over. With the narrowing: 85 subjects, 0 findings, 0 exemptions.

**And that discriminator is structural rather than a heuristic**, which is what makes it safe to lean
on: `powershell.exe` stops parsing its own flags at `-File`, so every flag a runnable line carries has
to sit before it. `-NoProfile` is what the house style puts there and what prose naming the mode never
bothers with -- a property of the command's grammar, not a guess about how a line looks.

**What the check does NOT reach is written into its own coverage note**, because a gate that hides a
gap is worse than one that names it: matching is per physical line, so a command written with a
backtick continuation between `-NoProfile` and `-File` is neither a finding nor a subject, and the
figure will not show the hole. Measured -- nothing here is written that way, and every multi-line
command in the tree breaks *after* `-File`, where the invocation is already complete on the first line.
Joining lines before matching would change what every line number in this check means, which is a real
cost for a shape nobody has written.

**The value is not pinned.** `RemoteSigned` passes. The rule is that the policy be *answered*, not that
this gate legislate which answer -- a repo that has chosen `RemoteSigned` has made the decision the
check exists to force.

**Fences are not masked**, unlike checks 10, 11 and 33. Their subject is prose and a fenced example is
an illustration; here the fenced block **is** the command a reader pastes, so masking would empty the
subject set entirely.

**The `.ps1` layer is deliberately not a subject.** The same rule over the script layer is born at 43
source findings -- mostly `.EXAMPLE` blocks in comment-based help -- which is a sweep to propose rather
than a regression guard, exactly the trade check 41 records this repo declining at 71. Filed as
[#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989) rather than swept in here.
A `&` call would be wrong to flag in either layer: `-ExecutionPolicy` sets
`$env:PSExecutionPolicyPreference`, which child processes inherit, so the suites' own
`& powershell -NoProfile -File $child` invocations are correct as they stand. Measured, not assumed.

#### Bypass or RemoteSigned -- why both, deliberately

`../INSTALL.md` prescribes `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` as a one-time machine
prerequisite; this branch puts `-ExecutionPolicy Bypass` on the command instead. They do not conflict
and neither replaces the other: the prerequisite fixes a **machine**, the flag fixes a **command**, and
a reader who has done the first loses nothing by the second. The per-command flag is process-scoped --
it never calls `Set-ExecutionPolicy` and leaves the machine's own default untouched -- which is
materially safer than what a reader improvises when a bare command dies with `UnauthorizedAccess`,
commonly a permanent `Unrestricted` at machine scope. Check 42 accepts either value for the same
reason: the rule is that the policy be *answered*, not that a lint gate pick the answer.

### TEST

- [x] `check-plugin-integrity.ps1`: **0 error(s)**, with `[exec-policy] checked 85 ... 0 finding(s),
      with 12 match(es) skipped as prose`.
- [x] Probed against the hazard rather than only asserted green: one page reverted to the bare form
      reports `[exec-policy] plugins\dkj-policy\skills\claim-issue\SKILL.md:32` and fails the run.
- [x] `check-plugin-integrity-docs.tests.ps1`: **151 asserts**, seven of them new -- the defect
      reported with file and line, prose *not* reported, an archived note left alone, and
      `RemoteSigned` clearing it.
- [x] The check-22 fixture was carrying the bare form itself and now carries the Bypass form, so this
      suite's own page does not model the defect the next check forbids.
- [x] `build-shared-scripts.ps1`: 0 mirrors updated, the rest already in sync.
- [x] Reviewed in parallel by Victor (code), Edith (copy) and Sebastian (security).
      **Edith found a real defect and it is repaired here**: the check's header and its list entry
      both claimed *101 subjects*, and one sentence carried 101 and 85 side by side for the same
      measurement. 101 is the probe's figure over the whole markdown tree; 85 is the check's, because
      `$lifecycleFiles` has already removed the 16 in history. The code printed 85 all along.
      Victor's two points are folded in above -- the structural reading of `-NoProfile`, and the
      line-continuation gap now named in the coverage note.

### DEPLOY: fix/1985-bypass-in-printed-commands

Every command this repo prints for a person to run now carries `-ExecutionPolicy Bypass`, and a new gate
check keeps it that way. A fresh Windows profile sits at `Restricted`, which refuses every `.ps1`, so the
form 32 documents printed died with `running scripts is disabled on this system` before the script's first
line -- measured in this repo, where all five execution-policy scopes read `Undefined`
([#1985](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1985)).

**Nothing was ever red, and that is the part worth keeping.** Everywhere this tree controls the
invocation -- 8 hook entries, 7 CI workflows, every script-to-script call, the allowlist -- it already
passed `Bypass`. Only the lines a reader types were bare, and no gate executes those. So the session
start was green while the first command of the page it had just loaded could not run.

**Check 42 is narrowed to invocations that already carry `-NoProfile`**, and that is the rule rather
than a detail. Without it the check is born with 12 findings, every one correct prose naming the
invocation mode; with it, 85 subjects and zero exemptions. The value is deliberately not pinned --
`RemoteSigned` passes -- because the rule is that the policy be answered, not that a lint gate pick the
answer. Fences are not masked, unlike the other document checks: here the fenced block *is* the command.

**The `.ps1` layer is filed rather than swept**
([#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989)). The same rule over
comment-based help is born at 43
findings, which is a proposal to sweep and not a regression guard. Two sites there are repaired here
anyway because they are functional: `bootstrap.ps1` writes both an allowlist pattern and a stub hook
command into a **consumer's** `settings.json`, and a bare pattern stops matching the day the pages print
the other form.

**Score:** 3

#### What makes this deploy extra special

A consumer adopting these plugins on a Windows machine that has not been told otherwise can now paste
the commands off the pages and have them work. Before this, every printed command depended on an
`INSTALL.md` prerequisite no page named, and the failure arrived as a security exception with the
plugin's own script in it -- which reads as a broken plugin rather than as a machine setting. Nothing
to run on an existing machine: the change is in what the pages say and in what `specialists-init`
writes into a new consumer's allowlist.

**Score:** 2

#### Pull Request

Printed powershell commands carry -ExecutionPolicy Bypass
