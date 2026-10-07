<#
.SYNOPSIS
    SessionStart hook of the Shopify team: says when the live-theme guard is only half armed, and when
    a second, hand-written guard is still registered beside the shipped one.

.DESCRIPTION
    The guard beside this file has three rules. Two of them need nothing from the repo -- a theme
    publish and a theme delete are refused whatever the configuration. The third, a push aimed at the
    LIVE theme, has two triggers and only one of them is self-declaring:

      '--allow-live'  is the author saying so in the command, and always blocks.
      the live THEME ID  can only be recognised where the repo has said which id that is.

    So a repo that never answered Get-ShopifyLiveThemeId has a guard that blocks publish, delete and
    an --allow-live push, and lets 'shopify theme push --theme <the live id>' through. That is the one
    combination worth a line at session start, and the reason is the shape of the failure rather than
    its likelihood: the guard is INSTALLED, so it reads as protection, and the gap is invisible from
    inside the repo. A check that goes quiet for the right-looking reason is worse than one that
    speaks.

    WHY THIS IS AN [ERROR] AND NOT AN [INFO]. The session-check hooks in this family forward [ERROR]
    to the transcript and keep everything else for a deliberate run. An [INFO] here would be written
    for nobody. It is still not a refusal -- see the exit code below.

    IT NEVER BLOCKS. Always exit 0, whatever it finds, like every other session check in this family:
    a session start is not the place to refuse somebody entry to their own repo over a configuration
    question they can answer in three lines.

    SILENT IN THE ORDINARY CASE, both of them. A repo that answered the id gets nothing, and so does a
    repo with no scripts/repo-config.ps1 at all -- the specialists-init bootstrap is what creates that
    file, and a repo that has not run it already gets the one message naming its actual state. Adding
    a second would be noise on top of it.

    THE THIRD STATE: A REPO WITH NO STORE (inbound #1570). A repo can enable this team WITHOUT a Shopify
    store -- the plugin's own source repo does, and so does any repo that turns the team on only to
    validate that its manifests, frontmatter and hooks still resolve. Such a repo has no truthful theme
    id to give: seeding one would arm the guard over a live theme on a number nobody verified, and a
    VUL-IN placeholder reads as forgotten (above). So it answers Get-ShopifyRepoHasNoStore instead,
    returning $true, and this check then stays silent on the half-armed finding -- exactly as it does for
    a repo that HAS answered the id. That silence is safe here for the same reason it is safe there: it
    follows a deliberate, self-authored DECLARATION, never an inference this check drew from the tree
    (a theme directory, a shopify.theme.toml), which is the failure mode the paragraph above argues
    against. Absent -- the overwhelmingly common case -- is unchanged and still means a store repo. The
    declaration suppresses ONLY the first finding; the duplicate-guard finding below is independent.

    THE SECOND FINDING: TWO GUARDS DOING ONE JOB (inbound #777). Both consumers of this plugin wrote
    this guard themselves before it shipped here, and a plugin refresh does not replace a repo's own
    file -- it registers a second hook beside it. So a repo that did the right thing by inbound #769
    is rewarded with two PreToolUse guards firing on every command, and nothing anywhere said so,
    because that refresh happened INSIDE one version: no bump, and no changelog surfaced at install.
    The two findings are independent and either can fire alone, which is why the config-file check
    below gates only the first one.

    THE STORE FINDING (#2880). The claude.ai Shopify connector is bound to one store per account, and
    the check-shop-connector skill compares that binding with the store this repo expects. This hook
    reports when the repo names no store at all (Get-ShopifyThemeEstateStore, else
    Get-ShopifyStoreDomain), because then there is nothing to compare against. Same gates as the id
    finding: it needs a config file, and a no-store repo is silent.

    Read-only: it dot-sources the repo's own config in a child scope, parses the repo's settings, and
    prints. It writes nothing.

    Pure ASCII (repo convention for .ps1).
#>

$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'

# NO CONFIG FILE, NO ID FINDING -- but the duplicate-guard finding below still runs. See the
# .DESCRIPTION: the bootstrap owns the "you have no repo-config.ps1" message, and a repo can perfectly
# well be running a hand-written guard without ever having run the bootstrap.
$hasConfig = Test-Path -LiteralPath $configPath -PathType Leaf

# StrictMode OFF in a child scope, exactly as the guard reads it -- a consumer's config is written on
# the assumption that its runtime callers do not set it, and this check must not be the one that
# disagrees with the guard about what the repo answered.
$liveId  = ''
$noStore = $false
$store   = ''
if ($hasConfig) {
    $answers = & {
        Set-StrictMode -Off
        try { . $args[0] } catch { return @{ LiveId = ''; NoStore = $false; Store = '' } }
        $id = if (Get-Command Get-ShopifyLiveThemeId   -ErrorAction SilentlyContinue) { [string](Get-ShopifyLiveThemeId) } else { '' }
        # A no-store repo declares itself here (inbound #1570). Read defensively: any truthy answer means
        # "no store", so a repo that never defines the function -- every store repo -- is unaffected.
        $ns = if (Get-Command Get-ShopifyRepoHasNoStore -ErrorAction SilentlyContinue) { [bool](Get-ShopifyRepoHasNoStore) } else { $false }
        # The store this repo expects, in the order archive-theme and push-preview resolve it (#2862):
        # the estate seam first, Get-ShopifyStoreDomain only where that one is unanswered. Neither is
        # REQUIRED here -- answering Get-ShopifyStoreDomain also opens sync-main's pull-request route, and
        # some consumers leave it unanswered on purpose (#2880).
        # Wrapped on its own: a seam that throws must not turn a never-blocking check into exit 1, and
        # a store this cannot read is reported as unnamed, which is what it is to the skill as well.
        $st = ''
        try {
            if (Get-Command Get-ShopifyThemeEstateStore -ErrorAction SilentlyContinue) { $st = ([string](Get-ShopifyThemeEstateStore)).Trim() }
            if (-not $st -and (Get-Command Get-ShopifyStoreDomain -ErrorAction SilentlyContinue)) { $st = ([string](Get-ShopifyStoreDomain)).Trim() }
        } catch { $st = '' }
        return @{ LiveId = $id; NoStore = $ns; Store = $st }
    } $configPath
    $liveId  = [string]$answers.LiveId
    $noStore = [bool]$answers.NoStore
    $store   = [string]$answers.Store
}

# A PLACEHOLDER STORE COUNTS AS NO ANSWER, the rule push-preview applies to the same value.
if ($store -match 'VUL-IN') { $store = '' }

$liveId = ([string]$liveId).Trim()

# A NON-NUMERIC ANSWER COUNTS AS NO ANSWER, exactly as the guard beside this file now reads it -- the
# two must not be able to disagree about what "answered" means. A theme id is numeric, so anything else
# is a placeholder that was never filled in, and treating it as an answer would silence this very
# message while the id half of rule 3 stayed inert. Since adopt-shopify-floor writes the seam block
# with a 'VUL-IN' placeholder in it, that is a path a consumer can actually walk.
if ($liveId -and $liveId -notmatch '^\d+$') { $liveId = '' }

# THE NO-STORE DECLARATION SUPPRESSES ONLY THIS FINDING (inbound #1570). The duplicate-guard finding
# below is independent -- a no-store repo would not carry a hand-written guard, but if it somehow does,
# reporting it is still correct. The guard beside this file is left untouched on purpose: with no store
# there is nothing to push to, so its id rule staying inert costs nothing, and widening the guard's
# contract for a repo that never invokes it would be change for its own sake.
if ($hasConfig -and -not $liveId -and -not $noStore) {
    Write-Host ("[ERROR] dkj-subagents-shopify: the live-theme guard is armed for publish, delete and an " +
        "'--allow-live' push, but this repo has not said which theme is live -- so a push aimed at live " +
        "BY ID is not recognised and passes. Add Get-ShopifyLiveThemeId to scripts/repo-config.ps1, " +
        "returning the live theme's numeric id (shopify theme list names it) -- or run the " +
        "'adopt-shopify-floor' skill, which writes the block for you. The guard reads it on every " +
        "command; nothing needs restarting.")
}

# --- The store finding: nothing says which store this repo is (#2880) -----------------------------
# The claude.ai Shopify connector is bound to ONE store per account, so a session in this repo answers
# for whichever store the last session switched it to. A hook is a process, not a model turn, and cannot
# ask the connector which store it is bound to -- the comparison is the check-shop-connector skill's
# step. What this hook CAN say is that the skill has nothing to compare against. Silent once the repo
# names its store, and silent in a no-store repo, exactly like the id finding above.
if ($hasConfig -and -not $store -and -not $noStore) {
    Write-Host ("[ERROR] dkj-subagents-shopify: this repo has not said which Shopify store it is, so " +
        "nothing can tell whether the claude.ai Shopify connector is bound to this store or to another one. " +
        "Add Get-ShopifyThemeEstateStore to scripts/repo-config.ps1, returning the store's " +
        "<store>.myshopify.com domain -- the same seam push-preview and archive-theme read. The " +
        "check-shop-connector skill compares the connector against it.")
}

# --- The second finding: a hand-written guard still registered beside the shipped one --------------
# WHY THIS BELONGS HERE (inbound #777). Both consumers of this plugin wrote this guard themselves before
# it shipped, and a plugin refresh does not replace a repo's own file -- it registers a SECOND hook
# beside it. Two PreToolUse guards then fire on every Bash call, agree on their verdict, and block the
# same command twice. Nothing anywhere said so, because the refresh happened inside one version: no
# version bump, no changelog surfaced at install.
#
# THE TEST IS PRECISE RATHER THAN BROAD. The plugin registers its own hook through its own hooks.json,
# never through the consumer's settings -- so a PreToolUse command in .claude/settings*.json naming
# guard-live-theme is, by construction, a second one. A command reaching into the plugin cache is
# excluded: that is somebody wiring the SHIPPED copy by hand, which is one guard, not two.
$dupes = @()
foreach ($rel in @('.claude\settings.json', '.claude\settings.local.json')) {
    $settingsPath = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { continue }
    # A SETTINGS FILE THIS CANNOT PARSE IS SKIPPED, NOT REPORTED. Somebody else's broken JSON is
    # somebody else's message, and a session start is not where this check gets to editorialise about a
    # file it only came to read.
    try { $json = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json } catch { continue }
    if (-not $json.hooks) { continue }
    # -contains against the property NAMES, not .Contains() on them: a single-property object hands back
    # a bare string there, whose .Contains() is a substring test that answers true for the wrong reason.
    if (-not ($json.hooks.PSObject.Properties.Name -contains 'PreToolUse')) { continue }
    foreach ($matcher in @($json.hooks.PreToolUse)) {
        foreach ($h in @($matcher.hooks)) {
            $c = [string]$h.command
            if (-not $c) { continue }
            if ($c -notmatch 'guard-live-theme') { continue }
            if ($c -match 'CLAUDE_PLUGIN_ROOT' -or $c -match 'marketplaces') { continue }
            $dupes += $rel
        }
    }
}

# THE ADVICE IS GATED ON THE SEAM, AND THAT IS THE WHOLE POINT OF THIS BLOCK (inbound #994, August 27,
# 2026). It used to be one unconditional message calling the shipped guard "the superset", on the
# reasoning that it matches Bash|PowerShell where a hand-written one usually matches Bash only. That
# reasoning is about the MATCHER; the id rule is about the RULES, and this file's own header states the
# consequence: a repo that never answered Get-ShopifyLiveThemeId has a shipped guard that does not
# recognise a push aimed at live BY ID. A hand-written guard that matches Bash only and DOES know the
# live id therefore covers a case the shipped one does not -- the two are complementary there, not
# superset and subset. Telling that repo to remove its own guard, on a line calling removal "a safety
# improvement", opens the push-at-the-live-id vector, and it fails silently: the hook keeps running,
# everything keeps working, and only a push naming live by its number starts getting through.
#
# NOT A HYPOTHETICAL ORDERING. The consumer that filed this had answered the seam FIRST and re-measured
# the superset before removing its local guard. The ordering was deliberate there; nothing in this
# message asked for it.
if ($dupes.Count -gt 0) {
    $where = (($dupes | Sort-Object -Unique) -join ' and ')
    $common = ("[ERROR] dkj-subagents-shopify: a second live-theme guard is registered in $where, so two " +
        "PreToolUse hooks run one job on every command. The plugin registers its own through its own " +
        "hooks.json -- yours is the extra one. ")
    if ($liveId) {
        Write-Host ($common +
            "This repo has answered Get-ShopifyLiveThemeId, so the shipped guard is the superset (it " +
            "matches Bash|PowerShell where a hand-written one usually matches Bash only, and all three " +
            "of its rules are armed), and converging is a safety improvement rather than housekeeping: " +
            "remove your PreToolUse entry and your own script, and keep your test suite pointed at the " +
            "shipped copy. Your existing authorisation marker keeps working -- any marker ending in " +
            "'LIVE-PUSH-AUTHORIZED' is accepted. See 'Converging off a hand-written guard' in the " +
            "dkj-subagents-shopify README.")
    } else {
        Write-Host ($common +
            "ANSWER Get-ShopifyLiveThemeId BEFORE YOU CONVERGE, and read the line above this one. Until " +
            "this repo says which theme is live, the shipped guard does not recognise a push aimed at " +
            "live BY ID -- so if your own guard does know the id, it is covering a case the shipped one " +
            "is not, and removing it now would open that vector silently rather than tidy up a " +
            "duplicate. Answer the seam, confirm the shipped guard blocks a push at the live id, and " +
            "then converge: remove your PreToolUse entry and your own script, keeping your test suite " +
            "pointed at the shipped copy. Your existing authorisation marker keeps working -- any " +
            "marker ending in 'LIVE-PUSH-AUTHORIZED' is accepted. See 'Converging off a hand-written " +
            "guard' in the dkj-subagents-shopify README.")
    }
}

exit 0
