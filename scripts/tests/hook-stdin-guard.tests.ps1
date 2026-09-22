<#
.SYNOPSIS
    Tests the CLASS rather than an instance: every place this tree reads its own stdin through
    [Console]::In is gated on [Console]::IsInputRedirected.

.DESCRIPTION
    WHY A SUITE AND NOT TWO MORE ASSERTS IN THE TWO HOOKS' OWN FILES. #2249 named this family as
    three members. Repairing it swept the tree and found seven, four of them hooks, two of those
    reading stdin with no guard at all (#2264). The defect both times was the ENUMERATION -- the
    family was counted by hand, from memory, by somebody looking at the file in front of them -- so
    the regression guard that is worth having is the one that counts it out of the tree instead.
    A member added tomorrow is in scope the moment it is written, which is the property a per-file
    assert cannot have.

    WHAT AN UNGUARDED READ COSTS. An unredirected [Console]::In is a live console, and ReadToEnd on
    one waits for a Ctrl+Z that is never coming. Everything in this family is invoked by the harness
    with a real payload, so the guard never fires in production -- it fires the first time a person
    runs one of these by hand to find out why it did something, which is exactly the moment they
    need it to answer. show-progress.ps1 states the cost in its own comment: a thing that hangs the
    first time somebody looks at it by hand is a thing nobody will look at twice.

    THE TEST GAP, NAMED RATHER THAN PAPERED OVER. This suite reads the SOURCE, and it does so
    because the behaviour it is about cannot be reached from a test process. The failing case needs
    a child whose stdin is a live console; a suite is spawned with stdin redirected -- and since
    #2233 the test gate redirects every lane's stdin to an empty file on purpose -- so a child that
    inherits it gets a handle that is redirected and already at EOF. Both the guarded and the
    unguarded shape return immediately there, so a behavioural assert would pass on the defect. What
    IS asserted behaviourally is the value the guard produces: an empty payload, down each hook's
    own documented degradation path.

    NOT THE TIMEOUT. A guard answers "there is no handle"; a bound answers "there is a handle nobody
    will close". They are different failures with different prices -- the bound costs per firing and
    the guard costs a property read -- and #2264 separates them deliberately. This suite holds the
    guard only. When #2249's bound lands, the read sites change shape and this matcher is what will
    say which ones were missed.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

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

# THE MATCHER IS [Console]::In AND NOT THE WORD ReadToEnd. A StreamReader over a child process's
# stdout calls ReadToEnd too (native-capture-lib.ps1 does, twice), and that is somebody else's
# stream with somebody else's failure mode. What this suite is about is a script reading ITS OWN
# stdin, which is what [Console]::In names and nothing else does.
$ReadPattern  = '\[Console\]::In\.ReadToEnd'
$GuardPattern = '\[Console\]::IsInputRedirected'

# THREE LINES, because the family uses two shapes and both are correct: the guard on the same line
# as the read (an if with the assignment in its body), and the guard opening a block the read sits
# inside. The window is what keeps the second shape passing without letting a guard three screens up
# count as one.
$WindowLines = 3

Write-Host ""
Write-Host "-- group 1: every [Console]::In read in the tree is gated on IsInputRedirected" -ForegroundColor Cyan

# SCANNED OUT OF THE TREE, NOT LISTED HERE. A list in this file is the same hand-count that produced
# #2249's three and #2264's seven; the point of the suite is that nobody maintains the list.
# scripts/tests is excluded because a suite may legitimately write the unguarded shape into a
# fixture in order to assert that it is caught.
$files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.FullName -notmatch '\\scripts\\tests\\' -and $_.FullName -notmatch '\\\.git\\' }

# COMMENT LINES ARE NOT READ SITES, and skipping them is not a convenience. This family DOCUMENTS
# itself: session-cache-lib.ps1's docstring quotes the unguarded idiom verbatim in order to say what
# it improves on, and the two hooks repaired under #2264 now argue in prose about the very line
# below them. Counting prose would make every explanation of this hazard an instance of it -- so a
# file that explains itself well would be the one that fails, which is the incentive to get exactly
# backwards.
# A LITERAL PREFILTER AHEAD OF THE PER-LINE LOOP, and it buys the walk rather than the guarantee.
# The expensive half is not the file walk but the comment tracking: two [regex]::Matches calls and a
# -notmatch on every line of every script in the tree, ~183,000 lines to find ten sites. $ReadPattern
# has no live metacharacters -- every special character in it is escaped to its literal -- so a plain
# substring test over the whole file is byte-for-byte equivalent and can produce no false negative.
# Measured: 3.4-4.3s over 244 files, against 0.53-0.59s when only the ~10 files that can possibly
# match reach the loop. The file SET is unchanged, so this is still counted out of the tree.
$ReadLiteral = '[Console]::In.ReadToEnd'

