<#
.SYNOPSIS
    Regression tests for the shared-workflow-scripts mechanics (issue #81): shared-scripts-lib.ps1,
    the generator/drift check, and the repo invariant that every plugin mirror is in sync with its source.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/shared-scripts.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')
# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

$script:pass = 0
$script:fail = 0

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

# --- Capturing a child script's output -------------------------------------------------------------
# EVERY assert in this file that reads a child's TEXT goes through this pair. It is defined here, at
# script scope, rather than inside the first scenario that happened to need it: a helper reachable only
# because PowerShell leaks a function out of somebody else's try block is a helper the next scenario
# writes around instead of using -- which is exactly what scenario C did, and what cost the run below.
#
# Test-OutputContains strips ALL whitespace from both sides, because the CHILD wraps its own Write-Error
# and Write-Warning output at its own console width: a phrase can break mid-word ('#33' + '2') or on a
# space, and no single substitution survives both.
#
# Invoke-CapturedScript exists for the half that whitespace stripping CANNOT repair. Under
# '& powershell ... 2>&1' the PARENT re-renders the child's stderr as its own NativeCommandError: it
# truncates the first line at the parent's buffer width and inserts the record decoration -- 'At line:',
# the '+ ' source echo, CategoryInfo, FullyQualifiedErrorId -- INTO the sentence at that point. The
# phrase is then not reformatted but interrupted, and a Contains can never match it again.
#
# WHERE THAT CUT LANDS IS DECIDED BY TWO THINGS THAT ARE NOT PROPERTIES OF THE SCRIPT UNDER TEST: the
# host's buffer width, and the LENGTH OF THE ABSOLUTE PATH the child was invoked with -- the parent
# renders '<powershell.exe> : <full script path> : <message>' and cuts the whole of it at the width. So
# the same commit passes or fails on where the repo happens to be checked out. Measured August 14, 2026:
# scenario C1's assert on '#332' failed at width 152 with the source at a 95-character path (the error
# arrived as '...open issue(s) #33', five lines of decoration, '2, but the PR declares...') and passed on
# the same machine, same commit, in an 80-column shell. Deterministic in both, twice each.
function Test-OutputContains {
    param([string]$Text, [string]$Pattern)
    return (($Text -replace '\s', '') -match ($Pattern -replace '\s', ''))
}

function Invoke-CapturedScript {
    <# Runs a shared script as a child and returns its combined output as plain text plus its exit
       code. Start-Process with redirect files rather than '2>&1' -- see the reasoning above. Each
       argument is quoted individually, because Start-Process joins -ArgumentList with plain spaces
       and a temp path containing a space would otherwise arrive as two arguments. #>
    param([string]$ScriptPath, [string[]]$ScriptArgs = @())
    $tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $outFile = Join-Path ([System.IO.Path]::GetTempPath()) "shared-out-$tag.txt"
    $errFile = Join-Path ([System.IO.Path]::GetTempPath()) "shared-err-$tag.txt"
    try {
        $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $ScriptArgs
        $quoted = @($all | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        })
        $proc = Start-Process -FilePath 'powershell' -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $text = ''
        foreach ($f in @($outFile, $errFile)) {
            if (Test-Path -LiteralPath $f) { $text += [System.IO.File]::ReadAllText($f) }
        }
        return [pscustomobject]@{ Out = $text; Code = $proc.ExitCode }
    } finally {
        foreach ($f in @($outFile, $errFile)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host "Invoke-CapturedScript -- a child's stderr arrives uninterrupted" -ForegroundColor Cyan
# THE GUARD FOR THE FINDING ABOVE, and it is deliberately about the CAPTURE rather than about any one
# phrase. An assert that merely looks for its own phrase is what was already there, and it only fails on
# the widths and paths where the cut happens to land inside that phrase -- which is how a broken capture
# stayed green on CI for days while it was red on a developer's machine.
#
# 'NativeCommandError' can only appear in this text if a PARENT rendered the child's stderr as an error
# record; a redirect file receives what the child wrote and nothing else. Its ABSENCE is therefore proof
# of which capture ran, at every width and every path length. Asserted in both directions, or an empty
# capture would pass the negative half on its own.
$probeChild = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-capture-probe-$PID-$([guid]::NewGuid().ToString('n')).ps1")
try {
    $probeBody = "Write-Error 'capture probe: the marker #332 must survive whole'" + [Environment]::NewLine + "exit 3"
    [System.IO.File]::WriteAllText($probeChild, $probeBody, (New-Object System.Text.UTF8Encoding $false))
    $probeRun = Invoke-CapturedScript -ScriptPath $probeChild
    Assert-Equal 3 $probeRun.Code "capture probe: the CHILD's exit code is reported"
    Assert-True (Test-OutputContains $probeRun.Out 'the marker #332 must survive whole') 'capture probe: the stderr message arrives whole'
    Assert-True (-not (Test-OutputContains $probeRun.Out 'NativeCommandError')) 'capture probe: no parent error-record decoration was stamped into it'
} finally {
    Remove-Item -LiteralPath $probeChild -Force -ErrorAction SilentlyContinue
}

Write-Host "Get-SharedScriptPairs" -ForegroundColor Cyan
$pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
Assert-True ($pairs.Count -ge 1) 'at least one shared script registered'
$fold = $pairs | Where-Object { $_.Name -eq 'fold-changelog-entry' }
Assert-True ($null -ne $fold) 'fold-changelog-entry is in the register'
Assert-True ($fold.SourceRel -like 'scripts\*') 'source is repo-root-relative under scripts\'
Assert-True ($fold.MirrorRel -like 'plugins\*') 'mirror lives under the plugin'
# Explicit -- the generic loops further down already cover these two implicitly, but a missing
# pair in the register would then slip through silently instead of giving a targeted failure.
$newChangelogPair = $pairs | Where-Object { $_.Name -eq 'new-branch' }
Assert-True ($null -ne $newChangelogPair) 'new-branch is in the register'
$newBranchPair = $pairs | Where-Object { $_.Name -eq 'new-branch' }
Assert-True ($null -ne $newBranchPair) 'new-branch is in the register'

Write-Host "Repo invariant: every mirror in sync with its source" -ForegroundColor Cyan
foreach ($pair in $pairs) {
    $src = Get-NormalizedScriptContent -Path $pair.SourcePath
    $mirror = Get-NormalizedScriptContent -Path $pair.MirrorPath
    Assert-True ($null -ne $src) "source exists: $($pair.SourceRel)"
    Assert-True ($null -ne $mirror) "mirror exists: $($pair.MirrorRel)"
    Assert-Equal $src $mirror "in sync: $($pair.Name)"
}

Write-Host "Dual-context resolution guarded in every source" -ForegroundColor Cyan
# The whole mirror mechanism relies on a shared script resolving its repo root dual-context.
# If CLAUDE_PROJECT_DIR disappears from a source, the consumer call breaks silently -- this catches
# that. Exception: a dot-sourced LIB (issue #114's check-report-lib) is not itself a standalone
# entry point -- it never resolves a repo root; it is reached via a $PSScriptRoot-relative
# dot-source from a caller that already resolved one, so this invariant does not apply to it.
# The lib exception is declared in the REGISTRY (LibOnly), not in a list kept here. This used to be a
# hand-written array of names, which meant every new shared lib arrived as a failing assert about an
# invariant that does not apply to it -- and the fix was to edit a second literal that nothing tied to
# the registration. Registering a lib now carries its own exception.
$libOnlyPairs = @($pairs | Where-Object { $_.LibOnly } | ForEach-Object { $_.Name })
Assert-True ($libOnlyPairs.Count -ge 1) 'the registry declares at least one dot-sourced lib (LibOnly)'
# Two ways to satisfy the invariant since inbound #203: resolve CLAUDE_PROJECT_DIR inline, or delegate
# to check-report-lib's shared Resolve-CheckRoot (which the two sync checks now do, so they can also
# report HOW the root was resolved). A bare '-match CLAUDE_PROJECT_DIR' would still pass on the two
# checks purely because their COMMENTS name the env var -- the assertion has to look for an actual
# call, otherwise it silently stops guarding anything the day the code moves out.
foreach ($pair in ($pairs | Where-Object { $libOnlyPairs -notcontains $_.Name })) {
    $src = Get-NormalizedScriptContent -Path $pair.SourcePath
    $inline   = $src -match '\$env:CLAUDE_PROJECT_DIR'
    $delegate = $src -match 'Resolve-CheckRoot\s+-Override'
    # THE THIRD WAY, added with #1917: delegate to Resolve-RepoRootOrFail, check-report-lib's
    # REFUSING sibling of Resolve-CheckRoot. It is the same dual-context resolution -- it calls
    # Resolve-CheckRoot itself -- so it satisfies this invariant for exactly the reason the second way
    # does, and it is a separate alternative here rather than a loosened regex because the two differ
    # in verdict, not in resolution, and a reader of this assert should see both names.
    $delegateOrFail = $src -match 'Resolve-RepoRootOrFail'
    Assert-True ($inline -or $delegate -or $delegateOrFail) "$($pair.Name): source resolves the repo root dual-context (inline `$env:CLAUDE_PROJECT_DIR, Resolve-CheckRoot or Resolve-RepoRootOrFail)"
}

# The invariant moves with the behavior: check-report-lib now OWNS the dual-context resolution for the
# scripts that delegate, so the env var has to be read there for real. Without this, dropping it from
# Resolve-CheckRoot would leave every delegating check silently non-dual-context while the loop above
# stayed green on the delegation alone.
$reportLibSrc = Get-NormalizedScriptContent -Path (($pairs | Where-Object { $_.Name -eq 'check-report-lib' }).SourcePath)
Assert-True ($reportLibSrc -match 'function Resolve-CheckRoot') 'check-report-lib defines Resolve-CheckRoot (the shared dual-context resolver)'
Assert-True ($reportLibSrc -match '\$env:CLAUDE_PROJECT_DIR') 'check-report-lib really reads $env:CLAUDE_PROJECT_DIR (not only the delegating callers)'
# Same reasoning one function over (#1917): the loop above now accepts Resolve-RepoRootOrFail as
# proof of dual-context resolution, so the thing it accepts has to exist and has to get its answer
# from Resolve-CheckRoot rather than re-deriving one. Without these two, deleting the delegation
# inside the lib would leave every acting script green on the name alone.
Assert-True ($reportLibSrc -match 'function Resolve-RepoRootOrFail') 'check-report-lib defines Resolve-RepoRootOrFail (the refusing sibling)'
Assert-True ($reportLibSrc -match 'Resolve-RepoRootOrFail[\s\S]*?Resolve-CheckRoot\s+-Override') 'Resolve-RepoRootOrFail delegates its resolution to Resolve-CheckRoot (it does not re-derive one)'

Write-Host "Get-NormalizedScriptContent" -ForegroundColor Cyan
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-test-$PID-$([guid]::NewGuid().ToString('n')).ps1")
[System.IO.File]::WriteAllText($tmp, "line1`r`nline2`r`n", (New-Object System.Text.UTF8Encoding $false))
try {
    $norm = Get-NormalizedScriptContent -Path $tmp
    Assert-Equal "line1`nline2`n" $norm 'CRLF is LF-normalized'
} finally {
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
}
Assert-Equal $null (Get-NormalizedScriptContent -Path (Join-Path $RepoRoot 'does-not-exist-xyz.ps1')) 'missing file -> $null'

Write-Host "build-shared-scripts.ps1 -Check -- repo in sync" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\sync\build-shared-scripts.ps1') -Check | Out-Null
Assert-Equal 0 $LASTEXITCODE 'generator -Check green on the repo'

Write-Host "Pre-flight (#86): missing repo-config stops with a clear pointer" -ForegroundColor Cyan
# Run every source against an EMPTY repo root (via CLAUDE_PROJECT_DIR) -- without repo-config/branch-info
# the pre-flight should stop with a pointer instead of a raw dot-source error. Child process, because
# the scripts call 'exit' themselves.
$pfDir = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-preflight-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $pfDir -Force | Out-Null
$prevPd = $env:CLAUDE_PROJECT_DIR
$prevEap = $ErrorActionPreference
$vfDir = $null
try {
    $env:CLAUDE_PROJECT_DIR = $pfDir
    # Continue, not Stop: the child writes its pointer via Write-Error to stderr; with 2>&1,
    # Windows PowerShell 5.1 would treat that as a terminating NativeCommandError and abort this test.
    $ErrorActionPreference = 'Continue'
    # The CHILD PROCESS itself already renders Write-Error to plain stderr lines at its own
    # (non-interactive) console width, BEFORE that text is ever captured here -- a word like
    # 'branch-info.ps1' can coincidentally split exactly at the hyphen wrap boundary
    # ('branch-'\n'info.ps1'), which would make a bare -match below fail flakily, purely depending
    # on the (arbitrary) temp-path length. Stripping newlines before the match restores the
    # original continuous text -- no functional change, only deterministic matching.
    #
    # AND THAT IS ONLY HALF OF IT, measured August 3, 2026 at width 198 (the same finding that repaired
    # new-branch.tests.ps1's Get-FlatOutput). Under '2>&1' the PARENT turns each of the child's stderr
    # lines into its own NativeCommandError and renders that record's header, CategoryInfo and
    # FullyQualifiedErrorId -- so with two stderr lines, ~300 characters of decoration land in the MIDDLE
    # of the first line's sentence. Stripping newlines cannot repair that: the phrase is not reformatted,
    # it has other content inserted into it. Invoke-CapturedScript (defined at the top of this file)
    # therefore captures the child's stderr as PLAIN TEXT via a redirect file, and Test-OutputContains
    # strips ALL whitespace so the child's own remaining wrap -- mid-word or on a space -- cannot break
    # a match either.

    $foldSrc = ($pairs | Where-Object { $_.Name -eq 'fold-changelog-entry' }).SourcePath
    $foldRun = Invoke-CapturedScript -ScriptPath $foldSrc
    $foldOut = $foldRun.Out
    $foldCode = $foldRun.Code
    Assert-Equal 1 $foldCode 'fold stops (exit 1) without repo-config'
    Assert-True (Test-OutputContains $foldOut 'repo-config') 'fold names repo-config in the pointer'
    $prSrc = ($pairs | Where-Object { $_.Name -eq 'open-pr' }).SourcePath
    $prRun = Invoke-CapturedScript -ScriptPath $prSrc -ScriptArgs @('-Title', 'fix: preflight-test')
    $prOut = $prRun.Out
    $prCode = $prRun.Code
    Assert-Equal 1 $prCode 'open-pr stops (exit 1) without repo-config/branch-info'
    Assert-True (Test-OutputContains $prOut 'branch-info') 'open-pr names branch-info in the pointer'

    # new-branch relies ONLY on branch-info.ps1 (no gh, and repo-config is optional to it -- lighter than
    # fold/open-pr), so no VUL-IN follow-up scenario for it: its only pre-flight check is the bare
    # existence check on branch-info.ps1 below. This used to name two scripts; they merged on
    # August 7, 2026.
    $nceSrc = ($pairs | Where-Object { $_.Name -eq 'new-branch' }).SourcePath
    $nceRun = Invoke-CapturedScript -ScriptPath $nceSrc -ScriptArgs @('-Name', 'fix/preflight-test')
    $nceOut = $nceRun.Out
    $nceCode = $nceRun.Code
    Assert-Equal 1 $nceCode 'new-branch stops (exit 1) without branch-info'
    Assert-True (Test-OutputContains $nceOut 'branch-info') 'new-branch names branch-info in the pointer'
    $nbSrc = ($pairs | Where-Object { $_.Name -eq 'new-branch' }).SourcePath
    $nbRun = Invoke-CapturedScript -ScriptPath $nbSrc -ScriptArgs @('-Name', 'feat/preflight-test')
    $nbOut = $nbRun.Out
    $nbCode = $nbRun.Code
    Assert-Equal 1 $nbCode 'new-branch stops (exit 1) without branch-info'
    Assert-True (Test-OutputContains $nbOut 'branch-info') 'new-branch names branch-info in the pointer'

    # Second scenario: scaffolds PRESENT but not yet filled in (VUL-IN) -> also stops with a pointer.
    # Minimal scaffolds (repo-config with VUL-IN + an empty branch-info so open-pr's existence check
    # succeeds and the placeholder check is reached).
    $vfDir = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-vulin-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path (Join-Path $vfDir 'scripts\lib') -Force | Out-Null
    $Utf8 = New-Object System.Text.UTF8Encoding $false
    $rcVulin = @'
$script:RepoName = 'VUL-IN/repo'
function Get-RepoName { return $script:RepoName }
function Get-RepoBlobUrl { return "https://github.com/$($script:RepoName)/blob/main/" }
$script:LintScript = 'VUL-IN'
function Get-LintScript { return $script:LintScript }
'@
    $biVulin = @'
$script:BranchTypeOrder = @()
$script:BranchPrefixTable = @{}
function Get-BranchTypes { return $script:BranchTypeOrder }
function Get-BranchPrefix { param([string]$Branch) if ($Branch -match '/') { return ($Branch -split '/')[0] } return ($Branch -split '-')[0] }
function Get-BranchInfo { param([string]$Branch) [pscustomobject]@{ Branch = $Branch; Prefix = (Get-BranchPrefix $Branch); IsKnown = $false; Label = $null; Type = $null; SafeName = ($Branch -replace '/', '-') } }
'@
    [System.IO.File]::WriteAllText((Join-Path $vfDir 'scripts\repo-config.ps1'), $rcVulin, $Utf8)
    [System.IO.File]::WriteAllText((Join-Path $vfDir 'scripts\lib\branch-info.ps1'), $biVulin, $Utf8)
    $env:CLAUDE_PROJECT_DIR = $vfDir
    $foldVRun = Invoke-CapturedScript -ScriptPath $foldSrc
    $foldV = $foldVRun.Out
    $foldVCode = $foldVRun.Code
    Assert-Equal 1 $foldVCode 'fold stops (exit 1) on an unfilled VUL-IN scaffold'
    Assert-True (Test-OutputContains $foldV 'VUL-IN') 'fold names VUL-IN in the pointer'
    $prVRun = Invoke-CapturedScript -ScriptPath $prSrc -ScriptArgs @('-Title', 'fix: vulin-test')
    $prV = $prVRun.Out
    $prVCode = $prVRun.Code
    Assert-Equal 1 $prVCode 'open-pr stops (exit 1) on an unfilled VUL-IN scaffold'
    Assert-True (Test-OutputContains $prV 'VUL-IN') 'open-pr names VUL-IN in the pointer'
} finally {
    $ErrorActionPreference = $prevEap
    if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    Remove-Item -Path $pfDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($vfDir) { Remove-Item -Path $vfDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "native-command stderr pitfall -- centralized in Invoke-NativeCapture (#107, #114 item 1)" -ForegroundColor Cyan
# The push/gh calls used to die on 'remote:'/status stderr: under ErrorActionPreference=Stop,
# PS 5.1 promotes native stderr to a terminating NativeCommandError, before the exit-code check.
# That guard now lives in exactly one place -- the shared Invoke-NativeCapture helper.
# (a) Mechanism proof: the bare pattern breaks, the capture pattern does not -- on a real native
# command (cmd.exe echoes to stderr and gives exit 0). NB: .ps1 is pure ASCII, so no diacritics.
$naiveThrew = $false
try {
    $prevE = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
    & cmd /c 'echo remote: something 1>&2 & exit 0' 2>&1 | Out-Null
    $ErrorActionPreference = $prevE
} catch { $naiveThrew = $true; $ErrorActionPreference = 'Stop' }
Assert-True $naiveThrew 'bare pattern (native stderr under EAP=Stop) is indeed terminating'

$fixThrew = $false; $fixCode = $null
try {
    $prevE = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
    $prevInner = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & cmd /c 'echo remote: something 1>&2 & exit 0' 2>&1
    $fixCode = $LASTEXITCODE
    $ErrorActionPreference = $prevInner
    $out | Out-Null
    $ErrorActionPreference = $prevE
} catch { $fixThrew = $true }
Assert-True (-not $fixThrew) 'capture pattern (EAP=Continue around the call) is NOT terminating'
Assert-Equal 0 $fixCode 'capture pattern reads the real exit code (0) of the command'

# (b) The helper behaves: run it FROM a caller scope that is EAP=Stop (exactly like the real
# scripts) against a native command that writes stderr AND returns exit 0. It must not throw, must
# capture the merged output, read the real exit code, and restore the caller's EAP afterwards. This
# also proves the FilePath/Arguments design (over a scriptblock): the EAP override only takes effect
# because the command runs inside the helper's own scope.
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
$prevEapNc = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
$ncThrew = $false; $ncResult = $null
try { $ncResult = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'echo remote: hi 1>&2 & exit 0') } catch { $ncThrew = $true }
Assert-True (-not $ncThrew) 'Invoke-NativeCapture does not throw on native stderr under caller EAP=Stop'
Assert-Equal 0 $ncResult.ExitCode 'Invoke-NativeCapture reads the real exit code (0)'
Assert-True ((($ncResult.Output | Out-String)) -match 'remote: hi') 'Invoke-NativeCapture captures merged stderr by default'
Assert-Equal 'Stop' $ErrorActionPreference 'Invoke-NativeCapture restores the caller EAP after running'
$ncNonZero = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit 3')
Assert-Equal 3 $ncNonZero.ExitCode 'Invoke-NativeCapture surfaces a non-zero exit code'
$ncDiscard = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'echo keep-stdout& echo drop-stderr 1>&2& exit 0') -DiscardStderr
$ncDiscardText = ($ncDiscard.Output | Out-String)
Assert-True ($ncDiscardText -match 'keep-stdout') '-DiscardStderr keeps stdout'
Assert-True (-not ($ncDiscardText -match 'drop-stderr')) '-DiscardStderr drops stderr (so it cannot pollute JSON)'
$ErrorActionPreference = $prevEapNc

# (c) Regression guard: the #107 protection must stay CENTRALIZED. The helper itself carries the
# EAP=Continue -> capture $LASTEXITCODE -> restore dance, and every native-command call site reaches
# for the helper rather than re-deriving a bare 'git push'/'gh' under EAP=Stop.
# (The live push against a real remote is exercised by the offline fixture below, not here.)
$ncLibSrc = ($pairs | Where-Object { $_.Name -eq 'native-capture-lib' }).SourcePath
$ncLibText = [System.IO.File]::ReadAllText($ncLibSrc)
Assert-True ($ncLibText -match "ErrorActionPreference = 'Continue'") 'native-capture-lib runs the command under EAP=Continue'
Assert-True ($ncLibText -match '\$code = \$LASTEXITCODE') 'native-capture-lib records $LASTEXITCODE right after the command'
Assert-True ($ncLibText -match '2>&1') 'native-capture-lib merges stderr by default (2>&1)'
Assert-True ($ncLibText -match '2>\$null') 'native-capture-lib discards stderr on -DiscardStderr (2>$null)'
Assert-True ($ncLibText -match '\$ErrorActionPreference = \$prevEap') 'native-capture-lib restores EAP (finally)'

$openPrSrc = ($pairs | Where-Object { $_.Name -eq 'open-pr' }).SourcePath
$openPrText = [System.IO.File]::ReadAllText($openPrSrc)
Assert-True ($openPrText -match "Invoke-NativeCapture -FilePath 'git' -Arguments @\('push'") 'open-pr runs the push via Invoke-NativeCapture'
Assert-True ($openPrText -match "Invoke-NativeCapture -FilePath 'gh' -Arguments \(@\('pr', 'create'") 'open-pr runs gh pr create via Invoke-NativeCapture'
Assert-True (-not ($openPrText -match "ErrorActionPreference = 'Continue'")) 'open-pr no longer re-derives the EAP dance inline (centralized in the helper)'

Write-Host "native-command stderr pitfall -- repo-wide guard over every call site" -ForegroundColor Cyan
# Why this is here on top of (c). The assertions above name call sites BY HAND -- open-pr's push,
# its gh pr create. They prove those two did not regress; they say nothing about the next one. A new
# script (or a new line in an existing one) can reach for a bare `git ... 2>$null` under EAP=Stop and
# every test above stays green, because no test is looking there. That is not hypothetical: the same
# class of bug was found four times in the smartwatchbanden consumer on July 29, 2026 -- once in the
# consumer's own ship-pr fork (a successful `git fetch` killed the run right before the fold step),
# and three more that nobody had noticed at all: `lint-brain` fell over the moment -Path pointed
# outside a git repo, `switch-account` died on `gh auth status` before it could switch anything, and
# `archive-and-remove-theme` plus `rename-specialist` made their own clear error messages
# unreachable. Each was a call site that no per-site assertion covered. A rule this repo enforces by
# convention is worth enforcing by scan.
#
# Two forms count as protected, and only these two:
#   1. the call sits inside a function that sets EAP=Continue first (what Invoke-NativeCapture does);
#   2. the statement sits inside a try/catch, so the terminating ErrorRecord is caught and the script
#      picks its own fallback deliberately.
# A file that never sets EAP=Stop is not at risk and is skipped.

$nativeExeAlternation = 'git|gh|npm|node|powershell|shopify'
# Single quotes on purpose: inside a double-quoted PowerShell string '\$null' is not an escape but a
# backslash followed by the VARIABLE $null, which interpolates to an empty string -- the pattern then
# quietly stops matching the very thing it is meant to catch.
$nativeRedirectRx = [regex]('\b(' + $nativeExeAlternation + ')\b[^\r\n]*\s2>(&1|\$null)')

function Get-UnprotectedNativeRedirects {
    <#
        Return one string per unprotected call site ("<relative path>:<line> (<scope>) -- <code>").
        $Files are scanned as text; the try-depth is tracked with a plain brace balance, which is
        coarse but ample for these scripts -- and the fixture below fails loudly if it ever becomes
        so lax that it stops finding a real violation.
    #>
    param([System.IO.FileInfo[]]$Files, [string]$BasePath)
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($sf in $Files) {
        $lines = @(Get-Content -LiteralPath $sf.FullName -Encoding UTF8)
        $rel = $sf.FullName
        if ($BasePath -and $rel.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $rel.Substring($BasePath.Length).TrimStart('\')
        }
        if (-not ($lines -match "^\s*\`$ErrorActionPreference\s*=\s*['`"]Stop['`"]")) { continue }

        $inBlockComment = $false
        $currentFn = ''
        $fnHasContinue = $false
        $balance = 0
        $tryStack = New-Object System.Collections.Generic.List[int]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trim = $line.Trim()

            # Skip block comments: the .DESCRIPTION of these very scripts DOCUMENTS the pitfall and
            # therefore contains a literal `2>$null` that is prose, not a call.
            if ($trim -like '<#*') { $inBlockComment = $true }
            if ($inBlockComment) {
                if ($trim -like '*#>*') { $inBlockComment = $false }
                continue
            }
            if ($trim.StartsWith('#')) { continue }

            $balanceBefore = $balance
            $hasTry = ($trim -match '\btry\s*\{')
            $balance += ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)

            if ($trim -match '^function\s+([\w-]+)') {
                $currentFn = $Matches[1]
                $fnHasContinue = $false
            } elseif ($trim -match "^\`$ErrorActionPreference\s*=\s*['`"]Continue['`"]") {
                if ($currentFn) { $fnHasContinue = $true }
            } elseif ($nativeRedirectRx.IsMatch($line)) {
                $inTry = ($tryStack.Count -gt 0) -or $hasTry
                if (-not (($currentFn -and $fnHasContinue) -or $inTry)) {
                    $scope = if ($currentFn) { "function '$currentFn'" } else { 'top-level' }
                    $found.Add("${rel}:$($i + 1) ($scope) -- $trim")
                }
            }

            if ($hasTry) { $tryStack.Add($balanceBefore) }
            while ($tryStack.Count -gt 0 -and $balance -le $tryStack[$tryStack.Count - 1]) {
                $tryStack.RemoveAt($tryStack.Count - 1)
            }
        }
    }
    return $found
}

# The scan covers the whole repo: the workshop's own scripts/ AND the plugin payload (hooks/,
# skills/, and every plugin's scripts/ mirror). The tests themselves are excluded -- they exercise
# the bare pattern on purpose, in (a) above.
$scanFiles = @(Get-ChildItem -Path $RepoRoot -Recurse -File -Filter '*.ps1' |
    Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' -and $_.DirectoryName -notlike '*\scripts\tests*' })
Assert-True ($scanFiles.Count -ge 10) "the scan sees a plausible number of scripts (found: $($scanFiles.Count))"

$unprotected = @(Get-UnprotectedNativeRedirects -Files $scanFiles -BasePath $RepoRoot)
Assert-Equal 0 $unprotected.Count 'no unprotected native stderr redirect anywhere in the repo'
foreach ($u in $unprotected) { Write-Host "         $u" -ForegroundColor Red }

# A guard that can no longer find anything is not a guard. Run the same scan over a fixture holding
# all four shapes side by side, so an over-eager try/catch exemption turns this red instead of
# silently exonerating the whole repo.
$guardFixture = Join-Path ([System.IO.Path]::GetTempPath()) "native-guard-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Force -Path $guardFixture | Out-Null
try {
    $badSrc = @'
$ErrorActionPreference = 'Stop'
$x = git rev-parse --show-toplevel 2>$null
'@
    $goodFnSrc = @'
$ErrorActionPreference = 'Stop'
function Invoke-GitQuiet {
    $ErrorActionPreference = 'Continue'
    git @args 2>$null
}
'@
    $goodTrySrc = @'
$ErrorActionPreference = 'Stop'
try {
    $x = git rev-parse --show-toplevel 2>$null
} catch {
    $x = $null
}
'@
    $noStopSrc = @'
$y = git status --porcelain 2>$null
'@
    [System.IO.File]::WriteAllText((Join-Path $guardFixture 'bad.ps1'), $badSrc)
    [System.IO.File]::WriteAllText((Join-Path $guardFixture 'good-function.ps1'), $goodFnSrc)
    [System.IO.File]::WriteAllText((Join-Path $guardFixture 'good-try.ps1'), $goodTrySrc)
    [System.IO.File]::WriteAllText((Join-Path $guardFixture 'no-stop.ps1'), $noStopSrc)

    $fixtureHits = @(Get-UnprotectedNativeRedirects -Files @(Get-ChildItem -Path $guardFixture -File -Filter '*.ps1') -BasePath $guardFixture)
    $fixtureText = ($fixtureHits -join "`n")
    Assert-Equal 1 $fixtureHits.Count 'the scan finds exactly the one unprotected call site'
    Assert-True ($fixtureText -match 'bad\.ps1:2') 'the bare top-level call is the one reported'
    Assert-True (-not ($fixtureText -match 'good-function')) 'an EAP=Continue wrapper is exonerated'
    Assert-True (-not ($fixtureText -match 'good-try')) 'a try/catch is exonerated'
    Assert-True (-not ($fixtureText -match 'no-stop')) 'a script without EAP=Stop is not at risk'
} finally {
    Remove-Item -Path $guardFixture -Recurse -Force -ErrorAction SilentlyContinue
}

# Sweep guard (after the v1.12.0 breakage): the other release scripts that mutate native git/gh must
# not carry the #107 pitfall. cut-release.ps1 now routes its git mutations through the same shared
# Invoke-NativeCapture helper (#114 follow-up) instead of a bare 'git add' under a hand-rolled
# EAP=Continue block -- so the guard asserts it reaches for the helper and no longer re-derives the
# inline dance.
$cutSrc = Join-Path $RepoRoot 'scripts\release\cut-release.ps1'
$cutText = [System.IO.File]::ReadAllText($cutSrc)
Assert-True ($cutText -match "Invoke-NativeCapture -FilePath 'git' -Arguments @\('add', '-A'\)") 'cut-release runs git add via Invoke-NativeCapture'
Assert-True ($cutText -match "Invoke-NativeCapture -FilePath 'git' -Arguments @\('push', 'origin', 'main'\)") 'cut-release runs git push via Invoke-NativeCapture'
Assert-True (-not ($cutText -match "(?m)^\s*git add -A\s*$")) 'cut-release no longer runs a bare inline git add'
Assert-True (-not ($cutText -match "ErrorActionPreference = 'Continue'")) 'cut-release no longer re-derives the EAP dance inline (centralized in the helper)'

$foldSrc = ($pairs | Where-Object { $_.Name -eq 'fold-changelog-entry' }).SourcePath
$foldText = [System.IO.File]::ReadAllText($foldSrc)
Assert-True ($foldText -match "Invoke-NativeCapture -FilePath 'gh' -Arguments @\('pr', 'list'") 'fold runs gh pr list via Invoke-NativeCapture'
Assert-True ($foldText -match '-DiscardStderr') 'fold discards gh pr list stderr (-DiscardStderr) so it cannot pollute the JSON'
Assert-True (-not ($foldText -match "gh pr list.*2>\`$null")) 'fold no longer re-derives the inline 2>$null discard (centralized in the helper)'
# #103 (Victor #4): gh pr list supplies 'files' just as well as gh pr view -- the second gh
# roundtrip has been dropped. Regression guard: the --json list carries 'files' along (now as an
# argument-array element), and a real 'gh pr view' call (as opposed to an explanatory code comment
# naming the old approach) has not returned.
# 'mergedAt' joined the list on August 5, 2026, when the merge date moved out of the scaffolded heading
# onto the entry's closing line. Asserted per FIELD rather than as one literal string, so adding a fifth
# field later does not fail this for no reason -- while dropping either of these two still does, and both
# matter: without 'files' the Plugins line disappears, without 'mergedAt' the date silently falls back to
# the clock, which is the exact inaccuracy the change removed.
$foldJson = [regex]::Match($foldText, "'--json',\s*'([^']+)'")
Assert-True $foldJson.Success 'fold passes a --json field list to gh pr list'
$foldFields = @($foldJson.Groups[1].Value -split ',')
Assert-True ($foldFields -contains 'files') 'fold requests files in the gh pr list call (the Plugins line)'
Assert-True ($foldFields -contains 'mergedAt') 'fold requests mergedAt in the same call (the merge date, from the PR rather than the clock)'
Assert-True (-not ($foldText -match '(?m)^\s*\$\w+\s*=\s*gh pr view')) 'fold no longer runs a separate gh pr view call (merged, #103)'

Write-Host "open-pr + fold-changelog-entry: repo-config-driven overrides (#101)" -ForegroundColor Cyan
# Shared fixture: a fake 'gh' on PATH (Sylvester's pattern -- a fake gh.cmd + a local bare git
# remote), so both the open-pr and fold-RepoRoot scenarios below run for real (real git repo,
# real script invocation) but fully offline and deterministically -- no dependency on a real `gh`
# being installed/authenticated on the machine running the suite.
$fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-fakegh-$PID-$([guid]::NewGuid().ToString('n'))")
$prArgsCapture = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-gh-args-$PID-$([guid]::NewGuid().ToString('n')).txt")
$prBodyCapture = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-scripts-gh-body-$PID-$([guid]::NewGuid().ToString('n')).md")
$prFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("openpr-fixture-$PID-$([guid]::NewGuid().ToString('n'))")
$prBareRemote  = Join-Path ([System.IO.Path]::GetTempPath()) ("openpr-remote-$PID-$([guid]::NewGuid().ToString('n')).git")
$foldTarget  = Join-Path ([System.IO.Path]::GetTempPath()) ("fold-reporoot-target-$PID-$([guid]::NewGuid().ToString('n'))")
$foldDecoy   = Join-Path ([System.IO.Path]::GetTempPath()) ("fold-reporoot-decoy-$PID-$([guid]::NewGuid().ToString('n'))")
$foldDefault = Join-Path ([System.IO.Path]::GetTempPath()) ("fold-reporoot-default-$PID-$([guid]::NewGuid().ToString('n'))")
$prBranch = 'feat/openpr-101-test'
$foldBranch = 'chore/fold-reporoot-test'
$Utf8NoBomTest = New-Object System.Text.UTF8Encoding $false
$prevPath1 = $env:PATH
$prevPd = $env:CLAUDE_PROJECT_DIR
$prevLoc = (Get-Location).Path
$prevEapShared = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'  # native git/gh calls below -- #107 pitfall guard

    # --- Fake gh on PATH ---
    # 'pr create' captures its full argument list + a copy of the --body-file content (read BEFORE
    # open-pr.ps1's own finally removes the temp file) and prints a fake PR URL. 'pr list' (used by
    # fold, not by open-pr) returns an empty JSON array, i.e. "no PR found" -- both exit 0.
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    $ghImpl = @'
if ($args -contains 'issue' -and $args -contains 'list') {
    # The resolves gate asks which issues are open. GH_OPEN_ISSUES lets a scenario decide; unset
    # means "no open issues", which is what every pre-gate scenario expects.
    # GH_FAIL_ISSUE_LIST simulates an unreachable/erroring gh for the degraded-path scenario.
    if ($env:GH_FAIL_ISSUE_LIST) { [Console]::Error.WriteLine('fake gh: issue list unavailable'); exit 1 }
    if ($env:GH_OPEN_ISSUES) { Write-Output $env:GH_OPEN_ISSUES } else { Write-Output '[]' }
    exit 0
}
if ($args -contains 'create') {
    if ($env:GH_ARGS_CAPTURE) {
        [System.IO.File]::WriteAllText($env:GH_ARGS_CAPTURE, ($args -join "`n"), [System.Text.Encoding]::UTF8)
    }
    $bfIdx = [array]::IndexOf($args, '--body-file')
    if ($bfIdx -ge 0 -and $env:GH_BODY_CAPTURE) {
        $bodyPath = $args[$bfIdx + 1]
        if (Test-Path -LiteralPath $bodyPath) {
            Copy-Item -LiteralPath $bodyPath -Destination $env:GH_BODY_CAPTURE -Force
        }
    }
    Write-Output 'https://github.com/fake/repo/pull/999'
    exit 0
} elseif ($args -contains 'list') {
    Write-Output '[]'
    exit 0
} else {
    exit 1
}
'@
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh-impl.ps1'), $ghImpl, $Utf8NoBomTest)
    $ghCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh.cmd'), $ghCmd, $Utf8NoBomTest)
    $env:PATH = "$fakeBin;$env:PATH"

    Write-Host "  open-pr: default path (regression) vs. override path" -ForegroundColor DarkCyan
    # A real (throwaway) git repo + a local bare remote, so open-pr's own 'git push -u origin
    # <branch>' succeeds without touching a real remote.
    New-Item -ItemType Directory -Path $prBareRemote -Force | Out-Null
    Invoke-FixtureGitJudged @('init', '--bare', '--quiet', $prBareRemote)
    New-Item -ItemType Directory -Path (Join-Path $prFixtureRoot '.github') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $prFixtureRoot 'scripts\lib') -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'scripts\lib\branch-info.ps1') -Destination (Join-Path $prFixtureRoot 'scripts\lib\branch-info.ps1') -Force
    # THE HEADING CARRIES ITS FIELDS IN THE SHAPE THE RECORD ACTUALLY USES -- middot-separated, as every
    # entry in releases/ does. It read '- Feat - 2026-07-21' until August 7, 2026, a shape that appears
    # NOWHERE in this repo's history (measured: zero hits across releases/), so the fixture was proving the
    # legacy path against a legacy format that never existed. That went unnoticed while nothing parsed the
    # heading; the PR title now does, and a fixture in an invented shape would have asserted the wrong title.
    $prEntryContent = "### Open-PR 101 test $([char]0x00B7) Feat $([char]0x00B7) 2026-07-21`n`nThis is the test description text.`n"
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'feat-openpr-101-test.md'), $prEntryContent, $Utf8NoBomTest)

    Set-Location $prFixtureRoot
    Invoke-FixtureGitJudged @('init', '--quiet')
    Invoke-FixtureGitJudged @('config', 'user.email', 'tycho@test.local')
    Invoke-FixtureGitJudged @('config', 'user.name', 'Tycho Test')
    # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
    Invoke-FixtureGitJudged @('config', 'commit.gpgsign', 'false')
    Invoke-FixtureGitJudged @('remote', 'add', 'origin', $prBareRemote)
    Invoke-FixtureGitJudged @('add', '-A')
    Invoke-FixtureGitJudged @('commit', '--quiet', '-m', 'initial')
    Invoke-FixtureGitJudged @('branch', '-M', 'main')
    Invoke-FixtureGitJudged @('push', '--quiet', '-u', 'origin', 'main')
    Invoke-FixtureGitJudged @('checkout', '--quiet', '-b', $prBranch)

    $env:CLAUDE_PROJECT_DIR = $prFixtureRoot
    $env:GH_ARGS_CAPTURE = $prArgsCapture
    $env:GH_BODY_CAPTURE = $prBodyCapture

    # Scenario A: default path -- no repo-config overrides defined (today's behavior, unchanged).
    Copy-Item -Path (Join-Path $RepoRoot 'scripts\repo-config.ps1') -Destination (Join-Path $prFixtureRoot 'scripts\repo-config.ps1') -Force
    Copy-Item -Path (Join-Path $RepoRoot '.github\pull_request_template.md') -Destination (Join-Path $prFixtureRoot '.github\pull_request_template.md') -Force
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    $codeA = $null
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String) | Out-Null
    $codeA = $LASTEXITCODE
    Assert-Equal 0 $codeA 'default path: open-pr exits 0'
    $argsA = if (Test-Path $prArgsCapture) { Get-Content -Path $prArgsCapture -Raw } else { '' }
    $bodyA = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($argsA -ne '') 'default path: fake gh pr create was invoked'
    Assert-True ($argsA -notmatch '--assignee') 'default path: no --assignee passed (no repo-config override)'
    Assert-True ($argsA -notmatch '--milestone') 'default path: no --milestone passed (no repo-config override)'
    Assert-True ($bodyA -match 'This is the test description text\.') 'default path: description filled in from the changelog entry'
    # The placeholder assert reads the template it actually copied rather than a remembered string --
    # that coupling has its own guard in pr-body.tests.ps1, and hard-coding it twice is how the two
    # drift apart. What matters here is that WHATEVER the repo ships got substituted.
    $templateCommentsA = @(Get-Content -LiteralPath (Join-Path $prFixtureRoot '.github\pull_request_template.md') -Encoding UTF8 |
        Where-Object { $_.Trim() -match '^<!--.*-->$' })
    foreach ($commentA in $templateCommentsA) {
        Assert-True ($bodyA -notmatch [regex]::Escape($commentA.Trim())) "default path: the template comment was replaced, not published ($($commentA.Trim().Substring(0, [Math]::Min(28, $commentA.Trim().Length)))...)"
    }
    # NO CHECKBOXES AT ALL SINCE #538, and asserted rather than left implied. The repo's template was cut
    # down to one section on 2026-08-09 because measured over 60 PRs not one of its boxes ever varied:
    # 'Type of change' had exactly one of four ticked every time, two checklist items were ticked 60/60
    # by this very script, and the two called "human judgement checks" were ticked 0/60 by anyone. A body
    # that grows a checkbox again means the template regained a section, which is the thing to notice.
    Assert-True ($bodyA -notmatch '(?m)^- \[[ x]\]') 'default path: the body carries no checkbox -- the repo template is the entry and nothing else'

    # THE TITLE IS COMPOSED, AND NOTHING WAS PASSED TO COMPOSE IT FROM (#506 + #505). This is the only
    # end-to-end proof of the derivation: Get-PrTitle's own asserts are pure-string, and what could still go
    # wrong here is the wiring -- the prefix read off the wrong thing, or the words read out of the wrong
    # section. It is also the legacy half of the rule: this entry has NO title section at all, so the words
    # come from its heading with the administrative fields dropped, which is what lets a branch created
    # before the split still open a PR after a plugin update.
    Assert-True ($argsA -match '(?m)^--title$') 'default path: a title was passed to gh even though none was given on the command line'
    Assert-True ($argsA -match '(?m)^feat: Open-PR 101 test$') 'default path: the title is the branch type plus the entry heading, with the type and date fields dropped'

    # --- Scenario A2: a CONSUMER's template, which is the pre-#538 shape ---------------------------
    #
    # WHY THIS EXISTS AT ALL. Ticking those boxes used to be proved incidentally by scenario A, because
    # this repo's own template carried them. It no longer does -- and the ticking logic stayed, on the
    # standing rule that a consumer's PR template is THEIR file: every consumer has these sections right
    # now and receives this script through a plugin update rather than by choosing to. Deleting the fill
    # logic in the same change would have left their forms blank, and deleting the asserts with it would
    # have left nothing watching the logic that was kept. So the case moved from incidental to explicit,
    # which is strictly better: it now says which shape it is testing and why.
    #
    # This is verbatim the template this repo shipped until 2026-08-09, `chore/` row and all.
    $legacyTemplate = @'
