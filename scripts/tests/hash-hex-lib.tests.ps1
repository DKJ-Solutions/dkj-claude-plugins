<#
.SYNOPSIS
    Tests for scripts/lib/hash-hex-lib.ps1 -- the one SHA-256-to-lowercase-hex rendering three
    files used to carry by hand.

.DESCRIPTION
    THE PROPERTY THAT WOULD BREAK SILENTLY IS THAT THE OUTPUT IS THE SAME AS WHAT THE CALLERS
    PRODUCED BEFORE. Two of the three folded call sites feed a value that has to stay stable across
    runs: Get-GateFingerprint decides whether a recorded gate pass still stands for the current
    working tree, and Get-SessionCacheFileName cuts 16 characters into a cache file name that a
    later firing looks up again. A rendering change there does not throw -- it produces a different
    valid-looking string, so every cached verdict silently misses and every gate re-runs. Nothing
    reports that; it just gets slower and quieter. So case 1 pins the digest against a KNOWN VECTOR
    rather than against this function's own output, which is the only assert here that could not be
    satisfied by a wrong implementation agreeing with itself.

    CASE 2 IS THE EMPTY INPUT, and it is a real case rather than an edge one. check-consumer-siblings
    reaches this with '' for any file it could not read (its own catch sets $text = ''), and
    Get-GateFingerprint composes a fingerprint over a possibly empty list. e3b0c442... is the
    published SHA-256 of zero bytes, so this asserts the function hashes nothing rather than
    short-circuiting to '' -- a short-circuit would make every unreadable file in a consumer checkout
    fingerprint identically, which reads as "these all agree" in exactly the check that exists to
    find disagreement.

    CASE 5 IS THE ONE THE ISSUE WAS ABOUT. #2058's argument is that a hand-copied rendering drifts,
    and the branch that folded it found that it already had: the copy in check-consumer-siblings.ps1
    rendered uppercase and disposed nothing. The assert that the output contains no uppercase is what
    keeps a later "tidy-up" from reintroducing BitConverter::ToString(), which is the exact shape the
    drift took.

    CASE 7 GUARDS THE TRUNCATION BOUND. -Chars is what makes a short name, and a caller asking for
    more characters than a SHA-256 has is a wrong assumption rather than a request to pad. The range
    refuses it at bind time, so the failure is loud and at the call site instead of a Substring
    exception from inside the lib.

    Dependency-free (no Pester), same style as the rest of the suite. No fixtures and no git: this
    lib touches no disk, no network and no repo state, which is most of why it is testable at all.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\hash-hex-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Write-Host "== hash-hex-lib ==" -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LibPath) 'hash-hex-lib.ps1 exists at its registered source path'
. $LibPath

# (1) KNOWN VECTORS, not self-agreement. 'abc' is the canonical SHA-256 test vector; the empty string
#     is the published digest of zero bytes. Asserted against the published constants so a rewrite of
#     the rendering cannot pass by agreeing with itself.
Assert-Equal 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' `
    (Get-Sha256Hex -Text 'abc') `
    "the SHA-256 of 'abc' is the published vector, in lowercase hex"

# (2) The empty input is HASHED, not short-circuited -- see the header for why '' would be the
#     damaging answer in check-consumer-siblings.
Assert-Equal 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' `
    (Get-Sha256Hex -Text '') `
    'the empty string hashes to the published digest of zero bytes rather than returning empty'

# (3) The BYTES set agrees with the TEXT set for the same content. The two parameter sets must not be
#     two implementations; a caller that has already encoded gets the same answer as one that has not.
Assert-Equal (Get-Sha256Hex -Text 'abc') `
    (Get-Sha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes('abc'))) `
    '-Bytes over UTF-8 bytes equals -Text over the same string'

# (4) An empty byte array is accepted and matches the empty string, for the same reason as (2).
Assert-Equal (Get-Sha256Hex -Text '') `
    (Get-Sha256Hex -Bytes ([byte[]]@())) `
    'an empty byte array hashes to the same digest as the empty string'

# (5) THE DRIFT #2058 WAS FILED ABOUT. The copy this replaced in check-consumer-siblings.ps1 rendered
#     uppercase via BitConverter::ToString(). This is the assert that refuses that shape coming back.
$hex = Get-Sha256Hex -Text 'Get-Sha256Hex'
Assert-True ($hex -cmatch '^[0-9a-f]{64}$') `
    'the digest is exactly 64 characters of LOWERCASE hex -- no uppercase, no separators'

# (6) The full digest is the default: no -Chars means nothing is cut.
Assert-Equal 64 (Get-Sha256Hex -Text 'anything').Length 'without -Chars the whole 64-character digest comes back'

# (7) -Chars cuts from the front and is a prefix of the full digest -- so a short id and a full one
#     never disagree about the same input.
$full  = Get-Sha256Hex -Text 'session:subject'
$short = Get-Sha256Hex -Text 'session:subject' -Chars 16
Assert-Equal 16 $short.Length '-Chars 16 returns 16 characters'
Assert-Equal $full.Substring(0, 16) $short '-Chars returns a PREFIX of the full digest, not a different hash'

# (8) -Chars 0 is the documented "no truncation" value and must not return an empty string.
Assert-Equal $full (Get-Sha256Hex -Text 'session:subject' -Chars 0) '-Chars 0 means the whole digest'

# (9) -Chars 64 is the boundary and is allowed; 65 is refused at bind time by the range, so the
#     wrong assumption fails loudly at the call site instead of as a Substring error inside the lib.
Assert-Equal $full (Get-Sha256Hex -Text 'session:subject' -Chars 64) '-Chars 64 is the boundary and returns the whole digest'
$refused = $false
try { Get-Sha256Hex -Text 'x' -Chars 65 | Out-Null } catch { $refused = $true }
Assert-True $refused '-Chars 65 is refused -- a SHA-256 has no 65th hex character to return'
$refusedNegative = $false
try { Get-Sha256Hex -Text 'x' -Chars -1 | Out-Null } catch { $refusedNegative = $true }
Assert-True $refusedNegative '-Chars -1 is refused rather than treated as "no truncation"'

# (10) Different inputs give different digests -- the floor property, and the one a stubbed
#      implementation returning a constant would fail.
Assert-True ((Get-Sha256Hex -Text 'a') -ne (Get-Sha256Hex -Text 'b')) 'different inputs produce different digests'

# (11) THE CALL SITES STILL RENDER WHAT THEY RENDERED BEFORE. Composed the way each caller composes
#      it, so a change to this lib that breaks either one fails here rather than in production, where
#      the symptom is a silent cache miss rather than an error.
Assert-Equal ('sess-1-' + (Get-Sha256Hex -Text 'subject' -Chars 16) + '.json') `
    ('sess-1-' + (Get-Sha256Hex -Text 'subject').Substring(0, 16) + '.json') `
    'the session-cache file name is the same whether the 16 chars are cut here or by the caller'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:pass) passed, $($script:fail) failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($script:pass) passed." -ForegroundColor Green
exit 0
