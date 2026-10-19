/**
 * Where each brand-book component comes from: the source repo, the component(s) in that repo, and the CSS it was
 * lifted from. This register is how we later see which repo delivers which component; the showcase prints it under
 * every component. Only the UI/UX design was taken over -- no content, data or logic. An empty array means a brand-book original: no source repo.
 */
export type SourceRef = {
  repo: string
  /** Function components in the source file that render this pattern. */
  components: readonly string[]
  /** Class names in the source stylesheet. */
  selectors: readonly string[]
  file: string
  css: string
}

const MESOWISE = 'DKJ-Solutions/dkj-maplestory-classic-mesowise'
const m = (components: string[], selectors: string[]): SourceRef[] => [
  { repo: MESOWISE, file: 'src/app.tsx', css: 'src/style.css', components, selectors },
]

// The ETF tracker is one generated file: the dashboard's CSS and its markup both live in dashboard.py.
const ETF = 'DKJ-Solutions/dkj-etf-tracker'
const e = (components: string[], selectors: string[]): SourceRef[] => [
  { repo: ETF, file: 'etf_tracker/dashboard.py', css: 'etf_tracker/dashboard.py', components, selectors },
]

export const SOURCES = {
  Icon: m(['CardIcon', 'EyeIcon', 'PencilPath', 'INFO_ICON', 'QUESTION_ICON', 'PENCIL_ICON'], ['.card-icon']),
  Button: m(['App (level row)', 'CheapestDetails', 'SkillQuestion', 'ChoiceSave', 'StatEditor', 'TopBar (download)'], ['.btn', '.btn.primary', '.btn.levelup', '.btn.level-down', '.level-row .btn', '.btn.auto-assign.ready', '.equip-save', '.equip-save:disabled', '.menu-download .download-btn']),
  SegmentedChoice: [...m(['JobChoices', 'GenderChoices'], ['.job-choices', '.job-choice', '.menu-drawer .job-choice']), ...e(['view switch'], ['.seg', '.seg button', '.seg button[aria-pressed]', '.controls .seg'])],
  IconButton: m(['ViewButtons', 'StatLine', 'JobCard', 'TopBar'], ['.card-action', '.equip-edit', '.job-edit', '.topbar-menu']),
  RoundToggle: [...m(['HelpToggle', 'PopupButton', 'InvoiceTable'], ['.help-toggle', '.info-toggle', '.invoice-why']), ...e(['info() (the "?" button)', 'labelInfo'], ['.info', '.info::after', '.info[aria-expanded]'])],
  Card: [...m(['CardHead', 'ViewButtons', 'EquipmentCard', 'StatsCard'], ['.card', '.card:has([aria-expanded])', '.spot-head', '.spot-body', '.card-actions', '.*.invalid']), ...e(['section.card (h2 + .sub)'], ['.card', 'h2', '.sub', '.grid2'])],
  TintedPanel: m(['LevelCostButtons', 'TotalCostCard'], ['.total-cost-part', '.level-cost-btn', '.level-cost-label', '.level-cost-total']),
  Banner: [...m(['App (app question)'], ['.app-question']), ...e(['ledger warning'], ['.warn', '.warn ul'])],
  Message: m(['Warnings', 'NotComputed', 'NotComputedDebug'], ['.hint', '.note', '.warn', '.error', '.debug']),
  Chip: m(['Question'], ['.chip', '.chip.yes', '.chip.no', '.chip.todo', '.chip.unknown']),
  TitleTag: [...m(['StatDialog (tag)'], ['.title-tag', '.worn-dialog .title-tag']), ...e(['advice action pill'], ['.act'])],
  Help: m(['Help', 'HelpToggle'], ['.help', '.help-toggle']),
  Disclosure: [...m(['TopBar (menu help)'], ['.menu-help']), ...e(['more()', 'sources list'], ['.more', '.more summary', '.more summary::after', '.sources.more'])],
  GroupHeading: m(['SkillGroups', 'PotionsCard', 'PoolCount'], ['.skill-group h3', '.potion-group h3', '.skill-sp.over']),
  QuestionBlock: m(['Question', 'SkillQuestion', 'MobQuestion', 'PotionQuestion'], ['.question-head', '.chip', '.verdict']),
  Amount: m(['MesoAmount'], ['.meso-amount', '.meso-icon']),
  Field: m(['PotionsCard', 'HuntedMobCard'], ['.field', '.field input', '.field select', '.field-fixed']),
  Checkbox: m(['EquipmentCard (switch)'], ['.equip-head .switch']),
  Stepper: m(['StatEditor', 'ApInput'], ['.equip-step', '.stat-dialog .equip-step', '.equip-reset', '.ap-edit']),
  SearchCombobox: m(['EquipSearch'], ['.equip-picked', '.equip-search input', '.equip-list', '.equip-list li.active', '.equip-list li.own', '.equip-list li.more']),
  ValueBox: m(['StatLine'], ['.equip-value', '.equip-value.changed', '.equip-value-num', '.equip-value-head', '.equip-value strong.cost/.gain']),
  StatRow: m(['StatLine', 'SkillLine', 'StatRows'], ['.stat-line', '.skill-row', '.stat-line.with-help', '.skill-mp']),
  FormulaRow: m(['AbilityLine', 'AbilityHead'], ['.stat-line.ability-line', '.ability-head', '.ap-plus', '.ap-total', '.ap-base.flash']),
  Dialog: m(['StatDialog', 'CardPopup', 'PopupButton'], ['.stat-dialog', '.stat-dialog-head', '.stat-dialog-close', '.advised-dialog', '.worn-dialog', '.stat-dialog-actions']),
  Drawer: m(['TopBar', 'StatDialog (drawer)'], ['.stat-dialog.menu-drawer', '.menu-drawer .stat-dialog-head']),
  TopBar: m(['TopBar'], ['.topbar', '.topbar-inner', '.topbar-brand', '.topbar-menu']),
  MenuRow: m(['SettingsList'], ['.menu-list', '.menu-row', '.menu-label', '.menu-value']),
  StepHeader: m(['App (level row)'], ['.level-row', '.current-level', '.btn.level-down', '.btn.levelup']),
  InfoRow: m(['BasedOn'], ['.based-on', '.based-on-row', '.based-on-label', '.based-on-value']),
  DefinitionList: [...m(['BreakdownList', 'BillRow (facts)'], ['.breakdown-list', '.item-facts']), ...e(['breakdown table (label, signed value, total)'], ['#breakdown', 'tr.total', '.pos', '.neg', '.info'])],
  BillTable: m(['BillTable', 'BillHead', 'BillRow', 'BillSum', 'BillTotal', 'LevelBill'], ['.advised-bill', '.advised-head', '.advised-row', '.advised-subtotal', '.advised-total']),
  ComparisonTable: m(['DifferenceTable'], ['.invoice', '.invoice-difference']),
  CalcTable: m(['MulCalc', 'WhyTable'], ['.why-mul', '.why-mul-box', '.why-mul-result', '.why-table']),
  AnswerBox: m(['PotionSteps', 'AmmoSteps', 'ShopSteps'], ['.why-answer', '.why-section', '.why-group']),
  // ETF tracker only
  DataTable: e(['renderHoldings', 'sortedHoldings', 'closed positions table'], ['table', 'th', 'th .sort', 'th .arrow', 'th[aria-sort]', 'tr.total', '.tablewrap', '.muted']),
  Alert: e(['DANGER zone (generalised: no hazard stripes, no advice layout)'], ['.danger', '.danger-body', '.warnbox']),
  StatTile: e(['tiles'], ['.tiles', '.tile', '.tile .label', '.tile .v', '.summary .tiles']),
  HeroValue: e(['summary hero'], ['.hero', '.hero .value', '.summary .hero']),
  Delta: e(['result line'], ['.delta', '.delta.up', '.delta.down', '.pos', '.neg']),
  Tooltip: e(['showTip', 'hideTip', 'openInfo', 'closeInfo', 'explainHtml'], ['.tip', '.tip b', '.tip.explain', '.tip.explain p']),
  ColumnChart: e(['columnChart', 'ticks', 'wire', 'showTip'], ['.chart svg', '.chart .bar', '.chart svg text', '.q', '.tip']),
  BarChart: e(['hbar', 'wire', 'showTip'], ['.chart svg', '.chart .bar', '.chart svg text', '.chart svg .val', '.tip']),
  LineChart: e(['lineChart', 'niceStep', 'wire', 'showTip'], ['.chart svg', '.chart svg text', '.chart svg .val', '.q', '#xhair', '#xdot', '#xhit', '.tip']),
  Legend: e(['chart legends'], ['.legend', '.legend span::before', '.legend span.line::before', '.series']),
  MiniCard: e(['quarter cards'], ['.quarters', '.qcard', '.qcard.open', '.qcard .ql', '.qcard .qa', '.qnote']),
  Meter: e(['quarter cards (progress)'], ['.meter', '.meter span', '.st-gehaald', '.st-gemist', '.st-open', '.st-gedekt']),
  Badge: e(['quarter status', 'insight groups'], ['.badge', '.qs', '.qs .badge', '.lvl-goed', '.lvl-let-op', '.lvl-info', '.lvl-vraag']),
  ReadMoreToggle: e(['market report tiles', 'advice pairmore'], ['.moretoggle', '.moretoggle::after', '.moretoggle[aria-expanded]', '.pairmore']),
  PageHeader: e(['header (title, as-of, controls)'], ['header', 'h1', '.controls', '.muted']),
  FooterNote: e(['page footer'], ['.foot']),
  // Brand-book original, no source repo.
  Prose: [],
  FilterChips: [],
  Figure: [],
  Breadcrumbs: [],
  PageLinks: [],
  DateRow: [],
} as const satisfies Record<string, SourceRef[]>

export type ComponentId = keyof typeof SOURCES
