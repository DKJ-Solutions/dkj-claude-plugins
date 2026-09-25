<#
.SYNOPSIS
    Judging a test fixture's own git commands -- one source for the rule, dot-sourced by the suites
    under scripts/tests/ (issue #1635).

.DESCRIPTION
    Dot-source this file from a suite:

        . (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

    WHY THIS EXISTS. A suite in this directory builds its fixture with git -- init, config,
    symbolic-ref, add, commit, remote add, push, clone -- and the standing idiom for those calls was

        & git -C $dir init -q 2>$null | Out-Null

    inside a try that lowers $ErrorActionPreference. Lowering the preference is correct and stays: git
    writes ordinary progress to stderr, which under EAP=Stop is a terminating NativeCommandError before
    any exit code is read (the #96/#97/#107 pitfall this repo documents). What was NOT correct is that
    the exit code went with it: a git command that FAILED was indistinguishable from one that worked.

    WHY THAT IS WORSE IN A FIXTURE THAN IN PRODUCTION CODE. A production script that ignores a failed
    git usually goes on to fail visibly. A fixture that ignores one produces a repo that is PLAUSIBLE --
    it exists, it has a HEAD, it just does not hold what the case assumed -- and every assert below it
    then measures the wrong thing. The failure is attributed to the script under test, which is the one
    place it certainly is not.

    AND THE PARALLEL GATE IS WHAT MAKES IT RECURRING RATHER THAN THEORETICAL. Thirty concurrent lanes
    over one temp tree make a transient index.lock sharing violation, a scanner holding a file or disk
    pressure ordinary rather than rare -- so the shape to expect is a suite that is red under the gate,
    green on its own, and silent about why. That is the sighting #1622 recorded, in sync-main.tests.ps1.

    THE COUNT DOES NOT THROW, DELIBERATELY. A suite that dies at the first fixture hiccup reports less
    than one that runs on and names what broke. So a failure is printed and counted, and
    Write-FixtureGitSummary at the foot of the suite turns the count into an exit code -- INCLUDING when
    every assert passed, because a clean sweep over a repo that was never built proves less than it
    appears to.

    THE STATE LIVES IN THE CALLING SUITE'S SCRIPT SCOPE, which is what dot-sourcing means: the
    assignment below and the functions' own $script: lookups both resolve to the scope of the file that
    dot-sourced this one. Each suite is its own process under the gate, so there is nothing to share and
    nothing to reset between suites.

    AND SINCE #1655 SOMETHING ENFORCES IT. Adopting this lib was a sweep, and a sweep does not refuse the
    next copy of the idiom it removed -- which matters here because the idiom was the HOUSE STYLE rather
    than one author's slip, and the next fixture builder is written by copying the nearest neighbour.
    Check 35 ('[fixture-git]') in scripts/lint/check-plugin-integrity.ps1 walks scripts/tests/ for a git
    command whose result is discarded and whose exit code is judged on neither the same statement nor the
    next. That last clause is what lets a fixture MUTATION be told from a git QUESTION -- a
    'rev-parse --verify --quiet' on a ref expected to be absent answers with exit 1 and is read on the very
    next line -- so no verb is special-cased and no file is exempt. The sweep itself turned out to have
    missed four files, which the check found: see the system-administration lens for the numbers.

    Workshop-only -- scripts/tests/ is not mirrored into any plugin, so this lib is not registered in
    shared-scripts-lib.ps1 and has no mirror to drift from.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# EVERY FIXTURE git CALL THAT FAILED in the suite that dot-sourced this file. Initialized here rather
# than in each suite, so a suite cannot adopt the helper and forget the counter it reads.
$script:FixtureGitFailures = 0

function Assert-FixtureGitOk {
    <#
        Judge ONE fixture git call: on a non-zero exit code, print the command, print git's own output,
        and count it. Silent and free on the normal path.

        The caller keeps its own signature and its own EAP handling -- this function is only the verdict,
        because the suites in this directory pass their git arguments in four different shapes (a
        [string[]] parameter, ValueFromRemainingArguments, $args, a literal argument list) and rewriting
        every call site was never the point of #1635.

        -Output is git's combined output, captured by the caller with 2>&1. Passing it is optional: a
        caller that discarded the output still gets the exit code and the command named, which is the
        part that says a fixture is broken. Under Windows PowerShell 5.1 a native child's stderr captured
        with 2>&1 arrives wrapped in ErrorRecords -- harmless at EAP=Continue, which is where every
        caller here already is, and $LASTEXITCODE is unaffected by the wrapping. It is $? that the
        wrapping disturbs, and nothing here reads $?.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()][int]$Code,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$GitArgs,
        $Output = $null
    )
    if ($Code -eq 0) { return }
    $script:FixtureGitFailures++
    Write-Host "  [FIXTURE GIT FAILED] exit $Code -- git $($GitArgs -join ' ')" -ForegroundColor Magenta
    if ($null -ne $Output) {
        foreach ($line in (($Output | Out-String) -split "`r?`n")) {
            if ("$line".Trim()) { Write-Host "      $line" -ForegroundColor Magenta }
        }
    }
}

# HOW MANY FIXTURE git CALLS WERE RETRIED after a transport-level break (issue #2481). Counted apart
# from the failures: a retry that then succeeded is not a broken fixture, but a run that needed several
# is saying something about the machine, and Write-FixtureGitSummary prints it.
$script:FixtureGitRetries = 0

# THE OUTPUT OF A TRANSPORT THAT BROKE MID-TRANSFER, as opposed to a command git refused. Only the first
# was measured (#2481: `git push -q -u origin main` to a local bare remote, under 22 parallel lanes,
# 'send-pack: unexpected sideband packet', exit 128, green when re-run alone). The other two are the
# same class -- the pack stream between the two git processes ended early -- and are listed because a
# pattern that names only the one wording seen so far would miss the next wording of the same break.
$script:FixtureGitTransientPattern = 'unexpected sideband packet|the remote end hung up unexpectedly|early EOF'

function Get-FixtureGitVerb {
    <# The git subcommand in an argument vector, skipping the global options a fixture passes ahead of
       it: '-C <dir>' and '-c <key=value>'. Empty when there is none. #>
    param([AllowEmptyCollection()][string[]]$GitArgs)
    $i = 0
    while ($i -lt $GitArgs.Count) {
        $a = "$($GitArgs[$i])"
        if ($a -ceq '-C' -or $a -ceq '-c') { $i += 2; continue }
        if ($a.StartsWith('-')) { $i++; continue }
        return $a
    }
    return ''
}

function Test-FixtureGitTransientFailure {
    <#
        Whether ONE failed fixture git call is the kind worth running a second time: a push or a fetch
        whose output shows the transport breaking, rather than git refusing the operation (#2481).

        WHY ONLY push AND fetch. They are the verbs that talk to a remote over a pack stream, which is
        where this break lives, and they are safe to repeat: a push whose refs did land answers the
        retry with 'Everything up-to-date', and a fetch is a read. A commit, a merge or a checkout that
        failed has no transport to blame and may have half-happened, so retrying one would hide exactly
        the broken fixture the counter above exists to report. A clone is excluded too: a clone that
        broke leaves its target directory behind, and the retry would fail on that instead.

        WHY NOT A LOWER LANE COUNT, which #2481 also asked about. The lane formula is sized for memory
        and cores, and one suite's local push breaking under load once in 144 suites is not a reason to
        slow every suite on every run; a retry costs nothing on the ordinary path and one git call on
        the rare one.
    #>
    param(
        [AllowNull()][int]$Code,
        [AllowEmptyCollection()][string[]]$GitArgs,
        $Output = $null
    )
    if ($Code -eq 0) { return $false }
    if ((Get-FixtureGitVerb -GitArgs $GitArgs) -notin @('push', 'fetch')) { return $false }
    if ($null -eq $Output) { return $false }
    return (($Output | Out-String) -match $script:FixtureGitTransientPattern)
}

function Invoke-FixtureGitNative {
    <#
        Run one fixture git command with the EAP lowered and judge it -- retrying it ONCE where the
        failure is a transport break (Test-FixtureGitTransientFailure), and saying so. This is the body
        every suite-local git helper in scripts/tests/ had typed out for itself
        (`$out = & git @Arguments 2>&1` then Assert-FixtureGitOk), so they call this instead and the
        retry reaches all of them from one place.

        ONE retry, not a loop. A transport that breaks twice in a row on a local-file remote is no longer
        contention worth waiting out, and the second failure is judged and counted exactly as before.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Arguments)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & git @Arguments 2>&1
        $code = $LASTEXITCODE
        if (Test-FixtureGitTransientFailure -Code $code -GitArgs $Arguments -Output $out) {
            $script:FixtureGitRetries++
            Write-Host "  [FIXTURE GIT RETRY] exit $code, transport broke -- running once more: git $($Arguments -join ' ')" -ForegroundColor DarkYellow
            $out = & git @Arguments 2>&1
            $code = $LASTEXITCODE
        }
        Assert-FixtureGitOk -Code $code -GitArgs $Arguments -Output $out
    } finally { $ErrorActionPreference = $prevEap }
}

