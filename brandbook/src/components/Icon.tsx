import type { SVGProps } from 'react'
import './buttons.css'

/**
 * The stroke icon set: a 24-unit viewBox, 2px round strokes in currentColor, so an icon follows the
 * foreground of whatever it sits in. Own drawings, no third-party marks.
 */
const STROKE_PATHS = {
  eye: ['M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z', 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z'],
  pencil: ['M4 20h4L19 9l-4-4L4 16v4zM14 6l4 4'],
  close: ['M6 6l12 12M18 6L6 18'],
  check: ['M5 12.5l4.5 4.5L19 7.5'],
  undo: ['M9 14L4 9l5-5M4 9h10.5a5.5 5.5 0 0 1 0 11H11'],
  search: ['M11 17.5a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13Z', 'M16 16l4.5 4.5'],
  menu: ['M4 7h16M4 12h16M4 17h16'],
  'arrow-left': ['M19 12H5m0 0l6-6M5 12l6 6'],
  'arrow-right': ['M5 12h14m0 0l-6-6m6 6l-6 6'],
  download: ['M12 4v11m0 0l-4.5-4.5M12 15l4.5-4.5M5 19.5h14'],
  help: ['M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Z', 'M9.1 9a3 3 0 0 1 5.8 1c0 2-3 2.5-3 4.5M12 17.5v.01'],
  warning: ['M12 3.5 2.5 20h19L12 3.5Z', 'M12 10v4.5M12 17.5v.01'],
  shield: ['M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6l-8-3Z'],
  book: ['M2 5.5C4.5 4 8 4 12 6c4-2 7.5-2 10-.5V19c-2.5-1.5-6-1.5-10 .5-4-2-7.5-2-10-.5Z', 'M12 6v13.5'],
  person: ['M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z', 'M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1'],
  chart: ['M4 20V10', 'M10 20V4', 'M16 20v-7', 'M22 20H2'],
  flask: ['M9 3h6', 'M10 3v5.5L5 17a2.5 2.5 0 0 0 2.2 4h9.6a2.5 2.5 0 0 0 2.2-4l-5-8.5V3', 'M7 14h10'],
  target: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z', 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z', 'M12 1v4', 'M12 19v4', 'M1 12h4', 'M19 12h4'],
  coin: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z', 'M12 7v10M9.5 9.5h3.75a1.75 1.75 0 0 1 0 3.5h-2.5a1.75 1.75 0 0 0 0 3.5H14.5'],
} as const

export type IconName = keyof typeof STROKE_PATHS | 'info'
export const ICON_NAMES = [...Object.keys(STROKE_PATHS), 'info'] as IconName[]

type IconProps = { name: IconName; size?: number } & Omit<SVGProps<SVGSVGElement>, 'name'>

export function Icon({ name, size = 20, ...rest }: IconProps) {
  if (name === 'info') {
    // Filled disc in currentColor with the "i" cut out in the surface below it (.dkj-info-dot / .dkj-info-stem).
    return (
      <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" focusable="false" {...rest}>
        <circle cx="12" cy="12" r="10" fill="currentColor" />
        <circle className="dkj-info-dot" cx="12" cy="7.6" r="1.4" />
        <path
          className="dkj-info-stem"
          d="M10.4 10.8H12.4V16.6M10.2 16.6H14"
          fill="none"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    )
  }
  const strong = name === 'close' || name === 'check' || name === 'undo'
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={strong ? 2.25 : 2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...rest}
    >
      {STROKE_PATHS[name].map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  )
}
