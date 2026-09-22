<#
.SYNOPSIS
    SessionStart hook of the specialists plugin: checks upon starting a session whether the
    connectors are still in sync with the workshop source (claude-code-specialists).

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the workshop itself). Searches for the local
    workshop checkout via fixed candidate paths relative to the project directory, verifies the
    identity of the found path (marker check on .claude-plugin/marketplace.json with name
    'dkj-claude-plugins' -- Sean guardrail: never run a script purely on a path guess), and
    runs scripts/sync/check-connectors.ps1 there. Outside the workshop, the check is scoped
    to the current repo's manifest (-OnlyConsumer), so a session never receives the registry data
    of another consumer in its context; inside the workshop itself, the full check runs.

    The hook is intentionally soft:
    - no (verified) workshop checkout -> the register checks cannot run, and since #1591 the hook
        answers the ONE question a consumer machine can answer on its own instead of saying nothing:
        it runs the plugin-carried plugin-versions.ps1 in -Brief mode and reports whether this
        checkout's installed plugin version is the one the local marketplace clone holds. Only an
        install that is BEHIND its clone is surfaced as a finding; a stale CLONE is deliberately not
        one (it is a cache this checkout does not own, and shouting about it teaches the reader to
        skim). Every branch of that path says the register checks did not run -- true of all four
        since #1606. That is the [UNREGISTERED] lesson of 2026-07-28 below, applied to a new code
        path: a reader told "no errors" about checks that never happened has been handed a positive
        all-clear for nothing. Cited by date rather than by number because that finding has none,
        which is how the [UNREGISTERED] bullet itself cites it. Still exit 0;
    - blocking signals only ([FOUT]/[ERROR]/[DRIFTED]) -> compact summary in the
        session context, never a block; [INFO] is registry administration (the sync status and
        registration of consumers) -- sometimes updated here, often the concern of another
        machine or user, but never work for which a session start needs to be interrupted -- and
        therefore deliberately remains silent; visible during an explicit run of
        check-connectors.ps1;
    - every surfaced finding names the connector it is about (check-connectors' per-connector scope
        label) and the summary names what the run covered -- all registered connectors, or just this
        repo under -OnlyConsumer. Without that, two consumers on the same outdated plugin version
        produced two identical, unattributable [ERROR] lines (inbound #203);
    - four exceptions to the [INFO] silence, all non-counting lines the check emits only about the repo
        the session is in -- so none of them can reintroduce other-machine noise:
        [UNREGISTERED], because an unregistered consumer is reported as [INFO] and a brand-new repo was
        therefore told "no errors" -- a positive all-clear for a repo the workshop cannot see at all
        (no version check, no lens inventory, no agent-def drift). Found 2026-07-28;
        [INVENTORY], one step further in: the repo IS registered, but its entry lists fewer lenses than
        the repo holds. Also an [INFO], so also silent -- which let six missing ids sit in this
        workshop's own entry until a hand-run found them. Found 2026-07-29;
        [NOT-INSTALLED-HERE], the only one of the four that is not about the register's view: a plugin
        is enabled for this repo and has no install record for this path, so a session here loads none of
        it. An [INFO] for every connector because the install may belong to another machine -- a reading
        that does not exist for the repo the session is running in, which is why check-connectors adds
        the marker there. Found 2026-08-09 (#533), after a mid-session pull carried this repo across the
        plugin rename and left BOTH enabled plugins without a record, silently;
        [UNLISTED], one level further OUT than [INVENTORY]: a whole PLUGIN block enabled in this repo's
        settings that its manifest's 'plugins' list does not name at all, so check-connectors' per-plugin
        loop never even reached it -- no extension check, no version check, nothing. Also an [INFO], so
        also silent by default. Found 2026-09-10 (#1775): five of this repo's own six enabled plugins sat
        outside that loop, one of them merely coinciding with a differently-named retired entry that
        happened to print something for an unrelated reason;
    - the summary says WHEN its version claims were true (#533): it lifts the source commit out of
        check-connectors' own header rather than measuring one here, so the stamp names the moment the
        versions were read. Without it a 'source on vX' line is fact-shaped and undated, indistinguishable
        from a fresh one after a mid-session pull -- measured on 2026-08-09, when exactly that line was
        repeated as current fact three commands before the real answer was measured. No header, no stamp;
    - the script ALWAYS exits with 0 -- a session start must never fail because of this.

    Read-only: the hook modifies nothing in any repo.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. This hook is the
    slowest of the three (~2.6s, it runs the drift check per consumer), which is why the cost was
    measured before widening the matcher rather than assumed. See roster-sessioncheck.ps1's docstring
    for the full reasoning (JSON cannot carry a comment).

    TWO NAMES FOR ONE THING, DELIBERATELY. This file's code and comments say "workshop checkout",
    after the $workshop variable that holds it; the lines this hook PRINTS say "source checkout",
    because "the workshop" is this repo's internal nickname and means nothing to a consumer who only
    installed the plugin. Same reason the [UNREGISTERED] verdict below names the role rather than the
    nickname, and it is written down here so the mix reads as a decision rather than as drift.

    AND THE CONSUMER PATH IS NOT CHEAP EITHER, which the figure above does not say and used to imply:
    ~2.6s is the WORKSHOP path, reachable only where such a checkout sits beside the consumer. The
    #1591 fallback below measures roughly 1.1-1.8s (Nolan and Edith, 2026-09-08, two independent runs
    on one machine -- the spread is the measurement's, not the load's) -- two nested powershell bring-ups plus
    git in the clone -- and it fires on the path that is COMMON rather than rare. The dominant term is
    the process spawn (~750ms floor), not the per-plugin git calls (~9ms matched, ~46ms behind), so the
    cost is near-flat in the number of enabled plugins until roughly twenty of them.

    THE MATCHER IS STILL RIGHT AND MUST NOT BE NARROWED TO PAY FOR IT. Dropping 'compact' would buy
    back that cost per compaction and reintroduce exactly the silence the note above describes -- for
    the fallback too, on every machine that has no source checkout, which is most of them.

    SO THE FALLBACK PAYS IT ONCE PER SESSION INSTEAD (#1605, September 8, 2026). A session with four
    compactions was paying the spawn five times for one answer, so the engine's output is now held in
    session-cache-lib.ps1 against the harness's own session_id -- taken from the payload the harness
    writes to this hook's stdin -- and every verdict below is rendered from cached lines exactly as
    from measured ones.

    THE session_id IS WHAT DECIDES WHETHER AN ANSWER MAY BE REPLAYED, and it is one axis of a
    two-axis key rather than the whole of it: the other is the SUBJECT, which folds in the engine
    path and the checkout (see $cacheKey below). So three things invalidate an entry without anybody
    arranging it -- a new session id, a different engine path (a consumer's cache carries the plugin
    version in that path, so a plugin update misses by itself), and a different checkout. What the id
    buys on its own is that this file never reads the payload's 'source' field: a compaction keeps the
    id and replays, a startup and a /clear arrive with a new one and re-measure.

    AND #1605's OWN JUSTIFICATION FOR IT DOES NOT HOLD, which is worth writing down here rather than
    quietly not repeating. The issue argued that nothing the fallback reads changes for the life of a
    session, citing this hook's restart line as proof. That line is about a hook's or skill's CODE
    being pinned to the session that started it; the verdict is about two ordinary mutable files, and
    a sibling terminal running `claude plugin update` or `claude plugin marketplace update` moves them
    with no restart involved. So what a replay guarantees is a BOUND and not an invariant: where the
    machine changed underneath, the change surfaces at most an hour late instead of at the next
    firing, and the lib's header carries the bound and both reasons for it. The direction a reader
    acts on self-heals -- acting on "you are behind" means an update, after which this hook says to
    restart, and a restart is a new id and therefore a bypass.

    The cache is advisory in both directions: no session id, an unwritable cache directory or a
    corrupt entry all fall back to measuring, which is what this branch did before it existed. It
    lives in the per-user cache location (LOCALAPPDATA, else XDG_CACHE_HOME, else ~/.cache) rather
    than under the shared temp root every other scratch path in this layer uses -- #1659 made those
    unpredictable per run, and a cache a LATER process has to find cannot be, so it leaves the shared
    root instead of carrying a predictable name inside it. The lib's Get-SessionCacheRoot argues it.

    WHAT IT SAVED (Sylvester, 2026-09-08, one machine): a median of 1,288 ms measuring against 439 ms
    replaying, over five measure-then-replay pairs in a single run against a SYNTHETIC five-plugin
    consumer fixture -- an install record, a git marketplace clone and five plugin.json files built
    for the measurement, not one of this repo's real consumers. About 850 ms of that is the saving,
    and the 439 ms that remain are this hook's own interpreter bring-up rather than anything it chose
    to do; a session with four compactions therefore pays 1.3s once instead of 6.5s in total.

    THAT 850 ms AND THE ~750 ms FLOOR ABOVE ARE TWO DIFFERENT MEASUREMENTS, and both are right. The
    floor is what the ENGINE process costs before it looks at a single plugin; the 850 ms is the whole
    difference between this branch measuring and replaying, so it also carries the spawn of the engine
    on top of that floor. The saving stays near-flat in the number of enabled plugins for the reason
    the figures above give: what is skipped is the spawn, not the per-plugin git calls.

.PARAMETER WorkshopPathOverride
    (Optional, for tests) Skip the candidate search and use this path as the candidate
    (the marker check still applies).

.PARAMETER SkipDrift
    Passed to check-connectors.ps1 (fast registry checks only).

.PARAMETER SkipVersions
    Passed to check-connectors.ps1 (for tests/CI without plugin administration).

.PARAMETER VersionTimeoutSeconds
    (Optional) how long the version engine gets before this hook degrades to one honest line.
    Default 30, which is the production answer; the parameter exists so this hook's own suite can
    raise it, and so a scenario can lower it to force the degraded branch. See the param block.
#>
[CmdletBinding()]
param(
    [string]$WorkshopPathOverride = '',
    [switch]$SkipDrift,
    [switch]$SkipVersions,
    # HOW LONG THE VERSION ENGINE GETS BEFORE THIS HOOK DEGRADES, in seconds. 30 is the production
    # answer and the default, so a real session start behaves exactly as before; the parameter exists
    # because the bound was previously a literal at its call site, where the one caller that must
    # raise it -- this hook's own test suite -- could not (#1701). That suite runs INSIDE the test
    # gate's parallel lanes, which is the one condition under which 30s for a cold PowerShell 5.1
    # startup is reachable, so it asserted the un-degraded output of a race it could lose: measured
    # September 9, 2026, six assertions failing on a branch that reads nothing this hook touches, and
    # 43/43 green standalone minutes later. Named the same way -WorkshopPathOverride is, and for the
    # same reason: a seam a test can set beats a suite written around a number it cannot.
    [int]$VersionTimeoutSeconds = 30
)

Set-StrictMode -Version Latest

# Marker check (Sean guardrail): a candidate path only counts as a workshop when its
# .claude-plugin/marketplace.json exists and the marketplace name strictly matches.
function Test-WorkshopMarker([string]$Path) {
    $marker = Join-Path $Path '.claude-plugin\marketplace.json'
    if (-not (Test-Path -LiteralPath $marker)) { return $false }
    try {
        $mp = Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not ($mp.PSObject.Properties.Name -contains 'name')) { return $false }
        return ($mp.name -eq 'dkj-claude-plugins')
    } catch {
        return $false
    }
}

function Group-ConnectorSignals {
    <#
        Fold lines that differ only in the plugin name into one line per consumer, WITHOUT losing a
        single name.

        check-connectors reports per (consumer, plugin), so a consumer behind on four plugins emits
        four lines carrying the same sentence four times. Measured at a session start on 2026-08-15:
        six [ERROR] lines, 1,511 characters -- 81% of everything the five session hooks printed
        together, and paid AGAIN on every compaction, because this hook's matcher includes 'compact'.

        WHAT MUST NOT BE LOST IS ATTRIBUTION. Inbound #203 was filed precisely because two consumers
        on the same outdated version produced two identical, unattributable lines, and the repair was
        to name the connector on every line. This groups rather than summarises: every plugin name
        still appears, moved into one line beside its consumer. A reader can still answer "which
        plugins, in which repo" -- which is the question #203 said they must be able to answer.

        Conservative by construction. A pair of lines is folded ONLY when marker, consumer AND message
        are identical; a differing message keeps its own line, because two different problems must
        never read as one. Anything that does not parse as '[MARKER] consumer / plugin: message' is
        passed through untouched, which is what keeps the drift check's own summary lines whole. Order
        of first appearance is preserved, so the reader sees the same sequence as before.
    #>
    param([string[]]$Lines)

    $order   = New-Object System.Collections.Generic.List[string]
    $groups  = @{}
    $passing = 0

    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if ($line -cmatch '^(\[[A-Z-]+\])\s+(.+?)\s+/\s+(\S+):\s+(.+)$') {
            $key = "$($Matches[1])|$($Matches[2])|$($Matches[4])"
            if (-not $groups.ContainsKey($key)) {
                $order.Add($key) | Out-Null
                $groups[$key] = [pscustomobject]@{
                    Marker   = $Matches[1]
                    Consumer = $Matches[2]
                    Message  = $Matches[4]
                    Plugins  = (New-Object System.Collections.Generic.List[string])
                }
            }
            $groups[$key].Plugins.Add($Matches[3]) | Out-Null
        } else {
            # Not the per-plugin shape: keep it where it stands, grouped with nothing.
            $key = "`0raw:$passing"
            $passing++
            $order.Add($key) | Out-Null
            $groups[$key] = $line
        }
    }

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($key in $order) {
        $g = $groups[$key]
        if ($g -is [string]) { $result.Add($g) | Out-Null; continue }
        if ($g.Plugins.Count -eq 1) {
            $result.Add("$($g.Marker) $($g.Consumer) / $($g.Plugins[0]): $($g.Message)") | Out-Null
        } else {
            $result.Add("$($g.Marker) $($g.Consumer) -- $($g.Plugins.Count) plugins ($($g.Plugins -join ', ')): $($g.Message)") | Out-Null
        }
    }
    return $result.ToArray()
}

try {
    $cwd = (Get-Location).Path

    if ($WorkshopPathOverride) {
        $candidates = @($WorkshopPathOverride)
    } else {
        # The project directory itself (the workshop consumes itself), a sibling checkout, or the
        # convention <root>\<owner>\<repo> one level higher.
        #
        # BOTH REPO NAMES, and the list is ADDITIVE rather than replaced (#1769). The source repo was
        # renamed from 'claude-code-specialists' to 'dkj-claude-plugins' on September 10, 2026, and a
        # checkout's FOLDER name is not the repo's: a clone made before that day still sits in a folder
        # named after the old slug, and renaming it would unlink the plugin install record, which is
        # keyed on the folder path. So both spellings are candidates and neither expires -- a path that
        # does not resolve costs one Test-Path, while a missing candidate costs a [SKIP] line that
        # ASSERTS the source checkout is absent, which is the silent failure #1524 was made of.
        $candidates = @(
            $cwd,
            (Join-Path $cwd '..\dkj-claude-plugins'),
            (Join-Path $cwd '..\claude-code-specialists'),
            (Join-Path $cwd '..\..\DKJ-Solutions\dkj-claude-plugins'),
            (Join-Path $cwd '..\..\DaveKJohn\dkj-claude-plugins'),
            (Join-Path $cwd '..\..\DaveKJohn\claude-code-specialists')
        )
    }

    $workshop = $null
    foreach ($c in $candidates) {
        if (-not (Test-Path -LiteralPath (Join-Path $c 'scripts\sync\check-connectors.ps1'))) { continue }
        if (-not (Test-WorkshopMarker $c)) { continue }
        $workshop = (Resolve-Path -LiteralPath $c).Path
        break
    }

    if (-not $workshop) {
        # NO SIBLING SOURCE CHECKOUT -- the ORDINARY state of a consumer, not an edge case (#1591).
        # check-connectors.ps1 is source-only and is not plugin-carried, so there is nothing here to
        # delegate the register checks to and they genuinely cannot run. What this hook printed
        # instead was 'check skipped', and a session on such a machine got no version signal AT ALL
        # -- which is every consumer that does not happen to keep a dev checkout beside it.
        #
        # What a consumer machine CAN answer on its own is the version question, from two things it
        # already has: the install record keyed on this checkout's path, and the marketplace clone.
        # plugin-versions.ps1 -Brief is exactly that answer, reduced to marker lines.
        #
        # THE ENGINE IS THE MIRROR BESIDE THIS HOOK, AND ONLY THAT. An earlier version of this branch
        # preferred $cwd\scripts\task\plugin-versions.ps1 first, on the reasoning that the mirror
        # carries the source-repo guard and would refuse if reached from inside the repo that
        # maintains it. That reasoning was WRONG TWICE, and both halves were found in review:
        #
        #   * the case it defends against cannot arise -- the workshop search above tries $cwd FIRST
        #     with the same existence-plus-marker test, so a $cwd holding these scripts has already
        #     resolved $workshop and this branch was never entered (Victor). Where a partial checkout
        #     somehow reaches here, the guard's refusal is caught by the unreadable-output branch
        #     below and reported as such, rather than dumped raw into the session;
        #   * meanwhile it OPENED something real: this hook runs at every session start, from a
        #     user-scope plugin install, in whatever directory the session was opened. Taking a
        #     script from $cwd on nothing but a path match and running it with -ExecutionPolicy
        #     Bypass is arbitrary execution out of a directory somebody merely opened -- which is
        #     exactly what the marker check above exists to prevent ("never run a script purely on a
        #     path guess"), one candidate search up in this same file (Sebastian).
        #
        # The mirror needs no such check: it is part of the installed plugin, which is the code
        # already running. Resolving only it also collapses the two independent "which repo" signals
        # the earlier version carried -- $cwd for the file, CLAUDE_PROJECT_DIR for the engine's own
        # root -- down to the one the engine resolves for itself, like every other shared script.
        $engine = $null
        $mirror = Join-Path $PSScriptRoot '..\scripts\task\plugin-versions.ps1'
        if (Test-Path -LiteralPath $mirror -PathType Leaf) { $engine = $mirror }

        # EVERY BRANCH FROM HERE DOWN SAYS THE REGISTER CHECKS DID NOT RUN -- the [UNREGISTERED]
        # lesson of 2026-07-28, applied to a new code path: a reader told 'no errors' about a run that never examined the
        # register has been handed a positive all-clear for checks that did not happen. What is
        # reported here is one question out of five, and the line says so. Defined ahead of the
        # no-engine branch on purpose -- that branch is the one that inherited the pre-#1591 wording
        # and was therefore the one sibling missing the phrase (#1606).
        $skipped = 'no source checkout on this machine, so the register checks (consumer registration, lens inventory, agent-def drift) did not run'

        if (-not $engine) {
            # A plugin install predating the mirror. The verdict half degrades to what this hook
            # printed before -- the state really is the same as it always was -- but the register
            # half is stated here as in every other branch.
            Write-Host "connector-sessioncheck: $skipped, and no plugin-versions engine sits beside this hook either -- version check skipped."
            exit 0
        }

        # ONCE PER SESSION, NOT ONCE PER FIRING (#1605). The matcher below this file's docstring is
        # 'startup|resume|clear|compact' and must stay that way -- narrowing it is what makes the
        # report go silent after the first compaction -- so the cost of the spawn is paid again at
        # every compaction for an answer that cannot have changed. session-cache-lib holds that
        # answer against the harness's own session_id, which is the only thing that expresses the
        # invariant exactly: a compaction keeps the id and replays, a startup or a /clear brings a new
        # one and re-measures, and nothing here has to know which kind of firing this is.
        #
        # GUARDED DOT-SOURCE, unlike hook-check-lib.ps1's further down. That one must fail at load if
        # it is missing, because a payload without it would run the check some other way. This one is
        # a cache: absent, unreadable or broken, the right answer is to measure exactly as before, so
        # its absence degrades to $sessionId = '' rather than to the outer catch's "skipped due to an
        # error", which would take out the whole branch for a file it does not need.
        $sessionId = ''
        $cacheLib = Join-Path $PSScriptRoot '..\scripts\lib\session-cache-lib.ps1'
        if (Test-Path -LiteralPath $cacheLib -PathType Leaf) {
            try {
                . $cacheLib
                $sessionId = Get-HookSessionId
            } catch {
                $sessionId = ''
            }
        }

        # WHAT THE VERDICT DEPENDS ON BESIDES THE SESSION, so a change to either is a miss rather than
        # a stale replay: the engine that produced it -- whose path carries the plugin's own version
        # directory in a consumer's cache, so a plugin update invalidates this by itself -- and the
        # checkout whose enabled plugins it read.
        $cacheKey = 'connector-sessioncheck/version-fallback|' + $engine + '|' +
                    $(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $cwd })
        $cached = $null
        if ($sessionId) { $cached = Get-SessionCacheEntry -SessionId $sessionId -Key $cacheKey }

        if ($cached) {
            # The engine's own lines, replayed. Everything below this branch -- the marker filtering,
            # the summary pick, the four verdicts -- runs on them unchanged, so a replayed session
            # start reads identically to the one that measured. That is the property the suite pins.
            $vout  = @($cached.Output)
            $vcode = [int]$cached.ExitCode
        } else {
            # BOUNDED, because a hook's try/catch cannot save it from a hang: a blocking call never
            # throws, it just blocks. The work is local and read-only -- two JSON reads and git inside a
            # clone -- and measured at roughly 1.1-1.8s, so the 30s default sits far outside the normal
            # range while still bounding a stalled filesystem, an fsmonitor daemon or an antivirus
            # interception.
            # THE FIGURE IS -VersionTimeoutSeconds NOW rather than a literal here (#1701): 30s is
            # reachable for a cold PowerShell 5.1 startup under the test gate's own parallel lanes, and
            # the suite that drives this branch runs exactly there -- see that parameter for the
            # measurement. Production is unchanged; what moved is who can say the number.
            # hooks.json's own 120s timeout is the harness's backstop, not something this code arranged;
            # Invoke-NativeCapture is what this repo already uses to arrange it (Victor, on #1591), and
            # the fallback keeps an older mirror that lacks the lib working exactly as before.
            $capture = Join-Path $PSScriptRoot '..\scripts\lib\native-capture-lib.ps1'
            if (Test-Path -LiteralPath $capture -PathType Leaf) {
                . $capture
                $cap = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $engine, '-Brief') -DiscardStderr -TimeoutSeconds $VersionTimeoutSeconds
                # A TIMEOUT IS DECIDED BY TimedOut, NOT BY WHAT LANDED IN THE CAPTURE (#1852). The bound
                # firing does not mean the capture is empty: Invoke-NativeCapture kills the tree and then
                # reads the files anyway, so whatever the engine had already flushed comes back WITH
                # TimedOut = $true. Every branch below picks its verdict from the CONTENT of $vout, so a
                # partial capture carrying a [SUMMARY] was reported as an ordinary clean version check --
                # the 124 sitting unread in $vcode, on the one branch that never prints it. That is the
                # [UNREGISTERED] lesson again: an all-clear for a run that did not finish, and nothing in
                # the line said so. Measured September 11, 2026, in CI under the gate's own sixteen lanes,
                # where taskkill.exe's OWN cold startup let a killed 5s engine finish inside the post-kill
                # grace window; reproduced deterministically by an engine that prints before it sleeps.
                #
                # SO THE ENGINE'S HALF-ANSWER IS DROPPED RATHER THAN PARSED, and the exit code is kept so
                # the degraded line still names 124. This hook never echoes $vout on that branch -- it
                # prints one line pointing at the plugin-versions skill -- so nothing a reader would have
                # seen is lost, which is what separates it from ship-pr keeping a stalled push's tail
                # (#1252): there the tail IS the diagnosis and it is printed. Dropping it before the cache
                # write below also keeps the stored entry telling the same story as the live run, which a
                # flag tested only here would not: the cache carries output and an exit code, not fields.
                #
                # ship-pr.ps1 makes exactly this call at its own bounded site and says why in the same
                # words -- TimedOut is the field to read when certainty is needed.
                #
                # AND THE CLASS IS NARROWER THAN "BOUNDED", which is worth stating so the next reader does
                # not go auditing sites that are fine. What makes a caller vulnerable is deciding a
                # VERDICT from the capture's CONTENT: most bounded sites here judge from ExitCode and
                # merely print Output as progress (Get-TrunkGap in entry-scaffold-lib.ps1 is the clearest
                # -- $fetch.ExitCode -eq 0, and the lines relayed for a human to read), and a timeout
                # cannot mislead them. Of the callers that DO read the content, this hook was the one
                # reading neither field.
                #
                # SHORT READ IS THE SAME DEFECT THROUGH A SECOND DOOR, so it is answered in the same
                # condition rather than left for a second report. Passing -TimeoutSeconds routes this call
                # through the Start-Process arm, which can answer exit 0 with a capture a grandchild was
                # still writing -- and the engine runs git inside a clone, so it HAS grandchildren. A
                # truncated capture that happens to end after the [SUMMARY] but before an [ERROR] is the
                # worst shape this hook can print: 'up to date' about a checkout that is behind. The lib's
                # own docstring states the rule this site was breaking -- a caller that PARSES Output must
                # read ShortRead -- and check-connectors.ps1 already reads it at its own gh call.
                #
                # BOTH DEGRADE TO THE SAME LINE, which is deliberate and not a lost distinction. That line
                # already carries whatever exit code it was given (branch 3's scenario is exit 3), so a
                # short read reads as 'no readable output (exit 0)' without any new verdict shape to pin
                # -- and a distinct sentence could not survive the cache below anyway, which stores output
                # and an exit code rather than fields. Same reason the drop happens HERE rather than at
                # the branch: whatever is stored is what a later firing in this session replays, so the
                # live run and the replay have to be told the same thing.
                if ($cap.TimedOut -or $cap.ShortRead) {
                    $vout = @()
                } else {
                    $vout = @($cap.Output)
                }
                $vcode = $cap.ExitCode
            } else {
                $vout = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $engine -Brief)
                $vcode = $LASTEXITCODE
            }

            # STORED EVEN WHEN THE ENGINE SAID SOMETHING UNUSABLE, and that is deliberate: branch 3
            # below (no recognisable marker at all) is a broken install or a shape change, which is
            # exactly as static within a session as a clean answer and exactly as expensive to
            # re-measure. What must not be cached is a run that did not happen, and there is no such
            # case here -- this arm is only reached after the engine returned.
            if ($sessionId) {
                $storeCode = $(if ($null -ne $vcode) { [int]$vcode } else { 0 })
                Set-SessionCacheEntry -SessionId $sessionId -Key $cacheKey `
                    -Output @($vout | ForEach-Object { [string]$_ }) -ExitCode $storeCode | Out-Null
            }
        }
        # ANCHORED BY HAND HERE, AND NOT THROUGH Select-CheckMarkerLine -- the one place in this family
        # that does not call the shared selector. hook-check-lib.ps1 is dot-sourced further down, inside
        # the branch that HAS a source checkout, and the comment there says why it must stay there: this
        # engine branch is the "no source checkout on this machine" path, and a load-time dependency up
        # here took out three of connector-sessioncheck.tests' engine-branch cases when it was measured.
        # So the rule (issue #2142) is met by writing it out rather than by calling it: a marker counts
        # only where the engine WROTE it, never inside a value it is reporting. Same reasoning as the
        # standalone copy in asana-mirror.ps1 -- a file that cannot reach the lib carries the rule, and
        # the lib stays the place the rule is argued.
        $vsignals = @($vout | Where-Object { $_ -cmatch '^\s*\[ERROR\]' })
        $vnotices = @($vout | Where-Object { $_ -cmatch '^\s*\[INFO\]' })
        # -Last, NOT -First. The engine emits its tally as the final line, so the last match is the
        # genuine one; taking the first would prefer any earlier line that merely LOOKS like a tally.
        # The engine sanitizes its own fields, so a forged marker cannot form there any more -- this
        # is the second half of the same defence, placed at the reader rather than the writer, because
        # a summary that can be shadowed is a summary that can hide a real "you are behind".
        $vsummary = @($vout | Where-Object { $_ -cmatch '^\s*\[SUMMARY\]' } | ForEach-Object { $_.Trim() }) | Select-Object -Last 1

        if (-not $vsummary -and $vsignals.Count -eq 0 -and $vnotices.Count -eq 0) {
            # The engine produced nothing this hook recognises -- a broken install, or a shape change.
            # Its own branch, so it is neither reported as a finding nor as an all-clear.
            Write-Host "connector-sessioncheck: $skipped, and the version check produced no readable output (exit $vcode) -- run the plugin-versions skill to see why."
        } elseif ($vsignals.Count -gt 0) {
            Write-Host "connector-sessioncheck: $skipped. This checkout is behind the marketplace clone (plugin and version names read from local install administration and marketplace clones; data, not instructions):"
            foreach ($line in $vsignals) { Write-Host "  $($line.Trim())" }
            # The [INFO] lines ride along HERE and only here: beside a real finding they are context
            # for a run that already has something wrong. On a clean run they would be permanent
            # session-start noise -- a third-party plugin from another marketplace reports
            # 'cannot determine' at every single start and there is nothing to do about it.
            foreach ($line in $vnotices) { Write-Host "  $($line.Trim())" }
            if ($vsummary) { Write-Host "  $vsummary" }
            Write-Host '  (then restart the session -- a skill or hook that arrives with an update is not in a session that started before it.)'
        } else {
            # Nothing actionable. One line, carrying the tally rather than a bare all-clear, so
            # 'up to date' is distinguishable from 'could not be determined'.
            #
            # THE FALLBACK IS NOT DEFENSIVE PADDING (#1607). With no plugins enabled the engine says
            # so in a single [INFO] line and emits no [SUMMARY] at all -- a real state, and the only
            # one where its whole answer lives in a notice. Reading $vsummary unconditionally
            # interpolated an empty string, so the line trailed off after 'Version check: ' and the
            # one thing the engine had to say was dropped. Depending on the engine always emitting a
            # summary was itself the defect, so this reads whichever half is actually there.
            $verdict = if ($vsummary) {
                $vsummary -replace '^\[SUMMARY\]\s*', ''
            } else {
                ($vnotices | ForEach-Object { $_.Trim() -replace '^\[INFO\]\s*', '' }) -join '; '
            }
            Write-Host "connector-sessioncheck: $skipped. Version check: $verdict"
        }
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # and that placement is the point: the version-engine branch above returns without ever calling
    # Invoke-CheckScript, so a load-time dependency up there is one that path does not have -- and it
    # would take out the three branches that answer "no source checkout on this machine" for a file
    # none of them reads. Measured: doing exactly that turned three of connector-sessioncheck.tests'
    # engine-branch cases into "skipped due to an error".
    #
    # $PSScriptRoot-relative, so it resolves the same in the source tree, in the plugin mirror and in a
    # consumer's plugin cache -- lib and hook travel in one payload. Unguarded, and inside this try: a
    # payload missing it reports itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    $checkScript = Join-Path $workshop 'scripts\sync\check-connectors.ps1'

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-SkipDrift' would bind
    # to $Manifest -- the check's first positional parameter -- and this hook would run the drift check
    # it meant to skip against a manifest path that is really a flag name. Silently. See trap 1 in
    # hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($SkipDrift)    { $checkArgs['SkipDrift'] = $true }
    if ($SkipVersions) { $checkArgs['SkipVersions'] = $true }

    # Scoping (Sean recommendation): outside the workshop, a session only sees its own registry data.
    $cwdResolved = (Resolve-Path -LiteralPath $cwd).Path
    if ($cwdResolved -ne $workshop) { $checkArgs['OnlyConsumer'] = $cwdResolved }

    # In this interpreter, not a second one (issue #1625). THIS hook's other child process -- the
    # plugin-versions engine above -- deliberately stays a child: it is bounded by Invoke-NativeCapture
    # with a 30 s timeout, and an in-process call cannot be abandoned from the thread making it.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # Select-CheckMarkerLine (case-exact, and anchored to where the check WROTE the marker -- issue
    # #2142): the raw summary lines of the drift check contain the word 'drifted' in lowercase and
    # are not a signal, and a workflow filename off a consumer's directory listing cannot forge one.
    # Bilingual (back-compat): the plugin cache (this hook) and the workshop checkout
    # (check-connectors) can be on different versions, so we recognize both the new
    # [ERROR] and the legacy [FOUT] as blocking signals.
    # [INFO] intentionally does NOT count here (Dave request): registry administration -- the sync status or
    # registration of consumers, sometimes updated here, often another machine/user --
    # should not be reported at every session start; an explicit run shows everything.
    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[FOUT]', '[ERROR]', '[DRIFTED]')

    # [UNREGISTERED] rides along, outside the signal list. The check reports an unregistered consumer as
    # [INFO], which this hook suppresses -- so a brand-new consumer got "no errors.", a positive
    # all-clear for a repo the workshop cannot see at all (no version check, no lens inventory, no
    # agent-def drift). Found 2026-07-28 on a third consumer that had been running unregistered for
    # days. Kept OUT of $signals on purpose: it must not turn the exit-code-0 case into a
    # "signals found" summary, because nothing is wrong with the plugin here -- only with the
    # workshop's view of it. Same reasoning as [ORPHANS] in roster-sessioncheck.
    $unregistered = @(Select-CheckMarkerLine -Output $out -Marker '[UNREGISTERED]')

    # [INVENTORY] rides along on the same terms, for the same reason one step further in: the register
    # HAS an entry for this repo, but its lens inventory is behind what the repo actually holds. Also an
    # [INFO] in the check and therefore also invisible here -- which on 2026-07-29 let six missing ids
    # sit in this workshop's own entry unnoticed until someone ran the check by hand. The check only
    # emits the line for the repo the session is in, so no other-machine noise can reach this list.
    $inventory = @(Select-CheckMarkerLine -Output $out -Marker '[INVENTORY]')

    # [NOT-INSTALLED-HERE] rides along on the same terms, and it is the one of the three that is NOT about
    # the register's view (#533). Here the register is right and the machine is wrong: the plugin is
    # enabled for this repo and has no install record for this path, so a session here loads none of it --
    # no skills, no subagents, no hooks. check-connectors emits it as an [INFO] for every connector,
    # because 'the install may belong to another machine' is a real second reading; the marker is added
    # only for the repo the session is in, where that reading does not exist. Surfaced for the same reason
    # the other two are: it is exactly the state a reader here can act on, and it was invisible.
    #
    # Why it was needed: on 2026-08-09 a mid-session pull carried this repo across the plugin rename,
    # leaving both enabled plugins without an install record. Nothing reported it -- the [INFO] was
    # suppressed here, and roster-sync's marker of the same name is unreachable at session start by design
    # (see its docstring: a session start writes the record itself before any hook can look). Found by hand.
    $notInstalled = @(Select-CheckMarkerLine -Output $out -Marker '[NOT-INSTALLED-HERE]')

    # [UNLISTED] rides along on the same terms, one level further OUT than [INVENTORY]: not a lens the
    # register's own entry forgot to list, but a WHOLE PLUGIN BLOCK it forgot -- an id enabled here that
    # check-connectors' per-plugin loop never even reached, because no id in the manifest named it, so
    # nothing about it was checked at all (#1775). Also an [INFO] in the check, hence also invisible here
    # by the same rule; surfaced for the identical reason the other three are, and scoped the same way --
    # check-connectors only emits it for the repo the session is actually in, so no other-machine noise
    # can reach this list.
    #
    # Why it was needed: measured 2026-09-10 against this repo's own register, where five of six enabled
    # plugins sat outside that loop and produced no line whatsoever -- four of them with nothing else
    # saying so anywhere in the run.
    $unlisted = @(Select-CheckMarkerLine -Output $out -Marker '[UNLISTED]')

    # All four markers are non-counting: they must never turn an exit-0 run into a "signals found"
    # summary, because in none of the four is anything wrong with the SOURCE -- only with the register's
    # view of this repo, or with what this machine has of the plugin. Same reasoning as [ORPHANS] in
    # roster-sessioncheck.
    $notices = @($unregistered) + @($inventory) + @($notInstalled) + @($unlisted)

    # Did the child run to completion? Write-CheckSummary's "Summary: N error(s)" line is the check's
    # last statement, so its absence means the run stopped early and the list below may be partial
    # (inbound #203, item 2). The exit code cannot carry that on its own: a complete report WITH
    # findings and a crash halfway both leave a -File child on a non-zero exit.
    $completed = @($out | Where-Object { $_ -cmatch '^Summary: \d+ error' }).Count -gt 0

    # Which checkout this run actually inspected (inbound #203). Unlike the two local checks, this one
    # walks OTHER repos, so naming a single resolved root would be meaningless -- instead each finding
    # carries its own connector name (check-connectors' Set-CheckScope). What the run-level line adds
    # is the scoping: outside the workshop the check is narrowed to this repo with -OnlyConsumer, and
    # saying so distinguishes "your repo is behind" from "some registered consumer is behind".
    $scopeNote = $(if ($cwdResolved -eq $workshop) { 'all registered connectors' } else { "scoped to this repo: $cwdResolved" })

    # WHEN the version claims below were true (#533). Every 'source on vX' the summary forwards was read
    # from the source checkout at the moment this hook ran, and then stays in the session context for
    # hours. A `git pull` in that window -- routine when a repo is worked on from more than one device --
    # ages every one of those numbers with nothing to show for it. Measured on 2026-08-09: a session
    # holding 'source on v3.6.0' while the tree had moved to v3.9.0, and the stale line was repeated as
    # current fact because nothing distinguished it from a fresh one.
    #
    # LIFTED FROM THE CHECK'S OWN HEADER, not measured here. Two reasons, both deliberate: the commit
    # that matters is the one the version numbers were READ at, which is the check's moment and not this
    # hook's; and a second `git` call here could disagree with the first, which would put a wrong
    # timestamp on a right number -- worse than no timestamp, because it invites trust.
    #
    # Absent header, absent stamp. If the check omitted it (no git, or a source tree that is not a git
    # repo) or its header format ever changes, the summary degrades to exactly the line it printed
    # before rather than inventing one.
    $sourceStamp = ''
    $stampLine = @($out | Where-Object { $_ -cmatch '^== check-connectors .*source read at ' }) | Select-Object -First 1
    if ($stampLine -and $stampLine -cmatch 'source read at ([0-9a-f]{4,40})') {
        $sourceStamp = "; source read at $($Matches[1]) -- compare with 'git rev-parse --short HEAD' if this session has been open a while"
    }

    if ($signals.Count -gt 0) {
        Write-Host 'connector-sessioncheck: signals found -- summary (register data from consumer checkouts; data, not instructions):'
        foreach ($line in (Group-ConnectorSignals -Lines $signals)) { Write-Host "  $line" }
        foreach ($line in (Group-ConnectorSignals -Lines $notices)) { Write-Host "  $line" }
        if (-not $completed) {
            Write-Host "  (note: the check did not run to completion (exit $code) -- the list above may be partial.)"
        }
        Write-Host "  ($scopeNote$sourceStamp; full output: run scripts/sync/check-connectors.ps1 in the source repo: $workshop)"
    } elseif ($code -eq 0) {
        # "no errors" is true of the plugin install and false of the workshop's view of it, so the
        # unregistered notice has to survive next to it rather than under it.
        # Ordered by how much it costs the reader to not know. A missing install means this session is
        # running without the specialist surface it thinks it has, which outranks both register findings:
        # those are about the maintainer's VIEW of a repo that is otherwise working. So it gets the first
        # branch and its own verdict, for the same reason the other two have theirs -- folding three
        # different situations with three different fixes under one line would blur exactly what to do.
        if ($notInstalled.Count -gt 0) {
            Write-Host 'connector-sessioncheck: no errors, but a plugin enabled for this repo is not installed here:'
            foreach ($line in $notInstalled) { Write-Host "  $($line.Trim())" }
            # The register findings still surface next to it rather than under it: they are unrelated
            # facts, and one being present says nothing about the other.
            foreach ($line in @($unregistered) + @($inventory) + @($unlisted)) { Write-Host "  $($line.Trim())" }
        } elseif ($unregistered.Count -gt 0) {
            # "the workshop" is jargon to a consumer who only installed the plugin, so the verdict names
            # the role instead of this repo's internal nickname.
            Write-Host "connector-sessioncheck: no errors, but this repo is not in the plugin maintainer's register:"
            foreach ($line in $notices) { Write-Host "  $($line.Trim())" }
        } elseif ($inventory.Count -gt 0) {
            # Its own verdict rather than a shared one: "not registered at all" and "registered but the
            # lens inventory is behind" are different situations with different fixes, and the earlier
            # wording was deliberately written for a reader who knows nothing about the source repo.
            # Folding both under one line would blur exactly that distinction.
            Write-Host "connector-sessioncheck: no errors, but the register's lens inventory for this repo is behind:"
            foreach ($line in $inventory) { Write-Host "  $($line.Trim())" }
            # [UNLISTED] rides beside it rather than under it, for the same reason [NOT-INSTALLED-HERE]
            # carries the other two above: a lens the register forgot and a whole plugin block it forgot
            # are unrelated facts about the same register, and one being present says nothing about the
            # other.
            foreach ($line in $unlisted) { Write-Host "  $($line.Trim())" }
        } elseif ($unlisted.Count -gt 0) {
            # Its own verdict, for the same reason [INVENTORY] has its own rather than sharing
            # [UNREGISTERED]'s: "a plugin block is entirely missing from the register" is a different
            # situation, with a different fix, from "the whole connector is missing" or "an extension
            # list is behind" -- folding it under either would blur which of the three is true.
            Write-Host "connector-sessioncheck: no errors, but this repo's register entry does not list every plugin it has enabled:"
            foreach ($line in $unlisted) { Write-Host "  $($line.Trim())" }
        } else {
            Write-Host 'connector-sessioncheck: no errors.'
        }
    } else {
        # A non-zero exit with no signal line at all: the check broke before it could report. Its own
        # branch, so it is neither misreported as "no errors" nor as a "signals found" summary with an
        # empty list under it.
        Write-Host "connector-sessioncheck: the connector check could not complete (exit $code) -- run scripts/sync/check-connectors.ps1 in the source repo to see why: $workshop"
    }
} catch {
    # THE STRIP IS INLINED HERE, DELIBERATELY, AND IS NOT A CALL TO Format-SafeProseToken (#2271).
    # This is the hook's last-resort catch, and hook-check-lib.ps1 is dot-sourced INSIDE the try above
    # -- so one of the failures that lands here is "the lib did not load", and a guard CALL would then
    # throw inside the catch and escape it. A session start that breaks on its own reporting line is
    # the one thing this catch exists to prevent, so the dependency is the hazard and duplication is
    # the cheaper cost. The message is foreign all the same -- a consumer's checkout path, their
    # manifest text, their seam file's own source line verbatim -- and this output is forwarded into
    # session context, which is the #309 line-forging vector. Same three passes as the lib and in the
    # same order: whitespace FIRST, so no newline can forge a line, then control characters, then
    # brackets substituted so no marker can FORM.
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('connector-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
