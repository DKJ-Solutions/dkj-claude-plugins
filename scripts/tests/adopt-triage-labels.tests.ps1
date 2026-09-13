<#
.SYNOPSIS
    Tests for scripts/task/adopt-triage-labels.ps1 -- the print-only adopter for the four canonical
    'prio-1'..'prio-4' triage labels (issue #1895, split from #1843).

.DESCRIPTION
    WHAT IS COVERED, AND WHY THESE PROPERTIES:

      1. IT NEVER RUNS `gh label create`, ANYWHERE, EVER -- the whole point of the script (Dave's
         decision on #1895: print, not apply, the same shape Get-MissingLabelNote already established
         for a PR label). Checked TWO ways: there is no -Apply parameter at all (unlike
         adopt-ci-floor.ps1, which has one for its local workflow files but never for the ruleset
         itself), and no Invoke-NativeCapture call in the script's own source ever passes 'create' as a
         `gh label` argument -- so even a future accidental rewiring could not quietly start applying.
      2. EVERY MISSING LABEL PRINTS A PASTE-READY COMMAND with the exact name, colour and description,
         and an EXISTING one (case-insensitive) is reported '[ok]' and left alone -- no drift check on
         colour/description, which #1895 scoped out.
      3. AN UNREADABLE LABEL LIST is '[skip]', never a false '[missing]' -- the same "unknowable is not
         absent" contract Get-MissingLabelNote already documents for its own caller.
      4. THE SEAM IS ACTUALLY READ, NOT MERELY DEFINED: a consumer's own Get-TriageLabels overrides the
         script's built-in fallback, and the fallback is exercised only when the seam is absent.
      5. THE TWO CANONICAL COPIES -- this script's own built-in fallback and
         scripts/repo-config.ps1's Get-TriageLabels -- are held byte-identical to each other, because a
         consumer who has not adopted the seam yet must be told the SAME set as one who has.
      6. ALWAYS EXITS 0 -- this is a report, never a gate.

    THE LABEL PAYLOAD ARRIVES FROM A FIXTURE FILE, via -LabelJsonOverride, for the same reason
    adopt-ci-floor.tests.ps1 uses -RulesJsonOverride: a test tree is not a checkout, has no remote,
    and CI has no token that could list a real repo's labels. EVERY FIXTURE CONSUMER ALSO DEFINES
    Get-RepoName in its own scripts/repo-config.ps1, so the script's `gh repo view` fallback (the one
    other native call in it) is never reached either -- this suite is fully network-free.

    TEST-GAP, STATED RATHER THAN HIDDEN: the "no Get-RepoName AND no -LabelJsonOverride" combination,
    where the script would genuinely call `gh repo view`/`gh label list`, is not exercised here, for the
    reason above. adopt-ci-floor.tests.ps1 carries the identical gap for its own `gh repo view`
    fallback, and the underlying resolution code is the same pattern, already proven there.

    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot     = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script       = Join-Path $RepoRoot 'scripts\task\adopt-triage-labels.ps1'
$MirrorScript = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\task\adopt-triage-labels.ps1'
$RepoConfigSrc = Join-Path $RepoRoot 'scripts\repo-config.ps1'
$Fixture      = Join-Path ([System.IO.Path]::GetTempPath()) "adopt-triage-labels-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

# The four canonical labels, in the shape `gh label list --json name,color,description` returns them.
# 'PRIO-3' is deliberately upper-case in the "all present" and "partial" payloads below, to exercise the
# case-insensitive match GitHub itself applies to label names.
#
# NONE OF THE FOUR PRESENT IS DELIBERATELY NOT A BARE '[]', because the script (like
# Get-MissingLabelNote before it) reads an EMPTY read as "unknowable" rather than "the repo has zero
# labels" -- a bare '[]' would collapse into the SAME [skip] branch as an actually unreadable payload,
# testing nothing new. GitHub seeds a handful of default labels on every repository, so a payload naming
# two of THOSE (and none of the four canonical ones) is the realistic shape of "this repo has not
# adopted the convention yet", and it is what lets this scenario reach the [missing] branch at all.
$LabelsNone    = '[{"name":"bug","color":"d73a4a","description":"unrelated default label"},{"name":"enhancement","color":"a2eeef","description":"unrelated default label"}]'
$LabelsAll     = '[{"name":"prio-1","color":"006B75","description":"old text"},{"name":"prio-2","color":"FBCA04","description":"old text"},{"name":"PRIO-3","color":"D93F0B","description":"old text"},{"name":"prio-4","color":"B60205","description":"old text"}]'
$LabelsPartial = '[{"name":"prio-1","color":"006B75","description":"old text"},{"name":"PRIO-3","color":"D93F0B","description":"old text"}]'
$LabelsBad     = 'not json'

