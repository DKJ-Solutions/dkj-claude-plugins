<#
.SYNOPSIS
    Gate: has a FIXTURE written into the real ~/.claude plugin administration, and is there a snapshot
    to put back if it has? (issue #1609)

.DESCRIPTION
    WHAT HAPPENED, MEASURED SEPTEMBER 8, 2026. While working #1591, an exploratory debug script -- a
    throwaway, written mid-investigation and never committed -- ran without redirecting
    $env:USERPROFILE, so every path it built from the user home resolved to the REAL one. It overwrote
    ~/.claude/plugins/installed_plugins.json with two fixture records (plug-behind@ccs-fixture and
    plug-clonebehind@ccs-fixture, both naming a projectPath under %TEMP%) and left a fixture
    marketplace clone at ~/.claude/plugins/marketplaces/ccs-fixture/. Every real per-checkout install
    record was gone -- this source checkout and both registered consumers -- and no backup existed
    beside the file.

    NOTHING ERRORED, and nothing reported it. The install record is what tells a session which plugin
    version this folder loaded, so with it gone roster-sessioncheck and plugin-versions both reported
    every plugin as "not installed in this checkout (enabled declaratively only)" -- which was by then
    literally true, and is indistinguishable from the ordinary state #1449 describes. It was found by
    reading the file.

    WHY THE FIX IS DETECT-AND-RECOVER RATHER THAN A GUARD, and this was measured before it was chosen.
    #1609 proposed a helper that refuses to write under ~/.claude unless the resolved home is a scratch
    path. Two things rule that shape out here:

      1. NOTHING IN THE COMMITTED TREE WRITES UNDER ~/.claude -- every reference anywhere in scripts/
         is a READER. So a write-helper would ship with no in-tree caller, enforced only by a one-off
         script's author remembering to call it, which is exactly the criticism #1609 makes of
         Get-InstallRecord's docstring. And the lint gate could not hold anyone to it either: there
         are no committed writes for it to check.
      2. A COMMAND-STRING GUARD CANNOT SEE IT. The PreToolUse shape that works for the live-theme
         guard reads the command a session is about to run. Here that command was
         'powershell -File <temp>/dbg.ps1' -- the write lived inside the file, and nothing in the
         invocation named ~/.claude. Reading the heredoc that WROTE the script was considered and is a
         real vector, but the false-positive surface is the one guard-live-theme spent a release
         learning: this repo writes ABOUT installed_plugins.json constantly (check 12 of
         check-plugin-integrity is entirely about printed queries against it), so the first thing such
         a guard blocks is the fixture that tests it.

    So the harness is the only thing that reaches a throwaway script, and it reaches it twice: this
    check reports the pollution at the next session start, and the snapshot below makes the clobber
    exactly restorable instead of merely re-installable. Decision by Dave, September 8, 2026.

    THE SIGNATURE IS ONE THING, DELIBERATELY: a record whose projectPath sits under a SCRATCH tree.
    A checkout does not live in %TEMP%, so such a record was written by a fixture. It is a signature
    the existing readers cannot see -- Get-InstallRecord filters to this repo's path, and separately
    skips any record whose path no longer resolves (#301), so a fixture record whose scratch root has
    since been deleted is invisible to every check in the tree. That is why this reads AllRecords.

    THE ORPHAN MARKETPLACE DIRECTORY IS REPORTED, BUT ONLY AS PART OF THAT FINDING -- never as a scan
    of its own. An independent "a directory under marketplaces/ that known_marketplaces.json does not
    reference" check fires on ordinary residue: measured on this machine the same day,
    ~/.claude/plugins/marketplaces/claude-plugins-official/ is exactly that, left behind by removing a
    marketplace and nothing to do with any fixture. Reporting it forever is the cry-wolf failure #294
    spent a release removing, and the stale-path check was already declined here at 124 findings all
    false. So the polluted RECORDS name their marketplace, and this check then says whether that
    marketplace's clone is also sitting in the real tree -- which is the actionable half, and is how
    ccs-fixture/ would have been named.

    THE SNAPSHOT, AND THE ORDER THAT MAKES IT SAFE. When the administration reads healthy this check
    copies it to installed_plugins.snapshot.json beside it, but only after the verdict is reached and
    only when the content differs from the snapshot already there. A polluted file can therefore never
    become the snapshot, and the reader gets the exact prior content -- which matters because
    re-installing changes WHAT IS INSTALLED rather than restoring what was, the reason #1609 was left
    unrepaired at filing. One file, no rotation: a rotation invites the question of which copy to
    trust, and "only ever written from a healthy read" already answers it.

    THIS IS THE ONE SESSION CHECK IN THE FAMILY THAT WRITES, and that is a change in kind rather than
    an oversight -- every other session check in this family states in as many words that it changes
    nothing (git-identity-sessioncheck.ps1: "Read-only: the hook changes nothing, in any repo"). The
    write is bounded to one path it owns, is skipped entirely on any finding, and is switched off by
    -NoSnapshot.

    THE SIBLINGS ARE NAMED RATHER THAN COUNTED, on the rule the plugin README's own hooks cell states:
    that cell said "two", went stale twice inside two days, and its answer was to stop counting. This
    sentence proved the rule while being written -- two reviewers checked it and returned two different
    numbers, four and five, because one counted this plugin's hooks and the other counted every plugin's.
    Both were wrong: eight hook files across three plugins carry that line today.

    ADVISORY, AND IN NO GATE, for the reason check-git-identity gives: the subject is a fact about the
    MACHINE, not about the diff. A CI runner has no plugin administration at all, so a workflow leg
    would report the empty state on every push.

    Its automatic caller is the SessionStart hook claude-home-sessioncheck.ps1. Run it by hand for the
    full report, [OK] and [SKIP] lines included:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-claude-home.ps1

    Exit 0 when the administration is clean, absent, or holds nothing to judge; exit 1 with the
    records, the marketplaces they name and the way back when a fixture has written into it.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER HomeOverride
    (For tests) Treat this directory as the user home instead of resolving the real one. The suite for
    this check MUST pass it -- a suite that exercised a check about polluting the real ~/.claude by
    polluting the real ~/.claude would be the defect wearing a test's clothes.

.PARAMETER ScratchRootOverride
    (For tests) Treat paths under these directories as scratch, instead of the machine's own temp
    directories. Semicolon-separated. Without it a fixture cannot express a CLEAN case at all: its own
    tree is under %TEMP%, so every record it writes would read as polluted.

.PARAMETER NoSnapshot
    Report only; write no snapshot. What the suite passes for every case that is not about the
    snapshot, and the switch to reach for if the snapshot is ever unwanted on a machine.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-claude-home.ps1
#>
[CmdletBinding()]
param(
    [string]$HomeOverride = '',
    [string]$ScratchRootOverride = '',
    [switch]$NoSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NO SOURCE-REPO GUARD, deliberately, and for the reason check-git-identity and check-unfolded-entry
# both give: a SessionStart hook invokes this from '${CLAUDE_PLUGIN_ROOT}/scripts/lint/' against the
# current machine, so Assert-OwnCopy would refuse it -- and thereby the hook -- at every session start
# in the source repo. Nothing this check reads is repo-relative, so a released copy answers exactly the
# same question as this one.

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# --- Which home, and which paths count as scratch -------------------------------------------------

# Get-InstallRecord resolves the home itself via -UserHomeOverride, which is the documented fixture
# seam; '' means "the real one", exactly as every other caller passes it.
#
# THE ROOT IS RESOLVED DUAL-CONTEXT, through the shared resolver the two sync checks delegate to, even
# though this check reads only the UNFILTERED field (AllRecords) and so never uses the repo-scoped half
# of the answer. It would work with any string. It resolves properly anyway because the invariant that
# every shared script does so is what keeps a consumer's mirror call from breaking silently -- and a
# script exempted from it because "this one does not need a root" is exactly how that invariant erodes.
# Resolve-CheckRoot returns Path = $null outside a work tree rather than throwing, so an advisory check
# run from anywhere still answers; Get-InstallRecord requires a non-empty string, and $PSScriptRoot is
# the honest stand-in for "nowhere in particular" since it names no checkout.
$rootScope = Resolve-CheckRoot -Override ''
$scopeRoot = if ($rootScope.Path) { $rootScope.Path } else { $PSScriptRoot }
$record = Get-InstallRecord -RepoRoot $scopeRoot -UserHomeOverride $HomeOverride

function Get-ScratchRoots {
    <# The directories a fixture builds under. Returns normalized, lowercased, separator-suffixed
       prefixes, so a StartsWith comparison cannot match a sibling whose name merely begins the same
       way ('...\Temporary' against '...\Temp'). #>
    param([string]$Override)

    $roots = @()
    if ($Override) {
        foreach ($r in ($Override -split ';')) { if ($r.Trim()) { $roots += $r.Trim() } }
    } else {
        # This READS the temp roots to recognise a fixture path; it composes nothing and writes
        # nowhere, so #1659's guid rule has no subject here -- hence the marker on the line itself,
        # which native-capture.tests.ps1 counts.
        foreach ($v in @($env:TEMP, $env:TMP, [System.IO.Path]::GetTempPath(), '/tmp', '/var/folders')) { # temp-path-exempt: reader, not composer
            if ($v) { $roots += $v }
        }
    }

    $out = @()
    foreach ($r in $roots) {
        $n = ([string]$r).Replace('/', '\').TrimEnd('\')
        if ($n) { $out += ($n.ToLowerInvariant() + '\') }
    }
    return @($out | Select-Object -Unique)
}

$scratchRoots = @(Get-ScratchRoots -Override $ScratchRootOverride)

function Test-ScratchPath {
    <# Does $Path sit under one of the scratch roots?

       TWO TESTS, and the second is what catches a temp directory THIS process cannot resolve: %TEMP%
       is a per-user path, so a record written by a fixture running as a scheduled task, in a
       container, or under another account names a temp directory that is nowhere in this process's
       environment. A literal '\temp\' segment survives that.

       The segment test is skipped under -ScratchRootOverride: that parameter names one specific tree,
       and widening it to any path with a '\temp\' segment would leave a fixture -- whose own tree is
       under %TEMP% -- unable to express a clean case, which is the one case the snapshot lives in.

       Both tests are case-insensitive: Windows paths are, and a record carries whatever casing the
       writer happened to use. #>
    param([string]$Path, [string[]]$Roots, [bool]$RootsWereOverridden)

    if (-not $Path) { return $false }
    $lower = ([string]$Path).Replace('/', '\').ToLowerInvariant()
    foreach ($r in $Roots) {
        if ($lower.StartsWith($r, [System.StringComparison]::Ordinal)) { return $true }
    }
    if (-not $RootsWereOverridden -and $lower -match '\\temp\\') { return $true }
    return $false
}

$rootsOverridden = [bool]$ScratchRootOverride

# --- The states that are not a finding ------------------------------------------------------------

if (-not $record.Path) {
    Write-Host '[SKIP] no user home could be resolved (no USERPROFILE / HOME) -- there is no plugin administration to read.'
    exit 0
}

$snapshotPath = Join-Path (Split-Path -Parent $record.Path) 'installed_plugins.snapshot.json'
$snapshotExists = Test-Path -LiteralPath $snapshotPath -PathType Leaf

if (-not $record.Exists) {
    # ABSENT IS NOT A FINDING ON ITS OWN. It is the ordinary state of a machine that has never
    # installed a plugin into a project -- and it is also what the worst case of this clobber looks
    # like. The snapshot is the only thing that tells the two apart, so the verdict turns on whether
    # one exists rather than on the missing file, which would otherwise cry wolf on every fresh
    # machine and be switched off before it caught anything.
    if ($snapshotExists) {
        Write-Host '[ERROR] the plugin administration is GONE, and a snapshot of it is sitting beside where it was:' -ForegroundColor Red
        Write-Host "          missing:  $($record.Path)" -ForegroundColor Red
        Write-Host "          snapshot: $snapshotPath" -ForegroundColor Red
        Write-Host '        A machine that never installed a plugin into a project has no snapshot either, so the' -ForegroundColor Red
        Write-Host '        snapshot is what separates that ordinary state from a file something deleted. Read it,' -ForegroundColor Red
        Write-Host '        and where it still describes what you expect to be installed, put it back:' -ForegroundColor Red
        Write-Host "          Copy-Item -LiteralPath '$snapshotPath' -Destination '$($record.Path)'" -ForegroundColor Red
        exit 1
    }
    Write-Host "[SKIP] no plugin administration on this machine ($($record.Path)) -- nothing installed into a project, so nothing to judge."
    exit 0
}

if (-not $record.Readable) {
    # AN UNREADABLE AUTHORITY IS ITS OWN FINDING, and it is reported rather than thrown for the reason
    # Get-InstallRecord states: a check must be able to say "I could not read the authority". It
    # belongs here because a half-finished write leaves exactly this -- and because every reader
    # downstream treats unreadable as "no evidence of absence" and stays deliberately silent about it
    # (Test-PluginInstalledHere), so without this line nobody says it at all.
    # THE PARSE ERROR IS THE MOST UNTRUSTED STRING THIS SCRIPT PRINTS, and it does not look like one.
    # ConvertFrom-Json's message EMBEDS THE OFFENDING DOCUMENT -- measured on a fixture, the message
    # carried the file's whole raw text, newlines and all -- so echoing it raw into output the hook
    # forwards into session context is the #309 line-forging vector at its widest: the content is
    # attacker-shaped by construction, since a file that parses would not be here. Format-SafeProseToken
    # is the sibling for echoing somebody else's text (#1419): control characters out, brackets
    # substituted so no marker can FORM, and a note when it had to change anything.
    Write-Host '[ERROR] the plugin administration exists but does not parse:' -ForegroundColor Red
    Write-Host "          file:  $($record.Path)" -ForegroundColor Red
    Write-Host "          error: $(Format-SafeProseToken -Value $record.Error)" -ForegroundColor Red
    Write-Host '        Until it parses, every check that asks "which plugin version is this checkout running?"' -ForegroundColor Red
    Write-Host '        answers from no evidence and stays silent about having none.' -ForegroundColor Red
    if ($snapshotExists) {
        Write-Host "        A snapshot from a healthy read is beside it: $snapshotPath" -ForegroundColor Red
    }
    exit 1
}

# --- The finding ----------------------------------------------------------------------------------

$allRecords = @($record.AllRecords)
$polluted = @($allRecords | Where-Object {
    Test-ScratchPath -Path $_.ProjectPath -Roots $scratchRoots -RootsWereOverridden $rootsOverridden
})

if ($polluted.Count -eq 0) {
    if ($allRecords.Count -eq 0) {
        Write-Host "[SKIP] the plugin administration holds no records ($($record.Path)) -- nothing to judge."
    } else {
        $plural = if ($allRecords.Count -ne 1) { 's' } else { '' }
        Write-Host "[OK] no fixture records in the plugin administration -- $($allRecords.Count) record$plural, none naming a scratch tree."
    }

    # THE SNAPSHOT: AFTER THE VERDICT, AND ONLY ON A CLEAN ONE. Written only on a difference, so an
    # unchanged administration is not rewritten at every session start. Wrapped because a read-only
    # home, a full disk or a permission denial must not turn an advisory check into a failure -- the
    # report above is the part that matters, and it has already been printed.
    if (-not $NoSnapshot) {
        try {
            # THIS RE-READS A FILE Get-InstallRecord ALREADY READ, and that is a declared trade rather
            # than an oversight. It read the same bytes to parse them and discards the raw text, so the
            # alternative is an -IncludeRaw switch on a lib five other scripts call -- more shared API
            # surface than a re-read of a few-KB file costs (measured in the low single-digit
            # milliseconds against a session start already spending hundreds).
            $live = Get-Content -LiteralPath $record.Path -Raw -Encoding UTF8
            $prior = if ($snapshotExists) { Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8 } else { $null }
            if ($live -ne $prior) {
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($snapshotPath, $live, $utf8NoBom)
                Write-Host "       snapshot refreshed: $snapshotPath"
            }
        } catch {
            Write-Host "       (snapshot not written: $(Format-SafeProseToken -Value $_.Exception.Message))"
        }
    }
    exit 0
}

# The marketplace half. An id is '<plugin>@<marketplace>', and the marketplace is what names a clone
# directory -- so a polluted record is what points at the leftover, rather than a scan of the
# directory itself (see the docstring for why that scan is declined).
$marketplaceDir = Join-Path (Split-Path -Parent $record.Path) 'marketplaces'
$leftoverClones = @()
foreach ($id in @($polluted | ForEach-Object { $_.Id } | Select-Object -Unique)) {
    $at = ([string]$id).LastIndexOf('@')
    if ($at -lt 0) { continue }
    $market = ([string]$id).Substring($at + 1)
    if (-not $market) { continue }
    # THE SLUG GUARD BEFORE THE PATH SEGMENT, which is the lib's own stated rule and what
    # check-roster-sync and check-policy-drift already do at the same seam. The id comes out of the
    # JSON file this whole check exists because a stray script can write, so a marketplace part
    # spelled '..\..\Windows' would otherwise have Test-Path probe -- and on a hit REPORT as a
    # "leftover clone" -- a directory nowhere near marketplaces/. Join-Path and Test-Path resolve '..'
    # without complaint. Nothing here deletes, so the cost is a misleading report rather than a lost
    # directory; the guard is one line and the convention is already established.
    if (-not (Test-PluginMarketplaceSlug -Marketplace $market)) { continue }
    $dir = Join-Path $marketplaceDir $market
    if (Test-Path -LiteralPath $dir -PathType Container) { $leftoverClones += $dir }
}
$leftoverClones = @($leftoverClones | Select-Object -Unique)

$totalPlural = if ($allRecords.Count -ne 1) { 's' } else { '' }
# The verb agrees with the POLLUTED count, not the total: "1 of 2 records names", "2 of 3 records name".
$pollutedVerb = if ($polluted.Count -eq 1) { 'names' } else { 'name' }

# EVERY VALUE OUT OF THE ADMINISTRATION IS SANITIZED BEFORE IT IS PRINTED (#309, #414). These lines
# are forwarded verbatim into session context by the hook, which decides how loudly by matching
# '[ERROR]' over the whole output -- so a record id or projectPath carrying a newline could forge a
# line, and one carrying a bracket could be COUNTED. This check is the place in the tree that needs
# that treatment most, its whole premise being that this file may hold content a stray script wrote.
# The id goes through the SUSPECT form because the record itself is the complaint: a sanitized id shown
# as clean would hide exactly what is wrong with it.
Write-Host '[ERROR] a FIXTURE has written into the real plugin administration on this machine:' -ForegroundColor Red
Write-Host "          file: $($record.Path)" -ForegroundColor Red
foreach ($p in $polluted) {
    Write-Host ("          record: {0}  ->  {1}" -f (Format-SuspectToken -Value $p.Id), (Format-SafePathToken -Value $p.ProjectPath)) -ForegroundColor Red
}
Write-Host "        $($polluted.Count) of $($allRecords.Count) record$totalPlural $pollutedVerb a scratch tree, which no checkout does. A record like this is" -ForegroundColor Red
Write-Host '        invisible to every other check here: the shared reader filters to this repo, and separately' -ForegroundColor Red
Write-Host '        skips any record whose path no longer resolves -- so a fixture root since deleted is skipped' -ForegroundColor Red
Write-Host '        twice over. What you SEE instead is every plugin reported as "not installed in this checkout".' -ForegroundColor Red
if ($leftoverClones.Count -gt 0) {
    Write-Host '        The same fixture left a marketplace clone in the real tree; nothing references it:' -ForegroundColor Red
    foreach ($d in $leftoverClones) { Write-Host "          $d" -ForegroundColor Red }
}
Write-Host '        The way back, in order:' -ForegroundColor Red
if ($snapshotExists) {
    Write-Host '          1. this check snapshotted the administration while it last read healthy:' -ForegroundColor Red
    Write-Host "             $snapshotPath" -ForegroundColor Red
    Write-Host '             Read it, and where it still describes what you expect, put it back -- that RESTORES the' -ForegroundColor Red
    Write-Host '             records, where re-installing writes new ones and changes what is installed.' -ForegroundColor Red
    Write-Host "             Copy-Item -LiteralPath '$snapshotPath' -Destination '$($record.Path)'" -ForegroundColor Red
} else {
    Write-Host '          1. there is NO snapshot to restore from -- this check had not read a healthy' -ForegroundColor Red
    Write-Host '             administration before the pollution landed. Re-install per plugin per checkout:' -ForegroundColor Red
    Write-Host '             claude plugin install <id> --scope project' -ForegroundColor Red
}
if ($leftoverClones.Count -gt 0) {
    Write-Host '          2. delete the leftover clone(s) above -- known_marketplaces.json does not name them.' -ForegroundColor Red
}
Write-Host '        And the cause sits upstream of all of it: a script that builds paths from the user home' -ForegroundColor Red
Write-Host '        without redirecting $env:USERPROFILE first writes HERE and reports success. A fixture' -ForegroundColor Red
Write-Host '        redirects it for the child process; see Get-InstallRecord in check-report-lib.ps1.' -ForegroundColor Red
exit 1
