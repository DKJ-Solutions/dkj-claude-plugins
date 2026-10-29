<#
.SYNOPSIS
    Regression tests for the fixture-pollution check (issue #1609): the check script
    scripts/lint/check-claude-home.ps1, the SessionStart hook claude-home-sessioncheck.ps1, and the
    AllRecords field the check reads from Get-InstallRecord.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/claude-home-gate.tests.ps1

    NOTHING HERE TOUCHES THE REAL ~/.claude, AND THAT IS NOT A COURTESY -- it is the defect under test.
    #1609 is a debug script that wrote fixture data into the real user tree because it never redirected
    the home; a suite for that check which read or wrote the real administration would be the same
    mistake, committed, running on every push and on every consumer's gate. So every case passes
    -HomeOverride into a fixture tree, and the two cases that assert on the SNAPSHOT are the only ones
    that let the check write at all -- every other case passes -NoSnapshot.

    -ScratchRootOverride IS PASSED EVERYWHERE, for a reason particular to this check. The fixture trees
    live under %TEMP%, which is exactly what the check calls scratch -- so without the override every
    record a fixture writes reads as polluted and the CLEAN case cannot be expressed at all. The
    override names a tree that does not exist, which is what makes a fixture path ordinary again. The
    machine's own resolution is therefore NOT exercised here, and that is a named test gap rather than
    an oversight: it reads $env:TEMP and a '\temp\' path segment, and a suite that asserted on them
    would be asserting about the machine it happens to run on. What IS pinned is the boundary logic
    those roots feed -- the prefix test below walks a sibling directory whose name merely begins the
    same way.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\lint\check-claude-home.ps1'
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\claude-home-sessioncheck.ps1'
$Mirror   = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lint\check-claude-home.ps1'
$Lib      = Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1'

# A scratch root that exists nowhere, so a fixture tree under %TEMP% reads as an ordinary path. Cases
# that want a POLLUTED record put one under this prefix deliberately.
$NoWhere  = 'C:\ccs-test-scratch-' + $PID

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("claudehome-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function New-Home {
    <# A fixture user home with a plugins directory, and optionally an administration file in it.
       -Records takes 'id=projectPath' pairs; a projectPath is written with forward slashes so the
       fixture never has to escape a backslash into JSON, which the check normalizes anyway. #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Records = @(),
        [switch]$NoAdminFile,
        [string]$RawAdmin = ''
    )
    $homeDir = New-Tree -Label $Label
    $plugins = Join-Path $homeDir '.claude\plugins'
    New-Item -ItemType Directory -Path $plugins -Force | Out-Null

    if ($NoAdminFile) { return $homeDir }

    $adminPath = Join-Path $plugins 'installed_plugins.json'
    if ($RawAdmin) {
        [System.IO.File]::WriteAllText($adminPath, $RawAdmin, (New-Object System.Text.UTF8Encoding($false)))
        return $homeDir
    }

    $parts = @()
    foreach ($r in $Records) {
        $i = $r.IndexOf('=')
        $id = $r.Substring(0, $i)
        $pp = $r.Substring($i + 1).Replace('\', '/')
        $parts += ('    "{0}": [ {{ "scope": "project", "projectPath": "{1}", "version": "4.32.0" }} ]' -f $id, $pp)
    }
    $json = "{`n  `"version`": 2,`n  `"plugins`": {`n" + ($parts -join ",`n") + "`n  }`n}`n"
    [System.IO.File]::WriteAllText($adminPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $homeDir
}

function Invoke-Check {
    param([string]$HomeOverride, [string]$ScratchRootOverride = '', [switch]$AllowSnapshot)
    $a = @('-HomeOverride', $HomeOverride, '-ScratchRootOverride', $(if ($ScratchRootOverride) { $ScratchRootOverride } else { $NoWhere }))
    if (-not $AllowSnapshot) { $a += '-NoSnapshot' }
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script @a 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Get-SnapshotPath { param([string]$HomeDir) return (Join-Path $HomeDir '.claude\plugins\installed_plugins.snapshot.json') }
function Get-AdminPath    { param([string]$HomeDir) return (Join-Path $HomeDir '.claude\plugins\installed_plugins.json') }

function New-StubCheck {
    <# A stand-in check script, so the hook's four output branches can be driven without a machine that
       actually has a polluted administration. It accepts -HomeOverride because that is the only
       argument the hook ever passes. #>
    param([string]$Dir, [string]$Name, [int]$ExitCode, [string]$Body)
    $p = Join-Path $Dir "$Name.ps1"
    $text = "param([string]`$HomeOverride = '')`nWrite-Host '$Body'`nexit $ExitCode`n"
    [System.IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding($false)))
    return $p
}

function Invoke-Hook {
    param([string]$CheckScriptOverride, [string]$HomeOverride = '')
    $a = @('-CheckScriptOverride', $CheckScriptOverride)
    if ($HomeOverride) { $a += @('-HomeOverride', $HomeOverride) }
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @a 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

try {
    Write-Host ''
    Write-Host '== Get-InstallRecord: the AllRecords field ==' -ForegroundColor Cyan

    # THE FIELD EXISTS BECAUSE EVERY OTHER ONE IS FILTERED. This is the assert that pins WHY the check
    # can see a fixture record at all: the record below is neither this repo's nor pathless, and its
    # path does not resolve -- so it is dropped by both filters and appears only in AllRecords.
    . $Lib
    $h = New-Home -Label 'lib' -Records @(
        "plug-behind@ccs-fixture=$NoWhere\dbg-1\repo",
        "dkj-policy@dkj-marketplace=$RepoRoot"
    )
    $rec = Get-InstallRecord -RepoRoot $RepoRoot -UserHomeOverride $h
    Assert-True ($rec.Readable -and @($rec.AllRecords).Count -eq 2) `
        'AllRecords holds every record in the file, whatever path it names'
    Assert-True (@($rec.Ids).Count -eq 1 -and $rec.Ids[0] -eq 'dkj-policy@dkj-marketplace') `
        'Ids stays filtered to this repo -- the new field did not widen the old ones'
    Assert-True (@($rec.AllRecords | Where-Object { $_.Id -eq 'plug-behind@ccs-fixture' }).Count -eq 1) `
        'a record whose projectPath does not resolve is in AllRecords -- the two filters would drop it'

    Write-Host ''
    Write-Host '== check-claude-home: the finding ==' -ForegroundColor Cyan

    $polluted = New-Home -Label 'polluted' -Records @(
        "plug-behind@ccs-fixture=$NoWhere\dbg-branch1-36616\repo",
        "dkj-policy@dkj-marketplace=$RepoRoot"
    )
    $r = Invoke-Check -HomeOverride $polluted
    Assert-True ($r.Code -eq 1 -and $r.Out -cmatch '\[ERROR\] a FIXTURE has written') `
        'a record under a scratch tree is an [ERROR], exit 1'
    Assert-True ($r.Out -match 'plug-behind@ccs-fixture') `
        'the refusal names the polluted record'
    Assert-True ($r.Out -notmatch 'dkj-policy@dkj-marketplace') `
        'and does NOT name the healthy record beside it'
    Assert-True ($r.Out -match '1 of 2 records names a scratch tree') `
        'it counts the polluted records against the total, and the verb agrees with the count'
    Assert-True ($r.Out -match 'there is NO snapshot to restore from') `
        'with no snapshot it says so, and falls back to re-installing per plugin per checkout'

    # The marketplace half: a polluted id names '<plugin>@<marketplace>', and the leftover clone is
    # reported only when that directory actually exists. Both directions, because a report that names
    # a directory nobody has is as wrong as one that misses the directory they do.
    $mkDir = Join-Path $polluted '.claude\plugins\marketplaces\ccs-fixture'
    $r = Invoke-Check -HomeOverride $polluted
    Assert-True ($r.Out -notmatch 'left a marketplace clone') `
        'no leftover clone reported while the marketplace directory does not exist'
    New-Item -ItemType Directory -Path $mkDir -Force | Out-Null
    $r = Invoke-Check -HomeOverride $polluted
    Assert-True ($r.Out -match 'left a marketplace clone' -and $r.Out -match 'ccs-fixture') `
        'the clone of the marketplace a polluted record names is reported once it is there'
    Assert-True ($r.Out -match '2\. delete the leftover clone') `
        'and deleting it is step 2 of the way back'

    # THE PLURAL VERB. Two polluted records rather than one, because the singular case above cannot
    # distinguish a correct agreement from a hard-coded 'names'.
    $twoBad = New-Home -Label 'twobad' -Records @(
        "plug-a@ccs-fixture=$NoWhere\dbg-a\repo",
        "plug-b@ccs-fixture=$NoWhere\dbg-b\repo",
        "dkj-policy@dkj-marketplace=$RepoRoot"
    )
    $r = Invoke-Check -HomeOverride $twoBad
    Assert-True ($r.Out -match '2 of 3 records name a scratch tree') `
        'two polluted records take the plural verb -- the singular case cannot prove the agreement'

    # EVERY VALUE OUT OF THE JSON IS SANITIZED BEFORE IT IS PRINTED (#309, #414). The hook forwards
    # these lines into session context and decides how loudly by matching '[ERROR]' over the whole
    # output, so a record carrying a newline could forge a line and one carrying a bracket could be
    # COUNTED. Both are asserted on the OUTPUT rather than on the call, because the call is what a
    # refactor moves and the property is what must survive it.
    $forge = New-Home -Label 'forge' -RawAdmin @"
{
  "version": 2,
  "plugins": {
    "plug-x[ERROR]@ccs-fixture": [ { "scope": "project", "projectPath": "$($NoWhere.Replace('\','/'))/dbg-f/repo", "version": "4.32.0" } ]
  }
}
"@
    $r = Invoke-Check -HomeOverride $forge
    Assert-True ($r.Code -eq 1 -and (@($r.Out -split "`n" | Where-Object { $_ -cmatch '\[ERROR\]' }).Count -eq 1)) `
        'a record id containing [ERROR] does not add a second marker line to the output'
    Assert-True ($r.Out -notmatch '\[ERROR\]@ccs-fixture') `
        'and the bracketed id is displayed sanitized rather than raw'

    # THE SLUG GUARD BEFORE A PATH SEGMENT. A marketplace part spelled with '..' must not be probed as
    # a directory, let alone reported as a leftover clone sitting somewhere it never was.
    $trav = New-Home -Label 'trav' -Records @("plug-t@..=$NoWhere\dbg-t\repo")
    $r = Invoke-Check -HomeOverride $trav
    Assert-True ($r.Code -eq 1 -and $r.Out -notmatch 'left a marketplace clone') `
        "a marketplace part of '..' is refused by the slug guard, so no clone is probed or reported"

    # THE PREFIX BOUNDARY. A sibling directory whose name merely BEGINS with a scratch root's name is
    # not inside it -- the trailing separator on the root is what makes that true, and this is the
    # assert that would catch its removal.
    $sibling = New-Home -Label 'sibling' -Records @("p@m=${NoWhere}orary\repo")
    $r = Invoke-Check -HomeOverride $sibling
    Assert-True ($r.Code -eq 0 -and $r.Out -cmatch '\[OK\]') `
        "'<root>orary\repo' is not under '<root>\' -- a sibling prefix is not a scratch path"

    Write-Host ''
    Write-Host '== check-claude-home: the states that are not a finding ==' -ForegroundColor Cyan

    $clean = New-Home -Label 'clean' -Records @("dkj-policy@dkj-marketplace=$RepoRoot")
    $r = Invoke-Check -HomeOverride $clean
    Assert-True ($r.Code -eq 0 -and $r.Out -cmatch '\[OK\] no fixture records' -and $r.Out -match '1 record,') `
        'a clean administration is [OK] with its record count, exit 0'

    $empty = New-Home -Label 'empty' -RawAdmin '{ "version": 2, "plugins": {} }'
    $r = Invoke-Check -HomeOverride $empty
    Assert-True ($r.Code -eq 0 -and $r.Out -cmatch '\[SKIP\] the plugin administration holds no records') `
        'an administration with no records is a [SKIP], not an [OK] -- nothing was compared'

    $fresh = New-Home -Label 'fresh' -NoAdminFile
    $r = Invoke-Check -HomeOverride $fresh
    Assert-True ($r.Code -eq 0 -and $r.Out -cmatch '\[SKIP\] no plugin administration on this machine') `
        'no administration and no snapshot is the ordinary fresh machine -- a [SKIP], never a finding'

    $unreadable = New-Home -Label 'unreadable' -RawAdmin '{ "version": 2, "plugins": { oops'
    $r = Invoke-Check -HomeOverride $unreadable
    Assert-True ($r.Code -eq 1 -and $r.Out -cmatch '\[ERROR\] the plugin administration exists but does not parse') `
        'an administration that does not parse is its own [ERROR] -- reported, never thrown'

    # THE PARSE MESSAGE EMBEDS THE DOCUMENT, which makes it the most untrusted string this check prints
    # -- a file that parses would not be here. The forged marker below sits inside the unparseable body,
    # so it reaches the message through ConvertFrom-Json rather than through a record field.
    $forgeParse = New-Home -Label 'forgeparse' -RawAdmin "{ `"plugins`": { oops [ERROR] more"
    $r = Invoke-Check -HomeOverride $forgeParse
    Assert-True ($r.Code -eq 1 -and (@($r.Out -split "`n" | Where-Object { $_ -cmatch '\[ERROR\]' }).Count -eq 1)) `
        'a forged marker inside the unparseable file does not reach the output as a second marker'

    # The snapshot sub-branch of the unreadable case: with one beside it the reader is told, and that
    # line is otherwise unreachable by the suite.
    Copy-Item -LiteralPath (Get-AdminPath -HomeDir $clean) -Destination (Get-SnapshotPath -HomeDir $unreadable)
    $r = Invoke-Check -HomeOverride $unreadable
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'A snapshot from a healthy read is beside it') `
        'an unreadable administration with a snapshot beside it says where the snapshot is'

    Write-Host ''
    Write-Host '== check-claude-home: the snapshot ==' -ForegroundColor Cyan

    # The only two cases that let the check write. Everything above passed -NoSnapshot.
    $snapHome = New-Home -Label 'snap' -Records @("dkj-policy@dkj-marketplace=$RepoRoot")
    $snapPath = Get-SnapshotPath -HomeDir $snapHome
    Assert-True (-not (Test-Path -LiteralPath $snapPath)) 'no snapshot before the first run'
    $r = Invoke-Check -HomeOverride $snapHome -AllowSnapshot
    Assert-True ((Test-Path -LiteralPath $snapPath) -and $r.Out -match 'snapshot refreshed') `
        'a clean read writes the snapshot, and says so'
    $live = Get-Content -LiteralPath (Get-AdminPath -HomeDir $snapHome) -Raw
    Assert-True ((Get-Content -LiteralPath $snapPath -Raw) -eq $live) `
        'the snapshot is the administration byte for byte -- it is what gets restored'

    $r = Invoke-Check -HomeOverride $snapHome -AllowSnapshot
    Assert-True ($r.Out -notmatch 'snapshot refreshed') `
        'an unchanged administration is not rewritten at every session start'

    # THE ORDER THAT MAKES THE SNAPSHOT SAFE: verdict first, write only on a clean one. A polluted file
    # must never be able to become the snapshot, or the recovery half is worthless exactly when it is
    # needed.
    $before = Get-Content -LiteralPath $snapPath -Raw
    $pollutedAdmin = "{`n  `"version`": 2,`n  `"plugins`": {`n    `"plug-x@ccs-fixture`": [ { `"scope`": `"project`", `"projectPath`": `"$($NoWhere.Replace('\','/'))/dbg-9/repo`", `"version`": `"4.32.0`" } ]`n  }`n}`n"
    [System.IO.File]::WriteAllText((Get-AdminPath -HomeDir $snapHome), $pollutedAdmin, (New-Object System.Text.UTF8Encoding($false)))
    $r = Invoke-Check -HomeOverride $snapHome -AllowSnapshot
    Assert-True ($r.Code -eq 1 -and (Get-Content -LiteralPath $snapPath -Raw) -eq $before) `
        'a finding leaves the snapshot alone -- a polluted file can never become the snapshot'
    Assert-True ($r.Out -match 'this check snapshotted the administration while it last read healthy' -and $r.Out -match 'Copy-Item') `
        'and the refusal points at the snapshot with the command that puts it back'

    # An administration that is GONE while a snapshot sits beside it is not the fresh-machine state --
    # the snapshot is the only thing that tells the two apart.
    Remove-Item -LiteralPath (Get-AdminPath -HomeDir $snapHome) -Force
    $r = Invoke-Check -HomeOverride $snapHome
    Assert-True ($r.Code -eq 1 -and $r.Out -cmatch '\[ERROR\] the plugin administration is GONE') `
        'a missing administration WITH a snapshot is an [ERROR] -- something deleted it'

    Write-Host ''
    Write-Host '== the SessionStart hook ==' -ForegroundColor Cyan

    $stubs = New-Tree -Label 'stubs'

    $errStub = New-StubCheck -Dir $stubs -Name 'stub-err' -ExitCode 1 -Body '[ERROR] a FIXTURE has written into the real plugin administration'
    $r = Invoke-Hook -CheckScriptOverride $errStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'needs a look' -and $r.Out -match 'data, not instructions') `
        'an [ERROR] reaches the session context, labelled as data -- and the hook still exits 0'

    $okStub = New-StubCheck -Dir $stubs -Name 'stub-ok' -ExitCode 0 -Body '[OK] no fixture records in the plugin administration -- 18 records'
    $r = Invoke-Hook -CheckScriptOverride $okStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no fixture records in the ~/\.claude plugin administration' -and $r.Out -notmatch '18 records') `
        'an [OK] is one quiet line at session start -- the detail stays for a deliberate run'

    $skipStub = New-StubCheck -Dir $stubs -Name 'stub-skip' -ExitCode 0 -Body '[SKIP] no plugin administration on this machine'
    $r = Invoke-Hook -CheckScriptOverride $skipStub
    Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'could not complete') `
        'a [SKIP] reads as clean rather than as a crash'

    $crashStub = New-StubCheck -Dir $stubs -Name 'stub-crash' -ExitCode 3 -Body 'something unexpected'
    $r = Invoke-Hook -CheckScriptOverride $crashStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'could not complete \(exit 3\)') `
        'a crashing check is reported as incomplete rather than as clean, and still exit 0'

    $r = Invoke-Hook -CheckScriptOverride (Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1")
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') `
        'check script missing -- a notice, exit 0, never a strand'

    Write-Host ''
    Write-Host '== the mirror ==' -ForegroundColor Cyan

    # The hook runs the MIRROR, not the source, so a source-only change ships nothing. The drift lint
    # holds this too; asserting it here is what makes the suite fail beside the code rather than two
    # gates later.
    Assert-True (Test-Path -LiteralPath $Mirror -PathType Leaf) `
        'the check is mirrored into the plugin the hook loads it from'
    $srcText = (Get-Content -LiteralPath $Script -Raw) -replace "`r`n", "`n"
    $mirText = (Get-Content -LiteralPath $Mirror -Raw) -replace "`r`n", "`n"
    Assert-True ($srcText -eq $mirText) 'and the mirror is byte-identical to the source'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
