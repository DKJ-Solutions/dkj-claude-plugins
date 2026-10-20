import { useState } from 'react'
import { Button, RoundToggle, SegmentedChoice } from '../../components/Button'
import { Dialog, DialogActions, DialogLabel } from '../../components/Dialog'
import { Disclosure, Message, Tooltip } from '../../components/Feedback'
import { Stepper } from '../../components/Field'
import { Breadcrumbs, DrawerFooter, InfoRow, InfoRows, MenuList, MenuRow, PageHeader, PageLinks, StepHeader, TopBar } from '../../components/Navigation'
import { RowList, StatRow, ValueBox } from '../../components/Row'
import { Demo, Section } from '../Showcase'
import { HouseDialogsDemo, HouseMenuDemo, HouseSettingsDemo, HouseTopBarDemo } from './HouseApp'

const LOREM = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'

type Which = null | 'plain' | 'edit' | 'accent' | 'info' | 'long'

export function Overlays() {
  const [open, setOpen] = useState<Which>(null)
  const [value, setValue] = useState(12)
  const [draft, setDraft] = useState(12)
  const [step, setStep] = useState(7)
  const [view, setView] = useState<'primary' | 'secondary'>('primary')
  const close = () => setOpen(null)
  return (
    <>
      <Section
        id="Dialog"
        title="Dialog"
        intro="The browser's own modal dialog: focus stays inside, Escape and a tap on the backdrop close it, the page behind stops scrolling. A dialog opened from a dialog is 93% of the one below. With a change to save, the close cross becomes a check, and a red undo arrow cancels."
      >
        <Demo label="Open a variant">
          <div className="dkj-demo-row">
            <Button onClick={() => setOpen('plain')}>Plain</Button>
            <Button
              onClick={() => {
                setDraft(value)
                setOpen('edit')
              }}
            >
              Edit (save / cancel)
            </Button>
            <Button onClick={() => setOpen('accent')}>Accent-tinted</Button>
            <Button onClick={() => setOpen('info')}>Info-tinted</Button>
            <Button onClick={() => setOpen('long')}>Long content</Button>
          </div>
          <Message>Saved value: {value}</Message>
        </Demo>

        <Dialog open={open === 'plain'} onClose={close} title="Dialog title" subtitle="A muted subtitle" info={LOREM}>
          <RowList>
            <StatRow name="Label one">
              <ValueBox value="1,234" />
            </StatRow>
            <StatRow name="Label two">
              <ValueBox value="56" />
            </StatRow>
          </RowList>
          <Message tone="note">Tap the “i” after the title: it opens a stacked dialog.</Message>
        </Dialog>

        <Dialog open={open === 'edit'} onClose={close} title="Label one" heading="plain" onSave={draft !== value ? () => setValue(draft) : undefined}>
          <DialogLabel>Value</DialogLabel>
          <Stepper label="Value" size="lg" value={draft} onChange={setDraft} />
          <Message tone="note">Change the value: the cross turns into a check (save) next to a red undo (cancel).</Message>
        </Dialog>

        <Dialog open={open === 'accent'} onClose={close} tone="accent" title="Dialog title" tag="Expected" subtitle="Step 12 · Variant A">
          <InfoRows head="Based on:">
            <InfoRow value="Profile alpha" onInfo={() => undefined} />
            <InfoRow value="Target bravo" onInfo={() => undefined} onHelp={() => undefined} />
          </InfoRows>
          <Message>{LOREM}</Message>
        </Dialog>

        <Dialog open={open === 'info'} onClose={close} tone="info" title="Dialog title" tag="Edit profile">
          <InfoRows head="Based on:" tone="info">
            <InfoRow value="Profile alpha" onInfo={() => undefined} onEdit={() => undefined} />
            <InfoRow value={null} onEdit={() => undefined} />
          </InfoRows>
          <DialogActions>
            <Button variant="primary" block>Primary action</Button>
          </DialogActions>
        </Dialog>

        <Dialog open={open === 'long'} onClose={close} title="Long content">
          {Array.from({ length: 14 }, (_, i) => (
            <p key={i} className="dkj-msg" style={{ marginBottom: 'var(--spacing-3)' }}>
              {LOREM}
            </p>
          ))}
        </Dialog>

        <Demo label="House .dialog / .dialog--drawer (native dialog, showModal)">
          <HouseDialogsDemo />
        </Demo>
      </Section>

      <Section
        id="Tooltip"
        title="Tooltip"
        intro="A non-modal explanation. Hover or focus the mark: it opens under it; click or tap pins it (no hover on a phone); Escape, a click elsewhere or a scroll closes it. The text is linked to the mark with aria-describedby and sits in the page while hidden. It is the house .tooltip (fixed, with a shadow)."
      >
        <Demo label="Live -- on an inline mark in a label">
          <span>
            Total value
            <Tooltip
              explain
              trigger={(a11y) => <RoundToggle size="inline" label="Explain: Total value" {...a11y} />}
              title="Total value"
              paragraphs={[
                'What everything together is worth now: the holdings plus the money that is not invested.',
                'It moves with the prices every trading day.',
              ]}
            />
          </span>
        </Demo>
        <Demo label="Live -- short, on a text button">
          <div className="dkj-demo-row">
            <Tooltip trigger={(a11y) => <Button size="compact" {...a11y}>Hover or focus me</Button>} title="A short title" paragraphs={['One line of detail.']} />
          </div>
        </Demo>
        <Demo label="How it looks open (static)">
          <div className="tooltip tooltip--explain dkj-tooltip-static">
            <b>Total value</b>
            <p>What everything together is worth now: the holdings plus the money that is not invested.</p>
            <p>It moves with the prices every trading day.</p>
          </div>
        </Demo>
      </Section>

      <Section id="Drawer" title="Drawer" intro="The menu: a full-height panel sliding in from the right; a swipe to the right closes it. Its head is as tall as the top bar. Open it with the menu button in the TopBar demo below.">
        <Demo label="See TopBar">
          <Message>The drawer is opened from the top bar.</Message>
        </Demo>
      </Section>

      <Section id="TopBar" title="TopBar" intro="Sticky, in the surface colour, aligned with the app column. The menu opens a Drawer with menu rows, a list choice, a disclosure and a download button pinned to the bottom.">
        <Demo label="TopBar + drawer" wide surface={false}>
          <div style={{ border: '1px solid var(--paper-3)', borderRadius: 'var(--dkj-radius-lg)', overflow: 'hidden', background: 'var(--paper-1)' }}>
            <TopBar name="Appname" tagline="A short tagline that says what the app does." menu={<DrawerMenu />} />
            <div style={{ height: '6rem' }} />
          </div>
        </Demo>
        <Demo label="House .topbar with a .icon-btn--ghost" wide surface={false}>
          <HouseTopBarDemo />
        </Demo>
        <Demo label="House .topbar with the settings button (DKJTheme.settings, Dutch defaults)" wide surface={false}>
          <HouseSettingsDemo />
        </Demo>
      </Section>

      <Section id="PageHeader" title="PageHeader" intro="The page title as the house serif h1, and on its right a controls row: a muted as-of line and the page's controls. The row wraps under the title on a narrow screen.">
        <Demo label="Title, as-of and a joined switch" wide>
          <PageHeader title="Page title" asOf="As of 1 January 2026">
            <SegmentedChoice
              label="View"
              layout="joined"
              value={view}
              onChange={setView}
              options={[
                { value: 'primary', label: 'Primary' },
                { value: 'secondary', label: 'Secondary' },
              ]}
            />
          </PageHeader>
        </Demo>
      </Section>

      <Section id="Breadcrumbs" title="Breadcrumbs" intro="Where the page sits: each ancestor a link (underlined under the pointer), a chevron between them, and the current page last and unlinked, the whole trail in the muted greys at the regular weight. The trail stays on one line and scrolls sideways when it is longer than the screen; as a bar it sticks to the top of the page.">
        <Demo label="Three levels">
          <Breadcrumbs items={[{ label: 'Home', href: '#Breadcrumbs' }, { label: 'Section', href: '#Breadcrumbs' }, { label: 'Current page' }]} />
        </Demo>
        <Demo label="As a bar (on a page it spans the full screen width, above main)" wide>
          <Breadcrumbs bar items={[{ label: 'Home', href: '#Breadcrumbs' }, { label: 'Section', href: '#Breadcrumbs' }, { label: 'Current page' }]} />
        </Demo>
      </Section>

      <Section id="PageLinks" title="PageLinks" intro="The Repo hub's Pages block: a data card titled Pages around a list of link rows, each with a label, an optional one-line description and a chevron. It is the house .menu-item as a link, so a row tints on hover; it renders nothing for an empty list. With generalPages too (Issues, Release notes: the pages every DKJ-Solutions repo serves) the h2 stands above two cards side by side, This repo and General.">
        <Demo label="Two pages, one with a description">
          <PageLinks
            pages={[
              { label: 'Release history', href: '#PageLinks', description: 'Every release, newest first' },
              { label: 'Roadmap', href: '#PageLinks' },
            ]}
          />
        </Demo>
        <Demo label="Two groups: This repo and General">
          <PageLinks
            pages={[
              { label: 'Release history', href: '#PageLinks', description: 'Every release, newest first' },
              { label: 'Roadmap', href: '#PageLinks' },
            ]}
            generalPages={[
              { label: 'Issues', href: '#PageLinks', description: 'Open and closed, on GitHub' },
              { label: 'Release notes', href: '#PageLinks', description: 'What each release changed' },
            ]}
          />
        </Demo>
      </Section>

      <Section id="MenuRow" title="MenuRow" intro="A label, the chosen value right-aligned, and a pencil centred under the drawer's close button.">
        <Demo label="Menu list">
          <MenuList>
            <MenuRow label="Label" value="Value A" />
            <MenuRow label="Another label" value="A longer value that wraps when needed" />
          </MenuList>
        </Demo>
        <Demo label="House .menu-list / .menu-row / .menu-item">
          <HouseMenuDemo />
        </Demo>
      </Section>

      <Section id="StepHeader" title="StepHeader" intro="Back, a large value exactly centred between two equal side columns, and forward. Both buttons are identical in size.">
        <Demo label="Interactive (1 to 10)">
          <StepHeader value={step} onBack={() => setStep(step - 1)} onForward={() => setStep(step + 1)} canBack={step > 1} canForward={step < 10} />
        </Demo>
        <Demo label="At the start (back disabled)">
          <StepHeader value={1} canBack={false} />
        </Demo>
      </Section>

      <Section id="InfoRow" title="InfoRow" intro="A tinted box per row: the value behind an info button that fills the box, an optional “?”, and an optional pencil outside the box. Empty rows show a muted placeholder.">
        <Demo label="Accent">
          <InfoRows head="Based on:">
            <InfoRow value="Profile alpha" onInfo={() => undefined} />
            <InfoRow value="Target bravo" onInfo={() => undefined} onHelp={() => undefined} />
          </InfoRows>
        </Demo>
        <Demo label="Info, with pencils and an empty row">
          <InfoRows head="Based on:" tone="info">
            <InfoRow value="Profile alpha" onInfo={() => undefined} onEdit={() => undefined} />
            <InfoRow value={null} onEdit={() => undefined} />
          </InfoRows>
        </Demo>
      </Section>
    </>
  )
}

function DrawerMenu() {
  const [choice, setChoice] = useState<'a' | 'b' | 'c'>('a')
  return (
    <>
      <MenuList>
        <MenuRow label="Label" value="Value A" />
        <MenuRow label="Another" value="Value B" />
      </MenuList>
      <div style={{ marginTop: 'var(--spacing-4)' }}>
        <SegmentedChoice
          label="Choose"
          layout="list"
          value={choice}
          onChange={setChoice}
          options={[
            { value: 'a', label: 'Option A' },
            { value: 'b', label: 'Option B' },
            { value: 'c', label: 'Option C' },
          ]}
        />
      </div>
      <div style={{ marginTop: 'var(--spacing-5)' }}>
        <Disclosure summary="Help">
          <Message>{LOREM}</Message>
        </Disclosure>
      </div>
      <DrawerFooter>
        <Button href="#TopBar" download icon="download" block>Download offline version</Button>
        <Message>One file you open in your browser, without internet.</Message>
      </DrawerFooter>
    </>
  )
}