function Invoke-FixtureGitJudged {
    <#
        Run one git command with the EAP lowered, discard its output, and judge its exit code. The
        one-line replacement for the `& git ... 2>$null | Out-Null` idiom, for the suites whose fixture
        builders call git inline rather than through a helper of their own.

        -Arguments is the whole argument vector, '-C <dir>' included -- the same shape those inline call
        sites already had, so converting one is a substitution rather than a redesign.
    #>
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    Invoke-FixtureGitNative -Arguments $Arguments
}

function Invoke-FixtureGitIn {
    <#
        The same thing for the dominant idiom in this directory -- `& git -C $dir <rest>` -- so a call
        site converts by substitution rather than by being rewritten:

            & git -C $dir commit -q -m 'init' 2>$null | Out-Null
            Invoke-FixtureGitIn $dir commit -q -m 'init'

        FIRST ARGUMENT IS THE REPO DIRECTORY; everything after it is git's own argument vector.

        NO param() BLOCK, DELIBERATELY, and this is the whole reason the function is shaped like this.
        A param block makes it an advanced function, and PowerShell then tries to BIND every argument
        starting with a dash to a parameter name -- so `branch -D <name>` would resolve `-D` against a
        `-Dir`-style parameter and either take the branch name as the directory or fail on a duplicate.
        A simple function with no param block puts every argument in $args verbatim, dashes included,
        which is exactly what a pass-through to a native command needs. Measured shape, not a
        preference: git's own flags include -C, -c, -D, -R, -q, -m and -b, and a wrapper that binds any
        of them silently changes the command it was asked to run.
    #>
    $a = @($args | ForEach-Object { "$_" })
    if ($a.Count -lt 1) { throw 'Invoke-FixtureGitIn: the first argument is the repo directory.' }
    $rest = if ($a.Count -gt 1) { @($a[1..($a.Count - 1)]) } else { @() }
    Invoke-FixtureGitJudged (@('-C', $a[0]) + $rest)
}

