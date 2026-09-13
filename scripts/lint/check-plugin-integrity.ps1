<#
.SYNOPSIS
    Integrity check for the dkj-claude-plugins marketplace: validates the manifests, the
    agent-def frontmatter and the internal links before a change lands via a PR on main.
.DESCRIPTION
    This repo's lint gate (invoked by scripts/release/open-pr.ps1). Read-only -- changes nothing.
    Checks the following; every finding is an error:
    <!-- checks:list -->

      1. .claude-plugin/marketplace.json: valid JSON; every plugins[].source points to an
         existing folder with a .claude-plugin/plugin.json.
      2. every <plugin>/.claude-plugin/plugin.json: valid JSON with a non-empty 'name'.
      3. every <plugin>/subagents/*.md: frontmatter contains 'name:', 'id:' and 'group:'.
      3b. every <plugin>/manuals/*-manual.md: frontmatter contains 'id:' and 'group:', and the
         file name <group>-<id>-manual.md matches that frontmatter (the portable manual that the
         corresponding agent def reads in via ${CLAUDE_PLUGIN_ROOT}/manuals/).
      3c. every <plugin>/personas/*-persona.md: frontmatter contains 'id:' and 'group:', and the
         file name <group>-<id>-persona.md matches that frontmatter. Personas (orchestrator +
         main-loop specialists) DELIBERATELY have no agent def -- they run in the main loop, not
         as a subagent -- so check 6 never demands one of them. It does read them in one direction:
         a persona MAY back a manual of the same id (6b), and then has to name it.
      4. dead relative links AND broken anchors in every ROOT *.md (README.md, CHANGELOG.md, CLAUDE.md,
         CONTRIBUTING.md, SECURITY.md, INSTALL.md, UNINSTALL.md and any unfolded changelog entry file
         -- globbed, never named), every .claude/extensions/*.md, every <plugin>/skills/*/SKILL.md, every
         <plugin>/manuals/*-manual.md, every <plugin>/personas/*-persona.md, every releases/**/*.md,
         every <plugin>/RELEASE.md, connectors/README.md, and
         every plugin's own plugins/<plugin>/CHANGELOG.md (#103).
         Checked: (a) the linked
         file exists, and (b) if the link
         has a #anchor, that anchor exists as a heading in the target file (GitHub slug rules).
         External http(s)/mailto links are skipped.
      5. every scripts/**/*.ps1 parses without error (catches syntax errors in the orchestration
         itself, which would otherwise only break at execution time).
      6. specialists-system integrity: per plugin, every '<group>-<id>' is unique across the
         agent defs, every agent def has a valid 'name:' + a corresponding manuals/<g>-<id>-manual.md
         which it also names, and conversely every manual is backed by an agent def OR a persona of
         the same id (no orphan manual) -- a persona-backed manual must be named by that persona.
      7. shared agent-def blocks: every <!-- BEGIN/END shared:NAME --> region in an agent def still
         equals its canonical source in dkj-subagents/subagent-shared/<name>.md (see scripts/agents/build-agent-defs.ps1)
         -- a hand-edit inside the sentinels or a forgotten rebuild is thus caught at the gate.
      8. shared workflow scripts: every plugin mirror of a repo-agnostic script (issue #81) is
         still LF-identical to its root source -- a hand-edit in the mirror or a forgotten
         scripts/sync/build-shared-scripts.ps1 is thus caught at the gate.
      9. RETIRED, August 8, 2026 ("RELEASE.md present per plugin + version match"). The number is kept
         and never reused: reusing it would silently repoint every older citation, which is the defect
         check 34 was built against arriving by the other door. It held each plugin-carried RELEASE.md
         card against its plugin.json version; the cards are gone, so a plugin's version has one
         statement again and there is no second copy left to compare. The retirement note sits in the
         code where the check stood.
     10. marked "all skills" enumerations: an opt-in <!-- skills:all --> ... <!-- /skills:all -->
         span (character-based, so it also wraps inline running prose, not just a bullet list on
         its own lines; scanned in every file from check 4's $linkFiles, with fenced ```-code blocks
         masked out first so a literal example of the marker syntax in a fence is not itself read as
         a live marker) must contain the exact set of backtick-quoted names -- no more, no fewer --
         against the canonical skillset read from every <plugin>/skills/<name>/SKILL.md 'name:'
         frontmatter across ALL plugin folders (not just 'specialists'). A BEGIN without a matching
         END, an END without a matching BEGIN, AND a stray extra END inside an already-open span
         (e.g. a pasted-in duplicate '/skills:all') are all hard errors -- symmetric in both
         directions, EXCEPT when a marker sits inside a fenced example (masked out before matching,
         so it is never seen at all, paired or not). Deliberately opt-in (no generic prose scan): a
         doc with zero spans passes without warning.
     11. printed lifecycle commands: every 'claude plugin install|update|uninstall' that carries an
         @-target (i.e. is an instruction someone RUNS, not prose discussing the command) must carry
         '--scope project' -- or, for 'uninstall' only, '--scope local' (inbound #315: that is the only
         command that removes a record a session start left at local scope). install/update must have
         'claude plugin marketplace update' or a link
         to 'staying-up-to-date' within 12 lines above or 6 below. Both flags fail SILENTLY when
         missing -- a scopeless install writes a machine-wide record and reports success (#274/#279),
         a stale cache serves the previous version and reports success (#282/#284) -- which is why
         three adoption rounds in a row found this same class of doc defect. The @-target is what
         makes a generic scan viable here where check 10 had to be opt-in: measured 11 targeted
         instructions against 13 bare mentions. History is excluded permanently and on purpose
         (CHANGELOG.md root + per-plugin, releases/**, RELEASE.md, root entry files): it records what
         was true then and is never rewritten. The unit is the enclosing inline-code span (a printed
         command wraps across lines), computed over check 10's fence-masked text so a ```-fence
         cannot throw off backtick pairing; inside a fence the unit is the physical line.
     12. printed install-record queries: a fenced block that READS installed_plugins.json in code (names
         the file and parses it) must select 'projectPath', 'scope', 'version' AND 'gitCommitSha'. This is
         the class behind all three findings of adoption round v8 rather than any one of them: the query
         every document points a reader at could not distinguish the release from main after it (#313),
         one record from two (#315), or 'project' from 'local' (#314) -- so it printed a green that
         under-determined the state it claimed to prove. projectPath is required rather than assumed: a
         query without it reports records beyond this repo, which is the 'claude plugin list' mistake
         these same docs warn against. A fenced JSON snippet illustrating the file's shape is NOT a
         subject (it names the fields but is not a command anyone reads a verdict off) -- the same
         mention-versus-use discriminator check 11 makes with its @-target. Shares check 11's scan set,
         so history is excluded identically. Matching is case-insensitive, since PowerShell property
         access is and a working query must not be reported as broken.

     13. entry-heading levels: an entry is an H3 with two named H4 sections, and a body heading may be
         neither. At or above the entry's own level it becomes a SEPARATE entry the moment the fold pastes
         it into CHANGELOG.md -- one declaring no impact, so filed as an undeclared tier 0 -- or, at H1,
         climbs above every entry in the document (seen in v2.13.2). At the SECTION level it truncates the
         section it lands in, and if it is a misspelling of a real section heading the entry silently loses
         that declaration and the tier/significance gates read nothing. Every level comes from
         entry-scaffold-lib.ps1 rather than being written out here. Judged in every unfolded root entry
         file (line 1 skipped, so a pre-format H3 entry still passes) and in CHANGELOG.md below its intro,
         where the intro/entries boundary is derived structurally exactly as Split-Changelog derives it.
    13b. no branch document is left behind between branches. The document exists for the lifetime of a
         branch -- new-branch creates it, the fold removes it -- so absent is the trunk's normal state, a
         file naming the CURRENT branch is work in progress, and a file naming the TRUNK is a leftover
         the fold should have taken. Inverted on August 23, 2026 (Dave): it used to hold the trunk's
         copy to the formatter byte-for-byte, which was two sources of one format, and there is no trunk
         copy to hold any more. No shape is asserted, deliberately -- a branch's file holds somebody's
         work and can never be compared to the formatter; the scaffold and step-list gates read its
         CONTENT on the way to the PR, so what was lost is the byte-comparison, not the coverage.
     14. encoding: scripts/maintenance/fix-mojibake.ps1 -Check is run as the gate. WHICH files it walks
         is repo-owned since issue #413 -- Get-MojibakePaths in scripts/repo-config.ps1 names them, here
         every *.md in the root, every *.md under plugins/, and every note under releases/. A UTF-8
         character read as ANSI and written back changes the text with no error -- and in an entry
         heading the separator IS the field delimiter, so cut-release.ps1 stops being able to read the
         entry type.
     15. unbound output samples: a fenced block with no language (or 'text') is something the reader
         COMPARES against, so something near it must say what the capture is bound to -- a version, a
         date, a platform, a repo state, or a hedge. Four of test round v11's nine findings were this
         one shape. Blocks tagged powershell/json/jsonc are commands to RUN and are left alone; so are
         blocks containing box drawing, which are drawn rather than captured.
     16. measured figures in prose: check 15's subject one step outside a fence -- a byte count or file
         size in the consumer-facing docs is a measurement of somebody's machine, and the surrounding
         paragraphs must say whose (round v12 filed exactly this as #374).
     17. RETIRED, August 8, 2026 ("the per-plugin CHANGELOG intro still matches its template"), and the
         number is kept for the reason given at 9. It existed because that intro was write-once, which is
         how all four per-plugin CHANGELOGs kept naming the retired marketplace long after the rename had
         swept it out of 59 files. The files it guarded are gone, and with them the write-once text; the
         LESSON survives in scripts/lib/release-lib.ps1's header, because it is about the next template
         rather than about those files.
     18. shared-script parameters vs. their skill: every parameter of a mirrored entry point must be named
         in the skill that documents it (the mapping lives in the shared-scripts registry, beside the
         registration). A consumer has only the mirror and its page, so a parameter the page never names
         does not exist for them -- including the escape valve they need when something goes wrong. This is
         a repair: the fold skill told consumers to commit by hand for two days after the script gained
         -Commit/-Push, and four more were found the same way, -Bump and -NoPush among them. Parameters are
         read via the PowerShell parser (a regex missed an attributed one). Per-script exemptions are
         declared in the registry; an entry point declaring no skill at all is reported in the coverage
         line rather than as an error, since writing a missing skill is separate work.
     19. the consumer-facing document set: a document named in that list but absent from the tree is
         reported instead of skipped, because checks 15 and 16 walk the same list and a missing entry
         lowers their coverage silently.
     20. a claimed entry-section COUNT vs. what the scaffolder writes, so prose describing the changelog
         entry cannot drift from the shape a branch actually gets. The rule is the count and not the
         section names, chosen by measuring four candidates. (20b) CHANGELOG.md's intro gets its own pass
         with the level marker optional: the entries below it are history, but the intro is a live
         statement that every cut copies through verbatim, so nothing else ever reads it.
     21. the shipped config blueprint, held by REGENERATING it from this repo's own libs and comparing.
         Nothing here reads the artefact, which is exactly why it needs a gate.
     22. a runnable command in a shipped SKILL.md must not name an absolute path. The page tells a
         consumer what to run, so the path has to resolve on their machine: '${CLAUDE_PLUGIN_ROOT}/...'
         does, 'C:/Users/<the author>/...' does not. Measured after adopt-config's page shipped with both
         of its commands pointing at the author's own plugin cache, pinned to a version. The subject is
         the '-File' argument rather than paths in general, because a tree-wide rule would be born
         accusing three correct comments that quote a user path to explain a path-mangling bug.
     23. a plugin's name says which kind it is, and where that name claims a directory it must sit
         there: 'team-*' under plugins/dkj-subagents/, and '*-policy' / '*-policy-*' under plugins/dkj-policy/.
         'workflow-*', 'contributing-*' and '*-codex' are accepted names held to no directory since
         #1467, because plugins/workflows/ -- which used to name their kind -- is gone. Every plugin is
         still one or the other BY NAME. The directory rule is DERIVED from the
         name, so a plugin matching none of those has its location held against nothing -- an
         unclassifiable name switches the check off for itself rather than merely reading untidily.
         (Until #886 the reason was the core's workflow-sessioncheck counting by the 'workflow-'
         prefix; that hook was retired with workflow-default and the argument above is the one that
         survives it.)
     24. the PR template keeps the two promises open-pr makes about it: the shipped reference under
         plugins/dkj-policy/templates/ byte for byte against Get-PrTemplateReference,
         and THIS repo's own .github/pull_request_template.md only to the contract (one placeholder line
         the matcher recognises). Deliberately weaker for the second, which is genuinely repo-owned: a
         byte rule would refuse a correct change the day it grows a section. A heading is no longer part
         of that contract -- see the block at the check for why open-pr stopped needing one.
     25. the consumer document does not send its reader into a tier written for somebody else -- a link
         from releases/consumer/ into the development (tier 0) or internal (tier 1) tree. LINK TARGETS
         only; a tier named in prose is check 4's declined-path territory. Two neighbouring rules (a
         score, a branch name) were measured on the same tree and declined at 4 and 3 findings, all false.
     26. no frontmatter-bearing shipped document carries a byte-order mark, read as BYTES. Every other
         reader here uses ReadAllText, which strips a BOM before any regex sees it, so a BOM is invisible
         to this gate AND to any editor a reviewer would open -- the one defect findable by neither.
         Measured: adopt-config/SKILL.md shipped with EF BB BF in 4.1.0 and was the one model-invocable
         skill of eleven missing from the agent's skill listing. The subject is the BOM and NOT "must have
         frontmatter": this repo deliberately tolerates a skill page without a 'name:' line, so demanding
         the block would be this gate inventing a policy the repo declined.
     27. the script layer is pure ASCII -- every .ps1 check 5 parses, held to the rule
         .claude/rules/language-layers.md has stated since August 19, 2026 and nothing enforced. Windows
         PowerShell 5.1 reads a BOM-less .ps1 as the system ANSI code page, so a literal non-ASCII
         character decodes as two CP1252 characters, silently, and reaches whatever the script EMITS --
         measured on a middot in entry-scaffold-lib.ps1 that came out wrong in every generated changelog
         template. Check 14 sees that damage one layer downstream, in the generated markdown; this sees
         the literal upstream. A BOM is deliberately NOT a finding: on a .ps1 it is the fix.
     28. every '@'-import target resolves. A dead markdown link costs a reader one click; a dead import
         costs the SESSION THE WHOLE DOCUMENT, because Claude Code drops one it cannot resolve without
         erroring. Reuses measure-context-lib's own parser rather than restating its three resolution
         rules. (Listed here from August 26, 2026 -- the check shipped without its line in this list.)
     29. a plugin's OWN skill enumeration: an opt-in <!-- skills:plugin --> ... <!-- /skills:plugin -->
         span, held against the skills/ of the plugin the DOCUMENT ITSELF sits in (resolved from its
         path, not named in the marker). The two ways it is not check 10: the canonical set is that one
         plugin's rather than the marketplace's, and a claim is a LINK TARGET resolving to
         skills/<one>/SKILL.md rather than any backtick-quoted token -- so a two-column table with prose
         and backticked paths in the second column needs no rewriting to be markable. Opt-in for the
         reason check 10 is: measured over all four plugins, a generic version yields 8 findings on two
         documents that never claimed to enumerate anything.

     30. a plugin-shipped relative link must resolve INSIDE its own plugin. Check 4 resolves every link
         against the tree it runs in, and for plugin payload that tree is this repo -- the one place the
         link is guaranteed to work -- so the single class of link defect that reaches a consumer is the
         one it is structurally blind to. A consumer reads the file under
         ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/, where the 'plugins/' level, the
         family level and every sibling plugin are gone, so a link that walks out of the plugin root
         lands nowhere -- or worse, on something else. THE BOUNDARY IS THE PLUGIN ROOT, not 'plugins/':
         the weaker rule inbound #1066 proposed passes a link that had ALREADY shipped dead. 17 escapes
         across 5 files at introduction, every one passing check 4 and all 17 dead in the installed
         copies. Personas are excluded for check 4's reason: a persona template is destined for a
         consuming repo, so its links are MEANT to resolve outside the plugin root.
     31. the Shopify CLI is never invoked bare. Under $ErrorActionPreference = 'Stop' -- which every
         script here sets -- a bare '& shopify ...' dies on the line AFTER the call the moment the CLI
         writes anything to stderr, so the exit-code check below it never runs. The repair is
         scripts/lib/shopify-cli-lib.ps1, which lowers the preference for the duration of the call, and
         the reason it needs a gate is that THE DANGEROUS FORM IS THE ABSENCE OF A WRAPPER: there is no
         redirect to grep for and no suspicious flag -- the wrong spelling is the shorter, more obvious
         one. Read through the PARSER, not by line matching, so a comment about the rule and a printed
         hint telling a reader to run the CLI are not subjects. Two exemptions, both by file name: the
         wrapper itself, and the suite whose probe invokes the stub bare on purpose.
     32. a mirror table's rows against the shared-scripts registry: an opt-in
         <!-- shared-scripts:mirror --> ... <!-- /shared-scripts:mirror --> span whose rows are held to
         Get-SharedScriptPairs. Check 8 proves the file on disk is the right file and has never asked
         whether the page that TELLS a consumer which files exist still names them all -- so a script can
         be registered, generated, mirrored byte-perfect and pass every gate while being invisible on the
         one page a consumer reads. That happened three times before this. The claim is the first
         backticked token of each row's first cell (the table's own 'Script' column), and the scope is
         the marked document's OWN directory. Opt-in like 10 and 29, because the root scripts/README.md
         is a deliberate SUBSET of the same registry and a filename-keyed rule would false-positive on
         every lib and hook-only script there.
     33. printed instructions naming a model-barred skill: a printed message must not tell its reader to
         "run the X skill" when X's frontmatter carries 'disable-model-invocation: true'. That flag removes
         the page from the model's context entirely, so a session cannot follow the instruction -- and the
         reader who CAN, the person at the keyboard, is never told the line is theirs to type. The correct
         form names the slash-command and the actor, or names the script. FRONTMATTER-DRIVEN, not a
         phrasing rule: check-script-contract names the UNFLAGGED 'adopt-dkj-policy' with the same
         bare imperative and is correct to, so a grep for the wording would be born with a false finding.
         The discriminator is the word 'skill' after the name, measured: without it 8 unique sites of which
         4 are wrong (three name the SCRIPT, one is prose offering a choice); with it 11 hits over 7 sites,
         all 7 correct. Both layers are scanned, also measured -- printed output carries 6 of the 7 and
         INSTALL.md the seventh, so output-only would have passed over the one a consumer reads. Printed
         means a string argument to a writer cmdlet, found through the PARSER, so a comment about the rule
         is not a subject. Markdown reuses CHECK 11's file set and its fence masking, and both matter here:
         history (CHANGELOG.md, releases/**, RELEASE.md) records the old wording and is never rewritten, the
         branch document's text is pasted into CHANGELOG.md at the fold, and a FENCED example is an
         illustration rather than an instruction. Found the hard way -- the branch introducing this check
         quotes the forbidden wording to explain it, and the gate refused to push it. The class bit twice a
         month apart with nothing connecting them (#731 -> #734, then #1093/#1096 rediscovered from scratch
         when a consumer adoption stopped on it), which is what turned it from a risk into the finding
         filed as #1104.
     34. a numbered section header is unique, ascending, and in one form. Every check here announces
         itself with a column-0 '# --- <n>. <what it does>' header, and that number is how a finding is
         cited in a lens, a hook, a test name and two published release notes -- read back by nothing
         until #1494, when two unrelated checks both carried 30 and two released documents meant
         different ones by it. ASCENDING is the property that prevents the collision, not uniqueness:
         it leaves a new section exactly one legal number, the one after the last header, so the
         renumbering that follows a move is forced rather than remembered. Gaps are legal (a retired
         number is never reused) and lettered sub-sections are legal. COLUMN 0 ONLY: the same marker is
         used indented inside the suites to separate scenarios under their own numbering, and those are
         not file sections. Both spellings are subjects; only '# --- <n>. ' is legal.
     35. a test fixture's own git command is judged. A suite that builds its fixture with a git call
         whose output AND exit code are both thrown away produces a repo that is PLAUSIBLE -- it exists,
         it has a HEAD, it just does not hold what the case assumed -- so every assert below it measures
         the wrong thing and attributes the failure to the script under test, which is the one place it
         certainly is not. The idiom was the HOUSE STYLE, copied from suite to suite, which is why the
         #1635 sweep could not hold it: it converted the neighbours and left nothing refusing the next
         copy. Measured before it was written -- 27 findings in 4 files the sweep had missed, 182 over
         the pre-sweep tree, and ZERO probe false positives. A call is cleared when $LASTEXITCODE or
         Assert-FixtureGitOk is read in the same statement or the next: a question's exit code is read
         immediately, a discarded one never is. No verb is special-cased and no file is exempt.
     36. a tool that obliges a shared block, against the defs that hold it. Check 7 compares the inside
         of a sentinel pair against its source, so it answers "has this block drifted" and has never had
         an opinion about a pair that is ABSENT -- right for a block placed by CRAFT, wrong for one
         placed by CAPABILITY. Get-ToolRequiredSharedBlocks maps tool -> block name, and that table is
         the subject: a list of expected carriers here would be the memory this check replaces. Without
         it, an agent def gaining Bash later sits silently outside the boundary with every gate green.
         The reverse is deliberately not checked -- a wider circle is a decision, a narrower one is the
         defect -- and the personas need no exclusion, carrying no 'tools:' line to be obliged by.
     37. THIS LIST, against the headers it claims to enumerate: an opt-in 'checks:list' span whose
         entries are held to the same column-0 headers check 34 reads. Check 34 holds those headers to
         each other; nothing read the prose that summarises them for a reader who has not opened the
         file -- the list a lens, a hook or a release note quotes a number from. Measured (#1680): the
         list stopped at 30 while the code ran to 36, 13b was missing too and no report had noticed,
         its own item 30 described the check #1494 had renumbered to 33, and 9 and 17 still read as
         live checks a month after they were retired. ONE DIRECTION, which is what makes it born green:
         every header needs an entry, an entry needs no header -- the reverse is where the exemptions
         would live, being a retired check's tombstone (9 and 17) and the consumer-doc guard the suites
         call check 19. An entry is read at the LIST'S OWN INDENT, so a number opening a line deeper
         than that -- a nested enumeration inside an entry's prose -- is not a claim; counting one
         would silence the check exactly where the missing entry sits below it. That shape is absent
         from this list today and was found by PROBING the check rather than by measuring the tree,
         which is check 35's lesson applied. Two spans in one file are unioned and counted once. NOT
         held, deliberately: a STALE entry keeps satisfying its number, which is this list's second
         drift and needs an entry's text read against a header's -- see the code for why that is left
         open. A script that must SHOW the marker composes it from a variable; there is no fence to
         hide it behind in a .ps1.
     38. a plugin's 'agents' key, in both directions: every entry held to the shape the INSTALLER
         accepts -- an existing .md file inside the plugin root, never a directory and never a glob --
         and every *-agent.md a plugin ships held to the list that has to name it. Measured (#1764):
         all four team plugins shipped v4.33.0 with "agents": "./subagents/", this gate reported 0
         error(s) over them, and 'claude plugin install' answered 'agents: Invalid input' on every
         one -- four of six uninstallable by any consumer for a whole release. Checks 1 and 2 read the
         same manifests and neither has an opinion about a FIELD's shape, which is how that passed.
         The plugins reference is what misled #1698 and is wrong: it prints ["./agents/", ...] as
         legal and this validator rejects it at element 0, while 'commands' accepts the same
         directory. The two directions fail differently -- a bad element makes the installer refuse
         the whole plugin, an omitted def installs fine and never loads -- and only the first is
         reachable by 'claude plugin validate', which is why that CLI is not delegated to. A plugin
         with NO key is held to the convention instead: a def outside agents/ is declared by nothing.
         A nested plugin root's files are its own, not its parent's.
     39. a depth-sensitive $PSScriptRoot resolution in a mirrored script, against the suite that runs
         the mirror. Check 8 holds the two copies byte-identical, which proves they are the same TEXT
         and says nothing about behaviour -- and they sit at different depths, so a resolution
         ascending TWO levels reaches the repo root from the source copy and the plugin root from the
         mirror. Identical characters, different folder, nothing to diff. Such a pair must declare
         MirrorRun (the suite that executes its mirror) or MirrorRunExempt (why none does), and a
         declared suite must exist and name the mirror, so the declaration cannot be fiction. One hop
         is deliberately not asked about: '..\lib\...' is the same folder relative to the file in both
         copies, and flagging it would bury the crossings under the thirty-odd that cannot differ
         (measured #1857: 3 of 34 entry points, all three already correct, and the single suite that
         ran a mirror at all covered none of them). Whether the run ASSERTS anything is the suite's
         job, the same line check 18 draws between this gate and a skill page.
     40. a plugin script's $PSScriptRoot-bound load of another .ps1, against the plugin that has to
         carry it. Check 8 proves the two copies are the same TEXT and check 39 that the text means
         the same FOLDER; neither asks whether the file it names is THERE. A lib registered for two
         plugins and dot-sourced by a script that mirrors into a third names a file its destination
         does not have -- check 8 has no third entry to compare against, and check 39's subject is a
         TWO-hop ascent while '..\lib\' is one. Measured (#1925): four shopify scripts shipped that
         way on the #1917 branch, all four dead ON LOAD in a consumer at their first statement, and
         this gate reported 0 error(s). The subject is the PLUGIN copy, since a source script's
         neighbours are all present here, and every .ps1 under a plugin root is read, hooks and
         plugin-native scripts included. TWO ARMS: the file must exist, AND the path must stay inside
         that plugin root -- an escaping path resolves in this tree and is gone in the install, which
         is check 30's lesson one layer over and invisible to existence alone. A reference GUARDED by
         Test-Path is counted, not judged: that is the author declaring the absence expected, which
         this tree means (release-lib's branch-info sibling is repo-owned and travels in no mirror),
         and judging the 70 of them would arrive with an exemption list. Only $PSScriptRoot is a
         subject, bound through the AST -- a $repoRoot-relative path names a file in the CONSUMER'S
         root by design, and reading those as plugin-relative yields 14 findings here, all false.
     41. the #1934 fixture load guard, against the suites that carry it. A fixture missing a lib the
         copied acting script dot-sources UNGUARDED kills the child during LOAD, and the suite then
         reports the absence of the document it never wrote -- naming the absent lib, the dot-source
         and load failure not at all (six suites, #1924). #1934 wired six suites in three parts and
         nothing asserted any of the three was still there, so an edit dropping a call restored the
         class silently, green. SELF-ANCHORING: a suite carrying ANY part must carry all three, so no
         list of wired suites is maintained -- the hand-listed failure #1693, #1865 and #1924 each
         ended up removing. A fourth fact is that Write-FixtureScriptSummary's verdict is READ, since
         printing it is not what fails the run: dropped, the suite prints the block and exits 0,
         wearing the guard's own output as proof it is wired. Born green: 7 wired, all complete, 0
         exemptions. #1948's OWN proposed rule -- any captured child invocation with no verdict -- was
         measured first and NOT built: 71 findings over 82 invocations, which is a proposal to wire 65
         more suites (#1954), and its check-35 adjacency reports all six WIRED suites as findings
         because they judge two to four statements after the call.
    <!-- /checks:list -->

    Exit code: 0 = no errors. 1 = at least one error (usable as a gate in open-pr.ps1).
.PARAMETER SkipCheck
    (Optional) coverage categories NOT to run, e.g. -SkipCheck parse,branch-template. FOR THIS GATE'S
    OWN TEST SUITES, and for nothing else: no gate -- open-pr, cut-release, CI -- passes it, and a guard
    test holds them to that.

    WHY IT EXISTS, MEASURED. The four check-plugin-integrity-*.tests.ps1 suites run this script 168 times
    over a fixture -- 52 + 45 + 40 + 31 -- each run a fresh process executing all 30 checks in order to
    assert one. As ONE suite that was 194s, of which 98% was inside those child runs, and it was the test
    gate's whole wall clock -- three times the next slowest suite, so the gate cost what this one suite
    cost. Profiled over the fixture at the time, three checks were reported as half of every run:
    agent-def, parse and branch-template, none of which most scenarios are about.

    THE SKIP CAME FIRST AND THE SPLIT SECOND, and both were needed. Skipping took the suite from 194s to
    ~160s; splitting it into four files (August 16, 2026, issue #714) took the runs from 160s in one lane
    to ~51s across four ON A WORKSTATION, because the test gate parallelises per FILE. Neither removed a
    scenario.

    THE SKIP'S OWN SAVING IS NOW 2.0%, re-measured September 3, 2026 (issue #1358): 1.362s against 1.390s
    over today's fixture. The three checks are not half of anything in it -- it carries 2 skills, no
    manuals and no personas, so they have almost nothing to walk there. The counts above were 110 and 27
    until the same re-measurement. Do not reach for this parameter for speed; it buys 2% and it is the one
    knob here that can make an absence assert pass vacuously. The fixture's own header records what
    actually dominates an invocation, and check-plugin-integrity-fixture.ps1 is where that measurement
    lives.

    A SKIPPED CHECK IS NEVER REPORTED AS 'checked 0'. This gate deliberately makes an empty scan visible
    -- 'no agent def found' is a finding-shaped statement, because a check that examined nothing must not
    read as a check that passed. A skip therefore prints its own [SKIP] line and no coverage line at all,
    so the two states cannot be confused by a reader or by an assert.

    An unknown category is a hard error rather than a no-op, because the failure mode this parameter
    introduces is silence: a scenario that skips 'agentdef' would run the check it meant to skip, and a
    scenario asserting the ABSENCE of a finding from a check it accidentally skipped would pass while
    testing nothing.
.EXAMPLE
    ./scripts/lint/check-plugin-integrity.ps1
#>
param([string[]]$SkipCheck = @())

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$errors = New-Object System.Collections.Generic.List[string]

# EVERY FINDING GOES THROUGH HERE, and that is load-bearing rather than tidy. Until August 6, 2026 the
# checks below were split between this function and sixteen bare '$errors += "..."' lines. On a List[T],
# '+=' does not append -- it rebuilds the whole thing as a fixed-size Object[] and rebinds $errors to it,
# after which EVERY later Add-Error throws "the collection is of a fixed size" and the run dies mid-scan.
# It never fired because the ordering hid it: all Add-Error callers happened to sit above the first '+=',
# so the array only ever came into being after the last one. The first check added below that line found
# it immediately. Adding a finding must not depend on where in the file you add it.
function Add-Error([string]$Msg) { $script:errors.Add($Msg) }

# CHECK 33'S FINDING, hoisted here beside Add-Error because it IS an Add-Error caller and the comment
# above says adding a finding must not depend on where in the file you add it. One place composes the
# message, so the two scan loops below (script strings, markdown lines) cannot drift in what they tell
# the author to do about it.
function Add-BarredSkillFinding {
    param([string]$Rel, [int]$LineNo, [string]$Skill, [string]$Sample)
    $trimmed = ($Sample -replace '\s+', ' ').Trim()
    if ($trimmed.Length -gt 120) { $trimmed = $trimmed.Substring(0, 120) + '...' }
    Add-Error ("[barred-skill] ${Rel}:${LineNo}: tells its reader to run the '$Skill' skill, but that skill" +
        " carries 'disable-model-invocation: true' -- its page is not in the model's context, so a session" +
        " cannot follow this and the person who CAN is not told the line is theirs to type. Name the" +
        " slash-command and the actor (`"ask the operator to run /$Skill`"), or name the script the skill" +
        " runs. The flag decides who types the line, not whether the line may run. Found: `"$trimmed`"")
    $script:barredFindings++
}

# Write-Coverage: the shared, non-counting [COVERAGE] line (issue #221), so every category below states
# how many items it examined and an empty one announces itself instead of passing in silence. Only that
# function is used from this lib; its counting report helpers (Write-Info/Write-Failure) stay unused and
# would in fact be wrong here -- this script's $errors is a List[string], not an int counter -- exactly
# the deliberate, documented non-collision check-consumer-drift.ps1 already relies on.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# release-lib supplies the pure helpers this gate reads the release layer through: Get-MarketplaceName,
# Get-PluginManifestPaths and Split-Changelog. It used to name Build-PluginChangelogIntro and check 17 here
# instead; both went with the per-plugin CHANGELOG and RELEASE.md on August 8, 2026, and this line outlived
# them by one day -- a comment naming a deleted function as the reason for an import, which is the same
# class of drift check 20 below was widened for.
#
# Dot-sourced here with the other lib rather than mid-file, so every import this gate depends on is visible
# in one place. release-lib deliberately sets no strict mode of its own, so it cannot loosen this script's
# Set-StrictMode -Version Latest.
. (Join-Path $PSScriptRoot '..\lib\release-lib.ps1')
# The PR-template contract check (24) needs the placeholder list open-pr matches against, and the
# reference body it ships. Both live here rather than inline in open-pr.ps1 since August 10, 2026 (#573)
# precisely so a gate can read them -- a list no gate can reach is a list that cannot be held to
# anything, which is how a consumer merged twelve PRs with no description.
. (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')

# measure-context-lib supplies the '@'-import parser check 28 resolves imports with: Get-ImportLinePath,
# Resolve-ImportPath and Test-IsFenceLine. Reused rather than restated so the gate and
# scripts/maintenance/measure-always-on.ps1 cannot drift on what an import means or where it resolves from
# -- the three rules are subtle enough that two implementations would eventually disagree, and the one that
# matters resolves relative to the IMPORTING FILE rather than to the repo root. It sets no strict mode of
# its own, like every lib in that directory, so it cannot loosen this script's Set-StrictMode.
. (Join-Path $PSScriptRoot '..\lib\measure-context-lib.ps1')

# -SkipCheck, resolved once here so every wrapped block asks the same question. The list of skippable
# names is written out rather than derived from the Write-Coverage calls: deriving it would accept any
# category the file happens to mention, including one in a comment, and the whole point of validating is
# that a name nobody implemented must not pass silently. Only the three the suite needs are skippable --
# adding a fourth is a deliberate act, and the narrower the list the smaller the surface for a check to
# be switched off by accident.
$script:SkippableChecks = @('agent-def', 'parse', 'branch-template')
$script:SkippedChecks   = @()
# SPLIT ON COMMAS AS WELL AS ON ARGUMENT BOUNDARIES, because the only caller invokes this script through
# 'powershell -File', and -File does no PowerShell parsing of its arguments: '-SkipCheck a,b,c' arrives as
# the single literal string 'a,b,c'. Without the split that lands on the unknown-name refusal below --
# which is at least loud, but it would refuse the exact form the docstring's own example uses.
foreach ($s in (@($SkipCheck) -split ',')) {
    if ([string]::IsNullOrWhiteSpace($s)) { continue }
    $name = $s.Trim()
    if ($script:SkippableChecks -notcontains $name) {
        Write-Host "check-plugin-integrity: -SkipCheck '$name' is not a skippable check. Known: $($script:SkippableChecks -join ', ')." -ForegroundColor Red
        exit 2
    }
    $script:SkippedChecks += $name
}
function Test-CheckEnabled([string]$Name) { return ($script:SkippedChecks -notcontains $Name) }

# ADDING A DOT-SOURCE HERE MEANS ADDING IT TO TWO TEST FIXTURES TOO -- check-plugin-integrity-fixture.ps1
# (the one the four check-plugin-integrity-*.tests.ps1 suites share) and workflow-exclusivity.tests.ps1
# both COPY this script into a temp tree and run it for real. A lib
# they do not copy does not make one check misbehave: the script dies at this line, so every check after
# it silently never runs. Measured on the day check 24 landed -- the exclusivity suite reported four
# failures in check 23, a check that change had not touched. Still TWO fixtures after the split, not five:
# the four suites build theirs from that one shared function.

function Test-JsonFile {
    param([string]$Path)
    try {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        return ($raw | ConvertFrom-Json)
    } catch {
        Add-Error "[JSON] $($Path.Replace($RepoRoot, '.')) is not valid JSON: $($_.Exception.Message)"
        return $null
    }
}

Write-Host "== check-plugin-integrity -- $RepoRoot ==" -ForegroundColor Cyan

# THE ONE FINDING THAT EXPLAINS EVERY OTHER ONE, so it is the FIRST ERROR REPORTED -- deliberately
# placed before check 1. Errors are buffered and printed as a block at the END of the run, in the order
# they were added, so being added ahead of check 1 is precisely what puts this above the findings it
# explains; it is not the first thing on screen, since the [COVERAGE] lines print as each check runs.
# not given a '# --- N.' header of its own (issue #1673, September 8, 2026), for the same reason
# $publishedPlugins below has none: it is infrastructure that every walking check needs to be told about
# rather than a numbered check of its own, and check 34 holds every such header to strict ascending order
# across every script in the repo, which a header placed here, ahead of check 1, could never satisfy.
#
# THE HARNESS PLACES ITS OWN WORKTREE INSIDE THE REPO, at .claude/worktrees/agent-<id>, and nothing
# ignores that path -- see .gitignore's own entry for why it cannot be closed there either. Every check
# below that walks $RepoRoot -Recurse with Get-ChildItem then sees a SECOND, complete copy of the tree it
# is standing inside. Measured (issue #1673) with a probe worktree standing: plugin.json 6->12,
# *-agent.md 26->52, SKILL.md 27->54, *.ps1 236->472 -- and the specialist check (6) then reported 26
# duplicate-id findings, every one of them accusing the REAL file and naming the WORKTREE'S COPY as the
# claimant. An operator reading THAT has no way back to the actual cause, which is what this finding is
# for: read this one first, and the duplicate-id findings further down are a CONSEQUENCE of it, not real.
#
# NOT AT A DIRTY-TREE REFUSAL, DELIBERATELY. Once the .gitignore entry landed alongside this, a nested
# worktree no longer makes `git status` report anything at all, so naming it at a dirty-tree refusal would
# buy nothing -- the place it still bites is exactly this walk, which is where this finding is.
#
# GUARDED ON '.git' EXISTING, the same technique checks 14 and 21 use for their own git-dependent reads.
# The fixture the four check-plugin-integrity-*.tests.ps1 suites share is a plain directory with no
# '.git', and asking a non-repository about its worktrees is a question with no meaning -- so the guard
# is what keeps a pointless `git` invocation, and the stderr it would produce, out of every one of those
# runs.
#
# WHAT THE GUARD DOES NOT DO, stated because the first draft of this comment claimed it did: it is NOT
# what keeps those fixtures from having to copy native-capture-lib.ps1 and worktree-lib.ps1 into their
# copy lists. $ErrorActionPreference = 'Stop' is set script-wide at the top of this file, so a missing
# dot-source is a TERMINATING error -- which the catch below would swallow with or without this guard.
# The copy lists are safe either way; the guard's job is the wasted call, not the crash.
if (Test-Path -LiteralPath (Join-Path $RepoRoot '.git')) {
    try {
        . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
        . (Join-Path $PSScriptRoot '..\lib\worktree-lib.ps1')
        $nwWtList = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'list', '--porcelain')
        if ($nwWtList.ExitCode -eq 0) {
            foreach ($nestedPath in (Get-NestedWorktreePath -PorcelainLines $nwWtList.Output -PrimaryRoot $RepoRoot)) {
                # THE PATH IS EXTERNALLY-AUTHORED TEXT, AND IT APPEARS TWICE IN ONE FINDING (issues #1637
                # and #1638, whose answer this reuses rather than re-deriving) -- once as the location and
                # once inside a remedy the reader is invited to copy and run. `git worktree add` is NOT
                # held to check-ref-format the way a branch name is, so the string it registers may carry
                # spaces, shell metacharacters, and the \p{Cf} runs that make a printed line read as
                # something other than what it says. Judged ONCE and answered as a pair, exactly as
                # sync-main.ps1 answers this same shape: both halves carry the real path or both read
                # '<path>', never one of each. Quoting is NOT the guard and must not be mistaken for one --
                # ref-print-lib is explicit that command substitution runs inside double quotes in bash and
                # in PowerShell alike, so a quoted hostile value closes nothing while reading as protection.
                #
                # THE LOCATION IS PROSE AND SO TAKES THE OTHER FUNCTION. Get-DisplayPath, not Get-DisplayRef:
                # a path may legitimately contain a space, a doubled one included, so the collapse-and-trim
                # that is safe for a ref name would report a path that is not the path (#1638).
                $nwPaste = Get-PasteableRef -Ref $nestedPath -Placeholder '<path>' -Kind Path
                $nwNote  = if ($nwPaste.Note) { ' ' + $nwPaste.Note } else { '' }
                Add-Error ("[nested-worktree] a worktree is standing INSIDE this repo, at " +
                    "'$(Get-DisplayPath $nestedPath)'." +
                    " Every check below that walks the tree with Get-ChildItem -Recurse is therefore" +
                    " seeing a SECOND, complete copy of it -- every count doubles, and any" +
                    " '[specialist] duplicate id' finding further down is a CONSEQUENCE of that rather" +
                    " than a real duplicate: it accuses the real file and names THIS worktree's copy as" +
                    " the claimant. Remove it ('git worktree remove $($nwPaste.Token)') before trusting" +
                    " anything else this gate reports." + $nwNote)
            }
        }
        # AN UNSUCCESSFUL 'git worktree list' DEGRADES QUIETLY, exactly like Get-RepoPluginRoots below:
        # git being unavailable or the call failing says something about the environment, not about a
        # worktree standing, and a lint gate must not manufacture a finding out of a question it could
        # not actually ask.
    } catch { }
}

# --- 1. marketplace.json + the plugins it references ------------------------------------------------
$marketplacePath = Join-Path $RepoRoot '.claude-plugin\marketplace.json'
if (-not (Test-Path -LiteralPath $marketplacePath)) {
    Add-Error "[marketplace] .claude-plugin/marketplace.json is missing."
} else {
    $mp = Test-JsonFile -Path $marketplacePath
    if ($mp) {
        if (-not ($mp.PSObject.Properties.Name -contains 'plugins') -or -not $mp.plugins) {
            Add-Error "[marketplace] marketplace.json has no 'plugins' list."
        } else {
            # Containment (Sean's advice): a source that points outside the repo via an absolute
            # or ..-path is always wrong -- what is registered here gets published.
            #
            # A SECOND IMPLEMENTATION OF ONE SECURITY-RELEVANT RULE, DELIBERATELY, and the pointer had
            # gone stale: it named Get-PluginManifestPaths in release-lib.ps1, which since August 9,
            # 2026 holds none of this logic -- it delegates to Get-PluginRoots in plugin-tree-lib.ps1.
            # That is the copy to keep this in step with.
            #
            # WHY THIS ONE IS NOT SIMPLY A CALL TO IT. Get-PluginRoots THROWS on the first bad source,
            # because its callers write to the paths it returns and must not proceed. A lint reports
            # every finding it can and then exits non-zero, so it has to keep walking after the first
            # -- and it names a different thing per plugin (outside the repo / folder missing / no
            # manifest), where the lib has one job and one error. Two shapes of the same rule, and the
            # reason is worth stating so the next reader does not "simplify" the gate into stopping at
            # its first finding.
            $rootPrefix = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + '\'
            foreach ($p in $mp.plugins) {
                $src = $p.source
                if (-not $src) { Add-Error "[marketplace] plugin '$($p.name)' is missing a 'source'."; continue }
                $pluginDir = (Join-Path $RepoRoot ($src -replace '/', '\')).TrimEnd('\')
                $resolvedDir = $null
                try { $resolvedDir = [System.IO.Path]::GetFullPath($pluginDir) } catch {}
                if (-not $resolvedDir -or -not ($resolvedDir + '\').StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Add-Error "[marketplace] plugin '$($p.name)': source '$src' points outside the repo."
                } elseif (-not (Test-Path -LiteralPath $pluginDir -PathType Container)) {
                    Add-Error "[marketplace] plugin '$($p.name)': source folder '$src' does not exist."
                } elseif (-not (Test-Path -LiteralPath (Join-Path $pluginDir '.claude-plugin\plugin.json'))) {
                    Add-Error "[marketplace] plugin '$($p.name)': '$src' contains no .claude-plugin/plugin.json."
                }
            }
        }
    }
}

# THE PUBLISHED PLUGIN SET, for the checks below that need to know where a plugin's folder is rather
# than assuming its shape. Derived once, here, immediately after check 1 has already reported anything
# wrong with the file it comes from.
#
# SWALLOWED ON FAILURE, DELIBERATELY, and this is the one place in this script where that is right: a
# marketplace this lib refuses to parse is a finding check 1 has just added by itself, with a better
# message than a rethrow here would give. A lint reports every finding it can rather than stopping at
# the first, so the checks that need the set degrade to an empty one -- and each of those reports its
# own zero coverage through Write-Coverage, so an empty set is visible rather than silently green.
$publishedPlugins = @()
try { $publishedPlugins = @(Get-RepoPluginRoots -RepoRoot $RepoRoot) } catch { }

# --- 2. every plugin.json: valid JSON with a name ----------------------------------------------------
Get-ChildItem -Path $RepoRoot -Recurse -Filter 'plugin.json' -File |
    Where-Object { $_.FullName -match '\.claude-plugin\\plugin\.json$' } | ForEach-Object {
        $pj = Test-JsonFile -Path $_.FullName
        if ($pj -and (-not ($pj.PSObject.Properties.Name -contains 'name') -or -not $pj.name)) {
            Add-Error "[plugin] $($_.FullName.Replace($RepoRoot, '.')) is missing a non-empty 'name'."
        }
    }

# --- 3. agent-def frontmatter: name/id/group ---------------------------------------------------------
# Each of checks 3/3b/3c/4/5/7/8/9 discovers its own file set and would report NOTHING if that set came
# back empty -- a tree that moved, a renamed directory, or a bad merge would read as a clean gate. Every
# one of them therefore closes with a [COVERAGE] line (issue #221): the verdict never travels without
# the count behind it. Applied to all of them on purpose -- a partial rollout recreates exactly the
# asymmetry that let check-consumer-drift's persona section state a clean verdict over 0 comparisons.
$agentDefs = @(Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-agent.md' -File |
    Where-Object { $_.FullName -match '\\subagents\\' })
# THE GATHER ABOVE IS OUTSIDE THE SKIP, DELIBERATELY. $agentDefs is read by three later checks
# (specialist, shared, frontmatter-bom), so skipping the collection would quietly narrow THEIR scan
# instead of this one's -- a skip that changes a different check's answer is worse than no skip at all.
# Only the frontmatter validation below is what -SkipCheck agent-def turns off.
if (Test-CheckEnabled 'agent-def') {
    $agentDefs | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $rel = $_.FullName.Replace($RepoRoot, '.')
        foreach ($key in 'name', 'id', 'group') {
            if (-not [regex]::IsMatch($text, "(?m)^$key`:\s*\S")) {
                Add-Error "[agent-def] $rel is missing '$key`:' in the frontmatter."
            }
        }
    }
    Write-Coverage -Category 'agent-def' -Checked $agentDefs.Count `
        -Note $(if ($agentDefs.Count -eq 0) { 'no */subagents/*-agent.md anywhere under the repo root -- the plugin tree is not where this check looked' } else { '' })
} else {
    Write-Skip 'agent-def -- not run (-SkipCheck). Nothing is asserted about agent-def frontmatter in this run.'
}

# --- 3b. manual frontmatter: id/group + file name <group>-<id>-manual.md -----------------------------
$manuals = @(Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-manual.md' -File |
    Where-Object { $_.FullName -match '\\manuals\\' })
$manuals | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $rel = $_.FullName.Replace($RepoRoot, '.')
        foreach ($key in 'id', 'group') {
            if (-not [regex]::IsMatch($text, "(?m)^$key`:\s*\S")) {
                Add-Error "[manual] $rel is missing '$key`:' in the frontmatter."
            }
        }
        if ($_.BaseName -match '^(\d{2})-(\d{2})-manual$') {
            $fnG = $Matches[1]; $fnI = $Matches[2]
            $mI = [regex]::Match($text, '(?m)^id:\s*(\S+)\s*$')
            $mG = [regex]::Match($text, '(?m)^group:\s*(\S+)\s*$')
            if ($mI.Success -and $mI.Groups[1].Value.Trim() -ne $fnI) {
                Add-Error "[manual] $rel`: file-name id '$fnI' != frontmatter 'id: $($mI.Groups[1].Value.Trim())'."
            }
            if ($mG.Success -and $mG.Groups[1].Value.Trim() -ne $fnG) {
                Add-Error "[manual] $rel`: file-name group '$fnG' != frontmatter 'group: $($mG.Groups[1].Value.Trim())'."
            }
        } else {
            Add-Error "[manual] $rel`: file name does not follow the <group>-<id>-manual pattern."
        }
    }
Write-Coverage -Category 'manual' -Checked $manuals.Count `
    -Note $(if ($manuals.Count -eq 0) { 'no */manuals/*-manual.md found -- every specialist playbook is either missing or somewhere this check does not look' } else { '' })

# --- 3c. persona frontmatter: id/group + file name <group>-<id>-persona.md ----------------------------
# Personas (Chris/Derek/Rendall etc.) run in the MAIN LOOP, not as a subagent, so they deliberately
# have no agent def. They live in <plugin>/personas/ as a portable template that the bootstrap
# skill copies to a consumer's repo layer (.claude/extensions/<g>-<id>-extension.md). Check 6
# (agent-def<->manual link) therefore ignores them; here we validate their frontmatter + file name
# on their own (mirrors 3b).
$personas = @(Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-persona.md' -File |
    Where-Object { $_.FullName -match '\\personas\\' })
$personas | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $rel = $_.FullName.Replace($RepoRoot, '.')
        foreach ($key in 'id', 'group') {
            if (-not [regex]::IsMatch($text, "(?m)^$key`:\s*\S")) {
                Add-Error "[persona] $rel is missing '$key`:' in the frontmatter."
            }
        }
        if ($_.BaseName -match '^(\d{2})-(\d{2})-persona$') {
            $fnG = $Matches[1]; $fnI = $Matches[2]
            $mI = [regex]::Match($text, '(?m)^id:\s*(\S+)\s*$')
            $mG = [regex]::Match($text, '(?m)^group:\s*(\S+)\s*$')
            if ($mI.Success -and $mI.Groups[1].Value.Trim() -ne $fnI) {
                Add-Error "[persona] $rel`: file-name id '$fnI' != frontmatter 'id: $($mI.Groups[1].Value.Trim())'."
            }
            if ($mG.Success -and $mG.Groups[1].Value.Trim() -ne $fnG) {
                Add-Error "[persona] $rel`: file-name group '$fnG' != frontmatter 'group: $($mG.Groups[1].Value.Trim())'."
            }
        } else {
            Add-Error "[persona] $rel`: file name does not follow the <group>-<id>-persona pattern."
        }
    }
Write-Coverage -Category 'persona' -Checked $personas.Count `
    -Note $(if ($personas.Count -eq 0) { 'no */personas/*-persona.md found -- the main-loop specialists appear in no always-on listing, so nothing else would report their absence' } else { '' })

# --- 4. dead relative links + broken anchors ---------------------------------------------------------
# Scanned files: README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md, the repo lenses (the seam
# .claude/specialists/, its pre-seam and legacy locations), every <plugin>/skills/*/SKILL.md, every
# <plugin>/manuals/*-manual.md, every releases/**/*.md and the connectors README. For every relative
# link it is checked (a) that the linked file exists, and (b) if the link has a #anchor: that anchor
# exists as a heading in the target file (GitHub slug rules). External http(s)/mailto links are skipped.

function Test-FenceDelimiterLine {
    # A single source for what counts as a fenced-code-block delimiter line, so the fence syntax
    # (currently ``` -- three-plus backticks, optionally indented) only ever needs to change in ONE
    # place. Shared by Get-HeadingSlugs (below) and Get-FenceMaskedText (check 10): both need to
    # toggle "am I inside a fence" per line, and a later fence-syntax change (tildes, four
    # backticks, ...) must not risk drifting between two independent hardcoded patterns.
    param([string]$Line)
    return [bool]($Line -match '^\s*```')
}

function ConvertTo-GhSlug {
    # Converts a heading text to a GitHub anchor slug.
    param([string]$Text)
    $t = [regex]::Replace($Text, '\[([^\]]*)\]\([^)]*\)', '$1')  # [text](url) -> text
    $t = $t -replace '[`*_]', ''                                  # strip inline code/emphasis markers
    $t = $t.ToLowerInvariant()
    $t = [regex]::Replace($t, '[^\p{L}\p{N} \-]', '')             # only letter/digit/space/hyphen
    $t = $t.Trim() -replace ' ', '-'
    return $t
}

function Get-HeadingSlugs {
    # Collects the anchor slugs of all headings in a markdown file (with GitHub duplicate suffixes).
    param([string]$Path)
    $slugs = New-Object System.Collections.Generic.HashSet[string]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $slugs }
    $lines = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) -split "`r?`n"
    $counts = @{}
    $inFence = $false
    foreach ($line in $lines) {
        if (Test-FenceDelimiterLine -Line $line) { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($line -match '^#{1,6}\s+(.*)$') {
            $base = ConvertTo-GhSlug -Text $Matches[1]
            if (-not $base) { continue }
            if (-not $counts.ContainsKey($base)) { $counts[$base] = 0; $slug = $base }
            else { $counts[$base] = $counts[$base] + 1; $slug = "$base-$($counts[$base])" }
            [void]$slugs.Add($slug)
        }
    }
    return $slugs
}

function Test-IsChangelogEntryFile {
    # A changelog entry file (new-branch.ps1) opens with its own heading; permanent root docs
    # (README, CHANGELOG, CONTRIBUTING, SECURITY, ...) open with an H1. Same structural signature
    # fold-changelog-entry.ps1 keys off, and TWO levels are accepted for the same reason it accepts
    # them: an entry file lives only on a branch, so a branch opened in the flat window
    # (August 5-26, 2026) still carries the shape from then -- the entry at H2 -- and the fold promotes
    # it to the current level as it lands.
    #
    # THE LEVEL IS READ FROM THE FORMAT LIB, NOT RESTATED, and that repair is the point. This function
    # used to hardcode '^###\s' with a comment explaining that restating it was deliberate, because
    # importing meant dot-sourcing the fold script -- which would RUN a release action to answer a
    # lint question. That reasoning was sound and its conclusion went stale the moment the entry format
    # moved into entry-scaffold-lib.ps1, a pure lib this file already loads through release-lib.ps1.
    # Measured August 5, 2026: entries had been H2 since the format changed and this copy still looked
    # for H3, so the gate recognised NO entry file at all -- check 13 below silently judged nothing and
    # reported clean, and check 11 stopped excluding entry files from its scan set. Exactly the
    # duplicated-fact failure the rest of this file exists to prevent, in the helper that answers
    # "what is an entry".
    #
    # THE RANGE RUNS DOWN FROM THE CURRENT LEVEL, NOT UP -- '#{entryLevel-1,entryLevel}'. After the
    # August 26, 2026 shift the current entry level is 3, so 'entryLevel+1' resolved to an H4 no entry
    # has ever opened with while the flat-window H2 fell outside the range: fold-all and check 13 stopped
    # seeing an H2 entry file, silently (issue #1344). This matches the direction Test-BranchChangelogIsFilled
    # took on the same day.
    param([Parameter(Mandatory = $true)][string]$Path)
    $entryLevel = Get-EntryHeadingLevel
    $rx = '^#{' + ($entryLevel - 1) + ',' + $entryLevel + '}\s'
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        return ($line -match $rx)
    }
    return $false
}

$linkFiles = @()
# EVERY ROOT *.md, ENUMERATED AND NOT NAMED, AND THAT IS THE POINT. This used to be a hardcoded list
# of four root documents PLUS a glob over the family directory that held QUICKSTART.md, UNINSTALL.md and
# the family README. Both halves were the same class of bug seen twice: the family glob replaced a
# hardcoded list of two ('README.md', 'QUICKSTART.md') that had gone stale the moment UNINSTALL.md was
# written beside them and no gate saw it -- not the dead-link scan, not check 11 (printed lifecycle
# commands), not check 12 (the install-record query), all three of which derive their scan set from
# $linkFiles. A brand-new consumer-facing page, printing exactly the class of command those two checks
# exist to police, was invisible on the run that introduced it.
#
# #405 moved those three documents INTO the root, which would have left the remaining named list as the
# only rule over the exact directory the class of defect lives in -- so the root gets the glob the family
# directory had, for the same reason: a list is only ever correct until the next document is written, and
# nothing announces the omission. Non-recursive on purpose; every subdirectory is gathered by its own rule
# below and would otherwise be picked up twice.
#
# This also subsumes the root changelog ENTRY files added in #234 (see the note further down on why they
# belong here) and picks up SECURITY.md, which no rule had ever covered.
$linkFiles += @(Get-ChildItem -Path $RepoRoot -Filter '*.md' -File |
    Select-Object -ExpandProperty FullName)
# AND THE SAME GLOB OVER plugins/, FOR THE SAME REASON, because that is where those three documents now
# live. ADOPTION.md, QUICKSTART.md and UNINSTALL.md moved out of the root, and the rules below reach into
# plugins/ only for CHANGELOG.md, SKILL.md, manuals and personas -- so a document sitting directly in
# plugins/ matched NO rule and left the scan set without a word. Measured on the move: all three went dark
# at once, every one of their own outbound links unvalidated, while the run still reported clean. That is
# the omission this file's root glob exists to prevent, arriving through the other side. Non-recursive on
# purpose, exactly as above: every subdirectory is gathered by its own rule below.
#
# GUARDED BY Test-Path, unlike the root glob, because $RepoRoot always exists and plugins/ does not: a
# consumer has no plugins/ at all, and neither does a lint fixture that never creates one. Without the
# guard Get-ChildItem raises ItemNotFound there -- which is how the first version of this line broke the
# test suite in a place that had nothing to do with links.
#
# RECURSIVE SINCE AUGUST 10, 2026, AND THAT ENDS THE CLASS RATHER THAN PATCHING IT (inbound #566). This
# glob was non-recursive with the comment "every subdirectory is gathered by its own rule below" -- true of
# agent defs, skills, manuals, personas and the plugin CHANGELOGs, and false of anything else. A markdown
# file at PLUGIN level matched no rule at all, which is where a plugin's own README.md sits: the first page
# a consumer reads, its links never once validated. Measured on the day this was widened: six such files,
# five of them already in the tree (plugins\dkj-subagents\README.md, plugins\workflows\README.md -- the latter
# merged into the plugin's own page by #1467 -- both workflow
# plugin READMEs, and dkj-policy\scripts\README.md) and the sixth the portable contribution guide
# added by that same change -- a consumer-facing page whose whole purpose is to be copied, and whose dead
# links would therefore be copied with it. All six were clean, so this arrives green; the point is that
# nothing would have said otherwise.
#
# THIS IS THE THIRD TIME THE SAME OMISSION HAS BEEN WRITTEN UP in this block -- the family glob, then
# plugins/, then branch/ -- each time as "a file leaves the scan set by moving, and nothing reports that it
# has". A shape-by-shape list keeps losing that race, so plugins/ is now read whole: every markdown under it
# is payload, and payload gets its links read. The rules below that also reach in here are left exactly as
# they are, because each one covers paths OUTSIDE plugins/ too; their overlap is removed by the dedupe at
# the end of this set rather than by trimming them back.
$pluginsRootDir = Join-Path $RepoRoot 'plugins'
if (Test-Path -LiteralPath $pluginsRootDir) {
    $linkFiles += @(Get-ChildItem -Path $pluginsRootDir -Recurse -Filter '*.md' -File |
        Select-Object -ExpandProperty FullName)
}
# AND THE THIRD, ARRIVING THE SAME WAY: the workflow's own root folder. The branch files used to be root
# *.md and were therefore covered by the root glob; the branch/ split moved them one level down, and the
# workflow folder (August 14, 2026) gathered them together with the audience releases and their history
# README one level further. Same omission as the plugins/ one above and worth stating separately rather
# than merging the two comments, because these documents went dark in the same week for two unrelated
# reasons -- which is the actual lesson about this scan set: a file leaves it by MOVING, and nothing
# reports that it has.
#
# THE FOLDER IS THE SEAM'S OWN Directory, and it stopped needing a Split-Path on August 23, 2026: the branch
# document sits directly in the workflow folder now, where it used to sit in a branch/ subdirectory of it. So
# the seam answers with the folder itself, and scanning it covers the branch document, releases/ and whatever
# docs the folder gains.
$workflowDirForLinks = Join-Path $RepoRoot ((Get-BranchFilePaths).Directory -replace '/', '\')
if (Test-Path -LiteralPath $workflowDirForLinks) {
    $linkFiles += @(Get-ChildItem -Path $workflowDirForLinks -Recurse -Filter '*.md' -File |
        Select-Object -ExpandProperty FullName)
}
# The specialists handbook lives next to the lenses (at family level) -- validate its links too.
$handbook = Join-Path $RepoRoot '.claude\plugins\claude-specialists\README.md'
if (Test-Path -LiteralPath $handbook) { $linkFiles += $handbook }
# Every plugin's own CHANGELOG.md (the consumer-facing card that cut-release.ps1 updates) did not yet
# belong to the scan set -- added (#103).
# The connectors README (connectors/) did not yet belong to
# the scan set either -- added alongside CONTRIBUTING.md (#159 follow-up, spotted by Edith).
$connectorsReadme = Join-Path $RepoRoot 'connectors\README.md'
if (Test-Path -LiteralPath $connectorsReadme) { $linkFiles += $connectorsReadme }
$linkFiles += (Get-ChildItem -Path (Join-Path $RepoRoot 'plugins') -Recurse -Filter 'CHANGELOG.md' -File |
    Where-Object { $_.FullName -notmatch '\\connectors\\' } |
    Select-Object -ExpandProperty FullName)
# The repo lenses live in the seam (.claude/specialists/, the canonical location since #253), on the
# pre-seam plugin path, or on the legacy path -- scan all of them, wherever they are.
#
# THIS IS THE CATEGORY THAT DISAPPEARS ON A TEARDOWN, which is why it is counted separately from the
# scan total below. `if (Test-Path)` per directory is correct -- a consumer has one layout, not four --
# but it also means all four being absent contributes zero files and says nothing. Green, and checking
# nothing (issue #221). Right after a deliberate teardown, wrong after a bad merge or a wrong path, and
# a silent skip cannot tell those apart.
$lensLinkFiles = @()
foreach ($extDir in @(
    (Join-Path $RepoRoot '.claude\specialists\lenses'),
    (Join-Path $RepoRoot '.claude\specialists'),
    (Join-Path $RepoRoot '.claude\plugins\claude-specialists\dkj-subagents-alpha'),
    (Join-Path $RepoRoot '.claude\extensions'))) {
    if (Test-Path -LiteralPath $extDir) {
        $lensLinkFiles += (Get-ChildItem -Path $extDir -Filter '*.md' -File | Select-Object -ExpandProperty FullName)
    }
}
$linkFiles += $lensLinkFiles
$linkFiles += (Get-ChildItem -Path $RepoRoot -Recurse -Filter 'SKILL.md' -File |
    Where-Object { $_.FullName -match '\\skills\\' } | Select-Object -ExpandProperty FullName)
$linkFiles += (Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-manual.md' -File |
    Where-Object { $_.FullName -match '\\manuals\\' } | Select-Object -ExpandProperty FullName)
$linkFiles += (Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-persona.md' -File |
    Where-Object { $_.FullName -match '\\personas\\' } | Select-Object -ExpandProperty FullName)
# THE AGENT DEFS, THE SHARED BLOCKS, AND THE TWO CONFIG-ADJACENT DOC LAYERS (#481). Every category above
# names a shape of file, and four kinds of markdown matched none of them: */subagents/*.md (26 files),
# plugins/dkj-subagents/subagent-shared/*.md (11), .github/**/*.md (2) and .claude/rules/*.md (1). Agent defs are the
# glaring one -- they are the largest single body of prose this repo ships, they are payload, and their
# links had never been read by anything. Measured on the day this was added: one genuinely dead link had
# been sitting in an agent def, plus the location-dependent CLAUDE.md links repaired alongside it.
#
# Manuals and personas already have a rule each, so this is the same family finally covered in full. Each
# directory is guarded, for the reason the plugins/ glob is: a consumer has some of these and not others.
foreach ($payloadSpec in @(
    @{ Dir = 'plugins';        Recurse = $true;  Filter = '*.md'; Match = '\\subagents\\' },
    @{ Dir = 'plugins\dkj-subagents\subagent-shared'; Recurse = $false; Filter = '*.md'; Match = $null },
    @{ Dir = '.github';        Recurse = $true;  Filter = '*.md'; Match = $null },
    @{ Dir = '.claude\rules';  Recurse = $false; Filter = '*.md'; Match = $null })) {
    $payloadDir = Join-Path $RepoRoot $payloadSpec.Dir
    if (-not (Test-Path -LiteralPath $payloadDir)) { continue }
    $found = if ($payloadSpec.Recurse) {
        Get-ChildItem -Path $payloadDir -Recurse -Filter $payloadSpec.Filter -File
    } else {
        Get-ChildItem -Path $payloadDir -Filter $payloadSpec.Filter -File
    }
    if ($payloadSpec.Match) { $found = @($found | Where-Object { $_.FullName -match $payloadSpec.Match }) }
    $linkFiles += @($found | Select-Object -ExpandProperty FullName)
}
$releasesDir = Join-Path $RepoRoot 'releases'
if (Test-Path -LiteralPath $releasesDir) {
    $linkFiles += (Get-ChildItem -Path $releasesDir -Recurse -Filter '*.md' -File | Select-Object -ExpandProperty FullName)
}
# Every plugin-carried RELEASE.md card (check 9) links to the full notes and its own
# CHANGELOG.md -- those links need to be validated too.
$linkFiles += (Get-ChildItem -Path $RepoRoot -Recurse -Filter 'RELEASE.md' -File |
    Select-Object -ExpandProperty FullName)
# Root changelog ENTRY files (<branch-name>.md) are covered by the root *.md glob at the top of this
# set, no longer by a rule of their own -- but WHY they must be in it is worth keeping, because the glob
# does not say it. Added to close the window in #234: the gap was structural rather than subtle, since an
# entry file's text lives outside every scanned path while the PR is open and only enters a scanned file
# at FOLD time -- which happens directly on main, past every PR gate. So the sequence was: CI green on the
# PR (text in an unscanned file) -> the fold introduces the error on main -> nothing reviews the fold,
# because it is one of the sanctioned direct-on-main actions -> the next full gate run is
# cut-release.ps1, which refuses to release. That is how v2.13.0 was blocked by a changelog sentence.
#
# Scanning them means the PR gate sees exactly the text the fold will paste into CHANGELOG.md, so the
# error surfaces where it can still be reviewed. Their links are validated at ROOT position, which is
# correct twice over: the entry file sits in the root, and CHANGELOG.md -- where it is headed -- is in the
# root too, so a relative link that resolves here resolves there. Checks 11 and 12 exclude them again by
# name, since an entry file is history in the making (see $lifecycleFiles below).
#
# Note this covers check 10 (the skills:all spans) as well, since that check reuses this same set --
# and check 10 is precisely what #234 tripped over.

# DEDUPED ONCE, HERE, so that widening a rule above never has to be weighed against double-reporting.
# The rules in this set are deliberately overlapping: several name a SHAPE of file wherever it sits (SKILL.md,
# *-manual.md, */subagents/*.md) while others name a PLACE and take everything in it (the root, plugins/,
# branch/, releases/). Under the previous shape-by-shape arrangement the two kinds happened not to collide,
# and that coincidence was load-bearing -- the plugins/ glob carried a comment justifying non-recursion by
# it. It is not load-bearing any more: a file gathered twice is scanned twice, every finding in it reported
# twice, and the coverage line would overcount the set. First occurrence wins, so the order the rules run in
# still decides nothing.
#
# Checks 10, 11 and 12 derive their own sets from $linkFiles, so they inherit this for free.
$linkFiles = @($linkFiles | Select-Object -Unique)

Write-Coverage -Category 'link-scan' -Checked $linkFiles.Count `
    -Note $(if ($linkFiles.Count -eq 0) { 'the scan set is empty -- no dead link anywhere could be found, which is not the same as there being none' } else { '' })
Write-Coverage -Category 'link-scan/lenses' -Checked $lensLinkFiles.Count `
    -Note $(if ($lensLinkFiles.Count -eq 0) { 'no repo-lens file in the seam, its pre-seam location, or the legacy path -- expected after a deliberate teardown, otherwise the lens tree has moved or been lost' } else { '' })

# WHERE THIS REPO'S CHANGELOG ACTUALLY LIVES, resolved once for the four checks that need to name it: the
# entry's LINK BASE in check 4 just below, the lifecycle-command exclusion (check 11), the entry-heading
# pass (check 13) and the shape-claim pass (check 20). All of them said the literal 'CHANGELOG.md' until
# August 27, 2026, when the file moved into contributing-davekjohn/ and this repo answered
# Get-ChangelogPath to say so. A gate that keeps naming the old path does not fail loudly -- it silently
# judges a file that is not there, which is the quietest way for a check to stop checking.
#
# IT IS RESOLVED HERE, ABOVE THE LINK SCAN, RATHER THAN 500 LINES DOWN WHERE IT USED TO SIT (issue #1041).
# Check 4 needs it to answer where an entry's links resolve from, and check 4 runs first -- so the value
# has to exist before the loop rather than in front of its first other consumer.
#
# DOT-SOURCED IN A SCRIPTBLOCK, the idiom check 16 established and for its reason: repo-config is not
# loaded in this process anywhere else, and pulling two dozen repo functions into the whole lint to serve
# four checks is how a gate acquires a dependency nobody meant to give it.
#
# READ THE SAME WAY THE FOLD READS IT -- Get-SeamValue over Get-DefaultChangelogPath -- rather than with a
# literal fallback of its own. A gate whose idea of "the changelog" can differ from the fold's is a gate
# that passes a document nobody writes and never sees the one that is written.
#
# THIS ADDS seam-lib.ps1 TO THE GATE'S DEPENDENCIES, which the lint fixture has to copy alongside the
# other libs. That is stated here because the failure is loud but misleading: the dot-source fails inside
# the fixture's own copy of this script, the gate dies before check 4, and four suites report several
# dozen unrelated scenarios as broken -- the same shape the fixture's marketplace list has twice paid for.
$changelogRel = & {
    $clCfg = Join-Path $RepoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $clCfg) { . $clCfg }
    . (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
    Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $RepoRoot)
}
$changelogRelWin = $changelogRel -replace '/', '\'
$changelogFull   = Join-Path $RepoRoot $changelogRelWin
# AND THE DIRECTORY IT SITS IN, which is the base an entry's relative links are judged from -- the same
# value open-pr's link gate computes for Get-EntryLinkFindings, by the same Split-Path. No fallback for a
# changelog at the ROOT: $RepoRoot is absolute (Resolve-Path, above), so the parent of a file directly in
# it IS $RepoRoot, which is exactly the answer that case wants.
$changelogDirForLinks = Split-Path -Parent $changelogFull

$linkRegex = [regex]'\[(?:[^\]]*)\]\(([^)]+)\)'
$slugCache = @{}
foreach ($lf in $linkFiles) {
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    # Exclude code: fenced (```...```) and inline (`...`). Link-like text inside code is
    # illustration, not a real link -- otherwise e.g. a `[..](#anchor)` example would get validated.
    $scan = [regex]::Replace($content, '(?s)```.*?```', '')
    $scan = [regex]::Replace($scan, '`[^`]*`', '')
    # HTML comments too, for the same reason as code: nothing in one is a rendered link. This became a
    # real finding the moment the entry format grew guidance comments -- one of them shows the closing
    # line the fold writes, '[PR #NN](url) - merged <date>', and the scanner reported 'url' as dead.
    # Illustrating a link is not publishing one.
    $scan = [regex]::Replace($scan, '(?s)<!--.*?-->', '')
    # Persona templates are destined for .claude/extensions/ of a consuming repo; their relative
    # links need to resolve THERE, not at the source location in the plugin. So validate them as if
    # the file were already at that destination (this repo mirrors the consumer layout).
    #
    # THE BRANCH DOCUMENT IS THE SECOND CASE OF THE SAME RULE (August 6, 2026). Its DEPLOY section is
    # pasted verbatim into the changelog, so its links have to resolve WHERE THE FOLD WRITES -- and until
    # the branch/ split they did by construction, because the entry file itself sat beside the changelog in
    # the root. Moving it one level down turned every link in an entry into a dead one: measured on the
    # first entry written after the move, with five more of the same shape already pending. Validating it
    # where the file sits would force authors to write '../' links that break the moment they land.
    #
    # THE BASE IS THE CHANGELOG'S OWN DIRECTORY, NOT $RepoRoot (issue #1041, August 28, 2026), and that is
    # the whole of this repair. It was the repo root while the changelog was, and CHANGELOG.md moved into
    # contributing-davekjohn/ on August 27 -- so the special case went on demanding the root form that the
    # fold then breaks. Measured: a DEPLOY link written as '../plugins/...' -- correct for BOTH
    # the branch's development document and the changelog, which now sit in one directory -- was refused as dead, and the form
    # this check accepted resolved from dkj-policy/ after the fold and was dead there. Precisely
    # the failure the paragraph above says this case exists to prevent, running backwards.
    #
    # THE SPECIAL CASE SURVIVES THE REPAIR RATHER THAN BEING DROPPED, which is the part that is not
    # obvious: for TODAY'S name the base now equals the file's own directory, so this branch and the
    # fall-through agree and it looks like dead weight. The LEGACY names do not agree -- they sit in
    # dkj-policy/branch/, one level BELOW the changelog -- and a branch open since before the
    # August 23 merge still carries one. Dropping the case would judge those where they sit, which is the
    # original defect at a smaller radius.
    #
    # READ FROM THE SEAM, not from a literal, for the reason the resolution block above the loop gives:
    # this is the same value the fold and open-pr's link gate resolve, so the three cannot disagree about
    # where an entry's text lands.
    #
    # THE STEP LIST IS DELIBERATELY NOT INCLUDED, though it sits in the same directory. It never travels:
    # it is read where it lies and reset in place, so 'where the file sits' IS its destination, and the
    # ordinary '../' convention every other nested document here follows is the correct one for it.
    # EVERY NAME, because a branch created before the merge still carries the pair and their links resolve
    # from the same place -- see Resolve-BranchFilePath.
    #
    # AND IT IS THE WHOLE DOCUMENT, NOT ONLY ITS DEPLOY SECTION (August 23, 2026). Strictly, the entry's text
    # is what folds; the plan above it stays where it is. One rule for one file is the honest simplification:
    # the head is guidance comments and phase headings, which carry no links at all in the scaffold, and an
    # author who does write one in a step means the same path the section below asks for. Two bases inside
    # one document would be a rule nobody could apply while writing.
    $entryRelsForLinks = @((Get-BranchFilePaths).File, (Get-BranchFilePaths).LegacyDeployment,
        (Get-BranchFilePaths).OlderDeployment) |
        ForEach-Object { '\' + ($_ -replace '/', '\') }
    if ($lf -match '\\personas\\.*-persona\.md$') {
        $dir = Join-Path $RepoRoot '.claude\extensions'
    # AND THE PER-BRANCH NAMES BY PATTERN (#1255), because a list cannot enumerate them. Same answer as the
    # fixed names above -- these documents sit in the same folder as CHANGELOG.md, so their links resolve
    # from the same base.
    } elseif (@($entryRelsForLinks | Where-Object { $lf.EndsWith($_) }).Count -gt 0 -or
        (Test-IsPerBranchDocumentPath -RelativePath ($lf.Substring($RepoRoot.Length)))) {
        $dir = $changelogDirForLinks
    } else {
        $dir = Split-Path -Parent $lf
    }
    $rel = $lf.Replace($RepoRoot, '.')
    foreach ($m in $linkRegex.Matches($scan)) {
        $target = $m.Groups[1].Value.Trim()
        if ($target -match '^(https?:|mailto:)') { continue }

        $parts = $target -split '#', 2
        $pathPart = $parts[0]
        $anchor = if ($parts.Count -gt 1) { $parts[1] } else { $null }

        # Determine target file: empty pathPart = this same file (pure #anchor).
        if (-not $pathPart) {
            $targetFile = $lf
        } else {
            $resolved = Join-Path $dir ($pathPart -replace '/', '\')
            if (-not (Test-Path -LiteralPath $resolved)) {
                # Where the resolution base is NOT the file's own directory (the two cases above),
                # say so in the finding. Without it the message reads as "this path is wrong" while
                # the path is correct for where the file sits -- and the author's next move is to add
                # a '../' that breaks the moment the text lands at its destination. Measured on
                # August 19, 2026: three suites failed on one entry, and the message named neither
                # the base it used nor why.
                $baseNote = if ($dir -eq (Split-Path -Parent $lf)) { '' } else {
                    " This file's links resolve from '$($dir.Replace($RepoRoot, '.'))' rather than from where it sits, because its text lands there."
                }
                Add-Error "[link] $rel -> dead link '$target' (expected file does not exist).$baseNote"
                continue
            }
            $targetFile = $resolved
        }

        # Anchor validation: only meaningful for an existing .md target file.
        if ($anchor -and $targetFile -match '\.md$' -and (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
            $full = (Resolve-Path -LiteralPath $targetFile).Path
            if (-not $slugCache.ContainsKey($full)) { $slugCache[$full] = Get-HeadingSlugs -Path $full }
            if (-not $slugCache[$full].Contains($anchor)) {
                Add-Error "[anchor] $rel -> '$target' (anchor '#$anchor' does not exist as a heading in the target file)."
            }
        }
    }
}

# --- 5. PowerShell scripts must parse -----------------------------------------------------------------
# Catches syntax errors before they land on main. The pure logic of a script can be tested
# separately, but a parse error in the orchestration itself would only break at execution time --
# this check pulls that forward, to the PR gate. Scanned: scripts/**/*.ps1 AND everything a plugin
# carries -- <plugin>/skills/**/*.ps1 (e.g. specialists-init's bootstrap), <plugin>/scripts/**/*.ps1
# (the shared SSOT home, issue #81) and, since August 23, 2026, <plugin>/hooks/**/*.ps1. Made unique so
# a path that hits two filters is not parsed twice.
#
# The plugin-scripts half is anchored on the plugins root rather than matched as a path segment (#405).
# 'plugins' is not a distinctive name: it is also the leaf of .claude/plugins/, so a segment match would
# widen this check to anything a consumer's plugin layer happens to carry. The old segment name
# ('claude-code-plugins') was unique enough to get away with it; this one is not.
# THE SET IS GATHERED ONCE AND CACHED, and it stopped being check 5's private business on
# August 23, 2026. Until then the gather sat inside the skip below, on the sound reasoning that
# $psScripts was read by nothing afterwards. Check 27 now reads the same set for a different property
# of the same files, so there are two callers -- and two checks over one set must not each decide for
# themselves what the set IS, which is the second-definition drift this gate exists to catch elsewhere.
#
# CACHED RATHER THAN CALLED TWICE, because the second glob is a -Recurse over the whole repo root. Two
# walks would double the most expensive part of the cheapest check, and the lazy field keeps the
# original saving intact: with both checks off, the walk never happens at all.
#
# THE HOOKS WERE MISSING FROM IT, and that was measured on the same day rather than reasoned about: 158
# .ps1 files are tracked here and this set held 151, the seven absentees being every plugin-carried
# plugins/<kind>/<plugin>/hooks/*.ps1. So a parse error in a SessionStart hook -- the five that speak on
# every session start in this repo among them -- was not seen by this gate at all, and a hook that does
# not parse does not announce itself: the harness reports the failure and the session continues without
# whatever the hook was there to say. They are named in .claude/rules/language-layers.md as part of the
# script layer for exactly that reason, so check 27 below could not have been pointed at that layer while
# they were out. Widening it fixes both checks at once, which is the argument for one set over two.
$script:PsScriptFileCache = $null
function Get-PsScriptFiles {
    if ($null -ne $script:PsScriptFileCache) { return $script:PsScriptFileCache }
    $pluginsRoot = Join-Path $RepoRoot 'plugins'
    $found = @()
    # THE Test-Path IS NEW WITH THE SECOND CALLER, and it is not decoration. Under
    # $ErrorActionPreference = 'Stop' a Get-ChildItem on a missing directory ENDS THE RUN, and while this
    # gather sat inside check 5's skip that could only happen in a tree where 'parse' was enabled. Check
    # 27 reads the same set unconditionally, so without this line a tree with no scripts/ directory would
    # take the whole gate down instead of reporting a coverage of zero -- and a gate that dies is worse
    # than one reporting zero, which is the argument check 8's guarded read already rests on.
    $scriptsDir = Join-Path $RepoRoot 'scripts'
    if (Test-Path -LiteralPath $scriptsDir -PathType Container) {
        $found += (Get-ChildItem -Path $scriptsDir -Recurse -Filter '*.ps1' -File)
    }
    $found += (Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.ps1' -File |
        Where-Object {
            $_.FullName -match '\\skills\\' -or
            ($_.FullName.StartsWith($pluginsRoot + '\') -and
                ($_.FullName -match '\\scripts\\' -or $_.FullName -match '\\hooks\\'))
        })
    $script:PsScriptFileCache = @($found | Sort-Object -Property FullName -Unique)
    return $script:PsScriptFileCache
}

# THE CommandAst SET PER SCRIPT FILE, PARSED AND WALKED ONCE -- issue #1358. Two non-skippable checks
# want exactly this list over exactly the set above: check 33 (barred-skill) reads the strings printed by
# a writer cmdlet, and shopify-cli looks for a command named 'shopify'. Each used to call ParseFile and
# then FindAll(CommandAst) itself, so every run paid for the same parse and the same full-tree walk twice.
#
# MEASURED, September 3, 2026, over this repo's own 184-file script set: one parse+walk pass is 1.41s, of
# which the WALK is 1.16s and the parse only 0.26s -- so the duplicate that mattered was the walk, not the
# parse the two comments both talked about. A second pass off this cache is 0.014s. Inside the fixture the
# gate's own suites build, the two checks were 216ms and 174ms of a 1315ms invocation; sharing the pass
# removes ~174ms of it, and those suites run this script 168 times.
#
# IT RETAINS THE ASTs, WHICH IS THE COST AND IT IS STATED RATHER THAN DISCOVERED: 25,476 CommandAst nodes
# over that set hold ~72MB of heap and ~100MB of working set. That is affordable on a hosted runner and
# trivial in the fixture (12 files), but it is the reason this caches the CommandAst LIST rather than the
# whole AST per file -- the nodes are reachable from it either way, and a narrower promise is easier to
# keep. If it ever needs to be memory-bounded, the answer is to run both checks in ONE pass over the file
# set rather than to cache: the two loops are independent per file and neither needs a second look.
#
# CHECK 5 ('parse') DELIBERATELY DOES NOT USE THIS, and the reason is the one its own comment gives from
# the other direction: it is the only skippable one of the three, and it needs the PARSE ERRORS this
# accessor throws away. So it keeps its own pass, which is what lets these two run when 'parse' is
# skipped -- the property the barred-skill comment already relied on, now stated where the sharing is.
#
# An unparseable file yields an EMPTY list, not $null. Both callers counted such a file as covered and
# then skipped it, so an empty list preserves their coverage numbers exactly.
$script:PsScriptCommandAstCache = @{}
function Get-EnclosingFunction {
    <#
        The FunctionDefinitionAst a node sits inside, or $null at file scope. Used to keep a
        variable-read search inside the scope the assignment it clears actually lives in: PowerShell
        scopes by runtime lookup rather than lexically, so two functions may hold the same name for
        unrelated values, and a name match across them clears a dead assignment. Identity comparison of
        the returned node is what the caller wants -- two nodes are in the same scope when this returns
        the same object (or $null for both).
    #>
    param([Parameter(Mandatory)]$Node)
    $walk = $Node
    while ($walk) {
        if ($walk -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $walk }
        $walk = $walk.Parent
    }
    return $null
}

function Get-DiscardedOuterPipeline {
    <#
        The outermost pipeline a call ultimately sits in, and whether its result is DISCARDED.

        ONE FUNCTION RATHER THAN A COPY PER CHECK (issue #1956). Checks 35 and 41 each grew their own
        implementation of the same two rules -- climb out of any wrapping, then ask whether the result is
        thrown away -- and check 41's own comment said so in as many words. The unwrap rule has already
        had to be repaired ONCE: check 35 was first written with only its [void] arm walking out of
        '(...)', so '$null = (& git ...)' and '(& git ...) | Out-Null' were both silently skipped, and its
        header draws the lesson that a check whose three arms disagree about wrapping teaches the shape that
        gets past it. With two copies that lesson applies one level up -- the next repair has to be made
        twice, and the copy that misses it fails exactly the way the original bug did.

        AND THE SECOND COPY HAD ALREADY DRIFTED, which is what makes this an extraction rather than a
        tidy-up. Check 41 climbed THROUGH a ConvertExpressionAst without noticing a [void] cast, so a
        '[void](Write-FixtureScriptSummary ...)' standing as a function's LAST statement fell into the
        implicit-return arm and was cleared as a READ -- while [void] is precisely what stops it being
        one. Measured September 13, 2026 against the real check: as a last statement 0 findings, one line
        further up 1 finding. The same call, the same cast, two answers.

        WHAT COUNTS AS A DISCARD is the three spellings both checks already meant to cover: an 'Out-Null'
        tail, a '$null =' assignment, and a '[void]' cast -- each judged AFTER the climb, on the same
        node, so a pair of brackets is not an escape hatch for any of them.

        Returns an object with:
          * Outer     -- the outermost pipeline/expression the call sits in, which is the node a caller
                         then walks up from to find the enclosing statement.
          * Discarded -- $true when the result is thrown away in any of the three spellings.

        DELIBERATELY NOT A THIRD FIELD SAYING WHICH SPELLING IT WAS. The first draft returned the [void]
        flag as well and nothing read it: neither finding names the spelling, because what a reader has to
        repair is the same in all three. A field kept for a caller nobody has is surface this gate then
        has to keep true. Add it on the day a finding wants to say it.

        Takes the CommandAst's own parent pipeline; returns $null when the call does not sit in a
        pipeline at all, which both callers treat as 'not a subject'.
    #>
    param([Parameter(Mandatory)]$Call)

    $pipe = $Call.Parent
    if ($pipe -isnot [System.Management.Automation.Language.PipelineAst]) { return $null }

    # Parentheses, a cast, and the CommandExpression/Pipeline pair a wrapped call is re-wrapped in are
    # all climbed, so every spelling below is judged on the SAME node.
    $outer    = $pipe
    $voidCast = $false
    while ($outer.Parent) {
        $up = $outer.Parent
        if ($up -is [System.Management.Automation.Language.ConvertExpressionAst]) {
            if ($up.Type.TypeName.Name -match '^(void|System\.Void)$') { $voidCast = $true }
            $outer = $up; continue
        }
        if ($up -is [System.Management.Automation.Language.ParenExpressionAst] -or
            $up -is [System.Management.Automation.Language.CommandExpressionAst] -or
            $up -is [System.Management.Automation.Language.PipelineAst]) { $outer = $up; continue }
        break
    }

    $discarded = $voidCast
    if ($outer -is [System.Management.Automation.Language.PipelineAst]) {
        $last = $outer.PipelineElements[$outer.PipelineElements.Count - 1]
        if ($last -is [System.Management.Automation.Language.CommandAst] -and
            $last.GetCommandName() -eq 'Out-Null') { $discarded = $true }
    }
    $assign = $outer.Parent
    if ($assign -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $assign.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $assign.Left.VariablePath.UserPath -eq 'null') { $discarded = $true }

    return [pscustomobject]@{
        Outer     = $outer
        Discarded = $discarded
    }
}

function Get-PsScriptCommandAsts {
    param([Parameter(Mandatory)][string]$Path)
    if ($script:PsScriptCommandAstCache.ContainsKey($Path)) { return $script:PsScriptCommandAstCache[$Path] }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $cmds = if ($null -eq $ast) {
        @()
    } else {
        @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))
    }
    $script:PsScriptCommandAstCache[$Path] = $cmds
    return $cmds
}

$psScripts = @()
if (Test-CheckEnabled 'parse') {
    $psScripts = @(Get-PsScriptFiles)
    $psScripts | ForEach-Object {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors -and $parseErrors.Count -gt 0) {
            $rel = $_.FullName.Replace($RepoRoot, '.')
            Add-Error "[parse] $rel`: $($parseErrors[0].Message)"
        }
    }
    Write-Coverage -Category 'parse' -Checked $psScripts.Count `
        -Note $(if ($psScripts.Count -eq 0) { 'no .ps1 found under scripts/ or in any plugin -- a syntax error anywhere could not have been seen' } else { '' })
} else {
    Write-Skip 'parse -- not run (-SkipCheck). Nothing is asserted about PowerShell syntax in this run.'
}

# --- 6. specialists-system integrity -------------------------------------------------------------------
# This repo is the source of the specialists system, so the agent-def<->manual link must be at
# least as strict here as for a consumer. Per plugin (folder with subagents/ and manuals/):
#   6a. every '<group>-<id>' is unique across all agent defs; every agent def has a valid 'name:'
#       (Claude Code call name), a corresponding manuals/<g>-<id>-manual.md in the same plugin, and
#       names that manual in its text.
#   6b. no orphan manual: every manuals/<g>-<id>-manual.md is backed by a subagents/<g>-<id>-agent.md
#       OR a personas/<g>-<id>-persona.md. A PERSONA MAY BACK A MANUAL (#1017). Being a persona says
#       where a specialist RUNS -- in the main loop rather than as a subagent -- and says nothing
#       about whether their craft has a playbook worth reading on demand. Until this changed it said
#       both, and the orchestrator paid for it: always loaded, and the one specialist whose every rule
#       had to sit on the always-on path, because the gate refused him the on-demand half the other
#       fifteen have. Where a persona backs a manual it must NAME it, for the same reason 6a makes an
#       agent def name its own -- nothing else would ever read it. A persona with no manual is the
#       normal case and is asserted about in neither direction.
# (The roster->lens link is already covered by the dead-link scan above, since that scans CLAUDE.md.)

$idOwner = @{}
$agentDefs | ForEach-Object {
        $rel = $_.FullName.Replace($RepoRoot, '.')
        if ($_.BaseName -notmatch '^(\d{2})-(\d{2})-agent$') {
            Add-Error "[specialist] $rel does not follow the <group>-<id>-agent.md pattern."
            return
        }
        $g = $Matches[1]; $id = $Matches[2]; $key = "$g-$id"
        if ($idOwner.ContainsKey($key)) {
            Add-Error "[specialist] ${rel}: duplicate id '$key' (already claimed by $($idOwner[$key]))."
        } else {
            $idOwner[$key] = $rel
        }

        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $nm = [regex]::Match($text, '(?m)^name:\s*(\S+)\s*$')
        if ($nm.Success -and ($nm.Groups[1].Value.Trim() -notmatch '^[a-z0-9-]+$')) {
            Add-Error "[specialist] ${rel}: 'name: $($nm.Groups[1].Value.Trim())' must consist of lowercase letters/digits/hyphens (Claude Code call name)."
        }

        $pluginRoot = Split-Path (Split-Path $_.FullName -Parent) -Parent
        $manualBase = "$g-$id-manual"
        $manualPath = Join-Path $pluginRoot ("manuals\$manualBase.md")
        if (-not (Test-Path -LiteralPath $manualPath -PathType Leaf)) {
            Add-Error "[specialist] ${rel}: corresponding manual 'manuals/$manualBase.md' is missing in the same plugin."
        } elseif ($text -notmatch [regex]::Escape("manuals/$manualBase.md")) {
            Add-Error "[specialist] ${rel}: agent def does not name its manual 'manuals/$manualBase.md'."
        }
    }

$manuals | ForEach-Object {
        if ($_.BaseName -match '^(\d{2})-(\d{2})-manual$') {
            $g = $Matches[1]; $id = $Matches[2]
            $pluginRoot = Split-Path (Split-Path $_.FullName -Parent) -Parent
            $agentPath   = Join-Path $pluginRoot ("subagents\$g-$id-agent.md")
            $personaPath = Join-Path $pluginRoot ("personas\$g-$id-persona.md")
            $hasAgent   = Test-Path -LiteralPath $agentPath   -PathType Leaf
            $hasPersona = Test-Path -LiteralPath $personaPath -PathType Leaf
            if (-not $hasAgent -and -not $hasPersona) {
                $rel = $_.FullName.Replace($RepoRoot, '.')
                Add-Error "[specialist] ${rel}: orphan manual -- no corresponding subagents/$g-$id-agent.md or personas/$g-$id-persona.md in the same plugin."
            } elseif (-not $hasAgent) {
                # Persona-backed. The naming half of 6a applies here for the same reason it does there:
                # the manual is only ever read because the body that IS loaded points at it.
                $pText = [System.IO.File]::ReadAllText($personaPath, [System.Text.Encoding]::UTF8)
                if ($pText -notmatch [regex]::Escape("manuals/$g-$id-manual.md")) {
                    $pRel = $personaPath.Replace($RepoRoot, '.')
                    Add-Error "[specialist] ${pRel}: persona backs 'manuals/$g-$id-manual.md' but does not name it, so nothing would ever read it."
                }
            }
        }
    }
Write-Coverage -Category 'specialist' -Checked ($agentDefs.Count + $manuals.Count) `
    -Note $(if (($agentDefs.Count + $manuals.Count) -eq 0) { 'neither an agent def nor a manual was found -- the agent-def/manual coupling could not be checked in either direction' } else { '' })

# --- 7. shared agent-def blocks in sync with their source ---------------------------------------------
# Verbatim-shared bullets (e.g. the inbound rule, 19/19) are maintained in ONE place in
# subagent-shared/<name>.md and filled into the agent defs between <!-- BEGIN/END shared:NAME -->
# sentinels (built via scripts/agents/build-agent-defs.ps1). Here we guard that every marked
# region still equals its source -- this catches a hand-edit inside the sentinels or a forgotten
# rebuild.
#
# THE PERSONAS ARE HELD TO THE SAME RULE, and this check has to walk exactly what the generator writes
# or the gate goes quiet on half of them. The generator gained the personas because the two specialists
# whose craft IS a way of working ship as personas rather than agent defs; a gate that kept looking only
# at agents/ would have let a hand-edit inside a persona's sentinels stand, which is the one failure
# this check exists to prevent. Both collections are built from the same two filters as there.
. (Join-Path $PSScriptRoot '..\lib\subagent-shared-lib.ps1')
$agentSharedDir = Get-AgentSharedDir -RepoRoot $RepoRoot
# The outer @() is load-bearing, not decoration: Sort-Object returns a SCALAR for a single-element
# collection, and $scalar.Count then throws under StrictMode. The real repo has 30 of these so it would
# never have shown up here -- it surfaced in the fixtures, which are one agent def and no persona.
$sharedBlockFiles = @(@($agentDefs) + @($personas) | Sort-Object FullName)
$sharedBlockFiles | ForEach-Object {
        $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $rel = $_.FullName.Replace($RepoRoot, '.')
        $sharedProblems = New-Object System.Collections.Generic.List[string]
        $expanded = Expand-AgentDefShared -Content $raw -SharedDir $agentSharedDir -Problems $sharedProblems
        foreach ($p in $sharedProblems) { Add-Error "[shared] ${rel}: $p" }
        if ($expanded -ne ($raw -replace "`r`n", "`n")) {
            Add-Error "[shared] ${rel}: shared block deviates from the source -- run scripts/agents/build-agent-defs.ps1."
        }
    }
Write-Coverage -Category 'shared' -Checked $sharedBlockFiles.Count `
    -Note $(if ($sharedBlockFiles.Count -eq 0) { 'no agent def or persona to expand, so no shared block could be compared with its source' } else { 'agent defs AND personas -- the generator writes both, so the gate walks both. A persona is where the specialists whose craft is itself a way of working live, which is exactly where a process block must not be allowed to drift' })

# --- 8. shared workflow scripts in sync with their source ----------------------------------------------
# Repo-agnostic scripts are shared with consumers as a plugin mirror (issue #81): the root copy is
# the tested source, the plugin mirror is what a consumer runs. Here we guard that every mirror is
# still LF-identical to its source -- this catches a hand-edit in the mirror or a forgotten rebuild
# (scripts/sync/build-shared-scripts.ps1) before it lands on main via a PR.
. (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')
# THE ALREADY-RESOLVED SET IS PASSED IN, not resolved again here. The registry composes each mirror
# path from its plugin's root, so it needs the same answer this script derived at its top -- and
# deriving it a second time would do so OUTSIDE that guarded try/catch. Measured: with a
# marketplace.json that does not parse, the unguarded second read threw straight out of this line and
# ended the run, so checks 9 through 22 never reported and no Summary was printed. A gate that dies is
# worse than a gate that reports zero, because zero is visible in the coverage line below.
$sharedPairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot -PluginRoots $publishedPlugins)
foreach ($pair in $sharedPairs) {
    $src = Get-NormalizedScriptContent -Path $pair.SourcePath
    if ($null -eq $src) {
        Add-Error "[shared-script] source is missing: $($pair.SourceRel)."
        continue
    }
    $mirror = Get-NormalizedScriptContent -Path $pair.MirrorPath
    if ($null -eq $mirror) {
        Add-Error "[shared-script] mirror is missing: $($pair.MirrorRel) -- run scripts/sync/build-shared-scripts.ps1."
    } elseif ($src -ne $mirror) {
        Add-Error "[shared-script] $($pair.MirrorRel) deviates from $($pair.SourceRel) -- run scripts/sync/build-shared-scripts.ps1."
    }
}
Write-Coverage -Category 'shared-script' -Checked $sharedPairs.Count `
    -Note $(if ($sharedPairs.Count -eq 0) { 'the source/mirror pair list is empty -- a mirror could not have been found out of sync, however far it had drifted' } else { '' })

# RETIRED, AUGUST 8, 2026 -- check 9 ("RELEASE.md present per plugin + version match").
# It held each plugin's RELEASE.md card against its plugin.json version, on the reasoning that both
# only ever change together via cut-release.ps1, so a mismatch could only be a forgotten regeneration
# or a hand-edit. Correct, and now moot: the cards are gone. A plugin's version has one statement
# again -- plugin.json -- so there is no second copy for a check to compare it with.

# --- 10. marked "all skills" enumerations vs. the canonical skillset -----------------------------------
# A prose bullet list that claims to enumerate "all skills" is a maintenance trap: it silently
# drifts as skills are added/removed, and a generic prose scan over-detects (tested and rejected --
# 147 hits repo-wide, including INSTALL.md's deliberately incomplete illustrative list, which
# would permanently false-positive). Instead this is opt-in: an author wraps the enumeration in
#     <!-- skills:all -->
#     - `skill-name`
#     ...
#     <!-- /skills:all -->
# and only spans between those sentinels are checked -- a doc with zero spans passes silently
# (that absence of warning is deliberate, not an oversight). Reuses check 4's $linkFiles set
# rather than its own file list (single source for "which docs matter").
#
# Extraction is CHARACTER-based (offset of the end of the BEGIN match to the start of the END
# match), not line-based. The real-world enumerations this exists for (e.g. the root README's
# "only the skills (...) remain available there" sentence) are inline running prose, not a bullet
# list on its own lines -- a line-based span could only mark that by putting a sentinel on its own
# line mid-paragraph, which breaks the paragraph in rendered markdown (an HTML comment is an HTML
# block that interrupts a paragraph). Character-based extraction lets the author wrap the sentinels
# tightly around just the enumeration itself, inline, e.g. `(...skills <!-- skills:all -->(`a`,
# `b`)<!-- /skills:all --> remain...`, with the same code path serving both the inline form and a
# block bullet-list form. AUTHOR CONDITION, because of this: every backtick-quoted token anywhere
# inside the span counts as a claimed name -- so the span must be wrapped tightly enough to contain
# ONLY skill names, nothing else in backticks (e.g. NOT the three SessionStart hook names in that
# same README sentence, which sit outside the parenthesized skill list and so outside the span).
#
# A literal example of the marker syntax in a doc (e.g. Tessa's convention writeup) must NOT be
# read as a live marker itself -- otherwise the syntax could only ever be described, never shown.
# Get-FenceMaskedText below masks fenced ```-code blocks with same-length whitespace before the
# BEGIN/END scan runs, so an example fence is invisible to it (an unpaired BEGIN inside a fence is
# therefore also invisible -- not reported, because the scan never sees it at all, not because it
# is special-cased). Deliberately fences only, not inline single-backtick code: a real span's own
# claimed names are themselves single-backtick-delimited (the `` `skill-name` `` bullets), so
# masking every inline-code run would erase the very names a real span exists to list -- there is
# no way to tell "backtick pair is an inline-code escape" from "backtick pair is a claimed skill
# name" at the character level. A fence is therefore the ONLY supported way to show the bare marker
# text without it being read as live; showing it in inline code is not an escape and stays in scope
# (Tessa documents the fence form as the convention, not inline code).
function Get-FenceMaskedText {
    # Masks fenced ```-code blocks with SAME-LENGTH whitespace (newlines untouched), so the caller
    # can keep using character offsets into the RETURNED text to derive correct line numbers -- the
    # length and every newline position stay identical to the input, only non-newline characters
    # inside a fence become spaces. Uses the SAME fence-toggle detection (Test-FenceDelimiterLine,
    # flip a boolean per line) that Get-HeadingSlugs already uses above -- one shared pattern, not
    # two independently hardcoded ones. It cannot reuse Get-HeadingSlugs's RESULT directly, though:
    # that function drops fenced lines outright (fine there -- it never reports a line number),
    # whereas this needs a same-shape mask, not a shorter string.
    param([string]$Text)
    $parts = [regex]::Split($Text, '(\r\n|\r|\n)')
    $inFence = $false
    for ($k = 0; $k -lt $parts.Length; $k += 2) {
        $isFenceLine = Test-FenceDelimiterLine -Line $parts[$k]
        if ($isFenceLine) { $inFence = -not $inFence }
        if ($isFenceLine -or $inFence) {
            $parts[$k] = ($parts[$k] -replace '.', ' ')
        }
    }
    return -join $parts
}

# THE OPT-IN SPAN WALK, ONCE (issue #1491). Three checks now read an author-placed
# '<!-- <marker> -->' ... '<!-- /<marker> -->' pair and hold what is inside it against a canonical set
# computed elsewhere: check 10 (skills:all), check 29 (skills:plugin) and check 32
# (shared-scripts:plugin). Everything about FINDING those spans is identical between them -- the fence
# masking, the forward walk, the three malformed-marker errors and the two symmetric sweeps -- and
# only what happens INSIDE a span differs.
#
# WHY THIS IS A FUNCTION AND NOT A THIRD COPY, and the argument is measured in this file rather than
# borrowed: checks 10 and 29 were the same walk written twice, and they DIVERGED. The nested-BEGIN
# case -- a second opener pasted inside an already-open span, which pairs across the whole span and
# comes out green for the wrong reason -- was reported by neither, was found while walking into it on
# check 29's branch, and had to be repaired in BOTH places on August 26, 2026. Check 10's own comment
# at that fix says so. A third hand-written copy would have been the third place to repair, and the
# one most likely to be missed: it is the copy nobody remembers exists.
#
# THE BODY WRITES THROUGH '$script:'. A scriptblock invoked with '&' runs in a CHILD scope, so a bare
# '$spanCount++' inside one would increment a local that dies with the call. Every caller's counters
# are therefore $script:-scoped, deliberately and visibly, rather than returned and accumulated here:
# what a body counts differs per check (spans, claims, both), and a walk that has to be told how to
# add up its callers' figures is a walk that knows too much about them.
function Invoke-MarkedSpanWalk {
    param(
        # The document, already fence-masked by the caller. Masked and RAW are both passed because the
        # two existing checks legitimately differ on which they read inside a span: check 10 reads the
        # mask (its claims are backticks, and a fenced block inside a span would otherwise claim
        # names), check 29 reads the raw text (its claims are link targets, which must stay
        # byte-exact). The mask is same-length and same-newlines, so one set of offsets addresses both.
        [Parameter(Mandatory)][AllowEmptyString()][string]$MaskedText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$RawText,
        # The marker's inner text -- 'skills:all', not the whole comment. Escaped here, so a caller
        # cannot smuggle a pattern into it.
        [Parameter(Mandatory)][string]$Marker,
        # The '[tag]' every finding from this walk carries, so a reader can tell which span reported.
        [Parameter(Mandatory)][string]$Category,
        # The repo-relative path, already formed, for the message.
        [Parameter(Mandatory)][string]$Rel,
        # Invoked once per well-formed span with a single hashtable argument: SpanStart, SpanEnd
        # (offsets into either text) and BeginLineNo (for the message). The body reports its own
        # findings through Add-Error and counts through $script: variables of its own.
        [Parameter(Mandatory)][scriptblock]$OnSpan
    )
    $m = [regex]::Escape($Marker)
    $beginRegex = [regex]"<!--\s*$m\s*-->"
    $endRegex = [regex]"<!--\s*/$m\s*-->"
    # Every END that actually closes a valid span, by offset, so the sweep below can tell one that
    # legitimately paired from a stray END before any BEGIN or a SECOND END inside an already-open
    # span (this walk only ever consumes the FIRST END after a BEGIN, so a duplicate further down
    # would otherwise sit there as silent, unchecked prose).
    $consumedEndIndices = New-Object System.Collections.Generic.HashSet[int]
    # Its mirror: every BEGIN this walk VISITS. A second BEGIN pasted INSIDE an already-open span is
    # never visited at all -- the walk jumps from a span's opener straight past its END -- so without
    # this it pairs across the span and the run comes out green for the wrong reason.
    $visitedBeginIndices = New-Object System.Collections.Generic.HashSet[int]
    $searchStart = 0
    while ($searchStart -le $MaskedText.Length) {
        $beginMatch = $beginRegex.Match($MaskedText, $searchStart)
        if (-not $beginMatch.Success) { break }
        [void]$visitedBeginIndices.Add($beginMatch.Index)
        $beginLineNo = 1 + [regex]::Matches($MaskedText.Substring(0, $beginMatch.Index), "`n").Count
        $spanStart = $beginMatch.Index + $beginMatch.Length
        $endMatch = $endRegex.Match($MaskedText, $spanStart)
        if (-not $endMatch.Success) {
            # An unpaired marker is a hard error, never a silent pass -- same principle as the
            # BEGIN-without-END guard in subagent-shared-lib.ps1's Expand-AgentDefShared (check 7): a
            # typo'd sentinel must not read as "no span here". Keep scanning past it, rather than
            # abandoning the file, so a later well-formed pair is still checked. (A BEGIN inside a
            # fence never reaches here at all -- it was masked to whitespace before the match.)
            Add-Error "[$Category] ${Rel}: '<!-- $Marker -->' at line $beginLineNo has no matching '<!-- /$Marker -->'."
            $searchStart = $spanStart
            continue
        }
        [void]$consumedEndIndices.Add($endMatch.Index)
        $searchStart = $endMatch.Index + $endMatch.Length
        & $OnSpan @{
            SpanStart   = $spanStart
            SpanEnd     = $endMatch.Index
            BeginLineNo = $beginLineNo
        }
    }
    # Symmetric sweep, both directions. The walk above only ever moves forward from a BEGIN, so an END
    # before any BEGIN, and a BEGIN inside an already-open span, are never visited by it -- each would
    # otherwise vanish into ordinary, unchecked prose instead of being reported.
    foreach ($em in $endRegex.Matches($MaskedText)) {
        if ($consumedEndIndices.Contains($em.Index)) { continue }
        $endLineNo = 1 + [regex]::Matches($MaskedText.Substring(0, $em.Index), "`n").Count
        Add-Error "[$Category] ${Rel}: '<!-- /$Marker -->' at line $endLineNo has no matching '<!-- $Marker -->'."
    }
    foreach ($bm in $beginRegex.Matches($MaskedText)) {
        if ($visitedBeginIndices.Contains($bm.Index)) { continue }
        $beginLineNo = 1 + [regex]::Matches($MaskedText.Substring(0, $bm.Index), "`n").Count
        Add-Error ("[$Category] ${Rel}: '<!-- $Marker -->' at line $beginLineNo sits INSIDE an already-open" +
            " span, so it is not the opener of anything -- the span that swallowed it closes at the next" +
            " '<!-- /$Marker -->' and its contents were checked as one. Usually this means the marker was" +
            " written in prose above a real span; show it in a fenced block instead.")
    }
}

# Canonical skillset: every <plugin root>/skills/<name>/SKILL.md, across ALL published plugins (not
# just the core -- an add-on team's start-task counts too). Exactly one skill-name folder between
# 'skills' and the file, so a deeper file such as a level-3 progressive-disclosure
# skills/<name>/references/SKILL.md, should that pattern ever appear, is not mistaken for a top-level
# skill.
#
# THE PLUGIN HALF IS ENFORCED NOW, WHICH IT WAS NOT (August 9, 2026). This walked everything under
# plugins/ and kept whatever matched '\skills\<one>\SKILL.md', while the comment above it claimed the
# match began at a plugin. It did not: any skills/ directory anywhere under plugins/ counted, published
# or not. Nothing was wrong in the output -- measured on the day it was changed, every skills/ directory
# under plugins/ did belong to a published plugin -- so this is a claim being made true rather than a
# defect being repaired. Worth doing because the next reader takes the comment at its word, and because
# the plugin roots are now something this gate can simply ask for.
#
# The name is read from the frontmatter 'name:' (the authoritative Claude Code call name, /plugin:name)
# rather than the folder name; as of this writing every skill's folder name happens to equal its
# frontmatter name, so this made no observable difference here, but frontmatter is the real source of
# truth if the two ever diverge. Falls back to the folder name only if 'name:' is missing from the
# frontmatter, so a future skill without that line does not silently drop out of the canonical set (not
# a new failure mode: the frontmatter's own presence/shape is check 3's domain, not this one's).
$skillCanonicalList = New-Object System.Collections.Generic.List[string]
foreach ($skillsDir in (Get-PluginSubdirs -PluginRoots $publishedPlugins -Leaf 'skills')) {
    Get-ChildItem -Path $skillsDir -Recurse -Filter 'SKILL.md' -File |
        Where-Object { $_.FullName -match '\\skills\\[^\\]+\\SKILL\.md$' } | ForEach-Object {
            $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
            $nm = [regex]::Match($text, '(?m)^name:\s*(\S+)\s*$')
            if ($nm.Success) {
                $skillCanonicalList.Add($nm.Groups[1].Value.Trim())
            } else {
                $skillCanonicalList.Add((Split-Path (Split-Path $_.FullName -Parent) -Leaf))
            }
        }
}
$skillCanonicalSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($n in $skillCanonicalList) { [void]$skillCanonicalSet.Add($n) }

# THE WALK ITSELF IS Invoke-MarkedSpanWalk (issue #1491) -- this check keeps only what is its own: the
# canonical set above, the claim rule below, and its counter. The fence masking, the forward walk, the
# three malformed-marker errors and the two symmetric sweeps moved into that function when a THIRD span
# check needed them; the note at its definition records why, and that it is this check and check 29
# having diverged which made a third copy unacceptable.
$skillSpanCount = 0
foreach ($lf in $linkFiles) {
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    # The cheap test first, on the RAW text, exactly as checks 29 and 32 do: masking is a split and a
    # regex-replace per line, and the overwhelming majority of this few-hundred-document set carries no
    # marker at all. A raw match is a superset of a masked one -- masking only ever removes markers, it
    # never creates one -- so skipping here can never skip a file the masked scan would have found.
    if ($content -notmatch '<!--\s*/?skills:all\s*-->') { continue }
    # Masked, not raw: a fenced example of the marker syntax must not be read as a live marker (see
    # Get-FenceMaskedText above). Same length + same newline positions as $content, so offsets
    # derived from it (line numbers, substrings) still point at the right place; a genuine span is
    # never inside a fence -- if it were, masking would make it invisible, not "found but wrong".
    $maskedContent = Get-FenceMaskedText -Text $content
    $rel = $lf.Replace($RepoRoot, '.')
    Invoke-MarkedSpanWalk -MaskedText $maskedContent -RawText $content -Marker 'skills:all' `
        -Category 'skill-list' -Rel $rel -OnSpan {
        param($span)
        # THE MASK, NOT THE RAW TEXT, and that is this check's own choice rather than the walk's: every
        # backtick pair inside the span is a claimed name here, so a fenced block within a span would
        # otherwise contribute names nobody claimed. Check 29 reads the raw text for the opposite reason.
        $skillSpanText = $maskedContent.Substring($span.SpanStart, $span.SpanEnd - $span.SpanStart)
        $skillFoundNames = [regex]::Matches($skillSpanText, '`([^`\r\n]+)`') | ForEach-Object { $_.Groups[1].Value }
        $skillFoundSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($n in $skillFoundNames) { [void]$skillFoundSet.Add($n) }
        $skillMissing = @($skillCanonicalSet | Where-Object { -not $skillFoundSet.Contains($_) } | Sort-Object)
        $skillExtra = @($skillFoundSet | Where-Object { -not $skillCanonicalSet.Contains($_) } | Sort-Object)
        if ($skillMissing.Count -gt 0) {
            Add-Error "[skill-list] ${rel}: <!-- skills:all --> span at line $($span.BeginLineNo) is missing: $($skillMissing -join ', ')."
        }
        if ($skillExtra.Count -gt 0) {
            Add-Error "[skill-list] ${rel}: <!-- skills:all --> span at line $($span.BeginLineNo) lists name(s) that are not a known skill: $($skillExtra -join ', ')."
        }
        # $script:-scoped because the body runs in a CHILD scope -- see the note at Invoke-MarkedSpanWalk.
        $script:skillSpanCount++
    }
}
if ($skillSpanCount -eq 0) {
    Write-Host "  [skill-list] 0 <!-- skills:all --> span(s) found -- opt-in, so this is a pass." -ForegroundColor DarkGray
} else {
    Write-Host "  [skill-list] checked $skillSpanCount <!-- skills:all --> span(s) against $($skillCanonicalSet.Count) canonical skill(s)." -ForegroundColor DarkGray
}

# --- 11. printed lifecycle commands carry their flags --------------------------------------------------
# THE CLASS THIS CLOSES. Three adoption rounds in a row (v3, v4, v5) found the same kind of defect and
# nothing else: a doc place printing a command, a count or a step that no longer holds. v3 was the
# adoption path plus three reporting errors, v4 was inbound #279 + #280, v5 was all four of its findings
# -- and three of the five repairs in 3.0.3 were of that kind too. Four doc fixes close four instances;
# the instances came back every round. This closes the half of the class a regex can actually decide:
# a printed `claude plugin install|update|uninstall` must carry `--scope project`, and install/update
# must have the marketplace refresh named nearby. Both are things a reader COPIES, and both fail
# silently when wrong -- a scopeless install writes a machine-wide record with no projectPath and
# reports success (inbound #274/#279), a stale cache reports success with a plausible version number
# (inbound #282/#284).
#
# THE TWO RULES REST ON DIFFERENT FOOTING, AND THE COMMENT SAYS SO RATHER THAN FLATTENING IT. The scope
# rule and the refresh-next-to-INSTALL rule each rest on a measured silent failure. The
# refresh-next-to-UPDATE half does not: measured 2026-07-31 (CLI 2.1.220) right after v3.0.4, with the
# cached clone verifiably still on the pre-release commit, a bare project-scoped update moved
# 3.0.3 -> 3.0.4 AND advanced the clone itself during the run -- so `update` refreshed for itself, and
# the older claim that skipping the refresh makes an update serve the previous version did not survive
# testing. The rule is kept anyway (Dave, 2026-07-31): the refresh is idempotent, it is one command, and
# a stale cache is invisible by construction, so the docs should keep naming it. What changed is the
# wording -- prudence, not a mechanism claim. Keeping that distinction visible here is the point: this
# check exists because doc claims drifted from measured reality, and it must not become an instance of
# that itself.
#
# THE DISCRIMINATOR, and it is the whole reason this can be a generic scan where check 10 could not be.
# A command with an explicit @-TARGET is an instruction someone runs:
#     claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project
#     claude plugin update <plugin>@<marketplace> --scope project
# A BARE mention is prose discussing the command, and demanding flags there would be nonsense:
#     "`claude plugin update` has the same default", "Because `claude plugin update` pins the cache"
# Measured over the scan set before this check was written: 10 targeted, 13 bare. That separation is
# what keeps this from becoming the 147-hit over-detection that made check 10 opt-in instead.
#
# HISTORY IS EXCLUDED, deliberately and permanently: CHANGELOG.md (root and per-plugin), releases/**,
# every RELEASE.md card, and the root changelog ENTRY files. Those record what was true at the time and
# are never rewritten -- the same principle the teardown's own audit applies when it excludes history
# from its scan. specialists/CHANGELOG.md:162 proves the need: it prints a targeted install with no
# scope flag, correctly, because that is what the release it describes actually said.
#
# SPANS, NOT LINES. A printed command wraps across a newline in running prose -- the teardown SKILL's
# `claude plugin uninstall <plugin>@<marketplace>` carries its `--scope project` on the NEXT line, inside
# the same inline-code span. A line-based check calls that a violation (it did, on the first probe run).
# So the unit is the enclosing inline-code span where there is one, and the rest of the physical line
# otherwise (which is the right unit inside a fenced block, where one command is one line).
#
# And the spans are computed over the FENCE-MASKED text, reusing check 10's Get-FenceMaskedText. Without
# that, a ```-fence delimiter throws off backtick pairing for the whole rest of the file: the regex
# cannot start a span on the first two backticks of a ``` run, starts one on the third, and closes it on
# the first backtick of the CLOSING fence -- after which every real inline span downstream is paired one
# position out. That is what made the wrapped uninstall above look flagless on the second run, and it is
# a silent misread rather than an error, so it is worth naming here. Masking keeps offsets and newline
# positions identical, so a span found in the mask indexes straight back into the real text.
#
# PRESENCE, NOT ORDER. The refresh window reaches 12 lines back and 6 forward, so a doc that names the
# refresh in the sentence just below the block still passes. Whether the refresh is described BEFORE the
# install in reading order is a judgement about prose, not something this regex should pretend to make;
# the check guarantees the step is named in the same instruction context, and a reviewer judges the rest.
# THE SCOPE RULE IS VERB-SPECIFIC, and `uninstall` is the exception rather than a loophole in it. For
# `install`/`update`, `project` is the only correct value and the rule rests on a measured silent failure
# (#274/#279). For `uninstall` it does not: a record sitting at `scope=local` is what a SESSION START
# leaves behind -- enabling a plugin is enough for one to create a record, and to flip an existing
# `project` record to `local`, with no command run (inbound #314) -- and `claude plugin uninstall ...
# --scope project` REFUSES to remove such a record ("Plugin ... is installed in local scope, not
# project", inbound #315). Demanding `project` on every printed uninstall would therefore make this gate
# reject the only command that does the job, i.e. it would enforce the very assumption round v8 disproved:
# that `project` is the only scope a consumer can be in. So `uninstall` accepts `project` OR `local`, and
# the other two verbs keep the stricter rule. Widening this to install/update would be wrong: nothing
# measured says a `local` install is ever what a reader wants.
$lcCmdRegex     = [regex]'claude\s+plugin\s+(?<verb>install|update|uninstall)\b'
$lcTargetRegex  = [regex]'(?:<plugin>@<marketplace>|[A-Za-z0-9_.\-]+@[A-Za-z0-9_.\-]+)'
$lcSpanRegex    = [regex]'(?s)`[^`]+`'
$lcScopeRegex   = [regex]'--scope\s+project'
$lcScopeUninstallRegex = [regex]'--scope\s+(?:project|local)'
$lcRefreshRegex = [regex]'claude\s+plugin\s+marketplace\s+update|staying-up-to-date'

# The changelog's path and the directory an entry's links resolve from are BOTH resolved above the link
# scan (check 4 needs the second one), so this check, check 13 and check 20 read $changelogRel,
# $changelogRelWin and $changelogFull from there. See that block for why the seam is read rather than the
# literal.

$lifecycleFiles = @($linkFiles | Where-Object {
    $rel = $_.Substring($RepoRoot.Length).TrimStart('\', '/')
    if ($rel -eq $changelogRelWin) { return $false }
    if ($rel -match '\\CHANGELOG\.md$') { return $false }
    if ($rel -match '(^|\\)RELEASE\.md$') { return $false }
    if ($rel -match '^releases\\') { return $false }
    # The moved release pages are the same history at their workflow-folder address (August 14, 2026).
    if ($rel -match '^dkj-policy\\releases\\') { return $false }
    # A root <branch-name>.md entry file is history in the making; same reasoning as CHANGELOG.md.
    if (($rel -notmatch '\\') -and (Test-IsChangelogEntryFile -Path $_)) { return $false }
    # branch/ is the same subject at its new address. Both files: the entry is history in the making, and
    # the step list is a scratch pad that never travels anywhere -- neither is a document a consumer reads
    # a lifecycle command off, which is what this check judges.
    # SEPARATORS NORMALISED before the escape, the lesson check 20 already paid for: the seam answers with
    # forward slashes while $rel is built from a Windows path, and an exclusion that compares the two raw
    # matches nothing -- silently, since these files rarely carry the commands this check judges.
    # THE BRANCH DOCUMENT, NOT THE WHOLE WORKFLOW FOLDER (August 23, 2026). This used to exclude everything
    # under the branch directory, which WAS only branch files; the seam's Directory is the workflow folder
    # itself now, so the same expression would wave through the folder's README, CLAUDE.md and
    # CONTRIBUTING.md -- three documents that print lifecycle commands and are exactly what this check is for.
    $lcBranchDoc = @((Get-BranchFilePaths).File, (Get-BranchFilePaths).LegacyCycle,
        (Get-BranchFilePaths).LegacyDeployment, (Get-BranchFilePaths).OlderCycle,
        (Get-BranchFilePaths).OlderDeployment) | ForEach-Object { $_ -replace '/', '\' }
    # THE PER-BRANCH NAMES JOIN IT BY PATTERN (#1255) -- see the predicate's own header for why a list
    # cannot do this job any more.
    if ($lcBranchDoc -contains $rel) { return $false }
    if (Test-IsPerBranchDocumentPath -RelativePath $rel) { return $false }
    return $true
})

$lcEnforced = 0
$lcBare = 0
foreach ($lf in ($lifecycleFiles | Sort-Object -Unique)) {
    $rel = $lf.Substring($RepoRoot.Length).TrimStart('\', '/')
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    $lcLines = $content -split "`r?`n"
    $lcMasked = Get-FenceMaskedText -Text $content
    # Inline-code spans, once per file, found in the MASKED text and read out of the real one.
    $spans = @($lcSpanRegex.Matches($lcMasked) | ForEach-Object {
        [pscustomobject]@{ Start = $_.Index; End = ($_.Index + $_.Length) }
    })
    foreach ($m in $lcCmdRegex.Matches($content)) {
        # Inside a fence the mask has whitespace where the real text has the command, and there the unit
        # is the physical line -- a fenced command is one line, and its own backticks (if any) are not
        # span delimiters.
        $inFence = ($lcMasked[$m.Index] -ne $content[$m.Index])
        $cmdText = $null
        $cmdStart = -1
        if (-not $inFence) {
            foreach ($s in $spans) {
                if ($m.Index -ge $s.Start -and $m.Index -lt $s.End) {
                    $cmdText = $content.Substring($s.Start, $s.End - $s.Start)
                    $cmdStart = $s.Start
                    break
                }
            }
        }
        if (-not $cmdText) {
            $eol = $content.IndexOfAny([char[]]@("`r", "`n"), $m.Index)
            if ($eol -lt 0) { $eol = $content.Length }
            $cmdText = $content.Substring($m.Index, $eol - $m.Index)
            $cmdStart = $m.Index
        }
        # Everything after THIS match's verb decides whether this is an instruction or a mention. The
        # offset is derived from the match position, not from IndexOf($verb) in the span: a span holding
        # two commands with the same verb would otherwise judge the second one on the first one's tail.
        # Clamped: a malformed span whose closing backtick lands mid-command would otherwise throw and
        # take the whole gate down over a typo in a doc. An empty tail simply reads as "no target".
        $verbEnd = [Math]::Min([Math]::Max(0, ($m.Groups['verb'].Index + $m.Groups['verb'].Length) - $cmdStart), $cmdText.Length)
        $afterVerb = $cmdText.Substring($verbEnd)
        # THIS command's arguments only: from its own verb up to the next lifecycle command, or the end
        # of the span/line. Both rules below judge that slice rather than the whole span, because a span
        # can hold two commands -- and then the second would borrow the first one's `--scope project`
        # and read as correct while a reader copies a scopeless line (Victor, on this check's own code).
        $nextCmd = [regex]::Match($afterVerb, 'claude\s+plugin\s+(?:install|update|uninstall)\b')
        $cmdArgs = if ($nextCmd.Success) { $afterVerb.Substring(0, $nextCmd.Index) } else { $afterVerb }
        if (-not $lcTargetRegex.IsMatch($cmdArgs)) { $lcBare++; continue }
        $lcEnforced++
        $lineNo = 1 + [regex]::Matches($content.Substring(0, $m.Index), "`n").Count
        $verb = $m.Groups['verb'].Value
        $scopeOk = if ($verb -eq 'uninstall') { $lcScopeUninstallRegex.IsMatch($cmdArgs) } else { $lcScopeRegex.IsMatch($cmdArgs) }
        if (-not $scopeOk) {
            $wanted = if ($verb -eq 'uninstall') { "'--scope project' (or '--scope local', the only way to remove a record a session start left at local scope -- inbound #314/#315)" } else { "'--scope project'" }
            Add-Error "[lifecycle] ${rel}:${lineNo}: printed 'claude plugin $verb' with an @-target but no $wanted. All three default to --scope user, which writes a machine-wide record with no projectPath and reports success (inbound #274/#279). Add the flag, or drop the @-target if this line is discussing the command rather than telling a reader to run it."
        }
        if ($verb -ne 'uninstall' -and -not $lcRefreshRegex.IsMatch(($lcLines[[Math]::Max(0, $lineNo - 13)..[Math]::Min($lcLines.Count - 1, $lineNo + 5)] -join "`n"))) {
            Add-Error "[lifecycle] ${rel}:${lineNo}: printed 'claude plugin $verb' with an @-target, but neither 'claude plugin marketplace update' nor a link to 'staying-up-to-date' appears within 12 lines above or 6 below. The marketplace is a cached clone and a stale one reports success with a plausible version number, so the refresh belongs next to a printed install/update. Measured for 'install' on 2026-07-30 (it served the previous version); a bare 'update' refreshed the clone for itself on 2026-07-31, so for that verb this is prudence rather than a measured failure. Quoting a command as the SUBJECT of prose rather than as an instruction? Elide the target as '...', the repo's convention."
        }
    }
}
Write-Coverage -Category 'lifecycle' -Checked $lcEnforced `
    -Note $(if ($lcEnforced -eq 0) { 'no printed lifecycle command with an @-target anywhere in the scan set -- nothing to enforce, which is not the same as the docs being right' } else { "$lcBare bare mention(s) skipped as discussion; history (CHANGELOG.md, releases/, RELEASE.md, entry files) excluded" })

# --- 12. a printed install-record query must name the fields that disambiguate the state -----
# THE CLASS, and why this is a gate rather than three doc fixes. Round v8 produced three findings that
# read as unrelated and are one: the family's own verification query -- the thing every document points a
# reader at to answer "what am I actually running?" -- printed a green that UNDER-DETERMINED the state it
# claimed to prove. It could not distinguish
#   - the release from `main` after it            (#313: `version` reads 3.0.8 on both; only gitCommitSha
#                                                  differs, and that field was printed nowhere),
#   - one record from two                         (#315: the prescribed repair install ADDS a record, and
#                                                  the line count was the only signal),
#   - `project` from `local`                      (#314: which is what a session start leaves behind).
# Three instances closed by three doc edits would have been the fourth adoption round in a row to close
# instances of a class that came back. This closes the half a regex can decide: whether the query a doc
# PRINTS still selects every field a reader needs to tell those states apart. Sibling of check 11 in
# footing and in shape -- both hold a copied instruction to what was measured rather than to itself -- and
# it shares check 11's scan set, so history is excluded here for the same reason.
#
# THE DISCRIMINATOR: the block must READ the administration IN CODE (it names installed_plugins.json and
# parses it). That is what separates an instruction someone copies from a doc merely discussing the file --
# the same mention-versus-use question check 11 answers with the @-target, and the third time this repo has
# had to answer it (see the MENTION vs USE rule in Sylvester's lens). A JSON snippet ILLUSTRATING a record
# is therefore out of scope even though it names the same fields: it teaches the file's shape, it is not a
# command whose output someone reads a verdict off.
#
# projectPath IS ONE OF THE REQUIRED FIELDS, not part of the discriminator, and that is deliberate: a query
# that reads the administration WITHOUT filtering on projectPath is exactly the `claude plugin list` mistake
# both documents spend a paragraph warning about -- it reports records beyond this repo and so cannot carry
# a verdict about this one. A doc printing that would be reproducing the very defect it warns against.
#
# Matching is case-INSENSITIVE on purpose. The reader copies these to run them, and PowerShell property
# access is case-insensitive, so `$_.Version` is as correct as `$_.version`; demanding the JSON file's exact
# casing would report a working query as broken. Erring this way can only miss a miscased field, never
# invent a finding -- the same direction check 11 and Get-RecordShape both chose.
$irRequiredFields = @('projectPath', 'scope', 'version', 'gitCommitSha')

$irChecked = 0
$irMentions = 0
foreach ($lf in ($lifecycleFiles | Sort-Object -Unique)) {
    $rel = $lf.Substring($RepoRoot.Length).TrimStart('\', '/')
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    $irLines = $content -split "`r?`n"
    # Fenced blocks, walked with the SHARED fence-toggle primitive (Test-FenceDelimiterLine) that
    # Get-HeadingSlugs and Get-FenceMaskedText already use -- one fence notion in this file, not a third
    # hand-rolled one. The mask itself is no use here: it replaces a fence's contents with whitespace, and
    # this check needs exactly those contents.
    $inFence = $false
    $blockBody = @()
    $blockLine = 0
    for ($i = 0; $i -lt $irLines.Count; $i++) {
        if (Test-FenceDelimiterLine -Line $irLines[$i]) {
            if (-not $inFence) {
                $inFence = $true
                $blockBody = @()
                $blockLine = $i + 2   # 1-based line of the first line INSIDE the fence
            } else {
                $inFence = $false
                $body = ($blockBody -join "`n")
                if ($body -match 'installed_plugins\.json' -and $body -match 'ConvertFrom-Json') {
                    $irChecked++
                    $missing = @($irRequiredFields | Where-Object { $body -notmatch [regex]::Escape($_) })
                    if ($missing.Count -gt 0) {
                        Add-Error "[record-query] ${rel}:${blockLine}: a printed query that reads installed_plugins.json does not name $(($missing | ForEach-Object { "'$_'" }) -join ', '). A reader runs this to answer 'what am I actually running?', and without every one of $(($irRequiredFields | ForEach-Object { "'$_'" }) -join ', ') the output cannot carry that verdict: 'version' cannot tell the release from main after it (inbound #313), the record COUNT is the only signal of the stray second record a repair install leaves (#315), 'scope' is what a session start silently flips to 'local' (#314), and without 'projectPath' the query reports records beyond this repo -- the 'claude plugin list' mistake these same docs warn about. Add the field, or move the snippet out of a fenced code block if it is illustrating the file's shape rather than telling a reader to run it."
                    }
                } elseif ($body -match 'installed_plugins\.json') {
                    $irMentions++
                }
            }
            continue
        }
        if ($inFence) { $blockBody += $irLines[$i] }
    }
}
# The skip count belongs in BOTH branches, which the test suite established rather than the design: an
# empty scan that had skipped an illustration reads identically to one that saw nothing about the file at
# all, and those are different states. "Nothing to enforce" plus "and one block was deliberately not
# judged" is the honest pair -- the same reasoning as the [COVERAGE] rule itself (issue #221).
$irSkipNote = "$irMentions fenced block(s) naming the file without parsing it skipped as illustration"
Write-Coverage -Category 'record-query' -Checked $irChecked `
    -Note $(if ($irChecked -eq 0) { "no printed query reads installed_plugins.json anywhere in the scan set -- nothing to enforce, which is not the same as the docs being right ($irSkipNote)" } else { "$irSkipNote; history excluded as in check 11" })

# --- 13. entry heading levels: a body heading cannot become an entry, nor a section of one ---------------
# THE DEFECT, and it is this repo's own, four times in one day. An entry body used a sub-heading at the
# entry's own level, so the two became siblings: after the fold, CHANGELOG.md carried headings with no PR
# number, and the release renderer split an entry on every one of them -- emitting extra "entries" with no
# number, no type and no Plugins line. Rendall's lens already warned about it (seen in v2.13.2, where a
# body heading rendered as a release category). The warning did not stop it, which is the argument for a
# gate rather than a sharper sentence: the rule is exactly checkable, so nobody should have to remember it.
#
# EVERY LEVEL IS READ FROM THE FORMAT LIB (entry-scaffold-lib.ps1, via release-lib.ps1), because the levels
# moved on August 5, 2026 and a hardcoded copy would have gone stale exactly the way this file's own
# Test-IsChangelogEntryFile did. An entry heading is an H3; its two named sections are H4.
#
# WHAT IS NOW WRONG, AND WHY EACH HALF IS A REAL DEFECT RATHER THAN A STYLE RULE:
#   - a heading AT OR ABOVE the entry's own level in a body. An H3 becomes a SEPARATE ENTRY -- Split-Changelog
#     splits on exactly that level -- and the phantom carries no impact table, so it reads as an undeclared
#     tier 0 and gets its own block in the record. An H1 climbs above every entry in the document.
#   - a SECTION-LEVEL heading that is not one of the entry's declared sections. This half is new with the
#     format, and it is not cosmetic: Get-EntrySectionBody ends a section at the next heading of that level
#     or above, so a stray H4 truncates whichever section it lands in -- and a MISTYPED section heading
#     ('Who is this For') is the same shape, silently costing the entry the very declaration the tier and
#     significance gates read. Use '##### ' or bold for a sub-heading; fix the spelling for a section.
#
# TWO PLACES, because they catch it at two different moments:
#   - the root ENTRY FILES, which is where the author can still fix it on the PR. Line 1 is the entry's own
#     heading and is skipped whatever its level -- a pre-format H3 entry file is legitimate, and the fold
#     promotes it as it lands.
#   - CHANGELOG.md below its intro, which is what cut-release actually parses. This half also catches damage
#     that arrived through the fold -- the one write that happens directly on main, past every PR gate (the
#     #234 lesson).
# Fence-aware in both, via the same Get-FenceMaskedText the other checks use: an entry that QUOTES a heading
# inside a code fence is discussing structure, not creating it -- the mention-versus-use question this file
# has now answered four times, and this repo's own changelog and entry files do exactly that.
$ehChecked = 0
$ehEntryLevel   = Get-EntryHeadingLevel
$ehSectionLevel = Get-EntrySectionLevel
# The current names PLUS the retired ones. Without the second half this check reports every entry
# written before a heading was renamed as a MISSPELLED section -- its most alarming finding, and its
# least true. Measured when 'Who is this for' became 'Significance': 24 pending entries in this repo's
# own CHANGELOG.md, all accused at once, which is how a check gets switched off rather than heeded.
$ehSectionNames = @((Get-EntrySectionHeadings).Values) + @(Get-EntryRetiredSectionHeadings)
# AND THE AUDIENCE TIER'S HEADING, which became one of these on August 23, 2026 by moving up a level. It is
# not a named SECTION of the entry -- Get-EntrySectionHeadings deliberately does not list it, because it is
# the tier writer's business -- but it now sits at the section level, so a check that only knew the named set
# would report every single entry for a heading the scaffolder itself writes. Both wordings, for the reason
# every reader here takes both: entries carrying the previous one are all over CHANGELOG.md.
$ehSectionNames += @(Get-EntryTierHigherHeading) + @(Get-EntryTierHigherRetiredHeadings)
$ehSectionNames = @($ehSectionNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
# At or above the entry's own level: '#' .. '###' while an entry is an H3.
$ehTooHighRx = '^#{1,' + $ehEntryLevel + '}\s'
# AND THE SAME TAIL TOLERANCE THE LIB'S READERS GOT (August 19, 2026) -- this gate is one of them, and it
# was the one left out. The 'Pull Request' heading carries the merge stamp now, so a folded entry reaches
# CHANGELOG.md as '### Pull Request <middot> 20260819-171500'. Anchored on a bare '\s*$' the name has to be
# the whole line, so that heading reads as a section nobody declares and the CHANGELOG.md half below raises
# [entry-heading] on it -- on the one write that happens directly on main, past every PR gate, inside the
# required CI check. Every PR after the first fold would have been blocked by the fold of the one before it.
# THE STAMP IS STRIPPED BEFORE THE COMPARISON, not tolerated inside it: the capture is still only the name,
# so 'Who is this For' differing by one letter is caught exactly as strictly as it was.
$ehSectionRx = '^#{' + $ehSectionLevel + '}\s+(.+?)' + (Get-EntrySectionHeadingTail)

function Test-IsDeclaredSectionHeading([string]$Line) {
    # $true when the line is a section heading whose text is one this repo declares. The comparison is
    # exact, deliberately: 'Who is this For' differing only in case is the mistyped-heading case this
    # exists to catch, and the parser it protects matches exactly too.
    $m = [regex]::Match($Line, $ehSectionRx)
    if (-not $m.Success) { return $false }
    return ($ehSectionNames -ccontains $m.Groups[1].Value)
}

# THE ENTRY IS IN branch/ SINCE THE SPLIT (August 6, 2026), so scanning only the root would leave this
# check with nothing to judge on every branch -- and it would still report [OK], because "no unfolded entry
# file" is a legitimate state between merges. A check that goes quiet for the right-looking reason is worse
# than one that errors. Both locations are walked, for the same "recognise both" reason the fold walks both.
#
# AND THE ENTRY IS A SECTION OF A DOCUMENT, NOT A DOCUMENT (August 23, 2026). Both branch files used to open
# with an H2, so the structural test -- the only thing that tells an entry from a root doc -- said yes to the
# step list too, and it had to be excluded by PATH. The branch document's own heading sits a level above an
# entry's, so that test now says no to the WHOLE file, which would have quietly dropped every branch entry out of this check rather
# than merely mis-reporting it. The exclusion is gone and the entry is read out of the document instead --
# Split-Development, the same boundary the fold and the two gates use.
#
# WITH ITS LINE OFFSET, because this check prints line numbers. A finding reported against the entry's own
# first line, in a file where the entry starts forty lines down, is a finding the reader cannot find.
#
# The fold needed no such repair: it reaches the document by path and only ever applies the structural test
# to loose *.md in the ROOT, where a step list has never lived.
$entryTextsForHeadings = @()
foreach ($ef in @(Get-ChildItem -Path $RepoRoot -Filter '*.md' -File |
        Where-Object { Test-IsChangelogEntryFile -Path $_.FullName })) {
    $entryTextsForHeadings += [pscustomobject]@{
        Rel    = $ef.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
        Text   = [System.IO.File]::ReadAllText($ef.FullName, [System.Text.Encoding]::UTF8)
        Offset = 0
    }
}
# THE BRANCH DOCUMENT, AND ONLY WHILE IT HOLDS AN ENTRY. In its reset state the DEPLOY section is the empty
# form, which has nothing to say about heading structure; check 13b is what holds that state to its shape.
# Every older name is read as well, because a branch created before the merge still has to be checked --
# Resolve-BranchFilePath picks the one that declares this branch.
#
# EVERY BRANCH DOCUMENT PRESENT, NOT ONLY THIS BRANCH'S (#1255). The resolver answers ONE path -- the right
# one for the branch you are on -- and that was the whole set while there was a single shared name. Now a
# tree can hold several: this branch's, plus any left on the trunk by a fold that could not push. Judging
# only one of them would let a malformed heading in another reach CHANGELOG.md at ITS fold, which is exactly
# the phantom entry this check exists to prevent -- and it would do it silently, since the run would report
# a clean pass over a document it never opened.
$branchDocForHeadings = Resolve-BranchFilePath -Kind Deployment -RepoRoot $RepoRoot
# The other per-branch documents in the folder, found by pattern because no list can name them. Same sweep
# check 13b runs, and for the same reason -- see the block above.
$branchDocSweep = @(Get-PerBranchDocumentRels -RepoRoot $RepoRoot)
$entryHeadingRels = @($branchDocForHeadings) + @($branchDocSweep) | Select-Object -Unique
foreach ($bdRel in $entryHeadingRels) {
    if (-not $bdRel) { continue }
    $branchDocPathForHeadings = Join-Path $RepoRoot ($bdRel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $branchDocPathForHeadings)) { continue }
    $bdText = [System.IO.File]::ReadAllText($branchDocPathForHeadings, [System.Text.Encoding]::UTF8)
    if (-not (Test-BranchChangelogIsFilled -Text $bdText)) { continue }
    $bdSplit = Split-Development -Text $bdText
    $entryTextsForHeadings += [pscustomobject]@{
        Rel    = $bdRel -replace '/', '\'
        Text   = $(if ($bdSplit.Found) { $bdSplit.Entry } else { $bdText })
        Offset = $(if ($bdSplit.Found) { $bdSplit.Index } else { 0 })
    }
}
foreach ($ef in $entryTextsForHeadings) {
    $ehChecked++
    $rel = $ef.Rel
    $masked = Get-FenceMaskedText -Text $ef.Text
    $ehLines = $masked -split "`r?`n"
    # A DECLARED SECTION THAT APPEARS TWICE IN ONE ENTRY (issue #1367). Every named section is meant to
    # appear once, and nothing downstream errors when one is doubled: the entry validates, every gate
    # passes, and the damage only surfaces in a PUBLISHED Release body -- the same silent-in-both-directions
    # shape as the split-entry rule above. The fold stamps and links the LAST 'Pull Request' heading while
    # Get-PrDescription and the release renderer read the FIRST, so a doubled section shipped a Release
    # bullet with no PR link, indistinguishable from one whose PR genuinely has no number. Keyed on the
    # stamp-stripped name ($ehSectionRx's own capture), so a folded 'Pull Request <middot> <stamp>' and a
    # scaffolded 'Pull Request' are recognised as the same section. Reset per entry -- 'Pull Request' in
    # two different entries is the norm.
    $ehSeenSections = @{}
    for ($i = 1; $i -lt $ehLines.Count; $i++) {
        $line = $ehLines[$i]
        if ($line -match $ehTooHighRx) {
            $lvl = ($line -replace '^(#+).*$', '$1')
            Add-Error "[entry-heading] ${rel}:$($ef.Offset + $i + 1): a '$lvl ' heading in an entry body, at or above the entry's own level. An entry heading is an H$ehEntryLevel, so an H$ehEntryLevel here becomes a SEPARATE entry the moment the fold pastes this section into CHANGELOG.md -- one that declares no impact and therefore reads as an undeclared tier 0 -- and an H1 climbs above every entry in the document. Use '$('#' * ($ehSectionLevel + 1)) ' or bold instead."
        } elseif (($line -match $ehSectionRx) -and -not (Test-IsDeclaredSectionHeading $line)) {
            Add-Error "[entry-heading] ${rel}:$($ef.Offset + $i + 1): '$($Matches[1])' is at the level of the entry's named sections but is not one of them ($($ehSectionNames -join ', ')). A section ends at the next heading of this level or above, so this truncates whichever section it sits in -- and if it is a misspelling of a real section heading, the entry silently loses that declaration and the tier/significance gates read nothing. Use '$('#' * ($ehSectionLevel + 1)) ' for a sub-heading, or correct the spelling."
        } elseif ($line -match $ehSectionRx) {
            $ehName = ([regex]::Match($line, $ehSectionRx)).Groups[1].Value
            if ($ehSeenSections.ContainsKey($ehName)) {
                Add-Error "[entry-heading] ${rel}:$($ef.Offset + $i + 1): a second '$ehName' section in this entry. Each named section is read once, and a repeat makes two readers disagree about which copy is the entry's -- the fold stamps and links the LAST 'Pull Request' heading, while the PR body and the release notes read the FIRST, so a doubled section ships a Release bullet with no PR link (issue #1367). Delete the duplicate and keep one."
            } else {
                $ehSeenSections[$ehName] = $true
            }
        }
    }
}

$clForHeadings = $changelogFull
if (Test-Path -LiteralPath $clForHeadings) {
    $clMasked = Get-FenceMaskedText -Text ([System.IO.File]::ReadAllText($clForHeadings, [System.Text.Encoding]::UTF8))
    $clLines = $clMasked -split "`r?`n"
    # THE BOUNDARY IS STRUCTURAL NOW, not a heading name. It used to be '## Pull Requests' to '## Releases',
    # matched in both spellings and in either order; the flat document has no section headings at all, so the
    # intro simply ends at the first entry heading -- the same rule Split-Changelog derives it by, which is
    # what keeps the gate and the parser looking at one document.
    #
    # A changelog with no entry at all is not judged and not an error: that is the normal state of the file
    # between a release and the next merge, and check 13's subject is the entries.
    $clFirstEntry = -1
    for ($i = 0; $i -lt $clLines.Count; $i++) {
        if ($clLines[$i] -match ('^#{' + $ehEntryLevel + '}\s')) { $clFirstEntry = $i; break }
    }
    if ($clFirstEntry -ge 0) {
        $ehChecked++
        $clRealLines = (([System.IO.File]::ReadAllText($clForHeadings, [System.Text.Encoding]::UTF8)) -split "`r?`n")
        # WHICH SECTION A WHOLE ENTRY OPENS WITH, and there is more than one right answer -- which is the
        # repair this rule needed when the dossier form put the title section in front (August 6, 2026).
        # A current entry opens with that; the entries ALREADY in CHANGELOG.md open with the description
        # question, under its current name or its retired one. Testing only the newest opener would have
        # reported every one of the pending entries as a split entry: two dozen false accusations, which is
        # how a check gets switched off rather than heeded -- measured on this very gate when
        # 'Who is this for' was renamed.
        # AND THE FIRST SECTION'S OWN RETIRED NAMES BELONG HERE TOO (August 7, 2026). 'What' had them from the
        # start; the opening section did not need them until it was renamed, and the moment it was, all six
        # pending entries were reported as split -- the very failure the paragraph above describes, reappearing
        # one section to the left. A rename is not a one-line change while any reader knows only the new name.
        # AND IT HAPPENED A THIRD TIME ON AUGUST 16, 2026, which is why the list of openers is no longer
        # built here. This read the CURRENT first key plus that key's retired NAMES -- correct until the
        # first KEY itself moves, which it did when 'Branch title' stopped being written: the retired-name
        # lookup then answered for 'What' while every pending entry in CHANGELOG.md still opened with
        # 'Branch title', and six correct entries were reported as split. Get-EntryOpeningSectionKeys is
        # the format owner's own answer to "which sections have ever opened an entry"; the gate adds each
        # one's retired names, which is the part that was already right.
        $ehHeadings = Get-EntrySectionHeadings
        $ehOpeners = @()
        foreach ($ehKey in (Get-EntryOpeningSectionKeys)) {
            $ehOpeners += @($ehHeadings[$ehKey]) + @(Get-EntrySectionRetiredNames -Key $ehKey)
        }
        # AND A FOURTH TIME, ON AUGUST 23, 2026 -- not a rename this time but a LEVEL MOVE, which is why the
        # three repairs above did not cover it. Tier 0 lost its heading when the entry became the development
        # cycle's DEPLOY section, and the audience tier's heading moved up to the section level to take its
        # place. So the first named section an entry has is now 'What makes this deploy extra special', and
        # this repo's own freshly folded entry was reported as split the moment it landed on main.
        #
        # ADDED BESIDE THE KEYED LIST RATHER THAN INTO IT, because it is not a section KEY: the tier writer
        # owns that heading, deliberately, and Get-EntrySectionHeadings does not answer for it. Both wordings,
        # like everywhere else that reads it -- every entry already in CHANGELOG.md carries the previous one.
        $ehOpeners += @(Get-EntryTierHigherHeading) + @(Get-EntryTierHigherRetiredHeadings)
        $ehOpeners = @($ehOpeners | Where-Object { $_ })
        $ehWhatHeading = $ehOpeners[0]

        # WHAT DISTINGUISHES AN ENTRY FROM A BODY HEADING, since markdown gives no marker for it. Every H2
        # here is read as one change, so a stray body heading becomes a phantom entry: no impact table, so an
        # undeclared tier 0, with its own block in the record. The rule is structural rather than a guess, and
        # it is TWO rules because there are two legitimate entry shapes:
        #
        #   - an entry with sections: its FIRST declared section must be the first one ('$ehWhatHeading').
        #     A stray heading dropped inside a formatted entry splits the three sections across two blocks,
        #     so the phantom's first section is whichever one followed it -- never the first.
        #   - an entry with NO sections: only a pre-format entry, which carries its type as a heading field
        #     instead. Resolve-EntryType answers that, reading the section where there is one and the heading
        #     where there is not -- the same reader the release documents use, so the gate cannot disagree
        #     with them about what an entry declares.
        #
        # THAT PAIR IS WHAT MAKES IT COMPLETE, and neither half is complete alone. A stray heading placed
        # between the entry heading and its first section keeps all three sections in ITS block and passes the
        # first rule -- but it leaves the real entry above it with none, and a current-format heading carries
        # no type field, so the second rule reports that one. The error lands on the entry rather than on the
        # stray, which is why the message names both possibilities instead of asserting which it found.
        #
        # NOT KEYED ON THE '#NN' THE FOLD PREPENDS, deliberately, though it would be the obvious test: the
        # fold cannot reach gh on a manual merge and then writes a legitimate entry with no number and no PR
        # footer, stating so on the console. A gate keying on the number would report the fold's own
        # documented output as a defect.
        $clStarts = @()
        for ($i = $clFirstEntry; $i -lt $clLines.Count; $i++) {
            if ($clLines[$i] -match ('^#{' + $ehEntryLevel + '}\s')) { $clStarts += $i }
        }
        for ($b = 0; $b -lt $clStarts.Count; $b++) {
            $from = $clStarts[$b]
            $to = if ($b + 1 -lt $clStarts.Count) { $clStarts[$b + 1] - 1 } else { $clLines.Count - 1 }
            $firstDeclared = $null
            # A DECLARED SECTION REPEATED WITHIN THIS ONE ENTRY (issue #1367). The branch-document pass
            # above catches it on the PR; this half catches a copy that arrived through the fold -- the one
            # write that lands directly on main, past every PR gate. Scoped to $from..$to because the same
            # section name in two different entries is normal. Keyed on the stamp-stripped capture, so a
            # folded 'Pull Request <middot> <stamp>' matches a plain 'Pull Request'.
            $clSeenSections = @{}
            for ($i = $from + 1; $i -le $to; $i++) {
                if (Test-IsDeclaredSectionHeading $clLines[$i]) {
                    $clName = ([regex]::Match($clLines[$i], $ehSectionRx)).Groups[1].Value
                    if ($clSeenSections.ContainsKey($clName)) {
                        Add-Error "[entry-heading] CHANGELOG.md:$($i + 1): a second '$clName' section in this H$ehEntryLevel. Each named section is read once -- the fold stamps and links the LAST 'Pull Request' heading while the release renderer reads the FIRST, so a doubled section renders a Release bullet with no PR link (issue #1367). Delete the duplicate and keep one."
                    } else {
                        $clSeenSections[$clName] = $true
                    }
                }
            }
            for ($i = $from + 1; $i -le $to; $i++) {
                if (Test-IsDeclaredSectionHeading $clLines[$i]) {
                    $firstDeclared = ([regex]::Match($clLines[$i], $ehSectionRx)).Groups[1].Value
                    break
                }
            }
            if ($null -ne $firstDeclared) {
                if ($ehOpeners -cnotcontains $firstDeclared) {
                    Add-Error "[entry-heading] CHANGELOG.md:$($from + 1): this H$ehEntryLevel's first named section is '$firstDeclared' rather than '$ehWhatHeading'. Every H$ehEntryLevel here is read as one change, so an entry whose sections do not start at the beginning is one that has been SPLIT -- almost certainly by a body sub-heading written at the entry's own level, which the release documents then file as a separate change declaring no impact. Demote that sub-heading to '$('#' * ($ehSectionLevel + 1)) '."
                }
            } else {
                $blockText = (@($clRealLines[$from..([Math]::Min($to, $clRealLines.Count - 1))]) -join "`n")
                if (-not (Resolve-EntryType -EntryText $blockText).Declared) {
                    Add-Error "[entry-heading] CHANGELOG.md:$($from + 1): this H$ehEntryLevel declares neither its named sections nor a change type. Every H$ehEntryLevel here is read as one change, and this one tells the release documents nothing -- it is either a body sub-heading written at the entry's own level (demote it to '$('#' * ($ehSectionLevel + 1)) ') or a real entry whose sections were absorbed by such a heading directly below it."
                }
            }
        }

        for ($i = $clFirstEntry; $i -lt $clLines.Count; $i++) {
            $line = $clLines[$i]
            if ($line -match '^#\s') {
                Add-Error "[entry-heading] CHANGELOG.md:$($i + 1): an H1 below the intro. It comes from an entry body and climbs above every entry in the document -- and in the generated release notes it renders above the tier heading it belongs under. Demote it to '$('#' * ($ehSectionLevel + 1)) '."
            } elseif (($line -match $ehSectionRx) -and -not (Test-IsDeclaredSectionHeading $line)) {
                Add-Error "[entry-heading] CHANGELOG.md:$($i + 1): '$($Matches[1])' sits at the level of an entry's named sections but is not one of them ($($ehSectionNames -join ', ')). A section ends at the next heading of this level or above, so this truncates the section it sits in -- and a misspelled section heading costs that entry its declaration silently. Demote it to '$('#' * ($ehSectionLevel + 1)) ', or correct the spelling."
            }
        }
    }
}

Write-Coverage -Category 'entry-heading' -Checked $ehChecked `
    -Note $(if ($entryTextsForHeadings.Count -eq 0) { 'no unfolded entry in the branch document or the root, so only CHANGELOG.md was judged -- normal between merges' } else { "$($entryTextsForHeadings.Count) unfolded entry(ies) plus CHANGELOG.md" })
# --- 13b. no branch document is left behind between branches -----------------------------------------------
# THE CHECK WAS INVERTED ON AUGUST 23, 2026 (Dave), AND THE THING IT PROTECTS DID NOT CHANGE. It used to hold
# the trunk's copy of development.md to the formatter byte-for-byte: a reference beside a scaffolder
# that writes the same shape is TWO SOURCES OF ONE FORMAT, which this repo has paid for repeatedly -- the
# scaffold wording, the fence readers, the tier sections. Before that it held two files under
# branch/templates/ for the same reason.
#
# THERE IS NO TRUNK COPY TO HOLD ANY MORE. The document exists for the lifetime of a branch: new-branch
# creates it, the fold removes it. So the drift this check existed to catch cannot happen -- a hand-edit to
# a reset copy needs a reset copy -- and what is worth asserting instead is the invariant that replaced it:
# NO DOCUMENT ANYWHERE DECLARES THE TRUNK. Absent is the trunk's normal state, a file naming this branch is
# work in progress, and a file naming the trunk is a leftover the fold should have taken.
#
# WHICH IS ALSO THE ONE STATE A CONSUMER CAN REACH BY DOING NOTHING WRONG, and the reason this reports the
# path rather than a shape. A repo updating from an older plugin has a trunk copy the previous fold wrote;
# their next fold removes it. Here, on the repo that owns the format, one should never survive a run.
#
# NO SHAPE IS ASSERTED, deliberately, and that is the cost of the inversion stated out loud. While a reset
# state existed there was one moment when the file was known-empty and could be compared to the formatter;
# a branch's file holds somebody's work and never can be. The scaffold gate and the step-list gate read the
# file's CONTENT on the way to the PR, so what is lost is the byte-comparison, not the coverage.
$btChecked = 0
$btStale = 0
if (Test-CheckEnabled 'branch-template') {
    # DOT-SOURCED INSIDE A SCRIPTBLOCK rather than at the top of the gate, deliberately. repo-config is not
    # loaded in this process anywhere else -- the one other check needing a repo-owned value spawns the script
    # that owns it -- and pulling two dozen repo functions into the whole lint to serve one check is how a gate
    # acquires a dependency nobody meant to give it. It is still dot-sourced now that no content is generated
    # here, because Get-BranchTrunkName reads a repo seam and answering it wrong would flip this check's verdict.
    $btState = & {
        $btCfg = Join-Path $RepoRoot 'scripts\repo-config.ps1'
        if (Test-Path -LiteralPath $btCfg) { . $btCfg }
        . (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
        # EVERY BRANCH DOCUMENT, NOT ONE PATH (#1255). This read the single shared name until the documents
        # were named per branch, at which point the one thing it exists to find -- a leftover -- became the
        # one thing it could no longer see: a stale document now sits at a name this check was not looking
        # at, and the run reported 'absent, which is the trunk between branches'. A gate that answers
        # 'nothing here' when it did not look is worse than no gate, so the subject is the SET.
        $btPaths = Get-BranchFilePaths
        $btRels  = @([string]$btPaths.SharedFile) + @(Get-PerBranchDocumentRels -RepoRoot $RepoRoot)
        $btDocs = @()
        foreach ($btRel in ($btRels | Select-Object -Unique)) {
            $btFull = Join-Path $RepoRoot ($btRel -replace '/', '\')
            if (-not (Test-Path -LiteralPath $btFull)) { continue }
            $btOnDisk = [System.IO.File]::ReadAllText($btFull, [System.Text.Encoding]::UTF8)
            $btDocs += [pscustomobject]@{
                Rel      = $btRel
                Declared = (Get-BranchFileDeclaredBranch -Text $btOnDisk)
            }
        }
        [pscustomobject]@{
            Docs  = $btDocs
            Trunk = (Get-BranchTrunkName)
        }
    }
    # ONE PER DOCUMENT, and 1 where there are none -- the absent case is still a thing this check ASSERTED,
    # so reporting 0 checks would read as 'not run'.
    $btChecked = [Math]::Max(1, @($btState.Docs).Count)
    foreach ($btDoc in @($btState.Docs)) {
        if (-not $btDoc.Declared) {
            $btStale = 1
            Add-Error "[branch-template] $($btDoc.Rel) exists but declares no branch in its heading. Every reader of this document -- the fold, the two local gates and the CI gate -- identifies a branch's work by that name, so a document without one belongs to nobody. Let new-branch.ps1 write it rather than creating it by hand."
        } elseif ($btDoc.Declared -eq $btState.Trunk) {
            $btStale = 1
            Add-Error "[branch-template] $($btDoc.Rel) names the trunk ('$($btState.Trunk)'), which is the empty state this repo no longer keeps. The document lives only while a branch is open -- new-branch.ps1 creates it and fold-changelog-entry.ps1 removes it -- so a trunk-declaring copy is a leftover from a fold that ran under the old behaviour. Delete it."
        }
    }
    Write-Coverage -Category 'branch-template' -Checked $btChecked `
        -Note $(if ($btStale -gt 0) { 'a document declaring the trunk was found where none should exist' } elseif (@($btState.Docs).Count -gt 0) { "present and declaring $((@($btState.Docs) | ForEach-Object { "'$($_.Declared)'" }) -join ', '), which is a branch in progress" } else { 'absent, which is the trunk between branches' })
} else {
    Write-Skip 'branch-template -- not run (-SkipCheck). Nothing is asserted about whether a branch document is left behind in this run.'
}

# --- 14. mojibake: a double-encoded character is a silent content change -----------------------------------
# MEASURED HERE, August 1, 2026, and it nearly shipped. Demoting four headings in CHANGELOG.md with
# Get-Content + WriteAllLines mangled 35 separators into 105 double-encoded sequences: Windows PowerShell
# 5.1's Get-Content reads a BOM-less UTF-8 file as ANSI, so a middot (U+00B7, bytes C2 B7) comes back as two
# characters, and writing that back as UTF-8 stores the mangled pair. Nothing errors -- the file stays valid
# UTF-8, it just says something else.
#
# WHY THIS IS A GATE AND NOT A CONVENTION. The middot IS the field delimiter in an entry heading
# ('### #NN <middot> title <middot> type <middot> date'), so cut-release.ps1 could no longer read the entry
# TYPE: eleven entries fell into a catch-all category instead of Features/Fixes/Documentation. It was caught
# by inspecting the generated notes before pushing (-NoPush), i.e. by one person looking carefully at the
# right moment -- which is precisely the thing not to rely on. Third repo to meet this class
# (smartwatchbanden -> life-hub -> here), and life-hub's own tool documents a v2.1.0 release that needed a
# manual fix for the same reason.
#
# The detector is the repair tool itself, run rather than restated: one source for "what does damage look
# like", so what the repair can fix and what the gate can see cannot drift apart.
#
# THAT SHARED SOURCE WAS ONCE SHARED BLINDNESS (August 2, 2026). While the tool worked off a hand-written
# table of known sequences, this gate inherited its coverage exactly -- and the table held only the
# single-layer form of most characters. 517 doubly-encoded runs across four files, three of them inside
# this check's own stated scope, were reported here as "No findings" for as long as they existed, and the
# damage rode into the v3.1.0 release notes and the consumer-facing RELEASE.md card. The tool now peels by
# the inverse operation instead of by enumeration, which is what makes this line an assertion again.
$mjChecked = 0
$mjScript = Join-Path $RepoRoot 'scripts\maintenance\fix-mojibake.ps1'
if (Test-Path -LiteralPath $mjScript) {
    # -Check reports and changes nothing; exit 1 = damage found. Run as a child process because the script
    # calls exit itself, and a lint gate must not be terminated by the tool it consults.
    #
    # Via Invoke-NativeCapture, not a bare '2>&1'. The first version used the bare form and this repo's own
    # shared-scripts guard caught it: under ErrorActionPreference=Stop a native command's stderr line
    # becomes a terminating NativeCommandError before the exit code is ever read (the #107 pitfall), so the
    # gate would have died on the tool's own output instead of reporting it.
    . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
    $mjRun = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $mjScript, '-Check')
    $mjOut = $mjRun.Output
    $mjCode = $mjRun.ExitCode
    $mjChecked = 1
    if ($mjCode -ne 0) {
        foreach ($line in @($mjOut | Where-Object { $_ -match '\[mojibake\]' })) {
            Add-Error ("[mojibake] " + ($line -replace '^\s*\[mojibake\]\s*', '') + " -- a UTF-8 character was read as ANSI and written back, so the file's text changed without any error. In an entry heading the separator IS the field delimiter, so cut-release.ps1 stops being able to read the entry type. Repair with scripts/maintenance/fix-mojibake.ps1; avoid it by never reading a non-ASCII file with bare Get-Content.")
        }
        if (@($mjOut | Where-Object { $_ -match '\[mojibake\]' }).Count -eq 0) {
            # NAME WHAT THE CHILD SAID, not only its exit code (#851). A non-zero exit with no [mojibake]
            # line means the sub-script never got to READ anything, and the likeliest cause has nothing to
            # do with encoding: the source-repo guard refusing the copy that was invoked. Measured
            # 2026-08-24, when this line reported 'the mojibake gate could not complete' for two lanes
            # whose trees were both clean -- a finding about the wrong subject, whose real explanation was
            # reachable only by running the sub-script by hand. The exit code alone cannot tell them apart,
            # so the child's own first line is quoted and a refusal is named when it is one.
            $mjWhy = @($mjOut | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
            $mjSaid = if ($mjWhy) { " It said: '$(([string]$mjWhy[0]).Trim())'" } else { ' It printed nothing.' }
            $mjHint = if (@($mjOut | Where-Object { $_ -match 'REFUSED:' }).Count -gt 0) {
                ' The sub-script REFUSED to run, so this is not about encoding: the copy invoked is not the one the repo being checked maintains. Run the gate from that repo, or from a worktree of it.'
            } else { '' }
            Add-Error ("[mojibake] scripts/maintenance/fix-mojibake.ps1 -Check exited $mjCode without naming a file -- the mojibake gate could not complete, so nothing is asserted about encoding." + $mjHint + $mjSaid)
        }
    }
} else {
    Add-Error "[mojibake] scripts/maintenance/fix-mojibake.ps1 is missing -- the encoding gate cannot run."
}

# THE COUNT IS FILES, NOT TOOL RUNS. It used to report 'checked 1' -- true of the invocation and useless
# as coverage, since the one number a reader wants here is how much was looked at. The tool states it on
# its own closing line; parsed rather than re-derived, so the gate cannot claim a scope the tool did not
# walk. A run that does not state it falls back to naming that, instead of quietly reporting 1.
$mjFiles = 0
if ($mjChecked -eq 1) {
    $mjMatch = [regex]::Match(($mjOut -join "`n"), '(\d+)\s+file\(s\)\s+examined')
    if ($mjMatch.Success) { $mjFiles = [int]$mjMatch.Groups[1].Value }
}
Write-Coverage -Category 'mojibake' -Checked $mjFiles `
    -Note $(if ($mjChecked -eq 0) {
        'the repair tool is absent, so no file was examined for double-encoded characters'
    } elseif ($mjFiles -eq 0) {
        'the repair tool ran but did not state how many files it examined, so this count is not evidence of scope'
    } else {
        'the set this repo names in Get-MojibakePaths (scripts/repo-config.ps1): every *.md in the root (the changelog and the root docs), every *.md under dkj-policy/ (the entry whose text is pasted into CHANGELOG.md, the step list, and the templates), plus every *.md under plugins/ and every note under releases/. Peeled by the inverse round trip rather than matched against a table of known sequences'
    })

# --- 15. unbound output samples: an expectation that cannot hold everywhere -------------------------------
# THE CLASS TEST ROUND v11 KEPT PRODUCING. Four of its nine findings were one shape: a captured sample
# handed to the reader as a fixed expectation, without saying what the capture was bound to.
#   #358  the bootstrap's 'Done:' line, captured in a repo that already had the script scaffolds, so the
#         third pair was inverted for the fresh repo the section was written for
#   #359  a CLI error string that CLI 2.1.220 no longer emits -- and whose replacement suggests a
#         different command than the procedure
#   #360  a byte baseline that was the LF figure, on a platform where every round measures the CRLF one
#   #361  a sender header the reader was told to look for, which no bootstrapped repo emits
# Individually four documentation fixes. Together a rule nobody was holding: an expectation is only
# checkable if the reader can tell when it does not apply to them.
#
# WHY THIS CAN BE A GATE AT ALL, where "is this prose accurate" cannot. The distinction it needs is
# already in the markup. A fenced block carrying a language (powershell, json, jsonc) is something to
# RUN; a fenced block with no language, or 'text', is something to COMPARE AGAINST -- and only the second
# kind can go stale under the reader. Measured before building: 34 fenced blocks across the two
# consumer-facing documents, of which exactly 4 are the second kind, and those 4 are precisely the
# findings above plus one instance the round missed. A check with a four-item haystack does not need a
# heuristic.
#
# AND IT MUST NOT BECOME A CHECK THAT PASSES BY BEING IGNORED. A fuzzy gate gets an opt-out pasted over
# every finding and then reports green while asserting nothing -- the exact failure mode of the mojibake
# table one check up. So the escape hatch is a visible marker that has to name a reason, and the coverage
# line below reports how many samples were examined rather than how many times the check ran.
$sampleChecked = 0
# THE CONSUMER-FACING SET, DECLARED ONCE. Checks 15 and 16 hold the same class of defect on the same three
# documents and differ only in where they look (inside a fence, or in the prose around it). Two copies of
# this list would drift the moment a fourth document joins -- which is check 16's own subject arriving in
# its source, so it is one variable shared by both.
# ADOPTION.md joined in #408, which is this comment's own warning arriving: the page renamed out from
# under 'QUICKSTART.md' carries every captured sample and measured figure these two checks exist for,
# and the new short QUICKSTART.md carried almost none. Listing only the old name would have left both
# checks reporting green over the document that actually holds their subject.
#
# THE TWO ARE ONE FILE AGAIN -- INSTALL.md, the short page as its first half -- so the set is
# three entries, not four. Note what the merge did to the failure mode this comment describes: while
# they were separate, naming the wrong one silently halved the coverage. Now there is one page and no
# wrong one to name, which is worth more than the entry it saved.
#
# AND THEN THEY WERE THREE AGAIN, on the audience seam rather than the length one (inbound #664,
# August 14, 2026). The adoption half became plugins/ADOPTION.md and the two plumbing pages moved to
# the repo root, so the set is four entries at three new paths. ADOPTION.md is the entry that matters
# most here, and this comment predicted exactly why: the captured samples and measured figures these
# two checks exist for -- the bootstrap's closing line, the 4+15+2 counts, the verification snippet --
# travelled WITH the adoption half. Listing only the pages that kept their names would have left both
# checks reporting green over the document that now holds their subject, for the second time.
$consumerDocs = @(
    'INSTALL.md',
    'UNINSTALL.md',
    'plugins\ADOPTION.md',
    'README.md'
)
# What counts as saying "here is what this is bound to". A version or a year pins the capture in time; the
# hedges pin it to a condition. Deliberately not 'measured' on its own -- that says the author saw it,
# which is exactly what was true of all four findings.
$bindingMarker = '(\d+\.\d+\.\d+)|(\b(19|20)\d{2}\b)|version-bound|varies|may differ|will differ|depends on|illustrative|not a fixed string|fresh repo|already present|whatever the phrasing|on Windows|CRLF'
# The opt-out has to NAME something. '(?!-->)' is the whole point: without it, the empty marker
# '<!-- unbound-sample: -->' satisfies '\S' on the comment terminator itself, and the escape hatch
# becomes a way to switch the check off rather than a way to record an exception.
$sampleOptOut  = '<!--\s*unbound-sample:\s*(?!-->)\S'
# A NAMED DOCUMENT THAT IS NOT THERE IS A FINDING, NOT A SKIP -- and this is the repair for how the
# defect above stayed invisible rather than for the defect itself. Both loops below open their file with
# a 'Test-Path ... { continue }', so a stale entry in the list costs coverage and says nothing: checks 15
# and 16 simply examine less and still report green. Measured on the move into plugins/: expected-output
# went 5 -> 1 and measured-figure 11 -> 0 in one commit, with no error anywhere, and it surfaced only
# because somebody happened to read the coverage line.
#
# Validated ONCE here rather than inside each loop, so a missing document is reported once instead of
# per reader -- two findings for one cause read as two causes.
foreach ($rel in $consumerDocs) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $rel))) {
        Add-Error "[consumer-doc] '$rel' is named in the consumer-facing set but does not exist -- checks 15 and 16 skip it in silence, so their coverage is lower than it looks. Either the document moved (update the list) or it is gone (drop the entry)."
    }
}
foreach ($rel in $consumerDocs) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $lines = [System.IO.File]::ReadAllLines($full, [System.Text.Encoding]::UTF8)
    $open = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not (Test-FenceDelimiterLine -Line $lines[$i])) { continue }
        if ($open -lt 0) { $open = $i; continue }
        $close = $i
        $lang = ($lines[$open] -replace '^\s*```', '').Trim().ToLowerInvariant()
        $open2 = $open; $open = -1
        # A block with a language is a command to run, not an expectation to match.
        if ($lang -ne '' -and $lang -ne 'text') { continue }
        # AND A DIAGRAM IS DRAWN, NOT CAPTURED. The class is text a tool emitted, which can therefore
        # emit something else tomorrow; a directory tree is authored by the writer and goes stale only
        # when the writer changes it. The seam diagram in README.md was this check's first false
        # positive, and box drawing is what separates the two without a judgement call. Named here and
        # in the coverage line rather than left as a silent narrowing -- an exclusion nobody can see is
        # how a gate quietly stops covering what it claims.
        # Built from codepoints, never written as literal box-drawing characters. This file is read by
        # Windows PowerShell 5.1, which takes a BOM-less UTF-8 script as ANSI -- writing the range
        # literally mangled it into a broken character class on the first run, which is check 14's own
        # subject arriving in check 15's source.
        $body = if ($close -gt $open2 + 1) { ($lines[($open2 + 1)..($close - 1)] -join "`n") } else { '' }
        $boxDrawing = '[' + [char]0x2500 + '-' + [char]0x257F + ']'
        if ($body -match $boxDrawing) { continue }
        $sampleChecked++
        # The window: the paragraph that introduces the sample, and the prose that follows it. Bounded
        # rather than section-wide on purpose -- a version number three screens away in another
        # subsection is not something the reader of THIS block is going to connect to it.
        # THE SAMPLE'S OWN BODY IS NOT CONTEXT. Caught by the first test written against this check: a
        # block whose text happened to contain 'already present' satisfied the binding with its own
        # content, so the very sample under examination vouched for itself. The binding has to be
        # something the DOCUMENT says about the sample, never something the sample says.
        $from = [Math]::Max(0, $open2 - 5)
        $to   = [Math]::Min($lines.Count - 1, $close + 14)
        $before = if ($open2 -gt $from) { ($lines[$from..($open2 - 1)] -join "`n") } else { '' }
        $after  = if ($to -gt $close) { ($lines[($close + 1)..$to] -join "`n") } else { '' }
        $context = $before + "`n" + $after
        if ($context -match $sampleOptOut) { continue }
        if ($context -notmatch $bindingMarker) {
            Add-Error "[expected-output] ${rel}:$($open2 + 1) -- a fenced block with no language is a sample the reader compares against, and nothing near it says what the capture is bound to (a CLI version, a date, a platform, a repo state, or a hedge such as 'varies' / 'illustrative'). Four of test round v11's nine findings were exactly this. Name the binding, or mark the block deliberate with '<!-- unbound-sample: <reason> -->'."
        }
    }
}
Write-Coverage -Category 'expected-output' -Checked $sampleChecked `
    -Note 'captured output samples in the consumer-facing docs -- language-less or text-tagged fenced blocks, i.e. the ones a reader compares against rather than runs. Two kinds are deliberately not examined and both are stated rather than assumed: blocks tagged powershell/json/jsonc (commands to run) and blocks containing box drawing (diagrams, which are drawn rather than captured)'

# --- 16. A measured figure in prose names what it was measured on -----------------------------------------
# CHECK 15'S SUBJECT, ONE STEP OUTSIDE ITS REACH. Check 15 holds captured samples inside fenced blocks,
# because a fence is a markup boundary a gate can see. Test round v12 found the same defect class in
# running prose, where there is no fence:
#   #374  "never literally clean" -- true of a user-scope declaration, written as true of every reader
#   ---   the same over-generalisation one section down, carrying three byte figures from a single machine
#         (~/.claude/settings.json at 22 bytes) on a profile where that file had never existed
# The figures were accurate when captured. What was missing is the sentence saying whose machine they came
# from, and without it a reader whose own numbers differ cannot tell whether they mis-installed or the page
# is stale. Round v12's step-0 table came back fully clean against a page that said clean was impossible.
#
# WHY THIS ONE IS GATEABLE WHERE "IS THIS PROSE ACCURATE" IS NOT. It does not judge the claim; it judges
# whether a binding is present near a figure whose SHAPE is unambiguous. A byte count or a file size is
# always a measurement of something -- there is no authored, non-measured reason to write "939,860 bytes"
# -- so the haystack needs no heuristic to identify. Measured before building, exactly as check 15 was:
# 9 figures across 8 lines in the three consumer-facing documents. A haystack that small is enumerable, and
# the check was run against it before the rule was written rather than after.
#
# THE WINDOW IS THE PARAGRAPH NEIGHBOURHOOD, NOT A LINE COUNT. A figure in a table row is bound by the
# paragraph introducing the table, which sits an arbitrary number of rows above; a figure in prose is bound
# by its own sentence. Both are "the block this line is in, plus the block either side", so that is the
# window -- it adapts to a 3-row table and a 12-row one without a magic number, and it stops at a blank
# line rather than wandering into an unrelated subsection.
#
# 'measured' IS DELIBERATELY NOT A BINDING, for the same reason check 15 rejects it: it says the author saw
# the number, which was true of every finding this check exists for. The binding has to pin the figure to a
# time, a version, a platform, or a stated condition.
$figureChecked = 0
# A digit immediately before the unit is what makes this a measurement rather than a word. 'byte-identical'
# carries no leading number and is therefore not a figure, which is the distinction the leading \d makes.
$figurePattern = '\d[\d,]*(\.\d+)?\s*(bytes?|KB|MB|GB)\b'
# What counts as pinning a figure down: a year or a date, a test round, a semver, a named machine state, or
# an explicit hedge. Kept close to check 15's list so the two gates teach the writer one habit, not two.
$figureBinding = '(\b(19|20)\d{2}\b)|(round v\d+)|(\d+\.\d+\.\d+)|virgin|fresh profile|clean machine|before adoption|a profile that|varies|may differ|will differ|depends on|illustrative|approximately|roughly'
$figureOptOut  = '<!--\s*unbound-figure:\s*(?!-->)\S'
foreach ($rel in $consumerDocs) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $lines = [System.IO.File]::ReadAllLines($full, [System.Text.Encoding]::UTF8)
    # Fenced blocks belong to check 15. Counting them here would double-report the same sample and would
    # also flag command output that is deliberately verbatim.
    $inFence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (Test-FenceDelimiterLine -Line $lines[$i]) { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($lines[$i] -notmatch $figurePattern) { continue }
        $figureChecked++
        # The block this line sits in ...
        $bStart = $i; while ($bStart -gt 0 -and $lines[$bStart - 1].Trim() -ne '') { $bStart-- }
        $bEnd = $i; while ($bEnd -lt $lines.Count - 1 -and $lines[$bEnd + 1].Trim() -ne '') { $bEnd++ }
        # ... plus the block before it (an intro paragraph above a table) ...
        $pEnd = $bStart - 1; while ($pEnd -gt 0 -and $lines[$pEnd].Trim() -eq '') { $pEnd-- }
        $pStart = $pEnd; while ($pStart -gt 0 -and $lines[$pStart - 1].Trim() -ne '') { $pStart-- }
        # ... and the block after it (a note below a table saying which column came from where).
        $nStart = $bEnd + 1; while ($nStart -lt $lines.Count -and $lines[$nStart].Trim() -eq '') { $nStart++ }
        $nEnd = $nStart; while ($nEnd -lt $lines.Count - 1 -and $lines[$nEnd + 1].Trim() -ne '') { $nEnd++ }
        $from = [Math]::Max(0, $pStart)
        $to   = [Math]::Min($lines.Count - 1, $nEnd)
        $context = ($lines[$from..$to] -join "`n")
        if ($context -match $figureOptOut) { continue }
        if ($context -notmatch $figureBinding) {
            Add-Error "[measured-figure] ${rel}:$($i + 1) -- a byte count or file size in prose is a measurement of somebody's machine, and nothing in the surrounding paragraphs says whose (a date, a test round, a CLI version, a named profile state, or a hedge such as 'varies' / 'approximately'). Round v12 filed exactly this as #374: a reader whose own number differs cannot tell whether they mis-installed or the page went stale. Name the binding, or mark it deliberate with '<!-- unbound-figure: <reason> -->'."
        }
    }
}
Write-Coverage -Category 'measured-figure' -Checked $figureChecked `
    -Note 'byte counts and file sizes in the PROSE of the consumer-facing docs -- the same staleness class as check 15, outside a fence where no markup marks it. Figures inside fenced blocks are deliberately not counted here: those are check 15''s, and counting them twice would report one sample as two'

# RETIRED, AUGUST 8, 2026 -- check 17 ("the per-plugin CHANGELOG intro still matches its template").
# It existed because that intro was write-once: it reached a file at creation and was never rewritten,
# so all four per-plugin CHANGELOGs kept naming the retired marketplace long after the rename had swept
# it out of 59 files. The check was the right repair for a real defect. The files it guarded are gone,
# and with them the write-once text -- see the retirement note in scripts/lib/release-lib.ps1. The
# LESSON survives in that file's header, because it is about the next template, not about these.
# --- 18. a shared script's parameters appear in the skill that documents it -----------------------
# A consumer has exactly two things: the plugin mirror of a script, and the skill that describes it. So a
# parameter the skill never names is, for them, a parameter that does not exist -- including the escape
# valve they need when something goes wrong.
#
# THIS IS A REPAIR, NOT A PRECAUTION. Measured August 4, 2026: the fold-changelog skill told every consumer
# to commit the fold BY HAND for two days after the script gained -Commit/-Push, because that improvement
# had been written into this repo's lens instead. Looking for siblings found three more -- cut-release's
# -NoPush and -SkipLint, and new-internal-note's -RepoRoot -- and -NoPush is the one inspection step before
# a release is pushed, the step that catches the '##-climbs-out-of-its-category' defect. The cause is
# structural: a parameter is added to a script, its reason goes into a lens or a commit message, and the
# skill follows nobody.
#
# The Skill mapping and the per-parameter exemptions live in the registry
# (scripts/lib/shared-scripts-lib.ps1), next to the registration, for the reason its own LibOnly comment
# gives: a second hand-written list is one a newly shared script falls out of silently.
$skillParamChecked = 0
$skillDocumented = 0
$skillGaps = @()
foreach ($pair in $sharedPairs) {
    if ($pair.LibOnly) { continue }
    # A missing SOURCE is check 8's finding, not this one's -- it already says so, and there are no
    # parameters to read anyway. Skipping keeps this check quiet against a minimal fixture (where none of
    # the registered scripts exist) instead of reporting every skill as absent.
    if (-not (Test-Path -LiteralPath $pair.SourcePath)) { continue }
    # $null = LibOnly/not applicable; '' = an entry point declaring it has no skill. Only the second is
    # reportable, and it is reported as coverage rather than as an error: writing a missing skill is its
    # own piece of work, and failing the gate over it would block every unrelated PR until someone did.
    if ([string]::IsNullOrEmpty($pair.Skill)) { $skillGaps += $pair.Name; continue }

    # SkillRel, not a hardcoded 'plugins\specialists\...' path. The registry derives it from the
    # mirror, so a script that moves to another plugin takes its page lookup with it. Measured on
    # August 8, 2026 during the workflow split: with the path hardcoded here, all nine moved entry
    # points reported their existing skill as a typo.
    $skillPath = Join-Path $repoRoot $pair.SkillRel
    if (-not (Test-Path -LiteralPath $skillPath)) {
        Add-Error "[skill-param] $($pair.SourceRel) names skill '$($pair.Skill)' in the shared-scripts registry, but $($pair.SkillRel -replace '\\', '/') does not exist. Either the skill was renamed or moved to another plugin (update the registry) or the mapping is a typo."
        continue
    }
    $skillText = Get-Content -LiteralPath $skillPath -Raw
    $params = Get-ScriptParameterNames -Path $pair.SourcePath
    foreach ($p in $params) {
        if ($pair.SkillParamsExempt -contains $p) { continue }
        $skillParamChecked++
        # Matched as '-Name' on a word boundary: that is how a reader would type it, and it avoids
        # crediting a bare prose mention of the word.
        if ($skillText -notmatch ('-' + [regex]::Escape($p) + '\b')) {
            Add-Error "[skill-param] $($pair.SourceRel): parameter -$p is documented nowhere in the '$($pair.Skill)' skill, so a consumer who has the mirror plus that page cannot know it exists. Add it, or -- if a consumer genuinely never types it -- register it in SkillParamsExempt with the reason."
        }
    }
    $skillDocumented++
}
$gapNote = if ($skillGaps.Count -gt 0) { " NOT covered, because they declare no skill in the registry: $($skillGaps -join ', ')." } else { '' }
Write-Coverage -Category 'skill-param' -Checked $skillParamChecked `
    -Note "parameters of the $skillDocumented shared entry point(s) that name a documenting skill, held against that skill's text -- a consumer has only the mirror and its page, so an undocumented parameter does not exist for them. Read via the PowerShell parser, not a regex, which missed an attributed parameter when this was first measured. Exemptions are declared per script in the registry.$gapNote"

# --- 20. a document claiming how many sections an entry has is held to the scaffolder ---------------
# Numbered 20 and not 19: the consumer-doc guard above carries no numbered header of its own, but the suite
# already calls it check 19, and two checks answering to one number is how a finding gets discussed as the
# wrong one.
# ISSUE #508 MEASURED THE PROBLEM: the entry format is described in about ten hand-maintained places against
# two that cannot drift (the templates, held by check 13b, and the scaffolder itself). Two documents were
# found stale during a sweep that was actively looking, one of them consumer-facing.
#
# THE RULE WAS CHOSEN BY MEASUREMENT, NOT BY REASONING, and three earlier candidates were rejected by it:
#
#   >=2 section NAMES together, one of them retired          -> 6 findings on the tree, ALL SIX FALSE
#   the same, minus units that mark the name as history      -> 3 findings, 2 false
#   fenced skeleton blocks only                              -> 0 findings, but covers 1 of 3 known drifts
#   a claimed section COUNT vs the scaffolder's              -> 4 claims, 3 correct, 1 genuinely stale
#
# The name-matching candidates fail on a collision nobody would predict: 'What does this change do?' and
# 'Type of change' are RETIRED entry sections and, AT THE TIME THIS WAS MEASURED, live headings of
# .github/pull_request_template.md. So a name-matcher accuses two correct documents of being stale for
# describing the PR body accurately -- and a check that is born red with an exemption list is the shape
# this repo was already bitten by (Get-RosterIgnoredIds).
#
# THAT COLLISION IS GONE, AND THE MEASUREMENT STANDS ANYWAY (#538, August 9, 2026). Both headings were
# removed from the PR template that day, so the six false findings are no longer reproducible from the
# tree. The tense above is deliberate rather than tidied away: it names WHEN the count was measured
# against the names, which is the only form in which a superseded measurement is still worth anything.
# Two reasons the conclusion does not move with the collision. First, name-matching lost on more than
# that: it also scored 3 findings with 2 false on the narrowed variant, against 4 claims with 3 correct
# for the count. Second, and structurally, a rule keyed on names is one rename away from silence in
# either direction -- which is precisely what just happened to the collision, and would just as easily
# happen to a match the check depends on. The count is a fact the scaffolder owns and no rename touches.
#
# A COUNT HAS NONE OF THAT. It is a fact the scaffolder owns, stated in a form that cannot mean anything
# else, and both recorded drifts made exactly this claim -- "three named `###` sections" -- while the
# scaffolder had moved to six. So this judges the one thing a document says about the shape that is
# checkable without judging its prose, which is the same line checks 15 and 16 draw.
#
# THE LEVEL MARKER IS REQUIRED IN THE TREE PASS, and that is what keeps the haystack honest across ~200
# files. (The one place it is not required is CHANGELOG.md's intro, a dozen lines with its own pass -- the
# block below states what that costs and why it costs nothing there.) Without it the pattern matches
# "one section apart", "two sections went in the same movement", "one section per tier" -- ordinary prose
# about anything, 18 disagreements of which 17 were noise. Requiring the '###' (backticked or not) between
# the number and the word narrows it to four claims in the whole tree, which is a haystack small enough to
# read by hand -- and it was, before this was written.
#
# History is excluded exactly as checks 11 and 12 exclude it: CHANGELOG.md's ENTRIES and the per-plugin
# copies, the release notes, RELEASE.md, and the branch's own document, which is history in the making.
# dkj-policy/CONTRIBUTING.md is deliberately NOT excluded -- it is a document ABOUT the shape,
# which is precisely this check's subject. Two pages used to carry that role and both are gone into it:
# branch/README.md at the merge on August 23, 2026, and this folder's own CLAUDE.md on August 26 (#886).
# One page now, and the check reaches it the same way.
#
# AND NEITHER IS CHANGELOG.md'S INTRO (August 8, 2026). It went out with the rest of that file on the history
# grounds above, and this repo had already written down why that reasoning does not reach the intro:
# release-lib.ps1 was bitten by it on the per-plugin CHANGELOGs and recorded the lesson one screen above the
# code -- "the entries below the intro were history, the intro was a live statement about the present
# mechanism". A cut empties this document down to that intro and carries it through verbatim, so it is the
# one piece of prose in the repo that no release ever rewrites and no reviewer ever opens. Measured on the
# day this was written: it claimed THREE sections while the scaffolder wrote six, and had done so since
# August 6 -- two days, one release, and a consumer-facing release page in between.
#
# TWO THINGS KEPT IT OUT OF REACH, and repairing either one alone leaves it unchecked:
#
#   1. the file was excluded, so nothing read the intro at all;
#   2. the pattern would have walked past it anyway -- the intro wrote "three named sections" with no '###'
#      in the sentence, and it wrote it ACROSS A LINE BREAK.
#
# So the head is judged by its own pass, with the level marker OPTIONAL, and the matching for both passes
# moves from per-line to whole-text. Both were chosen by measuring rather than by argument:
#
#   strict, per line, over the scanned tree   -> 4 claims   (what this check did)
#   strict, whole text, over the scanned tree -> 4 claims   (identical -- the 3 extra it finds sit in the
#                                                            history this check already excludes)
#   loose, whole text, over the whole tree    -> 50 claims  (the documented noise -- 46 of them)
#   loose, whole text, over the intro alone   -> 1 claim    (the real one, before and after the repair)
#
# The marker therefore keeps earning its place everywhere it was measured to earn it, and nowhere else: it
# guards ~200 files against 46 false hits, while the intro is a dozen lines this repo owns, where relaxing it
# costs nothing and is the whole difference between catching the drift and not. Whole-text matching changes
# nothing about what the tree pass reports -- it only closes the blind spot where a reflowed sentence hides a
# claim, which is a formatting accident no author would think of as a bypass.
# THE WRITTEN COUNT, NOT THE RECOGNISED ONE (August 16, 2026). Get-EntrySectionHeadings answers "which
# heading does key X have" for every key that ever existed, retired ones included, so counting its keys
# would hold a document to a shape the scaffolder stopped producing -- and accuse a correct page of being
# stale. Get-EntryWrittenSectionKeys is the shape a reader actually meets.
#
# AND IT IS DELIBERATELY NOT READ THROUGH repo-config, unlike check 16's own generation one screen up. That
# was tried on August 19, 2026, while the audience tier's heading was briefly a third '###' section, and
# reverted with it: the count is a property of the FORMAT rather than of the repo, so pulling two dozen repo
# functions in here to answer it would be a dependency bought for nothing.
$scExpected = @(Get-EntryWrittenSectionKeys).Count
$scLevel = Get-EntrySectionLevel
$scWords = @{ 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7; 'eight' = 8; 'nine' = 9; 'ten' = 10 }
$scNumRx = '(?<n>\d+|one|two|three|four|five|six|seven|eight|nine|ten)'
$scMarkerRx = "``?#{$scLevel}``?\s+"
$scClaimRx = "(?i)${scNumRx}\s+(?:named\s+)?${scMarkerRx}section"
$scHeadClaimRx = "(?i)${scNumRx}\s+(?:named\s+)?(?:${scMarkerRx})?section"

function Test-EntryShapeClaims {
    <#
        Reports every claim in $Text that disagrees with the scaffolder, and returns how many claims it
        read -- so an empty file and a clean one stay distinguishable in the coverage line.

        Matching is over the WHOLE text rather than line by line, so '\s+' spans the line break a markdown
        reflow puts in the middle of the sentence. The line number is then derived from the match offset
        rather than from a loop counter, which is the only bookkeeping that change costs.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Rel,
        [Parameter(Mandatory)][string]$Rx
    )
    $seen = 0
    foreach ($m in [regex]::Matches($Text, $Rx)) {
        $raw = $m.Groups['n'].Value.ToLowerInvariant()
        $claimed = if ($scWords.ContainsKey($raw)) { $scWords[$raw] } else { [int]$raw }
        $seen++
        if ($claimed -ne $scExpected) {
            $lineNo = 1 + ([regex]::Matches($Text.Substring(0, $m.Index), "`n")).Count
            Add-Error "[entry-shape] ${Rel}:${lineNo}: says an entry has $claimed '$('#' * $scLevel)' sections, and the scaffolder writes $scExpected. The shape has one source (Get-EntrySectionHeadings); a document that states a count is stating a fact it does not own, so either the prose is stale or the format moved without this page. Naming the sections is fine -- the COUNT is what is held here."
        }
    }
    return $seen
}

$scFiles = @($linkFiles | Where-Object {
    $rel = $_.Substring($RepoRoot.Length).TrimStart('\', '/')
    if ($rel -eq $changelogRelWin) { return $false }
    if ($rel -match '\\CHANGELOG\.md$') { return $false }
    if ($rel -match '(^|\\)RELEASE\.md$') { return $false }
    if ($rel -match '^releases\\') { return $false }
    # The moved release pages are the same history at their workflow-folder address (August 14, 2026).
    if ($rel -match '^dkj-policy\\releases\\') { return $false }
    if (($rel -notmatch '\\') -and (Test-IsChangelogEntryFile -Path $_)) { return $false }
    # The branch's own document only -- NOT the whole folder. It is history in the making above and a scratch
    # pad below; the folder's own pages are the convention itself and are checked.
    #
    # SEPARATORS ARE NORMALISED, and leaving that out was caught by this check on its first run:
    # Get-BranchFilePaths returns forward slashes while $rel is built from a
    # Windows path, so the two never compared equal and the exclusion did nothing. The step list of the very
    # branch that added this check was then reported for QUOTING a stale count while explaining it.
    $scPaths = Get-BranchFilePaths
    $scBranchFiles = @($scPaths.File, $scPaths.LegacyCycle, $scPaths.LegacyDeployment,
        $scPaths.OlderCycle, $scPaths.OlderDeployment) |
        ForEach-Object { $_ -replace '/', '\' }
    if ($scBranchFiles -contains $rel) { return $false }
    return $true
})

$scChecked = 0
foreach ($sf in ($scFiles | Sort-Object -Unique)) {
    $rel = $sf.Substring($RepoRoot.Length).TrimStart('\', '/')
    $scChecked += Test-EntryShapeClaims -Rel $rel -Rx $scClaimRx `
        -Text ([System.IO.File]::ReadAllText($sf, [System.Text.Encoding]::UTF8))
}

# The intro of CHANGELOG.md, derived the way check 13 and Split-Changelog derive it: everything above the
# first entry heading, fence-masked so an intro that QUOTES an entry heading -- this one documents the entry
# format, so it does -- cannot move the boundary into the middle of a code block.
#
# A changelog with NO entry is not a special case here: the head is then the whole file, which is exactly
# right. That is the normal state between a cut and the next merge, and it is the state the intro is most
# alone in. Split-Changelog throws there, deliberately (a cut with no entries describes nothing), which is
# why the boundary is derived here rather than borrowed from it -- a gate that threw in a legitimate state
# would take the whole lint down with it.
$scChangelog = $changelogFull
if (Test-Path -LiteralPath $scChangelog) {
    $scClLines = (Get-FenceMaskedText -Text ([System.IO.File]::ReadAllText($scChangelog, [System.Text.Encoding]::UTF8))) -split "`r?`n"
    $scHeadEnd = $scClLines.Count
    for ($i = 0; $i -lt $scClLines.Count; $i++) {
        if ($scClLines[$i] -match ('^#{' + $ehEntryLevel + '}\s')) { $scHeadEnd = $i; break }
    }
    $scHeadText = if ($scHeadEnd -gt 0) { (@($scClLines[0..($scHeadEnd - 1)])) -join "`n" } else { '' }
    $scChecked += Test-EntryShapeClaims -Rel $changelogRel -Rx $scHeadClaimRx -Text $scHeadText
}

Write-Coverage -Category 'entry-shape' -Checked $scChecked `
    -Note "claim(s) about how many '$('#' * $scLevel)' sections a changelog entry has, held against the $scExpected the scaffolder writes. The rule is the COUNT and not the section NAMES, chosen by measuring four candidates against this tree: matching names accuses two correct documents, because 'What does this change do?' and 'Type of change' are retired entry sections AND live headings of the PR template. History is excluded as in checks 11 and 12; dkj-policy/branch/README.md is not, being a document about the shape, and neither is CHANGELOG.md's INTRO -- the entries below it are history, the intro is a live statement about the present mechanism that every cut copies through verbatim, so it gets its own pass with the level marker optional"

# --- 21. The config blueprint matches what the source's own libs say right now -----------------------------
#
# The blueprint (the workflow plugin's blueprint/config-blueprint.json) is what a
# consumer adopts its workflow config FROM: the source's own answers, with the reasoning that produced
# them. It is generated from scripts/repo-config.ps1, scripts/lib/branch-info.ps1 and the contract
# registry -- so the moment any of those three changes, the shipped artefact describes a repo that no
# longer exists.
#
# HELD BY REGENERATING IT, not by inspecting it. The generator is the only thing that knows the answer,
# so a check that re-derived the comparison would be a second implementation free to disagree with the
# first -- the shape this repo keeps paying for. Same mechanism as the shared-scripts drift check
# (check 9): build in memory, compare, report.
#
# WHY THIS DEFECT WOULD BE INVISIBLE OTHERWISE: nothing in the repo reads the artefact. A stale one
# breaks nothing here, passes every other check, and is discovered by a consumer adopting last week's
# answers under this week's explanations -- which is worse than no blueprint, because it carries a
# citation.
#
# Run through Invoke-NativeCapture rather than a bare '2>&1', which this repo forbids and its own suite
# scans for: in Windows PowerShell 5.1 redirecting a native command's stderr wraps each line in an
# ErrorRecord and sets $? to $false even on exit code 0. Caught by shared-scripts.tests.ps1 on the first
# draft of this very check.
$bpChecked = 0
$bpScript = Join-Path $repoRoot 'scripts\sync\build-config-blueprint.ps1'
if (Test-Path -LiteralPath $bpScript -PathType Leaf) {
    $bpChecked = 1
    . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
    $bpRun = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bpScript, '-Check')
    if ($bpRun.ExitCode -ne 0) {
        Add-Error "[config-blueprint] $(($bpRun.Output | Out-String).Trim())"
    }
}
Write-Coverage -Category 'config-blueprint' -Checked $bpChecked `
    -Note 'the shipped config blueprint, held against a fresh generation from this repo own libs and the contract registry. Regenerated rather than inspected: the generator is the only thing that knows the answer, so a second implementation here could only disagree with it. Nothing in this repo READS the artefact, which is exactly why it needs a gate -- a stale one breaks nothing here and hands a consumer last week answers under this week explanations'

# --- 22. a skill's own command must not point at the author's disk ----------------------------------------
# A shipped SKILL.md tells a consumer what to RUN. The path in that command therefore has to resolve on
# THEIR machine, and '${CLAUDE_PLUGIN_ROOT}' is what does it -- the plugin root, substituted when the skill
# runs, which is why the other pages already use it.
#
# THE MEASURED DEFECT: adopt-config's page shipped in v3.8.0 with both of its commands written as
# 'C:/Users/<the author>/.claude/plugins/cache/.../3.8.0/scripts/...'. Wrong for every consumer twice over
# -- a different username, often a different OS -- and pinned to a version that goes stale at the next
# release. It was the newest skill page and the only one of eleven that did not use the substitution, and
# it was the first command a consumer runs to use the release's headline feature.
#
# WHY THE RULE IS ABOUT COMMANDS AND NOT ABOUT PATHS, which is the obvious shape and was measured first: a
# tree-wide "no absolute paths in plugins/" rule is born with THREE findings and all three are correct
# prose -- comments in check-report-lib and check-roster-sync that quote 'C:\Users\x\.claude\...' precisely
# to explain a path-mangling bug. A check that needs an exemption list on its first run is the shape this
# repo already has scar tissue from, so the subject is the '-File' argument of a runnable command instead.
# Measured over the 26 invocations in the 11 shipped skill pages: 23 use the substitution and 3 use the
# '<plugin>' placeholder, which passes deliberately -- angle brackets tell a reader to substitute, while an
# absolute path reads as a command to paste. Zero exemptions, and it would have caught the defect on the
# day it was written.
$skillCmdChecked = 0
$skillPagesDir = Join-Path $RepoRoot 'plugins'
if (Test-Path -LiteralPath $skillPagesDir -PathType Container) {
    $skillPages = @(Get-ChildItem -Path $skillPagesDir -Recurse -Filter 'SKILL.md' -File)
    foreach ($page in $skillPages) {
        $lines = Get-Content -LiteralPath $page.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            # Only a '-File <path>' argument: that is the one token a reader is told to execute.
            $m = [regex]::Match($lines[$i], '-File\s+"(?<path>[^"]+)"')
            if (-not $m.Success) { continue }
            $skillCmdChecked++
            $p = $m.Groups['path'].Value
            # Absolute = a drive letter, a POSIX root, or a home shortcut. Everything else is either the
            # substitution or a signposted placeholder, and both are honest about needing resolution.
            if ($p -match '^([A-Za-z]:[\\/]|[\\/]|~)') {
                $rel = $page.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
                Add-Error ("[skill-command] {0}:{1}: the command points at an absolute path ('{2}'), which resolves only on the machine it was written on. Use `${{CLAUDE_PLUGIN_ROOT}}/... so it resolves in the consumer's own plugin install." -f $rel, ($i + 1), $p)
            }
        }
    }
}
Write-Coverage -Category 'skill-command' -Checked $skillCmdChecked `
    -Note "the '-File' argument of every runnable command in the shipped skill pages, held against being machine-specific. The subject is the COMMAND and not the path, chosen by measuring: a tree-wide absolute-path rule is born with three findings, all three correct comments that quote a user path in order to explain a path-mangling bug. A '<plugin>' placeholder passes on purpose -- angle brackets ask the reader to substitute, an absolute path reads as a line to paste"

# --- 23. a plugin's name says which kind it is, and it must sit where that says ---------------------------
# WHAT THIS CHECK IS FOR, RESTATED (August 26, 2026, issue #886) BECAUSE ITS ORIGINAL REASON EXPIRED.
# From August 9, 2026 the prefix was a MECHANISM: the core team's workflow-sessioncheck decided what
# counted as a workflow by asking whether the plugin's name started with 'workflow-', so a workflow
# named otherwise would never be counted and two could be enabled in silence. That hook and the
# exclusivity rule it enforced were RETIRED with workflow-default, so that argument is gone and is not
# quietly left standing here -- a check whose stated reason no longer holds is worse than one with no
# comment, because the next reader trusts it.
#
# THE TEETH THAT SURVIVE, and they are this check's own. The two halves are not independent: the
# DIRECTORY rule is DERIVED FROM THE NAME. A plugin whose name matches no team or way-of-working shape
# falls through every branch below, so its location is never held against anything -- an unclassifiable
# name does not merely read untidily, it switches this check off for that plugin, silently and for as
# long as nobody counts the Checked total against the published set. That is why the else-branch is an
# error and not a style note, and the reason is now internal to the check rather than borrowed from a
# hook in another plugin.
#
# ANCHORED ON THE PUBLISHED SET, so a directory that is not a plugin is not held to a rule about
# plugins. That is what lets plugins/dkj-subagents/subagent-shared/ sit beside the teams it feeds without being
# read as a team whose name is missing its 'team-' prefix -- it is in no marketplace, so this loop
# never sees it. Worth knowing before anyone hardens the directory half into a filesystem sweep:
# 'every directory under plugins/dkj-subagents/ is named team-*' is a DIFFERENT check from this one, and it
# would be false the moment it was written.

# SEVERAL NAME SHAPES MAP TO THE SAME KIND SINCE AUGUST 26, 2026 (#886), AND THAT IS DELIBERATE.
# 'contributing-davekjohn' was renamed from 'workflow-davekjohn' because that is what it does: it serves
# one owner's contributing rules, not a workflow among several. '*-codex' joined the same way on
# September 1, 2026, when 'workflow-bwj' was renamed 'bwj-codex' -- a codex is a body of law, i.e. a way
# of working, and the leading word names whose. '*-policy' / '*-policy-*' joined on September 5, 2026
# (#1437), when 'contributing-davekjohn' became 'dkj-policy' and 'bwj-codex' became 'dkj-policy-bwj':
# a policy IS a way of working, the leading word says whose, and the trailing one -- where there is one --
# says which ministry under it. THE RETIRED SHAPES STAY ACCEPTED rather than being swapped out, which is
# this repo's standing answer to a rename (#952): a consumer who has not migrated still resolves a
# 'contributing-*' plugin, and a check that recognised only today's spelling would report their working
# install as unclassifiable.
#
# THE DIRECTORY NO LONGER NAMES THE KIND, AND ONLY THE POLICY FAMILY HAS A DIRECTORY RULE LEFT
# (#1467, September 5, 2026). plugins/workflows/ used to hold the KIND -- a way of working -- with the
# rest of the name saying whose it is, and Dave kept that directory name through #886 (decision A on that
# issue). #1467 renamed it to plugins/dkj-policy/ and lifted the prime ministry's own files to its root,
# so the directory now names the GOVERNMENT: 'dkj-policy' at plugins\dkj-policy, and every other ministry
# one level inside it ('dkj-policy-bwj' at plugins\dkj-policy\dkj-policy-bwj). That is what the anchored
# '^plugins\\dkj-policy($|\\)' below says, and the '($|\\)' is load-bearing rather than tidy: a bare
# prefix would also accept a sibling directory merely beginning with the same characters, which is a
# different plugin family and not a ministry.
#
# AND THE OTHER THREE SHAPES KEEP THE NAMING HALF ONLY, because there is no directory left to hold them
# to. 'workflow-*' is what a plugin from anybody else would be called, and refusing it would make this
# family's renames somebody else's problem -- but pointing it at plugins/dkj-policy/ would be worse than
# saying nothing: it would order a stranger's workflow into this government. So they fall through with no
# location check, DELIBERATELY, which is a real narrowing of this check and is recorded as one. The
# else-branch below is untouched: a name matching none of the shapes is still an error, because the
# failure it guards -- a plugin silently held to nothing at all -- is the one that has actually happened.
#
# 'dkj-team-*' JOINED THAT NAME-ONLY GROUP ON SEPTEMBER 9, 2026 (#1698), when this family's own teams were
# renamed 'dkj-subagents-*' and the directory rule moved with them to plugins\dkj-subagents\. It is the
# retired-shapes rule above applied to this rename: the shape stays recognised so a tree or a marketplace
# still carrying the old name reads as a team rather than as unclassifiable, and it is held to no location
# because plugins/dkj-teams/ no longer exists to hold it to. It cannot shadow the branch above it --
# 'dkj-subagents-alpha' does not match 'dkj-team-*' -- which is the property the first-match warning at the
# end of this block is about.
#
# 'team-*' JOINED THAT NAME-ONLY GROUP ON SEPTEMBER 5, 2026 (#1480), and the directory rule then moved with
# the teams to 'dkj-team-*' -> plugins\dkj-teams\, which is what #1698 renamed again. The reasoning is the paragraph above applied to the half it
# had not reached yet: once this family's own teams carry the owner prefix, a bare 'team-*' is exactly what
# a team from ANYBODY ELSE is called, and holding it to plugins/dkj-subagents/ orders a stranger's team into
# this family's directory -- the same failure the workflow half already refuses to commit. So the shape is
# still recognised as a team by name (an unclassifiable plugin remains an error), and only the location
# question is dropped for it. What must NOT happen is the tempting third option: leaving 'team-*' pointed
# at plugins\dkj-subagents\ and adding 'dkj-subagents-*' beside it. The first branch that matches wins, and
# 'dkj-subagents-alpha' does not match 'team-*', so that arrangement reads as harmless and is -- until somebody
# publishes a plugin literally named 'team-something', which is the one case the rule exists for.
$kindChecked = 0
foreach ($p in $publishedPlugins) {
    $kindChecked++
    $rel = $p.RelativeRoot
    if ($p.Name -like 'dkj-subagents-*') {
        if ($rel -notmatch '^plugins\\dkj-subagents\\') {
            Add-Error "[plugin-kind] '$($p.Name)' is one of this family's teams by its name but its source is '$rel' -- 'dkj-subagents-*' belongs under plugins/dkj-subagents/."
        }
    } elseif ($p.Name -like '*-policy' -or $p.Name -like '*-policy-*') {
        if ($rel -notmatch '^plugins\\dkj-policy($|\\)') {
            Add-Error "[plugin-kind] '$($p.Name)' is a ministry of the policy by its name but its source is '$rel' -- '*-policy' and '*-policy-*' belong under plugins/dkj-policy/, the prime ministry at its root and every other ministry one level inside it."
        }
    } elseif ($p.Name -like 'dkj-team-*' -or $p.Name -like 'team-*' -or $p.Name -like 'workflow-*' -or $p.Name -like 'contributing-*' -or $p.Name -like '*-codex') {
        # Accepted by name, held to no location: see the retired-shapes note above.
    } else {
        Add-Error "[plugin-kind] '$($p.Name)' is none of 'dkj-subagents-*', 'dkj-team-*', 'team-*', 'workflow-*', 'contributing-*', '*-codex', '*-policy' or '*-policy-*'. Every plugin here is a team or a way of working, and the name is what says which: the directory rule is DERIVED from the name, so a plugin whose name matches none of them has its location held against nothing at all -- this check switches itself off for it."
    }
}
Write-Coverage -Category 'plugin-kind' -Checked $kindChecked `
    -Note $(if ($kindChecked -eq 0) { 'no published plugin was read, so neither the naming rule nor the directory rule could be applied' } else { "every published plugin is a team or a way of working by name. Two name shapes still carry a directory rule: 'dkj-subagents-*' maps to plugins/dkj-subagents/, and '*-policy' / '*-policy-*' map to plugins/dkj-policy/ -- the government, with the prime ministry at its root and every other ministry one level inside it. 'workflow-*', 'contributing-*' and '*-codex' are accepted by name and held to no location since #1467, because the directory that used to name their kind is gone; bare 'team-*' joined them on #1480, when this family's own teams took the owner prefix and a prefixless team became what SOMEBODY ELSE's team is called, and 'dkj-team-*' joined them on #1698, when those teams were renamed again and the directory it pointed at was gone. The naming half is the one that cannot be seen by reading the tree: a directory rule is derived from the name, so an unclassifiable plugin is silently held to nothing" })

# --- 24. the PR template keeps the two promises open-pr makes about it ------------------------------------
# WHAT THIS IS FOR, measured at a consumer rather than imagined (#573). open-pr fills the PR body's
# description by comparing each template line, WHOLE AND EXACT, against the recognised placeholders. A
# template one word away from one of them matches nothing, and until August 10, 2026 the run said nothing
# either: that consumer merged TWELVE of sixty PRs with no description at all, found months later by
# diffing their template against this repo's. The warning added that day tells the person running open-pr;
# this check tells the person editing the template, which is one step earlier and one person wider.
#
# TWO SUBJECTS, HELD TO DIFFERENT STRENGTHS ON PURPOSE.
#   * The SHIPPED REFERENCE is held byte for byte to Get-PrTemplateReference. It is not a document anybody
#     edits -- it is the answer this family hands a consumer, and a reference whose placeholder open-pr
#     would walk past is worse than no reference at all, because it arrives looking authoritative. Same
#     reasoning as check 13b for the branch document's reset state and check 21 for the config blueprint.
#   * THIS REPO'S OWN .github/pull_request_template.md is held only to the contract: a placeholder line
#     the matcher recognises. Deliberately weaker, because that file is genuinely repo-owned -- the day it
#     grows a section this repo needs, a byte-for-byte rule would refuse a correct change and the gate
#     would be edited to allow it, which is how a check gets switched off rather than heeded.
#
# THE CONTRACT LOST ITS SECOND HALF ON AUGUST 24, 2026 (issue #865), and the reason is that open-pr stopped
# needing it. It also required A FIRST HEADING, because -RefreshBody replaced the description under the
# template's first heading and a template with none would have degraded to a warning on every run. Since
# #865 that switch reads the PLACEHOLDER's position instead: headings above it are the description's,
# headings below it are the form's boundaries, and where the placeholder comes first the description is the
# body's leading section. So a heading-less template is a supported shape, and this check refusing one
# would now refuse the template this repo actually ships.
#
# A CONSUMER'S TEMPLATE IS NOT CHECKED BY ANYTHING, and that is stated rather than left as a gap: this gate
# runs in this repo. What travels to them is the warning in open-pr and the shipped reference to diff
# against. check-script-contract.ps1 cannot help either -- Get-PrDescriptionPlaceholder is OPTIONAL, so a
# repo that does not define it is correct, exactly the shape recorded for Get-BranchTypes.
$prtChecked = 0
$prtNote = ''
$prtRefRel = 'plugins\dkj-policy\templates\pull_request_template.md'
$prtRefPath = Join-Path $RepoRoot $prtRefRel
$prtExpected = ((Get-PrTemplateReference) -join "`n").TrimEnd()
if (-not (Test-Path -LiteralPath $prtRefPath)) {
    Add-Error "[pr-template] $prtRefRel is missing. It is the reference body a consumer copies into their own .github/ -- generated from Get-PrTemplateReference in scripts/lib/pr-body-lib.ps1."
} else {
    $prtChecked++
    $prtOnDisk = (([System.IO.File]::ReadAllText($prtRefPath, [System.Text.Encoding]::UTF8)) -replace "`r`n", "`n").TrimEnd()
    if ($prtOnDisk -ne $prtExpected) {
        Add-Error "[pr-template] $prtRefRel no longer matches Get-PrTemplateReference (scripts/lib/pr-body-lib.ps1). It is a copy of that answer, not a second definition of it -- change the function and regenerate, rather than editing the file."
    }
}

$prtOwnRel = '.github\pull_request_template.md'
$prtOwnPath = Join-Path $RepoRoot $prtOwnRel
if (-not (Test-Path -LiteralPath $prtOwnPath)) {
    # Not an error: a repo without a PR template is a repo open-pr simply does not pre-fill a body for,
    # which the script already handles. Only a template that EXISTS makes a promise.
    $prtNote = 'this repo has no .github/pull_request_template.md, so only the shipped reference was judged'
} else {
    $prtChecked++
    $prtOwnLines = @(Get-Content -LiteralPath $prtOwnPath -Encoding UTF8)
    $prtKnown = @(Get-PrDescriptionPlaceholderDefaults)
    if (-not ($prtOwnLines | Where-Object { $prtKnown -contains $_ })) {
        Add-Error ("[pr-template] $prtOwnRel carries no placeholder line open-pr recognises, so every PR opened from it gets NO description. The comparison is whole-line and exact; one of these must appear verbatim:`n    " +
            ($prtKnown -join "`n    ") +
            "`n  Or define Get-PrDescriptionPlaceholder in scripts/repo-config.ps1 to name your own -- and then this check is the one that has to learn about it.")
    }
}
Write-Coverage -Category 'pr-template' -Checked $prtChecked `
    -Note $(if ($prtNote) { $prtNote } else { "the shipped reference held byte for byte to Get-PrTemplateReference, and this repo's own template held to the contract open-pr relies on -- a placeholder line the matcher recognises. Two strengths on purpose: the reference is an answer we hand out, the repo's own template is a file its owner edits" })

# --- 25. the consumer document does not send its reader into a tier written for somebody else -------------
# WHAT THIS IS FOR, and it is measured rather than imagined (August 10, 2026). The tier model gives each
# release document a named reader, and tier 0 -- the changelog notes -- is defined as "only this repo's own
# developers". A link from the consumer document into that tree hands a paying reader the per-PR record and
# calls it theirs. Measured on the day this landed: TWO of eleven consumer documents did exactly that, both
# of them labelling it invitingly -- v4.0.0's "The full recap is in the release notes" and v3.5.0's "Full
# per-change record". Both were removed in the same change, so this check is not born red.
#
# LINKS ONLY, DELIBERATELY. A path mentioned in prose or inline code is check 4's declined territory: this
# repo measured five variants of "a path in backticks must resolve" over 120 documents and the narrowest was
# born with 124 findings, none real, because most paths this product names describe somebody ELSE's repo. A
# markdown LINK escapes that entirely -- it is not a path being discussed, it is a destination being offered,
# and whose repo it is in is no longer ambiguous.
#
# TWO RULES WERE MEASURED ALONGSIDE THIS ONE AND BOTH DECLINED, recorded here because the next person to
# have the idea should not have to re-measure it:
#   * "no significance score in a consumer document" -- 4 findings, ALL FALSE. v3.7.0's release was ABOUT
#     the entry format, so its consumer document correctly quotes '#### Tier 2' and '**Score:** N/A' as
#     illustrations of the shape it is announcing. The generator already strips real scores
#     (-StripSignificance, asserted in release-lib.tests.ps1); what a human adds afterwards is prose.
#   * "no branch name or PR number in a consumer document" -- 3 findings, ALL FALSE, and the same reason:
#     '## `feat/your-branch` changelog' is v3.7.0 showing the reader the new heading.
# Both would have needed an exemption list on the day they landed, which is the shape this repo has already
# been bitten by. The rest of the writing norm therefore travels as PROSE in the cut-release skill, where a
# person applies it, rather than as gates that cannot tell an illustration from a leak.
#
# MORE THAN ONE TREE SINCE AUGUST 10, 2026, and the reason they are all read is that some of them are
# ARCHIVES. The two hand-written documents became one -- the tree Get-ReleaseNoteRoot names, since August 12
# releases/audience/, with a named section per reader -- and the
# rule follows the reader rather than the directory: a consumer reads the whole of that file, organisation
# section included, so a link into the per-PR record is exactly as wrong there as it was before.
#
# THIS REPO'S OWN ARCHIVE IS GONE AND 'releases\consumer' IS STILL READ, which is the point of the list
# rather than an oversight (August 12, 2026). Dave had the twelve releases/consumer/ + releases/internal/
# pairs merged into releases/audience/, so this repo has one hand-written tree and nothing else -- but a
# CONSUMER on the two-document flow still has that directory, and they receive this gate through a plugin
# update rather than by choosing to. Dropping the name would silently stop holding their outward-facing
# documents, with a coverage count that still looked healthy. Reading a root that is not there costs
# nothing: absent roots are filtered out below. Recognise both, write one.
#
# 'releases\internal' is deliberately NOT in the list, and that is not symmetry being broken by accident:
# this check asks whether a document written for a CONSUMER offers them a link into somewhere written for
# somebody else. An internal note's reader IS the organisation, so reading that tree here would accuse a
# correct document of the thing it cannot commit. The merged document is covered because its consumer
# section and its organisational sections share one file, which the reader-not-directory rule already
# handles -- not because both trees are scanned.
$ctrChecked = 0
# THE LIVE ROOT COMES FROM THE SEAM, and that is a repair rather than a flourish (August 12, 2026). This
# check named 'releases\notes' as a literal, so the day Get-ReleaseNoteRoot moved to 'releases/audience' the
# gate would have found no live tree, checked the archive alone, and reported a coverage count that still
# looked healthy -- a gate going quiet with nothing erroring, which is the failure class this repo keeps
# paying for. script-contract-lib.ps1 states the same lesson at this very seam's record, about its
# reader-versus-writer half; a GATE keyed on a hardcoded root is the third reader nobody thought of.
#
# ALL OF THEM ARE READ, NOT JUST THE CURRENT ONE. The seam's value, the pre-rename 'releases\notes' and the
# archive are walked together and deduplicated, so a repo mid-migration -- or one that never renamed -- has
# every document it owns held rather than whichever the seam happens to name today. Reading a root that is
# not there costs nothing: absent roots are filtered out below. Recognise both, write one.
#
# DOT-SOURCED IN A SCRIPTBLOCK, the pattern check 16 above established and for its reason: repo-config is
# not otherwise loaded in this process, and pulling two dozen repo functions into the whole lint to serve
# one check is how a gate acquires a dependency nobody meant to give it. A repo without the file falls
# through to the pre-rename literal, which is exactly what it had before.
$ctrSeamRoot = & {
    $ctrCfg = Join-Path $RepoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $ctrCfg) { . $ctrCfg }
    if (Test-FunctionDefined 'Get-ReleaseNoteRoot') { [string](Get-ReleaseNoteRoot) } else { '' }
}
# @() around the pipeline, not decoration: with only one of the trees present -- which is every repo
# until its first cut under this model -- a bare pipeline yields a scalar, and under Set-StrictMode
# reading .Count on it throws. Caught by this gate's own run.
$ctrRoots = @(@($ctrSeamRoot, 'releases\notes', 'releases\consumer') |
    Where-Object { $_ } |
    ForEach-Object { $_ -replace '/', '\' } |
    Select-Object -Unique |
    ForEach-Object { Join-Path $RepoRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ })
if ($ctrRoots.Count -eq 0) {
    $ctrNote = 'this repo has neither a hand-written release-note tree (Get-ReleaseNoteRoot) nor a releases/consumer/ archive from the two-document flow, so the tier is off here and there is nothing to hold'
} else {
    foreach ($ctrFile in @($ctrRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -Filter *.md -File })) {
        $ctrChecked++
        $ctrRel = $ctrFile.FullName.Substring($RepoRoot.Length).TrimStart('\')
        $ctrLines = @(Get-Content -LiteralPath $ctrFile.FullName -Encoding UTF8)
        for ($i = 0; $i -lt $ctrLines.Count; $i++) {
            # The link TARGET only -- '](...)'. A tier name in the link TEXT is someone writing about the
            # tiers, which is what v3.7.0 legitimately does.
            foreach ($m in [regex]::Matches($ctrLines[$i], '\]\(([^)]+)\)')) {
                $ctrTarget = $m.Groups[1].Value
                # 'changelog' IS LISTED BESIDE 'development', AND BOTH STAY (issue #914, August 26, 2026).
                # The tier-0 directory renamed, and this line is a LITERAL -- the same shape as the
                # hardcoded root the comment above this check describes going quiet. Dropping the old name
                # would un-cover every consumer who has not migrated; keeping only it would have covered
                # nothing here from the day of the rename onward, with the coverage count still reading
                # healthy. Recognise both, write one.
                if ($ctrTarget -match '(^|/)(development|changelog|internal)/') {
                    $ctrTier = if ($Matches[2] -eq 'internal') { 'tier 1, colleagues on this project' } else { 'tier 0, only this repo''s own developers' }
                    Add-Error ("[consumer-tier] $ctrRel line $($i + 1) links into '$($Matches[2])/' ($ctrTier): $ctrTarget`n" +
                        '  This document''s reader is a consumer of the product. Point them at another consumer document, at the docs, or at nothing -- ' +
                        'a link offered to them has to lead somewhere written for them.')
                }
            }
        }
    }
}
Write-Coverage -Category 'consumer-tier' -Checked $ctrChecked `
    -Note $(if ($ctrChecked -eq 0) { $ctrNote } else { "every document in the hand-written note tree Get-ReleaseNoteRoot names -- releases/audience/ here, one document with a named section per reader, and since August 12, 2026 the only such tree in this repo: the twelve releases/consumer/ + releases/internal/ pairs were merged into it -- plus the pre-rename releases/notes/ and a releases/consumer/ archive, both still read for a consumer who has one, held against offering its reader a link into the tier-0 tree (changelog/ since #914, development/ before it -- both recognised, so a consumer mid-migration stays covered) or the internal (tier 1) one. The rule follows the READER, not the directory: a consumer reads the organisation section too. LINK TARGETS only -- a tier named in link text or prose is someone writing ABOUT the model, which is check 4's declined-path territory. Two neighbouring rules (a score, a branch name) were measured on this same tree and declined at 4 and 3 findings, all false; the reasoning is above the check" })

# --- 26. no frontmatter-bearing shipped document carries a byte-order mark --------------------------------
# READ AS BYTES, AND THAT IS THE WHOLE POINT. Every other reader in this gate goes through
# [System.IO.File]::ReadAllText(..., UTF8), which DETECTS AND STRIPS a BOM before any regex sees it -- so a
# BOM is invisible to all twenty-five checks above, to the canonical-skillset reader that takes each skill's
# name from '(?m)^name:', and to every editor a reviewer would open the file in. It is the one defect
# findable by neither reading nor this gate, and the first three bytes are the only vantage point from which
# it exists at all.
#
# A REPAIR, NOT A PRECAUTION. plugins/dkj-policy/skills/adopt-config/SKILL.md shipped with
# EF BB BF in 4.1.0 -- the only one of the eleven skills across the two shipped plugins to carry it, and the
# only model-invocable one absent from the agent's skill listing. A frontmatter parser that wants '---' at
# offset 0 sees a BOM in front of it and reads the file as having no frontmatter, so the skill has no name
# and never registers. Nothing errors; the page is simply not there. It bites the consumer who can least
# afford it -- a fresh one, whose seam adopt-config exists to fill, and who cannot tell a skill that failed
# to load from one deliberately hidden behind disable-model-invocation. Reported as #581 from
# BWJ-ecommerce/smartwatchbanden, who found it by diffing first bytes because reading cannot.
# (Described in words rather than quoted: a literal BOM in the sentence explaining the bug is invisible here
# too, which is how one got into this very comment on the first draft.)
#
# THE SET IS EVERY FRONTMATTER-BEARING SHIPPED DOCUMENT, not only SKILL.md -- an agent def, manual or
# persona whose frontmatter the harness parses for 'name:'/'id:'/'group:' breaks identically and just as
# quietly, and checks 3/3b/3c already enumerate three of the four sets. Measured before widening rather than
# assumed: 69 documents (26 agent defs, 26 manuals, 4 personas, 13 registered skill pages), all four sets
# non-empty, ZERO findings once the one BOM was stripped, zero exemptions. A check needing an exemption list
# on its first run is the shape this repo has scar tissue from; this one is born green, and reintroducing
# the byte was used to prove it fires rather than merely passes.
#
# THE SUBJECT IS THE BOM AND NOT "MUST HAVE FRONTMATTER", and that narrowing was forced by measurement. The
# first draft also reported a file not opening with '---' at all, which reads as the same defect and is not:
# this repo DELIBERATELY tolerates a skill page without the line -- the canonical reader above falls back to
# the folder name precisely "so a future skill without that line does not silently drop out". Demanding the
# block would be this gate inventing a policy the repo declined, and it showed up at once, because the lint
# suite's own minimal fixtures for checks 18 and 22 are frontmatter-less on purpose: the rule was born with
# two findings, both false, and quieting them meant shifting the line numbers check 22 asserts on.
#
# A BOM needs no such policy -- it is never intentional in any of these files and always breaks a positional
# parse where frontmatter is present. A stray blank line above the block is a real but UNMEASURED cousin:
# named here and deliberately not guarded, per the standing rule that a risk which has not bitten gets
# written down rather than built against.
$bomChecked = 0
$fmDocs = New-Object System.Collections.Generic.List[string]
foreach ($d in (@($agentDefs) + @($manuals) + @($personas))) { $fmDocs.Add($d.FullName) }
$fmSkillDir = Join-Path $RepoRoot 'plugins'
if (Test-Path -LiteralPath $fmSkillDir -PathType Container) {
    # EXACTLY ONE skill-name folder between 'skills' and the file, the same narrowing the canonical
    # skillset above applies. A top-level SKILL.md is what the harness REGISTERS, so a BOM in front of its
    # frontmatter costs the whole skill; a deeper skills/<name>/references/SKILL.md is a
    # progressive-disclosure page that nothing registers, so there is no positional parse for a BOM to
    # break. Check 22 globs broadly on purpose -- a runnable command is machine-specific wherever it sits
    # -- while this check's subject is registration, which only the top level has.
    foreach ($p in @(Get-ChildItem -Path $fmSkillDir -Recurse -Filter 'SKILL.md' -File |
                     Where-Object { $_.FullName -match '\\skills\\[^\\]+\\SKILL\.md$' })) { $fmDocs.Add($p.FullName) }
}
foreach ($fmPath in $fmDocs) {
    $bomChecked++
    $rel = $fmPath.Replace($RepoRoot, '.')
    $head = New-Object byte[] 3
    $readCount = 0
    $fs = [System.IO.File]::OpenRead($fmPath)
    try { $readCount = $fs.Read($head, 0, 3) } finally { $fs.Dispose() }
    if ($readCount -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF) {
        Add-Error ("[frontmatter-bom] $rel begins with a UTF-8 byte-order mark (EF BB BF) before its '---'." +
            " A frontmatter parser that requires '---' at offset 0 reads the file as having no frontmatter, so the" +
            " document registers under no name and fails with no error anywhere. The BOM is invisible in every editor" +
            " and to ReadAllText, so no reviewer and no other check here can see it. Strip the three bytes and save" +
            " the file as UTF-8 WITHOUT a BOM.")
    }
}
Write-Coverage -Category 'frontmatter-bom' -Checked $bomChecked `
    -Note "the first three bytes of every frontmatter-bearing shipped document (agent defs, manuals, personas, and the skill pages a plugin REGISTERS), held against a UTF-8 byte-order mark. Read as bytes because ReadAllText strips a BOM before any other check here can see it -- which is how adopt-config/SKILL.md shipped one in 4.1.0 and silently failed to register (#581). The subject is the BOM and not the presence of frontmatter: this repo deliberately tolerates a skill page without a 'name:' line. Measured at introduction: 69 documents across all four sets, 0 findings once that one BOM was stripped, 0 exemptions"

# --- 27. the script layer is pure ASCII ------------------------------------------------------------------
# THE RULE ALREADY EXISTED AND NOTHING ENFORCED IT. .claude/rules/language-layers.md has said "the script
# layer is ASCII, and a character the script must EMIT is written as a code point" since August 19, 2026,
# and every .ps1 in this tree closes its own docstring with "Pure ASCII (repo convention for .ps1)". A
# convention held up by whoever remembers it is the shape this repo keeps paying for; this is the check.
#
# THE MEASURED DAMAGE, and it is not a style complaint. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# the SYSTEM ANSI CODE PAGE, so the two UTF-8 bytes of a middot (U+00B7) are decoded as two CP1252
# characters -- and nothing errors, because a mis-decoded string is still a string. On August 19, 2026 a
# middot typed literally into scripts/lib/entry-scaffold-lib.ps1 came out of EVERY generated changelog
# template as two wrong characters, and it reached the author's entry before anyone saw it. The repair is
# the code point ([char]0x00B7), not a BOM: the shared libs are held byte-identical to their plugin
# mirrors by check 8, so an encoding change would have to land in both, while an escape keeps the file
# out of the question entirely.
#
# WHY THIS AND NOT THE MOJIBAKE CHECK ABOVE. Check 14 hunts damage that has ALREADY happened, and its set
# (Get-MojibakePaths) is markdown -- so it sees the mangled character one layer downstream, in the
# generated document, after it has been copied into somebody's entry. This check sees the literal upstream,
# in the source that will emit it, which is the only place a repair is cheap.
#
# THE SUBJECT IS THE CHARACTER, NOT THE ENCODING. A BOM is deliberately NOT a finding here: on a .ps1 it
# is the one thing that makes 5.1 read the file correctly, so flagging it would push authors toward the
# defect. ReadAllText strips it before the scan for that reason, and check 26 owns the documents where a
# BOM does break something. Invalid UTF-8 is caught anyway -- it decodes to U+FFFD, which is non-ASCII.
#
# BORN GREEN, MEASURED BEFORE IT WAS WRITTEN: 158 tracked .ps1 files, all of them inside this set once
# the plugin hooks were added to it, and exactly two carrying a non-ASCII character --
# scripts/lib/pr-issues-lib.ps1 and its plugin mirror, two lines each, a deliberate en/em dash inside a
# regex character class. Both were repaired on this branch (composed from [char] code points) rather than
# exempted, and no exemption list exists. A check needing one on its first run is the shape this repo has
# scar tissue from; check 26 was born green on the same reasoning.
$asciiScripts = @(Get-PsScriptFiles)
$nonAscii = [regex]'[^\x00-\x7F]'
foreach ($sf in $asciiScripts) {
    $srcText = [System.IO.File]::ReadAllText($sf.FullName, [System.Text.Encoding]::UTF8)
    $first = $nonAscii.Match($srcText)
    if (-not $first.Success) { continue }
    $rel = $sf.FullName.Replace($RepoRoot, '.')
    # The line number is counted only for a file that already failed, so the scan itself stays a single
    # .NET regex pass over the text instead of a per-byte loop in PowerShell. That matters because this
    # runs over every .ps1 in the tree on every PR, and once more per scenario inside this gate's own
    # fixture suites -- which is where a hundred-odd extra passes over a few megabytes would show up.
    $lineNo = ($srcText.Substring(0, $first.Index) -split "`n").Count
    $total = $nonAscii.Matches($srcText).Count
    $cp = '0x{0:X4}' -f [int][char]$first.Value
    Add-Error ("[script-ascii] $rel`:$lineNo carries a non-ASCII character (U+$($cp.Substring(2)))" +
        "$(if ($total -gt 1) { ", $total in the file" }). Windows PowerShell 5.1 reads a BOM-less .ps1 as the" +
        " system ANSI code page, so this character decodes as two CP1252 characters -- silently, because a" +
        " mis-decoded string is still a string. Write it as a code point instead ([char]$cp), which is what" +
        " .claude/rules/language-layers.md requires of the script layer. Do NOT add a BOM: the shared libs" +
        " are held byte-identical to their plugin mirrors, so the encoding would have to change in both.")
}
Write-Coverage -Category 'script-ascii' -Checked $asciiScripts.Count `
    -Note $(if ($asciiScripts.Count -eq 0) {
        'no .ps1 found under scripts/ or in any plugin -- a literal non-ASCII character anywhere in the script layer could not have been seen'
    } else {
        "every .ps1 check 5 parses, held to the ASCII rule .claude/rules/language-layers.md states for the script layer. A literal non-ASCII character in a BOM-less .ps1 is decoded by Windows PowerShell 5.1 as two CP1252 characters, silently, and reaches whatever the script EMITS -- measured on a middot in entry-scaffold-lib.ps1 that came out wrong in every generated changelog template (August 19, 2026). A BOM is deliberately not a finding: on a .ps1 it is the fix, not the defect, and check 26 owns the files where one breaks something. Born green: 2 findings at introduction across all 158 tracked .ps1 files, both repaired rather than exempted, 0 exemptions"
    })

# --- 28. every '@'-import target resolves -----------------------------------------------------------------
# THE CLASS CHECK 4 CANNOT SEE. The [link] check above validates '[text](target)' and nothing else, so an
# '@'-import -- a different syntax entirely -- matches none of it. Reported as issue #874.
#
# WHY IT IS NOT JUST ANOTHER DEAD LINK. A dead markdown link costs a reader one click. A dead '@'-import
# costs the SESSION THE WHOLE DOCUMENT, silently: Claude Code drops an import it cannot resolve, nothing
# errors, and the instructions simply are not there. The failure is asymmetric in the worst direction,
# because the always-on path of this repo is assembled entirely out of imports and the layer that would
# vanish is the one carrying the safety rules or the roster. The only symptom is a session behaving as
# if it had never read them.
#
# THE THREE RESOLUTION RULES ARE NOT RESTATED HERE. measure-context-lib.ps1 already implements and
# documents them ('~/' -> user home, rooted -> as given, otherwise -> relative to the IMPORTING FILE's
# own directory, which is not the repo root), and its suite pins them. This check reuses that parser,
# so the gate and the measurement script cannot drift on what an import means. The issue proposed
# restating the rules; reusing them is the same repair with one definition instead of two.
#
# TWO DISCRIMINATORS, BOTH MEASURED BEFORE THIS WAS WRITTEN. A '^@' sweep of every markdown file in the
# tree returns 12 lines and only 3 are imports:
#   - 7 are PowerShell '@(...)' expressions inside fenced blocks. Fences are tracked, exactly as check 4
#     argues for links: illustrating a thing is not doing it.
#   - 1 is PROSE -- dkj-policy/releases/changelog/1.x/1.16.0.md, a paragraph that happens to wrap onto
#     '@-imported here (this maintenance repo ...)'. Get-ImportLinePath takes the rest of the line as the
#     path, which is right for the always-on walk (it never meets prose) and wrong for a scan set that
#     includes archived release notes. A target containing WHITESPACE is therefore not an import here.
#     That is a discriminator rather than an exemption list, deliberately: a check born needing one is
#     the shape this repo has scar tissue from (see check 27).
#
# AN IMPORT OUTSIDE THE REPO IS COUNTED, NOT REFUSED. SPECIALISTS.md imports the orchestrator's persona
# from the plugin MARKETPLACE CLONE under '~/', which legitimately does not exist on a machine without
# that plugin installed. CI is such a machine, so erroring there would fail every PR for a correct file.
# The coverage line names how many were seen instead.
#
# WHAT IS DELIBERATELY NOT BUILT, because it has not bitten. The mirror image of the prose rule: a
# wrapped paragraph beginning '@' at column 0 INSIDE an always-on document would be read by Claude Code
# as an import, and the document after it lost. No instance exists -- the only prose line in the tree
# sits in an archived release note nothing loads -- and .claude/rules/language-layers.md's standing rule
# is that a risk which has not bitten is written down rather than built against. This comment is that
# writing-down.
#
# BORN GREEN: 3 imports on the always-on path, all three resolving, 0 findings at introduction.
$importScanFiles = @($linkFiles)
$importAnyLine = [regex]'(?m)^@'
$importResolved = 0
$importExternal = 0
$importNotAPath = 0
foreach ($lf in $importScanFiles) {
    $importText = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    # One regex pass per file decides whether the line walk is worth doing. Every other file in the scan
    # set -- the overwhelming majority -- costs exactly that pass, which matters because this set is a few
    # hundred documents and the gate runs on every PR and again inside its own fixture suites.
    if (-not $importAnyLine.IsMatch($importText)) { continue }
    $importRel = $lf.Replace($RepoRoot, '.')
    $importInFence = $false
    $importLineNo = 0
    foreach ($importLine in [regex]::Split($importText, '\r?\n')) {
        $importLineNo++
        if (Test-IsFenceLine $importLine) { $importInFence = -not $importInFence; continue }
        if ($importInFence) { continue }
        $importTarget = Get-ImportLinePath -Line $importLine
        if (-not $importTarget) { continue }
        if ($importTarget -match '\s') { $importNotAPath++; continue }
        # A target that cannot even be turned into a path is not one. Resolve-ImportPath goes through
        # System.IO.Path, which throws on characters no filesystem accepts -- and a line carrying those
        # is prose the whitespace rule happened not to catch, not an import somebody meant.
        $importPath = $null
        try { $importPath = Resolve-ImportPath -Target $importTarget -ImportingFile $lf } catch { $importPath = $null }
        if (-not $importPath) { $importNotAPath++; continue }
        if (-not $importPath.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $importExternal++
            continue
        }
        if (-not (Test-Path -LiteralPath $importPath -PathType Leaf)) {
            Add-Error ("[import] ${importRel}:${importLineNo} -> dead '@'-import '$importTarget'" +
                " (expected file does not exist). An import resolves relative to the IMPORTING FILE's own" +
                " directory unless it starts with '~/' or is rooted -- so from" +
                " '$((Split-Path -Parent $lf).Replace($RepoRoot, '.'))', not from the repo root. Claude Code" +
                " drops an import it cannot resolve WITHOUT ERRORING, so this costs the session the whole" +
                " document rather than one link.")
            continue
        }
        $importResolved++
    }
}
Write-Coverage -Category 'import' -Checked $importScanFiles.Count `
    -Note $(if ($importScanFiles.Count -eq 0) {
        'the scan set is empty -- no dead @-import anywhere could be found, which is not the same as there being none'
    } else {
        "every file check 4 reads for links, read again for column-0 '@'-imports and resolved through measure-context-lib's own parser. Found $importResolved resolving in-tree import(s) and $importExternal outside the repo (not a finding: a '~/'-relative import points into the plugin marketplace clone, which CI does not have). $importNotAPath line(s) began with '@' and were read as prose rather than as a path. Fenced blocks are excluded, as in check 4. A dead import is not a dead link: Claude Code drops it silently and the session loses the WHOLE document"
    })

# --- 29. a plugin's OWN skill enumeration, scoped to that plugin and read from its links ------------------
# THE HALF CHECK 10 CANNOT HOLD, split out of #873 and measured in #920. Check 10 exists for a document
# that claims to list EVERY skill in the marketplace, and both of its defining properties make it the
# wrong instrument for a document that claims to list every skill of ONE plugin:
#
#   * its canonical set is repo-wide -- built from Get-PluginSubdirs over every published plugin -- so a
#     span in plugins/dkj-policy/README.md, which enumerates the 16 that plugin
#     ships, would report the team plugins' skills as 'missing';
#   * every backtick-quoted token inside its span is a claimed name, which is why its own author
#     condition is 'wrap tightly'. That table is two columns and three of its rows carry a backticked
#     path or flag in the SECOND one -- so the span could not close around only the names without
#     making the prose worse in order to satisfy a checker.
#
# So this is a second, separately opt-in sentinel rather than a relaxation of check 10. It differs in
# exactly those two respects and in nothing else: same fence masking, same unpaired-marker errors, same
# symmetric END sweep, same silent pass on zero spans.
#
#   1. SCOPE. The plugin is resolved from the FILE'S OWN PATH, through Get-PluginNameForPath -- the same
#      function the fold uses to decide which plugins a PR touched. A span in a file under no plugin root
#      is a hard error rather than a silent skip: the marker's whole meaning is 'this plugin', and a file
#      that belongs to none has made a claim nothing can adjudicate.
#   2. THE CLAIM IS THE LINK, NOT THE BACKTICKS. Every markdown link inside the span whose target
#      resolves to <this plugin>/skills/<one>/SKILL.md is one claimed skill; everything else inside the
#      span -- prose, backticked paths, flags, links elsewhere -- is ignored. That is what lets a
#      two-column table with running prose in the second column be marked without rewriting it, and it
#      needs no author condition at all. Resolution is relative to the document's own directory, exactly
#      as check 4 resolves a relative link.
#
# EXACTLY ONE segment between 'skills' and 'SKILL.md', mirroring check 10's canonical walk: a level-3
# progressive-disclosure page at skills/<name>/references/SKILL.md is not a top-level skill and is not
# read as a claim.
#
# THE COMPARISON IS ON FOLDER NAMES, where check 10 compares frontmatter 'name:' values. A link target
# can only ever name a DIRECTORY, so the directory is the only thing this span is able to claim. Should
# a skill's folder ever diverge from its frontmatter name, that divergence is check 3's domain, not
# this one's, and this check keeps answering the question it can actually answer: does the table link
# to every skill directory this plugin ships, and to nothing else.
#
# WHY IT MUST STAY OPT-IN, measured across all four plugins before it was proposed (#920): a generic
# rule -- 'a plugin README lists every skill it ships' -- would be born needing an exemption list.
# dkj-policy ships 16 and lists 16; dkj-subagents-alpha ships 4 and lists 0; dkj-subagents-shopify ships 4
# and lists 0; dkj-subagents-ecomm ships 0. So a non-opt-in version produces 8 findings on two documents that
# never claimed to enumerate anything, which is the shape this repo has scar tissue from (check 10's
# own prose scan rejected at 147 hits, the stale-path check declined at 124, check 27's exemption
# argument). An explicit sentinel fires on exactly the one table that means it.
#
# THE RECURRENCE THIS CLOSES: that table's correctness was guarded only by 'count when you add one',
# which has failed three times -- nine/twelve, thirteen/fourteen, fourteen/sixteen.
#
# BORN GREEN: 1 span, 16 claimed, 16 canonical, 0 findings at introduction.
$pluginSkillLinkRegex = [regex]'\]\(([^)\s]+)\)'
$pluginSkillSpanCount = 0
$pluginSkillClaimTotal = 0
# Cached per plugin: the walk is cheap, but a document could carry several spans and there is no
# reason to re-read a plugin's skills/ tree for each one.
$pluginSkillCanonicalCache = @{}
foreach ($lf in $linkFiles) {
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    # The cheap test first, on the RAW text, exactly as check 28 does for '@': masking is a split and a
    # regex-replace per line, and the overwhelming majority of this few-hundred-document set carries no
    # marker at all. A raw match is a superset of a masked one -- masking only ever removes markers, it
    # never creates one -- so skipping here can never skip a file the masked scan would have found.
    if ($content -notmatch '<!--\s*/?skills:plugin\s*-->') { continue }
    $maskedContent = Get-FenceMaskedText -Text $content
    $rel = $lf.Replace($RepoRoot, '.')
    $ownerName = Get-PluginNameForPath -PluginRoots $publishedPlugins -Path $lf.Substring($RepoRoot.Length)
    $ownerRoot = $null
    if ($ownerName) { $ownerRoot = Get-PluginRootByName -PluginRoots $publishedPlugins -Name $ownerName }
    # THE WALK IS Invoke-MarkedSpanWalk (issue #1491), shared with checks 10 and 32. What stays here is
    # only what is this check's own: the plugin resolved from the file's own path above, the link-based
    # claim rule below, and the two counters.
    Invoke-MarkedSpanWalk -MaskedText $maskedContent -RawText $content -Marker 'skills:plugin' `
        -Category 'skill-list-plugin' -Rel $rel -OnSpan {
        param($span)
        if (-not $ownerRoot) {
            Add-Error ("[skill-list-plugin] ${rel}: <!-- skills:plugin --> span at line $($span.BeginLineNo) sits in a file that" +
                " belongs to no published plugin, so there is no plugin whose skills it could be held against." +
                " This marker is plugin-scoped by definition -- for a marketplace-wide enumeration use" +
                " <!-- skills:all --> (check 10) instead.")
            return
        }
        if (-not $pluginSkillCanonicalCache.ContainsKey($ownerName)) {
            $ownerSkillDirs = New-Object System.Collections.Generic.HashSet[string]
            $ownerSkillsRoot = Join-Path $ownerRoot.Root 'skills'
            if (Test-Path -LiteralPath $ownerSkillsRoot -PathType Container) {
                Get-ChildItem -Path $ownerSkillsRoot -Recurse -Filter 'SKILL.md' -File |
                    Where-Object { $_.FullName -match '\\skills\\[^\\]+\\SKILL\.md$' } | ForEach-Object {
                        [void]$ownerSkillDirs.Add((Split-Path (Split-Path $_.FullName -Parent) -Leaf))
                    }
            }
            $pluginSkillCanonicalCache[$ownerName] = $ownerSkillDirs
        }
        $ownerCanonical = $pluginSkillCanonicalCache[$ownerName]
        # The claim set. Read from the RAW text at the same offsets, not from the mask -- the mask only
        # ever blanks fenced blocks, and a span never legitimately contains one, so the two agree here;
        # reading the raw text keeps the target byte-exact regardless.
        $spanText = $content.Substring($span.SpanStart, $span.SpanEnd - $span.SpanStart)
        $spanDir = Split-Path -Parent $lf
        $ownerSkillsPrefix = (Join-Path $ownerRoot.Root 'skills').TrimEnd('\') + '\'
        $claimed = New-Object System.Collections.Generic.HashSet[string]
        foreach ($m in $pluginSkillLinkRegex.Matches($spanText)) {
            $target = $m.Groups[1].Value
            if ($target -match '^(https?:|mailto:|#)') { continue }
            $target = ($target -split '#')[0]
            if (-not $target) { continue }
            $resolved = $null
            try { $resolved = [System.IO.Path]::GetFullPath((Join-Path $spanDir ($target -replace '/', '\'))) } catch { $resolved = $null }
            if (-not $resolved) { continue }
            if (-not $resolved.StartsWith($ownerSkillsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            if ($resolved -notmatch '\\skills\\[^\\]+\\SKILL\.md$') { continue }
            [void]$claimed.Add((Split-Path (Split-Path $resolved -Parent) -Leaf))
        }
        $missing = @($ownerCanonical | Where-Object { -not $claimed.Contains($_) } | Sort-Object)
        $extra = @($claimed | Where-Object { -not $ownerCanonical.Contains($_) } | Sort-Object)
        if ($missing.Count -gt 0) {
            Add-Error ("[skill-list-plugin] ${rel}: <!-- skills:plugin --> span at line $($span.BeginLineNo) claims to enumerate" +
                " every skill of plugin '$ownerName' but links to none for: $($missing -join ', ').")
        }
        if ($extra.Count -gt 0) {
            Add-Error ("[skill-list-plugin] ${rel}: <!-- skills:plugin --> span at line $($span.BeginLineNo) links into" +
                " '$ownerName'/skills/ for name(s) that ship no SKILL.md there: $($extra -join ', ').")
        }
        # $script:-scoped because the body runs in a CHILD scope -- see the note at Invoke-MarkedSpanWalk.
        $script:pluginSkillSpanCount++
        $script:pluginSkillClaimTotal += $claimed.Count
    }
}
Write-Coverage -Category 'skill-list-plugin' -Checked $pluginSkillSpanCount `
    -Note $(if ($pluginSkillSpanCount -eq 0) {
        "no <!-- skills:plugin --> span anywhere in the set check 4 reads. The marker is opt-in, so zero is a pass and not a gap -- but nothing about any plugin's own skill table is being asserted by this run"
    } else {
        "opt-in <!-- skills:plugin --> span(s), each held against the skills/ of the plugin the DOCUMENT ITSELF sits in (resolved via Get-PluginNameForPath, not named in the marker), with $pluginSkillClaimTotal claim(s) read from LINK TARGETS rather than from backticks -- so prose and backticked paths elsewhere in the row cost nothing. Check 10 is the marketplace-wide sibling and cannot serve this: its canonical set spans every plugin"
    })

# --- 30. A plugin-shipped relative link must resolve INSIDE its own plugin ---------------------------
#
# WHY CHECK 4 CANNOT SEE THIS, AND IS RIGHT NOT TO. The dead-link scan resolves every link against the
# tree it is run in, and for a plugin-shipped file that tree is the source repo -- the one place the
# link is guaranteed to work. It is correct about where the file IS; it has no notion of where the file
# will be READ. So the single class of link defect that reaches consumers is the one class it is
# structurally blind to. Inbound #1066, August 29, 2026.
#
# WHERE A CONSUMER ACTUALLY READS IT, measured rather than assumed -- this is the whole check:
#
#     ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
#
# Every installPath in installed_plugins.json is that shape. The plugin's OWN directory is the root,
# and three things present in the source tree are gone from it: the 'plugins/' level, the family level
# ('teams/', 'workflows/'), and every sibling plugin -- each sibling is a separate versioned directory,
# not a neighbour. A relative link that walks out of the plugin root therefore lands somewhere that
# does not exist, or worse, somewhere that does and holds something else.
#
# THE BOUNDARY IS THE PLUGIN ROOT, NOT 'plugins/', and that distinction is the reason this check is
# worth having rather than a detail of it. #1066 proposed the rule as "must resolve to a target also
# under plugins/, because that is the subtree the plugin cache contains". The cache contains no such
# subtree, and the weaker rule passes the one link that had ALREADY SHIPPED dead: cut-release's
# SKILL.md line 123 pointed at '../../../../teams/team-alpha/manuals/06-25-manual.md', which stays
# under plugins/ here and resolves to '<cache>/<marketplace>/teams/team-alpha/...' in a consumer,
# where the family level does not exist. Verified against the installed v4.22.0 copy on disk, not
# inferred. The manual it names does travel -- it simply never travels to that path.
#
# THE SIZE, RECOUNTED. #1066 reported zero findings and argued from that ("today's expected answer is
# zero, which is itself the reason not to build it yet"), and added that the defect "never shipped".
# The real count on the day the check landed was 17 escapes across 5 files, every one passing check 4 --
# and resolving all 17 inside the INSTALLED copies (dkj-subagents-alpha 4.21.0, dkj-policy 4.22.0)
# rather than in this tree, all 17 are dead. Not one of them, all of them. That inverts the report's own
# conclusion instead of qualifying it: the failure mode has bitten, in released payload, so the repo's
# name-it-and-leave-it rule no longer holds it back.
#
# THE CONVENTION THIS ENFORCES IS ALREADY WRITTEN, in DEVELOPMENT-portable.md: "links into the source's
# script tree are absolute on purpose". It was stated on one portable page, for that page, and enforced
# nowhere. This is that sentence made checkable for the plugin tree as a whole.
#
# PERSONAS ARE EXCLUDED, for check 4's reason and not a new one: a persona template is destined for a
# consuming repo's .claude/extensions/, so its links are MEANT to resolve outside the plugin root and
# check 4 already validates them at that destination. Measured when this check was written: no persona
# carries an escaping link either way, so the exclusion buys correctness rather than silence.
#
# THREE FORMS ARE PASSED OVER, each for its own reason: a '${...}' target is the plugin-relative form
# (${CLAUDE_PLUGIN_ROOT}) rather than a path this check can resolve; a '~/'-relative one points into
# the marketplace clone deliberately; an absolute URL is the repair this check asks for.
#
# THE TRUNCATION HALF -- the one absolute shape this check does judge (issue #1566, September 8, 2026).
# An absolute link whose target is this repo's blob/tree base with NOTHING after it. That is not a
# general opinion about absolute links, which stay correctly out of scope: it is the single absolute
# shape that is provably not what the author meant, because the link text always names something more
# specific than the repository front page. It is also, demonstrably, this check's own suggestion pasted
# without its tail -- the anchor note below records that ten of the seventeen repairs carried one, and
# what was measured on September 8 was SIXTEEN links across four plugin pages holding nothing but the
# base. Sixteen against seventeen is close enough to name the mechanism: the suggestion is right, and
# until now nothing held the RESULT of an earlier repair.
#
# WHY NEITHER EXISTING CHECK SEES IT, and both are right not to. Check 4 skips any target matching
# '^(https?:|mailto:)' and could not judge it anyway -- GitHub answers '.../blob/main/' with the repo
# root, so all sixteen returned 200 and were never dead links. This check skipped the same prefix for
# its own reason: its subject is a RELATIVE target escaping the plugin root. So the defect sat in the
# gap between "not dead" and "not relative", which is why it needed saying rather than catching.
#
# IT IS THE ONE PLACE THIS CHECK NEEDS THE SEAM FOR A VERDICT. The pattern is composed from
# Get-RepoBlobUrl, so a repo without scripts/repo-config.ps1 gets this half not at all rather than
# approximately -- stated in the coverage note, because a check that silently does less is worse than
# one that says what it did not do. Keying on the configured base is also what keeps it honest going
# forward: the shape it guards against is produced by the suggestion, and the suggestion is built from
# that same base, so the two can never disagree about which URL counts as this repo's.
#
# AND THE COST OF THAT CHOICE, NAMED RATHER THAN BUILT AGAINST. A base-only link written on a PREVIOUS
# owner name passes -- ALL SIXTEEN repaired on September 8 were on 'DaveKJohn/', which this repo left
# behind in the September 2 transfer, and a seventeenth written that way tomorrow would not be
# reported. Widening the pattern to any owner of a same-named repo was declined for the reason the
# repo-citation rule in CLAUDE.md gives: the old path resolves only through a transfer redirect, so
# recognising it here would teach the check to bless a spelling the prose rule is retiring. Measured
# after the repair: ZERO base-only links on either owner anywhere in the tree, and every future one
# comes from the suggestion, which writes the current base. So this is a risk with no instance, which
# is the repo's threshold for writing it down instead of coding for it.
#
# A FOURTH, ROOT-RELATIVE FORM ('/path') IS PASSED OVER TOO, and that one is a risk named rather than
# handled. On GitHub it means the repo root; in a plugin cache it means the filesystem root, so it is a
# defect of the same family. Measured when this check landed: ZERO of them in plugin payload. The repo's
# standing rule is to name a risk that has not bitten and leave it, so this stays a comment -- but it is
# a comment rather than an omission, and the second instance is the argument for widening the rule.
$pluginLinkFiles = 0
$pluginLinkChecked = 0
$pluginLinkEscapes = 0
$pluginLinkTruncated = 0
$pluginLinkMask = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) ($m.Value -replace '[^\r\n]', ' ') }
$pluginLinkBlobBase = & {
    # DOT-SOURCED IN A SCRIPTBLOCK, the idiom checks 16 and 26 established, for their reason: this is
    # the only value here that repo-config owns. It is wanted for the SUGGESTION in the message -- so a
    # repo without the seam gets a plainer finding, never a wrong one -- and, since #1566, for the
    # verdict of the truncation half below, which simply does not run without it. That is the one place
    # this check depends on the seam for an ANSWER rather than for advice, and the coverage note says so.
    $plCfg = Join-Path $RepoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $plCfg) { . $plCfg }
    if (Test-FunctionDefined 'Get-RepoBlobUrl') { Get-RepoBlobUrl } else { '' }
}
# THE BRANCH IS READ OUT OF THE SEAM, not assumed to be 'main'. Get-RepoBlobUrl happens to end in
# '/blob/main/' here, but it is a repo-owned function and a consumer whose trunk is 'master' returns
# that instead -- so the pattern is composed from whatever ref the base actually names. A directory
# suggestion swaps blob for tree, so both spellings count; a trailing slash is optional, and so is a
# bare anchor, because '<base>/#section' is still the front page with nothing of the path left.
$pluginLinkBaseOnly = ''
if ($pluginLinkBlobBase -match '^(?<stem>.+?)/blob/(?<ref>[^/]+)/$') {
    $pluginLinkBaseOnly = '^' + [regex]::Escape($Matches['stem']) + '/(?:blob|tree)/' +
        [regex]::Escape($Matches['ref']) + '/?(?:#\S*)?$'
}
foreach ($plugin in $publishedPlugins) {
    if (-not (Test-Path -LiteralPath $plugin.Root)) { continue }
    $pluginRootPrefix = $plugin.Root.TrimEnd('\') + '\'
    foreach ($pf in (Get-ChildItem -Path $plugin.Root -Recurse -Filter '*.md' -File)) {
        if ($pf.FullName -match '\\personas\\.*-persona\.md$') { continue }
        $pluginLinkFiles++
        $pluginText = [System.IO.File]::ReadAllText($pf.FullName, [System.Text.Encoding]::UTF8)
        # Masked, not stripped: check 4 removes code and comments outright because it never reports a
        # line number. This one does, so every mask preserves length and newline positions.
        $pluginScan = Get-FenceMaskedText -Text $pluginText
        $pluginScan = [regex]::Replace($pluginScan, '(?s)<!--.*?-->', $pluginLinkMask)
        $pluginScan = [regex]::Replace($pluginScan, '`[^`\r\n]*`', $pluginLinkMask)
        $pfRel = $pf.FullName.Replace($RepoRoot, '.')
        foreach ($m in $linkRegex.Matches($pluginScan)) {
            $pluginTarget = $m.Groups[1].Value.Trim()
            if ($pluginTarget -match '^(https?:|mailto:)') {
                # THE ONE ABSOLUTE SHAPE THIS CHECK JUDGES -- see 'THE TRUNCATION HALF' above. Reported
                # here rather than in a check of its own because it is this check's own suggestion with
                # its tail missing, and a finding is most useful next to the advice that produced it.
                if ($pluginLinkBaseOnly -and $pluginTarget -match $pluginLinkBaseOnly) {
                    $pluginLinkTruncated++
                    $pluginTruncLineNo = 1 + [regex]::Matches($pluginScan.Substring(0, $m.Index), "`n").Count
                    Add-Error ("[plugin-link] ${pfRel}:${pluginTruncLineNo} -> '$pluginTarget' is this repo's" +
                        " blob/tree base with nothing after it, so it resolves to the repository FRONT PAGE" +
                        " while the link text names something more specific. Give it the path of the file it" +
                        " names -- and the anchor, if the text names a section.")
                }
                continue
            }
            if ($pluginTarget.Contains('${') -or $pluginTarget.StartsWith('~')) { continue }
            $pluginPathPart = ($pluginTarget -split '#', 2)[0]
            if (-not $pluginPathPart) { continue }
            if ([System.IO.Path]::IsPathRooted($pluginPathPart)) { continue }
            $pluginLinkChecked++
            $pluginResolved = $null
            try {
                $pluginResolved = [System.IO.Path]::GetFullPath(
                    (Join-Path (Split-Path -Parent $pf.FullName) ($pluginPathPart -replace '/', '\')))
            } catch { continue }
            if (($pluginResolved.TrimEnd('\') + '\').StartsWith($pluginRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $pluginLinkEscapes++
            $pluginLineNo = 1 + [regex]::Matches($pluginScan.Substring(0, $m.Index), "`n").Count
            # The suggestion is built from the target's position IN THIS TREE, which is exactly what the
            # author meant and exactly what does not travel -- so the message hands over the absolute
            # form rather than describing it. THE ANCHOR IS CARRIED ALONG: ten of the seventeen found on
            # the day this landed pointed at a specific heading, and a suggestion that silently drops it
            # asks the author to re-find the section -- or, likelier, to paste the shorter form and lose it.
            $pluginSuggestion = ''
            if ($pluginLinkBlobBase -and $pluginResolved.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $pluginAnchorPart = ($pluginTarget -split '#', 2)
                # A DIRECTORY TARGET GETS 'tree/', not 'blob/'. GitHub redirects blob->tree for a
                # directory, so the blob form is not broken -- it is just not the URL anybody would
                # write, and a suggestion that has to be corrected before pasting is one the author
                # stops trusting. Two of the seventeen point at a directory.
                $pluginIsDir = (Test-Path -LiteralPath $pluginResolved -PathType Container)
                $pluginBase = if ($pluginIsDir) { $pluginLinkBlobBase -replace '/blob/', '/tree/' } else { $pluginLinkBlobBase }
                $pluginSuggestion = ' Write it absolute: ' + $pluginBase +
                    ($pluginResolved.Substring($RepoRoot.Length).Trim('\') -replace '\\', '/') +
                    $(if ($pluginIsDir) { '/' } else { '' }) +
                    $(if ($pluginAnchorPart.Count -gt 1) { '#' + $pluginAnchorPart[1] } else { '' })
            }
            Add-Error ("[plugin-link] ${pfRel}:${pluginLineNo} -> '$pluginTarget' leaves the '$($plugin.Name)'" +
                " plugin root. It resolves here, and a consumer reads this file from" +
                " <cache>/<marketplace>/$($plugin.Name)/<version>/, where everything outside the plugin is gone." +
                $pluginSuggestion)
        }
    }
}
$pluginLinkTruncNote = if (-not $pluginLinkBaseOnly) {
    ". The truncation half did NOT run: it is composed from Get-RepoBlobUrl and this repo has no scripts/repo-config.ps1 seam supplying one, so an absolute link holding nothing but this repo's blob/tree base is unasserted here"
} else {
    ". Absolute links are otherwise out of scope, with one exception held against the seam's own base: $pluginLinkTruncated of them carry that base and nothing after it, resolving to the repository front page while their text names a file"
}
Write-Coverage -Category 'plugin-link' -Checked $pluginLinkChecked `
    -Note $(if ($publishedPlugins.Count -eq 0) {
        'this repo publishes no plugin, so there is no plugin root for a link to escape -- nothing about consumer-side links is being asserted'
    } elseif ($pluginLinkChecked -eq 0) {
        "no relative link in any of the $pluginLinkFiles markdown file(s) under the $($publishedPlugins.Count) published plugin root(s) -- every link is absolute, anchored or plugin-variable-relative, so none can escape$pluginLinkTruncNote"
    } else {
        "relative link(s) in $pluginLinkFiles markdown file(s) across $($publishedPlugins.Count) published plugin root(s), each resolved from where it sits and held against its OWN plugin's root rather than against plugins/ -- $pluginLinkEscapes escaping. Check 4 validates the same links against this tree, where they all work; this one asks whether they survive the trip$pluginLinkTruncNote"
    })


# --- 31. the Shopify CLI is never invoked bare ------------------------------------------------
# WHY A STATIC GUARD RATHER THAN A CONVENTION (inbound #1183, September 1, 2026). Under
# $ErrorActionPreference = 'Stop' -- which every script in this repo sets -- a bare
#
#     & shopify theme pull --store $store --theme $liveId --path $mirror
#     if ($LASTEXITCODE -ne 0) { <clean up; report; exit 1> }
#
# dies on the line AFTER the call the moment the CLI writes anything to stderr, so the exit-code check
# below it never runs. The repair is scripts/lib/shopify-cli-lib.ps1, which lowers the preference for
# the duration of the call; the reason it needs a gate is that THE DANGEROUS FORM IS THE ABSENCE OF A
# WRAPPER. There is no redirect to grep for and no suspicious flag -- the wrong spelling is the shorter,
# more obvious one, which is exactly how the four sites this check was written for came to exist.
#
# ONE EXEMPTION, AND IT IS THE WRAPPER ITSELF, matched on its path so its plugin mirror is exempt too.
# Anything else naming 'shopify' as a command is a finding, including a new script in a plugin that does
# not exist yet: a consumer receives whatever ships, and a second wrapper is the same defect twice.
#
# THROUGH THE PARSER, NOT BY LINE MATCHING, for the reason check 33 gives: a comment explaining the rule
# (this one included) mentions the command, and so does every printed hint that tells a reader to run
# 'shopify theme list'. Only a CommandAst is a call. NOT SKIPPABLE, like every check added since the
# -SkipCheck list was fixed at the three the gate's own suites need -- and because both this check and
# check 33 always run, the two share ONE parse and ONE walk of the script set through
# Get-PsScriptCommandAsts (issue #1358) instead of each doing their own.
# TWO EXEMPTIONS, BOTH BY FILE NAME AND BOTH ABOUT THE SAME ONE CALL. The wrapper holds the permitted
# call, and shopify-cli.tests.ps1 holds the assert that gives the wrapper its meaning: it invokes the
# stub BARE, on purpose, to read back that the shim inherits the caller's 'Stop' -- which is what makes
# the neighbouring 'Continue' assert prove anything. Matched on the name rather than a full path, so a
# plugin mirror of either is exempt too; check 8 already holds a mirror byte-identical to its source.
# The gate found the test's own probe the first time it ran, which is how the second name got here.
$shopifyExempt = @('shopify-cli-lib.ps1', 'shopify-cli.tests.ps1')
$shopifyChecked  = 0
$shopifyFindings = 0
foreach ($psFile in (Get-PsScriptFiles)) {
    $shopifyChecked++
    if ($shopifyExempt -contains $psFile.Name) { continue }
    $shRel = $psFile.FullName.Replace($RepoRoot, '.')
    foreach ($cmd in (Get-PsScriptCommandAsts -Path $psFile.FullName)) {
        if ($cmd.GetCommandName() -ne 'shopify') { continue }
        $shSample = ($cmd.Extent.Text -replace '\s+', ' ').Trim()
        if ($shSample.Length -gt 120) { $shSample = $shSample.Substring(0, 120) + '...' }
        Add-Error ("[shopify-cli] ${shRel}:$($cmd.Extent.StartLineNumber): invokes the Shopify CLI bare." +
            " Under `$ErrorActionPreference = 'Stop' one stderr line from the CLI is a TERMINATING" +
            " ErrorRecord, so the run dies before the `$LASTEXITCODE check below it -- at exit code 0 as" +
            " much as any other. Route it through Invoke-ShopifyCli (scripts/lib/shopify-cli-lib.ps1) and" +
            " judge the run on its .ExitCode. Found: `"$shSample`"")
        $shopifyFindings++
    }
}
Write-Coverage -Category 'shopify-cli' -Checked $shopifyChecked `
    -Note "script file(s) parsed for a command named 'shopify' -- $shopifyFindings bare call(s). Two files are exempt by NAME, so a plugin mirror of either is exempt too: shopify-cli-lib.ps1, which holds the one permitted call, and shopify-cli.tests.ps1, whose probe invokes the CLI bare on purpose to prove the shim inherits the caller's preference. A comment or a printed hint naming the CLI is not a subject: only a CommandAst is"

# --- 32. a mirror table's rows against the shared-scripts registry ----------------------------------------
# THE FOURTH OCCURRENCE THIS EXISTS TO PREVENT (issue #1491). plugins/dkj-policy/scripts/README.md holds
# a hand-written table of the shared scripts that land in that plugin, beside Get-SharedScriptPairs, which
# can simply be asked. It has gone stale against that registry three times: August 15, 2026 (three rows
# missing -- adopt-workflow-folder, session-status, source-repo-guard-lib), August 26, 2026 (the header,
# the destination split and the row list all wrong at once), and September 6, 2026 (#1486: 21 rows short of
# a 45-entry registry). Each repair was a hand pass, which resets the clock rather than stopping it.
#
# CHECK 8 IS NOT THIS, and the distinction is the whole reason a second check is needed. Check 8 holds each
# mirror's CONTENT against its source -- it proves the file on disk is the right file. Nothing before this
# asked whether the page that TELLS a consumer which files exist still names them all, so a script could be
# registered, generated, mirrored byte-perfect and pass every gate while being invisible on the one page a
# consumer reads. All three misses above were of exactly that shape.
#
# THE SCOPE IS THE DOCUMENT'S OWN DIRECTORY, not "this plugin". The canonical set is every registry mirror
# that lands at or below the folder the marked document sits in, relativized against that folder -- which
# is what makes the claims in the table (`task/new-branch.ps1`) comparable as written. Put the marker in
# plugins/<p>/scripts/README.md and it means that folder; put it in plugins/<p>/README.md and it means the
# whole plugin, with the deeper paths (`scripts/task/new-branch.ps1`) the table would then have to carry.
# A file under no published plugin is a hard error rather than a silent skip, exactly as in check 29: the
# marker's meaning is "the mirrors that land here", and a document outside the tree has made a claim
# nothing can adjudicate.
#
# THE CLAIM IS THE ROW'S FIRST CELL, and this is where it differs from both siblings. Check 10 reads every
# backtick pair in the span; check 29 reads link targets. Neither serves a three-column table whose second
# column is running prose carrying `-Worker`, `Get-LintScript`, `Invoke-GitPark` and `CHANGELOG.md`, and
# whose third is a link to a SKILL.md rather than to the script. The first cell IS the claim this table
# makes -- its header says 'Script' -- so that is what is read: the first backticked token of the first
# cell of every table row inside the span. A header row ('Script'), a separator ('---') and a prose line
# carry no backticked first cell and are passed over without a rule of their own.
#
# WHY OPT-IN, like both siblings and for the third time in this file. A blanket rule -- "a plugin's
# scripts/README.md lists every mirror" -- would need an allow-list on the day it was written: the ROOT
# scripts/README.md is a deliberate SUBSET of the same registry (only what a person invokes by hand, as
# its own text says), so a check keyed on filename would false-positive on every lib, hook-only script and
# generator there. That page keeps its own question open; #1491 says so explicitly, and the sentinel is
# what lets this one be gated without answering it. Same scar tissue as check 10's prose scan (rejected at
# 147 hits) and the stale-path check (declined at 124, all false).
#
# BORN GREEN: 1 span, 45 claimed, 45 canonical, 0 findings at introduction -- measured on the trunk the
# hour after #1490 folded, which is the state that made gating this table possible at all.
$mirrorRowRegex = [regex]'(?m)^[ \t]*\|([^|\r\n]*)\|'
$mirrorTokenRegex = [regex]'`([^`\r\n]+)`'
$mirrorSpanCount = 0
$mirrorClaimTotal = 0
# THE CANONICAL SIDE IS REPORTED TOO, and it is not decoration. This check is silent when BOTH sets come
# back empty, and empty-versus-empty is the exact way a span check fails invisibly: it happened on this
# branch, where a mangled regex emptied check 29's two sets and the whole gate reported 0 errors while
# that check asserted nothing. What exposed it was its claim count read against a known baseline. A claim
# count alone would not have: 0 rows against 0 mirrors and 45 against 45 both report "no findings", so the
# figure that distinguishes them has to be printed beside it.
$mirrorCanonicalTotal = 0
foreach ($lf in $linkFiles) {
    $content = [System.IO.File]::ReadAllText($lf, [System.Text.Encoding]::UTF8)
    # The cheap raw test first, as in checks 10, 28 and 29 -- masking every document in this set to find
    # the one that carries a marker is the cost this avoids.
    if ($content -notmatch '<!--\s*/?shared-scripts:mirror\s*-->') { continue }
    $maskedContent = Get-FenceMaskedText -Text $content
    $rel = $lf.Replace($RepoRoot, '.')
    $ownerName = Get-PluginNameForPath -PluginRoots $publishedPlugins -Path $lf.Substring($RepoRoot.Length)
    # BOTH SIDES OF THE PREFIX TEST GO THROUGH GetFullPath, because they arrive by different routes and
    # only agree while the root is written canonically: $lf comes from a Get-ChildItem walk, which returns
    # the filesystem's long form, while a pair's MirrorPath is composed as Join-Path <the root as the
    # caller WROTE it> <relative>. Name the root any other way -- an 8.3 short name is the case that
    # actually occurs, and GetFullPath expands one where a string compare never will -- and this StartsWith
    # matches nothing. That is not a visible failure: an empty canonical set is compared against a claim
    # set and reports nothing, the silent-green shape this check's coverage line exists to expose.
    #
    # HONEST PROVENANCE: this is a fragility found while chasing a DIFFERENT failure, not the cure for it.
    # The CI red that prompted the look was the test hardcoding a plugin folder the trunk had renamed
    # underneath it, and the short-name path was a plausible mechanism that turned out not to be the one
    # operating -- the runner's own diagnostic printed the long form. Kept because the mismatch it
    # prevents is real and costs nothing to prevent; recorded as unfired so nobody later cites it as a
    # measurement. Check 29 is immune by accident rather than by care: both of its sides happen to be
    # GetFullPath'd already.
    $docDir = [System.IO.Path]::GetFullPath((Split-Path -Parent $lf)).TrimEnd('\') + '\'
    Invoke-MarkedSpanWalk -MaskedText $maskedContent -RawText $content -Marker 'shared-scripts:mirror' `
        -Category 'shared-script-list' -Rel $rel -OnSpan {
        param($span)
        if (-not $ownerName) {
            Add-Error ("[shared-script-list] ${rel}: <!-- shared-scripts:mirror --> span at line $($span.BeginLineNo) sits" +
                " in a file that belongs to no published plugin, so there is no mirror set it could be held" +
                " against. This marker reads the registry's mirrors that land in the marked document's OWN" +
                " folder; a document outside every plugin has none.")
            return
        }
        # THE REGISTRY READ AT THE TOP OF CHECK 8 IS REUSED, not taken again. $sharedPairs is the one
        # Get-SharedScriptPairs call this run makes, and it already carries the resolved PluginRoots that a
        # second call would have to re-derive outside that check's guarded try/catch.
        $canonical = New-Object System.Collections.Generic.HashSet[string]
        foreach ($pair in $sharedPairs) {
            $mirrorFull = $null
            try { $mirrorFull = [System.IO.Path]::GetFullPath($pair.MirrorPath) } catch { continue }
            if (-not $mirrorFull.StartsWith($docDir, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            [void]$canonical.Add(($mirrorFull.Substring($docDir.Length) -replace '\\', '/'))
        }
        # Read from the MASK: a fenced example of a table row inside the span must not be read as a claim,
        # for the same reason check 10 reads the mask. The offsets address both texts identically.
        $spanText = $maskedContent.Substring($span.SpanStart, $span.SpanEnd - $span.SpanStart)
        $claimed = New-Object System.Collections.Generic.HashSet[string]
        foreach ($row in $mirrorRowRegex.Matches($spanText)) {
            $tok = $mirrorTokenRegex.Match($row.Groups[1].Value)
            if (-not $tok.Success) { continue }
            [void]$claimed.Add($tok.Groups[1].Value.Trim())
        }
        $missing = @($canonical | Where-Object { -not $claimed.Contains($_) } | Sort-Object)
        $extra = @($claimed | Where-Object { -not $canonical.Contains($_) } | Sort-Object)
        if ($missing.Count -gt 0) {
            Add-Error ("[shared-script-list] ${rel}: <!-- shared-scripts:mirror --> span at line $($span.BeginLineNo) claims to" +
                " list every shared script mirrored into this folder but has no row for: $($missing -join ', ')." +
                " The registry is Get-SharedScriptPairs in scripts/lib/shared-scripts-lib.ps1; a row needs a" +
                " description and a Skill answer, which is why this reports rather than writes it.")
        }
        if ($extra.Count -gt 0) {
            Add-Error ("[shared-script-list] ${rel}: <!-- shared-scripts:mirror --> span at line $($span.BeginLineNo) has a row" +
                " for name(s) the registry does not mirror here: $($extra -join ', '). Either the pair was" +
                " retired from Get-SharedScriptPairs and the row outlived it, or the path is mistyped.")
        }
        # $script:-scoped because the body runs in a CHILD scope -- see the note at Invoke-MarkedSpanWalk.
        $script:mirrorSpanCount++
        $script:mirrorClaimTotal += $claimed.Count
        $script:mirrorCanonicalTotal += $canonical.Count
    }
}
Write-Coverage -Category 'shared-script-list' -Checked $mirrorSpanCount `
    -Note $(if ($mirrorSpanCount -eq 0) {
        "no <!-- shared-scripts:mirror --> span anywhere in the set check 4 reads. The marker is opt-in, so zero is a pass and not a gap -- but no mirror table is being held against Get-SharedScriptPairs by this run, which is the state that let the same page go stale three times"
    } else {
        "opt-in <!-- shared-scripts:mirror --> span(s), each held against the registry mirrors landing in the MARKED DOCUMENT'S OWN folder: $mirrorClaimTotal row(s) read from the first cell rather than from every backtick -- so prose and links elsewhere in a row cost nothing -- against $mirrorCanonicalTotal registered mirror(s). BOTH figures are printed because a silent pass needs both to be zero, which is how a span check fails invisibly. Check 8 is the sibling that proves each mirror's CONTENT; this one proves the page that names them is complete"
    })


# --- 33. printed instructions naming a model-barred skill ------------------------------------------
# A PRINTED INSTRUCTION MUST NOT TELL ITS READER TO "RUN THE X SKILL" WHEN X IS BARRED TO THAT READER.
# A skill whose frontmatter carries 'disable-model-invocation: true' has its page removed from the
# model's context entirely, so a session cannot see it and will not invoke it. A message that says
# `run the 'cut-release' skill` therefore names a route its reader does not have -- and the reader who
# DOES have it, the person at the keyboard, is never told they are the one who has to type it. The
# correct form names the slash-command and the actor, or names the script directly: the flag decides
# WHO TYPES THE LINE, not whether the line may run (new-branch/SKILL.md states this in full).
#
# WHY A CHECK RATHER THAN CARE -- the class bit twice, a month apart, and nothing connected the two:
# #731 -> #734 repaired it for the shipping chain, and #1093/#1096 rediscovered the same defect from
# scratch on the adoption path, where a consumer adoption stopped on it (testrun-2, August 29, 2026).
# Both repairs are wording, in files nothing holds to a shape, so a third instance is one message away.
# Offered as optional by #1093 and deliberately NOT built there, under this repo's rule that a risk
# which has not bitten gets named rather than repaired; filed as #1104 once the second instance made it
# a class rather than a risk.
#
# IT IS FRONTMATTER-DRIVEN, NOT A PHRASING RULE, and that is what keeps it honest. check-script-contract
# names 'adopt-dkj-policy' with exactly this bare imperative and is CORRECT to: that skill carries
# no flag, so its page is in context and a session can invoke it. A grep for "run the '...' skill" would
# have been born with that false finding. Only the barred set below is a subject.
#
# THE DISCRIMINATOR IS THE WORD 'skill' AFTER THE NAME, and it was measured rather than assumed. Without
# it -- an imperative verb plus a barred name anywhere in the message -- the scan returns 8 unique sites
# of which 4 are wrong: three name the SCRIPT rather than the skill ("run scripts/maintenance/
# fix-mojibake.ps1 to repair", "then run ship-pr again", "run park-cycle by hand" -- that last one a
# substring of the barred name 'park'), and one is prose offering a choice rather than issuing an
# instruction. With the discriminator: 11 hits over 7 unique sites, all 7 correct. That is the same
# mention-versus-use separation check 11 makes with its @-target, and it is what makes a generic scan
# viable here where check 10 had to be opt-in.
#
# THE SUBJECT IS BOTH LAYERS, also measured. Printed script output carries 6 of the 7 sites; INSTALL.md
# carries the seventh, in a consumer-facing document. Output-only would have shipped a check that passes
# over the one instance a consumer actually reads.
#
# PRINTED means a string argument to a writer cmdlet, found through the PowerShell PARSER rather than by
# line matching -- so a comment explaining the rule (this one included) is not a subject, and neither is
# a variable name. Markdown is matched per line, where there is no such distinction to draw.
#
# NOT SKIPPABLE, deliberately: -SkipCheck's list is the three checks the gate's own suites need, and the
# comment on $script:SkippableChecks says adding a fourth is a deliberate act. This one does not reuse
# check 5's pass, which is what lets it run when 'parse' is skipped -- it takes its CommandAsts from
# Get-PsScriptCommandAsts, shared with the equally non-skippable shopify-cli check below (issue #1358).
# Both used to parse and walk the same file set separately; that accessor's comment holds the measurement.
$barredSkills = New-Object System.Collections.Generic.HashSet[string]
foreach ($skillsDir in (Get-PluginSubdirs -PluginRoots $publishedPlugins -Leaf 'skills')) {
    Get-ChildItem -Path $skillsDir -Recurse -Filter 'SKILL.md' -File |
        Where-Object { $_.FullName -match '\\skills\\[^\\]+\\SKILL\.md$' } | ForEach-Object {
            # THE FLAG IS READ FROM THE FRONTMATTER BLOCK, NOT FROM THE FILE, and that is load-bearing:
            # new-branch/SKILL.md quotes the string 'disable-model-invocation: true' in its prose to
            # explain the mechanism, and a whole-file match reads that page as barred. It is not -- and
            # a false entry here does not produce one wrong line, it makes every correct instruction
            # naming that skill a finding. Same walk and same name-resolution as check 10's canonical
            # skillset, so "which skills exist" has one answer in this file.
            $bsText = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
            $bsFm = [regex]::Match($bsText, '(?s)\A\uFEFF?---\r?\n(.*?)\r?\n---\r?\n')
            if (-not $bsFm.Success) { return }
            $bsBlock = $bsFm.Groups[1].Value
            if ($bsBlock -notmatch '(?m)^disable-model-invocation:\s*true\s*$') { return }
            $bsName = [regex]::Match($bsBlock, '(?m)^name:\s*(\S+)\s*$')
            [void]$barredSkills.Add($(if ($bsName.Success) {
                $bsName.Groups[1].Value.Trim()
            } else {
                Split-Path (Split-Path $_.FullName -Parent) -Leaf
            }))
        }
}

# Check 11 computed this set (linkFiles, minus history, minus the branch document) and this check wants
# exactly it; see the loop below for why each exclusion matters here. Named rather than used inline so
# that the borrowing is visible at the top of the check rather than buried in a foreach.
$barredMdFiles = $lifecycleFiles
$barredChecked = 0
$barredFindings = 0
if ($barredSkills.Count -gt 0) {
    # LONGEST NAME FIRST, so a barred name that is a prefix of another barred name cannot claim the
    # match. And \b alone does not settle the boundary: a hyphen is a non-word character, so '\bpark\b'
    # matches inside 'park-cycle' -- which is exactly the false finding the naive rule produced. The
    # trailing (?![\w-]) is what refuses a hyphenated continuation.
    $barredAlt = (($barredSkills | Sort-Object -Property Length -Descending) |
        ForEach-Object { [regex]::Escape($_) }) -join '|'
    $barredQuote = "['" + '"' + [char]0x60 + ']?'
    $barredRegex = [regex]('(?i)\b(?:run|invoke|call|use|execute|start|launch)\b\s*(?:the\s+)?' +
        $barredQuote + '(?<skill>' + $barredAlt + ')(?![\w-])' + $barredQuote + '\s+skills?\b')

    $barredWriters = @('Write-Host', 'Write-Warning', 'Write-Error', 'Write-Output', 'Write-Information',
        'Write-Info', 'Write-Failure', 'Write-Ok', 'Write-Step', 'Write-Note', 'Add-Error')

    foreach ($psFile in (Get-PsScriptFiles)) {
        $barredChecked++
        $bsRel = $psFile.FullName.Replace($RepoRoot, '.')
        foreach ($cmd in (Get-PsScriptCommandAsts -Path $psFile.FullName)) {
            $cmdName = $cmd.GetCommandName()
            if (-not $cmdName -or $barredWriters -notcontains $cmdName) { continue }
            $bsStrings = $cmd.FindAll({ param($n)
                $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }, $true)
            foreach ($bsStr in $bsStrings) {
                # The cmdlet's own name parses as a string constant too; it is never a message.
                if ($bsStr.Extent.Text -eq $cmdName) { continue }
                foreach ($m in $barredRegex.Matches($bsStr.Extent.Text)) {
                    # The extent's first line plus the newlines preceding the match inside it, so a
                    # here-string reports the line the sentence is actually on rather than the line the
                    # string opened on.
                    $bsLine = $bsStr.Extent.StartLineNumber +
                        [regex]::Matches($bsStr.Extent.Text.Substring(0, $m.Index), "`n").Count
                    Add-BarredSkillFinding -Rel $bsRel -LineNo $bsLine -Skill $m.Groups['skill'].Value -Sample $m.Value
                }
            }
        }
    }

    # THE MARKDOWN SET IS CHECK 11'S, REUSED RATHER THAN REBUILT, and it brings two exclusions this check
    # needs for exactly the reasons check 11 documents at $lifecycleFiles. HISTORY (CHANGELOG.md root and
    # per-plugin, releases/**, every RELEASE.md) records what was true at the time and is never rewritten,
    # so a note describing the old wording must not become a finding. And THE BRANCH DOCUMENT is history
    # in the making: its DEPLOY text is pasted into CHANGELOG.md at the fold, so a finding there would
    # follow it into the changelog permanently.
    #
    # THAT SECOND ONE IS NOT HYPOTHETICAL -- it is how this exclusion was found. The branch that added this
    # check quotes the forbidden wording in its own PLAN section in order to explain what the check
    # forbids, and the gate refused to push it. A rule that cannot be written down in the document that
    # introduces it is a rule nobody can explain.
    #
    # AND FENCES ARE MASKED, the same way checks 10 and 11 mask them: a fenced example of the wording is an
    # illustration a reader compares against, not an instruction they follow. Masking keeps offsets and
    # newline positions identical, so a line index in the mask still points at the right line in the file.
    # Without it, the only way to show a reader what NOT to write is to not show them.
    foreach ($bsMd in ($barredMdFiles | Sort-Object -Unique)) {
        $barredChecked++
        $bsRel = $bsMd.Replace($RepoRoot, '.')
        $bsMasked = Get-FenceMaskedText -Text ([System.IO.File]::ReadAllText($bsMd, [System.Text.Encoding]::UTF8))
        $bsLines = $bsMasked -split "`r?`n"
        for ($i = 0; $i -lt $bsLines.Count; $i++) {
            foreach ($m in $barredRegex.Matches($bsLines[$i])) {
                Add-BarredSkillFinding -Rel $bsRel -LineNo ($i + 1) -Skill $m.Groups['skill'].Value -Sample $bsLines[$i]
            }
        }
    }
}

Write-Coverage -Category 'barred-skill' -Checked $barredChecked `
    -Note $(if ($barredSkills.Count -eq 0) {
        'no shipped skill carries disable-model-invocation: true, so there is no barred name a printed instruction could misuse -- nothing about printed routes is being asserted'
    } else {
        "script file(s) and markdown file(s) held against the $($barredSkills.Count) skill(s) whose frontmatter bars model invocation -- $barredFindings printed instruction(s) naming one with a bare imperative. Frontmatter-driven rather than a phrasing rule: the same wording about an UNFLAGGED skill (check-script-contract's 'adopt-dkj-policy') is correct and passes"
    })


# --- 34. a numbered section header is unique, ascending, and in one form ----------------------------
# THE FILE WHOSE JOB IS REFUSING HAND-MAINTAINED LISTS KEPT ONE OF ITS OWN. Every check in this script
# announces itself with a '# --- <n>. <what it does>' header at column 0, and that number is how a finding
# is referred to everywhere else: a repo lens, a plugin hook, a test scenario name and two published
# release notes all say "check <n>". Nothing ever read those headers back, so they were prose -- in the
# one file that exists to refuse a hand-maintained list a machine could check.
#
# THE MEASURED DEFECT (issue #1494, September 6, 2026). Two unrelated checks here both carried the number
# 30 -- '[plugin-link]' and '[barred-skill]' -- and both were already load-bearing in published prose
# pointing at DIFFERENT checks: release note 4.23.0 means the first, 4.24.0 the second. So a reader who
# grepped for the number a finding came from got two answers, and a released document was the source of
# one of them. The barred-skill check was renumbered to 33 and moved below 32. The archived notes are
# history and are not rewritten, so 4.24.0 still says 30 and stays standing as the record of when that
# was true -- the same way this repo keeps a superseded measurement in the past tense rather than
# deleting it.
#
# ASCENDING IS THE PROPERTY THAT PREVENTS THE COLLISION, and uniqueness alone is not. Uniqueness is what
# broke, but a check for it by itself still permits inserting a section anywhere and hand-picking its
# number, which is the act that produced the duplicate. Requiring each header to sit strictly above the
# one before it leaves a new check exactly ONE legal number -- the one after the last header in the file
# -- so the number stops being a choice and the renumbering that follows a move is forced rather than
# remembered. That is why check 33 was moved below 32 instead of being left between 30 and 31.
#
# GAPS ARE LEGAL AND THERE ARE THREE HERE (9, 17 and 19). A retired check leaves its number behind:
# reusing it would silently repoint every older citation, which is the defect above arriving by the other
# door. Two of the three carry a retirement note where the check stood, and that note is the convention.
#
# ONE FORM, because a second spelling is how the drift stayed invisible. Four headers read
# '# --- Check <n>: ' where the rest read '# --- <n>. ', so no single pattern listed them all and the
# duplicate showed up in a grep of neither. Both forms are subjects now; only the second is legal.
#
# COLUMN 0 ONLY, and that bound is measured rather than tidy. The same '# ---' marker is used INDENTED
# inside this gate's own test suites to separate scenarios within a function, under its own numbering.
# Those are not file sections, and holding them to this rule would be the gate inventing a convention the
# repo never had -- the narrowing check 26 had to make for the same reason. A header at column 0 is the
# file's table of contents; anything indented belongs to whatever block encloses it.
#
# EVERY SCRIPT, NOT JUST THIS ONE, because the convention is shared rather than local. Measured at
# introduction over this repo's script set (September 6, 2026): 19 files carry a column-0 numbered header,
# 123 headers before this one -- 124 with it -- 0 findings once #1494 was repaired, 0 exemptions. Run
# against the pre-repair file the same reader reports 5 -- the one duplicate and the four headers in the
# other form -- so it demonstrably fires on what it was written for instead of merely passing.
$secChecked  = 0
$secFiles    = 0
$secFindings = 0
foreach ($psFile in (Get-PsScriptFiles)) {
    $secRel   = $psFile.FullName.Replace($RepoRoot, '.')
    $secLines = [System.IO.File]::ReadAllLines($psFile.FullName, [System.Text.Encoding]::UTF8)
    $secSeen  = @{}
    $secPrevN = -1
    $secPrevS = ''
    $secPrevLine = 0
    $secInFile = 0
    for ($i = 0; $i -lt $secLines.Count; $i++) {
        $secLine = $secLines[$i]
        if ($secLine -notlike '# --- *') { continue }
        # THE OTHER FORM IS A SUBJECT, NOT A SKIP. Passing over an unrecognised spelling would let a file
        # opt out of the numbering rule by spelling its headers differently, which is how the duplicate
        # survived a grep for a month.
        if ($secLine -match '^# --- Check (\d+)([a-z]?)\s*[:.]') {
            $secFindings++
            Add-Error ("[section-number] ${secRel}:$($i + 1): a numbered section header in the second form." +
                " The convention is '# --- <n>. <what it does>'; this one reads" +
                " '# --- Check $($Matches[1])$($Matches[2]): '. Two spellings mean no single pattern lists" +
                " every section, which is how two checks came to share the number 30 without a grep showing" +
                " it (#1494). Rewrite it as '# --- $($Matches[1])$($Matches[2]). <what it does>'.")
            continue
        }
        if ($secLine -notmatch '^# --- (\d+)([a-z]?)\. ') { continue }
        $secN = [int]$Matches[1]
        $secS = $Matches[2]
        $secKey = "$secN$secS"
        $secChecked++
        $secInFile++
        if ($secSeen.ContainsKey($secKey)) {
            $secFindings++
            Add-Error ("[section-number] ${secRel}:$($i + 1): section number $secKey is already used at line" +
                " $($secSeen[$secKey]) of this file. That number is how a finding is referred to in lenses," +
                " hooks, test names and published release notes, so two sections sharing one gives a reader" +
                " two answers to the same question -- and a released document then cites the wrong one" +
                " (#1494). Give the LATER section the next free number above the last header in the file and" +
                " move it there; do not reuse a retired number.")
        } elseif ($secN -lt $secPrevN -or ($secN -eq $secPrevN -and $secS -le $secPrevS)) {
            $secFindings++
            Add-Error ("[section-number] ${secRel}:$($i + 1): section number $secKey sits after" +
                " $secPrevN$secPrevS at line $secPrevLine, so the numbers no longer ascend. Ascending order" +
                " is what leaves a new section exactly one legal number -- the one after the last header --" +
                " and it is therefore the property that stops two sections sharing a number at all. Move" +
                " this section to where its number belongs, or renumber it to sit above the previous one.")
        }
        $secSeen[$secKey] = $i + 1
        $secPrevN    = $secN
        $secPrevS    = $secS
        $secPrevLine = $i + 1
    }
    if ($secInFile -gt 0) { $secFiles++ }
}
Write-Coverage -Category 'section-number' -Checked $secChecked `
    -Note $(if ($secChecked -eq 0) {
        'no script in this set carries a column-0 numbered section header, so there is no table of contents to hold to itself -- nothing about section numbering is being asserted'
    } else {
        "column-0 '# --- <n>. ' section header(s) across $secFiles script file(s), each held against the one before it for uniqueness and ascending order, plus the second spelling '# --- Check <n>: ' which is a finding wherever it appears -- $secFindings in all. Indented '# ---' markers are deliberately NOT subjects: the lint suites use them inside functions under their own numbering, and they are not file sections"
    })

# --- 35. a test fixture's own git command is judged -------------------------------------------------
# WHAT #1635 SWEPT, AND WHY A SWEEP IS NOT AN ANSWER (issue #1655). scripts/lib/fixture-git-lib.ps1 exists
# because a suite in scripts/tests/ builds its fixture with git and the standing idiom for those calls was
#
#     & git -C $dir init -q 2>$null | Out-Null
#
# which discards the exit code along with the output. That is worse in a fixture than in production code:
# a production script that ignores a failed git usually goes on to fail visibly, while a fixture that
# ignores one produces a repo that is PLAUSIBLE -- it exists, it has a HEAD, it just does not hold what
# the case assumed -- and every assert below it then measures the wrong thing, attributing the failure to
# the script under test, which is the one place it certainly is not. Under the parallel gate a transient
# index.lock or a scanner holding a file makes that ordinary rather than rare, so the shape to expect is a
# suite red under the gate, green on its own, and silent about why (the #1622 sighting).
#
# THE IDIOM WAS THE HOUSE STYLE, WHICH IS WHY A CONVENTION CANNOT HOLD IT. It was copied from suite to
# suite for as long as this directory has existed, in several spellings, and the next fixture builder will
# be written by copying the nearest neighbour exactly as those were. #1635 converted the neighbours; it
# left nothing that refuses the next copy.
#
# THE MEASUREMENT THIS CHECK WAS BUILT ON, taken before it was written, because the reason it did not ship
# with #1635 was an honest one: this repo has scar tissue from checks born needing an exemption list (the
# stale-path check declined at 124 findings all false, in the system-administration lens), and there is a
# real false-positive class here -- a git call that is a QUESTION rather than a mutation. A
# 'rev-parse --verify --quiet' on a ref EXPECTED to be absent answers with exit 1 and is judged by the very
# next line; counting it would report every negative case as a defect. Three numbers settled it:
#
#   * over the tree as #1635 left it: 27 findings, in 4 files -- so the sweep did NOT finish. It missed
#     find-specialist-mentions, shared-scripts, source-repo-guard and fresh-consumer.measure, whose
#     spellings ('git ... 2>&1 | Out-Null' with no '&', and '& $git @(...)' over a scriptblock) its own
#     search did not reach. All 27 were converted on this branch, so the check is born green with 0
#     exemptions.
#   * over the tree BEFORE the sweep (130dd259~1): 182 findings, in 18 files -- the house style, measured.
#   * probe false positives, both trees: ZERO. Not one 'rev-parse'/'ls-remote'/'show-ref' call appears in
#     either finding set, because the judged rule below clears them.
#
# WHAT MAKES THE TWO CLASSES SEPARABLE, and it is the cheap property rather than a list of git verbs: a
# question's exit code is READ, and read immediately. So a call is cleared when $LASTEXITCODE (or
# Assert-FixtureGitOk) appears in the same statement or the next one -- which is what
# 'return ($LASTEXITCODE -eq 0)' after a rev-parse does, and what publish-to-business's deliberately
# failing probe does with '$probeCode = $LASTEXITCODE'. No verb is special-cased and no file is exempt.
#
# THE SUBJECT IS A DISCARDED RESULT, NOT EVERY UNJUDGED CALL, and that boundary was measured too. Widening
# it to a bare statement pipeline -- 'git log --oneline' with no Out-Null -- yields 20 findings on this
# tree, and all 20 are value-returning questions (a helper's implicit return, 'return @(& git ...)'), i.e.
# 20/20 false. Discarding the output AND ignoring the exit code is the combination that means nothing git
# said was read; either one alone is ordinary.
#
# TWO INVOCATION SPELLINGS, because both exist here and a check written BECAUSE spellings vary must not
# repeat the sweep's mistake: a command named 'git', and '& $git' where the variable is named exactly
# 'git' -- source-repo-guard's scriptblock over Invoke-NativeCapture, which returns an ExitCode the call
# site was throwing away. A wrapper under any other name is out of reach and is not claimed to be covered.
#
# NOT SKIPPABLE, and it shares the parse and the walk of the script set with checks 31 and 33 through
# Get-PsScriptCommandAsts (issue #1358) rather than parsing scripts/tests/ a second time.
$fixtureGitFiles    = @(Get-PsScriptFiles | Where-Object { $_.FullName -match '\\scripts\\tests\\' })
$fixtureGitFindings = 0
foreach ($fgFile in $fixtureGitFiles) {
    $fgRel = $fgFile.FullName.Replace($RepoRoot, '.')
    foreach ($fgCmd in (Get-PsScriptCommandAsts -Path $fgFile.FullName)) {
        # -- is this a git call, in either spelling --------------------------------------------------
        $fgName = $fgCmd.GetCommandName()
        $isGit = ($fgName -eq 'git')
        if (-not $isGit) {
            $fgFirst = $fgCmd.CommandElements[0]
            $isGit = ($fgFirst -is [System.Management.Automation.Language.VariableExpressionAst] -and
                      $fgFirst.VariablePath.UserPath -eq 'git')
        }
        if (-not $isGit) { continue }

        # -- climb out of any wrapping, then ask whether the result is discarded ---------------------
        # BOTH RULES LIVE IN Get-DiscardedOuterPipeline, shared with check 41 since #1956. The unwrap is
        # shared across all three discard spellings rather than written per-spelling, which is the repair
        # for the way this was first written: only the [void] arm walked out of '(...)', so
        # '$null = (& git ...)' and '(& git ...) | Out-Null' were both silently skipped -- the exact call
        # this check exists to catch, wearing one pair of brackets. Neither spelling exists in this tree
        # today, which is why the measurement could not see it and a review of the code could; a check
        # whose three arms disagree about wrapping teaches the shape that gets past it.
        #
        # AND THAT LESSON IS WHY THE FUNCTION IS SHARED RATHER THAN COPIED. Check 41 grew its own
        # near-verbatim copy, which had already drifted -- it climbed through a [void] cast without
        # noticing one (#1956).
        $fgDiscard = Get-DiscardedOuterPipeline -Call $fgCmd
        if ($null -eq $fgDiscard) { continue }
        if (-not $fgDiscard.Discarded) { continue }
        $fgOuter = $fgDiscard.Outer

        # -- is the exit code judged, here or on the next statement ----------------------------------
        # The statement this pipeline IS, which is the pipeline itself wherever it sits directly in a
        # block, and its enclosing statement (an assignment, say) otherwise.
        $fgStmt = $fgOuter
        while ($fgStmt.Parent -and
               $fgStmt.Parent -isnot [System.Management.Automation.Language.StatementBlockAst] -and
               $fgStmt.Parent -isnot [System.Management.Automation.Language.NamedBlockAst]) {
            $fgStmt = $fgStmt.Parent
        }
        $fgBlock = $fgStmt.Parent
        $fgJudged = $false
        if ($fgBlock) {
            $fgStmts = @($fgBlock.Statements)
            $fgIdx = 0
            while ($fgIdx -lt $fgStmts.Count -and $fgStmts[$fgIdx] -ne $fgStmt) { $fgIdx++ }
            # PARENTHESISED DELIBERATELY: '@($a, $a + 1)' is '@($a, $a) + 1' in PowerShell -- the comma
            # binds tighter than the addition -- which silently checks the wrong statements and reports
            # a judged call as a finding. Measured while building this check.
            foreach ($fgJ in @($fgIdx, ($fgIdx + 1))) {
                if ($fgJ -ge $fgStmts.Count) { continue }
                # THROUGH THE PARSER, NOT BY LINE MATCHING -- the same rule check 31 states for the same
                # reason, and it applies with extra force to a clearing condition: a text match on
                # '$LASTEXITCODE' is satisfied by the name appearing in a single-quoted string or a
                # trailing comment, which would clear a GENUINE miss and leave nothing to notice. A
                # VariableExpressionAst is a read (an interpolated "$LASTEXITCODE" is one too, correctly);
                # a comment is not in the AST at all.
                $fgJudged = $fgJudged -or @($fgStmts[$fgJ].FindAll({
                    param($n)
                    ($n -is [System.Management.Automation.Language.VariableExpressionAst] -and
                     $n.VariablePath.UserPath -eq 'LASTEXITCODE') -or
                    ($n -is [System.Management.Automation.Language.CommandAst] -and
                     $n.GetCommandName() -eq 'Assert-FixtureGitOk')
                }, $true)).Count -gt 0
            }
        }
        if ($fgJudged) { continue }

        $fgSample = ($fgCmd.Extent.Text -replace '\s+', ' ').Trim()
        if ($fgSample.Length -gt 120) { $fgSample = $fgSample.Substring(0, 120) + '...' }
        Add-Error ("[fixture-git] ${fgRel}:$($fgCmd.Extent.StartLineNumber): a fixture git command whose" +
            " output is discarded and whose exit code is never read -- so a git that FAILED is" +
            " indistinguishable from one that worked, and every assert below it may be reading a repo that" +
            " was never built. Route it through Invoke-FixtureGitIn / Invoke-FixtureGitJudged" +
            " (scripts/lib/fixture-git-lib.ps1, issue #1635), which lowers `$ErrorActionPreference for the" +
            " call, judges the exit code and counts a failure for Write-FixtureGitSummary. If this call is" +
            " a QUESTION whose non-zero exit is the answer, read `$LASTEXITCODE on the next statement and" +
            " it stops being a finding. Found: `"$fgSample`"")
        $fixtureGitFindings++
    }
}
Write-Coverage -Category 'fixture-git' -Checked $fixtureGitFiles.Count `
    -Note $(if ($fixtureGitFiles.Count -eq 0) {
        'no .ps1 found under scripts/tests/ -- an unjudged fixture git command could not have been seen'
    } else {
        "script file(s) under scripts/tests/ walked for a git command (named 'git', or invoked through a variable named exactly `$git) whose result is DISCARDED (| Out-Null, `$null =, or a [void] cast -- each judged after ONE shared unwrap of any (...) or cast, so a pair of brackets is not an escape hatch) and whose exit code is judged, through the AST rather than the line text, on neither the same statement nor the next -- $fixtureGitFindings finding(s). The immediate-read rule is what separates a fixture MUTATION from a git QUESTION such as 'rev-parse --verify --quiet' on a ref expected to be absent: zero probe false positives over both the current tree and the pre-#1635 tree (182 findings there, in 18 files). Born green: 27 findings at introduction, in the 4 files that sweep missed, all converted rather than exempted, 0 exemptions. A bare statement pipeline is deliberately NOT a subject -- widening to it yields 20 findings here and 20/20 are value-returning questions"
    })


# --- 36. a tool that obliges a shared block, against the defs that hold it ---------------------------
# WHY A SECOND CHECK BESIDE CHECK 7 (issue #1665, September 8, 2026). Check 7 compares the inside of a
# sentinel pair against its source, so it answers "has this block drifted" and has never had an opinion
# about a pair that is ABSENT. For a block placed by CRAFT that is right -- who carries it is a judgement,
# and a check cannot hold a judgement. working-copy-boundary is the first block placed by CAPABILITY: it
# goes to every agent def whose 'tools:' line names Bash, because that is what makes the failure
# reachable at all.
#
# AND A CAPABILITY CIRCLE IS EXACTLY THE KIND A CHECK CAN KEEP. Without this, the circle held only as long
# as somebody remembered it: an agent def gaining Bash later -- a new specialist, or one edited 'tools:'
# line on an existing one -- sits silently outside the boundary with every gate green. That is the same
# enforced-by-memory shape as the defect #1665 reported, arriving through the maintenance door, and it was
# reported by the red-team pass on #1665's own branch before the block had shipped.
#
# THE TABLE IS THE SUBJECT, NOT A FILE LIST. Get-ToolRequiredSharedBlocks maps tool -> block name; a list
# of expected carriers here would be the memory this check replaces, and would go stale the first time the
# roster changes. Nothing declares the reverse direction: an agent def is free to carry a block it is not
# obliged to, because a wider circle is a decision somebody can make and a narrower one is the defect.
#
# THE PERSONAS NEED NO EXCLUSION and deliberately have none: a persona carries no 'tools:' line, so it
# names no tool and is never obliged. That falls out of the data rather than being an exemption, which is
# what keeps it true when the generator's scope changes again.
#
# BORN GREEN: 11 obliged agent def(s) at introduction, all 11 carrying the block, 0 exemptions.
$toolBlockMap = Get-ToolRequiredSharedBlocks
$toolBlockObliged = 0
$toolBlockFindings = 0
foreach ($def in @($agentDefs)) {
    $raw = [System.IO.File]::ReadAllText($def.FullName, [System.Text.Encoding]::UTF8)
    $rel = $def.FullName.Replace($RepoRoot, '.')
    $declaredTools = @(Get-AgentDefTools -Content $raw)
    foreach ($tool in $toolBlockMap.Keys) {
        if ($declaredTools -notcontains $tool) { continue }
        $toolBlockObliged++
        $blockName = $toolBlockMap[$tool]
        if ($raw -notmatch [regex]::Escape("<!-- BEGIN shared:$blockName")) {
            Add-Error ("[tool-block] ${rel}: names '$tool' in its tools line but carries no" +
                " 'shared:$blockName' block. That block is placed by CAPABILITY rather than by craft" +
                " (subagent-shared/README.md says why), so holding the tool is what obliges it. Add the" +
                " sentinel pair and run scripts/agents/build-agent-defs.ps1.")
            $toolBlockFindings++
        }
    }
}
Write-Coverage -Category 'tool-block' -Checked $toolBlockObliged `
    -Note $(if ($toolBlockObliged -eq 0) {
        "no agent def names a tool in Get-ToolRequiredSharedBlocks ($($toolBlockMap.Count) mapping(s)), so no obligation could be missed"
    } else {
        "obligation(s) from $($toolBlockMap.Count) tool -> block mapping(s) in Get-ToolRequiredSharedBlocks, held against the defs that declare the tool -- $toolBlockFindings finding(s). Check 7 is the sibling and cannot serve this: it compares the INSIDE of a sentinel pair against its source and is silent on a pair that is absent, which is correct for a block placed by craft and wrong for one placed by capability. The personas are unaffected without an exemption -- a persona carries no 'tools:' line, so it names no tool. The reverse direction is deliberately not checked: carrying a block you are not obliged to is a decision, carrying none you are is the defect"
    })
# --- 37. this file's own check list, against the headers it claims to enumerate ---------------------
# THE FILE WHOSE JOB IS REFUSING HAND-MAINTAINED LISTS KEPT A SECOND ONE, and check 34 reaches only half
# of it. Check 34 reads the column-0 '# --- <n>.' headers back and holds them to each other; the prose
# list in this script's own .DESCRIPTION -- the one a reader who has not opened the file consults, and
# the one a lens, a hook, a test name or a release note quotes a number from -- was read by nothing.
#
# THE MEASURED DEFECT (issue #1680, September 9, 2026), and it had drifted in three directions at once.
# The list stopped at 30 while the code ran to 36, so six real checks had no line in it -- and a
# SEVENTH, 13b, was missing that no report had noticed: the check reported it on its first run. Item 30
# described the barred-skill check, which #1494 renumbered to 33 a month after the list was written --
# so a reader who grepped the list for "check 30" was told about a check answering to a different
# number, which is exactly the confusion #1494 was filed to end, one layer up. And items 9 and 17 still
# described checks RETIRED on August 8, 2026, reading as live ones; those are now tombstones keeping
# their number, for the reason the code keeps the gap -- reusing a number silently repoints every older
# citation.
#
# ONE DIRECTION ONLY, AND THAT IS WHAT MAKES IT BORN GREEN. Every header must have an entry; an entry
# need not have a header. The reverse direction is where the exemptions would live, and there are two
# legitimate kinds of entry with no header of its own: a retired check's tombstone (9 and 17), and the
# consumer-doc guard that the suites already call check 19. A rule reporting those would arrive needing
# an exemption list on the day it was written -- the shape this repo declined at 124 findings all false
# (the stale-path check, in the system-administration lens) and has refused since.
#
# OPT-IN, like checks 10, 29 and 32, and through the same Invoke-MarkedSpanWalk rather than a second
# span reader. A blanket rule keyed on "a script carrying numbered headers" would be born with a finding
# for each of the 19 files check 34 measured, none of which claims to enumerate anything. The marker is
# what turns a list into a claim, and it is the only thing that does.
#
# THE HEADER PATTERN IS CHECK 34'S, DELIBERATELY THE SAME LITERAL. Two readers disagreeing about what a
# section header is would let a header satisfy one and not the other, which is the divergence this file
# has extracted libs to prevent elsewhere. If that pattern ever moves, both move together.
#
# RAW TEXT ON BOTH ARGUMENTS OF THE WALK. The mask exists for markdown, where a fenced block inside a
# span would otherwise make claims; a PowerShell header comment has no fences to mask, and the walk's
# offsets then address the same bytes this check reads.
#
# AN ENTRY IS READ AT THE LIST'S OWN INDENT, and that bound came from PROBING this check rather than from
# measuring the tree -- which is check 35's own lesson ("a measurement tells you what a check catches
# here, and only a probe tells you what it would wave through") applied to its neighbour. The shape is a
# nested enumeration inside an entry's prose: a line opening with '1. ' indented under a paragraph. This
# list contains none today, so no amount of measuring it would have surfaced this; run past the check,
# such a line registered a claim. Counting one silences the check exactly where it matters -- drop
# entries 1 and 2 from the list and the nested pair keeps satisfying headers 1 and 2 forever, gate green,
# which is the drift this check exists to refuse. The level is taken from the shallowest candidate in
# each span, by DOT column rather than by leading spaces, because this list is right-aligned on the
# period (4, 5 and 6 spaces all occur).
#
# COUNTED ONCE PER FILE, over the union of its spans. Inside the callback each header was counted per
# SPAN, so a file carrying two spans reported its header count doubled and named one missing entry twice
# -- one defect, two owners, which is what the first-occurrence rule for headers above avoids. Two spans
# is the tolerant reading rather than an error of its own: a list legitimately split in two still
# enumerates one file.
#
# WHAT THIS DOES NOT HOLD, said here rather than left for a reader to discover. A STALE entry still
# satisfies its number: renumber check 33 to 38, add a '38.' entry, and the abandoned '33.' line -- still
# describing what is now 38 -- keeps header 33 satisfied. That is #1680's SECOND drift recurring, and it
# is not reachable from this side without reading an entry's text against a header's text. It is left
# open deliberately: a keyword-overlap rule is fuzzy, and a fuzzy rule on a gate arrives with an
# exemption list. Check 34's ascending rule is what limits the blast radius -- a renumber has to move the
# section and take the last free number -- so the shape is a lingering line, not a wrong live one.
#
# THERE IS NO FENCE TO HIDE THE MARKER BEHIND, unlike checks 10, 29 and 32, whose subjects are markdown.
# A script that must SHOW the marker -- a scaffolder emitting one, or a suite building a fixture that
# carries one -- composes it from a variable instead ("<!-- $tag -->"), which no marker regex matches.
# scripts/tests/check-plugin-integrity-commands.tests.ps1 does exactly that, and says why: it is a .ps1
# in the set this check walks, so a literal marker there would open a span in the SUITE.
#
# THE TWO ZERO STATES ARE SAID SEPARATELY, AND THAT BRANCH IS NOT REACHABLE FROM THE SUITE -- stated here
# rather than left as unexplained coverage. The note below distinguishes "no marker anywhere" (a clean
# opt-out) from "markers present, not one of them formed a span" (a broken gate), because keying on the
# span count alone printed the reassuring sentence over a run that had just raised an error about that
# very file: a true statement reading as a different, false one, which is what Write-Coverage's own
# docstring exists to prevent. It cannot be asserted in scripts/tests/: every fixture run invokes a COPY
# of this script inside the fixture, and that copy carries this list -- so one valid span always exists
# there and both zero states are unreachable. The suite covers the error itself (an unpaired marker) and
# the opt-out (a file with headers and no marker); the wording of the two zero notes is read, not tested.
#
# BORN GREEN: 1 span, 37 header(s), 37 claimed, 0 findings -- once the seven missing entries were
# written back on the branch that added this.
$clSpans    = 0
$clMarked   = 0
$clChecked  = 0
$clFindings = 0
foreach ($psFile in (Get-PsScriptFiles)) {
    $clText = [System.IO.File]::ReadAllText($psFile.FullName, [System.Text.Encoding]::UTF8)
    # The cheap raw test first, as in checks 10, 28, 29 and 32.
    if ($clText -notmatch '<!--\s*/?checks:list\s*-->') { continue }
    $clMarked++
    $clRel   = $psFile.FullName.Replace($RepoRoot, '.')
    $clLines = $clText -split "`r?`n"
    # Every column-0 numbered header in this file, first occurrence wins. A duplicate is check 34's
    # finding and not this one's -- reporting it twice would give one defect two owners.
    $clHeaderKeys  = New-Object System.Collections.Generic.List[string]
    $clHeaderLines = @{}
    for ($i = 0; $i -lt $clLines.Count; $i++) {
        if ($clLines[$i] -notmatch '^# --- (\d+)([a-z]?)\. ') { continue }
        $clKey = "$($Matches[1])$($Matches[2])"
        if ($clHeaderLines.ContainsKey($clKey)) { continue }
        $clHeaderLines[$clKey] = $i + 1
        $clHeaderKeys.Add($clKey)
    }
    # THE CLAIMS OF EVERY SPAN IN THE FILE, UNIONED, AND THE COMPARISON MADE ONCE AFTERWARDS. Run inside
    # the callback it counted each header once PER SPAN, so a file carrying two spans reported its header
    # count doubled and named one missing entry twice -- one defect, two owners, which is exactly what the
    # first-occurrence rule above avoids for headers. Two spans is also the tolerant reading rather than an
    # error of its own: a list legitimately split in two still enumerates one file.
    $clClaimed   = @{}
    $clSpanLines = New-Object System.Collections.Generic.List[int]
    Invoke-MarkedSpanWalk -MaskedText $clText -RawText $clText -Marker 'checks:list' `
        -Category 'check-list' -Rel $clRel -OnSpan {
        param($span)
        $script:clSpans++
        $clSpanLines.Add($span.BeginLineNo)
        # A span in a file with no headers is a claim about nothing, and silence would read as a pass.
        if ($clHeaderKeys.Count -eq 0) {
            $script:clFindings++
            Add-Error ("[check-list] ${clRel}: the 'checks:list' span at line $($span.BeginLineNo) claims to" +
                " enumerate this file's numbered checks, and the file carries no column-0" +
                " '# --- <n>. ' header at all. Either the headers were renamed out of the convention" +
                " check 34 holds, or the marker is on the wrong file.")
            return
        }
        $clRows = @($clText.Substring($span.SpanStart, $span.SpanEnd - $span.SpanStart) -split "`r?`n")
        # AN ENTRY MUST START INSIDE THE LIST'S GUTTER, and that bound came from probing this check rather
        # than from measuring the tree -- check 35's lesson, applied to its neighbour. A number opening a
        # line is not rare inside an entry's PROSE (a nested enumeration under a paragraph), and counting
        # one silences the check exactly where it matters: drop entries 1 and 2 from the list and the
        # nested pair keeps satisfying headers 1 and 2 forever, gate green, which is the drift this check
        # exists to refuse.
        #
        # THE GUTTER IS DERIVED, NOT ASSUMED, and it is a WIDTH rather than a column -- which is the
        # difference between this and the first attempt. The narrowest '<spaces><n><letter>' prefix in the
        # span is the gutter: a list right-aligned on the period puts wider keys further left, so the
        # leading spaces vary (4, 5 and 6 all occur here) while the prefix does not. But the alignment is
        # not perfect in practice -- 3b and 3c sit one column out -- and requiring the exact prefix width
        # dropped both, reporting two real entries as missing. So the rule is the weaker and truer one: an
        # entry's number must BEGIN no deeper than the gutter is wide. Every entry does, however ragged
        # the alignment; a line indented past the gutter is prose, and that is the whole discriminator.
        $clPrefixes = @()
        foreach ($clRow in $clRows) {
            if ($clRow -match '^(\s+\d+[a-z]?)\. ') { $clPrefixes += $Matches[1].Length }
        }
        if ($clPrefixes.Count -eq 0) { return }
        $clGutter = ($clPrefixes | Measure-Object -Minimum).Minimum
        foreach ($clRow in $clRows) {
            if ($clRow -notmatch '^(\s+)(\d+)([a-z]?)\. ') { continue }
            if ($Matches[1].Length -gt $clGutter) { continue }
            $clClaimed["$($Matches[2])$($Matches[3])"] = $true
        }
    }
    # ONCE PER FILE, over the union above. $clSpanLines is empty only when every marker in the file was
    # malformed, and the walk has already reported that.
    if ($clHeaderKeys.Count -eq 0 -or $clSpanLines.Count -eq 0) { continue }
    $clWhere = if ($clSpanLines.Count -eq 1) { "the 'checks:list' span at line $($clSpanLines[0])" }
               else { "any of this file's $($clSpanLines.Count) 'checks:list' spans (lines $($clSpanLines -join ', '))" }
    foreach ($clKey in $clHeaderKeys) {
        $clChecked++
        if ($clClaimed.ContainsKey($clKey)) { continue }
        $clFindings++
        Add-Error ("[check-list] ${clRel}:$($clHeaderLines[$clKey]): check $clKey has a section header but" +
            " no entry in $clWhere. That list is what a reader who has not opened this file consults, and" +
            " what a lens, a hook, a test name or a release note quotes a number from -- so a check missing" +
            " from it is one they cannot cite at all, and the neighbouring numbers then read as covering" +
            " ground they do not (#1680). Add a '$clKey.' entry saying what it does, at the list's own" +
            " indent -- a line indented deeper belongs to the entry above it and is not read as a claim.")
    }
}
Write-Coverage -Category 'check-list' -Checked $clChecked `
    -Note $(if ($clMarked -eq 0) {
        "no 'checks:list' marker anywhere in this repo's script set. The marker is opt-in, so zero is a pass and not a gap -- but no script's own summary of its numbered checks is being held to those checks by this run"
    } elseif ($clSpans -eq 0) {
        "$clMarked file(s) carry a 'checks:list' marker and NOT ONE FORMED A SPAN -- every marker in them is unpaired, and the errors above say which. Nothing was compared: read this as a broken gate rather than as a clean one. Said separately from the zero-marker case deliberately, because the two produce the same count and mean opposite things"
    } else {
        "column-0 numbered header(s) held to the list that claims to enumerate them, over $clSpans marked span(s) in $clMarked file(s) -- $clFindings finding(s). Counted ONCE PER FILE over the union of its spans, so two spans cannot double the figure or name one gap twice. AN ENTRY MUST START INSIDE THE LIST'S GUTTER, whose width is the narrowest number prefix in the span: a line indented past it is an entry's prose, and counting a nested enumeration there would silence the check where the missing entry sits below it. ONE DIRECTION: an entry with no header is deliberately not reported, because a retired check keeps its number as a tombstone and the consumer-doc guard the suites call check 19 carries no header of its own, so the reverse rule would be born needing exactly those exemptions -- the cost is that a STALE entry still satisfies its number, which is #1680's second drift and is NOT held here. Check 34 is the sibling and cannot serve this: it holds the headers to EACH OTHER and has no opinion about the prose that summarises them"
    })
# --- 38. a plugin's 'agents' key: the shape the installer accepts, and every def it ships ------------
# THE GATE CALLED A MANIFEST SOUND THAT THE INSTALLER REFUSES OUTRIGHT (issue #1764, September 10, 2026).
# Checks 1 and 2 read every plugin.json -- check 1 for the marketplace's view of it, check 2 for valid JSON
# and a non-empty name -- and neither has ever had an opinion about a FIELD's accepted shape. So all four
# team plugins shipped in v4.33.0 with "agents": "./subagents/", this gate reported 0 error(s) over them,
# CI agreed, and 'claude plugin install <id>@dkj-claude-plugins --scope project' answered
# 'Validation errors: agents: Invalid input' on every one. Four of the six plugins in the marketplace could
# not be installed at all, by any consumer, for a whole release.
#
# THE ACCEPTED SHAPE, MEASURED AGAINST THE LIVE VALIDATOR rather than read off the reference (Claude Code
# 2.1.267, 'claude plugin validate <path>'):
#
#     "./subagents/"                        agents: Invalid input
#     ["./subagents/"]                      agents.0: Invalid input   -- the array is fine, the element is not
#     "./subagents"   (no trailing slash)   agents: Invalid input     -- nor is the slash the objection
#     ["./subagents/*.md"]                  Path not found            -- no glob is expanded
#     "./subagents/04-18-agent.md"          passes                    -- a bare string IS one element
#     ["./x-agent.md", "./y-agent.md"]      passes
#
# So 'agents' is string|string[] over paths to EXISTING .md FILES. A directory is not a legal element in
# either form. THE REFERENCE SAYS OTHERWISE AND IS WRONG: it lists 'agents' among the fields that replace
# their default directory and prints ["./agents/", "./custom-agents/reviewer.md"] as the way to keep the
# default and add more -- an example this validator rejects at element 0. 'commands': ["./subagents/"]
# passes on the same manifest, so the two fields genuinely diverge where the docs treat them alike. That is
# upstream and is not this repo's to repair; what IS this repo's is not trusting the reference again.
#
# WHY THE DOC WAS BELIEVED, which is the part worth keeping. #1698 renamed each team's agents/ directory to
# subagents/ and justified reaching for the key on exactly that sentence -- "it is permitted by the plugin
# format: the reference documents an 'agents' key (string or array) that replaces the default directory."
# The premise was read, not run. One 'claude plugin validate' on that branch would have answered it.
#
# TWO DIRECTIONS, AND THE SECOND IS WHY A GATE AND NOT A ONE-OFF FIX. Dave chose (September 10, 2026) to
# keep the subagents/ name and list the files, over renaming back to agents/ and dropping the key -- so this
# repo now carries a hand-maintained list of 26 paths across four manifests, which is the shape this file
# exists to refuse. A specialist added tomorrow without touching its manifest would silently not ship, and
# nothing else in the tree looks: the roster check counts SPECIALISTS.md rows against the defs on disk and
# reads a manifest never. So completeness is held here, in the same check as the shape:
#
#   the shape        -- an element that is not an existing .md file inside the plugin root. The installer
#                       refuses the WHOLE PLUGIN, and #1764 is what that costs.
#   the completeness -- an agent def the plugin ships that no element names. It installs fine and simply
#                       never loads, with every gate green.
#
# AND A THIRD SHAPE, which is #1698's own defect stated as a rule: a plugin holding defs OUTSIDE the default
# agents/ directory with no key at all declares nothing, so convention discovery finds none of them. That is
# the state the rename would have produced had it not reached for the key, and it reads as a clean gate too.
#
# NOT DELEGATED TO 'claude plugin validate', though it is the authority the table above came from. It would
# be the shape half and only that -- it has no opinion about a def the list omits, which is the finding
# Dave's chosen repair actually needs -- and it would put a CLI on this gate's critical path, in CI and in
# every consumer, for an answer thirty lines of PowerShell give offline.
#
# A NESTED PLUGIN ROOT IS NOT ITS PARENT'S CONTENT. plugins/dkj-policy/dkj-policy-bwj sits inside
# plugins/dkj-policy, so a plain recursive scan would credit the child's files to the parent and demand the
# parent declare them. Neither ships an agent def today, so nothing bites -- which is exactly why it is
# handled now rather than after it does.
#
# BORN GREEN, over the repair in the same branch: 4 plugin(s) declaring 26 def(s), 26 named, 0 findings, 0
# exemptions. Against the tree as v4.33.0 shipped it the same reader reports 4 -- one per team plugin -- so
# it fires on what it was written for rather than merely passing.
#
# AND THE COMPLETENESS RULE IS MEASURED AGAINST THE LOADER NOW, not only inferred from the validator
# (#1771, September 10, 2026). It was proposed that this check should additionally REFUSE the key outright,
# on the ground that 'claude plugin details' reports 'Agents (0)' for all four team plugins and the key
# therefore registers nothing. That count is the inventory's, and the inventory counts only defs found by
# convention in the default agents/ directory -- it says nothing about what a session loads. A two-plugin
# control settles it: two defs in one non-default directory, only one named by the key, installed into a
# scratch project and read back from a real session via 'claude -p'. The named def is THERE; the unnamed
# one, same directory, is NOT. So the key is honoured, and honoured exclusively, exactly as the
# completeness finding above says -- and refusing it would forbid the mechanism that works. The defect
# #1771 actually found is in the instrument: measure-skill.ps1 read the empty per-component table of an
# agents-only plugin as a CLI format change, which is repaired there.
$akPlugins  = 0
$akDeclared = 0
$akFindings = 0
$akRoots    = @($publishedPlugins)
foreach ($akPlugin in $akRoots) {
    if (-not (Test-Path -LiteralPath $akPlugin.ManifestPath -PathType Leaf)) { continue }
    $akManifest = Test-JsonFile -Path $akPlugin.ManifestPath
    if (-not $akManifest) { continue }
    $akRel         = $akPlugin.RelativeRoot
    $akManifestRel = $akPlugin.ManifestPath.Replace($RepoRoot, '.')
    $akRootPrefix  = $akPlugin.Root.TrimEnd('\') + '\'

    # THE PLUGIN'S OWN DEFS: every *-agent.md under its root that does not belong to a plugin nested
    # deeper. Discovered from disk rather than from a list, which is the whole point of the check.
    $akOwnDefs = @()
    foreach ($akFile in @(Get-ChildItem -LiteralPath $akPlugin.Root -Recurse -Filter '*-agent.md' -File -ErrorAction SilentlyContinue)) {
        $akOwner = $true
        foreach ($akOther in $akRoots) {
            $akOtherPrefix = $akOther.Root.TrimEnd('\') + '\'
            if ($akOtherPrefix -eq $akRootPrefix) { continue }
            if ($akOtherPrefix.StartsWith($akRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
                $akFile.FullName.StartsWith($akOtherPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $akOwner = $false
                break
            }
        }
        if ($akOwner) { $akOwnDefs += $akFile }
    }

    $akPlugins++
    $akHasKey = ($akManifest.PSObject.Properties.Name -contains 'agents') -and $null -ne $akManifest.agents
    if (-not $akHasKey) {
        # NO KEY IS THE CONVENTION, and the convention is the literal directory 'agents/'. A def anywhere
        # else is undeclared and unreachable.
        $akStrays = @($akOwnDefs | Where-Object { $_.FullName -notmatch '(?i)\\agents\\' })
        if ($akStrays.Count -gt 0) {
            $akFindings++
            Add-Error ("[agents-key] ${akManifestRel}: declares no 'agents' key, so Claude Code discovers" +
                " agent defs by convention from '$akRel\agents\' only -- and this plugin ships" +
                " $($akStrays.Count) def(s) outside it, starting with" +
                " '$($akStrays[0].FullName.Replace($RepoRoot, '.'))'. None of them loads in any consumer." +
                " Either move them under agents\, or list them in an 'agents' array -- paths to .md FILES," +
                " because a directory is not a legal element (#1764).")
        }
        continue
    }

    # string|string[]: a bare string is one element, which is what the validator accepts. Read through
    # plugin-tree-lib's Get-ManifestAgentEntries, the ONE reading of this field -- measure-skill-lib's
    # Get-DeclaredAgentCount carried a second one until #1781, and the two could not disagree loudly.
    $akEntries = @(Get-ManifestAgentEntries -Manifest $akManifest)
    $akNamed = @{}
    foreach ($akEntry in $akEntries) {
        $akDeclared++
        if ($akEntry -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$akEntry)) {
            $akFindings++
            Add-Error ("[agents-key] ${akManifestRel}: an 'agents' entry is not a non-empty string. The" +
                " field is string|string[] over paths to .md files; anything else the installer refuses as" +
                " 'agents: Invalid input', and the whole plugin then fails to install (#1764).")
            continue
        }
        $akEntryText = [string]$akEntry
        if ($akEntryText -notmatch '(?i)\.md$') {
            $akFindings++
            Add-Error ("[agents-key] ${akManifestRel}: 'agents' entry '$akEntryText' does not name a .md" +
                " file. The installer refuses it -- a DIRECTORY is not a legal element in either the string" +
                " or the array form, and no glob is expanded, whatever the plugins reference says about" +
                " replacing the default directory (measured against Claude Code 2.1.267, #1764). List each" +
                " agent def by its own path.")
            continue
        }
        $akResolved = $null
        try { $akResolved = [System.IO.Path]::GetFullPath((Join-Path $akPlugin.Root ($akEntryText -replace '/', '\'))) } catch {}
        if (-not $akResolved -or -not $akResolved.StartsWith($akRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $akFindings++
            Add-Error ("[agents-key] ${akManifestRel}: 'agents' entry '$akEntryText' resolves outside the" +
                " plugin root '$akRel'. What is registered here gets published, so a path leaving the" +
                " plugin cannot travel with it -- the same containment rule check 1 holds a marketplace" +
                " source to.")
            continue
        }
        if (-not (Test-Path -LiteralPath $akResolved -PathType Leaf)) {
            $akFindings++
            Add-Error ("[agents-key] ${akManifestRel}: 'agents' entry '$akEntryText' names no file that" +
                " exists. The installer reports that as a path-not-found and refuses the plugin, so a" +
                " renamed or deleted def takes the whole install down rather than just itself.")
            continue
        }
        $akNamed[$akResolved.ToLowerInvariant()] = $true
    }

    # COMPLETENESS, the direction the installer has no opinion about: a def on disk that the list omits
    # loads for nobody, and every other check here stays green over it.
    foreach ($akDef in $akOwnDefs) {
        if ($akNamed.ContainsKey($akDef.FullName.ToLowerInvariant())) { continue }
        $akFindings++
        Add-Error ("[agents-key] ${akManifestRel}: ships" +
            " '$($akDef.FullName.Replace($RepoRoot, '.'))' but no 'agents' entry names it, so it does not" +
            " load in any consumer. Once the key is present it REPLACES convention discovery, so the list" +
            " is the only way in -- which is why this repo holds it to the directory rather than to memory" +
            " (#1764). Add the path, keeping the list in the order its neighbours are in.")
    }
}
Write-Coverage -Category 'agents-key' -Checked $akPlugins `
    -Note $(if ($akRoots.Count -eq 0) {
        'no published plugin root resolved at all, so no manifest was read -- read this as a broken gate rather than a clean one; check 1 says why'
    } elseif ($akDeclared -eq 0) {
        "published plugin(s) read and NOT ONE declares an 'agents' key. That is a pass where every plugin keeps its defs in the default agents\ directory, and the stray-def rule is what proves it -- but no entry's shape was measured in this run"
    } else {
        "published plugin(s) read, $akDeclared 'agents' entry(s) held to the shape the installer accepts -- an EXISTING .md FILE inside the plugin root, never a directory and never a glob -- and every *-agent.md each plugin ships held to the list that has to name it: $akFindings finding(s). BOTH DIRECTIONS, because they fail differently: a bad element makes the installer refuse the whole plugin (#1764 -- four of six uninstallable for a release), while a def the list omits installs fine and simply never loads. Checks 1 and 2 are the siblings and cannot serve this: they read the same manifests for the marketplace's view and for valid JSON with a name, and neither has an opinion about a field's accepted shape, which is why this gate reported 0 error(s) over manifests 'claude plugin validate' refuses outright. Not delegated to that CLI either: it is the authority this shape was measured against, but it is silent on the omitted def and would put a CLI on this gate's path in CI and in every consumer"
    })
# --- 39. a depth-sensitive $PSScriptRoot resolution, against the suite that runs the mirror ----------
# CHECK 8 PROVES THE TWO COPIES ARE THE SAME TEXT AND CANNOT PROVE THEY BEHAVE THE SAME (issue #1857).
# A shared script exists twice -- scripts\<area>\<name>.ps1 and <plugin>\scripts\<area>\<name>.ps1 --
# and byte-equality is exactly what makes the difference invisible: the characters are identical, and
# the two files sit at different depths, so a $PSScriptRoot resolution that ascends TWO levels reaches
# the repo root from the source copy and the PLUGIN root from the mirror. Same line, different folder,
# nothing to diff.
#
# WHY THAT IS WORTH A GATE RATHER THAN A NOTE. The mirror is the copy a consumer runs -- the source
# copy exists for this repo and for its suites. So the candidate that fires in every released install
# is precisely the one no test executes, and the failure mode is a path that silently resolves
# somewhere plausible rather than an error anybody sees. It was verified by hand when #1843 introduced
# such a resolution, and hand verification is what this repo keeps replacing with gates.
#
# WHAT IS ASKED, AND WHAT IS NOT. This check refuses an UNDECLARED depth-crossing resolution: the pair
# must name the suite that runs its mirror (MirrorRun) or say why it does not (MirrorRunExempt), and
# the named suite must exist and name the mirror, so a declaration cannot be fiction. It does not try
# to prove from here that the suite ASSERTS anything -- that is the suite's job and it is where the
# proof belongs, the same division check 18 already draws between this gate and a skill page. What the
# gate is for is the script nobody has thought about yet.
#
# ONE HOP IS NOT ASKED ABOUT, deliberately. '..\lib\...' reaches <x>\scripts\ in both copies, which is
# the same folder relative to the file either way -- so the overwhelming majority of resolutions in
# the tree are depth-invariant by construction and a check that flagged them would be noise. Measured
# when this was written: 3 of 34 entry points cross the boundary, and all three were already correct.
#
# THE THIRD ONE ARRIVED WHILE THIS CHECK WAS BEING BUILT, which is the best argument for it there is.
# The branch measured two; adopt-workflow-folder's PR-template reference merged to main in between and
# this gate caught it on its first CI run, because CI tests the merge and the branch's own working copy
# could not see it. A count taken from a branch base is a snapshot, and this one went stale inside a
# day -- so the live figures are in the coverage line below and this number is dated on purpose.
$msPairs = @($sharedPairs)
$msChecked = 0
$msCrossing = 0
$msDeclared = 0
$msFindings = 0
$msTestsDir = Join-Path $RepoRoot 'scripts\tests'
foreach ($pair in $msPairs) {
    if (-not (Test-Path -LiteralPath $pair.SourcePath -PathType Leaf)) { continue }
    $msChecked++
    $msHits = @(Get-DepthSensitiveResolutions -Path $pair.SourcePath)
    if ($msHits.Count -gt 0) { $msCrossing++ }

    if ($pair.MirrorRun -and $pair.MirrorRunExempt) {
        $msFindings++
        Add-Error ("[mirror-depth] shared-scripts registry: '$($pair.Name)' declares BOTH MirrorRun and" +
            " MirrorRunExempt. They are opposite answers -- one says a suite runs the mirror, the other" +
            " says none does and why -- so a pair carrying both leaves no reader able to say which is" +
            " true. Keep one.")
        continue
    }

    if ($msHits.Count -gt 0 -and -not $pair.MirrorRun -and -not $pair.MirrorRunExempt) {
        $msFindings++
        $msShown = ($msHits | Select-Object -First 2) -join ' | '
        Add-Error ("[mirror-depth] $($pair.SourceRel) resolves a path off `$PSScriptRoot that ascends two" +
            " or more levels, so it means the repo root in this copy and the plugin root in" +
            " $($pair.MirrorRel) -- and check 8 cannot see the difference, because the two files are" +
            " byte-identical. Found: $msShown. Declare MirrorRun = '<suite>.tests.ps1' in the" +
            " shared-scripts registry (scripts\lib\shared-scripts-lib.ps1), naming a suite that EXECUTES" +
            " the mirror from its own directory the way git-identity-gate.tests.ps1 does -- or" +
            " MirrorRunExempt = '<reason>' if that resolution genuinely cannot differ.")
        continue
    }

    if (-not $pair.MirrorRun) { continue }
    $msDeclared++
    $msSuite = Join-Path $msTestsDir $pair.MirrorRun
    if (-not (Test-Path -LiteralPath $msSuite -PathType Leaf)) {
        $msFindings++
        Add-Error ("[mirror-depth] shared-scripts registry: '$($pair.Name)' declares MirrorRun =" +
            " '$($pair.MirrorRun)', and no such suite exists under scripts\tests\. A declaration that" +
            " names nothing is worse than none, because it reads as proof.")
        continue
    }
    $msText = [System.IO.File]::ReadAllText($msSuite, [System.Text.Encoding]::UTF8)
    if (-not ($msText.Contains($pair.MirrorRel) -or $msText.Contains($pair.MirrorRel.Replace('\', '/')))) {
        $msFindings++
        Add-Error ("[mirror-depth] scripts\tests\$($pair.MirrorRun) is declared as the suite that runs" +
            " '$($pair.Name)'s mirror, and it never names $($pair.MirrorRel). Either it does not run the" +
            " mirror at all, or it reaches it by a path this check cannot follow -- both of which make" +
            " the declaration unverifiable from here.")
    }
}
Write-Coverage -Category 'mirror-depth' -Checked $msChecked `
    -Note $(if ($msChecked -eq 0) {
        'the source/mirror pair list is empty, so no script was scanned -- read this as a broken gate rather than a clean one, the way check 8 reads its own empty set'
    } else {
        "shared script(s) scanned for a `$PSScriptRoot resolution ascending two or more levels -- the ONE class where a byte-identical mirror can behave differently, because the two copies sit at different depths: $msCrossing crossing, $msDeclared with a declared suite, $msFindings finding(s). One hop is not asked about and that is the point: '..\lib\...' is the same folder relative to the file in both copies, so asking about it would bury the crossings above under the thirty-odd that cannot. What this proves is that no such resolution is UNDECLARED, and what it deliberately leaves to the suite is whether the run asserts anything -- the same line check 18 draws between this gate and a skill page"
    })


# --- 40. a plugin script's $PSScriptRoot-bound load, against the plugin that has to carry it --------
# CHECK 8 PROVES THE TWO COPIES ARE THE SAME TEXT, CHECK 39 THAT THE TEXT MEANS THE SAME FOLDER, AND
# NEITHER ASKS WHETHER THE FILE IT NAMES IS THERE (issue #1925). A shared script is generated into the
# plugin it is registered for, and the mirror resolves '..\lib\<name>.ps1' inside THAT plugin -- so a
# lib registered for two plugins and dot-sourced by a script that mirrors into a third names a file
# its destination does not have. Check 8 has nothing to compare, because there is no third entry to
# compare against; check 39 asks about a TWO-hop ascent and one hop is deliberately outside its
# subject. The gap between them is the one class where a byte-perfect mirror is simply broken where it
# lands.
#
# MEASURED, September 13, 2026, on the #1917 branch: adopt-shopify-floor.ps1, archive-theme.ps1,
# push-preview.ps1 and sync-main.ps1 each gained '. (Join-Path $PSScriptRoot ''..\lib\check-report-lib.ps1'')',
# check-report-lib was registered for dkj-policy and dkj-subagents-alpha, and those four mirror into
# dkj-subagents-shopify, whose scripts\lib\ held no such file. All four would have died ON LOAD in a
# consumer, at their first statement, before any of their own logic ran -- and this gate reported
# 0 error(s) over them.
#
# THE SUBJECT IS THE PLUGIN COPY, NOT THE SOURCE, and that is the whole point. A source script's
# neighbours are all present in this tree, which is exactly why the defect is invisible from there;
# the copy a consumer installs is where the reference either resolves or does not. Every .ps1 under a
# published plugin root is read, hooks included -- they dot-source libs too -- so a plugin-NATIVE
# script that names an absent lib is caught by the same pass rather than needing a rule of its own.
#
# TWO ARMS, BECAUSE THEY FAIL DIFFERENTLY AND ONLY ONE IS VISIBLE FROM HERE. An ABSENT file is absent
# in both copies, so a probe of this tree finds it. A reference that ESCAPES the plugin root resolves
# to a real file HERE -- the repo has every path a plugin script could climb to -- and is gone in the
# installed copy, where the 'plugins/' level, the family level and every sibling are stripped away.
# That is check 30's lesson one layer over: the tree a link is validated in is not the tree it ships
# to, and existence alone is the test that cannot see it. Probed rather than measured (check 35's
# rule): an escaping reference planted in a shopify mirror pointed at scripts\lib\release-lib.ps1,
# passed existence, and only the containment arm reported it.
#
# GUARDED REFERENCES ARE COUNTED AND NOT JUDGED. 'if (Test-Path $lib) { . $lib }' is the author saying
# the absence is expected, and this tree means it: release-lib's branch-info sibling is repo-owned and
# deliberately absent from every mirror, and several libs are guarded so a mirror older than the lib
# does not crash on load. 70 of the 224 references are guarded, so judging them would have arrived
# with 70 findings and an exemption list -- the shape this repo declined at 124 (the stale-path check,
# in the system-administration lens). The unguarded reference is the opposite statement: it runs at
# load, so a missing file is not a degradation but a crash at statement one.
#
# ONLY $PSScriptRoot IS A SUBJECT. 'Join-Path $repoRoot ''scripts\lib\branch-info.ps1''' names a file
# in the CONSUMER'S root by design -- branch-info is repo-owned and does not travel -- so reading a
# $repoRoot-relative path as plugin-relative reports 14 findings here, all 14 false and all 14 that
# same seam. The binding is done through the AST by Resolve-ScriptRootRelativePath rather than by a
# regex over 'lib\<name>.ps1', which cannot tell the two bases apart at all.
$plRoots    = @($publishedPlugins)
$plFiles    = 0
$plRefs     = 0
$plGuarded  = 0
$plFindings = 0
foreach ($plPlugin in $plRoots) {
    $plPrefix = $plPlugin.Root.TrimEnd('\') + '\'
    $plRel    = $plPlugin.Root.Replace($RepoRoot, '.')
    foreach ($plFile in (Get-ChildItem -LiteralPath $plPlugin.Root -Recurse -Filter *.ps1 -File -ErrorAction SilentlyContinue)) {
        $plFiles++
        $plFileRel = $plFile.FullName.Replace($RepoRoot, '.')
        foreach ($plRef in (Get-ScriptRootRelativeLoads -Path $plFile.FullName)) {
            if ($plRef.Guarded) { $plGuarded++; continue }
            $plRefs++
            $plResolved = $null
            try { $plResolved = [System.IO.Path]::GetFullPath((Join-Path $plFile.Directory.FullName $plRef.RelativePath)) } catch {}
            if (-not $plResolved) { continue }
            if (-not $plResolved.StartsWith($plPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $plFindings++
                Add-Error ("[plugin-lib] ${plFileRel}: loads '$($plRef.Text)', which climbs OUT of" +
                    " '$plRel'. It resolves here, because this tree holds every path a plugin script" +
                    " could climb to -- and in the installed copy under" +
                    " ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/ the 'plugins/' level," +
                    " the family level and every sibling plugin are gone, so it resolves nowhere. A" +
                    " load runs before the script's own logic, so this is a crash at statement one" +
                    " rather than a degradation. Give the lib a mirror into THIS plugin (the" +
                    " shared-scripts registry in scripts\lib\shared-scripts-lib.ps1), or guard the" +
                    " dot-source with Test-Path if its absence is genuinely expected.")
                continue
            }
            if (-not (Test-Path -LiteralPath $plResolved -PathType Leaf)) {
                $plFindings++
                Add-Error ("[plugin-lib] ${plFileRel}: loads '$($plRef.Text)', and '$plRel' ships no" +
                    " such file. Nothing else here can see that: check 8 holds a REGISTERED mirror to" +
                    " its source and there is no entry for this plugin to compare, and check 39 asks" +
                    " about a two-hop ascent while this is one hop. In a consumer the script dies ON" +
                    " LOAD, at its first statement, before any of its own logic runs. Register the lib" +
                    " for this plugin too in the shared-scripts registry" +
                    " (scripts\lib\shared-scripts-lib.ps1) and rebuild with" +
                    " scripts\sync\build-shared-scripts.ps1 -- or guard the dot-source with Test-Path" +
                    " if its absence is genuinely expected, which is what this check reads as a" +
                    " declaration rather than a defect.")
            }
        }
    }
}
Write-Coverage -Category 'plugin-lib' -Checked $plFiles `
    -Note $(if ($plRoots.Count -eq 0) {
        'no published plugin root resolved at all, so not one script was read -- read this as a broken gate rather than a clean one, the way checks 38 and 39 read their own empty sets'
    } elseif ($plRefs -eq 0) {
        "script(s) under $($plRoots.Count) published plugin root(s) read, and NOT ONE carries an unguarded `$PSScriptRoot-bound load of another .ps1 ($plGuarded guarded). That is a pass with nothing measured in it -- every lib is reached some other way -- so it says as little as an empty scan does"
    } else {
        ".ps1 file(s) under $($plRoots.Count) published plugin root(s), carrying $plRefs unguarded `$PSScriptRoot-bound load(s) of another .ps1, each resolved against the plugin it would land in and held BOTH ways -- the file exists, and the path stays inside that plugin root: $plFindings finding(s). $plGuarded further reference(s) are guarded by a Test-Path and are counted rather than judged, which is the author declaring the absence expected (release-lib's branch-info sibling is repo-owned and absent from every mirror on purpose). The escape arm is not redundant with the existence arm: an escaping path resolves HERE, because this tree holds everything a plugin script could climb to, and is gone in the install -- check 30's lesson one layer over. Only `$PSScriptRoot is a subject, bound through the AST: a `$repoRoot-relative path names a file in the CONSUMER'S root by design, and reading those as plugin-relative reports 14 findings on this tree, all false"
    })
# --- 41. the fixture-script load guard, against the suites that carry it ----------------------------
# WHAT #1934 LEFT UNGUARDED (issue #1948). scripts/lib/fixture-script-lib.ps1 exists because a suite here
# copies an acting script into a fixture tree and runs it in a child process, and since #1917 those
# scripts dot-source check-report-lib.ps1 UNGUARDED -- so a fixture missing a lib the script loads kills
# the child during LOAD, before it writes anything. What the suite then reports is the absence of the
# document the child never got far enough to write, naming the absent lib, the dot-source and load
# failure not at all. Six suites failed exactly that way on the #1917 branch (#1924): fold-changelog 155
# asserts red, prune-merged 73, park-branch 18, and three dead on load.
#
# #1934 wired those six, in three parts per suite: the dot-source, an Assert-FixtureScriptLoaded call
# where the child's exit code and captured output are both in hand, and Write-FixtureScriptSummary whose
# verdict becomes an exit code. NOTHING ASSERTED THAT ANY OF THE THREE WAS STILL THERE. An edit to
# Invoke-Fold, to Invoke-CapturedChild or to any of the other helpers that dropped the call would
# silently restore the exact class, and every suite would stay green while doing it.
#
# THE RULE AS FILED WAS MEASURED AND RETIRED, WHICH IS WHY THIS ONE HAS A DIFFERENT SHAPE. #1948 proposed
# the sibling of check 35: a suite that invokes a child .ps1 and captures BOTH its exit code and its
# output, and does not call Assert-FixtureScriptLoaded on the same statement or the next, is a finding.
# Probed over scripts/tests/ before anything was built: 82 such invocations, 11 of them in a scope that
# judges, so 71 FINDINGS. That is not a regression guard -- it is a proposal to wire 65 more suites, which
# is a real question and is filed separately as #1954. Born at 71 findings this would be the shape this
# repo declined outright for the stale-path check (124 findings, all false), and the adjacency half is
# wrong independently: the six wire their call two to four statements after the invocation, so check 35's
# same-statement-or-the-next rule reports all six of the WIRED suites as findings.
#
# SO THE SUBJECT IS THE WIRING, NOT THE INVOCATION, and the rule is self-anchoring: a suite carrying ANY
# of the three parts must carry all three. That needs no hand-maintained list of which suites are wired,
# because the file's own content says whether it has adopted the helper -- and a hand-listed set of files
# is the failure #1693, #1865 and #1924 each ended up removing. Born green: 7 files carry a part, all 7
# carry all three, 0 exemptions. Probed against the hazard by dropping one call from fold-changelog and
# the summary from park-branch: 2 findings, each naming the file and the part.
#
# THE FOURTH FACT IS THAT THE SUMMARY IS READ, because printing it is not what fails the run.
# Write-FixtureScriptSummary RETURNS whether something died on load and the caller turns that into an
# exit code -- '$loadBroken = Write-FixtureScriptSummary ...' in all six, then 'if ($loadBroken)'. Drop
# only the read and the suite prints the block and exits 0, which is the silence this whole lib exists to
# remove, wearing the helper's own output as proof that it is wired. Discarded or never read is therefore
# a finding in its own right, and the three spellings that count as a read are an assignment whose
# variable is read later, a direct use in a condition, and a use as an argument -- all three occur here.
#
# AND WHAT PART 4 DOES NOT REACH IS STATED HERE RATHER THAN LEFT TO BE DISCOVERED. It asks whether the
# verdict is READ, not whether it reaches an 'exit': a read is a read, so a suite whose only use of
# '$loadBroken' is 'Write-Host "load broken: $loadBroken"' clears this check while exiting 0 -- the very
# silent-success shape the part exists to catch, spelled as an interpolation. Telling that from a read
# that GATES needs data-flow analysis, which is a different instrument from the AST walk every other
# check here does, and one nobody has asked this gate to carry. The three cheap narrowings WERE made
# (after-not-anywhere, same-function, and the implicit-return arm), because each removes a false answer
# without changing the instrument. This one is the ceiling, and a guard that names its own ceiling is
# worth more than one that is assumed to have none -- #1948's whole subject is a guard nobody noticed
# had stopped guarding.
#
# ONE DIRECTION ONLY: a suite that carries NONE of the three parts is not a subject. Whether it should be
# wired is #1954's question, measured at 65 suites, and answering it here would be the 71-finding check
# under another name.
#
# NOT SKIPPABLE, and it shares the parse and the walk of the script set with checks 31, 33 and 35 through
# Get-PsScriptCommandAsts (issue #1358) rather than parsing scripts/tests/ a second time.
$fsFiles    = @(Get-PsScriptFiles | Where-Object { $_.FullName -match '\\scripts\\tests\\' })
$fsWired    = 0
$fsFindings = 0
foreach ($fsFile in $fsFiles) {
    $fsRel  = $fsFile.FullName.Replace($RepoRoot, '.')
    $fsCmds = @(Get-PsScriptCommandAsts -Path $fsFile.FullName)

    # -- part 1: the dot-source ------------------------------------------------------------------
    # THROUGH THE AST, NOT THE LINE TEXT -- the same rule check 35 states for the same reason. A text
    # match on the lib's name is satisfied by this very comment, by a string, or by a mention in a
    # docstring, any of which would clear a file that has genuinely lost the load.
    #
    # THE LEAF IS ANCHORED, because 'contains the substring' is satisfied by a DIFFERENT file whose name
    # merely ends the same way -- '..\lib\my-other-fixture-script-lib.ps1' dot-sourced instead, and this
    # counted the suite as wired. No such file exists here; the anchor is what keeps the finding honest
    # if one ever does. Caught by probing the check rather than by reading it.
    $fsHasSource = @($fsCmds | Where-Object {
        $_.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot -and
        $_.Extent.Text -match '[\\/''"]fixture-script-lib\.ps1'
    }).Count -gt 0

    # -- parts 2 and 3: the verdict and the summary -----------------------------------------------
    $fsAsserts  = @($fsCmds | Where-Object { $_.GetCommandName() -eq 'Assert-FixtureScriptLoaded' })
    $fsSummary  = @($fsCmds | Where-Object { $_.GetCommandName() -eq 'Write-FixtureScriptSummary' })
    $fsHasAssert  = $fsAsserts.Count  -gt 0
    $fsHasSummary = $fsSummary.Count -gt 0

    $fsParts = @($fsHasSource, $fsHasAssert, $fsHasSummary) | Where-Object { $_ }
    if (@($fsParts).Count -eq 0) { continue }
    $fsWired++

    foreach ($fsMissing in @(
        @{ Present = $fsHasSource;  Name = "the dot-source of scripts/lib/fixture-script-lib.ps1" }
        @{ Present = $fsHasAssert;  Name = "a call to Assert-FixtureScriptLoaded" }
        @{ Present = $fsHasSummary; Name = "a call to Write-FixtureScriptSummary" }
    )) {
        if ($fsMissing.Present) { continue }
        Add-Error ("[fixture-script] ${fsRel}: this suite carries part of the #1934 fixture load guard" +
            " but not $($fsMissing.Name). The three travel together: without the dot-source the other" +
            " two are unresolved commands, without the verdict a child that died on LOAD is reported as" +
            " the absence of the document it never wrote, and without the summary a run where every" +
            " assert happened to pass still exits 0 after measuring a fixture rather than the script." +
            " Restore the missing part, or remove all three if this suite is deliberately unwired.")
        $fsFindings++
    }

    # -- part 4: the summary's verdict is READ -----------------------------------------------------
    foreach ($fsCall in $fsSummary) {
        # THE UNWRAP AND THE DISCARD RULES ARE SHARED WITH CHECK 35 (issue #1956), not copied here.
        # A near-verbatim copy stood in this spot, and it had already DRIFTED from the original in the
        # one way that matters: it climbed straight THROUGH a ConvertExpressionAst without noticing a
        # [void] cast, so '[void](Write-FixtureScriptSummary ...)' standing as a function's LAST
        # statement fell into the implicit-return arm below and was cleared as a READ -- while [void] is
        # precisely what stops it being one. Measured against the real check before the extraction: as a
        # last statement 0 findings, one line further up 1 finding. The same call, the same cast, two
        # answers. That is check 35's own lesson, generalised -- arms that disagree about wrapping teach
        # the shape that gets past it -- arriving one level up, which is why the rule is now one
        # function rather than two implementations of it.
        $fsDiscard = Get-DiscardedOuterPipeline -Call $fsCall
        if ($null -eq $fsDiscard) { continue }
        $fsOuter = $fsDiscard.Outer

        # A READ IS ANY OF THREE SHAPES, and all three occur in this tree: the value is assigned to a
        # variable that is read again later in the file (the six wired suites' '$loadBroken'), or it is
        # consumed directly -- as a condition, or as an argument to another command. The last two are
        # the lib's own suite, which asserts the return rather than storing it.
        $fsRead = $false
        $fsUp = $fsOuter.Parent
        if ($fsDiscard.Discarded) {
            # A DISCARD ANSWERS THE QUESTION ON ITS OWN, in all three spellings -- an 'Out-Null' tail, a
            # '$null =' assignment, and a '[void]' cast. It is asked FIRST rather than subtracted from
            # the arms afterwards, because the implicit-return arm cannot tell a cast-away last statement
            # from a handed-back one: that is exactly the false negative the extraction repaired.
            #
            # AND ASKING IT FIRST REACHES EVERY POSITION, NOT ONLY THAT ARM, which is worth stating
            # because it is the part a reader would assume is untouched. '[void]' behind an explicit
            # 'return', or in front of an assignment to a variable that is read later, is a discard too
            # -- the cast is what throws the value away, so the shape it wears afterwards cannot give it
            # back. Both are pinned by scenario 78b rather than left to be inferred from this comment.
            $fsRead = $false
        } elseif ($fsUp -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $fsUp.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $fsVar = $fsUp.Left.VariablePath.UserPath
            # The variable has to be READ somewhere that is not this assignment's own left-hand side.
            # The root is reached by climbing from the node rather than by parsing the file again --
            # Get-PsScriptCommandAsts holds only CommandAsts, and a second ParseFile here would undo
            # the shared-parse property checks 31, 33, 35 and this one are built on (issue #1358).
            #
            # TWO NARROWINGS, BOTH OF THEM REPAIRS OF A FALSE NEGATIVE, caught by probing this check
            # rather than by reading it. A bare name match over the whole file cleared an assignment
            # whose value nothing consults:
            #   * AFTER, not anywhere. A reference sitting BEFORE the assignment is a different
            #     variable's life, and it cleared a dead assignment that followed it.
            #   * IN THE SAME FUNCTION, not anywhere. '$loadBroken' as a local inside an unrelated
            #     function cleared a dead file-scope assignment of the same name.
            $fsOwner = Get-EnclosingFunction -Node $fsUp
            $fsFrom  = $fsUp.Extent.StartOffset
            $fsRoot  = $fsUp
            while ($fsRoot.Parent) { $fsRoot = $fsRoot.Parent }
            $fsRead = @($fsRoot.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.VariablePath.UserPath -eq $fsVar -and
                $n.Extent.StartOffset -gt $fsFrom
            }, $true) | Where-Object {
                (Get-EnclosingFunction -Node $_) -eq $fsOwner
            }).Count -gt 0
        } elseif ($fsUp -is [System.Management.Automation.Language.ReturnStatementAst]) {
            # 'return Write-FixtureScriptSummary ...' -- the verdict is the caller's to act on.
            $fsRead = $true
        } elseif ($fsUp -is [System.Management.Automation.Language.StatementBlockAst] -or
                  $fsUp -is [System.Management.Automation.Language.NamedBlockAst]) {
            # A BARE STATEMENT, which is a discard EXCEPT as a function's implicit return -- PowerShell's
            # last-statement-is-the-value rule, and a false positive until this arm existed: a helper
            # ending in this call hands the verdict back exactly as an explicit 'return' does. No suite
            # here spells it that way today; the arm is what keeps a refactor that does from being told
            # its wiring is missing.
            $fsOwnerBlock = $fsUp
            $fsIsLast = $false
            if ($fsOwnerBlock.Statements -and
                $fsOwnerBlock.Parent -is [System.Management.Automation.Language.ScriptBlockAst] -and
                $fsOwnerBlock.Parent.Parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                $fsStmts  = @($fsOwnerBlock.Statements)
                $fsIsLast = ($fsStmts.Count -gt 0 -and
                             $fsStmts[$fsStmts.Count - 1].Extent.StartOffset -eq $fsOuter.Extent.StartOffset)
            }
            $fsRead = $fsIsLast
        } else {
            # Consumed in place -- an if/while condition, or an argument to another command.
            $fsRead = $true
        }

        if ($fsRead) { continue }
        Add-Error ("[fixture-script] ${fsRel}:$($fsCall.Extent.StartLineNumber): the verdict of" +
            " Write-FixtureScriptSummary is never read, so nothing turns it into an exit code. The" +
            " block still PRINTS, which is what makes this the worse failure: the run says a child died" +
            " on load and then exits 0, wearing the guard's own output as proof that it is wired. Assign" +
            " it (`$loadBroken = Write-FixtureScriptSummary ...) and act on it, as the six suites #1934" +
            " wired do.")
        $fsFindings++
    }
}
Write-Coverage -Category 'fixture-script' -Checked $fsFiles.Count `
    -Note $(if ($fsFiles.Count -eq 0) {
        'no .ps1 found under scripts/tests/ -- a half-removed fixture load guard could not have been seen'
    } elseif ($fsWired -eq 0) {
        'script file(s) under scripts/tests/ read, and NOT ONE carries any part of the #1934 fixture load guard. That is a pass with nothing measured in it: the rule is self-anchoring, so a tree where the guard has been removed everywhere is indistinguishable here from one where it was never added. Read it as a broken gate rather than a clean one'
    } else {
        "script file(s) under scripts/tests/ walked for the three parts of the #1934 fixture load guard -- the dot-source of fixture-script-lib.ps1, an Assert-FixtureScriptLoaded call, and a Write-FixtureScriptSummary call whose verdict is READ rather than printed and dropped -- over the $fsWired file(s) carrying at least one of them: $fsFindings finding(s). SELF-ANCHORING, so no list of wired suites is maintained anywhere: a file's own content says whether it has adopted the helper, which is the hand-listed-copy-list failure #1693, #1865 and #1924 each ended up removing. Born green: 7 wired, all complete, 0 exemptions. #1948's own proposed rule -- any captured child invocation without a verdict -- was measured first and NOT built: 71 findings over 82 invocations, which is a proposal to wire 65 more suites (#1954) rather than a regression guard, and its same-statement adjacency reports all six WIRED suites as findings because they judge two to four statements after the call. A suite carrying none of the three parts is deliberately not a subject"
    })

# --- Report ---------------------------------------------------------------------------------------------
if ($errors.Count -eq 0) {
    Write-Host "  No findings." -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary: 0 error(s)." -ForegroundColor Cyan
    exit 0
}
foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
Write-Host ""
Write-Host "Summary: $($errors.Count) error(s)." -ForegroundColor Cyan
exit 1
