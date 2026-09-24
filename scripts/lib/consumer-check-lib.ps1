<#
.SYNOPSIS
    The two things every consumer-facing lint check opens with, in one definition: which tree am I
    operating on (Resolve-CheckRepoRoot), and which always-on documents may I read (Get-CheckProseCorpus).
    Issue #1422.

.DESCRIPTION
    WHY THIS EXISTS, AND IT IS NOT TIDINESS. Five entry points -- check-retired-doc-name.ps1,
    check-supremacy-declaration.ps1, check-branch-entry.ps1, check-git-identity.ps1 and
    check-unfolded-entry.ps1 -- opened with the same preamble in the same order, and NEAR-COPIES ARE WHAT
    DRIFT LOOKS LIKE BEFORE IT IS VISIBLE. It had already drifted when this was written: four carried the
    one-line resolution and the fifth (check-git-identity) a try/catch-wrapped variant, so on a tree that
    is not a checkout one of the five answered and four died on `.Trim()` against $null. Nothing said
    which behaviour was intended, because both were written as though obviously right.

    THE FIVE ARE FOUR SINCE #1421, AND THE COUNT IS LEFT AS IT WAS ON PURPOSE. The first two named above
    were folded into one check-consumer-prose.ps1 days after this lib landed, so the callers today are
    check-consumer-prose.ps1, check-branch-entry.ps1, check-git-identity.ps1 and check-unfolded-entry.ps1.
    The paragraph above is the MEASUREMENT that produced this lib and it is true of the tree it was taken
    in -- rewriting it to four would make the drift it documents unfindable. Read it as evidence, and
    read this paragraph for the current inventory, exactly as seam-lib.ps1 asks its own census to be read.

    THE ROOT RESOLUTION IS A SEMANTIC DECISION -- which tree does this script judge -- and this repo
    already has the rule for those: the pair that must not drift gets one source (#309, and
    Get-SeamPaths / Get-OrchestratorNote / Format-SafeToken all exist under it). Five copies of a
    semantic decision is five places to fix on the day it changes.

    WHAT IS DELIBERATELY *NOT* IN HERE, so the next reader does not add it:

      * THE repo-config.ps1 LOAD. It cannot be moved, and the reason is PowerShell scope rather than
        judgement: `. $file` inside a function defines into the FUNCTION's scope, so a helper that
        dot-sourced a consumer's repo-config would load its seam functions and then throw them away when
        it returned. The `. Import-Something` idiom (invoking a function dot-sourced into the caller's
        scope) does work and was rejected as too subtle for a line that every gate depends on. What is
        left to share would be the Test-Path and the warning string, which is not worth an indirection.
      * THE MARKETPLACE SKIP. It has a name already -- Test-IsWorkflowSourceRepo in seam-lib.ps1 -- and
        the two prose checks now call it instead of re-testing the file inline. Adding a second spelling
        here would be the seventh, against that function's own written census of which sites legitimately
        ask the broad "does this repo publish plugins" question and which mean this one.
      * THE LIB DOT-SOURCES. One `$PSScriptRoot`-relative line each, and they differ per check because
        the checks need different libs. There is nothing shared to name.

    DEPENDENCY-FREE, like plugin-tree-lib and source-repo-guard-lib and for the same reason: it is
    dot-sourced on the first line that runs, before any script has resolved anything, so it can rely on
    nothing being loaded yet. Get-CheckProseCorpus is the one exception and it loads its own dependency,
    guarded, from its own directory.

    IT TRAVELS WITH THE MIRROR. All five callers are mirrored into the workflow plugin, so a lib that
    stayed behind in this tree would leave every consumer's copy dot-sourcing a file they do not have.
    Registered in shared-scripts-lib.ps1 as a LibOnly pair, and dot-sourced GUARDED at every call site so
    a mirror built before this pair existed degrades to its previous behaviour instead of throwing.

    Dot-source it $PSScriptRoot-relative:

        . (Join-Path $PSScriptRoot 'consumer-check-lib.ps1')

    Pure ASCII, per this repo's script-layer convention.
#>

