import { useState } from 'react'
import { Button, CardActions, FilterChips, IconButton, RoundToggle, SegmentedChoice } from '../../components/Button'
import { Stepper } from '../../components/Field'
import { Demo, Section } from '../Showcase'
import { HouseButtonsDemo, HouseFocusDemo } from './HouseApp'

const OPTIONS = [
  { value: 'a', label: 'Option A' },
  { value: 'b', label: 'Option B' },
  { value: 'c', label: 'Option C' },
  { value: 'd', label: 'Option D' },
] as const
const VIEWS = [
  { value: 'primary', label: 'Primary' },
  { value: 'secondary', label: 'Secondary' },
] as const
const TAGS = [
  { value: 'pasta', label: 'pasta' },
  { value: 'soup', label: 'soup' },
  { value: 'quick', label: 'quick' },
  { value: 'vegetarian', label: 'vegetarian' },
] as const
const DOTS = [
  { value: 'red', label: 'Red', color: 'var(--cat-1)' },
  { value: 'green', label: 'Green', color: 'var(--cat-2)' },
  { value: 'blue', label: 'Blue', color: 'var(--cat-3)' },
] as const
const MIXED = [
  { value: 'all-day', label: 'All day' },
  { value: 'morning', label: 'Morning', color: 'var(--cat-1)' },
  { value: 'evening', label: 'Evening', color: 'var(--cat-3)' },
  { value: 'night', label: 'Night' },
] as const
const LONG = ['Ambient', 'Breakbeat', 'Dub techno', 'Electro', 'Funk', 'Garage', 'House', 'Jungle', 'Minimal', 'Progressive', 'Synthwave', 'Trance'].map((l) => ({ value: l, label: l }))

