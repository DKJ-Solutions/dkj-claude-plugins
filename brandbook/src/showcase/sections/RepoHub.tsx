import { Button } from '../../components/Button'
import { DASHBOARD_PATH, DASHBOARDS_PATH } from '../../routes'
import { Section } from '../Showcase'

/** The Repo hub pattern in the showcase (#3202): a specimen page and the other repos' hubs drawn in it, both on placeholder data. */
export function RepoHub() {
  return (
    <Section
      id="repo-hub"
      title="Repo hub"
      intro="The index page a DKJ-Solutions repo's dev server opens on: what the repo is for, its pages, and what is in flight. The pattern is drawn with this brand book's components on placeholder data; the hub previews show other repos' hubs in it."
    >
      <div className="dkj-demo-row">
        <Button variant="primary" href={DASHBOARD_PATH}>
          Open the Repo hub pattern
        </Button>
        <Button href={DASHBOARDS_PATH}>Hub previews</Button>
      </div>
    </Section>
  )
}
