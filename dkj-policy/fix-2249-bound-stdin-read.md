## fix/2249-bound-stdin-read

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

Get-HookPayloadRaw's 250 ms bound does not bind on .NET Framework: [Console]::In is a SyncTextReader, so ReadToEndAsync() runs synchronously and Wait() is never reached. Replace it with a read that leaves the calling thread free, and cover the two unbounded neighbours (adopt-statusline.ps1, show-progress.ps1).

#### The mechanism was picked by measurement, not by argument

#2249 listed two mechanisms it had tried and rejected and named a third it had not. All of them were
measured here, in BOTH directions -- a handle left open AND a payload written and closed -- because
the failing candidates each pass one and fail the other:

| mechanism | payload written and closed | handle left open |
|---|---|---|
| `[Console]::In.ReadToEndAsync()` + `Wait(250)` (today) | 13-20 ms, correct | WEDGED: alive at 12 s, 0 CPU |
| raw stream `ReadAsync` in a loop | 91-153 ms, correct | `''` at the bound, exits clean |
| `BeginRead` + `AsyncWaitHandle.WaitOne` | 89-138 ms, correct | `''` at the bound, exits clean |
| **`OpenStandardInput().CopyToAsync()` + `Wait`** | **77-88 ms, correct** | **`''` at the bound, exits clean** |

The last one is the cheapest of the three that bind and the shortest to write, so it is what landed.
Also measured against it: a 1 MB payload (84 ms), a writer that sleeps 60 ms before writing (78 ms),
an empty stdin (73 ms). The process exits cleanly because the pool thread left blocked on the dead
handle is a background thread -- which is exactly what the runspace variant #2249 tried could not do.

#### A second, unreported defect in the same three lines

`[Console]::In` decodes with `Console.InputEncoding`, which on Windows is the OEM console codepage --
cp850 on this machine, not UTF-8. So every non-ASCII byte in a payload was already being mangled
before it reached `ConvertFrom-Json`. Measured: `Ren` + U+00E9 sent as UTF-8 came back as two cp850
characters (U+251C, U+00AE) and now comes back as the one character it is. Invisible for a
`session_id`, which is a UUID; not invisible for the `cwd` field the sibling readers in this family
take a repo root from.

#### Three call sites repaired, four filed

The sweep found seven `[Console]::In.ReadToEnd()` reads in this family, not the three #2249 named. The
four it missed are all hooks, they carry a per-firing cost trade that needs deciding rather than
assuming -- `guard-working-copy.ps1` fires on every Bash and PowerShell call and already measures
itself at 675 ms -- and one of them has a different exposure entirely (its `hooks.json` entry drains
stdin in the shell before PowerShell ever runs, so bounding the PowerShell read there repairs the
hand-run case and not the wedge). Filed as
[#2264](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2264).

#### No leaf lib, and that is a decision

The idiom is four lines in three places, and `hash-hex-lib` (#2058) is the tree's precedent for
folding a repeated idiom into one. It was declined here on two grounds: the statusline shim
structurally CANNOT dot-source it -- that lib lives in the payload the shim exists to find, the same
reason the shim reads `installed_plugins.json` itself -- and `show-progress.ps1` runs at a two-second
cadence under a header that refuses exactly this kind of load. So a lib would serve one of three call
sites. The canonical explanation lives in `Get-HookPayloadRaw`'s docstring and the other two point at
it by name. #2264 re-asks the question, because seven copies is a different arithmetic from three.

### CREATE

- [x] `scripts/lib/session-cache-lib.ps1` -- `Get-HookPayloadRaw` reads through
      `OpenStandardInput().CopyToAsync()` + `Wait($TimeoutMs)` and decodes through a `StreamReader`
      with BOM detection; the docstring carries the trap, the rejected mechanisms and the measurements
- [x] the default bound raised from 250 ms to 1000 ms on both `Get-HookPayloadRaw` and
      `Get-HookSessionId` -- 250 was chosen when the wait never fired, so its size cost nothing and was
      never measured; now that it binds, firing wrongly loses a payload silently while firing rightly
      bounds a case that was previously infinite, and that asymmetry argues for headroom
- [x] `scripts/task/show-progress.ps1` -- the same read, bounded inline, with a pointer to the
      canonical copy and a note on why the lib load is refused here
- [x] `scripts/task/adopt-statusline.ps1` -- the statusline shim's read, bounded inline, with the
      reason it cannot reach the lib
- [x] the three mirrors regenerated into `plugins/dkj-policy/scripts/` via `build-shared-scripts.ps1`
- [x] the four hook reads the issue's enumeration missed filed as #2264 rather than swept in

### TEST

- [x] `scripts/tests/session-cache-lib.tests.ps1` gains **3b** -- a child spawned with stdin redirected
      and then never written to and never closed must RETURN. It asserts termination and not a
      duration, deliberately: the failure it pins is infinite, so any finite wall is evidence and a
      tight one would only make the suite flaky on a loaded runner. The elapsed time is printed for the
      log. Against the pre-repair lib the same child was still alive at the 5 s wall; against the
      repaired one it exits in about 3 s
- [x] and **3c** -- a UTF-8 payload carrying U+00E9 must arrive as U+00E9 (233) and not as the cp850
      pair. The bytes are composed and written to the child's raw stdin, because this file is ASCII by
      repo convention and piping through PowerShell would re-encode the very thing under test
- [x] `session-cache-lib.tests.ps1`: 71 pass, 0 fail
- [x] the three edited files and the shim body inside the here-string all parse, and the shim stays
      pure ASCII
- [x] `check-plugin-integrity.ps1`: 0 error(s)
- [ ] the full suite set, green
- [ ] CI green on the pull request

### DEPLOY: fix/2249-bound-stdin-read

A SessionStart hook could hang a session start forever and print nothing while doing it. The timeout
that was supposed to stop that never ran: `[Console]::In` is a `SyncTextReader` on Windows PowerShell,
so `ReadToEndAsync()` completed on the calling thread before the `Wait()` bounding it was ever reached.
On a redirected handle nobody closes, the read blocked for as long as the session lasted -- measured at
15 s and still going, at no CPU at all. The read now goes through the raw stdin stream, which queues to
the thread pool and leaves the calling thread free to time out, so the bound binds. The same repair
went into the two neighbours that had no bound at all: the status line and the shim that wires it up,
both of which run every couple of seconds and would otherwise have left one more stuck process behind
on every refresh.

**Score:** 3

#### What makes this deploy extra special

A second defect surfaced in the same three lines and was fixed with them: the payload was being decoded
with the OEM console codepage rather than UTF-8, so any accented character in a path came through
mangled. Harmless for the session id, which is a UUID, and not harmless for the working-directory field
other readers in this family take a repo root from.

For a consumer of this workflow, nothing changes about how anything is used and no migration is needed;
a failure that had not visibly happened yet can now no longer happen. The read costs about 80 ms where
it used to cost about 15, which is the price of the bound actually binding, and it is stated in the code
beside the measurement rather than left for somebody to find.

**Score:** N/A

#### Pull Request

Bound the hook stdin read so an open handle cannot wedge a session start
