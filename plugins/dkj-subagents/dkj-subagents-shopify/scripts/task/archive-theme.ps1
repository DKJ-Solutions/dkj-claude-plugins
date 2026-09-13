<#
.SYNOPSIS
    Archive one or more Shopify themes to a local, verified backup under theme-archive/, and leave a
    committed receipt for each. Never removes anything.

.DESCRIPTION
    WHY IT SHIPS RATHER THAN BEING WRITTEN PER REPO (issue #1886 candidate 4). Both BWJ stores wrote
    this by hand, under two different filenames, and the sibling check could only see it as ALIASED on
    one shared function name. One copy is 183 lines of Dutch that archives a single theme and then
    removes it; the other is 407 lines of English that archives many and refuses to remove any. Neither
    could find the other, so every lesson either of them learned stayed where it was learned.

    IT NEVER REMOVES A THEME, AND THAT IS THE HALF THE CONVERGENCE CHANGES. The copy that did remove
    one did it from inside a .ps1, and this plugin's live-theme guard is a PreToolUse hook: it reads
    the COMMAND STRING of a tool call. A destructive theme command buried inside a script is invisible
    to it -- the tool call reads 'powershell -File scripts/task/archive-theme.ps1 -Execute', which
    contains nothing for the guard to match. So that shape is not a rule broken in the open; it is a
    silent hole in the one mechanism that closes the wrapper vector, and it was live in one store for
    as long as that script was.

    Instead this script ENDS by printing the removal command, with the theme's name and role beside it,
    for the caller to run as a separate, visible act -- expressed as output rather than as prose
    somebody has to remember. Whether a session may run that command itself is the guard's decision and
    is answered by Get-ShopifyThemeDeleteMarker in the consumer's scripts/repo-config.ps1: answered,
    the guard allows a command carrying that exact marker as a comment; unanswered, it refuses
    outright. The live theme is refused either way. This script's own output says which of the two the
    repo is in, because the alternative -- prose saying one and a printed command doing the other --
    is the defect Format-ThemeDeleteCommand was extracted to stop repeating.

    WHAT IT DOES: resolve each theme, check the guardrails, pull it into the archive, verify the pull
    landed something that is actually a theme, write the receipt, and report. Repeatable: an existing
    verified archive is reused rather than re-pulled, and a re-run over an estate already backed up is
    how a theme archived before the receipt existed gets one, without re-pulling a single file.

    THE DECISIONS ARE IN scripts/lib/theme-archive-rules.ps1 and not in here, the same split
    sync-main.ps1 and sync-rules.ps1 use: everything below either invokes the Shopify CLI against a
    real store or reads a consumer's own repo-config, and a suite must reach neither. What CAN be wrong
    without a network -- what the caller asked for, whether a theme may be archived, what it is called
    on disk, whether the pull landed, and every byte of the receipt -- is pure, and
    scripts/tests/theme-archive-rules.tests.ps1 measures it.

.PARAMETER ThemeId
    One or more theme ids to archive. A real estate runs to a dozen or more unpublished themes, so the
    plural is the common case: -ThemeId 202322018645,202330276181 archives both in one run.

.PARAMETER Store
    Store domain. Defaults to Get-ShopifyStoreDomain from the consumer's scripts/repo-config.ps1 rather
    than a literal -- the same seam the live-theme guard reads, so there is one answer to "which store
    is this".

.PARAMETER ArchiveRoot
    Where the backups land. Default: <repo>/theme-archive, which belongs in .gitignore. A theme pull is
    a full copy of a whole theme; committing every theme on an estate would put tens of thousands of
    files of unrelated history into a repo whose diffs are read by hand.

.PARAMETER ManifestRoot
    Where the committed receipts land. Default: <repo>/theme-archive-manifests, which is NOT
    gitignored. One small text file per archived theme -- the theme, one dated event per machine that
    has held a copy, and every file with its size and SHA-256.

.PARAMETER NoManifest
    Skip writing the receipt. For a throwaway archive taken to inspect a theme rather than to make a
    removal recoverable -- the two are the same command and only one of them is worth a committed file.

.PARAMETER Refresh
    Re-pull a theme that already has a verified archive. Without it an existing archive is reused, so a
    run over the whole estate is cheap to repeat after an interruption.

.PARAMETER RootOverride
    A fixture root, so a suite can drive this script against a scratch tree instead of a real store --
    and so the marketplace refusal can be bypassed in a repo that is one. A consumer never types it.

.EXAMPLE
    powershell -NoProfile -File scripts/task/archive-theme.ps1 -ThemeId 184381800789

.EXAMPLE
    powershell -NoProfile -File scripts/task/archive-theme.ps1 -ThemeId 183398957397,184381800789

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE. scripts/tests/theme-archive-rules.tests.ps1 pins
    the lib beside this file: the id list, both refusals of the verdict, the folder name against real
    theme names, the archive test, every byte of the receipt, the round trip through the parser and the
    merge, the removal command in both seam states, and the third-party warning.

    THIS SCRIPT ITSELF IS NOT DRIVEN, and deliberately, for the same reason push-preview.ps1 is not.
    What is therefore unpinned is the ORDER of the resolution steps and the two refusals -- which is
    exactly why the parts that CAN be judged without a network were moved into the lib.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ThemeId,

    [string]$Store = '',

    [string]$ArchiveRoot = '',

    [string]$ManifestRoot = '',

    [switch]$Refresh,

    [switch]$NoManifest,

    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined: the seam probes below read the function table directly rather than through
# Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on every miss --
# and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it resolves in the
# plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

. (Join-Path $PSScriptRoot '..\lib\theme-archive-rules.ps1')

# THE SHOPIFY CLI WRAPPER. Both calls below would otherwise be bare under this script's 'Stop', and on
# Windows the CLI is a PowerShell shim that inherits that preference -- so a hint line written to
# stderr while the command SUCCEEDS becomes terminating and the clear "is the CLI logged in?" message
# further down is unreachable. UNGUARDED, unlike the source-repo guard above: a copy of this script
# without the lib must fail at load rather than pull a theme whose failure path cannot be reached.
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source root copy falls back to the git root. Same resolution as every other mirrored script, which is
# what lets both copies stay byte-identical.
$repoRoot = if ($RootOverride) { $RootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }
$repoRoot = ([string]$repoRoot).Trim() -replace '/', '\'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store: there is no theme estate
# here to archive. Same one-file test push-preview, sync-main and adopt-shopify-floor use.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme estate here to archive. Nothing was changed.'
    exit 1
}

