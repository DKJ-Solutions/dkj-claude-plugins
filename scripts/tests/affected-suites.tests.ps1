<#
.SYNOPSIS
    Tests for the affected-suite selection -- issue #3223: open-pr's local test gate runs the suites a
    branch's changes can affect, and leaves the whole pool to the required CI check.

.DESCRIPTION
    The selection lives in scripts/lib/gate-lib.ps1 (ConvertTo-SuiteReference, Get-SuiteReferenceSet,
    Test-SuiteReferenceMatch, Get-GateChangedPaths, Get-AffectedSuiteSelection, and the -SelectSuites
    branch of Invoke-WorkflowGates) and in Invoke-TestSuiteGate's -SuiteNames parameter in
    native-capture-lib.ps1. A suite of its own rather than more cases in gate-lib.tests.ps1, so the pool
    can run it in a lane of its own.

    WRITTEN FROM THE SIDE THAT FAILS SILENTLY. A selection that runs too much costs time; one that runs
    too little reports green over a suite it never ran. So most cases here assert that a suite IS
    selected, that the run falls back to the whole pool where the mapping is not proven, and that a
    selected run records no gate evidence. The three asymmetries the map rests on each get a case: a
    comment is no reference, a library that LISTS a script does not run it, and a suite that walks the
    live tree runs every time.

    A REAL GIT REPOSITORY PER FIXTURE, for the reason gate-lib.tests.ps1 gives: the selection reads
    `git ls-files --stage` and a merge-base, and a stub would prove only that the parser agrees with it.

    Dependency-free (no Pester), same style as the rest of the suite.
#>

# What this suite's live-tree walk reads (#3309): the suites and helpers in scripts/tests, for the scope guard.
# gate-selection: walks scripts/tests/*.ps1
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$LibPath = Join-Path $RepoRoot 'scripts\lib\gate-lib.ps1'
$NativeLibPath = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'

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

. $LibPath

$FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "affected-suites-tests-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$script:seq = 0

function Invoke-FixtureGit {
    # Git mutations under EAP=Continue, judged by fixture-git-lib -- gate-lib.tests.ps1 says why both.
    param([string]$Dir, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitNative -Arguments (@('-C', $Dir) + @($GitArgs))
    } finally { $ErrorActionPreference = $prev }
}

function Set-FixtureFile {
    param([string]$Dir, [string]$Name, [string]$Content)
    $full = Join-Path $Dir $Name
    New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
    [System.IO.File]::WriteAllText($full, $Content, $Utf8NoBom)
}

function New-SelectionFixture {
    <#
        A small repo shaped like this one: libs that dot-source each other, a registry lib that LISTS a
        tool without running it, and five suites -- one per relationship the selection has to get right.
        Committed on 'main', then a 'feature' branch is checked out with nothing changed yet.
    #>
    $script:seq++
    $dir = Join-Path $FixtureRoot "repo-$script:seq"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-FixtureGit -Dir $dir 'init' '-q'
    Invoke-FixtureGit -Dir $dir 'config' 'core.autocrlf' 'false'
    Invoke-FixtureGit -Dir $dir 'config' 'user.email' 'tycho@example.test'
    Invoke-FixtureGit -Dir $dir 'config' 'user.name' 'Tycho'
    Invoke-FixtureGit -Dir $dir 'config' 'commit.gpgsign' 'false'

    Set-FixtureFile $dir 'scripts/lib/a-lib.ps1' ". (Join-Path `$PSScriptRoot 'b-lib.ps1')`nfunction Get-A { 'a' }`n"
    Set-FixtureFile $dir 'scripts/lib/b-lib.ps1' "# b-lib names ghost-lib.ps1 in a comment, which is no reference`nfunction Get-B { 'b' }`n"
    Set-FixtureFile $dir 'scripts/lib/registry-lib.ps1' "`$script:Tools = @('scripts/task/c-tool.ps1')`n`$script:Data = Join-Path `$PSScriptRoot '..\..\docs\data.json'`n`$script:Seam = 'README.md'`n"
    Set-FixtureFile $dir 'scripts/task/c-tool.ps1' "Write-Output 'c'`n"
    Set-FixtureFile $dir 'docs/data.json' "{}`n"
    Set-FixtureFile $dir 'README.md' "# fixture`n"
    Set-FixtureFile $dir 'scripts/tests/a.tests.ps1' ". (Join-Path `$PSScriptRoot '..\lib\a-lib.ps1')`nexit 0`n"
    Set-FixtureFile $dir 'scripts/tests/c.tests.ps1' "& powershell -NoProfile -File (Join-Path `$PSScriptRoot '..\task\c-tool.ps1')`nexit 0`n"
    Set-FixtureFile $dir 'scripts/tests/reg.tests.ps1' ". (Join-Path `$PSScriptRoot '..\lib\registry-lib.ps1')`nexit 0`n"
    Set-FixtureFile $dir 'scripts/tests/walk.tests.ps1' "`$RepoRoot = (Resolve-Path (Join-Path `$PSScriptRoot '..\..')).Path`n`$all = Get-ChildItem -LiteralPath `$RepoRoot -Recurse -File`nexit 0`n"
    Set-FixtureFile $dir 'scripts/tests/plain.tests.ps1' "exit 0`n"
    Invoke-FixtureGit -Dir $dir 'add' '-A'
    Invoke-FixtureGit -Dir $dir 'commit' '-qm' 'init'
    Invoke-FixtureGit -Dir $dir 'branch' '-M' 'main'
    Invoke-FixtureGit -Dir $dir 'checkout' '-q' '-b' 'feature'
    return $dir
}

