<#
.SYNOPSIS
    The progress record a long-running script PUBLISHES and the statusline RENDERS -- issue #2101.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\run-progress-lib.ps1')

    WHY THIS EXISTS. A run this session backgrounds prints to nobody. Measured on Claude Code 2.1.276
    and stated in its own documentation: a Bash call made with run_in_background streams no stdout to
    any visible surface at all -- the output is retrievable afterwards, from /tasks or the task's
    output file, and that is a different thing from watching a run. The terminal CLI and the VS Code
    extension behave the same way here. So the gate's own progress line (#1717) and ship-pr's watch
    are written for a reader who, in the one case they were needed for, is not there.

    THE ONE SURFACE THAT SURVIVES THAT is the statusLine: a command Claude Code re-runs and re-renders
    persistently, independent of whose output is being buffered where. It has a refreshInterval, and
    that setting exists for exactly this -- the documentation says the event-driven triggers "can go
    quiet when the main session is idle", which is precisely the state a backgrounded run leaves the
    session in. There is no native progress UI to hook instead: none is documented, and no marker a
    script can emit turns into one.

    SO THE SHAPE IS PUBLISH-AND-RENDER, NOT PRINT. The script that knows its own progress writes a
    small record; the statusline reads every live record and draws the bar. The two halves never meet
    in a pipe, which is the point -- the pipe is what the background hides.

    THE RENDERER DERIVES ELAPSED ITSELF, and that is load-bearing rather than an optimisation. The
    producer this was built for spends most of its life blocked inside one child call: ship-pr's watch
    hands twelve minutes to `gh pr checks --watch` in a single invocation, so a design where the bar
    advances only when the producer writes would freeze for the whole wait it exists to cover. The
    record carries the moment the run STARTED; the age of the file is not the age of the run.

    WHICH MAKES STALENESS THE WRONG LIVENESS TEST, and it is deliberately not used as one. A record
    untouched for ten minutes is the normal state of a healthy watch. What says a run is over is that
    its WRITER is gone, so that is what is asked -- the process id, plus that process's start time, so
    a pid the OS has since handed to somebody else cannot resurrect a finished run's bar. A hard age
    cap sits behind both as the last resort for a machine that was powered off mid-run.

    AND A WEDGED RUN GOES ON BEING SHOWN, on purpose. #1941 measured a 30-lane gate sitting for 141
    minutes printing nothing; a bar that hid itself after a few quiet minutes would have hidden
    exactly that. Alive and silent is a state the reader wants to see, not one to tidy away.

    ASCII GLYPHS, AND THE REASON IS THIS REPO'S OWN PROHIBITION. A bar of U+2588 blocks would be
    nicer to look at and it would have to survive Windows PowerShell 5.1's stdout encoder, which uses
    the console code page -- and the one repair for that, [Console]::OutputEncoding, is SetConsoleOutputCP,
    console-WIDE, which .claude/rules/language-layers.md forbids outright and which the test gate's
    shared console is the standing reason for. The alternative, writing raw UTF-8 bytes to the standard
    output stream, works and adds a second output path to a script that runs every couple of seconds
    forever. '#' and '-' cost nothing in meaning and cannot arrive as mojibake in the one line that is
    always on screen. The source of this file is ASCII either way -- check 27 holds every .ps1 to that.

    NO ETA, EVER. Format-GateProgressLine states the argument at length and it transfers unchanged:
    the only durations available to extrapolate from are another machine's, the sign of the difference
    is not fixed, and a wrong remaining-time printed twice a second is a worse diagnostic than no
    remaining-time at all. Counts and the run's own clock are measurements; the remainder is not.

    Pure ASCII (repo convention for .ps1).
#>

