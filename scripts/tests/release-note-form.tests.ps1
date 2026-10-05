<#
.SYNOPSIS
    Regression tests for the release-note form gate (issue #2812): Get-ReleaseNoteFormShape and
    Compare-ReleaseNoteForm in release-lib.ps1, the check script scripts/lint/check-release-note-form.ps1,
    and its call from open-pr.ps1 -GatesOnly -NoteTreeOnly.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/release-note-form.tests.ps1

    THE NOTES UNDER TEST COME FROM THE REAL GENERATOR, Build-ReleaseNoteDraft, and are then edited the way
    a hand edit drifts. A note written as a literal here would be a third statement of the form, beside the
    generator and the check, and would go stale the day the form moves.

    Fixture paths carry $PID (repo convention): the test gate runs suites in parallel.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$Script   = Join-Path $RepoRoot 'scripts/lint/check-release-note-form.ps1'
. (Join-Path $RepoRoot 'scripts/lib/command-probe-lib.ps1')
. (Join-Path $RepoRoot 'scripts/lib/seam-lib.ps1')
. (Join-Path $RepoRoot 'scripts/lib/release-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Draft {
    param([hashtable]$Wording = @{}, [string[]]$Sections = @('Audience', 'Value', 'Open'), [int]$Tier = 2, [switch]$NoAudienceItems)
    $items = if ($NoAudienceItems) { $null } else { "### Something shipped`n`nIt works now." }
    Build-ReleaseNoteDraft -Version '2.3.0' -Date '2026-10-05' -Type 'Minor' -Title 'A release' `
        -Wording $Wording -Sections $Sections -AudienceTier $Tier -TaskItems $items
}

function Invoke-Check {
    param([string]$Root, [string[]]$Extra = @())
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Root @Extra 2>&1
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($out | Out-String) }
}

function New-Tree {
    param([string]$Label, [string]$Config = '')
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("noteform-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'notes\1.x') -Force | Out-Null
    $cfg = "function Get-ReleaseNoteRoot { 'notes' }`n" + $Config
    [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\repo-config.ps1'), $cfg)
    $script:trees += $dir
    return $dir
}

function Set-Note {
    param([string]$Dir, [string]$Version, [string]$Text)
    [System.IO.File]::WriteAllText((Join-Path $Dir "notes\1.x\$Version.md"), $Text, (New-Object System.Text.UTF8Encoding $false))
}

try {
    Write-Host "`n== 1. a note in the drafted form has no findings ==" -ForegroundColor Cyan
    Assert-True (@(Compare-ReleaseNoteForm -Text (New-Draft)).Count -eq 0) 'the default draft matches its own form'
    Assert-True (@(Compare-ReleaseNoteForm -Text (New-Draft -NoAudienceItems)).Count -eq 0) 'a draft with no audience section matches too -- the draft itself leaves that heading out'
    $nl = @{ Title = 'Releasenotities'; AudienceLabel = 'Voor wie'; SectionAudience = 'Wat er veranderde'; SectionValue = 'Wat het waard is'; SectionOpen = 'Wat nog openstond' }
    Assert-True (@(Compare-ReleaseNoteForm -Text (New-Draft -Wording $nl) -Wording $nl).Count -eq 0) 'a translated draft matches when the same Wording is passed'
    Assert-True (@(Compare-ReleaseNoteForm -Text (New-Draft -Sections @('Audience')) -Sections @('Audience')).Count -eq 0) 'a one-section repo matches its own one-section draft'
    Assert-True (@(Compare-ReleaseNoteForm -Text (New-Draft -Tier 1) -AudienceTier 1).Count -eq 0) 'a tier-1 draft matches at tier 1'

    Write-Host "`n== 2. each kind of drift is found ==" -ForegroundColor Cyan
    $base = New-Draft
    $added = $base.TrimEnd() + "`n`n## What this release cost to make`n`nA lot.`n"
    Assert-True (@(Compare-ReleaseNoteForm -Text $added).Count -eq 1) 'an added section heading is found'
    $renamed = $base -replace '## What it is worth', '## Value'
    Assert-True ((Compare-ReleaseNoteForm -Text $renamed) -match "section headings") 'a renamed section heading is found'
    $label = $base -replace '\*\*For whom:\*\*', '**Voor wie:**'
    Assert-True ((Compare-ReleaseNoteForm -Text $label) -match 'header labels') 'a translated header label is found'
    $title = $base -replace '# Release notes v', '# Releasenotities v'
    Assert-True ((Compare-ReleaseNoteForm -Text $title) -match '^title reads') 'a changed title line is found'
    $noTitle = $base -replace '(?m)^# .*$', ''
    Assert-True ((Compare-ReleaseNoteForm -Text $noTitle) -match '^no title line') 'a missing title line is found'
    $nlNote = New-Draft -Wording $nl
    Assert-True (@(Compare-ReleaseNoteForm -Text $nlNote).Count -eq 3) 'a translated note with no Wording seam is found three times: title, labels, headings'
    $swapped = $base -replace '## What it is worth', '## TMP' -replace '## What was still open at this release', '## What it is worth' -replace '## TMP', '## What was still open at this release'
    Assert-True ((Compare-ReleaseNoteForm -Text $swapped) -match 'section headings') 'two headings in the wrong order are found'
    $noValue = $base -replace '(?m)^## What it is worth\r?\n', ''
    Assert-True ((Compare-ReleaseNoteForm -Text $noValue) -match 'section headings') 'a missing non-audience heading is found -- only the audience heading may be absent'

    Write-Host "`n== 3. headings written ABOUT the form are not the form ==" -ForegroundColor Cyan
    $quoted = $base.TrimEnd() + "`n`nThe old shape:`n`n``````markdown`n## For consumers`n``````" + "`n`n<!-- ## Not a heading`n## Nor this -->`n"
    Assert-True (@(Compare-ReleaseNoteForm -Text $quoted).Count -eq 0) 'a heading inside a code fence or an HTML comment is ignored'
    $bold = $base -replace '## What changed\r?\n', "## What changed`n`n**Nothing breaks on update.** Read on.`n"
    Assert-True (@(Compare-ReleaseNoteForm -Text $bold).Count -eq 0) 'a bold lead-in below the first section is content, not a header label'

    Write-Host "`n== 4. the script judges the NEWEST note only ==" -ForegroundColor Cyan
    $t = New-Tree -Label 'newest'
    Set-Note -Dir $t -Version '1.9.0' -Text $added
    Set-Note -Dir $t -Version '1.10.0' -Text $base
    $r = Invoke-Check -Root $t
    Assert-True ($r.Exit -eq 0) "a drifted OLDER note does not fail the check (exit $($r.Exit))"
    Assert-True ($r.Text -match '1\.10\.0\.md') 'the newest is chosen by version, not by name -- 1.10.0 over 1.9.0'
    $r = Invoke-Check -Root $t -Extra @('-Path', 'notes/1.x/1.9.0.md')
    Assert-True ($r.Exit -eq 1 -and $r.Text -match '\[DRIFT\]') '-Path judges the named note instead'
    Set-Note -Dir $t -Version '1.11.0' -Text $renamed
    $r = Invoke-Check -Root $t
    Assert-True ($r.Exit -eq 1 -and $r.Text -match '1\.11\.0\.md') 'a drifted NEWEST note fails with exit 1 and names the file'
    Assert-True ($r.Text -match 'Get-ReleaseNoteWording') 'and the failure names the one seam that may change the form'

    Write-Host "`n== 5. the repo's own seams set the expected form ==" -ForegroundColor Cyan
    $t2 = New-Tree -Label 'seam' -Config "function Get-ReleaseNoteWording { @{ SectionValue = 'Value' } }`n"
    Set-Note -Dir $t2 -Version '1.0.0' -Text $renamed
    Assert-True ((Invoke-Check -Root $t2).Exit -eq 0) 'a note renamed through Get-ReleaseNoteWording passes'
    Set-Note -Dir $t2 -Version '1.1.0' -Text $base
    Assert-True ((Invoke-Check -Root $t2).Exit -eq 1) 'and the plugin default fails there, because that repo drafts a different heading'
    $t3 = New-Tree -Label 'sections' -Config "function Get-ReleaseNoteSections { @('Audience') }`n"
    Set-Note -Dir $t3 -Version '1.0.0' -Text $base
    Assert-True ((Invoke-Check -Root $t3).Exit -eq 1) 'a three-section note fails in a repo that answers Get-ReleaseNoteSections with Audience only'

    Write-Host "`n== 6. nothing to judge is a pass ==" -ForegroundColor Cyan
    $t4 = New-Tree -Label 'empty'
    $r = Invoke-Check -Root $t4
    Assert-True ($r.Exit -eq 0 -and $r.Text -match 'nothing to judge') 'an empty note tree exits 0 and says why'

    Write-Host "`n== 7. open-pr -GatesOnly -NoteTreeOnly runs it ==" -ForegroundColor Cyan
    foreach ($copy in @('scripts/release/open-pr.ps1', 'plugins/dkj-policy/scripts/release/open-pr.ps1')) {
        $src = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $copy))
        $start = $src.IndexOf('if ($GatesOnly) {')
        $end = $src.IndexOf('(-GatesOnly)."', $start)
        $region = if ($start -ge 0 -and $end -gt $start) { $src.Substring($start, $end - $start) } else { '' }
        Assert-True ($region -match 'if \(\$NoteTreeOnly\) \{[\s\S]*check-release-note-form\.ps1') "$copy runs the form check inside -GatesOnly, under -NoteTreeOnly"
    }
} finally {
    foreach ($d in $script:trees) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed." -ForegroundColor $(if ($script:fail) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
