/// <reference types="vite/client" />

/** house-theme.js (the dkj-solutions plugin's house-style assets), inlined in <head> by vite.config.ts. */
interface DKJThemeApi {
  themes: { id: string; name: string; mode: 'light' | 'dark'; hex: string }[]
  set(id: string): void
  reset(): void
  picker(el: HTMLElement | null, labels?: { light?: string; dark?: string }): void
  /** Draws the settings button into el and returns the panel's slot for the app's own controls. */
  settings(
    el: HTMLElement | null,
    options?: {
      label?: string
      title?: string
      theme?: string
      reset?: string
      light?: string
      dark?: string
      width?: string
      fluid?: string
      phone?: string
      full?: string
      widths?: false
    },
  ): HTMLElement | null
  current(): string | null
  widths: ('fluid' | 'phone' | 'full')[]
  setWidth(width: 'fluid' | 'phone' | 'full'): void
  width(): 'fluid' | 'phone' | 'full' | null
}
interface Window {
  DKJTheme: DKJThemeApi
}
