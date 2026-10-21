import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../../plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css'
import './brand-layer.css'
import './index.css'
import App from './App.tsx'
import { RepoAbout, RepoDashboard } from './dashboard/RepoDashboard.tsx'
import { DashboardIndex, DashboardPreviewPage } from './dashboard/DashboardPreviews.tsx'
import { dashboardPreviewId, isAboutPath, isDashboardPath, isDashboardsPath } from './routes'

const { pathname } = window.location
const previewId = dashboardPreviewId(pathname)

/** The brand book is the index; any path this app does not know lands there too. */
function page() {
  if (isDashboardPath(pathname)) return <RepoDashboard />
  if (isAboutPath(pathname)) return <RepoAbout />
  if (isDashboardsPath(pathname)) return <DashboardIndex />
  if (previewId) return <DashboardPreviewPage id={previewId} />
  return <App />
}

createRoot(document.getElementById('root')!).render(<StrictMode>{page()}</StrictMode>)