function Get-FixtureGitFailureCount {
    <# How many fixture git commands failed so far. For a suite that wants to say so mid-run, and for
       this lib's own tests. #>
    return $script:FixtureGitFailures
}

function Get-FixtureGitRetryCount {
    <# How many fixture git commands were retried after a transport break so far (#2481). #>
    return $script:FixtureGitRetries
}

function Write-FixtureGitSummary {
    <#
        Print the broken-fixture block if anything failed, and return $true when it did -- which the
        caller turns into an exit code.

        WHY IT IS PRINTED ABOVE THE VERDICT AND EVEN ON A GREEN RUN. Every assert below a git command
        that failed is measuring a repo that was never built, so reading them as a judgement on the
        script under test is the wrong conclusion -- and it is the conclusion a reader reaches by
        default, because a red suite normally means the script regressed. A fixture that half-built and
        still went green is a case the suite is not testing, and the reader should know which run they
        are looking at.

        -Subject names the script under test, so the line says what the asserts are NOT a verdict on.
    #>
    param([string]$Subject = 'the script under test')
    if ($script:FixtureGitRetries -gt 0) {
        Write-Host "FIXTURE: $($script:FixtureGitRetries) git command(s) were retried after a transport break (issue #2481) -- see the [FIXTURE GIT RETRY] lines above." -ForegroundColor DarkYellow
    }
    if ($script:FixtureGitFailures -le 0) { return $false }
    Write-Host "FIXTURE: $($script:FixtureGitFailures) git command(s) FAILED while building this run's repos -- see the [FIXTURE GIT FAILED] lines above." -ForegroundColor Magenta
    Write-Host "         Whatever the asserts say, they are not a verdict on $Subject`: some of them read a repo that was never built." -ForegroundColor Magenta
    Write-Host "         Under the parallel test gate this is the shape to expect from contention (issue #1622) -- re-run the suite on its own before reading anything into it." -ForegroundColor Magenta
    Write-Host ''
    return $true
}
