import { useState, type ReactNode } from 'react'
import { cx } from './cx'
import './figure.css'

export type FigureRatio = '16/9' | '4/3' | '3/2' | '1/1' | '3/4' | '9/16'

type FigureBase = {
  /** The frame's aspect ratio; default 16/9. */
  ratio?: FigureRatio
  /** cover (default) fills and crops; contain letterboxes on the placeholder fill. */
  fit?: 'cover' | 'contain'
  /** Text (and, say, a verdict Chip) under the frame. */
  caption?: ReactNode
  /** Show the placeholder even when a src is given; the src is then not rendered at all. */
  placeholder?: boolean
  /** The visible text in the placeholder; default "Image placeholder". */
  placeholderLabel?: string
  className?: string
}

/** alt is required whenever a src is given; alt="" marks a decorative image. */
export type FigureProps = FigureBase & ({ src: string; alt: string } | { src?: undefined; alt?: string })

const RATIO_CLASS: Record<FigureRatio, string> = {
  '16/9': 'dkj-figure--r-16-9',
  '4/3': 'dkj-figure--r-4-3',
  '3/2': 'dkj-figure--r-3-2',
  '1/1': 'dkj-figure--r-1-1',
  '3/4': 'dkj-figure--r-3-4',
  '9/16': 'dkj-figure--r-9-16',
}

/**
 * Figure -- a framed image with a fixed aspect ratio, an optional caption and a placeholder state (no src, `placeholder`,
 * or an image that fails to load). The frame fills its column, so the parent sets the width. A brand-book original (no source repo).
 */
export function Figure(props: FigureProps) {
  // Keyed by src: a new src (also A -> B -> A) starts with a fresh load state and so always retries.
  return <FigureFrame key={props.src || ''} {...props} />
}

function FigureFrame({ src, alt, ratio = '16/9', fit = 'cover', caption, placeholder, placeholderLabel, className }: FigureProps) {
  const [failed, setFailed] = useState(false)
  const hasSrc = !!src
  const showImage = hasSrc && !placeholder && !failed
  const label = failed ? 'Image unavailable' : (placeholderLabel ?? 'Image placeholder')
  const name = alt || label
  // A decorative image (alt="") that failed is not announced either.
  const decorative = failed && alt === ''

  return (
    <figure className={cx('dkj-figure', RATIO_CLASS[ratio], fit === 'contain' && 'dkj-figure--contain', className)}>
      {showImage ? (
        <div className="dkj-figure__frame">
          <img src={src} alt={alt} loading="lazy" decoding="async" onError={() => setFailed(true)} />
        </div>
      ) : (
        <div className="dkj-figure__frame" {...(decorative ? { 'aria-hidden': true } : { role: 'img', 'aria-label': name })}>
          <div className="dkj-figure__placeholder" aria-hidden="true">
            <svg className="dkj-figure__glyph" viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="18" height="16" rx="2" />
              <circle cx="9" cy="10" r="1.75" />
              <path d="M3 17l5-5 4 4 3-3 6 6" />
            </svg>
            <span className="dkj-figure__label">{label}</span>
          </div>
        </div>
      )}
      {caption != null && <figcaption className="dkj-figure__caption">{caption}</figcaption>}
    </figure>
  )
}
