<#
.SYNOPSIS
    Reads the per-suite duration tables and the shard wall-clock out of CI runs -- the one parser
    behind record-suite-durations.ps1 (which writes suite-durations.json) and measure-suites.ps1
    (which compares two sets of runs and writes nothing).

.DESCRIPTION
    WHY IT IS A LIB (issue #2775). The before/after comparison of a change's CI cost was done by hand
    twice in two days, and both times it needed record-suite-durations.ps1's log parsing pointed at
    scratch copies of scripts/tests so that it would not write the committed file. The parsing is the
    part worth keeping -- above all its row validation against the suites that really exist, because
    test-suite-gate.tests.ps1 prints a table over its own fixtures that a naive grep mixes in -- so it
    moved here rather than being copied into a second script.

    REPO-ONLY, like ci-merge-skip-lib.ps1: both callers read this repo's own CI workflow (its job
    names, its sharded suites job), so nothing here is mirrored into a plugin.

    The pure functions take lines and job objects, so the suite tests them without gh or a network.
    Read-RunSuiteSamples and Read-RunShardSeconds are the two that call gh; they need
    native-capture-lib.ps1 dot-sourced by the caller.
#>

# '   249.2s  new-branch.tests.ps1  started +40.9s' -- anchored on the trailing 'started +' so a line that
# merely mentions a suite and a number cannot match.
$script:SuiteDurationRowPattern = '\s(\d+(?:\.\d+)?)s\s+(\S+\.tests\.ps1)\s+started\s+\+'

function Split-RunIdList {
    <#
        SPLIT THE IDS OURSELVES, because `powershell -File` does not. Every documented way of running a
        script in this repo is `-File`, and in that mode PowerShell passes each argument as a LITERAL
        string: `-RunId 123,456` binds a one-element array holding the text "123,456", and gh then 404s
        on a run id nobody typed. Splitting on commas and whitespace makes the `-File` form and the
        `-Command` form (where the comma really is an array operator) agree.
    #>
    param([AllowEmptyCollection()][string[]]$RunId)
    return @(@($RunId) | ForEach-Object { "$_" -split '[,\s]+' } | Where-Object { $_ })
}

function Get-SuiteDurationRows {
    <#
        Every per-suite row in a run log whose suite name is in -KnownNames, as objects with Name and
        Seconds. A row naming anything else -- a fixture table, a suite since deleted or renamed -- is
        counted in the returned Dropped total and never kept. Pure.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Lines,
        [Parameter(Mandatory)][hashtable]$KnownNames
    )
    $rows = New-Object System.Collections.ArrayList
    $dropped = 0
    foreach ($line in @($Lines)) {
        $m = [regex]::Match("$line", $script:SuiteDurationRowPattern)
        if (-not $m.Success) { continue }
        $name = $m.Groups[2].Value
        if (-not $KnownNames.ContainsKey($name)) { $dropped++; continue }
        $rows.Add([pscustomobject]@{
            Name    = $name
            Seconds = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }) | Out-Null
    }
    return [pscustomobject]@{ Rows = @($rows); Dropped = $dropped }
}

function Get-KnownSuiteNames {
    <# THE ONLY NAMES THAT COUNT are the *.tests.ps1 files in -TestsDir right now. #>
    param([Parameter(Mandatory)][string]$TestsDir)
    $known = @{}
    Get-ChildItem -LiteralPath $TestsDir -Filter '*.tests.ps1' -File | ForEach-Object { $known[$_.Name] = $true }
    if ($known.Count -eq 0) { throw "No *.tests.ps1 suites in $TestsDir." }
    return $known
}

function Get-SuiteMeans {
    <# The mean per suite over the samples, rounded to 0.1s, as an ordered hashtable sorted by name. Pure. #>
    param([Parameter(Mandatory)][hashtable]$Samples)
    $means = [ordered]@{}
    foreach ($name in ($Samples.Keys | Sort-Object)) {
        $means[$name] = [Math]::Round(((@($Samples[$name]) | Measure-Object -Average).Average), 1)
    }
    return $means
}

