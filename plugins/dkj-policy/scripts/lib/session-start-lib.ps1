<#
.SYNOPSIS
    The pure half of measure-session-start.ps1: shaping the measured half of a session-start report,
    reading the history out of a previously published page, and injecting the data into the page
    template. No Write-Host, no exit, no counter.

.DESCRIPTION
    WHY IT IS A LIB. measure-session-start.ps1 is mostly plumbing around three things that can each be
    wrong in a way that looks right: which skills a session really loads, what the previous page said,
    and whether the data survives being put inside a <script> element. A suite can pin all three against
    fixtures only if they take plain arguments and return objects, so they live here and the script is
    arguments in, files out. Same reasoning as measure-skill-lib.ps1, whose parser this reuses.

    WHAT THIS FILE REACHES NO VERDICT ABOUT. Nothing here ranks, advises or judges. That boundary is the
    recorded outcome of issue #861: a script that reaches a verdict about what should go was argued down
    there, and the verdict was left to whoever reads the measurement. The model that runs the
    measure-session-start skill writes the actions and the advice; this file measures and renders.

    THE PUBLISHED PAGE IS ITS OWN HISTORY. The page embeds the data it was rendered from between two
    markers, so the next run reads the previous measurement back out of the page itself
    (Read-SessionStartDataBlock) and no state file has to live anywhere. A page without that block -- the
    hand-built first version -- simply has no history, and the report says so rather than inventing
    deltas.

    A SKILL WITH disable-model-invocation: true IS NOT IN THE SESSION. `claude plugin details` prices every
    skill description, including those whose flag removes the page from the model's context entirely
    (issue #2664), so the always-on figure for such a plugin is too high by exactly those rows. This lib
    splits them out (Split-SkillRowsByInvocation) and records which were excluded, so the number is
    reproducible and the exclusion is visible. The split itself lives in measure-skill-lib.ps1 since #2664,
    and measure-skill.ps1 uses it too, so both reports subtract the same rows.

    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot. It loads
    its own dependencies. No Set-StrictMode here: dot-sourcing would change the strict mode of the calling
    script. Pure ASCII, per the [script-ascii] gate.
#>

. (Join-Path $PSScriptRoot 'check-report-lib.ps1')
. (Join-Path $PSScriptRoot 'measure-skill-lib.ps1')
. (Join-Path $PSScriptRoot 'measure-context-lib.ps1')

# The two markers the page template carries around its data object. They are written once, here, and
# nothing else in the template may spell them: a marker mentioned in a comment would make "exactly one"
# false and the render would refuse. The END marker does not contain the BEGIN marker (the BEGIN one starts
# with '/*SESSION'), which is what lets IndexOf count each on its own.
$script:SessionStartBegin = '/*SESSION-START-DATA*/'
$script:SessionStartEnd   = '/*END-SESSION-START-DATA*/'

function Get-SessionStartMarkers {
    <# The marker pair, for a suite that wants to assert against the same strings the render uses. #>
    return [pscustomobject]@{ Begin = $script:SessionStartBegin; End = $script:SessionStartEnd }
}

# Test-SkillModelInvocationDisabled, Get-PayloadDirForPlugin and Split-SkillRowsByInvocation live in
# measure-skill-lib.ps1 since #2664, so measure-skill.ps1 splits the priced rows the same way this report
# does. This lib dot-sources that one, so its callers here are unaffected.

function ConvertTo-SessionStartPluginEntry {
    <#
        One enabled plugin as the collect JSON carries it. -Details is Get-PluginDetails' result (already
        past the parse cross-checks), -Split the Split-SkillRowsByInvocation result, -Payload the
        Get-PayloadDirForPlugin result or $null, -DeclaredAgents the manifest's agent count or $null.

        Agents are the rows of the details table that are not skills. Where the manifest declares agents the
        inventory counts as 0 (they load by path), the entry says so instead of letting 0 read as 'none'.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PluginId,
        [Parameter(Mandatory = $true)]$Details,
        [Parameter(Mandatory = $true)]$Split,
        $Payload = $null,
        [string]$EnabledBy = 'repo',
        [string]$InstalledVersion = '',
        $DeclaredAgents = $null
    )

    $skillNames = @($Details.InventorySkills)
    $agentRows = @($Details.Rows | Where-Object { $skillNames -notcontains $_.Component })
    $loadedSum = 0
    if (@($Split.Loaded).Count -gt 0) { $loadedSum = [int](($Split.Loaded | Measure-Object -Property AlwaysOn -Sum).Sum) }
    $excludedSum = 0
    if (@($Split.Excluded).Count -gt 0) { $excludedSum = [int](($Split.Excluded | Measure-Object -Property AlwaysOn -Sum).Sum) }
    $agentSum = 0
    if ($agentRows.Count -gt 0) { $agentSum = [int](($agentRows | Measure-Object -Property AlwaysOn -Sum).Sum) }

    $payloadVersion = $null
    $payloadExact = $false
    if ($null -ne $Payload) { $payloadVersion = $Payload.Version; $payloadExact = [bool]$Payload.Exact }

    $inventoryAgents = $null
    if ($Details.InventoryCounts -and $Details.InventoryCounts.Contains('Agents')) { $inventoryAgents = [int]$Details.InventoryCounts['Agents'] }
    $agentNote = $null
    if ($null -ne $DeclaredAgents -and [int]$DeclaredAgents -gt 0 -and $inventoryAgents -eq 0) {
        $agentNote = "the manifest declares $DeclaredAgents agent def(s) by path; the inventory counts them as 0 although they load in a session, so their descriptions are in no figure here"
    }

    return [ordered]@{
        id               = $PluginId
        name             = ($PluginId -split '@')[0]
        version          = $Details.Version
        installedVersion = $(if ($InstalledVersion) { $InstalledVersion } else { $null })
        payloadVersion   = $payloadVersion
        payloadMatches   = $payloadExact
        enabledBy        = $EnabledBy
        measured         = $true
        source           = 'claude plugin details (count_tokens API), the copy it priced (version; installedVersion is the one the record pins)'
        printedAlwaysOn  = $Details.AlwaysOnTotal
        skills           = [ordered]@{
            loadedTokens   = $loadedSum
            excludedTokens = $excludedSum
            loaded         = @($Split.Loaded | ForEach-Object { [ordered]@{ name = $_.Component; alwaysOn = $_.AlwaysOn; onInvoke = $_.OnInvoke } })
            excluded       = @($Split.Excluded | ForEach-Object { [ordered]@{ name = $_.Component; alwaysOn = $_.AlwaysOn; reason = 'disable-model-invocation: true' } })
            unverified     = @($Split.Unverified)
        }
        agents           = [ordered]@{
            countedTokens = $agentSum
            counted       = @($agentRows | ForEach-Object { [ordered]@{ name = $_.Component; alwaysOn = $_.AlwaysOn } })
            declared      = $DeclaredAgents
            note          = $agentNote
        }
    }
}