## What does this change do?
<!-- Short description of what changes and why. -->

## Type of change
- [ ] `feat/` new functionality
- [ ] `fix/` correction of an error
- [ ] `docs/` documentation

## Checklist
- [ ] Changelog entry written (`branch/branch-deployment.md`)
- [ ] Shared agent defs change here only

## Explicit approval
- [ ] Requested by Dave (the PR request also counts as merge approval)
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot '.github\pull_request_template.md'), $legacyTemplate, $Utf8NoBomTest)
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String) | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'legacy template: open-pr exits 0'
    $bodyA2 = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($bodyA2 -match 'This is the test description text\.') 'legacy template: description still filled in from the changelog entry'
    Assert-True ($bodyA2 -notmatch '<!-- Short description of what changes and why') 'legacy template: the old placeholder string is still recognised'
    Assert-True ($bodyA2 -match '- \[x\] `feat/`') 'legacy template: type-of-change box still ticked for a consumer'
    Assert-True ($bodyA2 -match '- \[x\] Changelog entry written') 'legacy template: changelog-entry checklist item still ticked'
    Assert-True ($bodyA2 -match '- \[x\] Requested by Dave') 'legacy template: approval checklist item still ticked (default pattern)'
    # The one box the script has never claimed to know: it must stay untouched, or a self-ticking
    # checklist would be asserting something no code verified.
    Assert-True ($bodyA2 -match '- \[ \] Shared agent defs change here only') 'legacy template: the judgement item is NOT ticked by the script'

    # Back to the repo's own template so the scenarios below are not read through this one.
    Copy-Item -Path (Join-Path $RepoRoot '.github\pull_request_template.md') -Destination (Join-Path $prFixtureRoot '.github\pull_request_template.md') -Force

    # Scenario B: override path -- repo-config defines all four optional #101 functions.
    $rcOverride = @'