# --- The seam answers ------------------------------------------------------------------------------
# Read in a child scope with StrictMode OFF and inside a try, exactly as this plugin's live-theme guard,
# sync-main and push-preview read the same file. The reason is the same: repo-config.ps1 belongs to the
# consumer, so a fault in it must degrade to defaults rather than take this script down with it.
$seam = & {
    Set-StrictMode -Off
    $answers = @{ LiveThemeId = ''; StoreDomain = ''; DeleteMarker = ''; ExternalPrefixes = @(); VerifierPath = '' }
    $root = $args[0]
    $configPath = Join-Path $root 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try { . $configPath } catch { }
    }
    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId')     { $answers.LiveThemeId  = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyStoreDomain')     { $answers.StoreDomain  = [string](Get-ShopifyStoreDomain) }
    if (Test-FunctionDefined 'Get-ShopifyThemeDeleteMarker') { $answers.DeleteMarker = [string](Get-ShopifyThemeDeleteMarker) }
    # OPTIONAL, AND UNANSWERED IS THE ORDINARY CASE. A store with no third-party themes has nothing to
    # declare here and sees exactly what it saw before the seam existed. See Get-ExternalThemeWarning.
    if (Test-FunctionDefined 'Get-ShopifyExternalThemePrefixes') { $answers.ExternalPrefixes = @(Get-ShopifyExternalThemePrefixes) }
    # OPTIONAL: a consumer that has its own receipt verifier names it, and the receipt then says how to
    # check a recovered copy. Unanswered, the receipt says what it can prove without naming a tool that
    # does not exist in this repo.
    if (Test-FunctionDefined 'Get-ShopifyArchiveVerifierPath') { $answers.VerifierPath = [string](Get-ShopifyArchiveVerifierPath) }
    return $answers
} $repoRoot

if (-not $Store)        { $Store = $seam.StoreDomain }
if (-not $ArchiveRoot)  { $ArchiveRoot = Join-Path $repoRoot 'theme-archive' }
if (-not $ManifestRoot) { $ManifestRoot = Join-Path $repoRoot 'theme-archive-manifests' }