function ConvertTo-SessionStartDocumentEntry {
    <#
        One always-on document (a Get-AlwaysOnDocuments row) as the collect JSON carries it. The id is
        stable across runs and machines -- the tree-relative path, or for a document that loads from outside
        the tree the '@'-import target it was reached by -- because the next run matches on it to compute the
        delta. The display path has the user's home folded to '~' so the file carries no account name.
    #>
    param(
        [Parameter(Mandatory = $true)]$Doc,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$UserHome = ''
    )

    $display = [string]$Doc.Display
    $id = $display
    if ($Doc.Source -eq 'external') {
        if ($Doc.Target) { $id = 'external:' + [string]$Doc.Target } else { $id = 'external:' + (Split-Path $display -Leaf) }
        if ($UserHome) {
            $h = ($UserHome -replace '\\', '/').TrimEnd('/')
            if ($display.StartsWith($h, [System.StringComparison]::OrdinalIgnoreCase)) { $display = '~' + $display.Substring($h.Length) }
        }
    }

    $importedBy = $null
    if ($Doc.ImportedBy) {
        $ib = [string]$Doc.ImportedBy
        $repo = $RepoRoot.TrimEnd('\', '/')
        if ($ib.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
            $importedBy = ($ib.Substring($repo.Length) -replace '\\', '/').TrimStart('/')
        } else {
            $importedBy = $ib -replace '\\', '/'
            # Folded like the display path above: an import between two files outside the tree would
            # otherwise carry the account name in its folder.
            if ($UserHome) {
                $h2 = ($UserHome -replace '\\', '/').TrimEnd('/')
                if ($importedBy.StartsWith($h2, [System.StringComparison]::OrdinalIgnoreCase)) { $importedBy = '~' + $importedBy.Substring($h2.Length) }
            }
        }
    }

    $treeBytes = $null
    if ($null -ne $Doc.TreeBytes) { $treeBytes = [int64]$Doc.TreeBytes }

    return [ordered]@{
        id         = $id
        name       = (Split-Path $display -Leaf)
        sub        = $display
        source     = $Doc.Source
        hop        = $Doc.Hop
        importedBy = $importedBy
        exists     = [bool]$Doc.Exists
        bytes      = [int64]$Doc.Bytes
        lfBytes    = [int64]$Doc.LfBytes
        tokens     = (ConvertTo-EstimatedTokens -Bytes ([int64]$Doc.Bytes) -CharsPerToken $CharsPerToken)
        treeBytes  = $treeBytes
        measured   = $true
        tokensNote = 'bytes are measured; tokens are an estimate at the calibrated chars-per-token factor'
        origin     = 'measure-context-lib Get-AlwaysOnDocuments'
    }
}

function ConvertTo-SafeScriptJson {
    <#
        Compact JSON that is safe to put inside a <script> element. '<' becomes the six-character JSON escape, backslash plus u003c (valid
        inside any JSON string, and JSON has no '<' outside strings), which closes '</script' AND '<!--' in
        one rule. Windows PowerShell 5.1 already escapes it; PowerShell 7 does not, so the replace is not
        redundant, merely idempotent.
    #>
    param([Parameter(Mandatory = $true)]$Object)
    $json = ConvertTo-Json -InputObject $Object -Depth 20 -Compress
    # The replacement is the six ASCII characters of the JSON escape, never the decoded character:
    # it is composed from two halves because a tool in the authoring path decoded the literal escape,
    # and written decoded this line replaced '<' with itself -- a silent no-op on PowerShell 7.
    $json = $json.Replace('<', ('\' + 'u003c'))
    # A STAR-SLASH INSIDE THE DATA WOULD END THE MARKER SPAN EARLY, and with it the history: the data
    # sits between '/*...*/' markers that Read-SessionStartDataBlock finds with IndexOf, and a string that
    # carries the end marker (or any '*/') is cut there. '*' + backslash + '/' is the same JSON string
    # ('\/' is a legal JSON escape for '/'), and no marker can survive it. Composed from parts for the
    # reason the line above is: a tool in the authoring path rewrites a literal escape.
    return $json.Replace('*/', ('*' + '\' + '/'))
}

function Read-SessionStartDataBlock {
    <#
        Reads the data object back out of a rendered page. Returns Found, Data (the parsed object) and
        Reason. Found=$false with a Reason for a page that has no block (the hand-built first version), an
        empty placeholder, or JSON that does not parse -- in every case the caller renders without deltas and
        says why. It never throws on page content: the page is data, and a bad one is a finding.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Html)

    $i = $Html.IndexOf($script:SessionStartBegin, [System.StringComparison]::Ordinal)
    if ($i -lt 0) { return [pscustomobject]@{ Found = $false; Data = $null; Reason = 'the page has no data block (a hand-built page, or one rendered before this skill existed)' } }
    $start = $i + $script:SessionStartBegin.Length
    $j = $Html.IndexOf($script:SessionStartEnd, $start, [System.StringComparison]::Ordinal)
    if ($j -lt 0) { return [pscustomobject]@{ Found = $false; Data = $null; Reason = 'the page opens a data block and never closes it' } }

    $json = $Html.Substring($start, $j - $start).Trim()
    if ($json -eq '' -or $json -eq '{}') { return [pscustomobject]@{ Found = $false; Data = $null; Reason = 'the data block is the empty placeholder' } }
    try {
        $data = ConvertFrom-Json -InputObject $json
    } catch {
        return [pscustomobject]@{ Found = $false; Data = $null; Reason = 'the data block did not parse as JSON' }
    }
    return [pscustomobject]@{ Found = $true; Data = $data; Reason = '' }
}

function Set-JsonProperty {
    <# Sets a property on a parsed-JSON object whether or not it exists yet. #>
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name, $Value)
    Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
}

# Notes the last Merge-SessionStartPrevious wanted to tell its caller (a row it could not use). A lib prints
# nothing, so the caller reads these with Get-SessionStartMergeNotes and words the [INFO] lines itself.
$script:SessionStartMergeNotes = @()

function Get-SessionStartMergeNotes {
    <# The notes the most recent Merge-SessionStartPrevious left, as strings. #>
    return @($script:SessionStartMergeNotes)
}

function ConvertTo-Int64OrNull {
    <#
        A previous page is untrusted data, so a number read from it is parsed, never cast: a cast of
        'lots' throws and takes the whole render with it, where TryParse turns it into 'no history for this
        row'. Accepts whole numbers only (a number or a string of digits); anything else is $null.
    #>
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [bool]) { return $null }
    $parsed = [int64]0
    $text = [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    if ([int64]::TryParse($text, [System.Globalization.NumberStyles]::AllowLeadingSign, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) { return $parsed }
    return $null
}

function Merge-SessionStartPrevious {
    <#
        Adds the history from a previous page's data to the data about to be rendered, and returns the data.

        Per document: previousBytes, matched on id. A previous entry that carries NO id may be matched by
        name, and only such an entry: a name match against an entry that has an id would pair two different
        files that merely share a leaf name (a document moved to a new path is a new document, and the page
        labels it new). Each previous entry is consumed once, so two current documents cannot both claim it.
        Per item: previousTokens. On the documents block: hasPrevious (only when the previous page listed at
        least one document), previousLabel, previousTotalBytes and removed (documents that were on the path
        then and are not now). A top-level `previous` object carries the date and totals.

        Every number is read with TryParse. A value that is not a whole number means no history for that row,
        and a note (Get-SessionStartMergeNotes) naming the row. Both inputs are parsed JSON objects, and
        nothing is assumed present: a previous page from an older shape just yields fewer deltas.
    #>
    param(
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)]$Previous
    )

    $script:SessionStartMergeNotes = @()
    $notes = New-Object System.Collections.Generic.List[string]

    $prevDocBlock = Get-JsonField $Previous 'documents' $null
    $prevDocs = @()
    if ($null -ne $prevDocBlock) { $prevDocs = @(Get-JsonField $prevDocBlock 'items' @()) }
    $byId = @{}
    $byNameNoId = @{}
    for ($i = 0; $i -lt $prevDocs.Count; $i++) {
        $pdId = [string](Get-JsonField $prevDocs[$i] 'id' '')
        $pn = [string](Get-JsonField $prevDocs[$i] 'name' '')
        if ($pdId) { if (-not $byId.ContainsKey($pdId)) { $byId[$pdId] = $i } }
        elseif ($pn) { if (-not $byNameNoId.ContainsKey($pn)) { $byNameNoId[$pn] = $i } }
    }

    $prevTotal = [int64]0
    $curBlock = Get-JsonField $Data 'documents' $null
    if ($null -ne $curBlock -and $prevDocs.Count -gt 0) {
        $used = @{}
        foreach ($d in @(Get-JsonField $curBlock 'items' @())) {
            $idx = $null
            $did = [string](Get-JsonField $d 'id' '')
            $dn = [string](Get-JsonField $d 'name' '')
            if ($did -and $byId.ContainsKey($did) -and -not $used.ContainsKey($byId[$did])) { $idx = $byId[$did] }
            elseif ($dn -and $byNameNoId.ContainsKey($dn) -and -not $used.ContainsKey($byNameNoId[$dn])) { $idx = $byNameNoId[$dn] }
            if ($null -eq $idx) { continue }
            $used[$idx] = $true
            $pb = ConvertTo-Int64OrNull (Get-JsonField $prevDocs[$idx] 'bytes' $null)
            if ($null -eq $pb) { $notes.Add("the previous bytes of '$dn' are not a whole number, so that document has no history."); continue }
            Set-JsonProperty -Object $d -Name 'previousBytes' -Value $pb
        }
        $removed = @()
        for ($i = 0; $i -lt $prevDocs.Count; $i++) {
            $pd = $prevDocs[$i]
            $pb = ConvertTo-Int64OrNull (Get-JsonField $pd 'bytes' $null)
            if ($null -ne $pb) { $prevTotal += $pb }
            elseif (-not $used.ContainsKey($i)) { $notes.Add("the previous bytes of '$([string](Get-JsonField $pd 'name' ''))' are not a whole number, so it is left out of the history.") }
            if (-not $used.ContainsKey($i) -and $null -ne $pb) {
                $removed += [pscustomobject]@{ name = (Get-JsonField $pd 'name' (Get-JsonField $pd 'id' '')); previousBytes = $pb }
            }
        }
        $label = [string](Get-JsonField $Previous 'asOf' '')
        Set-JsonProperty -Object $curBlock -Name 'hasPrevious' -Value $true
        Set-JsonProperty -Object $curBlock -Name 'previousTotalBytes' -Value $prevTotal
        Set-JsonProperty -Object $curBlock -Name 'removed' -Value @($removed)
        if ($label) { Set-JsonProperty -Object $curBlock -Name 'previousLabel' -Value $label }
    }

    $prevItems = @(Get-JsonField $Previous 'items' @())
    $prevTok = @{}
    $prevTokTotal = [int64]0
    # The page's efficiency score is the 'none' share; the previous one is summed HERE, over the previous
    # items by their own influence, so a removed, renamed or reclassified layer cannot leave the denominator
    # without the numerator and fake a delta.
    $prevNoneTotal = [int64]0
    foreach ($prevIt in $prevItems) {
        $k = [string](Get-JsonField $prevIt 'id' (Get-JsonField $prevIt 'name' ''))
        $t = ConvertTo-Int64OrNull (Get-JsonField $prevIt 'tokens' $null)
        if ($null -eq $t) { $notes.Add("the previous tokens of '$k' are not a whole number, so that item has no history."); continue }
        if ($k) { $prevTok[$k] = $t }
        $prevTokTotal += $t
        if ([string](Get-JsonField $prevIt 'influence' '') -eq 'none') { $prevNoneTotal += $t }
    }
    foreach ($it in @(Get-JsonField $Data 'items' @())) {
        $k = [string](Get-JsonField $it 'id' (Get-JsonField $it 'name' ''))
        if ($k -and $prevTok.ContainsKey($k)) { Set-JsonProperty -Object $it -Name 'previousTokens' -Value $prevTok[$k] }
    }

    Set-JsonProperty -Object $Data -Name 'previous' -Value ([pscustomobject]@{
        asOf        = [string](Get-JsonField $Previous 'asOf' '')
        totalTokens = $prevTokTotal
        noneTokens  = $prevNoneTotal
        totalBytes  = $prevTotal
    })
    $script:SessionStartMergeNotes = @($notes)
    return $Data
}

function Get-SessionStartHistory {
    <#
        The NUMERIC history of a previous page's data and nothing else: asOf, item ids with tokens, document
        ids with bytes, action ids with the done flag. A previous page is data from outside this session, so
        what the model needs to carry the history forward is passed through a filter that keeps numbers,
        booleans and short identifier-shaped strings and drops every other string -- no title, no text, no
        'how' and no caveat ever comes out. An id that is not identifier-shaped is omitted along with its row.
    #>
    param([Parameter(Mandatory = $true)]$Previous)

    # '~' and the length are what collect's own ids need: an external document's id is 'external:' plus its
    # home-folded import target, and the persona path alone is ~130 characters (measured October 1, 2026 --
    # the first cut of this regex silently dropped the biggest always-on document from the history).
    $idRx = '^[A-Za-z0-9:._/@ ~-]{1,300}$'
    $asOf = [string](Get-JsonField $Previous 'asOf' '')
    if ($asOf -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') { $asOf = '' }

    $items = @()
    foreach ($x in @(Get-JsonField $Previous 'items' @())) {
        $id = [string](Get-JsonField $x 'id' '')
        $t = ConvertTo-Int64OrNull (Get-JsonField $x 'tokens' $null)
        if ($id -match $idRx -and $null -ne $t) {
            $items += [pscustomobject]@{ id = $id; tokens = $t; measured = ((Get-JsonField $x 'measured' $false) -eq $true) }
        }
    }
    $docs = @()
    $docBlock = Get-JsonField $Previous 'documents' $null
    if ($null -ne $docBlock) {
        foreach ($x in @(Get-JsonField $docBlock 'items' @())) {
            $id = [string](Get-JsonField $x 'id' '')
            $b = ConvertTo-Int64OrNull (Get-JsonField $x 'bytes' $null)
            if ($id -match $idRx -and $null -ne $b) { $docs += [pscustomobject]@{ id = $id; bytes = $b } }
        }
    }
    $actions = @()
    $actBlock = Get-JsonField $Previous 'actions' @()
    $actList = @($actBlock)
    if ($actBlock -isnot [array] -and $null -ne $actBlock) { $actList = @(Get-JsonField $actBlock 'items' @()) }
    foreach ($x in $actList) {
        $id = [string](Get-JsonField $x 'id' '')
        if ($id -notmatch $idRx) { continue }
        $inf = [string](Get-JsonField $x 'influence' '')
        if (@('direct', 'setting', 'none') -notcontains $inf) { $inf = '' }
        $actions += [pscustomobject]@{ id = $id; done = ((Get-JsonField $x 'done' $false) -eq $true); influence = $inf }
    }
    return [pscustomobject]@{ asOf = $asOf; items = @($items); documents = @($docs); actions = @($actions) }
}

function Merge-SessionStartTemplate {
    <#
        Puts the data JSON into the template between the two markers, keeping the markers so the rendered page
        can itself be read back as the next run's history. Refuses (throws) unless each marker occurs exactly
        once, in order: a template with two begin markers would put the data in whichever the replace found
        first and leave the other as a stale copy that Read-SessionStartDataBlock might later pick up.

        -PageTitle replaces the first <title> element, HTML-encoded: the artifact is found by that title, so
        it has to survive the template's own default.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Template,
        [Parameter(Mandatory = $true)][string]$Json,
        [string]$PageTitle = ''
    )

    $b = $script:SessionStartBegin
    $e = $script:SessionStartEnd
    # Defence in depth: ConvertTo-SafeScriptJson cannot emit a star-slash, but this function takes any
    # string, and a marker inside the data would be found by the next run before the real one.
    foreach ($m in @($b, $e)) {
        if ($Json.IndexOf($m, [System.StringComparison]::Ordinal) -ge 0) { throw "the data contains the marker $m, which would corrupt the history" }
    }
    foreach ($m in @($b, $e)) {
        $count = 0
        $from = 0
        while (($at = $Template.IndexOf($m, $from, [System.StringComparison]::Ordinal)) -ge 0) { $count++; $from = $at + $m.Length }
        if ($count -ne 1) { throw "the template must contain the marker $m exactly once, and has it $count time(s)" }
    }
    $i = $Template.IndexOf($b, [System.StringComparison]::Ordinal)
    $j = $Template.IndexOf($e, [System.StringComparison]::Ordinal)
    if ($j -lt $i) { throw 'the template has its END marker before its BEGIN marker' }

    $out = $Template.Substring(0, $i + $b.Length) + $Json + $Template.Substring($j)

    if ($PageTitle) {
        $enc = [System.Net.WebUtility]::HtmlEncode($PageTitle)
        $rx = New-Object System.Text.RegularExpressions.Regex('<title>.*?</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '<title>' + $enc + '</title>' }
        $out = $rx.Replace($out, $evaluator, 1)
    }
    return $out
}

# Get-InstalledVersionForRepo lives in measure-skill-lib.ps1 since #2670, so measure-skill.ps1 reads the
# install record the same way. This lib dot-sources that one, so its callers here are unaffected. The
# entry carries both versions rather than choosing one, because the gap is queued cost arriving at the
# next plugin update and not an error to smooth away.

function Resolve-PluginRequest {
    <#
        Turns the names given to -Plugin into plugin ids. A name with an '@' is taken as it is. A bare name
        takes the marketplace it is ENABLED under (every enabled id whose name part matches, so a plugin
        enabled twice under two marketplaces yields both), and only a name nothing enabled matches falls
        back to the literal -DefaultMarketplace -- looking a plugin from another marketplace up under the
        wrong one would report it as not installed.
    #>
    param(
        [string[]]$Requested = @(),
        [string[]]$EnabledIds = @(),
        [string]$DefaultMarketplace = 'dkj-claude-plugins'
    )
    $out = @()
    foreach ($req in @($Requested)) {
        if ($req -match '@') { $out += $req; continue }
        $hit = @($EnabledIds | Where-Object { ($_ -split '@')[0] -eq $req })
        if ($hit.Count -gt 0) { $out += $hit } else { $out += "$req@$DefaultMarketplace" }
    }
    return @($out)
}
