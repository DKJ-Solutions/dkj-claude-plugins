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

    AND THE THIRD GROUP IS ABOUT THE WRAPPER, NOT THE HOOK (issue #2276). The guard's value is an empty
    payload, and for guard-live-theme.ps1 that ends the run WITHOUT a verdict -- which on a guard whose
    subject is a live customer-facing theme is the one direction its own header forbids. What keeps that
    from being a hole is the hooks.json wrapper piping the payload back in, so IsInputRedirected is true
    on every call the harness makes. That was the single load-bearing fact behind "no bypass" for both
    guards and it was asserted nowhere. It is a string in a JSON file, which is reachable, so group 3
    holds it: a wrapper that drains the payload with $(cat) must hand it back.

    AND THE FOURTH GROUP IS ABOUT THIS FILE'S OWN OUTPUT (issue #2280). Groups 1 and 3 both print values
    they did not author -- a tracked path off a tree walk, and a JSON property key off a parsed
    hooks.json -- into a CI log on a PUBLIC repository. Those prints now pass ref-print-lib.ps1's strip,
    dot-sourced at the head of this file for the reasons stated there, and group 4 is the counter-case
    that keeps the call from being a comment. The site is registered as entry 14 of the standing
    print-site list in plugins/dkj-policy/skills/new-branch/SKILL.md.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# THE VALUES THIS SUITE PRINTS ARE NOT ITS OWN (issue #2280). Two classes, both scanned out of the tree
# by the groups below rather than typed here: a tracked FILE PATH off a Get-ChildItem walk, and -- new
# with group 3 -- a JSON PROPERTY KEY read straight out of a parsed hooks.json. This suite runs in CI on
# every PR, in a PUBLIC repository, so whatever it prints reaches a public log before anybody has read
# the branch it describes.
#
# THE NEIGHBOURING LINT DOES NOT CLOSE IT, which is why a strip here is not belt-and-braces.
# check-plugin-integrity.ps1's tracked-name check holds every tracked path to three classes -- a
# private-use character (U+E000-U+F8FF), one of Windows' reserved characters, and a control character --
# and \p{Cf} is not among them. \p{Cf} is the class the strip exists for: an RTL override or a
# zero-width run makes a printed line read as something other than what it says. A path carrying one is
# tracked, committed and printed raw with that lint green. The JSON key is not a path at all, and no
# lint has an opinion about it.
#
# DOT-SOURCED RATHER THAN COPIED, between the two precedents this repo has already argued.
# asana-mirror.ps1 types the class out by hand because it SHIPS STANDALONE into a consumer where none of
# these libs exist (#2019) -- a dot-source there would name a path that is not there. A suite in
# scripts/tests never leaves this repo and scripts/lib sits beside it, so that argument does not reach
# here. A copy would cost what the copies already cost: pr-issues.tests.ps1 pins WHICH files carry the
# class by comparing them character for character, so a fifth copy is an edit to that pin as well. A
# dot-source is neither -- the pin counts files in scripts/lib that DEFINE
# ConvertTo-ConsoleStrippedText, and this file defines nothing.
#
# AND IT CANNOT PERTURB THE SCAN BELOW, which is the one thing a new load in this file could break.
# ref-print-lib.ps1 is a leaf: it dot-sources nothing, sets no preference variable, and contains neither
# read pattern group 1 matches on -- so loading it adds no site. Group 1's file SET is unchanged either
# way, since it excludes scripts/tests and already walks the lib.
. (Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1')

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

# TWO READ SHAPES, AND THE SECOND ONE ARRIVED WHILE THIS BRANCH WAS IN FLIGHT. The matcher knew only
# [Console]::In, and #2249 landed its bound mid-flight -- replacing that idiom with
# [Console]::OpenStandardInput().CopyToAsync() in all six of its sites. The count fell from 10 to 4
# and this suite went red in CI, which is the behaviour its own floor comment predicted: a new way of
# reading stdin needs the same guard, and going red is how the suite says the matcher has to learn it
# rather than quietly stopping at the old shape. So it learned it. Both are named, and a third shape
# will do exactly the same thing again -- that is the mechanism working, not a defect in it.
#
# WHAT IS NOT MATCHED IS THE WORD ReadToEnd. A StreamReader over a child process's stdout calls it too
# (native-capture-lib.ps1 does, twice), and that is somebody else's stream with somebody else's
# failure mode. Both entries below name [Console] and this process's OWN stdin, which is the subject.
$ReadPatterns = @(
    '\[Console\]::In\.ReadToEnd'
    '\[Console\]::OpenStandardInput'
)
$GuardPattern = '\[Console\]::IsInputRedirected'

# THE WINDOW COUNTS CODE LINES, NOT LINES, and #2249's own shape is why. It reads:
#
#     if (-not [Console]::IsInputRedirected) { return '' }
#     $sink = New-Object System.IO.MemoryStream
#     # two lines of comment about why CopyToAsync and not [Console]::In's async methods
#     if (-not ([Console]::OpenStandardInput().CopyToAsync($sink)).Wait($TimeoutMs)) { return '' }
#
# which is FOUR raw lines from guard to read and TWO code lines. Widening a raw-line window to reach
# it would weaken the heuristic everywhere -- the further back a textual guard may sit, the likelier
# it is an unrelated one. Counting only lines that survive comment-stripping keeps the window tight
# while following the code, and it is comment density that varies in this tree, not code density.
$WindowCodeLines = 3

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
# The expensive half is not the file walk but the comment tracking: the strip plus a match on every
# line of every script in the tree, ~183,000 lines to find ten sites. Neither pattern above has a
# live metacharacter -- every special character in both is escaped to its literal -- so a plain
# substring test over the whole file is byte-for-byte equivalent and can produce no false negative.
# Measured: 3.4-4.3s over 244 files, against 0.53-0.59s when only the handful that can possibly match
# reach the loop. The file SET is unchanged, so this is still counted out of the tree.
$ReadLiterals = @('[Console]::In.ReadToEnd', '[Console]::OpenStandardInput')

$sites = @()
foreach ($f in $files) {
    $whole = Get-Content -LiteralPath $f.FullName -Raw
    if ($null -eq $whole) { continue }
    $couldMatch = $false
    foreach ($lit in $ReadLiterals) {
        if ($whole.Contains($lit)) { $couldMatch = $true; break }
    }
    if (-not $couldMatch) { continue }

    $lines = @(Get-Content -LiteralPath $f.FullName)

    # PASS ONE: STRIP THE COMMENTS AND KEEP WHAT STILL CARRIES CODE, remembering each survivor's real
    # line number. Two things need this and neither is a convenience. A read site must not be hidden
    # by a comment sharing its line -- `$raw = [Console]::In.ReadToEnd() <# why #>` is a genuinely
    # unguarded read, and skipping any line carrying a marker made it invisible to the one suite whose
    # job is to find it. And prose must not be counted AS a site: this family documents itself, so
    # every good explanation of the hazard would otherwise read as an instance of it.
    $codeLines = @()
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
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
        if ([string]::IsNullOrWhiteSpace($code)) { continue }
        $codeLines += [pscustomobject]@{ Num = $i + 1; Text = $code }
    }

    # PASS TWO: the read sites, each judged against the code lines immediately above it.
    for ($k = 0; $k -lt $codeLines.Count; $k++) {
        $isRead = $false
        foreach ($p in $ReadPatterns) {
            if ($codeLines[$k].Text -match $p) { $isRead = $true; break }
        }
        if (-not $isRead) { continue }

        $from   = [Math]::Max(0, $k - $WindowCodeLines)
        $window = (@($codeLines[$from..$k]) | ForEach-Object { $_.Text }) -join "`n"
        $sites += [pscustomobject]@{
            Path    = $f.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
            Line    = $codeLines[$k].Num
            Guarded = ($window -match $GuardPattern)
        }
    }
}

# STRIPPED AT EACH PRINT SITE RATHER THAN ONCE AT CONSTRUCTION (#2280), so that a reader auditing "does
# this site guard?" sees the answer on the line they are auditing. Storing a pre-stripped field would
# hide the guard one loop away and leave a raw .Path sitting on the object for the next print to reach
# for; the two extra calls cost nothing on a ten-element list. The LINE NUMBER is this suite's own
# integer and needs no guard.
Write-Host "     the family, counted out of the tree: $($sites.Count) read site(s)" -ForegroundColor DarkGray
foreach ($s in $sites) {
    Write-Host "       $(Get-DisplayPath -Path $s.Path):$($s.Line)" -ForegroundColor DarkGray
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
    Assert-True $s.Guarded "$(Get-DisplayPath -Path $s.Path):$($s.Line) reads stdin only where there is a handle"
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
Write-Host "-- group 3: a wrapper that drains the payload hands it back (issue #2276)" -ForegroundColor Cyan

# WHY THIS GROUP IS ABOUT hooks.json AND NOT ABOUT A HOOK. Groups 1 and 2 hold the guard and the value
# it produces. Neither can say why producing that value is SAFE -- and for guard-live-theme.ps1 it is
# safe only because the branch is unreachable: an empty payload there ends without a verdict, which on
# a guard whose subject is a live customer-facing theme is the one direction its own header forbids.
# What makes it unreachable is the wrapper, and the wrapper is a string in a JSON file that nobody's
# suite was reading.
#
# THE CONTRACT, STATED AS THE ONE THING THAT CAN BREAK IT. A wrapper that captures the payload with
# '$(cat)' has CONSUMED this process's stdin; whatever it runs next inherits a handle at EOF at best.
# So a wrapper that drains must pipe the payload back into the interpreter, and 'printf | powershell'
# is what makes [Console]::IsInputRedirected true on every call the harness makes. Drop the pipe and
# the guarded read below it yields an empty payload in PRODUCTION rather than only in the hand-run
# case #2264 built it for.
#
# WHAT IT CANNOT ASSERT, NAMED RATHER THAN IMPLIED. The runtime half -- a child whose stdin is a live
# console -- is out of reach for the reason group 1's own docstring gives, and #2276 filed it as a
# decision rather than a patch for exactly that reason. This asserts the half this repo owns and
# writes the other half down in the hook's header. Half a guard that says which half is not the same
# thing as a guard that looks whole.
function Test-WrapperDrainsPayload {
    param([string]$Command)
    return $Command.Contains('$(cat)')
}
# THE PIPE IS ANCHORED TO THE INVOCATION THAT RUNS THE GUARD, not merely present somewhere in the
# string, and each half of that was a counter-case a reviewer produced against the looser first form:
#
#   (?<!\|)\|    a SINGLE pipe. '\|\s*powershell' matches '|| powershell' too -- the second character
#                of a logical OR -- which is a plausible typo that also short-circuits, so the naive
#                form went green on a wrapper that hands the interpreter an unredirected stdin.
#   (powershell|pwsh)\b   both interpreters. This repo runs Windows PowerShell 5.1 for its own hooks,
#                and it SHIPS 'shell: pwsh' in the asana-mirror CI template; command-guard-lib.ps1
#                carries both in its own interpreter set for the same reason.
#   [^;|&]*-File  the piped invocation must be the one running a SCRIPT, before any statement ends it.
#                Without this, 'somecmd | powershell -Command "..."; powershell -File guard.ps1'
#                passes on an unrelated pipe while the guard itself is invoked unpiped, which is
#                precisely the regression this group exists to catch.
#
# THE RESIDUAL LIMIT, STATED RATHER THAN HIDDEN, on the convention guard-live-theme's own header uses.
# This does not prove the piped bytes are the CAPTURED payload -- 'echo hi | powershell -File guard.ps1'
# would pass -- and it does not recognise a wrapper that restores stdin by file redirection
# ('> tmp; powershell ... < tmp') rather than by a pipe. The first is a residual; the second would turn
# this gate RED on a correct wrapper, which is the direction to err in here: a false negative is a
# person reading a failure, and a false positive is silence on the one fact this group exists to hold.
function Test-WrapperHandsPayloadBack {
    param([string]$Command)
    return ($Command -match '(?<!\|)\|\s*(powershell|pwsh)\b[^;|&]*-File')
}

# SCANNED OUT OF THE TREE, on group 1's own principle: a list here is the hand-count that produced
# #2249's three and #2264's seven. A wrapper written tomorrow is in scope the moment it is written.
$hookManifests = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter 'hooks.json' -File |
    Where-Object { $_.FullName -notmatch '\\\.git\\' }

$wrappers = @()
foreach ($m in $hookManifests) {
    $rel = $m.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
    try { $json = Get-Content -LiteralPath $m.FullName -Raw | ConvertFrom-Json } catch { $json = $null }
    if ($null -eq $json -or $null -eq $json.hooks) { continue }
    foreach ($evt in $json.hooks.PSObject.Properties) {
        foreach ($matcherBlock in @($evt.Value)) {
            foreach ($h in @($matcherBlock.hooks)) {
                $cmd = [string]$h.command
                if (-not $cmd) { continue }
                if (-not (Test-WrapperDrainsPayload $cmd)) { continue }
                $wrappers += [pscustomobject]@{
                    Path      = $rel
                    Event     = $evt.Name
                    HandsBack = (Test-WrapperHandsPayloadBack $cmd)
                }
            }
        }
    }
}

# TWO VALUES, TWO FUNCTIONS, because a path and a label have different contracts (#2280). The manifest
# PATH takes Get-DisplayPath, which preserves spaces and length -- git and NTFS both accept a leading,
# trailing or doubled space, and a path has to survive being read off the screen and typed back. The
# EVENT NAME is a JSON property key off a parsed hooks.json: a single-line label, not a path, so it
# takes Get-DisplayRef, whose collapse and trim are right for a label and wrong for a path. A key that
# strips to nothing comes back as '' and prints as an empty [], which is the honest answer beside a path
# that already identifies the file -- Get-DisplayPath's '(no printable path)' is the wrong noun here.
#
# NEITHER IS CAPPED, on the reasoning entry 6 of the print-site list already gives one file type over:
# this console is a CI log, which wraps rather than truncates, so a cap would buy no screen back and
# could cut the half of an assert message that says which file failed.
Write-Host "     draining wrappers, counted out of the tree: $($wrappers.Count)" -ForegroundColor DarkGray
foreach ($w in $wrappers) {
    Write-Host "       $(Get-DisplayPath -Path $w.Path)  [$(Get-DisplayRef -Ref $w.Event)]" -ForegroundColor DarkGray
}

# A FLOOR, for group 1's reason one file type over: a walk that silently stops walking reports an empty
# family as a clean one. Two is the count at the time of writing -- guard-working-copy and
# guard-live-theme, the two PreToolUse guards #2217 wrapped -- and it is a floor because a third
# draining wrapper is the normal case and must not turn this suite red for existing.
Assert-True ($wrappers.Count -ge 2) "the scan found the draining wrappers (>= 2, got $($wrappers.Count)) -- a drop means the matcher broke or a wrapper changed shape, never that the tree is clean"

foreach ($w in $wrappers) {
    Assert-True $w.HandsBack "$(Get-DisplayPath -Path $w.Path) [$(Get-DisplayRef -Ref $w.Event)]: the wrapper pipes the drained payload back into the interpreter"
}

# THE COUNTER-CASE, because a predicate that has only ever seen passing input is a predicate nobody has
# tested. It is a fixture rather than an edit to a real manifest: mutating a shipped hooks.json to prove
# a matcher works leaves the suite one failed cleanup away from shipping the defect it was asserting.
# EVERY NARROWING ABOVE HAS ITS OWN COUNTER-CASE, because a narrowing without one is a hole with a
# comment on it -- guard-live-theme's own rule for its own exemptions, one file over. The last three
# are the shapes the first form of this matcher went green on.
$fixtureGood = 'p=$(cat); printf ''%s'' "$p" | powershell -NoProfile -File "x.ps1"; rc=$?'
$fixturePwsh = 'p=$(cat); printf ''%s'' "$p" | pwsh -NoProfile -File "x.ps1"; rc=$?'
$fixtureBad  = 'p=$(cat); powershell -NoProfile -File "x.ps1"; rc=$?'
$fixtureOr   = 'p=$(cat); printf ''%s'' "$p" || powershell -NoProfile -File "x.ps1"; rc=$?'
$fixtureStray = 'p=$(cat); echo hint | powershell -Command "..."; powershell -NoProfile -File "x.ps1"'
Assert-True (Test-WrapperDrainsPayload $fixtureBad)            'the drain matcher sees a wrapper that captures the payload'
Assert-True (Test-WrapperHandsPayloadBack $fixtureGood)        'a wrapper that pipes the payload back passes'
Assert-True (Test-WrapperHandsPayloadBack $fixturePwsh)        'pwsh is an interpreter too -- this repo ships a CI template that uses it'
Assert-True (-not (Test-WrapperHandsPayloadBack $fixtureBad))  'a wrapper that drains and does NOT pipe it back is caught'
Assert-True (-not (Test-WrapperHandsPayloadBack $fixtureOr))   'a logical OR is not a pipe -- || short-circuits and leaves stdin unredirected'
Assert-True (-not (Test-WrapperHandsPayloadBack $fixtureStray)) 'an unrelated | powershell elsewhere in the command does not vouch for the guard invocation'

Write-Host ""
Write-Host "-- group 4: this suite's own printed values pass the console strip (issue #2280)" -ForegroundColor Cyan

# GROUP 3'S OWN RULE, TURNED ON THIS FILE: a narrowing without a counter-case is a hole with a comment
# on it. The guard added above is a call, and a call nobody has exercised is a comment -- so these
# assert that the dot-source at the head of this file actually LANDED and that each of the two value
# classes reaches the function its own print site calls.
#
# NOT A SECOND TEST OF ref-print-lib.ps1, which has its own suite and is where the runtime's category
# table, the soft hyphen and the surrogate pairs above the BMP are pinned. What is asserted here is the
# SEAM: that this file loaded the lib rather than merely naming it in a comment, and that a path and a
# label are not routed through each other's function -- which is the one thing this file decided and
# nothing else can check.
$rtlPath   = 'plugins/dkj-policy/hooks/' + [char]0x202E + 'nosj.skooh'
$zwspEvent = 'Pre' + [char]0x200B + 'ToolUse'

Assert-Equal $false ((Get-DisplayPath -Path $rtlPath).Contains([char]0x202E)) 'a tracked path carrying U+202E RIGHT-TO-LEFT OVERRIDE does not reach the console -- the \p{Cf} class check-plugin-integrity.ps1 does NOT hold a tracked path to'
Assert-Equal $false ((Get-DisplayRef -Ref $zwspEvent).Contains([char]0x200B)) 'nor does a hooks.json event key carrying a zero-width space -- and no lint has an opinion about a JSON key at all'
Assert-Equal 'plugins/dkj-policy/hooks/ nosj.skooh' (Get-DisplayPath -Path $rtlPath) 'the PATH keeps its length and its spaces, because a path has to survive being read off the screen and typed back'
Assert-Equal 'Pre ToolUse' (Get-DisplayRef -Ref $zwspEvent) 'while the LABEL collapses and trims -- the contract difference that is why these two values take two functions'

Write-Host ""
Write-Host "-- group 5: the repaired print lines still CALL the strip (issue #2280)" -ForegroundColor Cyan

# GROUP 4 GUARDS THE LIBRARY; THIS GUARDS THE WIRING, and they are not the same assert. Group 4 proves
# the dot-source landed and that each function strips its own class -- and it would pass UNCHANGED if a
# later edit put one of the four repaired lines back to a raw interpolation while leaving the
# dot-source alone. A bad merge-conflict resolution is the likely shape, and this file is about to have
# one: a parked branch edits the same print-site list. That is a counter-case which passes either way,
# which is this file's own definition of a hole with a comment on it. Found by the security review of
# this branch rather than by the repair.
#
# WHY A SOURCE SCAN AND NOT AN INJECTED FIXTURE. The values at those lines are scanned out of the real
# tree, so driving a hazardous one through them means writing a deceptive path or a deceptive
# hooks.json into the tree being scanned -- which is exactly what group 3's own comment refuses to do
# to a shipped manifest. So this reads the SOURCE, as group 1 does and for the reason group 1's
# docstring already gives: the behaviour is not reachable from a test process, and the source is.
#
# ONE SENTINEL, BECAUSE THE COUNTER-CASE HAS TO CONTAIN WHAT IT FORBIDS. A fixture line proving the
# scan catches a raw print must carry the raw shape, so it would be reported as a defect. Every such
# line is marked, and the scan skips a marked line -- the same trick as excluding scripts/tests from
# group 1's own walk, one scale down.
$ForeignValueTokens = @('$s.Path', '$w.Path', '$w.Event')
$GuardCallTokens    = @('Get-DisplayPath', 'Get-DisplayRef')

function Test-LineIsForeignPrint {
    param([string]$Line)
    # Prose about the hazard is not an instance of it -- group 1's rule, one file over.
    if ($Line.TrimStart().StartsWith('#')) { return $false }
    if ($Line.Contains('not-a-print-site')) { return $false }
    if ($Line -notmatch 'Write-Host|Assert-True') { return $false }
    foreach ($tok in $ForeignValueTokens) { if ($Line.Contains($tok)) { return $true } }
    return $false
}

# PER VALUE, NOT PER LINE, and the first form of this function was per line. It asked whether the line
# NAMED a strip anywhere on it, which passes a line that guards one of its two foreign values and
# prints the other raw -- exactly the shape group 3 carries, where a path and a JSON key share a line.
# So the check that was written to catch #2280 went green on #2280's own defect, caught by running it
# against a fixture rather than by reading it. It is also the miss the print-site list already records
# one entry over: a repair "complete only as far as the colon".
#
# THE TEST IS THE ARGUMENT POSITION. A guarded value is the argument of a guard call, so it is preceded
# by that call's parameter name; a raw one is preceded by the opening of its interpolation. Every
# occurrence is judged, not the first -- a value can appear twice on one line.
#
# A POSITIONAL CALL WOULD BE REPORTED AS UNGUARDED, and that is the direction to err in, on this file's
# own rule for its comment stripper: the error this suite may make is the loud one. A false positive is
# a person reading a failure; a false negative is silence on the one fact this group exists to hold.
function Get-UnguardedForeignValues {
    param([string]$Line)
    $unguarded = @()
    foreach ($tok in $ForeignValueTokens) {
        $from = 0
        while ($true) {
            $at = $Line.IndexOf($tok, $from)
            if ($at -lt 0) { break }
            if (-not ($Line.Substring(0, $at) -match '-(Path|Ref)\s+$')) { $unguarded += $tok }
            $from = $at + $tok.Length
        }
    }
    return $unguarded
}

$selfLines  = @(Get-Content -LiteralPath $PSCommandPath)
$printLines = @()
for ($i = 0; $i -lt $selfLines.Count; $i++) {
    if (-not (Test-LineIsForeignPrint -Line $selfLines[$i])) { continue }
    $bare = @(Get-UnguardedForeignValues -Line $selfLines[$i])
    $printLines += [pscustomobject]@{
        Num     = $i + 1
        Guarded = ($bare.Count -eq 0)
        Bare    = ($bare -join ', ')
    }
}

Write-Host "     lines of this file printing a scanned value: $($printLines.Count)" -ForegroundColor DarkGray
foreach ($p in $printLines) {
    Write-Host "       line $($p.Num)" -ForegroundColor DarkGray
}

# A FLOOR AT FOUR, group 1's reasoning applied to this file: two groups print two value classes, each
# once in its enumeration and once in its per-item assert message. A fifth is the normal case and must
# not turn this red for existing; a DROP means the scan stopped matching, never that there is nothing
# left to guard.
Assert-True ($printLines.Count -ge 4) "the scan found this file's own print lines (>= 4, got $($printLines.Count)) -- a drop means the scan broke or a line changed shape, never that there is nothing to guard"

foreach ($p in $printLines) {
    # The names of the unguarded values are this suite's OWN tokens, typed in the array above -- so
    # naming them in a failure message prints nothing foreign, and it is what turns a red line into a
    # repair somebody can make without opening the file.
    $which = if ($p.Guarded) { '' } else { " -- unguarded: $($p.Bare)" }
    Assert-True $p.Guarded "line $($p.Num) hands EVERY scanned value on it to the strip before printing$which"
}

# THE COUNTER-CASES, on the rule this file states twice already. The first pair is the whole point: the
# scan has to SEE a raw print line and has to call it unguarded, or the asserts above are decoration.
$fixtureRaw      = 'Write-Host "   $($s.Path):$($s.Line)" -ForegroundColor DarkGray'                  # not-a-print-site
$fixtureGuarded  = 'Write-Host "   $(Get-DisplayPath -Path $s.Path):$($s.Line)" -ForegroundColor Gray' # not-a-print-site
$fixtureKeyRaw   = 'Assert-True $w.HandsBack "$($w.Path) [$($w.Event)]: the wrapper pipes it back"'    # not-a-print-site
$fixturePartial  = 'Assert-True $w.HandsBack "$(Get-DisplayPath -Path $w.Path) [$($w.Event)]: back"'   # not-a-print-site
$fixtureProse    = '#   Write-Host "   $($w.Event)" -- prose explaining the hazard, not an instance'   # not-a-print-site
$fixtureOwnValue = 'Write-Host "     the family, counted out of the tree: $($sites.Count) site(s)"'    # not-a-print-site

Assert-True (Test-LineIsForeignPrint -Line $fixtureRaw)                          'the scan sees a print line carrying a value this suite did not author'
Assert-Equal 1 (@(Get-UnguardedForeignValues -Line $fixtureRaw).Count)           'and reports that value UNGUARDED when no strip is named on it -- the shape a bad merge resolution would leave behind'
Assert-Equal 0 (@(Get-UnguardedForeignValues -Line $fixtureGuarded).Count)       'while the repaired shape reports none'
Assert-True (Test-LineIsForeignPrint -Line $fixtureKeyRaw)                       'an assert MESSAGE is a print site too, which is half of what issue #2280 reported'
Assert-Equal 2 (@(Get-UnguardedForeignValues -Line $fixtureKeyRaw).Count)        'and BOTH of its values are counted, not just the first one found'
# THE ONE THAT CAUGHT THIS CHECK'S OWN FIRST FORM: a path guarded, the JSON key beside it still raw.
# Per-line the line names a strip and passes; per-value it is exactly the defect #2280 reported.
Assert-Equal 1 (@(Get-UnguardedForeignValues -Line $fixturePartial).Count)       'a line that guards its PATH and prints its JSON KEY raw is still a finding -- the partial repair, which the per-line form of this check went green on'
Assert-True (-not (Test-LineIsForeignPrint -Line $fixtureProse))                 'prose about the hazard is not an instance of it -- this file documents itself, and counting that would make a good explanation the failure'
Assert-True (-not (Test-LineIsForeignPrint -Line $fixtureOwnValue))              'and a line printing this suite own count is not a subject at all'

Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
