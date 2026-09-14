<#
.SYNOPSIS
    Tests for scripts/task/plugin-versions.ps1 -- the read-only, per-device "is the plugin version
    this checkout loads the same as the marketplace clone's" report.

.DESCRIPTION
    The script is a monolithic entry point (param -> read the two sides -> print a verdict per
    plugin -> exit 0), not a lib of dot-sourceable functions -- Format-ShortSha, Resolve-Clone and
    Compare-Version are defined INSIDE it and cannot be reached without running the whole flow. So
    every scenario drives it end to end through its two documented test seams, -RootOverride and
    -UserHomeOverride, and asserts on stdout + exit code. Nothing here reads the real ~/.claude.

    THE CHILD IS CAPTURED THROUGH Invoke-NativeCapture -Utf8 (redirect files), never '2>&1' -- see
    Tycho's lens (04-18-extension.md) and issue #1530 for why a '2>&1' capture fails in a way that
    reads as a defect in the script under test. Phrase asserts strip ALL whitespace from both sides,
    so a line the child wrapped at its own console width still matches.

    The verdict paths covered, one scenario each:
      1  install sha == clone HEAD, versions agree            -> "up to date", summary all-current
      2  same version string, clone HEAD is a child of the    -> UNRELEASED work: its own verdict, its
         installed sha                                           own summary bucket, and NO command --
                                                                 `claude plugin update` is a measured
                                                                 no-op across a same-version boundary
                                                                 (#1772)
      2b same shape, but the clone's version moved too       -> genuinely "clone is AHEAD (x -> y)",
                                                                 per-plugin update
      2c same shape, but the CLONE has no readable version   -> says the release boundary cannot be
                                                                 read from here, never "same version
                                                                 string"
      3  no sha on the install side, installed version <      -> "clone is AHEAD (x -> y)", update
         clone version
      4  installed sha is NOT in the clone's history          -> "refresh the clone" (marketplace update)
      5  plugin enabled but no install record for this path   -> "enabled declaratively only" row, no crash
      6  no marketplace clone at all                          -> "cannot determine", exit 0, no throw
      7  two conflicting install records for one id+path      -> withheld comparison, no crash
      8  non-git clone: HEAD is read from the .gcs-sha file   -> 8a match on that sha, 8b version fallback
      9  a foreign plugin id not in the clone's marketplace   -> "cannot determine", no error
      10 no plugins enabled                                   -> a sentence, exit 0
      11 projectPath separator / trailing-slash insensitivity -> still matched, "up to date"
      12 install sha reachable in the clone but NOT an        -> version strings genuinely say the
         ancestor of HEAD (history rewrite in the clone)         clone is ahead -> per-plugin update,
                                                                   NOT a marketplace refresh
      13 same shape as 12, but the version strings do NOT     -> "your install is AHEAD of the
         say the clone is ahead                                  clone -- stale", marketplace refresh
      14 malformed gitCommitSha in the install record          -> degrades to the version comparison,
                                                                   never reaches git, no crash
      15 asymmetric gap (a): install has a version but no sha, -> the catch-all verdict names BOTH
         clone has HEAD but no readable plugin.json version       missing fields, never a bare
                                                                    "cannot determine -- " (regression)
      16 asymmetric gap (b): install has a sha but no version, -> same regression, opposite side
         clone has a version but no HEAD/.gcs-sha
      17 -Brief on a 'behind' row                             -> one [ERROR] line, action appended
      17b -Brief on an 'unreleased' row                       -> [INFO], NEVER [ERROR], and no command
                                                                  reaches a session start (#1772)
      18 -Brief on a 'clone-behind' row                       -> [INFO], NEVER [ERROR] -- #1591's own
                                                                  rule: a stale clone is not an error
      19 -Brief on an 'indeterminate' row                     -> [INFO], never [ERROR]
      20 -Brief on 'match' (20a) and 'ver-match' (20b)        -> the whole run is the [SUMMARY] line
                                                                  alone: an up-to-date plugin is silent
      21 -Brief with no plugins enabled                       -> one [INFO] line and no [SUMMARY]
      22 -Brief on a mix of every code                        -> exactly one [SUMMARY], whose counts
                                                                  partition all the rows (now SEVEN codes,
                                                                  including 'not-installed', #1802)
      23 -Brief suppresses the header, default view unchanged -> an absolute path stays out of a
                                                                  session start
      24 -Brief, enabled here with NO install record AT ALL   -> the SECOND [ERROR] verdict (#1802):
                                                                  'not-installed', its own summary bucket
                                                                  ("N enabled but not installed here")
      25 -Brief, only a path-less (machine-wide) record       -> deliberately STAYS 'indeterminate' /
         exists for this id                                     [INFO] -- narrower than #1802's split,
                                                                  and still counted as undetermined
      26 an UNREADABLE install administration file (Fix 1,    -> stays 'indeterminate'/[INFO], names
         Victor)                                                 the unreadable file, points at
                                                                   check-claude-home.ps1, NEVER the
                                                                   confident 'not installed' diagnosis
      27 NO install administration on the machine at all     -> still 'not-installed' -- Fix 1's own
                                                                   boundary, an accurate diagnosis that
                                                                   must not be swept up by scenario 26
      28 Fix 2 (Sebastian): id NAME half not a valid slug     -> the paste-ready install command is
                                                                   WITHHELD for that row only; a
                                                                   well-formed id in the same run still
                                                                   gets its own command
      29 Fix 2: id MARKETPLACE half not a valid slug          -> same withhold -- both halves are
                                                                   checked
      30 #1803: a bad-slug id that reaches a 'behind' verdict -> the `claude plugin update` command is
                                                                   withheld too, not just `install`
                                                                   (-Brief); every $action site is
                                                                   built from $idTok / $mpTok now
      31 #1803: the SAME id, default view (no -Brief)         -> command withheld AND the id header /
                                                                   verdict / action are sanitized at
                                                                   emission -- the default view is held
                                                                   to the same rule as -Brief
      32 #1986: a 'behind' row whose install record says      -> the prescription carries '--scope
         scope 'local'                                          local', never the hardcoded 'project'
                                                                   the CLI would refuse
      32b #1986: a path-less (machine-wide) record            -> the `claude plugin install` line is
                                                                   deliberately STILL '--scope project'
                                                                   -- it means "into this checkout"
      33 #1987: a clone marketplace.json that will not parse  -> names the manifest, and offers the
                                                                   refresh only as conditional on the
                                                                   file being damaged
      34 #1987: the measured shape -- valid JSON carrying     -> the refresh is ruled OUT by name, and
         two keys differing only in case                        the 5.1 reader is named as the cause
    Every scenario asserts exit code 0 explicitly (this is a report, not a gate).

    Scenarios 12/13 build the "reachable but not an ancestor" state the way a real marketplace clone
    reaches it: a rebase or force-push in the clone after which the OLD commit still exists as a loose
    git object (rev-parse -q --verify resolves it) but is no longer on the line from HEAD. See
    New-DivergedClone below.

    Test 8a additionally carries two SCOPED assertions (Assert-HasBetween / Assert-LacksBetween)
    alongside its existing Assert-Has: 'sha a1b2c3d4e5f6' also appears verbatim in the per-clone
    footer line (printed earlier than the per-plugin block), so an unscoped Assert-Has there would
    still pass even if the PER-PLUGIN "marketplace clone" line wrongly printed 'HEAD' instead of
    'sha' -- the footer alone would satisfy it. The scoped pair bounds the slice to that one line
    (from "marketplace clone" to the next "verdict"), so the needle -- or its absence -- can only be
    found where it is supposed to be.

    Dependency-free (no Pester), same style as check-report-lib.tests.ps1 / adopt-workflow-folder.tests.ps1.
    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$Script   = Join-Path $RepoRoot 'scripts\task\plugin-versions.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "plugin-versions-test-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8     = New-Object System.Text.UTF8Encoding $false

. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}
function Assert-Has {
    param([object]$Run, [string]$Needle, [string]$Label)
    Assert-True ($Run.Squish.Contains(($Needle -replace '\s', ''))) $Label
}
function Assert-Lacks {
    param([object]$Run, [string]$Needle, [string]$Label)
    Assert-True (-not $Run.Squish.Contains(($Needle -replace '\s', ''))) $Label
}
function Get-TextBetween {
    # The raw (unsquished) slice of $Run.Text from the first occurrence of $StartMarker up to the
    # next occurrence of $EndMarker (or to the end of the text if $EndMarker is not found after it).
    # $null when $StartMarker itself is not found, so callers can fail loudly on a bad scope rather
    # than silently searching the whole output.
    param([object]$Run, [string]$StartMarker, [string]$EndMarker)
    $s = $Run.Text.IndexOf($StartMarker)
    if ($s -lt 0) { return $null }
    $e = $Run.Text.IndexOf($EndMarker, $s + $StartMarker.Length)
    if ($e -lt 0) { return $Run.Text.Substring($s) }
    return $Run.Text.Substring($s, $e - $s)
}
function Assert-HasBetween {
    # Scoped version of Assert-Has: the needle must appear within the slice from $StartMarker up to
    # the next $EndMarker, not merely anywhere in the whole run's output. Use this where another part
    # of the output (the summary, the per-clone footer, the verdict line) can contain the same words
    # as the one line under test, so an unscoped Contains() would still pass even if that specific
    # line were wrong.
    param([object]$Run, [string]$StartMarker, [string]$EndMarker, [string]$Needle, [string]$Label)
    $slice = Get-TextBetween -Run $Run -StartMarker $StartMarker -EndMarker $EndMarker
    if ($null -eq $slice) {
        $script:fail++
        Write-Host "  [FAIL] $Label`n         marker not found in output: '$StartMarker'" -ForegroundColor Red
        return
    }
    Assert-True (($slice -replace '\s', '').Contains(($Needle -replace '\s', ''))) $Label
}
function Assert-LacksBetween {
    # The negation of Assert-HasBetween.
    param([object]$Run, [string]$StartMarker, [string]$EndMarker, [string]$Needle, [string]$Label)
    $slice = Get-TextBetween -Run $Run -StartMarker $StartMarker -EndMarker $EndMarker
    if ($null -eq $slice) {
        $script:fail++
        Write-Host "  [FAIL] $Label`n         marker not found in output: '$StartMarker'" -ForegroundColor Red
        return
    }
    Assert-True (-not (($slice -replace '\s', '').Contains(($Needle -replace '\s', '')))) $Label
}

# --- fixture builders -------------------------------------------------------------------------------

function Git-X {
    # git under EAP=Continue -- the #107 pitfall guard, the same one shared-scripts.tests.ps1 uses
    # around its own fixture git calls. scripts/tests/ is out of the unprotected-redirect scan, but the
    # runtime hazard (native stderr promoted to a terminating error under EAP=Stop) is real regardless.
    param([string]$Dir, [string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Dir @GitArgs 2>&1
        # THE EXIT CODE IS JUDGED (issue #1635). This helper returned the output and dropped the verdict,
        # so a failed fixture command was indistinguishable from a working one. Every call in this file
        # is expected to succeed -- there is no negative probe among them -- so judging the reads along
        # with the mutations costs nothing and covers both.
        Assert-FixtureGitOk -Code $LASTEXITCODE -GitArgs (@('-C', $Dir) + @($GitArgs)) -Output $out
        return (($out | ForEach-Object { "$_" }) -join "`n").Trim()
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Get-CloneGitExitCode {
    # Fixture-side sanity checks (12/13) need the EXIT CODE of a git call in the fixture clone --
    # e.g. does 'rev-parse -q --verify' resolve the orphaned commit at all -- not just its output, so
    # this goes through the already dot-sourced Invoke-NativeCapture rather than Git-X above (which
    # only hands back trimmed text). Distinct name from the script-under-test's own Invoke-CloneGit,
    # deliberately: this is the TEST's fixture helper, not a stand-in for the script's function.
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string[]]$GitArgs)
    return (Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $Dir) + $GitArgs) -DiscardStderr).ExitCode
}

function New-Case {
    # A checkout dir (-RootOverride) and a scratch home (-UserHomeOverride) that carries the install
    # administration and the marketplace clone. One '~/.claude' knob drives all three reads.
    param([Parameter(Mandatory = $true)][string]$Label)
    $repo    = Join-Path $Fixture "$Label\repo"
    $homeDir = Join-Path $Fixture "$Label\home"
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $homeDir '.claude\plugins') -Force | Out-Null
    [pscustomobject]@{
        Repo  = $repo
        Home  = $homeDir
        Clone = (Join-Path $homeDir '.claude\plugins\marketplaces\ccs-fixture')
        Admin = (Join-Path $homeDir '.claude\plugins\installed_plugins.json')
    }
}

function Set-Enabled {
    param([string]$RepoDir, [string[]]$Ids = @())
    New-Item -ItemType Directory -Path (Join-Path $RepoDir '.claude') -Force | Out-Null
    if ($Ids.Count -eq 0) {
        [System.IO.File]::WriteAllText((Join-Path $RepoDir '.claude\settings.json'), '{ "enabledPlugins": { } }', $Utf8)
        return
    }
    $ep = @{}
    foreach ($i in $Ids) { $ep[$i] = $true }
    [System.IO.File]::WriteAllText((Join-Path $RepoDir '.claude\settings.json'),
        (@{ enabledPlugins = $ep } | ConvertTo-Json -Depth 5), $Utf8)
}

function New-Clone {
    # A marketplace clone at $Dir: .claude-plugin/marketplace.json + one plugin.json per name, and
    # either a real git repo (returns the HEAD sha) or a plain tree with an optional .gcs-sha file.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Version = '4.32.0',
        [string[]]$PluginNames = @('dkj-subagents-alpha'),
        [switch]$NoGit,
        [string]$GcsSha = ''
    )
    New-Item -ItemType Directory -Path (Join-Path $Dir '.claude-plugin') -Force | Out-Null
    $plugins = @()
    foreach ($pn in $PluginNames) {
        $pdir = Join-Path $Dir "plugins\$pn\.claude-plugin"
        New-Item -ItemType Directory -Path $pdir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $pdir 'plugin.json'),
            (@{ name = $pn; version = $Version } | ConvertTo-Json -Depth 5), $Utf8)
        $plugins += @{ name = $pn; source = "./plugins/$pn" }
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir '.claude-plugin\marketplace.json'),
        (@{ name = 'ccs-fixture'; plugins = @($plugins) } | ConvertTo-Json -Depth 6), $Utf8)

    if ($NoGit) {
        if ($GcsSha) { [System.IO.File]::WriteAllText((Join-Path $Dir '.gcs-sha'), $GcsSha, $Utf8) }
        return ''
    }
    Git-X $Dir @('init', '--quiet') | Out-Null
    Git-X $Dir @('config', 'user.email', 'tycho@test.local') | Out-Null
    Git-X $Dir @('config', 'user.name', 'Tycho Test') | Out-Null
    Git-X $Dir @('config', 'commit.gpgsign', 'false') | Out-Null
    Git-X $Dir @('add', '-A') | Out-Null
    Git-X $Dir @('commit', '--quiet', '-m', 'clone c1') | Out-Null
    return (Git-X $Dir @('rev-parse', 'HEAD'))
}

