import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../../plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css'
import './brand-layer.css'
import './index.css'
import App from './App.tsx'
import { RepoDashboard } from './dashboard/RepoDashboard.tsx'
import { DashboardIndex, DashboardPreviewPage } from './dashboard/DashboardPreviews.tsx'
import { SHOWCASE_PATH, dashboardPreviewId, isDashboardPath, isDashboardsPath, isShowcasePath } from './routes'

const { pathname, hash } = window.location
const previewId = dashboardPreviewId(pathname)

function page() {
  if (isShowcasePath(pathname)) return <App />
  if (isDashboardsPath(pathname)) return <DashboardIndex />
  if (previewId) return <DashboardPreviewPage id={previewId} />
  return <RepoDashboard />
}

// A link from before the showcase moved off the index (/#tokens, /#preview/<repo>) still lands on its section;
// nothing renders meanwhile, so the dashboard neither flashes nor spends GitHub requests on the way.
if (isDashboardPath(pathname) && hash.length > 1) {
  window.location.replace(`${SHOWCASE_PATH}${hash}`)
} else {
  createRoot(document.getElementById('root')!).render(<StrictMode>{page()}</StrictMode>)
}
