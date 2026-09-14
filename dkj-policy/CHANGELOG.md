# Changelog

Everything merged since the last release sits under **`## [Unreleased]`**, **newest first**: **one `###` per
change**, and under it two named `####` sections. The `###` heading is the change's own —
`` DEPLOY: `<branch>` `` and the moment it
landed — and the text directly beneath it answers what a reader arrives with: what the change deploys to
`main`. Then `#### What makes this deploy extra special` for the second audience, and `#### Pull Request`.
Every level here moved one deeper on August 26, 2026, when the pending section above them was introduced and
the development cycle beside them shifted to match; entries written before that day carry the whole set one
level shallower and are read exactly as they always were.
The tier numbers live in the parser rather than in any heading. That second heading said `PR` rather than
`deploy` for one day, August 24 to 25, 2026, and `change` for the four days before that; every wording it
has ever carried is still read, so an entry below written under any of them is parsed exactly as it always
was — including the four written under `PR`, which are in the list below right now. Entries written
before August 23, 2026 carry that first answer under a `###` question of its own with the second nested
at `####` beneath it; entries before August 16 carry the longer set of headings that shape replaced, and
every earlier shape is read exactly as it always was. Every release ever cut is listed in
[`releases/history.md`](releases/history.md) — each with its date, type and title, and a link to what that
release was worth. How the mechanism works (entry files, the Significance sections, folding) is described in
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

Each change declares its own **reach**, and per audience how much it **weighs** there — one `##### Tier N`
sub-section per tier where a repo writes them numbered, each closing with its score; here the audience tier
carries a named heading beside the others instead. This list does not order on it: it is a record of what
landed, so it reads in the order things landed. What the declaration decides is what the **release
documents** lead with — they rank themselves on it — and what may be released at all, because **the bump
follows the highest tier pending**: **tier 0 only earns a patch**, **tier 1 or higher earns a minor**, and
a **major** recaps ten minors. So a changelog holding nothing but tier 0 is a patch waiting to be cut, not
a release with nobody to announce it to.

**The line directly under `## [Unreleased]` is a tally, and nobody types it.** It reads
`**4 / 9 minor entries**`: how many of the pending entries reach the audience this repo publishes to, out of
how many are waiting for the next release, and which bump that work has earned. The two numbers answer
different questions and may differ — the fraction counts tier 2 and above, the bump follows tier 1 and
above — so `**0 / 8 minor entries**` says nothing reaches a subscriber while the version still owes a minor
for what reaches management. It is
**derived from the entries below it every time it is written**, by the fold that adds one and the cut that
removes them all, so it holds no state of its own and a hand-edited count is simply corrected on the next
fold. It ends with an HTML comment that marks it as machine-written; that marker is what the next run
replaces, so anything else written in this space is left alone.

---

## [Unreleased]

**7 / 8 minor entries** <!-- pending-tally -->

### DEPLOY: fix/1998-templates-in-script-set · 20260914-182517

`Get-PsScriptFiles` -- the file set five script-layer checks share -- took three named subtrees inside
`plugins/`: `skills/`, `scripts/` and `hooks/`. One tracked file sat in none of them, and it is not an inert
template: `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1` is copied by `adopt-dkj-policy-bwj`
into a BWJ store repo as `.github/scripts/asana-mirror.ps1`, where it runs in that consumer's CI holding
`issues: write`. So 1812 lines this repo scaffolds into somebody else's automation had never been parsed,
held to the ASCII rule, checked for a bare Shopify call, or read for a printed command missing its execution
policy -- and a parse error in it reaches them rather than us, which is check 5's own argument for existing,
one directory over from where it was looking.

**The anchor is inverted rather than extended by a fourth name, and the choice was measured.** Today both
forms select the identical set, so the whole difference is the next subtree somebody adds: a named list is
silent about it, and this one had already failed open twice. The cost is stated at the code rather than
discovered later -- the walk is the filesystem's, not git's, so an untracked `.ps1` anywhere under
`plugins/` now enters the set where before it had to land in one of three directories.