function Add-CloneCommit {
    # -Version REWRITES the named plugins' plugin.json in the same commit, which is what makes the two
    # sha-ancestor cases (#1772) buildable: the ancestry alone says the clone is newer, and only the
    # version strings say whether that newer commit crossed a RELEASE boundary. Omit it and the commit
    # is a bare marker file, exactly as before -- every pre-#1772 call site keeps its old behaviour.
    param([string]$Dir, [string]$Version = '', [string[]]$PluginNames = @('dkj-subagents-alpha'))
    if ($Version) {
        foreach ($pn in $PluginNames) {
            $pj = Join-Path $Dir "plugins\$pn\.claude-plugin\plugin.json"
            [System.IO.File]::WriteAllText($pj, (@{ name = $pn; version = $Version } | ConvertTo-Json -Depth 5), $Utf8)
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir 'marker.txt'), [guid]::NewGuid().ToString(), $Utf8)
    Git-X $Dir @('add', '-A') | Out-Null
    Git-X $Dir @('commit', '--quiet', '-m', 'clone c2') | Out-Null
    return (Git-X $Dir @('rev-parse', 'HEAD'))
}

function New-DivergedClone {
    # A clone whose HEAD has moved through a history rewrite: the returned sha exists as a real git
    # object in the clone (rev-parse -q --verify resolves it) but is reachable from NEITHER HEAD nor
    # an ancestor of it -- exactly the state a rebase or force-push in the marketplace clone leaves
    # behind while the old object has not yet been garbage-collected. Built by committing once past
    # a shared base, resetting the clone back to that base (the commit is now an orphan, unreachable
    # from the branch, but still a loose object), then committing again down a DIFFERENT line so the
    # clone ends up with a real HEAD that never passed through the returned sha.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Version = '4.32.0',
        [string[]]$PluginNames = @('dkj-subagents-alpha')
    )
    New-Clone -Dir $Dir -Version $Version -PluginNames $PluginNames | Out-Null
    $base = Git-X $Dir @('rev-parse', 'HEAD')
    $diverged = Add-CloneCommit -Dir $Dir
    Git-X $Dir @('reset', '--hard', $base) | Out-Null
    Add-CloneCommit -Dir $Dir | Out-Null
    return $diverged
}

function New-Rec {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Version = '4.32.0',
        [string]$Sha = '',
        [string]$Scope = 'project'
    )
    $h = @{ scope = $Scope; projectPath = $ProjectPath; version = $Version }
    if ($Sha) { $h['gitCommitSha'] = $Sha }
    return $h
}

