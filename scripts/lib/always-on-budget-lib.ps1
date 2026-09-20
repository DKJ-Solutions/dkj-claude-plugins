<#
.SYNOPSIS
    The always-on budget: the ceiling, the ratchet, the baseline file, and the one verdict every
    carrier reads. Sits ON TOP of measure-context-lib.ps1 and deliberately beside it, not inside it.

.DESCRIPTION
    WHY IT EXISTS (issue #2037, Dave September 16, 2026: "find a durable way for ALL consumers to keep
    CLAUDE.md under 100.0k chars, because I notice it goes over 150k everywhere"). The always-on
    document path -- CLAUDE.md plus everything it '@'-imports -- is paid by every session before a
    single assignment is given. measure-always-on.ps1 has reported that figure since August 2026 and
    every measurable consumer went over 100,000 B anyway, the source repo included. That IS the
    finding: MEASUREMENT WITHOUT A BOUND DOES NOT HOLD A LINE.

    WHY A SEPARATE LIB AND NOT A FUNCTION IN measure-context-lib.ps1. That file states its own boundary
    in its header -- "It reaches no verdict. It says what a document costs and where the mass sits; it
    does not say what should go" -- and that boundary is the recorded outcome of issue #861, where a
    skill that would have JUDGED an instruction document block by block was argued down. Putting a
    verdict function in there would retire that decision by accident, in the one file whose docstring
    promises it is still in force. So the measurement stays there, the judgement is here, and #861's
    line holds: this lib bounds a TOTAL and still says nothing about which block should go.

    A RATCHET, NOT A CLIFF, AND THAT IS THE CHOICE THE MECHANISM LIVES OR DIES ON. All four measurable
    repos were over the ceiling the day this was written, so a hard refusal on day one is a gate that
    gets -Skip'ped once and never obeyed again. Instead the effective limit is:

        over the ceiling  (baseline > budget)  -> the limit is the BASELINE: the path may not grow
        at or under it    (baseline <= budget) -> the limit is the BUDGET:  the headroom is usable

    i.e. Get-AlwaysOnLimit = max(budget, baseline). The baseline is LOWERED automatically whenever a
    run measures less than it, and raised only behind an explicit flag with a reason. So every branch
    that touches the path either shrinks it or holds it, and a repo converges on the ceiling instead of
    failing against it from a standing start.

    THE UNIT IS LF BYTES, AND THAT IS LOAD-BEARING RATHER THAN FUSSY. measure-context-lib reports Bytes
    (the working copy on disk, which is what a session actually loads) and LfBytes beside it, because a
    CRLF checkout carries one byte per LINE above the form the repository stores -- inbound #1162. For a
    REPORT the on-disk figure is the right one. For a RATCHET it is fatal: a baseline recorded on a
    Windows checkout and compared against a CI runner's, or against an editor-rewritten file, differs by
    ~1.4% on a 1,346-line document -- plausible, wrong, and enough to refuse a branch that changed
    nothing. LfBytes is the same number everywhere, so the ratchet compares that and the report NAMES the
    on-disk figure beside it.

    AND THE TERM A CI RUNNER CANNOT MEASURE IS CARRIED, NOT SILENTLY DROPPED. This is the premise
    #2037 never weighed. A consumer's path reaches its orchestrator persona through an absolute
    '~/.claude/plugins/marketplaces/...' import -- 30,267 B, 27.7% of the source repo's own path, and
    the issue's own argument for why `wc -c CLAUDE.md` is the wrong unit. A CI runner has no marketplace
    clone, so that import DOES NOT RESOLVE there: measure-context-lib returns it Exists=$false, Bytes=0,
    exactly as designed. Left alone, the local carrier would measure 109,385 B and the CI carrier 79,118
    B for the same commit, and a ratchet comparing the two would flap on every push.

    SO THE BASELINE CARRIES THE LAST MEASURED SIZE OF EVERY DOCUMENT, KEYED BY ITS IMPORT TARGET, and a
    run that cannot resolve one takes the recorded figure and says so. Three properties make this safe:
    the carried term is plugin payload, which no branch in the consuming repo can change; a local run
    re-measures and re-records it, so it tracks the installed version within one run of the local gate;
    and a term that is neither measurable NOR recorded is reported as unmeasured and named in the
    verdict rather than counted as zero -- a smaller, healthier-looking path is the one wrong answer
    this whole lib exists to stop.

    THE BASELINE FILE LIVES IN THE WORKFLOW'S OWN FOLDER, resolved through Get-WorkflowFolderName rather
    than spelled out -- that folder has renamed once already. It is machine-written STATE, which is why
    it is not in scripts\repo-config.ps1 beside the seam: repo-config is where a PERSON declares what
    this repo is, and a file the gate rewrites on its own does not belong in it.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script, which is
    the standing convention for every lib in this directory. Pure ASCII, per the [script-ascii] gate.
#>

# measure-context-lib supplies the walk (Get-AlwaysOnDocuments); seam-lib supplies Get-WorkflowFolderName
# and Get-SeamValue. Both $PSScriptRoot-relative, so they resolve in the plugin mirror exactly as they do
# here. Unguarded: this lib is useless without either, and a silent degrade would answer a budget
# question with no measurement behind it.
. (Join-Path $PSScriptRoot 'measure-context-lib.ps1')
. (Join-Path $PSScriptRoot 'seam-lib.ps1')

# THE CEILING, AND IT IS A DEFAULT RATHER THAN A LAW. Dave's figure, in bytes because that is what the
# measurement layer produces and what a person can check with `wc -c`. A repo raises it through the
# Get-AlwaysOnBudget seam, and the raise is then VISIBLE AND ARGUABLE in a tracked file rather than
# silent -- which is the whole difference between this and no bound at all.
$script:AlwaysOnBudgetDefault = 100000

# Bumped when the shape below changes in a way an older reader would misread. A file from the future is
# refused rather than guessed at: a baseline is the one number the ratchet trusts, so half-understanding
# it is worse than not reading it.
$script:AlwaysOnBaselineSchema = 1

function Get-AlwaysOnBudgetDefault {
    <# The built-in ceiling in bytes, for a repo that states no Get-AlwaysOnBudget seam. #>
    return $script:AlwaysOnBudgetDefault
}

function Resolve-AlwaysOnBudget {
    <#
        The ceiling this repo runs under: the Get-AlwaysOnBudget seam where it states one, otherwise the
        built-in default. Read through Get-SeamValue like every other optional seam, so an absent
        function and an unreadable one behave the same way.

        NAMED Resolve- AND NOT Get-AlwaysOnBudget, WHICH IS THE OBVIOUS NAME AND WOULD HANG. The seam
        this reads is itself called Get-AlwaysOnBudget, and a repo's repo-config.ps1 and this lib are
        dot-sourced into ONE session: whichever loads last wins the name. With the obvious name, a load
        order that put this lib second would have Get-SeamValue find THIS function, call it, and recurse
        until the session died -- no error message, no seam, no budget.

        A NON-POSITIVE OR NON-NUMERIC ANSWER FALLS BACK rather than disabling the gate. 'Get-AlwaysOnBudget
        returned 0' would be indistinguishable from a repo that has opted out, and opting out is not
        something this seam offers -- a repo that wants more room raises the number, where the raise is
        readable. Deliberately NOT a refusal either: a malformed seam must not be able to stop every PR
        in a consumer, so the default answers and the caller prints which number it used.
    #>
    $raw = Get-SeamValue -Name 'Get-AlwaysOnBudget' -Default $null
    if ($null -eq $raw) { return [int64]$script:AlwaysOnBudgetDefault }
    $parsed = [int64]0
    if (-not [int64]::TryParse([string]$raw, [ref]$parsed)) { return [int64]$script:AlwaysOnBudgetDefault }
    if ($parsed -le 0) { return [int64]$script:AlwaysOnBudgetDefault }
    return [int64]$parsed
}

function Get-AlwaysOnBaselinePath {
    <# The baseline file: '<workflow folder>/always-on-baseline.json', the folder NAMED rather than
       spelled out (it renamed once already -- see seam-lib's header). #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $folder = Get-WorkflowFolderName -RepoRoot $RepoRoot
    return (Join-Path $RepoRoot (Join-Path $folder 'always-on-baseline.json'))
}

function Get-AlwaysOnDocumentKey {
    <#
        The stable key a document is recorded under, and it is NOT its resolved path.

        An external import resolves to 'C:\Users\<somebody>\.claude\plugins\...', which differs per
        machine and per operating system -- so a baseline keyed on it would match nothing on the next
        checkout and every carried term would read as missing. The IMPORT TARGET as written
        ('~/.claude/plugins/marketplaces/.../specialist-01-01-persona.md') is the same string in every clone,
        because it is a string in a tracked file. The root document has no target, so it is keyed by
        its repo-relative display name, which is equally stable.
    #>
    param([Parameter(Mandatory = $true)]$Document)
    if ($Document.Target) { return [string]$Document.Target }
    return [string]$Document.Display
}

function Read-AlwaysOnBaseline {
    <#
        Reads the baseline file, or returns $null when there is none / it cannot be understood.

        EVERY FAILURE READS AS 'NO BASELINE', which is the safe direction: no baseline means the gate
        judges against the budget alone and records a fresh one, where a half-read baseline would ratchet
        against a number nobody can see. A file from a NEWER schema is the one exception -- it comes back
        with Unreadable filled in and Bytes $null, so the caller can NAME the remedy ("update the
        plugin") instead of silently re-recording over a file it did not understand.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $path = Get-AlwaysOnBaselinePath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    try {
        $json = [System.IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding $false))
        $obj = $json | ConvertFrom-Json
    } catch { return $null }
    if (-not $obj) { return $null }

    $names = @($obj.PSObject.Properties.Name)

    $schema = 0
    if ($names -contains 'schema') { $schema = [int]$obj.schema }
    if ($schema -gt $script:AlwaysOnBaselineSchema) {
        return [pscustomobject]@{
            Path       = $path
            Unreadable = "schema $schema, and this copy understands $($script:AlwaysOnBaselineSchema) -- update the dkj-policy plugin"
            Bytes      = $null
            Recorded   = ''
            Reason     = ''
            Documents  = @{}
        }
    }

    if ($names -notcontains 'bytes') { return $null }
    $bytes = [int64]$obj.bytes

    $docs = @{}
    if ($names -contains 'documents' -and $obj.documents) {
        foreach ($p in $obj.documents.PSObject.Properties) { $docs[$p.Name] = [int64]$p.Value }
    }

    $reason = ''
    if ($names -contains 'reason' -and $obj.reason) { $reason = [string]$obj.reason }
    $recorded = ''
    if ($names -contains 'recorded' -and $obj.recorded) { $recorded = [string]$obj.recorded }

    return [pscustomobject]@{
        Path       = $path
        Unreadable = ''
        Bytes      = $bytes
        Recorded   = $recorded
        Reason     = $reason
        Documents  = $docs
    }
}

function Write-AlwaysOnBaseline {
    <#
        Records a measurement as the new baseline: the total, the per-document sizes that let a carrier
        with no marketplace clone measure the same subject, and a reason where the write is a RAISE.

        NEWLINE-EXACT AND LF, because this file is tracked and compared: a JSON blob that changed its
        line endings per machine would show up as a whole-file diff on every write, in the one file
        whose whole purpose is to make a single number reviewable.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)]$Measurement,
        [string]$Reason = ''
    )

    $documents = [ordered]@{}
    foreach ($key in ($Measurement.Sizes.Keys | Sort-Object)) { $documents[$key] = [int64]$Measurement.Sizes[$key] }

    $payload = [ordered]@{
        schema    = $script:AlwaysOnBaselineSchema
        bytes     = [int64]$Measurement.Total
        recorded  = (Get-Date -Format 'yyyy-MM-dd')
        reason    = $Reason
        note      = 'LF bytes of the always-on document path. Written by the always-on budget gate -- see always-on-budget-lib.ps1. Do not hand-edit this to make room: the gate lowers it on its own and raises it only behind -Raise, with a reason.'
        documents = $documents
    }

    $json = ($payload | ConvertTo-Json -Depth 5) -replace "`r`n", "`n"
    if (-not $json.EndsWith("`n")) { $json += "`n" }

    $path = Get-AlwaysOnBaselinePath -RepoRoot $RepoRoot
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
    return $path
}

