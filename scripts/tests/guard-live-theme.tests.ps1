<#
.SYNOPSIS
    Tests for plugins/dkj-subagents/dkj-subagents-shopify/hooks/guard-live-theme.ps1 -- the PreToolUse hook that holds
    the live Shopify theme -- and for the session check that says when it is only half armed.

.DESCRIPTION
    THE GUARD IS THE ONE FILE IN THIS PLUGIN WHERE BEING WRONG IS EXPENSIVE IN BOTH DIRECTIONS: too
    loose and a stray command reaches a revenue-serving theme, too tight and the deliberate live push a
    consumer's own rules describe cannot be executed at all. Everything else dkj-subagents-shopify ships is
    instruction text, which no test can hold.

    Each case feeds a realistic hook payload to the guard on stdin and asserts the exit code
    (2 = blocked, 0 = allowed). No mocking: the guard is invoked as the harness invokes it.

    FOUR GROUPS, AND EACH ONE ANSWERS A DIFFERENT WAY THIS CAN GO WRONG.
      1. The real commands must be blocked, INCLUDING when wrapped in a shell invocation -- that
         wrapper is exactly what a permission deny list cannot see, and the reason the hook exists.
      2. Mentioning the rule must NOT be blocked. Both cases here happened for real, on the day the
         reporting consumer installed their own version: the heredoc that wrote the rule into their
         CLAUDE.md, and the perl one-liner that edited that sentence afterwards.
      3. The exemptions in group 2 must not become a hole. A heredoc fed to an interpreter, text piped
         into a shell, xargs, and a real command sitting next to a harmless one are all still caught.
         GROUP 3 IS WHAT MAKES GROUP 2 SAFE TO HAVE -- an exemption without a counter-case is a hole
         with a comment on it.
      4. The seam, which is this version's own addition and therefore has no field history behind it:
         the id half of the live-push rule only exists where the repo answered, the marker default
         accepts what both existing consumers already write, and a configured marker narrows it.

      5. A PLACEHOLDER IS NOT AN ANSWER, and this group is the counter-case for the seam block
         adopt-shopify-floor writes: a 'VUL-IN' left in place must read as unanswered to the guard AND to
         the check, or the stub would silence the report while the id half stayed inert. Group 5 is to
         the seam what group 3 is to the exemptions.
      6. Two guards doing one job (inbound #777). A consumer who wrote this guard before it shipped now
         runs both, so the check reports it -- and the three cases that must NOT trip it are asserted
         beside the one that must: the shipped copy wired by hand, an unrelated PreToolUse hook, and a
         settings file that does not parse.
      7. THE SAME RULE, AUTHORED IN POWERSHELL (inbound #1032) -- groups 2 and 3 over again in the
         other shell, which is where the gap was. The matcher covered both shells from the first day;
         both exemptions knew only the POSIX spellings, and no case here had a PowerShell twin. So a
         consumer on Windows could not move its own printed delete command into a testable function,
         and the refusal it met advised adding the delete marker to that command -- advice that WORKS
         on a file write, because the marker is matched over the whole string. Group 7 closes both
         halves and asserts the refusal WORDING, because a sentence nothing asserts is a sentence the
         next edit removes.
      9. THE SAME RULES THROUGH THE ADMIN API (#2881). 'shopify store execute --allow-mutations' runs
         Admin GraphQL, so a themePublish or a themeFilesUpsert there does what rules 1 to 3 refuse
         through 'shopify theme'. Each rule is asserted in that form, with the query inline, over
         several lines, or in a --query-file / --variable-file, beside the reads and the non-theme
         mutations that must stay possible.

    Groups 1 to 3 are ported from the reference implementation the reporting consumer offered
    (BWJ-ecommerce/xoxowildhearts, inbound #769), which is where the false-positive lesson was paid
    for. Group 4 and the session-check cases are new here, because the shipped version reads a seam
    that the single-repo original did not have; groups 5 and 6 arrived with the floor's install path
    (inbound #776 and #777), and the command that places it has its own suite in
    adopt-shopify-floor.tests.ps1.

    Pure ASCII (repo convention for .ps1).
#>
# 'Continue', not 'Stop': the guard writes its refusal to stderr, and PowerShell 5.1 turns native
# stderr from a child process into a terminating NativeCommandError when the preference is 'Stop'.
# That stderr IS the expected output of a blocking case, so it must not end the run.
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Guard    = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify\hooks\guard-live-theme.ps1'
$Check    = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify\hooks\shopify-floor-sessioncheck.ps1'
# Fixture paths carry $PID: the test gate is a throttled PARALLEL scheduler, so two runs at one fixed
# temp path tear down each other's tree mid-assert.
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "guard-live-theme-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:pass = 0
$script:fail = 0
$LF = "`n"
$LIVE = '190793613653'

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function New-FixtureRepo {
    <# A consuming repo with the seam answers under test, or none at all. #>
    param([string]$Label, [string]$ConfigBody = $null)
    $root = Join-Path $Fixture "repo-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'scripts') | Out-Null
    if ($null -ne $ConfigBody) {
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), $ConfigBody, $Utf8NoBom)
    }
    return $root
}

function Invoke-Guard {
    <# Returns the exit code. The payload is the shape the harness sends, built rather than typed. #>
    param([string]$Command, [string]$Root)
    $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress -Depth 5
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $Root
    try {
        $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $Guard 2>&1 | Out-Null
        return $LASTEXITCODE
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
}

function Get-GuardRefusal {
    <#
        The refusal TEXT rather than the exit code. Invoke-Guard discards stderr on purpose -- forty
        cases care only whether the command was blocked -- but the wording is itself a guard property
        since inbound #1032, and a sentence nothing asserts is a sentence the next edit removes.
    #>
    param([string]$Command, [string]$Root)
    $payload = @{ tool_name = 'PowerShell'; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress -Depth 5
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $Root
    try {
        $out = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $Guard 2>&1
        return (($out | ForEach-Object { "$_" }) -join "`n")
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
}

function Invoke-FloorCheck {
    param([string]$Root)
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $Root
    try {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Check 2>&1
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
}

try {
    Write-Host "== guard-live-theme.tests: the live-theme guard and its session check ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $Fixture | Out-Null
    Assert-True (Test-Path -LiteralPath $Guard) 'the guard is where hooks.json says it is'
    Assert-True (Test-Path -LiteralPath $Check) 'and so is the session check beside it'

    # A repo that answered both seams: the ordinary, fully configured consumer.
    $configured = New-FixtureRepo -Label 'configured' -ConfigBody @"
function Get-ShopifyLiveThemeId { return '$LIVE' }
"@

    # --- group 1: the real thing, blocked ---------------------------------------------------------
    Write-Host "group 1 -- the real commands are blocked, wrapper and all" -ForegroundColor Cyan
    $blocked = @(
        @{ n = 'publish';                      c = "shopify theme publish --store x.myshopify.com --theme 123" },
        @{ n = 'publish through a wrapper';    c = 'powershell -Command "shopify theme publish --theme 123"' },
        @{ n = 'delete';                       c = "shopify theme delete --store x.myshopify.com --theme 123" },
        @{ n = 'live push by id, no marker';   c = "shopify theme push --store x.myshopify.com --theme $LIVE --only assets/x.css" },
        @{ n = 'live push by --allow-live';    c = "shopify theme push --store x.myshopify.com --allow-live" },
        @{ n = 'live push through a wrapper';  c = 'powershell -Command "shopify theme push --allow-live"' }
    )
    foreach ($case in $blocked) { Assert-Equal 2 (Invoke-Guard -Command $case.c -Root $configured) "blocked: $($case.n)" }

    # --- group 1b: what must stay possible --------------------------------------------------------
    Write-Host "group 1b -- and the work that must stay possible is untouched" -ForegroundColor Cyan
    $allowed = @(
        @{ n = 'live push WITH the marker';        c = "shopify theme push --theme $LIVE --only assets/x.css --allow-live # LIVE-PUSH-AUTHORIZED" },
        @{ n = 'preview push by id';               c = "shopify theme push --store x.myshopify.com --theme 987654321" },
        @{ n = 'unpublished preview creation';     c = "shopify theme push --store x.myshopify.com --unpublished --theme-name feat-x --json" },
        @{ n = 'pull from live (pre-task sync)';   c = "shopify theme pull --store x.myshopify.com --theme $LIVE" },
        @{ n = 'pull --live';                      c = "shopify theme pull --store x.myshopify.com --live" },
        @{ n = 'theme list';                       c = "shopify theme list --store x.myshopify.com" },
        @{ n = 'an ordinary command';              c = "git status --short" }
    )
    foreach ($case in $allowed) { Assert-Equal 0 (Invoke-Guard -Command $case.c -Root $configured) "allowed: $($case.n)" }

    # --- group 2: talking about the rule is not performing it -------------------------------------
    # THE TWO THAT HAPPENED FOR REAL are the heredoc and the perl one-liner. They are the reason the
    # matching asks where the words sit rather than whether they occur.
    Write-Host "group 2 -- mentioning the rule is not performing it" -ForegroundColor Cyan
    $mentions = @(
        @{ n = 'a commit message mentioning publish'; c = 'git commit -m "document how theme publish is gated"' },
        @{ n = 'grepping for the phrase';             c = 'grep -n "shopify theme publish" CLAUDE.md' },
        @{ n = 'a perl one-liner editing it';         c = "perl -0pi -e 's/shopify theme publish/a theme publish/' CLAUDE.md" },
        @{ n = 'a sed one-liner writing it';          c = "sed -i 's/x/shopify theme delete/' notes.md" },
        @{ n = 'docs mentioning publish';             c = "cat > CLAUDE.md <<'EOF'${LF}Never run shopify theme publish yourself.${LF}EOF" },
        @{ n = 'docs mentioning a live push';         c = "cat > CLAUDE.md <<'EOF'${LF}shopify theme push --theme $LIVE --allow-live${LF}EOF" },
        @{ n = 'docs mentioning delete';              c = "cat > notes.md <<'EOF'${LF}shopify theme delete --theme 1${LF}EOF" },
        @{ n = 'an indented heredoc terminator';      c = "cat > notes.md <<-EOF${LF}shopify theme publish --theme 1${LF}    EOF" }
    )
    foreach ($case in $mentions) { Assert-Equal 0 (Invoke-Guard -Command $case.c -Root $configured) "mention: $($case.n)" }

    # --- group 3: the exemptions are not a hole ---------------------------------------------------
    Write-Host "group 3 -- and every exemption in group 2 has its counter-case" -ForegroundColor Cyan
    $holes = @(
        @{ n = 'a real command AFTER a heredoc';        c = "cat > notes.md <<'EOF'${LF}harmless text${LF}EOF${LF}shopify theme publish --theme 1" },
        @{ n = 'a heredoc fed to bash IS a script';     c = "bash <<'EOF'${LF}shopify theme publish --theme 1${LF}EOF" },
        @{ n = 'a heredoc fed to powershell likewise';  c = "powershell -Command - <<'EOF'${LF}shopify theme delete --theme 1${LF}EOF" },
        @{ n = 'echo piped into a shell executes';      c = 'echo "shopify theme publish --theme 1" | bash' },
        @{ n = 'cat piped into a shell';                c = 'cat script.sh | sh   # shopify theme publish --theme 1' },
        @{ n = 'xargs disables the exemption';          c = 'echo "shopify theme delete --theme 1" | xargs -I{} {}' },
        @{ n = 'a real command after a harmless one';   c = 'grep -n foo CLAUDE.md; shopify theme publish --theme 1' },
        @{ n = 'a live push after a harmless one';      c = "git status && shopify theme push --theme $LIVE --allow-live" }
    )
    foreach ($case in $holes) { Assert-Equal 2 (Invoke-Guard -Command $case.c -Root $configured) "counter-case: $($case.n)" }

    # A payload the guard cannot parse must fail towards CHECKING, not towards allowing.
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $configured
    try {
        'this is not json but it says shopify theme publish' |
            & powershell -NoProfile -ExecutionPolicy Bypass -File $Guard 2>&1 | Out-Null
        Assert-Equal 2 $LASTEXITCODE 'an unparseable payload still blocks a publish -- it fails towards checking'
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }

    # --- group 4: the seam, which is this version's own addition -----------------------------------
    # THE SHIPPED GUARD READS A REPO'S ANSWERS, and the single-repo original it was ported from
    # hardcoded them. So this group has no field history behind it and is the part most worth asserting.
    Write-Host "group 4 -- the seam: what a repo answers, and what it gets when it does not" -ForegroundColor Cyan

    # No config file at all: the two absolute rules still hold, and so does the self-declaring flag.
    $bare = New-FixtureRepo -Label 'bare'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme publish --theme 1' -Root $bare) 'no config: publish is still blocked -- rule 1 needs no answer'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 1' -Root $bare) 'no config: delete is still blocked -- nor does rule 2'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme push --allow-live' -Root $bare) 'no config: --allow-live still blocks, because the flag declares itself'
    # AND THE HOLE, ASSERTED RATHER THAN LEFT IMPLIED. This is the case the session check exists for:
    # the guard is installed, so it reads as protection, while a push aimed at live BY ID passes.
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE" -Root $bare) 'no config: a push aimed at live BY ID passes -- the id half cannot fire, which is what the session check reports'

    # A configured id is what closes it.
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme push --theme $LIVE" -Root $configured) 'configured id: the same push is blocked'

    # THE DEFAULT MARKER IS A SUFFIX, so both existing consumers' spellings are accepted without either
    # of them configuring anything -- 'recognise both, write one', applied to a marker.
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # SWB-LIVE-PUSH-AUTHORIZED" -Root $configured) "default marker: one consumer's existing 'SWB-' spelling authorises"
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # XOXO-LIVE-PUSH-AUTHORIZED" -Root $configured) "default marker: and the other's 'XOXO-' spelling"
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # NOT-THE-MARKER" -Root $configured) 'default marker: an unrelated comment does not authorise'

    # A configured marker NARROWS it: the repo's own spelling only.
    $narrow = New-FixtureRepo -Label 'narrow' -ConfigBody @"
function Get-ShopifyLiveThemeId { return '$LIVE' }
function Get-ShopifyLivePushMarker { return 'ONLY-THIS-ONE' }
"@
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # ONLY-THIS-ONE" -Root $narrow) 'configured marker: the repo spelling authorises'
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # LIVE-PUSH-AUTHORIZED" -Root $narrow) 'configured marker: and the generic default no longer does -- configuring it NARROWS'

    # A broken config must not take the guard down with it: the absolute rules are the floor.
    $broken = New-FixtureRepo -Label 'broken' -ConfigBody "function Get-ShopifyLiveThemeId { this is not powershell"
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme publish --theme 1' -Root $broken) 'broken config: publish is still blocked rather than the guard erroring open'

    # --- the session check ------------------------------------------------------------------------
    Write-Host "the session check -- the half-armed state is the only thing it speaks about" -ForegroundColor Cyan
    $c1 = Invoke-FloorCheck -Root $bare
    Assert-Equal 0 $c1.Code 'floor check: never blocks a session, whatever it finds'
    Assert-True ($c1.Out -match '\[ERROR\]') 'floor check: an unanswered live theme id IS reported -- [ERROR] is the level the hook forwards'
    Assert-True ($c1.Out -match 'Get-ShopifyLiveThemeId') 'floor check: naming the function to add, not just the problem'
    Assert-True ($c1.Out -match 'publish, delete') 'floor check: and saying which rules DO hold, so it does not read as "unprotected"'

    $c2 = Invoke-FloorCheck -Root $configured
    Assert-Equal 0 $c2.Code 'floor check: exit 0 on a configured repo too'
    Assert-True (-not ($c2.Out -match '\[ERROR\]')) 'floor check: silent once the repo answered -- the ordinary state says nothing'

    # NO CONFIG FILE AT ALL IS ALSO SILENT, and that is a decision rather than an oversight: a repo that
    # has not run specialists-init already gets the one message naming its actual state.
    $noConfig = Join-Path $Fixture 'repo-noconfig'
    New-Item -ItemType Directory -Force -Path $noConfig | Out-Null
    $c3 = Invoke-FloorCheck -Root $noConfig
    Assert-Equal 0 $c3.Code 'floor check: exit 0 with no repo-config at all'
    Assert-True (-not ($c3.Out -match '\[ERROR\]')) 'floor check: and silent -- the bootstrap owns that message, not this hook'

    # --- group 5: a PLACEHOLDER is not an answer --------------------------------------------------
    # THIS IS THE COUNTER-CASE FOR adopt-shopify-floor's SEAM BLOCK. That command writes the block with
    # a 'VUL-IN' placeholder in it, so "somebody uncommented the line and never filled it in" is a state
    # a real consumer can reach -- and if a non-empty answer counted, it would silence the report above
    # while leaving the id half exactly as inert as before. A hole with a comment on it, which is the
    # failure this plugin's README is built around. Both readers must agree, so both are asserted.
    Write-Host "a placeholder id -- unanswered to the guard AND to the check" -ForegroundColor Cyan
    $placeholder = New-FixtureRepo -Label 'placeholder' -ConfigBody "function Get-ShopifyLiveThemeId { return 'VUL-IN' }"

    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme publish --theme 1' -Root $placeholder) 'placeholder id: publish is still refused -- rules 1 and 2 never depended on the seam'
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live" -Root $placeholder) 'placeholder id: an --allow-live push still blocks -- that half is self-declaring'
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE" -Root $placeholder) 'placeholder id: a push aimed at live BY ID passes, exactly as with no answer at all'
    # And the one that would be a real regression: the placeholder must not become something the guard
    # matches on. 'VUL-IN' inside an ordinary command is not an aim at the live theme.
    Assert-Equal 0 (Invoke-Guard -Command 'shopify theme push --theme 12345 # note: VUL-IN' -Root $placeholder) 'placeholder id: the placeholder text itself is not treated as a theme id'

    $c4 = Invoke-FloorCheck -Root $placeholder
    Assert-Equal 0 $c4.Code 'floor check: exit 0 on a placeholder answer too'
    Assert-True ($c4.Out -match '\[ERROR\]') 'floor check: a placeholder is REPORTED -- a non-numeric answer counts as unanswered, so the report is not silenced'

    # --- group 6: two guards doing one job (inbound #777) -----------------------------------------
    # A repo that wrote its own guard before this one shipped now runs both, because a plugin refresh
    # registers beside a consumer's file rather than replacing it. The test is precise on purpose: the
    # plugin registers through its OWN hooks.json, so a PreToolUse command in the consumer's settings
    # naming this guard is by construction a second one -- unless it reaches into the plugin cache,
    # which is somebody wiring the shipped copy by hand.
    Write-Host "the duplicate-guard finding -- and what must NOT trip it" -ForegroundColor Cyan
    function Set-FixtureSettings {
        param([string]$Root, [string]$Json, [string]$Rel = '.claude\settings.json')
        $p = Join-Path $Root $Rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
        [System.IO.File]::WriteAllText($p, $Json, $Utf8NoBom)
    }

    $dupe = New-FixtureRepo -Label 'dupe' -ConfigBody "function Get-ShopifyLiveThemeId { return '$LIVE' }"
    Set-FixtureSettings -Root $dupe -Json '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"powershell -File scripts/maintenance/guard-live-theme.ps1"}]}]}}'
    $c5 = Invoke-FloorCheck -Root $dupe
    Assert-Equal 0 $c5.Code 'duplicate guard: exit 0 -- this never blocks a session either'
    Assert-True ($c5.Out -match '\[ERROR\]') 'duplicate guard: a hand-written guard in the repo settings is reported'
    Assert-True ($c5.Out -match 'second live-theme guard') 'duplicate guard: and named, so the reader knows which finding this is'
    Assert-True ($c5.Out -match 'LIVE-PUSH-AUTHORIZED') 'duplicate guard: the report confirms the marker keeps working -- what a converging repo has to know BEFORE deleting its own guard'

    # The shipped copy wired by hand is ONE guard, not two.
    $viaPlugin = New-FixtureRepo -Label 'viaplugin' -ConfigBody "function Get-ShopifyLiveThemeId { return '$LIVE' }"
    Set-FixtureSettings -Root $viaPlugin -Json '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"powershell -File ${CLAUDE_PLUGIN_ROOT}/hooks/guard-live-theme.ps1"}]}]}}'
    $c6 = Invoke-FloorCheck -Root $viaPlugin
    Assert-True (-not ($c6.Out -match '\[ERROR\]')) 'duplicate guard: a command reaching the SHIPPED copy is not a second guard'

    # An unrelated PreToolUse hook is not a duplicate either -- the match is on this guard's name.
    $otherHook = New-FixtureRepo -Label 'otherhook' -ConfigBody "function Get-ShopifyLiveThemeId { return '$LIVE' }"
    Set-FixtureSettings -Root $otherHook -Json '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"powershell -File scripts/maintenance/guard-something-else.ps1"}]}]}}'
    $c7 = Invoke-FloorCheck -Root $otherHook
    Assert-True (-not ($c7.Out -match '\[ERROR\]')) 'duplicate guard: an unrelated PreToolUse hook is left alone'

    # Unparseable settings must be skipped, not reported: somebody else's broken JSON is somebody
    # else's message, and a session start must not turn into a complaint about a file we came to read.
    $badJson = New-FixtureRepo -Label 'badjson' -ConfigBody "function Get-ShopifyLiveThemeId { return '$LIVE' }"
    Set-FixtureSettings -Root $badJson -Json '{"hooks":{"PreToolUse":[ this is not json'
    $c8 = Invoke-FloorCheck -Root $badJson
    Assert-Equal 0 $c8.Code 'duplicate guard: unparseable settings do not break the session start'
    Assert-True (-not ($c8.Out -match '\[ERROR\]')) 'duplicate guard: and are skipped in silence rather than reported'

    # settings.local.json counts too: it is where a hand-registered hook most often actually lives.
    $localOnly = New-FixtureRepo -Label 'localonly' -ConfigBody "function Get-ShopifyLiveThemeId { return '$LIVE' }"
    Set-FixtureSettings -Root $localOnly -Rel '.claude\settings.local.json' -Json '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"pwsh ./guard-live-theme.ps1"}]}]}}'
    $c9 = Invoke-FloorCheck -Root $localOnly
    Assert-True ($c9.Out -match '\[ERROR\]') 'duplicate guard: settings.local.json is read as well'
    Assert-True ($c9.Out -match 'settings.local.json') 'duplicate guard: and named in the report, so the reader knows which file to edit'

    # BOTH FINDINGS ARE INDEPENDENT, and the earlier no-config exit used to swallow the second one: a
    # repo can run a hand-written guard without ever having run the bootstrap.
    $dupeNoConfig = Join-Path $Fixture 'repo-dupe-noconfig'
    New-Item -ItemType Directory -Force -Path $dupeNoConfig | Out-Null
    Set-FixtureSettings -Root $dupeNoConfig -Json '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"powershell -File scripts/maintenance/guard-live-theme.ps1"}]}]}}'
    $c10 = Invoke-FloorCheck -Root $dupeNoConfig
    Assert-True ($c10.Out -match 'second live-theme guard') 'duplicate guard: reported even with no repo-config.ps1 -- the two findings do not gate each other'
    Assert-True (-not ($c10.Out -match 'has not said which theme is live')) 'duplicate guard: while the id finding stays silent there, as it always was'


    # --- group 7: the authorised preview-theme delete ---------------------------------------------
    # Rule 2 became conditional, and every branch of that condition is asserted here. The FIRST case is
    # the one that matters most: a consumer who never asked for this capability must not receive it on a
    # plugin update. An unstated seam means unchanged, and unchanged for a delete is 'always denied'.
    Write-Host "the delete marker -- opt-in, and off until a repo asks" -ForegroundColor Cyan

    # $configured answers the id and nothing else, i.e. every existing consumer.
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 999 # ANY-MARKER-AT-ALL' -Root $configured) 'seam unanswered: a delete is refused however the command is decorated -- the capability does not exist'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 999 # THEME-DELETE-AUTHORIZED' -Root $configured) 'seam unanswered: and there is no generic default spelling that works, unlike the push marker'

    # A repo that DOES ask for it.
    $del = New-FixtureRepo -Label 'del' -ConfigBody @"
function Get-ShopifyLiveThemeId { return '$LIVE' }
function Get-ShopifyThemeDeleteMarker { return 'XOXO-THEME-DELETE-AUTHORIZED' }
"@
    Assert-Equal 0 (Invoke-Guard -Command 'shopify theme delete --store x.myshopify.com --theme 198933086549 # XOXO-THEME-DELETE-AUTHORIZED' -Root $del) 'seam answered: a spent preview theme with the marker is allowed'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --store x.myshopify.com --theme 198933086549' -Root $del) 'seam answered: the same delete WITHOUT the marker still blocks -- answering the seam does not open deletes generally'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 198933086549 # SOME-OTHER-COMMENT' -Root $del) 'seam answered: an unrelated comment does not authorise'
    Assert-Equal 0 (Invoke-Guard -Command 'shopify theme delete --theme 1 # xoxo-theme-delete-authorized' -Root $del) 'seam answered: the marker match is case-insensitive, like the push marker'

    # THE ONE NO MARKER REACHES. This is the check that runs before the authorisation path, so its
    # counter-case is the whole reason the ordering in the hook is not an accident.
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme delete --theme $LIVE # XOXO-THEME-DELETE-AUTHORIZED" -Root $del) 'the live theme: refused even WITH the marker'
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme delete --store x.myshopify.com --theme $LIVE" -Root $del) 'the live theme: and without it'

    # ONE MARKER MAY NOT DO TWO JOBS -- neither by being reused across seams, nor by leaking sideways.
    $same = New-FixtureRepo -Label 'same' -ConfigBody @"
function Get-ShopifyLiveThemeId { return '$LIVE' }
function Get-ShopifyLivePushMarker { return 'ONE-MARKER-FOR-BOTH' }
function Get-ShopifyThemeDeleteMarker { return 'ONE-MARKER-FOR-BOTH' }
"@
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 1 # ONE-MARKER-FOR-BOTH' -Root $same) 'same string for both seams: the delete capability is refused rather than granted -- a routine live-push marker must not double as standing delete authorisation'
    Assert-Equal 0 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # ONE-MARKER-FOR-BOTH" -Root $same) 'same string for both seams: while the push it was configured for keeps working'

    # The two markers stay in their own lanes when they are properly distinct.
    $both = New-FixtureRepo -Label 'both' -ConfigBody @"
function Get-ShopifyLiveThemeId { return '$LIVE' }
function Get-ShopifyLivePushMarker { return 'XOXO-LIVE-PUSH-AUTHORIZED' }
function Get-ShopifyThemeDeleteMarker { return 'XOXO-THEME-DELETE-AUTHORIZED' }
"@
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme delete --theme 1 # XOXO-LIVE-PUSH-AUTHORIZED' -Root $both) 'lanes: the PUSH marker does not authorise a delete'
    Assert-Equal 2 (Invoke-Guard -Command "shopify theme push --theme $LIVE --allow-live # XOXO-THEME-DELETE-AUTHORIZED" -Root $both) 'lanes: nor the DELETE marker a live push'
    Assert-Equal 2 (Invoke-Guard -Command 'shopify theme publish --theme 1 # XOXO-THEME-DELETE-AUTHORIZED' -Root $both) 'lanes: and publish stays absolute -- rule 1 has no marker at all'

    # The exemptions and their counter-cases hold for the new branch too.
    Assert-Equal 0 (Invoke-Guard -Command "cat > CLAUDE.md <<'EOF'${LF}shopify theme delete --theme 1 # XOXO-THEME-DELETE-AUTHORIZED${LF}EOF" -Root $both) 'documenting the authorised delete is still writing, not running'
    Assert-Equal 2 (Invoke-Guard -Command "cat > notes.md <<'EOF'${LF}harmless${LF}EOF${LF}shopify theme delete --theme $LIVE # XOXO-THEME-DELETE-AUTHORIZED" -Root $both) 'counter-case: a real live-theme delete after a heredoc is still caught'
    Assert-Equal 0 (Invoke-Guard -Command 'git status && shopify theme delete --theme 42 # XOXO-THEME-DELETE-AUTHORIZED' -Root $both) 'an authorised delete after a harmless command is allowed'

    # --- group 7: authoring the rule in POWERSHELL, and the note that stops it teaching forgery -----
    # INBOUND #1032. Group 2 proves that WRITING one of these commands into a file is not running it --
    # in Bash. The matcher covered both shells from day one, the exemptions covered only the POSIX
    # spellings, and nobody had asserted the PowerShell twin of a single group 2 case. So a consumer on
    # Windows could not move its own printed delete command into a function, and the refusal it met
    # told it to add the delete marker to 'this exact command' -- which, on a command that writes a
    # file, WORKS. Group 7 is group 2 and group 3 again in the other shell, plus the refusal text
    # itself, because a sentence with no assert on it is a sentence the next edit removes.
    Write-Host "group 7 -- the same rule, authored in PowerShell" -ForegroundColor Cyan
    $psMentions = @(
        # The reported case, as close to verbatim as a fixture gets: the printed command being moved
        # out of a format string into a function a test suite can assert.
        @{ n = 'a here-string carrying the delete, piped to Out-File'
           c = "`$fn = @'${LF}function Get-ThemeDeleteCommand([string]`$Id) { `"shopify theme delete --theme `$Id`" }${LF}'@${LF}`$fn | Out-File -FilePath scripts\theme.ps1" },
        @{ n = 'the double-quoted here-string form too'
           c = "`$doc = @`"${LF}Never run shopify theme publish yourself.${LF}`"@${LF}Set-Content -Path CLAUDE.md -Value `$doc" },
        @{ n = 'Out-File is the redirection'      ; c = 'Out-File -InputObject "shopify theme delete --theme 1" -FilePath notes.md' },
        @{ n = 'Set-Content writes text'          ; c = 'Set-Content -Path notes.md -Value "shopify theme delete --theme 1"' },
        @{ n = 'Add-Content appends it'           ; c = 'Add-Content -Path notes.md -Value "shopify theme publish --theme 1"' },
        @{ n = 'Select-String is grep'            ; c = 'Select-String -Pattern "shopify theme publish" -Path CLAUDE.md' },
        @{ n = 'Get-Content is cat'               ; c = 'Get-Content CLAUDE.md | Select-String "shopify theme delete"' }
    )
    foreach ($case in $psMentions) { Assert-Equal 0 (Invoke-Guard -Command $case.c -Root $both) "PS mention: $($case.n)" }

    # AND EVERY ONE OF THOSE EXEMPTIONS HAS ITS COUNTER-CASE, exactly as group 3 is to group 2. The
    # here-string strip is gated on the same $executesText that gates the text-tool exemption, so the
    # PowerShell ways of executing a string are what make it safe to have.
    $psHoles = @(
        @{ n = 'a here-string fed to Invoke-Expression IS a script'
           c = "`$c = @'${LF}shopify theme delete --theme 1${LF}'@${LF}Invoke-Expression `$c" },
        @{ n = 'and through the iex alias'
           c = "`$c = @'${LF}shopify theme publish --theme 1${LF}'@${LF}`$c | iex" },
        @{ n = 'and through [scriptblock]::Create'
           c = "`$c = @'${LF}shopify theme publish --theme 1${LF}'@${LF}& ([scriptblock]::Create(`$c))" },
        @{ n = 'a real command AFTER a closed here-string'
           c = "`$doc = @'${LF}harmless text${LF}'@${LF}`$doc | Out-File notes.md${LF}shopify theme publish --theme 1" },
        # AN OPENER WITH NO CLOSER MUST NOT SWALLOW THE REST. PowerShell would refuse to parse this, so
        # nothing would run either way -- which is the argument not to lean on: that would rest the
        # exemption on a claim about somebody else's parser rather than on what the guard can see.
        @{ n = 'an UNTERMINATED here-string puts its body back'
           c = "`$doc = @'${LF}harmless${LF}shopify theme publish --theme 1" },
        @{ n = 'a write cmdlet does not cover a real command beside it'
           c = 'Set-Content -Path a.txt -Value x; shopify theme publish --theme 1' },
        # A MARKER INSIDE A STRIPPED BODY IS DOCUMENTATION, NOT AUTHORISATION -- the same property the
        # heredoc path has always had, asserted for the new one before somebody discovers it.
        @{ n = 'a delete marker written INTO a file does not authorise a real delete'
           c = "`$doc = @'${LF}Add # XOXO-THEME-DELETE-AUTHORIZED to the command.${LF}'@${LF}`$doc | Out-File notes.md${LF}shopify theme delete --theme 42" }
    )
    foreach ($case in $psHoles) { Assert-Equal 2 (Invoke-Guard -Command $case.c -Root $both) "PS counter-case: $($case.n)" }

    # THE REFUSAL TEXT IS PART OF THE GUARD. The delete refusal told an author to add the marker to the
    # command in front of them; on a file write that advice works, and it trains the habit the marker
    # exists to prevent. The note now rides on every refusal, so every refusal is checked for it --
    # including publish, which has no marker at all and whose 'run it yourself' was wrong the same way.
    foreach ($case in @(
        @{ n = 'publish';    c = 'shopify theme publish --theme 1' },
        @{ n = 'delete';     c = 'shopify theme delete --theme 42' },
        @{ n = 'live push';  c = "shopify theme push --theme $LIVE --allow-live" }
    )) {
        $refusal = Get-GuardRefusal -Command $case.c -Root $both
        Assert-True ($refusal -match 'AUTHORING, NOT RUNNING') "the $($case.n) refusal says a marker authorises a command, not a file write"
    }

    # ----------------------------------------------------------------------------------------------
    Write-Host ""
    Write-Host "group 8 -- the machinery is command-guard-lib's now (#1734)" -ForegroundColor Cyan

    # THE ONE BEHAVIOUR THAT CHANGED WHEN THE LIB WAS ADOPTED, pinned so it is a decision rather than a
    # discovery. The lib expands an interpreter wrapper into a command in its own right BEFORE any
    # exemption is considered; this file used to reach the same wrapper only by matching the words
    # ANYWHERE in the segment. Every wrapper below lands where it always did -- except the last.
    Assert-Equal 2 (Invoke-Guard -Command 'bash -c "shopify theme publish --theme 1"' -Root $both)      'wrapper: bash -c is caught, as it always was'
    Assert-Equal 2 (Invoke-Guard -Command 'pwsh -Command "shopify theme publish --theme 1"' -Root $both) 'wrapper: and the PowerShell spelling'

    # THE ONE NEW REFUSAL, AND IT IS A FALSE POSITIVE. 'perl' is in $TEXT_TOOLS and is an interpreter,
    # and perl's own -c means SYNTAX CHECK -- nothing in that body runs. It is pinned rather than
    # exempted: carving perl out here would put a second opinion about wrappers back in the caller,
    # which is the duplication #1734 removed. The counter-case below is what keeps that honest.
    Assert-Equal 2 (Invoke-Guard -Command "perl -c 'shopify theme publish --theme 1'" -Root $both) 'wrapper: perl -c now blocks -- a NEW false positive, accepted with the lib and pinned here'
    Assert-Equal 0 (Invoke-Guard -Command "perl -e 'system(qq{shopify theme publish --theme 1})'" -Root $both) "wrapper: and 'perl -e' is UNCHANGED -- the residual limit this hook's header states, not a hole the swap opened"

    # ----------------------------------------------------------------------------------------------
    # A MISSING LIB DEGRADES TOWARDS CHECKING, which is where this guard parts company with its sibling
    # guard-working-copy.ps1: that one exits 0 and says the guard is off, because a working copy can be
    # restored from origin and a published theme cannot be un-published. Run from a directory with no
    # scripts\lib beside it, which is exactly what a broken or half-updated install looks like.
    $noLibDir = Join-Path $Fixture 'nolib\hooks'
    New-Item -ItemType Directory -Force -Path $noLibDir | Out-Null
    $noLibGuard = Join-Path $noLibDir 'guard-live-theme.ps1'
    Copy-Item -LiteralPath $Guard -Destination $noLibGuard -Force

    function Invoke-DegradedGuard {
        param([string]$Command)
        $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress -Depth 5
        $prev = $env:CLAUDE_PROJECT_DIR
        $env:CLAUDE_PROJECT_DIR = $both
        try {
            $err = ($payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $noLibGuard 2>&1 | Out-String)
            return @{ Code = $LASTEXITCODE; Out = $err }
        } finally {
            if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
            else { $env:CLAUDE_PROJECT_DIR = $prev }
        }
    }

    $degraded = Invoke-DegradedGuard -Command 'shopify theme publish --theme 1'
    Assert-Equal 2 $degraded.Code                             'no lib: a publish is STILL blocked -- the guard degrades, it does not switch off'
    Assert-True ($degraded.Out -match 'DEGRADED')             'no lib: and it says on stderr that it is running degraded'
    Assert-True ($degraded.Out -match 'command-guard-lib')    'no lib: naming the file to reinstall, so the report is actionable'

    # THE COST OF THAT CHOICE, ASSERTED RATHER THAN LEFT TO BE DISCOVERED. Without the lib there are no
    # exemptions, so writing the rule down is blocked too -- the pre-#769 behaviour. This case passes
    # (exit 0) in every normal install, and group 2 above is what proves it.
    Assert-Equal 2 (Invoke-DegradedGuard -Command "cat > notes.md <<'EOF'${LF}shopify theme publish --theme 1${LF}EOF").Code 'no lib: and the cost is real -- authoring the rule is blocked too, which is why this is a broken-install path and not a mode anybody runs in'

    # --- group 9: the same rules through the Admin API -- 'shopify store execute' (#2881) ---------
    # 'shopify store execute --allow-mutations' runs Admin GraphQL, so themePublish or themeFilesUpsert
    # does through the API what rules 1 to 3 refuse through 'shopify theme'. Before #2881 nothing here
    # matched it. Each rule is asserted in its API form, beside the reads and the non-theme mutations that
    # must stay possible.
    Write-Host "group 9 -- Admin GraphQL theme writes through 'shopify store execute'" -ForegroundColor Cyan
    $gid = "gid://shopify/OnlineStoreTheme/$LIVE"
    $exec = 'shopify store execute --store x.myshopify.com --allow-mutations'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation { themePublish(id: \`"gid://shopify/OnlineStoreTheme/1\`") { theme { id } } }'" -Root $configured) 'store execute: themePublish is refused, like rule 1'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation { themeFilesUpsert(themeId: \`"$gid\`", files: []) { job { id } } }'" -Root $configured) 'store execute: a theme write naming the live id is refused'
    Assert-Equal 0 (Invoke-Guard -Command "$exec --query 'mutation { themeFilesUpsert(themeId: \`"gid://shopify/OnlineStoreTheme/987654321\`", files: []) { job { id } } }'" -Root $configured) 'store execute: the same write to a preview theme passes, like a preview push'
    Assert-Equal 0 (Invoke-Guard -Command "$exec --query 'mutation { themeFilesUpsert(themeId: \`"$gid\`", files: []) { job { id } } }' # LIVE-PUSH-AUTHORIZED" -Root $configured) 'store execute: and the live write WITH the marker passes, like rule 3'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation { themeFilesUpsert(themeId: \`"gid://shopify/OnlineStoreTheme/987654321\`", files: []) { job { id } } }'" -Root $bare) 'store execute: with no live id configured, any theme write is refused -- nothing can tell it from live'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation { themeDelete(id: \`"gid://shopify/OnlineStoreTheme/987654321\`") { deletedThemeId } }'" -Root $configured) 'store execute: themeDelete is refused without the delete seam, like rule 2'
    Assert-Equal 0 (Invoke-Guard -Command "$exec --query 'mutation { themeDelete(id: \`"gid://shopify/OnlineStoreTheme/987654321\`") { deletedThemeId } }' # XOXO-THEME-DELETE-AUTHORIZED" -Root $del) 'store execute: and allowed for a preview with the repo delete marker'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation { themeDelete(id: \`"$gid\`") { deletedThemeId } }' # XOXO-THEME-DELETE-AUTHORIZED" -Root $del) 'store execute: but never for the live id, marker or not'
    # A multi-line query: the mutation name is not in the segment that holds 'store execute'.
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query 'mutation {${LF}  themePublish(id: \`"gid://shopify/OnlineStoreTheme/1\`") { theme { id } }${LF}}'" -Root $configured) 'store execute: a query spread over lines is still read whole'
    # The flag on a continuation line, away from the segment that holds 'store execute'.
    Assert-Equal 2 (Invoke-Guard -Command "shopify store execute --store x.myshopify.com \${LF}  --allow-mutations --query 'mutation { themePublish(id: 1) { theme { id } } }'" -Root $configured) 'store execute: --allow-mutations on a continuation line is still seen'

    # The query in a file: read relative to the repo, and refused when it cannot be read.
    [System.IO.File]::WriteAllText((Join-Path $configured 'publish.graphql'), 'mutation { themePublish(id: "gid://shopify/OnlineStoreTheme/1") { theme { id } } }', $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $configured 'product.graphql'), 'mutation { productUpdate(input: {id: "gid://shopify/Product/1", title: "x"}) { product { id } } }', $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $configured 'vars.json'), "{ `"id`": `"$gid`" }", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $configured 'upsert.graphql'), 'mutation($id: ID!) { themeFilesUpsert(themeId: $id, files: []) { job { id } } }', $Utf8NoBom)
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query-file publish.graphql" -Root $configured) 'store execute: a themePublish in a --query-file is refused'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query-file upsert.graphql --variable-file vars.json" -Root $configured) 'store execute: the live id in a --variable-file counts as aimed at live'
    Assert-Equal 0 (Invoke-Guard -Command "$exec --query-file product.graphql" -Root $configured) 'store execute: a non-theme mutation in a file passes'
    Assert-Equal 2 (Invoke-Guard -Command "$exec --query-file does-not-exist.graphql" -Root $configured) 'store execute: a query file that cannot be read is refused -- a theme mutation cannot be ruled out'

    # What must stay possible: reads, and mutations that are not about themes.
    Assert-Equal 0 (Invoke-Guard -Command "shopify store execute --store x.myshopify.com --query 'query { themes(first: 5) { nodes { id role } } }'" -Root $configured) 'store execute: a theme READ without --allow-mutations passes'
    Assert-Equal 0 (Invoke-Guard -Command "shopify store execute --store x.myshopify.com --query 'mutation { themePublish(id: 1) { theme { id } } }'" -Root $configured) 'store execute: without --allow-mutations the CLI runs no mutation, so there is nothing to refuse'
    Assert-Equal 0 (Invoke-Guard -Command "$exec --query 'mutation { productUpdate(input: {id: \`"gid://shopify/Product/1\`"}) { product { id } } }'" -Root $configured) 'store execute: a non-theme mutation passes'
    Assert-Equal 0 (Invoke-Guard -Command "grep -n 'shopify store execute --allow-mutations' notes.md # themePublish" -Root $configured) 'store execute: mentioning it in a text command is not running it'
    $refusal = Get-GuardRefusal -Command "$exec --query 'mutation { themeFilesUpsert(themeId: \`"$gid\`", files: []) { job { id } } }'" -Root $configured
    Assert-True ($refusal -match 'LIVE-PUSH-AUTHORIZED') 'store execute: the refusal names the marker for the deliberate live write'
} finally {
    Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
