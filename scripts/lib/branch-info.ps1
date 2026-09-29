<#
.SYNOPSIS
    Shared branch conventions for the workflow scripts (single source of truth).

.DESCRIPTION
    Dot-source this file from a script in scripts/release/:

        . (Join-Path $PSScriptRoot '..\lib\branch-info.ps1')

    Supplies Get-BranchPrefix, Get-BranchInfo and Get-BranchTypes. The prefix table determines both
    the GitHub label of the PR and the changelog entry type, and follows the standard GitHub labels:
    Enhancement -> label 'enhancement', Bug -> 'bug', Documentation -> 'documentation'.
    Changing the table? Do it here too -- and nowhere else: every script reads this one table.

    The branch types (Feat/Fix/Docs/Chore) have their single source here. release-lib.ps1 reads
    them via Get-BranchTypes for the release-notes grouping, so the list does not drift across two
    places (previously release-lib.ps1 duplicated the same types as $catOrder).

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script
    and could break loose code there.
#>

# The canonical branch types, in the order they appear in the release notes. Single source: every
# Type value in the table below is a member of this list, and release-lib.ps1 reads it via
# Get-BranchTypes. Adding a type? Do it here -- and nowhere else.
$script:BranchTypeOrder = @('Feat', 'Fix', 'Docs', 'Chore')

# prefix -> GitHub label (PR) + branch type (changelog entry).
# Note: a release does NOT run via a branch/PR (cut-release.ps1 commits directly to main),
# so there is deliberately no 'release' prefix here.
#
# AND NO 'chore' PREFIX EITHER, SINCE AUGUST 7, 2026 (Dave). There are three branch prefixes -- feat,
# fix, docs -- because chore is not something a branch does: it is the name for work that lands
# DIRECTLY ON main under one of the named exceptions. The commit log agrees emphatically: 15 of the
# last 30 first-parent commits are 'chore:' and every one of them is a direct commit (the fold, and
# the changelog re-sort Dave authorised the same day). That measurement is kept in the past tense on
# purpose: since August 10, 2026 the fold commit is typed 'fold:', so the count cannot be reproduced
# from today's log -- which strengthens the point rather than weakening it. Nothing produces a 'chore:'
# subject any more, and the type survives only as an entry TYPE below.
#
# THE RULE ALWAYS HELD; THE TOOLING NEVER SAID SO. Measured when it was written down: 'chore/' had been
# used as a branch prefix 12 times, against 70 docs/, 58 fix/ and 51 feat/. Dave's answer on seeing that
# count was that all twelve were wrong at the time too -- he had simply never noticed. So this is not a
# rule changing, it is a rule that existed only in someone's head finally being enforced, and the twelve
# are what a silently unenforced rule costs.
#
# 'Chore' STAYS A TYPE below, and that is the whole nuance. Entries already in CHANGELOG.md and in
# every consumer's tree carry it, and Resolve-EntryType validates against that list -- dropping it
# would make those entries declare a type this repo "does not produce" and fail their own gate.
# Recognise both, write one: no branch produces Chore any more, and every reader still knows it. It is
# also still the fallback for an unknown prefix, which is exactly what it now means -- the name for work
# that is neither a feature, a fix, nor documentation.
#
# TEST-BranchName REFUSES IT OUTRIGHT, rather than the row merely going missing. Removing the row alone
# would demote 'chore/' to an unknown prefix -- soft warn, proceed -- and a soft warn is what let it
# through twelve times. THIS FILE IS REPO-OWNED and does not travel into the plugin: every consumer has
# their own copy with their own table, so refusing it here states our rule without touching a consumer
# who legitimately runs chore/ branches of their own.
$script:BranchPrefixTable = @{
    feat  = @{ Label = 'enhancement';   Type = 'Feat' }
    fix   = @{ Label = 'bug';           Type = 'Fix' }
    docs  = @{ Label = 'documentation'; Type = 'Docs' }
}

