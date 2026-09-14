## fix/1988-native-capture-utf8-claude-shim

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

#### Root cause (verified, not assumed)

Reproduced the exact `Get-Command claude -All` ordering issue #1988 reports on this machine's own
npm install: `claude.ps1` (ExternalScript), `claude.cmd` (Application, `.cmd`), `claude` (Application,
no extension). `Invoke-NativeCaptureUtf8`'s `Start-Process -FilePath 'claude'` resolves the bare name
via CreateProcess's own PATH search, which matches the extensionless file before it ever tries an
appended extension -- confirmed by launching `Start-Process` against the resolved `.cmd` path directly
and getting a clean exit, versus the reported Win32-loader failure on the bare name.

### CREATE

- [x] Add `Resolve-NativeApplicationPath` to `scripts/lib/native-capture-lib.ps1`: resolves a bare,
      PATH-searched `$FilePath` to the first `Get-Command -All -CommandType Application` match that
      carries a real extension (skips the extensionless shim and the `.ps1`, which `Start-Process`
      cannot launch directly); leaves an already-specific path, or a name that resolves to nothing,
      unchanged.
- [x] Call it from `Invoke-NativeCaptureUtf8` before building `$startArgs`.
- [x] Rebuild the shared-script mirrors (`scripts/sync/build-shared-scripts.ps1`) so `dkj-policy` and
      `dkj-subagents-shopify` carry the fix too.

### TEST

- [x] Added a regression test in `scripts/tests/native-capture.tests.ps1` that reproduces the
      three-shim npm layout in a throwaway `PATH` entry and asserts the `.cmd` shim runs (not the
      Win32-loader failure), plus that an already-resolved path and a genuinely missing command are
      both left unchanged.
- [x] `native-capture.tests.ps1`: 204 pass, 0 fail.
- [x] `check-plugin-integrity.ps1`: 0 error(s) (shared-script mirrors back in sync).

### DEPLOY: fix/1988-native-capture-utf8-claude-shim

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

