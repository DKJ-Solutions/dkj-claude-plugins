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

**18 / 22 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2052-handover-control-pinned-to-live · 20260918-043046

`Get-MarketHandoverPairs` returned the bare storefront URL as its control half -- the exact form
`PREVIEW-portable.md` rules out, because `preview_theme_id` sets a per-domain cookie and the bare URL
keeps rendering the *preview* once the preview link has been opened. Both tabs of a handover then
agreed and the reviewer concluded the change was not visible. The control is now pinned to the live
theme id, read from the consumer's own `Get-ShopifyLiveThemeId` seam or passed as `-LiveThemeId`, and
the builder **throws rather than falling back** -- a fallback would rebuild the same silent defect. Two
tests that had pinned the old behaviour were inverted.

The chapter also gains a measured section on what is *not* a trap: a `301` path drops
`preview_theme_id` from the address bar but does **not** lose the preview, because Shopify's handshake
sets the cookie before the handle redirect fires. That closes a second report which proposed gating
handovers on a per-path `200` -- a check that would have refused correct cards, and every card built
from a preview URL.

**Score:** 4

#### What makes this deploy extra special

Both BWJ stores build preview handovers through this function, so both have been publishing controls
in the wrong form. A reviewer who opened the preview link first saw the preview theme in *both* tabs
and reported the change as not visible -- a false negative on work that had shipped correctly. The fix
is invisible to a colleague but the handovers they receive stop lying to them.

**Score:** 3

#### Pull Request

The handover control URL is pinned to the live theme id

Plugins: dkj-policy-bwj

