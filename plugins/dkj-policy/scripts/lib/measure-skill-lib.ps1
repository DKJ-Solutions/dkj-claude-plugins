<#
.SYNOPSIS
    The parsing and formatting half of measure-skill.ps1 -- everything that turns `claude plugin
    details` output into figures, with no I/O of its own.

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot (NOT
    $repoRoot) -- like scripts/lib/check-report-lib.ps1 and unlike scripts/repo-config.ps1, this lib is
    not repo-owned, so it does not need a consumer-side scaffold. It travels as part of the SAME
    plugin/mirror payload as its caller (registered in scripts/lib/shared-scripts-lib.ps1):

        . (Join-Path $PSScriptRoot '..\lib\measure-skill-lib.ps1')   -- from scripts/maintenance/*

    WHY IT IS A LIB AND NOT PART OF THE SCRIPT. The parse is the one fragile thing in the whole
    measurement: it reads a human-formatted table whose shape the CLI owns and may change. A parser
    that cannot be tested without shelling out to `claude` is one nobody pins, so the functions that
    do the reading live here, take strings, and return objects. scripts/tests/measure-skill.tests.ps1
    dot-sources this file and asserts against captured output -- the same reasoning that put the entry
    format in entry-scaffold-lib.ps1, so a format change breaks the script and its test together
    instead of leaving the test asserting a shape nothing writes.

    Contains NO Write-Host, no exit, and no counter. Reporting belongs to the caller, which owns the
    [OK]/[INFO]/[ERROR] vocabulary from check-report-lib.ps1.

    ONE FUNCTION RUNS A COMMAND, Get-PluginDetails at the bottom: it is the single place `claude plugin
    details` is invoked, lifted here from measure-skill.ps1 so measure-session-start.ps1 asks the CLI the
    same question the same way instead of carrying a second copy. Everything it returns still comes from
    the parsers above, which stay pinned against captured output.

    THE OTHER FUNCTIONS THAT READ FILES sit below it, each moved here so measure-skill and
    measure-session-start answer one question the same way: Get-InstalledVersionForRepo (#2670) and
    Get-PayloadDirForPlugin read the install record and the plugin cache, Test-SkillModelInvocationDisabled
    and Split-SkillRowsByInvocation read SKILL.md frontmatter (#2664). The first two need check-report-lib
    (Get-InstallRecord, Get-UserClaudeHome, Get-CachedPluginDirs), which every caller dot-sources first.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# THE ONE DEPENDENCY, for the one field this lib does not own. Get-ManifestAgentEntries is the shared
# reading of a manifest's 'agents' key; Get-DeclaredAgentCount below carried its own until #1781. Safe to
# pull in here for the reason plugin-tree-lib's own header states: it has no dependencies of its own, so
# this costs one small file rather than a chain of them.
. (Join-Path $PSScriptRoot 'plugin-tree-lib.ps1')

# THE SECOND DEPENDENCY, for Get-PluginDetails' command runner. Invoke-NativeCapture was already loaded
# beside this lib by its only caller (measure-skill.ps1); it is pulled in here so the lib is whole for
# the second caller too. Dot-sourcing it twice only redefines the same functions.
. (Join-Path $PSScriptRoot 'native-capture-lib.ps1')

# EVERY FIGURE IS FORMATTED INVARIANTLY, and that is not a style choice. Formatted on a Dutch machine,
# '{0:N0}' renders 13700 as '13.700' -- which an English reader of this repo reads as 13.7, off by a
# factor of a thousand and still plausible. That is the same trap ConvertTo-TokenCount guards against in
# the other direction. Same reasoning as Get-EnabledPlugins sorting ordinally: a figure must not depend
# on the machine that printed it.
$script:MeasureSkillInvariant = [System.Globalization.CultureInfo]::InvariantCulture

function Format-Tok {
    <# A token count with thousands separators, invariantly. 'n/a' for $null. #>
    param($Value)
    if ($null -eq $Value) { return 'n/a' }
    return ([string]::Format($script:MeasureSkillInvariant, '{0:N0}', $Value))
}

function Format-Pct {
    <# A percentage to at most one decimal, invariantly. #>
    param($Value)
    return ([string]::Format($script:MeasureSkillInvariant, '{0:0.#}', $Value))
}

function Format-Sec {
    <# A duration in seconds to two decimals, invariantly. #>
    param($Value)
    return ([string]::Format($script:MeasureSkillInvariant, '{0:0.00}', $Value))
}

function ConvertTo-TokenCount {
    <#
        THE TWO NOTATIONS THAT SHARE ONE TABLE, in one place.

            '~3.031'  -> 3031     the dot is a THOUSANDS separator
            '~1.3k'   -> 1300     a k suffix on a DECIMAL
            '~160'    -> 160
            '', '-'   -> $null

        A parser that read '~3.031' as 3.031 would under-report by a factor of a thousand and still
        look entirely plausible, which is why the caller cross-checks the row sum against the printed
        total rather than trusting this function on its own.

        A value below 10 with a decimal point cannot be a token count -- '1.3' is 13, not 1.3 -- so the
        thousands reading is the safe one wherever there is no k.
    #>
    param([string]$Raw)
    if ($null -eq $Raw) { return $null }
    $t = $Raw.Trim().TrimStart([char]0x7E).Trim()
    if ($t -eq '' -or $t -eq '-') { return $null }
    if ($t -match '^([0-9]+(?:[.,][0-9]+)?)[kK]$') {
        $decimal = $Matches[1].Replace(',', '.')
        $value = [double]::Parse($decimal, [System.Globalization.CultureInfo]::InvariantCulture)
        return [int][math]::Round($value * 1000)
    }
    $digits = $t -replace '[.,]', ''
    if ($digits -match '^[0-9]+$') { return [int]$digits }
    return $null
}

function Expand-ListArgument {
    <#
        Splits a comma-separated value, because of how every script in this repo is invoked.
        `powershell -NoProfile -File <script> -Skill a,b,c` does NOT parse PowerShell syntax for the
        arguments after the script path, so the whole of 'a,b,c' arrives as ONE element of the
        [string[]]. Measured on the first run that used the filter: three skills were named, nothing
        matched, and the report said "0 of 14" -- true, and reading as if the plugin had no such skills.
    #>
    param([string[]]$Value)
    if (-not $Value) { return @() }
    return @($Value |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' })
}

function Read-PluginDetailsOutput {
    <#
        Parses the output of `claude plugin details <id>` into the five things a measurement needs:
        the version, the printed Always-on total, the component inventory's own COUNTS, the skills that
        inventory names, and one row per component. Takes LINES rather than running the command, so it
        can be pinned by a suite against captured output.

        Returns a pscustomobject: Version, AlwaysOnTotal, InventoryCounts, RowProducingCount,
        InventorySkills, Rows (Component, AlwaysOn, OnInvoke). Anything it could not find is $null or an
        empty array -- judging that is Get-PluginDetailsParseProblems' job, not this function's.

        THE COUNTS ARE READ BECAUSE AN EMPTY TABLE HAS TWO CAUSES, and they are opposite facts. The CLI
        prints no per-component table at all for a plugin whose inventory is all zeroes -- there is
        nothing to tabulate -- and it prints none if the format moves under this parser. Only the
        inventory itself can tell those apart, so it is parsed rather than inferred. RowProducingCount is
        skills plus agents: hooks are marked harness-only and MCP/LSP servers carry no model context, so
        neither of those produces a row.
    #>
    param([string[]]$Lines)

    $version         = $null
    $alwaysOnTotal   = $null
    $inventoryCounts = [ordered]@{}
    $inventorySkills = @()
    $rows            = @()
    $inInventory     = $false
    $inTable         = $false

    foreach ($line in @($Lines)) {
        if ($null -eq $line) { continue }

        # The header line ends in the version: '... (dkj-subagents-alpha) 5.5.0'. First match only, so a
        # version-looking string further down cannot overwrite it. That pair is an ILLUSTRATION of the
        # shape, not a capture of a released header, so it is kept true as names change rather than
        # frozen and marked the way a quotation is (#2144).
        if ($null -eq $version -and $line -match '\s(\d+\.\d+\.\d+)\s*$') { $version = $Matches[1] }

        # Every inventory line, by name and count -- 'Skills (4)', 'Agents (0)', 'MCP servers (0)'. The
        # count is what the CLI BELIEVES it has, which is the only thing that says whether a table was
        # owed at all. Deliberately not matched against a fixed list of component kinds: a kind this
        # parser has never heard of is still counted, so a new one cannot make an owed table look unowed.
        #
        # READ ONLY INSIDE THE 'Component inventory' BLOCK, the same way the table below is read only
        # inside its own. The pattern is '<words> (<digits>)', which is ordinary prose: measured, an
        # indented line reading 'See also (2) related notes.' parses as a component called 'See also'
        # with a count of 2, inflating what the check below thinks was owed. Excluding ':' from the name
        # keeps today's Description and Source lines out, but that is a property of today's wording
        # rather than a rule -- the block boundary is structural, so a note the CLI adds tomorrow cannot
        # become a component wherever it is worded.
        if ($line -match '^\S') { $inInventory = $false }
        if ($line -match '^Component inventory\s*$') { $inInventory = $true; continue }
        if ($inInventory -and $line -match '^\s{2,}([A-Za-z][A-Za-z ]*?)\s*\((\d+)\)\s*(?:\s\S.*)?$') {
            $inventoryCounts[$Matches[1]] = [int]$Matches[2]
        }

        if ($line -match '^\s*Skills\s*\(\d+\)\s+(.+)$') {
            $inventorySkills = @($Matches[1] -split ',' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -ne '' })
        }

        if ($line -match '^\s*Always-on:\s*(\S+)') { $alwaysOnTotal = ConvertTo-TokenCount $Matches[1] }

        # The per-component table starts at its own header and ends at the first line that is not a
        # row -- a blank line, or the 'On-invoke cost is paid...' note under it.
        if ($line -match '^\s*component\s+always-on\s+on-invoke\s*$') { $inTable = $true; continue }
        if ($inTable) {
            if ($line -match '^\s{2,}(\S+)\s{2,}([~0-9.,kK]+)\s+([~0-9.,kK]+)\s*$') {
                $rows += [pscustomobject]@{
                    Component = $Matches[1]
                    AlwaysOn  = ConvertTo-TokenCount $Matches[2]
                    OnInvoke  = ConvertTo-TokenCount $Matches[3]
                }
            } elseif ($rows.Count -gt 0) {
                $inTable = $false
            }
        }
    }

    # $null, not 0, where the inventory could not be read: 'no table was owed' and 'the format moved
    # under the parser' must not collapse into one value -- the same three-state lesson claim-issue's
    # read-back learned in #1628, where one boolean carried two opposite facts and printed the wrong one.
    #
    # BOTH KINDS MUST BE PRESENT, or the answer is $null. Summing whichever of the two happened to parse
    # was the weaker rule: rename 'Skills (N)' alone and the block still yields lines, so the count stays
    # non-$null and silently loses that kind's contribution -- undercounting TOWARDS 0, which is the
    # direction that turns a refusal into a pass. Requiring both means a per-kind drift lands on the
    # [ERROR] this check exists for rather than on the quiet branch. It also means a future CLI dropping
    # either line outright is refused, which is the correct failure direction: loud, and one line to fix.
    $rowProducing = $null
    $kinds = @('Skills', 'Agents')
    if (@($kinds | Where-Object { $inventoryCounts.Contains($_) }).Count -eq $kinds.Count) {
        $rowProducing = 0
        foreach ($kind in $kinds) { $rowProducing += [int]$inventoryCounts[$kind] }
    }

    return [pscustomobject]@{
        Version           = $version
        AlwaysOnTotal     = $alwaysOnTotal
        InventoryCounts   = $inventoryCounts
        RowProducingCount = $rowProducing
        InventorySkills   = $inventorySkills
        Rows              = $rows
    }
}

function Get-PluginDetailsParseProblems {
    <#
        THE TWO CROSS-CHECKS, and the reason no figure is reported without them. The table above is
        human-formatted output whose shape the CLI owns, so a drifted parse is a question of when
        rather than whether -- and a drifted parse that still produces numbers is the dangerous
        outcome, not a crash.

          1. The rows must SUM to the printed Always-on total, within tolerance. This is what catches a
             misread notation: reading '~3.031' as 3 would leave the sum a thousandfold short.
          2. Every skill the component inventory names must have produced a ROW. This is what catches a
             row-regex that stopped matching -- a table that silently yields fewer rows than it has.

        Returns the problems as strings; an empty array means the parse can be trusted. Reporting and
        refusing belong to the caller.

        AN EMPTY TABLE IS ONLY A PROBLEM WHERE THE INVENTORY SAYS ONE WAS OWED. The CLI prints no
        per-component table for a plugin whose inventory declares no skills and no agents -- there is
        nothing to tabulate, and 'Always-on: ~0 tok' corroborates it. Reading that as a format change was
        a FALSE refusal on exactly the plugins that ship subagents and no skills (#1771): two of this
        repo's six enabled plugins reported '[ERROR] ... did not parse as expected', with the CLI's
        format entirely intact. So the emptiness is judged against RowProducingCount, and where the
        inventory could not be read at all ($null) the old refusal stands -- an unreadable inventory is
        the format change this check exists for.

        THE TOLERANCE IS NOT SLACK. Every printed figure is rounded to two significant figures, so the
        sum CANNOT equal the total: measured on this repo, 19 rows summing to 3,010 against a printed
        3,031. 5% of the total with a floor of 100 covers that rounding across a plugin of any size and
        nothing larger -- a misread notation is off by orders of magnitude, not by 5%.
    #>
    param([Parameter(Mandatory = $true)]$Details)

    $problems = @()
    if (@($Details.Rows).Count -eq 0) {
        $owed = $Details.RowProducingCount
        if ($null -eq $owed) {
            $problems += ('the per-component table produced no rows, and the component inventory could ' +
                'not be read either, so nothing says whether a table was owed')
        } elseif ($owed -gt 0) {
            $problems += ("the per-component table produced no rows, while the component inventory " +
                "declares $owed skill(s)/agent(s) that each owe one")
        }
    }
    if ($null -eq $Details.AlwaysOnTotal) { $problems += 'no Always-on total was found' }

    if (@($Details.Rows).Count -gt 0 -and $null -ne $Details.AlwaysOnTotal) {
        $sum = ($Details.Rows | Measure-Object -Property AlwaysOn -Sum).Sum
        $tolerance = [math]::Max(100, [int][math]::Round($Details.AlwaysOnTotal * 0.05))
        $drift = [math]::Abs($sum - $Details.AlwaysOnTotal)
        if ($drift -gt $tolerance) {
            $problems += ("rows sum to $(Format-Tok $sum) against a printed total of " +
                "$(Format-Tok $Details.AlwaysOnTotal) -- off by $(Format-Tok $drift), over a tolerance " +
                "of $(Format-Tok $tolerance)")
        }
    }

    $named = @($Details.Rows | Select-Object -ExpandProperty Component)
    $missing = @($Details.InventorySkills | Where-Object { $named -notcontains $_ })
    if ($missing.Count -gt 0) {
        $problems += "the inventory names $($missing.Count) skill(s) that produced no row: $($missing -join ', ')"
    }

    return @($problems)
}

function Get-DeclaredAgentCount {
    <#
        WHAT THE MANIFEST DECLARES, WHERE THE INVENTORY CANNOT SAY. `claude plugin details` reports
        'Agents (N)' by counting only defs found by convention in a plugin's default agents\ directory:
        measured against Claude Code 2.1.267, a def named by the manifest's 'agents' key LOADS in a
        session and is counted as 0 there. So that count is not evidence about a plugin's agents, and
        this reads the manifest for the one thing that is -- how many the plugin declares.

        Read from the TREE, which is also where the version comparison gets its answer: that is the copy
        this repo can act on, and the caller names it whenever it differs from the measured one.

        Returns Found / Version / AgentCount. A manifest that is missing or unparseable is Found=$false
        with a count of 0, so a caller cannot mistake 'could not look' for 'declares none' -- the same
        three-state care Read-PluginDetailsOutput takes over the inventory.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ShortName
    )

    $manifest = @(Get-ChildItem -Path (Join-Path $RepoRoot "plugins\*\$ShortName\.claude-plugin\plugin.json") -ErrorAction SilentlyContinue |
        Select-Object -First 1)
    if ($manifest.Count -ne 1) { return [pscustomobject]@{ Found = $false; Version = $null; AgentCount = 0 } }
    try {
        $json = Get-Content -LiteralPath $manifest[0].FullName -Raw | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ Found = $false; Version = $null; AgentCount = 0 }
    }

    # string|string[], the two forms the installer accepts -- a bare string is one entry, and the absent
    # key is the ordinary case for every plugin that ships none. Both of those answers come from
    # plugin-tree-lib's Get-ManifestAgentEntries, the ONE reading of this field: check 38 of
    # check-plugin-integrity.ps1 validates the same key through the same function, so the gate and this
    # count cannot silently drift apart (#1781). 'version' is still PROBED here, because Set-StrictMode
    # throws on an absent property and that one has no shared reader.
    $agents = @(Get-ManifestAgentEntries -Manifest $json).Count
    $version = if ($json.PSObject.Properties['version']) { $json.version } else { $null }
    return [pscustomobject]@{ Found = $true; Version = $version; AgentCount = $agents }
}

function Get-PluginDetails {
    <#
        Runs `claude plugin details <id>` and parses it. The ONE place that command is invoked (measure-skill
        and measure-session-start both call it). Returns Ok=$false with a Reason when the command fails,
        else Ok=$true with the fields Read-PluginDetailsOutput returns, plus Raw (the lines as printed) so a
        caller can say how much came back when the parse is refused.
    #>
    param([Parameter(Mandatory = $true)][string]$PluginId)

    $res = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'details', $PluginId)
    $lines = @($res.Output | ForEach-Object { [string]$_ })
    if ($res.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok     = $false
            Reason = "claude plugin details exited $($res.ExitCode)"
            Raw    = $lines
        }
    }

    $parsed = Read-PluginDetailsOutput -Lines $lines
    return [pscustomobject]@{
        Ok                = $true
        Version           = $parsed.Version
        AlwaysOnTotal     = $parsed.AlwaysOnTotal
        InventoryCounts   = $parsed.InventoryCounts
        RowProducingCount = $parsed.RowProducingCount
        InventorySkills   = $parsed.InventorySkills
        Rows              = $parsed.Rows
        Raw               = $lines
    }
}

function Get-InstalledVersionForRepo {
    <#
        The version of this plugin the INSTALL RECORD says this repo loads: the record for the repo's own
        project path first, then a machine-wide one with no path. $null when none exists.

        IT IS NOT THE VERSION `claude plugin details` PRICES, and that is why both callers read it (#2670).
        The details command takes no project path, and it does not price the copy the record pins:
        measured October 1, 2026, it priced dkj-policy at 5.10.0 for a checkout whose record said 5.8.0, and
        later the same day at 5.11.0 when run from a checkout whose record said 5.9.0. So a caller that wants
        to say what a session HERE pays compares the two, rather than assuming they agree.

        Moved here from session-start-lib.ps1 so measure-skill.ps1 asks the question the same way. It reads
        a file, through check-report-lib's Get-InstallRecord, which the caller has already dot-sourced --
        both callers do, and loading it here as well would only redefine it. -UserHomeOverride is for
        fixtures, passed straight through.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginId,
        [string]$UserHomeOverride = ''
    )
    $rec = Get-InstallRecord -RepoRoot $RepoRoot -UserHomeOverride $UserHomeOverride
    foreach ($map in @($rec.RecordsById, $rec.PathlessById)) {
        if ($null -eq $map) { continue }
        if ($map.ContainsKey($PluginId)) {
            $first = @($map[$PluginId] | Where-Object { $_.Version } | Select-Object -First 1)
            if ($first.Count -eq 1) { return [string]$first[0].Version }
        }
    }
    return $null
}

function Test-PricedIsLoaded {
    <#
        Is the version `claude plugin details` priced the one this checkout loads? True where the two
        agree, and also where either is unknown -- an absent record or an unparsed version is no evidence
        of a gap, and a warning that fires on missing data would teach a reader to ignore it (#2670).
    #>
    param([string]$Installed = '', [string]$Priced = '')
    if (-not $Installed -or -not $Priced) { return $true }
    return ($Installed -eq $Priced)
}

function Test-SkillModelInvocationDisabled {
    <#
        Does this SKILL.md carry `disable-model-invocation: true` in its frontmatter? Only the frontmatter
        counts -- the first '---' block -- and only a top-level key: a line further down the page, or an
        indented one, is prose or a nested value and not the flag. Quoted `"true"` counts. An unreadable or
        absent file is $false here; the CALLER decides what an absent file means (see
        Split-SkillRowsByInvocation, which keeps the question apart from the answer).
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $text = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
    $text = $text -replace "`r`n", "`n"
    if (-not $text.StartsWith("---`n")) { return $false }
    $close = $text.IndexOf("`n---", 4)
    if ($close -lt 0) { return $false }
    $front = $text.Substring(4, $close - 4)
    return ($front -match '(?m)^disable-model-invocation:\s*["'']?true["'']?\s*(#.*)?$')
}

function Get-PayloadDirForPlugin {
    <#
        The PAYLOAD directory of the copy `claude plugin details` priced -- the only one whose SKILL.md files
        say which of the priced rows are really loaded. That is not necessarily the copy this repo's install
        record pins (#2670): Get-InstalledVersionForRepo reads that one. Picks the install record whose
        version equals the version the details command reported (any scope: a plugin enabled for the whole
        machine has a record with no projectPath), then falls back to any record that exists on disk, then to
        the newest cached version. Returns $null when none exists.

        Returns an object so the caller can say when it had to settle: Dir, Version, Exact (the version
        matched the one measured).

        Reads through check-report-lib's Get-InstallRecord, Get-UserClaudeHome and Get-CachedPluginDirs,
        which every caller has already dot-sourced -- the same arrangement as Get-InstalledVersionForRepo.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginId,
        [string]$Version = ''
    )

    $candidates = @()
    $rec = Get-InstallRecord -RepoRoot $RepoRoot
    foreach ($map in @($rec.RecordsById, $rec.PathlessById)) {
        if ($null -eq $map) { continue }
        if ($map.ContainsKey($PluginId)) { $candidates += @($map[$PluginId]) }
    }
    $candidates = @($candidates | Where-Object { $_.InstallPath -and (Test-Path -LiteralPath $_.InstallPath -PathType Container) })

    if ($Version) {
        $hit = @($candidates | Where-Object { $_.Version -eq $Version } | Select-Object -First 1)
        if ($hit.Count -eq 1) { return [pscustomobject]@{ Dir = $hit[0].InstallPath; Version = $hit[0].Version; Exact = $true } }
    }
    # THE CACHE BY VERSION NEXT, before settling for an install record of another version. Measured
    # October 1, 2026: `claude plugin details` priced dkj-policy at 5.10.0 while this checkout's install
    # record said 5.8.0, and 5.10.0 was sitting in the cache -- so the rows being split are the cache
    # copy's, and its SKILL.md files are the ones that say which of them are loaded.
    $cached = @()
    $parts = $PluginId -split '@', 2
    if ($parts.Count -eq 2) {
        $userHome = Get-UserClaudeHome
        if ($userHome) {
            $cacheRoot = Join-Path $userHome '.claude\plugins\cache'
            $cached = @(Get-CachedPluginDirs -Name $parts[0] -Marketplace $parts[1] -CacheRoot $cacheRoot)
        }
    }
    if ($Version) {
        $hit = @($cached | Where-Object { (Split-Path $_ -Leaf) -eq $Version } | Select-Object -First 1)
        if ($hit.Count -eq 1) { return [pscustomobject]@{ Dir = $hit[0]; Version = $Version; Exact = $true } }
    }
    if ($candidates.Count -gt 0) {
        return [pscustomobject]@{ Dir = $candidates[0].InstallPath; Version = $candidates[0].Version; Exact = (-not $Version) }
    }
    if ($cached.Count -gt 0) {
        return [pscustomobject]@{ Dir = $cached[0]; Version = (Split-Path $cached[0] -Leaf); Exact = $false }
    }
    return $null
}

function Split-SkillRowsByInvocation {
    <#
        Splits the per-skill rows of one plugin into the skills a session LOADS and the ones it does not
        (disable-model-invocation: true). The skill pages are read from -SkillsDir (<payload>/skills).

        A skill whose SKILL.md cannot be found is kept in Loaded and named in Unverified. That is the
        conservative direction on purpose: dropping a row nobody could check would shrink the figure on a
        guess, and a smaller, healthier-looking number is the one wrong answer a measurement must not give.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [string]$SkillsDir = ''
    )

    $loaded = @()
    $excluded = @()
    $unverified = @()
    foreach ($row in @($Rows)) {
        $page = ''
        if ($SkillsDir) { $page = Join-Path (Join-Path $SkillsDir $row.Component) 'SKILL.md' }
        if (-not $page -or -not (Test-Path -LiteralPath $page -PathType Leaf)) {
            $unverified += $row.Component
            $loaded += $row
            continue
        }
        if (Test-SkillModelInvocationDisabled -Path $page) { $excluded += $row } else { $loaded += $row }
    }
    return [pscustomobject]@{ Loaded = @($loaded); Excluded = @($excluded); Unverified = @($unverified) }
}
