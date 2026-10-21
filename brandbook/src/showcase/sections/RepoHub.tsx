import { Button } from '../../components/Button'
import { ABOUT_PATH, DASHBOARD_PATH, DASHBOARDS_PATH } from '../../routes'
import { Section } from '../Showcase'

/** The Repo hub pattern in the showcase (#3202): a specimen page and the other repos' hubs drawn in it, both on placeholder data. */
export function RepoHub() {
  return (
    <Section
      id="repo-hub"
      title="Repo hub"
      intro="The two pages a DKJ-Solutions repo's dev server opens on (#3270): the home page, a portal with the repo's name, its products, one link to About this repo and the Brand book; and About this repo, with its pages, what is in flight and its facts. The pattern is drawn with this brand book's components on placeholder data; the hub previews show other repos' About pages in it."
    >
      <div className="dkj-demo-row">
        <Button variant="primary" href={DASHBOARD_PATH}>
          Open the Repo hub pattern
        </Button>
        <Button href={ABOUT_PATH}>About this repo</Button>
        <Button href={DASHBOARDS_PATH}>Hub previews</Button>
      </div>
    </Section>
  )
}
