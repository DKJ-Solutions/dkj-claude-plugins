import type { ComponentId } from '../components/sources'

/**
 * The apps overview: every DKJ-Solutions app whose design the brand book follows, and the views it is made of.
 * Adding the next app is one new entry in APPS below (plus its views); the Apps section and the "Used in" footer
 * under every component are derived from this file. `components` is typed against ComponentId, so a typo fails tsc.
 */
export type ViewKind = 'screen' | 'card' | 'dialog' | 'tooltip' | 'drawer' | 'menu'

export type View = {
  id: string
  name: string
  kind: ViewKind
  description: string
  components: readonly ComponentId[]
}

export type App = {
  id: string
  name: string
  /** GitHub "owner/name". */
  repo: string
  description: string
  /** Live URL, where the app is deployed. */
  url?: string
  stack: string
  views: readonly View[]
}

/** Display order and labels of the view kinds. */
export const VIEW_KINDS: readonly { kind: ViewKind; label: string }[] = [
  { kind: 'screen', label: 'Screens' },
  { kind: 'card', label: 'Cards' },
  { kind: 'dialog', label: 'Dialogs' },
  { kind: 'tooltip', label: 'Tooltips' },
  { kind: 'drawer', label: 'Drawers' },
  { kind: 'menu', label: 'Menus and bars' },
]

// Mesowise: researched read-only from the app's repo; live URL verified 2026-10-13.
const MESOWISE_VIEWS: readonly View[] = [
  { id: 'top-bar', name: 'Top bar', kind: 'menu', description: 'Full-width header with the app name, a tagline and a hamburger button that opens the settings drawer.', components: ['TopBar', 'IconButton'] },
  { id: 'settings-drawer', name: 'Settings drawer', kind: 'drawer', description: 'Panel sliding in from the right with a list of settings rows, a collapsible Help note and an offline-download button; each row opens a second drawer with segmented choices and a Save button.', components: ['Drawer', 'MenuRow', 'SegmentedChoice', 'Button', 'Disclosure', 'Message'] },
  { id: 'level-row', name: 'Level stepper', kind: 'card', description: 'A row with Back, the current level as the page heading and Level up, with a hint under it when levelling is blocked.', components: ['StepHeader', 'Button', 'Message'] },
  { id: 'app-question', name: 'Headline question', kind: 'card', description: 'A single highlighted question line that names the current level and job.', components: ['Banner'] },
  { id: 'level-cost-summary', name: 'Level cost summary', kind: 'card', description: 'Tinted buttons showing the cost of the next level for the cheapest setup versus the current setup, with the difference below; each opens the matching popup.', components: ['TintedPanel', 'Amount', 'Icon'] },
  { id: 'job-card', name: 'Job and gender card', kind: 'card', description: 'First-run card with segmented choices for job and gender, shown only until both are chosen, with an edit icon afterwards.', components: ['Card', 'SegmentedChoice', 'IconButton', 'Help'] },
  { id: 'equipment-card', name: 'Equipment card', kind: 'card', description: 'Card with a title and Cheapest/Profile view buttons; the popups hold equipment slots with a search picker, value boxes with steppers and a switch.', components: ['Card', 'IconButton', 'Icon', 'SearchCombobox', 'ValueBox', 'Stepper', 'Button', 'Checkbox', 'StatRow', 'Message'] },
  { id: 'skills-card', name: 'Skill points card', kind: 'card', description: 'Card with view buttons; the popup lists grouped skill rows with a points-pool counter, and its report asks a question and offers a Place-point button.', components: ['Card', 'GroupHeading', 'StatRow', 'QuestionBlock', 'Chip', 'Button', 'Message'] },
  { id: 'monster-card', name: 'Monster card', kind: 'card', description: 'Card where you pick the monster you hunt and edit its info, with a draft that Save commits and a report.', components: ['Card', 'Field', 'Button', 'QuestionBlock', 'Chip', 'Message'] },
  { id: 'potions-card', name: 'Potions card', kind: 'card', description: 'Card with groups of selectable potion fields you can correct, plus a report with a recommendation.', components: ['Card', 'GroupHeading', 'Field', 'QuestionBlock', 'Chip'] },
  { id: 'ability-points-card', name: 'Ability points card', kind: 'card', description: 'Card whose popup shows the character profile with plus/total ability rows, steppers, an auto-assign button and a Based-on summary.', components: ['Card', 'FormulaRow', 'Stepper', 'StatRow', 'Button', 'InfoRow', 'DefinitionList'] },
  { id: 'total-stats-card', name: 'Total stats card', kind: 'card', description: 'Card whose popup shows derived stat rows with value boxes and an expandable per-stat breakdown.', components: ['Card', 'StatRow', 'ValueBox', 'DefinitionList', 'RoundToggle', 'Help'] },
  { id: 'total-cost-card', name: 'Total cost card', kind: 'card', description: 'Card with the level cost as itemised bill tables for the current and cheapest setups, a difference table, an Apply/Undo change list and a note on what changes.', components: ['Card', 'TintedPanel', 'BillTable', 'ComparisonTable', 'Amount', 'Button', 'Message', 'RoundToggle', 'AnswerBox', 'CalcTable'] },
  { id: 'card-dialog', name: 'Card popup', kind: 'dialog', description: 'Modal opened from a card with a title, optional tag, close button, a Based-on summary, the card body and an optional Save.', components: ['Dialog', 'TitleTag', 'Help', 'InfoRow', 'IconButton', 'Button', 'Message'] },
  { id: 'report-dialog', name: 'Report dialog', kind: 'dialog', description: 'Modal opened from a clipboard icon inside a card popup, holding the advice question with a coloured verdict chip and step-by-step calculations.', components: ['Dialog', 'IconButton', 'QuestionBlock', 'Chip', 'AnswerBox', 'CalcTable', 'Message'] },
  { id: 'why-dialog', name: 'Bill line explanation', kind: 'dialog', description: 'Small modal opened from the question-mark toggle on a bill row, showing a worked multiplication/answer breakdown.', components: ['Dialog', 'RoundToggle', 'AnswerBox', 'CalcTable'] },
]

