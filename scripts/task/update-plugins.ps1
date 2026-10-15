<#
.SYNOPSIS
    The buildable half of #1890: 1 + N commands per checkout, run as one. Refreshes the marketplace
    clone once, then runs `claude plugin update <id> --scope <the scope it is installed at>` for every
    plugin THIS checkout enables, then prints plugin-versions.ps1's receipt so the run's own result is
    verifiable.

.DESCRIPTION
    #1810 asked how updating stays workable across repos and machines; #1812 settled the mechanics
    (a session loads the extracted payload, the unit that moves it is a release, pulled per checkout
    per machine) and #1769 landed the flag day it was urgent for. What #1890 split out is the one
    piece still worth building: measured against `claude plugin update --help` / `install --help`,
    there is no `--all` and no repeatable `<plugin>` argument, so the act stays 1 + N commands unless
    something wraps it. This is that wrapper.

    THE BOUNDARY, NAMED IN #1890 ITSELF, AND A DEFAULT RUN KEEPS IT: this checkout plus the machine-wide
    marketplace clone, never a walk into another checkout. Every `claude plugin update` call below
    names $repoRoot alone, and `claude plugin install/update` rewrites the visited repo's
    .claude/settings.json -- so a sweeping updater could leave uncommitted diffs in repos nobody
    opened, possibly on a mid-work branch (#1810's second cost). A default run reads and writes no tree
    but this one; -AllCheckouts is the sweep, asked for by name and guarded per checkout against
    exactly that cost -- see .PARAMETER AllCheckouts.

    THE SCOPE IS READ OFF THE INSTALL RECORD, AND THAT DOES NOT WIDEN THAT BOUNDARY (issue #1986).
    Until then every call was hardcoded `--scope project`, and the CLI refuses a scope a plugin is not
    installed at -- so a machine-wide plugin was handed the one command that could have moved it and
    the run exited 1 on a healthy machine. Get-PluginUpdateScope answers it from the administration
    this run already reads; read its own block in check-report-lib.ps1 for why a 'local' or pathless
    'user' record is an ordinary state rather than an edge case. The boundary is about WHICH TREE gets
    written, and nothing here changes that: a user-scope update rewrites no repo's tree at all, and a
    'local'/'project' one rewrites exactly the checkout the caller is standing in.

    THREE STEPS, IN ONE RUN:
      1. `claude plugin marketplace update <marketplace>` once per DISTINCT marketplace this checkout's
         enabled plugins name (there is ordinarily one, but the loop does not assume it).
      2. `claude plugin update <id> --scope <scope>` for every plugin id `Get-EnabledPlugins` reports
         for $repoRoot -- the full effective set after the settings-chain precedence, the same set
         plugin-versions.ps1 reports on, so step 3's receipt is never comparing against a different
         list than step 2 acted on. The scope per id comes from Get-PluginUpdateScope (see the block
         above), so step 2 and the receipt's own prescriptions cannot disagree inside one run. Where a
         plugin ALSO has a path-less user-scope record beside this checkout's own, that record is
         updated too (#2459): it is a second install a session can load (#2442), and leaving it
         behind made the receipt call the run's own result behind. A plugin with NO record for this
         checkout gets `claude plugin install <id> --scope project` instead (#2560): an update there
         moved another checkout's record.
      3. plugin-versions.ps1, run as a CHILD PROCESS (Start-Process, live console, exactly the pattern
         Invoke-TestSuiteGate and the lint gate already use) -- never dot-sourced, because that script
         ends in `exit 0` on every path and dot-sourcing it would exit THIS script too.

    WHY EXECUTE RATHER THAN ONLY PRINT (unlike plugin-versions.ps1's own paste-ready commands). Every
    `claude ...` call here reaches the CLI through Invoke-NativeCapture's argument ARRAY, never through
    a string a shell re-parses -- so the paste-into-a-terminal injection surface Format-SafeProseToken /
    the withhold doctrine exist for does not apply to the exec path itself. What an untrusted
    'enabledPlugins' KEY can still do is confuse the CLI's OWN argument parser (an id starting with '-'
    reads as a flag to `claude`, not to a shell) -- so a target is only ever built from an id that
    passes Test-PluginNameSlug / Test-PluginMarketplaceSlug; anything else is reported and skipped
    rather than handed to the CLI to misinterpret.

    CONTINUES PAST A FAILURE. One marketplace or one plugin failing to update is not a reason to skip
    the rest -- each call's own exit code is recorded and the run's own exit code is non-zero only if
    something failed, so a caller (or a person reading $LASTEXITCODE) can tell without parsing prose.

    Dual-context: run the root copy in this repo, the plugin mirror in a consumer. Pure ASCII, per
    this repo's script-layer convention.

.PARAMETER DryRun
    Print every command this run would execute -- the marketplace refresh(es) and the per-plugin
    update(s) -- and run none of them. No receipt either: nothing changed for plugin-versions.ps1 to
    report on. The paste-ready line for a target that fails its slug check is withheld exactly as
    plugin-versions.ps1 withholds one, and for the identical reason.

.PARAMETER AllCheckouts
    Run the whole of the above once in EVERY checkout on this machine that holds a plugin install
    record, instead of only in the checkout you are standing in -- one command for "update all my
    repos". The checkouts are read off ~/.claude/plugins/installed_plugins.json (every record's
    projectPath), so it needs no list of folders and finds the same set on any machine.

    THIS IS #1890'S BOUNDARY MADE A GUARD RATHER THAN A WALL. The boundary existed for one measured
    cost: `claude plugin install/update` rewrites the visited repo's .claude/settings.json, so a sweep
    would leave uncommitted diffs in repos nobody opened, possibly on a mid-work branch. Measured
    October 15, 2026, over 11 checkouts going 5.20.0 -> 5.21.0: not one diff. So the sweep runs, and
    the half of the cost that can still happen is refused per checkout instead of for all of them:
      * a checkout NOT ON ITS TRUNK (origin/HEAD) is skipped -- a mid-work branch is never touched;
      * a checkout with uncommitted changes under .claude/ is skipped -- this run's rewrite would be
        mixed into somebody's own edit;
      * a checkout this run DID leave a .claude/ diff in is named in the summary, so the diff is a
        line to act on rather than a surprise in the next session there.
    A record that does not name the root of a git checkout is skipped too, and records whose folder is
    gone are counted into one summary line (tidy-machine owns those records). Each checkout runs this
    same script as a child process, from its own root -- except an unmodified checkout of the source
    repo, which runs its own copy, since the source-repo guard refuses any other; a checkout merely
    SHAPED like the source repo is skipped rather than having its script executed. TRUST: the sweep
    runs git in every recorded checkout before deciding to skip it, and git honours that repo's own
    .git/config -- the same trust as opening it, extended to repos you did not open this time. -DryRun is passed through, so -AllCheckouts -DryRun
    prints every checkout's commands and runs none. Exits 1 if any checkout's run failed.

.PARAMETER RootOverride
    Repo root to resolve the enable state against, for the test suite. A consumer never types this.

.PARAMETER UserHomeOverride
    The home directory '~/.claude' hangs off, for the test suite. A consumer never types this.

.PARAMETER ReceiptScriptOverride
    The plugin-versions.ps1 path step 3 runs as a child process, for the test suite to point at a
    fixture double instead of the real script. A consumer never types this; the real run always
    resolves it as a sibling of this file.

.EXAMPLE
    ./scripts/task/update-plugins.ps1
.EXAMPLE
    ./scripts/task/update-plugins.ps1 -DryRun
.EXAMPLE
    ./scripts/task/update-plugins.ps1 -AllCheckouts
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$AllCheckouts,
    [string]$RootOverride = '',
    [string]$UserHomeOverride = '',
    [string]$ReceiptScriptOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The source-repo guard, wired the way every shared entry point wires it -- see plugin-versions.ps1
# for the reasoning; it refuses a released copy run from inside the repo that maintains it.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context, exactly as plugin-versions.ps1 resolves it.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# --- -AllCheckouts: the sweep, one child run per checkout (see .PARAMETER AllCheckouts) -------------

function Get-GitLine {
    # One line of git output for $Path, or '' where git answers nothing or fails -- every caller below
    # treats '' as "could not establish", never as a value.
    param([string]$Path, [string[]]$GitArgs)
    $r = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $Path) + $GitArgs) -Utf8 -DiscardStderr
    if ($r.ExitCode -ne 0) { return '' }
    return ("$(@($r.Output) | Where-Object { "$_".Trim() } | Select-Object -First 1)").Trim()
}

function Test-ClaudeDirDirty {
    # $true when .claude/ in $Path -- the one tree this run rewrites -- has uncommitted changes, AND when
    # git could not answer: an unknown reads as dirty, so neither the guard nor the after-run warning
    # fails open (code review).
    param([string]$Path)
    $r = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $Path, 'status', '--porcelain', '--', '.claude') -Utf8 -DiscardStderr
    if ($r.ExitCode -ne 0) { return $true }
    return (@(@($r.Output) | Where-Object { "$_".Trim() }).Count -gt 0)
}

