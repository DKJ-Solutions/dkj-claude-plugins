<#
.SYNOPSIS
    PreToolUse hook: deterministically blocks a write action against the LIVE Shopify theme.

.DESCRIPTION
    Reads the hook JSON from stdin, takes the command out of tool_input.command, and blocks (exit 2)
    when that command is:

      1. a theme PUBLISH -- always. Publishing makes a theme the live customer-facing theme, and no
         marker in a command line can stand in for a human deciding to do that.
      2. a theme DELETE -- always, unless this repo has answered Get-ShopifyThemeDeleteMarker AND the
         command carries that marker. Default (seam unanswered) is the original rule, absolute: what is
         deleted cannot be un-deleted, and whether a preview theme is really spent is a judgement rather
         than a cleanup step. A delete aimed at the LIVE theme id is refused even with the marker.
      3. a theme PUSH aimed at LIVE -- unless explicitly authorised. Aimed at live means the command
         carries '--allow-live' or this repo's own live theme id.

    WHY hooks.json WRAPS THIS FILE IN A SHELL COMMAND (issue #2217). Everything above is what this script
    decides once it RUNS. When PowerShell cannot start at all -- out of memory, a failed type
    initializer -- no line of this file executes, and the harness reads every exit code other than 2 as a
    NON-blocking error, so the command goes through: the guard fails OPEN in exactly the condition where
    a machine is least healthy. No hooks.json field declares a hook fail-closed, and the exit code of a
    start failure is arbitrary (127, 45, 66 and 1 were measured), so the only place it is visible is the
    bash layer above the interpreter. The hooks.json command runs this file, passes 0 and 2 through, and
    on any other exit code refuses ONLY a payload that names a Shopify theme; any other call passes the
    failure through as before. hook-fail-closed.tests.ps1 holds both halves. It assumes the hook shell is
    bash, which is the documented default wherever Git Bash is installed.

    WHY THIS SHIPS WITH THE TEAM RATHER THAN BEING BUILT PER REPO (inbound #769). Two Shopify
    consumers of this plugin independently built this same guard, and the second had to learn the
    false-positive lesson below from scratch while the first still carries it. The plugin stated the
    rule in prose in three manuals; prose does not stop a command.

    WHAT THIS CLOSES THAT PERMISSIONS CANNOT. A permission rule matches a command PREFIX, so a deny
    entry for the CLI never sees the same command wrapped in a shell invocation -- and a settings file
    that allows both the CLI and a 'powershell -Command "..."' wrapper leaves the exact forbidden
    command reachable by wrapping it. This hook reads the whole command string, and its matcher covers
    both the Bash and the PowerShell tool for that reason.

    ------------------------------------------------------------------------------------------------
    MENTIONING A RULE IS NOT PERFORMING IT, AND THAT LESSON COST THE REPORTING CONSUMER TWO BLOCKED
    COMMANDS ON ITS FIRST DAY. Their first version matched the forbidden words anywhere in the command
    string, and it blocked, in order: the heredoc that wrote the rule into their CLAUDE.md, and the
    perl one-liner that later edited that sentence. Neither would have touched the store. A guard that
    makes its own rule impossible to write down is a guard somebody eventually switches off, which is
    worse than no guard, so the matching asks WHERE the words sit rather than whether they occur:

      - HEREDOC BODIES are stripped. 'cat > file <<EOF ... EOF' writes data and the body never runs.
        UNLESS an interpreter is consuming it ('bash <<EOF'), in which case the body IS a script and
        nothing is stripped.
      - HERE-STRING BODIES are stripped for the same reason, in the same way. A PowerShell '@'' ... ''@'
        body is assigned or piped somewhere and nothing in it runs. UNLESS the command also shows an
        execution vector (Invoke-Expression, iex, [scriptblock]::Create, or the eval/xargs/pipe-into-a-
        shell forms below), in which case nothing is stripped.
      - TEXT TOOLS are skipped. A segment whose leading command is grep, sed, perl, awk, cat, echo,
        git, Out-File, Set-Content, Get-Content, Select-String and friends is handling text rather than
        running the CLI. UNLESS the command pipes into an interpreter or uses eval/xargs/iex --
        'echo "..." | bash' really does execute, and that override is the whole reason the exemption is
        safe to have.
      - EVERYTHING ELSE is matched per shell segment, so a real command after a heredoc, after a
        semicolon, or inside a wrapper is still caught.

    Every one of those exemptions has a counter-case in the suite, because an exemption without one is
    a hole with a comment on it.

    THE TWO POWERSHELL HALVES ABOVE ARRIVED LATE, AND THE ASYMMETRY WAS NOT A DECISION (inbound #1032).
    The matcher covered both shells from the first day -- that breadth is what closes the wrapper
    vector -- while both exemptions knew only the POSIX spellings. So a consumer writing this very rule
    into its own scripts was permitted through Bash and refused through PowerShell, which made the
    answer depend on which shell its platform uses. That is not a security boundary. Of the two, the
    here-string stripping is the one that matters: the segment split is on NEWLINES, so an unstripped
    body turns each of its lines into a segment, and the cmdlet that would have earned the exemption
    sits a segment away from the line that matches.

    AND THE REFUSAL TEXT IS PART OF THE GUARD, not commentary on it. See $AUTHORING_NOTE below for the
    sentence every refusal now carries and the reason it had to be written: the delete refusal used to
    tell a reader who was AUTHORING to add the delete marker to 'this exact command', which on a
    file-writing command works -- and teaches the habit the marker exists to prevent.

    THE RESIDUAL LIMIT, STATED RATHER THAN HIDDEN. A text tool asked to execute -- 'perl -e' with a
    system() call, say -- is exempted by the rule above and is not caught. That is a deliberate trade:
    the vector needs somebody to go out of their way, while the false positives it would otherwise
    cause happen in ordinary work every time a repo documents its own safety rules.

    AND THE MACHINERY ABOVE NO LONGER LIVES IN THIS FILE (issue #1734). Every exemption described in
    this block is now command-guard-lib.ps1's, dot-sourced from beside this hook and mirrored into this
    plugin as its own registry entry. It was extracted FROM here by #1669 so a second guard could reuse
    it, and for one release this file went on carrying its own copy of what it had taught -- two copies
    of one behaviour, free to drift, with the copy that drifts being whichever nobody looks at. The
    rules and their counter-cases are unchanged; where they are written down moved. The exempt set
    itself stays HERE, because the two guards disagree about 'git' and the lib therefore has no default.
    ------------------------------------------------------------------------------------------------

    WHAT IT NEEDS FROM THE REPO, AND WHAT IT DOES WITHOUT IT. Two optional functions in the consuming
    repo's scripts/repo-config.ps1:

      Get-ShopifyLiveThemeId     the live theme's numeric id. Absent, the id half of rule 3 cannot
                                 fire -- '--allow-live' still blocks, and a push aimed at live BY ID
                                 passes. That is a real hole, so it is not left silent: the
                                 SessionStart check beside this file reports it once per session.
      Get-ShopifyLivePushMarker  the exact authorisation marker. Absent, any marker ending in
                                 'LIVE-PUSH-AUTHORIZED' is accepted, which is what both existing
                                 consumers already write ('SWB-...' and 'XOXO-...'). Recognise both,
                                 write one.
      Get-ShopifyThemeDeleteMarker  the marker that authorises a THEME DELETE. Absent -- the default --
                                 rule 2 is absolute and no marker exists that could pass it, which is
                                 how this hook behaved before the seam and therefore what an unstated
                                 seam has to keep meaning. Answered, a delete carrying that exact marker
                                 is allowed, EXCEPT one aimed at the live theme id, which is refused
                                 unconditionally. Answering it with the same string as the push marker
                                 also leaves the capability off: see the note beside $DELETE_MARKER.

    AUTHORISING THE DELIBERATE LIVE PUSH. Add the marker as a shell comment to that exact push
    command: '... --allow-live # LIVE-PUSH-AUTHORIZED'. It is a comment in both shells, so it changes
    nothing about what runs, and the hook sees it in the command string.

    WHY A MARKER AND NOT AN ENVIRONMENT VARIABLE. The hook runs as its own process and does not
    inherit an inline env prefix, so a variable would either not arrive or would have to be set
    session-wide -- which is exactly the state that makes a stray push dangerous. A marker authorises
    ONE command, visibly, in the transcript, where a reviewer can see it.

    UNTOUCHED (exit 0): every form of 'theme pull' including --live, since reading is how a pre-task
    sync works; pushes to an unpublished preview theme; and every other command.

    SCOPE. This covers the CLI vector reached through the Bash and PowerShell tools. A publish issued
    through a Shopify MCP connector is a different vector and is NOT covered here -- that one is held
    by the MCP server's own permission prompt.

    Exit codes (PreToolUse contract): 2 = block and send stderr to Claude; 0 = allow.

    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script as ANSI.
    Tested by scripts/tests/guard-live-theme.tests.ps1 in the source repo -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# --- What the repo answers, if it answers ---------------------------------------------------------
# Dot-sourced in a CHILD scope with StrictMode explicitly OFF: a consumer's repo-config.ps1 is written
# on the assumption that its runtime callers do not set it. Both values have a safe fallback, so a repo
# with no config file at all still gets rules 1 and 2 and the --allow-live half of rule 3.
$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$config = & {
    Set-StrictMode -Off
    $answers = @{ LiveThemeId = ''; Marker = ''; DeleteMarker = '' }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $answers }
    try { . $configPath } catch { return $answers }
    if (Get-Command Get-ShopifyLiveThemeId       -ErrorAction SilentlyContinue) { $answers.LiveThemeId  = [string](Get-ShopifyLiveThemeId) }
    if (Get-Command Get-ShopifyLivePushMarker    -ErrorAction SilentlyContinue) { $answers.Marker       = [string](Get-ShopifyLivePushMarker) }
    if (Get-Command Get-ShopifyThemeDeleteMarker -ErrorAction SilentlyContinue) { $answers.DeleteMarker = [string](Get-ShopifyThemeDeleteMarker) }
    return $answers
} $repoRoot

$LIVE_ID = ([string]$config.LiveThemeId).Trim()
# A NON-NUMERIC ANSWER COUNTS AS NO ANSWER, and this is the counter-case to the seam block that
# adopt-shopify-floor now writes into a consumer's repo-config.ps1. A Shopify theme id is numeric, so
# anything else is a placeholder somebody left behind -- and accepting one would be worse than an absent
# function: the SessionStart check reads a non-empty answer as ANSWERED, so a 'VUL-IN' left in place
# would silence the report while the id half of rule 3 stayed inert. A hole with a comment on it, which
# is the exact failure this guard's own README warns about. Rejecting it here keeps the two in agreement:
# unanswered to the guard is unanswered to the check.
if ($LIVE_ID -and $LIVE_ID -notmatch '^\d+$') { $LIVE_ID = '' }
# THE DEFAULT MARKER IS A SUFFIX RATHER THAN A FULL STRING, which is what makes this work in both
# existing consumers without either of them configuring anything: they write
# 'SWB-LIVE-PUSH-AUTHORIZED' and 'XOXO-LIVE-PUSH-AUTHORIZED', and both end in the default. A repo that
# wants only its own spelling accepted sets the seam.
$MARKER = if (([string]$config.Marker).Trim()) { ([string]$config.Marker).Trim() } else { 'LIVE-PUSH-AUTHORIZED' }

# THE DELETE MARKER HAS NO DEFAULT, AND THAT ASYMMETRY WITH $MARKER ABOVE IS THE WHOLE DESIGN.
# A push marker needs a fallback because both existing consumers already write one and rule 3 has to keep
# working unconfigured. Nobody writes a delete marker, because until now no marker could authorise a
# delete at all -- so a default here would hand every consumer a capability they never asked for, on the
# next plugin update, silently. An unstated seam has to mean UNCHANGED, and unchanged for a delete is
# 'always denied'. So: empty answer -> the capability is off -> rule 2 stays exactly as it was.
#
# WHICH MAKES THIS OPT-IN PER REPO, deliberately. A repo that wants a session to be able to clear away
# its own spent preview themes says so, in its own words, once. Everyone else keeps the old rule and
# never reads this comment.
$DELETE_MARKER = ([string]$config.DeleteMarker).Trim()

# ONE MARKER MAY NOT DO TWO JOBS. If a repo answers both seams with the same string, the delete
# capability is refused rather than granted: the push marker is written on live-push commands as a matter
# of routine (it is in that repo's own step-by-step), so accepting it here would mean every documented
# live push doubles as a standing authorisation to delete. That is the opposite of a marker authorising
# ONE command visibly. Failing safe costs a repo one word of config; failing open costs it a theme.
if ($DELETE_MARKER -and $DELETE_MARKER.ToLower() -eq $MARKER.ToLower()) { $DELETE_MARKER = '' }

# Commands that read or write text rather than run the store CLI. A segment led by one of these is
# handling the words, not obeying them.
#
# THE SECOND ROW IS THE POWERSHELL HALF OF THE FIRST, AND IT WAS MISSING UNTIL INBOUND #1032. The
# matcher covers both the Bash and the PowerShell tool -- that breadth is what closes the wrapper
# vector -- while the exemption knew only the POSIX spellings. So whether a consumer was allowed to
# write this rule into its own scripts depended on which shell its platform uses, which is not a
# security boundary. 'Out-File' is the redirection, 'Get-Content' is cat, 'Select-String' is grep, and
# each is exempt for the reason its twin above is: a segment led by it cannot invoke the store CLI.
$TEXT_TOOLS = @(
    'grep', 'egrep', 'fgrep', 'rg', 'sed', 'perl', 'awk', 'cat', 'echo', 'printf', 'head', 'tail',
    'less', 'more', 'jq', 'git', 'findstr', 'tee', 'diff', 'wc', 'sort', 'uniq', 'tr', 'cut',
    'out-file', 'set-content', 'add-content', 'get-content', 'select-string', 'tee-object',
    'write-output', 'write-host', 'out-string'
)

# --- The false-positive machinery, dot-sourced rather than carried --------------------------------
# WHY THIS IS A DOT-SOURCE AND NOT A COPY (issue #1734). Everything that used to sit here -- the
# heredoc and here-string stripping, the leading-command reader, the segment split and the
# execution-vector override -- was extracted into command-guard-lib.ps1 by #1669, so the working-copy
# guard could reuse it instead of learning the same false-positive lesson at the same price. This file
# is where that lesson was learned, and until #1734 it was also the one caller still carrying its own
# copy: two copies of one behaviour, free to drift, with the copy that drifts being whichever nobody
# looks at.
#
# THE LIB IS MIRRORED INTO THIS PLUGIN rather than reached for in another one. dkj-policy and
# dkj-subagents-shopify are separately versioned and separately installed, and a Shopify consumer may
# run this team without the workflow plugin -- so the registry carries a SECOND mirror of one source,
# 'command-guard-lib-shopify' in Get-SharedScriptPairs, on native-capture-lib-shopify's precedent.
#
# $PSScriptRoot-relative, so it resolves the same in the source tree, in the plugin mirror and in a
# consumer's plugin cache -- the same rule guard-working-copy.ps1 states for its own lib.
$libPath = Join-Path $PSScriptRoot '..\scripts\lib\command-guard-lib.ps1'
$libLoaded = $false
if (Test-Path -LiteralPath $libPath -PathType Leaf) {
    try { . $libPath; $libLoaded = $true } catch { }
}

$raw = [Console]::In.ReadToEnd()

# A MISSING OR UNLOADABLE LIB DEGRADES TOWARDS CHECKING, NOT TOWARDS ALLOWING -- and this is where
# this hook parts company with guard-working-copy.ps1, which exits 0 in the same situation and says
# so. The asymmetry is the subject, not a disagreement about style: that guard protects a working copy
# a person can restore from origin, this one protects a live customer-facing theme, and a publish
# cannot be un-published. So the whole payload becomes the single segment to match -- the pre-#769
# behaviour, which costs the exemptions and therefore blocks some authoring -- and it says on stderr
# that it is doing so. It is the same direction the unparseable-payload fallback takes, for the reason
# that fallback already gives: fail towards CHECKING.
if (-not $libLoaded) {
    [Console]::Error.WriteLine('guard-live-theme: command-guard-lib.ps1 not found beside this hook -- running DEGRADED, matching the whole payload without the heredoc, here-string and text-tool exemptions. Reinstall or update the dkj-subagents-shopify plugin.')
    $cmd = [string]$raw
    $scan = $cmd
    $segments = @($cmd)
} else {
    # AN UNPARSEABLE PAYLOAD FALLS BACK TO THE RAW TEXT rather than to an empty string, so a hook
    # contract that changes shape fails towards CHECKING instead of towards allowing. Asserted in the
    # suite; the fallback itself now lives in Get-HookCommandPayload rather than here.
    $cmd = [string](Get-HookCommandPayload $raw).Command

    # $scan IS THE COMMAND WITH THE DATA STRIPPED OUT OF IT, and the two marker tests below read it
    # rather than the raw string: a marker sitting inside a heredoc body is text somebody wrote down,
    # not an authorisation. It is rebuilt from the lib's own two primitives rather than re-implemented
    # here -- and rather than widened into Get-GuardSegments's return, whose other caller has no
    # markers and no use for it.
    $scan = Remove-HeredocBodies $cmd
    if (-not (Test-CommandExecutesText $scan)) { $scan = Remove-HereStringBodies $scan }

    # THE EXEMPT SET IS THIS CALLER'S AND STAYS THIS CALLER'S. -TextTools is mandatory in the lib with
    # no default precisely because the two guards disagree about 'git': here a segment led by it is
    # handling text, and in the working-copy guard it is the subject. Do not give the lib a default --
    # command-guard-lib.tests.ps1 asserts the absence of one.
    #
    # AND THE LIB EXPANDS AN INTERPRETER WRAPPER, which this file used to reach only by accident. A
    # 'bash -c "shopify theme publish"' was caught here because the words were matched ANYWHERE in the
    # segment; now the -c body is split and matched as a command in its own right. Every wrapper case
    # in the suite lands the same way it did before -- the vector is simply explicit instead of
    # incidental.
    #
    # IT COSTS EXACTLY ONE NEW REFUSAL, MEASURED RATHER THAN ARGUED, and it is a false positive:
    # 'perl -c "..."' now blocks where it used to pass. 'perl' is both a $TEXT_TOOLS entry above and an
    # interpreter in the lib, and the lib expands a wrapper BEFORE any exemption is considered -- but
    # perl's own -c means SYNTAX CHECK, so nothing in that body runs. It is pinned in the suite rather
    # than exempted: the shape is the lib's, the same shape guard-working-copy.ps1 has, and carving perl
    # out here would put a second opinion about wrappers in the caller, which is what #1734 exists to
    # remove. 'perl -e' -- the residual limit this file's header already states -- is unchanged and
    # still passes.
    $segments = Get-GuardSegments -Command $cmd -TextTools $TEXT_TOOLS
}

$authorised = $scan.ToLower().Contains($MARKER.ToLower())
# Computed on the whole command rather than per segment, exactly like $authorised above: a marker is a
# comment on the command line, and which segment it trails is not something a reader should have to
# reason about. Empty $DELETE_MARKER can never match, which is what keeps the capability off.
$deleteAuthorised = $DELETE_MARKER -and $scan.ToLower().Contains($DELETE_MARKER.ToLower())

# APPENDED TO EVERY REFUSAL, BECAUSE THE REFUSAL TEXT USED TO ADVISE THE ONE THING THAT MUST NOT BE
# DONE (inbound #1032). A consumer editing a script, a test or a doc that CONTAINS one of these
# commands meets this guard -- the guard's own header says so, and so does that consumer's own repo,
# which carries the delete literal in four files. What the refusal told them was to add the delete
# marker to 'this exact command', and on a command that writes a FILE that advice works, because the
# marker is matched over the whole string. So the reader is trained to mark non-deletes as authorised
# deletes, which is precisely the erosion the marker exists to prevent. The header above already
# argues that a guard making its own rule impossible to write down is one somebody switches off; this
# is the sharper version, a guard that made its own rule HAZARDOUS to write down.
#
# It is written once, here, rather than into the four refusals: all four were wrong in the same way,
# and a sentence copied four times is a sentence that will be corrected three times.
$AUTHORING_NOTE = @(
    '  AUTHORING, NOT RUNNING? A marker authorises a COMMAND, never a file write, so do NOT add one to',
    '  get past this -- it would mark a file write as an authorised delete, which is the erosion the',
    '  marker exists to prevent. Writing this text into a script or a doc is already exempt (heredoc and',
    "  here-string bodies, and segments led by a text or file-write command), so reach for the harness's",
    '  Edit/Write tool rather than a shell if one is fighting you.'
) -join "`n"

function Deny([string]$msg) {
    [Console]::Error.WriteLine("BLOCKED (guard-live-theme): $msg")
    [Console]::Error.WriteLine($AUTHORING_NOTE)
    exit 2
}

foreach ($segment in $segments) {
    if (-not $segment.Trim()) { continue }

    $lc = $segment.ToLower()

    if ($lc -match 'shopify\s+theme\s+publish') {
        Deny "a theme publish is never allowed from here. Publishing makes a theme the live customer-facing theme, and that is the store owner's own keystroke rather than something a session decides -- run it yourself if that is what you want."
    }

    if ($lc -match 'shopify\s+theme\s+delete') {
        # THE LIVE THEME IS NEVER DELETABLE, marker or not, and this check comes FIRST so no
        # authorisation path can reach past it. Shopify itself refuses to delete a published theme, so
        # this is belt-and-braces -- and it is worth the two lines precisely because it is the one
        # outcome nothing else in this file could undo.
        if ($LIVE_ID -and $lc.Contains($LIVE_ID.ToLower())) {
            Deny "delete aimed at the LIVE theme ($LIVE_ID) is refused unconditionally -- no marker authorises this one. If the intent was a spent preview theme, check the id against 'shopify theme list'."
        }

        if ($DELETE_MARKER) {
            if ($deleteAuthorised) {
                [Console]::Error.WriteLine("guard-live-theme: theme delete allowed (delete marker present).")
                exit 0
            }
            Deny "a theme delete needs this repo's own authorisation. Confirm the theme is spent -- its work merged and, if it was ever pushed, already live -- then add the marker '# $DELETE_MARKER' to this exact command. The live theme is refused even with it."
        }

        Deny "a theme delete is never allowed from here. What is deleted cannot be un-deleted, and whether a preview theme is really spent is a judgement rather than a cleanup step -- run the command yourself once you have confirmed nothing on it is still needed. (A repo that wants sessions to clear away their own spent preview themes can answer Get-ShopifyThemeDeleteMarker in scripts/repo-config.ps1; unanswered, this rule stays absolute.)"
    }

    $aimedAtLive = ($lc -match '--allow-live') -or ($LIVE_ID -and $lc.Contains($LIVE_ID.ToLower()))
    if ($lc -match 'shopify\s+theme\s+push' -and $aimedAtLive) {
        if ($authorised) {
            [Console]::Error.WriteLine("guard-live-theme: live push allowed (authorisation marker present).")
            exit 0
        }
        $idPart = if ($LIVE_ID) { "$LIVE_ID / --allow-live" } else { '--allow-live' }
        Deny "push to the live theme ($idPart) blocked. If this IS the deliberate live push this repo's own rules describe, add the marker '# $MARKER' to this exact command. Preview pushes and every form of pull are not blocked."
    }
}

exit 0