// ETF tracker: researched read-only from etf_tracker/dashboard.py. All three charts are mirrored (ColumnChart, BarChart, LineChart, #20).
const ETF_VIEWS: readonly View[] = [
  { id: 'dashboard', name: 'Dashboard', kind: 'screen', description: 'One page: a header, then a column of cards (some in a two-up grid on a wide screen), a footer note, and a tooltip layer behind every explanation mark. A switch in the header toggles between a primary and a secondary set of cards.', components: ['PageHeader', 'Card', 'FooterNote', 'Tooltip'] },
  { id: 'page-header', name: 'Page header', kind: 'menu', description: 'The page title in a serif h1, a muted as-of date, and a joined two-option switch that changes which set of cards shows.', components: ['PageHeader', 'SegmentedChoice'] },
  { id: 'ledger-warning', name: 'Ledger warning', kind: 'card', description: 'A warm notice above the cards when the data does not add up: a bold lead line with a warning mark, then a list of the discrepancies.', components: ['Banner'] },
  { id: 'summary', name: 'Summary', kind: 'card', description: 'The key figures as a grid of tiles, then the total value as one large figure beside the result as a coloured up or down change; every label has an explanation mark.', components: ['Card', 'StatTile', 'HeroValue', 'Delta', 'RoundToggle'] },
  { id: 'monthly-result', name: 'Monthly result', kind: 'card', description: 'A column chart of the result per month around a zero line, with quarter guides, a gain/loss legend and an explanation mark beside the title.', components: ['Card', 'Legend', 'ColumnChart', 'Tooltip', 'RoundToggle'] },
  { id: 'positions', name: 'Positions', kind: 'card', description: 'A sortable table of everything held, one row per holding with its code as a muted line under the name, signed figures in colour and a bold total row; it scrolls sideways on a phone.', components: ['Card', 'DataTable', 'Tooltip', 'RoundToggle'] },
  { id: 'insights', name: 'Insights', kind: 'card', description: 'Observations grouped by kind, each group with a status badge and a count in its heading and its items in a responsive grid.', components: ['Card', 'Badge', 'RoundToggle'] },
  { id: 'danger-zone', name: 'Danger zone', kind: 'card', description: 'A framed, high-visibility zone for the one part of the page that gives concrete advice: a warning title, an acknowledgement, an action tag per advice, a read-more per advice and a collapsible list of sources. Here it is the generic danger alert; the hazard stripes and the advice layout stay in the app.', components: ['Alert', 'TitleTag', 'ReadMoreToggle', 'Disclosure', 'RoundToggle'] },
  { id: 'allocation', name: 'Allocation', kind: 'card', description: 'A horizontal bar chart of value per holding with a legend of holding types (series colours), each with an explanation mark.', components: ['Card', 'Legend', 'BarChart', 'Tooltip', 'RoundToggle'] },
  { id: 'unrealised', name: 'Unrealised result', kind: 'card', description: 'A horizontal bar chart of gain and loss per holding with a gain/loss legend.', components: ['Card', 'Legend', 'BarChart', 'Tooltip', 'RoundToggle'] },
  { id: 'breakdown', name: 'Result breakdown', kind: 'card', description: 'Where the result comes from: a list of sources with a signed, coloured figure each and an explanation mark after the label, and a bold total.', components: ['Card', 'DefinitionList', 'Tooltip', 'RoundToggle'] },
  { id: 'closed-positions', name: 'Closed positions', kind: 'card', description: 'A table of what was fully sold, with the realised result in colour; an empty state is one muted row.', components: ['Card', 'DataTable', 'RoundToggle'] },
  { id: 'timeline', name: 'Value over time', kind: 'card', description: 'A line chart of value, deposits and result at each month end with a legend of three line series.', components: ['Card', 'Legend', 'LineChart', 'Tooltip', 'RoundToggle'] },
  { id: 'quarters', name: 'Quarterly deposits', kind: 'card', description: 'A grid of small cards, one per quarter: the amount, a progress bar towards the target, a status badge with its label and a muted note; the quarter still open has a warning border.', components: ['Card', 'MiniCard', 'Meter', 'Badge', 'RoundToggle'] },
  { id: 'market-report', name: 'Market report', kind: 'card', description: 'A long written report in a grid of tiles that is cut off with a fade until a full-width read-more button opens it, with a collapsible list of sources and an outdated note.', components: ['Card', 'ReadMoreToggle', 'Disclosure', 'RoundToggle'] },
  { id: 'footer-note', name: 'Footer note', kind: 'card', description: 'A small muted note at the foot of the page saying what the explanations and the figures are and are not.', components: ['FooterNote'] },
  { id: 'explain-tooltip', name: 'Explanation tooltip', kind: 'tooltip', description: 'A bold title and a few short paragraphs in a floating panel, opened by hover or keyboard focus on an explanation mark (or a sortable column header), pinned by a click, closed by Escape or a click elsewhere.', components: ['Tooltip', 'RoundToggle'] },
]

