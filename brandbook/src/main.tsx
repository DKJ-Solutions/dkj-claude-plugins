import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../../plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css'
import './brand-layer.css'
import './index.css'
import App from './App.tsx'

/** The brand book is the app's one page; any path under its base lands there (#3274: the Repo hub specimen and its previews are gone). */
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