function Write-Admin {
    # installed_plugins.json: { version, plugins: { "<id>": [ <record>, ... ] } }
    param([string]$Path, [hashtable]$Plugins)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, (@{ version = 2; plugins = $Plugins } | ConvertTo-Json -Depth 12), $Utf8)
}

function Write-BadAdmin {
    # A RAW writer, deliberately bypassing Write-Admin's ConvertTo-Json -- scenario 26 needs a file
    # that EXISTS but does not PARSE, the shape Get-InstallRecord's own .Readable / .Error fields exist
    # to report (Fix 1, Victor, #1802 follow-up). Any well-formed JSON producer can only ever write a
    # file that parses; this one writes text that cannot.
    param([string]$Path)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, '{ "version": 2, "plugins": { this is not valid json !!', $Utf8)
}

function Invoke-PV {
    param([Parameter(Mandatory = $true)][string]$Repo, [Parameter(Mandatory = $true)][string]$UserHome, [switch]$Brief)
    # CLAUDE_PROJECT_DIR is pinned to the fixture checkout so the source-repo guard resolves a
    # deterministic root (a dir with no .claude-plugin/marketplace.json -> condition 2 fails -> the
    # guard returns nothing) instead of depending on the ambient env or `git rev-parse`. -RootOverride
    # still wins inside the script itself.
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $Repo
    try {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script,
               '-RootOverride', $Repo, '-UserHomeOverride', $UserHome)
        if ($Brief) { $a += '-Brief' }
        $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments $a -Utf8
        $joined = ($run.Output | ForEach-Object { "$_" }) -join "`n"
        return [pscustomobject]@{
            Code   = $run.ExitCode
            Text   = $joined
            Squish = ($joined -replace '\s', '')
        }
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
}

$ID  = 'dkj-subagents-alpha@ccs-fixture'
$UPD = 'claude plugin update dkj-subagents-alpha@ccs-fixture --scope project'
$MKT = 'claude plugin marketplace update ccs-fixture'

