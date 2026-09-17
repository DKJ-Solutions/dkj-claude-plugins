<#
.SYNOPSIS
    Does a CI runner in THIS repo fold the changelog off a push to the trunk? -- the one question that
    decides whether a shipping session which cannot fold locally has lost the fold or merely handed it
    over (issue #2087).

.DESCRIPTION
    THE REFUSAL THIS EXISTS TO NARROW. ship-pr.ps1 step 0a refuses to ship at all while another worktree
    stands on the trunk, and its whole stated ground is "step 5 could not fold after the merge" -- git
    allows one worktree per branch, so a second checkout holding the trunk locks it for the clone and the
    local fold cannot run. That ground was exactly right when #1069 wrote it, and it has an exception
    already written into the same file: under a merge queue the refusal is skipped, because there the
    queue's own push to main runs fold-on-merge.yml (#1493) and this session was never going to fold.

    THE EXCEPTION IS NARROWER THAN THE FACT IT RESTS ON. fold-on-merge.yml triggers on `push: branches:
    [main]` -- EVERY push to the trunk, not only a queue's -- so the same recovery covers an ordinary
    ship whose local fold cannot run. ship-pr already relies on this on the ordinary path: #1792 gave
    step 5c the case where fold-on-merge.yml WINS the race against the local fold, and calls that a
    success rather than a failed ship. So the refusal was gated on the queue when the thing it actually
    depends on is the runner.

    WHAT THAT COSTS, AND WHY IT IS NOT A RARE STATE. The close-out rule and step 5b both END sessions on
    the trunk, deliberately -- that is what makes a session safe to clear. So a second live session
    standing on the trunk is the ORDINARY state of this workflow, not an unusual one, and two lanes
    shipping in the same period block each other on it even when CI is fresh. Measured on PR #2076
    (issue #2087, September 17, 2026), refused on exactly this while five green PRs sat unmerged.

    SO THE REFUSAL IS KEPT AND CONDITIONED ON THE RUNNER INSTEAD OF ON THE QUEUE. Where a push-to-trunk
    runner folds, a shipping session that cannot fold locally hands the fold over and says so; where
    none does, the refusal fires exactly as it always did. A consumer that never adopted the CI floor
    (adopt-dkj-policy part 3 is optional and separate from enabling the plugin) is therefore unchanged
    by this file, which is the property that let it be written at all.

    READ FROM DISK, NOT FROM A SEAM, AND THAT IS THE WHOLE SAFETY ARGUMENT. A repo-config declaration
    ("this repo folds in CI") is the house convention for a repo-owned answer and was the first shape
    tried. It was declined because it can go stale in the one direction that costs the fold: delete the
    workflow, leave the declaration, and every later ship merges and never folds -- the half-state
    nothing reports until a release trips over it, arriving through a file nobody re-reads. The
    workflow files ARE the mechanism, so reading them cannot disagree with it.

    AND EVERY AMBIGUITY ANSWERS "NO RECOVERY", WHICH IS TODAY'S BEHAVIOUR. A file that cannot be read, a
    trigger written in a shape the recogniser below declines, a `branches-ignore:` filter this does not
    try to evaluate: each yields $false, the refusal fires, and the operator is where they already were.
    A false negative costs one refusal that was already being paid; a false positive costs a merged-and-
    unfolded trunk. The two are not symmetric and nothing here treats them as if they were.

    THIS DOES NOT ASK WHETHER THE RUNNER WOULD SUCCEED. It cannot: the push needs an actor that bypasses
    the trunk's ruleset (FOLD_PUSH_TOKEN here, #1507), which is a secret this process cannot read, and a
    run can go red for reasons that have nothing to do with the fold. What it answers is whether the
    fold is SOMEBODY'S -- and the detector this repo already ships for the other direction,
    check-unfolded-entry.ps1, reports a leftover on the trunk from a SessionStart hook and from a push
    workflow. So a runner that exists and fails is a state that gets reported; a runner that does not
    exist is one nothing would ever look for.

    Pure ASCII (repo convention for .ps1). No Set-StrictMode: dot-sourcing would change the strict mode
    of the calling script.
#>

function Get-WorkflowTriggerBlock {
    <#
    .SYNOPSIS
        The lines of a workflow's top-level `on:` mapping, or an empty array when there is none.

    .DESCRIPTION
        A TOP-LEVEL KEY IS ONE AT COLUMN 0, which is what makes this a scan rather than a YAML parse.
        The block runs from the `on:` line to the next line that begins a top-level key -- any line
        whose first character is neither whitespace nor '#'. Blank lines and comments inside the block
        belong to it.

        THREE SPELLINGS OF THE KEY, AND THE REASON IS YAML 1.1 RATHER THAN TASTE. The bare word `on` is
        a BOOLEAN in YAML 1.1, so an author who knows that writes the key quoted to be safe; GitHub
        accepts all three spellings and real workflows use all three. Matching only the bare one would
        read a correctly written file as having no triggers at all.

        THE INLINE FORM IS RETURNED AS ITS OWN SINGLE LINE. `on: [push, pull_request]` and `on: push`
        carry the whole mapping on the key's own line, so the block is that line, and the caller's
        matchers read it there.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$WorkflowText)

    if (-not $WorkflowText) { return @() }
    # Split on all three line endings rather than on [Environment]::NewLine: a workflow committed from
    # a Linux checkout and read on Windows (or the reverse) has to split identically, and this lib is
    # read by a script that runs on both.
    $lines = $WorkflowText -split "`r`n|`n|`r"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#') { continue }
        if ($lines[$i] -match '^(on|"on"|''on'')\s*:') { $start = $i; break }
    }
    if ($start -lt 0) { return @() }

    $block = @($lines[$start])
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # A WHITESPACE-ONLY LINE STAYS IN THE BLOCK. It carries no key, so it cannot end the mapping,
        # and dropping it here would let the caller's indentation comparisons read across a gap as if
        # it were not there -- which is true, and is why it is kept rather than skipped.
        if ($line -match '^\s*$') { $block += $line; continue }
        if ($line -match '^\s') { $block += $line; continue }
        if ($line -match '^#') { $block += $line; continue }
        break
    }
    return @($block)
}

