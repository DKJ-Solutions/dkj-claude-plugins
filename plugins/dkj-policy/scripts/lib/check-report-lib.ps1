<#
.SYNOPSIS
    Shared [OK]/[INFO]/[ERROR] report helpers for the sync/check scripts (single source of truth,
    issue #114).

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot (NOT
    $repoRoot) -- unlike scripts/repo-config.ps1 / scripts/lib/branch-info.ps1, this lib is not
    repo-owned, so it does not need a consumer-side scaffold. It travels as part of the SAME
    plugin/mirror payload as its callers, so a $PSScriptRoot-relative path resolves correctly
    whether the caller runs from the workshop root, a consumer's plugin cache, or the plugin mirror
    tree (the same reasoning new-branch.ps1 already relies on for its sibling
    new-branch.ps1 call):

        . (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')          -- from scripts/sync/*
        . (Join-Path $PSScriptRoot '..\..\scripts\lib\check-report-lib.ps1') -- from skills/<name>/*

    Callers of Write-Info/Write-Failure/Write-CheckSummary must declare $script:errors = 0 and
    $script:infos = 0 before use -- dot-sourcing runs in the caller's own scope (verified: a
    function defined via dot-source increments the CALLER's $script: variable, not one local to
    this file), so the counters live with the caller, not here.

    Supplies:
      - Write-Ok / Write-Skip                        -- plain report lines, no counting.
      - Write-Coverage                               -- ONE non-counting [COVERAGE] line per category
                                                          stating how many items it examined, so a
                                                          verdict is never read without its coverage
                                                          and an empty category announces itself
                                                          instead of passing in silence (issue #221).
      - Write-Info / Write-Failure                       -- report lines that also bump
                                                          $script:infos / $script:errors.
      - Write-CheckSummary                            -- the "Summary: N error(s), N info
                                                          signal(s)." line + matching exit code
                                                          (0 = no errors, 1 = at least one). Doubles
                                                          as the RAN-TO-COMPLETION marker the session
                                                          hooks look for (see Resolve-CheckRoot's
                                                          block below for why).
      - Resolve-CheckRoot / Write-CheckScope /        -- naming WHICH repo a finding is about
        Set-CheckScope                                  (inbound #203).
      - Format-SafeToken / Format-SuspectToken        -- make a value from a consumer-owned JSON file
                                                          safe to PRINT into a line the session hooks
                                                          forward (inbound #309). A plugin id is an
                                                          'enabledPlugins' KEY NAME, i.e. an arbitrary
                                                          JSON string that may carry newlines -- so an
                                                          unsanitized one could forge a line in the
                                                          session context. Display only; the slug
                                                          guards below remain what decides whether a
                                                          value may become a PATH.
      - Test-TokenChanged                             -- the ORDINAL "did sanitizing change anything"
                                                          test the two announcing forms share (#1419).
                                                          Never '-ne': that comparison is culture-aware
                                                          and treats format characters as ignorable.
      - Format-SafePathToken / Format-SafeProseToken  -- the same job for the two values an id charset
                                                          would mangle: a file path (inbound #414) and
                                                          an echoed line of the consumer's own prose
                                                          (#1419). Same two classes, one shared answer
                                                          for control characters and a per-shape one
                                                          for square brackets.
      - Test-PluginNameSlug / Test-PluginMarketplaceSlug -- the plugin-id / '@marketplace' slug
                                                          guards (values from settings.json /
                                                          manifests become filesystem paths, so
                                                          never trusted unvalidated).
      - Get-SettingsChainPaths / Get-EnabledPlugins    -- WHICH plugins this repo has enabled, read
                                                          from the same settings chain Claude Code
                                                          honors instead of settings.json alone
                                                          (inbound #294). Single source for the
                                                          bootstrap, check-roster-sync and
                                                          check-connectors.
      - Get-InstallRecord / Test-PluginInstalledHere  -- the OTHER half Claude Code needs: an install
                                                          record for THIS project path in
                                                          ~/.claude/plugins/installed_plugins.json
                                                          (inbound #302). An enable without a record
                                                          loads nothing, and every check used to
                                                          report the full specialist surface anyway.
      - Get-UserClaudeHome / Get-JsonField / Format-LabelList -- the small shared pieces those two
                                                          rest on: where '~/.claude' is, a
                                                          StrictMode-safe field read on
                                                          consumer-owned JSON, and the one place a
                                                          list of layer labels becomes prose.
      - Resolve-PluginDir                             -- resolve a plugin's versioned dir under a
                                                          plugin cache root (honors
                                                          $env:CLAUDE_PLUGIN_ROOT when it points at
                                                          THIS plugin; else the semantically highest
                                                          version -- [version]-sort, not
                                                          string-sort, so 1.10.0 beats 1.9.0 -- that
                                                          has an agents/ dir).
      - Get-DisplayName                               -- sanitize + capitalize a raw agent name into a
                                                          display name (single source for sync-roster
                                                          and check-roster-sync -- issue #145).
      - Get-LensFamily / Get-LensDirCandidates        -- the family segment of the consumer repo-lens
                                                          path, and the ordered dirs to look for a
                                                          lens in (single source for the writers
                                                          bootstrap.ps1/sync-roster.ps1 and the reader
                                                          check-roster-sync.ps1 -- issue #179).
      - Get-RosterIdTokenPattern                      -- the regex that recognizes a '<group>-<id>'
                                                          specialist token in free roster prose,
                                                          bounded so it does not also match inside an
                                                          ISO date (single source for
                                                          check-roster-sync.ps1's Test-InRoster and
                                                          its orphan-scan -- issue #182).

    Not every caller needs every function -- e.g. sync-roster.ps1 uses its own non-counting
    Write-Info/Write-Failure (it tracks created/kept/proposed, not error/info signals, and always
    exits 0), so it only dot-sources this file for Write-Ok, Resolve-PluginDir and the slug guards,
    and keeps its own Write-Info/Write-Failure defined afterward (a later definition in the same scope
    intentionally shadows the one from this file -- ordinary PowerShell function resolution, not a
    workaround).

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# --- Scope: naming WHICH repo a finding is about (inbound #203) ----------------------------------
# A finding is only actionable when you know which repo it concerns. The three SessionStart hooks
# filter their child's output down to the signal lines, and that filter threw away the one line
# naming the inspected repo -- so on 2026-07-27 a script-contract alarm sent an investigation into
# the wrong repo. The check was right; it was right ABOUT ANOTHER REPO than the session it reported
# into, and the report had no way to say so. A gate whose findings you cannot check is a gate you
# learn to ignore, so the fix is diagnosability, not detection.
#
# Two mechanisms, because the two shapes of check need different things:
#   - Write-CheckScope -- ONE [SCOPE] line per run, for a check whose whole run inspects a single
#     repo root (check-script-contract, check-roster-sync). It also names HOW that root was
#     resolved, since the silent git-root fallback is precisely how a check ends up inspecting a
#     different repo than the session it reports into.
#   - Set-CheckScope -- a short label that Write-Info/Write-Failure prepend, for a check that walks
#     SEVERAL scopes in one run (check-connectors: one block per connector). A per-run line cannot
#     disambiguate there, and the hook may surface a single line in isolation, so the finding itself
#     has to carry its subject.
#
# [SCOPE] is a non-counting token like [OK]/[SKIP]: it is context, not a signal, and must never move
# the error/info counts or the exit code.
$script:CheckScopeLabel = ''

# --- What must never survive into a report line (inbound #309, inbound #414, #1419) --------------
# (#1419 is a same-repo issue, not an inbound one -- the label is per issue, not per list.)
# Two classes, named here because the sanitizers below have to AGREE about them and differ only in what
# they do with the second:
#   - CONTROL CHARACTERS ('\p{C}' -- Cc, Cf and the surrogates): newlines, ANSI escape sequences and
#     bidi overrides. The SessionStart hooks forward this output into session context, where "the hook
#     labels its output 'data, not instructions'" does not cover a value that fabricates a line of its
#     own, repaints a terminal, or reverses the reading order of the text around it.
#   - SQUARE BRACKETS. The hooks decide what to surface, and how loudly, by matching markers like
#     '[ERROR]' over a check's WHOLE output -- so a bracket out of an untrusted value is not merely odd,
#     it is COUNTED.
# Named rather than repeated per function so the shared half stays one decision: what each sanitizer
# DOES with a class is its own argument, but which class it is arguing about is not.
#
# A THIRD CLASS IS CLOSED BY THE WHITESPACE COLLAPSE, NOT BY EITHER PATTERN, and it is written down here
# because nothing about the code says so. U+2028 LINE SEPARATOR and U+2029 PARAGRAPH SEPARATOR are
# category Zl/Zp -- '\p{C}' does not match them, and entry-scaffold-lib.ps1's line splitter does not split
# on them either, so a consumer line can genuinely carry one. What neutralizes them is the
# "-replace '\s+', ' '" pass every sanitizer below runs, because .NET's '\s' DOES match both. That makes
# the protection real but incidental: reorder or drop that pass "because stripping controls first reads
# more naturally" and a line-forging channel reopens silently. The asserts in check-report-lib.tests.ps1
# are what stop that, and this comment is what tells the next editor which pass they belong to.
$script:CheckReportControlPattern = '\p{C}'
$script:CheckReportMarkerPattern  = '[\[\]]'

# AND "DID SANITIZING CHANGE ANYTHING" IS ASKED ORDINALLY, NEVER WITH '-ne'. PowerShell's string '-eq'
# and '-ne' compare culture-sensitively, and an invariant-culture comparison treats format characters
# (Cf) as IGNORABLE -- so "start<U+202E>end" -ne 'startend' is FALSE. The two functions below that say
# out loud when the display differs from the raw value would therefore have stayed silent for exactly
# the class most worth announcing: a bidi override, a zero-width joiner, a soft hyphen. Measured by this
# branch's own bidi assert, on the new function, in the same shape Format-SuspectToken had carried
# unnoticed since #309.
function Test-TokenChanged {
    param([AllowEmptyString()][string]$Before = '', [AllowEmptyString()][string]$After = '')
    return (-not [string]::Equals($Before, $After, [System.StringComparison]::Ordinal))
}

function Format-SafeToken {
    <# Make a value from a consumer-owned JSON file safe to PRINT into a report line.

       WHY THIS IS A FUNCTION NOW (inbound #309). This sanitization was written inline in
       Set-CheckScope, with the reasoning recorded there: a JSON string may carry newlines and control
       characters, so an unsanitized value printed into output the SessionStart hooks forward could
       FORGE AN EXTRA LINE in the session context -- and "the hook labels its output 'data, not
       instructions'" does not cover a value that fabricates a line of its own. That reasoning was
       correct and it was applied to exactly one value: the scope label.
       Everything else printed from the same untrusted source -- above all the plugin ids, which are
       'enabledPlugins' KEY NAMES from a settings file and therefore arbitrary JSON strings -- went out
       raw. Since #302 more of those lines are surfaced by the hooks than before ([NOT-INSTALLED-HERE]
       joins ids into one line), so the surface grows with each marker added. One definition, applied at
       every point where such a value enters a message, is the same move Get-SeamPaths and
       Get-OrchestratorNote exist for: the pair that must not drift gets one source.

       Restricted to the charset real repo/plugin/specialist ids need ('a-z', '0-9', '.', '_', '/',
       '@', '-', space), whitespace collapsed to single spaces, trimmed, and length-capped. Note what
       this deliberately does NOT do: it is not validation and never rejects. Test-PluginNameSlug and
       Test-PluginMarketplaceSlug are the guards that decide whether a value may become a PATH; this
       one only decides how it may be DISPLAYED. A caller that reports a value *because* it is
       suspect should say when the display differs from the raw value -- otherwise a sanitized id
       reads as a valid one, which would hide the very thing being complained about. #>
    param(
        [AllowEmptyString()][string]$Value = '',
        [int]$MaxLength = 120
    )
    $clean = ($Value -replace '[^A-Za-z0-9 ._/@-]', '') -replace '\s+', ' '
    $clean = $clean.Trim()
    if ($clean.Length -gt $MaxLength) { $clean = $clean.Substring(0, $MaxLength) }
    return $clean
}

function Format-SafePathToken {
    <# The path-shaped sibling of Format-SafeToken, for a finding whose SUBJECT is a file path.

       WHY A SECOND FUNCTION RATHER THAN A WIDER CHARSET (inbound #414). Format-SafeToken's allowed set
       is built for ids -- it strips '~', '\' and ':' among others, which is exactly right for a plugin
       id and exactly wrong for a path: 'C:\Users\x\.claude\...' comes back as 'CUsersx.claude...' and
       '~/.claude/...' loses the '~' that says where it starts. A finding that exists to tell a reader
       WHICH path is missing must not print a path they cannot look up, and Format-SafeToken's own
       docstring says as much -- "a caller that reports a value because it is suspect should say when
       the display differs from the raw value". Widening that function instead would have loosened the
       guard on every id it protects, to serve a case it was not written for.

       What is actually stripped, and why only this much:
         - CONTROL CHARACTERS, newlines included. This is the real risk the #309 reasoning names: these
           lines are forwarded into session context by the SessionStart hooks, and a value carrying a
           newline could forge a line of its own.
         - SQUARE BRACKETS. The hooks decide what to surface, and how loudly, by matching markers like
           '[ERROR]' over a check's whole output -- so a path containing one would not merely look odd,
           it would be COUNTED. A bracket in a real path is vanishingly rare; a bracket that changes a
           hook's verdict is not something to leave to chance.
       Everything else is kept, because everything else is what makes a path a path. Both classes come
       from the shared patterns above, so the prose sibling below argues about the same two things. #>
    param([AllowEmptyString()][string]$Value = '', [int]$MaxLength = 200)
    $clean = (($Value -replace $script:CheckReportControlPattern, '') -replace $script:CheckReportMarkerPattern, '') -replace '\s+', ' '
    $clean = $clean.Trim()
    if ($clean.Length -gt $MaxLength) { $clean = $clean.Substring(0, $MaxLength - 3) + '...' }
    return $clean
}

function Format-SafeProseToken {
    <# The prose-shaped sibling, for a finding that ECHOES A LINE OF THE CONSUMER'S OWN TEXT (#1419).

       WHY A THIRD FUNCTION RATHER THAN EITHER EXISTING ONE. check-consumer-prose.ps1 prints the
       offending line out of a consumer's markdown so the reader recognises what to repair, and neither
       sibling can carry it: Format-SafeToken's id charset deletes most of a sentence (every ':', '(',
       ',' and quote in it), and Format-SafePathToken -- exactly right for a path -- deletes the square
       brackets that in prose are a markdown link. The value here is not a token at all, it is a
       sentence, and the only property that has to hold is that it cannot be mistaken for output of ours.

       CONTROL CHARACTERS ARE REMOVED, AND THE LINE SAYS SO. Same class and same reasoning as the
       sibling, with Format-SuspectToken's doctrine attached rather than assumed: this line is echoed
       BECAUSE somebody is about to edit it, so a reader shown a silently altered preview would go
       hunting for text that is not in the file. NO NEWLINE SURVIVES THIS FUNCTION, FOR ANY CALLER --
       and that is a guarantee of the code below, not a property of who calls it: the '\s+' collapse
       runs FIRST and '\s' matches a newline, so multi-line input arrives here legitimately and leaves
       as a single line. WHICH IS WHY THAT COLLAPSE IS LOAD-BEARING and must not be dropped as cosmetic
       or moved behind a condition. Callers deliberately send un-split text, and the measured one is
       check-claude-home.ps1's parse error: ConvertFrom-Json's message EMBEDS the offending document,
       newlines and all, and that document is attacker-shaped by construction. This used to read as a
       claim about "today's one caller" pre-splitting into lines, which was false for two existing
       callers by then and handed the next reader exactly the wrong licence (#1813). No census here for
       command-probe-lib.ps1's reason: a list of call sites is a snapshot that goes stale silently while
       the tree keeps being written, and 'grep' is the inventory.

       SQUARE BRACKETS ARE SUBSTITUTED, NOT DELETED, and this is the one place the three siblings
       deliberately differ. The property that matters is only that no marker can FORM, and '(ERROR)'
       cannot be counted by any hook. Bounded honestly: this closes what a hook COUNTS, not what an eye
       mistakes -- every hook regex here matches literal ASCII brackets, so a fullwidth U+FF3B passes
       through and could still LOOK like a marker to somebody scanning the terminal. That is a display
       resemblance with no mechanical effect, and widening the pattern to chase homoglyphs would start
       deleting ordinary punctuation out of prose to prevent nothing measurable.
       In an id or a path a bracket is vanishingly rare, so deleting it
       costs nothing; in prose it is ordinary and load-bearing, and deleting it turns '[the guide](x.md)'
       into something the reader has to reconstruct. So the substitution is uniform and carries NO note:
       it is a display convention like the whitespace collapsing beside it, not a claim about this line.

       WHAT MAKES THE REMAINING LOSS AFFORDABLE is that the preview is not the locator. The caller
       prints '<file>:<line>' immediately above it, so the echo is there for recognition -- which is
       also why a cap and an ellipsis are enough for an over-long line. #>
    param([AllowEmptyString()][string]$Value = '', [int]$MaxLength = 200)
    # Whitespace first and separately: a tab is both '\s' and a control character, and collapsing it to
    # a space is cosmetic, so it must not trip the "held characters that cannot be printed" note below.
    $normalized = $Value -replace '\s+', ' '
    $stripped = $normalized -replace $script:CheckReportControlPattern, ''
    $hadControl = Test-TokenChanged -Before $normalized -After $stripped
    $clean = (($stripped -replace '\[', '(') -replace '\]', ')').Trim()
    if ($clean.Length -gt $MaxLength) { $clean = $clean.Substring(0, $MaxLength - 3) + '...' }
    if ($hadControl) {
        if (-not $clean) { return "<unprintable> (the raw line held nothing displayable; $($Value.Length) character(s))" }
        return "$clean (shown sanitized -- the raw line held characters that cannot be printed)"
    }
    return $clean
}

function Format-SuspectToken {
    <# For the case where the value IS the complaint: an invalid plugin id, a malformed marketplace.

       Returns the safe display form, plus an explicit note when sanitizing changed something -- so a
       reader is never shown a clean-looking id as the subject of an "invalid id" error while the real
       defect (a newline, a control character, sheer length) is exactly what was stripped out to make it
       printable. Without the note the message would be self-defeating: it would complain about a value
       and then show a different, plausible one. #>
    param([AllowEmptyString()][string]$Value = '', [int]$MaxLength = 120)
    $clean = Format-SafeToken -Value $Value -MaxLength $MaxLength
    if (Test-TokenChanged -Before $Value -After $clean) {
        if (-not $clean) { return "<unprintable> (the raw value held nothing displayable; $($Value.Length) character(s))" }
        return "$clean (shown sanitized -- the raw value held characters that cannot be printed)"
    }
    return $clean
}

function Set-CheckScope {
    <# Set (or, with no argument, clear) the short label Write-Info/Write-Failure prepend to every
       subsequent finding. Call it when entering a per-scope block and clear it when leaving, so
       findings that belong to the run as a whole are not attributed to the last scope walked.

       The label is SANITIZED via Format-SafeToken -- see that function for the reasoning and for why it
       is no longer inline here. check-connectors derives this label from a connector manifest's 'repo'
       and plugin 'id' fields, and unlike the '== connector: <repo>' header -- which the session hooks
       filter away -- the label travels INTO the session context. Same defense-in-depth reasoning as
       Test-PluginNameSlug and Get-DisplayName: manifest values are never used raw. #>
    param([string]$Label = '')
    $script:CheckScopeLabel = Format-SafeToken -Value $Label
}

function Format-CheckScoped {
    <# Prefix $Msg with the active scope label, if one is set. Kept separate from Write-Info/
       Write-Failure so the prefixing rule has one implementation rather than two. #>
    param([string]$Msg)
    if ($script:CheckScopeLabel) { return "$($script:CheckScopeLabel): $Msg" }
    return $Msg
}

function Write-Ok   ([string]$Msg) { Write-Host "  [OK]    $Msg" -ForegroundColor Green }
function Write-Skip ([string]$Msg) { Write-Host "  [SKIP]  $Msg" -ForegroundColor DarkGray }
function Write-Info ([string]$Msg) { $script:infos++;  Write-Host "  [INFO]  $(Format-CheckScoped $Msg)" -ForegroundColor Yellow }
function Write-Failure ([string]$Msg) { $script:errors++; Write-Host "  [ERROR] $(Format-CheckScoped $Msg)" -ForegroundColor Red }

function Write-Coverage {
    <# ONE [COVERAGE] line stating how many items a category actually examined -- so a verdict is
       never read without its coverage (issue #221).

       THE DEFECT THIS EXISTS FOR, measured 2026-07-30. check-consumer-drift's persona section ended
       with "Persona drift is INFORMATIONAL: 0 drifted." Run against a repo holding no lens files at
       all, it printed exactly that: a clean verdict over four personas it never compared. "0 drifted
       out of 0 compared" and "0 drifted out of 4 compared" were the same sentence, and the reader had
       no way to tell a torn-down repo from a healthy one. A gate that iterates a category and finds it
       empty must SAY the category was empty; the alternative is not a false pass, it is worse -- a
       true statement that reads as a different, false one.

       Right for a deliberate teardown, wrong for an accidental loss: a silent skip cannot distinguish
       an operator's removal from a bad merge or a wrong path, and the one line it costs is what keeps
       the gate honest.

       [COVERAGE] is a NON-COUNTING token, like [OK]/[SKIP]/[SCOPE]: coverage is context about the
       run, not a finding about the repo, so it must never move an exit code or a signal count. A
       category that is legitimately empty is not an error -- it is a fact the reader needs.

       -Of is optional: pass it when the category has a known denominator (4 personas exist, 0 were
       compared), omit it when the count IS the whole story (57 files scanned). -Note carries the
       reason an empty category is empty, which is the part a reader cannot infer from a zero. #>
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][int]$Checked,
        [int]$Of = -1,
        [string]$Note = ''
    )
    $what = if ($Of -ge 0) { "checked $Checked of $Of" } else { "checked $Checked" }
    $msg = "[$Category] $what"
    if ($Note) { $msg += " -- $Note" }
    # An empty category is the case this helper exists to make visible, so it is the one that does not
    # blend into the dark-gray run chatter.
    $color = if ($Checked -eq 0) { 'Yellow' } else { 'DarkGray' }
    Write-Host "  $msg" -ForegroundColor $color
}

function Write-CheckSummary {
    <# Prints "Summary: N error(s), N info signal(s)." (green if no errors, red otherwise) and
       exits the script: 1 if $script:errors -gt 0, else 0. Called directly by both
       check-connectors.ps1 and check-roster-sync.ps1 -- no more duplicated ending to mirror. #>
    Write-Host "`nSummary: $($script:errors) error(s), $($script:infos) info signal(s)." -ForegroundColor $(if ($script:errors -gt 0) { 'Red' } else { 'Green' })
    if ($script:errors -gt 0) { exit 1 }
    exit 0
}

function Resolve-CheckRoot {
    <# The dual-context repo-root resolution the local checks share (check-script-contract.ps1,
       check-roster-sync.ps1): -ConsumerPathOverride wins (a fixture pointing at a throwaway
       consumer), then $env:CLAUDE_PROJECT_DIR (a consumer running the plugin mirror inside a
       session), then the git root of the inherited working directory.

       Returns Path (resolved, or $null when nothing could be resolved), Source ('override' /
       'CLAUDE_PROJECT_DIR' / 'git-root'), and Note -- a human-readable explanation of what Source
       means for trusting the finding.

       Why the Source matters (inbound #203, item 3): that last fallback used to be silent, so the
       check could inspect a completely different repo than the session it reported into without a
       word about it. It is not a failure -- a deliberate run from the workshop root legitimately
       lands there -- but inside a session it means CLAUDE_PROJECT_DIR was absent and the root came
       from whatever directory the process happened to inherit. That is worth saying out loud.

       git rev-parse is a query command: it writes its result to stdout and only real errors to
       stderr, so it needs none of native-capture-lib's EAP dance (which exists for commands like
       git push whose progress chatter goes to stderr). It CAN legitimately fail -- outside a git
       work tree -- and then a caller under $ErrorActionPreference = 'Stop' used to die on a raw
       .Trim() against $null. Returning Path = $null instead lets the caller report that as one
       clean line. #>
    param([string]$Override = '')

    if ($Override) {
        $resolved = Resolve-Path -LiteralPath $Override -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Path   = $(if ($resolved) { $resolved.Path } else { $null })
            Source = 'override'
            Note   = 'explicitly passed in via -ConsumerPathOverride'
        }
    }

    if ($env:CLAUDE_PROJECT_DIR) {
        $resolved = Resolve-Path -LiteralPath $env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Path   = $(if ($resolved) { $resolved.Path } else { $null })
            Source = 'CLAUDE_PROJECT_DIR'
            Note   = 'from CLAUDE_PROJECT_DIR -- the repo of the session this is reported into'
        }
    }

    $top = $null
    $gitCode = $null
    $gitErr = ''
    try {
        # Stderr is captured rather than let through, because it is the ONLY thing that says why git
        # declined and it is what the refusal below quotes (#1917). Without it the reader gets an exit
        # code and nothing else; git's own line reaches the console by accident at best, and in a
        # redirected child not at all. 2>&1 merges it into the stream, so the ErrorRecord objects are
        # split back out by type -- a native command's stderr arrives as ErrorRecord under
        # $ErrorActionPreference = 'Stop' and would otherwise terminate the call it is explaining.
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $raw = @(& git rev-parse --show-toplevel 2>&1)
            $gitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prevEap }
        $outLines = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
        $errLines = @($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $gitErr = (($errLines | ForEach-Object { [string]$_ }) -join '; ').Trim()
        if ($gitCode -eq 0 -and $outLines.Count -gt 0) { $top = ([string]$outLines[0]).Trim() }
    } catch {
        $top = $null
        if (-not $gitErr) { $gitErr = $_.Exception.Message }
    }
    $resolved = $(if ($top) { Resolve-Path -LiteralPath $top -ErrorAction SilentlyContinue } else { $null })
    return [pscustomobject]@{
        Path   = $(if ($resolved) { $resolved.Path } else { $null })
        Source = 'git-root'
        Note   = 'CLAUDE_PROJECT_DIR was not set -- fell back to the git root of the working directory; inside a session that root can differ from the repo being reported into'
        # ADDITIVE, and only ever populated on this branch (#1917). The override and env-var branches
        # above return without them because no git call was made there -- $null means "git was not
        # asked", which is a different fact from "git answered 0". Every existing caller reads Path,
        # Source and Note and is untouched.
        GitExitCode = $gitCode
        GitError    = $gitErr
    }
}

function Resolve-RepoRootOrFail {
    <#
        THE SAME RESOLUTION AS Resolve-CheckRoot, WITH THE OPPOSITE VERDICT -- and that split is the
        whole point of this function existing beside it rather than inside it.

        Resolve-CheckRoot returns Path = $null when nothing answers, because its callers are ADVISORY
        checks: a SessionStart hook must not fail a session over a root it could not resolve, and a
        fixture tree that is deliberately not a repo is a normal input there. Its own docstring says so,
        and consumer-check-lib's Resolve-CheckRepoRoot says it again: "THE VERDICT IS NOT SHARED, ONLY
        THE RESOLUTION."

        An ACTING script is the other case. open-pr, ship-pr, cut-release, claim-issue, new-branch and
        the rest cannot do anything useful without a tree, so for them '' is not a tolerable answer --
        but the shape they all carried instead was

            $repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }

        which never reads git's exit code and dereferences its output. Where git answers nothing that is
        $null.Trim(), and under $ErrorActionPreference = 'Stop' -- which every one of them sets -- the
        script dies on "You cannot call a method on a null-valued expression", exit 1, having said
        nothing about what went wrong. Measured on 37 call sites, September 13, 2026 (#1917). It is the
        FIRST statement of most of those scripts, so its failure mode is the one a reader meets with no
        other context, and it is the mode that explains least.

        THE REFUSAL NAMES GIT'S EXIT CODE AND WHAT GIT SAID, because the cause was previously in the
        output only by accident -- git's own fatal line happens to precede the PowerShell error on a
        console, and in a redirected child, or where git fails for a reason that prints less, it is not
        there at all.

        -ScriptName is the caller's own name for the refusal's first line. It is not derived from
        $MyInvocation here: inside a dot-sourced function that reports this lib, not the script the
        reader ran.
    #>
    param(
        [string]$Override = '',
        [string]$ScriptName = ''
    )

    $scope = Resolve-CheckRoot -Override $Override
    if ($scope.Path) { return $scope.Path }

    $who = $(if ($ScriptName) { $ScriptName } else { 'this script' })
    Write-Host ''
    Write-Host "REFUSED: $who could not determine which repository to work on." -ForegroundColor Red
    Write-Host ''
    switch ($scope.Source) {
        'override' {
            Write-Host ("  -RepoRoot was given as '{0}', and that path does not exist." -f $Override) -ForegroundColor Yellow
        }
        'CLAUDE_PROJECT_DIR' {
            Write-Host ("  CLAUDE_PROJECT_DIR is set to '{0}', and that path does not exist." -f $env:CLAUDE_PROJECT_DIR) -ForegroundColor Yellow
            Write-Host '  That variable is how a session tells a plugin-mirror script which repo it is about,'
            Write-Host '  so a stale or mistyped value points every shared script at nothing.'
        }
        default {
            Write-Host '  No -RepoRoot was given and CLAUDE_PROJECT_DIR is not set, so the root had to come from'
            Write-Host ("  'git rev-parse --show-toplevel' in {0} -- and git declined." -f (Get-Location).Path) -ForegroundColor Yellow
            Write-Host ("  git exit code: {0}" -f $(if ($null -ne $scope.GitExitCode) { $scope.GitExitCode } else { '(git could not be run at all)' }))
            Write-Host ("  git said:      {0}" -f $(if ($scope.GitError) { $scope.GitError } else { '(nothing on stderr)' }))
            Write-Host ''
            Write-Host '  Run this from inside the checkout, or pass -RepoRoot, or set CLAUDE_PROJECT_DIR.' -ForegroundColor Green
        }
    }
    Write-Host ''
    exit 1
}

function Write-CheckScope {
    <# The one [SCOPE] line a single-root check prints before its findings, naming the inspected root
       and how it was resolved. Non-counting on purpose (see the scope block above): context, not a
       signal. The session hooks keep this line through their [ERROR] filter, so a surfaced finding
       always arrives with the repo it is about. #>
    param(
        [Parameter(Mandatory = $true)]$Scope,
        [string]$CheckName = ''
    )
    $who = $(if ($CheckName) { "$CheckName inspected " } else { 'inspected ' })
    Write-Host "  [SCOPE] $who$($Scope.Path) ($($Scope.Note))" -ForegroundColor Cyan
}

function Test-GitHubOwnerNameSlug {
    <#
        Is $Slug ('owner/name') held to GitHub's own shape -- an owner is alphanumeric with hyphens, a
        name adds '.' and '_' -- rather than merely escaped?

        PROMOTED HERE FROM check-connectors.ps1 (#1869), where its own docstring already argued the
        case: it was factored out inside that script so two call sites could hold ONE field to ONE
        bound rather than keep "a second, silently drifting copy of the regexes". A third caller
        outside that file -- check-consumer-siblings.ps1, which turns the same 'repo' field into the
        same kind of API call -- is that argument one step further on, so the function moved to the lib
        both scripts already dot-source instead of being copied into the second one.

        Returns @{ Ok; Reason } -- Reason is empty on success and is the caller's own failure sentence
        otherwise (the two distinct reasons Get-RemoteConsumerWorkflow already printed: no slash at all,
        or a slash with characters GitHub's own naming rules do not allow), so every existing call site
        keeps the exact wording it always had.
    #>
    param([Parameter(Mandatory = $true)][string]$Slug)
    $slash = $Slug.IndexOf('/')
    if ($slash -le 0 -or $slash -eq $Slug.Length - 1) {
        return @{ Ok = $false; Reason = "not an 'owner/name' slug" }
    }
    $owner = $Slug.Substring(0, $slash)
    $name  = $Slug.Substring($slash + 1)
    if ($owner -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$' -or $name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        return @{ Ok = $false; Reason = 'not a valid GitHub owner/name slug -- rejected before it became an API call' }
    }
    return @{ Ok = $true; Reason = '' }
}

function Test-PluginNameSlug {
    <# The plugin-name part of a plugin id (before '@') must be a simple lowercase slug before it
       becomes a path segment. #>
    param([Parameter(Mandatory = $true)][string]$Name)
    return ($Name -match '^[a-z0-9][a-z0-9-]*$')
}

function Test-PluginMarketplaceSlug {
    <# The marketplace part of a plugin id (after '@') must be a simple slug before it becomes a
       path segment. #>
    param([Parameter(Mandatory = $true)][string]$Marketplace)
    return ($Marketplace -match '^[A-Za-z0-9][A-Za-z0-9._-]*$')
}

# --- Which plugins are enabled here? (inbound #294) ----------------------------------------------
# THE DEFECT THIS EXISTS FOR, measured 2026-07-31 against 3.0.5. Three places read 'enabledPlugins'
# from .claude/settings.json and nothing else, while Claude Code honors a CHAIN of settings files --
# and this plugin's own settings proposal points the reader at the other end of it ("Copy desired
# blocks to .claude/settings.json (or settings.local.json)"). One blind spot, three symptoms, in both
# directions at once:
#
#   1. FALSE GREEN. roster-sessioncheck reported "roster in sync with the enabled plugins" for
#      DaveKJohn/life-hub while that repo had 0 lenses, 0 roster rows and no '@'-import -- in the very
#      session that loaded four of its skills and all three of its hooks. The check saw 0 enabled
#      plugins, so the [BOOTSTRAP] branch could not fire and the run fell through to the exit-0
#      "in sync" verdict. That is the one sentence roster-sessioncheck.ps1 says in as many words it
#      must never print: "roster in sync would be a bald-faced lie for a repo that has no roster."
#      Same class as the gap #225 closed, reached through a different door.
#   2. SILENT SKIP. bootstrap.ps1 placed 19 lenses instead of 24 and said nothing about the 5 it
#      never considered, because 'specialists-lifehub' was enabled in a file it did not read. The
#      closing count was consistent with what the bootstrap DECIDED and not with what the consumer has
#      switched on -- and the docstring's "without settings, only its own plugin" does not cover this
#      case at all: there ARE settings, they are one file over.
#   3. FALSE ALARM. check-connectors reported "plugin is NOT (or no longer) enabled" for that same
#      repo in that same session. Literally true about settings.json, false about the session.
#
# The pair is what makes this worth a shared helper rather than three local fixes: the identical
# blindness yields a reassuring lie in one check and a spurious error in another, so a reader who
# cross-references them learns to trust neither.
#
# WHY THE USER LAYER IS IN. A plugin enabled at user scope IS loaded in every session, so a repo that
# does not roster it genuinely has drift -- excluding that layer would rebuild the same false green one
# level up. Verified before including it that this widens nothing silently on the machine this was
# measured on: ~/.claude/settings.json carries 'enabledPlugins' as an EMPTY object, so the chain reads
# exactly as before there. Every finding names the layer it came from, so an enable arriving from
# outside the repo is diagnosable instead of mysterious.
#
# WHY PER-KEY PRECEDENCE. The layers are merged per plugin id (local > project > user), not
# wholesale-replaced, and an explicit 'false' in a higher layer therefore switches off an enable from a
# lower one. Claude Code's merge semantics for this particular map are not documented, and the
# measurement cannot distinguish the two (life-hub's settings.json had no key at all). Per-key was
# chosen deliberately because it errs in the safe direction for these three callers: it never LOSES an
# enable, so the worst case is a visible, actionable drift report -- never the false green that is the
# whole reason this helper exists.

function Get-UserClaudeHome {
    <# The home directory that '~/.claude' hangs off, for the two things in this lib that live there:
       the user settings layer (Get-SettingsChainPaths) and the plugin administration
       (Get-InstallRecord).

       $env:USERPROFILE first -- the convention the rest of these scripts use for the plugin cache, and
       the variable the connector test already redirects to point a child process at a throwaway home --
       falling back to $HOME so the plugin's non-Windows consumers resolve something sensible rather than
       a path rooted in the empty string. Returns '' when neither is set, which every caller must read as
       "cannot look" rather than "looked and found nothing". #>
    param([string]$UserHomeOverride = '')
    if ($UserHomeOverride) { return $UserHomeOverride }
    if ($env:USERPROFILE)  { return $env:USERPROFILE }
    if ($HOME)             { return $HOME }
    return ''
}

function Get-JsonField {
    <# Read one field off a ConvertFrom-Json object without dying on a shape that does not have it.

       Under Set-StrictMode -Version Latest a plain '$obj.field' on a PSCustomObject that lacks the field
       is a terminating error, and these scripts read files a consumer owns -- a record written by a
       newer (or older) CLI is an ordinary state, not a corrupt file. The per-item filter is the same
       idiom Get-EnabledPlugins documents at length: it touches no member on the (possibly empty)
       property collection itself, which the '-contains' idiom used elsewhere in this repo does. #>
    param($Object, [Parameter(Mandatory = $true)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name })
    if ($p.Count -eq 0)      { return $Default }
    if ($null -eq $p[0].Value) { return $Default }
    return $p[0].Value
}

function Get-SettingsChainPaths {
    <# The settings files that can carry 'enabledPlugins', LOWEST precedence FIRST -- so a caller that
       walks this list in order and lets each layer overwrite the previous one ends up with Claude
       Code's precedence (local > project > user) for free.

       RepoOwned marks the layers that live INSIDE $RepoRoot, and it sits here rather than at a call
       site because this function is the only place that knows which those are. A caller asking "did
       THIS repo enable it, or did it arrive from the machine?" would otherwise match the labels by
       hand -- and a label is PROSE, printed in the messages, so it could be reworded without anything
       noticing that a predicate elsewhere had quietly stopped matching (issue #1138).

       -UserHomeOverride is for fixtures. See Get-UserClaudeHome for how the user home resolves. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$UserHomeOverride = ''
    )
    $userHome = Get-UserClaudeHome -UserHomeOverride $UserHomeOverride

    $chain = @()
    if ($userHome) {
        $chain += [pscustomobject]@{
            Label     = 'user ~/.claude/settings.json'
            Path      = (Join-Path $userHome '.claude\settings.json')
            RepoOwned = $false
        }
    }
    $chain += [pscustomobject]@{
        Label     = '.claude/settings.json'
        Path      = (Join-Path $RepoRoot '.claude\settings.json')
        RepoOwned = $true
    }
    $chain += [pscustomobject]@{
        Label     = '.claude/settings.local.json'
        Path      = (Join-Path $RepoRoot '.claude\settings.local.json')
        RepoOwned = $true
    }
    return $chain
}

function Format-LabelList {
    <# 'a', 'a and b', 'a, b and c' -- the one place this report's prose joins a list of layer labels.

       Extracted (inbound #304) because the phrasing was inline in Get-EnabledPlugins' $summary and a
       SECOND list of layers now needs the identical wording. Two hand-rolled joins producing "almost
       the same sentence" is the shape that made #294 and #304 possible in the first place.

       -IfEmpty is the caller's word for "there is nothing to list", since that sentence differs per
       question: no settings file at all vs. no layer carrying the key. #>
    param(
        [string[]]$Labels = @(),
        [string]$IfEmpty = 'none'
    )
    $l = @($Labels)
    if ($l.Count -eq 0) { return $IfEmpty }
    if ($l.Count -eq 1) { return $l[0] }
    return (($l[0..($l.Count - 2)]) -join ', ') + ' and ' + $l[-1]
}

function Get-EnabledPlugins {
    <# Read the enable state for $RepoRoot from the whole settings chain and report both the answer and
       how it was reached. Never throws on a malformed file: an unreadable layer is reported as such and
       the rest of the chain still counts, because a typo in one file must not silently turn a
       drift check into a green one.

       Returns:
         Ids            -- the enabled plugin ids ('<name>@<marketplace>') after precedence, sorted
                           ORDINALLY (see the sort below -- a culture-dependent order would make this
                           check's output depend on the machine it runs on).
         LayerById      -- hashtable id -> the layer label that DECIDED its value (for messages).
         RepoEnabledIds -- the subset of Ids whose deciding layer is one of $RepoRoot's OWN settings
                           files, i.e. the enables THIS REPO makes rather than ones arriving from the
                           machine. Always a subset of Ids and never larger: a repo layer outranks the
                           user layer in this chain, so an id enabled in both decides in the repo's
                           and is counted here. See "WHY RepoEnabledIds EXISTS" below.
         Layers         -- per layer: Label, Path, Exists, Readable, HasKey, TrueCount.
         AnyFileExists  -- did any layer's file exist at all?
         AnyKeyFound    -- did any existing layer carry an 'enabledPlugins' key? A present-but-empty
                           key is a real answer ("nothing is enabled here"), and deliberately
                           distinguished from "no file and no key anywhere", which is a repo that was
                           never configured.
         Unreadable     -- labels of layers that exist but did not parse.
         Consulted      -- labels of the layers that exist (what a message should claim was checked).
         Summary        -- ready-made 'a, b and c' phrasing of Consulted, or 'no settings file' when
                           the chain is empty, so the three callers word this identically.
         KeyIn          -- labels of the layers that actually CARRY an 'enabledPlugins' key (the
                           HasKey subset of Consulted).
         KeySummary     -- ready-made phrasing of KeyIn, for a message about where the key LIVES.

       WHY KeyIn EXISTS, AND WHY IT IS NOT Summary (inbound #304, measured 2026-07-31 against 3.0.6).
       Summary is the phrasing of Consulted, and Consulted is "the layers that EXIST" -- so it answers
       "what did you look at?", never "where is the key?". check-roster-sync used it for the second
       question and therefore claimed 'enabledPlugins' was "present in" all three layers of a repo that
       carried it in exactly one (life-hub: the user layer, as an empty object; the two repo-owned files
       had no key at all). The two files a reader opens first are the two that demonstrably do not have
       it.
       That inverts the promise #294 was fixed to make -- every verdict names the layer an enable came
       from, "so an enable arriving from outside the repo is diagnosable instead of mysterious" -- in the
       one line where the layer is the whole answer. The data was already here (Layers[].HasKey); what was
       missing was a ready-made phrasing, so the fix is a second Summary rather than a filter re-typed at
       each call site. Same reasoning that put Summary here to begin with.

       WHY RepoEnabledIds EXISTS, AND THE MEASUREMENT IT RESTS ON (issue #1138, measured 2026-08-30
       against Claude Code 2.1.251). check-roster-sync's [RECORD-SHAPE] roll-up counted every enabled id,
       so a plugin enabled MACHINE-WIDE and never installed here reached the headline a reader meets
       first -- for a state that repo did not create and cannot fix from inside itself. The obvious gate
       is to stop counting those, and #1095 had already withdrawn a NEIGHBOURING one: gating on
       scope == 'user' was disproved by #323, which measured that the demotion writes exactly that scope,
       so the gate would have restored the silence #314/#315/#323 exist to end.
       Enable provenance is a different field and the demotion does not touch it, so that objection does
       not transfer -- but it was UNMEASURED, and one fact decided it: does
       'claude plugin install --scope project' ALWAYS write the enable into the repo's own settings?
       Measured in a throwaway CLAUDE_CONFIG_DIR against six shapes, so the live register was never
       touched. Yes in all six, and the sixth is stronger than a yes:
         - a bare repo, no settings file           -> writes .claude/settings.json with the enable
         - already enabled in the USER layer       -> writes it into the repo's file anyway
         - already enabled in settings.local.json  -> writes it into settings.json anyway
         - the id present and explicitly 'false'   -> flips it to true, in that same file
         - a repair re-install after a hand-edit   -> re-writes it, merging beside existing keys
         - settings.json unparseable               -> THE INSTALL FAILS and NO register record is
                                                      written. So the settings write is a PRECONDITION
                                                      of the record, not a side effect of it: there is
                                                      no state in which a project install record exists
                                                      while the repo's own settings never carried the
                                                      enable.
       WHY THIS READS BOTH REPO LAYERS AND NOT settings.json ALONE, which is what the issue proposed.
       The install writes settings.json, but a person may afterwards move an enable into
       settings.local.json -- an ordinary thing to do, since that file is the uncommitted personal layer
       and Claude Code honours it at HIGHER precedence. Gating on settings.json alone would go silent on
       a legitimately project-installed plugin whose enable was merely moved one file sideways, which is
       the exact class of silence this marker exists to end. RepoOwned (Get-SettingsChainPaths) is
       therefore the predicate, not a label match. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$UserHomeOverride = ''
    )

    $decided = @{}          # id -> $true/$false, last layer to speak wins
    $decidedBy = @{}        # id -> layer label
    $decidedRepo = @{}      # id -> did that deciding layer belong to THIS repo? (issue #1138)
    $layers = @()
    $unreadable = @()
    $consulted = @()
    $anyKey = $false

    foreach ($layer in (Get-SettingsChainPaths -RepoRoot $RepoRoot -UserHomeOverride $UserHomeOverride)) {
        $exists = Test-Path -LiteralPath $layer.Path -PathType Leaf
        $readable = $false
        $hasKey = $false
        $trueCount = 0

        if ($exists) {
            $consulted += $layer.Label
            try {
                $parsed = Get-Content -LiteralPath $layer.Path -Raw -Encoding UTF8 | ConvertFrom-Json
                $readable = $true
                # Deliberately NOT '$parsed.PSObject.Properties.Name -contains ...', the idiom used
                # everywhere else in this repo. Under Set-StrictMode -Version Latest that member
                # enumeration THROWS on an object with no properties at all ("The property 'Name' cannot
                # be found on this object") -- and a settings.json holding exactly '{ }' is an ordinary
                # consumer state, not a corrupt file. Measured 2026-07-31 against a throwaway consumer:
                # the old inline reader hit this too, where $ErrorActionPreference = 'Stop' turned it into
                # a dead check reported as "could not complete"; routing it through this function's catch
                # merely relabelled it as "does not parse", which is worse -- a confident false statement
                # about the file instead of an obvious failure. Filtering the properties per item touches
                # no member on the (possibly empty) collection itself.
                $epProp = @($parsed.PSObject.Properties | Where-Object { $_.Name -eq 'enabledPlugins' })
                if ($epProp.Count -gt 0) {
                    $hasKey = $true
                    $anyKey = $true
                    # '"enabledPlugins": null' is a present key that enables nothing -- same reasoning:
                    # report it as an answer, do not throw reaching into it.
                    $epValue = $epProp[0].Value
                    if ($null -ne $epValue) {
                        foreach ($prop in @($epValue.PSObject.Properties)) {
                            $decided[$prop.Name] = ($prop.Value -eq $true)
                            $decidedBy[$prop.Name] = $layer.Label
                            $decidedRepo[$prop.Name] = $layer.RepoOwned
                            if ($prop.Value -eq $true) { $trueCount++ }
                        }
                    }
                }
            } catch {
                $unreadable += $layer.Label
            }
        }

        $layers += [pscustomobject]@{
            Label     = $layer.Label
            Path      = $layer.Path
            Exists    = $exists
            Readable  = $readable
            HasKey    = $hasKey
            TrueCount = $trueCount
        }
    }

    # ORDINAL sort, not Sort-Object's culture-aware default. Measured while writing the test for this
    # helper: under the invariant/en-US collation Sort-Object put 'specialists@...' before
    # 'specialists-lifehub@...' because punctuation carries a lower weight, while an ordinal comparison
    # orders '-' (0x2D) before '@' (0x40). Either order is defensible; a check whose output order depends
    # on the machine's culture is not, since this list drives both the report order and the order the
    # bootstrap walks its plugins in.
    #
    # THE PAIR THAT MEASUREMENT WAS TAKEN ON NO LONGER DEMONSTRATES IT. Those two plugins were renamed to
    # 'dkj-subagents-alpha' and 'dkj-subagents-lifehub' on August 9, 2026, and for that pair the two collations agree --
    # so anyone re-checking the claim against today's plugin names will find no difference and conclude
    # this sort is pointless. It is not: the divergence needs a name that is a prefix of another with
    # punctuation between, which the next plugin added here may well be. The property is asserted on a
    # synthetic pair in check-report-lib.tests.ps1 rather than left to whatever the real names happen to
    # be, precisely so it stops depending on that.
    $ids = [string[]]@($decided.Keys | Where-Object { $decided[$_] })
    if ($ids.Count -gt 1) { [array]::Sort($ids, [System.StringComparer]::Ordinal) }

    $keyIn = @($layers | Where-Object { $_.HasKey } | ForEach-Object { $_.Label })

    return [pscustomobject]@{
        Ids            = $ids
        RepoEnabledIds = [string[]]@($ids | Where-Object { $decidedRepo[$_] })
        LayerById      = $decidedBy
        Layers         = $layers
        AnyFileExists  = @($layers | Where-Object { $_.Exists }).Count -gt 0
        AnyKeyFound    = $anyKey
        Unreadable     = $unreadable
        Consulted      = $consulted
        Summary        = (Format-LabelList -Labels $consulted -IfEmpty 'no settings file')
        KeyIn          = $keyIn
        KeySummary     = (Format-LabelList -Labels $keyIn -IfEmpty 'no settings layer')
    }
}

# --- Is the plugin actually INSTALLED for this path? (inbound #302) -------------------------------
# Claude Code needs TWO things before a session loads a plugin: an ENABLE in the settings chain, and an
# INSTALL RECORD for this project path in ~/.claude/plugins/installed_plugins.json. #294 taught these
# checks to read the first one properly. Nothing read the second -- so a mirror image of #294 lived in
# the same scripts, pointing the other way.
#
# THE DEFECT, measured 2026-07-31 against 3.0.6 in a throwaway consumer with three plugins enabled and
# no install record for its path. What the session saw: zero specialists skills, zero subagents, zero
# hook output. What check-roster-sync said about that same directory: "27 specialisten", one [ERROR]
# each. What the bootstrap did there: 27 lens files on disk, for specialists that exist in no session of
# that repo. Where #294's blindness produced a reassuring lie in one check and a spurious error in
# another, this one produces a confident, fully detailed report about a plugin surface that is not there.
#
# The state is not exotic, and since 3.0.6 it is not even self-inflicted: it arises from a forgotten
# install, an uninstall that left the enable behind, a renamed or moved repo directory (the record is
# keyed on projectPath) -- and from a session start in ANOTHER directory taking this repo's record over,
# reproduced twice and filed as inbound #301. In that last case a correctly adopted repo enters this
# state without its owner doing anything at all: no command run, no file changed, git status clean.
#
# WHY THIS IS A LIB FUNCTION AND NOT A NEW READER. The query already existed, hand-rolled inside
# check-connectors' version check -- which is why inbound #302's grep for 'installed_plugins' over the
# PLUGIN tree came back with prose only: that reader lives in the workshop-owned scripts/sync/, outside
# the tree it searched. The claim was right as scoped; the fix is to lift that one reader out rather than
# add a second, since "one reader per call site, tightened in none of them" is the sentence #294 was
# filed about. check-connectors' record-matching rules (#240: EVERY match, not the first; case- and
# trailing-separator-insensitive, because two spellings of one path are not two answers) are preserved
# here verbatim, and its call site now asks this function instead.
#
# WHY A PATHLESS RECORD COUNTS FOR EVERY REPO. check-connectors skipped records without a 'projectPath'
# and was right to -- it is comparing versions for one specific checkout. A "is it installed HERE?"
# question cannot skip them: a record that is not scoped to a path does not exclude this path. They are
# therefore kept separately rather than dropped, so a caller states which kind of evidence it found. Note
# honestly what is measured and what is not: every record observed on this machine is scope 'project' or
# 'local' and carries a projectPath, so the pathless shape is INFERRED from the field's absence being
# meaningful, not from a user-scope install that was watched being written. Erring this way is deliberate
# -- it can only suppress a warning, never invent one, and a false [NOT-INSTALLED-HERE] against a working
# repo is precisely the cry-wolf failure #294 spent a release removing.

function Get-InstallRecord {
    <# The install administration's answer to "is <plugin> installed for $RepoRoot?", read from
       ~/.claude/plugins/installed_plugins.json.

       Returns:
         Path          -- the administration file consulted ('' when no user home could be resolved).
         Exists        -- did that file exist?
         Readable      -- did it parse? A file that does not parse is reported, never thrown: a check
                          must be able to say "I could not read the authority" instead of dying.
         Error         -- the parse error message, or ''.
         AnyRecord     -- does the file hold ANY record, for any path? Distinguishes "no installs
                          administered on this machine at all" from "installs, but none for this repo".
         RecordsById   -- hashtable id -> ALL records whose projectPath IS this repo (#240: never just
                          the first one -- several disagreeing records is its own answer).
         Ids           -- ordinally sorted ids that have at least one record for this repo.
         PathlessById  -- hashtable id -> records carrying no projectPath (see the block above).
         PathlessIds   -- ordinally sorted ids of those.
         AllRecords    -- EVERY record in the file, whatever path it names and whether or not that path
                          still resolves. The three fields above are all FILTERED -- to this repo, or to
                          the pathless -- so none of them can answer a question about the file ITSELF,
                          which is what check-claude-home.ps1 asks (issue #1609): does the real
                          administration hold records a FIXTURE wrote? Such a record names a scratch
                          tree, so it is neither this repo's nor pathless, and it is dropped twice over
                          -- once for the path mismatch, and again because a deleted fixture root no
                          longer resolves. A field rather than a second reader, for the reason the
                          block above this function gives: one reader, tightened here.

       Records are projected onto a fixed shape (Id/Scope/Version/GitCommitSha/InstallPath/ProjectPath/
       InstalledAt/LastUpdated) so callers never reach into raw JSON -- the field a caller reads is then
       a decision made once, here, rather than at each call site. GitCommitSha is the commit the CLI
       recorded at install/update time; plugin-versions.ps1 compares it against the marketplace clone's
       HEAD, which is finer than the cut-granular .version.

       -UserHomeOverride is for fixtures, same as Get-EnabledPlugins'. Note that the two checks
       deliberately do NOT pass their own -UserHomeOverride through to this function: that parameter is
       documented as pinning the USER LAYER OF THE SETTINGS CHAIN, and the administration is a different
       file answering a different question. A fixture that wants to control the administration redirects
       $env:USERPROFILE for the child process, which is what the connector version test already does. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$UserHomeOverride = ''
    )

    $userHome = Get-UserClaudeHome -UserHomeOverride $UserHomeOverride
    $path = if ($userHome) { Join-Path $userHome '.claude\plugins\installed_plugins.json' } else { '' }
    $exists = [bool]($path -and (Test-Path -LiteralPath $path -PathType Leaf))

    $readable = $false
    $err = ''
    $anyRecord = $false
    $forPath = @{}
    $pathless = @{}
    $allRecords = @()

    # Normalize the repo root once, the same way the record side is normalized below. Best-effort
    # Resolve-Path: the root normally exists (it is the repo being inspected), but a fixture may name one
    # that does not, and a check must not die on that -- fall back to the literal string.
    $rootResolved = Resolve-Path -LiteralPath $RepoRoot -ErrorAction SilentlyContinue
    $rootKey = if ($rootResolved) { $rootResolved.Path.TrimEnd('\', '/') } else { ([string]$RepoRoot).TrimEnd('\', '/') }

    if ($exists) {
        try {
            $admin = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            $readable = $true
            $pluginsMap = Get-JsonField $admin 'plugins' $null
            if ($null -ne $pluginsMap) {
                foreach ($entry in @($pluginsMap.PSObject.Properties)) {
                    $id = $entry.Name
                    foreach ($rec in @($entry.Value)) {
                        if ($null -eq $rec) { continue }
                        $anyRecord = $true
                        $projected = [pscustomobject]@{
                            Id           = $id
                            Scope        = (Get-JsonField $rec 'scope')
                            Version      = (Get-JsonField $rec 'version')
                            GitCommitSha = (Get-JsonField $rec 'gitCommitSha')
                            InstallPath  = (Get-JsonField $rec 'installPath')
                            ProjectPath  = (Get-JsonField $rec 'projectPath')
                            InstalledAt  = (Get-JsonField $rec 'installedAt')
                            LastUpdated  = (Get-JsonField $rec 'lastUpdated')
                        }
                        # COLLECTED BEFORE EITHER FILTER BELOW, and that order is the whole point: both
                        # of them drop a record on purpose, and this field's job is to see what they drop.
                        $allRecords += $projected
                        if (-not $projected.ProjectPath) {
                            if (-not $pathless.ContainsKey($id)) { $pathless[$id] = @() }
                            $pathless[$id] += $projected
                            continue
                        }
                        # A record can name a projectPath that no longer exists on this machine (a
                        # deleted throwaway directory is the case that produced inbound #301);
                        # Resolve-Path then returns $null and must never be read via .Path under
                        # StrictMode. Such a record cannot be about THIS repo, so skipping it is both
                        # safe and correct -- carried over verbatim from check-connectors.
                        $recResolved = Resolve-Path -LiteralPath $projected.ProjectPath -ErrorAction SilentlyContinue
                        if (-not $recResolved) { continue }
                        if ($recResolved.Path.TrimEnd('\', '/') -ieq $rootKey) {
                            if (-not $forPath.ContainsKey($id)) { $forPath[$id] = @() }
                            $forPath[$id] += $projected
                        }
                    }
                }
            }
        } catch {
            $err = $_.Exception.Message
        }
    }

    # ORDINAL sort, for the same reason Get-EnabledPlugins sorts that way: a check whose output order
    # depends on the machine's culture is not a check you can diff between machines.
    $ids = [string[]]@($forPath.Keys)
    if ($ids.Count -gt 1) { [array]::Sort($ids, [System.StringComparer]::Ordinal) }
    $plIds = [string[]]@($pathless.Keys)
    if ($plIds.Count -gt 1) { [array]::Sort($plIds, [System.StringComparer]::Ordinal) }

    return [pscustomobject]@{
        Path         = $path
        Exists       = $exists
        Readable     = $readable
        Error        = $err
        AnyRecord    = $anyRecord
        RecordsById  = $forPath
        Ids          = $ids
        PathlessById = $pathless
        PathlessIds  = $plIds
        AllRecords   = @($allRecords)
    }
}

function Test-PluginInstalledHere {
    <# Does $PluginId have install evidence covering this repo? One predicate, so the three call sites
       cannot each decide differently what "installed here" means -- the exact drift that produced #294.

       Returns $true for a record scoped to this repo's path OR a record scoped to no path at all (see
       the block above for why the second counts). Deliberately also $true when the administration could
       not be read at all: an unreadable or absent authority is not evidence of absence, and a check that
       treats "I could not look" as "it is not installed" would fire its loudest new signal exactly where
       it knows least. The caller reports the unreadable file separately. #>
    param(
        [Parameter(Mandatory = $true)]$InstallRecord,
        [Parameter(Mandatory = $true)][string]$PluginId
    )
    if ($null -eq $InstallRecord) { return $true }
    if (-not $InstallRecord.Exists -or -not $InstallRecord.Readable) { return $true }
    if ($InstallRecord.RecordsById.ContainsKey($PluginId)) { return $true }
    if ($InstallRecord.PathlessById.ContainsKey($PluginId)) { return $true }
    return $false
}

# WHY THERE IS A SECOND PREDICATE ABOUT THE SAME RECORDS, and why it is not folded into the one above.
# Test-PluginInstalledHere answers "is there evidence covering this repo?" -- a yes/no that must stay
# permissive, because a false [NOT-INSTALLED-HERE] against a working repo is the cry-wolf failure #294
# spent a release removing. The question below is different in kind: GIVEN that evidence exists, is it the
# shape this family's documents assume everywhere -- exactly ONE record, scoped 'project'? Merging the two
# would force one predicate to be permissive and strict at once.
#
# Rounds v8 and v9 measured THREE ways that shape breaks, and none was reported by anything
# (inbound #314/#315/#323):
#   - NO 'project' RECORD. A SESSION START writes install records for enabled plugins: it creates a
#     missing one and flips an existing 'project' record to 'local'. No command runs, no file in the repo
#     changes, and nothing announces it. The state a consumer is left in is 'local', which no document in
#     this family assumes anywhere.
#   - MORE THAN ONE RECORD. The repair install prescribed for a missing record can ADD a record beside the
#     existing one instead of correcting it, reporting success both times. specialists-init step 0c
#     already teaches the reader that two lines is the signal -- but only a human eyeballing that query
#     ever saw it, which is exactly the "a rule nobody has a mechanism for" shape. Note the trigger is
#     narrower than first written: measured on 3.0.9, a SAME-scope install replaces cleanly, and it is a
#     SCOPE MISMATCH that accumulates (inbound #325).
#   - A 'project' RECORD DEMOTED TO A PATHLESS ONE. A session start can rewrite an existing, correct
#     'project' record into a 'user'-scope record with the 'projectPath' REMOVED -- measured in v9, one
#     write, timestamp preserved. The repo then has no record for its own path for the plugin that is
#     demonstrably loading, and it DISAPPEARS from the verification query the documents prescribe. This
#     is the shape that used to fall between the two predicates: permissive Test-PluginInstalledHere says
#     "installed" on the pathless record, while Get-RecordShape saw nothing to judge because it reads
#     only records scoped to this path. Reported here since #323.
#
# A SECOND, INDEPENDENT REASON [NOT-INSTALLED-HERE] NEVER FIRES AT A SESSION START (inbound #327). The
# reasoning below is about the record being written away before a hook can look. Round v10 measured the other
# half: the session that writes the record LOADS NOTHING -- no skills, no subagents, no hook output at all,
# because the record is written after the load phase and the hooks ship in the plugin that session did not
# load. So even if the state survived, there would be nothing running to report it. Both halves have to be
# true for the marker to be reachable from a session, and neither is. That is why this marker is documented
# as reachable only by a DELIBERATE run, and why the workshop's own check-connectors -- which speaks about a
# consumer from outside -- remains the only thing that can report the total case.
#
# "THE STATE HEALS ITSELF" WAS WRONG, AND IT IS WORTH KEEPING WHY. This block used to argue that
# [NOT-INSTALLED-HERE] is practically unreachable because the missing-record state heals itself. Round v9
# falsified that by the only test that settles it: after the first session start rewrote the
# administration, a SECOND fresh session wrote nothing at all -- installed_plugins.json kept its mtime to
# the tick, and the hook's verdict was identical. So the honest statement is the opposite of self-healing:
# the FIRST session start rewrites the administration and later ones do not, which makes the post-write
# state stable, persistent and observable. That is what makes these shapes worth a marker at all -- a
# state that really healed itself would need no reporting.
#
# All three are real, actionable, and about the repo the session is in, and in all three the repo still
# WORKS -- the plugin loads from a 'local' or user-scope record just as well. So this is a non-counting
# marker, not an [ERROR]: a red line plus exit 1 would be a lie. Classification question asked first, per
# the connectors README rule: no shape can indicate tampering -- all are written by the CLI itself.
function Get-RecordShape {
    <# Given an install record set and a plugin id, is the administration for this repo the shape the
       documents assume (exactly one 'project'-scoped record)?

       Returns $null when it is, and when there is nothing to judge at all -- no record for this path AND
       no pathless one, which is [NOT-INSTALLED-HERE]'s subject rather than this one's. Keeping the two
       questions apart is what stops the markers reporting one state twice.

       Otherwise returns Id / Count / Scopes (ordinally sorted, deduplicated) / HasProject / Shapes, where
       Shapes holds 'no-project-scope', 'duplicate' and/or 'pathless-only'.

       WHY 'pathless-only' IS JUDGED HERE (inbound #323). A pathless record used to end the function early:
       Get-RecordShape read only RecordsById, so with the projectPath gone there was nothing to judge, and
       the case was assigned to step 0b's scopeless-install warning instead. Measurement moved it. A
       pathless record is not only something a user TYPES -- a session start manufactures one out of a
       correct 'project' record, dropping the projectPath, with no command run. In that reading "0b's
       documented warning" is the wrong owner, because nobody ran an install. And the state is exactly what
       this predicate is for: the administration for this repo is not the assumed shape. It is the most
       consequential of the three shapes, because it is the one that makes the repo's own record vanish
       from the query the documents tell a reader to trust, while Test-PluginInstalledHere stays
       (correctly) permissive and says nothing. Count is 0 for this shape -- there are no records for this
       path, which is the finding -- and Scopes carries the pathless records' own scopes so the report can
       name what it found instead. #>
    param(
        [Parameter(Mandatory = $true)]$InstallRecord,
        [Parameter(Mandatory = $true)][string]$PluginId
    )
    if ($null -eq $InstallRecord) { return $null }
    if (-not $InstallRecord.Exists -or -not $InstallRecord.Readable) { return $null }

    $hasForPath = [bool]($InstallRecord.RecordsById.ContainsKey($PluginId) -and @($InstallRecord.RecordsById[$PluginId]).Count -gt 0)
    $hasPathless = [bool]($InstallRecord.PathlessById.ContainsKey($PluginId) -and @($InstallRecord.PathlessById[$PluginId]).Count -gt 0)

    if (-not $hasForPath) {
        # No record for this path. Only a finding when a PATHLESS one exists; with neither, the plugin has
        # no evidence here at all and that belongs to [NOT-INSTALLED-HERE].
        #
        # THIS CONJUNCTION IS NOT "THE DEMOTION", and saying so here is what put a false cause into the
        # reader's line (inbound #1095). It is the demotion AND the resting state of every correctly
        # user-installed plugin in a repo that never project-installed it -- two states the register cannot
        # separate, because #323 measured that the demotion writes scope='user' and drops projectPath,
        # producing byte-for-byte the shape of an ordinary machine-wide install. The shape name is therefore
        # exactly what it says -- 'pathless-only', an observation -- and the report that consumes it asks
        # the reader which of the two it is instead of picking one.
        if (-not $hasPathless) { return $null }

        $plRecs = @($InstallRecord.PathlessById[$PluginId])
        $plScopes = [string[]]@($plRecs | ForEach-Object { [string]$_.Scope } | Where-Object { $_ } | Sort-Object -Unique)
        if ($plScopes.Count -gt 1) { [array]::Sort($plScopes, [System.StringComparer]::Ordinal) }
        return [pscustomobject]@{
            Id         = $PluginId
            Count      = 0
            Scopes     = $plScopes
            HasProject = $false
            Shapes     = [string[]]@('pathless-only')
        }
    }

    $recs = @($InstallRecord.RecordsById[$PluginId])

    # A record whose 'scope' field is absent or empty is NOT read as a mismatch: this predicate reports
    # what the administration positively says, and an unstated scope is a gap in the file rather than a
    # statement that the scope is wrong. Same direction of error as Test-PluginInstalledHere -- it can
    # suppress a marker but never invent one.
    $scopes = [string[]]@($recs | ForEach-Object { [string]$_.Scope } | Where-Object { $_ } | Sort-Object -Unique)
    if ($scopes.Count -gt 1) { [array]::Sort($scopes, [System.StringComparer]::Ordinal) }
    $hasProject = [bool](@($scopes | Where-Object { $_ -ieq 'project' }).Count -gt 0)

    $shapes = @()
    if ($scopes.Count -gt 0 -and -not $hasProject) { $shapes += 'no-project-scope' }
    if ($recs.Count -gt 1) { $shapes += 'duplicate' }
    if ($shapes.Count -eq 0) { return $null }

    return [pscustomobject]@{
        Id         = $PluginId
        Count      = $recs.Count
        Scopes     = $scopes
        HasProject = $hasProject
        Shapes     = [string[]]$shapes
    }
}

function Get-SubagentDirName {
    <# The leaf name of the directory a plugin keeps its subagent definitions in -- 'subagents' where the
       plugin ships one, 'agents' where it ships the pre-rename shape, and '' where it ships neither.

       BOTH ARE READ AND ONE IS WRITTEN, which is this tree's standing rule for a renamed shape and is
       load-bearing here rather than a courtesy. This family's own plugins moved agents/ to subagents/ on
       September 9, 2026 (#1698), but the readers built on this function run against a CONSUMER'S PLUGIN
       CACHE, which holds whatever version that machine last installed -- including a pre-rename one, and
       including somebody else's plugin that never renamed anything. A reader that knew only the new leaf
       would report those as shipping no subagents at all, which is the one answer that is false in both
       directions: Resolve-PluginDir would skip the plugin, and the roster check would then read no roster
       while saying it had.

       The order is new-first so a cache dir carrying both -- which nothing writes, but a hand-copied
       directory can produce -- resolves to the one the manifest's "agents": "./subagents/" key points at.

       THE LEAF HAS ONE OWNER, for the same reason Get-CachedPluginDirs gives for the path shape: a second
       spelling of it in a caller can disagree with the one the resolver used, and the two answers are only
       ever compared by a person reading a finding. #>
    param([Parameter(Mandatory = $true)][string]$PluginDir)
    foreach ($leaf in @('subagents', 'agents')) {
        if (Test-Path -LiteralPath (Join-Path $PluginDir $leaf) -PathType Container) { return $leaf }
    }
    return ''
}

function Get-SubagentDirPath {
    <# The full path of that directory, or '' when the plugin ships neither shape. The convenience half of
       Get-SubagentDirName, so a caller that only wants to enumerate the files does not re-join the leaf. #>
    param([Parameter(Mandatory = $true)][string]$PluginDir)
    $leaf = Get-SubagentDirName -PluginDir $PluginDir
    if (-not $leaf) { return '' }
    return (Join-Path $PluginDir $leaf)
}

function Resolve-PluginDir {
    <# Resolve the versioned plugin dir for Name+Marketplace under CacheRoot, in three steps:

         1. $env:CLAUDE_PLUGIN_ROOT (hook context), honored only when it points at THIS plugin (its
            parent dir leaf equals Name), so a multi-plugin setup stays correct.
         2. THE INSTALL RECORD for -RepoRoot, when one is given. This is the authority on what a
            session in that repo actually loads, and it is consulted BEFORE the version scan below.
         3. The semantically highest version under <CacheRoot>/<Marketplace>/<Name>/ that has an
            agents/ dir (bootstrap lesson: a string-sort puts 1.9.0 above 1.10.0 -- [version] fixes
            that). This remains the answer when no -RepoRoot is passed, when the repo has no record,
            or when the recorded installPath is gone from disk.

       WHY STEP 2 EXISTS (August 4, 2026). Step 3 alone answers "the newest version present on this
       machine", which is a different question from "the version this repo loads" as soon as the cache
       holds more than one. Measured here: the cache held 3.1.2, 3.2.0 and 3.3.0, all three with an
       agents/ dir, while this repo's record pinned 3.2.0 -- so the roster check reported on 3.3.0's
       agent set. Nothing was visibly wrong, because both versions happened to ship the same 15 agents;
       the moment two versions differ in roster content, a check reading the wrong one reports "all
       present" about a specialist the session does not have. A cache holding several versions is the
       normal state for a machine with more than one consumer, not an edge case.

       The record is matched on <Name>@<Marketplace>, which is the id the administration keys on, and
       its installPath is used directly rather than being rebuilt from the version -- the record names
       the directory, so reconstructing it would be a second way of saying the same thing that can
       disagree with the first. A recorded path that no longer exists, or that has no agents/ dir, falls
       through to step 3 rather than returning $null: a stale record must not be able to blind a check
       that would otherwise have found something.

       There is deliberately NO -UserHomeOverride here. Get-InstallRecord documents that flag as pinning
       the USER LAYER OF THE SETTINGS CHAIN, and states that its callers do not forward theirs to it
       because the administration is a different file answering a different question. A fixture that
       wants to control the administration redirects $env:USERPROFILE for the child process, which is
       what the connector version test already does; adding a passthrough here would offer a second,
       contradicting way to do it. #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Marketplace,
        [Parameter(Mandatory = $true)][string]$CacheRoot,
        [string]$RepoRoot = ''
    )

    if ($env:CLAUDE_PLUGIN_ROOT) {
        $cpr = $env:CLAUDE_PLUGIN_ROOT
        if ((Test-Path -LiteralPath $cpr -PathType Container) -and
            ((Split-Path (Split-Path $cpr -Parent) -Leaf) -eq $Name)) {
            return (Resolve-Path -LiteralPath $cpr).Path
        }
    }

    if ($RepoRoot) {
        # Best-effort: this is a refinement of step 3, never a gate in front of it. An unreadable or
        # absent administration leaves $records empty and the version scan below answers as it always
        # did -- Get-InstallRecord reports rather than throws, which is what makes that safe.
        $record = Get-InstallRecord -RepoRoot $RepoRoot
        $recId = "$Name@$Marketplace"
        if ($record.RecordsById.ContainsKey($recId)) {
            foreach ($rec in @($record.RecordsById[$recId])) {
                if (-not $rec.InstallPath) { continue }
                if (-not (Test-Path -LiteralPath $rec.InstallPath -PathType Container)) { continue }
                if (-not (Get-SubagentDirName -PluginDir $rec.InstallPath)) { continue }
                return (Resolve-Path -LiteralPath $rec.InstallPath).Path
            }
        }
    }

    foreach ($v in (Get-CachedPluginDirs -Name $Name -Marketplace $Marketplace -CacheRoot $CacheRoot)) {
        if (Get-SubagentDirName -PluginDir $v) {
            return (Resolve-Path -LiteralPath $v).Path
        }
    }
    return $null
}

function Get-CachedPluginDirs {
    <# Every version dir present on disk for Name+Marketplace under CacheRoot, newest first, WITHOUT
       asking whether any of them ships an agents/ dir. Returns @() when the plugin has no cached dir
       at all.

       IT EXISTS TO SEPARATE TWO ANSWERS Resolve-PluginDir CANNOT (August 6, 2026). That function
       requires agents/ at every return path -- correctly, because a roster check has nothing to read
       without one -- so it answers $null both for "this plugin is not on this machine" and for "it is
       right here and ships no agents". Those are different facts about the machine, and a caller that
       reports the first when the second is true states something false: measured on
       figma@claude-plugins-official, sitting in the cache at 2.2.90 with its installPath present in the
       administration, reported by check-roster-sync as "enabled but not found in the cache". Everything
       about the BEHAVIOUR was right -- a plugin of skills and MCP servers is nothing for a roster check
       to check -- and only the stated reason was wrong, which is the failure shape this repo keeps
       paying for: a message a reader cannot act on because it describes a different problem.

       THE PATH SHAPE HAS ONE OWNER, which is why this is here rather than in the caller.
       <CacheRoot>/<Marketplace>/<Name>/<version> is Resolve-PluginDir's own layout knowledge, and a
       second construction of it in the script that asks the question could disagree with the one that
       answers it. Resolve-PluginDir's version scan now reads from this function, so the enumeration
       and the discriminator cannot drift apart.

       The [version] sort is load-bearing and predates this extraction: a string sort puts 1.9.0 above
       1.10.0 (bootstrap lesson). #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Marketplace,
        [Parameter(Mandatory = $true)][string]$CacheRoot
    )
    $nameDir = Join-Path (Join-Path $CacheRoot $Marketplace) $Name
    if (-not (Test-Path -LiteralPath $nameDir -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $nameDir -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object { $_.FullName })
}

function Get-DisplayName {
    <# Sanitize + capitalize a raw agent name (from an agent-def's `name:` frontmatter) into a display
       name. Defense-in-depth: the name may be written into a scaffold file or a proposed roster row,
       so restrict it to a safe charset before use. Returns $Fallback when nothing usable remains.
       Single source (issue #145) for skills/sync-roster/sync-roster.ps1 (roster-row proposals +
       header-drift comparison) and scripts/sync/check-roster-sync.ps1 (header-drift detection). #>
    param([string]$RawName, [string]$Fallback = '')
    $n = $RawName -replace '[^A-Za-z0-9_-]', ''
    if (-not $n) { return $Fallback }
    return ($n.Substring(0, 1).ToUpper() + $n.Substring(1))
}

function Get-LensFamily {
    <# The family segment of a consumer's repo-lens path:
       .claude/plugins/<family>/<plugin>/<group>-<id>-extension.md.

       A CONSTANT, deliberately not derived from the install path (issue #179). specialists-init used
       to derive it, and in the plugin-cache layout (~/.claude/plugins/cache/<marketplace>/<plugin>/
       <version>/) that derivation yields the MARKETPLACE name instead of the plugin family. A repo
       installed through 'specialists@dkj-claude-plugins' therefore got its lenses written to
       .claude/plugins/dkj-claude-plugins/<plugin>/, while every reader looked only under
       'claude-specialists' -- so existing lenses were reported as missing, and following that advice
       would have produced a second copy of every lens on a second path. The family is a property of
       the plugin family, not of the marketplace it happens to be fetched from, so it is fixed here:
       one value, used by the writers (bootstrap.ps1, sync-roster.ps1) and the reader
       (check-roster-sync.ps1) alike. #>
    return 'claude-specialists'
}

function Get-RosterIdTokenPattern {
    <# The regex pattern that recognizes a '<group>-<id>' specialist token (e.g. '06-24') bounded so
       it does not spuriously match inside surrounding digits/dates. Single source (inbound #182) for
       BOTH call sites in check-roster-sync.ps1 -- Test-InRoster (a specific id's presence) and the
       orphan-scan's Matches() over the whole roster text (every token) -- so the two can no longer
       drift out of sync, which is exactly how this bug arose: the same lookaround duplicated in two
       places and tightened in neither.

       Leading boundary '(?<![\d-])': excludes a preceding digit OR hyphen. The old pattern
       ('(?<!\d)') only excluded a digit, so an ISO date matched -- in '2026-07-25' the '07' is
       preceded by '-', which passed, so '07-25' was read as a specialist token. Excluding a
       preceding hyphen too kills that case; verified '2026-07-25' and '2026-05-15' now yield no
       match, while '06-24' and '05-15' inside a real reference like 'See 05-15-extension.md' still
       match (nothing precedes them there but the start-of-string/whitespace).

       Trailing boundary '(?!\d)' (unchanged, deliberately NOT tightened to '(?![\d-])'): a real
       lens reference is immediately followed by '-extension.md', i.e. a hyphen -- tightening the
       trailing side to also exclude a hyphen would stop '05-15-extension.md' from matching at all,
       breaking the exact legitimate case this token exists to recognize. Verified.

       KNOWN LIMITATION (documented in inbound #182, not silently swallowed): this narrows the
       ISO-date case in practice but does not cover every prose false positive -- e.g. a plain
       two-digit number range in prose ('see pages 12-34', 'a range of 10-20 items') still matches
       (verified). That only becomes a visible orphan line if no real specialist happens to share
       that id, and stays [INFO], never [ERROR]. Accepted as-is; option 2 from the issue (binding the token to
       a roster row/table shape) was deliberately not taken, since Test-InRoster is asked about a
       specific id in free prose and binding it to a table shape would change behavior for consumers
       who format their roster differently -- a bigger risk than the residual noise this leaves.

       WHERE THAT LIMITATION STOPPED BEING COSMETIC (issue #227, July 29, 2026): the bootstrap writes
       '@.claude/plugins/<family>/<plugin>/01-01-extension.md' into CLAUDE.md, and that path contains
       the token, so the import LINE satisfied Test-InRoster and Chris counted as rostered with no
       roster row in the file at all -- measured as 18 ids missing after a bootstrap instead of 19. The
       decision above is unchanged: the fix is NOT in this pattern. check-roster-sync.ps1 strips
       '^\s*@' lines from the roster text before reading it, which is safe precisely because an
       '@'-import is never a roster row under ANY formatting convention -- the property the rejected
       table-shape rule could not claim. If a future case needs more than that, weigh it against this
       carve-out rather than reopening option 2 from scratch: the useful question is whether the
       offending text has a writer that is knowably not the roster author. #>
    param(
        # Omit to get the generic 'any <group>-<id> token' pattern (the orphan-scan's use, matching
        # every token in the roster text). Pass a specific id (e.g. '05-15') to get a pattern that
        # matches only that literal token (Test-InRoster's use) -- same boundary, single source.
        [string]$Id = ''
    )
    $body = if ($Id) { [regex]::Escape($Id) } else { '\d{2}-\d{2}' }
    return "(?<![\d-])$body(?!\d)"
}

function Get-SeamPaths {
    <# THE SEAM (issue #221): the single place a consumer's whole specialist surface lives, so a
       teardown is "remove one directory and one line" instead of hand-editing a roster woven through
       CLAUDE.md. One source for the literal strings, because the bootstrap WRITES them and the
       teardown MATCHES them -- the pair that must never drift apart.

         .claude/specialists/SPECIALISTS.md   the inclusion: body import, lens import, roster slot
         .claude/specialists/lenses/          every <group>-<id>-extension.md, flat (ids are unique
                                              family-wide, so no per-plugin subdirectory is needed)

       ImportLine is what goes into CLAUDE.md, forward-slashed: an '@'-import path is not a filesystem
       path, and it must read identically on every platform. Verified against the memory reference:
       imports nest to a maximum of four hops, and the seam spends two (CLAUDE.md -> SPECIALISTS.md ->
       body/lens), so a lens may still import something of its own.

       RelInclusion is the same file as Inclusion, repo-root-relative and forward-slashed -- the form a
       repo-config's Get-RosterPath takes. It lives here because the bootstrap has to WRITE that value
       into a consumer's scaffold while check-roster-sync READS it back, which is the writer/recogniser
       pair this function exists for. It was a hand-typed literal in the scaffold, and it was typed
       wrong: 'CLAUDE.md', while the bootstrap puts the roster slot in SPECIALISTS.md (inbound #333). #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $dir = Join-Path $RepoRoot '.claude\specialists'
    return [pscustomobject]@{
        Dir          = $dir
        LensDir      = Join-Path $dir 'lenses'
        Inclusion    = Join-Path $dir 'SPECIALISTS.md'
        ImportLine   = '@.claude/specialists/SPECIALISTS.md'
        RelDir       = '.claude/specialists'
        RelInclusion = '.claude/specialists/SPECIALISTS.md'
    }
}

function Get-OrchestratorNote {
    <# The explanatory note the bootstrap writes above the orchestrator import(s), as ONE source for the
       writer and both removers (inbound #271).

       WHY THIS MOVED HERE. The note is a single sentence wrapped over TWO lines: a fixed head and a tail
       that names where the imports point. Both cleanup paths -- the teardown, and the bootstrap's own
       [tidy] guard -- matched the HEAD only, by re-typing that literal. So every teardown left the tail
       behind and the next bootstrap wrote a fresh two-line note above the orphan. Measured over two
       cycles in DaveKJohn/life-hub on 2026-07-30: 1 orphan tail after the first teardown, 2 after the
       second, and CLAUDE.md +4 lines from a round trip that should have returned to zero.

       THE INVISIBILITY WAS THE WORSE HALF. Every counter in the documented verification -- and the
       regression test written for the earlier accumulation bug -- keys on the head, so it read 0 after a
       teardown and 1 after a bootstrap: exactly the healthy values, at every step, while the file grew.
       Same failure class as the 1 -> 2 -> 3 accumulation fixed after smartwatchbanden, moved one line
       down into the only line nothing checked. The lesson already written above that fix --
       "idempotence has to cover everything the script WRITES, not just the line it happens to look
       for" -- was true of the note itself, and this is the second time it had to be learned.

       So the shape of the fix is the same as Get-SeamPaths': the pair that must never drift apart gets
       one definition. A literal mirrored by hand in two scripts is what created this bug.

       Head is an exact literal. Tail is a REGEX, because the tail interpolates a path that differs per
       consumer and per layout (the seam names the seam dir; the pre-seam form names the plugin path).
       It stays anchored on the distinctive generated clauses, so the existing rule holds unchanged: a
       consumer who reworded or translated the note has AUTHORED that text, and neither remover touches
       it. #>
    [pscustomobject]@{
        Head        = 'The orchestrator (Chris) is always loaded -- portable body from plugin install and repo lens'
        # Either generated tail, and nothing else. Deliberately not '^from ' alone: that would match a
        # sentence an owner happened to start with the same word.
        TailPattern = "^from\s.*(that file carries the body import, the lens import and this repo's roster\.|routes on-demand to specialists in\s)"
    }
}

function Test-IsOrchestratorNoteLine {
    <# Is this line part of the note block the bootstrap writes? Head or either tail. Trimmed, so an
       indentation change in a consumer's editor does not hide it from the remover. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
    $note = Get-OrchestratorNote
    $t = $Line.Trim()
    if ($t -eq $note.Head) { return $true }
    return [bool]($t -match $note.TailPattern)
}

function Get-ClaudeMdScaffold {
    <# The CLAUDE.md scaffold the bootstrap writes when the consumer has NO CLAUDE.md at all -- the heading
       plus the two prose lines above the orchestrator import block. One source for the writer
       (bootstrap.ps1) and the reporter (teardown.ps1), for the same reason Get-OrchestratorNote is one:
       a literal mirrored by hand in two scripts produced BOTH instances of the accumulation bug documented
       above, and this is the third literal that crosses the same boundary.

       WHY THE TEARDOWN NEEDS TO RECOGNISE IT (inbound #331, test round v10). On a consumer that had no
       CLAUDE.md before adoption, every byte of that file was written by specialists-init -- so after a full
       teardown these two lines are the only thing left in it, and they were reported as NEITHER [remove]
       nor [KEEP]. Three things were true at once: they stayed, they were unreported, and the free-standing
       audit said [FREE]. The audit's own claim was narrowly true (the lines name no specialist, persona,
       roster or lens, so nothing loads because of them), which is exactly what made the silence worse: the
       document tells a reader that '[remove] versus [KEEP] is what tells you which case you were in', and
       here it was neither.

       Matched on the LITERAL generated wording only, like the note above: a consumer who reworded or
       translated these lines has authored that text, and the teardown reports nothing about it. #>
    [pscustomobject]@{
        Heading = '# CLAUDE.md'
        Prose   = @(
            'This repo is governed by **Claude Specialists** -- a team of specialized Claudes led by a Chief of Staff.',
            'This scaffold was created by `specialists-init` skill; expand with governance and safety rules for this repo.'
        )
    }
}

function Test-IsClaudeMdScaffoldProseLine {
    <# Is this line one of the scaffold's generated prose lines? Trimmed, so an indentation change in a
       consumer's editor does not hide it from the reporter. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
    $t = $Line.Trim()
    foreach ($p in (Get-ClaudeMdScaffold).Prose) { if ($t -eq $p) { return $true } }
    return $false
}

function Get-LensDirCandidates {
    <# The ordered directories a repo lens for $PluginName may live in, most canonical first:
         0. .claude/specialists/lenses/                  -- THE SEAM (#221); where writers write for a
                                                            FRESH consumer. Plugin-independent on
                                                            purpose: one directory holds the lenses of
                                                            every enabled plugin, since <group>-<id> is
                                                            unique family-wide.
         1. .claude/plugins/<Get-LensFamily>/<plugin>/   -- the pre-seam standard; still written for a
                                                            consumer that already has a lens tree there,
                                                            because the bootstrap never relocates a file
                                                            the repo owner owns.
         2. .claude/plugins/<other-family>/<plugin>/     -- what a pre-#179 bootstrap left behind
                                                            (the marketplace name as family). Read
                                                            but never written, so a consumer that was
                                                            bootstrapped before the fix keeps working
                                                            without a migration.
         3. .claude/extensions/                          -- the legacy pre-plugin-path location.
       Readers should walk this list; writers should ask Get-LensWriteDir, which picks between the seam
       and an existing tree. $PluginName is assumed slug-validated by the caller (Test-PluginNameSlug)
       before it becomes a path segment. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginName
    )
    $family = Get-LensFamily
    $pluginsRoot = Join-Path $RepoRoot '.claude\plugins'
    $dirs = @((Get-SeamPaths -RepoRoot $RepoRoot).LensDir)
    $dirs += (Join-Path (Join-Path $pluginsRoot $family) $PluginName)
    if (Test-Path -LiteralPath $pluginsRoot -PathType Container) {
        foreach ($fam in (Get-ChildItem -LiteralPath $pluginsRoot -Directory | Sort-Object Name)) {
            if ($fam.Name -eq $family) { continue }
            $d = Join-Path $fam.FullName $PluginName
            if (Test-Path -LiteralPath $d -PathType Container) { $dirs += $d }
        }
    }
    $dirs += (Join-Path $RepoRoot '.claude\extensions')
    return $dirs
}

function Get-LensWriteDir {
    <# Where a writer (the bootstrap) should PUT a lens. The seam for a fresh consumer; the existing
       tree for one that already has lenses somewhere.

       WHY NOT ALWAYS THE SEAM: the bootstrap is strictly additive and never relocates a file the repo
       owner owns. Writing seam lenses next to a legacy tree would split the surface in two, which is
       worse than either layout alone -- the teardown would then have to reason about both at once, and
       a reader would find half a roster in each. Migrating is the owner's act, documented in the family
       README, and once they have moved the files this function follows them automatically because the
       legacy tree is gone.

       Returns the seam lens dir when no *-extension.md exists in ANY candidate directory, else the
       first candidate directory that actually holds one. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginName
    )
    foreach ($dir in (Get-LensDirCandidates -RepoRoot $RepoRoot -PluginName $PluginName)) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        $found = @(Get-ChildItem -LiteralPath $dir -Filter '*-extension.md' -File -ErrorAction SilentlyContinue)
        if ($found.Count -gt 0) { return $dir }
    }
    return (Get-SeamPaths -RepoRoot $RepoRoot).LensDir
}

function Get-SettingsArtifactNames {
    <# The two settings artifacts specialists-init writes into a consumer's .claude/, repo-relative.
       One source for the writer (bootstrap.ps1) and the remover (teardown.ps1), for exactly the reason
       Get-ClaudeMdScaffold and Get-OrchestratorNote are one: a literal mirrored by hand across those two
       scripts is what produced both instances of the accumulation bug, and an artifact the bootstrap
       writes under a name the teardown does not know is an orphan nobody is told about -- in a directory
       many consumers gitignore, where git cannot mention it either.

       Suggested -- the ANNOTATED proposal (.jsonc). It explains WHY each rule is there and is the file a
       reader consults; it is not, and cannot be, pasted whole, because comments are illegal in the
       destination and because it holds only the two permission halves.

       Proposed -- the MERGED end result (strict .json), added for inbound #1124. It is the consumer's own
       .claude/settings.json key for key with those halves folded in, so the reader's whole act is
       'replace one file with the other' instead of a hand-merge they have to invent. That merge was the
       unwarned trap: the destination is not empty -- it carries enabledPlugins and
       extraKnownMarketplaces, which is what was holding the adoption up -- and a whole-file paste of the
       .jsonc silently deletes both, landing the reader in #1076's zero-surface state through a file that
       parses perfectly. #>
    [pscustomobject]@{
        Suggested = '.claude\settings.suggested.jsonc'
        Proposed  = '.claude\settings.proposed.json'
    }
}