try {
    Write-Host "== plugin-versions.tests: scripts/task/plugin-versions.ps1 ==" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    Assert-True (Test-Path -LiteralPath $Script -PathType Leaf) 'plugin-versions.ps1 exists at its canonical path'

    # --- 1. Happy path: install sha == clone HEAD, versions agree --------------------------------------
    Write-Host "1. up to date -- install sha == clone HEAD" -ForegroundColor Cyan
    $c = New-Case 'happy'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $head) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '1: exit 0'
    Assert-Has  $r 'dkj-subagents-alpha@ccs-fixture' '1: the plugin id heads its block'
    Assert-Has  $r 'up to date -- your install is at the clone''s HEAD' '1: verdict is "up to date"'
    Assert-Has  $r 'All 1 plugin(s) up to date on 4.32.0' '1: summary says every plugin is current'
    Assert-Has  $r $MKT '1: the action names the clone-refresh command (currency is unprovable from here)'
    Assert-Lacks $r 'cannot determine' '1: nothing is indeterminate'
    Assert-Lacks $r $UPD '1: no per-plugin update is advised'

    # --- 2. Clone ahead by commit ONLY: same version string on both sides -> unreleased, no command ---
    # THE REGRESSION #1772 NAMES. This shape used to be reported as 'behind' with
    # `claude plugin update` as its action, and that command is a measured no-op here: it arbitrates on
    # the version string, finds both sides on 4.32.0, and exits successfully without moving the
    # install. If this is ever counted as behind again, or ever hands over an update command, these are
    # the asserts that must fail.
    Write-Host "2. clone ahead by commit only, same version -> unreleased work, NO command (#1772)" -ForegroundColor Cyan
    $c = New-Case 'ahead-commit'
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0'
    $shaB = Add-CloneCommit -Dir $c.Clone
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '2: exit 0'
    Assert-True ($shaA -ne $shaB) '2: fixture sanity -- the clone really advanced a commit'
    Assert-Has  $r 'your install is on the released version 4.32.0' '2: the verdict names the released version the install sits on'
    Assert-Has  $r 'unreleased work, so there is no version gap for a plugin update to close' '2: and says why no update closes it'
    Assert-Lacks $r $UPD '2: the per-plugin update command is NOT handed over -- it is a measured no-op here (#1772)'
    Assert-Has  $r '1 plugin(s): 1 on the released version, with unreleased commits in the clone -- nothing to update' '2: the summary reports it as its own state'
    Assert-Lacks $r 'plugin(s) behind' '2: and never as behind'

    # --- 2b. Clone ahead by commit AND by version -> genuinely behind, the update command applies -----
    # The sibling of 2, and the reason 2 is not simply "ancestry means do nothing": here the newer
    # commit DID cross a release boundary, so `claude plugin update` has a version gap to close and is
    # the right thing to print.
    Write-Host "2b. clone ahead by commit and by version -> behind, per-plugin update" -ForegroundColor Cyan
    $c = New-Case 'ahead-commit-and-version'
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0'
    $shaB = Add-CloneCommit -Dir $c.Clone -Version '4.33.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '2b: exit 0'
    Assert-True ($shaA -ne $shaB) '2b: fixture sanity -- the clone really advanced a commit'
    Assert-Has  $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '2b: the verdict names both versions'
    Assert-Has  $r $UPD '2b: the action is the per-plugin update command'
    Assert-Has  $r '1 of 1 plugin(s) behind' '2b: the summary counts it as behind'

    # --- 2c. Sha ancestor, but the CLONE has no readable version -> the honest "cannot read" wording --
    # Pre-#1772 this printed "same version string 4.32.0, newer commit" whenever the INSTALL had a
    # version, which was a wrong statement when the missing one was the clone's.
    Write-Host "2c. sha ancestor with no clone version -> says the boundary cannot be read from here" -ForegroundColor Cyan
    $c = New-Case 'ahead-commit-no-clone-version'
    $shaA = New-Clone -Dir $c.Clone -Version ''
    $shaB = Add-CloneCommit -Dir $c.Clone
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '2c: exit 0'
    Assert-True ($shaA -ne $shaB) '2c: fixture sanity -- the clone really advanced a commit'
    Assert-Has  $r "no version in the clone's plugin.json, so whether that crosses a release boundary cannot be read from here" '2c: the verdict names the side that is missing'
    Assert-Lacks $r 'same version string' '2c: and never claims the two version strings agree'
    Assert-Has  $r $UPD '2c: an update is still advised, because the gap may be a real one'

    # --- 3. Clone ahead by version: no sha on the install side, installed version < clone version -----
    Write-Host "3. clone ahead by version -> per-plugin update" -ForegroundColor Cyan
    $c = New-Case 'ahead-version'
    New-Clone -Dir $c.Clone -Version '4.33.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '3: exit 0'
    Assert-Has  $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '3: verdict names both versions'
    Assert-Has  $r $UPD '3: the action is the per-plugin update command'
    Assert-Has  $r '1 of 1 plugin(s) behind' '3: the summary counts it as behind'

    # --- 4. Installed sha is NOT in the clone's history -> refresh the clone --------------------------
    Write-Host "4. installed sha not in clone history -> marketplace refresh" -ForegroundColor Cyan
    $c = New-Case 'not-in-history'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha '1234567890abcdef1234567890abcdef12345678') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '4: exit 0'
    Assert-Has  $r "is not in the clone's history" '4: verdict says the recorded commit is unknown to the clone'
    Assert-Has  $r $MKT '4: the action is the marketplace-refresh command'
    Assert-Lacks $r $UPD '4: a per-plugin update is NOT advised here'
    Assert-Has  $r '1 of 1 plugin(s) behind' '4: the summary counts it as behind'

    # --- 5. Plugin enabled but no install record for this checkout -----------------------------------
    Write-Host "5. enabled declaratively only -> the no-record row, no crash" -ForegroundColor Cyan
    $c = New-Case 'declared-only'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    $elsewhere = Join-Path $c.Home 'some-other-checkout'
    New-Item -ItemType Directory -Path $elsewhere -Force | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $elsewhere -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '5: exit 0'
    Assert-Has  $r 'no install record in this checkout (enabled declaratively only)' '5: the installed-here line names the state'
    Assert-Has  $r 'cannot determine -- not installed in this checkout (enabled declaratively only)' '5: and the verdict does too'
    Assert-Has  $r 'claude plugin install dkj-subagents-alpha@ccs-fixture --scope project' '5: the action offers the install command'
    Assert-Lacks $r 'Exception' '5: no unhandled exception text leaked'

    # --- 6. No marketplace clone at all ------------------------------------------------------------
    Write-Host "6. no marketplace clone -> cannot determine, exit 0, no throw" -ForegroundColor Cyan
    $c = New-Case 'no-clone'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'abc123') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '6: exit 0 -- a missing clone is an ordinary consumer state'
    Assert-Has  $r 'no marketplace clone at' '6: the clone line says the directory is absent'
    Assert-Has  $r 'cannot determine -- no marketplace clone to compare against' '6: the verdict says so'
    Assert-Has  $r 'none confirmed up to date and none confirmed behind' '6: the summary is the indeterminate sentence'
    Assert-Lacks $r 'Exception' '6: nothing threw'

    # --- 7. Two conflicting install records for one id+path --------------------------------------------
    Write-Host "7. conflicting install records -> withheld comparison, no crash" -ForegroundColor Cyan
    $c = New-Case 'conflicting'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '4.32.0'),
        (New-Rec -ProjectPath $c.Repo -Version '4.31.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '7: exit 0'
    Assert-Has  $r '2 CONFLICTING records for this checkout' '7: the installed-here line reports the conflict'
    Assert-Has  $r 'cannot determine -- this checkout has 2 conflicting install records' '7: the verdict withholds the comparison'
    Assert-Has  $r 'repair: claude plugin install dkj-subagents-alpha@ccs-fixture --scope project' '7: the action offers the repair install'
    Assert-Lacks $r 'Exception' '7: no crash on the multi-record shape'

    # --- 8a. Non-git clone: HEAD read from .gcs-sha, and it matches the install sha -------------------
    Write-Host "8a. non-git clone -> HEAD comes from .gcs-sha (matches -> up to date)" -ForegroundColor Cyan
    $gcs = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
    $c = New-Case 'gcs-match'
    New-Clone -Dir $c.Clone -Version '4.32.0' -NoGit -GcsSha $gcs | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $gcs) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '8a: exit 0'
    Assert-Has  $r 'non-git fetch' '8a: the clone line marks it as a non-git fetch'
    Assert-Has  $r 'sha a1b2c3d4e5f6' '8a: the short sha printed is the one from .gcs-sha'
    # Scoped: 'sha a1b2c3d4e5f6' also appears verbatim in the per-clone FOOTER line (printed earlier,
    # before this plugin's own block), so the unscoped Assert-Has above would still pass even if the
    # PER-PLUGIN "marketplace clone" line wrongly printed 'HEAD' instead of 'sha'. Bound the slice to
    # that one line (from "marketplace clone" to the next "verdict") so the needle can only be found
    # where it is supposed to be.
    Assert-HasBetween  $r 'marketplace clone' 'verdict' 'sha a1b2c3d4e5f6' '8a: the PER-PLUGIN line itself (not just the footer) says "sha", scoped to that line'
    Assert-LacksBetween $r 'marketplace clone' 'verdict' 'HEAD' '8a: and that same line never says "HEAD" for a non-git clone'
    Assert-Has  $r 'up to date -- your install is at the clone''s HEAD' '8a: matching that sha yields "up to date"'
    Assert-Has  $r 'All 1 plugin(s) up to date on 4.32.0' '8a: and the summary agrees'

    # --- 8b. Non-git clone: shas differ -> version-only fallback, history cannot confirm direction ----
    Write-Host "8b. non-git clone -> version fallback when the shas differ" -ForegroundColor Cyan
    $c = New-Case 'gcs-fallback'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit -GcsSha $gcs | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha '9999999999999999999999999999999999999999') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '8b: exit 0'
    Assert-Has  $r 'non-git fetch so the commit history cannot confirm direction' '8b: verdict flags the non-git fallback'
    Assert-Has  $r $UPD '8b: and still advises the per-plugin update (version is behind)'

    # --- 9. A foreign plugin id that the clone's marketplace.json does not list ----------------------
    Write-Host "9. foreign plugin id -> cannot determine, no error" -ForegroundColor Cyan
    $c = New-Case 'foreign'
    New-Clone -Dir $c.Clone -Version '4.32.0' -PluginNames @('dkj-subagents-alpha') | Out-Null
    $foreign = 'foreign-thing@ccs-fixture'
    Set-Enabled -RepoDir $c.Repo -Ids @($foreign)
    Write-Admin -Path $c.Admin -Plugins @{ $foreign = @( (New-Rec -ProjectPath $c.Repo -Version '9.9.9' -Sha 'beefbeef') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '9: exit 0'
    Assert-Has  $r "cannot determine -- 'foreign-thing' is not in the clone's marketplace.json" '9: the verdict names the missing plugin'
    Assert-Has  $r 'could not be determined' '9: the summary rolls it up as indeterminate'
    Assert-Lacks $r 'Exception' '9: a foreign id does not throw'

    # --- 10. No plugins enabled -----------------------------------------------------------------------
    Write-Host "10. no plugins enabled -> a sentence, exit 0" -ForegroundColor Cyan
    $c = New-Case 'none-enabled'
    Set-Enabled -RepoDir $c.Repo -Ids @()
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '10: exit 0'
    Assert-Has  $r 'No plugins are enabled for this checkout.' '10: it says there is nothing to compare'

    # --- 11. projectPath separator / trailing-slash insensitivity -----------------------------------
    Write-Host "11. projectPath separator + trailing slash still match" -ForegroundColor Cyan
    $c = New-Case 'sep-fwd'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath ($c.Repo -replace '\\', '/') -Version '4.32.0' -Sha $head) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '11: exit 0'
    Assert-Has  $r 'up to date -- your install is at the clone''s HEAD' '11: a forward-slash projectPath still matches this checkout'
    Assert-Lacks $r 'no install record in this checkout' '11: it is not misread as "no record"'
    Assert-Lacks $r 'enabled declaratively only' '11: nor as "declared only"'

    $c = New-Case 'sep-trail'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath ($c.Repo + '\') -Version '4.32.0' -Sha $head) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '11b: exit 0'
    Assert-Has  $r 'up to date -- your install is at the clone''s HEAD' '11b: a trailing-separator projectPath still matches'

    # --- 12. Reachable in the clone, NOT an ancestor of HEAD -- version strings say clone IS ahead ----
    # existsInClone = $true, isAncestor = $false. Before the pre-PR repair the script concluded
    # unconditionally here "your install is AHEAD -- the clone is stale" (a marketplace-refresh
    # verdict); it now consults Compare-Version first, exactly like its -not $existsInClone sibling
    # branch. This scenario pins the direction where that consultation matters: the clone's version
    # really is newer, so the correct verdict points at the PER-PLUGIN update, not a refresh.
    Write-Host "12. reachable-not-ancestor (history rewrite), version says clone IS ahead -> per-plugin update" -ForegroundColor Cyan
    $c = New-Case 'diverged-clone-ahead'
    $orphanSha = New-DivergedClone -Dir $c.Clone -Version '4.33.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $orphanSha) ) }
    $verify = Get-CloneGitExitCode -Dir $c.Clone -GitArgs @('rev-parse', '-q', '--verify', "$orphanSha^{commit}")
    $isAnc = Get-CloneGitExitCode -Dir $c.Clone -GitArgs @('merge-base', '--is-ancestor', $orphanSha, 'HEAD')
    Assert-Equal 0 $verify '12: fixture sanity -- the orphaned commit is still a resolvable object in the clone'
    Assert-True ($isAnc -ne 0) '12: fixture sanity -- and it is NOT an ancestor of the clone''s (rewritten) HEAD'
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '12: exit 0'
    Assert-Has  $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '12: verdict says the clone is genuinely ahead, by version'
    Assert-Has  $r 'history rewrite?' '12: verdict names the mechanism (a rewrite in the clone''s history)'
    Assert-Has  $r $UPD '12: the action is the PER-PLUGIN update command, not a marketplace refresh'
    Assert-Lacks $r $MKT '12: a marketplace refresh is NOT advised here'
    Assert-Has  $r '1 of 1 plugin(s) behind' '12: the summary counts it as behind'

    # --- 13. Same reachable-not-ancestor shape, but the versions do NOT say the clone is ahead -------
    # Same existsInClone/isAncestor shape as 12, opposite version relationship: here the stale-clone
    # verdict (marketplace refresh) is the CORRECT one, and must stay that way.
    Write-Host "13. reachable-not-ancestor (history rewrite), version does NOT say clone is ahead -> stale clone, refresh" -ForegroundColor Cyan
    $c = New-Case 'diverged-clone-stale'
    $orphanSha = New-DivergedClone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $orphanSha) ) }
    $verify = Get-CloneGitExitCode -Dir $c.Clone -GitArgs @('rev-parse', '-q', '--verify', "$orphanSha^{commit}")
    $isAnc = Get-CloneGitExitCode -Dir $c.Clone -GitArgs @('merge-base', '--is-ancestor', $orphanSha, 'HEAD')
    Assert-Equal 0 $verify '13: fixture sanity -- the orphaned commit is still a resolvable object in the clone'
    Assert-True ($isAnc -ne 0) '13: fixture sanity -- and it is NOT an ancestor of the clone''s (rewritten) HEAD'
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '13: exit 0'
    Assert-Has  $r 'your install is AHEAD of the clone -- the clone is stale' '13: verdict says the clone is stale (equal version strings do not overrule it)'
    Assert-Has  $r $MKT '13: the action is the marketplace-refresh command'
    Assert-Lacks $r $UPD '13: a per-plugin update is NOT advised here'
    Assert-Has  $r '1 of 1 plugin(s) behind' '13: the summary counts it as behind'

    # --- 14. A malformed gitCommitSha in the install record degrades to the version comparison --------
    # Get-ValidatedSha rejects anything that is not 7-40 hex characters. A record carrying something
    # else (corruption, a future format change) must fall through to the version-only comparison
    # exactly like "no sha recorded at all" (scenario 3) -- never be handed to git.
    Write-Host "14. malformed gitCommitSha -> degrades to version comparison, never reaches git" -ForegroundColor Cyan
    $c = New-Case 'malformed-sha'
    New-Clone -Dir $c.Clone -Version '4.33.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'not-a-valid-sha!!') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '14: exit 0 -- a malformed sha does not crash the script'
    Assert-Has  $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '14: verdict is the same as the no-sha version-comparison case (scenario 3)'
    Assert-Has  $r $UPD '14: the action is the per-plugin update command'
    Assert-Lacks $r 'not-a-valid-sha' '14: the malformed sha itself is never echoed back'
    Assert-Lacks $r 'Exception' '14: no unhandled exception text leaked'
    # --- 15. Asymmetric gap (a): version but no sha on the install side, HEAD but no readable ---------
    # -- plugin.json version on the clone side. NEITHER side is fully empty, so the pre-fix per-SIDE
    # test ("-not $instSha -and -not $instVer" / "-not $clone.Head -and -not $cloneVer") never fires on
    # either line, and the catch-all verdict used to print a bare "cannot determine -- " with the
    # reason missing -- the Code and the summary tally stayed right throughout, which is why nothing
    # else surfaced it. This is the exact defect Victor found on pickup of that branch; the fix names
    # the missing fields per FIELD instead of per side.
    Write-Host "15. asymmetric gap (a): version/no-sha vs HEAD/no-version -> reason is named, not blank" -ForegroundColor Cyan
    $c = New-Case 'gap-a'
    New-Clone -Dir $c.Clone -Version '' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '15: exit 0'
    Assert-True (-not ($r.Text -match 'cannot determine --[ \t]*\r?\n')) '15: the regression itself -- the verdict is never a bare "cannot determine --" with the reason missing'
    Assert-Has  $r 'no commit sha in the install record' '15: names the missing sha on the install side'
    Assert-Has  $r "no version in the clone's plugin.json" '15: names the missing version on the clone side'
    Assert-Has  $r '-- 1 could not be determined' '15: still counted as indeterminate in the summary tally'

    # --- 16. Asymmetric gap (b): the symmetric flip -- sha but no version on the install side, ---------
    # -- version but no HEAD/.gcs-sha on the clone side (a non-git fetch missing its sha file). Same
    # defect, opposite side: a per-side test that only ever fires on one side's both-empty state leaves
    # this state silent too.
    Write-Host "16. asymmetric gap (b): sha/no-version vs version/no-HEAD -> reason is named, not blank" -ForegroundColor Cyan
    $c = New-Case 'gap-b'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '' -Sha 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '16: exit 0'
    Assert-True (-not ($r.Text -match 'cannot determine --[ \t]*\r?\n')) '16: the regression itself -- the verdict is never a bare "cannot determine --" with the reason missing'
    Assert-Has  $r 'no version in the install record' '16: names the missing version on the install side'
    Assert-Has  $r 'no HEAD or sha on the clone side' '16: names the missing HEAD/sha on the clone side'
    Assert-Has  $r '-- 1 could not be determined' '16: still counted as indeterminate in the summary tally'

    # --- 17. -Brief: a 'behind' verdict -> "[ERROR] <id>: <verdict> -- <action>" ---------------------
    Write-Host "17. -Brief: 'behind' -> [ERROR] with the action appended" -ForegroundColor Cyan
    $c = New-Case 'brief-behind'
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0'
    Add-CloneCommit -Dir $c.Clone -Version '4.33.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '17: exit 0'
    Assert-Equal (
        "[ERROR] ${ID}: the clone is AHEAD of your install (4.32.0 -> 4.33.0) -- $UPD`n" +
        "[SUMMARY] 1 plugin(s) enabled here: 1 behind, 0 up to date."
    ) $r.Text.Trim() '17: the whole run is the marker line plus the summary, verbatim'

    # --- 17b. -Brief: 'unreleased' -> [INFO], NEVER [ERROR] and never a command ----------------------
    # THE SESSION-START HALF OF #1772. connector-sessioncheck forwards these lines into a session's
    # context at every start; before the split this shape was an [ERROR] carrying a no-op command, in
    # the most ordinary state a checkout can be in -- sitting between two releases. If it is ever
    # promoted back to [ERROR], this is the assert that must fail.
    Write-Host "17b. -Brief: 'unreleased' -> [INFO], never [ERROR] (#1772)" -ForegroundColor Cyan
    $c = New-Case 'brief-unreleased'
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0'
    Add-CloneCommit -Dir $c.Clone | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '17b: exit 0'
    Assert-Has   $r "[INFO] $($ID): your install is on the released version 4.32.0" '17b: reported as [INFO]'
    Assert-Lacks $r '[ERROR]' '17b: never promoted to [ERROR] -- the #1772 regression guard'
    Assert-Lacks $r $UPD '17b: and the no-op update command never reaches a session start'
    Assert-Has   $r '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 on the released version with unreleased clone commits, 0 up to date.' '17b: the summary gives it its own bucket'

    # --- 18. -Brief: a 'clone-behind' verdict (stale clone) -> "[INFO]", NEVER "[ERROR]" -------------
    # THE REGRESSION #1591 NAMES EXPLICITLY: a stale clone is not an error. If this code is ever
    # promoted to [ERROR], this assert is the one that must fail.
    Write-Host "18. -Brief: 'clone-behind' -> [INFO], never [ERROR]" -ForegroundColor Cyan
    $c = New-Case 'brief-clonebehind'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @(
        (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '18: exit 0'
    Assert-Has   $r "[INFO] $($ID): your install (deadbeefdead) is not in the clone's history" '18: reported as [INFO]'
    Assert-Lacks $r '[ERROR]' '18: never promoted to [ERROR] -- the #1591 regression guard'
    Assert-Has   $r '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 ahead of a stale clone, 0 up to date.' '18: the summary counts it as a stale clone, not as behind'

    # --- 19. -Brief: an 'indeterminate' verdict (foreign plugin) -> "[INFO]", NEVER "[ERROR]" --------
    Write-Host "19. -Brief: 'indeterminate' (foreign plugin) -> [INFO], never [ERROR]" -ForegroundColor Cyan
    $c = New-Case 'brief-indeterminate'
    New-Clone -Dir $c.Clone -Version '4.32.0' -PluginNames @('dkj-subagents-alpha') | Out-Null
    $foreign = 'foreign-thing@ccs-fixture'
    Set-Enabled -RepoDir $c.Repo -Ids @($foreign)
    Write-Admin -Path $c.Admin -Plugins @{ $foreign = @( (New-Rec -ProjectPath $c.Repo -Version '9.9.9' -Sha 'beefbeef') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '19: exit 0'
    Assert-Has   $r "[INFO] $($foreign): cannot determine -- 'foreign-thing' is not in the clone's marketplace.json" '19: reported as [INFO]'
    Assert-Lacks $r '[ERROR]' '19: never promoted to [ERROR]'
    Assert-Has   $r '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 undetermined, 0 up to date.' '19: the summary counts it as undetermined'

    # --- 17. -Brief: 'match' / 'ver-match' -> nothing printed for that plugin ------------------------
    # With one plugin enabled, "nothing printed for that plugin" means the ENTIRE run is the
    # [SUMMARY] line -- the strongest form of "emits nothing" this suite can pin.
    Write-Host "20a. -Brief: 'match' -> the whole run is just the [SUMMARY] line" -ForegroundColor Cyan
    $c = New-Case 'brief-match'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $head) ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '20a: exit 0'
    Assert-Equal '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 up to date.' $r.Text.Trim() '20a: match emits nothing but the summary'

    Write-Host "20b. -Brief: 'ver-match' -> the whole run is just the [SUMMARY] line, identically" -ForegroundColor Cyan
    $c = New-Case 'brief-vermatch'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '20b: exit 0'
    Assert-Equal '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 up to date.' $r.Text.Trim() '20b: ver-match emits nothing but the summary -- indistinguishable from match, by contract'

    # --- 21. -Brief: no plugins enabled -> a single [INFO] line, no [SUMMARY], exit 0 -----------------
    Write-Host "21. -Brief: no plugins enabled -> one [INFO] line, no [SUMMARY]" -ForegroundColor Cyan
    $c = New-Case 'brief-none-enabled'
    Set-Enabled -RepoDir $c.Repo -Ids @()
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '21: exit 0'
    Assert-Equal '[INFO] no plugins are enabled for this checkout -- nothing to compare.' $r.Text.Trim() '21: exactly one INFO line and nothing else -- no [SUMMARY] when there is nothing to summarize'

    # --- 22. -Brief: one run mixing every code -> exactly one [SUMMARY] line partitioning all rows ---
    # SEVEN codes now, not six (#1802): 'plug-notinstalled' is enabled, its name IS in the clone's
    # marketplace.json (so it does not fall into the foreign/indeterminate branch), and it carries NO
    # install record at all -- the exact shape that produces 'not-installed', the second [ERROR] verdict.
    Write-Host "22. -Brief: a mix of every code -> one [SUMMARY] line, correctly partitioned" -ForegroundColor Cyan
    $c = New-Case 'brief-mixed'
    $mixNames = @('plug-behind', 'plug-clonebehind', 'plug-match', 'plug-vermatch', 'plug-unreleased', 'plug-notinstalled')
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0' -PluginNames $mixNames
    # ONLY plug-behind's version is bumped by the second commit, and that is what separates it from
    # plug-unreleased: both records sit at $shaA, so the ancestry is identical and the version strings
    # are the whole difference. plug-match is unaffected either way (its sha equality short-circuits
    # first) and plug-vermatch MUST keep 4.32.0 on the clone side, which is why the bump is scoped.
    $shaB = Add-CloneCommit -Dir $c.Clone -Version '4.33.0' -PluginNames @('plug-behind')
    $foreignMix = 'plug-foreign@ccs-fixture'
    $ids = @('plug-behind@ccs-fixture', 'plug-clonebehind@ccs-fixture', $foreignMix, 'plug-match@ccs-fixture', 'plug-vermatch@ccs-fixture', 'plug-unreleased@ccs-fixture', 'plug-notinstalled@ccs-fixture')
    Set-Enabled -RepoDir $c.Repo -Ids $ids
    Write-Admin -Path $c.Admin -Plugins @{
        'plug-behind@ccs-fixture'      = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) )
        'plug-clonebehind@ccs-fixture' = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') )
        $foreignMix                    = @( (New-Rec -ProjectPath $c.Repo -Version '9.9.9' -Sha 'beefbeef') )
        'plug-match@ccs-fixture'       = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaB) )
        'plug-vermatch@ccs-fixture'    = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') )
        'plug-unreleased@ccs-fixture'  = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) )
        # plug-notinstalled@ccs-fixture: DELIBERATELY no key at all -- enabled, in the clone's
        # marketplace.json, and with no record of any shape (not even a path-less one).
    }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '22: exit 0'
    $lines = @($r.Text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
    $errLines = @($lines | Where-Object { $_ -match '^\[ERROR\]' })
    $infoLines = @($lines | Where-Object { $_ -match '^\[INFO\]' })
    $summaryLines = @($lines | Where-Object { $_ -match '^\[SUMMARY\]' })
    Assert-Equal 2 $errLines.Count '22: exactly two [ERROR] lines (the behind plugin AND the not-installed one, #1802)'
    Assert-True  (($errLines -join '|') -like "*plug-behind@ccs-fixture*") '22: one [ERROR] line names the behind plugin'
    Assert-True  (($errLines -join '|') -like "*plug-notinstalled@ccs-fixture*") '22: the other [ERROR] line names the not-installed plugin'
    Assert-Equal 3 $infoLines.Count '22: exactly three [INFO] lines (the stale clone, the foreign plugin, the unreleased one)'
    Assert-True  (($infoLines -join '|') -like '*plug-clonebehind@ccs-fixture*') '22: one [INFO] line is the stale-clone plugin'
    Assert-True  (($infoLines -join '|') -like '*plug-foreign@ccs-fixture*') '22: another [INFO] line is the foreign plugin'
    Assert-True  (($infoLines -join '|') -like '*plug-unreleased@ccs-fixture*') '22: and the third is the unreleased one, NOT an [ERROR]'
    Assert-Equal 1 $summaryLines.Count '22: exactly one [SUMMARY] line for the whole run'
    Assert-Equal '[SUMMARY] 7 plugin(s) enabled here: 1 behind, 1 enabled but not installed here, 1 ahead of a stale clone, 1 on the released version with unreleased clone commits, 1 undetermined, 2 up to date.' $summaryLines[0] '22: the summary partitions all seven rows correctly, with its own disjoint part for not-installed'
    Assert-Lacks $r 'plug-match@ccs-fixture:'    '22: the match plugin gets no marker line of its own'
    Assert-Lacks $r 'plug-vermatch@ccs-fixture:' '22: the ver-match plugin gets no marker line of its own'

    # --- 23. -Brief suppresses the header; the default view keeps it, unaffected --------------------
    Write-Host "23. -Brief has no header; the default (no -Brief) view is unchanged" -ForegroundColor Cyan
    $c = New-Case 'brief-header'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $head) ) }
    $rDefault = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    $rBrief   = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $rDefault.Code '23: default view exit 0'
    Assert-Equal 0 $rBrief.Code   '23: brief view exit 0'
    Assert-Has   $rDefault "plugin-versions -- $($c.Repo)" '23: the default view still prints its header (unchanged)'
    Assert-Lacks $rDefault '[SUMMARY]' '23: the default view never emits the brief marker vocabulary'
    Assert-Lacks $rBrief   'plugin-versions--'  '23: -Brief never prints the header line (an absolute path stays out of a session start)'
    Assert-Has   $rBrief   '[SUMMARY]' '23: -Brief still emits its own summary'

    # --- 24. -Brief: enabled here with NO install record at all -> the SECOND [ERROR] verdict (#1802) --
    # 'not-installed' now carries its own row code rather than sharing 'indeterminate'. Before this
    # split this exact state -- a plugin enabled here, loading NOTHING in this checkout right now --
    # was reported at [INFO], the same quiet marker a stale clone or an unreleased-clone-commits row
    # get. It is promoted here because, unlike those two, it names one command that repairs it, here
    # and now -- exactly the #1591 rule that decided the FIRST [ERROR] verdict.
    Write-Host "24. -Brief: enabled here with NO install record at all -> [ERROR] (#1802)" -ForegroundColor Cyan
    $c = New-Case 'brief-not-installed'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{}
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '24: exit 0 -- a report, not a gate'
    Assert-Equal (
        "[ERROR] ${ID}: cannot determine -- not installed in this checkout (enabled declaratively only) -- install here: claude plugin install $ID --scope project`n" +
        "[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 enabled but not installed here, 0 up to date."
    ) $r.Text.Trim() '24: exactly one [ERROR] naming the plugin, and the summary carries its own disjoint part'

    # --- 25. -Brief: only a path-less (machine-wide) record exists -- deliberately STAYS 'indeterminate'
    # / [INFO], narrower than the #1802 split. The record here carries no 'projectPath' at all, which is
    # the shape Get-InstallRecord files under PathlessById rather than RecordsById.
    Write-Host "25. -Brief: only a path-less (machine-wide) record -> still [INFO], still undetermined" -ForegroundColor Cyan
    $c = New-Case 'brief-pathless'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( @{ scope = 'user'; version = '4.32.0' } ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '25: exit 0'
    Assert-Has   $r "[INFO] $($ID): cannot determine for this checkout -- only a path-less (machine-wide) record exists" '25: still reported as [INFO], not promoted to [ERROR]'
    Assert-Lacks $r '[ERROR]' '25: never promoted to [ERROR] -- narrower than the #1802 split on purpose'
    Assert-Has   $r '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 undetermined, 0 up to date.' '25: counted as undetermined, not split into its own bucket'

    # --- 26. Fix 1 (Victor): an UNREADABLE install administration -> stays 'indeterminate' / [INFO], --
    # -- NEVER the confident 'not installed' diagnosis. Get-InstallRecord's empty RecordsById used to
    # collapse "genuinely no record for this checkout" and "the file exists but will not parse" into
    # the same branch, so a corrupt installed_plugins.json produced 'cannot determine -- not installed
    # in this checkout (enabled declaratively only)' with an install command as its remedy -- a
    # confident wrong diagnosis that this branch's own #1802 split would have promoted to [ERROR].
    # There is now a branch ahead of it, gated on (-not $install.Readable -and $install.Exists), that
    # keeps the row's code 'indeterminate', names the unreadable file, and points at
    # check-claude-home.ps1 rather than an install command.
    Write-Host "26. unreadable install administration -> stays indeterminate/[INFO], never 'not-installed'" -ForegroundColor Cyan
    $c = New-Case 'admin-unreadable'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-BadAdmin -Path $c.Admin
    $rDefault = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $rDefault.Code '26: exit 0 -- a report, not a gate'
    Assert-Has   $rDefault 'install administration could not be read' '26: the installed-here line names the unreadable file'
    Assert-Has   $rDefault 'the install administration exists but could not be read' '26: the verdict names it too -- the two lines no longer contradict each other'
    Assert-Has   $rDefault 'check-claude-home.ps1' '26: the action points at the tool that owns that file''s health'
    Assert-Lacks $rDefault 'claude plugin install' '26: no install command is offered -- the fault is the file, not a missing install'
    Assert-Lacks $rDefault 'not installed in this checkout (enabled declaratively only)' '26: never the old, confident wrong diagnosis'

    $rBrief = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $rBrief.Code '26b: exit 0'
    Assert-Has   $rBrief '[INFO]' '26b: reported at [INFO]'
    Assert-Lacks $rBrief '[ERROR]' '26b: never promoted to [ERROR] -- an unreadable administration is not a confirmed absence'
    Assert-Lacks $rBrief 'claude plugin install' '26b: still no install command in brief mode'
    Assert-Has   $rBrief '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 undetermined, 0 up to date.' '26b: counted as undetermined, NOT split into "enabled but not installed here"'

    # --- 27. Fix 1's own boundary: NO install administration on the machine AT ALL -> still ------------
    # -- 'not-installed', which IS an accurate diagnosis here and must not be swept up by the new
    # branch. -not $install.Readable is true in this shape too (nothing parsed, because nothing exists
    # to parse) but $install.Exists is false, so the gate '-not $install.Readable -and $install.Exists'
    # does not fire and the row still reaches the ordinary 'not-installed' branch -- correctly, since
    # nothing is installed anywhere on this machine.
    Write-Host "27. no install administration at all -> still 'not-installed' (an accurate diagnosis)" -ForegroundColor Cyan
    $c = New-Case 'admin-missing'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    # Deliberately no Write-Admin / Write-BadAdmin call at all -- installed_plugins.json never created.
    Assert-True (-not (Test-Path -LiteralPath $c.Admin)) '27: fixture sanity -- the administration file does not exist'
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '27: exit 0'
    Assert-Equal (
        "[ERROR] ${ID}: cannot determine -- not installed in this checkout (enabled declaratively only) -- install here: claude plugin install $ID --scope project`n" +
        "[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 enabled but not installed here, 0 up to date."
    ) $r.Text.Trim() '27: identical shape to scenario 24 -- a missing administration file is diagnosed the same as an empty-but-readable one, correctly'

    # --- 28. Fix 2 (Sebastian): an id whose NAME half is not a valid slug -> the paste-ready install ---
    # -- command is WITHHELD, not the verdict. $idIsCommandSafe = Test-PluginNameSlug(name) -and
    # Test-PluginMarketplaceSlug(mp); a shell metacharacter in the name half fails the first half of
    # that AND. A second, WELL-FORMED id rides in the SAME run to prove the guard is per-row: it must
    # still get its own install command.
    Write-Host "28. Fix 2: id NAME half not a valid slug -> install command withheld, row still reported" -ForegroundColor Cyan
    $c = New-Case 'badslug-name'
    $badName = 'plug;bad'
    $badId = "$badName@ccs-fixture"
    New-Clone -Dir $c.Clone -Version '4.32.0' -PluginNames @($badName, 'dkj-subagents-alpha') -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($badId, $ID)
    Write-Admin -Path $c.Admin -Plugins @{}
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '28: exit 0'
    Assert-Has   $r 'plugbad@ccs-fixture' '28: fixture sanity -- the sanitized display of the bad id is present (row not suppressed)'
    Assert-LacksBetween $r 'plugbad@ccs-fixture' '[SUMMARY]' 'claude plugin install' '28: no paste-ready install command is built out of the unsafe id, scoped to that row'
    Assert-HasBetween   $r 'plugbad@ccs-fixture' '[SUMMARY]' "no paste-ready command -- the 'enabledPlugins' key is not a valid plugin id (bad slug)" '28: the withhold sentence is printed instead, scoped to that row (#1803 unified wording)'
    Assert-Has  $r "claude plugin install $ID --scope project" '28: a normal well-formed id in the SAME run still gets its install command -- the guard is per-row, not global'
    Assert-Has  $r '[SUMMARY] 2 plugin(s) enabled here: 0 behind, 2 enabled but not installed here, 0 up to date.' '28: both rows still counted in the "enabled but not installed here" bucket -- withholding the command does not suppress the finding'

    # --- 29. Fix 2: an id whose MARKETPLACE half is not a valid slug -> the same withhold, because -----
    # -- both halves are checked. The name half here ('plug-ok') is an ordinary slug; only the
    # marketplace half fails Test-PluginMarketplaceSlug.
    Write-Host "29. Fix 2: id MARKETPLACE half not a valid slug -> install command withheld too" -ForegroundColor Cyan
    $c = New-Case 'badslug-marketplace'
    $badMp = 'ccs`fixture'
    $cloneDir = Join-Path $c.Home (Join-Path '.claude' (Join-Path 'plugins' (Join-Path 'marketplaces' $badMp)))
    New-Clone -Dir $cloneDir -Version '4.32.0' -PluginNames @('plug-ok') -NoGit | Out-Null
    $badId2 = "plug-ok@$badMp"
    Set-Enabled -RepoDir $c.Repo -Ids @($badId2)
    Write-Admin -Path $c.Admin -Plugins @{}
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '29: exit 0'
    Assert-Lacks $r 'claude plugin install' '29: no paste-ready install command is built out of the unsafe marketplace half'
    Assert-Has  $r "no paste-ready command -- the 'enabledPlugins' key is not a valid plugin id (bad slug)" '29: the withhold sentence is printed (#1803 unified wording)'
    Assert-Has  $r 'plug-ok@ccsfixture' '29: the row is still reported (sanitized display), not suppressed'
    Assert-Has  $r '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 enabled but not installed here, 0 up to date.' '29: still counted in the "enabled but not installed here" bucket'

    # --- 30. #1803: the withhold is not only the INSTALL command. A bad-slug id that reaches a --------
    # -- 'behind' verdict has its `claude plugin update` command withheld too -- #1591 gated only the
    # one `install` line it made reachable; #1803 built every $action string from $idTok / $mpTok, so
    # a metacharacter in the id can no longer survive into ANY paste-ready line, in either mode.
    Write-Host "30. #1803: a bad-slug id at a 'behind' verdict -> the UPDATE command is withheld too (-Brief)" -ForegroundColor Cyan
    $c = New-Case 'badslug-behind-brief'
    $evilName = 'plug;evil'
    $evilId = "$evilName@ccs-fixture"
    New-Clone -Dir $c.Clone -Version '4.33.0' -PluginNames @($evilName) -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($evilId)
    Write-Admin -Path $c.Admin -Plugins @{ $evilId = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home -Brief
    Assert-Equal 0 $r.Code '30: exit 0'
    Assert-Has   $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '30: fixture sanity -- the row really is a "behind" verdict'
    Assert-Lacks $r 'claude plugin update' '30: no paste-ready update command is built out of the unsafe id -- the withhold now covers this site too'
    Assert-Lacks $r 'plug;evil'            '30: and the raw metacharacter id never reaches the line'
    Assert-Has   $r "no paste-ready command -- the 'enabledPlugins' key is not a valid plugin id (bad slug)" '30: the withhold sentence stands in for the update command'
    Assert-Has   $r '[ERROR] plugevil@ccs-fixture' '30: the row is still an [ERROR] and still names the (sanitized) plugin'

    # --- 31. #1803: the default view is held to the same rule as -Brief. Same bad-slug id, no -Brief:
    # -- the update command is withheld AND the id header / verdict / action are sanitized at emission
    # (display axis), exactly as the -Brief block has always done. Decision (2) of the issue.
    Write-Host "31. #1803: default view -> command withheld AND every emitted field sanitized" -ForegroundColor Cyan
    $c = New-Case 'badslug-behind-default'
    New-Clone -Dir $c.Clone -Version '4.33.0' -PluginNames @($evilName) -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($evilId)
    Write-Admin -Path $c.Admin -Plugins @{ $evilId = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '31: exit 0'
    Assert-Lacks $r 'claude plugin update' '31: the update command is withheld in the default view too'
    Assert-Lacks $r 'plug;evil'            '31: the raw metacharacter id never appears -- the id header is Format-SuspectToken-sanitized'
    Assert-Has   $r 'plugevil@ccs-fixture' '31: the sanitized id is what heads the block'
    Assert-Has   $r 'shown sanitized'      '31: and the reader is told the id was altered (Format-SuspectToken note)'
    Assert-Has   $r "no paste-ready command -- the 'enabledPlugins' key is not a valid plugin id (bad slug)" '31: the withhold sentence stands in for the command in the default view'

    # --- 32. #1986: the update command carries the scope the record actually states --------------
    # -- Every `claude plugin update` line on this page was the literal `--scope project` until
    # -- #1986, and the CLI REFUSES a scope a plugin is not installed at. A 'local' record is not an
    # -- edge case: a session start writes one, flipping a correct 'project' record, with no command
    # -- run (inbound #314) -- so this page was handing a reader a command that cannot work and
    # -- calling it the repair. The pairing with scenario 30/31 is deliberate: same fixture shape,
    # -- different axis (that one is the id, this one is the scope).
    Write-Host "32. #1986: a 'behind' row prescribes the scope the install record states" -ForegroundColor Cyan
    $c = New-Case 'scope-local'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Scope 'local') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '32: exit 0'
    Assert-Has   $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '32: fixture sanity -- the row really is a "behind" verdict'
    Assert-Has   $r 'claude plugin update dkj-subagents-alpha@ccs-fixture --scope local' '32: the prescription carries the record''s own scope'
    Assert-Lacks $r $UPD '32: and NOT the hardcoded --scope project, which the CLI would refuse'

    # -- THE CARVE-OUT, PINNED: `claude plugin install` is deliberately NOT built from the resolved
    # -- scope. A path-less (machine-wide) record is the shape #1986 was measured on, and the row it
    # -- reaches prescribes installing INTO THIS CHECKOUT -- which is what 'project' means and what
    # -- the reader is being told to do. It is not asking where the plugin already lives, so reading
    # -- the scope off the record there would replace the instruction with a no-op.
    Write-Host "32b. #1986: the INSTALL prescription is deliberately still --scope project" -ForegroundColor Cyan
    $c = New-Case 'scope-pathless'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( @{ scope = 'user'; version = '4.32.0' } ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '32b: exit 0'
    Assert-Has   $r 'a user-scope record not tied to a path exists' '32b: fixture sanity -- the row really is the path-less shape'
    Assert-Has   $r 'install here: claude plugin install dkj-subagents-alpha@ccs-fixture --scope project' '32b: the install command keeps project scope -- it means "into this checkout"'

    # --- 33. #1987: an UNPARSEABLE clone manifest no longer prescribes a refresh -----------------
    # -- Two ways of not answering shared one command: the plugin absent from a manifest that PARSED
    # -- (scenario 9 -- a refresh is right, the clone is merely behind) and the manifest not being
    # -- readable at all. For the second the refresh can be advice that provably cannot work, and it
    # -- is now split: the manifest's own path is named, and the refresh is offered only as
    # -- conditional on the file actually being damaged.
    Write-Host "33. #1987: a clone manifest that will not parse names the FILE, not a bare refresh" -ForegroundColor Cyan
    $c = New-Case 'clone-unparseable'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $c.Clone '.claude-plugin\marketplace.json'), '{ "name": "ccs-fixture", "plugins": [ this is not json', $Utf8)
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '33: exit 0'
    Assert-Has   $r "cannot determine -- the clone's marketplace.json could not be read" '33: the verdict is unchanged -- this half was never wrong'
    Assert-Has   $r 'marketplace.json' '33: the action names the manifest the reader has to look at'
    Assert-Has   $r "a refresh only helps if the clone's copy is damaged" '33: the refresh is conditional now, not the prescription'
    Assert-Lacks $r 'refresh the clone and re-run' '33: and the unconditional staleness command is gone from this branch'

    # -- The other half of the split is scenario 9 and stays there: a manifest that PARSES and simply
    # -- lacks the plugin still gets the unconditional refresh, which is the reasoning this branch
    # -- inherited and kept.

    # --- 34. #1987: the measured case, where the refresh provably cannot help --------------------
    # -- Windows PowerShell 5.1's ConvertFrom-Json folds object keys case-insensitively, and the
    # -- official marketplace manifest legitimately carries both '.c' and '.C' (an lspServers
    # -- extension map). The file is VALID JSON; no number of refreshes changes what 5.1 can
    # -- represent -- measured September 14, 2026, where the refresh had already run and succeeded
    # -- seconds earlier in step 1 of the same update-plugins run. So this shape rules the refresh
    # -- OUT by name instead of leaving it as a thing to try.
    Write-Host "34. #1987: case-colliding keys -- the refresh is ruled out by name" -ForegroundColor Cyan
    $c = New-Case 'clone-dupkeys'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $c.Clone '.claude-plugin\marketplace.json'),
        '{ "name": "ccs-fixture", "plugins": [], "lspServers": { "extensionToLanguage": { ".c": "c", ".C": "cpp" } } }', $Utf8)
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '34: exit 0'
    Assert-Has   $r 'duplicated keys' '34: fixture sanity -- 5.1 really does refuse this valid JSON, and the reason is printed'
    Assert-Has   $r 'NOT a stale clone, so a refresh cannot help' '34: the advice that cannot work is ruled out rather than prescribed'
    Assert-Has   $r 'folds JSON keys case-insensitively' '34: and the reader is told whose fault it is, so they stop re-running the refresh'
    Assert-Lacks $r 'refresh the clone and re-run' '34: the staleness command does not appear for this shape'

    # --- 34b. #1987's new action is held to the withhold doctrine too (Sebastian, on this branch) ----
    # -- Scenarios 28-31 each pair one withhold branch with a deliberately unsafe slug, and the parse-
    # -- failure action was the one new branch without such a pairing. It names a FILESYSTEM PATH built
    # -- from the raw marketplace segment -- an 'enabledPlugins' key, i.e. an arbitrary string from a
    # -- settings file -- so the placeholder has to reach the redaction step, and a future edit to how
    # -- that path is composed must not be able to reopen it undetected. A path is not a command; it is
    # -- still a line printed for a person to act on.
    Write-Host "34b. #1987: the parse-failure action withholds the manifest path for an unsafe marketplace" -ForegroundColor Cyan
    $c = New-Case 'clone-unparseable-badmkt'
    $evilMkt = 'ccs;evil'
    $evilMktId = "dkj-subagents-alpha@$evilMkt"
    $evilClone = Join-Path $c.Home ".claude\plugins\marketplaces\$evilMkt"
    New-Clone -Dir $evilClone -Version '4.33.0' -NoGit | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $evilClone '.claude-plugin\marketplace.json'), '{ "name": "x", "plugins": [ not json', $Utf8)
    Set-Enabled -RepoDir $c.Repo -Ids @($evilMktId)
    Write-Admin -Path $c.Admin -Plugins @{ $evilMktId = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '34b: exit 0'
    Assert-Has   $r "cannot determine -- the clone's marketplace.json could not be read" '34b: fixture sanity -- the row really is the parse-failure branch'
    # SCOPED TO THE ACTION, AND THE SCOPING IS THE POINT. An unscoped Assert-Lacks over the whole run
    # fails here, correctly and for an unrelated reason: the per-clone FOOTER prints the clone's
    # directory through Format-SafePathToken, which deliberately keeps every character that makes a
    # path a path (inbound #414 -- a reader told which path is missing must be able to look it up), and
    # that line is DarkGray context rather than anything shaped for pasting. The withhold doctrine is
    # about the paste-ready command, so that is what this scenario bounds itself to.
    Assert-LacksBetween $r 'verdict' 'NO-SUCH-MARKER' 'ccs;evil' '34b: the raw metacharacter marketplace never reaches the action, not even inside a path'
    Assert-LacksBetween $r 'verdict' 'NO-SUCH-MARKER' 'marketplaces' '34b: and no filesystem path is built into the action for this row'
    Assert-Has   $r "no paste-ready command -- the 'enabledPlugins' key is not a valid plugin id (bad slug)" '34b: the withhold sentence stands in for it, exactly as at every other site'

    # --- 35. #1986 (Victor, on this branch): a scope the CLI does not accept is SAID, not swallowed --
    # -- The fallback is 'project', which is the same string a confirmed project record produces -- so
    # -- in the printed command the two are indistinguishable. This is the one row where that can hide:
    # -- every `claude plugin update` line is reached only with exactly ONE record for this checkout.
    # -- Without the note, the installed-here line printed the invalid scope raw, right beside an
    # -- unexplained '--scope project', with nothing connecting the two.
    Write-Host "35. #1986: an unrecognised scope falls back to project AND says so on the row" -ForegroundColor Cyan
    $c = New-Case 'scope-bogus'
    New-Clone -Dir $c.Clone -Version '4.33.0' -NoGit | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @($ID)
    Write-Admin -Path $c.Admin -Plugins @{ $ID = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Scope 'bogus-value') ) }
    $r = Invoke-PV -Repo $c.Repo -UserHome $c.Home
    Assert-Equal 0 $r.Code '35: exit 0'
    Assert-Has   $r 'the clone is AHEAD of your install (4.32.0 -> 4.33.0)' '35: fixture sanity -- the row really is a "behind" verdict'
    Assert-Has   $r $UPD '35: the prescription falls back to project, which is the honest answer'
    Assert-Has   $r 'names a scope this CLI does not accept' '35: and the installed-here line says the printed scope is a fallback'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'plugin-versions.ps1'
if ($script:fail -gt 0) { exit 1 }
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
