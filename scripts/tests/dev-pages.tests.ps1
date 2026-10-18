<#
.SYNOPSIS
    Tests for scripts/lib/dev-pages-lib.ps1 -- the Repo hub, the SessionStart page, the test-gate page
    and the Artifacts page of the dev server (#3097). Pure: the server that serves them is exercised by
    connector-dashboard.tests.ps1.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

Write-Host '-- the number formats' -ForegroundColor Cyan
Assert-Equal '58,895' (Format-DevNumber 58895) 'thousands separators, whatever the culture'
Assert-Equal '--' (Format-DevNumber $null) 'a value not read is --'
Assert-Equal '7.6s' (Format-DevSeconds 7.6) 'under a minute: seconds with one decimal'
Assert-Equal '23:22' (Format-DevSeconds 1402) 'from a minute: m:ss'
Assert-Equal '59.6s' (Format-DevSeconds 59.6) 'just under a minute stays in seconds'

Write-Host '-- the page shell' -ForegroundColor Cyan
$shell = Format-DevPageHtml -Title 'A <b>page' -Lead 'lead' -Body '<p>body</p>' -FooterNote 'note'
Assert-True ($shell.IndexOf('<div class="breadcrumbs-bar">') -lt $shell.IndexOf('<main')) 'the breadcrumb bar comes before <main>'
Assert-True ($shell -match '<li><a href="/">Repo hub</a></li>') 'the trail starts at the Repo hub, linked'
Assert-True ($shell -match 'breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">A &lt;b&gt;page</span>') 'and ends at the page, unlinked and escaped'
Assert-True ($shell -match '<h1>A &lt;b&gt;page</h1>') 'the h1 is the page name, escaped'
Assert-True ($shell -match 'data-theme-key="connector-dashboard"') 'the theme key is the index page''s, so a picked theme holds across pages'
Assert-True ($shell -match '<p class="footer-note">note</p>') 'the footer note closes the column'

Write-Host '-- the Repo hub' -ForegroundColor Cyan
$pages = @(Get-RepoHubPages)
Assert-Equal '/connectors,/test-gate,/artifacts,/issues,/release-notes,/sessionstart' (($pages | ForEach-Object { $_.Href }) -join ',') 'the hub links the six pages, in order'
Assert-Equal 'repo,repo,general,general,general,general' (($pages | ForEach-Object { $_.Group }) -join ',') 'the repo''s own pages first, then the general ones'
$hub = Format-RepoHubHtml -Pages $pages -SourceCommit 'abc1234'
Assert-True ($hub -match '<title>dkj-claude-plugins -- Repo hub</title>' -and $hub -match '<h1>Repo hub</h1>') 'the h1 and the title are Repo hub, word for word'
Assert-True ($hub -match '<body>\s*<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>\s*<li><span aria-current="page">Repo hub</span></li>\s*</ol>') 'the bar opens <body>, its trail the one crumb Repo hub'
Assert-True ($hub -match '<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>' -and $hub -notmatch '<header' -and $hub -notmatch 'btn--primary') 'the intro is the slug and no <header>, and there is no product button'
Assert-Equal 6 ([regex]::Matches($hub, '<a class="menu-item" href="/[a-z-]+"><span class="menu-item__label">[^<]+<span class="menu-item__sub">[^<]+</span></span><svg class="menu-item__chevron"')).Count 'each page is a menu-item row: label, description, chevron'
Assert-True ($hub -match '<nav class="menu-list" aria-labelledby="pages-repo">\r?\n<a class="menu-item"' -and $hub -match '</a>\r?\n<a class="menu-item"') 'the rows are direct siblings in the nav, so the house draws the line between them'
Assert-Equal 1 ([regex]::Matches($hub, '<h2 class="card__title">Pages</h2>')).Count 'one Pages card, and no second card for the general pages'
Assert-True ($hub -match '<h2 class="card__title">Pages</h2><p class="card__sub">[^<]+</p></div>') 'the Pages card carries a sub line under its h2'
Assert-True ($hub -match '<h3 id="pages-repo">This repo</h3>\r?\n<nav class="menu-list" aria-labelledby="pages-repo">\r?\n<a class="menu-item" href="/connectors"' -and $hub -match '<h3 id="pages-general">General</h3>\r?\n<p class="card__sub">[^<]+</p>\r?\n<nav class="menu-list" aria-labelledby="pages-general">\r?\n<a class="menu-item" href="/artifacts"') 'it splits one level down: an h3 over the repo''s own pages, an h3 over the general ones'
Assert-True ($hub.IndexOf('Pages</h2>') -lt $hub.IndexOf('pages-repo') -and $hub.IndexOf('pages-general') -lt $hub.IndexOf('About this repo</h2>')) 'and both groups sit inside the Pages card'
Assert-True ($hub.IndexOf('href="/test-gate"') -lt $hub.IndexOf('General</h3>') -and $hub.IndexOf('href="/issues"') -gt $hub.IndexOf('General</h3>')) 'and no page sits in the other group'
Assert-True ((Format-RepoHubHtml -Pages @(@{ Href = '/x'; Label = 'X'; Sub = '' })) -notmatch 'pages-general') 'a group with no page has no heading, and a page without a Group is the repo''s own'
Assert-True ($hub -match '<dt>Source at</dt><dd><code>abc1234</code></dd>') 'About this repo names the commit it serves from'
Assert-True ((Format-RepoHubHtml -Pages $pages) -notmatch 'Source at') 'and leaves the row out when the commit could not be read'
$ix = @('class="breadcrumbs-bar"', 'id="settings"', 'class="eyebrow"', 'Pages</h2>', 'About this repo</h2>', 'class="footer-note"') | ForEach-Object { $hub.IndexOf($_) }
Assert-True ((@($ix | Where-Object { $_ -lt 0 }).Count -eq 0) -and ((($ix | Sort-Object) -join ',') -eq ($ix -join ','))) 'the blocks stand in the form''s order'
$evil = Format-RepoHubHtml -Pages @(@{ Href = '/x"><script>'; Label = '<b>'; Sub = '' })
Assert-True ($evil -notmatch 'x"><script>' -and $evil -match 'href="/x&quot;&gt;&lt;script&gt;"' -and $evil -notmatch '<b>' -and $evil -notmatch 'menu-item__sub') 'every value is escaped, and an empty description is left out'

Write-Host '-- the test-gate model' -ForegroundColor Cyan
$json = '{ "seconds": { "a.tests.ps1": 10, "b.tests.ps1": 30, "gone.tests.ps1": 5 }, "recordedFrom": { "runs": ["111", "222"], "date": "2026-10-07", "machine": "m", "method": "mean" } }' | ConvertFrom-Json
$m = ConvertFrom-SuiteDurations -Durations $json -SuiteFiles @('a.tests.ps1', 'b.tests.ps1', 'new.tests.ps1')
Assert-Equal 'b.tests.ps1,a.tests.ps1,gone.tests.ps1' (($m.Suites | ForEach-Object { $_.Name }) -join ',') 'suites slowest first'
Assert-Equal 45 $m.Total 'the sum of every recorded suite'
Assert-Equal 'new.tests.ps1' ($m.Missing -join ',') 'a suite on disk the file does not record is missing'
Assert-Equal 'gone.tests.ps1' ($m.Stale -join ',') 'a recorded suite no longer on disk is stale'
Assert-Equal '111,222' ($m.Runs -join ',') 'the runs it was recorded from'
$empty = ConvertFrom-SuiteDurations -Durations $null -SuiteFiles @('a.tests.ps1')
Assert-Equal 0 @($empty.Suites).Count 'no file: no suites'
Assert-Equal 'a.tests.ps1' ($empty.Missing -join ',') 'and every suite on disk is missing'

Write-Host '-- the test-gate page' -ForegroundColor Cyan
$tg = Format-TestGatePageHtml -Model $m
Assert-True ($tg -match '<h1>Test gate</h1>') 'the page is named Test gate'
Assert-True ($tg.IndexOf('b.tests.ps1') -lt $tg.IndexOf('>a.tests.ps1<')) 'the table lists the slowest first'
Assert-True ($tg -match 'width: 100%"></span></span></td><td>66.7%</td>') 'the slowest suite''s bar is full, and its share is of the sum'
Assert-True ($tg -match 'width: 33.33%"></span></span></td><td>22.2%</td>') 'another suite''s bar is drawn against the slowest'
Assert-True ($tg -match 'gone.tests.ps1</code> <span class="badge badge--sm badge--neutral">no longer on disk') 'a stale suite is marked'
Assert-True ($tg -match 'class="msg" role="status">Not recorded yet.*new.tests.ps1') 'the missing suites are named'
Assert-True ($tg -match 'actions/runs/111"') 'each run links to its CI run'
$bad = Format-TestGatePageHtml -Model $empty -ReadError 'it is not valid JSON'
Assert-True ($bad -match 'msg msg--warn" role="alert">scripts/tests/suite-durations.json could not be read: it is not valid JSON') 'an unreadable file is a warning'
Assert-True ($bad -match 'No suite durations are recorded') 'and the table says it is empty rather than vanishing'
$hostile = ConvertFrom-SuiteDurations -Durations ('{ "seconds": { "<x>.tests.ps1": 1 }, "recordedFrom": { "runs": ["1\" onclick=\"x"] } }' | ConvertFrom-Json)
$hp = Format-TestGatePageHtml -Model $hostile
Assert-True ($hp -match '&lt;x&gt;.tests.ps1' -and $hp -notmatch '<x>') 'a suite name is escaped'
Assert-True ($hp -notmatch 'onclick') 'a run id that is not a number is not linked'

Write-Host '-- the SessionStart page' -ForegroundColor Cyan
$ssModel = @{
    Total = 1000; Budget = 4000; State = 'inside'; Ok = $true; Tokens = 320; GeneratedAt = '2026-10-18 00:00:00'; Seconds = 1.2
    Documents = @(
        @{ Display = 'CLAUDE.md'; Bytes = 100; Source = 'measured' },
        @{ Display = '~/persona.md'; Bytes = 900; Source = 'carried' },
        @{ Display = 'lost.md'; Bytes = 0; Source = 'unmeasured' })
}
$ss = Format-SessionStartPageHtml -Model $ssModel
Assert-True ($ss -match '<h1>SessionStart</h1>') 'the page is named SessionStart'
Assert-True ($ss -match 'Headroom \(B\)</div><div class="v num">3,000') 'inside the budget: the headroom'
Assert-True ($ss.IndexOf('~/persona.md') -lt $ss.IndexOf('<code>CLAUDE.md</code></td>')) 'the documents are listed largest first'
Assert-True ($ss -match '~/persona.md</code></td><td class="num">900</td>.*?<td>90.0%</td><td class="dp-left">from the baseline') 'a carried document says so'
Assert-True ($ss -match 'role="status">Not counted.*lost.md') 'an unmeasured document is named, not counted as zero'
Assert-True ($ss -notmatch 'msg--warn') 'no warning inside the budget'
$ssModel.Total = 5000; $ssModel.Ok = $false; $ssModel.State = 'over-growing'
$over = Format-SessionStartPageHtml -Model $ssModel
Assert-True ($over -match 'Over the budget \(B\)</div><div class="v num">1,000') 'over the budget: by how much'
Assert-True ($over -match 'msg msg--warn" role="alert">The always-on path is over its limit \(over-growing\)') 'and a warning naming the state'
$failed = Format-SessionStartPageHtml -Model $null -ReadError 'boom <x>'
Assert-True ($failed -match 'could not be measured: boom &lt;x&gt;') 'a failed measurement is a warning, escaped'
Assert-True ($failed -match 'No always-on document was measured') 'and the table says it is empty'

Write-Host '-- the Artifacts link check' -ForegroundColor Cyan
Assert-True (Test-ArtifactUrl 'https://claude.ai/artifact/TzrnhFefotMqYp6oWXYp5y') 'a claude.ai/artifact link is one'
Assert-True (Test-ArtifactUrl 'https://claude.ai/code/artifact/7d2fa536-ace6-412a-8977-60a4ddc4b6be') 'and so is a claude.ai/code/artifact link'
Assert-True (-not (Test-ArtifactUrl 'javascript:alert(1)')) 'a script url is not'
Assert-True (-not (Test-ArtifactUrl 'http://claude.ai/artifact/abc')) 'nor plain http'
Assert-True (-not (Test-ArtifactUrl 'https://claude.ai.evil.example/artifact/abc')) 'nor another host'
Assert-True (-not (Test-ArtifactUrl 'https://claude.ai/artifact/abc"><script>')) 'nor a link that breaks out of its attribute'
Assert-True (-not (Test-ArtifactUrl '')) 'nor an empty one'
Assert-True (-not (Test-ArtifactUrl "https://claude.ai/artifact/abc`n")) 'nor one with a trailing newline'

Write-Host '-- the Artifacts model' -ForegroundColor Cyan
$reg = '{ "recordedFrom": { "date": "2026-10-18", "method": "transcripts" }, "artifacts": [ { "title": "Old", "url": "https://claude.ai/artifact/aaa", "kind": "page", "created": "2026-09-01", "updated": "2026-09-02", "about": "first" }, { "title": "New <b>", "url": "https://claude.ai/code/artifact/0f1e-2a", "kind": "document", "created": "2026-10-07", "updated": "2026-10-07" }, { "title": "Bad", "url": "javascript:alert(1)", "kind": "page", "created": "2026-09-15" } ] }' | ConvertFrom-Json
$am = ConvertFrom-ArtifactRegister -Register $reg
Assert-Equal 'New <b>,Bad,Old' ((@($am.Artifacts) | ForEach-Object { $_.Title }) -join ',') 'newest first'
Assert-Equal 'False' (@($am.Artifacts | Where-Object { $_.Title -eq 'Bad' })[0].Linked) 'a url that is not an Artifact link is kept, unlinked'
Assert-Equal '2026-10-18' $am.Date 'the recording date is read'
$empty = ConvertFrom-ArtifactRegister -Register $null
Assert-Equal 0 @($empty.Artifacts).Count 'a missing register is an empty list'

Write-Host '-- the Artifacts page' -ForegroundColor Cyan
$ap = Format-ArtifactsPageHtml -Model $am
Assert-True ($ap -match '<h1>Artifacts</h1>' -and $ap -match '<span aria-current="page">Artifacts</span>') 'the page is named Artifacts, in the h1 and the trail'
Assert-True ($ap -match 'Artifacts</div><div class="v num">3<') 'the tile counts every recorded Artifact'
Assert-True ($ap -match '<a class="dp-link" href="https://claude.ai/artifact/aaa" target="_blank" rel="noopener noreferrer">Old</a>') 'a recorded Artifact links to claude.ai, in a new tab'
Assert-True ($ap -match 'New &lt;b&gt;</a>' -and $ap -notmatch 'New <b>') 'the title is escaped'
Assert-True ($ap -notmatch 'href="javascript' -and $ap -match '<td class="dp-left">Bad</td>') 'an unlinked row shows its title without an href'
Assert-True ($ap -match 'msg msg--warn" role="status">Not a claude.ai Artifact link.*<code>Bad</code>') 'and is named in a warning'
Assert-True ($ap -match '<p class="note">first</p>') 'the one-line description sits under the title'
Assert-True ($ap -match '<dt>Recorded</dt><dd>2026-10-18</dd>') 'where the list comes from is stated'
$apFailed = Format-ArtifactsPageHtml -Model $empty -ReadError 'it is not valid JSON'
Assert-True ($apFailed -match 'could not be read: it is not valid JSON' -and $apFailed -match 'No Artifact is recorded') 'an unreadable register is a warning and an empty table'

Write-Host '-- the register in the tree' -ForegroundColor Cyan
$treeReg = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\dashboard\artifacts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$treeModel = ConvertFrom-ArtifactRegister -Register $treeReg
Assert-True (@($treeModel.Artifacts).Count -gt 0) 'the register parses and records at least one Artifact'
Assert-Equal 0 @($treeModel.Artifacts | Where-Object { -not $_.Linked }).Count 'every recorded url is a claude.ai Artifact link'
Assert-Equal 0 @($treeModel.Artifacts | Where-Object { $_.Created -notmatch '^\d{4}-\d{2}-\d{2}$' }).Count 'every row has an ISO creation date'

Write-Host '-- the harvest: urls read from a result (#3112)' -ForegroundColor Cyan
. (Join-Path $RepoRoot 'scripts\lib\artifact-harvest-lib.ps1')
Assert-Equal 'https://claude.ai/artifact/Abc123' (Get-ArtifactPublishUrl 'Published C:\x\index.html at https://claude.ai/artifact/Abc123 (Version 2, version id 1-a)') 'a publish names its Artifact after "at"'
Assert-Equal 'https://claude.ai/artifact/New1' (Get-ArtifactPublishUrl 'Created a new Artifact at https://claude.ai/artifact/New1 (version 1) from the Artifact type https://claude.ai/artifact/Type9 (release 2)') 'a typed create names the new Artifact, not its type'
Assert-Equal '' (Get-ArtifactPublishUrl 'The publish was refused: the file is too large.') 'a refused publish names none'
Assert-Equal 'https://claude.ai/code/artifact/7d2f-ac' (Get-ArtifactPublishUrl '{"frame":{"url":"https://claude.ai/code/artifact/7d2f-ac"}}' -Docs) 'a Docs create names its code/artifact link'
Assert-Equal 'https://claude.ai/artifact/Abc' (Get-ArtifactUrlKey 'https://claude.ai/artifact/Abc?sk=Zx_1') 'a share link is recorded without its key'
Assert-True (Test-PathUnderRoot 'c:\users\me\repo\sub' @('C:/Users/me/repo')) 'a session in a subfolder is the repo''s, whatever the case or slash'
Assert-True (-not (Test-PathUnderRoot 'C:\Users\me\repo-other' @('C:\Users\me\repo'))) 'a sibling with a longer name is not'

Write-Host '-- the harvest: one transcript' -ForegroundColor Cyan
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('harvest-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$repo = 'C:\\Users\\me\\repo'
$lines = @(
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-01T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Artifact","input":{"file_path":"C:\\nowhere\\atlas.html","title":"Atlas","description":"first"}}]}}',
    '{"type":"user","cwd":"{REPO}","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"Published C:\\nowhere\\atlas.html at https://claude.ai/artifact/Atl1 (Version 1)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-02T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Artifact","input":{"action":"read","url":"https://claude.ai/artifact/Read1"}}]}}',
    '{"type":"user","cwd":"{REPO}","message":{"content":[{"type":"tool_result","tool_use_id":"t2","content":"Read the Artifact at https://claude.ai/artifact/Read1"}]}}',
    '{"type":"assistant","cwd":"C:\\Users\\me\\elsewhere","timestamp":"2026-10-03T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t3","name":"Artifact","input":{"file_path":"C:\\nowhere\\x.html"}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t3","content":"Published C:\\nowhere\\x.html at https://claude.ai/artifact/Other1 (Version 1)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-04T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t4","name":"mcp__claude_ai_Claude_Docs__batch","input":{"container":{"kind":"project","create":{"name":"Handout"}}}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t4","content":[{"type":"text","text":"{\"frame\":{\"url\":\"https://claude.ai/code/artifact/0f1e-2a\"}}"}]}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-05T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t5","name":"Artifact","input":{"url":"https://claude.ai/artifact/Atl1?sk=k","file_path":"C:\\nowhere\\atlas.html","asset":true}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t5","content":"Uploaded the asset at https://claude.ai/artifact/Atl1"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-06T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t6","name":"Artifact","input":{"url":"https://claude.ai/artifact/Atl1?sk=k","file_path":"C:\\nowhere\\atlas.html","description":"second"}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t6","content":"Published C:\\nowhere\\atlas.html at https://claude.ai/artifact/Atl1 (Version 2)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","message":{"content":[{"type":"tool_use","id":"t7","name":"Artif'
) | ForEach-Object { $_.Replace('{REPO}', $repo) }
$tx = Join-Path $tmp 'session.jsonl'
[IO.File]::WriteAllText($tx, ($lines -join "`n"))
$pubs = @(Read-ArtifactPublishes -Path $tx -Root @('C:\Users\me\repo'))
Assert-Equal 'Atl1,0f1e-2a,Atl1' (($pubs | ForEach-Object { ($_.Url -split '/')[-1] }) -join ',') 'publishes and a Docs create are found; a read, an asset upload, another repo and a cut-off last line are not'
Assert-Equal 'Atlas|page|2026-10-01' ($pubs[0].Title + '|' + $pubs[0].Kind + '|' + $pubs[0].Date) 'a publish carries its title, kind and day'
Assert-Equal 'Handout|document' ($pubs[1].Title + '|' + $pubs[1].Kind) 'a Docs create is a document named after the doc'
Assert-Equal 'atlas' $pubs[2].Title 'a publish without a title, its page gone, is named after its file'
$none = @(Read-ArtifactPublishes -Path $tx -Root @('C:\Users\me\unrelated'))
Assert-Equal 0 $none.Count 'a transcript from another repo yields nothing, not one empty entry'
Remove-Item -LiteralPath $tmp -Recurse -Force

Write-Host '-- the harvest: the merge only adds' -ForegroundColor Cyan
$held = '{ "artifacts": [ { "title": "Fixed by hand", "url": "https://claude.ai/artifact/Atl1", "kind": "slides", "created": "2026-10-02", "updated": "2026-10-03", "about": "kept" } ] }' | ConvertFrom-Json
$mg = Merge-ArtifactRegister -Register $held -Found $pubs
Assert-Equal 2 @($mg.Artifacts).Count 'one row added, the held one not duplicated by its share link'
$a1 = @($mg.Artifacts)[0]
Assert-Equal 'Fixed by hand|slides|kept' ($a1.title + '|' + $a1.kind + '|' + $a1.about) 'a held row keeps its title, kind and about'
Assert-Equal '2026-10-01..2026-10-06' ($a1.created + '..' + $a1.updated) 'and only has its dates widened'
Assert-Equal 'https://claude.ai/artifact/Atl1' (@($mg.Widened) -join ',') 'the widened row is reported'
Assert-Equal 'https://claude.ai/code/artifact/0f1e-2a' (@($mg.Added) -join ',') 'and so is the new one'
$fresh = Merge-ArtifactRegister -Register $null -Found $pubs
$f1 = @($fresh.Artifacts | Where-Object { $_.url -like '*Atl1' })[0]
Assert-Equal 'Atlas|second|2026-10-01|2026-10-06' ($f1.title + '|' + $f1.about + '|' + $f1.created + '|' + $f1.updated) 'a new row: title from the first publish, about from the last, dates spanning both'
$again = Merge-ArtifactRegister -Register ((ConvertTo-ArtifactRegisterJson -About 'a' -Date 'd' -Method 'm' -Artifacts $fresh.Artifacts) | ConvertFrom-Json) -Found $pubs
Assert-Equal 0 (@($again.Added).Count + @($again.Widened).Count) 'a second harvest of the same transcripts changes nothing'

Write-Host '-- the harvest: the file it writes' -ForegroundColor Cyan
$json = ConvertTo-ArtifactRegisterJson -About "it's" -Date '2026-10-18' -Method 'm' -Artifacts @([ordered]@{ title = 'A "q" \ b'; url = 'https://claude.ai/artifact/X'; kind = 'page'; created = '2026-10-01'; updated = '2026-10-01'; about = "line`tend" })
$back = $json | ConvertFrom-Json
Assert-Equal 'A "q" \ b' $back.artifacts[0].title 'quotes and backslashes survive the round trip'
Assert-Equal "line`tend" $back.artifacts[0].about 'and so does a control character'
Assert-True ($json.Contains("`"about`": `"it's`"")) 'an apostrophe is written as itself'
Assert-True ($json.StartsWith("{`n  `"about`"") -and $json.EndsWith("`n  ]`n}`n")) 'two-space indented, LF, ending in a newline'
Assert-Equal 0 @((ConvertTo-ArtifactRegisterJson -About 'a' -Date 'd' -Method 'm' -Artifacts @()) | ConvertFrom-Json).artifacts.Count 'an empty register is still valid JSON'

Write-Host '-- the release-notes page, as the dev server serves it (#3108)' -ForegroundColor Cyan
# The real template, so a change to its shape that would leave the served copy undressed goes red here.
$tpl = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\release-notes-page-template.html'))
$rn = Format-ReleaseNotesDevPage -Html $tpl
Assert-True ($rn -ne $tpl) 'the template has the shape the dressing needs'
Assert-True ($rn -match '<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="connector-dashboard">') 'it takes the theme key every other page of this server uses'
$tplStyleEnd = $rn.IndexOf('</style>')
$houseAt = $rn.IndexOf('<link rel="stylesheet" href="/house-style.css">')
Assert-True ($houseAt -gt $tplStyleEnd -and $tplStyleEnd -gt 0) 'the house stylesheet loads after the template''s own style, so the house body wins'
Assert-True ($rn.IndexOf('--panel: var(--primary-2)') -gt $houseAt) 'and the template''s tokens are pointed at house tokens after it'
Assert-True ($rn.IndexOf('<script src="/house-theme.js"></script>') -lt $rn.IndexOf('<body')) 'the theme script loads in the head'
$bodyAt = $rn.IndexOf('<body>')
$barAt = $rn.IndexOf('<div class="breadcrumbs-bar">')
Assert-True ($barAt -gt $bodyAt -and $rn.Substring($bodyAt + 6, $barAt - $bodyAt - 6).Trim() -eq '') 'the breadcrumb bar is the first thing in <body>'
Assert-True ($rn -match '<li><a href="/">Repo hub</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">Release notes</span></li>') 'its trail runs from the Repo hub to this page'
Assert-True ($rn.IndexOf('DKJTheme.settings(') -gt $rn.IndexOf('id="settings"') -and $rn.IndexOf('DKJTheme.settings(') -lt $rn.LastIndexOf('</body>')) 'the settings button is mounted before </body>'
Assert-True ($rn.Contains('<div class="wrap">') -and $rn.Contains('@@RELEASE_ROWS@@') -and $rn.Contains('@@PAGE_STYLE@@')) 'the template''s own content is left alone'
Assert-Equal '<html>fixture</html>' (Format-ReleaseNotesDevPage -Html '<html>fixture</html>') 'a page without the template''s shape is served as it came'

Write-Host '-- the Issues model' -ForegroundColor Cyan
$now = [DateTime]::new(2026, 10, 18, 12, 0, 0, [DateTimeKind]::Utc)
$isOpen = '[ { "number": 7, "title": "Free <b>", "state": "OPEN", "labels": [ { "name": "bug" }, { "name": "prio-3" } ], "assignees": [], "createdAt": "2026-10-16T12:00:00Z", "closedAt": null },
  { "number": 8, "title": "Parked", "state": "OPEN", "labels": [ { "name": "feature" }, { "name": "awaiting-decision-dev" } ], "assignees": [ { "login": "a" } ], "createdAt": "2026-10-10T12:00:00Z", "closedAt": null },
  { "number": 9, "title": "Claimed", "state": "OPEN", "labels": [ { "name": "bug-inbound" }, { "name": "bug" }, { "name": "prio-3" } ], "assignees": [ { "login": "b" } ], "createdAt": "2026-08-01T12:00:00Z", "closedAt": null } ]' | ConvertFrom-Json
$isRecent = '[ { "number": 1, "title": "Done", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [ { "name": "bug" }, { "name": "prio-2" } ], "assignees": [], "createdAt": "2026-10-17T00:00:00Z", "closedAt": "2026-10-17T10:00:00Z" },
  { "number": 1, "title": "Done", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [ { "name": "bug" }, { "name": "prio-2" } ], "assignees": [], "createdAt": "2026-10-17T00:00:00Z", "closedAt": "2026-10-17T10:00:00Z" },
  { "number": 2, "title": "Old one closed", "state": "CLOSED", "stateReason": "NOT_PLANNED", "labels": [], "assignees": [], "createdAt": "2026-09-01T00:00:00Z", "closedAt": "2026-10-01T00:00:00Z" },
  { "number": 3, "title": "Closed before the window", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [], "assignees": [], "createdAt": "2026-09-01T00:00:00Z", "closedAt": "2026-09-02T00:00:00Z" },
  { "number": 7, "title": "Free <b>", "state": "OPEN", "labels": [ { "name": "bug" }, { "name": "prio-3" } ], "assignees": [], "createdAt": "2026-10-16T12:00:00Z", "closedAt": null } ]' | ConvertFrom-Json
$im = ConvertFrom-IssueList -Open @($isOpen | ForEach-Object { $_ }) -Recent @($isRecent | ForEach-Object { $_ }) -Now $now -Days 28
Assert-Equal '7,9,8' ((@($im.Open) | ForEach-Object { $_.Number }) -join ',') 'open issues, highest priority first, then by number'
Assert-Equal 'Free,Claimed,Parked' ((@($im.Open) | ForEach-Object { $_.Board }) -join ',') 'a parking label wins over an assignee; an assignee makes it claimed'
Assert-Equal 'bug-inbound' (@($im.Open)[1].Kind) 'an inbound label names the kind before bug'
Assert-Equal 3 $im.Opened 'opened in the window: #7, #8 and #1, #1 counted once'
Assert-Equal 2 $im.Closed 'closed in the window: #1 and #2, not #3'
Assert-Equal 1 $im.Matrix['3'].Free 'the matrix counts the free prio-3 issue...'
Assert-Equal 1 $im.Matrix['3'].Claimed '...and the claimed one'
Assert-Equal 1 $im.Matrix['0'].Parked 'an issue without a priority lands in row 0'
Assert-Equal 4 @($im.Weeks).Count 'a 28-day window is four weeks'
Assert-Equal 2 @($im.Weeks)[-1].Opened 'the last week holds the openings of #7 and #1'
Assert-Equal 1 @($im.Weeks)[-1].Closed 'and the one close of that week'
Assert-Equal 365.0 ([double]$im.MedianCloseHours) 'the median of 10 h and 720 h is their mean'
Assert-Equal 'completed,not planned' ((@($im.ClosedBy.Reason) | ForEach-Object { $_.Name }) -join ',') 'closed-as reasons, lowercase'

Write-Host '-- the Issues page' -ForegroundColor Cyan
$ip = Format-IssuesPageHtml -Model $im -GeneratedAt '2026-10-18 14:00:00' -Seconds 3.2
Assert-True ($ip -match '<h1>Issues</h1>' -and $ip -match '<span aria-current="page">Issues</span>') 'the page is named Issues, in the h1 and the trail'
Assert-True ($ip -match 'Open now</div><div class="v num">3<') 'the tile counts the open issues'
Assert-True ($ip.Contains('Free &lt;b&gt;') -and -not $ip.Contains('Free <b>')) 'an issue title is escaped'
Assert-True ($ip.Contains('href="https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/7"')) 'each open issue links to GitHub'
Assert-True ($ip.Contains('/refresh?page=issues')) 'the footer offers a fresh read'
$ipNone = Format-IssuesPageHtml -Model (ConvertFrom-IssueList -Now $now)
Assert-True ($ipNone.Contains('No open issue')) 'no open issue says so instead of an empty table'
$ipFailed = Format-IssuesPageHtml -Model $null -ReadError 'gh issue list exited 1'
Assert-True ($ipFailed.Contains('msg--warn') -and $ipFailed.Contains('gh issue list exited 1')) 'a failed read is a warning on the page'
Write-Host ''
Write-Host "dev-pages: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