function Test-PushTriggerOnBranch {
    <#
    .SYNOPSIS
        Does this workflow run on a push to $Branch? $true only where the text says so plainly.

    .DESCRIPTION
        FOUR SHAPES ANSWER YES, and they are the four GitHub's own documentation writes:

          on: push                             -- every branch, so the trunk among them
          on: [push, ...]                      -- the same, in flow form
          on: / push:  with no branches filter -- every branch again
          on: / push: / branches: [main]       -- or the block-sequence form under `branches:`

        A `branches:` FILTER IS MATCHED ON THE NAME, in the flow form or the block-sequence form, and a
        quoted entry is accepted. A GLOB THAT MERELY COULD MATCH IS NOT -- `branches: ['*']` answers no.
        Evaluating a glob correctly means implementing GitHub's own filter-pattern grammar, and getting
        that subtly wrong returns a false positive, which is the expensive direction. A repo whose fold
        runner is written that way keeps today's refusal and loses nothing it had.

        `branches-ignore:` ANSWERS NO, WITHOUT BEING EVALUATED, for the same reason one step further on:
        proving the trunk is not excluded needs the same grammar and carries the same risk. This is the
        file header's ambiguity rule applied to the construct most likely to carry one.

        THE `push:` KEY IS FOUND BY INDENTATION, not by a bare match on the word. Comments, `paths:`
        entries and branch names can all contain 'push', and a workflow that runs only on
        `pull_request` while mentioning push in a comment must not read as a push trigger.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$WorkflowText,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    $block = @(Get-WorkflowTriggerBlock -WorkflowText $WorkflowText)
    if ($block.Count -eq 0) { return $false }

    # THE KEY'S OWN LINE FIRST: the two inline forms carry the whole mapping there and have no
    # sub-block at all, so they are answered before any indentation is measured.
    $head = $block[0]
    if ($head -match '^(?:on|"on"|''on'')\s*:\s*(\S.*)$') {
        $inline = $Matches[1].Trim()
        # A trailing comment is not part of the value. Split on whitespace-then-hash rather than on a
        # bare hash, so a value legitimately containing one is not cut in half.
        $inline = ($inline -split '\s+#')[0].Trim()
        if ($inline -eq 'push') { return $true }
        if ($inline -match '^\[(.*)\]$') {
            $items = @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') })
            return ($items -contains 'push')
        }
        # Something else entirely on the key's line: no push trigger is stated and none is inferred.
        return $false
    }

    # THE INDENTED FORM. Find `push:` as a key, remember how deep it sits, and read everything deeper
    # than it as its sub-block -- stopping at the first line at its own depth or shallower, which is
    # the next sibling trigger.
    #
    # THE SEARCH FOR THE KEY AND THE COLLECTION OF ITS BLOCK ARE TWO DIFFERENT TESTS, and conflating
    # them is a bug this file's own suite caught on its first run. A KEY line has to carry a colon; a
    # line of the block does not -- `- main` under `branches:` is a sequence item and carries none. A
    # single loop that skipped every colon-less line found `push:` correctly and then collected a
    # sub-block with every branch name missing from it, so the block-sequence form (which is how every
    # runner this workflow ships is written) answered no.
    $pushIndent = -1
    $sub = @()
    for ($i = 1; $i -lt $block.Count; $i++) {
        $line = $block[$i]
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        if ($pushIndent -lt 0) {
            if (-not ($line -match '^(\s+)(\S+?)\s*:')) { continue }
            if ($Matches[2].Trim("'", '"') -eq 'push') { $pushIndent = $Matches[1].Length }
            continue
        }
        # INDENT MEASURED OFF THE LINE ITSELF, whatever it carries. Anything deeper than `push:` belongs
        # to it; the first thing at its own depth or shallower is the next sibling trigger and ends it.
        $null = $line -match '^(\s*)'
        if ($Matches[1].Length -le $pushIndent) { break }
        $sub += $line
    }
    if ($pushIndent -lt 0) { return $false }

    # THE FILTER KEYS ARE READ AS A SET FIRST, and the branch list is read only from under its OWN key.
    # Both halves of that are repairs of a first build that asked simpler questions:
    #
    #   - "no `branches:` key means every branch" is WRONG when a tag filter is present. GitHub runs a
    #     `push:` carrying only `tags:` (or `tags-ignore:`) on TAG pushes and not on branch pushes at
    #     all, so reading it as "every branch" is a false positive -- the expensive direction, and one
    #     no consumer's own workflow has to be unusual to hit.
    #   - reading every `- <item>` in the whole push sub-block lets a `paths:` entry spelled exactly
    #     like the trunk (`- main`) answer for `branches:`. That was noted as an accepted limitation in
    #     the first build; it is cheaper to read the list properly than to keep explaining it.
    $wanted = $Branch.Trim()
    $branchesIndent = -1
    $hasBranches = $false
    $hasIgnore = $false
    $hasTagFilter = $false
    $inBranchList = $false

    foreach ($line in $sub) {
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        $null = $line -match '^(\s*)'
        $indent = $Matches[1].Length

        # A LIST ENTRY BELONGS TO THE KEY ABOVE IT, and the key's own indent is what ends the list.
        if ($inBranchList) {
            if ($indent -le $branchesIndent) { $inBranchList = $false }
            elseif ($line -match '^\s*-\s*(.+?)\s*$') {
                $item = ($Matches[1].Trim() -split '\s+#')[0].Trim().Trim("'", '"')
                if ($item -eq $wanted) { return $true }
                continue
            } else { continue }
        }

        if ($line -match '^\s*(branches|branches-ignore|tags|tags-ignore)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            switch ($key) {
                'branches-ignore' { $hasIgnore = $true }
                'tags-ignore'     { $hasTagFilter = $true }
                'tags'            { $hasTagFilter = $true }
                'branches'        {
                    $hasBranches = $true
                    if ($value -match '^\[(.*)\]$') {
                        $items = @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') })
                        if ($items -contains $wanted) { return $true }
                    } elseif (-not $value) {
                        # A block sequence follows: its entries are the lines deeper than this key.
                        $branchesIndent = $indent
                        $inBranchList = $true
                    }
                }
            }
        }
    }

    # `branches-ignore:` ANSWERS NO WITHOUT BEING EVALUATED -- see this function's own description.
    if ($hasIgnore) { return $false }
    # A BRANCH LIST THAT DID NOT NAME THE TRUNK IS A NO, whatever else the block carries.
    if ($hasBranches) { return $false }
    # NO BRANCH FILTER, BUT A TAG ONE: this workflow fires on tag pushes and not on branch pushes.
    if ($hasTagFilter) { return $false }
    # PUSH WITH NO FILTER AT ALL RUNS ON EVERY BRANCH. That is GitHub's documented default, and it is
    # the shape a minimal fold runner is most likely to be written in.
    return $true
}

