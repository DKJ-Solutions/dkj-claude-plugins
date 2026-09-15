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

**11 / 18 minor entries** <!-- pending-tally -->

### DEPLOY: docs/2017-bwj-four-seams · 20260915-082358

Fixes #2017: `dkj-policy-bwj` has had four chapters since inbound #1965 (the theme lifecycle), but
three documents still said "three seams" / "the last two chapters" -- the plugin's own root
`README.md`, the two manifest descriptions (`plugin.json` and `marketplace.json`), and the
`dkj-policy-bwj/README.md` chapter-history sentence. All four now name the theme-lifecycle seam
(what the theme estate owes at a push and a cut) alongside the other three, and the manifest
descriptions no longer contradict their own "Four chapters" / `THE THEME LIFECYCLE` text two
sentences later.

**Score:** 1 -- cosmetic: a stale seam count in prose and manifest descriptions, corrected before it
misled a consumer into enabling the plugin believing the theme estate was untouched.

#### What makes this deploy extra special

N/A -- internal documentation and plugin-manifest wording, reaching only this repo's own
maintainers and a consumer reading `claude plugin details` before enabling.

**Score:** N/A

#### Pull Request

fix the dkj-policy-bwj seam list to name all four chapters, consistently

Plugins: dkj-policy-bwj

