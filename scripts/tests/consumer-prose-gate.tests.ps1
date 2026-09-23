<#
.SYNOPSIS
    Regression tests for the consumer-prose guard: the shared corpus Get-ConsumerProseDocuments, the two
    detectors over it -- Get-RetiredDocNameMention (issue #1389) and Get-SupremacyDeclaration (#1415),
    with Get-RetiredBranchDocNames and Get-ProseParagraphUnits underneath them -- the check script
    scripts/lint/check-consumer-prose.ps1, and the SessionStart hook consumer-prose-sessioncheck.ps1.
    One suite since issue #1421 merged the pair.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/consumer-prose-gate.tests.ps1

    THIS IS TWO SUITES FOLDED TOGETHER, and the fold is the point rather than a side effect. The two
    detectors were separate scripts, separate hooks and separate suites for one day; what they always
    shared was the CORPUS, and a corpus asserted twice is a corpus that drifts on the day a third
    exclusion is found. It is asserted ONCE here, on its own, because a change to it moves what BOTH
    detectors are allowed to look at.

    THE ASSERT THE MERGE ADDED, and it is the one that fails first if anybody re-splits the run: a
    fixture carrying BOTH defects produces BOTH [ERROR] blocks from ONE invocation. A check that
    short-circuited on the first finding would give a session start the worse half of the two-hook
    arrangement -- one defect reported, the other hidden -- without the cost saving that motivated
    merging them.

    THE MEASURED INSTANCES ARE ALL FIXTURES HERE, in the STRUCTURE they were found in.
    #1389, both BWJ consumers: the retired single 'development.md' still restated in an always-on
    document, one day and six days after the rename -- once in the consumer's own CLAUDE.md and once in
    dkj-policy/CONTRIBUTING.md, the second being the page #1380's detector never read.
    #1415, BWJ-ecommerce/smartwatchbanden, September 4, 2026: the Dutch preamble inversion in
    CLAUDE.md:22 ('wint' beside `CLAUDE.md`, inside a blockquote), and the same inversion stated from the
    other side in dkj-policy/CONTRIBUTING.md:306 (`CLAUDE.md` beside 'wins', under bold
    markup). The second is the one #1380's census never counted at all.

    STRUCTURE, NOT WORDING, AND THAT IS THE BOUND RATHER THAN AN ACCIDENT. Those consumers are private
    and this repository is public, so a measurement taken there quotes only what the finding reads --
    here the retired filename and the adjacency, which are the detectors' own patterns -- with the repo,
    file and line carrying the provenance. The rule is in CLAUDE.md's public-repo bullet (Dave,
    September 5, 2026, issue #1420) and it binds a fixture exactly as it binds prose: a matcher reads
    shape, so the consumer's surrounding sentence adds no coverage and a public repository would keep it
    forever. Each fixture below is therefore built from this repo's own words around the clause that
    fires, and is pinned to the line it was measured at.

    THE RETIRED NAMES COME FROM THE REAL DERIVATION, never from a literal here. Every case that needs a
    retired name reads it out of Get-RetiredBranchDocNames, so the next rename reaches these cases
    automatically instead of leaving a second list of names to go stale in the file whose job is to prove
    there is only one. The two asserts that DO name a literal are the ones about the literals themselves.

    AND THE ONE SUPPRESSED FALSE POSITIVE IS PINNED TOO, because a suppression rule resting on a single
    instance has to be pinned by that instance or it is untestable folklore: xoxowildhearts QUOTING the
    closing line of a page it retired, in order to explain why it removed it.

    DIRECTION IS THE POINT, AND IT HAS ITS OWN CASE. 'this page wins' over CLAUDE.md is the law stated
    CORRECTLY, and a term-co-occurrence detector scores it identically to the inversion. The negative
    case below is what proves adjacency reads the subject of the verb rather than merely the presence of
    two words -- it is the assert that fails first if anybody ever loosens the pattern back toward
    co-occurrence, which is the design #1380 declined.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\lint\check-consumer-prose.ps1'
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\consumer-prose-sessioncheck.ps1'
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\measure-context-lib.ps1')
# check-report-lib carries the lens-discovery seams (Get-SeamPaths, Get-LensDirCandidates,
# Get-SpecialistFiles) that Get-ConsumerProseDocuments probes for kind 3 (#2188). The check script loads
# it for its sanitizers already; without it here the lens half would silently degrade to off and every
# case below would pass for the wrong reason.
. (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("consumerprose-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path (Join-Path $dir 'dkj-policy') -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function New-BareDir {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("consumerprose-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    return $dir
}

function Set-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Rel,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $target = Join-Path $Dir ($Rel -replace '/', '\')
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($target, $Text + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Get-AlwaysOnRows {
    # The always-on closure the way the check builds it: from this tree's CLAUDE.md if it has one. Both
    # detectors are handed the SAME rows, which is the merge in one line.
    param([Parameter(Mandatory = $true)][string]$Dir)
    $root = Join-Path $Dir 'CLAUDE.md'
    if (Test-Path -LiteralPath $root -PathType Leaf) {
        return @(Get-AlwaysOnDocuments -RootDocument $root -RepoRoot $Dir)
    }
    return @()
}

function Get-Mentions {
    param([Parameter(Mandatory = $true)][string]$Dir)
    return @(Get-RetiredDocNameMention -RepoRoot $Dir -Documents (Get-AlwaysOnRows -Dir $Dir))
}

function Get-Declarations {
    param([Parameter(Mandatory = $true)][string]$Dir)
    return @(Get-SupremacyDeclaration -RepoRoot $Dir -Documents (Get-AlwaysOnRows -Dir $Dir))
}

function Invoke-Script {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Dir 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

function Invoke-Hook {
    # -CheckScriptOverride defaults to the source check script: a bare test run has no
    # CLAUDE_PLUGIN_ROOT, which is the hook's only other way to find it. Pass an explicit path to
    # exercise the "not found" branch.
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$CheckScriptOverride = $Script)
    $hookArgs = @('-ConsumerPathOverride', $Dir)
    if ($CheckScriptOverride) { $hookArgs += @('-CheckScriptOverride', $CheckScriptOverride) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @hookArgs 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

$paths = Get-BranchFilePaths

try {
    # --- Get-RetiredBranchDocNames, the derivation ------------------------------------------------
    Write-Host 'Get-RetiredBranchDocNames'

    $names = @(Get-RetiredBranchDocNames)
    Assert-True ($names.Count -ge 2) 'the set is non-empty and carries more than one name'

    Assert-True (@($names | Where-Object { $_.Name -eq 'development.md' -and $_.Kind -eq 'file' }).Count -eq 1) `
        "the measured instance's own name, 'development.md', is in the set exactly once"

    Assert-True (@($names | Where-Object { $_.Name -eq 'workflow-davekjohn' -and $_.Kind -eq 'folder' }).Count -eq 1) `
        "the retired FOLDER name is in the set, derived from the pre-#886 paths rather than written out"

    $currentLeaf = [System.IO.Path]::GetFileName(((Get-BranchFilePaths -Branch 'feat/x').File -replace '/', '\'))
    Assert-True (@($names | Where-Object { $_.Name -ieq $currentLeaf }).Count -eq 0) `
        "today's document name ('$currentLeaf') is NOT reported as retired"
    Assert-True (@($names | Where-Object { $_.Name -ieq $paths.Directory }).Count -eq 0) `
        "today's folder name ('$($paths.Directory)') is NOT reported as retired"

    $lengths = @($names | ForEach-Object { $_.Name.Length })
    $sorted = @($lengths | Sort-Object -Descending)
    Assert-True ((($lengths -join ',') -eq ($sorted -join ','))) `
        'the set is longest-name-first, which the span claim in Get-RetiredDocNameMention depends on'

    Assert-True (@($names | Where-Object { -not $_.Since }).Count -eq 0) `
        'every row carries a Since line, so a finding never leaves its remedy to be derived'

    $retired = ($names | Where-Object { $_.Kind -eq 'file' } | Select-Object -First 1).Name

    # --- Get-ConsumerProseDocuments, the shared corpus ---------------------------------------------
    # It is asserted on its OWN, and ONCE, because it is the half both detectors share: a change here
    # moves what #1389 and #1415 are alike allowed to look at.
    Write-Host ''
    Write-Host 'Get-ConsumerProseDocuments'

    $bare = @(Get-ConsumerProseDocuments)
    Assert-True (@($bare | Where-Object { $_ -eq "$($paths.Directory)/CONTRIBUTING.md" }).Count -eq 1) `
        "the folder's contributor page is in the corpus with no always-on walk supplied at all"
    Assert-True (@($bare | Where-Object { $_ -match 'CHANGELOG\.md$' }).Count -eq 0) `
        'the changelog is NOT in the corpus -- a folded entry correctly states the rule of its day'
    Assert-True (@($bare | Where-Object { $_ -match '^releases/' -or $_ -match '/releases/' }).Count -eq 0) `
        'releases/ is not in the corpus either -- neither always-on nor a reserved page'

    # --- KIND 3: THE REPO LENSES (#2188) -----------------------------------------------------------
    # The corpus held one half of RANK 2 and not the other: a retired convention restated in
    # dkj-policy/README.md was reported and the identical sentence in a lens was not. These pin the
    # widening AND its seam -- -RepoRoot is what turns the walk on, which is the switch #2197 may need.
    Write-Host ''
    Write-Host 'Get-ConsumerProseDocuments -- the repo lenses (#2188)'

    $lensTree = New-Tree -Label 'lenscorpus'
    Set-Text -Dir $lensTree -Rel 'CLAUDE.md' -Text "# Consumer`n`nWe point at the shared pages."
    Set-Text -Dir $lensTree -Rel '.claude/specialists/lenses/specialist-05-05-lens.md' -Text "# Derek`n`nThis repo's answer to the branch seam."
    $lensRows = @(Get-AlwaysOnRows -Dir $lensTree)

    $withRoot = @(Get-ConsumerProseDocuments -Documents $lensRows -RepoRoot $lensTree)
    $noRoot   = @(Get-ConsumerProseDocuments -Documents $lensRows)
    Assert-True (@($withRoot | Where-Object { $_ -eq '.claude/specialists/lenses/specialist-05-05-lens.md' }).Count -eq 1) `
        'a repo lens is in the corpus when -RepoRoot is supplied -- the other half of RANK 2'
    Assert-True (@($noRoot | Where-Object { $_ -match 'lenses/' }).Count -eq 0) `
        'and it is NOT, with -RepoRoot omitted -- the seam that keeps an older caller at the two-kind corpus'

    # A lens the always-on closure already carries must appear ONCE. A duplicated path is a duplicated
    # FINDING -- the same line reported twice for one thing to repair.
    $lensImported = New-Tree -Label 'lensimported'
    Set-Text -Dir $lensImported -Rel 'CLAUDE.md' -Text "# Consumer`n`n@.claude/specialists/lenses/specialist-01-01-lens.md"
    Set-Text -Dir $lensImported -Rel '.claude/specialists/lenses/specialist-01-01-lens.md' -Text "# Chris`n`nThe orchestrator's repo lens."
    $importedCorpus = @(Get-ConsumerProseDocuments -Documents (Get-AlwaysOnRows -Dir $lensImported) -RepoRoot $lensImported)
    Assert-True (@($importedCorpus | Where-Object { $_ -match 'specialist-01-01-lens\.md$' }).Count -eq 1) `
        "a lens the root document '@'-imports is in the corpus exactly once, not once per kind"

    # --- Test-ProseCarriesAnyLiteral, the prefilter (#2188) ----------------------------------------
    # It may short-circuit a GATE, so it is asserted on its own. Lossless is the only licence it has.
    Write-Host ''
    Write-Host 'Test-ProseCarriesAnyLiteral'

    Assert-True (Test-ProseCarriesAnyLiteral -Text 'the CLAUDE.md page' -Literals @('CLAUDE.md')) `
        'a literal that is present is found'
    Assert-True (-not (Test-ProseCarriesAnyLiteral -Text 'nothing to see' -Literals @('CLAUDE.md'))) `
        'a literal that is absent is not found -- the rejection the saving rests on'
    Assert-True (Test-ProseCarriesAnyLiteral -Text 'the claude.MD page' -Literals @('CLAUDE.md')) `
        "case folding matches the detectors' own -- OrdinalIgnoreCase here, '(?i)' there"
    Assert-True (Test-ProseCarriesAnyLiteral -Text 'it wint hier' -Literals @('wins', 'wint')) `
        'any one of several literals is enough -- the OR the retired-name caller needs'
    Assert-True (-not (Test-ProseCarriesAnyLiteral -Text '' -Literals @('x'))) 'empty text carries nothing'
    Assert-True (-not (Test-ProseCarriesAnyLiteral -Text 'anything' -Literals @())) 'no literals -- nothing to carry'

    # --- The two shared fixtures -------------------------------------------------------------------
    $empty = New-Tree -Label 'empty'

    # Clean for BOTH detectors: it points at the shared pages instead of restating either convention.
    $clean = New-Tree -Label 'clean'
    Set-Text -Dir $clean -Rel 'CLAUDE.md' -Text "# Consumer`n`nThe branch document and the rank order are both described in CONTRIBUTING-portable.md. We only point at it."

    # --- Get-RetiredDocNameMention, the detector --------------------------------------------------
    Write-Host ''
    Write-Host 'Get-RetiredDocNameMention'

    Assert-True ((Get-Mentions -Dir $empty).Count -eq 0) 'a tree with no documents at all -- no findings, no throw'

    Assert-True (@(Get-RetiredDocNameMention -RepoRoot (New-BareDir -Label 'nodir')).Count -eq 0) `
        'a repo root that does not exist -- no findings, no throw'

    Assert-True ((Get-Mentions -Dir $clean).Count -eq 0) 'a consumer that POINTS instead of restating -- no findings'

    # The first measured instance: a consumer's own always-on CLAUDE.md restating the retired name.
    $retiredRoot = New-Tree -Label 'retiredroot'
    Set-Text -Dir $retiredRoot -Rel 'CLAUDE.md' -Text "# Consumer`n`nElke branch krijgt zijn eigen ``dkj-policy/$retired``."
    $f = @(Get-Mentions -Dir $retiredRoot)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq 'CLAUDE.md' -and $f[0].Line -eq 3 -and $f[0].Name -eq $retired) `
        "a retired name in the consumer's own CLAUDE.md -- one finding naming the document, the line and the name"

    # An '@'-imported document one hop down: the closure is walked, not just the root.
    $retiredImported = New-Tree -Label 'retiredimported'
    Set-Text -Dir $retiredImported -Rel 'CLAUDE.md' -Text "# Consumer`n`n@.claude/specialists/SPECIALISTS.md"
    Set-Text -Dir $retiredImported -Rel '.claude/specialists/SPECIALISTS.md' -Text "# Roster`n`nDe cyclus staat in $retired."
    $f = @(Get-Mentions -Dir $retiredImported)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq '.claude/specialists/SPECIALISTS.md') `
        "an '@'-imported always-on document is scanned too, not only the root"

    # The second measured instance, and the one #1380's detector missed: the folder's own contributor
    # page. It is NOT always-on, so it is in the set only because the lib names it.
    $retiredFolder = New-Tree -Label 'retiredfolder'
    Set-Text -Dir $retiredFolder -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nWelke scripts wonen in de plugin: zie $retired."
    $f = @(Get-Mentions -Dir $retiredFolder)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq "$($paths.Directory)/CONTRIBUTING.md") `
        'the workflow folder CONTRIBUTING.md is scanned with no CLAUDE.md present at all'

    # THE EXCLUSION THAT IS NOT OPTIONAL.
    $retiredArchive = New-Tree -Label 'retiredarchive'
    Set-Text -Dir $retiredArchive -Rel 'dkj-policy/CHANGELOG.md' -Text "# Changelog`n`n### DEPLOY: old/branch`n`nRenamed $retired at the time."
    Set-Text -Dir $retiredArchive -Rel 'dkj-policy/releases/history.md' -Text "Historic: $retired."
    Assert-True ((Get-Mentions -Dir $retiredArchive).Count -eq 0) `
        'the changelog and releases/ are never read -- a folded entry correctly names the file of its day'

    # A per-branch document is transient working prose and must not report itself.
    $retiredOwnDoc = New-Tree -Label 'retiredowndoc'
    Set-Text -Dir $retiredOwnDoc -Rel ((Get-BranchFilePaths -Branch 'feat/x').File) -Text "## feat/x`n`nThis plan discusses $retired at length."
    Assert-True ((Get-Mentions -Dir $retiredOwnDoc).Count -eq 0) `
        "a branch's own development document is not in the set, so a plan about the rename is silent"

    # Plugin-shipped payload: one file '@'-imported by every consumer, not one finding per consumer.
    $retiredExternal = New-Tree -Label 'retiredexternal'
    $extDir = New-BareDir -Label 'retiredext'
    New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    $script:trees += $extDir
    [System.IO.File]::WriteAllText((Join-Path $extDir 'persona.md'), "# Persona`n`nThe document was $retired.`n", (New-Object System.Text.UTF8Encoding($false)))
    Set-Text -Dir $retiredExternal -Rel 'CLAUDE.md' -Text ("# Consumer`n`n@" + (($extDir -replace '\\', '/') + '/persona.md'))
    $rows = @(Get-AlwaysOnDocuments -RootDocument (Join-Path $retiredExternal 'CLAUDE.md') -RepoRoot $retiredExternal)
    Assert-True (@($rows | Where-Object { $_.Source -eq 'external' }).Count -ge 1) `
        'the fixture really does produce an external row (otherwise the next assert proves nothing)'
    Assert-True (@(Get-RetiredDocNameMention -RepoRoot $retiredExternal -Documents $rows).Count -eq 0) `
        'plugin-shipped payload (Source = external) is excluded -- it is the text a consumer points AT'

    # One line, one repair: two different retired names on one line are two findings, the same name
    # twice on one line is two spans -- but no span is claimed twice.
    $retiredTwice = New-Tree -Label 'retiredtwice'
    Set-Text -Dir $retiredTwice -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`nBoth $retired and $retired appear here."
    $f = @(Get-Mentions -Dir $retiredTwice)
    Assert-True ($f.Count -eq 2 -and @($f | Where-Object { $_.Line -eq 3 }).Count -eq 2) `
        'the same retired name twice on one line -- two spans, both reported, neither doubled'

    # --- Get-SupremacyDeclaration, the detector ----------------------------------------------------
    Write-Host ''
    Write-Host 'Get-SupremacyDeclaration'

    Assert-True ((Get-Declarations -Dir $empty).Count -eq 0) 'a tree with no documents at all -- no findings, no throw'

    Assert-True (@(Get-SupremacyDeclaration -RepoRoot (New-BareDir -Label 'supnodir')).Count -eq 0) `
        'a repo root that does not exist -- no findings, no throw'

    Assert-True ((Get-Declarations -Dir $clean).Count -eq 0) 'a consumer that POINTS instead of declaring -- no findings'

    # MEASURED INSTANCE 1 -- smartwatchbanden/CLAUDE.md:22, the Dutch preamble inversion, and the one
    # #1380 named as structurally invisible: the portable page's filename sits two lines above, so every
    # pointer-based candidate suppressed it.
    $dutch = New-Tree -Label 'dutch'
    Set-Text -Dir $dutch -Rel 'CLAUDE.md' -Text "# Consumer`n`n> **Deze pagina staat bovenaan.** Bij tegenspraak wint ``CLAUDE.md``."
    $f = @(Get-Declarations -Dir $dutch)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq 'CLAUDE.md' -and $f[0].Line -eq 3) `
        'the measured Dutch inversion -- one finding naming the document and the line'
    Assert-True ($f[0].Match -match 'wint') `
        'the Dutch verb is matched, and the match is reported so the finding names what fired'

    # MEASURED INSTANCE 2 -- smartwatchbanden/dkj-policy/CONTRIBUTING.md:306, the same
    # inversion from the other side, on a page that is NOT always-on.
    $english = New-Tree -Label 'english'
    Set-Text -Dir $english -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nSo when this page and ``CLAUDE.md`` disagree, **``CLAUDE.md`` wins.**"
    $f = @(Get-Declarations -Dir $english)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq "$($paths.Directory)/CONTRIBUTING.md") `
        'the folder CONTRIBUTING.md is scanned with no CLAUDE.md present at all'
    Assert-True ($f[0].Match -match 'wins') `
        'bold markup between the tokens does not break the adjacency'

    # DIRECTION. The law stated CORRECTLY carries both terms and must NOT fire. This is the assert that
    # separates this detector from the co-occurrence design #1380 measured at 12.5% and declined.
    $correct = New-Tree -Label 'correct'
    Set-Text -Dir $correct -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nThis page sits on top of ``CLAUDE.md``, and where they disagree, this page wins."
    Assert-True ((Get-Declarations -Dir $correct).Count -eq 0) `
        'the rank order stated CORRECTLY carries both terms and does not fire -- adjacency reads direction'

    # And the near miss on the same line: a clause between the two tokens ends the adjacency, because it
    # is a different claim.
    $between = New-Tree -Label 'between'
    Set-Text -Dir $between -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nWhere ``CLAUDE.md``, which we treat as the floor, disagrees, the portable page wins."
    Assert-True ((Get-Declarations -Dir $between).Count -eq 0) `
        'a whole clause between the two tokens is not adjacency -- no finding'

    # THE ONE SUPPRESSION, pinned by the instance that produced it: xoxowildhearts quoting the closing
    # line of a page it RETIRED, to explain why it removed it. Somebody else's words, reported.
    $quoted = New-Tree -Label 'quoted'
    Set-Text -Dir $quoted -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nIts own closing line conceded the point: *`"when this page and ``CLAUDE.md`` disagree, ``CLAUDE.md`` wins.`"* It was retired."
    Assert-True ((Get-Declarations -Dir $quoted).Count -eq 0) `
        'a hit sitting wholly inside a quotation span is suppressed -- a retired page being narrated'

    # ... and the suppression is a SPAN test, not a "this line contains a quote mark" test: an unquoted
    # declaration on a line that also carries an unrelated quotation still fires.
    $mixed = New-Tree -Label 'mixed'
    Set-Text -Dir $mixed -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# Contributing`n`nWe call it the `"grondwet`" here: on any disagreement ``CLAUDE.md`` wins."
    # @() BEFORE .Count, and it is load-bearing rather than style: PowerShell unwraps a single-element
    # array on return, and under Set-StrictMode -Version Latest '.Count' on the resulting scalar THROWS
    # rather than answering 1. Every assert here that expects exactly one finding wraps first for that
    # reason -- the zero cases survive unwrapped only because $null.Count is still 0.
    Assert-True (@(Get-Declarations -Dir $mixed).Count -eq 1) `
        'an unrelated quotation elsewhere on the line does not suppress a real declaration'

    # --- WRAPPING, the false negative review found and reproduced --------------------------------
    # This repo's prose convention hard-wraps at about 100 columns, so a declaration routinely straddles
    # two physical lines. The detector matched per line until this was found, and reported NOTHING for
    # either shape below. Both are pinned, and so is the line number a finding must still resolve to --
    # a check that found the defect but named the wrong line is a check nobody can act on.
    Write-Host ''
    Write-Host 'Get-SupremacyDeclaration -- hard-wrapped prose'

    $wrapped = New-Tree -Label 'wrapped'
    Set-Text -Dir $wrapped -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`nOn any real conflict between the two, ``CLAUDE.md```nwins, and the contributing page is simply wrong."
    $f = @(Get-Declarations -Dir $wrapped)
    Assert-True ($f.Count -eq 1 -and $f[0].Line -eq 3) `
        'a declaration hard-wrapped across two lines is found, and names the line it BEGINS on'

    # THE ONE THAT MATTERS MOST: the single real instance this check exists for lives in a blockquote.
    # It sits on one physical line today, so a line-scoped detector found it -- one re-wrap of that
    # paragraph would have emptied the gate with every test still green.
    $bq = New-Tree -Label 'blockquote'
    Set-Text -Dir $bq -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n> Bij tegenspraak wint`n> ``CLAUDE.md``."
    $f = @(Get-Declarations -Dir $bq)
    Assert-True ($f.Count -eq 1 -and $f[0].Line -eq 3) `
        "a wrapped BLOCKQUOTE declaration is found -- the '>' markers are stripped, not read as text"

    # The bound on the join: a paragraph break is where a unit ends, so a gap may not bridge one.
    $across = New-Tree -Label 'across'
    Set-Text -Dir $across -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`nSomething about ``CLAUDE.md```n`nwins is a new paragraph here."
    Assert-True ((Get-Declarations -Dir $across).Count -eq 0) `
        'adjacency does not bridge a blank line -- the paragraph is the largest unit joined'

    # ... and the suppression has to survive the join too, or widening the match would have re-admitted
    # the very false positive the quotation rule was built for.
    $qWrapped = New-Tree -Label 'qwrapped'
    Set-Text -Dir $qWrapped -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`nIts closing line conceded: *`"when this page and ``CLAUDE.md```ndisagree, ``CLAUDE.md`` wins.`"* It was retired."
    Assert-True ((Get-Declarations -Dir $qWrapped).Count -eq 0) `
        'a quotation that itself wraps still suppresses -- the quote span is read on the joined unit'

    # LIST ITEMS, the regression the wrap repair introduced and review caught. A tight list has no blank
    # line between its items, and '*' is BOTH a bullet marker and the bold decoration the gap class must
    # allow -- so joining a paragraph ran two unrelated bullets together into a match present in neither.
    # All three marker shapes are pinned, not just the one that could bridge: '-' and '1.' are outside
    # the gap class today, and the assert is what keeps them safe if it is ever widened.
    Write-Host ''
    Write-Host 'Get-SupremacyDeclaration -- list items'

    $stars = New-Tree -Label 'stars'
    Set-Text -Dir $stars -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n* Read the constitution in ``CLAUDE.md```n* wins arguments only when they cite the rank order."
    Assert-True ((Get-Declarations -Dir $stars).Count -eq 0) `
        "two '*' bullets do not bridge into a declaration that exists in neither item"

    $dashes = New-Tree -Label 'dashes'
    Set-Text -Dir $dashes -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n- Read the constitution in ``CLAUDE.md```n- wins arguments only when they cite the rank order."
    Assert-True ((Get-Declarations -Dir $dashes).Count -eq 0) "'-' bullets do not bridge either"

    $numbered = New-Tree -Label 'numbered'
    Set-Text -Dir $numbered -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n1. Read the constitution in ``CLAUDE.md```n2. wins arguments only when they cite the rank order."
    Assert-True ((Get-Declarations -Dir $numbered).Count -eq 0) 'numbered items do not bridge either'

    # The other edge of the same rule: a real declaration INSIDE one bullet is still found, and so is one
    # that wraps within its own item -- the item is a unit, not a dead zone.
    $inBullet = New-Tree -Label 'inbullet'
    Set-Text -Dir $inBullet -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n* On any real conflict between the two, ``CLAUDE.md```n  wins outright.`n* Something else entirely."
    $f = @(Get-Declarations -Dir $inBullet)
    Assert-True ($f.Count -eq 1 -and $f[0].Line -eq 3) `
        'a declaration wrapped inside ONE bullet is still found, at the line it begins on'

    # And the marker test must not catch bold at the start of a line -- '**text**' has no space after the
    # first '*', which is the whole difference between a bullet and emphasis.
    $boldStart = New-Tree -Label 'boldstart'
    Set-Text -Dir $boldStart -Rel 'dkj-policy/CONTRIBUTING.md' -Text "# C`n`n**On any real conflict ``CLAUDE.md`` wins outright.**"
    Assert-True (@(Get-Declarations -Dir $boldStart).Count -eq 1) `
        "a line opening with '**bold**' is not read as a list item"

    # --- BOTH detectors over a repo LENS (#2188) ---------------------------------------------------
    # The corpus asserts above prove the path is in the set; these prove a real defect sitting in a lens
    # is actually reported, which is the whole of what #2188 asked for.
    Write-Host ''
    Write-Host 'Both detectors -- a defect in a repo lens (#2188)'

    $lensRetired = New-Tree -Label 'lensretired'
    Set-Text -Dir $lensRetired -Rel 'CLAUDE.md' -Text "# Consumer`n`nWe point at the shared pages."
    Set-Text -Dir $lensRetired -Rel '.claude/specialists/lenses/specialist-05-05-lens.md' `
        -Text "# Derek`n`nElke branch krijgt zijn eigen ``dkj-policy/$retired``."
    $f = @(Get-Mentions -Dir $lensRetired)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq '.claude/specialists/lenses/specialist-05-05-lens.md' -and $f[0].Line -eq 3) `
        'a retired name in a repo LENS is reported -- the half the always-on closure never reached'

    $lensSupremacy = New-Tree -Label 'lenssupremacy'
    Set-Text -Dir $lensSupremacy -Rel 'CLAUDE.md' -Text "# Consumer`n`nWe point at the shared pages."
    Set-Text -Dir $lensSupremacy -Rel '.claude/specialists/lenses/specialist-05-15-lens.md' `
        -Text "# Sylvester`n`nOn any real conflict ``CLAUDE.md`` wins."
    $d = @(Get-Declarations -Dir $lensSupremacy)
    Assert-True ($d.Count -eq 1 -and $d[0].Rel -eq '.claude/specialists/lenses/specialist-05-15-lens.md') `
        'an inverted supremacy declaration in a repo LENS is reported too'

    # THE PREFILTER'S LOSSLESSNESS, PINNED BY THE CASE THAT WOULD BREAK IT. The filter is a whole-TEXT
    # test precisely so a declaration hard-wrapped across two lines still survives it; a well-meaning
    # "optimisation" to a per-LINE test would pass every other case in this file and empty the gate on
    # exactly the shape #1415 built Get-ProseParagraphUnits for. This is the assert that fails first.
    $lensWrapped = New-Tree -Label 'lenswrapped'
    Set-Text -Dir $lensWrapped -Rel 'CLAUDE.md' -Text "# Consumer`n`nWe point at the shared pages."
    Set-Text -Dir $lensWrapped -Rel '.claude/specialists/lenses/specialist-06-16-lens.md' `
        -Text "# Tessa`n`nOn any real conflict between the two, ``CLAUDE.md```nwins, and the shared page is simply wrong."
    $w = @(Get-Declarations -Dir $lensWrapped)
    Assert-True ($w.Count -eq 1 -and $w[0].Line -eq 3) `
        'a declaration WRAPPED across two lines of a lens still fires -- the prefilter reads the whole text, not a line'

    # And the mirror image: a lens naming ONE half of the pattern is rejected by the prefilter and must
    # stay rejected by the detector. This is what proves the filter is not merely inert.
    $lensHalf = New-Tree -Label 'lenshalf'
    Set-Text -Dir $lensHalf -Rel 'CLAUDE.md' -Text "# Consumer`n`nWe point at the shared pages."
    Set-Text -Dir $lensHalf -Rel '.claude/specialists/lenses/specialist-06-17-lens.md' `
        -Text "# Edith`n`nThe rank order is described in ``CLAUDE.md`` and we do not restate it."
    Assert-True (@(Get-Declarations -Dir $lensHalf).Count -eq 0) `
        "a lens naming 'CLAUDE.md' with no verb beside it -- no finding, prefiltered or not"

    # --- Get-ProseParagraphUnits, on its own ------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-ProseParagraphUnits'

    $units = @(Get-ProseParagraphUnits -Lines @('# H', '', 'one', 'two', '', '> quoted', '> more'))
    Assert-True ($units.Count -eq 3) 'blank lines separate units -- heading, paragraph, blockquote'
    Assert-True ($units[1].Text -eq 'one two') 'continuation lines are joined with a single space'
    Assert-True ($units[2].Text -eq 'quoted more') "blockquote markers are stripped from every line of the unit"
    Assert-True ((Resolve-ProseUnitLine -Unit $units[1] -Offset 0) -eq 3 -and (Resolve-ProseUnitLine -Unit $units[1] -Offset 4) -eq 4) `
        'an offset resolves to the source line that contributed it, not to the unit start'

    # The empty-input edge, which is what the parameter attributes exist for: blank lines ARE the input.
    Assert-True (@(Get-ProseParagraphUnits -Lines @()).Count -eq 0) 'no lines at all -- no units, no throw'
    Assert-True (@(Get-ProseParagraphUnits -Lines @('', '', '')).Count -eq 0) 'only blank lines -- no units, no throw'

    # --- The corpus exclusions, exercised through the SECOND detector too --------------------------
    # The corpus asserts above prove the path is absent; these prove a real declaration sitting there is
    # genuinely never read. Kept per detector rather than folded, because each reads the file itself.
    Write-Host ''
    Write-Host 'Get-SupremacyDeclaration -- the shared exclusions'

    $supArchive = New-Tree -Label 'suparchive'
    Set-Text -Dir $supArchive -Rel 'dkj-policy/CHANGELOG.md' -Text "# Changelog`n`n### DEPLOY: old/branch`n`nBack then ``CLAUDE.md`` wins was the rule."
    Set-Text -Dir $supArchive -Rel 'dkj-policy/releases/history.md' -Text "Historic: ``CLAUDE.md`` wins."
    Assert-True ((Get-Declarations -Dir $supArchive).Count -eq 0) `
        'the changelog and releases/ are never read -- a folded entry correctly states the rule of its day'

    # A per-branch document is transient working prose and must not report itself -- this very branch's
    # document discusses the inversion at length.
    $supOwnDoc = New-Tree -Label 'supowndoc'
    Set-Text -Dir $supOwnDoc -Rel ((Get-BranchFilePaths -Branch 'feat/x').File) -Text "## feat/x`n`nThe defect is a line saying ``CLAUDE.md`` wins over the contributing page."
    Assert-True ((Get-Declarations -Dir $supOwnDoc).Count -eq 0) `
        "a branch's own development document is not in the set, so a plan about the defect is silent"

    # Plugin-shipped payload: one file '@'-imported by every consumer, not one finding per consumer.
    $supExternal = New-Tree -Label 'supexternal'
    $supExtDir = New-BareDir -Label 'supext'
    New-Item -ItemType Directory -Path $supExtDir -Force | Out-Null
    $script:trees += $supExtDir
    [System.IO.File]::WriteAllText((Join-Path $supExtDir 'persona.md'), "# Persona`n`nOn a disagreement ``CLAUDE.md`` wins.`n", (New-Object System.Text.UTF8Encoding($false)))
    Set-Text -Dir $supExternal -Rel 'CLAUDE.md' -Text ("# Consumer`n`n@" + (($supExtDir -replace '\\', '/') + '/persona.md'))
    $rows = @(Get-AlwaysOnDocuments -RootDocument (Join-Path $supExternal 'CLAUDE.md') -RepoRoot $supExternal)
    Assert-True (@($rows | Where-Object { $_.Source -eq 'external' }).Count -ge 1) `
        'the fixture really does produce an external row (otherwise the next assert proves nothing)'
    Assert-True (@(Get-SupremacyDeclaration -RepoRoot $supExternal -Documents $rows).Count -eq 0) `
        'plugin-shipped payload (Source = external) is excluded -- it is the text a consumer points AT'

    # An '@'-imported document one hop down: the closure is walked, not just the root.
    $supImported = New-Tree -Label 'supimported'
    Set-Text -Dir $supImported -Rel 'CLAUDE.md' -Text "# Consumer`n`n@.claude/specialists/SPECIALISTS.md"
    Set-Text -Dir $supImported -Rel '.claude/specialists/SPECIALISTS.md' -Text "# Roster`n`nBij tegenspraak wint ``CLAUDE.md``."
    $f = @(Get-Declarations -Dir $supImported)
    Assert-True ($f.Count -eq 1 -and $f[0].Rel -eq '.claude/specialists/SPECIALISTS.md') `
        "an '@'-imported always-on document is scanned too, not only the root"

    # --- check-consumer-prose.ps1, the gate --------------------------------------------------------
    Write-Host ''
    Write-Host 'check-consumer-prose.ps1'

    $r = Invoke-Script -Dir $clean
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\] no retired branch-document name and no inverted supremacy declaration') `
        'clean consumer fixture -- one [OK] covering both detectors, exit 0'

    $r = Invoke-Script -Dir $retiredRoot
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match [regex]::Escape($retired) -and $r.Out -match 'CLAUDE\.md:3') `
        'a restatement present -- [ERROR] exit 1, naming the document, the line and the retired name'
    Assert-True ($r.Out -match 'POINT at a shared convention' -and $r.Out -match 'CONTRIBUTING-portable\.md') `
        'the retired-name finding names the remedy and the page the rule lives on'
    Assert-True ($r.Out -notmatch 'THE ORDER RUNS THE OTHER WAY') `
        'and the OTHER detector stays silent -- one block per defect actually present, never both by default'

    $r = Invoke-Script -Dir $dutch
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -match 'CLAUDE\.md:3') `
        'a declaration present -- [ERROR] exit 1, naming the document and the line'
    Assert-True ($r.Out -match 'THE ORDER RUNS THE OTHER WAY' -and $r.Out -match 'CONTRIBUTING-portable\.md') `
        'the supremacy finding names the remedy and the page the rank order lives on'
    Assert-True ($r.Out -match 'SEAM answer') `
        'the finding names the sanctioned route for a repo that really does want its own page to lead'
    Assert-True ($r.Out -notmatch 'POINT at a shared convention') `
        'and the retired-name block stays silent on a tree carrying only the inversion'

    # THE ASSERT THE MERGE EXISTS FOR. One invocation, both defects, BOTH blocks -- the first finding
    # must not short-circuit the second, or a session start reports one defect and hides the other.
    $both = New-Tree -Label 'both'
    Set-Text -Dir $both -Rel 'CLAUDE.md' -Text "# Consumer`n`nElke branch krijgt zijn eigen ``dkj-policy/$retired``.`n`n> **Deze pagina staat bovenaan.** Bij tegenspraak wint ``CLAUDE.md``."
    $r = Invoke-Script -Dir $both
    Assert-True ($r.Code -eq 1) 'a tree carrying BOTH defects -- exit 1'
    Assert-True ($r.Out -match 'POINT at a shared convention' -and $r.Out -match 'THE ORDER RUNS THE OTHER WAY') `
        'ONE run reports BOTH blocks -- neither detector short-circuits the other'
    Assert-True (([regex]::Matches($r.Out, '\[ERROR\]')).Count -eq 2) `
        'and it emits exactly two [ERROR] markers, one per detector, so the hook surfaces both'
    Assert-True ($r.Out -match [regex]::Escape($retired) -and $r.Out -match 'CLAUDE\.md:5') `
        'both findings name their own line in the same document'

    # WHAT THE REPORT ECHOES OUT OF THE CONSUMER'S OWN FILE IS SANITIZED (#1419). The hook forwards this
    # whole report into session context and decides what to surface by matching '[ERROR]' over it, so a
    # raw echo lets a consumer's own line choose how loudly it is reported -- and paint a terminal on the
    # way past. Asserted end to end rather than only on the helper, because the defect was never in the
    # helper: it was this script printing around it. Both blocks are exercised, because they print
    # different values: the retired-name one mixes the consumer's text with the PLUGIN'S own strings,
    # which stay raw, while every value in the supremacy one is the consumer's.
    $retiredForged = New-Tree -Label 'retiredforged'
    Set-Text -Dir $retiredForged -Rel 'CLAUDE.md' -Text ("# C`n`nWe keep $retired here$([char]27)[31m, and also [ERROR] forged.")
    $r = Invoke-Script -Dir $retiredForged
    Assert-True ($r.Code -eq 1 -and ([regex]::Matches($r.Out, '\[ERROR\]')).Count -eq 1) `
        "a forged '[ERROR]' in the consumer's own line cannot add a second marker to the retired-name block"
    Assert-True (-not $r.Out.Contains([char]27)) `
        'an ESC in that line never reaches the terminal'
    Assert-True ($r.Out -match '\(ERROR\)') `
        'the bracketed text is still legible -- substituted, not deleted, so the reader recognises the line'
    Assert-True ($r.Out -match 'shown sanitized') `
        'and the preview says it was altered, so nobody hunts for text that is not in the file'
    Assert-True ($r.Out -match 'square brackets are shown as round ones') `
        'the footer discloses the substitution, which carries no per-line note of its own'

    $supForged = New-Tree -Label 'supforged'
    Set-Text -Dir $supForged -Rel 'CLAUDE.md' -Text ("# Consumer`n`nHere ``CLAUDE.md`` wins$([char]27)[31m, and also [ERROR] forged.")
    $r = Invoke-Script -Dir $supForged
    Assert-True ($r.Code -eq 1 -and ([regex]::Matches($r.Out, '\[ERROR\]')).Count -eq 1) `
        "a forged '[ERROR]' in the consumer's own line cannot add a second marker to the supremacy block"
    Assert-True (-not $r.Out.Contains([char]27)) `
        'an ESC in that line never reaches the terminal, in the supremacy block either'
    Assert-True ($r.Out -match '\(ERROR\)' -and $r.Out -match 'shown sanitized') `
        'the matched phrase and the echoed line are both substituted, not deleted'

    # THE SKIP, and it is measured on a real marketplace file rather than asserted about this repo: the
    # same tree answers [ERROR] twice without one and [OK] with one -- so the skip covers BOTH detectors.
    #
    # BOTH DIRECTIONS SINCE #1422: the skip narrowed from "publishes plugins" to
    # Test-IsWorkflowSourceRepo's "publishes THIS workflow", so a manifest publishing somebody else's
    # product is a consumer and is judged. The negative case is asserted first, being the one the old
    # broad file test would have passed as [OK] -- and here it must still produce BOTH blocks.
    New-Item -ItemType Directory -Path (Join-Path $both '.claude-plugin') -Force | Out-Null
    Set-Text -Dir $both -Rel '.claude-plugin/marketplace.json' -Text '{ "name": "fixture", "plugins": [ { "name": "some-other-product" } ] }'
    $r = Invoke-Script -Dir $both
    Assert-True ($r.Code -eq 1 -and ([regex]::Matches($r.Out, '\[ERROR\]')).Count -eq 2) `
        'a repo publishing ANOTHER product is a consumer of this workflow -- both detectors still judged, not skipped'

    Set-Text -Dir $both -Rel '.claude-plugin/marketplace.json' -Text '{ "name": "fixture", "plugins": [ { "name": "dkj-policy" } ] }'
    $r = Invoke-Script -Dir $both
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'publishes the workflow') `
        'a repo that publishes THIS workflow is skipped -- and the skip silences both detectors at once'

    # --- consumer-prose-sessioncheck.ps1, the hook (always exit 0) ---------------------------------
    Write-Host ''
    Write-Host 'consumer-prose-sessioncheck.ps1'

    $r = Invoke-Hook -Dir $clean
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no retired branch-document name and no inverted supremacy declaration') `
        'clean consumer -- the in-sync line, exit 0'

    $r = Invoke-Hook -Dir $retiredFolder
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'contradicts the plugin' -and $r.Out -match [regex]::Escape($retired)) `
        'a restatement present -- a compact summary carrying the [ERROR] detail, still exit 0'

    $r = Invoke-Hook -Dir $english
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'contradicts the plugin' -and $r.Out -match '\[ERROR\]') `
        'a declaration present -- a compact summary carrying the [ERROR] detail, still exit 0'

    $r = Invoke-Hook -Dir $clean -CheckScriptOverride (Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1")
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') `
        'check script missing -- a notice, exit 0, never a strand'

    # --- the constitution import (#2374) -----------------------------------------------------------
    Write-Host ''
    Write-Host 'constitution import (#2374)'
    . (Join-Path $RepoRoot 'scripts\lib\consumer-check-lib.ps1')

    Assert-True ((Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\claude-code-specialists\dkj-policy\5.7.0\scripts\lib') -eq '@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/CLAUDE.md') `
        'the marketplace segment is read off a cache-shaped location -- a pre-rename consumer gets ITS clone name'
    Assert-True ((Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\[ERROR] forged name\dkj-policy\5.7.0\scripts\lib') -eq '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md') `
        'a marketplace segment that is not a plain slug is never printed -- the canonical name stands in'
    Assert-True ((Get-ConstitutionImportLine -LibDir (Join-Path $RepoRoot 'scripts\lib')) -eq '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md') `
        'anywhere else the canonical marketplace name is used'

    # $clean carries no import: the gap is WARNED, and the exit code the two detectors own is untouched.
    $r = Invoke-Script -Dir $clean
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[WARNING\] this repo''s CLAUDE\.md does not import the dkj-policy constitution' -and
                 $r.Out -match [regex]::Escape('/plugins/dkj-policy/CLAUDE.md')) `
        'no import -- a [WARNING] carrying the paste-ready line, and still exit 0'

    # The absolute line, unresolved on this machine: the written line is what counts, not the clone.
    $imported = New-Tree -Label 'constimported'
    Set-Text -Dir $imported -Rel 'CLAUDE.md' -Text "# Consumer`n`n@~/.claude/plugins/marketplaces/no-such-mkt-$PID/plugins/dkj-policy/CLAUDE.md`n`nThis repo's trunk is main."
    $rows = @(Get-AlwaysOnRows -Dir $imported)
    Assert-True (Test-ConstitutionImported -Documents $rows) `
        'an absolute import counts even where the clone has not refreshed yet (Exists = false)'
    $r = Invoke-Script -Dir $imported
    Assert-True ($r.Code -eq 0 -and $r.Out -notmatch '\[WARNING\]' -and $r.Out -match '\[OK\]') `
        'import present -- no warning, the ordinary [OK]'

    Assert-True (-not (Test-ConstitutionImported -Documents @())) 'an empty closure imports nothing'

    $r = Invoke-Hook -Dir $clean
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no inverted supremacy declaration' -and $r.Out -match 'does not import the dkj-policy constitution' -and
                 $r.Out -match [regex]::Escape('/plugins/dkj-policy/CLAUDE.md')) `
        'the hook forwards the warning and its paste-ready line beside the clean line, still exit 0'
    $r = Invoke-Hook -Dir $imported
    Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'does not import') `
        'the hook stays quiet about the import where the line is there'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