function Get-AlwaysOnMeasurement {
    <#
        Walks the path and returns what the budget is judged on -- in LF bytes, with every term this run
        could not measure carried from $Baseline and named.

        Three row sets, and the third is the one that must never be confused with zero:
          Measured   -- resolved here, LF bytes read off disk
          Carried    -- did not resolve here, taken from the baseline (the plugin term in a CI runner)
          Unmeasured -- did not resolve and the baseline has no figure for it either

        Total is Measured + Carried. Unmeasured contributes NOTHING and is reported, because a document
        counted as zero makes the path look healthier than it is, which is the one wrong answer this
        whole lib exists to stop.

        AND A MEASURED DOCUMENT IS JUDGED ON THIS TREE'S COPY WHERE THIS TREE HAS ONE (issue #2187).
        The source repo consumes itself, so a document loaded from '~/.claude/plugins/marketplaces/<this
        marketplace>/...' has a counterpart in the checkout the branch is editing. The installed copy
        only advances at a RELEASE, so summing it asked the wrong question: not "does this branch grow
        the always-on path" but "did somebody run a plugin update lately". Measured on the branch that
        filed #2187 -- a persona body grew 621 B in this tree and the gate reported "[OK] ... NOT
        growing", because the figure it summed had not moved. The weight was not cancelled, only
        deferred onto whichever later branch happened to be open when the release landed, which is the
        one direction a ratchet must not err in: it refuses an author for weight absent from their own
        diff.

        SO THE SUBSTITUTION IS BOUNDED THREE WAYS, and each bound is load-bearing:
          - the loaded copy must EXIST. An unresolved target keeps the carried/unmeasured branches
            below untouched. Measured during #2135's persona rename, when SPECIALISTS.md deliberately
            carried both the pre- and post-rename import: substituting on an unresolved target would
            have added the renamed body's 30,899 B ON TOP of the 30,267 B carried for the old one -- a
            30k jump no branch caused, refusing whichever branch was open.
          - the counterpart must EXIST IN THIS TREE. Get-TreeCounterpart already returns $null
            otherwise, so a consumer -- which mirrors nothing -- is untouched by every line of this.
          - it is LF bytes either side, never TreeBytes. See TreeLfBytes in measure-context-lib.

        WHAT A CI RUNNER DOES WITH IT, said here rather than left to be discovered: nothing. No '~/'
        import resolves there, so the term is CARRIED and the recorded figure is what CI judges -- and
        that figure was recorded by the local gate, which did substitute. The two carriers still
        describe one subject; the local one is simply the one that can see the change, which is also
        the one that runs before the push.

        LoadedTotal is what the resolved copies actually come to -- the figure a session on THIS machine
        pays today. It is reported beside Total where the two differ and is judged by nothing, exactly
        as DiskBytes is reported beside the LF total.

        AND A FOURTH SET THAT CUTS ACROSS THE OTHER THREE: Dead -- an import this run can PROVE is not
        there (Get-ImportAbsenceKind). It is not a fourth bucket in the sum: a dead import may also be
        carried, and then its recorded bytes stay in the total exactly as before, because dropping a
        term the run merely could not read is what would make the next branch read as growth. What
        changes is only what is SAID about it. The two facts are independent and both are true:
        the figure is carried, and the document is not being loaded.

        That the question is asked BEFORE the carried branch is the point rather than an ordering
        detail. A figure in the baseline says what a document USED to cost; it is no evidence at all
        that anything still loads it. Asking afterwards would let this lib's own memory hide the one
        failure it exists to surface.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$RootDocument = '',
        $Baseline = $null
    )

    if (-not $RootDocument) { $RootDocument = Join-Path $RepoRoot 'CLAUDE.md' }

    $docs = @(Get-AlwaysOnDocuments -RootDocument $RootDocument -RepoRoot $RepoRoot)
    $recorded = @{}
    if ($Baseline -and $Baseline.Documents) { $recorded = $Baseline.Documents }

    $sizes = @{}
    $measured = New-Object System.Collections.Generic.List[object]
    $carried = New-Object System.Collections.Generic.List[object]
    $unmeasured = New-Object System.Collections.Generic.List[object]
    $dead = New-Object System.Collections.Generic.List[object]
    $substituted = New-Object System.Collections.Generic.List[object]
    $measuredBytes = [int64]0
    $carriedBytes = [int64]0
    $loadedBytes = [int64]0
    $diskBytes = [int64]0

    foreach ($d in $docs) {
        $key = Get-AlwaysOnDocumentKey -Document $d
        if ($d.Exists) {
            # THE JUDGED COPY, chosen here and nowhere else. Defaults to the one that loaded; becomes
            # this tree's counterpart where the walk found one. TreeLfBytes is $null on a row from a
            # mirror built before #2187 -- tested rather than assumed, so an older measure-context-lib
            # degrades to the previous behaviour instead of summing $null as zero.
            $judged     = [int64]$d.LfBytes
            $judgedDisk = [int64]$d.Bytes
            $loadedBytes += [int64]$d.LfBytes
            $hasTreeLf = @($d.PSObject.Properties.Name) -contains 'TreeLfBytes'
            if ($d.Source -eq 'external' -and $d.TreeCounterpart -and $hasTreeLf -and $null -ne $d.TreeLfBytes) {
                $judged     = [int64]$d.TreeLfBytes
                $judgedDisk = [int64]$d.TreeBytes
                $sourceDisplay = $d.TreeCounterpart
                if ($sourceDisplay.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $sourceDisplay = ($sourceDisplay.Substring($RepoRoot.Length) -replace '\\', '/').TrimStart('/')
                }
                $substituted.Add([pscustomobject]@{
                    Key           = $key
                    Display       = $d.Display
                    Target        = $d.Target
                    ImportedBy    = $d.ImportedBy
                    SourceDisplay = $sourceDisplay
                    Bytes         = $judged
                    LoadedBytes   = [int64]$d.LfBytes
                    Delta         = $judged - [int64]$d.LfBytes
                }) | Out-Null
            }
            $sizes[$key] = $judged
            $measuredBytes += $judged
            $diskBytes += $judgedDisk
            $measured.Add([pscustomobject]@{
                Key = $key; Display = $d.Display; Bytes = $judged; DiskBytes = $judgedDisk; Source = $d.Source
            }) | Out-Null
            continue
        }
        # DEAD OR MERELY UNSEEN -- asked here, ahead of both branches below, for the reason in this
        # function's header. ImportedBy is required: a root document that is not there is a missing
        # ROOT, which the caller has already refused by the time it gets here, and calling it a dead
        # import would name something nothing imported.
        if ($d.ImportedBy -and (Get-ImportAbsenceKind -Path $d.Path -RepoRoot $RepoRoot) -eq 'dead') {
            $dead.Add([pscustomobject]@{
                Key = $key; Display = $d.Display; Target = $d.Target; ImportedBy = $d.ImportedBy
            }) | Out-Null
        }
        if ($recorded.ContainsKey($key)) {
            # CARRIED FORWARD UNCHANGED, so the next baseline write does not quietly drop a term this run
            # merely could not see. Dropping it would shrink the recorded path by the size of the plugin
            # persona every time a CI run wrote a baseline -- and the next local run would then read as
            # growth of exactly that size, refusing a branch that changed nothing.
            $b = [int64]$recorded[$key]
            $sizes[$key] = $b
            $carriedBytes += $b
            # A CARRIED TERM COUNTS TOWARDS THE LOADED FIGURE TOO. It is the best answer this run has
            # for what that document costs, and leaving it out would make LoadedTotal differ from Total
            # on every CI run -- printing a "what a session loads" line on the one carrier that cannot
            # know.
            $loadedBytes += $b
            $carried.Add([pscustomobject]@{ Key = $key; Display = $d.Display; Bytes = $b; Target = $d.Target }) | Out-Null
            continue
        }
        $unmeasured.Add([pscustomobject]@{ Key = $key; Display = $d.Display; Target = $d.Target; ImportedBy = $d.ImportedBy }) | Out-Null
    }

    return [pscustomobject]@{
        RootDocument  = $RootDocument
        Total         = $measuredBytes + $carriedBytes
        LoadedTotal   = $loadedBytes
        MeasuredBytes = $measuredBytes
        CarriedBytes  = $carriedBytes
        DiskBytes     = $diskBytes
        # .ToArray() AND NOT @(...), WHICH IS THE IDIOM EVERYWHERE ELSE IN THIS TREE AND THROWS HERE.
        # On Windows PowerShell 5.1 the array-subexpression operator raises ArgumentException
        # ("Argument types do not match") on a List[object] -- empty or not -- while the same operator on
        # a List[string] is fine. Every other caller in this repo gets away with @() because a List
        # RETURNED from a function is unrolled to object[] before anybody wraps it; a List still held in
        # a variable is not. Measured September 16, 2026: the first draft of this function died here, and
        # the exception names neither the operator nor the type.
        Measured      = $measured.ToArray()
        Carried       = $carried.ToArray()
        Unmeasured    = $unmeasured.ToArray()
        Dead          = $dead.ToArray()
        Substituted   = $substituted.ToArray()
        Sizes         = $sizes
    }
}

