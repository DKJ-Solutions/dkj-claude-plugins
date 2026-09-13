<#
.SYNOPSIS
    Adopts dkj-subagents-shopify's operational floor into a consuming Shopify repo: the guard's two seams, a
    starter theme-check config, and the CI workflow that runs it (issues #769, #776).

.DESCRIPTION
    THE PLUGIN SHIPS THE FLOOR; NOTHING SHIPPED THE INSTALL PATH. dkj-subagents-shopify's PreToolUse guard
    arrives with the plugin and starts working on its own -- for two of its three rules. The third, a
    push aimed at the LIVE theme, needs this repo to say which theme that is, and no install step owned
    that answer: an install is a clone into the plugin cache and writes nothing into a repo. So every
    refreshed consumer met a standing [ERROR] at session start and a guard whose id half was inert
    until somebody hand-edited a file belonging to a different plugin (inbound #776). The other two
    items are the ones both existing consumers wrote by hand before the floor shipped at all
    (inbound #769): a theme-check config and the CI workflow over it.

    WHAT IT PLACES, three things, all additive:

      scripts/repo-config.ps1            the Shopify seam block APPENDED (the file must already exist)
      .theme-check.yml                   a starter config, created when absent
      .github/workflows/theme-check.yml  theme-check on every PR into main, created when absent

    THE SEAM BLOCK IS COMMENTED OUT UNLESS -LiveThemeId SAYS OTHERWISE, and that is the one design
    decision in here worth reading. A stub returning 'VUL-IN' is WORSE than an absent function: the
    SessionStart check treats a non-empty answer as answered, so the stub would silence the report and
    leave the hole exactly where it was -- a hole with a comment on it, which is the failure
    dkj-subagents-shopify's own README warns about. adopt-config settled the same question the same way for its
    'decide' records. So the block arrives as a paste-ready comment in the right file with the command
    that produces the id, and the check keeps reporting until a real id is there. Pass -LiveThemeId to
    have it written answered in one move, which is the route the skill takes.

    THE BLOCK ALSO CARRIES THE PRE-TASK SYNC'S SEAMS since inbound #787 (August 20, 2026), and the same
    answered-or-commented rule applies to the store domain. sync-main is the higher-risk half of the same
    problem the guard covers: a live theme has no locking, so work starts by mirroring live into the
    trunk, and the obvious wholesale implementation overwrites whatever the trunk has done since. Its
    other five seams are listed in the block with their defaults rather than written out, because those
    defaults are right for both existing consumers -- what they buy is that nobody has to read the script
    to find out what is configurable.

    THE STARTER CONFIG IS MEASURED RATHER THAN DESIGNED. Both existing Shopify consumers wrote a
    theme-check config independently, before this command existed, and both arrived at the SAME two
    checks over 'extends: nothing' -- Liquid that does not parse and JSON that does not parse. Neither
    turned the recommended set on, and both recorded why in their own file: the full set reports 1504
    offenses across 171 files on one of those themes (1078 at error severity), and roughly 58k on the
    other. A gate that is red on arrival is not a gate; it gets bypassed on day one. So the starter is
    green on arrival in a real theme (Dave, August 20, 2026, choosing that over assuming a clean one),
    and every check a repo cleans up is a line it adds here itself.

    STRICTLY ADDITIVE, NEVER OVERWRITES. A file that exists is left exactly as it is, whatever it
    contains, and a repo-config.ps1 that already defines Get-ShopifyLiveThemeId gets no block appended.
    The same rule specialists-init, adopt-config and adopt-workflow-folder follow, and what makes a
    re-run find nothing to do.

    NOT A BOOTSTRAP. If scripts/repo-config.ps1 is missing altogether this reports it and places the
    other two files anyway: creating the seam lib is the specialists-init job, this command owns its
    contents.

    CONVERGING OFF A HAND-WRITTEN GUARD IS NOT THIS COMMAND'S JOB, deliberately (inbound #777). A repo
    that built its own guard before the plugin shipped one now runs two, and removing a PreToolUse entry
    from somebody's .claude/settings.json is a deletion -- so this prints the pointer, the session check
    reports the duplicate, and the removal stays a person's keystroke.

.PARAMETER Apply
    Write the files. Without it the command is a DRY RUN that prints exactly what it would do and
    touches nothing -- the same default adopt-config and adopt-workflow-folder use, and for the same
    reason: the first run of a command that adds files to your repo should show you the list.

.PARAMETER LiveThemeId
    The live theme's numeric id. Given, the seam function is written ANSWERED and the session check goes
    quiet because the guard is actually armed. Omitted, the block is written commented out and the check
    keeps reporting -- see the header for why a stub would be worse than nothing.
    Find it with: shopify theme list --store <your-store>.myshopify.com

.PARAMETER StoreDomain
    The store the pre-task sync pulls from, e.g. 'your-store.myshopify.com'. Given, Get-ShopifyStoreDomain
    is written ANSWERED and sync-main works on its first run. Omitted, it is written commented out like
    the theme id, and sync-main refuses rather than guessing which store to read -- its own -Store
    parameter gets you through one run.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite. A consumer never types this: the root is resolved
    dual-context like every other shared script.

.EXAMPLE
    .\scripts\task\adopt-shopify-floor.ps1
    .\scripts\task\adopt-shopify-floor.ps1 -LiveThemeId 190793613653 -Apply
    .\scripts\task\adopt-shopify-floor.ps1 -LiveThemeId 190793613653 -StoreDomain my-store.myshopify.com -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$LiveThemeId = '',
    [string]$StoreDomain = '',
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source root copy falls back to the git root. Same resolution as every other mirrored script, which is
# what lets both copies stay byte-identical.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'adopt-shopify-floor.ps1' -OverrideName '-RootOverride'

# A repo that publishes plugins is the floor's SOURCE, not a Shopify store: it has no theme, so a
# .theme-check.yml and a theme-check workflow there would be lint over nothing. Same one-file test
# adopt-workflow-folder uses for the same distinction, and it is what keeps this refusal out of every
# genuine consumer's way.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is the floor''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme here to lint and no live theme to guard. Nothing was written.'
    exit 1
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# --- The seam block -------------------------------------------------------------------------------
# Two functions, and only one of them is ever worth answering on day one. Get-ShopifyLivePushMarker has
# a documented permissive default -- any marker ENDING IN 'LIVE-PUSH-AUTHORIZED' is accepted, which is
# what both existing consumers already write -- so it is offered commented out whatever happens, while
# the id is the one that decides whether rule 3 can fire at all.
function Get-SeamBlock([string]$Id, [string]$StoreDomain) {
    $answered = [bool](([string]$Id).Trim())
    $storeAnswered = [bool](([string]$StoreDomain).Trim())
    $lines = @(
        '',
        '# --- dkj-subagents-shopify: the live-theme guard''s two seams ----------------------------------------------',
        '#',
        '# Placed by adopt-shopify-floor. The guard is a PreToolUse hook in the dkj-subagents-shopify plugin: it',
        '# refuses a theme publish and a theme delete unconditionally, and refuses a push aimed at the LIVE',
        '# theme unless the command carries the authorisation marker. That third rule has two triggers, and',
        '# only ''--allow-live'' is self-declaring -- the id half can fire only where this repo names the id.',
        '#'
    )
    if ($answered) {
        $lines += @(
            '# Answered at adoption time, so the guard is armed on all three rules and the session check is',
            '# silent. Change it the day the live theme changes; the guard reads this on every command, so',
            '# nothing needs restarting.',
            ('function Get-ShopifyLiveThemeId { return ''' + (([string]$Id).Trim()) + ''' }   # the live theme''s numeric id')
        )
    }
    else {
        $lines += @(
            '# LEFT UNANSWERED, AND WRITTEN AS A COMMENT ON PURPOSE. A stub returning ''VUL-IN'' would be worse',
            '# than no function at all: the SessionStart check reads a non-empty answer as answered, so the',
            '# stub would silence the report while the id half of rule 3 stayed inert -- a hole with a comment',
            '# on it. Uncomment this line with the real id and the check goes quiet because the guard is',
            '# actually armed. (The guard and the check also reject a non-numeric answer, so leaving the',
            '# placeholder in place still counts as unanswered rather than as protection.)',
            '#',
            '# Find it:  shopify theme list --store <your-store>.myshopify.com     -- the one marked [live]',
            '#',
            '# function Get-ShopifyLiveThemeId { return ''VUL-IN'' }   # the live theme''s numeric id'
        )
    }
    $lines += @(
        '',
        '# THE MARKER NEEDS NO ANSWER unless you want to narrow it. Left out, any marker ending in',
        '# ''LIVE-PUSH-AUTHORIZED'' is accepted, which is what both existing Shopify consumers already write',
        '# (''SWB-...'', ''XOXO-...''). Setting it narrows to your spelling alone.',
        '#',
        '# function Get-ShopifyLivePushMarker { return ''VUL-IN-LIVE-PUSH-AUTHORIZED'' }',
        '',
        '# --- dkj-subagents-shopify: the pre-task sync ------------------------------------------------------------',
        '#',
        '# For sync-main, which mirrors the live theme into the trunk without letting live overwrite what',
        '# the trunk has done since. Only the STORE is worth answering on day one; the other three have',
        '# defaults that are right for both existing Shopify consumers, and they are listed so nobody has to',
        '# read the script to find out what is configurable.'
    )
    if ($storeAnswered) {
        $lines += @(
            ('function Get-ShopifyStoreDomain { return ''' + (([string]$StoreDomain).Trim()) + ''' }   # the store the sync pulls from')
        )
    }
    else {
        $lines += @(
            '#',
            '# UNANSWERED, and sync-main refuses rather than guessing which store to pull from -- the same',
            '# reasoning as the theme id above. Its -Store parameter gets you through one run.',
            '#',
            '# function Get-ShopifyStoreDomain { return ''VUL-IN.myshopify.com'' }'
        )
    }
    $lines += @(
        '',
        '# The remaining five, with their defaults, all optional:',
        '#',
        '#   Get-ShopifySyncReferencePattern   default ''^[Ss]ync''    the pattern that recognises a previous',
        '#                                                            sync commit. It is matched against the',
        '#                                                            commit SUBJECT, so it is a .NET regex and',
        '#                                                            not git''s ''--grep'', which the lookup no',
        '#                                                            longer uses. The capital is not defensive:',
        '#                                                            the two consumers spell it ''sync:'' and',
        '#                                                            ''Sync '', and a pattern that matches one',
        '#                                                            aborts on the FIRST run in the other.',
        '#                                                            Narrow it if your history says so -- but',
        '#                                                            never widen it: the floor is the MOST',
        '#                                                            RECENT match, so a looser pattern can only',
        '#                                                            move it forward and protect less.',
        '#   Get-ShopifySyncBranchPrefix       default ''sync/live-''   the drift branch''s prefix. Yours to set',
        '#                                                            because it has to line up with whatever',
        '#                                                            your PR guardrails and CI exempt.',
        '#   Get-ShopifySyncMerges             default $false        $true opens the PR and merges once CI is',
        '#                                                            green. The default stops at the push, so',
        '#                                                            somebody LOOKS at what third parties',
        '#                                                            changed before it becomes the base of new',
        '#                                                            branches -- which is the point of the step.',
        '#   Get-ShopifySyncPrBody             default (none)        the PR body, composed from -Take, -Keep',
        '#                                                            (the classified rows: Status/Path/Reason)',
        '#                                                            and -Default (the body the script already',
        '#                                                            composed). Answer it only where the PR body',
        '#                                                            IS your review policy: a template, a',
        '#                                                            checkbox, a fixed wording. Unanswered, the',
        '#                                                            default already names both halves and every',
        '#                                                            path with its kind -- changed, new or gone',
        '#                                                            on live -- which is what a reader needs.',
        '#   Get-ShopifySyncLogPath            default (none)        where this repo keeps a DURABLE record of',
        '#                                                            what third parties did on live, repo-root-',
        '#                                                            relative. Answered, every sync prepends an',
        '#                                                            entry there and it rides in the branch''s own',
        '#                                                            commit, so a sync cannot land record-less.',
        '#                                                            Unanswered, nothing is written: keeping a log',
        '#                                                            is your repo''s policy rather than a Shopify',
        '#                                                            fact. The PR body says the same things once,',
        '#                                                            on GitHub, where nothing in the tree indexes',
        '#                                                            it -- which is what this answers (#1382).',
        '#   Get-ShopifySyncPrLabels           default (none)        the label(s) the sync PR carries. A',
        '#                                                            string or an array of them; empty and',
        '#                                                            absent both mean no label. Answer it where',
        '#                                                            a guardrail workflow fails an unlabelled PR:',
        '#                                                            without one the sync PR goes red on CI and',
        '#                                                            cannot merge. They go on the create AND on',
        '#                                                            the printed line, so whichever route you',
        '#                                                            take carries them (inbound #1023).',
        ''
    )
    return (($lines -join "`n") + "`n")
}

# --- The starter theme-check config ---------------------------------------------------------------
# Two checks over 'extends: nothing', because that is what two independent consumers arrived at. See
# the header for the measurement; the file states it again for whoever opens it next, since a minimal
# config with no reason in it reads as laziness rather than as arithmetic.
$themeCheckYml = @'
# Theme-check configuration -- for the CI workflow beside it (.github/workflows/theme-check.yml) and
# for local runs. Placed by dkj-subagents-shopify's adopt-shopify-floor as a STARTER: it is yours now, and
# raising it is how a repo reports that it has cleaned something up.
#
# DELIBERATELY MINIMAL, AND THE MEASUREMENT IS THE REASON. The recommended check set is written for a
# theme somebody has been linting all along. On a real store theme it is not: measured on the two
# Shopify repos this floor comes from, the full set reported 1504 offenses across 171 files on one
# (1078 of them at error severity) and roughly 58k on the other. A gate that is red on arrival is not a
# gate -- it gets bypassed on day one and never looks at the change that actually broke something.
#
# So this selects only what a merge must genuinely block on: Liquid that does not parse, and JSON that
# does not parse. Both are breakage a branch can introduce, both are invisible to a reviewer, and
# neither is a style opinion. Every other check is off, not forgiven -- switch one on here the day its
# offenses are at zero.
extends: nothing

LiquidHTMLSyntaxError:
  enabled: true
  severity: error
  ignore:
    # A .liquid extension without HTML inside: the HTML parser false-positives on these. Both existing
    # consumers needed exactly this exemption, which is why it is here rather than left to be
    # rediscovered. Delete a line if your theme has no such file.
    - assets/*.js.liquid     # JavaScript carrying Liquid variables
    - assets/*.css.liquid    # CSS carrying Liquid variables
    - assets/*.svg.liquid    # inline SVG assets

    # A PRE-EXISTING BREAK GOES HERE, ONE LINE PER FILE, WITH ITS REASON AND ITS LINE NUMBER -- not
    # because breaks are acceptable, but because repairing a revenue-serving section is a task with a
    # preview theme and somebody looking at it, rather than a lint setting. State the cost every time:
    # an exempted file gets NO syntax check, so a NEW break inside it passes silently.
    # - sections/example.liquid   # line 681: 'ul' closed before 'li' -- came in with the live theme

JSONSyntaxError:
  enabled: true
  severity: error
'@

# --- The CI workflow ------------------------------------------------------------------------------
# --fail-level error, and that is not a loosening: the config above selects two checks, both declared
# at error severity, so 'error' is exactly the set this repo said it wants to block on. Both existing
# consumers run precisely this.
$themeCheckWorkflow = @'
name: Theme check

# Shopify's own linter over the whole theme, on every PR into main. It catches Liquid that does not
# parse and JSON that does not parse -- the class of breakage a reviewer cannot reliably see and a
# preview does not always reveal, because a broken section can still render on the one page you open.
#
# Static analysis only: no store access, no secrets, and it never touches a theme. Which checks count
# is .theme-check.yml in the repo root, so a green run there means a green run here.
#
# Placed by dkj-subagents-shopify's adopt-shopify-floor. It is this repo's workflow now.

on:
  pull_request:
    branches: [main]

# The default token is read-only; checks:write lets the action write its result as a GitHub check with
# inline annotations on the diff, which is where a finding is actually useful.
permissions:
  contents: read
  checks: write

jobs:
  theme-check:
    name: Shopify theme check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Run theme check
        uses: Shopify/theme-check-action@v2
        with:
          theme_root: '.'
          # Only 'error' severity fails the check; warnings and info stay visible in the log. The two
          # checks .theme-check.yml enables are both declared at error severity.
          flags: '--fail-level error'
          token: ${{ github.token }}
'@

# --- Plan -----------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'adopt-shopify-floor -- the guard''s seams, a theme-check starter, and the CI gate' -ForegroundColor Cyan
Write-Host "  repo: $repoRoot"
Write-Host ''

$plan = @()

# The seam file: appended to, never created. A repo with no repo-config.ps1 has not run the bootstrap,
# and half-creating the seam lib here would take a job that belongs to specialists-init.
$configRel = 'scripts\repo-config.ps1'
$configPath = Join-Path $repoRoot $configRel
$seamState = 'append'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    $seamState = 'no-lib'
}
else {
    # Asked of the LOADED function rather than of the file text, so a repo that answers the seam from
    # somewhere else -- a dot-sourced sibling, a generated file -- is not told to add it twice.
    $defined = & {
        Set-StrictMode -Off
        try { . $args[0] } catch { return $false }
        return [bool](Test-FunctionDefined 'Get-ShopifyLiveThemeId')
    } $configPath
    if ($defined) { $seamState = 'already' }
}

switch ($seamState) {
    'already' { Write-Host "  [skip]   $configRel -- Get-ShopifyLiveThemeId is already answered here" -ForegroundColor DarkGray }
    'no-lib'  { Write-Host "  [STOP]   $configRel does not exist -- type /dkj-subagents-alpha:specialists-init first (reserved for explicit user invocation, so an agent hands it to the repo owner); it owns that file's existence." -ForegroundColor Yellow }
    default   {
        $how = if (([string]$LiveThemeId).Trim()) { "answered with $(([string]$LiveThemeId).Trim())" } else { 'commented out, so the session check keeps reporting' }
        Write-Host "  [append] $configRel -- the Shopify seam block, $how" -ForegroundColor Green
        $plan += @{ Rel = $configRel; Mode = 'append'; Content = (Get-SeamBlock $LiveThemeId $StoreDomain) }
    }
}

foreach ($f in @(
    @{ Rel = '.theme-check.yml';                  Content = $themeCheckYml;      What = 'starter config: Liquid + JSON syntax, green on arrival' },
    @{ Rel = '.github\workflows\theme-check.yml'; Content = $themeCheckWorkflow; What = 'theme-check on every PR into main' }
)) {
    $target = Join-Path $repoRoot $f.Rel
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        Write-Host "  [skip]   $($f.Rel) -- already exists, left exactly as it is" -ForegroundColor DarkGray
        continue
    }
    Write-Host "  [create] $($f.Rel) -- $($f.What)" -ForegroundColor Green
    $plan += @{ Rel = $f.Rel; Mode = 'create'; Content = (($f.Content -replace "`r`n", "`n") + "`n") }
}

if ($plan.Count -eq 0) {
    Write-Host ''
    Write-Host '  Nothing to do: the floor is already adopted here.' -ForegroundColor Green
    exit 0
}

if (-not $Apply) {
    Write-Host ''
    Write-Host "  Re-run with -Apply to write the $($plan.Count) item(s) above. Nothing was written."
    if (-not (([string]$LiveThemeId).Trim()) -and $seamState -eq 'append') {
        Write-Host '  Add -LiveThemeId <numeric id> to have the guard armed in the same move.'
    }
    if (-not (([string]$StoreDomain).Trim()) -and $seamState -eq 'append') {
        Write-Host '  Add -StoreDomain <store>.myshopify.com to have the pre-task sync runnable in the same move.'
    }
    exit 0
}

# --- Apply ----------------------------------------------------------------------------------------
foreach ($item in $plan) {
    $target = Join-Path $repoRoot $item.Rel
    $dir = Split-Path -Parent $target
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($item.Mode -eq 'append') {
        # Appended, never merged into the existing text: the file belongs to this repo, and an inserter
        # that tried to find "the right place" would be rewriting somebody else's file on a guess.
        $existing = [System.IO.File]::ReadAllText($target)
        $sep = if ($existing.EndsWith("`n")) { '' } else { "`n" }
        [System.IO.File]::WriteAllText($target, ($existing + $sep + $item.Content), $Utf8NoBom)
        Write-Host "  appended: $($item.Rel)" -ForegroundColor Green
    }
    else {
        [System.IO.File]::WriteAllText($target, $item.Content, $Utf8NoBom)
        Write-Host "  created:  $($item.Rel)" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host "Done: $($plan.Count) item(s) placed." -ForegroundColor Green
if (([string]$LiveThemeId).Trim()) {
    Write-Host 'The guard is armed on all three rules. The session check will be silent from the next session.'
}
else {
    Write-Host 'The guard still has its id half inert: uncomment Get-ShopifyLiveThemeId with the real id.'
    Write-Host 'The session check will keep saying so until you do, which is the point.'
}
if (([string]$StoreDomain).Trim()) {
    Write-Host 'The pre-task sync (the sync-main skill) can run as it stands: the store is answered.'
}
else {
    Write-Host 'The pre-task sync (the sync-main skill) needs one more answer before it runs: uncomment'
    Write-Host 'Get-ShopifyStoreDomain with your store. It refuses rather than guessing which store to pull.'
}
Write-Host ''
Write-Host 'ONE THING TO READ BEFORE YOUR FIRST PULL FROM LIVE: the CLI rewrites line endings, so a pull'
Write-Host 'reports files as modified that nobody modified -- 37 with zero changed lines on one real'
Write-Host 'theme. Read the drift after a ''git add -A'', never off the raw git status, and do NOT pin'
Write-Host 'eol=lf in .gitattributes: that is the obvious fix and it makes the noise permanent. The'
Write-Host 'measurements are in the dkj-subagents-shopify README, under the git status section.'
Write-Host ''
Write-Host 'Already had a hand-written guard? See "Converging off a hand-written guard" in the'
Write-Host 'dkj-subagents-shopify README before you keep both -- two PreToolUse hooks fire on every command.'