[PR #2021](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2021)

---

### DEPLOY: fix/asana-stage-letter-codes · 20260915-080439

A stage code in `Get-AsanaStageMap` may now carry one trailing letter (`'1C'`, not just `'3'`), so a
consuming repo can group several of its own cycle stages under one leading digit shared with a second,
coarser board -- exactly the blocker smartwatchbanden hit renaming `GitHub - SWB` to align with
`Workload Overview`. Every board that has not adopted a letter is unaffected: the 251 pre-existing
asserts over these functions pass byte-for-byte unchanged, because ordering is now read from the map's
own declared cycle position (`Get-StageRank`) rather than the raw magnitude of the code, and that
reduces to the same answer a bare `1`..`7` already gave.

**Score:** 3 -- a repo that renames its board to share a leading digit goes from silently broken (a
section either drops off the pipeline entirely or is misread as a different stage) to correctly
tracked, the moment it touches that part. No repo that keeps plain per-stage numbers notices anything
changed.

#### What makes this deploy extra special

N/A -- an internal CI/Asana-mirroring mechanism; no subscriber of a service built on a consuming repo
is ever a reader of this.

**Score:** N/A

#### Pull Request

asana-mirror stage codes support a compound number+letter section prefix

Plugins: dkj-policy-bwj

[PR #2022](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2022)

---

### DEPLOY: docs/2014-bwj-chapter-skill-counts · 20260915-075445

The `dkj-policy` README's `dkj-policy-bwj` row now states what that plugin actually is: **four**
chapters rather than three -- the theme lifecycle, added on #1965, was missing from the row entirely --
and **four** skills rather than two, named. The same sentence also stopped claiming the codex binds
only BWJ's two Shopify store repos: since `b9b2a65a` the ticket-handling chapter also binds this
plugin's own source repo, and the row now says the reach differs per chapter.

A reader of this README was being told a plugin has three chapters and two skills while its own
README, its `plugin.json` and the marketplace manifest all said four and four -- so the one page a
consumer reaches from the workflow plugin was the page that disagreed with every other.

**Score:** 2

#### What makes this deploy extra special

A consumer deciding whether to enable `dkj-policy-bwj` reads this row and was under-counting what it
carries -- most consequentially, that a chapter exists which deletes themes from a live store's
estate. Nothing they run changes; what they know before enabling does.

**Score:** 2

#### Pull Request

the dkj-policy README's bwj row states four chapters and four skills

Plugins: dkj-policy

[PR #2020](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2020)

---

### DEPLOY: docs/2012-ticket-work-step-reach · 20260915-062857

Three prose sites describing the `dkj-policy-bwj` ticket-work step still said it reached "BWJ's two
Shopify store repos" after commit `b9b2a65a` widened that one chapter to a third repo
(`dkj-claude-plugins`, this plugin's own source) on September 14, 2026 -- a related but distinct
staleness from the one #1982 fixed the same day, since #1982 never named these three files. All three
now state the real reach. A fourth, unrelated staleness on the same row `README.md:339` -- the chapter
count still read "Three chapters" with the September 13 theme-lifecycle chapter missing from the list
-- is fixed in the same pass, since #2012 explicitly asked for it on the ground that whoever picked
this up would already be editing that exact cell. One further site of the same chapter/skill-count
drift, `plugins/dkj-policy/README.md:98`, was noticed but not named by #2012 and is filed separately
as #2014 rather than folded into this branch's scope.

**Score:** 1 -- corrects stated reach in prose; no script, gate or check reads these sentences, so
nothing behaves differently for this repo's own maintainers.

#### What makes this deploy extra special

`CONTRIBUTING-portable.md` is portable payload that ships to every consumer running `dkj-policy`. A
subscriber reading its ticket-work-step section previously saw an inaccurate scope for
`dkj-policy-bwj`'s worked example; it now matches the gate `report-issue`/`adopt-dkj-policy-bwj`
actually enforce.

**Score:** 1 -- a subscriber who never reads that one paragraph is unaffected, and the gate itself was
already correct; this only fixes what the prose claims about it.

#### Pull Request

Sweep the ticket-work step's stale two-repo reach and README:339's missing fourth chapter

Plugins: dkj-policy

[PR #2015](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2015)

---

### DEPLOY: docs/1982-bwj-third-repo-reach · 20260914-200323

`dkj-policy-bwj`'s four portable law pages, its `README.md`, `plugin.json` and the root
`marketplace.json` said "exactly two repos" everywhere, even after commit `b9b2a65a` (Sept 14, 2026)
admitted this plugin's own source repo (`dkj-claude-plugins`) as a third target for its ticket-handling
chapter alone. Each page now states its own actual reach -- three repos for `WORKFLOW-portable.md`,
two for the other three chapters, each explaining why it did or didn't widen and cross-linking the
one that did. `CLAUDE.md` and the root `README.md`'s plugin table, which restated the same fact, were
brought in line in the same move so this branch does not leave a fresh disagreement behind it. Closes
#1982.

**Score:** 1 -- corrects prose so a reader following a cross-reference is told the truth about which
repos a chapter applies in; nothing here changes what any gate enforces or what a session does.

#### What makes this deploy extra special

N/A -- no subscriber-facing behaviour changed; this is a documentation-only correction inside a policy
plugin's own portable pages.

**Score:** N/A

#### Pull Request

Sweep dkj-policy-bwj's stated reach to match its report-issue/adopt gate

Plugins: dkj-policy-bwj

[PR #2013](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2013)

---

### DEPLOY: fix/2003-json-case-collision-verdict · 20260914-194709

`check-plugin-integrity`'s `Test-JsonFile` reported every parse failure as `is not valid JSON`,
which for one whole class of them is the opposite of the truth: Windows PowerShell 5.1's
`ConvertFrom-Json` folds object keys case-insensitively and then refuses the collision it made
itself, so a valid document carrying `.c` beside `.C` was accused of being malformed. It now
establishes validity with a case-sensitive reader before it judges, and where the file is sound it
says so and names which keys collided and where -- `'.C' and '.c' in lspServers.clangd.extensionToLanguage`,
which is the real map the official marketplace ships. Still an error, because the checks that read
the manifest did not run; what changed is that the reader is no longer sent to edit a correct file.
The diagnosis reads the document rather than the exception's message, which is localized.

**Score:** 2

Nothing in this repo is red today -- its own `marketplace.json` and `plugin.json` files carry no
collision and have no reason to. What was wrong was the gate's verdict for a document class that
provably exists, so this is noticed only by whoever meets it, and then it saves them from editing a
file that was already correct.

#### What makes this deploy extra special

`Test-JsonFile` is this repo's own lint, not plugin payload, so no consumer runs it -- the reach
label on the issue is one layer over from where the symptom is. #1993 -- merged mid-branch as PR
#2010 -- is the half that reads the manifest a consumer installs from, and it is the one that reaches them.

The branch is also a small worked example of the repo's own rule that a report's REASON is verified
before it is repaired. Two of this issue's premises moved under it: one was stale on arrival and one
became true while the work was in flight. Neither changed the repair, because what was checked was
the tree rather than the sentence.

**Score:** N/A

#### Pull Request

Stop calling a case-colliding JSON file malformed

[PR #2011](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2011)

---

### DEPLOY: fix/1993-case-collision-json-reader · 20260914-192344

A marketplace manifest that Windows PowerShell 5.1's own JSON reader refuses can be read again.

5.1's `ConvertFrom-Json` folds object keys case-insensitively and then refuses the collision it made
itself, so a *valid* manifest carrying two keys differing only in case could not be parsed at all --
and the official marketplace carries exactly such a pair, an `lspServers.clangd` extension map
listing `.c` beside `.C`. Every plugin from that marketplace was therefore permanently
`cannot determine` in `plugin-versions`, `update-plugins`' step-3 receipt could never verify what its
step 2 had done for them, and nothing a consumer ran changed it: the state was stable, not transient.
`#1987` had already stopped the tool prescribing a refresh that provably cannot help; this is the
reading itself.

`ConvertFrom-MarketplaceJson` keeps `ConvertFrom-Json` as the only path an ordinary document takes,
and falls back to a case-sensitive reader for the documents it refuses. The fallback is **lazy**, so
the header's no-dependencies rule survives where it was written to hold: nothing extra is loaded on
the path `check-connectors.ps1` takes at every SessionStart. It triggers on **any** parse failure
rather than on the error message -- an exception message is not a contract, and matching one is not
merely risky but unnecessary: a failure that is not a case collision fails in the second reader too,
and then the original exception is what the caller sees. The discriminating is done by trying.

Two things the issue could not have known, both found by measuring rather than by reading it:

- **A faithful reparse is impossible on 5.1**, because a `PSObject` rejects the colliding property
  for the same reason the hashtable does. So the fallback does not pretend to return the document: it
  projects the three fields this repo consumes, and everything else is dropped by design rather than
  lost by accident -- checkable, because exactly two functions parse a marketplace document anywhere
  in the repo, and both now read through it. Routing only the first would have moved the symptom four
  lines down `cut-release.ps1` rather than removed it.
- **Making the document readable made a second branch reachable that had never had to be decided.**
  244 of that manifest's 296 entries declare a *url* source rather than a path -- the majority shape
  in a real catalogue -- and resolving one produces a root that is a stringified type name. Those are
  now skipped: a plugin fetched from a url does not live in this tree, and one of them must not cost
  the whole catalogue, which would have been #1993's own symptom in a new costume.

That skip made `plugin-versions` say `'x' is not listed in the clone's marketplace.json` about a
plugin that plainly is, and send the reader to a marketplace refresh -- the third loop of the shape
#1987 had just finished splitting apart. So `-IncludeRemote` lets that one caller tell *declared
elsewhere* from *not declared*, and the row now says the version cannot be read because the payload
is fetched from a url, with nothing to run, because nothing is broken.

**Score:** 3

#### What makes this deploy extra special

N/A. This repo's own consumers read `plugin-versions` and `update-plugins`, and both get a truthful
answer where they previously got a permanent `cannot determine` and an instruction that could not
work -- but it reaches no subscriber of a service, because there is none.

**Score:** N/A

#### Pull Request

A marketplace manifest with case-colliding JSON keys is readable again

Plugins: dkj-policy

[PR #2010](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2010)

---

### DEPLOY: fix/2005-slow-fixture-shared-dir · 20260914-190653

`test-suite-gate.tests.ps1`'s deadline case ran in a fixture directory it shared with the
parallelism case, so its 3s suite bound also applied to that case's six 1.2s sleepers. Under CI
contention one of them exceeded the bound, the gate correctly named two timed-out suites on its
verdict line, and the case's assert -- which expects the wedged suite alone -- went red over a gate
that was behaving exactly right: intermittent in CI, green on re-run, green locally. The case now
has its own directory, so the pool is the two suites it creates, and a pool-size assert keeps it
that way. Cause established from attempt 1 of the failing run rather than inferred; the issue's
proposed ordering gap between the header path and the verdict path does not exist.

**Score:** 2

A flaky required check is noticed by whoever it stops, and this one stopped a merge and was cleared
by a re-run that proved nothing. But it is one assert in one suite of this repo's own gate, it had
fired once, and nothing about the gate itself was wrong -- so it is small, and a reader who was not
blocked by it would need to be told.

#### What makes this deploy extra special

The repair is a directory name, and the finding is that the issue's own stated reason was wrong in
a way that would have produced a wrong fix. Both candidate causes it named -- an ordering gap
between the header and verdict paths, or a margin too tight for the wedged suite -- point at the
gate; the log shows the gate was right and the fixture was wrong. A repair built on either would
have loosened a correct assert or widened a bound that was never the problem, and it would have
carried a citation.

The retrieval is worth keeping too: `gh run rerun --failed` replaces the current attempt, so the
red job's log looks gone from `gh run view`. It is not -- `actions/runs/<id>/attempts/1/jobs` gives
the job ids, and `actions/jobs/<id>/logs` gives the log. The issue's "I did not establish which"
was one API call from being established.

**Score:** N/A

#### Pull Request

Give the deadline case its own fixture directory

[PR #2009](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2009)

---

### DEPLOY: feat/1979-backlog-page-builder · 20260914-185529

The minor-backlog page builder: `build-backlog-page.ps1` writes `minor-backlog.html` from a store
repo's open, reach-labelled issues, showing each one's mirrored Asana task text -- never the GitHub
issue's own developer-facing title and body, per Dave's decision on the issue. `publish-page.ps1
-Kind backlog` already routed and published this kind since #1977; this was the missing half.

**Score:** 3

#### What makes this deploy extra special

A BWJ store repo (`smartwatchbanden`, `xoxowildhearts`) can now actually build and publish the minor
backlog to a colleague, completing the loop #1977 opened the worker for. Opt-in: nothing runs until a
store repo invokes the new skill.

**Score:** 3

#### Pull Request

The minor-backlog page builder for the shared BWJ pages worker

Plugins: dkj-policy, dkj-policy-bwj

[PR #2008](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2008)

---

### DEPLOY: fix/2000-quota-red-check · 20260914-184214

`claude-review` went red on every pull request, and the cause was not a credential. The failure annotation
had already named it -- the org's monthly spend limit, the third of the three 429 kinds this workflow
documents (#1164) -- which no clock resets and no rotation touches. #2000 was filed as a sixth credential
rotation; there was nothing to rotate.

**The check no longer goes red when the account is out of quota** (Dave, September 14, 2026), reversing
the paragraph this workflow had carried since #966. That argument was not wrong about what a red check
MEANS; it was wrong about what a red check DOES after the seventh consecutive one. Seven issues have been
filed against this one check -- #891, #913, #942, #966, #1055, #1164 and #2000 -- and a signal that fires
on every pull request is not a signal.

**The downgrade is scoped to 429 and nothing else**, on the line this file already drew: that headline
says *re-running adds none*, and no act available to a reader of the check changes it. Everything else
stays red because there something can be done -- a 529 is transient and a re-run is a real remedy, an
unexpected status is unknown, and the pre-SDK class is a missing GitHub App install (#1245), which a green
check would have buried. The empty status falls into the failing branch by construction, so a diagnostic
step that dies under its own `continue-on-error` makes the check red rather than green.

**The legibility work is untouched, which is the half worth protecting.** The annotation keeps its level,
its title and its text and is still written on a 429; it renders whatever the job's conclusion is. What
goes away is the red tick beside it, and with it ship-pr's "a check FAILED but the merge was not blocked"
paragraph -- the line that was printing on every ship.

**Score:** 3

#### What makes this deploy extra special

The one way this change can go wrong is silently. `continue-on-error` defers the verdict, so a decision
step that stopped re-failing -- or a diagnostic left keying on `failure()`, which is now false everywhere
in this job -- would turn every failure green, including the setup defects somebody genuinely has to act
on. That regression prints nothing and looks like a healthy repo. Thirteen asserts pin the direction of
the fail-safe against the workflow's own text, 11 of them go red against the trunk's version, and the
`failure()` one is there because that exact mistake was made while writing this and caught by a test
rather than by a reader.

**Score:** 2

#### Pull Request

Stop claude-review going red when the account is out of quota, and keep it red for everything else

[PR #2007](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2007)

---

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