$script:RepoName = 'DKJ-Solutions/claude-code-specialists'
function Get-RepoName { return $script:RepoName }
function Get-RepoBlobUrl { return "https://github.com/$($script:RepoName)/blob/main/" }
$script:LintScript = 'scripts\lint\check-plugin-integrity.ps1'
function Get-LintScript { return $script:LintScript }
function Get-PrDescriptionPlaceholder { return @('<!-- CUSTOM PLACEHOLDER TEXT -->') }
function Get-PrApprovalPattern { return '^- \[ \] Custom approval line' }
function Get-PrAssignee { return 'octocat' }
function Get-PrMilestone { return 'v9.9.9' }
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'scripts\repo-config.ps1'), $rcOverride, $Utf8NoBomTest)
    $templateOverride = @'
## What does this change do?
<!-- CUSTOM PLACEHOLDER TEXT -->

## Type of change
- [ ] `feat/` custom marker

## Checklist
- [ ] Changelog entry file created (`<branch-name>.md` in the repo root)

## Explicit approval
- [ ] Custom approval line here
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot '.github\pull_request_template.md'), $templateOverride, $Utf8NoBomTest)
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String) | Out-Null
    $codeB = $LASTEXITCODE
    Assert-Equal 0 $codeB 'override path: open-pr exits 0'
    $argsB = if (Test-Path $prArgsCapture) { Get-Content -Path $prArgsCapture -Raw } else { '' }
    $bodyB = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($argsB -match '--assignee') 'override path: --assignee passed through to gh pr create'
    Assert-True ($argsB -match 'octocat') 'override path: assignee value from Get-PrAssignee used'
    Assert-True ($argsB -match '--milestone') 'override path: --milestone passed through to gh pr create'
    Assert-True ($argsB -match 'v9\.9\.9') 'override path: milestone value from Get-PrMilestone used'
    Assert-True ($bodyB -notmatch '<!-- CUSTOM PLACEHOLDER TEXT -->') 'override path: custom description placeholder was replaced (override function actually used)'
    Assert-True ($bodyB -match 'This is the test description text\.') 'override path: description still filled in from the changelog entry'
    Assert-True ($bodyB -match '- \[x\] Custom approval line') 'override path: custom approval pattern (Get-PrApprovalPattern) ticked the custom checklist line'

    # --- Scenario B2: a NEAR-MISS placeholder must be loud (#573) ---------------------------------
    # The failure this guards is the one that looks like success: an exact whole-line comparison, a
    # template one word away from a recognised string, and a run that exits 0 with a PR body carrying
    # no description. Measured at a consumer -- 12 of 60 merged PRs, found by diffing templates rather
    # than by anything failing. Asserted in BOTH directions on purpose: the warning must appear AND
    # the body must genuinely be missing the description, or a passing test would only prove that a
    # message is printed.
    Write-Host "  open-pr: an unrecognised description placeholder warns" -ForegroundColor DarkCyan
    Copy-Item -Path (Join-Path $RepoRoot 'scripts\repo-config.ps1') -Destination (Join-Path $prFixtureRoot 'scripts\repo-config.ps1') -Force
    # One word away from the recognised English string, which is exactly how the consumer's drifted.
    $templateNearMiss = @'
