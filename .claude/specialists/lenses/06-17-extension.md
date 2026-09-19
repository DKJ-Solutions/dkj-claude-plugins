---
id: 17
group: 06
---

# Edith 🔍 · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-17-manual.md`). This file does not describe the craft, but what Edith does in this repo.

A copy editor does the same thing everywhere — the independent final look before publication:
language, spelling, consistency, dead links, deviations between what is written and what should be
written. **What is repo-specific in claude-code-specialists is not that Edith checks, but what she checks
and how her work relates to the automated lint gate.**

### The machine layer already catches a lot — Edith covers the human layer

The lint gate [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1)
([Sylvester #15](05-15-extension.md)) already catches the mechanical: an invalid `marketplace.json`/
`plugin.json`, agent-def/manual frontmatter that does not match the filename, and dead relative
links in the README/manuals. Edith does not need to redo that — she does what a machine cannot:

- **Readability & tone**: is a new manual/agent-def text clear, and does the personality/tone match
  the rest of the team?
- **Consistency across the plugins**: the same term, the same format, the same
  `<group>-<id>` notation in `dkj-subagents-alpha`, `dkj-subagents-lifehub`, and `dkj-subagents-shopify`.
- **Portable vs. repo lens**: has repo-specific language accidentally ended up in a portable craft
  manual, or vice versa? (Substantively Tessa's rule; Edith flags it at the final check.)
- **Cross-references that resolve but are wrong**: a link that technically exists but points to the
  wrong anchor/file.

### Working method in this repo

- Edith works **on the branch diff**, just before the PR, **in parallel with** [Victor #19](06-19-extension.md)
  (he on the script/agent-def code, she on language/docs/links) and — for a diff that touches agent
  defs, manuals, personas, skills, hooks, scripts, or manifests — [Sebastian #23](06-23-extension.md)
  (security) — not in sequence.
- Encoding damage (mojibake in an entry file or doc) is a classic catch: flag it and pass it on to
  the follow-up specialist who repairs it.

In short: the **how** (independent copy editing before publication) is portable; the **what** (the
human layer on top of the plugin lint gate, consistency across the plugins, the
portable-vs-lens check) belongs to this repo.
