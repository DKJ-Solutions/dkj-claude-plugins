<#
.SYNOPSIS
    SHA-256 over text or bytes, rendered as lowercase hex and optionally truncated -- the one
    definition of an idiom this tree had hand-copied five times.

.DESCRIPTION
    THE MEASUREMENT THIS EXISTS FOR (issue #2058, September 17, 2026). Five files carried the same
    seven lines: create a SHA-256 provider, ComputeHash over encoded bytes, dispose it in a finally,
    and render the digest as lowercase hex, sometimes cut to a fixed length. gate-lib.ps1,
    session-cache-lib.ps1, check-consumer-siblings.ps1, theme-archive-rules.ps1 and -- on the parked
    branch fix/2055-preview-theme-name-length, where a code review found all of this --
    theme-lifecycle-rules.ps1.

    THREE OF THE FIVE ARE FOLDED IN HERE. The two Shopify ones are not, and that is a decision rather
    than an oversight -- see the second carve-out below.

    THE DUPLICATION HAD ALREADY DRIFTED, WHICH IS WHAT SETTLED THE JUDGEMENT #2058 LEFT OPEN. The
    issue filed this as a reuse note explicitly, saying nothing observable was wrong and that the
    trade was for whoever next touched one of the files. Reading the copies before folding them found
    that check-consumer-siblings.ps1 had drifted in two ways at once: it never disposed its provider
    -- and it creates one PER FILE, inside a Get-ChildItem -Recurse over every comparable path in a
    consumer checkout -- and it rendered UPPERCASE hex, via BitConverter::ToString().Replace('-','')
    with no .ToLower(), where every other copy renders lowercase through .ToString('x2'). Neither was
    load-bearing, and that is the point: the copies diverged silently, in the direction the issue
    predicted, before anybody was comparing them.

    WHY THE CASE CHANGE IS SAFE THERE, CHECKED RATHER THAN ASSUMED. That fingerprint is only ever
    compared against other fingerprints from the same function: check-consumer-siblings.ps1 picks its
    route once per run ($useGitHub), so a run is either all git blob ids or all disk hashes -- the
    one-scheme rule Compare-SiblingInventory states in its own header. The value is never printed
    (only the path count is), never stored, and never compared across runs. So the case was
    unobservable, which is exactly why it was free to drift.

    WHAT IS DELIBERATELY NOT FOLDED IN HERE, ONE. Get-GitRawBlobId in sync-rules.ps1 composes git's
    own object id -- SHA1('blob ' + length + NUL + bytes) -- so its algorithm is git's choice and not
    this tree's. #2058 names it as one to leave alone, and the name of this function is the fence
    that keeps it out: a helper called Get-Sha256Hex cannot be reached for by something that must
    stay SHA-1.

    WHAT IS DELIBERATELY NOT FOLDED IN HERE, TWO -- AND THIS ONE DEPARTS FROM WHAT #2058 ASKED FOR.
    theme-archive-rules.ps1 and theme-lifecycle-rules.ps1 keep their hand-written copies. Both are
    registered in the shared-scripts registry with an argued DEPENDENCY-FREE property, and both
    registrations call it a safety property rather than a style: the live-theme guard reads
    repo-config.ps1 on every command inside a catch that returns no live theme id, so a lib in that
    family which pulls anything in is a way to disarm a guard over a revenue-serving theme -- on a
    store carrying about 39 themes belonging to other people. Adopting this helper there would also
    need a SECOND registration of this file for dkj-subagents-shopify, because the two plugins are
    separately versioned and separately installed and a cross-plugin dot-source breaks silently on a
    version mismatch, which sync-rules.ps1 rules out by name.

    WHAT THAT BUYS AND WHAT IT COSTS, SO THE TRADE IS AUDITABLE. Bought: two files keep a property
    their own registrations argue for, and this lib needs one registration instead of two. Paid: the
    six-character theme-name renderer #2058 leads with -- one of the two load-bearing short-hash
    sites it was most worried about -- stays hand-written. That is the weaker half of the issue's
    case: the two name sites are in different plugins, hash different inputs for different purposes,
    and are never compared with each other, so each only has to agree with ITSELF across runs, which
    a single file's own code already does. The drift the issue predicted is real and had already
    happened -- but in check-consumer-siblings.ps1, which IS folded in here, not at either name site.

    THERE IS NO -Encoding PARAMETER, AND THAT IS THE SAME DECISION ONE LAYER DOWN. theme-archive-rules
    encodes its manifest text as ASCII, so folding it in would have needed one; with that file left
    alone, every remaining caller is UTF-8 and a switch would be surface no test exercises. Whoever
    adopts that file later adds the parameter with the caller that needs it -- and should know that
    its ASCII is load-bearing in a way that looks like a bug: a non-ASCII path collapses to '?', so
    two such paths can collide, but the digest goes into COMMITTED receipts that later runs read
    back. Moving it to UTF-8 is a migration, not a consolidation.

    THE DISPOSE IS IN A finally AND IS THE MAIN THING BEING BOUGHT. SHA256::Create() returns an
    IDisposable holding unmanaged state; two of the three folded sites already wrapped it correctly
    and the third did not. Written once, that cannot be got wrong a fourth time.

    THE FOLD IS OUTPUT-PRESERVING, MEASURED RATHER THAN ASSUMED. Each folded site was run against its
    pre-fold implementation over the same inputs -- including the empty string and a non-ASCII one --
    and every digest matched, with check-consumer-siblings' matching once lowercased, which is the
    one intended difference. The suite beside this file pins the digests themselves against published
    SHA-256 vectors rather than against this function's own output, so a later rewrite cannot pass by
    agreeing with itself.

    Pure ASCII (repo convention for .ps1). No Set-StrictMode: dot-sourcing would change the strict
    mode of the calling script.
#>

function Get-Sha256Hex {
    <#
    .SYNOPSIS
        The SHA-256 of some text or bytes, as lowercase hex, optionally cut to -Chars characters.

    .DESCRIPTION
        LOWERCASE IS THE ONLY RENDERING, deliberately, rather than a switch. Every caller wants one or
        the other and none wants both, and a case parameter would be a second thing to get wrong at a
        call site whose whole purpose is that the rendering cannot vary. It matches git's own hex and
        the .ToString('x2') the folded sites already used.

        -Chars CUTS, IT DOES NOT HASH SHORTER. A truncated SHA-256 is the standard way to get a short
        stable id and is what the short-hash caller already did by hand; what matters is that the cut
        is taken in one place, so two call sites asking for 16 characters provably get the same 16.

        AN EMPTY INPUT IS HASHED, NOT REFUSED. The SHA-256 of zero bytes is a real, well-defined
        digest (e3b0c442...), and callers reach this with a legitimately empty value -- an empty file
        on disk, a fingerprint over no rows. Refusing would turn a normal case into an exception at a
        depth where none of them handles one.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        # The text to hash, encoded as UTF-8.
        [Parameter(Mandatory = $true, ParameterSetName = 'Text')]
        [AllowEmptyString()]
        [string]$Text,

        # Raw bytes to hash, for a caller that has already done its own encoding.
        [Parameter(Mandatory = $true, ParameterSetName = 'Bytes')]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

        # Keep only the first N hex characters. 0 (the default) means the whole 64-character digest.
        # Refused above 64 by the range rather than silently returning a shorter string than asked
        # for: a caller asking for more than exists has a wrong assumption, and a name built on it
        # would be stable and wrong rather than stable and right.
        [ValidateRange(0, 64)]
        [int]$Chars = 0
    )

    # DECLARED [byte[]] AND ASSIGNED IN BRANCHES, rather than $buf = if (...) {...} else {...}. The
    # difference only shows on an empty input, and it is this repo's own list-unrolling trap
    # (docs/2040-list-object-array-trap) one type over: a statement expression UNROLLS its output, so
    # an empty byte[] coming out of an if block arrives as $null, and ComputeHash then throws
    # ArgumentNullException instead of hashing zero bytes. The folded call sites did NOT have this --
    # each assigned its buffer directly, which does not unroll -- so it is a trap this consolidation
    # introduced and its own suite caught (case 2), not a defect inherited from them.
    [byte[]]$buf = @()
    if ($PSCmdlet.ParameterSetName -eq 'Text') {
        $buf = [System.Text.Encoding]::UTF8.GetBytes($Text)
    } else {
        $buf = $Bytes
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        # $buf is typed [byte[]] above, which is what keeps this unambiguous: ComputeHash is
        # overloaded on byte[] and Stream, and an UNTYPED empty array picks neither -- PowerShell
        # throws 'Multiple ambiguous overloads found for "ComputeHash"'. The declaration does that
        # work, so no cast is needed here.
        $digest = $sha.ComputeHash($buf)
    } finally {
        $sha.Dispose()
    }

    $hex = -join ($digest | ForEach-Object { $_.ToString('x2') })
    if ($Chars -gt 0) { return $hex.Substring(0, $Chars) }
    return $hex
}
