<#
.SYNOPSIS
    Which scripts of THIS tree a consumer's CI runners reach into, and whether those paths still
    exist here (issue #1805) -- and, since #1850, whether that consumer reaches into this tree at
    all, which is the question the first one cannot ask.

.DESCRIPTION
    WHAT BROKE, AND WHY NOTHING SAID SO. Three runners this workflow scaffolds into a consumer --
    branch-entry.yml from adopt-workflow-folder.ps1, fold-on-merge.yml and verify-resolved.yml from
    adopt-ci-floor.ps1 -- do not vendor the script they run. They check THIS repository out beside
    the consumer's own tree and run a path into it:

        - uses: actions/checkout@v5
          with:
            repository: DKJ-Solutions/dkj-claude-plugins
            ref: main
            path: .workflow-scripts
        - run: powershell ... -File .workflow-scripts/plugins/dkj-policy/scripts/lint/check-branch-entry.ps1

    That is deliberate and stays: there is ONE definition of the entry gate, of the fold and of the
    resolves check in this system, and a vendored copy would be a second one, free to drift. The cost
    is a dependency pointing the wrong way -- a path INTO this tree, written into a file this tree
    cannot reach, by a scaffolder that runs once at adoption and never again.

    So when `plugins/workflows/contributing-davekjohn/` became `plugins/dkj-policy/`, every consumer
    scaffolded before the move kept naming the old path. Measured September 10, 2026 (#1805):
    `DaveKJohn/thumbnail-generator` and `DaveKJohn/life-hub` were red on every pull request, and
    neither had been noticed, because neither repo had opened one since the break.

    THE REPORT DATED THAT BREAK TO AUGUST 3 AND IT CANNOT BE, which is worth writing down because the
    wrong figure is the more quotable one. `git log --diff-filter=ADR -- '*check-branch-entry.ps1'`
    gives the whole life of the path those two consumers name:

        2026-08-20  A   plugins/workflows/workflow-davekjohn/scripts/lint/check-branch-entry.ps1
        2026-08-26  R   -> plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1
        2026-09-05  R   -> plugins/workflows/dkj-policy/... -> plugins/dkj-policy/...

    So the gate did not exist at all until August 20, the path they name existed only from August 26,
    and it stopped resolving on September 5 -- FIVE DAYS before the measurement, not five weeks.
    August 3 is the date of a different move (the plugin tree flattening to `plugins/<plugin>/`), and
    it reached the report because it is the date this repo's own CLAUDE.md gives for a reorganisation
    of the same folder. Nothing about the defect changes; its duration does, by a factor of seven.
    Recorded here rather than only in the issue because a citation is what makes a measurement
    auditable, and this one would have shipped to every consumer on the strength of sounding worse.

    THE `ref: main` PIN IS NOT THE DEFECT, AND WAS NOT WHAT WENT UNARGUED. adopt-dkj-policy/SKILL.md
    argues the pin by name: a pinned tag keeps enforcing the shape it was pinned at, and the ENTRY's
    own path has moved twice, so a stale pin does not fail loudly -- it refuses branches that do carry
    an entry at the current path. That is right, and this lib does not reopen it. What the argument
    never weighed is the other half of the same trade: tracking the tip protects a consumer from a
    stale convention and exposes it to a moved SCRIPT. This lib is what covers that exposure, which
    is why the pin can stay.

    AND THE TESTS DID NOT CATCH IT BECAUSE THEY PINNED THE LITERAL. adopt-ci-floor.tests.ps1
    asserted `$fold -like '*.workflow-scripts/plugins/dkj-policy/scripts/...*'` -- that the scaffolder
    EMITS that string. Moving the script in this tree leaves that assertion green: it compares the
    emitted text against itself. The two callers of this lib close both ends of that:

      * the scaffolder suites read the emitted runners back through Get-SharedScriptReference and
        assert every referenced path EXISTS in this tree, so a move here goes red on the day it lands
        rather than in somebody else's repository days later;
      * check-connectors.ps1 reads the runners a REGISTERED CONSUMER has already got, so a path
        written before a move is reported from the register instead of discovered by a red gate.

    Only the second reaches a repo that adopted in August. That distinction is the whole reason this
    is a lib and not a test helper: a repair that must reach an already-adopted consumer cannot live
    in the thing that is written once.

    THE CHECKOUT IS MATCHED ON THE REPOSITORY *NAME*, NEVER THE OWNER, and that is a decision rather
    than laziness. This repo was transferred from `DaveKJohn` to `DKJ-Solutions` on September 2, 2026,
    and a consumer scaffolded before that names the old owner -- which still works, through a transfer
    redirect. Matching `owner/name` would skip those files entirely and report nothing about them:
    the same silence this lib exists to end, arriving through the guard itself. What the match has to
    answer is "does this checkout step bring in the tree I am judging", and the name answers it for a
    redirect, a fork and an org move alike. An old-owner citation is a real finding, but a different
    one (#1526's subject), and it is not made here.

    THE PREFIX IS READ FROM THE FILE, NOT ASSUMED TO BE `.workflow-scripts`. The scaffolders write
    that value and nothing stops a consumer changing it; a hard-coded prefix would go quietly blind on
    exactly the repo that had edited its own runner. It costs one more line of parsing to read the
    `path:` the checkout step actually declares.

    NO YAML PARSER, AND THE BOUND THAT MAKES THAT HONEST. This walks lines and matches two keys inside
    one `with:` block by indentation. That is not YAML and cannot be: a quoted multi-line scalar or a
    flow mapping would defeat it. What it is asked to read are files THIS workflow wrote, in a shape
    these scaffolders control and their own suites assert -- and where it fails to recognise a
    checkout step it yields nothing, so an unreadable runner is invisible rather than misreported.
    A finding here is therefore always about a path that IS named; the absence of one is never
    evidence that a consumer is clean. Adding a parser dependency to a lint that must run on a bare
    Windows PowerShell 5.1 in a consumer with no modules installed is the cost this declines to pay.

    THAT LAST SENTENCE NAMED A BLIND SPOT AND LEFT IT OPEN, which #1850 measured from the outside: a
    consumer running NO runner at all reads identically to a fully adopted one. Test-ConsumerRunnerAdoption
    at the foot of this file asks that second question -- does anything here reach into this tree -- and
    inherits the same bound rather than escaping it, which is why its 'no-reference' means "nothing
    recognisable", never "nothing is there".
#>

Set-StrictMode -Version Latest

function Get-SharedScriptReference {
    <#
        Every script path a workflow file reaches into a checkout of $RepositoryName for.

        Returns one record per DISTINCT path: @{ Path; Prefix; Repository; Line }, where Path is
        repo-relative to the checked-out tree with forward slashes ('plugins/dkj-policy/scripts/...'),
        Prefix is the local directory the step checks it out into, Repository is the `repository:`
        value as written (so a caller can name the owner the consumer cited), and Line is the
        1-based line of the first reference.

        Distinct by Path: fold-on-merge.yml names two scripts and would name one of them twice if a
        step retried it, and a reader wants one finding per broken path rather than one per mention.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$WorkflowText,
        # ONE OR MANY, because a rename does not reach a file another repository already holds
        # (#1769). A consumer scaffolded before this repo was renamed still writes the old name, and
        # its runner still WORKS -- GitHub answers the transfer redirect -- so a matcher that knows
        # only the current name reports nothing about it and the consumer reads as clean. That is the
        # silence this lib exists to end, arriving through the matcher itself. The caller supplies the
        # current name plus whatever Get-RetiredRepoNames states; a single string still binds, so
        # every existing call site is unchanged.
        [Parameter(Mandatory)][string[]]$RepositoryName
    )

    if ([string]::IsNullOrWhiteSpace($WorkflowText)) { return @() }

    $lines = $WorkflowText -split "`r?`n"

    # --- 1. Which local prefixes hold a checkout of this repository -----------------------------
    # A `repository:` whose name half matches, then the `path:` of the SAME `with:` block. A checkout
    # step with no `path:` lands in the workspace root itself, which this deliberately does NOT treat
    # as a prefix: every reference in the file would then look like one of ours, including the
    # consumer's own scripts. The scaffolders always write a path, so that shape is somebody else's
    # checkout step and not this lib's business.
    #
    # THE BLOCK IS READ IN BOTH DIRECTIONS, AND A TRAILING COMMENT IS TOLERATED. Both were false
    # NEGATIVES in the first cut of this lib, caught in review before it merged, and a false negative
    # here is the whole failure this file exists to end -- arriving one layer down, inside the
    # detector built to end it. A consumer whose runner is missed goes on reading as clean, which is
    # indistinguishable from being clean.
    #   * FORWARD-ONLY missed `path:` written ABOVE `repository:`. The scaffolders emit
    #     repository/ref/path in that order, so a fresh runner was safe -- but YAML imposes no order
    #     and this lib's own docstring anticipates hand edits, and swapping two keys is about the most
    #     ordinary edit there is.
    #   * ANCHORING THE VALUE AT `$` missed `repository: owner/name  # why we check it out`. An
    #     end-of-line comment is everyday YAML, not one of the exotic shapes the header declines.
    # Both are now covered by their own scenarios in connectors.tests.ps1.
    $keyPattern = '^(?<ind>[ \t]*)(?<key>repository|path):[ \t]*(?<q>["''])?(?<val>[^"''\r\n#]*?)(?(q)\k<q>)[ \t]*(#.*)?$'

    $prefixes = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match($lines[$i], $keyPattern)
        if (-not $m.Success -or $m.Groups['key'].Value -ne 'repository') { continue }

        $repo = $m.Groups['val'].Value.Trim()
        if (-not $repo) { continue }
        $name = $repo.Substring($repo.LastIndexOf('/') + 1)
        $isOurs = $false
        foreach ($candidate in $RepositoryName) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            if ([string]::Equals($name, $candidate, [System.StringComparison]::OrdinalIgnoreCase)) { $isOurs = $true; break }
        }
        if (-not $isOurs) { continue }

        $indent = $m.Groups['ind'].Value.Length

        # The block this key belongs to: outward from it in both directions until a line indented LESS
        # than the key, which is the parent (`with:`) above and the next step below. A blank line does
        # not end a block, so it is stepped over rather than treated as a boundary.
        $first = $i
        while ($first -gt 0) {
            $prev = $lines[$first - 1]
            if (-not [string]::IsNullOrWhiteSpace($prev) -and ([regex]::Match($prev, '^[ \t]*').Value.Length -lt $indent)) { break }
            $first--
        }
        $last = $i
        while ($last -lt $lines.Count - 1) {
            $next = $lines[$last + 1]
            if (-not [string]::IsNullOrWhiteSpace($next) -and ([regex]::Match($next, '^[ \t]*').Value.Length -lt $indent)) { break }
            $last++
        }

        for ($j = $first; $j -le $last; $j++) {
            $p = [regex]::Match($lines[$j], $keyPattern)
            if (-not $p.Success -or $p.Groups['key'].Value -ne 'path') { continue }
            if ($p.Groups['ind'].Value.Length -ne $indent) { continue }

            $prefix = $p.Groups['val'].Value.Trim().TrimEnd('/', '\')
            if ($prefix) { $prefixes[$prefix] = $repo }
            break
        }
    }
    if ($prefixes.Count -eq 0) { return @() }

    # --- 2. Every '<prefix>/<...>.ps1' token in the file ----------------------------------------
    # Both separators are admitted and normalised to '/': the scaffolders emit forward slashes, but a
    # hand-edited runner on Windows may not, and a reference this lib fails to recognise is a finding
    # it fails to make.
    $seen = @{}
    $found = @()
    foreach ($prefix in $prefixes.Keys) {
        $pattern = '(?<![\w./\\-])' + [regex]::Escape($prefix) + '[/\\](?<rel>[\w./\\-]+?\.ps1)\b'
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($hit in [regex]::Matches($lines[$i], $pattern)) {
                $rel = ($hit.Groups['rel'].Value -replace '\\', '/')
                if ($seen.ContainsKey($rel)) { continue }
                $seen[$rel] = $true
                $found += [pscustomobject]@{
                    Path       = $rel
                    Prefix     = $prefix
                    Repository = $prefixes[$prefix]
                    Line       = $i + 1
                }
            }
        }
    }

    return @($found)
}