# What does the change on this branch bring to main?
<!-- Brief description of what changes and why. -->
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot '.github\pull_request_template.md'), $templateNearMiss, $Utf8NoBomTest)
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    $outB2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String)
    # WHITESPACE-STRIPPED BEFORE MATCHING, and this cost a red CI run to learn: Write-Warning wraps its
    # text at the HOST's buffer width, which is wide in a developer console and narrow on the runner. The
    # exact same warning therefore arrives here as one line locally and as two on CI, and a match on any
    # phrase long enough to be worth asserting lands straight on the break -- so it is read through
    # Test-OutputContains above, like every other captured phrase in this file.
    #
    # IT COLLAPSED THE BREAK TO A SPACE UNTIL #1742 (September 9, 2026), on the reasoning that "wrapping
    # only ever inserts a newline where a space was, so collapsing whitespace restores the sentence
    # verbatim". That is measurably false: #1736 padded a Write-Error until its break swept every column
    # of a 120-wide render and the formatter broke INSIDE a word 68 times in 480 -- 'dirty working tre e'.
    # This was the second copy of that variant in the tree and the only one genuinely exposed, because
    # unlike find-specialist-mentions.tests.ps1 (the copy #1742 was filed about) these three asserts read
    # a phrase the formatter emitted. Stripping ALL whitespace needs neither property of the renderer.
    Assert-Equal 0 $LASTEXITCODE 'near-miss placeholder: open-pr still exits 0 (a warning, not a refusal)'
    $bodyB2 = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($bodyB2 -notmatch 'This is the test description text\.') 'near-miss placeholder: the description is indeed absent from the body (the defect is reproduced)'
    Assert-True (Test-OutputContains $outB2 'NONE of its lines matched a description placeholder') 'near-miss placeholder: the run warns instead of staying silent'
    Assert-True (Test-OutputContains $outB2 'Get-PrDescriptionPlaceholder') 'near-miss placeholder: the warning names the seam that overrides the list'
    Assert-True (Test-OutputContains $outB2 '<!-- Short description of what changes and why\. -->') 'near-miss placeholder: the warning prints the strings it compared against'
    # The mirror image: with a recognised placeholder the warning must stay away, or it would be
    # noise on every ordinary run and get ignored exactly when it matters.
    Copy-Item -Path (Join-Path $RepoRoot '.github\pull_request_template.md') -Destination (Join-Path $prFixtureRoot '.github\pull_request_template.md') -Force
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    $outB3 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String)
    # The negative assert is read the same way, and it is the one that mattered most: a mangled phrase
    # makes a -notmatch pass, so the collapse variant here would have reported "no warning" for a warning
    # that was printed and merely wrapped mid-word.
    Assert-True (-not (Test-OutputContains $outB3 'NONE of its lines matched a description placeholder')) 'recognised placeholder: no warning on the ordinary path'

    # --- Scenario C: the resolves gate, wired into open-pr (not just its decision table) ----------
    # pr-issues.tests.ps1 asserts the table; this asserts the WIRING -- that the gate actually runs,
    # blocks BEFORE the push/gh call, and that the closing keyword reaches the PR body. The gate is
    # the answer to PRs #341-#343, where eight repaired findings stayed open after the merge.
    Write-Host "  open-pr: the resolves gate" -ForegroundColor DarkCyan
    # Back to the default repo-config + template, so this scenario is not read through scenario B's
    # custom markers.
    Copy-Item -Path (Join-Path $RepoRoot 'scripts\repo-config.ps1') -Destination (Join-Path $prFixtureRoot 'scripts\repo-config.ps1') -Force
    Copy-Item -Path (Join-Path $RepoRoot '.github\pull_request_template.md') -Destination (Join-Path $prFixtureRoot '.github\pull_request_template.md') -Force
    $gateEntry = @'