function Get-ShardSeconds {
    <#
        Wall-clock seconds per shard of the sharded suites job, from `gh run view --json jobs` objects.
        A shard is a job named 'suites (<n>)'; any other job is not this measurement's subject, and a
        shard without both timestamps (cancelled before it started) is left out rather than read as 0.
        Returned as objects with Name and Seconds, in shard order. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Jobs)
    $out = foreach ($job in @($Jobs)) {
        $name = [string]$job.name
        $m = [regex]::Match($name, '^suites \((\d+)\)$')
        if (-not $m.Success) { continue }
        if (-not $job.startedAt -or -not $job.completedAt) { continue }
        $start = [datetime]::Parse([string]$job.startedAt, [System.Globalization.CultureInfo]::InvariantCulture,
                                   [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        $end   = [datetime]::Parse([string]$job.completedAt, [System.Globalization.CultureInfo]::InvariantCulture,
                                   [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        [pscustomobject]@{ Name = $name; Index = [int]$m.Groups[1].Value; Seconds = [Math]::Round(($end - $start).TotalSeconds) }
    }
    return @($out | Sort-Object Index)
}

function Get-FamilyTotals {
    <#
        The summed mean seconds per family, where -Family holds 'name=glob[;glob]' strings matched
        against the suite file names (-like, so case-insensitive). A suite can count in more than one
        family; one matching none counts in none. Pure.
    #>
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Means,
        [AllowEmptyCollection()][string[]]$Family
    )
    $totals = [ordered]@{}
    foreach ($spec in @($Family | Where-Object { $_ })) {
        $parts = "$spec" -split '=', 2
        if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
            throw "-Family '$spec' is not name=glob -- e.g. 'integrity=check-plugin-integrity-*'."
        }
        $globs = @($parts[1] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $sum = 0.0; $count = 0
        foreach ($name in $Means.Keys) {
            foreach ($g in $globs) { if ($name -like $g) { $sum += [double]$Means[$name]; $count++; break } }
        }
        $totals[$parts[0].Trim()] = [pscustomobject]@{ Seconds = [Math]::Round($sum, 1); Suites = $count }
    }
    return $totals
}

function Read-RunSuiteSamples {
    <#
        Reads one run's log through gh and adds every known suite's duration to -Samples (name ->
        ArrayList). Throws on an unreadable run and on a run with no table at all -- the fold and merge
        pushes ship-pr leaves on the trunk skip the suites, and their jobs complete green having
        measured nothing, so a silent zero would read as data. Returns the Dropped count.
    #>
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Slug,
        [Parameter(Mandatory)][hashtable]$KnownNames,
        [Parameter(Mandatory)][hashtable]$Samples
    )
    # -Utf8 because this output is PARSED, not echoed: Windows PowerShell 5.1 decodes a child's stdout
    # with the console code page, so the same log yields different strings on cp850 and cp65001.
    $run = Invoke-NativeCapture -FilePath 'gh' -Arguments @('run', 'view', $Id, '--repo', $Slug, '--log') -Utf8
    # THE UNMEASURABLE CODE IS ASKED FOR FIRST (issue #1931): `$null -ne 0` is true, so the throw below
    # would otherwise fire on a read that may have SUCCEEDED and quote the log's own opening lines as
    # the reason.
    if (-not (Test-NativeExitMeasured -Capture $run)) {
        throw "gh ran but its exit code could not be measured reading run ${Id} (issue #1931) -- nothing is known about the read, so no durations were taken from it. Run this again; the next process almost always answers."
    }
    if ($run.ExitCode -ne 0) { throw "gh could not read run ${Id}: $(@($run.Output) | Select-Object -First 3)" }

    $parsed = Get-SuiteDurationRows -Lines @($run.Output) -KnownNames $KnownNames
    if (@($parsed.Rows).Count -eq 0) {
        # Take a PR run: the 'fold:' push skips the suites by its subject (#1300), and the 'merge:' push
        # skips them whenever the merge-commit certificate proves its tree was already certified (#2303),
        # which is the normal case after ship-pr -- so both trunk runs a ship leaves behind are tableless.
        throw "run $Id printed no per-suite duration table - is it a CI run that ran the suites job? Take a PR run: a trunk push skips that step by design, the 'fold:' push by its subject (#1300) and the 'merge:' push whenever the merge-commit certificate proves its tree was already certified (#2303), which is the normal case after ship-pr."
    }
    foreach ($row in $parsed.Rows) {
        if (-not $Samples.ContainsKey($row.Name)) { $Samples[$row.Name] = New-Object System.Collections.ArrayList }
        $Samples[$row.Name].Add($row.Seconds) | Out-Null
    }
    return [pscustomobject]@{ Found = @($parsed.Rows).Count; Dropped = $parsed.Dropped }
}

function Read-RunShardSeconds {
    <# One run's shard wall-clock through `gh run view --json jobs`. Throws on an unreadable run. #>
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Slug
    )
    $call = Invoke-NativeCapture -FilePath 'gh' -Arguments @('run', 'view', $Id, '--repo', $Slug, '--json', 'jobs') -Utf8 -DiscardStderr
    if (-not (Test-NativeExitMeasured -Capture $call) -or $call.ExitCode -ne 0) {
        throw "gh could not read the jobs of run ${Id}."
    }
    $jobs = (@($call.Output) -join "`n" | ConvertFrom-Json).jobs
    return @(Get-ShardSeconds -Jobs @($jobs))
}

function Get-RepoSlugFromGh {
    <# owner/name of the current repository, through gh. #>
    $slugCall = Invoke-NativeCapture -FilePath 'gh' -Arguments @('repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner') -DiscardStderr
    if ($slugCall.ExitCode -ne 0) { throw 'gh could not resolve the current repository - is it authenticated here?' }
    return (@($slugCall.Output) | Where-Object { "$_".Trim() } | Select-Object -First 1).Trim()
}
