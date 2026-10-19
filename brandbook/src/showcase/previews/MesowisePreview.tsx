import { useState } from 'react'
import { Button, CardActions, IconButton, SegmentedChoice } from '../../components/Button'
import { Card, CardHead, TintedPanel } from '../../components/Card'
import { Amount } from '../../components/Content'
import { Banner, Disclosure, Message } from '../../components/Feedback'
import { Icon, type IconName } from '../../components/Icon'
import { DrawerFooter, MenuList, MenuRow, StepHeader, TopBar } from '../../components/Navigation'

/** The cards of the main column, in the app's order, each with its two view buttons. */
const CARDS: readonly { title: string; icon: IconName }[] = [
  { title: 'Equipment', icon: 'shield' },
  { title: 'Skill points', icon: 'book' },
  { title: 'Monster', icon: 'target' },
  { title: 'Potions', icon: 'flask' },
  { title: 'Ability points', icon: 'person' },
  { title: 'Total stats', icon: 'chart' },
]

/** A recreation of Mesowise's main screen (src/apps/registry.ts, MESOWISE_VIEWS), built from brand-book components only. */
export function MesowisePreview() {
  const [level, setLevel] = useState(34)
  return (
    <div className="dkj-preview-app">
      <TopBar name="Mesowise" tagline="The cheapest way to your next level." menu={<SettingsMenu />} />
      <div className="dkj-preview-column">
        <StepHeader value={`Level ${level}`} forwardLabel="Level up" onBack={() => setLevel(level - 1)} onForward={() => setLevel(level + 1)} canBack={level > 1} />
        <Banner>
          What does it cost a <strong>level {level} Warrior</strong> to reach level {level + 1}?
        </Banner>
        <div className="dkj-preview-tiles">
          <TintedPanel as="button" tone="positive">
            <span className="dkj-panel-label">Cheapest setup</span>
            <span className="dkj-panel-value">
              <Amount value="184,200" icon={<Icon name="coin" />} />
            </span>
          </TintedPanel>
          <TintedPanel as="button" tone="accent">
            <span className="dkj-panel-label">Your setup</span>
            <span className="dkj-panel-value">
              <Amount value="231,750" icon={<Icon name="coin" />} />
            </span>
          </TintedPanel>
        </div>
        <Message>Your setup costs 47,550 more than the cheapest one.</Message>
        {CARDS.map((c) => (
          <Card key={c.title} flush>
            <CardHead
              title={c.title}
              icon={c.icon}
              actions={
                <div className="dkj-preview-card-actions">
                  <CardActions>
                    <IconButton variant="filled" icon="eye" label={`${c.title}: cheapest`}>
                      Cheapest
                    </IconButton>
                    <IconButton variant="filled" icon="eye" label={`${c.title}: profile`}>
                      Profile
                    </IconButton>
                  </CardActions>
                </div>
              }
            />
          </Card>
        ))}
      </div>
    </div>
  )
}

function SettingsMenu() {
  const [server, setServer] = useState<'eu' | 'na'>('eu')
  return (
    <>
      <MenuList>
        <MenuRow label="Job" value="Warrior" />
        <MenuRow label="Gender" value="Female" />
      </MenuList>
      <div className="dkj-preview-gap">
        <SegmentedChoice
          label="Server"
          layout="list"
          value={server}
          onChange={setServer}
          options={[
            { value: 'eu', label: 'Europe' },
            { value: 'na', label: 'North America' },
          ]}
        />
      </div>
      <div className="dkj-preview-gap">
        <Disclosure summary="Help">
          <Message>Pick your job and level; every card works out the cheapest way up from there.</Message>
        </Disclosure>
      </div>
      <DrawerFooter>
        <Button href="#preview/dkj-maplestory-classic-mesowise" download icon="download" block>Download offline version</Button>
      </DrawerFooter>
    </>
  )
}