function Test-SharedScriptReference {
    <#
        Does each referenced path still exist in $SourceRoot -- and where a path is gone, where did
        that script go?

        Returns the input records with Exists added, plus MovedTo: the repo-relative paths in
        $SourceRoot carrying the same file name, and Escapes: the reference does not stay under
        $SourceRoot at all.

        ESCAPES IS TESTED FIRST, AND A REFERENCE THAT ESCAPES REACHES NO FILESYSTEM CALL. The path
        comes out of a consumer's own workflow file, and the capture charset admits '.' and '/' --
        which is what a path needs and is therefore not containment: `../../../../somewhere.ps1`
        matches it exactly as a real reference does. Join-Path does not normalise '..', but Test-Path
        resolves it against the real filesystem, so handing it one unchecked turns this check into an
        existence oracle for the maintainer's own disk -- answered by the presence or absence of an
        [ERROR] line, unattended, at every session start, for every registered connector. Bounded
        (existence only, '.ps1'-suffixed, nothing read or run) and still wrong: it is not the question
        this function is documented to answer.

        NORMALISED WITHOUT TOUCHING THE DISK. [IO.Path]::GetFullPath is pure string work on a rooted
        path, so the containment test itself performs no I/O -- which is what makes this a closure of
        the oracle rather than a narrowing of it. The repo's own doctrine is the same shape one layer
        up: Test-PluginNameSlug guards what may BECOME a path, Format-SafeToken only guards how one is
        DISPLAYED, and a charset was never the containment.

        AN ESCAPING REFERENCE IS REPORTED, NEVER DROPPED. Silence about a strange path is the exact
        failure this lib exists to end, so it comes back as its own state for the caller to name --
        not folded into Exists=$false, which would print 'that path does not exist here' about a path
        whose problem is that it was never asked about.

        THE SUGGESTION IS THE POINT OF THE CHECK, not a
        courtesy. "This path no longer exists here" leaves the reader to find out what replaced it in
        a tree they may not have; "it is at plugins/dkj-policy/scripts/lint/check-branch-entry.ps1
        now" is a repair they can paste. Where the name matches nothing, MovedTo is empty and the
        script was removed rather than moved -- which is a different conversation and reads as one.

        A PUBLISHED COPY IS OFFERED BEFORE THE TREE'S OWN. Most scripts here exist twice: the source
        under scripts/, and the mirror under plugins/<plugin>/scripts/ that a release carries. Both
        answer the file-name search and only the second is the one an outside caller may run -- the
        source copy is this repo's own path, correct here and absent from every consumer, which is the
        mistake adopt-ci-floor.tests.ps1 already asserts against in the other direction. So a
        candidate under a plugin folder sorts first, and a reader who takes the first suggestion takes
        the right one. Both are still listed: which plugin publishes it is a question this lib has no
        business answering, and hiding the alternative would make a genuinely ambiguous case look
        settled.

        The recursive search runs ONLY on the failure path, so a clean consumer costs one Test-Path
        per reference. .git is excluded because a packed object tree holds no scripts and walking it
        is the whole cost of the walk.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Reference,
        [Parameter(Mandatory)][string]$SourceRoot
    )

    $rootFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path).TrimEnd('\', '/')
    $rootLen  = $rootFull.Length + 1

    $results = @()
    foreach ($ref in @($Reference)) {
        $full = Join-Path $rootFull ($ref.Path -replace '/', [System.IO.Path]::DirectorySeparatorChar)

        # Containment before contact -- see the docstring. GetFullPath normalises '..' as a string; the
        # comparison is against the root plus its separator, so a sibling directory whose name merely
        # starts with the root's ('...-old') cannot pass as a descendant.
        $escapes = $true
        try {
            $normalised = [System.IO.Path]::GetFullPath($full)
            $escapes = -not $normalised.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        } catch {
            # An unnormalisable path (a reserved device name, an illegal character the capture charset
            # happens to admit) is treated as escaping rather than as absent: it is not a path under
            # this root, which is the only claim this flag makes.
            $escapes = $true
        }

        $exists = $false
        if (-not $escapes) { $exists = Test-Path -LiteralPath $full -PathType Leaf }

        $movedTo = @()
        if (-not $exists -and -not $escapes) {
            $leaf = Split-Path -Leaf $ref.Path
            $movedTo = @(
                Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '(^|\\|/)\.git(\\|/)' } |
                    ForEach-Object { $_.FullName.Substring($rootLen) -replace '\\', '/' } |
                    Sort-Object -Property @{ Expression = { -not $_.StartsWith('plugins/') } }, @{ Expression = { $_ } }
            )
        }

        $results += [pscustomobject]@{
            Path       = $ref.Path
            Prefix     = $ref.Prefix
            Repository = $ref.Repository
            Line       = $ref.Line
            Exists     = $exists
            Escapes    = $escapes
            MovedTo    = $movedTo
        }
    }

    return @($results)
}