if (-not $Store) {
    Write-Host 'REFUSED: no store domain. Answer Get-ShopifyStoreDomain in scripts/repo-config.ps1, or pass -Store.' -ForegroundColor Red
    exit 1
}

$liveId = ([string]$seam.LiveThemeId).Trim()
if (-not $liveId) {
    Write-Host 'REFUSED: Get-ShopifyLiveThemeId returned nothing -- refusing to guess which theme is live.' -ForegroundColor Red
    Write-Host 'Answer it in scripts/repo-config.ps1. Until then every theme would have to be refused anyway.'
    exit 1
}

# --- The receipt -----------------------------------------------------------------------------------
# THE RECEIPT NEVER FAILS THE RUN, which is why this wraps the whole thing in a try. The archive is the
# valuable half and it has already landed by the time this is called; a hash that throws on a file the
# pull left locked must not turn a good backup into a red exit code, because the caller reads the code
# before the log and would remove nothing on a run that actually succeeded. A failure here is reported
# as 'failed' in the summary and is a reason to re-run, not a reason to distrust the archive.
#
# IT MERGES, AND THERE IS ONE PATH RATHER THAN TWO. This used to take an -Overwrite switch: the reuse
# branch called it without, the fresh-pull branch called it with. Read from either end that is the same
# rule -- "the manifest describes the bytes on disk now" -- and in the middle it was not, because 'the
# archive is already on disk' and 'the content has not changed' are different questions. theme-archive/
# is gitignored, so on any machine that did not take the archive the first is false while the second is
# true, and every run there rewrote the machine field the receipt exists to record. Every run now reads
# the committed receipt, folds its own event in, and writes the result; whether anything actually
# changed is Merge-ThemeArchiveEvent's answer, not the caller's.
function Write-ThemeArchiveManifest {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$ManifestRoot,
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Id,
        [AllowEmptyString()][string]$Name,
        [AllowEmptyString()][string]$Role,
        [AllowEmptyString()][string]$Store,
        [AllowEmptyString()][string]$VerifierPath = ''
    )

    try {
        $file = Join-Path $ManifestRoot (Get-ArchiveManifestFileName -Folder $Folder)

        $existingText = ''
        if (Test-Path -LiteralPath $file) {
            # -Raw: the parse is regex over the whole text, and Get-Content without it returns an array
            # whose -join would have to guess the newline back.
            $existingText = [string](Get-Content -LiteralPath $file -Raw)
        }

        # THE WALK HAPPENS EVEN ON A REUSE, and that is the change that makes the merge possible at all.
        # The old reuse path returned 'kept' before hashing anything, so it could not tell whether the
        # bytes it was reusing were the bytes the receipt described. The cost is one local read of a few
        # hundred small files -- nothing beside the theme pull this path exists to avoid.
        $records = Get-ThemeArchiveFileRecords -Path $ArchivePath
        $bytes   = [int64]0
        foreach ($r in $records) { $bytes += [int64]$r.Bytes }

        $merged = Merge-ThemeArchiveEvent `
            -Events (Get-ThemeArchiveEvents -Text $existingText) `
            -ArchivedUtc ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')) `
            -Machine ([string]$env:COMPUTERNAME) `
            -Files @($records).Count -Bytes $bytes `
            -ContentSha (Get-ThemeArchiveContentDigest -Records $records)

        $text = Format-ThemeArchiveManifest `
            -ThemeId $Id -ThemeName $Name -Role $Role -Store $Store -Folder $Folder `
            -Events $merged.Events -Records $records -VerifierPath $VerifierPath

        # WRITTEN EVEN WHEN THE EVENT WAS 'kept', because 'kept' is a statement about the EVENTS and not
        # about the file: a v1 receipt re-rendered gains the event log and the content digest with its
        # recorded day intact, and a receipt whose role or store changed on the store picks that up. The
        # render is deterministic over the same facts, so a genuine no-op writes byte-identical content
        # and leaves no diff -- which is the property that matters, rather than skipping the write.
        New-Item -ItemType Directory -Path $ManifestRoot -Force | Out-Null
        # -Encoding ascii, deliberately: the manifest is pure ASCII by construction (hex, digits and
        # theme paths), and Set-Content's default here is the system ANSI codepage, which would make
        # the committed file differ between machines for no reason at all.
        Set-Content -LiteralPath $file -Value $text -Encoding ascii -NoNewline
        return $merged.Change
    } catch {
        Write-Host "  Manifest FAILED for $Folder : $($_.Exception.Message)" -ForegroundColor Red
        return 'failed'
    }
}

