<#
.SYNOPSIS
    Regression tests for the claim step: the two decisions in scripts/lib/claim-issue-lib.ps1, and the
    two structural properties of scripts/task/claim-issue.ps1 that a suite can hold.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/claim-issue.tests.ps1

    NOTHING HERE TOUCHES A TRACKER, and that is why the script was built with its decisions in a lib.
    Every gh call in claim-issue.ps1 needs a live tracker, an account with write access and an issue it
    is allowed to edit -- so a suite can either assert nothing or assert the wrong thing. What it CAN
    hold is the whole judgement: which account a checkout claims under, and which of the four verdicts
    an issue gets. That is where all four refusals live, so the untestable half is reduced to two gh
    invocations and a read-back.

    THE NAMED TEST GAP, stated rather than papered over: the round trip itself -- gh accepting the
    edit, and the read-back catching an assignee GitHub silently dropped -- is exercised by hand
    against the live tracker, not here. It was exercised that way when this landed (issue #1453 was
    unassigned, re-claimed by the script, and read back), and the same reasoning applies as in
    git-identity-gate.tests.ps1: a suite that installed a keyring and a tracker would be testing gh.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\claim-issue.ps1'
$Lib      = Join-Path $RepoRoot 'scripts\lib\claim-issue-lib.ps1'
$IdLib    = Join-Path $RepoRoot 'scripts\lib\git-identity-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

# Test-GitHubLoginShape lives in the identity lib and Resolve-ClaimAccount calls it, so both are
# loaded here -- which also asserts, by simply not throwing, that the extraction left the identity lib
# dot-sourceable on its own.
. $IdLib
. $Lib

Write-Host ''
Write-Host 'Resolve-ClaimAccount -- which account this checkout claims under' -ForegroundColor Cyan

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName 'maikel-bwj'
Assert-True ($r.Account -eq 'maikel-bwj' -and -not $r.Split -and $r.Reason -eq 'gh') 'the two agree -- that account, no split'

$r = Resolve-ClaimAccount -GhAccount 'DaveKJohn' -GitUserName 'davekokbwj'
Assert-True ($r.Account -eq 'davekokbwj' -and $r.Split -and $r.Reason -eq 'split') 'the measured #1315 split -- claims by the GIT name, not the gh one'

$r = Resolve-ClaimAccount -GhAccount 'DaveKJohn' -GitUserName 'davekjohn'
Assert-True ($r.Account -eq 'DaveKJohn' -and -not $r.Split) 'GitHub logins are case-insensitive -- a case difference is ONE account'

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName 'Ada Lovelace'
Assert-True ($r.Account -eq 'maikel-bwj' -and -not $r.Split) 'a display name is not an account -- no split, and the gh account stands'

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName ('a' * 40)
Assert-True (-not $r.Split) '40 characters is not a GitHub login -- outside the shape, so no split'

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName ('a' * 39)
Assert-True ($r.Split -and $r.Account -eq ('a' * 39)) '39 characters IS a GitHub login -- the shape boundary is walked at both edges'

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName '-leading'
Assert-True (-not $r.Split) 'a leading hyphen is not a GitHub login -- no split'

$r = Resolve-ClaimAccount -GhAccount 'maikel-bwj' -GitUserName 'dou--ble'
Assert-True (-not $r.Split) 'a doubled hyphen is not a GitHub login -- no split'

$r = Resolve-ClaimAccount -GhAccount '' -GitUserName 'maikel-bwj'
Assert-True ($r.Account -eq '' -and $r.Reason -eq 'none') 'gh logged out -- there is nobody to claim as, and it says so rather than falling back to the git name'

$r = Resolve-ClaimAccount -GhAccount '  maikel-bwj  ' -GitUserName '  maikel-bwj  '
Assert-True ($r.Account -eq 'maikel-bwj' -and -not $r.Split) 'both values are trimmed -- whitespace is not a second account'

Write-Host ''
Write-Host 'Get-ClaimVerdict -- may this issue be claimed' -ForegroundColor Cyan

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @()
Assert-True ($v.Action -eq 'claim' -and $v.Code -eq 'open-unassigned') 'open and unassigned -- claim it'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees $null
Assert-True ($v.Action -eq 'claim') 'a null assignee list is an unassigned issue, not a crash'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'CLOSED' -Assignees @()
Assert-True ($v.Action -eq 'refuse' -and $v.Code -eq 'closed') 'CLOSED is refused -- the refusal the documented one-liner cannot make'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'closed' -Assignees @()
Assert-True ($v.Code -eq 'closed') 'the state is compared case-insensitively -- gh and the REST API disagree on case'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'CLOSED' -Assignees @('maikel-bwj')
Assert-True ($v.Code -eq 'closed') 'closed beats already-yours -- your own name on finished work is still finished work'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @('DaveKJohn')
Assert-True ($v.Action -eq 'refuse' -and $v.Code -eq 'taken' -and $v.Others -contains 'DaveKJohn') 'somebody else holds it -- refused, and the message can name them'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @('maikel-bwj', 'DaveKJohn')
Assert-True ($v.Code -eq 'taken' -and $v.Others.Count -eq 1 -and $v.Others[0] -eq 'DaveKJohn') 'a co-assignment is refused too, and Others carries only the other party'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @('maikel-bwj')
Assert-True ($v.Action -eq 'skip' -and $v.Code -eq 'already-yours') 'already yours -- a resume, so nothing to write and no error'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @('MAIKEL-BWJ')
Assert-True ($v.Code -eq 'already-yours') 'your own login in another case is still you'

$v = Get-ClaimVerdict -Account '' -State 'OPEN' -Assignees @()
Assert-True ($v.Action -eq 'refuse' -and $v.Code -eq 'no-account') 'no account -- a claim cannot be made anonymously, even on a perfectly claimable issue'

$v = Get-ClaimVerdict -Account 'maikel-bwj' -State 'OPEN' -Assignees @('DaveKJohn')
Assert-True ($v.Others -is [array]) 'Others is always an array -- a single other assignee must not arrive as a bare string'

Write-Host ''
Write-Host 'Get-AssigneeLogins -- reading gh JSON without trusting its shape' -ForegroundColor Cyan

Assert-True ((Get-AssigneeLogins -Json '{"assignees":[{"login":"maikel-bwj"}]}') -contains 'maikel-bwj') 'the ordinary payload -- one assignee'

$l = Get-AssigneeLogins -Json '{"assignees":[{"login":"a"},{"login":"b"}]}'
Assert-True ($l.Count -eq 2 -and $l[0] -eq 'a' -and $l[1] -eq 'b') 'two assignees, in order'

Assert-True ((Get-AssigneeLogins -Json '{"assignees":[]}').Count -eq 0) 'an unassigned issue is an empty array'
Assert-True ((Get-AssigneeLogins -Json '{"number":7}').Count -eq 0) 'a payload with no assignees field at all -- empty, not a throw'
Assert-True ((Get-AssigneeLogins -Json 'not json').Count -eq 0) 'unparseable JSON is empty rather than an exception'
Assert-True ((Get-AssigneeLogins -Json '').Count -eq 0) 'empty input is empty'

# Victor's finding: under Set-StrictMode -Version Latest a dot-read of an ABSENT property throws, and
# the previous inline loop did exactly that. This is the assert that keeps it out.
Assert-True ((Get-AssigneeLogins -Json '{"assignees":[{"id":"X"},{"login":"maikel-bwj"}]}') -contains 'maikel-bwj') 'an assignee record with no login is skipped, not fatal -- the rest is still read'

Assert-True ((Get-AssigneeLogins -Json '{"assignees":[{"login":"a"},{"login":"a"}]}').Count -eq 1) 'a repeated login is counted once'
Assert-True ((Get-AssigneeLogins -Json '{"assignees":[{"login":"  a  "}]}')[0] -eq 'a') 'logins are trimmed'

Write-Host ''
Write-Host 'Format-ForConsole -- tracker text is written by strangers' -ForegroundColor Cyan

$t = Format-ForConsole -Text ("Fix the thing" + [char]27 + "[2K" + [char]27 + "[A")
Assert-True ($t -notmatch [char]27) 'an ANSI escape in an issue title never reaches the terminal'
Assert-True ($t -like 'Fix the thing*') 'the printable half of the title survives verbatim'

$t = Format-ForConsole -Text ("one" + [char]10 + "two")
Assert-True ($t -eq 'one two') 'a newline becomes a space -- a title cannot forge a second output line'