### Open-PR 101 test - Feat - 2026-07-21

This is the test description text. It repairs the thing reported in #332.
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'feat-openpr-101-test.md'), $gateEntry, $Utf8NoBomTest)
    $env:GH_OPEN_ISSUES = '[{"number":332},{"number":340}]'

    # C1: an open issue is mentioned and no decision is declared -> BLOCKED, and nothing reached gh.
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    # CAPTURED VIA REDIRECT FILES, NOT '2>&1' -- see Invoke-CapturedScript at the top of this file.
    # This scenario used to capture with '& powershell ... 2>&1 | Out-String' and strip all whitespace,
    # on the reasoning that a phrase can only then fail to match if it is genuinely absent "or has other
    # content inserted into the middle of it (the NativeCommandError decoration case)". That parenthesis
    # was the whole defect: the decoration case is not an edge of this capture, it IS this capture, and
    # the asserts below were kept SHORT in the hope of dodging it rather than moved out of its way.
    #
    # Measured August 14, 2026: at width 152, with $openPrSrc at a 95-character path, the parent cut the
    # rendered record after '...open issue(s) #33' and put 'At line:', the source echo, CategoryInfo and
    # FullyQualifiedErrorId between that and the '2, but the PR declares...' remainder. Stripping
    # whitespace cannot rejoin '#33' and '2' across five lines of other text, so the assert on '#332'
    # failed while open-pr.ps1 was doing exactly what it is specified to do. The same commit passed in an
    # 80-column shell on the same machine. Deterministic both ways, twice each -- so it is not flake, it
    # is the console width and the checkout path deciding a verdict about a script.
    #
    # A redirect file receives what the child actually wrote. Test-OutputContains still strips ALL
    # whitespace, because the CHILD's own wrap remains: it can break mid-word ('#33' + newline + '2') or
    # on a space, and collapsing to single spaces only ever survives the second.
    $gateRun = Invoke-CapturedScript -ScriptPath $openPrSrc -ScriptArgs @('-Title', 'feat-openpr-101-test', '-SkipLint', '-SkipTests')
    $gateOutRaw = $gateRun.Out
    $gateCode = $gateRun.Code
    $gateFlat = ($gateOutRaw -replace '\s', '')
    function Test-GatePhrase { param([string]$Phrase) return $gateFlat.Contains(($Phrase -replace '\s', '')) }
    Assert-Equal 1 $gateCode 'resolves gate: open-pr exits 1 when an open issue is mentioned without a decision'
    # The gate must have actually CHECKED. Without this, the degraded path ("cannot check, not
    # blocking") satisfies every other assert in this scenario while the gate never blocks -- which
    # is exactly what a ConvertFrom-Json bug did here: 5.1 hands a parsed JSON array to the pipeline
    # as one object, the [int] cast threw, and the failure was swallowed as "cannot check".
    Assert-True (-not (Test-GatePhrase 'cannot check')) 'resolves gate: it really checked (did not fall back to the degraded path)'
    Assert-True (Test-GatePhrase 'resolves gate') 'resolves gate: the error names the gate'
    Assert-True (Test-GatePhrase '#332') 'resolves gate: the error names the blocking issue'
    Assert-True (-not (Test-Path $prArgsCapture)) 'resolves gate: no PR was created while blocked'

    # C2: -NoResolves is the deliberate way past it, and it closes nothing.
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests -NoResolves 2>&1 | Out-String) | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'resolves gate: -NoResolves lets the PR through'
    $bodyNo = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($bodyNo -ne '') 'resolves gate: -NoResolves still creates the PR'
    Assert-True ($bodyNo -notmatch 'Closes #') 'resolves gate: -NoResolves writes no closing keyword'

    # C3: -Resolves writes one closing line per issue into the body that reaches gh.
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    # Passed exactly as ship-pr.ps1 passes it: one string, over `powershell -File`. This IS the hop
    # where an [int[]] parameter silently became 332340 (comma read as a thousands separator), so the
    # assert below that BOTH numbers come out is the regression guard for that trap.
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests -Resolves '332,340' 2>&1 | Out-String) | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'resolves gate: -Resolves lets the PR through'
    $bodyRes = if (Test-Path $prBodyCapture) { Get-Content -Path $prBodyCapture -Raw } else { '' }
    Assert-True ($bodyRes -match '(?m)^Closes #332$') 'resolves gate: the body closes #332'
    Assert-True ($bodyRes -match '(?m)^Closes #340$') 'resolves gate: the body closes #340'
    Assert-True ($bodyRes -match 'This is the test description text') 'resolves gate: the description survives alongside the closing block'
    Assert-True ($bodyRes -notmatch '332340') 'resolves gate: the comma list did NOT collapse into one number (the -File thousands-separator trap)'

    # C4: the cry-wolf guard, end to end. An entry that only cites PRs must NOT block -- a gate that
    # fires on every branch gets routinely bypassed, which is how it would silently stop working.
    $prOnlyEntry = @'
