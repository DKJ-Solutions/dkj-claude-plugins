<#
.SYNOPSIS
    Which sibling libs a lib dot-sources, which libs and ACTING SCRIPTS a file under scripts/tests copies
    into its fixture, and the gap between the two (issues #1693, #1865, #1924).

.DESCRIPTION
    WHY THIS EXISTS. Several suites build their fixture tree by HAND-LISTING the libs they copy into
    it, and nothing held those lists against what the copied libs actually dot-source. #1682 gave
    park-lib.ps1 its first lib dependency and every one of those lists went stale in the same commit.

    AND THE MISS IS SILENT, WHICH IS THE PART WORTH A GATE. The dot-source is guarded --
    `if (Test-Path $lib) { . $lib }` -- and correctly so: a consumer whose plugin mirror predates the
    new lib must not crash on load. In a fixture the file is absent for a completely different reason
    (nobody listed it), and the guard turns "this dependency is missing" into "the function is
    undefined". In Get-GitParkBacking's case that came out as an EMPTY BACKING NOTE rather than an
    error, so the failure surfaced only in whichever suite happened to assert the affected behaviour:
    park-cycle.tests.ps1 went 10 of 91 asserts red, while park-branch (31) and park-commit (28)
    exercised the same lib and stayed green because neither asserts that note.

    THE DEPENDENCY IS READ THROUGH THE VARIABLE, NOT OFF THE DOT-SOURCE LINE. The shape this repo
    actually uses is:

        $parkPorcelainLib = Join-Path $PSScriptRoot 'git-porcelain-lib.ps1'
        if (Test-Path -LiteralPath $parkPorcelainLib -PathType Leaf) { . $parkPorcelainLib }

    so the dot-source command's own text is `. $parkPorcelainLib` and carries NO filename at all. A
    reader that matches on the dot-source's extent finds nothing -- measured against
    origin/fix/1682-porcelain-line-parse, the only real instance of the class, where the first version
    of this lib missed it outright.

    AND THAT READING IS NOT DONE HERE. script-contract-lib.ps1 already resolves it --
    Get-ScriptDotSourceTargets, with Get-AstPathHints doing the variable half -- so this lib delegates
    and converts the answer to bare leaves. The first version did not, and a second AST walker is
    exactly the "second literal" defect its own sibling issue (#1682) is about; the code review on this
    branch is what caught it. Get-DotSourcedLibName carries the whole argument.

    WHAT IS GENUINELY THIS LIB'S OWN is the other half of the question: which libs a SUITE copies into
    its fixture, which nothing else in the tree reads. That is Get-FixtureCopiedLibName, and it is
    where the two false findings a naive version produced were repaired.

    AND THE SUBJECT HAS TWO HALVES, WHICH IT DID NOT UNTIL #1924. Everything above reads the copied LIBS;
    for each one it asks whether that lib's own siblings came along. Nothing asked it of the SCRIPT the
    fixture exists to run -- so when #1917 gave ~25 acting scripts an unguarded dot-source of
    check-report-lib.ps1, six fixture-based suites broke on exactly this class (fold-changelog 155 asserts
    red, prune-merged 73, park-branch 18, new-branch and two more dead on load) and this lib's own gate
    reported all 26 asserts green throughout. Get-FixtureCopiedScriptPath is that half, and
    Get-FixtureDepFinding carries the one asymmetry it comes with: a copied script is read for its
    LOAD-TIME dot-sources only, a copied lib for all of them.

    Pure ASCII (repo convention for .ps1). No Set-StrictMode: dot-sourcing would change the strict
    mode of the calling script.
#>

# THE SHARED DOT-SOURCE WALKER, AND THIS LOAD IS DELIBERATELY UNGUARDED. Every sibling dot-source in
# this tree is wrapped in `if (Test-Path ...)` because those libs travel to consumers, where a mirror
# may predate the file. This one does not travel: it is repo-local, read by one repo-local suite, and a
# missing sibling here is a broken checkout rather than an older consumer -- so it must fail loudly on
# load instead of leaving Get-DotSourcedLibName undefined, which is precisely the silence this whole
# lib exists to remove. Dot-sourcing it twice is harmless if a caller has already loaded it.
. (Join-Path $PSScriptRoot 'script-contract-lib.ps1')

# Separators are normalised through these rather than through a '\\' in a pattern. Written as code
# points because a backslash pair does not survive every layer this repo's scripts get written by --
# measured while building #1693, where '[\\/]' reached the file as '[\/]' and the class then matched
# only a forward slash, so the reader silently found nothing.
$script:FixtureDepBackslash = [char]92
$script:FixtureDepForwardSlash = [char]47

# A bare '<name>.ps1', or one at the end of a path. Anchored on the leaf so 'scripts/lib/x.ps1',
# '..\lib\x.ps1' and a bare 'x.ps1' all yield 'x.ps1'.
$script:FixtureDepLeafPattern = '(?:^|/)([A-Za-z0-9_.-]+\.ps1)$'

# A copied SCRIPT's destination, captured from 'scripts/' onward so the answer is a repo-relative path
# rather than a leaf (issue #1924). A path, not a leaf, because the leaf cannot be found again: the
# fixture copies the real 'scripts/task/new-branch.ps1', and the walk has to read THAT file to learn what
# it dot-sources. Every fixture in this tree reproduces the repo's own layout below the fixture root --
# it has to, since the script resolves its libs through '$PSScriptRoot\..\lib' -- so the destination
# literal already carries the repo-relative path and nothing has to be guessed.
$script:FixtureDepScriptPathPattern = '(?:^|/)(scripts/(?!lib/)[A-Za-z0-9_./-]*[A-Za-z0-9_.-]+\.ps1)$'

# THE DECLARED OPT-OUT, AND THE SHAPE OF IT WAS SPECIFIED BEFORE IT WAS NEEDED. Get-FixtureCopiedLibName's
# own docstring predicted this case under #1693 -- "a fixture that omits a dependency ON PURPOSE ... would
# be reported and would be right to complain ... the answer is a declared opt-out on that suite, NOT
# another entry in the exemption list" -- and named the two as different things on purpose: the exemption
# list is about a FILE the whole tree does not owe, this is about ONE fixture that does not load a script
# it copies. #1924 produced the first instance, so the mechanism is built to that specification rather
# than to a fresh judgement.
#
#     # fixture-dep: script-not-loaded scripts/lint/check-branch-entry.ps1 -- <why>
#
# THE REASON IS PART OF THE SYNTAX, not a convention beside it: a line with no ' -- <why>' does not match,
# so the finding stands. That is the safe direction for a malformed opt-out -- it fails loud rather than
# silently disarming the gate -- and it means every opt-out in the tree carries its argument at the point
# a reader meets it.
$script:FixtureDepOptOutPattern = '(?m)^\s*#\s*fixture-dep:\s*script-not-loaded\s+(\S+)\s+--\s+\S'

# THE REPO-OWNED SEAMS, WHICH A FIXTURE DOES NOT OWE (issue #1693). These are not "libs we decided to
# skip": they are the files whose CONTENT differs per repo, so the caller dot-sources the consumer's
# own copy from its repo root and a lib's sibling dot-source of the same name is a documented
# FALLBACK rather than the dependency. release-lib.ps1 says it in so many words -- "branch-info.ps1 is
# REPO-OWNED -- the prefix table differs per repo ... the caller (cut-release.ps1) has already
# dot-sourced the CONSUMER's branch-info from its repo root". A fixture that supplies the seam its own
# way is therefore complete, and demanding the sibling copy would report a correct fixture as broken.
#
# MEASURED: this is the second of the two false findings a naive version of this check produced on a
# clean tree -- internal-note.tests.ps1, which copies release-lib.ps1 and four of its five siblings and
# is right not to copy this one.
#
# ONE ENTRY, AND THE BAR FOR A SECOND IS THE RULE ABOVE, not convenience: the file must be one whose
# content the consuming repo owns. repo-config.ps1 is the other file in this tree that would qualify,
# and it is deliberately absent because no lib dot-sources it as a sibling -- adding it now would be a
# rule with nothing under it. THIS LIST IS NOT THE PLACE for a fixture that omits a dependency on
# purpose; see Get-FixtureCopiedLibName for why that needs an opt-out on the suite instead.
$script:FixtureDepRepoOwnedSeam = @('branch-info.ps1')

# The destination-literal memo -- see Get-FixtureCopyDestinationLiteral for what it is worth and why its
# key carries the file's identity. Declared at load time rather than lazily, which is a strict-mode
# requirement rather than a style choice: every caller runs under Set-StrictMode -Version Latest, where
# even the "is it initialised yet" test would throw. Same reasoning, same shape, as the walker's own memo
# in script-contract-lib.ps1.
$script:FixtureDepDestinationCache = @{}


function Get-FixtureDepRepoOwnedSeam {
    <# The repo-owned seam files a fixture does not owe a copy of. Exposed so a suite can assert the
       list rather than restate it -- a second definition of an exemption list is how one of them goes
       stale without anything saying so. #>
    return @($script:FixtureDepRepoOwnedSeam)
}

function Get-FixtureDepAst {
    <#
        The parsed AST of one .ps1, or a throw naming the file. Separate so both readers below fail
        the same way on an unparseable file rather than one of them returning an empty answer -- an
        empty answer here reads as "no dependencies", which is the exact silence this lib exists to
        remove.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
    if ($errs -and @($errs).Count -gt 0) {
        throw "fixture-dep: '$Path' does not parse ($(@($errs)[0].Message))"
    }
    return $ast
}

function Get-FixtureDepPs1Leaf {
    <#
        The '<name>.ps1' a string literal names, or '' when it names none. One place, so the three
        spellings a path can arrive in are normalised identically wherever they are read.
    #>
    param([string]$Value)

    if (-not $Value) { return '' }
    $normalised = $Value.Replace($script:FixtureDepBackslash, $script:FixtureDepForwardSlash)
    $m = [regex]::Match($normalised, $script:FixtureDepLeafPattern)
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Get-DotSourcedLibName {
    <#
        Every sibling lib ONE .ps1 dot-sources, as bare '<name>.ps1' leaves.

        THIS DELEGATES, AND THAT IS THE POINT OF IT. The first version of this function was a second
        AST walker: it found dot-source commands, resolved a variable to its last assignment, and read
        the '.ps1' literal out of the right-hand side. All of that already existed in
        script-contract-lib.ps1 -- Get-ScriptDotSourceTargets, with Get-AstPathHints doing the variable
        resolution -- and that lib's own docstring says why: '$VarMap carries the same shape per
        variable name so ". $configPath" resolves through its assignment, which is how three of the
        four dot-source shapes in this tree are written'.

        SO THE SECOND ENGINE WAS THE DEFECT THIS BRANCH'S SIBLING ISSUE IS ABOUT. #1682 is "the git
        porcelain line parse is a second literal", and writing a rival dot-source resolver in the same
        week would have been the same mistake with a citation attached. Found by the code review on
        this branch rather than by me, which is worth recording: the duplication was invisible from
        inside the file, because both halves read correctly on their own.

        WHAT DELEGATING GAINED, beyond one engine instead of two. Get-ScriptDotSourceTargets already
        handles two shapes the hand-rolled reader did not: a path built from the REPO ROOT rather than
        $PSScriptRoot, and the `& { . $args[0] }` idiom. It also drops a target that resolves to no
        existing file, which is the same judgement Get-FixtureDepFinding was making one layer later.

        WHAT IS LEFT HERE IS THE SHAPE CONVERSION, and it is the whole reason this wrapper exists at
        all rather than the callers calling through: that function answers in absolute paths, and every
        question this lib asks is about a bare leaf, because a fixture's copy list is a list of leaves.
        Split-Path -Leaf is the entire difference.

        -RepoRoot is passed through because that function needs it to try the repo-root base. A caller
        with no repo (this lib's own suite, working in a sandbox) passes the sandbox root, which is the
        honest answer for that tree.

        -LoadTimeOnly narrows the answer to the dot-sources that run when the file is LOADED, and is the
        shared walker's -UnconditionalOnly under the name this lib's question uses: here the subject is
        always a file a fixture copies, and the thing being asked is whether that file can be loaded at
        all. Get-FixtureDepFinding carries the argument for why the copied SCRIPT is read this way and the
        copied LIBS are not.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [switch]$LoadTimeOnly
    )

    # THE PARSE FAILURE IS STILL THIS LIB'S OPINION, NOT THE SHARED WALKER'S. Get-ScriptDotSourceTargets
    # returns @() for a file it cannot parse, which is right for its own caller -- a contract check
    # asking "is this lib reachable" must not fall over on a syntax error elsewhere. Here an empty
    # answer means "this lib needs nothing copied", which is the exact silence the gate exists to
    # remove, so a file that does not parse is thrown on before the walk is asked.
    $null = Get-FixtureDepAst -Path $Path

    return @(Get-ScriptDotSourceTargets -Path $Path -RepoRoot $RepoRoot -UnconditionalOnly:$LoadTimeOnly |
                ForEach-Object { Split-Path -Path $_ -Leaf } |
                Sort-Object -Unique)
}

# Copy-Item's SWITCH parameters -- the ones that consume no following element. Everything else that
# arrives as a parameter without an attached argument does consume the next element, so the positional
# walk below can tell 'Copy-Item -LiteralPath $a $b' (one positional) from 'Copy-Item $a $b -Force'
# (two). The set is closed and small because the command is fixed; a name missing from it costs one
# skipped positional, which under-reports rather than accuses.
# -ErrorAction, -WarningAction and -InformationAction are NOT in this list and must not be added: they
# are common parameters that take a VALUE (-ErrorAction Stop), unlike -Verbose and -Debug, which are
# switches. They were here, and the code review caught it: `Copy-Item -ErrorAction Stop $src (Join-Path
# $dir 'scripts\lib\a-lib.ps1')` lost its destination entirely -- measured, the reader returned nothing
# at all -- because 'Stop' was counted as the first positional and the real destination became the
# second. No suite in the tree writes that today, which is exactly why it needed a review to find and
# an assert to keep.
$script:FixtureDepCopyItemSwitch = @(
    'Recurse', 'Force', 'PassThru', 'Container', 'Confirm', 'WhatIf', 'UseTransaction', 'Verbose',
    'Debug'
)

function Get-CopyItemDestinationAst {
    <#
        The AST(s) that give ONE Copy-Item its destination -- named or positional.

        BOTH SHAPES ARE IN THIS TREE, which is the only reason this is a function rather than a line.
        Most suites write `-Destination (Join-Path $dir '...')`; source-repo-guard.tests.ps1 writes
        `Copy-Item $GuardLib (Join-Path $awayDir 'scripts\lib\source-repo-guard-lib.ps1')` positionally.
        A reader that handles only the named form silently stops treating that suite as a subject at
        all -- which is the same class of silent miss this whole lib exists to remove, so getting it
        wrong here would have been the joke writing itself.

        Positional destination is index 1 (0-based) among the positional arguments: Copy-Item's first
        positional is -Path and its second is -Destination.
    #>
    param([Parameter(Mandatory = $true)]
          [System.Management.Automation.Language.CommandAst]$Command)

    $elements = @($Command.CommandElements)
    $named = @()
    $positional = @()

    # Element 0 is the command name itself.
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
            $name = $el.ParameterName
            if ($null -ne $el.Argument) {
                # -Destination:<value> -- the value is attached to the parameter itself.
                if ($name -eq 'Destination') { $named += $el.Argument }
                continue
            }
            if ($script:FixtureDepCopyItemSwitch -contains $name) { continue }
            if ($i + 1 -lt $elements.Count) {
                if ($name -eq 'Destination') { $named += $elements[$i + 1] }
                $i++   # the next element is this parameter's value, not a positional
            }
            continue
        }
        $positional += $el
    }

    if ($named.Count -gt 0) { return @($named) }
    if ($positional.Count -ge 2) { return @($positional[1]) }
    return @()
}

function Get-FixtureCopiedLibName {
    <#
        Every 'scripts/lib/<name>.ps1' a test suite copies into its fixture tree, as bare leaves.

        THE SUBJECT IS THE -Destination AND ONLY THE -Destination, which is not a detail. Every one of
        these copies reads FROM 'scripts\lib\<x>.ps1' in the real repo, so a reader that takes any
        literal in the command takes the source too -- and then every Copy-Item in the tree looks like
        a fixture lib copy. Measured while building this: that mistake produced two findings on a clean
        tree and both were false, which is the false-positive rate this repo declines a check over.

        THE FIRST OF THOSE TWO IS THE ONE WORTH KNOWING ABOUT, because binding to the destination fixes
        it for the right reason rather than by luck. consumer-check-lib.tests.ps1 copies its lib into a
        FLAT directory that deliberately has no measure-context-lib sibling: that fixture exists to
        prove the guarded load degrades correctly on a mirror built before that lib travelled. Its
        destination is therefore not a scripts/lib tree at all, and it is correctly not a subject here.

        BUT THE SHAPE IT REPRESENTS IS A REAL FUTURE FALSE POSITIVE, and there is deliberately no
        mechanism for it yet: a fixture that omits a dependency ON PURPOSE, inside a scripts/lib tree,
        would be reported and would be right to complain. None exists today. If one appears, the answer
        is a declared opt-out on that suite -- NOT another entry in the exemption list below, which is
        about a different thing entirely.

        Read off the command rather than the line, so a backtick continuation between -LiteralPath and
        -Destination cannot change the answer -- internal-note.tests.ps1 writes every one of its copies
        that way. A suite that copies nothing into a fixture scripts/lib returns nothing and is not a
        subject at all.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $found = @()
    foreach ($dest in (Get-FixtureCopyDestinationLiteral -Path $Path)) {
        if ($dest -notmatch 'scripts/lib/') { continue }
        $leaf = Get-FixtureDepPs1Leaf -Value $dest
        if ($leaf) { $found += $leaf }
    }

    return @($found | Sort-Object -Unique)
}

function Get-FixtureCopyDestinationLiteral {
    <#
        Every string literal that appears in a Copy-Item DESTINATION in one file, normalised to forward
        slashes. The shared half of the two readers above and below, so a file is parsed once and the
        two questions -- which libs, which scripts -- cannot drift apart on how a destination is found.

        Split out for #1924, when the second reader arrived. Before that the walk and the 'scripts/lib/'
        filter were one function, which reads fine with one caller and would have meant a second copy of
        Get-CopyItemDestinationAst's contract with two.

        AND MEMOISED, BECAUSE FACTORING IT OUT DID NOT BY ITSELF MAKE THE PARSE SHARED. Both readers call
        this, so Get-FixtureDepReport asking its two questions about one file read and parsed that file
        TWICE -- the copy review caught the comment claiming otherwise, which was the honest description of
        an optimisation that had only been half made. Keyed exactly as Get-ScriptDotSourceTargets' memo is,
        on the file's identity rather than its path alone: this lib's own suite writes a fixture, reads it
        and writes another at the same path, and a path-only key is the one that goes stale under precisely
        that caller (#1693, where it cost two red asserts reading as a bug in the walk).
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $stat = Get-Item -LiteralPath $Path
    $cacheKey = "$($stat.FullName)|$($stat.LastWriteTimeUtc.Ticks)|$($stat.Length)"
    if ($script:FixtureDepDestinationCache.ContainsKey($cacheKey)) {
        return @($script:FixtureDepDestinationCache[$cacheKey])
    }

    # THE PREFILTER IS FREE AND IT IS NOT A MICRO-OPTIMISATION EITHER. This runs over EVERY suite in the
    # directory to decide which ones are subjects, and only 18 of 84 files contain the string
    # 'Copy-Item' at all -- so 66 of them were being parsed to prove they have no Copy-Item in them.
    # Measured by the cost review: 725 ms for parse-plus-walk over all 84, against 275-281 ms with this
    # line, a 2.6x cut for one substring test. It cannot change the answer: a file with no occurrence of
    # the string cannot hold a Copy-Item CommandAst, and a file that only mentions it in a comment costs
    # one harmless parse.
    # THE EMPTY ANSWER IS CACHED TOO, and the early return is inside the walk rather than above the memo
    # for that reason: 'this file has no Copy-Item' is an answer, and re-reading 66 files to reach it a
    # second time is the same waste one line down.
    $found = @()
    if (([System.IO.File]::ReadAllText($Path)).IndexOf('Copy-Item', [System.StringComparison]::Ordinal) -ge 0) {
        $ast = Get-FixtureDepAst -Path $Path
        foreach ($node in @($ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))) {
            if ($node.GetCommandName() -ne 'Copy-Item') { continue }

            foreach ($valueAst in (Get-CopyItemDestinationAst -Command $node)) {
                foreach ($lit in @($valueAst.FindAll({
                            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true))) {
                    $found += ([string]$lit.Value).Replace($script:FixtureDepBackslash, $script:FixtureDepForwardSlash)
                }
            }
        }
    }

    $script:FixtureDepDestinationCache[$cacheKey] = @($found)
    return @($found)
}

function Get-FixtureCopiedScriptPath {
    <#
        Every ACTING SCRIPT a file copies into its fixture tree, as repo-relative forward-slash paths
        ('scripts/task/new-branch.ps1'). The other half of the subject, and the half that was missing
        until #1924.

        WHY THE GATE NEEDED THIS. The reader above asks, for each copied LIB, whether that lib's own
        siblings were copied too. Nothing asked the same question about the SCRIPT the fixture exists to
        run -- so #1917 gave ~25 acting scripts an unguarded dot-source of check-report-lib.ps1, six
        fixture-based suites broke on it, and this gate reported all 26 of its asserts green throughout.
        A lib gaining a sibling is the rarer half of the class; a script gaining one is the commoner half,
        and a script is what a fixture is built to run.

        AND THE SYMPTOM IS WHY IT WAS WORTH A MECHANISM RATHER THAN A HABIT. The script dies during load,
        before it writes anything, so what the suite reports is a MISSING FIXTURE DOCUMENT -- 'cannot find
        part of the path ...\dkj-policy\feat-my-task-v1.md'. Nothing in that names the absent lib, so the
        cost of the class is not the repair but the hour spent reading it backwards.

        A PATH, NOT A LEAF, unlike everything else in this lib -- see the pattern's own note. 'scripts/lib'
        destinations are excluded here rather than merely unmatched, so the two readers partition the
        destinations between them instead of overlapping.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $found = @()
    foreach ($dest in (Get-FixtureCopyDestinationLiteral -Path $Path)) {
        $m = [regex]::Match($dest, $script:FixtureDepScriptPathPattern)
        if ($m.Success) { $found += $m.Groups[1].Value }
    }

    return @($found | Sort-Object -Unique)
}

function Get-FixtureDepScriptOptOut {
    <#
        The copied scripts one file DECLARES it does not load, as the same repo-relative paths
        Get-FixtureCopiedScriptPath answers in. See the pattern's own note for the syntax and why the
        reason is part of it.

        READ FROM THE COMMENT TOKENS, WHICH IS NEITHER THE RAW TEXT NOR THE AST. The declaration is a
        comment, so the AST cannot carry it -- that is the very property Get-DotSourcedLibName relies on
        to ignore a dot-source written inside a docstring. But a raw text match is wrong in the mirror
        image: a directive that appears inside a STRING is data, not a declaration, and this lib's own
        suite is the proof. It writes synthetic opt-out fixtures into here-strings, so on a raw match the
        tree-wide count read 3 where the tree held 1 -- measured the first time that assert ran. The
        parser's token stream separates the two exactly, and it is the same parser already being used one
        function over.

        Returned separately rather than subtracted inside the reader, so that what a fixture COPIES and
        what it declares stay two readable answers. Get-FixtureDepFinding applies it, in the same place it
        applies the repo-owned seam list.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    # The same free prefilter as the destination reader, and it matters more here: this one is asked about
    # every file in the directory, while a declaration exists in one of them.
    if (([System.IO.File]::ReadAllText($Path)).IndexOf('fixture-dep:', [System.StringComparison]::Ordinal) -lt 0) {
        return @()
    }

    $tokens = $null
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    if ($errs -and @($errs).Count -gt 0) {
        throw "fixture-dep: '$Path' does not parse ($(@($errs)[0].Message))"
    }

    $found = @()
    foreach ($t in @($tokens)) {
        if ($t.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) { continue }
        foreach ($m in [regex]::Matches($t.Text, $script:FixtureDepOptOutPattern)) {
            $found += $m.Groups[1].Value.Replace($script:FixtureDepBackslash, $script:FixtureDepForwardSlash)
        }
    }

    return @($found | Sort-Object -Unique)
}

function Get-FixtureDepFinding {
    <#
        The gap for ONE fixture builder: every lib that some lib it copies dot-sources, and that it
        does not copy itself. Returns a (possibly empty) list of pscustomobjects { File, Lib, Missing }.

        THE SUBJECT IS A FILE THAT COPIES A LIB, WHICH IS USUALLY BUT NOT ALWAYS A SUITE. The parameter
        was -SuitePath and the field was Suite until #1865 widened the scan set; both now name what
        they actually hold, since check-plugin-integrity-fixture.ps1 is a builder four suites share and
        no suite itself.

        THE CLOSURE IS WALKED, NOT ONE LEVEL. If a copied lib pulls in B and B pulls in C, the fixture
        needs all three -- so reporting only B would make the author fix it, re-run, and be told about
        C on the second round. A visited set keeps a cycle from spinning.

        A DEPENDENCY THAT DOES NOT EXIST IN -LibDirectory IS NOT A FINDING. The guarded dot-source is
        there precisely because a lib may legitimately not be present yet, and this lib is not the
        place to have an opinion about a name the tree does not carry.

        -CopiedLib LETS A CALLER THAT ALREADY ASKED HAND THE ANSWER IN. Get-FixtureDepReport computes
        the copy list to decide whether a file is a subject at all, and then called this, which read
        the same file again -- measured by the cost review at 447 ms against 257 ms over the twelve real
        subjects, so ~190 ms of every run went on parsing each subject twice. Omitted, it reads the
        list itself, which keeps this function usable on its own.

        THE COPIED SCRIPT SEEDS THE WALK TOO (issue #1924), and on a NARROWER rule than a lib does: only
        its dot-sources that run AT LOAD -- top level, outside any if/try/function/script block. That is
        -UnconditionalOnly on the shared walker, and the asymmetry is measured rather than tidy.

        WHY A LIB'S GUARDED DOT-SOURCE IS A FINDING AND A SCRIPT'S IS NOT. For a copied lib the guard is
        the whole point of the gate: park-lib.ps1's `if (Test-Path) { . $lib }` of git-porcelain-lib is
        the founding instance (#1693), where the missing file turned into an undefined function and came
        out as an EMPTY BACKING NOTE rather than an error. For the script under test the same shape means
        something different, because a script's guarded dot-sources in this tree are its OPTIONAL
        equipment -- the source-repo guard, the commit-ability probe, the close-out printer -- each of
        which a fixture may legitimately decline to carry. Measured on the clean tree the day this was
        built: seeding from every dot-source reports 10 subjects, and all ten are conditional ones that a
        fixture deliberately does not copy (source-repo-guard-lib in eight of them, whose refusal cannot
        even fire in a fixture, which carries no marketplace.json). Seeding from the load-time ones alone
        reports none -- and still reports exactly the class that was missed, since check-report-lib.ps1
        was dot-sourced unguarded at the top of all ~25 scripts.

        SO THIS UNDER-REPORTS BY DESIGN, which is this repo's stated bias for a findings list: a fixture
        that omits a lib its script loads conditionally is not accused, and if one of those ever matters
        the fixture's own author is the one who knows it -- new-branch.tests.ps1 already copies
        git-identity-lib.ps1 for exactly that reason, in a comment that says so. What the gate now
        guarantees is the narrower, mechanical thing it can prove: a fixture that would DIE ON LOAD is
        named before it dies.

        -RepoRoot is the base Get-ScriptDotSourceTargets needs for a dot-source built from the repo root
        rather than from $PSScriptRoot; it is ALSO where a copied script is read from, since the fixture's
        own copy does not exist until the suite runs.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$LibDirectory,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string[]]$CopiedLib,
        [string[]]$CopiedScript
    )

    # @() AROUND THE WHOLE if, not inside its branches: an if-expression assigned to a variable is
    # unwrapped, so a single-element result arrives as a bare string and .Count below then throws under
    # Set-StrictMode. The inner @() are not enough and it looked like they were.
    $copied = @(if ($PSBoundParameters.ContainsKey('CopiedLib')) { $CopiedLib }
                else { Get-FixtureCopiedLibName -Path $Path })
    $scripts = @(if ($PSBoundParameters.ContainsKey('CopiedScript')) { $CopiedScript }
                 else { Get-FixtureCopiedScriptPath -Path $Path })
    if ($copied.Count -eq 0 -and $scripts.Count -eq 0) { return @() }

    $fileName = Split-Path -Path $Path -Leaf
    $findings = @()
    $seen = @{}
    $queue = New-Object System.Collections.Queue
    foreach ($c in $copied) { $queue.Enqueue($c) }

    # THE SCRIPTS ARE READ FIRST AND THEIR DEPENDENCIES JOIN THE SAME QUEUE, so the closure is walked in
    # one pass exactly as it is for a lib: a lib the script loads and the fixture lacks is reported here,
    # and whatever THAT lib dot-sources is then walked below rather than waiting for a second run.
    # THE DECLARED OPT-OUTS ARE READ FROM THE FILE EVEN WHEN THE COPY LIST WAS HANDED IN. A caller passing
    # -CopiedScript has answered "what does it copy"; it has not answered "what does it say about them",
    # and a report that honoured the declaration only on the path where nothing was pre-computed would be
    # a gate that is correct depending on who called it.
    $optOut = @(Get-FixtureDepScriptOptOut -Path $Path)

    foreach ($rel in $scripts) {
        if ($optOut -contains $rel) { continue }
        $scriptPath = Join-Path $RepoRoot ($rel -replace $script:FixtureDepForwardSlash, $script:FixtureDepBackslash)
        # A DESTINATION THAT NAMES NO FILE IN THIS REPO IS NOT A FINDING. A fixture may copy a script it
        # writes itself, or one from a tree this run cannot see; either way there is nothing to read, and
        # inventing an opinion about it is how a gate starts accusing.
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { continue }

        foreach ($dep in (Get-DotSourcedLibName -Path $scriptPath -RepoRoot $RepoRoot -LoadTimeOnly)) {
            if ($script:FixtureDepRepoOwnedSeam -contains $dep) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $LibDirectory $dep) -PathType Leaf)) { continue }
            if ($copied -notcontains $dep) {
                $findings += [pscustomobject]@{ File = $fileName; Lib = $rel; Missing = $dep }
            }
            $queue.Enqueue($dep)
        }
    }

    while ($queue.Count -gt 0) {
        $lib = [string]$queue.Dequeue()
        if ($seen.ContainsKey($lib)) { continue }
        $seen[$lib] = $true

        $libPath = Join-Path $LibDirectory $lib
        if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) { continue }

        foreach ($dep in (Get-DotSourcedLibName -Path $libPath -RepoRoot $RepoRoot)) {
            if ($dep -eq $lib) { continue }

            # A REPO-OWNED SEAM IS NEITHER REPORTED NOR WALKED. Not reported because the fixture does
            # not owe it (see the list's own note); not walked because it is not part of the fixture,
            # so its own dot-sources are the consumer's business rather than this fixture's debt.
            if ($script:FixtureDepRepoOwnedSeam -contains $dep) { continue }

            if (-not (Test-Path -LiteralPath (Join-Path $LibDirectory $dep) -PathType Leaf)) { continue }
            if ($copied -notcontains $dep) {
                $findings += [pscustomobject]@{ File = $fileName; Lib = $lib; Missing = $dep }
            }
            $queue.Enqueue($dep)
        }
    }

    return @($findings | Sort-Object Lib, Missing -Unique)
}