# WHAT THE MERGE DID IS SAID OUT LOUD, because three of the four outcomes are facts about the ESTATE
# rather than about this run, and the caller cannot see them anywhere else. 'added' means a machine that
# was not previously recorded now holds a copy. 'replaced' means this machine's copy is not the copy the
# receipt described, which is the one outcome worth stopping over before a removal. 'kept' is the good
# silence: nothing about the archive changed and the recorded day still names the day those bytes
# landed, which is exactly the promise the old code broke.
function Write-ManifestOutcome {
    param([AllowEmptyString()][string]$Change)

    switch ($Change) {
        'added'    { Write-Host '  Manifest: this machine recorded as holding a copy.' -ForegroundColor Green }
        'migrated' { Write-Host '  Manifest: pre-log receipt carried forward, its recorded day intact, content digest added.' -ForegroundColor Green }
        'replaced' { Write-Host '  Manifest: this machine''s copy CHANGED -- the previous event described other bytes.' -ForegroundColor Yellow }
        'kept'     { Write-Host '  Manifest: unchanged (same machine, same content -- the recorded day stands).' -ForegroundColor Green }
        default    { }
    }
}

# --- The run ---------------------------------------------------------------------------------------
Write-Host ''
Write-Host "=== archive-theme  |  store: $Store ===" -ForegroundColor Cyan
Write-Host "Archive root:  $ArchiveRoot" -ForegroundColor Cyan
if ($NoManifest) {
    Write-Host 'Manifest root: (none -- -NoManifest, so this run leaves no committed receipt)' -ForegroundColor Yellow
} else {
    Write-Host "Manifest root: $ManifestRoot" -ForegroundColor Cyan
}

Write-Host "`nReading the estate ..." -ForegroundColor Yellow
# -DiscardStderr because this output is PARSED: the CLI writes a hint line to stderr while succeeding,
# and a merged capture puts it in front of the JSON. -Quiet because the JSON is not for a reader.
$list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $Store, '--json') -Quiet -DiscardStderr
if ($list.ExitCode -ne 0 -or -not $list.Output) {
    throw "Could not read the theme list (is the Shopify CLI logged in? 'shopify theme list --store $Store' re-triggers auth)."
}
$themes = ($list.Output -join "`n") | ConvertFrom-Json

$archived = @()
$skipped  = @()

# -File does not parse PowerShell, so '-ThemeId a,b,c' arrives as ONE string. See Expand-ThemeIdList.
$ids = Expand-ThemeIdList -ThemeId $ThemeId
if ($ids.Count -eq 0) {
    Write-Host 'No theme ids given.' -ForegroundColor Red
    exit 1
}
Write-Host "Themes to archive: $($ids.Count)" -ForegroundColor Cyan