### Open-PR 101 test - Feat - 2026-07-21

This follows the shape PRs #341-#343 established, see https://github.com/o/r/pull/343.
'@
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'feat-openpr-101-test.md'), $prOnlyEntry, $Utf8NoBomTest)
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $openPrSrc -Title 'feat-openpr-101-test' -SkipLint -SkipTests 2>&1 | Out-String) | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'resolves gate: an entry citing only PRs does not block'
    Assert-True (Test-Path $prArgsCapture) 'resolves gate: that PR was created'

    # C5: an unreachable gh must WARN, not wedge -- the deliberate escape hatch. GH_FAIL_ISSUE_LIST
    # makes the issue query fail while the rest of the fake gh keeps working.
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'feat-openpr-101-test.md'), $gateEntry, $Utf8NoBomTest)
    $env:GH_FAIL_ISSUE_LIST = '1'
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    # Same capture as C1, and for the same reason: the phrase asserted here arrives on the child's
    # stderr (a Write-Warning), so under '2>&1' it is subject to exactly the interruption C1 measured.
    $degradedRun = Invoke-CapturedScript -ScriptPath $openPrSrc -ScriptArgs @('-Title', 'feat-openpr-101-test', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $degradedRun.Code 'resolves gate: a failing issue query does not block the PR'
    Assert-True (Test-OutputContains $degradedRun.Out 'resolves gate cannot check') 'resolves gate: it says out loud that it could not check'
    Remove-Item Env:\GH_FAIL_ISSUE_LIST -ErrorAction SilentlyContinue
    Remove-Item Env:\GH_OPEN_ISSUES -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText((Join-Path $prFixtureRoot 'feat-openpr-101-test.md'), $prEntryContent, $Utf8NoBomTest)

    Write-Host "  fold-changelog-entry: -RepoRoot override vs. default path" -ForegroundColor DarkCyan
    # THE SKELETON IS FLAT, AND IT USED TO BE PRE-FLAT ('## Pull Requests' + '## Releases'). It was changed
    # on August 10, 2026 by the fix for inbound #561, which is the change that gave those two headings a
    # meaning here: the fold now REFUSES a document carrying section headings at the entry level, so this
    # fixture described a document the workflow declines to write into -- and the six asserts below, whose
    # subject is which TREE the fold writes to, went red over the shape of the file instead. A fixture
    # describing a document the workflow refuses is not a minimal fixture, it is a different program.
    #
    # Worth keeping in mind rather than only fixing: this fixture is the evidence that the pre-flat shape was
    # accepted silently until then. It folded, exit 0, into the wrong place, in this repo's own suite. The
    # refusal itself is covered where it belongs, in fold-changelog.tests.ps1.
    $changelogSkeleton = @'
# Changelog

Everything merged since the last release, furthest reach first.
'@
    # THE CHANGELOG SEAM IS STATED, NOT INFERRED (issue #998, August 27, 2026). These fixtures keep
    # CHANGELOG.md at their root and assert on it there. That used to follow from the marketplace stub
    # below -- Get-DefaultChangelogPath returned the root answer for any repo publishing plugins -- and
    # #998 retired that branch, so the computed default isolates for every repo now. Stating the seam is
    # not a workaround: it is exactly the migration that collapse documents for a repo keeping its
    # changelog at the root, and the same shape fold-changelog.tests.ps1 already patches in.
    $rcMinimal = @'
$script:RepoName = 'DKJ-Solutions/claude-code-specialists'
function Get-RepoName { return $script:RepoName }
function Get-ChangelogPath { return 'CHANGELOG.md' }
'@
    $targetEntryContent = @'
### Fold RepoRoot Test - Chore - 2026-07-21

Testing the -RepoRoot parameter.
'@
    # Flat for the same reason as the skeleton above. The decoy's asserts are byte-identity ones, so any
    # content would pass them -- which is exactly why it should not be a shape this workflow refuses: the
    # next reader would take it as the format a consumer's changelog has.
    $decoyChangelog = @'
# Changelog

DECOY-MARKER-MUST-STAY
'@
    $decoyEntryContent = @'
### DECOY entry - must not be touched - Chore - 2026-07-21

Decoy body.
'@
    $defaultEntryContent = @'
### Fold Default Path Test - Chore - 2026-07-21

Testing the default (no -RepoRoot) path.
'@

    # .claude-plugin/marketplace.json (issue #885): these three fixtures put CHANGELOG.md at ROOT and
    # assert on it there -- Get-DefaultChangelogPath tests exactly this file's presence, so without it
    # each fixture reads as a CONSUMER and the fold isolates into a dkj-policy/ that does not
    # exist here, which is a different failure than the one this scenario is about.
    function New-FoldMarketplaceStub {
        param([Parameter(Mandatory)][string]$Dir)
        New-Item -ItemType Directory -Path (Join-Path $Dir '.claude-plugin') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $Dir '.claude-plugin\marketplace.json'), '{}', $Utf8NoBomTest)
    }

    # Scenario C: -RepoRoot wins over the ambient CLAUDE_PROJECT_DIR (a decoy tree) -- the decoy
    # tree's CHANGELOG.md and entry file must come out byte-identical, unfolded/unremoved.
    New-Item -ItemType Directory -Path (Join-Path $foldTarget 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $foldTarget 'CHANGELOG.md'), $changelogSkeleton, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldTarget 'scripts\repo-config.ps1'), $rcMinimal, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldTarget 'chore-fold-reporoot-test.md'), $targetEntryContent, $Utf8NoBomTest)
    New-FoldMarketplaceStub -Dir $foldTarget

    New-Item -ItemType Directory -Path (Join-Path $foldDecoy 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $foldDecoy 'CHANGELOG.md'), $decoyChangelog, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldDecoy 'scripts\repo-config.ps1'), $rcMinimal, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldDecoy 'chore-fold-reporoot-test.md'), $decoyEntryContent, $Utf8NoBomTest)
    New-FoldMarketplaceStub -Dir $foldDecoy

    $env:CLAUDE_PROJECT_DIR = $foldDecoy  # ambient context -- -RepoRoot must win over this
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $foldSrc -Branch $foldBranch -RepoRoot $foldTarget 2>&1 | Out-String) | Out-Null
    $rrCode = $LASTEXITCODE
    Assert-Equal 0 $rrCode '-RepoRoot: fold exits 0'
    $targetChangelogAfter = Get-Content -Path (Join-Path $foldTarget 'CHANGELOG.md') -Raw
    Assert-True ($targetChangelogAfter -match 'Fold RepoRoot Test') "-RepoRoot: the TARGET tree's CHANGELOG.md received the folded entry"
    Assert-True (-not (Test-Path (Join-Path $foldTarget 'chore-fold-reporoot-test.md'))) '-RepoRoot: the entry file was removed from the TARGET tree'
    $decoyChangelogAfter = Get-Content -Path (Join-Path $foldDecoy 'CHANGELOG.md') -Raw
    Assert-Equal $decoyChangelog $decoyChangelogAfter "-RepoRoot: the DECOY (ambient CLAUDE_PROJECT_DIR) tree's CHANGELOG.md is untouched"
    Assert-True (Test-Path (Join-Path $foldDecoy 'chore-fold-reporoot-test.md')) "-RepoRoot: the DECOY tree's entry file still exists (not removed)"
    $decoyEntryAfter = Get-Content -Path (Join-Path $foldDecoy 'chore-fold-reporoot-test.md') -Raw
    Assert-Equal $decoyEntryContent $decoyEntryAfter "-RepoRoot: the DECOY tree's entry file content is unchanged"

    # Scenario D: default path (regression) -- no -RepoRoot, falls back to CLAUDE_PROJECT_DIR
    # exactly like before #101.
    New-Item -ItemType Directory -Path (Join-Path $foldDefault 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $foldDefault 'CHANGELOG.md'), $changelogSkeleton, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldDefault 'scripts\repo-config.ps1'), $rcMinimal, $Utf8NoBomTest)
    [System.IO.File]::WriteAllText((Join-Path $foldDefault 'chore-fold-reporoot-test.md'), $defaultEntryContent, $Utf8NoBomTest)
    New-FoldMarketplaceStub -Dir $foldDefault
    $env:CLAUDE_PROJECT_DIR = $foldDefault
    (& powershell -NoProfile -ExecutionPolicy Bypass -File $foldSrc -Branch $foldBranch 2>&1 | Out-String) | Out-Null
    $defCode = $LASTEXITCODE
    Assert-Equal 0 $defCode 'default path (no -RepoRoot): fold exits 0'
    $defChangelogAfter = Get-Content -Path (Join-Path $foldDefault 'CHANGELOG.md') -Raw
    Assert-True ($defChangelogAfter -match 'Fold Default Path Test') 'default path (no -RepoRoot): CLAUDE_PROJECT_DIR tree received the folded entry'
    Assert-True (-not (Test-Path (Join-Path $foldDefault 'chore-fold-reporoot-test.md'))) 'default path (no -RepoRoot): entry file removed'
} finally {
    $ErrorActionPreference = $prevEapShared
    Set-Location -Path $prevLoc
    if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    Remove-Item Env:\GH_ARGS_CAPTURE -ErrorAction SilentlyContinue
    Remove-Item Env:\GH_BODY_CAPTURE -ErrorAction SilentlyContinue
    $env:PATH = $prevPath1
    Remove-Item -Path $fakeBin -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $prArgsCapture, $prBodyCapture -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $prFixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $prBareRemote -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $foldTarget -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $foldDecoy -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $foldDefault -Recurse -Force -ErrorAction SilentlyContinue
}

