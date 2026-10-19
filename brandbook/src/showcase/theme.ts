import { useEffect, useState } from 'react'
import { DEFAULT_THEMES, defaultThemeOf } from '../repos'

/** The active house theme id (e.g. "blue"), kept in sync with data-theme so token readouts can re-read on a change. */
export function useThemeId() {
  const [id, setId] = useState(() => document.documentElement.dataset.theme ?? '')
  useEffect(() => {
    const obs = new MutationObserver(() => setId(document.documentElement.dataset.theme ?? ''))
    obs.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
    return () => obs.disconnect()
  }, [])
  return id
}

/** Sets (or, for null, removes) the page's default theme; a viewer's own stored pick always wins. */
function applyDefaultTheme(id: string | null) {
  const root = document.documentElement
  if (id) root.setAttribute('data-theme-default', id)
  else root.removeAttribute('data-theme-default')
  // The storage key as house-theme.js derives it; a stored value counts as a pick only if it is a known theme.
  let picked = false
  try {
    const stored = localStorage.getItem('dkj-theme' + (root.dataset.themeKey ? ':' + root.dataset.themeKey : ''))
    picked = window.DKJTheme.themes.some((t) => t.id === stored)
  } catch {
    // storage unavailable: nothing is stored, so the default applies
  }
  // With no pick, reset only makes the house script resolve the theme again from the attribute.
  if (!picked) window.DKJTheme.reset()
}

/**
 * While the calling page is open, the repo's default theme is the page default (an unknown repo gets the brand
 * book's own); leaving restores what <html> declared before (index.html). A viewer's own pick is never overridden.
 */
export function useRepoDefaultTheme(repo: string) {
  const id = defaultThemeOf(repo) ?? DEFAULT_THEMES['dkj-brandbook']
  useEffect(() => {
    const before = document.documentElement.getAttribute('data-theme-default')
    applyDefaultTheme(id)
    return () => applyDefaultTheme(before)
  }, [id])
}