// DKJ Claude plugins: researched read-only from the repo's issue-dashboard worker and release-notes page generator. Two generated pages, no app.
const PLUGINS_VIEWS: readonly View[] = [
  { id: 'issue-dashboard', name: 'Issue dashboard', kind: 'screen', description: 'A generated page served by a worker: a heading with the repo, a muted generated-at and count line, count chips for sweepable and skipped issues, an optional "read with care" warning with a list, then one row per open issue (number, title, labels, a muted detail line); skipped rows say why, and an empty list says "No open issues".', components: ['PageHeader', 'Message', 'Badge', 'Banner', 'Card', 'DataTable', 'FooterNote'] },
  { id: 'release-notes', name: 'Release notes', kind: 'screen', description: 'A generated page: a masthead with the product name, a heading and a muted subtitle, then a bordered panel with one closed disclosure per release (version, optional chip, date) whose body is the rendered release note, and a snapshot note at the foot.', components: ['PageHeader', 'TitleTag', 'Message', 'Card', 'Disclosure', 'GroupHeading', 'FooterNote', 'Prose'] },
]

// DKJ Music library: researched read-only from the app's repo; a local app, no deployment. Three screens.
const MUSIC_LIBRARY_VIEWS: readonly View[] = [
  { id: 'playlist-manager', name: 'Playlist manager', kind: 'screen', description: 'A masthead, a connection section with status, connect and sync buttons, tiles per world with a total, a stats row, a filter toolbar (search, multi-select filter chips for colour with a dot, density and BPM tier, type and genre selects, an "ID filled" switch, clear filters) and a sortable playlist table with a done checkbox per row.', components: ['PageHeader', 'SegmentedChoice', 'FilterChips', 'TitleTag', 'Message', 'Card', 'Button', 'StatTile', 'Field', 'Checkbox', 'DataTable'] },
  { id: 'data-dashboard', name: 'Data dashboard', kind: 'screen', description: 'A table of duplicate tracks with a count, ranked top-artist bars ("N tracks"), and distributions: tiles per world, a colour bar list with a legend, and tiles per BPM tier.', components: ['Card', 'GroupHeading', 'DataTable', 'BarChart', 'Legend', 'StatTile'] },
  { id: 'track-register', name: 'Track register', kind: 'screen', description: 'A stats row, a filter fieldset (search, BPM, genre, album and group selects, clear), a sortable track table with an empty row, and a player strip under the table.', components: ['StatTile', 'Card', 'Field', 'Button', 'DataTable', 'TintedPanel', 'Message', 'FooterNote'] },
]