function Get-MeasurementField {
    <#
        One field of a measurement object, or $Default where the object does not carry it.

        NOT DEFENSIVE PROGRAMMING FOR ITS OWN SAKE. Under Set-StrictMode -Version Latest -- which every
        carrier of this lib sets -- reading an absent property is a TERMINATING error, so a verdict
        reaching for a field added later dies with 'PropertyNotFound' inside a gate whose whole job is
        to exit 0 or 1 on a budget. Two callers can hand over an older shape: the test suite, which
        builds a measurement by hand precisely so the verdict is tested without the walk, and a mirror
        of this lib shipped before the field existed.
    #>
    param(
        [Parameter(Mandatory = $true)]$Measurement,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )
    if ($null -eq $Measurement) { return $Default }
    if (-not (@($Measurement.PSObject.Properties.Name) -contains $Name)) { return $Default }
    $value = $Measurement.$Name
    if ($null -eq $value) { return $Default }
    return $value
}

function Get-AlwaysOnLimit {
    <#
        The number this run is actually held to: max(budget, baseline).

        Over the ceiling the baseline wins, so the gate refuses GROWTH and a repo ratchets down. At or
        under it the budget wins, so the headroom below the ceiling stays usable and a branch is not
        refused for spending room the repo is entitled to. With no baseline the budget is the limit.

        max() rather than min(), and min() is the tempting mistake: it would freeze every repo at its
        own low-water mark forever and refuse a branch for adding 200 B to a 60,000 B path -- a rule
        nobody agreed to, arriving as a side effect of a rule they did.
    #>
    param(
        [Parameter(Mandatory = $true)][int64]$Budget,
        $Baseline = $null
    )
    if ($Baseline -and $null -ne $Baseline.Bytes -and [int64]$Baseline.Bytes -gt $Budget) { return [int64]$Baseline.Bytes }
    return $Budget
}