**Born green, which was the point of measuring first.** All five checks pass over the newly-read file:
`[exec-policy/script]` coverage moves 202 -> 203 and `[parse]`, `[script-ascii]` and `[shopify-cli]` move
312 -> 313, with `Summary: 0 error(s)` before and after. `[section-number]` is unchanged at 159, because
the file carries no column-0 `# --- ` markers at all -- an empty subject set rather than a miss.

**Score:** 3

#### What makes this deploy extra special

The three new scenarios pin the property and not the arithmetic: put a defect in a plugin's `templates/`
and the gate must find it, whatever the file count happens to be that week. And they were proved to
discriminate rather than assumed to -- with the old anchor stashed back in place, three of the five asserts
go red, and the two that stay green are the ones guarding against a repair that widens the set by accusing
whatever it newly reads.

**Score:** 2

#### Pull Request

Bring plugins/**/templates/** into Get-PsScriptFiles, so the script-layer checks read what this repo scaffolds into a consumer's CI

[PR #2006](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2006)

---

### DEPLOY: fix/1994-allownull-on-record-predicates · 20260914-175823

Two predicates in `check-report-lib.ps1` -- `Test-PluginInstalledHere` and `Get-RecordShape` -- each opened
with an `if ($null -eq $InstallRecord)` line that had never once run. A `Mandatory` parameter rejects
`$null` during BINDING, with `ParameterArgumentValidationErrorNullNotAllowed`, before a line of the body
executes, so each function's documented answer for that input was a promise its own signature broke.
`[AllowNull()]` makes both reachable, which is the choice the sibling `Get-PluginUpdateScope` already made
deliberately for the same reason.

**The three answers stay different, and that is the point.** They are not one contract repeated: the
permissive predicate answers `$true` because an absent authority is not evidence of absence, the shape
predicate answers `$null` because it may suppress a finding and never invent one, and the scope function
answers a usable `project`/`default` because every caller needs something to put in a command. Three
answers to one input is why the attribute is repeated three times rather than factored into a shared
validator.

**One caller proved the state is real.** `check-policy-drift.ps1` sets `$installRecord = $null` and fills it
inside a `try`/`catch`, then guarded its call site with `if ($installRecord -and ...)` -- a clause
hand-rolling the contract the signature would not honour. It is gone, with the reasoning left at the line,
and the behaviour is identical: `$true` means the guarded branch is not taken either way.

**The issue's reason was half right, and the half that was wrong is recorded in the code.**
`Get-RecordShape`'s doc never promised a `$null` answer for a `$null` argument. Repairing on the quoted
reason would have written a promise into the doc that was never there; the argument that does hold is the
direction-of-error rule its suites already pin.

**Score:** 2

#### What makes this deploy extra special

Nothing here was broken today -- `Get-InstallRecord` never returns `$null`, so no run has ever reached the
binder. That is exactly what makes it worth four asserts rather than a one-line edit: a latent contradiction
between a doc and a signature is invisible until somebody writes the caller that meets it, and #1986
measured that happening, in this same file, to a new sibling written from the same template.

**Score:** 1

#### Pull Request

Make the null guards in Test-PluginInstalledHere and Get-RecordShape reachable

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2004](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2004)

---

### DEPLOY: docs/1990-bwj-plugin-no-work-stale · 20260914-173105

`CLAUDE.md`'s repo slot no longer groups `dkj-policy-bwj` with the three add-on teams as having no
work in this repo. It now says what is actually true since September 14, 2026: three of its four
chapters still have none (this repo has no Shopify store), but its ticket-handling chapter does,
because Dave admitted this repo as a third permitted target at its own gate.

**Score:** 2 -- a documentation correction with no functional effect; worth having right so a future
session does not read the old sentence and wrongly rule out `dkj-policy-bwj`'s `report-issue` skill
for this repo's own inbound findings.

#### What makes this deploy extra special

N/A -- `CLAUDE.md` is this repo's own governance document; it is not shipped to consumers.

**Score:** N/A

#### Pull Request

CLAUDE.md still groups dkj-policy-bwj with the add-on teams as having no work here, after the gate admitted this repo

[PR #2002](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2002)

---

### DEPLOY: fix/1988-native-capture-utf8-claude-shim · 20260914-171155

`update-plugins.ps1` (and any other `-Utf8`/`-TimeoutSeconds` caller of `Invoke-NativeCapture`) now
runs `claude` correctly on a Windows machine where npm's global install left three PATH shims for one
bin -- previously `Start-Process` matched the extensionless POSIX script first and failed with
"%1 is not a valid Win32 application".

**Score:** 3 -- a concrete blocker on this Windows/npm install shape, fixed the moment a maintainer
touches `update-plugins.ps1` on such a machine; not a breaking change and not everyone's daily path.

#### What makes this deploy extra special

A consumer running `dkj-policy:update-plugins` on the same Windows/npm-global install shape had step
1/3 (marketplace refresh) and step 2/3 (per-plugin update) fail outright; this fix reaches them once
mirrored into the plugin via a release.

**Score:** 3 -- a clear improvement, noticed the moment they run `update-plugins` on this install shape.

#### Pull Request

Invoke-NativeCaptureUtf8 resolves 'claude' to npm's extensionless shim on Windows

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2001](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2001)

---

### DEPLOY: fix/stray-scratchpad-file · 20260914-162151

A 53 KB scratch artefact that reached `main` under a mangled filename is removed, and the lint gate grew
check 43 `[tracked-name]` so the class cannot land again.

**The file was green through every gate**, which is the part worth recording. A tool wrote its output to
an absolute path, Windows substituted U+F03A for the drive colon and flattened the separators, and the
result was a single file in the repo root named after the whole path. The lint gate, the test gate and CI
all passed it, because nothing in this tree had an opinion about what a path is *called*. Git cannot write
such a name into a Windows working tree, so on a public repo the next Windows `git clone` fails on
checkout.

**Check 43 asks what git tracks, not what is on disk** -- an untracked scratch file is what a scratchpad is
for, and a working-tree check would fire on every run made mid-task and be trained away. Three classes: a
Unicode private-use character (the one that bit), a Windows-reserved character, and a control character.
Born green over all 717 tracked paths with no exemptions. It is deliberately not a `.gitignore` pattern:
that would have to predict the mangled spelling, and not predicting it is the whole shape of the failure.

**The rule is a pure function in `check-report-lib.ps1`**, so the half that can be asserted is asserted --
including the exact U+F03A code point, both ends of the private-use range, and the two code points just
outside it. The pattern is composed from `[char]` code points rather than typed, because a private-use
character in a BOM-less `.ps1` decodes through the system ANSI code page and silently matches nothing.

**Score:** 3

#### What makes this deploy extra special

Anyone cloning this public repository on Windows after that commit would have hit a checkout failure on a
file nobody meant to publish. That is repaired for every clone made from here on; the name stays in
history, which no gate can reach, and check 43 says so rather than implying otherwise.

**Score:** 3

#### Pull Request

Remove a scratchpad artefact that a mangled absolute path put in the repo root, and gate the class

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1999](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1999)

---

### DEPLOY: fix/1989-exec-policy-in-script-layer · 20260914-160407

The script layer now prints what the document layer prints: every `powershell` invocation a reader is told
to run carries `-ExecutionPolicy Bypass`, in `.EXAMPLE` help and in the two operator hints a script writes
to the screen. 73 sites across 36 files, and check 42 has a second pass that keeps it that way
([#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989)). #1985 repaired the 85 markdown
occurrences and deliberately left this half filed rather than swept; this is that file being closed.

**The interesting part is not the sweep, it is what the same rule costs one layer down.** Over documents
check 42 was born green at 85 subjects. Over `.ps1` the identical rule is born at **93 findings**, because
a script holds three things a page does not: prose *about* the invocation form, fixture strings that must
*model* the defect, and real invocations the script *runs*. Each got a narrowing, and each was measured
before it was written rather than argued for.

**The invocation must begin its line, or a line of the string it sits in** -- a command somebody pastes is
the whole of its line, while prose naming the form is a fragment of a sentence. That takes 93 to 75, and
all 18 dropped are correct. The string half carries its weight: `check-fanout.ps1`'s hint begins the line
of the *string* and not of the file, so a file-line rule would have missed the case that most deserved
sweeping.

**A command the script runs is read off the parser, not off a leading `&`.** `-ExecutionPolicy` sets
`PSExecutionPolicyPreference`, which a child inherits, so a script-to-script call is correct bare -- and
the AST also catches the shapes an `&` rule misses: an assignment, a pipeline, the operator a line above.

**The fixture layer is excluded as a layer, not as an exemption list.** A suite that proves this check
fires has to contain what it forbids. Measured rather than assumed: of the 75 subjects exactly 2 sit under
a `tests/` folder, and both are check 42's own markdown fixtures. Born green at 73, 0 exemptions.

**Score:** 2

#### What makes this deploy extra special

A consumer runs these scripts, not just reads them. The sweep reaches the plugin-carried copies -- the
`dkj-policy` lint and task scripts, the Shopify theme scripts, `sync-roster.ps1` -- so `Get-Help` on any of
them now prints a command that survives a Windows machine sitting at the default `Restricted`, and
`ship-pr.ps1`'s hand-back hint can be pasted straight out of the terminal. Small, and invisible until the
moment somebody copies a line; that moment is exactly when the old form cost them a failed run and a
detour into why.

**Score:** 2

#### Pull Request

The script layer's printed commands carry -ExecutionPolicy Bypass, and check 42 now reaches them

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1995](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1995)

---

### DEPLOY: fix/1986-scope-from-install-record · 20260914-154645

`update-plugins` and `plugin-versions` now read the `--scope` for every `claude plugin update` off the
install administration instead of assuming `project`, and a marketplace clone whose `marketplace.json`
will not parse no longer prescribes the refresh that provably cannot repair it
([#1986](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1986),
[#1987](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1987)).

**The CLI refuses a scope a plugin is not installed at**, so the hardcoded `project` meant a
machine-wide plugin was handed the one command that could have moved it -- never updated, and the run
exited 1 on a machine where nothing was wrong. It is not only the machine-wide case: a session start
rewrites install records with no command run, flipping a `project` record to `local` and sometimes
dropping the path off one entirely, and `project` is wrong in both of those too.

**The repair went further than the report asked, because the receipt prints what the executor runs.**
`plugin-versions.ps1` carried the same hardcode in seven of its own prescriptions, so fixing only
`update-plugins.ps1` would have left one run contradicting itself in step 3. One reader --
`Get-PluginUpdateScope`, beside the two predicates already reading those records -- now answers it for
both. It returns one of the CLI's own four scope names rather than the file's string, so no byte of
`installed_plugins.json` reaches a command line; where the administration cannot answer, the run falls
back to `project` exactly as before and **says that it did**.

**All three `claude plugin install` lines are deliberately untouched.** Those prescribe installing
*into this checkout*, which is what `project` means and what the reader is being told to do -- they
are not asking where the plugin already lives.

**Score:** 3

#### What makes this deploy extra special

Both scripts are plugin-carried, so a consumer running `update-plugins` on a machine where a plugin is
installed machine-wide previously watched that plugin stay behind release after release while the run
ended in red -- and the same consumer's `plugin-versions` handed them a repair command the CLI would
refuse. Both now work at the scope the machine is actually in, and the one state the tool cannot read is
reported rather than papered over.

The `#1987` half is smaller but is the one that wastes a reader's time in a loop: a clone whose manifest
Windows PowerShell 5.1 cannot represent was told to refresh, forever. It now names the manifest, and for
the one shape whose cause is known it rules the refresh out by name and says whose fault it is.

**Score:** 3

#### Pull Request

update-plugins and plugin-versions take --scope from the install record, and a clone that will not parse no longer prescribes a refresh

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1996](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1996)

---

### DEPLOY: fix/1985-bypass-in-printed-commands · 20260914-143406

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

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1992](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1992)

---