// DKJ Recipes: researched read-only from the app's repo. Two screens.
const RECIPES_VIEWS: readonly View[] = [
  { id: 'recipe-list', name: 'Recipe list', kind: 'screen', description: 'A header with the title and a shopping-list link with a count, a search field, a wrapping row of multi-select tag chips (all must match), then one tappable card per recipe with a bold title and a muted line of time, ingredient count and tags; no match says "No recipe found.".', components: ['PageHeader', 'Button', 'Field', 'FilterChips', 'Card', 'TitleTag', 'Message', 'FooterNote'] },
  { id: 'recipe-page', name: 'Recipe page', kind: 'screen', description: 'A back link, the recipe title and a muted meta line, an add-to-shopping-list toggle, a portions stepper that scales the amounts, "Ingredients" with a reset action, a checkbox per ingredient under department headings that strikes through when checked, and a numbered "Method" with a muted source line.', components: ['PageHeader', 'Button', 'Message', 'Card', 'Stepper', 'GroupHeading', 'Checkbox', 'FooterNote', 'Prose'] },
]

// DKJ Thumbnail generator: researched read-only from the repo. No interface; two generated outputs.
const THUMBNAIL_VIEWS: readonly View[] = [
  { id: 'yardstick-report', name: 'Yardstick report', kind: 'screen', description: 'A generated report: a heading with a muted generated-on date and a "generated report" note, a short introduction, a series summary as key-figure tiles, numbered sections, each a table with one row per round and verdicts as text, then a collapsible note per round. A dash means not measured.', components: ['PageHeader', 'Message', 'GroupHeading', 'StatTile', 'Card', 'DataTable', 'Disclosure', 'FooterNote', 'Prose'] },
  { id: 'contact-sheet', name: 'Contact sheet', kind: 'screen', description: 'A generated image: four candidate tiles side by side on a dark panel, each an image with its verdict, then a "discard" row and a "retain" row below.', components: ['PageHeader', 'Message', 'TintedPanel', 'Figure', 'Chip', 'Card', 'DefinitionList', 'FooterNote'] },
]

// Life hub: researched read-only from the app code (a private repo); a local app, no deployment. Content here is invented.
const LIFE_HUB_VIEWS: readonly View[] = [
  { id: 'hub', name: 'Hub', kind: 'screen', description: 'A masthead with three key figures (apps, dossiers, open actions); a "Coming up" list of dated rows (DateRow), each with a distance label, a title and a muted date, near ones highlighted and an invalid one with its reason; a grid of link cards to the available apps; then "My dossiers" grouped by category with a count, each dossier a card with a subpath, title, phase as text, a muted status date, a summary and an "N open of M" progress bar; and a footer note.', components: ['PageHeader', 'StatTile', 'GroupHeading', 'DateRow', 'Card', 'TitleTag', 'Message', 'Badge', 'Meter', 'Button', 'FooterNote'] },
  { id: 'dossier-detail', name: 'Dossier detail', kind: 'screen', description: 'Opening a dossier card replaces the hub: a back button naming the parent, a "Dossier" label with the slug, a two-option toggle when the dossier has a second document, a "Save as PDF" button, the document as a rendered article (headings, paragraphs, a list with checkboxes) and, when it has children, a "Subfolders" grid of the same cards.', components: ['PageHeader', 'Button', 'Message', 'SegmentedChoice', 'Card', 'GroupHeading', 'Checkbox', 'Badge', 'Meter', 'Prose'] },
]

