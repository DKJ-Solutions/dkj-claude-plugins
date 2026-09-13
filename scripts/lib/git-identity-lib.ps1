<#
.SYNOPSIS
    The identity a checkout ACTS as on the tracker, the identity it COMMITS as, and whether it can
    commit at all -- read once, for every caller that needs one of them (issue #1315, extracted for
    claim-issue.ps1; the third question added for inbound #1867).

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')

    WHY IT IS A LIB. The first three functions were written inside check-git-identity.ps1, which
    REPORTS the split identity, and they are now needed by claim-issue.ps1, which has to ACT under the
    right one. A script cannot dot-source check-git-identity.ps1 to reach them -- that file runs its
    whole comparison and `exit`s on load -- so the alternative to extracting was a second copy of
    Get-ActiveGhAccount's multi-account parse. That parse is the subtle one (see its own header), and
    a repo whose branch-prefix table carries "do it here -- and nowhere else" does not get to keep two
    of it. Test-GitCanCommit arrived as a lib for the same reason one step on: check-git-identity.ps1
    reports that state and new-branch.ps1 REFUSES on it, which is two callers on day one.

    THE FOURTH FUNCTION ANSWERS A DIFFERENT KIND OF QUESTION, and the file is no longer named by the
    pair alone. The three above are advisory reads feeding a comparison; Test-GitCanCommit is a
    blocker -- there is no useful answer to "which account" on a checkout that cannot commit under any
    of them.

    NO NETWORK, and that property is load-bearing for every caller: `gh auth status` reads the
    keyring, `git config` reads a file, and `git var` reads config plus the environment. The
    SessionStart hook behind check-git-identity.ps1 pays three local process launches and nothing
    more -- and only one of the three on a checkout that cannot commit, which is where that script
    exits first.

    Dot-sources native-capture-lib.ps1 itself, guarded -- a mirror built before that lib existed
    degrades to a caller that has already loaded it rather than throwing on load.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script and could
    break loose code there (same reasoning as branch-info.ps1).

    Pure ASCII, per this repo's script-layer convention.
#>

$captureLib = Join-Path $PSScriptRoot 'native-capture-lib.ps1'
if (Test-Path -LiteralPath $captureLib -PathType Leaf) { . $captureLib }

# THE ONE EXIT CODE THAT MEANS "THIS CHECKOUT CANNOT COMMIT" (issue #1920). git reports an unknown
# author identity through die(), which exits 128; every other non-zero exit from the probe is a
# measurement that did not happen, and Test-GitCanCommit's own contract says those must not refuse.
# Named rather than typed inline because two readers have to agree on it -- this function, and the
# fixture sanity assert in new-branch.tests.ps1 that pins git's side of the number.
$script:GitAuthorIdentityUnknownExitCode = 128

function Test-GitHubLoginShape {
    <#
        GitHub's own username rule: 1-39 characters, alphanumeric or single hyphens, and it may
        neither begin nor end with a hyphen. This is the whole false-positive guard -- a value that
        fails it cannot be an account, so a difference from the active login proves nothing and is
        not reported. The lookahead is what forbids a double hyphen and a trailing one in one pass.
    #>
    param([string]$Value)
    if (-not $Value) { return $false }
    return ($Value -match '^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$')
}

function Get-ActiveGhAccount {
    <#
        The account `gh` currently acts as, read from `gh auth status` -- which reports it from the
        keyring, so this makes no network call. Returns '' when gh is absent, logged out, or its
        output does not name an account.

        WHY IT PARSES TEXT. `gh auth status` has no --json, and the alternative that does
        (`gh api user --jq .login`) is a network round-trip at every session start. The shape parsed
        is the pair of lines gh has printed since v2:

            github.com
              * Logged in to github.com account <name> (keyring)
              - Active account: true

        MULTIPLE ACCOUNTS CAN BE LOGGED IN, and only one is active -- `@me` binds to that one. So the
        account name is remembered as a candidate and only committed to when its own 'Active account:
        true' line follows. A single logged-in account prints that line too, so the common case needs
        no special handling. With no active line anywhere the answer is the last name seen, which is
        what a pre-multi-account gh printed.
    #>
    $res = $null
    try {
        $res = Invoke-NativeCapture -FilePath 'gh' -Arguments @('auth', 'status') -Utf8
    } catch {
        return ''
    }
    if (-not $res) { return '' }

    $candidate = ''
    $active = ''
    foreach ($line in @($res.Output)) {
        $text = [string]$line
        $m = [regex]::Match($text, 'account\s+(\S+)')
        if ($m.Success) { $candidate = $m.Groups[1].Value }
        if ($text -match 'Active account:\s*true' -and $candidate) { $active = $candidate }
    }
    if ($active) { return $active }
    return $candidate
}

function Get-GitUserName {
    <#
        `git config user.name` for the checkout, read with -C so the answer is the repo's own rather
        than whatever directory the hook happened to start in. An empty repo root falls back to the
        plain call, which then reads the global config -- the right answer for a session with no
        checkout.
    #>
    param([string]$RepoRoot)
    $gitArgs = @()
    if ($RepoRoot) { $gitArgs += @('-C', $RepoRoot) }
    $gitArgs += @('config', 'user.name')
    $res = $null
    try {
        $res = Invoke-NativeCapture -FilePath 'git' -Arguments $gitArgs -Utf8 -DiscardStderr
    } catch {
        return ''
    }
    if (-not $res -or $res.ExitCode -ne 0) { return '' }
    $value = (@($res.Output) | Where-Object { $_ -and ([string]$_).Trim() } | Select-Object -First 1)
    if (-not $value) { return '' }
    return ([string]$value).Trim()
}

function Test-GitCanCommit {
    <#
        CAN THIS CHECKOUT COMMIT AT ALL? (inbound #1867) -- a different question from the two reads
        above, and the only one of the three whose answer is a blocker rather than an advisory.

        WHY `git var GIT_AUTHOR_IDENT` AND NOT `git config user.name`. The three functions above ask
        who this checkout ACTS and COMMITS as, for a comparison. This asks whether git will accept a
        commit at all, and user.name is the wrong reading for it in BOTH directions:

          - user.name set, user.email unset -> a name is there to compare, and git still refuses.
          - user.name unset, but the hostname carries a domain part or GIT_AUTHOR_NAME /
            GIT_AUTHOR_EMAIL are in the environment -> git commits fine, so there is nothing to say.

        `git var GIT_AUTHOR_IDENT` collapses both into the question actually being asked. It applies
        git's own resolution order -- environment, then local, global and system config, then an
        auto-detection that is NOT only the username@hostname guess -- and exits 128 with "Author
        identity unknown" exactly when a commit would. Measured September 11, 2026 on DAVE-KOK-BWJ:
        exit 0 with the ident on a healthy checkout, and a `git commit` refused with the identical
        message in the state the probe exits 128 on.

        THE SUPPRESSION HALF OF THAT MEASUREMENT WAS WRONG, and it is corrected here rather than
        deleted because it is the trap (#1888). It read "exit 128 under GIT_CONFIG_GLOBAL=/dev/null
        GIT_CONFIG_NOSYSTEM=1", and on that same machine, re-measured September 12, 2026 on git
        2.55.0.windows.5, that state exits 0: config genuinely has nothing
        (`git config --show-origin --get user.email` exits 1) and Git for Windows still names an
        author, because its last source is the OS account rather than a config file, and what it
        produces is a real display name and a real address instead of the username@hostname guess git
        then refuses. Emptying every config scope therefore does NOT produce a checkout that cannot
        commit; `user.useConfigOnly = true` in a readable config file is what disables the fallback.
        This function is unaffected either way -- it reads whatever git resolves -- but anything
        trying to CONSTRUCT the refusing state needs that key, and new-branch.tests.ps1's fixture is
        where it is constructed.

        NO NETWORK, like everything else in this lib: git reads config files and the environment. That
        property is load-bearing -- this is a third local process launch at every session start, on top
        of the two the identity reads above already cost, and nothing more. On the broken machine it is
        the ONLY one: check-git-identity.ps1 runs this probe before either read and exits on it.

        UNKNOWN IS TREATED AS CAN-COMMIT, deliberately. git absent, or a tree that is not a checkout,
        returns $true: this function's one job is to refuse a state it has PROVEN broken, and a
        refusal built on a failure to measure would wedge a run for the wrong reason. Every caller
        already fails honestly on a git that is not there.

        AND THAT CONTRACT WAS STATED HERE WITHOUT BEING IMPLEMENTED (issue #1920). The body read
        `$res.ExitCode -eq 0`, so EVERY non-zero exit refused -- not only git's own "Author identity
        unknown", but a probe that was killed, timed out, or came back non-zero for any reason at all.
        The paragraph above says in so many words that such a refusal must not happen, and one line
        further down it did. Only the throw path and a $null result were ever honoured.

        WHY THAT IS WORTH A NARROWING RATHER THAN A COMMENT, and where it bites. This probe runs on
        EVERY new-branch.ps1 run, before the checkout, and its refusal exits 1 with nothing created --
        no branch, no document, nothing on origin. Under the parallel test gate new-branch.tests.ps1
        invokes that script some forty times per run, sixteen lanes deep, and #1915 measured on this
        same suite, on the same day, that a git child in a fixture really does transiently fail under
        that load. A probe that reads any such failure as "this checkout cannot commit" turns one
        unlucky git into a red gate, and the red says nothing about the tree.

        128 IS THE DISCRIMINATOR, AND IT IS GIT'S OWN. `git var GIT_AUTHOR_IDENT` reports an unknown
        author identity through die(), which exits 128 -- measured, and pinned by this suite rather
        than asserted here: new-branch.tests.ps1's (y) fixture sanity assert runs the probe against a
        deliberately identity-less repo and requires exactly 128 before any of its other asserts are
        allowed to mean anything. So a refusal is gated on 128, and every other non-zero exit is the
        "unknown" the paragraph above promises to let through.

        WHAT THE NARROWING GIVES UP, stated because it is not nothing: `git -C <path that is not a
        repository>` also exits 128, so that state still refuses under the identity message. It did
        before this change too, and it is not made worse -- by the time any caller reaches here the
        root has already been resolved and judged (new-branch.ps1's own #1913 block does exactly
        that), so the case is unreachable from the callers that exist. Matching on git's message text
        instead would trade an exact exit code for a locale-dependent string.

        Returns $true when a commit would be accepted, $false only on a measured refusal.
    #>
    param([string]$RepoRoot)
    $gitArgs = @()
    if ($RepoRoot) { $gitArgs += @('-C', $RepoRoot) }
    $gitArgs += @('var', 'GIT_AUTHOR_IDENT')
    $res = $null
    try {
        $res = Invoke-NativeCapture -FilePath 'git' -Arguments $gitArgs -Utf8 -DiscardStderr
    } catch {
        return $true
    }
    if (-not $res) { return $true }
    # A bounded call that expired measured nothing -- and its substituted exit code is not git's, so it
    # must be read before the number is. Property-guarded: a caller holding an older capture lib gets
    # an object without the field rather than a strict-mode throw.
    if ($res.PSObject.Properties['TimedOut'] -and $res.TimedOut) { return $true }
    if ($res.ExitCode -eq 0) { return $true }
    # THE ONLY REFUSAL. Anything else is a probe that did not answer the question, which is the
    # "unknown" case above -- see the docstring for why this is an exit code and not a message match.
    return ($res.ExitCode -ne $script:GitAuthorIdentityUnknownExitCode)
}
