<#
.SYNOPSIS
    Report mechanisms one consumer has and its sibling does not -- the divergence between two repos
    that are meant to run the same floor -- and the ones a plugin here already ships, which is an
    adoption gap rather than divergence. Issues #1869, #1885.

.DESCRIPTION
    WHAT THIS ANSWERS, and it is a question nothing else here asks. check-consumer-drift.ps1 compares
    a consumer against THIS source; check-connectors.ps1 asks whether a consumer's register record is
    true. Both are source-to-consumer. This one is consumer-to-CONSUMER: two repos declared siblings
    build the same mechanism twice, each ahead of the other on different things, and nothing carries
    either way.

    WHY IT IS WORTH A SCRIPT, measured 2026-09-11 in the two BWJ stores (#1869): of the 48 tooling
    paths they share, 47 have diverged, and the ONE that has not is a verbatim template this plugin
    ships. The load-bearing instance is scripts/task/prune-merged.ps1 -- inbound #815 asked for it
    centrally, dkj-policy 4.21.0 shipped it, one store replaced its copy with a forwarder and the
    other still carried its own 120-line version three weeks later. The inbound route worked; nothing
    propagated the result to the second consumer.

    IT REPORTS AND REFUSES NOTHING, by default. That is the shape Dave chose on 2026-09-11 when the
    three candidate repairs were put to him: land the detector first, converge afterwards. A detector
    changes no ownership and needs no consumer to adopt anything, which is what lets it run today
    against repos whose convergence is still a decision. -FailOnFinding is there for a repo that
    later wants it as a gate; nothing in this workflow passes it.

    THE GROUPING IS DECLARED, NEVER INFERRED -- see Group-SiblingConsumer in the lib for why. A
    manifest opts in with a 'siblingGroup' field; one without it is in no group and is never
    compared.

    WHERE THE TREES ARE READ FROM, and it says so in the report rather than leaving you to guess:

      github (default where gh can answer)  the member's trunk, via one git-trees call per member.
                                            Blob shas come back with the listing, so the whole
                                            path-level comparison costs one call per member and no
                                            content is transferred at all.
      disk                                  a resolved localCheckout, hashed file by file.

    ONE SCHEME PER GROUP, ALWAYS. A blob sha and a content hash are not comparable, so a group whose
    members cannot all be read the same way is reported as unreadable rather than compared with a
    mixed vocabulary -- which would report every path in it as drifted, a false alarm indistinguishable
    from the finding this script exists to make.

    THE SHIPPED LANE ANSWERS A THIRD QUESTION, and it is not consumer-to-consumer at all (#1885).
    For every only-in, partial and drifted path it asks whether a plugin in THIS marketplace already
    publishes a script of that name -- because if one does, the mechanism already has an owner and the
    repair is to adopt it, not to decide who should own it. Nothing here could see that before: the
    drift check compares agent defs and personas, this one compares two consumers, and the script
    contract asks whether a consumer exposes the seam functions the shared scripts call. So the
    CHEAPEST convergence was the invisible one while the expensive kind was the only kind reported.
    The lane ADDS and never reclassifies -- the match is on filename, and a wrong one must cost a file
    to open rather than delete a real divergence finding from the report.

    THE ALIAS PASS IS THE ONE THAT COSTS CONTENT, and it is bounded to the ONLY-IN set: a path present
    in every member cannot be aliased, so the files whose text has to be read are exactly the ones
    already reported as only-in, and only the .ps1 among those. Skip it with -SkipAliasCheck.

    PRIVACY. The consumers are private repos and this one is public, so the boundary matters. This
    script PRINTS to a console and writes nothing into the tree -- no findings file, no manifest
    field beyond the group label an operator types. What it prints is paths and function names, never
    file content, and the test fixtures are synthetic for the same reason.

    Exit code: 0 always, unless -FailOnFinding is given, in which case 1 on any ONLY-IN, DRIFTED,
    ALIASED or SHIPPED finding. A group that could not be read is an [INFO] and never an error -- an
    absent checkout or an unauthenticated gh is a fact about this machine, not about the consumers.

.PARAMETER Group
    (Optional) Restrict the run to one sibling group by name.

.PARAMETER Source
    'auto' (default), 'github' or 'disk'. auto prefers github where gh answers, and falls back to
    disk. See ONE SCHEME PER GROUP above.

.PARAMETER SkipAliasCheck
    Skip the capability-aliasing pass (the only pass that reads file content).

.PARAMETER FailOnFinding
    Exit 1 when any finding is reported. Off by default -- this is a detector, not a gate.

.PARAMETER ConnectorDir
    (Optional, for tests) Read manifests from this directory instead of connectors/.

.EXAMPLE
    .\scripts\sync\check-consumer-siblings.ps1
.EXAMPLE
    .\scripts\sync\check-consumer-siblings.ps1 -Group bwj-store -SkipAliasCheck
#>
[CmdletBinding()]
param(
    [string]$Group = '',
    [ValidateSet('auto', 'github', 'disk')][string]$Source = 'auto',
    [switch]$SkipAliasCheck,
    [switch]$FailOnFinding,
    [string]$ConnectorDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:errors = 0
$script:infos  = 0

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\sibling-divergence-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\hash-hex-lib.ps1')

if ($ConnectorDir -eq '') { $ConnectorDir = Join-Path $RepoRoot 'connectors' }

Write-Host ''
Write-Host '== check-consumer-siblings: mechanisms one consumer has and its sibling does not ==' -ForegroundColor Cyan

# ---------------------------------------------------------------------------------------------------
# Reading a member's tooling inventory
# ---------------------------------------------------------------------------------------------------

function Test-GhCanAnswer {
    <#
        Is gh present AND authenticated. Both, because an installed-but-logged-out gh answers every
        api call with an error that parses as "repository not found" -- which would be read as a
        consumer whose tooling layer is empty, i.e. the entire comparison reported as ONLY-IN against
        whichever member happened to be readable. That is the worst possible false alarm here, so the
        question is asked once, up front, rather than inferred from a failure.
    #>
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
    try {
        $r = Invoke-NativeCapture -FilePath 'gh' -Arguments @('auth', 'status') `
                                  -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        # AUDITED UNDER #2081 AND LEFT AS IT IS. An unmeasurable exit code (#1931) is not `-eq 0`, so this
        # already answers $false -- "assume no credential", which skips the remote route and keeps the
        # register on disk. That is the fail-safe direction and it costs nothing but one sweep's reach, so
        # the site needs no third state; the positive comparison is what makes it right, and that is the
        # decision rather than an accident.
        return ($r.ExitCode -eq 0 -and -not $r.TimedOut)
    } catch { return $false }
}

function Get-GitHubInventory {
    <#
        One git-trees call, recursive. Returns @{ Ok; Reason; Paths = @{ path -> blob sha } }.

        The blob sha is git's own content identity, so two members agreeing on it is proof the file is
        byte-identical without either file being transferred. That is what keeps the path-level
        comparison to one network call per member.
    #>
    param([Parameter(Mandatory)][string]$Repo)

    $slug = Test-GitHubOwnerNameSlug -Slug $Repo
    if (-not $slug.Ok) { return @{ Ok = $false; Reason = "the manifest's 'repo' field is $($slug.Reason)"; Paths = @{} } }

    # The default branch is asked for by name rather than assumed to be 'main': this register already
    # holds consumers that were moved between orgs, and a wrong branch name returns the same 404 as an
    # unreadable repo.
    $head = Invoke-NativeCapture -FilePath 'gh' `
        -Arguments @('api', "repos/$Repo", '--jq', '.default_branch') `
        -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if ($head.TimedOut) { return @{ Ok = $false; Reason = "gh did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"; Paths = @{} } }
    # AN UNMEASURABLE EXIT CODE IS ASKED FOR AHEAD OF THE NUMBER (issue #1931, audited under #2081), at
    # both of this function's reads. `$null -ne 0` is true, so the arm below fired and the Reason printed
    # as "gh exited  reading the default branch (no access, or the repo is gone)" -- a missing number, and
    # two diagnoses about a consumer repository that this run measured nothing about. Ok stays $false
    # either way; it is the sentence the register carries to a reader that had to change.
    # AND A COULD-NOT-START READING AHEAD OF THAT ONE, AT BOTH READS (issue #2250, on #2234's repair). A
    # gh that never started sets ExitCodeUnknown on purpose, so absorbed by the arm above it a missing gh
    # is described as one that ran, and the Reason this register carries to a reader closes with advice
    # that cannot work: a command that is not installed does not settle on a re-run.
    #
    # AND IT IS REACHABLE HERE DESPITE Test-GhCanAnswer, which is the whole reason this arm is worth
    # writing rather than reasoning away. That guard opens with `Get-Command gh` and would indeed keep an
    # absent gh away from this function -- but it is consulted only on the DEFAULT route: `-Source github`
    # sets $useGitHub straight to $true and never asks it. So the one caller who forces the remote route
    # on a machine without gh lands here exactly as #2250 describes, and this arm names the remedy.
    if (-not (Test-NativeCommandStarted -Capture $head)) { return @{ Ok = $false; Reason = 'gh is not installed here, or is not on PATH (issue #2234), so the default branch was never read -- a fact about this machine rather than about that repository; a re-run will not settle it, and with -Source github this run never asked whether gh was available. Install the GitHub CLI, or drop -Source github to compare off the disk'; Paths = @{} } }
    if (-not (Test-NativeExitMeasured -Capture $head)) { return @{ Ok = $false; Reason = 'gh ran and its exit code came back unmeasurable (issue #1931) reading the default branch -- a fact about this run rather than about that repository; it normally settles on a re-run'; Paths = @{} } }
    if ($head.ExitCode -ne 0) { return @{ Ok = $false; Reason = "gh exited $($head.ExitCode) reading the default branch (no access, or the repo is gone)"; Paths = @{} } }
    $branch = ([string]($head.Output -join '')).Trim()
    if ($branch -eq '') { return @{ Ok = $false; Reason = 'the default branch came back empty'; Paths = @{} } }

    $call = Invoke-NativeCapture -FilePath 'gh' `
        -Arguments @('api', "repos/$Repo/git/trees/$branch`?recursive=1", '--jq', '.tree[] | select(.type=="blob") | "\(.sha) \(.path)"') `
        -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if ($call.TimedOut) { return @{ Ok = $false; Reason = "gh did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"; Paths = @{} } }
    # The second of the two reads named above, and it takes the same arm for the same reason. In practice
    # the first read is what fails on a gh-less machine and this one is never reached -- but "unreachable
    # because its sibling refuses first" is a property of the other read rather than of this one, and the
    # pair is deliberately kept in step so a later change to that arm cannot silently leave this one lying.
    if (-not (Test-NativeCommandStarted -Capture $call)) { return @{ Ok = $false; Reason = 'gh is not installed here, or is not on PATH (issue #2234), so the tree was never read -- a fact about this machine rather than about that repository; a re-run will not settle it. Install the GitHub CLI, or drop -Source github to compare off the disk'; Paths = @{} } }
    if (-not (Test-NativeExitMeasured -Capture $call)) { return @{ Ok = $false; Reason = 'gh ran and its exit code came back unmeasurable (issue #1931) reading the tree -- a fact about this run rather than about that repository; it normally settles on a re-run'; Paths = @{} } }
    if ($call.ExitCode -ne 0) { return @{ Ok = $false; Reason = "gh exited $($call.ExitCode) reading the tree of $branch"; Paths = @{} } }

    $paths = @{}
    foreach ($line in @($call.Output)) {
        $s = [string]$line
        $sp = $s.IndexOf(' ')
        if ($sp -lt 1) { continue }
        $p = ConvertTo-SiblingPath -Path $s.Substring($sp + 1)
        if (Test-IsSiblingComparablePath -Path $p) { $paths[$p] = $s.Substring(0, $sp) }
    }
    return @{ Ok = $true; Reason = "github:$branch"; Paths = $paths }
}

function Get-DiskInventory {
    <#
        A resolved localCheckout, hashed file by file. Returns the same shape as the GitHub route.

        The hash is over LF-NORMALIZED content, not the raw bytes. Two checkouts of the same file can
        differ only in line endings -- core.autocrlf is per-machine -- and reporting that as drift
        would put every shared path in the report on the first Windows machine to run this.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $paths = @{}
    foreach ($rootRel in (Get-SiblingComparableRoot)) {
        $dir = Join-Path $Root ($rootRel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue)) {
            $rel = ConvertTo-SiblingPath -Path ($f.FullName.Substring($Root.Length).TrimStart('\', '/'))
            if (-not (Test-IsSiblingComparablePath -Path $rel)) { continue }
            $text = ''
            try { $text = [System.IO.File]::ReadAllText($f.FullName) } catch { $text = '' }
            $norm = $text -replace "`r`n", "`n"
            # SHARED SINCE #2058, and this site is why the issue's "nothing observable is wrong"
            # turned out to be the weaker half of its own case. The copy that stood here disposed
            # nothing -- one provider per file, inside the Get-ChildItem -Recurse above -- and
            # rendered UPPERCASE, where every other copy of the idiom rendered lowercase. The case is
            # unobservable because a run picks ONE scheme ($useGitHub) and these values are only ever
            # compared with each other, never printed, stored or carried across runs; that is what
            # let it drift unnoticed rather than what made it harmless to fix.
            $paths[$rel] = Get-Sha256Hex -Text $norm
        }
    }
    return @{ Ok = $true; Reason = 'disk'; Paths = $paths }
}

function Resolve-ConsumerCheckout {
    <#
        The first localCheckout candidate present on this machine, or ''. Deliberately the same
        first-match-wins rule check-connectors.ps1 applies, and deliberately NOT a second
        implementation of its guardrails: this route is only ever reached for a manifest that check
        already validates, and an absolute or out-of-scope path here simply fails to resolve under
        the repo root and is reported as absent.
    #>
    param([Parameter(Mandatory)][object]$Manifest)

    if (-not $Manifest.PSObject.Properties['localCheckout']) { return '' }
    foreach ($c in @(@($Manifest.localCheckout) | Where-Object { $null -ne $_ -and [string]$_ -ne '' })) {
        if ([System.IO.Path]::IsPathRooted([string]$c)) { continue }
        $full = Join-Path $RepoRoot ([string]$c -replace '/', '\')
        if (Test-Path -LiteralPath $full) { return (Resolve-Path -LiteralPath $full).Path }
    }
    return ''
}

function Get-OnlyInContentMap {
    <#
        The text of the ONLY-IN .ps1 files, per member, for the alias pass. Same route the inventory
        came from, so a group read over the network does not silently start reading a disk.
    #>
    param(
        [Parameter(Mandatory)][object[]]$OnlyIn,
        [Parameter(Mandatory)][hashtable]$MemberSource
    )

    $map = @{}
    foreach ($f in $OnlyIn) {
        if ($f.Path -notmatch '\.ps1$') { continue }
        $label = $f.Member
        $src   = $MemberSource[$label]
        $text  = ''

        if ($src.Route -eq 'disk') {
            $full = Join-Path $src.Root ($f.Path -replace '/', '\')
            if (Test-Path -LiteralPath $full) { try { $text = [System.IO.File]::ReadAllText($full) } catch { $text = '' } }
        } else {
            $call = Invoke-NativeCapture -FilePath 'gh' `
                -Arguments @('api', "repos/$($src.Repo)/contents/$($f.Path)?ref=$($src.Branch)", '--jq', '.content') `
                -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
            # AUDITED UNDER #2081 AND LEFT AS IT IS, for the reason the positive comparison already gives:
            # an unmeasurable exit code (#1931) is not `-eq 0`, so $text stays empty and the file drops out
            # of the comparison -- exactly what the disk route above does for a file it cannot read. A file
            # this sweep did not read produces no drift finding, which under-reports rather than
            # mis-reports, and the register is advisory. A per-file warning was the alternative and was
            # declined: it would fire on every legitimately absent path too.
            if (-not $call.TimedOut -and $call.ExitCode -eq 0) {
                $b64 = (@($call.Output) -join '') -replace '\s', ''
                if ($b64 -ne '') {
                    try { $text = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64)) } catch { $text = '' }
                }
            }
        }

        if ($text -eq '') { continue }
        if (-not $map.ContainsKey($label)) { $map[$label] = @{} }
        $map[$label][$f.Path] = $text
    }
    return $map
}

function Get-MarketplaceShippedScript {
    <#
        Every .ps1 this marketplace publishes, as @{ Plugin; Path } -- the set a consumer's local copy
        is held against for the SHIPPED lane (#1885).

        TWO SOURCES, because neither alone is the answer. Get-SharedScriptPairs is the REGISTRY of
        scripts mirrored from this workshop into a plugin, and it is authoritative about the ones it
        names -- including one whose mirror has not been written yet. Walking each published plugin's
        own scripts/ and hooks/ catches what a plugin ships DIRECTLY and no registry knows about, and
        that is where the four scripts #1885 measured actually sit: push-preview.ps1, sync-main.ps1,
        preview-theme.ps1 and sync-rules.ps1 are dkj-subagents-shopify's own, registered nowhere.

        hooks/ IS WALKED ALONGSIDE scripts/. A consumer re-implementing a plugin's hook does not put
        it in a hooks/ folder of its own -- it lands in scripts/, which is where the comparable roots
        look. Asking only about the plugin's scripts/ would make exactly that copy invisible, and a
        guard is the last mechanism anyone wants duplicated quietly.

        IT DEGRADES TO AN EMPTY SET, NEVER THROWS. This is a detector's extra lane, and a marketplace
        this run cannot parse must cost the SHIPPED lane and nothing else -- the consumer-to-consumer
        comparison above it is the part that was asked for and it needs none of this.
    #>
    $shipped = @()

    $pluginRoots = @()
    try { $pluginRoots = @(Get-RepoPluginRoots -RepoRoot $RepoRoot) } catch { return @() }
    if ($pluginRoots.Count -eq 0) { return @() }

    try {
        foreach ($pair in @(Get-SharedScriptPairs -RepoRoot $RepoRoot -PluginRoots $pluginRoots)) {
            $shipped += @([pscustomobject]@{ Plugin = [string]$pair.Plugin; Path = [string]$pair.MirrorRel })
        }
    } catch {
        # A registry that names a plugin the marketplace does not declare throws by design. The direct
        # walk below is unaffected and is the larger half, so the lane reports what it can.
        Write-Info "the shared-scripts registry could not be read ($($_.Exception.Message)) -- the SHIPPED lane covers only what the plugins ship directly."
    }

    foreach ($p in $pluginRoots) {
        foreach ($sub in @('scripts', 'hooks')) {
            $dir = Join-Path $p.Root $sub
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
                $rel = $f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
                $shipped += @([pscustomobject]@{ Plugin = [string]$p.Name; Path = $rel })
            }
        }
    }

    return @($shipped)
}

# ---------------------------------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $ConnectorDir)) {
    Write-Failure "no connectors directory at '$ConnectorDir'."
    Write-CheckSummary
    exit 1
}

$manifests = @()
foreach ($mf in (Get-ChildItem -LiteralPath $ConnectorDir -Filter '*.json' -File | Sort-Object Name)) {
    try {
        $obj = Get-Content -LiteralPath $mf.FullName -Raw | ConvertFrom-Json
        $obj | Add-Member -NotePropertyName '__file' -NotePropertyValue $mf.Name -Force
        $manifests = @($manifests) + @($obj)
    } catch {
        Write-Failure "connectors/$($mf.Name) is not valid JSON -- skipped."
    }
}

$groups = Group-SiblingConsumer -Manifest $manifests
if ($Group -ne '') {
    $filtered = [ordered]@{}
    foreach ($k in $groups.Keys) { if ($k -eq $Group) { $filtered[$k] = $groups[$k] } }
    $groups = $filtered
}

if (@($groups.Keys).Count -eq 0) {
    if ($Group -ne '') {
        Write-Skip "no sibling group named '$Group' with two or more members."
    } else {
        # NOT a finding. A register whose consumers are all independent is the ordinary state, and this
        # check is opt-in by design -- reporting its own inapplicability as a problem is how a detector
        # trains people to ignore it.
        Write-Skip "no sibling groups declared -- add a 'siblingGroup' field to two or more connectors manifests to compare them."
    }
    Write-CheckSummary
    exit 0
}

$useGitHub = switch ($Source) {
    'github' { $true }
    'disk'   { $false }
    default  { Test-GhCanAnswer }
}

# BUILT ONCE, OUTSIDE THE GROUP LOOP. What this marketplace publishes is a property of this repo, not
# of the group being compared, and the walk touches every plugin's script tree.
$shippedIndex = Get-ShippedScriptIndex -Shipped (Get-MarketplaceShippedScript)

$findingCount = 0

foreach ($groupName in $groups.Keys) {
    $members = @($groups[$groupName])
    Write-Host ''
    Write-Host "-- group '$groupName' ($($members.Count) members) --" -ForegroundColor Cyan

    $inventory    = @{}
    $memberSource = @{}
    $unreadable   = @()

    foreach ($m in $members) {
        $label = [string]$m.repo
        $inv   = $null

        if ($useGitHub) {
            $inv = Get-GitHubInventory -Repo $label
            if ($inv.Ok) {
                $memberSource[$label] = @{ Route = 'github'; Repo = $label; Branch = ($inv.Reason -replace '^github:', ''); Root = '' }
            }
        } else {
            $root = Resolve-ConsumerCheckout -Manifest $m
            if ($root -eq '') {
                $inv = @{ Ok = $false; Reason = 'no localCheckout candidate resolves on this machine'; Paths = @{} }
            } else {
                $inv = Get-DiskInventory -Root $root
                $memberSource[$label] = @{ Route = 'disk'; Repo = $label; Branch = ''; Root = $root }
            }
        }

        if (-not $inv.Ok) {
            # $label's guard arrived on the trunk with #2272 (PR #2275), independently of this
            # branch. What is added here is $inv.Reason, traced rather than assumed: every arm is
            # this script's own composed text (or embeds only a number) EXCEPT Get-GitHubInventory's
            # two, built from $branch -- the sibling's own default-branch name off gh's API
            # ('gh exited N reading the tree of <branch>', 'github:<branch>'). The whole sentence is
            # guarded as prose rather than picking that one arm apart at its composition site: the
            # underlying $inv.Reason is stripped of its 'github:' prefix into
            # $memberSource[$label].Branch and carried into a live contents/...?ref= call, so only
            # this print copy may be sanitized.
            $unreadable = @($unreadable) + @("$(Format-SafePathToken -Value $label) -- $(Format-SafeProseToken -Value $inv.Reason)")
            continue
        }
        $inventory[$label] = $inv.Paths
        # Same trace and the same two guards as above.
        Write-Host "   read $(Format-SafePathToken -Value $label) : $($inv.Paths.Count) comparable path(s) via $(Format-SafeProseToken -Value $inv.Reason)" -ForegroundColor DarkGray
    }

    # ONE SCHEME PER GROUP. Anything less than every member read the same way is not a smaller
    # comparison, it is a different and wrong one -- so the group is reported and skipped whole.
    if ($unreadable.Count -gt 0) {
        Write-Info ("group '$groupName' not compared -- " + ($unreadable -join '; ') + ". A comparison missing a member would report that member's whole tooling layer as absent.")
        continue
    }

    $result = Compare-SiblingInventory -Inventory $inventory

    Write-Host "   $($result.SharedCount) shared path(s), $($result.AgreedCount) identical, $(@($result.Drifted).Count) drifted" -ForegroundColor DarkGray

    # GROUPED BY MEMBER, because the reader's question is "what does the other one have that we do
    # not" -- one member at a time. A flat path-sorted list interleaves the two and makes the answer
    # something you have to assemble by eye, which on the BWJ pair is 75 lines of assembling.
    #
    # #2248: $label/$f.Member/$f.Members are a sibling group's own manifest 'repo' field and $f.Path is
    # a path read straight off that sibling's checkout (disk walk or GitHub listing) -- both foreign
    # text, guarded via Format-SafePathToken the same way check-connectors.ps1 already guards the same
    # manifest field (manifestRepo/remoteRepo/originRepo there).
    foreach ($label in @($result.Members)) {
        $mine = @($result.OnlyIn | Where-Object { $_.Member -eq $label })
        if ($mine.Count -eq 0) { continue }
        Write-Host "   ONLY-IN $(Format-SafePathToken -Value $label) ($($mine.Count)):" -ForegroundColor Yellow
        foreach ($f in $mine) {
            Write-Info "ONLY-IN  $(Format-SafePathToken -Value $f.Member)  $(Format-SafePathToken -Value $f.Path)"
            $findingCount++
        }
    }
    foreach ($f in @($result.Partial)) {
        Write-Info "PARTIAL  $(Format-SafePathToken -Value $f.Path) -- held by $(@($f.Members | ForEach-Object { Format-SafePathToken -Value $_ }) -join ', ') and not by the rest of the group"
        $findingCount++
    }
    foreach ($f in @($result.Drifted)) {
        Write-Info "DRIFTED  $(Format-SafePathToken -Value $f.Path)"
        $findingCount++
    }

    # THE SHIPPED LANE (#1885). Reported AFTER the three consumer-to-consumer lanes and never instead
    # of them: these paths are still only-in or drifted, and this line adds the fact that decides what
    # to do about them -- adopt, rather than pick an owner and move a mechanism that already has one.
    # #2248: $f.Path/$f.Members guarded as above. $f.Class is our own enum and $_.Plugin/$_.Path in
    # $where come off Get-MarketplaceShippedScript -- this repo's own marketplace index -- so neither is
    # foreign and neither is guarded.
    foreach ($f in (Find-ShippedMechanism -Comparison $result -Index $shippedIndex)) {
        $where = (@($f.Shipped | ForEach-Object { "$($_.Plugin) ($($_.Path))" }) -join '; ')
        Write-Info ("SHIPPED  $(Format-SafePathToken -Value $f.Path) -- carried by $(@($f.Members | ForEach-Object { Format-SafePathToken -Value $_ }) -join ', ') [$($f.Class)]; " +
                    "the marketplace already ships this: $where. An ADOPTION gap, not divergence. Matched on filename.")
        $findingCount++
    }

    if ($SkipAliasCheck) {
        Write-Skip 'capability-aliasing pass skipped (-SkipAliasCheck).'
        continue
    }
    if (@($result.OnlyIn).Count -eq 0) {
        Write-Host '   no only-in paths, so nothing can be aliased' -ForegroundColor DarkGray
        continue
    }

    $contentMap = Get-OnlyInContentMap -OnlyIn @($result.OnlyIn) -MemberSource $memberSource
    $aliased    = Find-AliasedCapability -OnlyInContent $contentMap
    foreach ($pair in (Group-AliasedCapability -Aliased $aliased)) {
        Write-Info ("ALIASED  $($pair.Pair) -- same capability under two names, evidence: " + (@($pair.Functions) -join ', '))
        $findingCount++
    }
}

Write-Host ''
if ($findingCount -eq 0) {
    Write-Ok 'no divergence reported between declared siblings.'
} else {
    Write-Host "  $findingCount finding(s). ONLY-IN and ALIASED are the ones that mean duplicated work; DRIFTED means two copies of one mechanism that have grown apart." -ForegroundColor Yellow
    Write-Host '  SHIPPED is the cheap one: the marketplace already owns that mechanism, so the repair is to adopt it rather than to decide who should.' -ForegroundColor Yellow
    Write-Host '  This check reports and never prevents -- converging is a decision about ownership, not a repair this script can make.' -ForegroundColor DarkGray
}

Write-CheckSummary

if ($FailOnFinding -and $findingCount -gt 0) { exit 1 }
if ($script:errors -gt 0) { exit 1 }
exit 0