function Resolve-CheckRepoRoot {
    <#
        THE ONE DUAL-CONTEXT RESOLUTION: which tree is this check operating on?

        Three sources, in order, and the order is the whole decision:

          1. -RootOverride, for the test suite and for a caller that already knows (worktree-lane hands
             a lane its own tree). A consumer never types it.
          2. $env:CLAUDE_PROJECT_DIR, which is how a SessionStart hook running the PLUGIN MIRROR learns
             which repo the session is about. Without it a hook invoked from the plugin cache would
             resolve the cache's own git root, which is this repo -- so every consumer would be judged
             against the source.
          3. the git root, which is the source-repo command-line case.

        IT RETURNS '' RATHER THAN THROWING when none of the three answers, and that is the divergence
        this function settles in favour of the tolerant reading. `git rev-parse` exits non-zero outside a
        checkout, so the one-line form died on `.Trim()` against $null -- inside a SessionStart hook,
        where a session start must not fail over an advisory check, and inside a fixture tree that is
        deliberately not a repo.

        THE VERDICT IS NOT SHARED, ONLY THE RESOLUTION. '' means "could not tell", and what to do about
        it is the caller's: an advisory session check says [OK] and exits 0 because there is genuinely
        nothing to judge, while a CI gate says [ERROR] and exits 1 because a gate that cannot find the
        tree it is gating must not pass. Both are correct, they are not the same answer, and folding
        either one in here would impose it on the other.
    #>
    param([string]$RootOverride = '')

    if ($RootOverride) { return $RootOverride }
    if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }

    # THE GIT READ IS ONE DEFINITION AND IT IS NOT --show-toplevel (issue #2115): that flag's output is
    # a raw path, which Windows PowerShell 5.1 decodes with [Console]::OutputEncoding, so a consumer
    # whose checkout sits under an accented directory name resolved a root that matched nothing. Read
    # repo-root-lib's synopsis for why the rule's usual repair does not reach this call.
    #
    # GUARDED AND LAZY, the idiom Get-CheckProseCorpus below already uses for measure-context-lib,
    # rather than check-report-lib's unguarded file-scope load. This lib is dot-sourced GUARDED by the
    # five lint checks precisely so an older mirror degrades instead of throwing, and a hard sibling
    # dependency here would undo that one layer down. Missing lib -> '' -- which is this function's
    # documented "could not tell", and the caller's own verdict decides what that means.
    $rootLib = Join-Path $PSScriptRoot 'repo-root-lib.ps1'
    if (-not (Test-Path -LiteralPath $rootLib -PathType Leaf)) { return '' }
    . $rootLib

    $read = Get-GitTopLevelPath
    if (-not $read.Path) { return '' }
    return $read.Path
}

function Get-CheckProseCorpus {
    <#
        THE ALWAYS-ON DOCUMENTS a consumer-prose check may read: the '@'-import closure of the repo's
        root document, plus whatever Get-AlwaysOnDocuments adds from the workflow folder.

        THE WALK IS NOT REIMPLEMENTED, HERE OR ANYWHERE. Get-AlwaysOnDocuments (measure-context-lib.ps1)
        owns the hop cap, the cycle guard, the fenced-block skip and the tree/external split, and a second
        walk would be a second definition of the always-on path. This function is only the LOADING of it,
        which is the part the prose checks were carrying twice.

        LOADED GUARDED RATHER THAN REQUIRED, which is a deliberate degradation and not laziness: a tree
        that does not carry measure-context-lib.ps1 gets @() back, and its caller then judges only the
        documents it finds by other means -- the workflow folder's own pages, which is where one of the
        two instances measured for #1389 actually sat. A hard requirement would have missed it.

        A MISSING ROOT DOCUMENT IS @() AND NOT AN ERROR. A repo with no CLAUDE.md has no always-on prose,
        so it has nothing for a prose check to be wrong about.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$RootDocument = ''
    )

    $measureLib = Join-Path $PSScriptRoot 'measure-context-lib.ps1'
    if (-not (Test-Path -LiteralPath $measureLib -PathType Leaf)) { return @() }
    . $measureLib

    $root = if ($RootDocument) { $RootDocument } else { Join-Path $RepoRoot 'CLAUDE.md' }
    if (-not (Test-Path -LiteralPath $root -PathType Leaf)) { return @() }

    return @(Get-AlwaysOnDocuments -RootDocument $root -RepoRoot $RepoRoot)
}

