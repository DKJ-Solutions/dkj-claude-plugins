<#
.SYNOPSIS
    Regression tests for the `orchestrator` skill (inbound #669 B1): the route that puts Chris into a
    session where no repo CLAUDE.md can carry his @-import.

.DESCRIPTION
    The subject is a property, not prose: THIS SKILL MUST NEVER SHELL OUT. Every other .ps1-wrapping
    skill in this family is fine to run a script, because a repo that has one also has a machine to run
    it on. This one exists for the opposite case -- a session with no repo, measured in a Linux cloud
    container where `powershell` answers exit 127 -- so a script here would fail in exactly the
    environment the skill was written for, and nowhere else. That is the worst kind of defect: green on
    the maintainer's machine, broken only for the audience it was built for.

    The persona path is asserted for the same reason. The skill tells the reader to open one file; if
    that file moves or is renamed, the skill still reads perfectly and does nothing at all.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/orchestrator-skill.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

$skillPath   = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\skills\orchestrator\SKILL.md'
$personaPath = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\personas\specialist-01-01-persona.md'

Write-Host "orchestrator skill -- it exists and names itself" -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $skillPath) 'the skill page is where the plugin expects it'
$text = if (Test-Path -LiteralPath $skillPath) { [System.IO.File]::ReadAllText($skillPath, [System.Text.Encoding]::UTF8) } else { '' }
Assert-True ($text -match '(?m)^name:\s*orchestrator\s*$') 'its frontmatter registers the name the README enumerates'

Write-Host "orchestrator skill -- it runs NO script, which is the whole point" -ForegroundColor Cyan
# The environment this skill is for has no PowerShell. Any of these would make it fail there and only
# there -- so they are asserted as absent rather than left to review.
foreach ($forbidden in @('powershell -NoProfile', 'pwsh ', '.ps1', 'bash -c', 'Invoke-Expression')) {
    Assert-True (-not ($text -like "*$forbidden*")) "no '$forbidden' anywhere in the page"
}

Write-Host "orchestrator skill -- the file it tells you to open actually exists" -ForegroundColor Cyan
Assert-True ($text -match '\$\{CLAUDE_PLUGIN_ROOT\}/personas/specialist-01-01-persona\.md') 'it names the persona through the plugin-root variable, not a machine path'
Assert-True (Test-Path -LiteralPath $personaPath) 'and that persona file is really there'
# A skill that points at a moved file reads perfectly and does nothing. Held against the real tree
# rather than against a second copy of the path.
$personaRel = 'plugins\dkj-subagents\dkj-subagents-alpha\personas\specialist-01-01-persona.md'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot $personaRel)) 'the asserted path is the one the plugin ships'

Write-Host "orchestrator skill -- it points a repo consumer somewhere else" -ForegroundColor Cyan
# Without this the skill competes with the @-import: it would load the portable half over a session
# that already has the portable half PLUS the repo lens, which is strictly worse and silently so.
Assert-True ($text -match 'specialists-init') 'it names the bootstrap as the better route inside a repo'
Assert-True ($text -match '(?i)repo lens') 'and says what the import brings that this skill cannot'

Write-Host "orchestrator skill -- it is model-invocable on purpose" -ForegroundColor Cyan
# The opposite decision from specialists-init/teardown/sync-roster, which were locked down on the same
# day (inbound #669 B2) because they write files through a script. This one reads one file and changes
# nothing on disk, so a model reaching for it when a conversation needs routing is the intended use.
#
# THE SUBJECT IS THE FRONTMATTER KEY, NOT THE WORD. This read the whole page until August 29, 2026, and
# it cost a false failure the first time the page discussed the flag: the pre-bootstrap section names
# `disable-model-invocation` because a refusal read as the owner's settled policy is one of the three
# rule-gaps it tables (inbound #1107). That is the page explaining a neighbouring skill's flag, which is
# exactly the distinction this repo's [lifecycle] check already draws between a bare mention and a
# declaration. So the assert reads the frontmatter block alone -- where the key would actually take
# effect -- and the body is free to talk about it.
$frontmatter = if ($text -match '(?s)\A---\r?\n(.*?)\r?\n---\r?\n') { $Matches[1] } else { '' }
Assert-True ($frontmatter -ne '') 'the page has a frontmatter block to hold the flag'
Assert-True (-not ($frontmatter -match 'disable-model-invocation')) 'no disable-model-invocation in the frontmatter -- reading a persona is not a state change'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
