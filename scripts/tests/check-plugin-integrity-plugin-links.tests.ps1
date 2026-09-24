<#
.SYNOPSIS
    check-plugin-integrity.ps1, check 30: a plugin-shipped relative link must resolve inside its own
    plugin, and an absolute link must not be this repo's bare base.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -links under #2304.

    Check 30 is check 4's OTHER sibling (check 4 lives in -links), and the one whose scenarios are
    easiest to write vacuously: it reads the same links and asks a different question of them -- not
    "does this resolve here" but "does it still resolve once the file has travelled to a consumer's
    plugin cache". Every link in its scenarios resolves in the fixture on purpose, so check 4 stays
    silent and any finding is 30's own; scenario 36 asserts that silence head-on. Scenario 37 is the one
    that earns the suite -- a link into a SIBLING plugin, which satisfies the boundary inbound #1066
    proposed ('stay under plugins/') while still being dead for a consumer, because the cache gives
    every plugin its own versioned directory and a sibling is not a neighbour.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-plugin-links-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # --- Check 30: a plugin-shipped relative link must resolve inside its OWN plugin ---------------
    #
    # WHAT THESE SIX SCENARIOS ARE FOR. Check 4 answers "does this link resolve in THIS tree"; check 30
    # answers "does it still resolve once the file has travelled". The two are independent, and the
    # fixture makes that visible: every link written below resolves perfectly where it sits, so check 4
    # stays silent throughout and any finding here is check 30's alone.
    #
    # SCENARIO 37 IS THE ONE THAT EARNS THE SUITE. Inbound #1066 proposed the boundary as 'plugins/',
    # and a link into a SIBLING plugin satisfies that while still being dead for a consumer -- the
    # cache gives each plugin its own versioned directory, so a sibling is not a neighbour. Without 37
    # a wrong-but-plausible rule passes every other scenario here.
    $PluginLinkFindingPattern = '\[plugin-link\] \.'
    $plNotes = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\NOTES.md'
    # Real targets, so each scenario tests CONTAINMENT and not existence. A dead target would make the
    # finding appear for the wrong reason and the scenario would keep passing after the rule was broken.
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'README.md'), "# Fixture root`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\GUIDE.md'), "# Shopify guide`n", $Utf8NoBom)

    Write-Host "check 30 -- a link out of the plugin root is a finding, at the right line" -ForegroundColor Cyan
    $p36Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        'Line three is prose.'
        ''
        'See [the root readme](../../../README.md) for the rest.'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p36Lines -join "`n") + "`n"), $Utf8NoBom)
    $q36 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q36.Out -match $PluginLinkFindingPattern) 'scenario 36: a link leaving the plugin root is reported'
    Assert-True ($q36.Out -match 'NOTES\.md:5 ') 'scenario 36: the finding names the line the link is on, not the file'
    Assert-True ($q36.Out -match "leaves the 'dkj-subagents-alpha' plugin root") 'scenario 36: the finding names the plugin the file belongs to'
    # The link resolves in this tree, so check 4 has nothing to say about it. Asserted head-on: if this
    # ever fails, the two checks have started overlapping and 30's findings are no longer its own.
    Assert-True (-not ($q36.Out -match 'dead link .\.\./\.\./\.\./README\.md')) 'scenario 36: check 4 stays silent -- the link is live HERE, which is the whole premise'
    # No repo-config in the fixture, so Get-RepoBlobUrl is undefined and the suggestion is dropped. The
    # designed fallback: a repo without the seam gets a plainer finding, never a wrong one or a crash.
    Assert-True (-not ($q36.Out -match 'Write it absolute:')) 'scenario 36: without repo-config the suggestion is omitted and the finding still stands'

    Write-Host "check 30 -- a SIBLING plugin is not a neighbour, though it shares plugins/" -ForegroundColor Cyan
    $p37Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        'See [the shopify guide](../dkj-subagents-shopify/GUIDE.md) for the rest.'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p37Lines -join "`n") + "`n"), $Utf8NoBom)
    $q37 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q37.Out -match $PluginLinkFindingPattern) 'scenario 37: a link into a sibling plugin is reported, though it never leaves plugins/'
    Assert-True ($q37.Out -match "leaves the 'dkj-subagents-alpha' plugin root") 'scenario 37: the finding is attributed to the plugin the FILE sits in, not the one it points at'

    Write-Host "check 30 -- a link inside the plugin root is not a finding" -ForegroundColor Cyan
    $p38Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        'See [skill alpha](skills/skill-alpha/SKILL.md) and [beta](./skills/skill-beta/SKILL.md).'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p38Lines -join "`n") + "`n"), $Utf8NoBom)
    $q38 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q38.Out -match $PluginLinkFindingPattern)) 'scenario 38: links staying inside the plugin root pass, in both the bare and the ./ form'

    Write-Host "check 30 -- code and comments are masked, and the mask keeps line numbers honest" -ForegroundColor Cyan
    # All three exclusions in one file, ABOVE a live escape: masking that shortened the text instead of
    # preserving its length would still suppress these three and then misreport the fourth's line. That is
    # the failure this scenario is shaped to catch -- a passing absence assert would hide it.
    $p39Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        '```'
        'See [fenced](../../../README.md) -- illustration, not a link.'
        '```'
        ''
        'Inline `[code](../../../README.md)` is illustration too.'
        ''
        '<!-- [commented](../../../README.md) -->'
        ''
        'But [this one](../../../README.md) is real.'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p39Lines -join "`n") + "`n"), $Utf8NoBom)
    $q39 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($q39.Out, $PluginLinkFindingPattern).Count) 'scenario 39: exactly one of the four links is live -- fence, inline code and HTML comment are all masked'
    Assert-True ($q39.Out -match 'NOTES\.md:11 ') 'scenario 39: the surviving finding reports line 11, so the mask preserved length and newlines'

    Write-Host "check 30 -- three forms are passed over rather than reported" -ForegroundColor Cyan
    $p40Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        'An [absolute URL](https://github.com/DaveKJohn/claude-code-specialists/blob/main/README.md) is the repair, not the defect.'
        ''
        'A [plugin-relative path](${CLAUDE_PLUGIN_ROOT}/skills/skill-alpha/SKILL.md) resolves at runtime.'
        ''
        'A [marketplace-clone path](~/.claude/plugins/marketplaces/x/README.md) points there deliberately.'
        ''
        'A [pure anchor](#dkj-subagents-alpha-notes) never leaves the file.'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p40Lines -join "`n") + "`n"), $Utf8NoBom)
    $q40 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q40.Out -match $PluginLinkFindingPattern)) 'scenario 40: absolute, ${...}-relative, ~/-relative and pure-anchor targets are all passed over'

    Write-Host "check 30 -- the coverage line counts what was read and what escaped" -ForegroundColor Cyan
    # Coverage is asserted separately from the findings for Write-Coverage's own reason (#221): "0
    # escaping" and "checked nothing at all" are the same verdict read two ways, and only the count
    # tells them apart. So BOTH states are pinned, because the note has a branch for each and the
    # uninformative one is the branch a reader would otherwise be handed by accident.
    #
    # The file left over from scenario 40 carries four links and not one relative path among them, so
    # this is the zero-checked state -- and the assert is that the gate SAYS so rather than reporting a
    # bare zero that reads like a clean sweep.
    $q41 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q41.Out -match '\[plugin-link\] checked 0 --') 'scenario 41: with only passed-over forms, the coverage count is zero'
    Assert-True ($q41.Out -match 'so none can escape') 'scenario 41: and the note says WHY it is zero, instead of leaving a bare zero to read as a clean sweep'

    # Now the other branch: one link, contained, so something was genuinely resolved and passed.
    $p41Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        'See [skill alpha](skills/skill-alpha/SKILL.md).'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p41Lines -join "`n") + "`n"), $Utf8NoBom)
    $q41a = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q41a.Out -match '\[plugin-link\] checked [1-9]') 'scenario 41: a contained relative link is COUNTED, not skipped -- a pass must be a measurement'
    Assert-True ($q41a.Out -match '0 escaping') 'scenario 41: and it reports zero escaping'

    Remove-Item -LiteralPath $plNotes -Force
    Remove-Item -LiteralPath (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\GUIDE.md') -Force
    $q41b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q41b.Out -match $PluginLinkFindingPattern)) 'scenario 41: the fixture is clean again once the notes file is gone'

    # --- Check 30, the truncation half: an absolute link holding only this repo's base (#1566) ------
    #
    # WHY THESE SIT HERE AND NOT IN A SUITE OF THEIR OWN. The rule is check 30's, and deliberately so:
    # the shape it catches is check 30's OWN suggestion pasted without its tail. Sixteen such links were
    # measured across four plugin pages on September 8, 2026, every one of them returning 200 -- GitHub
    # answers '<base>/' with the repo front page -- so check 4 was right to stay silent and check 30 was
    # skipping them along with every other absolute target.
    #
    # THE SEAM IS THE VERDICT HERE, WHICH IS NEW FOR THIS CHECK, and 41t1 pins the honest gap that
    # creates: scenario 36 above proves a missing repo-config costs only the SUGGESTION, while below it
    # costs this half entirely. That has to be asserted rather than assumed, because a check that goes
    # quiet without saying so is the failure class this suite exists for -- hence the coverage assert
    # beside the absence one, on the sentence that admits it.
    $plTruncBase = 'https://github.com/Fixture-Owner/fixture-repo'
    $p41tLines = @(
        '# dkj-subagents-alpha notes'
        ''
        "Read [the install page]($plTruncBase/blob/main/) before you start."
    )
    [System.IO.File]::WriteAllText($plNotes, (($p41tLines -join "`n") + "`n"), $Utf8NoBom)

    Write-Host "check 30 -- without the seam the truncation half does not run, and SAYS so" -ForegroundColor Cyan
    $q41t1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q41t1.Out -match $PluginLinkFindingPattern)) 'scenario 41t: with no repo-config there is no base to compare against, so a truncated link is not reported'
    Assert-True ($q41t1.Out -match 'The truncation half did NOT run') 'scenario 41t: and the coverage line admits the gap instead of reporting a clean sweep'

    # From here on the fixture HAS a base -- deliberately a different owner/name than this repo's, so a
    # rule that hardcoded 'DKJ-Solutions/claude-code-specialists' would pass 41t2 and fail 41t4.
    $plTruncCfg = Join-Path $Fixture 'scripts\repo-config.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $plTruncCfg) -Force | Out-Null
    [System.IO.File]::WriteAllText($plTruncCfg,
        "function Get-RepoBlobUrl { return '$plTruncBase/blob/main/' }`n", $Utf8NoBom)

    Write-Host "check 30 -- with the seam, a base-only absolute link is a finding at the right line" -ForegroundColor Cyan
    $q41t2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q41t2.Out -match $PluginLinkFindingPattern) 'scenario 41t: a link holding nothing but the repo base is reported'
    Assert-True ($q41t2.Out -match 'NOTES\.md:3 ') 'scenario 41t: the finding names the line the link is on'
    Assert-True ($q41t2.Out -match 'resolves to the repository FRONT PAGE') 'scenario 41t: the message says what the reader actually lands on, which is why no dead-link check can see it'
    Assert-True ($q41t2.Out -match '1 of them carry that base and nothing after it') 'scenario 41t: and the coverage line counts it'

    Write-Host "check 30 -- every spelling of the bare base counts, and a fence still hides one" -ForegroundColor Cyan
    # The four live shapes are one rule, not four: blob and tree (the suggestion swaps them for a
    # directory target), with and without the trailing slash, and the anchor-only form -- '<base>/#x' is
    # the front page with the whole path still missing, which is the shape that looks most like a
    # working link. The fenced fifth proves the branch sits inside the same masked scan as the rest of
    # the check rather than reading the raw text.
    $p41t3Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        "A [tree form]($plTruncBase/tree/main/) points at the root too."
        ''
        "So does [no trailing slash]($plTruncBase/blob/main)."
        ''
        "And [anchor only]($plTruncBase/blob/main/#the-seam-specified), which looks most like a real link."
        ''
        '```'
        "An [illustration]($plTruncBase/blob/main/) inside a fence is not a link."
        '```'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p41t3Lines -join "`n") + "`n"), $Utf8NoBom)
    $q41t3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 3 ([regex]::Matches($q41t3.Out, $PluginLinkFindingPattern).Count) 'scenario 41t: blob, tree, slashless and anchor-only all count as the bare base -- and the fenced fifth is masked'
    Assert-True ($q41t3.Out -match '3 of them carry that base') 'scenario 41t: the coverage count agrees with the findings'

    Write-Host "check 30 -- the rule stays narrow: a real path passes, another repo's root passes" -ForegroundColor Cyan
    # Absolute links are correctly out of this check's scope. The finding is not "an absolute link" but
    # "this repo's base with the author's own target dropped", and both halves of that have to hold: a
    # base WITH a path is the repair the check asks for, and a bare root belonging to some other
    # repository is somebody else's front page, which may well be exactly what the text names.
    #
    # THE FOURTH LINE PINS THE NAMED COST, not an accident: same repo NAME, previous OWNER. It passes,
    # and it is asserted so that widening the rule to reach it has to be a deliberate edit to this
    # scenario rather than a silent change of behaviour. The reasoning for leaving it -- recognising a
    # retired owner path would bless a spelling the repo-citation rule is retiring -- is above the check.
    $p41t4Lines = @(
        '# dkj-subagents-alpha notes'
        ''
        "The repair is [the install page]($plTruncBase/blob/main/INSTALL.md#staying-up-to-date)."
        ''
        'And [another project](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/) is its own front page.'
        ''
        'So is [a bare host](https://github.com/).'
        ''
        'And [the previous owner of this same repo](https://github.com/Previous-Owner/fixture-repo/blob/main/) is out of reach by design.'
    )
    [System.IO.File]::WriteAllText($plNotes, (($p41t4Lines -join "`n") + "`n"), $Utf8NoBom)
    $q41t4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q41t4.Out -match $PluginLinkFindingPattern)) 'scenario 41t: a base plus a real path, another repo bare root, a bare host and this repo under a PREVIOUS owner are all passed over'
    Assert-True ($q41t4.Out -match '0 of them carry that base') 'scenario 41t: and the coverage line reports zero rather than going silent'

    Remove-Item -LiteralPath $plTruncCfg -Force
    Remove-Item -LiteralPath $plNotes -Force
    $q41t5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q41t5.Out -match $PluginLinkFindingPattern)) 'scenario 41t: the fixture is clean again once the notes file and the seam are gone'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