function Get-SelectedNames {
    param($Verdict)
    return (@($Verdict.Suites | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' } | Sort-Object) -join ',')
}

try {
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null

    # --- 1. a reference, reduced to the tail a tracked path can end with --------------------------
    Write-Host "`n== 1. ConvertTo-SuiteReference ==" -ForegroundColor Cyan
    Assert-Equal 'lib/gate-lib.ps1' (ConvertTo-SuiteReference -Value '..\lib\gate-lib.ps1') "'..' segments drop out and backslashes turn"
    Assert-Equal 'lib/x-lib.ps1' (ConvertTo-SuiteReference -Value '$PSScriptRoot\..\lib\x-lib.ps1' -Expandable) 'an expandable string keeps only what follows its last variable'
    Assert-Equal '' (ConvertTo-SuiteReference -Value '$Name.ps1' -Expandable) 'a leaf built from a variable names no file'
    Assert-Equal '' (ConvertTo-SuiteReference -Value 'see the README.md file') 'prose with spaces is no reference'
    Assert-Equal '' (ConvertTo-SuiteReference -Value '*.tests.ps1') 'neither is a wildcard'
    Assert-Equal 'release-lib' (ConvertTo-SuiteReference -Value 'release-lib') 'a bare kebab name is kept -- the form a list of lib names takes'
    Assert-Equal 'plugins/dkj-policy/claude.md' (ConvertTo-SuiteReference -Value 'plugins\dkj-policy\CLAUDE.md') 'and the result is lower case'
    Assert-Equal '.gitignore' (ConvertTo-SuiteReference -Value '.gitignore') 'a dotfile is a file (Victor: the first pattern dropped it)'
    Assert-Equal 'license' (ConvertTo-SuiteReference -Value 'LICENSE') 'and so is an extensionless name'

    # --- 2. what one file runs, reads, and walks ---------------------------------------------------
    Write-Host "`n== 2. Get-SuiteReferenceSet ==" -ForegroundColor Cyan
    $src = @'
# ghost-lib.ps1 is only named in this comment
. (Join-Path $PSScriptRoot 'a-lib.ps1')
$lib = Join-Path $PSScriptRoot 'b-lib.ps1'
if (Test-Path $lib) { . $lib }
$list = @('c-tool.ps1', 'docs/data.json')
& powershell -NoProfile -File (Join-Path $PSScriptRoot 'd-tool.ps1')
'@
    $set = Get-SuiteReferenceSet -Text $src
    Assert-True $set.Parsed 'a well-formed file parses'
    Assert-True ($set.Run.Contains('a-lib.ps1')) 'a dot-sourced file is RUN'
    Assert-True ($set.Run.Contains('b-lib.ps1')) 'and so is one dot-sourced through a variable assigned a statement earlier'
    Assert-True ($set.Run.Contains('d-tool.ps1')) 'and one handed to -File'
    Assert-True (-not $set.Run.Contains('c-tool.ps1')) 'a script that is only LISTED is not run'
    Assert-True ($set.Read.Contains('c-tool.ps1')) 'but it is read'
    Assert-True ($set.Read.Contains('docs/data.json')) 'and a data path keeps its directory'
    Assert-True (-not $set.Read.Contains('ghost-lib.ps1') -and -not $set.Run.Contains('ghost-lib.ps1')) 'a name in a comment is no reference at all'
    Assert-True (-not $set.Walks) 'naming files is not walking the tree'

    $walkDirect = Get-SuiteReferenceSet -Text "Get-ChildItem -Path (Join-Path `$RepoRoot 'scripts') -Recurse -Filter *.ps1`n"
    Assert-True $walkDirect.Walks 'a Get-ChildItem over a path built from $RepoRoot walks the live tree'
    $walkDerived = Get-SuiteReferenceSet -Text "`$root = Join-Path `$RepoRoot 'plugins'`n`$dir = Join-Path `$root 'x'`nGet-ChildItem -LiteralPath `$dir -Recurse`n"
    Assert-True $walkDerived.Walks 'and so does one through a variable derived from a variable derived from it'
    $walkGit = Get-SuiteReferenceSet -Text "`$tracked = @(& git -C `$RepoRoot ls-files -- '*.md')`n"
    Assert-True $walkGit.Walks 'and a git ls-files on the live repo'
    $walkScriptRoot = Get-SuiteReferenceSet -Text "`$scriptsRoot = Resolve-Path (Join-Path `$PSScriptRoot '..')`nGet-ChildItem -LiteralPath `$scriptsRoot -Recurse -Filter *.ps1`n"
    Assert-True $walkScriptRoot.Walks 'a walk rooted at $PSScriptRoot is a walk of the live tree too (Victor: native-capture, release-lib)'
    $walkPairs = Get-SuiteReferenceSet -Text "`$pairs = @(Get-SharedScriptPairs -RepoRoot `$RepoRoot)`n"
    Assert-True $walkPairs.Walks 'and so is handing the live root to a lib function that enumerates it'
    $walkFixture = Get-SuiteReferenceSet -Text "`$Fixture = Join-Path `$env:TEMP 'f'`nGet-ChildItem -LiteralPath `$Fixture -Recurse`n"
    Assert-True (-not $walkFixture.Walks) 'a walk over a fixture is not a walk over the live tree'
    $walkMarked = Get-SuiteReferenceSet -Text "# gate-selection: always`nexit 0`n"
    Assert-True $walkMarked.Walks "a suite can declare its walk with '# gate-selection: always'"
    # OPEN WALKS (#3316, ported from PR #3313): a walk is open unless a constant in a filtering position names a type.
    Assert-True $walkMarked.WalksOpen 'and a declared walk is OPEN, since nobody can read what it returns'
    Assert-True (-not $walkDirect.WalksOpen) 'a recursive walk with -Filter is narrowed to a type, so not open'
    Assert-True $walkDerived.WalksOpen 'a recursive walk with no filter at all is open'
    Assert-True (-not $walkGit.WalksOpen) 'a git ls-files with a typed pathspec is not open'
    Assert-True (Get-SuiteReferenceSet -Text "& git -C `$RepoRoot ls-files`n").WalksOpen 'and one with no pathspec lists every type, so it is'
    Assert-True (Get-SuiteReferenceSet -Text "gci `$RepoRoot -r`n").WalksOpen 'an alias and an abbreviated -Recurse are read the same'
    Assert-True (-not (Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot '*.md' -Recurse`n").WalksOpen) 'a positional wildcard naming a type is a filter'
    Assert-True (Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot -Recurse -Exclude '*.tmp'`n").WalksOpen 'but a type handed to -Exclude narrows nothing'
    Assert-True (Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot -File`n").WalksOpen 'a walk that does not recurse is still open: it lists every type at the top'
    Assert-True (Get-SuiteReferenceSet -Text "& git -C `$RepoRoot grep -n 'a.*b'`n").WalksOpen 'a regex with a star is no pathspec, so a git grep without -- stays open'
    Assert-True (-not (Get-SuiteReferenceSet -Text "& git -C `$RepoRoot grep -n 'a.*b' -- '*.ps1'`n").WalksOpen) 'and a pathspec after -- narrows it'
    Assert-True (Get-SuiteReferenceSet -Text "`$f = [System.IO.Directory]::EnumerateFiles(`$RepoRoot, '*', 'AllDirectories')`n").WalksOpen 'a .NET file listing with a typeless pattern is open'
    Assert-True (-not (Get-SuiteReferenceSet -Text "`$f = [System.IO.Directory]::GetFiles(`$RepoRoot, '*.md')`n").WalksOpen) 'and one with a typed pattern is not'
    Assert-True (Get-SuiteReferenceSet -Text "Copy-Item `$RepoRoot `$tmp -Recurse`n").WalksOpen 'copying the whole tree is open'
    Assert-True (Get-SuiteReferenceSet -Text "Get-ChildItem (Join-Path `$RepoRoot 'plugins/*/skills') -Recurse`n").WalksOpen 'a star in a DIRECTORY segment names no type'
    Assert-True (Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot -Recurse -Filter `$pattern`n").WalksOpen 'a filter held in a variable is not provable, so the walk stays open'
    Assert-True (-not (Get-SuiteReferenceSet -Text "Get-ChildItem -LiteralPath `$RepoRoot -Recurse -Filter 'hooks.json'`n").WalksOpen) 'a named manifest narrows to its type'
    Assert-True (-not (Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot -Recurse -Include @('*.ps1', '*.md')`n").WalksOpen) 'and so does an -Include list'
    Assert-True (Get-SuiteReferenceSet -Text "& git.exe -C `$RepoRoot ls-files`n").WalksOpen "the command name 'git.exe' is not read as a type"
    Assert-True (-not (Get-SuiteReferenceSet -Text "Get-ChildItem -LiteralPath `$RepoRoot -Directory`n").WalksOpen) 'a -Directory listing returns no file, so it is not open'
    Assert-True (Get-SuiteReferenceSet -Text "Get-ChildItem -LiteralPath `$RepoRoot -Depth 1`n").WalksOpen "and -Depth is not read as -Directory"
    Assert-True (-not $walkFixture.WalksOpen) 'and an unfiltered walk over a fixture is no walk of the live tree at all'
    $scopedSet = Get-SuiteReferenceSet -Text "# gate-selection: walks *.PS1 plugins\x\plugin.json`n# gate-selection: walks *.ps1`nexit 0`n"
    Assert-True $scopedSet.Walks "a '# gate-selection: walks' line declares a walk on its own (#3309)"
    Assert-Equal '*.ps1|plugins/x/plugin.json' (@($scopedSet.Scope) -join '|') 'and its patterns are the scope: lower case, forward slashes, every line, each once'
    Assert-Equal 0 @($walkDirect.Scope).Count 'a walk nobody declared has no scope -- unbounded'
    $bothSet = Get-SuiteReferenceSet -Text "# gate-selection: always`n# gate-selection: walks *.ps1`nexit 0`n"
    Assert-True ($bothSet.Walks -and @($bothSet.Scope).Count -eq 0) "a file that says 'always' as well keeps no scope: the safe line wins"
    $broken = Get-SuiteReferenceSet -Text "function Broken {`n"
    Assert-True (-not $broken.Parsed) 'a file that does not parse is reported as unparsed, never as empty'

    # --- 3. matching a path against a reference -----------------------------------------------------
    Write-Host "`n== 3. Test-SuiteReferenceMatch ==" -ForegroundColor Cyan
    Assert-True (Test-SuiteReferenceMatch -Path 'scripts/lib/gate-lib.ps1' -Reference 'lib/gate-lib.ps1') 'a reference with a directory matches the tail of a path'
    Assert-True (Test-SuiteReferenceMatch -Path 'plugins/x/scripts/lib/gate-lib.ps1' -Reference 'lib/gate-lib.ps1') 'including a mirror under a plugin -- over-selecting is the safe direction'
    Assert-True (-not (Test-SuiteReferenceMatch -Path 'scripts/mylib/gate-lib.ps1' -Reference 'lib/gate-lib.ps1')) 'but only at a segment boundary'
    Assert-True (-not (Test-SuiteReferenceMatch -Path 'plugins/a/claude.md' -Reference 'plugins/b/claude.md')) 'a qualified reference does not match a namesake elsewhere'
    Assert-True (Test-SuiteReferenceMatch -Path 'scripts/lib/release-lib.ps1' -Reference 'release-lib') "a bare kebab name matches that name with '.ps1'"

    Write-Host "`n== 3b. Test-WalkScopeMatch ==" -ForegroundColor Cyan
    Assert-True (Test-WalkScopeMatch -Path 'scripts/lib/deep/x.ps1' -Pattern '*.ps1') 'a pattern without a directory matches the leaf at any depth'
    Assert-True (-not (Test-WalkScopeMatch -Path 'web/src/styles.css' -Pattern '*.ps1')) 'and nothing with another extension -- the saving'
    Assert-True (Test-WalkScopeMatch -Path 'scripts/release/open-pr.ps1' -Pattern 'scripts/*.ps1') 'a pattern with a directory matches the whole path, and * crosses folders'
    Assert-True (-not (Test-WalkScopeMatch -Path 'plugins/p/scripts/x.ps1' -Pattern 'scripts/*.ps1')) 'but is anchored at the root'
    Assert-True (Test-WalkScopeMatch -Path 'plugins/p/.claude-plugin/plugin.json' -Pattern 'plugin.json') 'a bare file name matches that file wherever it sits'

    # THE SCOPE GUARD, over this repo's own suites (#3309, #3392). A declared scope is a claim the
    # selection cannot check, and since #3392 CI's asset-only selection trusts it to DROP a walker, where a
    # wrong one is an ungated merge. So every part a reading CAN check is held here: each live-tree walk's
    # samples -- its root, resolved through the variables it is built from, plus each type it filters on,
    # or any type at all for an open walk -- must fall inside the scope the file declares. A walk added
    # later outside it, by root or by type, fails here, not on CI.
    Write-Host "`n== 3c. declared scopes cover their own walks ==" -ForegroundColor Cyan
    $samplesOf = { param([string]$Text) @((Get-SuiteReferenceSet -Text $Text -SuiteDirectory 'scripts/tests').WalkSamples) -join '|' }
    Assert-Equal 'x/x.ps1|x/x.yml' (& $samplesOf "Get-ChildItem -LiteralPath (Join-Path `$RepoRoot 'x') -Recurse -Include '*.ps1', '*.yml' -File`n`$s = Join-Path `$env:TEMP 'f'`nGet-ChildItem -LiteralPath `$s -Filter '*.txt'`n") "a live walk samples its root and each filter, and a fixture walk samples nothing"
    Assert-Equal 'plugins/p/x.gate-any' (& $samplesOf "Copy-Item -Path (Join-Path `$RepoRoot 'plugins\p') -Destination `$tmp -Recurse`n") 'a recursive Copy-Item is a walk of its source, of any type'
    Assert-Equal 'scripts/x.ps1' (& $samplesOf "`$scriptsRoot = (Resolve-Path (Join-Path `$PSScriptRoot '..')).Path`nGet-ChildItem -LiteralPath `$scriptsRoot -Recurse -Filter '*.ps1'`n") 'a root built from $PSScriptRoot resolves against the suite directory, through a variable'
    Assert-Equal 'plugins/x.ps1|scripts/x.ps1' (& $samplesOf "foreach (`$root in @('scripts', 'plugins')) { Get-ChildItem -LiteralPath (Join-Path `$RepoRoot `$root) -Recurse -Filter '*.ps1' }`n") 'a foreach over a constant list samples every root in it'
    Assert-Equal '.github/workflows/x.yml|scripts/x.yml' (& $samplesOf "`$roots = @('scripts', '.github\workflows') | ForEach-Object { Join-Path `$RepoRoot `$_ } | Where-Object { Test-Path `$_ }`nGet-ChildItem -LiteralPath `$roots -Recurse -Include '*.yml'`n") 'and so does a ForEach-Object over one, past a filtering stage'
    Assert-Equal 'a/b/x-persona.md' (& $samplesOf "`$src = Join-Path `$RepoRoot 'a\b\c-persona.md'`nGet-ChildItem -LiteralPath (Split-Path `$src -Parent) -Filter '*-persona.md'`n") 'Split-Path resolves to the parent'
    Assert-Equal 'x.gate-any' (& $samplesOf "`$d = Get-Something`n`$all = Join-Path `$RepoRoot `$d`nGet-ChildItem -LiteralPath `$all -Recurse`n") 'an unresolved root samples from no directory'
    Assert-Equal 'x.md' (& $samplesOf "`$d = if (`$a) { Join-Path `$RepoRoot 'a' } else { Join-Path `$RepoRoot 'b' }`nGet-ChildItem -LiteralPath `$d -Filter '*.md'`n") 'and so does one assigned through a statement it cannot read'
    Assert-Equal 'x.md' (& $samplesOf "`$r = @('scripts')`n`$r += 'plugins'`nforeach (`$x in `$r) { Get-ChildItem -LiteralPath (Join-Path `$RepoRoot `$x) -Recurse -Filter '*.md' }`n") "a '+=' write makes the variable unresolved, not its first value alone (Victor)"
    Assert-Equal 'x.md' (& $samplesOf "`$d = 'scripts'`nSet-Variable d 'plugins'`nGet-ChildItem -LiteralPath (Join-Path `$RepoRoot `$d) -Filter '*.md'`n") 'and so does a Set-Variable'
    Assert-Equal 'a/x.gate-any|b/x.gate-any' (& $samplesOf "`$dirs = @((Join-Path `$RepoRoot 'a'), (Join-Path `$RepoRoot 'b'))`nforeach (`$d in `$dirs) { Get-ChildItem `$d -Recurse }`n") 'a foreach over live paths is a live walk through its loop variable'
    Assert-True (Get-SuiteReferenceSet -Text "Copy-Item `$RepoRoot `$tmp -r`n").Walks 'an abbreviated -Recurse makes a Copy-Item a walk'
    Assert-True (Get-SuiteReferenceSet -Text "& git -C `$RepoRoot ls-files -- ':!*.md'`n").WalksOpen 'a git exclude pathspec narrows nothing, so the walk stays open'
    Assert-Equal '' (& { $set = Get-SuiteReferenceSet -Text "Get-ChildItem `$RepoRoot -Recurse`n"; @($set.WalkSamples) -join '|' }) 'without -SuiteDirectory no samples are computed -- the selection never reads them'
    # THE SHAPES THE WALK READING USED TO MISS (#3397): each is a live walk, sampled at its root, and the
    # same shape over a fixture is no walk at all.
    Assert-Equal 'plugins/x.md' (& $samplesOf "(Join-Path `$RepoRoot 'plugins') | Get-ChildItem -Recurse -Filter '*.md'`n") 'a root piped into Get-ChildItem is a live walk, rooted at the stage before it'
    Assert-Equal 'x.gate-any' (& $samplesOf "Get-Item `$RepoRoot | Get-ChildItem -Recurse`n") 'and so is one piped through Get-Item'
    Assert-Equal 'docs/x.gate-any' (& $samplesOf "function Get-Docs(`$root) { Get-ChildItem `$root -Recurse }`nGet-Docs (Join-Path `$RepoRoot 'docs')`n") 'a root handed to a function parameter walks through it'
    Assert-Equal 'x.md' (& $samplesOf "function Get-Docs { param(`$Base, `$Filter) Get-ChildItem -LiteralPath `$Base -Recurse -Filter '*.md' }`nGet-Docs -Filter 'x' -Base `$RepoRoot`n") 'and a named argument binds to its own parameter'
    Assert-Equal 'x.md' (& $samplesOf "Invoke-GitRead -RepoRoot `$RepoRoot -GitArgs @('ls-files', '*.md')`n") 'git through Invoke-GitRead is a walk, narrowed by its typed pathspec'
    Assert-True (Get-SuiteReferenceSet -Text "Invoke-GitRead -RepoRoot `$RepoRoot -GitArgs @('ls-files')`n").WalksOpen 'and open without one'
    Assert-True (-not (Get-SuiteReferenceSet -Text "Invoke-GitRead -RepoRoot `$RepoRoot -GitArgs @('rev-parse', 'HEAD')`n").Walks) 'but a git read that lists nothing is no walk'
    Assert-Equal 'scripts/x.md' (& $samplesOf "Select-String -Path (Join-Path `$RepoRoot 'scripts\*.md') -Pattern 'x'`n") 'a Select-String over a wildcard path is a walk'
    Assert-True (Get-SuiteReferenceSet -Text "Select-String 'a.b' (Join-Path `$RepoRoot 'plugins\*')`n").WalksOpen 'its positional pattern is no filter, so a typeless path keeps it open'
    Assert-True (-not (Get-SuiteReferenceSet -Text "Select-String -Path (Join-Path `$RepoRoot 'CLAUDE.md') -Pattern 'x'`n").Walks) 'while a Select-String over one named file reads, it does not walk'
    Assert-True (-not (Get-SuiteReferenceSet -Text "`$f = Join-Path `$env:TEMP 'f'`n`$f | Get-ChildItem -Recurse`n").Walks) 'a fixture piped into Get-ChildItem is no live walk'
    Assert-True (-not (Get-SuiteReferenceSet -Text "function Get-Docs(`$root) { Get-ChildItem `$root -Recurse }`nGet-Docs `$Fixture`n").Walks) 'and neither is a function handed only a fixture'
    Assert-Equal '' (@(Get-UncoveredWalkSample -Samples @('plugins/p/x.gate-any') -Scope @('plugins/p/*')) -join ',') 'an open walk is covered by a folder pattern over its root'
    Assert-Equal 'plugins/q/x.gate-any' (@(Get-UncoveredWalkSample -Samples @('plugins/q/x.gate-any') -Scope @('plugins/p/*', '*.ps1')) -join ',') 'but not by one over another folder, nor by a typed pattern'
    Assert-Equal 'x.ps1' (@(Get-UncoveredWalkSample -Samples @('x.ps1', 'scripts/x.ps1') -Scope @('scripts/*.ps1')) -join ',') 'a whole-tree *.ps1 walk is NOT covered by scripts/*.ps1 -- the hole the filter-only guard had'
    Assert-Equal '' (@(Get-UncoveredWalkSample -Samples @('x.ps1', 'scripts/x.ps1') -Scope @('*.ps1')) -join ',') 'while a pattern without a directory covers it at any root'
    Assert-Equal 'hooks.json' (@(Get-UncoveredWalkSample -Samples @('hooks.json') -Scope @('*.ps1')) -join ',') 'and a pattern for another kind of file covers nothing'
    $declared = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File)) {
        $set = Get-SuiteReferenceSet -Text ([System.IO.File]::ReadAllText($f.FullName)) -SuiteDirectory 'scripts/tests'
        if (@($set.Scope).Count -eq 0) { continue }
        $declared++
        Assert-Equal '' (@(Get-UncoveredWalkSample -Samples $set.WalkSamples -Scope $set.Scope) -join ', ') "$($f.Name): its declared scope covers every root and type its live walks reach"
    }
    Assert-True ($declared -ge 30) "the guard read the declared suites (found $declared)"

    # --- 4. the selection over a real repository ----------------------------------------------------
    Write-Host "`n== 4. Get-AffectedSuiteSelection ==" -ForegroundColor Cyan
    $r4 = New-SelectionFixture
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/lib/b-lib.ps1')
    Assert-True $sel.Proven 'a mapped change is proven'
    Assert-Equal 5 $sel.PoolCount 'the pool is the five suites'
    Assert-Equal 'a,walk' (Get-SelectedNames $sel) 'a lib reached TRANSITIVELY selects its suite, plus the live-tree walker'
    Assert-Equal 'walk' ((@($sel.Always | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' })) -join ',') 'and the walker is reported as one that always runs'
    Assert-Equal 'walk' ((@($sel.Open | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' })) -join ',') 'and as OPEN, its unfiltered walk returning every type -- CI never drops it by type (#3316)'
    # WHY, for the /test-gate page (#3309, lever 3): one sentence per selected suite, and none for the rest.
    Assert-Equal 'it reaches scripts/lib/b-lib.ps1' $sel.Why['scripts/tests/a.tests.ps1'] 'a reached lib is named as the reason'
    Assert-True ($sel.Why['scripts/tests/walk.tests.ps1'] -match 'walks the live tree and declares no scope') 'an unscoped walker says it runs for every change'
    Assert-Equal 2 $sel.Why.Count 'and a suite that is not selected has no reason'

    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/task/c-tool.ps1')
    Assert-Equal 'c,walk' (Get-SelectedNames $sel) 'a tool selects the suite that RUNS it, and not the one whose lib only lists it'

    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('docs/data.json')
    Assert-Equal 'reg,walk' (Get-SelectedNames $sel) "a library's data reference with a directory selects the suites that load the library"

    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('README.md')
    Assert-Equal 'walk' (Get-SelectedNames $sel) "but a BARE name in a library is a seam value, not a dependency"

    # THE SEAM CONFIG NAMES DATA, NOT DEPENDENCIES (#3343): a path with a directory in repo-config.ps1's
    # tables selects only the suites that name or reach it themselves, not every suite that loads the seam.
    $r4s = New-SelectionFixture
    Set-FixtureFile $r4s 'scripts/repo-config.ps1' "function Get-HouseStyleAllowlist { @(@{ Path = 'docs/style.css'; Name = '.tip'; Reason = 'a fixture' }) }`n"
    Set-FixtureFile $r4s 'docs/style.css' "/* fixture */`n"
    Set-FixtureFile $r4s 'scripts/tests/seam.tests.ps1' ". (Join-Path `$PSScriptRoot '..\repo-config.ps1')`nexit 0`n"
    Set-FixtureFile $r4s 'scripts/tests/named.tests.ps1' "`$css = Join-Path `$PSScriptRoot '..\..\docs\style.css'`nexit 0`n"
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4s -ChangedPaths @('docs/style.css')
    Assert-Equal 'named,walk' (Get-SelectedNames $sel) "a path in repo-config.ps1's data does not select the suites that load the seam"

    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/tests/plain.tests.ps1')
    Assert-Equal 'plain,walk' (Get-SelectedNames $sel) 'a changed suite selects itself'

    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/lib/gate-lib.ps1')
    Assert-True (-not $sel.Proven) 'a change to the selector itself is not proven'
    Assert-True ($sel.Reason -match 'selector does not judge its own change') 'and says why'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('plugins/p/scripts/lib/native-capture-lib.ps1')
    Assert-True (-not $sel.Proven) 'nor is a change to the gate that runs it, mirror included'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('.github/workflows/ci.yml')
    Assert-True (-not $sel.Proven) 'nor a change to a CI workflow, which could shrink what CI runs (Sebastian)'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/repo-config.ps1')
    Assert-True (-not $sel.Proven) 'nor one to repo-config.ps1, which names the CI check'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('"docs/caf\303\251.md"')
    Assert-True (-not $sel.Proven) 'a quoted, non-ASCII path cannot be matched, so the selection is not proven'

    # A suite that does not parse runs every time: what it reaches is unknown, not empty.
    Set-FixtureFile $r4 'scripts/tests/plain.tests.ps1' "function Broken {`n"
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('README.md')
    Assert-True ((Get-SelectedNames $sel) -match 'plain') 'a suite that does not parse is selected whatever changed'
    Set-FixtureFile $r4 'scripts/tests/plain.tests.ps1' "exit 0`n"

    # A suite deleted but not staged is in the index and not on disk; naming it to the gate would throw.
    Remove-Item -LiteralPath (Join-Path $r4 'scripts/tests/plain.tests.ps1')
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/tests/plain.tests.ps1')
    Assert-Equal 4 $sel.PoolCount 'a suite deleted from disk is not in the pool (Victor)'
    Assert-True ((Get-SelectedNames $sel) -notmatch 'plain') 'and is never selected'
    Set-FixtureFile $r4 'scripts/tests/plain.tests.ps1' "exit 0`n"

    # A walk that DECLARES its scope runs only for a change inside it (#3309, lever 1) -- and a suite that
    # reaches a scoped helper inherits that helper's scope rather than running every time.
    Set-FixtureFile $r4 'scripts/tests/scoped.tests.ps1' "# gate-selection: walks *.md`nGet-ChildItem -Path `$RepoRoot -Recurse -Filter *.md`n"
    Set-FixtureFile $r4 'scripts/tests/walk-helper.ps1' "# gate-selection: walks docs/*`nGet-ChildItem -Path `$RepoRoot -Recurse`n"
    Set-FixtureFile $r4 'scripts/tests/uses-helper.tests.ps1' ". (Join-Path `$PSScriptRoot 'walk-helper.ps1')`nexit 0`n"
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/lib/b-lib.ps1')
    Assert-Equal 'a,walk' (Get-SelectedNames $sel) 'a change outside every declared scope selects none of the scoped walkers'
    Assert-Equal 'scoped,uses-helper,walk' ((@($sel.Walkers | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' }) | Sort-Object) -join ',') 'and every walker is still reported as one, for CI to judge'
    Assert-Equal 0 @($sel.Scoped).Count 'none of them is scoped in'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('README.md')
    Assert-Equal 'scoped,walk' (Get-SelectedNames $sel) 'a change inside a declared scope selects that walker'
    Assert-Equal 'scoped' ((@($sel.Scoped | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' })) -join ',') 'and reports it as scoped in, not as always'
    Assert-Equal "its walk scope '*.md' covers readme.md" $sel.Why['scripts/tests/scoped.tests.ps1'] 'and its reason names the scope and the path it covers (#3309, lever 3)'
    # The branch's own document falls in no walk scope (#3379): every branch carries one, so a '*.md'
    # scope would select its walker on every branch. Any other .md still does, and an empty name removes nothing.
    $doc = 'dkj-policy/fix-1-x.md'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @($doc) -BranchDocument $doc
    Assert-Equal 0 @($sel.Scoped).Count 'the branch document scopes in no walker (#3379)'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @($doc) -BranchDocument 'DKJ-Policy\Fix-1-X.md'
    Assert-Equal 0 @($sel.Scoped).Count 'whatever its case or slashes'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @($doc, 'README.md') -BranchDocument $doc
    Assert-Equal 'scoped' ((@($sel.Scoped | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' })) -join ',') 'another .md beside it still scopes the walker in'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @($doc) -BranchDocument ''
    Assert-Equal 'scoped' ((@($sel.Scoped | ForEach-Object { ($_ -split '/')[-1] -replace '\.tests\.ps1$', '' })) -join ',') 'an empty -BranchDocument leaves the document in the scope match'
    $sel = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('docs/data.json')
    Assert-True ((Get-SelectedNames $sel) -match 'uses-helper') "a suite inherits the declared scope of a helper it reaches"
    Remove-Item -LiteralPath (Join-Path $r4 'scripts/tests/scoped.tests.ps1'), (Join-Path $r4 'scripts/tests/walk-helper.ps1'), (Join-Path $r4 'scripts/tests/uses-helper.tests.ps1')

    # --- 5. the per-blob cache ------------------------------------------------------------------------
    Write-Host "`n== 5. the reference cache ==" -ForegroundColor Cyan
    $cachePath = Get-SuiteReferenceCachePath -RepoRoot $r4
    Assert-True (Test-Path -LiteralPath $cachePath -PathType Leaf) 'the cache is written in the git directory'
    $cache = [System.IO.File]::ReadAllText($cachePath) | ConvertFrom-Json
    $blobA = "$((& git -C $r4 rev-parse 'HEAD:scripts/lib/a-lib.ps1'))".Trim()
    Assert-True ([bool]$cache.blobs.PSObject.Properties[$blobA]) 'keyed by the blob id of each file it parsed'
    $warm = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/lib/b-lib.ps1')
    Assert-Equal 'a,walk' (Get-SelectedNames $warm) 'a warm run selects exactly what the cold run did'
    # A DIRTY file is parsed fresh: its blob id names content it no longer has.
    Set-FixtureFile $r4 'scripts/tests/plain.tests.ps1' ". (Join-Path `$PSScriptRoot '..\lib\b-lib.ps1')`nexit 0`n"
    $dirty = Get-AffectedSuiteSelection -RepoRoot $r4 -ChangedPaths @('scripts/lib/b-lib.ps1')
    Assert-Equal 'a,plain,walk' (Get-SelectedNames $dirty) 'an edited suite is read from the working tree, not from the cache'

    # --- 6. what this branch changes -----------------------------------------------------------------
    Write-Host "`n== 6. Get-GateChangedPaths ==" -ForegroundColor Cyan
    $r6 = New-SelectionFixture
    Set-FixtureFile $r6 'scripts/lib/b-lib.ps1' "function Get-B { 'b2' }`n"
    Invoke-FixtureGit -Dir $r6 'commit' '-qam' 'change b'
    Set-FixtureFile $r6 'docs/new.md' "new`n"
    $changes = Get-GateChangedPaths -RepoRoot $r6
    Assert-True $changes.Known 'the changes are read'
    Assert-Equal 'main' $changes.Base 'against the trunk, with no origin to prefer'
    Assert-Equal 'docs/new.md,scripts/lib/b-lib.ps1' ($changes.Paths -join ',') 'committed and untracked changes alike'
    Invoke-FixtureGit -Dir $r6 'branch' '-m' 'main' 'trunk-elsewhere'
    $noTrunk = Get-GateChangedPaths -RepoRoot $r6
    Assert-True (-not $noTrunk.Known) 'without a trunk ref there is nothing to compare with'

    # --- 7. Invoke-WorkflowGates -SelectSuites ---------------------------------------------------------
    Write-Host "`n== 7. the selected run in Invoke-WorkflowGates ==" -ForegroundColor Cyan
    $script:SeenSuites = 'never called'
    function Invoke-TestSuiteGate {
        param([string]$TestsDir, [string]$Context, [int]$MaxParallel = 0, [string[]]$SuiteNames = @())
        $script:SeenSuites = (@($SuiteNames) | Sort-Object) -join ','
        return $true
    }
    function Get-CiTestCheckName { return 'lint-en-tests' }
    $r7 = New-SelectionFixture
    Set-FixtureFile $r7 'scripts/task/c-tool.ps1' "Write-Output 'c2'`n"
    Invoke-FixtureGit -Dir $r7 'commit' '-qam' 'change c'
    Assert-True (Invoke-WorkflowGates -RepoRoot $r7 -SkipLint -SelectSuites -Context 'test' -FailureConsequence 'x') 'a selected run passes'
    Assert-Equal 'c.tests.ps1,walk.tests.ps1' $script:SeenSuites 'and hands the test gate exactly the selected suites'
    Assert-True (-not (Test-GateEvidence -RepoRoot $r7 -Gate 'tests')) 'and records NO test evidence -- a partial pass must not skip the next full run'

    $script:SeenSuites = 'never called'
    Assert-True (Invoke-WorkflowGates -RepoRoot $r7 -SkipLint -Context 'test' -FailureConsequence 'x') 'without -SelectSuites the run passes'
    Assert-Equal '' $script:SeenSuites 'and the whole pool runs'
    Assert-True (Test-GateEvidence -RepoRoot $r7 -Gate 'tests') 'and a whole-pool pass is recorded as before'

    # A selection that THROWS costs the saving, never the gate: every suite runs (Victor).
    [void](Clear-GateEvidence -RepoRoot $r7)
    $realSelection = ${function:Get-AffectedSuiteSelection}
    function Get-AffectedSuiteSelection { throw 'simulated selection failure' }
    $script:SeenSuites = 'never called'
    Assert-True (Invoke-WorkflowGates -RepoRoot $r7 -SkipLint -SelectSuites -Context 'test' -FailureConsequence 'x') 'a selection that throws does not fail the gate'
    Assert-Equal '' $script:SeenSuites 'it runs the whole pool instead'
    Set-Item -Path function:\Get-AffectedSuiteSelection -Value $realSelection

    Remove-Item function:\Get-CiTestCheckName
    [void](Clear-GateEvidence -RepoRoot $r7)
    $script:SeenSuites = 'never called'
    Assert-True (Invoke-WorkflowGates -RepoRoot $r7 -SkipLint -SelectSuites -Context 'test' -FailureConsequence 'x') 'with no CI check named, -SelectSuites still passes'
    Assert-Equal '' $script:SeenSuites 'but runs the whole pool -- there is nothing behind a partial run'
    Remove-Item function:\Invoke-TestSuiteGate

    # --- 8. the callers ------------------------------------------------------------------------------
    Write-Host "`n== 8. open-pr selects by default; nothing else does ==" -ForegroundColor Cyan
    $openPr = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\open-pr.ps1'))
    $shipPr = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'))
    $cut = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\cut-release.ps1'))
    $sites = @([regex]::Matches($openPr, 'Invoke-WorkflowGates -RepoRoot \$repoRoot[^\r\n]*'))
    Assert-Equal 1 @($sites | Where-Object { $_.Value -match '-SelectSuites:\(-not \$AllSuites\)' }).Count 'open-pr selects at exactly one call site'
    Assert-True (@($sites | Where-Object { $_.Value -match "-Context 'the PR'" -and $_.Value -match '-SelectSuites' }).Count -eq 1) 'and it is the PR path, which has the CI check behind it'
    Assert-True ($openPr -match '\[switch\]\$AllSuites') 'open-pr declares -AllSuites'
    Assert-True ($shipPr -match "if \(\`$AllSuites\)\s+\{ \`$openArgs \+= '-AllSuites' \}") 'ship-pr forwards -AllSuites only when set'
    Assert-True ($cut -notmatch 'SelectSuites') 'the release cut never selects'

    # --- 9. Invoke-TestSuiteGate -SuiteNames, for real ------------------------------------------------------
    Write-Host "`n== 9. Invoke-TestSuiteGate -SuiteNames ==" -ForegroundColor Cyan
    $t9 = Join-Path $FixtureRoot 'gate9'
    Set-FixtureFile $t9 'ok.tests.ps1' "Write-Host 'MARKER-OK'`nexit 0`n"
    Set-FixtureFile $t9 'red.tests.ps1' "Write-Host 'MARKER-RED'`nexit 1`n"
    $driver = Join-Path $FixtureRoot 'driver9.ps1'
    Set-FixtureFile $FixtureRoot 'driver9.ps1' @"
param([string]`$Suites, [switch]`$WithShard)
`$ErrorActionPreference = 'Stop'
. '$NativeLibPath'
try {
    if (`$WithShard) { `$ok = Invoke-TestSuiteGate -TestsDir '$t9' -MaxParallel 1 -SuiteNames @(`$Suites -split ',') -Shard 1 -ShardCount 2 }
    else { `$ok = Invoke-TestSuiteGate -TestsDir '$t9' -MaxParallel 1 -SuiteNames @(`$Suites -split ',') }
} catch { Write-Host "THREW: `$(`$_.Exception.Message)"; exit 3 }
if (`$ok) { exit 0 } else { exit 1 }
"@
    $depthHeld = [Environment]::GetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', 'Process')
    [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $null, 'Process')
    try {
        $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $driver -Suites 'ok.tests.ps1' 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        Assert-Equal 0 $code 'only the selected suite runs, so the red one cannot fail the gate'
        Assert-True (($out -join "`n") -match 'MARKER-OK') 'the selected suite ran'
        Assert-True (($out -join "`n") -notmatch 'MARKER-RED') 'the other did not'
        Assert-True (($out -join "`n") -match 'the 1 selected of 2 suites passed') 'and the verdict says it was a selection, not the pool'

        $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $driver -Suites 'missing.tests.ps1' 2>&1 | ForEach-Object { "$_" })
        Assert-Equal 3 $LASTEXITCODE 'a selected name that matches no suite throws rather than running less'
        $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $driver -Suites 'ok.tests.ps1' -WithShard 2>&1 | ForEach-Object { "$_" })
        Assert-Equal 3 $LASTEXITCODE 'and a selection inside a shard is refused'
    } finally {
        [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $depthHeld, 'Process')
    }

} finally {
    if (Test-Path -LiteralPath $FixtureRoot) {
        Remove-Item -Recurse -Force -LiteralPath $FixtureRoot -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
$fixtureBroken = Write-FixtureGitSummary -Subject 'the affected-suite selection'
if ($script:fail -gt 0) { exit 1 }
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