export function Actions() {
  const [tags, setTags] = useState<string[]>(['quick'])
  const [dots, setDots] = useState<string[]>([])
  const [mixed, setMixed] = useState<string[]>(['morning'])
  const [long, setLong] = useState<string[]>(['House', 'Trance'])
  const [choice, setChoice] = useState<'a' | 'b' | 'c' | 'd'>('b')
  const [listChoice, setListChoice] = useState<'a' | 'b' | 'c' | 'd'>('a')
  const [view, setView] = useState<'primary' | 'secondary'>('primary')
  const [pressed, setPressed] = useState(false)
  const [amount, setAmount] = useState(12)
  const [help, setHelp] = useState(false)
  const [inline, setInline] = useState(false)
  return (
    <>
      <Section id="Button" title="Button" intro="One text button with four variants, a compact size, an optional icon and an accent tone for the outline. With href it is a link that looks the same. Width is content-sized unless block is set. The compact size keeps a 44px tap area around its 36px face.">
        <Demo label="Variants">
          <div className="dkj-demo-row">
            <Button>Default</Button>
            <Button variant="outline">Outline</Button>
            <Button variant="positive">Positive</Button>
          </div>
          <div className="dkj-demo-row">
            <Button variant="primary">Primary (content width)</Button>
          </div>
          <Button variant="primary" block>Primary (block)</Button>
        </Demo>
        <Demo label="States -- default">
          <div className="dkj-demo-row">
            <Button>Rest</Button>
            <Button data-demo-state="focus">Focus</Button>
            <Button disabled>Disabled</Button>
          </div>
        </Demo>
        <Demo label="Compact">
          <div className="dkj-demo-row">
            <Button variant="outline" size="compact">Back</Button>
            <Button variant="positive" size="compact">Next</Button>
            <Button variant="positive" size="compact" disabled>Next</Button>
          </div>
        </Demo>
        <Demo label="Primary -- states">
          <div className="dkj-demo-row">
            <Button variant="primary">Rest</Button>
            <Button variant="primary" data-demo-state="focus">Focus</Button>
            <Button variant="primary" disabled>Disabled</Button>
          </div>
        </Demo>
        <Demo label="Accent outline -- beside a Stepper (reset), rest / focus / disabled">
          <div className="dkj-demo-row">
            <Stepper label="Amount" value={amount} onChange={setAmount} />
            <Button variant="outline" tone="accent" onClick={() => setAmount(12)}>Reset</Button>
            <Button variant="outline" tone="accent" data-demo-state="focus">Focus</Button>
            <Button variant="outline" tone="accent" disabled>Disabled</Button>
          </div>
        </Demo>
        <Demo label="Link with icon -- a download: rest / hover / focus / active / disabled">
          <Button href="#Button" download icon="download" block>Download offline version</Button>
          <div className="dkj-demo-row">
            <Button href="#Button" download icon="download" data-demo-state="hover">Hover</Button>
            <Button href="#Button" download icon="download" data-demo-state="focus">Focus</Button>
            <Button href="#Button" download icon="download" data-demo-state="active">Active</Button>
            <Button href="#Button" icon="download" aria-disabled="true">Disabled</Button>
          </div>
        </Demo>
        <Demo label="House .btn / .btn--primary -- rest / disabled">
          <div className="dkj-demo-row">
            <button type="button" className="btn">Rest</button>
            <button type="button" className="btn" disabled>Disabled</button>
            <button type="button" className="btn btn--primary">Rest</button>
            <button type="button" className="btn btn--primary" disabled>Disabled</button>
          </div>
        </Demo>
        <Demo label="House .btn--touch / .btn--block / .icon-btn in an .action-row">
          <HouseButtonsDemo />
        </Demo>
        <Demo label="House .seg / .info-button / .more / .sort / .chart .bar / .moretoggle -- tab through for the focus rings">
          <HouseFocusDemo />
        </Demo>
      </Section>

      <Section id="SegmentedChoice" title="SegmentedChoice" intro="A single choice. As a row it holds four options on a 360px phone; in a drawer it becomes a list; joined is the dense capsule for a page header, 30px to the eye with a 44px tap area.">
        <Demo label="Row">
          <SegmentedChoice label="Choose an option" options={OPTIONS} value={choice} onChange={setChoice} />
        </Demo>
        <Demo label="Row -- nothing chosen yet">
          <SegmentedChoice label="Choose an option" options={OPTIONS} value={undefined} onChange={setChoice} />
        </Demo>
        <Demo label="List (in a drawer)">
          <SegmentedChoice label="Choose an option" layout="list" options={OPTIONS} value={listChoice} onChange={setListChoice} />
        </Demo>
        <Demo label="Joined -- two options / nothing chosen / a single option">
          <div className="dkj-demo-row">
            <SegmentedChoice label="View" layout="joined" options={VIEWS} value={view} onChange={setView} />
            <SegmentedChoice label="Choose an option" layout="joined" options={OPTIONS.slice(0, 3)} value={undefined} onChange={setChoice} />
            <SegmentedChoice label="View" layout="joined" options={VIEWS.slice(0, 1)} value="primary" onChange={setView} />
          </div>
        </Demo>
      </Section>

      <Section id="FilterChips" title="FilterChips" intro="A multi-select filter: several chips on at once, empty means no filter. An on chip shows a check mark as well as the fill. The row wraps, so every chip stays visible on a 360px phone; Clear appears while anything is chosen.">
        <Demo label="Text tags -- one preset on">
          <FilterChips label="Tags" options={TAGS} value={tags} onChange={setTags} />
        </Demo>
        <Demo label="Colour dots -- house tokens, nothing on">
          <FilterChips label="Colour" options={DOTS} value={dots} onChange={setDots} />
        </Demo>
        <Demo label="Mixed -- only some options have a dot">
          <FilterChips label="Time of day" options={MIXED} value={mixed} onChange={setMixed} />
        </Demo>
        <Demo label="Long set -- wraps instead of scrolling">
          <FilterChips label="Genre" options={LONG} value={long} onChange={setLong} />
        </Demo>
      </Section>

      <Section id="IconButton" title="IconButton" intro="Filled for a card's actions, outline for the pencil beside a value (never taller than --control-h), ghost for the menu and close.">
        <Demo label="Filled -- card actions">
          <CardActions>
            <IconButton variant="filled" icon="eye" label="View A">View A</IconButton>
            <IconButton variant="filled" icon="eye" label="View B">View B</IconButton>
          </CardActions>
          <CardActions>
            <IconButton variant="filled" icon="eye" label="Icon only" />
            <IconButton variant="filled" icon="eye" label="Focus" data-demo-state="focus" />
            <IconButton variant="filled" icon="eye" label="Disabled" disabled />
          </CardActions>
        </Demo>
        <Demo label="Outline -- rest / focus / pressed (open)">
          <div className="dkj-demo-row">
            <IconButton icon="pencil" label="Edit" />
            <IconButton icon="pencil" label="Edit" data-demo-state="focus" />
            <IconButton icon="pencil" label="Edit" pressed={pressed} onClick={() => setPressed(!pressed)} />
            <span style={{ fontSize: 'var(--text-sm)', color: 'var(--ink-4)' }}>tap the third to toggle</span>
          </div>
        </Demo>
        <Demo label="Ghost">
          <div className="dkj-demo-row">
            <IconButton variant="ghost" icon="menu" label="Menu" />
            <IconButton variant="ghost" icon="close" label="Close" />
          </div>
        </Demo>
      </Section>

      <Section id="RoundToggle" title="RoundToggle" intro="A round “?” or “i”: a small glyph with a 44px tap area that does not make its row taller. The badge size sits after a number in a table; the inline size is a 16px muted ring for inside a label or heading.">
        <Demo label="Help -- closed / open">
          <div className="dkj-demo-row">
            <RoundToggle />
            <RoundToggle expanded />
            <RoundToggle data-demo-state="focus" />
          </div>
        </Demo>
        <Demo label="Info -- closed / open">
          <div className="dkj-demo-row">
            <RoundToggle kind="info" />
            <RoundToggle kind="info" expanded />
          </div>
        </Demo>
        <Demo label="Inline -- in a label and a heading / open / focus">
          <div className="dkj-demo-row">
            <span>
              Net deposits
              <RoundToggle size="inline" label="Explain: Net deposits" expanded={inline} onClick={() => setInline(!inline)} />
            </span>
            <span>
              Open
              <RoundToggle size="inline" label="Explain: Open" expanded />
            </span>
            <span>
              Focus
              <RoundToggle size="inline" label="Explain: Focus" data-demo-state="focus" />
            </span>
            <span>
              Info
              <RoundToggle size="inline" label="Info: Info" kind="info" />
            </span>
          </div>
          <h3 style={{ margin: 0, display: 'flex', alignItems: 'center' }}>
            A heading
            <RoundToggle size="inline" label="Explain: A heading" />
          </h3>
        </Demo>
        <Demo label="Badge -- after a number">
          <div className="dkj-demo-row" style={{ fontVariantNumeric: 'tabular-nums' }}>
            <span>12 pcs</span>
            <RoundToggle size="badge" expanded={help} onClick={() => setHelp(!help)} />
          </div>
        </Demo>
      </Section>
    </>
  )
}