$t = Format-ForConsole -Text ("a" + [char]0 + "b")
Assert-True ($t -eq 'a b') 'a control character becomes a space rather than vanishing -- two words cannot be glued into one'

Assert-True ((Format-ForConsole -Text '') -eq '') 'an empty title is an empty string, not a crash'

# ISSUE #1858. The class was '[\x00-\x1F\x7F]' until then -- C0 and DEL -- so every hazard below
# reached the terminal untouched, none of it carrying a byte under 0x80. The asserts are per code
# point rather than one sweep because they fail for different reasons: C1 is a second CONTROL range
# the old class simply did not reach, while the rest are \p{Cf}, which is a different category and
# which `git check-ref-format` accepts in a branch name to this day (#1617's own measurement).
$t = Format-ForConsole -Text ('a' + [char]0x9B + 'b')
Assert-True ($t -eq 'a b') 'a C1 control (0x9B, read as CSI by some terminals) becomes a space -- it is above 0x7F and the old class stopped there'

$t = Format-ForConsole -Text ('report' + [char]0x202E + 'gnp.txt')
Assert-True ($t -eq 'report gnp.txt') 'a RIGHT-TO-LEFT OVERRIDE cannot reorder the line it sits on -- the Trojan-Source shape #1858 was filed for'

$t = Format-ForConsole -Text ('a' + [char]0x2066 + 'b' + [char]0x2069 + 'c')
Assert-True ($t -eq 'a b c') 'the bidi isolates go too, both halves of the pair'

$t = Format-ForConsole -Text ('ad' + [char]0x200B + 'min')
Assert-True ($t -eq 'ad min') 'a zero-width space becomes a visible space rather than vanishing -- two words are never welded into one that reads as a different title'

$t = Format-ForConsole -Text ([char]0xFEFF + 'title')
Assert-True ($t -eq ' title') 'and nothing is trimmed or collapsed: a title is quoted evidence, which is why this is NOT Get-DisplayRef'

$t = Format-ForConsole -Text 'Ordinary title -- with punctuation! 100% (v2)'
Assert-True ($t -eq 'Ordinary title -- with punctuation! 100% (v2)') 'printable text survives the widening exactly as written'

# ISSUE #2024. Neither Zl/Zp nor Mn/Me is Cc or Cf, so both survived the class above untouched.
$t = Format-ForConsole -Text ('one' + [char]0x2028 + 'two')
Assert-True ($t -eq 'one two') 'a LINE SEPARATOR (U+2028) becomes a space -- it cannot make one printed line read as two'

$t = Format-ForConsole -Text ('one' + [char]0x2029 + 'two')
Assert-True ($t -eq 'one two') 'a PARAGRAPH SEPARATOR (U+2029) becomes a space, same reasoning'

$t = Format-ForConsole -Text ('e' + [char]0x0301 + [char]0x0301 + [char]0x0301)
Assert-True ($t -eq 'e   ') 'stacking combining marks (Zalgo text) each become a space rather than piling onto the base character'

# THE DRIFT PIN'S LOCAL HALF. pr-issues.tests.ps1 asserts WHICH libs type this class and that they
# agree; this asserts there is ONE definition inside this one, the same shape that suite uses for
# Format-AuthoredText. A second -replace here would be a strip that could drift from its own docstring.
$libText = [System.IO.File]::ReadAllText($Lib)
Assert-True ([regex]::Matches($libText, [regex]::Escape("-replace '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]', ' '")).Count -eq 1) 'ONE definition inside this lib -- Format-ForConsole, which the title, the commit subjects and the branch names all go through'

Write-Host ''
Write-Host 'claim-issue.ps1 -- the properties a suite can hold' -ForegroundColor Cyan

$body = Get-Content -LiteralPath $Script -Raw

# THE REGRESSION THIS SUITE EXISTS TO PREVENT. The whole reason this script is not the documented
# one-liner is that '@me' binds to gh's account rather than to the one the commits will name (#1315).
# A later edit "simplifying" the identity resolution back to '@me' would pass every behavioural test
# above -- they never run the script -- and reintroduce the exact defect in one line.
Assert-True ($body -match "'--add-assignee',\s*\`$identity\.Account") 'the claim is written by NAME, from the resolved identity'
Assert-True ($body -notmatch "--add-assignee'\s*,\s*'@me'") "the script never sends '@me' as the assignee"

# The write is not the proof: gh reports success for a login GitHub silently drops. Two issue views
# is what a read-back looks like from here -- the facts before, the assignees after.
Assert-True ((([regex]::Matches($body, "'issue',\s*'view'")).Count) -ge 2) 'the claim is read back after the write, not assumed from the exit code'

# THE READ-BACK'S THREE STATES (#1628). The defect was one boolean standing for two opposite facts --
# "gh answered and said no" and "gh never answered" -- with the refusal message printed for both. It is
# a WRONG MESSAGE on a path no behavioural test here reaches, so the shape is what a suite can hold:
# the refusal must be gated on the read having succeeded, and the unverified path must exist and must
# not exit. A later edit collapsing them back would restore a false stop on a claim that landed.
#
# THE PATTERN NO LONGER PINS THE CLOSING BRACKET (#1679), and the loosening is deliberate rather than
# convenient: #1628's subject is that $readOk is its OWN value, computed from whether gh answered, and
# separate from what gh said. It was never that the expression has exactly two terms. #1679 added a
# third -- a capture that came back short is also gh not having answered -- and the old regex refused
# it by requiring `0)` immediately, which would have made this suite argue for the defect. The
# ShortRead half is pinned exactly, in its own block further down, so nothing is left unasserted.
Assert-True ($body -match '\$readOk\s*=\s*\[bool\]\(\$after\s+-and\s+\$after\.ExitCode\s+-eq\s+0') 'whether the read-back answered is its own value, separate from what it said'
Assert-True ($body -match 'if\s*\(\$readOk\s+-and\s+-not\s+\$landed\)') 'the "not on the issue" refusal fires only where the read actually answered'
Assert-True ($body -notmatch 'if\s*\(-not\s+\$landed\)\s*\{') 'no branch keys the refusal off $landed alone -- that is the collapse itself'
Assert-True ($body -match 'if\s*\(-not\s+\$readOk\)') 'a read that did not answer has its own branch'