# --- The Skill mapping and Get-ScriptParameterNames (check 18's two inputs) ------------------------------
# Asserted on the REGISTRY and the PARSER rather than on the gate's output: the gate is exercised by
# the four check-plugin-integrity-*.tests.ps1 suites, while what can rot silently here is an entry point that never declares
# a Skill at all -- which would drop out of the check without any assert noticing.
Write-Host ""
Write-Host "Skill mapping + parameter parsing" -ForegroundColor Cyan

# Every non-lib entry must DECLARE a Skill, even if the declaration is '' ("no skill documents this").
# $null means the key is absent, and that is the one state that must not exist: it is how a newly shared
# script would fall out of check 18 unnoticed -- the accumulation shape the LibOnly comment warns about.
$undeclared = @($pairs | Where-Object { -not $_.LibOnly -and $null -eq $_.Skill } | ForEach-Object { $_.Name })
Assert-True ($undeclared.Count -eq 0) "every shared entry point declares a Skill (missing: $($undeclared -join ', '))"

# A lib carries no Skill at all -- it is never invoked, so there is nothing to document.
$libWithSkill = @($pairs | Where-Object { $_.LibOnly -and $null -ne $_.Skill } | ForEach-Object { $_.Name })
Assert-True ($libWithSkill.Count -eq 0) "a LibOnly entry declares no Skill (unexpected: $($libWithSkill -join ', '))"

# A non-empty Skill must name a skill that exists, or the gate reports a typo forever.
foreach ($p in @($pairs | Where-Object { -not $_.LibOnly -and -not [string]::IsNullOrEmpty($_.Skill) })) {
    $skillFile = Join-Path $RepoRoot $p.SkillRel
    Assert-True (Test-Path -LiteralPath $skillFile) "$($p.Name) names an existing skill ('$($p.Skill)' in $($p.Plugin))"
}

# SkillRel and MirrorRel are both DERIVED from the pair's Plugin, so the property that matters is that
# the two cannot disagree: a pair's page is looked for in the same plugin its mirror travels in.
# Without this, the split could move a mirror and leave its page lookup pointing at the plugin it left.
#
# ASSERTED AGAINST THE RESOLVED ROOT, NOT A COMPOSED 'plugins\<name>\' LITERAL. Writing the layout into
# the assertion would make this test the last place in the chain that still knows how deep a plugin
# sits -- and it would fail the day the tree is regrouped, on a change that did not break the invariant
# it is guarding. The roots come from the same marketplace the registry reads.
$rootByPlugin = @{}
foreach ($r in (Get-RepoPluginRoots -RepoRoot $RepoRoot)) { $rootByPlugin[$r.Name] = $r.RelativeRoot }
foreach ($p in @($pairs | Where-Object { $null -ne $_.SkillRel })) {
    $root = $rootByPlugin[$p.Plugin]
    Assert-True ($p.SkillRel -like "$root\skills\*") "$($p.Name): skill page is looked for in the plugin its mirror lives in ($($p.Plugin))"
    Assert-True ($p.MirrorRel -like "$root\*") "$($p.Name): and the mirror is under that same plugin root"
}

# EVERY PAIR NAMES A PLUGIN THIS REPO ACTUALLY PUBLISHES. The registry throws on an unknown name, but
# only in a repo that declares plugins at all -- a repo declaring none yields an empty registry instead,
# which is the right answer for a consumer and for the lint's minimal fixture. That escape hatch is
# exactly what would let a typo here go quiet, so the claim is asserted where it is checkable: here, in
# the repo the registry belongs to.
Assert-True ($pairs.Count -gt 0) 'the registry resolves to a non-empty set in this repo'
foreach ($p in $pairs) {
    Assert-True ($rootByPlugin.ContainsKey($p.Plugin)) "$($p.Name): names a plugin the marketplace declares ('$($p.Plugin)')"
}
Assert-True (@($pairs | Where-Object { $_.LibOnly -and $null -ne $_.SkillRel }).Count -eq 0) 'a LibOnly entry never derives a skill page (nothing invokes it, so there is no procedure to document)'