# THE DIRECTORY LIVE RECORDS SIT IN -- per-user, for session-cache-lib.ps1's reasons rather than for
# new ones: a record is written by one process and read by another, so the path has to be derivable
# twice and New-ScratchPath's guid cannot serve; and a predictable leaf under a SHARED temp root is
# what #1659 closed, so this goes where LOCALAPPDATA and XDG_CACHE_HOME are per-user by construction.
# A DIRECTORY OF ITS OWN rather than a subject inside that cache: these entries are reaped on a
# liveness test, not on an age, and mixing two reap rules in one tree is how one starts deleting the
# other's files.
$script:RunProgressDirName = 'dkj-run-progress'

# THE LAST-RESORT AGE CAP. Not a staleness test -- see the header -- but the answer to the one state
# the liveness test cannot reach: a machine powered off mid-run leaves a record whose pid means
# nothing, and after a reboot pid 8124 is somebody. Twelve hours is far past any run this workflow
# has (#1941's deadlocked gate sat for 141 minutes, the longest thing on record) and far short of
# "forever".
$script:RunProgressMaxAgeHours = 12

function Get-RunProgressRoot {
    <#
        The directory live progress records live in. -Override exists for the suite, so a scenario
        writes into its own fixture and can assert on what is and is not there afterwards; nothing
        shipped passes it.
    #>
    param([string]$Override = '')

    if ($Override) { return $Override }

    $base = ''
    foreach ($candidate in @($env:LOCALAPPDATA, $env:XDG_CACHE_HOME)) {
        if ($candidate) { $base = $candidate; break }
    }
    if (-not $base -and $env:HOME) { $base = Join-Path $env:HOME '.cache' }
    # No per-user directory is nameable: the caller gets a path under the module rather than a guess
    # at somebody's home. A write there normally fails, which under this file's contract means "no
    # bar" -- the correct degradation, and never an error in a producer's own run.
    if (-not $base) { $base = $PSScriptRoot }
    return (Join-Path $base $script:RunProgressDirName)
}

function Get-RunProgressId {
    <#
        A record's file-name stem, made safe without being made ambiguous.

        The caller names WHAT is running ('test-gate', 'ship-pr-ci'); this appends the writer's pid,
        because two of the same thing running at once is ordinary here -- the gate drives itself over
        a fixture in its own suite, and a lane is a second checkout shipping beside the first. Without
        the pid the second run would overwrite the first's record and the bar would jump between two
        unrelated runs with nothing saying so.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$ProcessId = $PID
    )
    $safe = ($Name -replace '[^A-Za-z0-9._-]', '-')
    if (-not $safe) { $safe = 'run' }
    return ("$safe-$ProcessId")
}

function Get-RunProgressProcessStartTicks {
    <#
        The writer process's start time, in UTC ticks -- the half of the liveness test that makes it
        safe against pid reuse.

        RETURNS 0 WHEN IT CANNOT BE READ, and 0 means "do not use this half". Process.StartTime
        throws on a process the caller may not query, and that is a normal state rather than an
        error: the run is still perfectly able to publish a bar. Losing the reuse guard costs a
        stale bar in a rare case; throwing here would cost the run.
    #>
    param([int]$ProcessId = $PID)
    try {
        $p = Get-Process -Id $ProcessId -ErrorAction Stop
        return $p.StartTime.ToUniversalTime().Ticks
    } catch { return 0 }
}