function New-LabelsFile {
    param([string]$Label, [string]$Json)
    $p = Join-Path $Fixture "labels-$Label.json"
    [System.IO.File]::WriteAllText($p, $Json)
    return $p
}

# Every fixture consumer defines Get-RepoName, so the script's `gh repo view` fallback is never
# reached (see the header's Test-gap note). -CustomTriageLabels writes a Get-TriageLabels of its own,
# to prove the seam is read rather than merely defined; without it the fixture has none, exercising the
# script's built-in fallback.
function New-FixtureConsumer {
    param(
        [string]$Label,
        [string]$RepoName = 'fixture-org/fixture-repo',
        [string]$CustomTriageLabelsBody = ''
    )
    $root = Join-Path $Fixture "consumer-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null

    $lines = @("function Get-RepoName { '$RepoName' }")
    if ($CustomTriageLabelsBody) {
        $lines += "function Get-TriageLabels { $CustomTriageLabelsBody }"
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), (($lines -join "`n") + "`n"))
    return $root
}

function Invoke-Adopt {
    param([string]$Dir, [string]$LabelJsonPath)
    $prevPd = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $Dir
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -LabelJsonOverride $LabelJsonPath
        # Flat is for phrase asserts that might otherwise be split mid-word by the child's own host-width
        # wrapping -- the same reasoning adopt-ci-floor.tests.ps1 documents for its own Invoke-Adopt.
        return [pscustomobject]@{
            Code = $LASTEXITCODE
            Out  = ($out -join "`n")
            Flat = (($out | ForEach-Object { [string]$_ }) -join '')
        }
    } finally {
        if ($null -eq $prevPd) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

try {
    Write-Host '== adopt-triage-labels.tests: scripts/task/adopt-triage-labels.ps1 ==' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
    $fNone    = New-LabelsFile -Label 'none'    -Json $LabelsNone
    $fAll     = New-LabelsFile -Label 'all'     -Json $LabelsAll
    $fPartial = New-LabelsFile -Label 'partial' -Json $LabelsPartial
    $fBad     = New-LabelsFile -Label 'bad'     -Json $LabelsBad

    # --- 1. Never applies: no -Apply parameter, and no native call ever creates a label -------------
    Write-Host '-- 1. print-only, mechanically enforced --' -ForegroundColor Cyan
    $scriptSrc = [System.IO.File]::ReadAllText($Script)
    Assert-True ($scriptSrc -notmatch '\$Apply\b') `
        'no -Apply parameter exists at all -- unlike adopt-ci-floor.ps1, there is no local-file half to apply, so nothing here could ever write a label'
    $createCalls = @([regex]::Matches($scriptSrc, "Arguments\s+@\([^)]*'create'[^)]*\)"))
    Assert-Equal 0 $createCalls.Count 'no Invoke-NativeCapture call in the script ever passes ''create'' as a gh label argument'
    Assert-True ($scriptSrc -match "gh label create") `
        'the literal command DOES appear in the source -- as a printed string, which the next assert confirms is all it is'
    Assert-True ($scriptSrc -match "Write-Host\s+`"\s*gh label create") `
        'and it is printed via Write-Host, not passed to a native call'

    # --- 2. All four missing: the built-in fallback, four paste-ready commands, exit 0 --------------
    Write-Host '-- 2. all four missing (built-in fallback, no seam defined) --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'allmissing'
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fNone
    Assert-Equal 0 $r.Code 'all missing: exit-code 0 -- this is a report, never a gate'
    foreach ($name in @('prio-1', 'prio-2', 'prio-3', 'prio-4')) {
        Assert-True ($r.Out -like "*[missing]*'$name'*") "all missing: '$name' reported [missing]"
    }
    Assert-True ($r.Flat -like "*READ-ONLY*never runs gh label create*") 'all missing: the header states the print-only contract on every run'
    # THE EXACT COMPOSED LINE for one concrete label -- name, colour, description and --repo, quoted
    # exactly as a person would paste it.
    Assert-True ($r.Flat -like "*gh label create 'prio-2' --color 'FBCA04' --description 'Priority 2 of 4 -- worth doing, no pressure' --repo fixture-org/fixture-repo*") `
        "all missing: the composed command for 'prio-2' is exact and paste-ready, including --repo"
    Assert-Equal 0 (@([regex]::Matches($r.Out, '\[ok\]')).Count) 'all missing: zero [ok] lines'
    Assert-True ($r.Flat -like '*4 of 4 canonical triage label(s) missing*') 'all missing: the summary line counts 4 of 4'

    # --- 3. All four present (one in a different case): all [ok], nothing printed to create ---------
    Write-Host '-- 3. all four already exist (one case-differently) --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'allpresent'
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fAll
    Assert-Equal 0 $r.Code 'all present: exit-code 0'
    foreach ($name in @('prio-1', 'prio-2', 'prio-3', 'prio-4')) {
        Assert-True ($r.Out -like "*[ok]*'$name' already exists*") "all present: '$name' reported [ok]"
    }
    Assert-Equal 0 (@([regex]::Matches($r.Out, '\[missing\]')).Count) 'all present: zero [missing] lines'
    Assert-True ($r.Flat -like '*Done: all 4 canonical triage label(s) already exist*') 'all present: the summary line says done'
    # THE CASE-INSENSITIVE MATCH, explicitly: 'PRIO-3' in the payload must satisfy 'prio-3' in the
    # canonical set -- GitHub itself treats the two as the same label, and a case-sensitive compare
    # here would print a create command gh would refuse as a duplicate.
    Assert-True ($r.Out -like "*[ok]*'prio-3' already exists*") "case-insensitive: the payload's 'PRIO-3' satisfies the canonical 'prio-3'"

    # --- 4. Two of four present: a mixed report, correct counts -------------------------------------
    Write-Host '-- 4. two of four already exist --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'partial'
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fPartial
    Assert-Equal 0 $r.Code 'partial: exit-code 0'
    foreach ($name in @('prio-1', 'prio-3')) {
        Assert-True ($r.Out -like "*[ok]*'$name' already exists*") "partial: '$name' reported [ok]"
    }
    foreach ($name in @('prio-2', 'prio-4')) {
        Assert-True ($r.Out -like "*[missing]*'$name'*") "partial: '$name' reported [missing]"
    }
    Assert-True ($r.Flat -like '*2 of 4 canonical triage label(s) missing*2 already exist*') 'partial: the summary line counts both halves'

    # --- 5. An unreadable payload: [skip], never a false [missing] or [ok] -------------------------
    Write-Host '-- 5. an unreadable label payload --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'unreadable'
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fBad
    Assert-Equal 0 $r.Code 'unreadable payload: exit-code 0 -- unknowable is not a failure'
    Assert-True ($r.Out -like '*[skip]*could not read*') 'unreadable payload: reported as [skip]'
    Assert-Equal 0 (@([regex]::Matches($r.Out, '\[missing\]')).Count) 'unreadable payload: no false [missing] lines'
    Assert-Equal 0 (@([regex]::Matches($r.Out, '\[ok\]')).Count) 'unreadable payload: no false [ok] lines either'
    # A path that does not exist at all behaves the same way -- Test-Path fails before anything is read.
    $r2 = Invoke-Adopt -Dir $dir -LabelJsonPath (Join-Path $Fixture 'does-not-exist.json')
    Assert-Equal 0 $r2.Code 'missing override file: exit-code 0'
    Assert-True ($r2.Out -like '*[skip]*could not read*') 'missing override file: also reported as [skip]'

    # --- 6. The seam is READ, not merely defined: it overrides the built-in fallback ----------------
    Write-Host '-- 6. a consumer''s own Get-TriageLabels overrides the built-in fallback --' -ForegroundColor Cyan
    $customBody = "@([pscustomobject]@{ Name = 'foo-team-label'; Color = 'abcdef'; Description = 'a made-up team convention' })"
    $dir = New-FixtureConsumer -Label 'customseam' -CustomTriageLabelsBody $customBody
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fNone
    Assert-Equal 0 $r.Code 'custom seam: exit-code 0'
    Assert-True ($r.Out -like "*[missing]*'foo-team-label'*") 'custom seam: the CONSUMER''s own label is what gets reported'
    Assert-True ($r.Flat -like "*gh label create 'foo-team-label' --color 'abcdef' --description 'a made-up team convention' --repo fixture-org/fixture-repo*") `
        'custom seam: and the exact command composes from the seam''s own values'
    foreach ($name in @('prio-1', 'prio-2', 'prio-3', 'prio-4')) {
        Assert-True ($r.Out -notlike "*'$name'*") "custom seam: the built-in canonical '$name' is NOT reported -- the seam fully replaced it"
    }

    # --- 6b. A seam value carrying an APOSTROPHE composes a still-pasteable command (security review, --
    #         issue #1895's own PR). The four built-in canonical labels happen to carry none, which is
    #         exactly why this had zero coverage until now: Get-TriageLabels is Adopt='copy' and
    #         Optional, so a consumer is free to answer it with their own free text, and test 6 above
    #         already proves the seam fully replaces the built-in set. An unescaped apostrophe in
    #         Name, Color or Description would close the surrounding '...' early in the composed
    #         `gh label create` line, and everything after it would spill out as separate shell tokens
    #         the moment a person pastes it -- which is the whole point of a script that never runs the
    #         command itself: the printed line IS the product.
    Write-Host '-- 6b. a seam value carrying an apostrophe still composes a pasteable command --' -ForegroundColor Cyan
    # Concrete examples named in the review: "won't wait" and "team's convention" -- one label's Name
    # carries an apostrophe, the other's Description carries two.
    $quoteBody = "@([pscustomobject]@{ Name = 'team''s-label'; Color = 'ABCDEF'; Description = 'plain' }, [pscustomobject]@{ Name = 'prio-y'; Color = '123456'; Description = 'it won''t wait, and it''s the team''s convention' })"
    $dir = New-FixtureConsumer -Label 'quoteseam' -CustomTriageLabelsBody $quoteBody
    $r = Invoke-Adopt -Dir $dir -LabelJsonPath $fNone
    Assert-Equal 0 $r.Code 'apostrophe seam: exit-code 0'
    # PowerShell's own escape for a literal quote inside a '...' string is doubling it, so the composed
    # line must read '' wherever the source value carried a bare '.
    Assert-True ($r.Flat -like "*gh label create 'team''s-label' --color 'ABCDEF' --description 'plain' --repo fixture-org/fixture-repo*") `
        'apostrophe seam: an apostrophe in NAME is escaped in the composed command'
    Assert-True ($r.Flat -like "*gh label create 'prio-y' --color '123456' --description 'it won''t wait, and it''s the team''s convention' --repo fixture-org/fixture-repo*") `
        'apostrophe seam: every apostrophe in DESCRIPTION is escaped, not just the first'
    # The '[missing]'/'[ok]' PROSE lines are read by a person and composed into nothing a shell parses,
    # so they are deliberately NOT escaped (see Format-SingleQuotedArg's own docstring) -- asserted here
    # so a future "fix" that escapes them too is a deliberate choice rather than an accident.
    # ONE apostrophe here, not doubled: this is a double-quoted PowerShell string literal in THIS test
    # file, where a bare ' needs no escape at all -- unlike the doubled '' asserted above, which is the
    # composed command's escape of the SAME raw value. Doubling it here by mistake would assert that the
    # prose line escapes too, which it must not (see Format-SingleQuotedArg's own docstring).
    Assert-True ($r.Out -like "*[missing]*'team's-label'*") `
        'apostrophe seam: the prose [missing] line still carries the RAW apostrophe, unescaped -- it is not a shell argument'

    # --- 7. Mirror byte-identity (drift is also covered generically by shared-scripts.tests.ps1; --
    #        asserted here too so whoever edits either copy finds the guard beside the script it touched)
    Write-Host '-- 7. the plugin mirror is LF-identical to the source --' -ForegroundColor Cyan
    Assert-True (Test-Path -LiteralPath $MirrorScript -PathType Leaf) 'the plugin mirror exists'
    if (Test-Path -LiteralPath $MirrorScript -PathType Leaf) {
        $srcNorm    = ([System.IO.File]::ReadAllText($Script) -replace "`r`n", "`n")
        $mirrorNorm = ([System.IO.File]::ReadAllText($MirrorScript) -replace "`r`n", "`n")
        Assert-Equal $srcNorm $mirrorNorm 'source and mirror are LF-identical'
    }

    # --- 8. The two canonical copies never disagree: this script's built-in fallback and ------------
    #        scripts/repo-config.ps1's Get-TriageLabels must be the SAME four literal records, because
    #        an unanswered consumer and an answered one must be told the same set (see both files'
    #        headers for why).
    Write-Host '-- 8. the built-in fallback and Get-TriageLabels agree, byte for byte --' -ForegroundColor Cyan
    # Pulls every '[pscustomobject]@{ Name = ...; Color = ...; Description = ... }' literal line out of
    # a file's raw text, in the order they appear -- both files use the identical single-line-per-record
    # shape, so a plain line match is exact and does not need a PowerShell parse.
    function Get-TriageLiteralLines {
        param([string]$Text)
        return @([regex]::Matches($Text, "\[pscustomobject\]@\{\s*Name\s*=\s*'[^']*';\s*Color\s*=\s*'[^']*';\s*Description\s*=\s*'[^']*'\s*\}") |
            ForEach-Object { $_.Value })
    }
    $repoConfigText = [System.IO.File]::ReadAllText($RepoConfigSrc)
    $scriptLiterals      = @(Get-TriageLiteralLines -Text $scriptSrc)
    $repoConfigLiterals  = @(Get-TriageLiteralLines -Text $repoConfigText)
    Assert-Equal 4 $scriptLiterals.Count 'the script''s own built-in fallback declares exactly four label literals'
    Assert-Equal 4 $repoConfigLiterals.Count 'scripts/repo-config.ps1''s Get-TriageLabels declares exactly four label literals'
    Assert-Equal ($repoConfigLiterals -join "`n") ($scriptLiterals -join "`n") `
        'the built-in fallback and Get-TriageLabels are the exact same four literal records -- an unanswered consumer and an answered one are told the same set'

    # --- 9. The contract record itself (Get-ScriptContract), the same shape reach-label.tests.ps1 ----
    #        already asserts for its neighbouring axis.
    Write-Host '-- 9. the Get-TriageLabels contract record --' -ForegroundColor Cyan
    . (Join-Path $RepoRoot 'scripts\lib\script-contract-lib.ps1')
    $rec = @(Get-ScriptContract | Where-Object { $_.Function -eq 'Get-TriageLabels' })
    Assert-Equal 1 $rec.Count 'the contract declares Get-TriageLabels exactly once'
    if ($rec.Count -eq 1) {
        $c = $rec[0]
        Assert-True ([bool]$c.Optional) 'it is Optional, so an unanswered consumer is not an [ERROR]'
        Assert-Equal 'copy' $c.Adopt "its Adopt is 'copy' -- the value states the shared way of working, not what the repo is"
        Assert-Equal 'scripts\repo-config.ps1' $c.Lib 'it is answered in repo-config.ps1'
        Assert-True ([bool]$c.Returns) 'it carries a Returns line, so a finding is actionable without this source repo'
        Assert-True ($c.Default -like '*adopt-triage-labels.ps1*') "its Default names the script that carries the fallback"
    }
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