function Get-AlwaysOnBudgetVerdict {
    <#
        The one verdict every carrier reads -- the local gate in open-pr, the CI runner, and the session
        hook -- so the three cannot drift into describing the same path differently.

        States:
          'first-run'    no baseline yet; the limit is the budget and the caller records what it measured
          'inside'       at or under the budget, and not crossing it
          'crossing'     at or under the budget before, over it now       -> REFUSED
          'over-holding' over the budget and not growing                  -> allowed, the ratchet holds
          'over-shrink'  over the budget and smaller than the baseline    -> allowed, baseline lowered
          'over-growing' over the budget and growing                      -> REFUSED

        Ok is what a gate exits on. ShouldRecord is what a WRITING carrier acts on -- the local gate
        lowers the baseline, a read-only carrier (CI, the session hook) ignores it.

        A FIRST RUN NEVER REFUSES, whatever it measures. It is the run that establishes where the repo
        is, and refusing there would hand every adopting consumer a red gate before they have been told
        a ceiling exists -- the day-one cliff the ratchet was chosen to avoid.
    #>
    param(
        [Parameter(Mandatory = $true)]$Measurement,
        [Parameter(Mandatory = $true)][int64]$Budget,
        $Baseline = $null
    )

    $total = [int64]$Measurement.Total
    $hasBaseline = ($Baseline -and $null -ne $Baseline.Bytes)
    $baselineBytes = [int64]0
    if ($hasBaseline) { $baselineBytes = [int64]$Baseline.Bytes }
    $limit = Get-AlwaysOnLimit -Budget $Budget -Baseline $Baseline

    $state = 'inside'
    $ok = $true
    $shouldRecord = $false

    if (-not $hasBaseline) {
        $state = 'first-run'
        $shouldRecord = $true
    } elseif ($total -gt $limit) {
        # OVER THE LINE, and WHICH line it is decides which sentence the carrier prints: a repo that has
        # never been inside the ceiling is being held to its own history, one that has is being told it
        # is about to leave.
        $state = 'crossing'
        if ($baselineBytes -gt $Budget) { $state = 'over-growing' }
        $ok = $false
    } elseif ($baselineBytes -gt $Budget) {
        $state = 'over-holding'
        if ($total -lt $baselineBytes) {
            $state = 'over-shrink'
            $shouldRecord = $true
        }
    } else {
        # THE BASELINE IS A LOW-WATER MARK AND ONLY EVER FALLS ON ITS OWN. Under the ceiling a branch may
        # use the headroom, so growth here is allowed and NOT recorded -- recording it would turn the
        # ceiling into a ratchet at whatever the path happened to be that day, which is the min() mistake
        # Get-AlwaysOnLimit's header names, arriving by the back door.
        $shouldRecord = ($total -lt $baselineBytes)
    }

    $baselineOut = $null
    if ($hasBaseline) { $baselineOut = $baselineBytes }
    $deltaOut = $null
    if ($hasBaseline) { $deltaOut = $total - $baselineBytes }

    return [pscustomobject]@{
        State        = $state
        Ok           = $ok
        Total        = $total
        Budget       = $Budget
        Baseline     = $baselineOut
        Limit        = $limit
        Headroom     = $limit - $total
        Delta        = $deltaOut
        ShouldRecord = $shouldRecord
        Unmeasured   = @($Measurement.Unmeasured)
        Carried      = @($Measurement.Carried)
        Dead         = @($Measurement.Dead)
        # PROPERTY-TESTED, unlike the three above. Those have been on every measurement since this lib
        # was written; these two arrived with #2187, and this function is called with a hand-built
        # measurement in the suite and by any carrier shipped from a mirror built before that. An
        # absent property under Set-StrictMode is a terminating error, not $null -- and the caller is a
        # GATE, so it would exit 1 with a PropertyNotFound message about a reporting field.
        Substituted  = @(Get-MeasurementField -Measurement $Measurement -Name 'Substituted' -Default @())
        LoadedTotal  = [int64](Get-MeasurementField -Measurement $Measurement -Name 'LoadedTotal' -Default $total)
    }
}