export const APPS: readonly App[] = [
  {
    id: 'mesowise',
    name: 'Mesowise',
    repo: 'DKJ-Solutions/dkj-maplestory-classic-mesowise',
    description:
      'A mobile-first web app that works out the cheapest way to level up a game character, and shows the cost of each level as an itemised bill you can compare against your current setup.',
    url: 'https://dkj-solutions.github.io/dkj-maplestory-classic-mesowise/',
    stack: 'Preact 11 + TypeScript + Vite 8; installable PWA; GitHub Pages',
    views: MESOWISE_VIEWS,
  },
  {
    id: 'etf-tracker',
    name: 'ETF tracker',
    repo: 'DKJ-Solutions/dkj-etf-tracker',
    description:
      'A personal investment dashboard: one generated page with the portfolio value, the result against deposits, the holdings, charts over time, quarterly deposit goals and a written market report, every figure with a short explanation.',
    stack: 'Python-generated static HTML dashboard (inline CSS + JS)',
    views: ETF_VIEWS,
  },
  {
    id: 'claude-plugins',
    name: 'DKJ Claude plugins',
    repo: 'DKJ-Solutions/dkj-claude-plugins',
    description:
      'The shared Claude Code plugins behind the DKJ-Solutions way of working: policy, skills and specialists. Its only screens are two generated pages, a release-notes page and an issue dashboard, each served by a Cloudflare Worker.',
    stack: 'PowerShell scripts + Cloudflare Workers (vanilla JS, inline CSS); no framework',
    views: PLUGINS_VIEWS,
  },
  {
    id: 'music-library',
    name: 'DKJ Music library',
    repo: 'DKJ-Solutions/dkj-music-library',
    description:
      'A local app for managing a music library: sync playlists from a music service, sort them into worlds, filter and annotate them, and look at the library through a data dashboard and a track register.',
    stack: 'Next.js (React) + TypeScript; runs locally, no deployment',
    views: MUSIC_LIBRARY_VIEWS,
  },
  {
    id: 'recipes',
    name: 'DKJ Recipes',
    repo: 'DKJ-Solutions/dkj-recipes',
    description:
      'A recipe collection you can search and filter by tag, with a recipe page that scales the amounts to the number of portions, lets you tick ingredients off by department and collects recipes on a shopping list.',
    url: 'https://dkj-solutions.github.io/dkj-recipes/',
    stack: 'Astro static site; installable PWA; GitHub Pages',
    views: RECIPES_VIEWS,
  },
  {
    id: 'thumbnail-generator',
    name: 'DKJ Thumbnail generator',
    repo: 'DKJ-Solutions/dkj-thumbnail-generator',
    description:
      'Scripts that run a thumbnail round at an image-generation service, measure the result against a yardstick and place it in a design file. It has no interface; its two outputs are a generated measurement report and a contact sheet of the candidates.',
    stack: 'Node scripts; local only, no deployment',
    views: THUMBNAIL_VIEWS,
  },
  {
    id: 'life-hub',
    name: 'Life hub',
    repo: 'DKJ-Solutions/dkj-lifehub',
    description:
      'A start page: key figures, what is coming up, links to the other local apps and a set of dossiers, each opening as a rendered document with subfolders.',
    stack: 'Next.js (React) + TypeScript; runs locally, no deployment',
    views: LIFE_HUB_VIEWS,
  },
]

/** One place a component is used: an app and one of its views. */
export type Usage = { app: App; view: View }

/** The reverse index: for a component, every app view that uses it. */
export function usagesOf(id: ComponentId): Usage[] {
  return APPS.flatMap((app) => app.views.filter((v) => v.components.includes(id)).map((view) => ({ app, view })))
}