function Get-BranchTypes {
    # The canonical branch types in release-notes order (SSOT for release-lib.ps1).
    return $script:BranchTypeOrder
}

function Get-BranchPrefix {
    param([Parameter(Mandatory = $true)][string]$Branch)
    # 'feat/name' -> 'feat'; without a slash, the part before the first hyphen applies
    if ($Branch -match '/') { return ($Branch -split '/')[0] }
    return ($Branch -split '-')[0]
}

function Get-BranchInfo {
    param([Parameter(Mandatory = $true)][string]$Branch)
    $prefix = Get-BranchPrefix -Branch $Branch
    $known  = $script:BranchPrefixTable.ContainsKey($prefix)
    [pscustomobject]@{
        Branch   = $Branch
        Prefix   = $prefix
        IsKnown  = $known
        Label    = $(if ($known) { $script:BranchPrefixTable[$prefix].Label } else { $null })
        Type     = $(if ($known) { $script:BranchPrefixTable[$prefix].Type } else { $null })
        # The same name is used for the changelog entry file <SafeName>.md in the repo root.
        SafeName = $Branch -replace '/', '-'
    }
}

function Test-BranchName {
    <#
        Additive SSOT helper (alongside Get-BranchInfo) for scripts that need to VALIDATE a branch
        name before using it (e.g. new-branch.ps1), instead of repeating the hard-reject rules
        inline. Does not touch Get-BranchInfo/Get-BranchTypes/the prefix table.

        Hard rejects (IsValid = $false, Reason filled in):
          - empty/whitespace-only name
          - name equal to 'main'
          - name starting with the prefix 'chore' -- chore work goes directly on the trunk, so a chore
            BRANCH is a contradiction. Anchored to the prefix, unlike 'final' below: a branch may well be
            ABOUT chores.
          - name contains the substring 'final' (case-insensitive, so also 'finalize'/'refinalization' --
            deliberately broad; see below)
          - name contains a character outside [A-Za-z0-9._/-], or does not start with a letter or a
            digit. A SHELL rule, not a taste rule: this workflow prints the branch name into paste-ready
            commands and quoting does not make a metacharacter safe (issue #1594; see the block at the
            end of this function for the measurement and for why the print sites are guarded separately)

        WHY 'final' IS REFUSED, IN DAVE'S OWN WORDS (August 7, 2026): "je weet nooit zeker of iets echt
        final is" -- you can never be certain something really is final. A branch named for being the last
        word on something is a prediction, and the prediction is wrong often enough that the name outlives
        its own truth: the next round has to be called 'final-2' or 'really-final', which is the shape the
        rule exists to prevent. **Use a version suffix instead** -- 'fix/template-newline-v2' -- because a
        number makes no claim about being the last one.

        The rule is Dave's, recorded here rather than only in a memory note because this repo's convention
        is that a lesson lives in the doc closest to what it governs. It was attributed to Derek in this
        docstring until the day the reasoning was actually asked for, which is how a rule ends up looking
        like a habit somebody picked up.

        AND THE OPPOSITE RULE ONCE EXISTED, WHICH IS WORTH KNOWING BEFORE ANYONE "RESTORES" IT. A written
        rule used to forbid exactly that '-v2' suffix, because the fold looked an entry file up by the exact
        branch name ('feat-x.md') and a suffix broke both the match and the cleanup that followed it. The
        branch/ split (August 6, 2026) retired it: the fold reads the branch out of the document rather than
        guessing it from a filename, so a suffix costs nothing. Nothing here rejects '-v2', deliberately.

        An unknown prefix is NOT a hard reject (IsValid stays $true); the caller reads IsKnown and
        decides for itself whether/how a soft warning is needed, consistent with
        new-branch/open-pr which also fall back (Chore/'question') on an unknown prefix
        instead of blocking.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        return [pscustomobject]@{ IsValid = $false; Reason = "Branch name must not be empty."; IsKnown = $false }
    }
    if ($Branch -eq 'main') {
        return [pscustomobject]@{ IsValid = $false; Reason = "Branch name must not be 'main'."; IsKnown = $false }
    }
    # 'chore/' IS NOT A BRANCH (Dave, August 7, 2026). Chore is the name for work that lands directly on
    # main under one of the named exceptions -- the fold commit, the release commit -- so a chore BRANCH is
    # a contradiction. Anchored to the prefix rather than matched anywhere in the name, unlike 'final':
    # 'chore' is a perfectly good word for a branch to be about ('docs/explain-the-chore-commits'), and it
    # is only the prefix position that makes a claim.
    if ($Branch -match '^chore(/|$)') {
        return [pscustomobject]@{
            IsValid = $false
            Reason  = "'chore' is not a branch prefix -- chore work goes directly on the trunk under one of the named exceptions (the fold commit, the release commit). Use feat/, fix/ or docs/, or make the commit on the trunk if it genuinely is a chore."
            IsKnown = $false
        }
    }
    if ($Branch -match 'final') {
        # THE REFUSAL NAMES THE REMEDY, which this one did not. A gate that says only "not that" leaves the
        # next person guessing, and the guess for a rejected 'final' is 'finished' or 'done' -- the same
        # claim in a different word. '-v2' is the answer Dave gave when asked, and it is one word longer.
        return [pscustomobject]@{
            IsValid = $false
            Reason  = "Branch name must not contain the token 'final' -- you can never be sure something really is final, and the next round then has to be called 'final-2'. Use a version suffix instead, e.g. 'fix/template-newline-v2'."
            IsKnown = $false
        }
    }

    # THE CHARACTER SET, AND IT IS A SHELL RULE RATHER THAN A TASTE RULE (issue #1594, September 8, 2026).
    # git's own ref rules reject ASCII control characters and the space and admit everything else, so
    # `fix/evil;touch`, `fix/evil$(touch)` and `fix/it's-fine` are all legal branch names -- measured with
    # `git check-ref-format --branch`, exit 0 for each. This workflow PRINTS the branch name into
    # paste-ready commands (ship-pr's stale-CI and fold remedies, sync-main's push and PR lines), and
    # neither single nor double quoting closes that: `$( )` runs inside double quotes in bash and in
    # PowerShell alike, and a legal apostrophe terminates single quotes. So the name is held to the
    # characters that are inert in every shell a remedy might be pasted into.
    #
    # THIS IS THE CREATION-SIDE HALF AND IT DOES NOT CLOSE THE HOLE ALONE -- deliberately. This file is
    # REPO-OWNED and per-consumer (the script contract requires the function, not its body; the config
    # blueprint carries seam VALUES, not this rule), and a branch that was cloned, fetched, or created
    # with plain `git checkout -b` never meets it. The half that travels is Get-PasteableRef in the
    # mirrored scripts\lib\ref-print-lib.ps1, which guards the print sites themselves. Both exist because
    # each is wrong to rely on alone: this one stops the workflow AUTHORING such a name -- new-branch's
    # -Name is where a session, often a model, types one -- and that one stops any name reaching a command.
    #
    # MEASURED BEFORE IT WAS ADOPTED: all 994 pull-request head refs in this repo's history match the
    # pattern, so it refuses nothing anybody here has ever wanted. The first character is pinned to a
    # letter or digit so a name cannot read as a flag; git already rejects a leading '-' (exit 128), which
    # makes that half belt-and-braces rather than load-bearing.
    if ($Branch -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$') {
        return [pscustomobject]@{
            IsValid = $false
            Reason  = "Branch name may only contain letters, digits, '.', '_', '-' and '/', and must start with a letter or a digit. This workflow prints the branch name into commands that get pasted into a shell, and a character like ';', '&', '|', '`$' or a quote is not made safe by quoting it (issue #1594). Rename it using those characters only."
            IsKnown = $false
        }
    }

    $info = Get-BranchInfo -Branch $Branch
    [pscustomobject]@{ IsValid = $true; Reason = $null; IsKnown = $info.IsKnown }
}
