<#
.SYNOPSIS
    Tests for the rule that a .NET exception message never reaches a console unstripped (issue #2271).

.DESCRIPTION
    THE CLASS, AND WHY IT IS ONE. The foreign-text guards (Format-SafeToken, Format-SafePathToken,
    Format-SafeProseToken) exist because a value somebody else authored must not be able to forge a
    line, repaint a terminal, or plant a marker a SessionStart hook COUNTS -- the reasoning is in
    check-report-lib.ps1's own header, from inbound #309. Every guarded site so far guards a value the
    script itself read: a path, an id, a line of a consumer's markdown.

    An exception message reads like OURS and is not. .NET composes the sentence, so most of the
    characters are its own -- and it INTERPOLATES the offending input into that sentence. #2271
    measured 34 console sites in scripts/** printing $_.Exception.Message with no strip at all, and
    the dominant shape is the `. $repoConfig` dot-source catch: a consuming repo's own seam file,
    loaded by shared scripts that run in that consumer's checkout.

    THREE MEASUREMENTS EARNED THE SWEEP, and they are asserted below rather than described, because
    the whole argument for guarding all 34 rests on them being true:

      1. A dot-source of a file that does not PARSE produces a message carrying the offending source
         line VERBATIM and REAL NEWLINES. That is the #309 line-forging vector at its widest, reached
         by the most ordinary failure there is -- a consumer typos their own repo-config.ps1.
      2. A dot-source of a file that THROWS produces a message that is entirely the consumer's text,
         with zero .NET characters in it.
      3. A file API given a foreign path interpolates that path, brackets and all, into its own
         sentence -- so a value already guarded in the first half of a line comes back unguarded in
         the second half via the exception thrown on it.

    THE PRECEDENT WAS ALREADY IN THE TREE and #2271's own grep could not see it: check-claude-home.ps1
    prints Get-InstallRecord's parse error through Format-SafeProseToken, and that field is assigned
    `$_.Exception.Message` in repo-root-lib.ps1 -- two files away, so a same-line grep reports the class
    as having no guarded site anywhere. The class was decided once, correctly, and never generalised.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')

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

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) "exception-message-guard-$PID-$([guid]::NewGuid().ToString('n'))"

# The console cmdlets this repo prints findings through. Kept here as one list because both the scan
# below and the #2271 measurement in the issue are about the same set.
$ConsoleCmdlets = 'Write-(Host|Warning|Info|Failure|Skip|Error|Output)'

try {
    Write-Host "== exception-message-guard.tests: a foreign exception message never reaches a console raw ==" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    # --- 1. The measurements that earned the sweep -------------------------------------------------
    #     These assert a property of PowerShell/.NET, not of our code, and that is deliberate: if a
    #     future runtime stops embedding the offending input, the argument for guarding all 34 sites
    #     weakens and somebody should be told rather than left with a sweep nobody can re-derive.
    Write-Host "what an exception message actually carries" -ForegroundColor Cyan

    # 1a. A consumer's seam file that does not PARSE.
    $syntaxCfg = Join-Path $Fixture 'cfg-syntax.ps1'
    Set-Content -LiteralPath $syntaxCfg -Encoding ASCII -Value @(
        'function Get-Thing { return @("[ERROR] forged marker"'
    )
    $syntaxMsg = ''
    try { . $syntaxCfg } catch { $syntaxMsg = [string]$_.Exception.Message }
    Assert-True ($syntaxMsg -match "\r|\n") 'a parse failure''s message carries REAL NEWLINES'
    Assert-True ($syntaxMsg -match '\[ERROR\]') 'and the consumer''s own source line verbatim, marker and all'

    # 1b. A consumer's seam file that THROWS -- the message is entirely theirs.
    $throwCfg = Join-Path $Fixture 'cfg-throw.ps1'
    Set-Content -LiteralPath $throwCfg -Encoding ASCII -Value 'throw "consumer text: [ERROR] forged"'
    $throwMsg = ''
    try { . $throwCfg } catch { $throwMsg = [string]$_.Exception.Message }
    Assert-Equal 'consumer text: [ERROR] forged' $throwMsg 'a throw''s message is the consumer''s text and nothing else'

    # 1c. A file API given a foreign path puts that path back into its own sentence. This is the
    #     sync-main.ps1 shape #2271 opened on: $rel guarded in the first half of the line, and the
    #     exception thrown ON that same path carrying it unguarded into the second half.
    $badPath = Join-Path $Fixture 'no\such\dir\[ERROR] x.md'
    $pathMsg = ''
    try { [System.IO.File]::WriteAllText($badPath, 'y') } catch { $pathMsg = [string]$_.Exception.Message }
    Assert-True ($pathMsg -match '\[ERROR\]') 'a file API interpolates the offending path, brackets and all, into its own sentence'

    # --- 2. The guard neutralises all three ---------------------------------------------------------
    #     Format-SafeProseToken is the sibling for a SENTENCE somebody else wrote (#1419): control
    #     characters out, brackets substituted so no marker can FORM, and a note when it changed
    #     anything. That last property is what answers the "it re-spaces text a reader may be
    #     comparing against a live error" objection #2271 raised against sweeping: the line says so.
    Write-Host "Format-SafeProseToken -- what survives it" -ForegroundColor Cyan
    foreach ($case in @(
        @{ Label = 'parse failure'; Value = $syntaxMsg },
        @{ Label = 'consumer throw'; Value = $throwMsg },
        @{ Label = 'foreign path in a file API'; Value = $pathMsg }
    )) {
        $safe = Format-SafeProseToken -Value $case.Value
        Assert-True (-not ($safe -match "\r|\n")) "$($case.Label): no newline survives the guard"
        Assert-True (-not ($safe -match '\[|\]')) "$($case.Label): no square bracket survives, so no marker can form"
    }
    # AND THE ANNOUNCEMENT IS NARROWER THAN IT LOOKS -- asserted in both directions, because #2271
    # weighed "it re-spaces text a reader may be comparing against a live error" as a cost of
    # sweeping, and the tempting answer ("the line says so") is only half true.
    #
    # The '\s+' collapse runs FIRST and '\s' matches a newline, so a multi-line parse error is
    # flattened to one line BEFORE $hadControl is measured -- and it is therefore flattened SILENTLY.
    # That is the function's own documented decision, not a defect: a tab collapsed to a space is
    # cosmetic and must not trip a note about characters that cannot be printed. The consequence is
    # worth writing down rather than discovering: the security property (no newline survives) holds
    # unconditionally, while the note fires only for a control character that is not whitespace.
    $flattened = Format-SafeProseToken -Value $syntaxMsg
    Assert-True (-not ($flattened -match 'shown sanitized')) 'a newline is collapsed SILENTLY -- the note is not a promise that every change is announced'
    Assert-True ($flattened.Length -gt 0) 'and the flattened message is still there to read'

    # A non-whitespace control character is what the note exists for -- a bidi override is the class
    # most worth announcing, and the one an ordinal comparison had to be used to notice at all.
    $bidi = Format-SafeProseToken -Value "consumer text: start$([char]0x202E)end"
    Assert-True ($bidi -match 'shown sanitized') 'a control character that is NOT whitespace does say so on the line'

    # --- 3. THE CLASS REGRESSION SCAN -------------------------------------------------------------
    #     The 34 sites are not the rule; the rule is that there are none. A per-site test would pass
    #     forever while the 35th is written, which is exactly how this class got to 34 in the first
    #     place -- so the assertion is over the tree.
    #
    #     SAME-LINE, LIKE #2271'S OWN GREP, AND THE BOUND IS STATED RATHER THAN HIDDEN. A message
    #     captured into a variable and printed elsewhere (repo-root-lib.ps1 -> check-claude-home.ps1)
    #     is invisible here, which is precisely how the existing guarded precedent went uncounted.
    #     This scan therefore proves that no site prints one INLINE unguarded; it does not prove the
    #     indirect route is clean, and it must not be read as doing so.
    #
    #     BOTH ROOTS ARE SCANNED, AND plugins/ IS NOT REDUNDANT WITH scripts/. Most of plugins/ is a
    #     byte-identical mirror the drift lint already pins, so scanning it changes nothing there --
    #     but the HOOKS (plugins/*/hooks/*.ps1) and the dkj-policy-bwj templates are plugin-NATIVE,
    #     with no counterpart under scripts/ at all. A scripts/-only scan is exactly how #2271's own
    #     measurement reported 34 and missed the eight hook catch-alls, which are the highest-severity
    #     members of the class: their output IS what a SessionStart hook forwards into session context.
    Write-Host "the tree -- no console site prints an exception message raw" -ForegroundColor Cyan
    $scriptFiles = @(
        foreach ($root in @('scripts', 'plugins')) {
            Get-ChildItem -LiteralPath (Join-Path $RepoRoot $root) -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\tests\\' }
        }
    )
    Assert-True ($scriptFiles.Count -gt 0) 'the scan found scripts to read (a scan over nothing must not read as a pass)'

    $unguarded = @()
    foreach ($f in $scriptFiles) {
        $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -notmatch 'Exception\.Message') { continue }
            if ($line -notmatch $ConsoleCmdlets) { continue }
            # THREE GUARD FAMILIES ARE ACCEPTED, because three kinds of file reach a console here and
            # they cannot all reach the same helper:
            #   - Format-Safe*Token / Get-Display*  -- check-report-lib's, for anything that can load it.
            #   - Format-ForConsole                 -- the dkj-policy-bwj templates' own, hand-typed
            #     because adopt-dkj-policy-bwj copies them into a consumer as .github/scripts/*.ps1
            #     where none of this repo's libs exist. It is STRICTER on control and format characters
            #     (six categories, a code point at a time) and does not substitute brackets, which is
            #     right there: that output is a GitHub Actions log, not session context a hook counts.
            #   - an INLINE -replace chain          -- the eight hook catch-alls, where a guard CALL is
            #     itself the hazard (hook-check-lib is dot-sourced inside the try, so "the lib did not
            #     load" is one of the failures that lands in the catch).
            if ($line -match 'Format-Safe(Prose|Path)?Token|Get-Display(Ref|Path|Name)|Format-ForConsole') { continue }
            $rel = $f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
            $unguarded += "$rel`:$($i + 1)"
        }
    }
    Assert-Equal 0 $unguarded.Count "no console site prints an exception message unstripped$(if ($unguarded.Count) { " -- found: $($unguarded -join ', ')" })"

    # --- 4. Every caller can actually CALL it ------------------------------------------------------
    #     Three of the files swept by #2271 did not have check-report-lib.ps1 in scope and had the
    #     dot-source added with the guard. Nothing else would catch its removal: PowerShell resolves
    #     a missing function at RUN time, and these are catch blocks -- so the failure would surface
    #     only on the day a consumer's seam file is already broken, which is the worst possible day
    #     for the reporting line to be the thing that throws.
    Write-Host "every guarding script can reach the guard" -ForegroundColor Cyan
    $missingLoad = @()
    foreach ($f in $scriptFiles) {
        $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        # CALLS ONLY, NOT MENTIONS -- and BOTH comment forms have to go, which took two passes to get
        # right. Line comments first: the eight hook catch-alls name this function in prose precisely
        # to say they do NOT call it, and counting that as a call reports every one of them as missing
        # a load they must not have. Then BLOCK comments: hook-check-lib.ps1 names it inside a `<# #>`
        # docstring, which survives a line-comment strip and read as a call for exactly as long as the
        # strip was one pass.
        $code = $text -replace '(?s)<#.*?#>', ''
        $code = (@(($code -split "`r?`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
        if ($code -notmatch 'Format-SafeProseToken\s') { continue }
        # The lib itself defines it; a file that dot-sources it, or one that reaches it through
        # check-report-lib's own siblings, is fine.
        if ($f.Name -eq 'check-report-lib.ps1') { continue }
        # AND THE LOAD IS LOOKED FOR IN CODE, NOT IN PROSE -- the same distinction as above and the
        # reason it is made twice. This check first matched any MENTION of the lib's filename, which
        # let native-capture-lib.ps1 pass with two comment references and no dot-source at all: the
        # guard call was added to it, the assertion went green, and the call would have thrown the
        # first time that catch fired. A file that merely names the lib in a comment has not loaded it.
        if ($code -match '\.\s*\(Join-Path[^)]*check-report-lib\.ps1') { continue }
        $rel = $f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
        $missingLoad += $rel
    }
    Assert-Equal 0 $missingLoad.Count "every script calling Format-SafeProseToken dot-sources check-report-lib.ps1$(if ($missingLoad.Count) { " -- missing in: $($missingLoad -join ', ')" })"

    # --- 5. The hook catch-alls, pinned by name ----------------------------------------------------
    #     The scan above cannot see these, and that is a property of the repair rather than a gap in
    #     it: the hooks strip into a variable on one line and print it on the next, so neither line
    #     carries both an exception message and a console cmdlet. The scan still guards the REGRESSION
    #     -- reverting one to the raw one-liner puts both back on a single line and trips it -- but
    #     nothing would notice a hook quietly losing its strip while keeping the two-line shape. These
    #     are the sites whose output a SessionStart hook forwards into session context, so they are
    #     the ones worth naming rather than inferring.
    Write-Host "the hook catch-alls strip before they print" -ForegroundColor Cyan
    $hookFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'plugins') -Recurse -Filter '*-sessioncheck.ps1' -File -ErrorAction SilentlyContinue)
    Assert-True ($hookFiles.Count -ge 8) "the session-start hooks were found to check ($($hookFiles.Count) found)"
    $rawHooks = @()
    foreach ($h in $hookFiles) {
        $text = Get-Content -LiteralPath $h.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        if ($text -notmatch 'Exception\.Message') { continue }
        # The three passes, in the order the lib uses them. Whitespace FIRST is the load-bearing one:
        # it is what makes a newline unable to forge a line, and it is the pass most likely to be
        # dropped as cosmetic by a later editor who reads the control-character strip as the whole job.
        # Matched LITERALLY rather than by regex: the thing being looked for is itself a chain of
        # regex literals, and escaping a pattern that hunts for backslashes is how a check ends up
        # quietly matching nothing and passing forever.
        $hasWhitespace = $text.Contains("-replace '\s+', ' '")
        $hasControl    = $text.Contains("-replace '\p{C}', ''")
        $hasBrackets   = $text.Contains("-replace '\[', '('")
        if (-not ($hasWhitespace -and $hasControl -and $hasBrackets)) { $rawHooks += $h.Name }
    }
    Assert-Equal 0 $rawHooks.Count "every session-start hook that prints an exception message runs all three passes$(if ($rawHooks.Count) { " -- incomplete in: $($rawHooks -join ', ')" })"
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
