- **A finding becomes an issue, not a question at the end of the turn.** Something real that is not part
  of the assignment — a bug, a stale or wrong doc, a decision that is not yours to make, a measurement
  that contradicts what a doc claims — is filed in the issue tracker of the repo you are working in, and
  then you finish the assignment. The owner has to be able to close a finished session and clear its
  context without first answering everything you found along the way. Name the issues you filed when you
  close out, with their numbers, so they can see what was parked rather than lost. Improvements to the
  shared core keep the `inbound` route above; this is for the repo in front of you.
- **An inconsistency is a finding, and it is ALWAYS filed.** Two statements in the tree that cannot both
  be true: a portable page prescribing an arrangement its own source repo does not run, a doc naming a
  path a script no longer writes, a count in prose that disagrees with what the code produces, a gate
  list naming three suites where the guide names ten. Neither the kind nor the size changes the answer —
  if it is a contradiction and it sits outside the assignment in front of you, it leaves the session as
  an issue with a number. **This needs saying separately because an inconsistency does not read as a
  finding while you are the one who created it**: it arrives as a *consequence* of the change you are
  reporting, so it feels like context for the work rather than a defect of its own, and the close-out is
  where it lands. Deciding it is not yours to decide, and scoping it out of the branch, are both usually
  right — and neither is a reason to keep it in the reply. **Scoping a contradiction out of the work is a
  reason not to edit the file; it is never a reason not to file it.** Where your own change created it,
  file it anyway and say so in the issue, because *"this branch caused it"* is the reader's first
  question and the answer is what makes it triageable. And *always filed* is not *always a new issue* —
  the bar above still applies first, so a contradiction that argues for exactly what an open issue is
  already asking belongs on that thread as a comment.
- **Establish that there is a tracker before you promise one.** This needs a checkout and a reachable
  tracker — check, rather than assuming either way. In a session with no repository there is nothing to
  file to, and the finding goes in your reply instead. Never report an issue as filed where you could not
  file it.
- **The bar, because an issue nobody reads is worse than one sentence in a reply.** File what a later
  reader can act on; search the tracker first — for the duplicate, and for the reason in the last bullet
  below; one subject per issue; and say what you measured and what you only inferred. Do not file
  work you were asked to do, or a finding you can simply fix inside the assignment. And never file
  instead of asking when the question genuinely blocks the work — something unsafe or irreversible still
  stops and asks.
- **A number does not exist until the issue does — file first, cite second.** Before writing an issue
  number anywhere — a lib header, a step list, a commit message — open the issue and read the number
  back. Issues and pull requests share one counter, so a predicted number is taken by whichever of the
  two lands first.
- **Filing needs no permission — asking for it is the same failure as not filing.** *"Shall I open an
  issue for this?"* and *"say the word and I'll file it"* are the rule above wearing a helpful face:
  the finding still leaves the session as something the owner has to answer, which is exactly what
  filing exists to prevent. There is no fourth close-out shape in which a finding waits for a yes. If
  it stands and it is outside the assignment, file it and name the number; if it does not, there is
  nothing to file and nothing to ask.
- **And the question to answer before filing is not "may I?" but "does it still stand?"** This is the
  real cost of asking, and the reason the two rules are one rule: the permission question *feels* like
  diligence and substitutes for the check that matters, so a finding that has never been held against
  the tree arrives pre-approved. Read the code, the script or the doc that would have to be true for
  your finding to hold — the same treatment an inbound report gets, applied to your own. **A tool that
  seems to be missing a capability is where this bites hardest**: the flag usually exists, and what you
  actually met was the default. Where the finding collapses, say so plainly instead of filing a
  weakened version of it — a report withdrawn with its reason is worth more than one filed to justify
  having raised it.
- **And the tracker is one of the things you read, because it is where a guardrail's INTENT lives.**
  The code is the source of truth for what a check currently *does*; the issue that produced it is the
  only source for what it was *built to prevent*, and a proposal that touches a guardrail needs both.
  Reading only the tree is the failure that looks most like diligence: you verified, correctly, against
  an artefact that cannot tell you the answer. So the search is not only how you avoid a duplicate.
