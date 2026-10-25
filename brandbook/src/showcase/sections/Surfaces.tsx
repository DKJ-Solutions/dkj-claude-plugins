import { useId, useState } from 'react'
import { CardActions, IconButton, RoundToggle } from '../../components/Button'
import { Card, CardBody, CardHead, TintedPanel } from '../../components/Card'
import { Amount, FooterNote, GroupHeading, QuestionBlock } from '../../components/Content'
import { Alert, Banner, Chip, Disclosure, Help, Message, ReadMoreToggle, TitleTag } from '../../components/Feedback'
import { Figure } from '../../components/Figure'
import { Badge } from '../../components/Metrics'
import { Prose } from '../../components/Prose'
import { Icon } from '../../components/Icon'
import { StatRow, RowList, ValueBox } from '../../components/Row'
import { DefinitionList } from '../../components/Table'
import { Demo, Section } from '../Showcase'

/** A neutral two-tone 4:3 picture as a data: URI, so the demos need no network and no asset. */
const SAMPLE_IMAGE =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300"><rect width="400" height="300" fill="#8a97a6"/><path d="M0 300V210l110-80 90 70 70-50 130 90v60z" fill="#5d6b7b"/><circle cx="300" cy="80" r="32" fill="#d5dbe2"/></svg>',
  )

const LOREM = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.'

function Actions2() {
  return (
    <div style={{ padding: '0 var(--spacing-4) var(--spacing-4)' }}>
      <CardActions>
        <IconButton variant="filled" icon="eye" label="View A">View A</IconButton>
        <IconButton variant="filled" icon="eye" label="View B">View B</IconButton>
      </CardActions>
    </div>
  )
}

/** A read-more block: the extra text opens above the full-width toggle. */
function ReadMoreDemo() {
  const [open, setOpen] = useState(false)
  const id = useId()
  return (
    <div>
      <p className="dkj-msg" id={id} hidden={!open} style={{ marginBottom: 'var(--spacing-3)' }}>
        {LOREM} {LOREM}
      </p>
      <p className="dkj-msg" style={{ marginBottom: 'var(--spacing-3)' }}>
        {LOREM}
      </p>
      <ReadMoreToggle expanded={open} controls={id} onToggle={() => setOpen(!open)} />
    </div>
  )
}

function ProseSample() {
  return (
    <>
      <h1>A document title</h1>
      <p>
        A first paragraph with a <a href="#Prose">link</a>, some <strong>bold</strong> and <em>italic</em> text and <code>inline code</code>. {LOREM}
      </p>
      <h2>A second-level heading</h2>
      <p>{LOREM}</p>
      <h3>Lists</h3>
      <ul>
        <li>An unordered item</li>
        <li>
          Another item with a nested list
          <ul>
            <li>A nested item</li>
            <li>Another nested item</li>
          </ul>
        </li>
      </ul>
      <ol>
        <li>A first step</li>
        <li>A second step</li>
      </ol>
      <h3>A task list</h3>
      <ul>
        <li>
          <input type="checkbox" checked disabled aria-labelledby="prose-task-done" />
          <span id="prose-task-done">A done task</span>
        </li>
        <li>
          <input type="checkbox" disabled aria-labelledby="prose-task-open" />
          <span id="prose-task-open">An open task</span>
        </li>
      </ul>
      <table tabIndex={0}>
        <thead>
          <tr>
            <th scope="col">Name</th>
            <th scope="col">Kind</th>
            <th scope="col" align="right">
              Count
            </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>First row</td>
            <td>Text</td>
            <td align="right">12</td>
          </tr>
          <tr>
            <td>Second row</td>
            <td>Text</td>
            <td align="right">1,204</td>
          </tr>
        </tbody>
      </table>
      <pre tabIndex={0}>
        <code>{'const longLine = "a line of code that is longer than the column, so the block scrolls sideways instead of wrapping"\nconst short = 1'}</code>
      </pre>
      <blockquote>
        <p>A quotation that sets a passage apart from the text around it.</p>
      </blockquote>
      <hr />
      <p>A closing paragraph after the rule.</p>
    </>
  )
}