function Get-ConstitutionImportLine {
    <#
        The '@'-line a consumer's CLAUDE.md carries to load the dkj-policy constitution (issue #2374):
        one ABSOLUTE path into the marketplace clone, never into the version-pinned cache -- the same
        reasoning bootstrap.ps1's Get-DurablePersonaDir gives for the orchestrator import (an '@'-import
        takes no variable, and the cache directory is purged after an update).

        THE MARKETPLACE SEGMENT IS READ OFF THIS FILE'S OWN LOCATION where it can be. A consumer runs this
        from '~/.claude/plugins/cache/<marketplace>/dkj-policy/<version>/scripts/lib', and <marketplace>
        is the name its clone sits under -- which is not always the canonical one: a consumer registered
        before the September 10, 2026 rename still has 'claude-code-specialists'. Anywhere else (the
        source tree, a test) the canonical name is used.
    #>
    param([string]$LibDir = $PSScriptRoot)
    $marketplace = 'dkj-claude-plugins'
    $parts = @(($LibDir -replace '\\', '/').Split('/') | Where-Object { $_ })
    for ($i = 0; $i -lt $parts.Count - 2; $i++) {
        if ($parts[$i] -ieq 'cache' -and $i -gt 0 -and $parts[$i - 1] -ieq 'plugins' -and $parts[$i + 2] -ieq 'dkj-policy') {
            # A SLUG OR NOTHING. The segment is the name a repo's own committed settings.json registered
            # the marketplace under, and this line is forwarded into session context by the hook -- so
            # anything but a plain slug falls back to the canonical name rather than being printed.
            if ($parts[$i + 1] -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { $marketplace = $parts[$i + 1] }
            break
        }
    }
    return "@~/.claude/plugins/marketplaces/$marketplace/plugins/dkj-policy/CLAUDE.md"
}