if ($AllCheckouts) {
    if ($RootOverride) {
        Write-Host "update-plugins: -AllCheckouts and -RootOverride cannot be combined -- the sweep reads its checkouts off the install administration." -ForegroundColor Red
        exit 1
    }
    $here = (Get-Location).Path
    $admin = Get-InstallRecord -RepoRoot $here -UserHomeOverride $UserHomeOverride
    if (-not $admin.Exists -or -not $admin.Readable) {
        $why = if (-not $admin.Exists) { 'it does not exist' } else { "it does not parse: $($admin.Error)" }
        Write-Host "update-plugins -AllCheckouts: cannot read the install administration ($($admin.Path)) -- $why." -ForegroundColor Red
        exit 1
    }

    # Distinct project paths, case-insensitively and without a trailing separator, ordinally sorted so
    # the run order is the same on every machine.
    $seen = @{}
    foreach ($rec in @($admin.AllRecords)) {
        $p = [string]$rec.ProjectPath
        if (-not $p) { continue }
        $key = $p.TrimEnd('\', '/').ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $p.TrimEnd('\', '/') }
    }
    $paths = [string[]]@($seen.Values)
    if ($paths.Count -gt 1) { [array]::Sort($paths, [System.StringComparer]::OrdinalIgnoreCase) }

    Write-Host ""
    Write-Host "update-plugins -AllCheckouts -- $($paths.Count) checkout(s) in the install administration$(if ($DryRun) { ', -DryRun' })" -ForegroundColor Cyan

    $results = New-Object System.Collections.Generic.List[object]
    # A record naming a folder that is gone is not a checkout to skip but clutter tidy-machine owns, so
    # it is counted into one summary line rather than listed: measured on the first live run, six such
    # records buried the ten real checkouts.
    $gone = 0
    foreach ($p in $paths) {
        $skip = ''
        $hint = ''
        if (-not (Test-Path -LiteralPath $p -PathType Container)) {
            $gone++
            continue
        }
        # IS THIS FOLDER THE ROOT: asked as --show-cdup rather than --show-toplevel, which returns raw
        # UTF-8 bytes a code page can corrupt (#2115, and the repo-wide guard on that flag). Inside a
        # work tree, an empty cdup line means the folder IS the root; --is-inside-work-tree keeps the
        # .git directory itself from answering 'yes'.
        $rootProbe = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $p, 'rev-parse', '--is-inside-work-tree', '--show-cdup') -Utf8 -DiscardStderr
        $probeLines = @(@($rootProbe.Output) | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        $isRoot = ($rootProbe.ExitCode -eq 0) -and ($probeLines.Count -eq 1) -and ($probeLines[0] -eq 'true')
        if (-not $isRoot) {
            $skip = 'not the root of a git checkout'
        } else {
            $branch = Get-GitLine -Path $p -GitArgs @('branch', '--show-current')
            $trunk = (Get-GitLine -Path $p -GitArgs @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')) -replace '^origin/', ''
            if (-not $trunk) {
                $skip = 'its trunk cannot be read (origin/HEAD is not set)'
                $hint = "git -C `"$p`" remote set-head origin --auto"
            } elseif ($branch -ne $trunk) {
                $shown = if ($branch) { "branch '$branch'" } else { 'a detached HEAD' }
                $skip = "on $shown, not on its trunk '$trunk' -- a mid-work branch is never touched (#1890)"
            } elseif (Test-ClaudeDirDirty -Path $p) {
                $skip = 'uncommitted changes under .claude/ (or git could not say) -- this run would mix its rewrite into them'
            }
        }

        if ($skip) {
            $results.Add([pscustomobject]@{ Path = $p; Outcome = 'skipped'; Detail = $skip; Hint = $hint })
            continue
        }

        # The source repo refuses every copy but its own (source-repo-guard-lib), so a checkout that
        # publishes plugins AND holds this script runs that copy; everyone else runs this file.
        # BUT ONLY THE REAL SOURCE REPO'S COPY, AND ONLY UNMODIFIED (security review): any clone can carry
        # a marketplace.json and a scripts/task/update-plugins.ps1, and the sweep would execute it in a
        # repo nobody opened. So the own copy runs only where origin IS the source repo and that file has
        # no uncommitted change; any other checkout shaped like a source repo is skipped, not executed.
        $ownCopy = Join-Path $p 'scripts\task\update-plugins.ps1'
        $useOwn = (Test-Path -LiteralPath (Join-Path $p '.claude-plugin\marketplace.json') -PathType Leaf) -and
                  (Test-Path -LiteralPath $ownCopy -PathType Leaf)
        if ($useOwn) {
            $origin = Get-GitLine -Path $p -GitArgs @('remote', 'get-url', 'origin')
            $ownDirty = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $p, 'status', '--porcelain', '--', 'scripts/task/update-plugins.ps1') -Utf8 -DiscardStderr
            $isSource = $origin -match '[/:]DKJ-Solutions/dkj-claude-plugins(\.git)?$'
            if (-not $isSource -or @(@($ownDirty.Output) | Where-Object { "$_".Trim() }).Count -gt 0) {
                $results.Add([pscustomobject]@{ Path = $p; Outcome = 'skipped'; Detail = 'it carries its own update-plugins.ps1 but is not an unmodified checkout of the source repo -- run the update there by hand'; Hint = '' })
                continue
            }
        }
        $childScript = if ($useOwn) { $ownCopy } else { $PSCommandPath }
        # THE CHILD IS TOLD ITS CHECKOUT THREE WAYS, because each reader resolves it differently:
        # -RootOverride for this script's own root (Resolve-CheckRoot puts CLAUDE_PROJECT_DIR ABOVE the
        # working directory, so inside a session every child would otherwise resolve to the session's
        # repo), CLAUDE_PROJECT_DIR for anything else that consults it, and the working directory for
        # the `claude plugin` calls, which write the checkout they are run from.
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $childScript, '-RootOverride', $p)
        if ($DryRun) { $childArgs += '-DryRun' }
        if ($UserHomeOverride) { $childArgs += @('-UserHomeOverride', $UserHomeOverride) }
        if ($ReceiptScriptOverride) { $childArgs += @('-ReceiptScriptOverride', $ReceiptScriptOverride) }

        Write-Host ""
        Write-Host "==== $p" -ForegroundColor Cyan
        $prevProj = $env:CLAUDE_PROJECT_DIR
        $env:CLAUDE_PROJECT_DIR = $p
        Push-Location -LiteralPath $p
        try {
            & powershell @childArgs | ForEach-Object { Write-Host $_ }
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
            if ($null -eq $prevProj) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
            else { $env:CLAUDE_PROJECT_DIR = $prevProj }
        }

        if ($code -ne 0) {
            $results.Add([pscustomobject]@{ Path = $p; Outcome = 'FAILED'; Detail = "exit $code -- see its run above"; Hint = '' })
        } elseif (-not $DryRun -and (Test-ClaudeDirDirty -Path $p)) {
            $results.Add([pscustomobject]@{ Path = $p; Outcome = 'updated'; Detail = 'left uncommitted changes under .claude/ (or git could not say) -- review and commit them in that repo'; Hint = '' })
        } else {
            $results.Add([pscustomobject]@{ Path = $p; Outcome = $(if ($DryRun) { 'dry-run' } else { 'updated' }); Detail = ''; Hint = '' })
        }
    }

    Write-Host ""
    Write-Host "update-plugins -AllCheckouts -- summary:" -ForegroundColor Cyan
    foreach ($r in $results) {
        # Yellow for a skip and for an update that left a .claude/ diff -- the two lines to act on.
        $color = if ($r.Outcome -eq 'FAILED') { 'Red' } elseif ($r.Detail) { 'Yellow' } else { 'Green' }
        $line = "  {0,-8} {1}" -f $r.Outcome, $r.Path
        if ($r.Detail) { $line += " -- $($r.Detail)" }
        Write-Host $line -ForegroundColor $color
        if ($r.Hint) { Write-Host "           -> $($r.Hint)" }
    }
    if ($gone -gt 0) {
        Write-Host "  $gone install record path(s) name a folder that is gone -- tidy-machine reports and clears them." -ForegroundColor Yellow
    }
    $failed = @($results | Where-Object { $_.Outcome -eq 'FAILED' }).Count
    $skipped = @($results | Where-Object { $_.Outcome -eq 'skipped' }).Count
    $ran = $results.Count - $failed - $skipped
    Write-Host ""
    Write-Host "update-plugins -AllCheckouts: $ran checkout(s) run, $skipped skipped, $failed failed." -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
    if ($failed -gt 0) { exit 1 }
    exit 0
}

$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'update-plugins.ps1' -OverrideName '-RootOverride'

Write-Host ""
Write-Host "update-plugins -- $repoRoot" -ForegroundColor Cyan

$enabled = Get-EnabledPlugins -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
$ids = @($enabled.Ids)

if ($ids.Count -eq 0) {
    Write-Host ""
    Write-Host "No plugins are enabled for this checkout." -ForegroundColor Yellow
    Write-Host "  Consulted: $($enabled.Summary)."
    Write-Host "  Nothing to update."
    exit 0
}

# The install administration, for the SCOPE half of every step-2 command (#1986). Read once rather
# than per target: it is one file, and plugin-versions.ps1 -- this run's own step-3 receipt -- reads
# it exactly this way, with the same fixture knob, so the two halves of one run cannot end up
# consulting different administrations.
$install = Get-InstallRecord -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride

# One command safety check per id, same predicate plugin-versions.ps1 already applies to its OWN
# printed commands (Test-PluginNameSlug / Test-PluginMarketplaceSlug) -- see this file's own
# docstring for why the reason differs (the CLI's argument parser, not a shell) while the guard is
# the one already in the tree.
$targets = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[string]
foreach ($id in $ids) {
    $parts = $id -split '@'
    $name = $parts[0]
    $mp = $parts[-1]
    if ((Test-PluginNameSlug -Name $name) -and (Test-PluginMarketplaceSlug -Marketplace $mp)) {
        $sc = Get-PluginUpdateScope -InstallRecord $install -PluginId $id
        # NO RECORD FOR THIS CHECKOUT AT ALL IS AN INSTALL, NEVER AN UPDATE (issue #2560). That is the
        # one 'default' answer with an empty Note: nothing names this path and nothing is tied to no
        # path. `claude plugin update --scope project` does not install there -- it goes looking for
        # A project-scope record and moved the one belonging to ANOTHER checkout, measured in a
        # consumer on 5.8.0 ("updated ... for scope project (...\smartwatchbanden)"), while the run
        # reported success and its own receipt said "not installed in this checkout". That breaks
        # #1890's boundary from inside the one call that was meant to respect it. `install --scope
        # project` writes exactly this checkout, and it is the command plugin-versions.ps1 already
        # prescribes for the same state. A 'default' WITH a Note is a checkout record the scope could
        # not be read off, so it stays an update, as before.
        $verb = if ($sc.Source -eq 'default' -and -not $sc.Note) { 'install' } else { 'update' }
        $targets.Add([pscustomobject]@{
            Id          = $id
            Name        = $name
            Marketplace = $mp
            Verb        = $verb
            Scope       = $sc.Scope
            ScopeSource = $sc.Source
            ScopeNote   = $sc.Note
        })
    } else {
        $skipped.Add((Format-SuspectToken -Value $id))
    }
}

# THE PATH-LESS USER-SCOPE SHADOW IS A SECOND INSTALL, SO IT IS A SECOND TARGET (issue #2459).
# Get-PluginUpdateScope answers ONE scope per plugin, the checkout's own record first -- so where a
# plugin has both a record for this checkout and a path-less user-scope record, the path-less one was
# never updated. Measured September 24, 2026, v5.7.0 -> v5.8.0: every project record moved, and this
# run's own step-3 receipt then reported 5 of 7 behind on exactly those path-less records (#2442's
# "a session can load the older one"), under a summary saying "0 failed".
#
# NOT GATED ON THE VERSION, and that is the point rather than a shortcut: in the measured run both
# records were at 5.7.0 BEFORE step 2, so a comparison taken here reads "nothing to do" and the shadow
# appears only after the checkout's record has moved. `claude plugin update` is idempotent, so a
# shadow already current costs one no-op call.
#
# ONLY 'user', never another path-less scope: 'managed' belongs to an administrator and is not this
# run's to move, and #1890's boundary is untouched because a user-scope update writes no repo tree.
$shadows = New-Object System.Collections.Generic.List[object]
foreach ($t in $targets) {
    if ($t.ScopeSource -ne 'record' -or $t.Scope -eq 'user') { continue }
    if ($null -eq $install -or -not $install.Readable -or $null -eq $install.PathlessById) { continue }
    if (-not $install.PathlessById.ContainsKey($t.Id)) { continue }
    $hasUser = @(@($install.PathlessById[$t.Id]) | Where-Object { [string]$_.Scope -ieq 'user' }).Count -gt 0
    if ($hasUser) {
        $shadows.Add([pscustomobject]@{ Id = $t.Id; Verb = 'update'; Scope = 'user' })
    }
}

if ($skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped (not a valid plugin id, so not handed to the CLI): $($skipped -join ', ')" -ForegroundColor Yellow
}

if ($targets.Count -eq 0) {
    Write-Host ""
    Write-Host "Nothing left to update after the id check above." -ForegroundColor Yellow
    exit 1
}

# WHY THE NOTES ARE PRINTED BEFORE ANYTHING RUNS, not beside the call they belong to. A note only ever
# exists where the administration could NOT answer and the run fell back to 'project' -- which is
# exactly the state #1986 was filed about, so it must not scroll past inside step 2's own output. The
# scope actually used is printed per call below regardless, so this block is the reason and that line
# is the act.
$scopeNotes = @($targets | Where-Object { $_.ScopeNote })
if ($scopeNotes.Count -gt 0) {
    Write-Host ""
    Write-Host "Scope could not be read from the install administration for $($scopeNotes.Count) plugin(s):" -ForegroundColor Yellow
    foreach ($t in $scopeNotes) { Write-Host "  $($t.Id) -- $($t.ScopeNote)" -ForegroundColor Yellow }
}

$marketplaces = [string[]]@($targets | ForEach-Object { $_.Marketplace } | Select-Object -Unique)
[array]::Sort($marketplaces, [System.StringComparer]::Ordinal)

if ($DryRun) {
    Write-Host ""
    Write-Host "-DryRun -- printing the commands this run would execute, none of them run:" -ForegroundColor Cyan
    foreach ($mp in $marketplaces) { Write-Host "  claude plugin marketplace update $mp" }
    # NOTHING IS APPENDED TO THESE LINES, not even the scope's provenance. -DryRun exists to be pasted
    # into a terminal, so a trailing '(from the install record)' would turn every line into one that
    # has to be edited first. The provenance that matters -- the administration failing to answer --
    # is the $scopeNotes block above, which is prose and does not pretend to be a command.
    foreach ($t in $targets) { Write-Host "  claude plugin $($t.Verb) $($t.Id) --scope $($t.Scope)" }
    foreach ($t in $shadows) { Write-Host "  claude plugin $($t.Verb) $($t.Id) --scope $($t.Scope)" }
    exit 0
}

# --- step 1: refresh each distinct marketplace clone, once ---------------------------------------

Write-Host ""
Write-Host "Step 1/3 -- refreshing the marketplace clone(s):" -ForegroundColor Cyan
$marketplaceFailures = 0
foreach ($mp in $marketplaces) {
    Write-Host ""
    Write-Host "  claude plugin marketplace update $mp"
    $r = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'marketplace', 'update', $mp) -Utf8 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    foreach ($line in @($r.Output)) { Write-Host "    $line" }
    if ($r.ExitCode -ne 0) {
        $marketplaceFailures++
        # THE REASON IS COMPOSED RATHER THAN INTERPOLATED (issue #1931, audited under #2081), at this
        # line and at its twin in step 2. An unmeasurable exit code satisfies `-ne 0` and prints as
        # nothing, so a lost code read "FAILED (exit )" -- and this script is the one a reader runs
        # BECAUSE something already looked wrong, so a failure with no reason in it is the worst shape
        # here.
        #
        # IT IS STILL COUNTED AS A FAILURE, AND THAT IS THE ONE PLACE IN THIS AUDIT WHERE AN UNKNOWN IS
        # DELIBERATELY REPORTED AS A FAILURE. The reason is the direction of the question: this script
        # answers "did every update succeed", and for an updater the conservative answer to "I could not
        # tell" is no. The seven WRITES elsewhere in this audit are the opposite case -- there the
        # conservative answer is to stop claiming a failure, because a reader acting on one re-does a
        # write that may have landed. Here re-running is the remedy anyway, and it is idempotent.
        #
        # SAID PRECISELY BECAUSE THE FIRST WORDING OVERCLAIMED (caught in review): step 3's receipt
        # prints the versions actually installed, so it corrects what the CONSOLE says -- it does not
        # touch this script's own exit code, and a caller reading that still gets the conservative
        # verdict above.
        Write-Host "    FAILED ($(Get-NativeExitLabel -Capture $r))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
    }
}

# --- step 2: update every plugin this checkout enables, each at its own scope ---------------------

Write-Host ""
Write-Host "Step 2/3 -- updating $($targets.Count) plugin(s), each at the scope it is installed at:" -ForegroundColor Cyan
$updateFailures = 0
# A CALL IS NOT A MOVE (issue #2728). `claude plugin update` exits 0 on a plugin that is already
# current, so the summary counted calls and a no-op run read "5 plugin(s) updated" under five lines of
# "is already at the latest version". The CLI's own sentence is the only per-call signal there is, so
# it is matched here; should the CLI reword it, the count falls back to the old reading (every clean
# call an update) rather than to a wrong "already current". Only the targets are counted -- the
# shadows have their own clause in the summary.
$alreadyCurrent = 0
$inShadows = $false
# ONE LOOP FOR BOTH: the path-less user-scope records beside a checkout record (#2459, see the block
# above $targets' skip report) go through the same call site as the targets, after them. They are the
# same question -- counted as update failures like any other call -- and one site is one audited
# bounded capture rather than two copies of it.
$firstShadow = if ($shadows.Count -gt 0) { $shadows[0] } else { $null }
# .ToArray() on both, not @(): Windows PowerShell 5.1 hands a generic List back from @() unchanged, and
# List + List throws "argument types do not match" rather than concatenating.
foreach ($t in ([object[]]$targets.ToArray() + [object[]]$shadows.ToArray())) {
    if ($null -ne $firstShadow -and [object]::ReferenceEquals($t, $firstShadow)) {
        $inShadows = $true
        Write-Host ""
        Write-Host "  ...and $($shadows.Count) path-less user-scope record(s) beside this checkout's own, which a session can load instead (#2442):" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  claude plugin $($t.Verb) $($t.Id) --scope $($t.Scope)"
    $r = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', $t.Verb, $t.Id, '--scope', $t.Scope) -Utf8 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    foreach ($line in @($r.Output)) { Write-Host "    $line" }
    if ($r.ExitCode -ne 0) {
        $updateFailures++
        Write-Host "    FAILED ($(Get-NativeExitLabel -Capture $r))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
    } elseif ($t.Verb -eq 'update' -and -not $inShadows -and (@($r.Output) -join "`n") -match 'already at the latest version') {
        $alreadyCurrent++
    }
}

# --- step 3: the receipt -- plugin-versions.ps1, as a CHILD PROCESS ------------------------------
# Never dot-sourced: it ends in `exit 0` on every path, and dot-sourcing it would exit this script
# too. Start-Process -NoNewWindow -Wait is the pattern gate-lib.ps1 already uses for exactly this
# reason (live, coloured child output on the caller's own console rather than a buffered pipe).

Write-Host ""
Write-Host "Step 3/3 -- receipt:" -ForegroundColor Cyan
$receiptPath = if ($ReceiptScriptOverride) { $ReceiptScriptOverride } else { Join-Path $PSScriptRoot 'plugin-versions.ps1' }
$receiptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $receiptPath + '"'))
if ($RootOverride) { $receiptArgs += @('-RootOverride', ('"' + $RootOverride + '"')) }
if ($UserHomeOverride) { $receiptArgs += @('-UserHomeOverride', ('"' + $UserHomeOverride + '"')) }
Start-Process -FilePath 'powershell' -ArgumentList $receiptArgs -NoNewWindow -Wait -WorkingDirectory (Get-Location).Path | Out-Null

Write-Host ""
$totalFailures = $marketplaceFailures + $updateFailures
if ($totalFailures -eq 0) {
    $shadowText = if ($shadows.Count -gt 0) { " (plus $($shadows.Count) path-less user-scope record(s))" } else { '' }
    $installed = @($targets | Where-Object { $_.Verb -eq 'install' }).Count
    $installText = if ($installed -gt 0) { ", $installed installed into this checkout (it had no install record)" } else { '' }
    $currentText = if ($alreadyCurrent -gt 0) { ", $alreadyCurrent already at the latest version" } else { '' }
    Write-Host "update-plugins: $($marketplaces.Count) marketplace(s) refreshed, $($targets.Count - $installed - $alreadyCurrent) plugin(s) updated$shadowText$currentText$installText, 0 failed." -ForegroundColor Green
    exit 0
}
Write-Host "update-plugins: $marketplaceFailures marketplace refresh(es) failed, $updateFailures plugin update(s) failed -- see FAILED lines above." -ForegroundColor Red
exit 1