export function Surfaces() {
  return (
    <>
      <Section id="Card" title="Card" intro="The main surface. A card head is a centred title with an accent icon, and below it the card's actions across the full width. The body sits under a rule.">
        <Demo label="Default" surface={false}>
          <Card>
            <p style={{ margin: 0 }}>{LOREM}</p>
          </Card>
        </Demo>
        <Demo label="Flush -- head, actions" surface={false}>
          <Card flush>
            <CardHead title="Card title" icon="shield" />
            <Actions2 />
          </Card>
        </Demo>
        <Demo label="Flush -- head and body" surface={false}>
          <Card flush>
            <CardHead title="Card title" icon="chart" />
            <CardBody>
              <RowList>
                <StatRow name="Label one">
                  <ValueBox value="1,234" />
                </StatRow>
                <StatRow name="Label two">
                  <ValueBox value="56" />
                </StatRow>
              </RowList>
            </CardBody>
          </Card>
        </Demo>
        <Demo label="Open (its dialog is open)" surface={false}>
          <Card flush open>
            <CardHead title="Card title" icon="book" />
            <Actions2 />
          </Card>
        </Demo>
        <Demo label="Invalid" surface={false}>
          <Card flush invalid>
            <CardHead title="Card title" icon="target" />
            <p className="dkj-msg dkj-msg--error" style={{ padding: '0 var(--spacing-4) var(--spacing-3)' }}>
              This value is out of range.
            </p>
          </Card>
        </Demo>
        <Demo label="Data -- serif title, subline, info" surface={false}>
          <Card variant="data">
            <CardHead title="Card title" subtitle="A muted line saying what the figures are, in euro" info={<RoundToggle size="inline" label="Explain: Card title" />} />
            <CardBody>
              <DefinitionList
                items={[
                  { term: 'Label one', value: '1,234' },
                  { term: 'Label two', value: '56' },
                ]}
              />
            </CardBody>
          </Card>
        </Demo>
        <Demo label="Data -- open / invalid" surface={false}>
          <Card variant="data" open>
            <CardHead title="Open" subtitle="Its dialog is open" />
          </Card>
          <Card variant="data" invalid>
            <CardHead title="Invalid" subtitle="This value is out of range" />
          </Card>
          <Card variant="data">
            <CardHead title="example-repo" badge={<Badge tone="warn">!</Badge>} subtitle="warn · public -- the badge is decorative, so the sub line says the status too" />
          </Card>
        </Demo>
      </Section>

      <Section id="TintedPanel" title="TintedPanel" intro="Parts of one card, each in its own tint mixed from a colour token, so they follow the theme and the mode on their own. As a button it becomes a large tile.">
        <Demo label="Panels">
          <TintedPanel>
            <strong>Neutral</strong>
            <p className="dkj-msg">{LOREM}</p>
          </TintedPanel>
          <TintedPanel tone="accent">
            <strong>Accent</strong>
            <p className="dkj-msg">{LOREM}</p>
          </TintedPanel>
          <TintedPanel tone="positive">
            <strong>Positive</strong>
            <p className="dkj-msg">{LOREM}</p>
          </TintedPanel>
        </Demo>
        <Demo label="Tiles (buttons)">
          <TintedPanel as="button" tone="accent">
            <span className="dkj-panel-label">Label A</span>
            <span className="dkj-panel-value">1,234</span>
          </TintedPanel>
          <TintedPanel as="button">
            <span className="dkj-panel-label">Label B</span>
            <span className="dkj-panel-value dkj-tone-negative">−5,678</span>
          </TintedPanel>
        </Demo>
      </Section>

      <Section id="Banner" title="Banner" intro="A callout. Accent is a soft tinted line whose strong words turn accent; warn is the notice look: a warm background, a bold lead line with a warning mark, then text and an optional list.">
        <Demo label="Accent" surface={false}>
          <Banner>
            What does it take to reach <strong>step 12</strong>?
          </Banner>
        </Demo>
        <Demo label="Warn -- lead and list" surface={false}>
          <Banner tone="warn" lead="The ledger does not match the export">
            -- figures may differ.
            <ul>
              <li>Difference one: 12 units</li>
              <li>Difference two: a missing line</li>
            </ul>
          </Banner>
        </Demo>
        <Demo label="Warn -- lead only" surface={false}>
          <Banner tone="warn" lead="Check this before you go on" />
        </Demo>
      </Section>

      <Section id="Alert" title="Alert" intro="A generic danger callout: a danger border, a tint of --negative-3 built from house tokens, a title in the danger text colour. No hazard stripes: a layout that is one app's own stays in that app.">
        <Demo label="Danger" surface={false}>
          <Alert title="Danger zone">
            <p className="dkj-msg">{LOREM}</p>
          </Alert>
        </Demo>
      </Section>

      <Section id="Message" title="Message" intro="Supporting text in five tones. Debug is for developers only, outlined so it never reads as help.">
        <Demo label="Tones">
          <Message>Hint -- muted help under a field.</Message>
          <Message tone="warn">Warning -- needs attention.</Message>
          <Message tone="error">Error -- the value is not valid.</Message>
          <Message tone="debug">Debug -- developer info: id=42, state=idle</Message>
          <Message tone="note">Note -- a hint with more room above it.</Message>
        </Demo>
      </Section>

      <Section id="Chip" title="Chip" intro="A verdict pill.">
        <Demo label="Tones">
          <div className="dkj-demo-row">
            <Chip tone="yes">Yes</Chip>
            <Chip tone="no">No</Chip>
            <Chip tone="todo">To do</Chip>
            <Chip tone="unknown">Unknown</Chip>
          </div>
        </Demo>
      </Section>

      <Section id="TitleTag" title="TitleTag" intro="A small uppercase pill on its own line above a title. Warn is warning text (--warning-5) on the warning background (--warning-1), so it reads in both modes.">
        <Demo label="Accent / info / warn">
          <div className="dkj-demo-row">
            <TitleTag>Expected</TitleTag>
            <TitleTag tone="info">Edit</TitleTag>
            <TitleTag tone="warn">Sell</TitleTag>
          </div>
        </Demo>
      </Section>

      <Section id="Help" title="Help" intro="An explanation that stays closed until asked for; the round “?” sits on the right.">
        <Demo label="Closed">
          <Help>{LOREM}</Help>
        </Demo>
        <Demo label="Open">
          <Help defaultOpen>{LOREM}</Help>
        </Demo>
      </Section>

      <Section id="Disclosure" title="Disclosure" intro="A native details/summary with a ▾ / ▴ marker after the summary. A plain string is the title; the optional meta and trailing slots add a date and a chip on the right, and the row wraps instead of truncating.">
        <Demo label="Closed / open">
          <Disclosure summary="Help">
            <Message>{LOREM}</Message>
          </Disclosure>
          <Disclosure summary="Help" defaultOpen>
            <Message>{LOREM}</Message>
          </Disclosure>
        </Demo>
        <Demo label="Structured summary">
          <Disclosure
            summary={
              <>
                <span className="dkj-disclosure-version">v2.1.0</span> Example release title
              </>
            }
            meta="13 Oct 2026"
            trailing={<Chip tone="yes">Latest</Chip>}
          >
            <Message>{LOREM}</Message>
          </Disclosure>
        </Demo>
        <Demo label="Structured summary, 320px wide">
          <div className="dkj-narrow">
            <Disclosure
              summary={
                <>
                  <span className="dkj-disclosure-version">v2.1.0</span> Example release title
                </>
              }
              meta="13 Oct 2026"
              trailing={<Chip tone="yes">Latest</Chip>}
            >
              <Message>{LOREM}</Message>
            </Disclosure>
          </div>
        </Demo>
      </Section>

      <Section id="ReadMoreToggle" title="ReadMoreToggle" intro="A full-width read-more button under a block. The extra text opens above it, so the button moves down with what it reveals; aria-expanded and aria-controls tell a screen reader.">
        <Demo label="Closed, then open">
          <ReadMoreDemo />
        </Demo>
      </Section>

      <Section id="GroupHeading" title="GroupHeading" intro="An uppercase muted section label, with an optional counter that turns danger when over its limit. The level prop (2, 3 or 4; default 3) sets the heading element for the page outline and never changes the look.">
        <Demo label="Plain / with counter / over">
          <GroupHeading>Group label</GroupHeading>
          <GroupHeading count="12 / 20">Group label</GroupHeading>
          <GroupHeading count="23 / 20" over>
            Group label
          </GroupHeading>
        </Demo>
        <Demo label="level 2 / level 3 (same look)">
          <GroupHeading level={2}>Group label (h2)</GroupHeading>
          <GroupHeading level={3}>Group label (h3)</GroupHeading>
        </Demo>
      </Section>

      <Section id="QuestionBlock" title="QuestionBlock" intro="An h3 with its verdict chip on the same line (the chip shrinks or drops below a long heading), then the verdict and supporting text.">
        <Demo label="Yes">
          <QuestionBlock title="Question title" chip="yes" chipText="Yes" verdict="Short verdict line">
            <Message>{LOREM}</Message>
          </QuestionBlock>
        </Demo>
        <Demo label="To do -- long heading">
          <QuestionBlock title="A considerably longer question title that wraps" chip="todo" chipText="Not decided yet">
            <Message>{LOREM}</Message>
          </QuestionBlock>
        </Demo>
      </Section>

      <Section id="Amount" title="Amount" intro="A tabular figure with a small icon at the height of the digits.">
        <Demo label="Amount">
          <div className="dkj-demo-row">
            <Amount value="1,234" icon={<Icon name="coin" />} />
            <Amount value="98,765" icon={<Icon name="coin" />} />
          </div>
        </Demo>
      </Section>

      <Section id="Prose" title="Prose" intro="A rendered long-form body (markdown output): plain headings, paragraphs, lists, task lists, a table, code, a quotation, links and a rule, styled without a class on any child. The headings sit one step below the house scale.">
        <Demo label="Base -- every element" surface={false} wide>
          <Prose>
            <ProseSample />
          </Prose>
        </Demo>
        <Demo label="Small -- inside a card" surface={false}>
          <Card>
            <Prose size="sm">
              <ProseSample />
            </Prose>
          </Card>
        </Demo>
        <Demo label="Measure none -- a wide table" wide>
          <Prose measure="none">
            <table tabIndex={0}>
              <thead>
                <tr>
                  <th scope="col">Column</th>
                  <th scope="col">Description</th>
                  <th scope="col">Notes</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>First</td>
                  <td>{LOREM}</td>
                  <td>{LOREM}</td>
                </tr>
              </tbody>
            </table>
          </Prose>
        </Demo>
      </Section>

      <Section id="Figure" title="Figure" intro="A framed image with a fixed aspect ratio, an optional caption and a placeholder state: shown when there is no src, when placeholder is set (the src is then not rendered at all) or when the image fails to load. The frame fills its column; the parent sets the width. alt is required whenever a src is given; alt=&quot;&quot; marks a decorative image. For a bare markdown image, Prose styles the img itself; use a Figure for one that needs a ratio, a caption or a placeholder.">
        <Demo label="Ratios (placeholder): 16/9, 4/3, 1/1, 9/16" wide>
          <div className="dkj-figure-grid">
            <Figure ratio="16/9" caption="16/9" />
            <Figure ratio="4/3" caption="4/3" />
            <Figure ratio="1/1" caption="1/1" />
            <Figure ratio="9/16" caption="9/16" />
          </div>
        </Demo>
        <Demo label="Real image: cover / contain (a 4:3 image in a 1/1 frame)">
          <div className="dkj-figure-grid">
            <Figure src={SAMPLE_IMAGE} alt="A grey landscape with a pale sun" ratio="1/1" caption="cover" />
            <Figure src={SAMPLE_IMAGE} alt="A grey landscape with a pale sun" ratio="1/1" fit="contain" caption="contain" />
          </div>
        </Demo>
        <Demo label="Caption with a Chip">
          <Figure
            src={SAMPLE_IMAGE}
            alt="A grey landscape with a pale sun"
            ratio="16/9"
            caption={
              <>
                Candidate 1 <Chip tone="yes">Within the margin</Chip>
              </>
            }
          />
        </Demo>
        <Demo label="placeholder on a given src (the image is not revealed)">
          <Figure src={SAMPLE_IMAGE} alt="A grey landscape with a pale sun" placeholder placeholderLabel="Preview hidden" caption="src given, placeholder set" />
        </Demo>
        <Demo label="Broken image (the src cannot load)">
          <Figure src="/figure-demo-missing.png" alt="A picture that cannot be loaded" caption="Falls back to the placeholder" />
        </Demo>
        <Demo label="Inside Prose" wide>
          <Prose>
            <p>A figure sits in a prose body as a block child.</p>
            <Figure src={SAMPLE_IMAGE} alt="A grey landscape with a pale sun" ratio="3/2" caption="A captioned image between two paragraphs." />
            <p>{LOREM}</p>
          </Prose>
        </Demo>
      </Section>

      <Section id="FooterNote" title="FooterNote" intro="The small muted note at the foot of a page: what the figures and the explanations are, and are not.">
        <Demo label="Footer note" surface={false}>
          <FooterNote>The explanations are general information to help read the figures. Prices are closing prices; the page does not refresh by itself.</FooterNote>
        </Demo>
      </Section>
    </>
  )
}
