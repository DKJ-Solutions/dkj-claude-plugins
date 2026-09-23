# CLAUDE.md — the dkj-policy-bwj extension

**This file extends the `dkj-policy` constitution (that plugin's own `CLAUDE.md`) for the repos that
run the BWJ procedure, and it never overrides it** (Dave, issue
[#2374](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2374), September 23, 2026). A repo
with `dkj-policy-bwj` installed imports it on the line directly below the `dkj-policy` import. Where the
two ever speak to the same question, `dkj-policy` wins.

It adds four chapters. Each chapter's page states its own reach, and that reach is not repeated here:

- **Ticket handling** — [`WORKFLOW-portable.md`](WORKFLOW-portable.md). A discovered issue is filed on
  GitHub first (the source of truth) and mirrored to Asana for colleagues, through the `report-issue`
  skill rather than a plain `gh issue create`.
- **The sync log** — [`SYNC-LOG-portable.md`](SYNC-LOG-portable.md). This is what a `sync/` branch
  owes: a durable record, in the tree, of what a third party did on the live theme.
- **The preview handover** — [`PREVIEW-portable.md`](PREVIEW-portable.md). This is what a preview
  handover owes, and how it reaches the reviewer.
- **The theme lifecycle** — [`THEME-LIFECYCLE-portable.md`](THEME-LIFECYCLE-portable.md). A verified
  backup of the live theme is rotated at the cut, and spent previews are swept after the live push.

**The safety rules of the constitution hold here unchanged, and one of them bites hardest in a store
repo:** a push to the live theme is outward-facing, so it waits for the owner's word.