function Test-WorkflowRunsScript {
    <#
    .SYNOPSIS
        Does this workflow actually RUN $ScriptName, as opposed to merely mentioning it?

    .DESCRIPTION
        THE FALSE POSITIVE THIS CLOSES WAS LIVE IN THE SOURCE REPO, which is why it is a function
        rather than a sharpened regex. The first build asked `$body -match <script name>` over the
        whole file, and this repo has TWO workflows that trigger on a push to the trunk and name
        fold-changelog-entry.ps1: fold-on-merge.yml, which runs it, and unfolded-entry.yml, which
        mentions it in a COMMENT on line 3 while running only the detector. The second one qualified.

        IT WAS MASKED BY ALPHABETICAL ORDER, AND THAT IS THE WORST PART. Get-ChildItem returns
        fold-on-merge.yml first, the verdict stops at the first qualifying file, and the suite's assert
        on the real directory passed -- on the ordering, not on the recogniser. Rename or delete the
        real runner and this repo would have believed CI folds while nothing did, which is the
        merged-and-unfolded state this whole file exists to avoid producing.

        SO THE MENTION HAS TO SIT IN A COMMAND. A `run:` step is what executes something; a comment, a
        `paths:` filter, a job name and a workflow description do not. `uses:` is deliberately NOT
        accepted: it names an action rather than a script, so a consumer folding through a composite
        action reads as no recovery -- a false negative, which costs the refusal they already had.

        BOTH RUN FORMS, because a workflow writes either. An inline `run: pwsh -File ...` carries the
        command on the key's own line; a block scalar (`run: |`) carries it on the lines indented under
        it, and those end at the first line back at the key's own depth or shallower.

        A COMMENT IS DROPPED WHEREVER IT SITS -- a whole line, or the tail of one. Inside a `run:` block
        the language is a shell, where `#` opens a comment in both sh and PowerShell, so a commented-out
        call is exactly the thing this must not read as a fold. The tail is cut on whitespace-then-hash
        so a value legitimately carrying one is not cut in half; a `#` inside a quoted string would cut
        early, which loses the mention and answers no. That is the safe direction, and it is the file
        header's ambiguity rule reaching one layer further in.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$WorkflowText,
        [Parameter(Mandatory = $true)][string]$ScriptName
    )

    if (-not $WorkflowText) { return $false }
    $needle = [regex]::Escape($ScriptName)
    $lines = $WorkflowText -split "`r`n|`n|`r"

    $runIndent = -1
    foreach ($line in $lines) {
        # A whole-line comment is never a command, inside a block or outside one.
        if ($line -match '^\s*#') { continue }

        if ($runIndent -ge 0) {
            if ($line -match '^\s*$') { continue }
            $null = $line -match '^(\s*)'
            if ($Matches[1].Length -le $runIndent) {
                # Back at the key's own depth or shallower: the block has ended. Fall through so this
                # same line can still open a `run:` of its own -- the next step in the same list.
                $runIndent = -1
            } else {
                if ((($line -split '\s+#')[0]) -match $needle) { return $true }
                continue
            }
        }

        # THE KEY ITSELF. The optional '- ' is the sequence marker of a step whose first key is `run`,
        # and the indent that matters is the KEY's, not the marker's, because that is what the block's
        # own lines are measured against.
        if ($line -match '^(\s*)((?:-\s+)?)run\s*:\s*(.*)$') {
            # THE MARKER'S WIDTH COUNTS TOWARDS THE KEY'S COLUMN. '      - run: |' puts `run` at column
            # 8, not 6, and the step's sibling keys (`env:`, `with:`, `if:`) sit at that same 8 -- so
            # measuring from the dash reads them as part of the block and any script name under them as
            # a command. Caught by this file's own suite, against the comment two lines up that already
            # said the key's indent was what mattered.
            $keyIndent = $Matches[1].Length + $Matches[2].Length
            $value = $Matches[3].Trim()
            if ($value -match '^[|>][+-]?\d*$') { $runIndent = $keyIndent; continue }
            if ($value -and (($value -split '\s+#')[0]) -match $needle) { return $true }
        }
    }
    return $false
}

