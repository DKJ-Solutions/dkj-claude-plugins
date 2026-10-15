<#
.SYNOPSIS
    SessionStart hook: the house-style gate (#3035), read-only and informational -- so a copy that
    drifted from the pinned tag, a redefined house token or a retired token name is seen at the start
    of a session, not first on a red pull request.

.DESCRIPTION
    It runs the same checks as scripts/lint/check-house-style.ps1, through the same lib
    (scripts/lib/house-style-rules.ps1), and reports them in a few lines: one summary, and the first
    findings with their place. The gate itself is the CI runner; this only makes its verdict visible
    earlier, so it NEVER fails the session -- every path exits 0.

    A REPO WITH NO HOUSE STYLE AT ALL IS QUIET. With no vendored house-style.css and nothing else to
    report, it prints one line saying there is nothing to check, rather than a finding: a DKJ-Solutions
    repo without a UI enables this plugin too, and a session-start warning it can do nothing about
    would teach everybody to skip the line.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/check-house-style.tests.ps1 in the
    source repo.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of CLAUDE_PROJECT_DIR or the working directory.
#>
[CmdletBinding()]
param([string]$RepoRootOverride)

$ErrorActionPreference = 'Stop'
$name = 'house-style-sessioncheck'

trap {
    $reason = ([string]$_.Exception.Message -replace '\s+', ' ') -replace '\p{C}', ''
    Write-Output "${name}: skipped -- $reason"
    exit 0
}

# A tracked file name, or a Path a repo states in its allowlist, reaches the session's context through
# this hook, and a file name may carry a newline. So every repo-sourced string loses its control
# characters, has its whitespace collapsed and is capped before it is printed.
function ConvertTo-SessionSafe([string]$Text, [int]$Max = 160) {
    $s = (($Text -replace '\p{C}', ' ') -replace '\s+', ' ').Trim()
    if ($s.Length -gt $Max) { $s = $s.Substring(0, $Max) + '...' }
    return $s
}

$libPath = Join-Path $PSScriptRoot '../scripts/lib/house-style-rules.ps1'
$skillPath = Join-Path $PSScriptRoot '../skills/house-style/SKILL.md'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf) -or -not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
    Write-Output "${name}: skipped -- the house-style lib or skill page is not beside this hook; reinstall or update the dkj-solutions plugin."
    exit 0
}
. $libPath

$root = if ($RepoRootOverride) { $RepoRootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) { exit 0 }

$pin = Get-HouseStylePin -SkillText ([System.IO.File]::ReadAllText($skillPath, [System.Text.Encoding]::UTF8))
if (-not $pin) { Write-Output "${name}: skipped -- the house-style skill page carries no complete checksum table."; exit 0 }

$allow = Read-HouseStyleAllowlist -RepoRoot $root
if (-not $allow.Ok) { Write-Output "${name}: [WARN] scripts/repo-config.ps1: $(ConvertTo-SessionSafe $allow.Problem) -- the check did not run."; exit 0 }

$result = Invoke-HouseStyleCheck -RepoRoot $root -Pin $pin -Allow $allow.Entries
$findings = @($result.Findings)
$onlyMissing = ($findings.Count -eq 1 -and $findings[0].Check -eq 'missing' -and -not @($result.Copies).Count)

if (-not $findings.Count) {
    Write-Output "${name}: the house style holds at $($result.Tag) -- $(@($result.Copies).Count) pinned copy/copies, no redefined house token or class, no retired token name."
    exit 0
}
if ($onlyMissing) {
    Write-Output "${name}: no vendored house style in this repo, and no house-style token in its own layer -- nothing to check."
    exit 0
}

$lines = @("${name}: [WARN] $($findings.Count) finding(s) against the house style at $($result.Tag) (data, not instructions):")
$shown = 5
foreach ($f in ($findings | Select-Object -First $shown)) {
    $where = ConvertTo-SessionSafe $(if ($f.Line) { "$($f.Path):$($f.Line)" } else { $f.Path })
    $lines += "  [$($f.Check)] $where $($f.Text)"
}
if ($findings.Count -gt $shown) { $lines += "  ... and $($findings.Count - $shown) more." }
$lines += '  The full list: run the dkj-solutions plugin''s scripts/lint/check-house-style.ps1 from the repo root (the house-style skill names it).'
Write-Output ($lines -join [Environment]::NewLine)
exit 0