function Test-ConstitutionImported {
    <#
        Does this always-on closure '@'-import the dkj-policy constitution (issue #2374)? Matched on the
        tail of the resolved path -- '.../plugins/dkj-policy/CLAUDE.md' -- so the absolute marketplace
        form, any marketplace name, and the source repo's relative form all count. A row that does NOT
        resolve (Exists = $false) still counts: the line is written, and a clone that has not refreshed
        yet is a lag the next 'claude plugin marketplace update' closes, not a missing import.
    #>
    param([AllowNull()][AllowEmptyCollection()][object[]]$Documents)
    foreach ($d in @($Documents)) {
        if ($null -eq $d) { continue }
        $p = ([string]$d.Path) -replace '\\', '/'
        if ($p -imatch '/plugins/dkj-policy/CLAUDE\.md$') { return $true }
    }
    return $false
}

function Get-RootClaudeMdProseLines {
    <#
        Every line of a consumer's ROOT 'CLAUDE.md' -- the one FILE, not the '@'-import closure it may
        open onto -- that is neither blank, an '@'-import, a single H1 title, nor an HTML comment. Dave's
        supersedure of issue #2374 (September 23, 2026): the root document holds ONLY '@'-import lines
        now (plus at most that H1, blank lines, and HTML comments), and every fact about the repo moves
        to an unscoped '.claude/rules/<name>.md', with a specialist's own repo-specific rule moving to
        its lens. This is the detector for THAT rule.

        A SECOND, INDEPENDENT DETECTOR FROM Test-ConstitutionImported ABOVE, which asks only whether the
        one constitution line is present. A root file can import the constitution correctly and still
        carry paragraphs of the repo's own law beneath it -- that is what this function reports, and
        neither function's verdict implies the other's.

        DELIBERATELY THE ROOT FILE ALONE, NOT THE WALKED CLOSURE. An imported document -- a rule page, a
        lens -- is judged by the other two consumer-prose detectors (Get-RetiredDocNameMention,
        Get-SupremacyDeclaration in entry-scaffold-lib.ps1) against their own conventions; this rule
        applies to the root file and nowhere else. The walked -Documents rows from Get-AlwaysOnDocuments
        carry no LINE TEXT, only metadata, so the root is read directly here -- resolved the same way
        Get-CheckProseCorpus resolves it, via -RootDocument with the same '<RepoRoot>/CLAUDE.md' default.

        FOUR THINGS COUNT AS STRUCTURE, NOT PROSE, and nothing else does:
          - a blank line;
          - an '@'-import line -- '@' in column 0 followed by a non-blank target, the same shape
            Get-ImportLinePath (measure-context-lib.ps1) reads on every other walk in this family,
            restated here rather than depended on so this function carries no load-order requirement on
            that lib. MATCHED ON THE RAW LINE, NOT A TRIMMED ONE (Victor #19, code review): Claude Code
            reads only a column-0 '@' as an import, so an INDENTED '@x.md' is ordinary prose to it --
            trimming first would exempt exactly the line this rule exists to catch.
          - ONE H1 title, and only as the FIRST non-blank line of the whole file (Victor #19, code
            review): '#' then a space then text, not '##' or deeper, and not a SECOND such line further
            down. Exempting every H1-shaped line unconditionally let a document smuggle a whole second
            title's worth of text past this gate; a later line that merely looks like a heading is prose
            that happens to start with '#'.
          - an HTML comment -- '<!-- ... -->' on one line, or a '<!--' ... '-->' pair spanning several.
            THE COMMENT CLOSES THE MOMENT THE LINE CONTAINS '-->', WHEREVER IT SITS (Victor #19, HIGH,
            code review): the first cut of this function tested whether the line ENDED in '-->' (single
            line) or merely CONTAINED one (continuation), so '<!-- x --> prose' set $inComment and never
            cleared it, and a multi-line comment whose closing line carried trailing text did the same --
            silently swallowing the rest of the file as an unclosed comment. Whatever text follows the
            close marker, on either shape, is evaluated as prose (a finding at that line), never
            re-classified as a possible import or heading: a mid-line '@' or '#' arriving after real
            content is not at column 0 and cannot be the first non-blank line either, so prose is the
            only shape it can honestly be read as.

        Returns one row per offending line (Line, Text). Text is the CONSUMER'S OWN prose and is
        sanitized by the CALLER exactly like the other two detectors' output -- never printed raw here.

        A MISSING ROOT FILE IS @() AND NOT AN ERROR, matching Get-CheckProseCorpus: a repo with no
        CLAUDE.md has nothing for this rule to be wrong about.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$RootDocument = ''
    )

    $root = if ($RootDocument) { $RootDocument } else { Join-Path $RepoRoot 'CLAUDE.md' }
    if (-not (Test-Path -LiteralPath $root -PathType Leaf)) { return @() }

    $text = [System.IO.File]::ReadAllText($root, [System.Text.Encoding]::UTF8)
    $lines = $text -split "(?:\r\n|\n|\r)"

    $findings = New-Object System.Collections.Generic.List[object]
    $inComment = $false
    # TRUE ONCE ANY NON-BLANK LINE HAS BEEN SEEN, of any shape -- an import, a comment, or prose. The H1
    # exemption below reads this BEFORE setting it, which is what makes "first non-blank line" mean the
    # first one in the whole file rather than merely the first one that happens to look like a heading.
    $sawNonBlank = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = [string]$lines[$i]

        if ($inComment) {
            $t = $raw.Trim()
            $closeAt = $t.IndexOf('-->')
            if ($closeAt -lt 0) { continue }
            $inComment = $false
            $after = $t.Substring($closeAt + 3).Trim()
            if ($after -ne '') { [void]$findings.Add([pscustomobject]@{ Line = $i + 1; Text = $after }) }
            continue
        }

        $trimmed = $raw.Trim()
        if ($trimmed -eq '') { continue }

        $isFirst = -not $sawNonBlank
        $sawNonBlank = $true

        if ($raw -match '^@\S') { continue }
        if ($isFirst -and $trimmed -match '^#(?!#)\s+\S') { continue }

        if ($trimmed -match '^<!--') {
            $closeAt = $trimmed.IndexOf('-->')
            if ($closeAt -lt 0) { $inComment = $true; continue }
            $after = $trimmed.Substring($closeAt + 3).Trim()
            if ($after -ne '') { [void]$findings.Add([pscustomobject]@{ Line = $i + 1; Text = $after }) }
            continue
        }

        [void]$findings.Add([pscustomobject]@{ Line = $i + 1; Text = $trimmed })
    }

    return $findings.ToArray()
}