function Get-CiFoldRecoveryVerdict {
    <#
    .SYNOPSIS
        Is there a workflow in this repo that folds the changelog off a push to the trunk?

    .DESCRIPTION
        TWO CONDITIONS, BOTH REQUIRED, AND NEITHER IS THE FILE'S NAME. A workflow qualifies when it runs
        on a push to the trunk AND names the fold script. Matching on the name fold-on-merge.yml would
        be matching on a convention this workflow does not own: a consumer may rename it, and
        adopt-dkj-policy places it under that name without promising it forever. What cannot be renamed
        is the script it has to call.

        THE SCRIPT IS MATCHED BY FILENAME, NOT BY PATH. A consumer's runner checks this repository out
        beside its own tree and runs a path into it, and that path has moved before -- so pinning the
        directory would make this go quietly false on exactly the repos it is for. The filename is what
        every one of those paths ends in.

        ONE VERDICT FOR THE WHOLE SET, NAMING THE FIRST WORKFLOW THAT QUALIFIES. The name is for the
        sentence ship-pr prints, so the operator can read the runner that now owns their fold; nothing
        downstream branches on WHICH one it is.

        AN UNREADABLE FILE IS COUNTED, NOT GUESSED AT. Files and Readable come back separately for the
        reason Test-ConsumerRunnerAdoption reports them: "I read four workflows and none folds" and "I
        could read none of the four" are different sentences, and only the first is a verdict.
    #>
    param(
        # One record per workflow file, carrying Name and Text, with Text $null where the bytes could
        # not be obtained. Either a hashtable or an object -- a hashtable's PSObject.Properties are
        # Keys/Values/Count, so reading only one shape is a silent miss rather than an error.
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()][object[]]$Workflow,
        [Parameter(Mandatory = $true)][string]$TrunkBranch,
        # The script a qualifying workflow has to name. A parameter rather than a constant so the suite
        # can pin the negative case without depending on this repo's own file being present.
        [string]$FoldScriptName = 'fold-changelog-entry.ps1'
    )

    $files = @(@($Workflow) | Where-Object { $null -ne $_ })
    $readable = 0
    $found = ''

    foreach ($wf in $files) {
        $text = $null
        $name = ''
        if ($wf -is [System.Collections.IDictionary]) {
            if ($wf.Contains('Text')) { $text = $wf['Text'] }
            if ($wf.Contains('Name')) { $name = [string]$wf['Name'] }
        } else {
            if ($wf.PSObject.Properties.Name -contains 'Text') { $text = $wf.Text }
            if ($wf.PSObject.Properties.Name -contains 'Name') { $name = [string]$wf.Name }
        }
        if ($null -eq $text) { continue }
        $readable++
        if ($found) { continue }
        $body = [string]$text
        # THE MENTION HAS TO BE A COMMAND, not a substring of the file. See Test-WorkflowRunsScript:
        # asking the whole text qualified this repo's own unfolded-entry.yml, which triggers on a push
        # to the trunk and names the fold script in a comment while running only the detector.
        if (-not (Test-WorkflowRunsScript -WorkflowText $body -ScriptName $FoldScriptName)) { continue }
        if (Test-PushTriggerOnBranch -WorkflowText $body -Branch $TrunkBranch) { $found = $name }
    }

    $reason =
        if ($found)                 { '' }
        elseif ($files.Count -eq 0) { 'no workflow files were found' }
        elseif ($readable -eq 0)    { 'no workflow file could be read' }
        else                        { "no workflow runs $FoldScriptName on a push to '$TrunkBranch'" }

    return [pscustomobject]@{
        Recovered = [bool]$found
        Workflow  = $found
        Files     = $files.Count
        Readable  = $readable
        Reason    = $reason
    }
}

