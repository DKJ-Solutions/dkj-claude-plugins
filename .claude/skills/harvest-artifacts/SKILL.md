---
name: harvest-artifacts
description: Add to scripts/dashboard/artifacts.json -- the register behind the dev server's /artifacts page -- every claude.ai Artifact a session in this repo published on this machine that the register lacks, read from the session transcripts. Use after publishing an Artifact or a Claude Docs doc from a session here, when /artifacts is missing one, or on a second machine to add its own. A dry run unless -Apply.
---

# harvest-artifacts -- the Artifacts register, filled from the transcripts

**It exists because the register was kept by hand**
([#3112](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3112)): it was seeded once from
this repo's session transcripts, and every Artifact published after that stayed off `/artifacts` until
somebody remembered to add it.

**It is repo-local**, beside `measure-suites`: the register and the page are this repo's own dev
server, so nothing here ships in a plugin.

## Run it

```powershell
# what this machine published here that the register lacks; writes nothing
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/harvest-artifacts.ps1

# write it into the register, then commit it on a branch like any other change
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/harvest-artifacts.ps1 -Apply
```

`-TranscriptRoot` points it at another transcript folder; the default is `~/.claude/projects`. A full
read of about 450 MB of transcripts took 7 seconds when it was written.

## What it reads, and why there

- **The transcripts, not the claude.ai account listing.** The listing holds Artifacts from several
  repos and has no repo field. A transcript record carries the `cwd` its session stood in, so a publish
  is this repo's when that `cwd` lies under this checkout, or under a sibling checkout named after one
  of `Get-RetiredRepoNames`.
- **A publish is read from its result, not its input.** A first publish names no url in its input, and
  a refused one names none in its result, so a call that did not publish adds nothing. An asset upload
  and every non-publish action (`read`, `list`, ...) are skipped; a Claude Docs `batch` that creates a
  doc counts, as kind `document`. An Artifact created from a type is recorded as kind `typed`, because
  the call does not say which type it was -- correct it in the register (`slides`, say) and it stays.
- **Each owner harvests their own machine.** The register is committed, so it is the union of every
  machine that ran this.

## What the merge does

**It only adds.** A url the register lacks becomes a row: its title from the first publish that names
one (the call's `title`, else the `<title>` of the page it sent if that file still exists, else the
file's name), its about line from the last publish's `description`. A url the register already holds
only has its dates widened. A title, kind or about line in the register is never rewritten, so a
correction made there by hand survives every later harvest. A share link (`?sk=...`) and the plain link
are one Artifact.

## What it is not

- **Not a hook.** A hook on every Artifact publish would rewrite a tracked file on whatever branch is
  checked out, which is usually the trunk, and leave it dirty for the ship scripts. The register
  changes through a branch and a PR like any other file.
- **Not a reachability check.** An Artifact is private to the account that made it until shared, so a
  recorded link may answer 404 for the other owner. The page says so; this does not test it.

The functions are in `scripts/lib/artifact-harvest-lib.ps1`, tested in
`scripts/tests/dev-pages.tests.ps1`.