# The unverified branch must stay non-blocking and must name what it measured. Its whole reason for
# existing is that a false stop costs the assignment (#1485), so an `exit` added to it would be the
# defect back in a new spelling -- and a message that does not name the exit code is the old one's
# other half: a cause asserted rather than measured.
$unverified = if ($body -match '(?s)if\s*\(-not\s+\$readOk\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
Assert-True ($unverified -ne '') 'the unverified branch is findable as a block'

# THE 'DOES IT BLOCK' ASSERT READS CODE, NOT PROSE, and that distinction was measured rather than
# anticipated (#1639). The assert below is about an `exit` STATEMENT; run over the raw block it also
# matched the word "exit" inside a comment -- and the comment that tripped it was a correct one,
# explaining that a stall and an exit code point the reader at different things. A test that a true
# comment can fail teaches the next author to write a worse comment, so the comment lines come off
# first and the assert keeps exactly the subject it always had.
function Get-CodeOnly {
    param([string]$Block)
    return (($Block -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
}

Assert-True ((Get-CodeOnly -Block $unverified) -notmatch '\bexit\b') 'the unverified read does NOT block -- the write returned 0 and the claim most likely landed'
Assert-True ($unverified -match '\[WARNING\]') 'it reports as a warning, not as the refusal it is not'
Assert-True ($unverified -match 'exited \$\(\$after\.ExitCode\)') 'it names the exit code it actually measured'
Assert-True ($unverified -match [regex]::Escape('$after.TimedOut')) 'and it names a TIMEOUT as its own reason, which #1639 made reachable -- a stall says nothing about the tracker, where an exit code says gh answered and disagreed'

# --- a short read is not gh disagreeing (#1679) ---------------------------------------------------
# THE READ-BACK'S OWN GUARD, and the one assert that pins WHY. $readOk used to ask the exit code alone,
# so a -Utf8 capture that came back empty at exit 0 made $landed false and sent the run down the
# REFUSED branch -- "Treat the issue as UNCLAIMED", exit 1 -- on a claim that had in fact landed. The
# fix is that the short read joins the could-not-verify state, which already exists and does not block.
Write-Host ''
Write-Host 'A short read is not a refusal (#1679)' -ForegroundColor Cyan

Assert-True ($body -match [regex]::Escape('$readOk = [bool]($after -and $after.ExitCode -eq 0 -and -not $after.ShortRead)')) `
    'the read-back folds ShortRead into $readOk, so a truncated capture cannot reach the REFUSED branch'
Assert-True ($unverified -match [regex]::Escape('$after.ShortRead')) `
    'and the could-not-verify branch names it as its own reason -- the exit code is 0 there, so "exited 0" would be the misleading half'
Assert-True ($unverified.IndexOf('$after.ShortRead') -lt $unverified.IndexOf('exited $($after.ExitCode)')) `
    'named BEFORE the exit-code arm, or it could never print'
Assert-True ($body -match [regex]::Escape('if ($view.ShortRead)')) `
    'the pre-write read separates a truncated capture from gh returning non-JSON -- same verdict, different thing to go and check'

# --- the network bound on every gh call (#1639) ---------------------------------------------------
# ALL THREE CALLS WERE UNBOUNDED while every sibling script bounded its own, and the reason was a stale
# comment on the shared value: it opened "THE BOUND A GIT NETWORK CALL PASSES" and listed three sites,
# by which time six files read it and two passed it to `gh`. So a `gh`-only script read the policy as
# somebody else's. The claim is the FIRST step of an issue-driven assignment (#1485), so a stall here
# is a session that never starts with nothing printed to say why.
Write-Host ''
Write-Host 'The network bound (#1639)' -ForegroundColor Cyan

# PER CALL, NOT PER FILE (#1853). This was a whole-file count of the bound compared with a whole-file
# count of the gh calls, which was EXACT for as long as gh was the only thing in this script bounded --
# and stopped being so the moment the parked-fix scan added a bounded `git fetch`. The old shape then
# failed on a script where every gh call was in fact bounded, which is a test arguing against the rule
# it exists to hold. The intent is unchanged and is now measured directly: each gh invocation is read on
# its own, so a fourth one added later and left unbounded still fails, and a bounded call to something
# else no longer can.
$calls = [regex]::Matches($body, "Invoke-NativeCapture\s+(?:-Utf8\s+)?-FilePath\s+'(?<cmd>[a-z]+)'")
$ghCalls = 0
$unbounded = @()
for ($i = 0; $i -lt $calls.Count; $i++) {
    if ($calls[$i].Groups['cmd'].Value -ne 'gh') { continue }
    $ghCalls++
    # THE INVOCATION, NOT THE REST OF THE FILE: a PowerShell call ends at the first line that does not
    # end in a backtick continuation, so reading to there is what keeps a neighbouring call's bound from
    # being counted for this one.
    $tail = $body.Substring($calls[$i].Index)
    $statement = ''
    foreach ($line in ($tail -split "`r?`n")) {
        $statement += $line + "`n"
        if ($line -notmatch '`\s*$') { break }
    }
    if ($statement -notmatch [regex]::Escape('-TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds')) {
        $unbounded += ($statement -split "`n")[0].Trim()
    }
}
Assert-True ($ghCalls -ge 3) "the three gh calls are still here (found $ghCalls)"
Assert-True ($unbounded.Count -eq 0) "every gh call carries the shared bound -- $ghCalls call(s), $($unbounded.Count) unbounded"
Assert-True ($body -match [regex]::Escape('$NativeCaptureNetworkTimeoutSeconds')) 'and it is the SHARED value, not a number typed in here'

# THE READ AND THE READ-BACK REPORT A STALL AS A STALL. The pre-write read's failure branch offers a
# list of three causes gh reached a verdict for; a hang is none of them, so sending a reader down that
# list would be the bound announcing itself as the wrong thing.
Assert-True ($body -match [regex]::Escape('if ($view -and $view.TimedOut)')) 'the pre-write read distinguishes a stall from the three verdicts it otherwise lists'

# THE WRITE IS THE ONE TIMEOUT THAT IS NOT A FAILURE, and it gets its own branch above the failure one.
# `gh issue edit` changes the tracker, so a write that reached the network and never answered may have
# landed -- reporting "the claim failed" there would be a claim about the tracker this run cannot make.
$editTimeout = if ($body -match '(?s)if\s*\(\$edit\s+-and\s+\$edit\.TimedOut\)\s*\{(.*?)\n\}') { $Matches[1] } else { '' }
Assert-True ($editTimeout -ne '') 'the write has a timeout branch of its own, ahead of the failure branch'
Assert-True ($editTimeout -match 'DOES NOT KNOW') 'it says the run does not know whether the claim landed, rather than that it failed'
Assert-True ((Get-CodeOnly -Block $editTimeout) -match '\bexit\b') 'and it DOES stop -- unlike the read-back, nothing about this write is known'
Assert-True ($editTimeout -match 'already yours') 'while naming the safe way out: re-running reports an already-landed claim as already yours'
# The failure branch must not swallow the timeout case by running first.
Assert-True ($body.IndexOf('$edit.TimedOut') -lt $body.IndexOf('the claim failed')) 'the timeout branch is tested BEFORE the generic failure branch, or it could never be reached'

# ...and the closing verdict must not contradict the warning it sits under: an unconditional
# '[OK] claimed' there asserts exactly what the read-back failed to establish.
Assert-True ($body -match '\$confirmed\s*=\s*if\s*\(\$landed\)') 'the headline distinguishes a confirmed claim from an unconfirmed one'
Assert-True ($body -match "claimed for '\`$\(\`$identity\.Account\)'\`$confirmed") 'and the OK line carries that distinction rather than asserting the claim landed'

# The title is the one field on the issue that a stranger writes, and this script prints it twice.
Assert-True ($body -notmatch '\$\(\$facts\.title\)') 'the issue title is never printed straight from the tracker'

# The defect #1485 measured is a SILENCE, so nothing behavioural can catch its return: a fresh claim
# that prints only its verdict passes every test above, and the session that reads it stops and asks.
# Both sibling verdicts point forward; a later edit trimming either one is what this holds.
Assert-True ($body -match 'open the branch \(new-branch\)') 'the fresh-claim verdict says what follows a successful claim'
Assert-True ($body -match 'read the branch and its document') 'the already-yours verdict still says what follows a resume'

# --- THE FOURTH PICKUP SIGNAL: A FIX PARKED ON A BRANCH WITH NO PR (#1853) ------------------------
#
# The four functions below are the pure half of a check whose other half is git. Same split, and the
# same reason, as everything above: the git calls need a checkout with a remote, other people's
# branches on it and a fetch that reaches the network, so a suite can either assert nothing or assert
# the wrong thing. The pattern, the two parses and the report are pure, and they carry every decision
# the check makes about what is worth saying.

Write-Host ''
Write-Host 'Get-IssueMentionPattern -- the three spellings, and the one that must not match (#1853)' -ForegroundColor Cyan

Assert-True ((Get-IssueMentionPattern -Issue 0) -eq '') 'issue 0 yields no pattern, so the caller scans nothing'
Assert-True ((Get-IssueMentionPattern -Issue -3) -eq '') 'a negative number yields no pattern either'

$pat1853 = Get-IssueMentionPattern -Issue 1853
# .NET's regex is a superset of POSIX ERE for these constructs, so the pattern git will be handed can
# be exercised here directly. THREE SPELLINGS, and each is a real shape this workflow writes.
Assert-True ('fixed here rather than left filed (#1853, inside scope)' -cmatch $pat1853) 'a body reference (#1853) matches'
Assert-True ('fix(1853): repair the pickup check' -cmatch $pat1853) 'the conventional-commit scope (1853) matches'
Assert-True ('park: fix/1853-parked-fix-scan (the branch files only)' -cmatch $pat1853) 'a branch name in a subject (/1853-) matches -- the only shape a freshly parked branch has'
Assert-True ('#1853' -cmatch $pat1853) 'a reference at the very end of the message matches'

# THE NOISE THIS EXISTS TO KEEP OUT, and the assert that would fail if the trailing class were dropped.
Assert-True (-not ('closes #18530 at last' -cmatch $pat1853)) 'a LONGER number starting with these digits does not match'
Assert-True (-not ('fix(18530): something else' -cmatch $pat1853)) 'nor does it in the commit scope'
Assert-True (-not ('release 1853 items shipped' -cmatch $pat1853)) 'a bare number with no #, ( or / is not a reference'
Assert-True (-not ('fix(1852): the neighbour' -cmatch $pat1853)) 'a different issue does not match'

Write-Host ''
Write-Host 'ConvertFrom-CommitScanLog -- reading git log without trusting its shape (#1853)' -ForegroundColor Cyan

$US = [string][char]0x1F
Assert-True (@(ConvertFrom-CommitScanLog -Text '').Count -eq 0) 'empty input is an empty array, not a crash'
Assert-True (@(ConvertFrom-CommitScanLog -Text "   `n  ").Count -eq 0) 'whitespace-only input yields nothing'

$twoLines = "abc1234${US}davekokbwj${US}1757620000${US}fix(1853): repair it`ndef5678${US}maikel-bwj${US}1757620100${US}park: fix/1853-x (the branch files only)"
$parsedTwo = @(ConvertFrom-CommitScanLog -Text $twoLines)
Assert-True ($parsedTwo.Count -eq 2) 'two log lines become two records'
Assert-True ($parsedTwo[0].Sha -eq 'abc1234') 'the sha is the first field'
Assert-True ($parsedTwo[0].Subject -eq 'fix(1853): repair it') 'the subject is the last one'
# THE TWO FIELDS #1878 ADDED, and the whole reason the format string grew: they are what the reader's
# decision turns on, and neither is derivable from the two that were already there.
Assert-True ($parsedTwo[1].Author -eq 'maikel-bwj') 'the author name is read'
Assert-True ($parsedTwo[1].AuthorEpoch -eq 1757620100) 'and so is the author date, as seconds'

# A LINE WITH TOO FEW FIELDS IS SKIPPED rather than becoming a commit with no sha -- git writes progress
# and hints that a caller not discarding stderr would otherwise hand in here.
$withNoise = "warning: some git hint`nabc1234${US}davekokbwj${US}1757620000${US}fix(1853): repair it"
Assert-True (@(ConvertFrom-CommitScanLog -Text $withNoise).Count -eq 1) 'a line carrying no separator is skipped'
Assert-True (@(ConvertFrom-CommitScanLog -Text "abc1234${US}subject only").Count -eq 0) 'and so is a line carrying the OLD two-field shape, rather than parsing as a wrong record'
Assert-True (@(ConvertFrom-CommitScanLog -Text "${US}a${US}1757620000${US}subject with no sha").Count -eq 0) 'a record with an empty sha is skipped too'

# THE COUNT ON THE SPLIT IS LOAD-BEARING: a subject may contain anything, and without the 4 the tail
# after a further separator would be silently dropped.
$oddSubject = "abc1234${US}davekokbwj${US}1757620000${US}fix: a | b`tc: d${US}tail"
$parsedOdd = @(ConvertFrom-CommitScanLog -Text $oddSubject)
Assert-True ($parsedOdd.Count -eq 1) 'a subject containing pipes, tabs and colons is one record'
Assert-True ($parsedOdd[0].Subject -eq "fix: a | b`tc: d${US}tail") 'and everything after the THIRD separator is kept, tail included'

# THE EPOCH IS DIGITS OR NOTHING. An author name holding a separator is the one shape that shifts the
# fields, and an age printed off a shifted field would be a confident wrong fact -- exactly the class
# #1878 was filed about. 0 is the report's signal to say it does not know.
$shifted = "abc1234${US}od${US}d name${US}1757620000${US}fix: x"
$parsedShift = @(ConvertFrom-CommitScanLog -Text $shifted)
Assert-True ($parsedShift.Count -eq 1) 'a shifted line still yields a record -- the sha is unaffected'
Assert-True ($parsedShift[0].Sha -eq 'abc1234') 'and the sha is still right'
Assert-True ($parsedShift[0].AuthorEpoch -eq 0) 'while the unreadable epoch reads as unknown rather than as a date'

Assert-True (@(ConvertFrom-CommitScanLog -Text "abc1234${US}a${US}1757620000${US}one`r`ndef5678${US}b${US}1757620001${US}two").Count -eq 2) 'CRLF captures parse the same as LF ones'

Write-Host ''
Write-Host 'Format-CommitAge -- how long ago, coarsely (#1878)' -ForegroundColor Cyan

Assert-True ((Format-CommitAge -Seconds 0) -eq 'just now') 'zero seconds is just now'
Assert-True ((Format-CommitAge -Seconds 59) -eq 'just now') 'and so is anything under a minute'
Assert-True ((Format-CommitAge -Seconds 180) -eq '3 minutes ago') 'minutes are the first unit -- the measured collision was three of them'
Assert-True ((Format-CommitAge -Seconds 60) -eq '1 minute ago') 'one of a unit is singular'
Assert-True ((Format-CommitAge -Seconds 7200) -eq '2 hours ago') 'hours come next'
Assert-True ((Format-CommitAge -Seconds 172800) -eq '2 days ago') 'then days'
Assert-True ((Format-CommitAge -Seconds 7776000) -eq '3 months ago') 'then months, so a stale branch does not print as ninety days'
Assert-True ((Format-CommitAge -Seconds 63072000) -eq '2 years ago') 'and years at the top'
# A CLOCK RUNNING AHEAD IS A FACT ABOUT CLOCKS, not about the commit -- and reading it as ancient is
# the one direction that would hide a live collision.
Assert-True ((Format-CommitAge -Seconds -30) -eq 'just now') 'a commit dated in the future reads as just now, not as an error'

Write-Host ''
Write-Host 'Test-SelfAuthored -- whose commit is this (#1878)' -ForegroundColor Cyan

Assert-True (Test-SelfAuthored -Author 'davekokbwj' -SelfNames @('davekokbwj', 'davekokbwj')) 'the checkout recognises its own name'
Assert-True (-not (Test-SelfAuthored -Author 'maikel-bwj' -SelfNames @('davekokbwj', 'davekokbwj'))) 'and does not recognise somebody else'
# THE COMPARISON IS AGAINST THE GIT AUTHOR NAME. A repo whose user.name is a display name never
# matches its own login, so comparing against the login alone would report every one of that person's
# own parked commits as a stranger's.
Assert-True (Test-SelfAuthored -Author 'Ada Lovelace' -SelfNames @('Ada Lovelace', 'ada')) 'a display-name checkout recognises its own commits'
Assert-True (Test-SelfAuthored -Author 'ADA' -SelfNames @('Ada Lovelace', 'ada')) 'either name matches, case-insensitively, as GitHub logins are'
# NO NAMES IS NO VERDICT, never 'somebody else': a check that cannot measure must not print one.
Assert-True (Test-SelfAuthored -Author 'maikel-bwj' -SelfNames @()) 'with nothing to compare against, nothing is claimed'
Assert-True (Test-SelfAuthored -Author 'maikel-bwj' -SelfNames @('', '  ')) 'and blank names are the same as none'
Assert-True (Test-SelfAuthored -Author '' -SelfNames @('davekokbwj')) 'an unreadable author name is not asserted to be somebody else either'

Write-Host ''
Write-Host 'Get-ForeignParkedCommit -- the locked-door half of the scan (#1878)' -ForegroundColor Cyan

$mineOnly = @([pscustomobject]@{ Sha = 'aaa'; Author = 'davekokbwj'; AuthorEpoch = 1757620000; Subject = 'x'; Branches = @('origin/fix/1853-x') })
Assert-True ($null -eq (Get-ForeignParkedCommit -Findings $mineOnly -SelfNames @('davekokbwj'))) 'a branch carrying only commits by this checkout is no verdict'
Assert-True ($null -eq (Get-ForeignParkedCommit -Findings @() -SelfNames @('davekokbwj'))) 'and neither is nothing at all'

$mixed = @(
    [pscustomobject]@{ Sha = 'newest'; Author = 'maikel-bwj'; AuthorEpoch = 1757620100; Subject = 'park: docs/1874-x'; Branches = @('origin/docs/1874-x') },
    [pscustomobject]@{ Sha = 'older'; Author = 'someone-else'; AuthorEpoch = 1757000000; Subject = 'fix(1874): older'; Branches = @('origin/other') }
)
$found = Get-ForeignParkedCommit -Findings $mixed -SelfNames @('davekokbwj')
Assert-True ($null -ne $found) 'a commit by another account is found'
Assert-True ($found.Sha -eq 'newest') 'and it is the NEWEST such commit -- the caller hands them in git log order'
Assert-True ($found.Branch -eq 'origin/docs/1874-x') 'the branch it names is the one the reader has to go and look at'

# A FINDING WHOSE BRANCHES WERE ALL EXCLUDED IS NOT IN THE REPORT, so it must not produce a verdict
# either -- the two have to agree about which commits are even being discussed.
$excluded = @([pscustomobject]@{ Sha = 'aaa'; Author = 'maikel-bwj'; AuthorEpoch = 1757620100; Subject = 'x'; Branches = @() })
Assert-True ($null -eq (Get-ForeignParkedCommit -Findings $excluded -SelfNames @('davekokbwj'))) 'a commit with no surviving branch is out of scope for the verdict too'

Write-Host ''
Write-Host 'Get-ContainingBranchNames -- cleaning git branch -a --contains (#1853)' -ForegroundColor Cyan

$branchText = @(
    '  fix/1853-parked-fix-scan',
    '* main',
    '+ feat/held-by-a-worktree',
    '  remotes/origin/fix/1853-parked-fix-scan',
    '  remotes/origin/feat/somebody-else',
    '  remotes/origin/HEAD -> origin/main'
) -join "`n"

$cleaned = @(Get-ContainingBranchNames -Text $branchText -Exclude @('main', 'origin/main'))
Assert-True ($cleaned -contains 'feat/held-by-a-worktree') "the '+' worktree marker is stripped, not treated as part of the name"
Assert-True ($cleaned -contains 'origin/feat/somebody-else') "the 'remotes/' prefix is stripped to the spelling a reader can paste"
Assert-True (-not ($cleaned -contains 'main')) 'an excluded branch is dropped'
Assert-True (@($cleaned | Where-Object { $_ -match '->' }).Count -eq 0) 'the symbolic origin/HEAD line is dropped rather than named twice'
Assert-True (@(Get-ContainingBranchNames -Text '  (HEAD detached at abc1234)').Count -eq 0) 'a detached HEAD is not a branch'
Assert-True (@(Get-ContainingBranchNames -Text '').Count -eq 0) 'empty input is an empty array'

# THE CURRENT BRANCH IS WHAT THE CALLER EXCLUDES ON A RESUME, and reporting a session's own commits
# back to it as somebody else's parked work is the fastest way to teach it to skip this warning.
$onlyMine = @(Get-ContainingBranchNames -Text $branchText -Exclude @('main', 'origin/main', 'fix/1853-parked-fix-scan', 'origin/fix/1853-parked-fix-scan'))
Assert-True (-not ($onlyMine -contains 'fix/1853-parked-fix-scan')) 'the current branch is excludable in its local spelling'
Assert-True (-not ($onlyMine -contains 'origin/fix/1853-parked-fix-scan')) 'and in its remote one'

# CASE-SENSITIVELY, because git refs are: 'Main' and 'main' are two branches, and dropping the wrong
# one would hide real parked work.
Assert-True (@(Get-ContainingBranchNames -Text '  Main' -Exclude @('main')) -contains 'Main') "exclusion is case-sensitive, as git refs are"

$dupText = "  feat/x`n  feat/x`n  remotes/origin/a"
$deduped = @(Get-ContainingBranchNames -Text $dupText)
Assert-True ($deduped.Count -eq 2) 'a name listed twice appears once'
Assert-True ($deduped[0] -eq 'feat/x' -and $deduped[1] -eq 'origin/a') 'and the order is sorted, so two runs print the same line'

# THE LOCAL/REMOTE FOLD. A checkout holding a local copy of a parked branch gets both spellings from
# `git branch -a --contains`, and they are ONE piece of work -- counting both inflates the single
# number this report exists to give.
$twinText = "  feat/x`n  remotes/origin/feat/x`n  remotes/origin/other"
$folded = @(Get-ContainingBranchNames -Text $twinText)
Assert-True ($folded.Count -eq 2) 'a local branch and its own remote-tracking twin count once'
Assert-True ($folded -contains 'origin/feat/x') 'and the REMOTE spelling is the one kept -- it is the address that is true for anybody'
Assert-True (-not ($folded -contains 'feat/x')) 'so the bare local name is folded away'
Assert-True (@(Get-ContainingBranchNames -Text "  feat/local-only") -contains 'feat/local-only') 'a branch with no twin keeps its own name'
# A SECOND REMOTE IS NOT A TWIN: a local branch tracking 'upstream' is indistinguishable here from two
# unrelated branches sharing a name, so the fold deliberately only knows 'origin/'.
$otherRemote = @(Get-ContainingBranchNames -Text "  feat/x`n  remotes/upstream/feat/x")
Assert-True ($otherRemote.Count -eq 2) 'a non-origin remote folds nothing -- it cannot be told from two unrelated branches'

Write-Host ''
Write-Host 'Format-ParkedFixReport -- what is worth saying, and what is not (#1853)' -ForegroundColor Cyan

Assert-True (@(Format-ParkedFixReport -Issue 1853 -Findings @()).Count -eq 0) 'no findings means no lines at all, not an empty header'

$noBranches = @([pscustomobject]@{ Sha = 'abc'; Subject = 'x'; Branches = @() })
Assert-True (@(Format-ParkedFixReport -Issue 1853 -Findings $noBranches).Count -eq 0) 'a finding whose branches were all excluded is dropped, not printed as a commit in no branch'

# NOW is pinned on every call below, so the ages in these lines are reproducible rather than a
# function of when the suite happens to run.
$Now = 1757620300
$oneFinding = @([pscustomobject]@{ Sha = 'f686b0af3fda'; Author = 'davekokbwj'; AuthorEpoch = 1757620120; Subject = 'fix(1842): apply the parallel review findings'; Branches = @('origin/feat/1842-unify-prio-labels-bwj') })
$oneReport = @(Format-ParkedFixReport -Issue 1847 -Findings $oneFinding -SelfNames @('davekokbwj') -NowEpoch $Now)
Assert-True ($oneReport.Count -gt 0) 'a real finding produces a report'
Assert-True ($oneReport[0] -match '1 commit on 1 branch') 'the lead line counts in the singular for one of each'
Assert-True (@($oneReport | Where-Object { $_ -match 'origin/feat/1842-unify-prio-labels-bwj' }).Count -eq 1) 'the branch is named once, as its own line'
Assert-True (@($oneReport | Where-Object { $_ -match 'f686b0af  davekokbwj, 3 minutes ago -- fix\(1842\)' }).Count -eq 1) 'the commit line is sha, WHO, WHEN, then the subject (#1878)'
Assert-True (@($oneReport | Where-Object { $_ -match 'cannot tell a fix from a mention' }).Count -eq 1) 'the report says what it does not know, so it cannot be read as a verdict'
# The commit above is this checkout own, so no verdict block belongs under it.
Assert-True (@($oneReport | Where-Object { $_ -match 'NOT YOURS' }).Count -eq 0) 'and a branch of your own draws no verdict at all'

# THE VERDICT, which is the whole of #1878: the two facts printed above decide it, and leaving the
# reader to assemble them is what the measured session did -- correctly, by content, and wrongly.
$foreignFinding = @(
    [pscustomobject]@{ Sha = 'afb52d0bcc'; Author = 'maikel-bwj'; AuthorEpoch = 1757620120; Subject = 'park: docs/1874-preview-control-variant (the branch files only)'; Branches = @('origin/docs/1874-preview-control-variant') }
)
$foreignReport = @(Format-ParkedFixReport -Issue 1874 -Findings $foreignFinding -SelfNames @('davekokbwj') -NowEpoch $Now)
Assert-True (@($foreignReport | Where-Object { $_ -match 'NOT YOURS' }).Count -eq 1) 'a commit by another account draws a refusal-shaped verdict'
Assert-True (@($foreignReport | Where-Object { $_ -match "'maikel-bwj', 3 minutes ago" }).Count -eq 1) 'which names the account and the age -- the two facts the judgement turns on'
Assert-True (@($foreignReport | Where-Object { $_ -match 'origin/docs/1874-preview-control-variant' }).Count -eq 2) 'and the branch, in the listing and again in the verdict'
Assert-True (@($foreignReport | Where-Object { $_ -match 'ASK THEM BEFORE YOU WRITE ANYTHING' }).Count -eq 1) 'it says what to do instead of describing the state'
Assert-True (@($foreignReport | Where-Object { $_ -match 'empty by design' }).Count -eq 1) 'and it names the trap: the park commit content is exactly what cannot answer this'
Assert-True ($foreignReport[$foreignReport.Count - 1] -match 'mid-flight') 'the verdict is last, where the reader stops'
# REFUSAL-SHAPED, NOT A REFUSAL. The scan matches any commit NAMING the issue, and a colleague
# mentioning one in a commit of their own is ordinary -- so the closing caveat stays put.
Assert-True (@($foreignReport | Where-Object { $_ -match 'the claim stands either way' }).Count -eq 1) 'the claim still stands -- this scan cannot tell a fix from a mention'

# NO SELF NAMES, NO VERDICT. On a checkout with no user.name there is nothing to compare against, and
# a check that cannot measure must not print one.
$blindReport = @(Format-ParkedFixReport -Issue 1874 -Findings $foreignFinding -SelfNames @() -NowEpoch $Now)
Assert-True (@($blindReport | Where-Object { $_ -match 'NOT YOURS' }).Count -eq 0) 'with no name to compare against, no verdict is printed'
Assert-True (@($blindReport | Where-Object { $_ -match 'maikel-bwj, 3 minutes ago' }).Count -eq 1) 'but the author and the age are still printed -- they are facts, not a judgement'

# AN AGE THIS RUN COULD NOT READ IS SAID, not guessed at.
$noEpoch = @([pscustomobject]@{ Sha = 'abc12345'; Author = 'maikel-bwj'; AuthorEpoch = 0; Subject = 'x'; Branches = @('origin/feat/y') })
Assert-True (@(Format-ParkedFixReport -Issue 1 -Findings $noEpoch -SelfNames @('davekokbwj') -NowEpoch $Now | Where-Object { $_ -match 'abc12345  maikel-bwj, at an unknown time' }).Count -eq 1) 'an unreadable author date prints as unknown rather than as 1970'

# A RECORD FROM BEFORE #1878 -- no Author, no AuthorEpoch -- still prints rather than throwing.
$legacy = @([pscustomobject]@{ Sha = 'abc12345'; Subject = 'x'; Branches = @('origin/feat/y') })
Assert-True (@(Format-ParkedFixReport -Issue 1 -Findings $legacy -SelfNames @('davekokbwj') -NowEpoch $Now | Where-Object { $_ -match 'author unknown' }).Count -eq 1) 'a record missing the new fields prints what it has'

# GROUPED BY BRANCH, which is the unit the reader acts on. A commit on two branches belongs under both:
# that is the answer to "which of these do I look at", not duplication.
$shared = @([pscustomobject]@{ Sha = 'aaaaaaaa11'; Subject = 'fix(1853): one'; Branches = @('origin/feat/b', 'origin/feat/a') })
$sharedReport = @(Format-ParkedFixReport -Issue 1853 -Findings $shared)
Assert-True ($sharedReport[0] -match '1 commit on 2 branches') 'the lead line counts commits and branches separately'
$branchLines = @($sharedReport | Where-Object { $_ -match '^  origin/feat/' })
Assert-True ($branchLines.Count -eq 2) 'a commit on two branches is listed under both'
Assert-True ($branchLines[0] -match 'origin/feat/a') 'and the branches come out sorted'

# THE CAP IS WHAT KEEPS THIS A WARNING RATHER THAN A WALL: a branch cut for this issue writes its
# number into every commit subject, so a week-old one matches dozens of times.
$many = @(1..5 | ForEach-Object { [pscustomobject]@{ Sha = "sha00000$_"; Subject = "fix(1853): step $_"; Branches = @('origin/fix/1853-x') } })
$capped = @(Format-ParkedFixReport -Issue 1853 -Findings $many -MaxCommitsPerBranch 2)
Assert-True (@($capped | Where-Object { $_ -match '^      sha00000' }).Count -eq 2) 'only the capped number of commits is listed'
Assert-True (@($capped | Where-Object { $_ -match 'and 3 more naming #1853' }).Count -eq 1) 'the overflow is named rather than silently hidden'
Assert-True ($capped[0] -match '5 commits on 1 branch') 'and the lead line still counts all of them'

$capZero = @(Format-ParkedFixReport -Issue 1853 -Findings $many -MaxCommitsPerBranch 0)
Assert-True (@($capZero | Where-Object { $_ -match '^      sha00000' }).Count -eq 1) 'a cap below 1 still shows one example -- a branch with nothing under it says nothing'

Write-Host ''
Write-Host 'Get-SignificantWords -- tokenizing a title or a branch slug (#2018)' -ForegroundColor Cyan

Assert-True ((@(Get-SignificantWords -Text 'Get-StageFromSectionName / Test-AsanaStageMap') -join ',') -eq 'stage,section,name,test,asana') `
    'camelCase identifiers split into their own words, in order, deduped -- "get"/"from"/"map" fall out (stop list or MinLength), which is the filters doing their job, not the splitter failing to split'
Assert-True (@(Get-SignificantWords -Text 'a the for so not so').Count -eq 0) 'short structural words are all on the stop list'
Assert-True (@(Get-SignificantWords -Text '#2016 issue 1234') -notcontains '2016') 'a pure-digit token is dropped -- the fourth signal already owns issue numbers'
Assert-True (@(Get-SignificantWords -Text 'cat dog owl').Count -eq 0) 'words below the default MinLength (4) are dropped'
Assert-True ((@(Get-SignificantWords -Text 'code CODE Code') -join ',') -eq 'code') 'case is folded, and a repeated word appears once'
Assert-True (@(Get-SignificantWords -Text '').Count -eq 0) 'empty text has no significant words'
Assert-True (@(Get-SignificantWords -Text '   ').Count -eq 0) 'whitespace-only text has no significant words'

Write-Host ''
Write-Host 'Get-BranchSlugWords -- the prefix and the issue number are not the subject (#2018)' -ForegroundColor Cyan

Assert-True ((@(Get-BranchSlugWords -Branch 'fix/2016-compound-stage-code') -join ',') -eq 'compound,stage,code') `
    'the type prefix and the leading issue number are stripped before tokenizing'
Assert-True ((@(Get-BranchSlugWords -Branch 'fix/asana-stage-letter-codes') -join ',') -eq 'asana,stage,letter,codes') `
    'a branch with no leading number tokenizes the whole slug'
Assert-True (@(Get-BranchSlugWords -Branch '').Count -eq 0) 'an empty branch name has no words'

Write-Host ''
Write-Host 'Get-TitleOverlapBranches -- the fifth pickup signal itself (#2018)' -ForegroundColor Cyan

$title2016 = "Get-StageFromSectionName / Test-AsanaStageMap can't handle a compound stage code, so a board that groups columns under one Workload-style number silently breaks"
$candidateBranches = @('fix/2016-compound-stage-code', 'fix/asana-stage-letter-codes', 'docs/2012-ticket-work-step-reach', 'fix/1830-git-identity-skip-vs-ok')

# THE MEASURED CASE ITSELF: the branch #2018 was filed about, found by name alone.
$overlaps2016 = @(Get-TitleOverlapBranches -Title $title2016 -Branches $candidateBranches)
Assert-True (@($overlaps2016 | Where-Object { $_.Branch -eq 'fix/asana-stage-letter-codes' }).Count -eq 1) `
    'the no-number branch #2018 was filed about is found by its shared words alone'
$asanaHit = $overlaps2016 | Where-Object { $_.Branch -eq 'fix/asana-stage-letter-codes' }
Assert-True ((@($asanaHit.SharedWords) -join ',') -eq 'asana,stage') 'and the shared words are the ones a reader would recognise'
Assert-True (@($overlaps2016 | Where-Object { $_.Branch -eq 'docs/2012-ticket-work-step-reach' }).Count -eq 0) `
    'an unrelated branch is not reported'
$overlapBranchNames = @($overlaps2016 | Select-Object -ExpandProperty Branch)
Assert-True (($overlapBranchNames -join ',') -eq (($overlapBranchNames | Sort-Object) -join ',')) `
    'results come out sorted by branch name, so two runs print the same order'

Assert-True (@(Get-TitleOverlapBranches -Title '' -Branches $candidateBranches).Count -eq 0) 'a title with no significant words matches nothing'
Assert-True (@(Get-TitleOverlapBranches -Title $title2016 -Branches @()).Count -eq 0) 'no branches to compare against is an empty result, not an error'
Assert-True (@(Get-TitleOverlapBranches -Title $title2016 -Branches @($null, '', '  ')).Count -eq 0) 'blank branch entries are skipped rather than crashing the scan'

# THE FLOOR: below 1 is treated as 1, the same defensive floor Format-ParkedFixReport's own
# -MaxCommitsPerBranch applies, so a caller cannot silently disable the threshold to 0.
$flooredNames = @(Get-TitleOverlapBranches -Title $title2016 -Branches $candidateBranches -MinSharedWords 0 | Select-Object -ExpandProperty Branch | Sort-Object)
$unflooredNames = @(Get-TitleOverlapBranches -Title $title2016 -Branches $candidateBranches -MinSharedWords 1 | Select-Object -ExpandProperty Branch | Sort-Object)
Assert-True (($flooredNames -join ',') -eq ($unflooredNames -join ',')) 'MinSharedWords below 1 behaves exactly as 1'

Write-Host ''
Write-Host 'The measurement behind the default: the corpus Get-SignificantWords is documented against (#2018)' -ForegroundColor Cyan

# THIS IS THE MEASUREMENT ITSELF, PINNED, not merely cited in the doc comment above the function.
# 21 branches off this repo's own trunk at the time #2018 was picked up, matched against the 21 issue
# titles behind them (fix/asana-stage-letter-codes carries #2016's REPAIR but not #2016's NUMBER, which
# is the whole reason it is in this corpus at all). A change to Get-SignificantWords or
# Get-TitleOverlapBranches that moves these counts must update this test AND the doc comment above
# Get-SignificantWords together, or the two go stale in different directions.
# PLAIN HASHTABLES, NOT [ordered] -- System.Collections.Specialized.OrderedDictionary carries a
# POSITIONAL int indexer alongside its key indexer, and an integer key ($corpusTitles[2016]) resolves
# to the wrong one silently ($null, not a throw): measured here while writing this very test. Order
# does not matter to what these two tables assert, so the plain [hashtable] sidesteps the trap rather
# than working around it with quoted string keys.
$corpusTitles = @{
    1830 = 'git-identity-sessioncheck reports agreement on a machine with no git identity, because it branches on the exit code rather than the verdict'
    1842 = 'Unify the priority axis on prio-1..prio-4 in the BWJ repos too (Dave reverses half 1 of #1686)'
    1848 = 'Retire $script:LegacyPrioLabels once both BWJ stores are migrated -- four generic words a daily issues:write job strips'
    1857 = 'No suite ever EXECUTES a plugin-mirror copy of a shared script -- only the source copy, with the drift lint standing in for the rest'
    1858 = 'Format-ForConsole strips only the ASCII control range, so a bidi override in a title or a branch name still reaches the terminal'
    1865 = 'fixture-lib-deps scans only *.tests.ps1, so the shared lint fixture builder the four integrity suites use is invisible to it'
    1870 = "The reach label goes portable: every dkj-policy consumer carries 'minor', the tier model applied to issues"
    1890 = "Updating a checkout's plugins is 1 + N commands per machine, and the CLI has no --all"
    1895 = "dkj-policy ships no label ADOPTER: the prio set is prose in one family's page, and apply-vs-print is undecided"
    1916 = 'open-pr and ship-pr report a 5xx on a MUTATION as a hard failure, while claim-issue documents the opposite doctrine for exactly that case'
    1931 = 'An absent exit code reads as a measured failure at ~270 comparison sites -- ExitCodeUnknown is reported but nothing consults it'
    1973 = 'Run parallel sessions with worktrees'
    1976 = 'dkj-policy-bwj: THEME-LIFECYCLE-portable.md claims both BWJ stores answer Get-ShopifyThemeDeleteMarker; smartwatchbanden deliberately does not'
    1980 = 'dkj-policy: a committed artifact SOURCE records no published URL, so the next session republishes it as a NEW artifact and silently orphans its database'
    1988 = "update-plugins.ps1 fails on Windows: Invoke-NativeCapture's -Utf8/Start-Process arm resolves 'claude' to npm's extensionless POSIX shim"
    1990 = 'SPECIALISTS.md still says dkj-policy-bwj has no real work here, after the gate admitted this repo'
    2012 = "dkj-policy-bwj: 'ticket-work step' description still says BWJ's two Shopify store repos in three more docs"
    2014 = "dkj-policy-bwj: plugins/dkj-policy/README.md:98 still says 'three chapters' and 'Two skills'"
    2016 = $title2016
    2017 = 'dkj-policy-bwj: the seam list still says three seams in three documents, and the chapter-four count in one more'
    2018 = "claim-issue's parked-fix scan matches on the ISSUE NUMBER, so a branch named for the subject is invisible -- measured as a full duplicate implementation"
}
$corpusBranches = @{
    1830 = 'fix/1830-git-identity-skip-vs-ok'
    1842 = 'feat/1842-unify-prio-labels-bwj'
    1848 = 'fix/1848-retire-legacy-prio-labels'
    1857 = 'feat/1857-mirror-depth-gate'
    1858 = 'fix/1858-bidi-console-strip'
    1865 = 'fix/1865-fixture-dep-scan-set'
    1870 = 'feat/1870-reach-label-portable'
    1890 = 'feat/1890-update-plugins'
    1895 = 'feat/1895-triage-label-adopter'
    1916 = 'fix/1916-gh-mutation-5xx-not-hard-fail'
    1931 = 'fix/1931-exit-code-unknown-audit'
    1973 = 'docs/1973-native-worktree-note'
    1976 = 'docs/1976-theme-lifecycle-delete-marker-claim'
    1980 = 'docs/1980-artifact-source-url-record'
    1988 = 'fix/1988-native-capture-utf8-claude-shim'
    1990 = 'docs/1990-bwj-plugin-no-work-stale'
    2012 = 'docs/2012-ticket-work-step-reach'
    2014 = 'docs/2014-bwj-chapter-skill-counts'
    2016 = 'fix/2016-compound-stage-code'
    2017 = 'docs/2017-bwj-four-seams'
    2018 = 'fix/2018-parked-fix-scan-title-overlap'
}
$corpusAllBranches = @($corpusBranches.Values) + 'fix/asana-stage-letter-codes'

function Measure-CorpusOverlap {
    param([int]$MinSharedWords)
    $self = 0; $target = 0; $noise = 0
    foreach ($key in $corpusTitles.Keys) {
        foreach ($o in @(Get-TitleOverlapBranches -Title $corpusTitles[$key] -Branches $corpusAllBranches -MinSharedWords $MinSharedWords)) {
            if ($o.Branch -eq $corpusBranches[$key]) { $self++ }
            elseif ($key -eq 2016 -and $o.Branch -eq 'fix/asana-stage-letter-codes') { $target++ }
            else { $noise++ }
        }
    }
    return [pscustomobject]@{ Self = $self; Target = $target; Noise = $noise }
}

$m1 = Measure-CorpusOverlap -MinSharedWords 1
$m2 = Measure-CorpusOverlap -MinSharedWords 2
$m3 = Measure-CorpusOverlap -MinSharedWords 3
Assert-True ($m1.Self -eq 19 -and $m1.Target -eq 1 -and $m1.Noise -eq 27) 'at threshold 1: 19 self-hits, the target hit, and 27 unrelated cross-hits -- too noisy'
Assert-True ($m2.Self -eq 14 -and $m2.Target -eq 1 -and $m2.Noise -eq 3) 'at threshold 2 (the default): 14 self-hits, the target hit, and only 3 -- each a genuinely related pair'
Assert-True ($m3.Self -eq 7 -and $m3.Target -eq 0 -and $m3.Noise -eq 0) 'at threshold 3: silent, and it misses the very branch #2018 was filed about'

Write-Host ''
Write-Host 'Format-TitleOverlapReport -- the fifth signal is worded weaker than the fourth (#2018)' -ForegroundColor Cyan

Assert-True (@(Format-TitleOverlapReport -Issue 2016 -Title $title2016 -Overlaps @()).Count -eq 0) 'no overlaps means no lines at all'

$oneOverlap = @([pscustomobject]@{ Branch = 'fix/asana-stage-letter-codes'; SharedWords = @('asana', 'stage') })
$overlapReport = @(Format-TitleOverlapReport -Issue 2016 -Title $title2016 -Overlaps $oneOverlap)
Assert-True ($overlapReport[0] -match '1 branch off the trunk') 'the lead line counts in the singular for one branch'
Assert-True (@($overlapReport | Where-Object { $_ -match 'fix/asana-stage-letter-codes\s+--\s+shares: asana, stage' }).Count -eq 1) 'the branch and its shared words are printed together'
Assert-True (@($overlapReport | Where-Object { $_ -match 'NOT YOURS' }).Count -eq 0) `
    'the fifth signal never borrows the fourth signal''s stronger verdict wording'
Assert-True (@($overlapReport | Where-Object { $_ -match 'ASK THEM BEFORE YOU WRITE ANYTHING' }).Count -eq 0) `
    'nor its imperative -- a shared word is weaker evidence than a number, not stronger (#2018)'
Assert-True (@($overlapReport | Where-Object { $_ -match 'is not a matched number' }).Count -eq 1) 'the hedge says plainly that this is not the fourth signal'

$twoOverlaps = @(
    [pscustomobject]@{ Branch = 'fix/2016-compound-stage-code'; SharedWords = @('code', 'compound', 'stage') },
    [pscustomobject]@{ Branch = 'fix/asana-stage-letter-codes'; SharedWords = @('asana', 'stage') }
)
$twoReport = @(Format-TitleOverlapReport -Issue 2016 -Title $title2016 -Overlaps $twoOverlaps)
Assert-True ($twoReport[0] -match '2 branches off the trunk') 'the lead line counts in the plural for more than one'

Write-Host ''
Write-Host 'The parked-fix scan inside claim-issue.ps1 (#1853)' -ForegroundColor Cyan

# The block a suite can hold: everything between its own heading and the verdict switch it sits above.
$scan = if ($body -match '(?s)# --- IS THE FIX ALREADY SITTING ON A BRANCH \(issue #1853\).*?\n(.*?)\nswitch \(\$verdict\.Code\)') { $Matches[1] } else { '' }
Assert-True ($scan -ne '') 'the scan block is present, above the verdict switch'

# IT RUNS ONLY WHERE THERE IS SOMETHING TO SAVE. Gated on the verdict, so a closed or taken issue --
# both of which exit in the switch below -- pays nothing for an answer it would not use, while a RESUME
# ('skip') gets it, which is the case Chris's own body calls picking up.
Assert-True ($scan -match "\`$verdict\.Action\s+-eq\s+'claim'") 'the scan runs on a fresh claim'
Assert-True ($scan -match "\`$verdict\.Action\s+-eq\s+'skip'") 'and on a resume, where the other session is the only trace there is'

# ADVISORY, NEVER A REFUSAL (#1485): a claim that blocks costs the whole assignment, and this check
# cannot tell a fix from a mention. An `exit` added here would be that rule broken in one line, on a
# path no behavioural test can reach.
Assert-True ($scan -notmatch '(?m)^\s*exit\s') 'nothing in the scan exits -- the claim stands whatever it finds'
Assert-True ($scan -notmatch 'REFUSED') 'and it never speaks in the refusal vocabulary'

# THE FETCH GOES THROUGH THE SHARED SEAM (#1860), NOT THROUGH A CALL OF ITS OWN. new-branch.ps1 runs
# immediately after this script by design -- the claim is the OPENING of the work (#1485) -- and it
# fetches the same remote inside Get-TrunkGap, so before the seam a fresh assignment paid for two full
# network calls seconds apart, and against an unreachable remote for two full network BOUNDS.
#
# WHAT MOVED IS THE CALL, NOT THE RULE. The two properties this block held before -- the bound, and
# keeping git's stderr (#1313) -- still have to hold, and the assert follows them down one layer:
# Invoke-RecordedRemoteFetch's own suite (scripts/tests/fetch-attempt.tests.ps1) holds the stderr half
# where the git call now lives, and the bound stays HERE, because passing it is this script's decision
# rather than the lib's default.
Assert-True ($scan -match "(?s)Invoke-RecordedRemoteFetch.*?-TimeoutSeconds\s+\`$NativeCaptureNetworkTimeoutSeconds") 'the fetch is bounded'
Assert-True ($scan -match '\$staleNote') 'a fetch that did not answer is reported rather than read as a clean scan'

# THE ARGUMENT-LESS FORM SURVIVED THE MOVE, and it is the half a shared seam could quietly take away:
# #1853 chose git's DEFAULT remote over 'origin' by name, so a checkout whose default is something else
# must match nothing rather than be assumed into another script's premise. -Remote is therefore absent
# here on purpose, and the seam resolves the name for its record alone.
$fetchCall = if ($scan -match "(?s)(\`$fetch\s*=\s*Invoke-RecordedRemoteFetch.*?)\n\s*\`$staleNote") { $Matches[1] } else { '' }
Assert-True ($fetchCall -ne '') 'the fetch statement is findable'
Assert-True ($fetchCall -notmatch '-Remote') "the fetch still names no remote, so git's own default is what the scan reads (#1853)"
Assert-True ($scan -match '\$staleDetail') 'and those lines are actually printed -- keeping stderr and never showing it is the same loss one step later'

# BOTH UNTRUSTED FIELDS GO THROUGH THE ONE SANITISER. A commit subject and a ref name come from the
# same place -- anyone who can push -- and the branch name was the half printed raw.
Assert-True ($scan -match '(?s)Subject\s*=\s*\(Format-ForConsole') 'the commit subject is stripped before printing'
Assert-True ($scan -match '(?s)Branches\s*=\s*@\(\$branches\s*\|\s*ForEach-Object\s*\{\s*Format-ForConsole') 'and so is every branch name'

# WITHOUT A TRUNK REF TO SUBTRACT, `git log --all` reports the issue's own merged repair on the trunk --
# the noise that teaches a reader to skip the warning. So: no trunk ref, no scan.
Assert-True ($scan -match '\$trunkRefs\.Count\s+-gt\s+0') 'the scan is skipped where no trunk ref could be verified'
Assert-True ($scan -match "'--not'") 'and the trunk is subtracted from the log it reads'
Assert-True ($scan -match '\$currentBranch') "the session's own branch is excluded, so a resume is not warned about itself"

# THE CONTAINMENT LOOP IS BOUNDED, and Format-ParkedFixReport's display cap does NOT bound it -- that
# one trims what is PRINTED, after every commit has already paid for its own ancestry walk. A branch
# whose every subject carries the number (the convention is `fix(<n>): ...`) is the shape that runs
# away, and one issue in this repo's history is named by 21 commits.
Assert-True ($scan -match '\$maxContainmentReads\s*=\s*[0-9]+') 'the per-commit containment reads have a stated ceiling'
Assert-True ($scan -match 'Select-Object\s+-First\s+\$maxContainmentReads') 'and the loop actually honours it'
Assert-True ($scan -match 'were resolved to a branch') 'a truncation says so -- a cap a reader cannot see is the defect this check exists to remove, one layer in'
# $matches is a PowerShell automatic variable; assigning to it inside a script that also uses -match
# is the kind of collision that produces a wrong answer rather than an error.
Assert-True ($scan -notmatch '\$matches\s*=') 'the match list does not shadow the automatic $Matches'

# THE TWO FIELDS #1878 ADDED ARE ASKED FOR IN THE LOG CALL, and nothing downstream can recover them if
# they are not: the report would print the same sha and subject it always did, and the session that
# read them would reach the same wrong conclusion for the same reason.
Assert-True ($scan -match '%H%x1f%an%x1f%at%x1f%s') 'the log call asks git for the author and the author date'
Assert-True ($scan -match '(?s)Author\s*=\s*\(Format-ForConsole') 'the author name is stripped before printing -- it is pushed text like the other two'
# WHOSE COMMITS COUNT AS THIS CHECKOUT'S OWN. The GIT name first, because %an is what the scan read;
# the login as well, so a split checkout (#1315) recognises itself under either.
Assert-True ($scan -match '\$identity\.GitUserName') 'the self test compares against the git name, not the login alone'
Assert-True ($scan -match 'Format-ParkedFixReport[^\r\n]*-SelfNames') 'and the report is told which names are its own'

# THE CLOSING VERDICT MAY NOT CONTRADICT THE BLOCK. A run that prints 'ASK THEM BEFORE YOU WRITE
# ANYTHING' and closes with 'the work starts here' has told the reader both and settled neither -- and
# the closing line is the one a session acts on. Held here because it is a SILENCE otherwise: every
# behavioural property of the scan passes with the old headline still in place.
Assert-True ($scan -match 'Get-ForeignParkedCommit') 'the script asks the lib for the verdict rather than scraping it back out of the printed lines'
Assert-True ($body -match '\$foreignParked\s*=\s*\$false') 'the flag has a default, so a scan that never ran cannot leave it undefined'
Assert-True ($body -match '\$opening\s*=\s*if\s*\(\$foreignParked\)') 'the closing headline reads the flag'
Assert-True ($body -match 'read the parked-fix verdict above before you start') 'and says so rather than asserting the work starts here'
Assert-True ($body -match 'BUT NOT THAT BRANCH') 'the resume verdict carries it too -- where the other session branch is already in the working copy'

foreach ($path in @($Script, $Lib, $IdLib)) {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
    Assert-True (@($errors).Count -eq 0) "$(Split-Path -Leaf $path) parses without error"
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "claim-issue.tests: $($script:pass) passed, $($script:fail) FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "claim-issue.tests: $($script:pass) passed, 0 failed" -ForegroundColor Green
exit 0
