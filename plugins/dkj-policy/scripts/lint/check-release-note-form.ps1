<#
.SYNOPSIS
    Gate: does the newest audience release note still have the form cut-release.ps1 drafts for this repo --
    its title line, its Date / Type / For whom labels, and its section headings in order? (issue #2812)

.DESCRIPTION
    THE RULE IS #2802's, AND THIS IS ITS GATE. The cut-release skill page (step 2) states that the note's
    form is the plugin's and that only Get-ReleaseNoteWording changes it; a lens, a seam comment or a hand
    edit that restates or translates the form is drift. Until this existed, drift was found by reading two
    pages side by side -- measured October 5, 2026, when two BWJ stores' latest notes differed in language,
    header labels and section shape.

    IT ADDS NO RULE OF ITS OWN. Compare-ReleaseNoteForm in release-lib.ps1 draws the expected form from
    Build-ReleaseNoteDraft, called with this repo's own Get-ReleaseNoteWording, Get-ReleaseNoteSections and
    audience tier -- the same three answers cut-release.ps1 passes -- so the check and the cut cannot
    disagree about what the form is.

    ONLY THE NEWEST NOTE IS JUDGED, and that is the answer to the design question #2812 left open. Published
    notes are records and keep the form they were written with, so judging every note would refuse this
    repo's own history (eight of its 5.x notes carry a section the form has since dropped). A cutoff would
    need a second answer per repo -- a version to start from -- that nobody maintains. The newest note is the
    one being finished at the cut's release-notes step, and the one the next writer copies from, so it is
    the one place drift still costs something.

    WHERE IT RUNS. open-pr.ps1 -GatesOnly -NoteTreeOnly runs it after the gates -- the command the
    cut-release skill's step 4 already prescribes before the release-notes commit, so the note is held to
    its form at exactly the moment it was hand-edited. Run it by hand whenever you want the answer early.

    Exit 0 when the form matches, or when there is no note to judge. Exit 1 with one line per difference.
    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Path
    A note to judge instead of the newest one, repo-relative or absolute.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite. A consumer never types this.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-release-note-form.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = '',
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD, as in cut-release.ps1. open-pr runs this as its own sibling, so the copy that
# runs is always the one beside the open-pr that called it -- and the guard passes for exactly that copy.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

$repoRoot = if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) { $RootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else {
    $p = (Get-GitTopLevelPath).Path
    if ($p) { $p } else { '' }
}
if (-not $repoRoot) {
    Write-Host '[OK] no git checkout here -- no release note to judge.'
    exit 0
}

# repo-config first and optional: every answer this check reads is an optional seam, and a repo that has
# answered none is judged against the plugin's defaults -- which is what its cut drafts.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($(Format-SafeProseToken -Value $_.Exception.Message)) -- the plugin's defaults are used." }
}
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\release-lib.ps1')

if ($Path) {
    $notePath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path -LiteralPath $notePath -PathType Leaf)) {
        Write-Error "check-release-note-form: -Path names no file: $notePath"
        exit 1
    }
} else {
    # The default is the cut's own: the same seam and the same fallback cut-release.ps1 writes under.
    $noteRootRel = [string](Get-SeamValue -Name 'Get-ReleaseNoteRoot' -Default 'releases/notes')
    $noteRoot = Join-Path $repoRoot ($noteRootRel -replace '/', '\')
    $notes = @()
    if (Test-Path -LiteralPath $noteRoot -PathType Container) {
        $notes = @(Get-ChildItem -LiteralPath $noteRoot -Recurse -File -Filter '*.md' |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.md$' } |
            Sort-Object { [version]($_.BaseName) } -Descending)
    }
    if ($notes.Count -eq 0) {
        Write-Host "[OK] no release note under $noteRootRel -- nothing to judge."
        exit 0
    }
    $notePath = $notes[0].FullName
}
$noteRel = if ($notePath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $notePath.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
} else { $notePath }

# THE SAME THREE ANSWERS cut-release.ps1 reads, read the same way: the wording under both its names, the
# sections validated by the cut's own resolver, and the tier with the cut's fallback of 2.
$wording = Get-SeamValue -Name 'Get-ReleaseNoteWording', 'Get-InternalNoteWording' -Default @{}
if ($wording -isnot [hashtable]) { $wording = @{} }
try {
    $sections = Resolve-ReleaseNoteSections -Answer (Get-SeamValue -Name 'Get-ReleaseNoteSections' -Default $null)
} catch {
    Write-Error "check-release-note-form: $(Format-SafeProseToken -Value $_.Exception.Message)"
    exit 1
}
$tier = Get-EntryAudienceTier
if ($null -eq $tier) { $tier = 2 }

$text = [System.IO.File]::ReadAllText($notePath, (New-Object System.Text.UTF8Encoding $false))
$findings = @(Compare-ReleaseNoteForm -Text $text -Wording $wording -Sections $sections -AudienceTier $tier)

if ($findings.Count -eq 0) {
    Write-Host "[OK] $noteRel has the form cut-release drafts for this repo."
    exit 0
}
Write-Host "[DRIFT] $noteRel differs from the form cut-release drafts for this repo:" -ForegroundColor Red
foreach ($f in $findings) { Write-Host "  - $f" -ForegroundColor Red }
Write-Host ('  The form is the plugin''s, and only Get-ReleaseNoteWording in scripts/repo-config.ps1 changes it ' +
    '(cut-release skill, step 2). Put the note back in the drafted form, or answer that seam once if this repo ' +
    'genuinely needs other words.') -ForegroundColor Yellow
exit 1