function Get-RepoWorkflowRecord {
    <#
    .SYNOPSIS
        Read .github/workflows/*.yml|*.yaml off disk as the {Name; Text} records the verdict above takes.

    .DESCRIPTION
        THE ONE IMPURE FUNCTION IN THIS FILE, and it is here rather than inline in ship-pr.ps1 so the
        verdict's two callers cannot disagree about what a workflow file is. Everything above it is a
        pure function of text and is tested as one; this is the disk read they are fed from.

        A FILE THAT CANNOT BE READ COMES BACK WITH Text = $null RATHER THAN BEING DROPPED. That is the
        distinction the verdict's Readable count exists to report -- a dropped file would make an
        unreadable set indistinguishable from an empty one, which is the exact ambiguity
        Test-ConsumerRunnerAdoption was written to close.

        BOTH EXTENSIONS, BECAUSE GITHUB ACCEPTS BOTH. Every runner this workflow ships is .yml; a
        consumer's own may not be, and reading only one extension would answer "no recovery" on a repo
        that has it.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $dir = Join-Path $RepoRoot '.github/workflows'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    $records = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.yml', '.yaml') })) {
        $text = $null
        try {
            $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        } catch {
            $text = $null
        }
        $records += [pscustomobject]@{ Name = $file.Name; Text = $text }
    }
    return @($records)
}
