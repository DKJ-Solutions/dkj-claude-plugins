<#
.SYNOPSIS
    Is it safe to write into this path inside a consumer's checkout, or does the write pass through a
    symlink or junction first? Issue #2533.

.DESCRIPTION
    The adoptions write into files a consumer already has: adopt-workflow-folder.ps1 appends to
    scripts/repo-config.ps1 (#1150) and inserts the constitution import into CLAUDE.md (#2531),
    adopt-extension-import.ps1 inserts the BWJ extension import (#2532), and specialists-init's
    bootstrap.ps1 appends the orchestrator import. A write follows a reparse point without asking, so a
    CLAUDE.md that is a symlink, or a scripts/ directory that is a junction, would have these runs write
    outside the repo root. Get-WriteTargetReparsePoint is the one check each of them makes first.

    THE PATH AND EVERY DIRECTORY BETWEEN IT AND THE ROOT, NOT THE FILE ALONE. A junctioned scripts/
    directory carries a plain repo-config.ps1, so a check of the file's own attributes passes while the
    write still lands outside. The root itself and everything above it are not judged: a checkout that
    sits under a junction is the consumer's own arrangement, and the write still lands inside it.

    READ FROM THE PARENT'S LISTING, NOT FROM THE PATH. [System.IO.File]::GetAttributes and Test-Path
    follow the link, so a symlink whose target does not exist reads as "no file here" -- and a write to
    it creates the target, wherever it points. The directory listing reports the entry itself.

    A LEAF WITH NO DEPENDENCIES, mirrored into every plugin that carries one of those writers --
    dkj-policy, dkj-policy-bwj and dkj-subagents-alpha -- because a script may only dot-source a lib
    that ships in its own plugin.

    Pure ASCII, per this repo's script-layer convention.
#>

function Get-WriteTargetReparsePoint {
    <#
        Returns the first path, walking up from -Path to -Root (exclusive), whose directory entry is a
        reparse point (a symlink or junction); -Path itself when it is not under -Root at all; $null when
        the write stays inside -Root. -Path need not exist.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not $full.StartsWith($rootFull + $sep, [System.StringComparison]::OrdinalIgnoreCase)) { return $full }

    $cur = $full
    while ($cur.Length -gt $rootFull.Length) {
        $parent = [System.IO.Path]::GetDirectoryName($cur)
        $name = [System.IO.Path]::GetFileName($cur)
        if ([System.IO.Directory]::Exists($parent)) {
            foreach ($entry in ([System.IO.DirectoryInfo]$parent).GetFileSystemInfos($name)) {
                if ($entry.Name -ieq $name -and ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $cur }
            }
        }
        $cur = $parent
    }
    return $null
}