function Write-RunProgress {
    <#
        Publish (or update) one run's progress record.

        -Current/-Total ARE OPTIONAL AND THE BAR FOLLOWS THEM. A producer that honestly knows how
        many of how many -- the gate does, every lane event -- gets a bar. One that does not, which
        is ship-pr waiting on a check whose internals it cannot see, publishes a label and its start
        time and gets an elapsed readout with no bar. That asymmetry is the honest one: a bar is a
        fraction, and a fraction nobody measured is an invention.

        -StartedUtc is passed on every update, by the caller that already holds its own stopwatch, so
        the run's clock is the run's rather than the first write's.

        IT NEVER THROWS. A producer calls this from inside its hot loop; a progress record that
        cannot be written must cost that run nothing at all. Every failure path returns $false.

        -WriterPid PUBLISHES ON BEHALF OF ANOTHER PROCESS (issue #2104), and it exists because the
        liveness test above is the writer's PROCESS. The two producers this file was built for are
        long-lived -- the gate and ship-pr each stay alive for the whole run they describe -- so
        stamping $PID was the same thing as stamping the run. A HOOK is not: a PostToolUse hook that
        wants to publish a backgrounded shell's progress lives about 400 ms and then exits, so a record
        under its own pid is reaped by the very next statusline read, two seconds later.

        So the caller may name the process whose life IS the run. The pid and its start ticks are read
        together, from that process, because the pair is what makes the liveness test safe against pid
        reuse -- passing one without the other would leave a record that a recycled pid could resurrect.
        Omitted, it is $PID exactly as before, which is what every existing producer wants.

        IT IS NOT VALIDATED AGAINST ANYTHING. A pid that is already gone simply produces a record the
        next read drops, which is the correct outcome and not an error worth a return value: the run it
        described was over before the record landed.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Label,
        [AllowNull()][object]$Current = $null,
        [AllowNull()][object]$Total = $null,
        [string]$Note = '',
        [AllowNull()][object]$StartedUtc = $null,
        [string]$Root = '',
        # 0 means "this process" -- see -WriterPid in the block above.
        [int]$WriterPid = 0
    )

    try {
        $dir = Get-RunProgressRoot -Override $Root
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }

        $started = if ($StartedUtc -is [datetime]) { ([datetime]$StartedUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
        $writerProcessId = if ($WriterPid -gt 0) { $WriterPid } else { $PID }

        $record = [ordered]@{
            id             = $Id
            label          = $Label
            note           = $Note
            current        = $(if ($null -ne $Current) { [int]$Current } else { $null })
            total          = $(if ($null -ne $Total) { [int]$Total } else { $null })
            startedUtc     = $started.ToString('o')
            updatedUtc     = (Get-Date).ToUniversalTime().ToString('o')
            # READ ONCE INTO A LOCAL, so the pid in the record and the pid the ticks were read from
            # cannot drift apart -- the pair is the whole reuse guard, and two separate conditionals
            # would be two chances to answer them differently.
            writerPid      = $writerProcessId
            writerStartTicks = (Get-RunProgressProcessStartTicks -ProcessId $writerProcessId)
        }

        $path = Join-Path $dir ($Id + '.json')
        # WRITE ASIDE, THEN MOVE. The reader is a statusline firing on its own clock, so it WILL land
        # mid-write sooner or later; a rename is the cheapest thing that makes a torn read impossible
        # rather than merely unlikely. Same directory, so the move stays a rename and not a copy.
        $tmp = "$path.$PID.tmp"
        # BOM-less UTF-8 through WriteAllText: Set-Content -Encoding utf8 means WITH BOM in Windows
        # PowerShell 5.1, and a BOM in front of a JSON document is what ConvertFrom-Json chokes on.
        [System.IO.File]::WriteAllText($tmp, ($record | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $path -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Complete-RunProgress {
    <#
        Remove one run's record: the run is over, so its bar goes.

        THE LIVENESS TEST MEANS THIS IS A TIDY-UP RATHER THAN A CONTRACT. A producer killed before it
        reaches this line leaves a record behind, and the reader drops it on the next read because the
        writer is gone -- so forgetting to call this degrades to a bar that disappears a second or two
        late, not to one that never goes. That is why no producer needs a try/finally to be correct.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Root = ''
    )
    try {
        $path = Join-Path (Get-RunProgressRoot -Override $Root) ($Id + '.json')
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
        return $true
    } catch {
        return $false
    }
}

function Test-RunProgressWriterAlive {
    <#
        Is the process that published this record still there?

        TWO FIELDS, AND THE SECOND IS WHY THIS IS NOT JUST Get-Process. A pid alone comes back true
        for whatever the OS handed that number to after the run ended. The recorded start time pins
        the identity: same pid AND same start time is the same process. Where the start time could
        not be read at publish time (0) or cannot be read now, the pid alone stands -- degraded, and
        still better than treating an ordinary permission refusal as death.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Record)

    if ($null -eq $Record) { return $false }
    $recordedPid = 0
    if (-not [int]::TryParse("$($Record.writerPid)", [ref]$recordedPid) -or $recordedPid -le 0) { return $false }

    $proc = Get-Process -Id $recordedPid -ErrorAction SilentlyContinue
    if (-not $proc) { return $false }

    $recordedTicks = 0
    [void][long]::TryParse("$($Record.writerStartTicks)", [ref]$recordedTicks)
    if ($recordedTicks -le 0) { return $true }

    $liveTicks = 0
    try { $liveTicks = $proc.StartTime.ToUniversalTime().Ticks } catch { return $true }
    return ($liveTicks -eq $recordedTicks)
}

function Remove-OrphanedRunProgressTemp {
    <#
        Delete the '.json.<pid>.tmp' files no writer is coming back for -- issue #2174.

        WHY THE MAIN LOOP CANNOT DO THIS. Write-RunProgress writes aside and then moves into place,
        so a producer killed between those two statements leaves '<id>.json.<pid>.tmp' behind. The
        reader below globs '*.json', which that name is not, so both of its reaping paths -- the age
        cap and the liveness test -- sit inside a loop the file never enters. Nothing ever looked at
        it again, and a killed producer is ordinary here: a backgrounded ship dies with its harness.

        THE PID COMES OUT OF THE NAME, NOT OUT OF THE FILE. The content may be the torn half-write
        this whole scheme exists to hide from the reader, so it is never parsed. The name is written
        by this lib one function up and carries the id of the process that was doing the writing --
        which is $PID there, deliberately, and NOT the record's writerPid: -WriterPid names the
        process whose life is the RUN, while what abandoned this file is the process whose life was
        the WRITE.

        A NAME THIS LIB DID NOT WRITE IS LEFT ALONE, which is the same rule the reader states over
        its unparseable records: something else having put a file here is not this function's
        business to clean up. So the match is the exact shape above and not a '*' glob -- a widened
        sweep would have been the cheaper repair and it is the one that starts destroying evidence.

        THE TWO REAP RULES ARE THE READER'S OWN, IN THE READER'S ORDER. Past the hard age cap it
        goes whatever the pid says, because after a reboot that number belongs to somebody else;
        otherwise it goes when its writer is gone. The age is the file's mtime rather than a
        startedUtc, for the reason the pid is read off the name.

        It never throws: this runs inside a reader that must cost a producer nothing at all.
    #>
    param(
        [string]$Root = '',
        [AllowNull()][object]$NowUtc = $null
    )

    $now = if ($NowUtc -is [datetime]) { ([datetime]$NowUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
    $dir = Get-RunProgressRoot -Override $Root
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return 0 }

    $temps = @()
    # '*.tmp' AND THEN A REGEX, rather than the whole pattern in -Filter: Windows matches a -Filter
    # against the 8.3 short name as well as the long one, so a multi-dot glob there answers a
    # question about a name nobody chose. The filter narrows, the regex decides.
    try { $temps = @(Get-ChildItem -LiteralPath $dir -Filter '*.tmp' -File -ErrorAction Stop) } catch { return 0 }

    $removed = 0
    foreach ($file in $temps) {
        if ($file.Name -notmatch '\.json\.(?<pid>[0-9]+)\.tmp$') { continue }
        $writerPid = 0
        if (-not [int]::TryParse($Matches['pid'], [ref]$writerPid) -or $writerPid -le 0) { continue }

        $doomed = $false
        if (($now - $file.LastWriteTimeUtc).TotalHours -gt $script:RunProgressMaxAgeHours) {
            $doomed = $true
        } elseif (-not (Test-RunProgressWriterAlive -Record ([pscustomobject]@{ writerPid = $writerPid; writerStartTicks = 0 }))) {
            # START TICKS 0 IS THE DOCUMENTED DEGRADED MODE, and it is the only one available: the
            # name carries a pid and nothing else. So a recycled pid keeps a stray tmp alive until
            # the age cap above catches it, which is the safe direction to err in: one small file
            # for at most twelve hours, against deleting the file of a writer that is still running.
            $doomed = $true
        }

        if ($doomed) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                # COUNTED ONLY ONCE IT IS ACTUALLY GONE. SilentlyContinue is what keeps this from
                # costing a producer anything, and it is also what makes an unconditional count a
                # claim nobody checked -- a file the writer's own Move-Item took first, or one a
                # permission refused, would be reported as reaped without having been.
                if (-not (Test-Path -LiteralPath $file.FullName)) { $removed++ }
            } catch { }
        }
    }

    return $removed
}

function Get-LiveRunProgress {
    <#
        Every run currently publishing, newest first -- and the dead ones deleted on the way past.

        REAPING HERE RATHER THAN IN A SWEEPER is deliberate: this function runs every couple of
        seconds for as long as a session is open, so the directory is tidied continuously by the one
        party that has just proved each record dead. Nothing else has to remember.

        AND THE ABANDONED '.tmp' FILES GO ON THE SAME PASS (#2174), for the same reason and by
        the same party -- see Remove-OrphanedRunProgressTemp. They are swept separately because
        the loop below reads records, and the whole point of a leftover tmp is that there is no
        record in it to read.

        NEWEST FIRST because the statusline shows one line and the run a reader is asking about is
        the one that just started -- the gate opening inside a ship, not the ship it opened inside of.
    #>
    param(
        [string]$Root = '',
        [AllowNull()][object]$NowUtc = $null
    )

    $now = if ($NowUtc -is [datetime]) { ([datetime]$NowUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
    $dir = Get-RunProgressRoot -Override $Root
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }

    [void](Remove-OrphanedRunProgressTemp -Root $Root -NowUtc $now)

    $live = @()
    $files = @()
    try { $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction Stop) } catch { return @() }

    foreach ($file in $files) {
        $record = $null
        try {
            $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
            if ($raw) { $record = $raw | ConvertFrom-Json }
        } catch {
            # A HALF-WRITTEN OR CORRUPT RECORD IS SKIPPED, NOT DELETED. The move above makes a torn
            # read impossible for this lib's own writers; something else having put a file here is
            # not this function's business to clean up, and deleting what it cannot parse is how a
            # reader starts destroying evidence.
            continue
        }
        if ($null -eq $record) { continue }

        $started = [datetime]::MinValue
        if (-not [datetime]::TryParse("$($record.startedUtc)", [ref]$started)) { continue }
        $started = $started.ToUniversalTime()

        if (($now - $started).TotalHours -gt $script:RunProgressMaxAgeHours) {
            try { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue } catch { }
            continue
        }
        if (-not (Test-RunProgressWriterAlive -Record $record)) {
            try { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue } catch { }
            continue
        }

        $live += [pscustomobject]@{
            Id        = "$($record.id)"
            Label     = "$($record.label)"
            Note      = "$($record.note)"
            Current   = $(if ($null -ne $record.current) { [int]$record.current } else { $null })
            Total     = $(if ($null -ne $record.total) { [int]$record.total } else { $null })
            StartedUtc = $started
            # A DOUBLE, AND KEPT ONE. [math]::Max(0, ...) here would bind the int overload and round the
            # elapsed to a whole second before the formatter ever saw it -- the same trap Format-ElapsedShort
            # names below, one call earlier and invisible because the formatter floors anyway.
            ElapsedSeconds = $(if (($now - $started).TotalSeconds -lt 0) { 0.0 } else { ($now - $started).TotalSeconds })
        }
    }

    return @($live | Sort-Object -Property StartedUtc -Descending)
}

function Format-ProgressBar {
    <#
        '[####------]' for a fraction, at a fixed width.

        The fraction is CLAMPED rather than trusted: a producer that publishes 85 of 84 -- which a
        re-queued suite could -- gets a full bar instead of a line that overruns the statusline and
        pushes everything after it off the screen.
    #>
    param(
        [Parameter(Mandatory = $true)][double]$Fraction,
        [int]$Width = 12
    )
    if ($Width -lt 1) { $Width = 1 }
    $f = $Fraction
    if ($f -lt 0) { $f = 0 }
    if ($f -gt 1) { $f = 1 }
    $filled = [int][math]::Round($f * $Width)
    if ($filled -gt $Width) { $filled = $Width }
    return ('[' + ('#' * $filled) + ('-' * ($Width - $filled)) + ']')
}

function Format-ElapsedShort {
    <#
        '42s', '6m12s', '2h05m' -- the run's own clock, short enough to sit in a status line.

        Every number formatted through the invariant culture, for the reason Format-GateSeconds
        states: on a Dutch machine '{0:N0}' renders 2182 as '2.182', which an English reader of this
        repo reads as two-point-something. A figure must not depend on the machine that printed it.
    #>
    param([Parameter(Mandatory = $true)][double]$Seconds)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    # NOT [math]::Max(0, $Seconds) -- that is the well-formed wrong answer this repo keeps a trap list
    # for. A literal 0 is an [int], so PowerShell's overload resolution picks Max(int, int) and CONVERTS
    # the double by ROUNDING it: 59.9 comes back as 60, and the floor below then has nothing left to
    # floor. Caught by this file's own suite -- '59s' rendered as '1m00s'. A plain comparison cannot
    # pick an overload and cannot round.
    if ($Seconds -lt 0) { $Seconds = 0 }
    $s = [int][math]::Floor($Seconds)
    if ($s -lt 60) { return [string]::Format($inv, '{0}s', $s) }
    if ($s -lt 3600) { return [string]::Format($inv, '{0}m{1:00}s', [int][math]::Floor($s / 60), ($s % 60)) }
    return [string]::Format($inv, '{0}h{1:00}m', [int][math]::Floor($s / 3600), [int][math]::Floor(($s % 3600) / 60))
}

function Format-RunProgressLine {
    <#
        One live record as the line the statusline prints.

        WITH COUNTS:     [#####-------] 37/84  test gate  +6m12s
        WITHOUT COUNTS:  ...  ship-pr: waiting for CI  +11m48s

        THE LABEL IS TRIMMED TO A CEILING, because it reaches this function from a producer and a
        producer's label can carry a branch name, a suite path or a check title. A status line that
        wraps stops being a status line.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Record,
        [int]$BarWidth = 12,
        [int]$LabelWidth = 42
    )
    if ($null -eq $Record) { return '' }

    $label = "$($Record.Label)"
    if ($Record.Note) { $label = "$label ($($Record.Note))" }
    if ($label.Length -gt $LabelWidth) { $label = $label.Substring(0, [math]::Max(1, $LabelWidth - 3)) + '...' }

    $elapsed = '+' + (Format-ElapsedShort -Seconds ([double]$Record.ElapsedSeconds))

    $total = $Record.Total
    $current = $Record.Current
    if ($null -ne $total -and [int]$total -gt 0 -and $null -ne $current) {
        $bar = Format-ProgressBar -Fraction ([double][int]$current / [double][int]$total) -Width $BarWidth
        return ("$bar $([int]$current)/$([int]$total)  $label  $elapsed")
    }

    # NO COUNTS, NO BAR -- see the header. An indeterminate animation was the other option and it
    # would read as progress to anybody glancing at it, which is the one thing this must not do.
    return ("... $label  $elapsed")
}