$sites = @()
foreach ($f in $files) {
    $whole = Get-Content -LiteralPath $f.FullName -Raw
    if ($null -eq $whole -or -not $whole.Contains($ReadLiteral)) { continue }

    $lines = @(Get-Content -LiteralPath $f.FullName)
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        # THE COMMENT IS REMOVED FROM THE LINE, NOT THE LINE FROM THE SCAN. Counting the markers and
        # skipping any line that carried one was the first shape of this, and it hid a read site
        # written as `$raw = [Console]::In.ReadToEnd() <# why #>` -- a real unguarded read, silently
        # absent from a suite whose whole job is to find them. That shape is not far-fetched in a tree
        # that argues in prose on the lines either side of every one of these reads. So a complete
        # <# ... #> span is cut out and whatever is left is judged as code.
        $code = $lines[$i]

        # A block still open from an earlier line ends at the first #>; the remainder is code again.
        if ($inBlockComment) {
            $close = $code.IndexOf('#>')
            if ($close -lt 0) { continue }
            $code = $code.Substring($close + 2)
            $inBlockComment = $false
        }

        # Then every complete span on this line, and an unclosed <# opens a block and truncates here.
        while ($true) {
            $open = $code.IndexOf('<#')
            if ($open -lt 0) { break }
            $close = $code.IndexOf('#>', $open + 2)
            if ($close -lt 0) {
                $code = $code.Substring(0, $open)
                $inBlockComment = $true
                break
            }
            $code = $code.Remove($open, $close + 2 - $open)
        }

        # A TRAILING # COMMENT IS DELIBERATELY NOT STRIPPED. A '#' is a comment anywhere on a line but
        # is also an ordinary character inside a string, so cutting at one risks discarding real code.
        # Left alone, a prose mention after a '#' is reported as an unguarded site -- a FALSE POSITIVE,
        # which turns this suite red and is read by a person. Stripping it would risk a false negative,
        # which is silence. The error this suite may make is the loud one.
        if ($code.TrimStart().StartsWith('#')) { continue }
        if ($code -notmatch $ReadPattern) { continue }
        $from   = [Math]::Max(0, $i - $WindowLines)
        $window = ($lines[$from..$i] -join "`n")
        $sites += [pscustomobject]@{
            Path    = $f.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
            Line    = $i + 1
            Guarded = ($window -match $GuardPattern)
        }
    }
}

Write-Host "     the family, counted out of the tree: $($sites.Count) read site(s)" -ForegroundColor DarkGray
foreach ($s in $sites) {
    Write-Host "       $($s.Path):$($s.Line)" -ForegroundColor DarkGray
}

# A FLOOR ON THE COUNT, so a matcher that silently stops matching cannot report an empty family as a
# clean one. It is a floor and not an equality: a new member is the normal case and must not turn this
# suite red for existing.
#
# TEN IS THE SITE COUNT, NOT THE FILE COUNT. The family is 7 source files and 10 code sites, because
# three of the seven are mirrored into a plugin; a floor of 7 would tolerate losing three real sites --
# one half of a mirrored pair silently losing its guard, say -- which is the exact silence this assert
# exists to break.
#
# AND A DROP HERE HAS TWO CAUSES, BOTH OF WHICH WANT A LOOK. Either the matcher broke, or a read site
# legitimately changed shape -- which is what #2249's bound will do to session-cache-lib.ps1 when it
# lands, since OpenStandardInput().CopyToAsync() is not [Console]::In and this matcher will not see it.
# That second case is not a false alarm: a new way of reading stdin needs the same guard, and going red
# is how this suite says the matcher has to learn it rather than quietly stopping at the old shape. The
# enumeration printed above says which sites it did find, so telling the two apart is one look.
Assert-True ($sites.Count -ge 10) "the scan found the family (>= 10 sites, got $($sites.Count)) -- a drop means the matcher broke or a read changed shape, never that the tree is clean"

foreach ($s in $sites) {
    Assert-True $s.Guarded "$($s.Path):$($s.Line) reads stdin only where there is a handle"
}

Write-Host ""
Write-Host "-- group 2: the two hooks #2264 repaired, on the value their new guard produces" -ForegroundColor Cyan

# THE GUARD'S OUTPUT IS AN EMPTY PAYLOAD, and each hook has already written down where an empty
# payload lands. guard-working-copy fails OPEN ("cannot tell who this is" must not refuse the
# orchestrator's own git); guard-live-theme fails towards CHECKING on an unreadable payload, but an
# empty one carries no command to check, so there is no verdict to reach. Both are exit 0, for two
# different documented reasons -- which is why both are asserted rather than one standing for both.
function Invoke-HookWithEmptyStdin {
    param([string]$HookPath)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = 'powershell'
    $psi.Arguments              = '-NoProfile -ExecutionPolicy Bypass -File "' + $HookPath + '"'
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    # CLOSED IMMEDIATELY, which is the whole of the fixture: a redirected handle at EOF is what the
    # harness hands a hook on a payload-less call, and it is the one stdin state a test process can
    # produce honestly.
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    # BOUNDED, because this suite's whole subject is a read that does not return. An unbounded Wait
    # here would hang the gate on exactly the regression it exists to catch.
    if (-not $p.WaitForExit(30000)) {
        try { $p.Kill() } catch { }
        return [pscustomobject]@{ Code = -1; Out = $out; Err = $err }
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out; Err = $err }
}

$gwc = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\guard-working-copy.ps1'
$glt = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify\hooks\guard-live-theme.ps1'

Assert-True (Test-Path -LiteralPath $gwc -PathType Leaf) 'guard-working-copy.ps1 is where this suite expects it'
Assert-True (Test-Path -LiteralPath $glt -PathType Leaf) 'guard-live-theme.ps1 is where this suite expects it'

$r = Invoke-HookWithEmptyStdin -HookPath $gwc
Assert-Equal 0 $r.Code 'guard-working-copy: an empty payload reaches the documented fail-OPEN path'

$r = Invoke-HookWithEmptyStdin -HookPath $glt
Assert-Equal 0 $r.Code 'guard-live-theme: an empty payload carries no command, so there is no verdict to reach'

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