foreach ($rawId in $ids) {
    $id = ([string]$rawId).Trim()
    Write-Host ''
    Write-Host "--- $id ---" -ForegroundColor Cyan

    $theme = $themes | Where-Object { "$($_.id)" -eq $id }
    if (-not $theme) {
        Write-Host "  REFUSED: not found on $Store." -ForegroundColor Red
        $skipped += "$id (not found on the store)"
        continue
    }

    $name = [string]$theme.name
    $role = [string]$theme.role
    Write-Host "  $name  (role: $role)"

    # The guardrail, and why it lives in the lib: see Get-ThemeArchiveVerdict. Short version -- the live
    # theme is refused because a pull of live is a read of live, which this workflow allows in exactly
    # two places and this is not one of them.
    $verdict = Get-ThemeArchiveVerdict -Id $id -Name $name -Role $role -LiveThemeId $liveId
    if (-not $verdict.Allowed) {
        Write-Host "  REFUSED: $($verdict.Reason)" -ForegroundColor Red
        $skipped += "$id ($($verdict.Reason))"
        continue
    }

    # A THIRD-PARTY THEME IS ARCHIVED, NEVER GATED. The gate one converged copy carried refused the
    # archive; this script does not remove anything, so a local read-only backup of somebody else's
    # theme harms nothing and the gate had no subject. What the warning DOES attach to is the removal
    # command printed at the end, which is where the integration is actually at risk -- see
    # Get-ExternalThemeWarning.
    $externalWarning = Get-ExternalThemeWarning -Name $name -ExternalPrefixes $seam.ExternalPrefixes
    if ($externalWarning) { Write-Host "  $externalWarning" -ForegroundColor Yellow }

    $folder      = Get-ArchiveFolderName -Name $name -Id $id
    $archivePath = Join-Path $ArchiveRoot $folder

    if ((Test-ThemeArchive -Path $archivePath) -and -not $Refresh) {
        $n = (Get-ChildItem -LiteralPath $archivePath -Recurse -File | Measure-Object).Count
        Write-Host "  Existing verified archive reused ($n files): $folder" -ForegroundColor Green
        # AND THIS IS THE REPAIR PATH, not just a reuse. An archive taken before the receipt existed has
        # none, and a re-run over an estate already backed up is exactly how those get one -- without
        # re-pulling a single theme. What that run writes is decided by the merge, not by which branch
        # got here: an event for THIS machine whose content is unchanged is left exactly as recorded.
        $m = 'off'
        if (-not $NoManifest) {
            $m = Write-ThemeArchiveManifest -ArchivePath $archivePath -ManifestRoot $ManifestRoot `
                -Folder $folder -Id $id -Name $name -Role $role -Store $Store -VerifierPath $seam.VerifierPath
            Write-ManifestOutcome -Change $m
        }
        $archived += [pscustomobject]@{ Id = $id; Name = $name; Role = $role; Folder = $folder; Files = $n; Fresh = $false; Manifest = $m; External = [bool]$externalWarning }
        continue
    }

    # 'theme pull --path' needs the target directory to exist; -Force creates the ArchiveRoot too.
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    Write-Host "  Pulling into $folder ..." -ForegroundColor Yellow
    # STREAMED, deliberately: a theme pull takes minutes and reports its progress as it goes, so that
    # output belongs on the console live rather than all at once when it is over. Nothing parses it.
    $pull = Invoke-ShopifyCli -Arguments @('theme', 'pull', '--store', $Store, '--theme', $id, '--path', $archivePath)
    if ($pull.ExitCode -ne 0) {
        Write-Host "  FAILED: theme pull returned $($pull.ExitCode). Nothing archived for this theme." -ForegroundColor Red
        $skipped += "$id (pull failed)"
        continue
    }
    if (-not (Test-ThemeArchive -Path $archivePath)) {
        Write-Host "  VERIFICATION FAILED: $archivePath holds no recognisable theme directory." -ForegroundColor Red
        $skipped += "$id (archive did not verify)"
        continue
    }

    $n = (Get-ChildItem -LiteralPath $archivePath -Recurse -File | Measure-Object).Count
    Write-Host "  Archived and verified ($n files)." -ForegroundColor Green

    # THE SAME CALL AS THE REUSE BRANCH. This used to pass -Overwrite and the branch above did not, on
    # the reasoning that "a fresh pull's bytes are today's". The reasoning was sound and the condition
    # it hung on was not: reaching this branch means the archive was not on disk, which on a second
    # machine says nothing at all about whether the CONTENT changed. So the freshness of the pull no
    # longer decides anything; the content digest does.
    $m = 'off'
    if (-not $NoManifest) {
        $m = Write-ThemeArchiveManifest -ArchivePath $archivePath -ManifestRoot $ManifestRoot `
            -Folder $folder -Id $id -Name $name -Role $role -Store $Store -VerifierPath $seam.VerifierPath
        Write-ManifestOutcome -Change $m
    }
    $archived += [pscustomobject]@{ Id = $id; Name = $name; Role = $role; Folder = $folder; Files = $n; Fresh = $true; Manifest = $m; External = [bool]$externalWarning }
}

Write-Host ''
Write-Host '=== summary ===' -ForegroundColor Cyan
Write-Host "Archived: $($archived.Count)   Skipped: $($skipped.Count)" -ForegroundColor Cyan
foreach ($a in $archived) {
    $tag = if ($a.Fresh) { 'new' } else { 'reused' }
    Write-Host ('  [{0,-6}] {1,6} files  manifest: {2,-8} {3}' -f $tag, $a.Files, $a.Manifest, $a.Folder) -ForegroundColor Green
}
foreach ($s in $skipped) { Write-Host "  [skip  ] $s" -ForegroundColor Yellow }

$manifestFailed = @($archived | Where-Object { $_.Manifest -eq 'failed' })

if ($archived.Count -gt 0) {
    Write-Host ''
    Write-Host 'The BYTES are LOCAL ONLY -- theme-archive/ belongs in .gitignore, so they do not travel' -ForegroundColor Yellow
    Write-Host 'with the repo and do not survive this machine. That is deliberate: for a spent branch' -ForegroundColor Yellow
    Write-Host 'preview the durable copy is git, not this folder.' -ForegroundColor Yellow
    if (-not $NoManifest) {
        Write-Host ''
        Write-Host 'The RECEIPTS do travel. theme-archive-manifests/ is committed, so the repo can always' -ForegroundColor Green
        Write-Host 'say what was archived, when, and on which machines. Commit them with your change:' -ForegroundColor Green
        Write-Host '  git add theme-archive-manifests' -ForegroundColor Cyan
    }
    if ($manifestFailed.Count -gt 0) {
        Write-Host ''
        Write-Host ('MANIFEST FAILED for {0} theme(s) -- the archive is fine, the receipt is not.' -f $manifestFailed.Count) -ForegroundColor Red
        Write-Host 'Re-run to write it; do not remove a theme whose receipt did not land.' -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Nothing has been removed from the store. A theme is spent only once its work is merged' -ForegroundColor Green
    Write-Host 'and, if it was ever pushed, already live -- that is a judgement, not a cleanup step.' -ForegroundColor Green
    Write-Host ''

    # THE COMMAND IS NOT BUILT HERE. It was a format string once, and that is precisely how all three of
    # its defects -- no marker, no --force, and a false sentence above them -- survived a repair pass
    # over the very file it lived in: a string nothing measures is repaired only by whoever happens to
    # look at it. Format-ThemeDeleteCommand is pure, so the suite asserts the exact bytes it produces,
    # marker placement included. What stays here is the PROSE and the seam read.
    #
    # THE SEAM IS READ AND PASSED IN, never spelled in the formatter. Get-ShopifyThemeDeleteMarker is
    # what the guard hook itself reads on every command, so a literal anywhere else would be a second
    # copy free to drift -- and it would fail in the direction that costs most: a printed command that
    # looks authorised, is refused, and sends the caller editing config that was already correct.
    $deleteMarker = ([string]$seam.DeleteMarker).Trim()
    if ($deleteMarker) {
        Write-Host 'To remove one, run the command below as its own visible act. The marker is what the' -ForegroundColor Green
        Write-Host 'guard hook reads; the live theme is refused even with it.' -ForegroundColor Green
    } else {
        Write-Host 'To remove one, run it yourself: Get-ShopifyThemeDeleteMarker is unanswered, so the' -ForegroundColor Green
        Write-Host 'guard hook refuses this command from a session outright.' -ForegroundColor Green
    }
    foreach ($a in $archived) {
        if ($a.External) {
            Write-Host ('  ' + (Get-ExternalThemeWarning -Name $a.Name -ExternalPrefixes $seam.ExternalPrefixes)) -ForegroundColor Yellow
        }
        Write-Host ('  ' + (Format-ThemeDeleteCommand -Store $Store -ThemeId $a.Id -ThemeName $a.Name -DeleteMarker $deleteMarker)) -ForegroundColor Cyan
    }
}

# A SKIP IS A FAILURE, AND THE EXIT CODE HAS TO SAY SO. The first version of this exited 0 after
# archiving nothing at all -- every id refused, "Skipped: 1" printed in yellow, success reported. A
# caller (or a session reading a tail) sees the code before it reads the log, so the code is what has to
# be honest. A reused archive is not a skip: it counts as archived, so a repeat run over an estate
# already backed up still exits 0.
#
# A FAILED RECEIPT IS ALSO A FAILURE, for the same reason as the paragraph above. The archive landed, so
# it is tempting to call the run green -- but the caller's very next act is a removal, and a removal
# whose receipt did not land is the state the receipt was built to prevent. The bytes being fine today
# is exactly the assurance that expires. A re-run costs nothing and writes only the missing receipt, so
# there is no cost to being honest here.
if ($skipped.Count -gt 0 -or $manifestFailed.Count -gt 0) { exit 1 }
exit 0