function Get-RunnerRecordField {
    <#
        One field of a workflow record, whichever of the two shapes its caller built (#1850) -- a
        hashtable from the network read, a [pscustomobject] from the disk read. $null when the record
        does not carry that field at all, which is the same answer as a field explicitly set to $null
        and deliberately so: both mean "this run has no text for that file".
    #>
    param(
        [Parameter(Mandatory)][AllowNull()]$Record,
        [Parameter(Mandatory)][string]$Field
    )

    if ($null -eq $Record) { return $null }
    if ($Record -is [System.Collections.IDictionary]) {
        if ($Record.Contains($Field)) { return $Record[$Field] }
        return $null
    }
    if ($Record.PSObject.Properties.Name -contains $Field) { return $Record.$Field }
    return $null
}

function Test-ConsumerRunnerAdoption {
    <#
        Does this consumer run ANY runner that reaches into a checkout of $RepositoryName at all --
        issue #1850.

        THE BLIND SPOT THIS CLOSES IS THE ONE THIS FILE'S OWN HEADER DECLARES. Get-SharedScriptReference
        answers "is the path this runner names still here?", and its bound is stated up there without
        euphemism: a finding is always about a path that IS named, and the absence of one is never
        evidence that a consumer is clean. So a consumer running NONE of the three runners produces no
        reference, no finding, and reads exactly like a fully adopted one -- adoption and non-adoption
        are indistinguishable to the register.

        MEASURED SEPTEMBER 11, 2026 (#1850). connectors/djcylow-react.json registers the full 19-lens
        core-team adoption and names the workflow plugin, and that repository's entire
        .github/workflows/ is one ci.yml: no branch-entry.yml, no fold-on-merge.yml, no
        verify-resolved.yml. check-connectors.ps1 reported it exactly as it reports a repo running all
        three.

        FOUR STATUSES, BECAUSE THE WAYS OF HAVING NO RUNNER ARE DIFFERENT CONVERSATIONS and a caller
        that cannot tell them apart writes a sentence that is wrong in three of the four cases:

          'no-workflows' -- no workflow files at all. Nothing was adopted and nothing was read.
          'unreadable'   -- workflow files exist and NONE of them came with text (the remote read hits
                            this on a binary or over-size file). Nothing was judged, so this is not a
                            verdict about adoption and must not be printed as one.
          'no-reference' -- workflow files were read, and not one of them checks $RepositoryName out.
          'adopted'      -- at least one does.

        AND 'no-reference' IS STILL BOUNDED BY THE PARSER ABOVE. This walks the same recogniser, so a
        runner written in a shape that recogniser declines (a quoted multi-line scalar, a flow mapping)
        yields nothing and lands here as 'no-reference'. That is honest for the finding it feeds --
        "nothing recognisable reaches into this tree" -- and it is why the caller's wording says that
        rather than "this consumer has not adopted". Readable and Unreadable come back alongside so a
        partially-read set can say so.

        WHETHER AN ABSENT RUNNER IS A DEFECT IS NOT THIS FUNCTION'S QUESTION, and deliberately so: the
        two halves of adopt-dkj-policy that place these runners are optional and separate from enabling
        the plugin, so a consumer may have decided against them. What was wrong was that nobody could
        tell either way from here. This reports the state; the caller decides what to call it.
    #>
    param(
        # One record per workflow file, carrying Name and Text, with Text $null where the bytes could
        # not be obtained. EITHER A HASHTABLE OR AN OBJECT, because the two callers genuinely hold two
        # shapes -- the network read builds @{ Name; Text } and the disk read builds a [pscustomobject]
        # -- and reading only one of them is a silent miss, not an error: a hashtable's
        # PSObject.Properties are Keys/Values/Count, so 'Text' is simply never found and every file
        # reads as unreadable. Measured on the first run of this function against the real register.
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowNull()][object[]]$Workflow,
        [Parameter(Mandatory)][string[]]$RepositoryName
    )

    $files       = @(@($Workflow) | Where-Object { $null -ne $_ })
    $readable    = 0
    $referencing = @()

    foreach ($wf in $files) {
        $text = Get-RunnerRecordField -Record $wf -Field 'Text'
        if ($null -eq $text) { continue }
        $readable++
        if (@(Get-SharedScriptReference -WorkflowText ([string]$text) -RepositoryName $RepositoryName).Count -gt 0) {
            $referencing += [string](Get-RunnerRecordField -Record $wf -Field 'Name')
        }
    }

    $status =
        if ($files.Count -eq 0)         { 'no-workflows' }
        elseif ($readable -eq 0)        { 'unreadable'   }
        elseif ($referencing.Count -gt 0) { 'adopted'    }
        else                            { 'no-reference' }

    return [pscustomobject]@{
        Status      = $status
        Workflows   = $files.Count
        Readable    = $readable
        Unreadable  = $files.Count - $readable
        Referencing = @($referencing)
    }
}