function Get-FixtureDepReport {
    <#
        Every file in -TestsDirectory that copies a lib, with its findings -- the whole answer in one
        call, so a gate and a suite cannot disagree about what was examined.

        Returns { Files, Subjects, Findings }: how many files were read, how many of them copy a lib
        at all, and the flat finding list. SUBJECTS IS RETURNED BECAUSE A SILENT PASS NEEDS IT: zero
        findings over zero subjects is a reader that found nothing to read, and zero findings over
        thirteen is the tree being clean. The two must never print the same line -- the same reason
        check-plugin-integrity.ps1's span checks print both figures.

        EVERY '.ps1', NOT ONLY '*.tests.ps1' (issue #1865). The filter was the suite-name pattern until
        September 11, 2026, on the reasonable-sounding ground that the class this gate measures is "a
        SUITE copies a lib into a fixture". What that misses is the case where the copying has been
        FACTORED OUT of the suites, and the tree already holds one: check-plugin-integrity-fixture.ps1
        is not a suite by name, copies fourteen libs, and is shared by the four
        check-plugin-integrity-{links,commands,docs,entries} suites -- so the one builder here that four
        suites depend on was the one the gate could not see.

        MEASURED ON #1860's BRANCH, which gave entry-scaffold-lib.ps1 a new unconditional sibling: this
        gate reported 7 findings, named all seven suites, and was right about every one of them -- and
        the four lint suites then failed anyway, 4 of 93 asserts red, because check-plugin-integrity.ps1
        died on lib load before printing a finding. That is the identical failure mode #1650 records one
        lib earlier and the identical one #1693 built this gate to prevent. The gate found the seven it
        could see and was structurally blind to the eighth.

        AND WIDENING IS BORN GREEN, which is why it is this repair rather than the more thorough one.
        The three other non-suite files here (fresh-consumer, round-baseline and round-tally .measure.ps1)
        contain no Copy-Item at all, so they are not subjects and cost one substring test each; the
        builder itself reports 0 findings today. The alternative weighed in #1865 -- follow each suite's
        own dot-sources, so a builder is reached because a suite LOADS it rather than because of where it
        sits -- is strictly more correct and strictly more code, and buys nothing this tree can measure
        today. It is the repair to reach for on the day a builder moves out of scripts/tests.

        -RepoRoot is passed through to the dot-source walker; -LibDirectory is where a dependency is
        looked for. They are separate parameters because this lib's own suite points them at a sandbox
        whose layout is not a repo's.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TestsDirectory,
        [Parameter(Mandatory = $true)][string]$LibDirectory,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $files = @(Get-ChildItem -Path $TestsDirectory -Filter '*.ps1' -File | Sort-Object Name)
    $subjects = 0
    $findings = @()
    foreach ($f in $files) {
        # Read ONCE and handed on -- see Get-FixtureDepFinding's -CopiedLib for the measurement. Both
        # readers share one parse of the file (Get-FixtureCopyDestinationLiteral), so asking the second
        # question costs a regex per destination rather than a second walk.
        $copied = @(Get-FixtureCopiedLibName -Path $f.FullName)
        $scripts = @(Get-FixtureCopiedScriptPath -Path $f.FullName)
        # A FILE THAT COPIES ONLY A SCRIPT IS A SUBJECT TOO (issue #1924). It was 'copies a lib', which
        # is the same one-word gap this widening is about one layer up: a fixture that copies an acting
        # script and no lib at all is precisely the one that dies on load, and it was not even counted.
        if ($copied.Count -eq 0 -and $scripts.Count -eq 0) { continue }
        $subjects++
        $findings += @(Get-FixtureDepFinding -Path $f.FullName -LibDirectory $LibDirectory `
                                             -RepoRoot $RepoRoot -CopiedLib $copied -CopiedScript $scripts)
    }

    return [pscustomobject]@{
        Files    = $files.Count
        Subjects = $subjects
        Findings = @($findings)
    }
}