# The split's own invariant (August 8, 2026): the two halves are separately versioned and separately
# installed, so a mirror may never dot-source a lib that ships in the OTHER plugin -- that would be a
# runtime dependency on a path a version mismatch silently breaks. Asserted by reading each mirror's
# $PSScriptRoot-relative '..\lib\<name>.ps1' dot-sources and checking the lib is registered into the
# same plugin. This is the assertion that would have caught the mention-vs-use misreading that had
# check-report-lib and native-capture-lib filed as shared by both halves.
# Keyed on the lib's FILE NAME and holding a LIST of plugins, because check-report-lib is
# deliberately mirrored into both -- so the question is never "which plugin owns this lib" but "is it
# present in the plugin that dot-sources it".
$libPlugins = @{}
foreach ($p in @($pairs | Where-Object { $_.LibOnly })) {
    $libName = [System.IO.Path]::GetFileNameWithoutExtension($p.MirrorRel)
    if (-not $libPlugins.ContainsKey($libName)) { $libPlugins[$libName] = @() }
    $libPlugins[$libName] += $p.Plugin
}
foreach ($p in @($pairs | Where-Object { -not $_.LibOnly })) {
    $mirrorText = Get-NormalizedScriptContent -Path $p.MirrorPath
    if ($null -eq $mirrorText) { continue }
    foreach ($m in [regex]::Matches($mirrorText, "\.\s+\(Join-Path \`$PSScriptRoot '\.\.\\lib\\([a-z-]+)\.ps1'\)")) {
        $lib = $m.Groups[1].Value
        if (-not $libPlugins.ContainsKey($lib)) { continue }
        Assert-True ($libPlugins[$lib] -contains $p.Plugin) "$($p.Name) finds $lib inside its own plugin ($($p.Plugin)), not across the split"
    }
}

# The parser, not a regex. This is the regression that matters: an attributed parameter
# ([Parameter(Mandatory = $true)][string]$Version) was missed by the regex this replaced, and -Bump was
# the parameter it hid -- the one that says what kind of release you are cutting.
$cutRelease = $pairs | Where-Object { $_.Name -eq 'cut-release' }
$cutParams = @(Get-ScriptParameterNames -Path $cutRelease.SourcePath)
foreach ($expected in @('Version', 'Bump', 'NoPush', 'SkipLint')) {
    Assert-True ($cutParams -contains $expected) "Get-ScriptParameterNames finds -$expected on cut-release (the attributed-parameter case)"
}

# A dot-sourced lib has no param block, and that must be @() rather than a throw -- the gate walks every
# registered pair.
$libPair = $pairs | Where-Object { $_.LibOnly } | Select-Object -First 1
Assert-Equal 0 (@(Get-ScriptParameterNames -Path $libPair.SourcePath).Count) 'a lib with no param block yields no parameters instead of throwing'
Assert-Equal 0 (@(Get-ScriptParameterNames -Path (Join-Path $RepoRoot 'does-not-exist.ps1')).Count) 'a missing file yields no parameters instead of throwing'

# An exemption must name a parameter the script actually has, or it is a dead entry that silently excuses
# nothing -- and reads as if it does.
foreach ($p in @($pairs | Where-Object { $_.SkillParamsExempt.Count -gt 0 })) {
    $actual = @(Get-ScriptParameterNames -Path $p.SourcePath)
    foreach ($ex in $p.SkillParamsExempt) {
        Assert-True ($actual -contains $ex) "$($p.Name): exempted parameter -$ex actually exists on the script"
    }
}

# --- Get-DepthSensitiveResolutions (check 39's input) ---------------------------------------------
# ISSUE #1857. The ONE class of difference a byte-identical mirror can still carry: a $PSScriptRoot
# resolution ascending two levels lands on the repo root from the source copy and on the plugin root
# from the mirror. The gate acts on what this function returns, so its two forms and its one
# deliberate non-subject are pinned here rather than only through the gate's own fixture.
Write-Host ""
Write-Host "Get-DepthSensitiveResolutions" -ForegroundColor Cyan

$depthDir = Join-Path ([System.IO.Path]::GetTempPath()) ("depthres-$PID-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $depthDir -Force | Out-Null
try {
    $depthAscii = New-Object System.Text.UTF8Encoding($false)
    function New-DepthFixture {
        param([string]$Name, [string]$Body)
        $path = Join-Path $depthDir "$Name.ps1"
        [System.IO.File]::WriteAllText($path, $Body, $depthAscii)
        return $path
    }

    # ONE HOP IS NOT A SUBJECT, and this is asserted FIRST on purpose: a detector that returns
    # everything satisfies every positive case below while being worthless as a gate.
    $fOne = New-DepthFixture -Name 'one-hop' -Body ". (Join-Path `$PSScriptRoot '..\lib\x.ps1')`n"
    Assert-Equal 0 (@(Get-DepthSensitiveResolutions -Path $fOne).Count) `
        'a single-hop resolution is not reported -- it is the same folder relative to the file in both copies'

    $fTwo = New-DepthFixture -Name 'two-hop' -Body "`$p = Join-Path `$PSScriptRoot '..\..\blueprint\x.json'`n"
    Assert-Equal 1 (@(Get-DepthSensitiveResolutions -Path $fTwo).Count) `
        'a two-hop literal is reported'

    # FORWARD SLASHES TOO. A consumer-facing script may be written either way, and a detector that
    # only understood backslashes would be silent on exactly the half a reader finds most portable.
    $fSlash = New-DepthFixture -Name 'two-hop-slash' -Body "`$p = Join-Path `$PSScriptRoot '../../blueprint/x.json'`n"
    Assert-Equal 1 (@(Get-DepthSensitiveResolutions -Path $fSlash).Count) `
        'a two-hop literal written with forward slashes is reported too'

    # THE SECOND FORM, and the one that caught this function's own first draft: the same ascent with no
    # '..' anywhere in it. Climbing only to the NEAREST statement stops inside the inner pipeline,
    # where one Split-Path is in scope, so the nesting reads as a single hop and nothing is reported.
    # check-policy-drift's step 4a is written exactly this way, so that draft was silent on one of the
    # two crossings in the tree while reporting the other correctly.
    $fSplit = New-DepthFixture -Name 'split-chain' -Body "`$own = Split-Path (Split-Path `$PSScriptRoot -Parent) -Parent`n"
    Assert-Equal 1 (@(Get-DepthSensitiveResolutions -Path $fSplit).Count) `
        'a nested Split-Path ascent is reported, though it contains no ".." at all'

    $fSplitOne = New-DepthFixture -Name 'split-one' -Body "`$own = Split-Path `$PSScriptRoot -Parent`n"
    Assert-Equal 0 (@(Get-DepthSensitiveResolutions -Path $fSplitOne).Count) `
        'a single Split-Path is not reported -- one hop is one hop in either spelling'

    # THE MULTI-LINE CASE, which is why this reads the AST rather than a window of characters after
    # the variable. A Join-Path whose literal sits on the next line is the same resolution.
    $fWrap = New-DepthFixture -Name 'wrapped' -Body "`$p = Join-Path `$PSScriptRoot ```n    '..\..\blueprint\x.json'`n"
    Assert-Equal 1 (@(Get-DepthSensitiveResolutions -Path $fWrap).Count) `
        'a resolution wrapped across lines is reported -- the statement is the unit, not the line'

    # A '..' that is not LEADING is not an ascent: it is a path that descends and then steps back.
    $fInner = New-DepthFixture -Name 'inner-dots' -Body "`$p = Join-Path `$PSScriptRoot 'a\..\b\..\c'`n"
    Assert-Equal 0 (@(Get-DepthSensitiveResolutions -Path $fInner).Count) `
        'a ".." that is not leading is not an ascent and is not reported'

    Assert-Equal 0 (@(Get-DepthSensitiveResolutions -Path (Join-Path $depthDir 'no-such-file.ps1')).Count) `
        'a missing file yields nothing instead of throwing'
} finally {
    Remove-Item -LiteralPath $depthDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- The MirrorRun declarations, against the tree ---------------------------------------------------
# The gate refuses an UNDECLARED crossing; these hold the declarations themselves honest, which is the
# half a gate scanning for the defect cannot see. A declaration that names a suite that is not there,
# or one that has stopped naming the mirror, reads as proof while proving nothing.
foreach ($p in @($pairs | Where-Object { $_.MirrorRun })) {
    $suite = Join-Path $RepoRoot "scripts\tests\$($p.MirrorRun)"
    Assert-True (Test-Path -LiteralPath $suite -PathType Leaf) `
        "$($p.Name): the declared MirrorRun suite '$($p.MirrorRun)' exists"
    if (Test-Path -LiteralPath $suite -PathType Leaf) {
        $suiteText = [System.IO.File]::ReadAllText($suite, [System.Text.Encoding]::UTF8)
        Assert-True ($suiteText.Contains($p.MirrorRel)) `
            "$($p.Name): that suite names the mirror it is declared to run"
    }
    Assert-True (-not $p.MirrorRunExempt) `
        "$($p.Name): declares MirrorRun, so it does not also declare MirrorRunExempt -- they are opposite answers"
}

# EVERY CROSSING IN THE TREE IS DECLARED. The same invariant check 39 enforces, asserted here too --
# deliberately, because the gate is skippable per category (-SkipCheck) and this suite is not.
foreach ($p in @($pairs)) {
    if (-not (Test-Path -LiteralPath $p.SourcePath -PathType Leaf)) { continue }
    if (@(Get-DepthSensitiveResolutions -Path $p.SourcePath).Count -eq 0) { continue }
    Assert-True ([bool]($p.MirrorRun -or $p.MirrorRunExempt)) `
        "$($p.Name): crosses the plugin-root boundary off `$PSScriptRoot, and declares how its mirror is proven"
}

Write-Host ""
# ABOVE THE VERDICT AND EVEN ON A GREEN RUN: a clean sweep over a fixture repo that was never built
# proves less than it appears to, so the count decides the exit code too (issue #1635).
$fixtureBroken = Write-FixtureGitSummary -Subject 'the shared-scripts mechanics'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
