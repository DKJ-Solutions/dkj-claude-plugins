import { themeName, type ThemeId } from '../repos'

/** A theme as a small round swatch (the house .theme-swatch carries the theme's own colours) and its name. */
export function ThemeLabel({ id }: { id: ThemeId }) {
  return (
    <span className="dkj-theme-label">
      <span className="theme-swatch dkj-theme-label__swatch" data-id={id} aria-hidden="true">
        <i />
      </span>
      {themeName(id)}
    </span>
  )
}