[PR #2062](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2062)

---

### DEPLOY: fix/2075-sixth-signal-git-spelled-branches · 20260918-040316

`claim-issue`'s sixth signal now asks git about the branch names **git has**. It is fed by two scans,
and one of them handed it names that had already been through the console sanitiser -- which replaces
what it strips with a space, so the ref it named did not exist. `rev-list --count` and `ls-tree` both
came back empty, both are guarded on their exit code and discard stderr, and the block printed *not a
dependency*: the one verdict in that report a reader cannot distinguish from the truth.

The finding record now carries both spellings and each reader takes its own -- `Branches` stripped for
the report, `GitBranches` as git wrote it for the scan. That is the seam the sixth signal's own weighing
loop already drew for itself, and the one `fix/2069-title-overlap-strip-and-plural-v2` draws for the
fifth signal; the fourth signal's input was the place it had never been drawn.

Pinned with three structural asserts rather than a behavioural case, deliberately: `git
check-ref-format` accepts `\p{Cf}`, so the failure needs a branch carrying a bidi override or a
zero-width run, and on every ordinary name the two fields hold the identical string. No run can tell
them apart, so the direction is the whole finding and an assert is the only thing that can state it.

**Score:** 2

#### What makes this deploy extra special

A consumer running `claim-issue` gets a signal that had a silent hole in it: the one case the branch-name
strip was added for was also the one case the prerequisite scan could not answer. Nobody has hit it --
it needs somebody to push a branch whose name carries a formatting character -- so this is a failure
named rather than a failure repaired, and that is worth saying plainly.

What generalises past this one script is the rule the repair states twice in comments and three times in
asserts: **sanitise on the way out, never on the way in.** A value that is going to be printed and a
value that is going back to the tool it came from are two different values, and where one variable
carries both, the tool is the one that loses -- quietly, and only when it matters.

**Score:** 1

#### Pull Request

The sixth signal is fed git-spelled branch names, not the stripped copies the report prints

Plugins: dkj-policy

[PR #2079](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2079)

---

### DEPLOY: fix/2061-lane-forwards-resolves · 20260918-001347

`worktree-lane.ps1` now forwards `-Resolves` to `new-branch.ps1`, so a branch opened in a lane runs the
same already-done check a direct `new-branch` run does -- one `gh` call, before the checkout, asking
whether the issue is already closed or already resolved by a merged PR. The parameter did not exist on
the lane script at all, so passing one was refused outright and a lane simply ran without the check,
silently: nothing in the run said it had not happened.

That is exactly the cost #1409 was filed to remove -- a branch cut, its commits, its development
document, its reviews and its test runs, all spent before the warning finally arrives at `open-pr` --
and a lane is where it bites hardest, because a lane is opened during a busy window, which is precisely
when another session is likeliest to have just closed the issue being picked up.

`-SkipStaleBase` stays declined and is now argued beside it, at the call site and on the skill page,
because the two read as a pair and are not one: that check reads the BASE, which this script chose from
`origin/<trunk>` seconds earlier, so it has nothing left to discover; the already-done check reads the
TRACKER, which no step here has asked about. One is waived because the script already answered its
question, the other could never have been.

**Score:** 3

#### What makes this deploy extra special

A consumer who installs `dkj-policy` gets the lane script and the skill page, and the page is what
tells them a lane inherits every rule `new-branch` enforces. That sentence was not true of the check
that costs the most to skip, and nothing in a lane's output reported the gap -- so the reader furthest
from the code was the one most likely to believe it. The page now names `-Resolves` in the parameter
list and says plainly to pass it whenever a lane is opened for an issue.

**Score:** 3

#### Pull Request

worktree-lane forwards -Resolves to new-branch

Plugins: dkj-policy

[PR #2084](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2084)

---

### DEPLOY: fix/2069-title-overlap-strip-and-plural-v2 · 20260917-234831

`claim-issue`'s title-overlap scan no longer prints a branch name it has not sanitised, and its lead
line now agrees with itself when it reports one branch -- which is the common case and the one #2018
itself measured.

The strip is the half with teeth. `git check-ref-format` enforces `\p{Cc}` and **accepts** `\p{Cf}`,
so a branch fetched from `origin` can carry U+202E or a zero-width run -- and the line it lands in is
the one whose whole job is to tell a reader which branch to go and look at before writing anything.
The fourth signal strips exactly these values, off exactly this `git branch -a` capture, at the
caller; the fifth signal was written one signal later and never acquired the call. The convention it
skipped is stated in `ConvertFrom-CommitScanLog`'s docstring -- *"neither free field is stripped here.
The caller prints them and the caller runs them through `Format-ForConsole`"* -- and the fourth
signal's caller holds up that end while the fifth signal's did not.

**Where it is placed is the part worth reading, because the obvious placement is wrong now.** #2069
proposed either stripping the names on the way into the scan or the report on the way out, and
between the filing and this repair #2064 decided it: its sixth signal collects
`$overlaps[].Branch` and puts each name back to git (`rev-list --count`, `ls-tree`). A name this
strip has rewritten is a ref git does not have, so stripping on the way in would leave that scan
silent exactly where it should report a prerequisite -- in the adversarial case the strip exists for,
and with no error anywhere. So the record keeps git's spelling and the **report** gets a stripped
copy, which is the same seam the weighing loop below it already draws between its printed `Branch`
field and the `$branch` it queries. The exclusion above needs the git spelling for the same reason,
which is why the strip also sits below it.

The lead line was the smaller slip and the more visible one: `1 branch ... share words ... though no
commit on them`. `$branchWord` already switched; the verb and the pronoun were left fixed at the
plural. They switch together now.

Both are held by tests the suite did not have, and the seam is asserted in both directions -- a strip
that creeps back onto the scan input would pass every behavioural test in the file, because on an
ordinary ASCII branch name the two placements are indistinguishable. The strip assert reads the fifth
signal's block **extracted on its own**: the existing `$scan` capture runs as far as the verdict
switch and therefore contains the fifth signal, so the fourth signal's own calls would have satisfied
it while this block printed raw. That is #2019's lesson one turn later, in the place it was filed
about -- the unit is a **value** that reaches the terminal, never a variable that looks like the
script's own.

**Score:** 3

#### What makes this deploy extra special

Both lines are shipped plugin payload, so a consumer's console is where they are read -- with nothing
beside them to compare against. That is the whole reason the grammar was worth filing rather than
leaving: it is the first line of a warning arguing that the reader should stop and look, and a
consumer cannot tell an unfinished sentence from house style. The strip closes a terminal-spoofing
route in a consumer's own checkout, where a branch name arrives off whichever remote they fetch, and
it does so without blinding the prerequisite scan that landed one release earlier. Nothing to do on
upgrade and no behaviour to relearn: the scan reports the same branches, printed safely and read
correctly.

**Score:** 2

#### Pull Request

The title-overlap scan sanitises the branch names it prints, and its lead line agrees with itself in the singular

Plugins: dkj-policy

[PR #2076](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2076)

---

### DEPLOY: fix/2087-ship-pr-converges-under-parallel-lanes · 20260917-231934

`ship-pr` now lands a branch on a busy trunk instead of refusing it. Two blockers are gone, and neither
gate was weakened to do it.

A **stale certificate is repaired rather than reported**: on a stale reading the script brings the branch
up to date through GitHub's own `update-branch`, waits for a genuinely new certifying run, and takes the
same measurement again -- up to `-MaxForwardLaps` times, default 2. The predicate is untouched, so
`-SkipStaleCheck` is still the only way to merge on an old certificate; what changes is that the remedy
costs a CI cycle instead of however long it takes somebody to read a refusal and retype four commands.
Each lap is CI-bound, so the TRUNK takes one merge per CI cycle instead of none. That is a claim about
throughput and not about any one lane: a lap absorbs exactly one trunk merge, so a lane contending with
several others can still exhaust its budget and refuse -- the bound is a stop-loss, and the refusal says
so. A conflict, a branch already current, or a red check on the forwarded head all end the run rather
than lapping. Worth knowing before upgrading: the trigger is "the trunk moved", not "several lanes are
shipping", so a single-lane repo meets this too -- and a lap pushes a merge commit to the branch, made by
GitHub, which is what the printed remedy always told an operator to do by hand. `-MaxForwardLaps 0` keeps
the old behaviour.

And **a trunk held by another checkout no longer blocks the merge** where a CI runner folds. That
refusal's ground -- "step 5 could not fold" -- stopped being true when `fold-on-merge.yml` began folding
off every push to the trunk, not only a merge queue's; it was gated on the queue when the thing it
depends on is the runner. A repo with no such runner is refused exactly as before, and the refusal now
says which read came back empty.

Measured, September 17, 2026: five pull requests sat `CLEAN` and `MERGEABLE` with every check green and
none of them merged, against a trunk taking 33 first-parent commits in a day. PR #2062 recorded seven
refusals in a row, one of them 48 commits behind; PR #2076 was refused on the worktree instead.

**Score:** 5

#### What makes this deploy extra special

A consumer running this workflow with more than one lane could not land work on a busy trunk, and the
two mechanisms that stopped them are both repaired in the shared scripts -- so the fix arrives with a
plugin update and needs no repo setting, which is the half a merge queue could not deliver: GitHub
offers one on a private repo only under Enterprise Cloud, and otherwise only on a public repo owned by
an organisation.

**Score:** 4

#### Pull Request

ship-pr converges under parallel lanes: it forwards the branch itself, and a busy trunk no longer blocks the merge

Plugins: dkj-policy

[PR #2094](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2094)

---

### DEPLOY: fix/2090-anchor-ordering-asserts · 20260917-220352

`scripts/tests/pr-issues.tests.ps1` no longer locates anything in `ship-pr.ps1` with a whole-file
`IndexOf`. All 45 reads go through one region-scoped helper, `Get-ShipIdx`, which searches inside a
single `function` or `# --- Step ` region and, with `-Code`, skips comments and docstrings. A needle
it cannot find is a named failure instead of a silent `-1` that a `-lt` assert would read as a pass.

This closes both directions of the defect. The red one is what #2087 met: two helpers added above
step 3 turned four asserts red about behaviour that had not moved. The green one was measured on the
repair -- of the 39 distinct needles those 45 reads used, eight already matched in more than one
place, and two of them resolved to prose rather than to code, so the assert pinning ship-pr's wait
order was passing on a comment 121 lines above the call, and the check-suite read was pinned to a
docstring line.

Nobody outside this repo runs this suite, and nothing it guards changed behaviour. What it buys is
the next person who adds a helper to `ship-pr.ps1`: they no longer meet a red suite naming a
behaviour they did not touch, whose cheapest reading is to delete the assert.

**Score:** 2

#### What makes this deploy extra special

A test that is green about the wrong text is worse than one that is red, because nothing ever asks it
again. Two of these had drifted onto prose -- one onto a comment, one into a docstring -- while
reporting that ship-pr's wait order was pinned. The branch then reproduced the same failure in its own
writing: the first counts were taken with a grep line count, which missed the one LastIndexOf site,
and every figure above is re-measured off the AST.

The reader of a tier-2 change is the subscriber of a service; this is a test suite inside the repo
that authors the workflow, and it reaches nobody who installs it.

**Score:** N/A

#### Pull Request

pr-issues.tests.ps1's ship-pr ordering asserts are region-scoped instead of whole-file

[PR #2093](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2093)

---

### DEPLOY: fix/2083-failed-fetch-not-all-clear · 20260917-191911

`park-cycle.ps1`'s collision detector no longer reports a **failed** fetch as "nothing to report". The
reader `Get-BranchCollisionNote` is the earliest collision detector in this workflow -- it runs from
the `cycle-autopark` Stop hook, in the one place where no operator is watching -- and `''` is its own
word for *no collision*. A fetch that exited non-zero returned exactly that, so a network blip, a
credential that had just expired or a stale ref made it answer all-clear and the turn went on building
on top of somebody else's tip.

It still returns `''`, deliberately: a collision report is a claim about another session's work, and a
failed fetch is no evidence for one. What changes is that the function now says so, from inside, on
both call sites at once -- `the fetch of 'origin/<branch>' failed (git exit code 128), so this run did
NOT read who is on the far side. That is NOT an all-clear` -- which is the sentence the neighbouring
spent-budget path has printed since #1958. A **timeout** is named apart and carries
`Invoke-NativeCapture`'s own `[timeout]` diagnosis, which this site had been discarding.

**It is the second of two arms, and #2081 is the first.** That change landed days earlier in the same
release and gives the same sentence to a fetch whose exit code came back *unmeasurable*. The two sit
next to each other in `Get-BranchCollisionNote` by design and only one of them ever speaks: unreadable
above, unsuccessful below. A reader meeting both lines in this changelog is not reading a repair made
twice.

**Not a sighting.** #2083 says outright that nobody has measured this firing, and `git fetch` of one
branch against a configured origin is reliable; it is priced as the latent hazard it is. The failure it
prevents is the one #1439 measured -- two sessions building the same branch end to end, discovered at
the push -- arriving through a fetch that could not answer rather than through a look nobody bought.

**Score:** 2

#### What makes this deploy extra special

A consumer running `dkj-policy`'s `cycle-autopark` Stop hook gets a line where it previously got
silence, and only in the state where the silence was wrong: a turn with something to push, on a branch
with an open PR or a refused push, whose fetch of that branch did not succeed. Nothing else changes --
no new refusal, no new network call, and a healthy fetch is byte-identical to before. They notice it
the first time their network, credential or remote ref is having a bad day, which is precisely the
turn on which the old answer was a confident wrong one.

**Score:** 2

#### Pull Request

park-cycle's collision detector says a FAILED fetch out loud instead of reporting it as 'nothing to report'

Plugins: dkj-policy

[PR #2089](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2089)

---

### DEPLOY: fix/2081-exitcodeunknown-audit · 20260917-190004

`ExitCodeUnknown` had no reader outside the lib that defines it, so all 56 bounded native-capture sites
went on judging `$r.ExitCode` against a value that is `$null` about once in 300 fresh child processes.
The direction made it worse than a wrong number: `$null -ne 0` is true, so every site that refuses on a
failure refused, and PowerShell renders `$null` as the empty string, so twelve of them printed a reason
with the number missing out of it -- `gh refused the read (exit ) -- no access, or no such branch`. The
field now has two consumers, `Test-NativeExitMeasured` and `Get-NativeExitLabel`, and the audit's verdict
per family is recorded where the next reader of the field will find it.

**Score:** 3

#### What makes this deploy extra special

Most of the repaired scripts are the ones this marketplace ships -- `claim-issue`, `open-pr`,
`new-branch`, `park-cycle`, `sync-main`, `update-plugins`, the fold. In a consuming repo the sentences
that were wrong are the ones a session acts on: *the claim failed -- #N is NOT yours* over a claim
sitting on the tracker, *git push failed* over a branch that reached origin, and `park-cycle`'s
collision detector reporting all-clear on a fetch it never read. Nothing changes on a healthy run; what
changes is what a consumer is told on the rare one, and that none of the nine writes reaching a remote
may call itself a failure any more.

**Score:** 3

#### Pull Request

The bounded native-capture sites audited against an unmeasurable exit code, and the ones that diagnose gain a third state

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2088](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2088)

---

### DEPLOY: fix/2060-chain-ending-list-one-definition · 20260917-184309

The instrument the close-out ceiling is measured with was filtering on a hand-typed list of "chain-ending
scripts" that was wrong in both directions: it named `park-cycle.ps1`, which the autopark Stop hook runs
after every turn and which prints no receipt, and it omitted `park-branch.ps1`, which prints one -- so
close-out shape C was outside the governed population and ordinary turns were candidates for it. The list
now exists once, as `Get-ChainEndingScripts` in `closeout-lib.ps1`, the file those callers already
dot-source, and the suite holds that definition against a scan of the tree, so a sixth chain ender cannot
be added without going red.

Re-measured over one frozen snapshot of this machine's corpus, old filter against new: the population did
not move (n=252 both) and one session's anchor did -- over-ceiling 193 to 192, over-six 120 to 119. Small
because `park-cycle` reaches a transcript almost never (a Stop hook runs it, not a tool call) and every
park session here had already run another chain ender. So the committed baseline is deliberately left as
it stands; what was wrong was the definition, not the recorded number.

The report's second finding does not stand: `-UpdateBaseline` writes the flat shape the committed baseline
carries, and only `-Json` emits the nested `All`/`CloseOuts`. Nothing is stale there.

**Score:** 2

#### What makes this deploy extra special

N/A -- an instrument used inside this repo to evaluate its own close-out rule. A consumer running the
workflow gets the corrected filter with the next release, but nothing they do changes on account of it.

**Score:** N/A

#### Pull Request

measure-closeouts reads the chain-ending list from one definition

Plugins: dkj-policy

[PR #2086](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2086)

---

### DEPLOY: feat/2058-shared-sha256-hex-helper · 20260917-182501

The SHA-256-to-lowercase-hex idiom now has one definition, `Get-Sha256Hex` in
`scripts/lib/hash-hex-lib.ps1`, and three of the five files that carried it by hand call it:
`gate-lib.ps1`, `session-cache-lib.ps1` and `check-consumer-siblings.ps1`. Text or bytes in,
lowercase hex out, with an optional `-Chars` cut for the callers that put a short hash in a name.

**The fold found the drift the issue predicted, already there.** #2058 filed this as a reuse note and
said in so many words that nothing observable was wrong. The copy in `check-consumer-siblings.ps1`
disagreed: it never disposed its SHA-256 provider -- and it creates one **per file**, inside a
`Get-ChildItem -Recurse` over every comparable path in a consumer checkout -- and it rendered
uppercase hex where every other copy rendered lowercase. Both are repaired by the adoption. The case
change is unobservable, checked rather than assumed: a run picks one scheme, those values are only
ever compared with each other, and none of them is printed, stored or carried across runs -- which is
exactly what let it drift unnoticed.

**Two of the five are deliberately left hand-written**, and that is a departure from what the issue
asked for. `theme-archive-rules.ps1` and `theme-lifecycle-rules.ps1` are registered with an argued
dependency-free property that their own registrations call a safety property: the live-theme guard
reads `repo-config.ps1` on every command inside a catch that returns no live theme id, so a lib in
that family which pulls anything in is a way to disarm a guard over a revenue-serving theme. Adopting
there would also need a second registration of the new lib for a separately versioned plugin. The
cost is that the six-character theme-name renderer stays hand-written; the reasoning is in the lib's
header and on the issue.

The fold is output-preserving, measured against each pre-fold implementation over five inputs
including the empty string and a non-ASCII one. `sync-rules.ps1` is untouched, as the issue asked:
its SHA-1 composes git's own object id, and the new function's name is the fence that keeps it out.

**Score:** 2

#### What makes this deploy extra special

N/A -- nothing a subscriber of this service can observe. This is internal tooling: one shared helper
behind three call sites whose output is byte-identical to what it replaced, so no consumer-visible
behaviour changes. The undisposed provider it repairs was a slow leak in a maintenance check that
runs in this repo, not in anything a consumer runs.

**Score:** N/A

#### Pull Request

One shared SHA-256-to-hex helper for the four sites that hand-copied it

Plugins: dkj-policy

[PR #2085](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2085)

---

### DEPLOY: fix/2074-base-is-another-branch · 20260917-175423

`new-branch` no longer reports `Base is current with origin/main` and nothing else when the base is
another branch's tip. Where `HEAD` is a branch other than the trunk and carries commits `origin/<trunk>`
does not, the run names that branch and that count -- twice, once before the checkout and once near the
last line -- and the dim currency line names the branch as well, so the sentence that reads as *"the base
is the trunk"* cannot be read alone. It warns and never refuses: stacking on purpose is on the happy path
and the lane chooses its base seconds before delegating here. A detached `HEAD` is not a subject, which
keeps the lane itself silent, and `origin/<trunk>..HEAD` is zero for a base that really is the trunk and
for a branch not yet committed on, which keeps the ordinary run silent.

**Score:** 3

#### What makes this deploy extra special

This is the gap every other guard in the family reads straight past. The stale-base refusal fires on a
base *behind* the trunk and this base is behind nothing; the remote-ahead warning is about the branch you
are resuming; the claim step reads the tracker; the lint gate, the suites and CI all read the branch, and
the branch is valid. The measured run went green on all of them while carrying 22 files of somebody
else's unlanded work into a two-line repair's pull request, and was caught by a human reading a diff.
Since two sessions can now share one working copy without either typing a git command, the accidental
stack is reachable without anyone doing anything wrong.

**Score:** 3

#### Pull Request

new-branch names the base when it is another branch's tip, so a stack is not silent

Plugins: dkj-policy

[PR #2080](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2080)

---

### DEPLOY: docs/2073-entry-five-whole-report · 20260917-171859

Entry 5 of `new-branch/SKILL.md`'s six-site injection-surface inventory now names every value
`claim-issue`'s report prints, instead of the one scan that existed when the entry was written: the
issue title off the tracker, the parked-fix scan's author/subject/branch names, the title-overlap
scan's branch names off the `git branch -a` capture the per-commit strip never reaches (#2018, and why
#2069 needs a second call at the caller), and the prerequisite scan's branch names plus the file paths
it reads out of an issue body (#2064). The list's closing lessons gain the one this repaired: an entry
goes stale the same way the list does, one level in, so a new signal, field or caller inside a site
already listed is an edit to that entry.

**Score:** 2

#### What makes this deploy extra special

This is the document a consumer audits their own console against -- the page that says which of their
printed lines carry somebody else's characters and what guards each one. An entry that under-describes
its own site is worse than a missing entry, because it reads as having been checked: a reader taking
entry 5 at face value was told the title-overlap scan's branch names were already accounted for by
text that had never mentioned them. The list's own discipline covered the case one level up and not
this one; it does now.

**Score:** 2

#### Pull Request

Entry 5 of the six-site list names every value claim-issue's report prints, not two

Plugins: dkj-policy

[PR #2078](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2078)

---

### DEPLOY: docs/2066-title-overlap-section · 20260917-163712

`claim-issue`'s fifth pickup signal -- the title-overlap scan, which matches an issue's own title
against every branch name off the trunk to catch a branch cut for the subject rather than the number
-- now has its section on the skill page, between the fourth signal and the bounded-call section. It
carries #2018's own measurement (two complete independent implementations of #2016 inside half an
hour, every other pickup signal reading clean), how the word matching filters and why, the corpus
measurement behind the floor of two shared words, and the hedges that make it weaker evidence than the
fourth signal -- including that it deliberately never moves this script's closing line. The page's
numbered summary of what the script does names the scan as its own step.

**Score:** 2

#### What makes this deploy extra special

A consumer who installs `dkj-policy` reads this page and nothing else, and the scan has been printing
its block to their console with no document behind it: nothing saying what it measured, how strong a
shared word is as evidence, or that it is advisory like every other signal in the family. That is
exactly the hedging every neighbouring section is careful to state, and the reader most in need of it
is the one furthest from the code.

**Score:** 3

#### Pull Request

The title-overlap scan gets its own section on claim-issue's page

Plugins: dkj-policy

[PR #2072](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2072)

---

### DEPLOY: fix/2056-already-done-three-state · 20260917-161539

The already-done check no longer reads **"this number is not an open issue in this repo"** as
**"this issue is CLOSED"** (inbound #2056). It had no third state, so a number this repo has never had
was reported as closed and the author was told the branch "may repeat work that is already merged".

**This workflow produced the case it is repairing**, which is why it fired so often. The numbers being
tested are scraped as bare integers out of the branch's development document, and the inbound route
*prescribes* citing an issue in another repo: a shared-core finding is filed on the marketplace repo,
and the consumer then cites that number in a docstring, a README entry and the DEPLOY section. Every
one of those is a bare `#<n>` after scraping, pointing at a repo the check never queried -- so it was
loudest on exactly the branches that follow the documented route.

`Get-TargetIssueWarnings` now takes `-ClosedIssues` instead of `-OpenIssues`: it is told what is
closed rather than inferring it, because an absence cannot be the evidence for a positive claim. The
caller does the resolving, one `gh issue view` per number the open list did not already account for --
per number rather than one `--state all` list, because that list is paged and this repo is past 2000
issues, so a genuinely closed issue behind the page boundary would come back as "not here" and take
#1282's real signal with it.

**One thing the report did not name is fixed with it: a pull request number.** Issues and pull requests
share one counter, so a document citing `PR #1276` handed the check a number that is not an issue
either, and it read as CLOSED for the same reason. Measured here: `gh issue view 2053` answers exit 0
with state `MERGED`. A *closed* pull request answers exactly what a closed issue answers, so the
discriminator is the `/pull/` in the URL rather than the state.

What did NOT change: the check still warns and never blocks, and a state it cannot determine still
claims nothing.

The cost this removes is trust rather than a blocked PR -- an author who learns these warnings are
usually wrong stops reading them, and #1282's real signal goes with them. Every branch citing an
upstream finding saw it, so the noise was routine rather than occasional.

**Score:** 3

#### What makes this deploy extra special

It is the second attempt at this class and the first one to reach the cause. #1718 narrowed the scraped
region so the scaffold's own guidance block stopped contributing foreign numbers -- a real repair, and
one that removed a *source* rather than the conflation: a foreign number written in the branch's own
prose, which the inbound route requires, still landed in the target set and still read as closed.

**Score:** 2

#### Pull Request

The already-done check tells a closed issue apart from a number that is not an issue here

Plugins: dkj-policy

[PR #2067](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2067)

---

### DEPLOY: feat/2064-prerequisite-branch-signal · 20260917-160011

`claim-issue` now asks a sixth question at pickup, and it is the first one that is not about
ownership: **is a surfaced branch in my way rather than racing me?** Where the parked-fix or
title-overlap scan names a branch, the step weighs it -- how far ahead of the trunk it is -- and holds
the paths the issue's own text cites against the trunk. A path that is **absent from the trunk and
present on that branch** reaches its own verdict: *PREREQUISITE, NOT A COMPETITOR*, with the ordering
handed to the owner.

The five signals before it all answer *is somebody mid-flight on this work?*, which is why the
strongest ends in *ASK THEM BEFORE YOU WRITE ANYTHING*. Measured on the #2051 pickup (#2064): that
verdict fired on `origin/fix/2048-closeout-repair-strategy`, and reading settled it -- the commit
merely *mentioned* #2051 because it had filed it. What nothing named was that #2051's subject,
`scripts/maintenance/measure-closeouts.ps1`, existed only on that branch, so every route to the issue
ran through it landing first. No other check can see that: `triage-inbound`'s *subject does not exist*
is about a name that names nothing, while a subject on an unmerged branch greps, opens and has
history -- present to every check, and blocking the work exactly as hard as absence.

Three endings, deliberately not two. A prerequisite found; every cited path already on the trunk; or a
body citing no path at all, where the overlap question was never asked. Printing *not a dependency*
where nothing was tested is the failure this signal exists to remove, one layer in.

Advisory, like every signal in this family -- a claim that blocks costs the whole assignment (#1485).
What it does change is the closing line: where both verdicts fire the headline names **both**, because
they are different questions and naming one sends the reader to the block that settles the other.

Free on an ordinary claim: nothing surfaced, no git call made. Where something was surfaced the bill is
one `rev-list` per branch plus **one** `ls-tree` on the trunk carrying every cited path at once -- the
per-branch read runs only for the paths the trunk turned out to lack, which is normally none. Weights
are measured against `origin/<trunk>` where it exists, because a local trunk sitting behind origin
reports landed commits as unlanded and inflates a branch in the one direction this must not err.

Noticed the first time a pickup lands behind somebody else's branch, which is the day it saves the
whole detour.

**Score:** 3

#### What makes this deploy extra special

It is the first pickup signal that answers a question the others were not asking. The five before it
add evidence on one axis -- who else is working this -- and #2064's cost was a verdict that was
*correct on that axis* and pointed at the wrong question: the reader spent the time working out why
the branch mattered, from a block that had already told them to ask about ownership. Widening an
existing verdict would have made weaker evidence share a headline with stronger, which #2018 refused
by name one signal earlier; a second question gets its own block and its own hedges instead.

The issue body is read for the first time here, and it is read as **data**: bounded to path-shaped
tokens with a directory and an extension, URLs stripped first, nothing absolute, no `..`, no
option-shaped token, and none of it printed verbatim. Anybody who can open an issue writes that text,
and it now reaches a git argument list.

**Score:** 2

#### Pull Request

A surfaced branch is weighed, so a prerequisite is not read as a competitor

Plugins: dkj-policy

[PR #2071](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2071)

---

### DEPLOY: feat/2051-mirror-closeout-instrument · 20260917-154400

The close-out instrument now ships to the consumers it measures worst. `measure-closeouts.ps1` landed
in #2048 as a source-repo maintenance script, which was the wrong way round for what it measures: per
repo, close-outs over the three-line ceiling ran `smartwatchbanden` 97%, `xoxowildhearts` 88%,
`claude-code-specialists` 86%, `thumbnail-generator` 67% -- and the repo that owns the instrument is
its best performer at 50%. The two worst were consumers who could not run it, and every close-out
complaint on the record came from a consumer.

It is registered, mirrored byte-identically into `dkj-policy`, and documented by its own
`measure-closeouts` skill page rather than filed under `measure-skill`'s, whose subject is what a skill
costs in tokens. Two things the mirror needed came with it: the source-repo guard, so a stale cached
copy is refused instead of reporting a plausible number, and a baseline that lands in the consumer's
own repo rather than in the plugin cache the next update replaces.

**Score:** 3

#### What makes this deploy extra special

A consumer of this workflow gains an instrument they could not run before, and it needs nothing
configured: it reads `~/.claude/projects` rather than the repo, is read-only, always exits 0, and only
counts leave it -- no transcript content -- so it is safe in a repo whose measurements are published
while its sessions stay private. It costs one more always-on skill description in every session that
enables `dkj-policy`, which was weighed and accepted rather than discovered.

**Score:** 3

#### Pull Request

The close-out instrument ships to the consumers whose rates are worst

Plugins: dkj-policy

[PR #2063](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2063)

---

### DEPLOY: feat/2050-closeout-gate · 20260917-151732

Step 6 of the ritual now has a gate instead of a seventh piece of advice. A Stop hook refuses a
close-out over this repo's band and asks for it again, once per work chain; every other turn, and
every repo that has not answered the new seam, is untouched.

**Score:** 3

#### What makes this deploy extra special

Six repairs to the close-out are on the record and all six were advice. #2048 built the instrument and
measured the baseline none of them had ever been argued against -- 84% of close-outs over the stated
ceiling, which means the rule had never been in force anywhere. This is the first one that can be
measured rather than judged by whether a complaint arrives.

It also reverses a written doctrine, narrowly: `cycle-autopark.ps1` says a Stop hook never blocks, and
that stays true of `cycle-autopark`. The exception is bounded to a measured over-run on a turn that
ended a work chain in a repo that opted in by name.

**Score:** 2

#### Pull Request

A close-out gate: a Stop hook that blocks a receipt over the band

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2065](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2065)

---

### DEPLOY: fix/2055-preview-theme-name-length · 20260917-150335

`Get-RepoPreviewThemeName` now bounds a branch's preview theme name to Shopify's 50-character
ceiling (inbound #2055). A branch name long enough to compose past it used to reach the platform and
come back as `Name is too long (maximum is 50 characters)` -- after the run had already announced
which theme it was creating, so the push read as half-done. A name that FITS is returned unchanged,
so every preview theme that exists today keeps its name and stays findable; only an over-long one is
rewritten, as `<prefix><truncated branch part>-<6 hex of SHA256(the full name)>`.

The bound belongs in the shared builder rather than at the caller because three call sites compose
this name and all three have to agree on one string: `push-preview.ps1` creates the theme, and
`sweep-preview-themes.ps1` composes it again -- once for the current branch and once for every branch
still alive -- in order to SPARE it. A ceiling applied outside the builder would leave the sweep
composing a name it no longer recognises as spared, which is silent and destructive.

The discriminator is not decoration: plain truncation maps every branch sharing a long enough head
onto one theme name, so two branches would push over each other onto a preview that looks correct
from both.

A consumer whose branch names run long cannot create a preview theme at all today; everyone else sees
no change, because a name that fits is untouched. Noticed the moment that consumer pushes.

**Score:** 3

#### What makes this deploy extra special

It closes the class rather than the instance. `Get-RepoPreviewThemeName` already refused a name
illegal at the CLI -- a `/` in it -- and its own docstring named that as its job; the length ceiling
is the same kind of rule from the same vendor, and it was the one case the function did not cover.

**Score:** 2

#### Pull Request

Get-RepoPreviewThemeName bounds the theme name to Shopify's 50-character limit

Plugins: dkj-subagents-shopify

[PR #2059](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2059)

---

### DEPLOY: fix/2048-closeout-repair-strategy · 20260917-143821

The close-out ceiling is now measured instead of argued about. `measure-closeouts.ps1` reads this
machine's recorded sessions and reports how the close-out actually behaved, separating the two
populations that matter -- every session's final message, and the close-outs that follow a
chain-ending script, which is the set the ceiling governs and the only set a verdict may be read off.

It answers the question inbound #2048 called open and real. Over 328 sessions, 263 of them real
close-outs: **84% exceed the three-line ceiling, 56% exceed even six, and the median is seven.** So the
rule has never been in force anywhere -- five complaints are five of two hundred and twenty-two -- and
every previous repair was advice against a baseline nobody had counted, evaluated by waiting for the
next complaint. That is a sample of one, which cannot tell a repair that worked from one that did not,
and it is the mechanism behind the pattern the report identified.

It also settles the report's leading hypothesis, that the trigger is volume of work: measured,
`r = 0.207` over n=263 -- real, about 4% of the variance, and not the cause, because the smallest
quarter of sessions already averages 5.8 lines against a ceiling of 3.

Nothing about what the close-out print says was changed, deliberately. The finding is about how
repairs are evaluated, and the instrument plus its recorded baseline is what lets the next change here
be shown to have done something.

**Score:** 4

#### What makes this deploy extra special

N/A -- this repo's audience tier is the developers maintaining it. The instrument reads session
transcripts on the machine it runs on and ships to no consumer in this change.

**Score:** N/A

#### Pull Request

The close-out repair strategy, investigated across five recurrences

Plugins: dkj-policy

[PR #2057](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2057)

---

### DEPLOY: fix/2049-asana-block-before-close · 20260917-125439

`dkj-policy-bwj` reverses the order of its Asana notification: the paste-ready block is written by the
session that shipped the work, while the issue is still **open**, and closing the issue is a person's
confirmation that the block reached Asana. It is gated on the issue having a linked Asana task rather
than on the `CRO` label, which was narrower than the need. `asana-mirror` still writes a block on the
`closed` event, but only where no block is already there -- it is the backstop now, not the route.

The old order could not be repaired in place. Its comment appeared underneath an item that had just
left every open-issue view; a missed event was never detected afterwards; and the link inside it was a
placeholder that CI cannot fill, because "where the result can be viewed" depends on what the ticket
was about. The session that built the thing is the one party that knows that link.

**Score:** 2

#### What makes this deploy extra special

A store repo running `dkj-policy-bwj` has to act, in two places. Re-copy `templates/asana-mirror.ps1`
into `.github/scripts/` -- an install writes nothing into a repo -- or the old CRO-gated comment keeps
running. And ship an Asana-linked issue with `-NoResolves` from now on: a `Closes #<n>` has GitHub
close the issue at the merge, before anybody has written a block and with nobody's confirmation, which
bypasses the whole rule silently.

In exchange the requester stops being told where to look by a comment nobody reads, on a ticket
nobody reopens, with the link still reading `[ADD LINK]`.

**Score:** 5

#### Pull Request

The paste-ready Asana block is written before the issue closes, by the session that shipped it

Plugins: dkj-policy, dkj-policy-bwj

[PR #2053](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2053)

---

### DEPLOY: fix/2043-closeout-fillable-template · 20260917-103912

The close-out reminder the chain-ending scripts print now hands over a line to fill in rather than
describing the shape to compose: `<what happened> -- see PR #1885. [Filed #<n>.] Session can be
cleared.`, with the citation slot already answered from the run's own knowledge. The three parts, the
ceiling and the rehousing rule are unchanged; only the delivery is.

It is the fifth repair of a rule that keeps losing, and the first taken after verifying that the
previous one was in force and still lost. Inbound #2043 asked for the print to be moved last -- it was
already last, the final statement of `ship-pr.ps1`. What put ~35 lines under it was the child
processes' output arriving after the parent's, which no placement can fix and whose cause does not
reproduce in this repo -- filed on its own as #2044. That **retires** the placement repair without
arguing for this one: a template printed in a buried position is exactly as buried as prose was, so
this change does not repair the ordering and is not offered as doing so. What it stands on is the
report's other argument, independent of where the line lands -- **a shape that is described has to be
composed, and a shape that is handed over has to be filled.** The general lesson banked alongside it is
that **last in the file is not last on the screen**.

**Score:** 3

#### What makes this deploy extra special

Every repo running this workflow gets the new line at every `open-pr`, `ship-pr`, `park-branch`,
`fold-changelog-entry` and `cut-release`, on its next plugin update. Nothing to do and nothing breaks
-- the parameters, the suppression and the bypass clause are untouched -- but what a session reads at
the end of every chain changes wording.

**Score:** 3

#### Pull Request

The close-out receipt hands over a fillable template instead of describing one

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2047](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2047)

---

### DEPLOY: fix/2044-child-output-to-host · 20260917-091623

A child process's narration could arrive after everything its parent printed, so where a line was placed
stopped predicting where it was read. `ship-pr.ps1`, `cut-release.ps1` and `verify-pushed-merges.ps1`
each started their children with `& powershell`, which hands the child's stdout to the parent script's
**success stream** -- its return value -- while the parent's own `Write-Host` narration goes to the
information stream. The two reach one console in printed order only while nothing consumes the success
stream; pipe such a run, capture it, or `Tee-Object` it, and the narration prints live while every
child is collected and replayed at the end. The output is not scrambled, which is what made it hard to
read as a defect: it is every parent line in file order, then every child line in file order.

All five narrating spawns across the three scripts now route through `| Out-Host`, which keeps the
child's text with the narration and leaves the success stream empty -- where a child's console output
never belonged. `$LASTEXITCODE` is unaffected, and `2>&1` is deliberately not used.

The repair went further than #2044 asked. The issue named `ship-pr.ps1` alone and expected to need three
consumer-side facts before anything could change; none was needed, because the reproduction it had
already written only had to be run through a pipe. Going looking then found the same defect in two
sibling scripts it had not reported. `../scripts/tests/ordering-passthrough.tests.ps1` pins both halves:
that the defect is real, and that no narrating spawn in either copy of `scripts/release/` is left
unrouted.

**Score:** 3

#### What makes this deploy extra special

A consumer is where this was measured -- a ship whose output arrives grouped rather than interleaved
costs a debugging session to explain, and #2044 was filed only after a second issue had already been
misdiagnosed from the resulting screen order. Consumers running a ship in a foreground shell see no
change at all; those who pipe, capture or background one get output they can read in order again.
Conditional reach is why this is not scored higher: nothing was blocked, and the workflow no longer
depends on placement anyway.

**Score:** 2

#### Pull Request

A child process's output no longer lands after everything the parent printed

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2046](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2046)

---

