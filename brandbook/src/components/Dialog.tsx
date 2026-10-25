import { createContext, useContext, useEffect, useId, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cx } from './cx'
import { RoundToggle } from './Button'
import { TitleTag } from './Feedback'
import { Icon } from './Icon'
import './dialog.css'

/** How many dialogs this one sits on: each stacked dialog is --popup-step of the one below it. */
const Depth = createContext(0)

export type DialogProps = {
  open: boolean
  onClose: () => void
  title: string
  /** A muted line under the title. */
  subtitle?: string
  /** A pill label on its own line above the title. */
  tag?: string
  /** accent: the surface turns accent-tinted. info: info-tinted, and the accent inside becomes the info-accent. */
  tone?: 'default' | 'accent' | 'info'
  /** An "i" right after the title; it opens its own (stacked) dialog with this text. */
  info?: ReactNode
  /** With onSave the close cross becomes a check that saves, and a red undo arrow (cancel) sits left of it. */
  onSave?: () => void
  /** drawer: a full-height panel sliding in from the right, swipe right to close. */
  variant?: 'dialog' | 'drawer'
  /** heading: card (bold) or plain; the title is an <h3> (--text-h3) either way, and a drawer's title is a bold <h3> too. */
  heading?: 'card' | 'plain'
  children: ReactNode
}

/**
 * Dialog -- the browser's own modal <dialog>: focus stays inside, Escape and a tap on the backdrop close it, and the
 * page behind it stops scrolling. Centred on any screen; taller content scrolls inside the dialog. The padding sits in
 * an inner box, so a tap on empty space inside never counts as a tap outside.
 */
export function Dialog({
  open,
  onClose,
  title,
  subtitle,
  tag,
  tone = 'default',
  info,
  onSave,
  variant = 'dialog',
  heading = 'card',
  children,
}: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null)
  const depth = useContext(Depth)
  const [infoOpen, setInfoOpen] = useState(false)
  const swipeStart = useRef<number | null>(null)
  const titleId = useId()
  // h3 is the lowest heading the house style has (October 25, 2026), so every dialog title is one.
  const Title = 'h3'

  useEffect(() => {
    const d = ref.current
    if (!d) return
    if (open && !d.open) d.showModal()
    if (!open && d.open) d.close()
    // A dialog closed with its info dialog open reopens with it closed.
    if (!open) setInfoOpen(false)
  }, [open])

  const scale: CSSProperties | undefined =
    variant === 'drawer' ? undefined : ({ '--dkj-depth': depth } as CSSProperties)

  return (
    <dialog
      ref={ref}
      className={cx('dkj-dialog', variant === 'drawer' && 'dkj-dialog--drawer', tone !== 'default' && `dkj-dialog--${tone}`)}
      style={scale}
      aria-labelledby={titleId}
      onCancel={(e) => {
        e.preventDefault()
        onClose()
      }}
      onClick={(e) => e.target === ref.current && onClose()}
      onPointerDown={
        variant === 'drawer'
          ? (e) => {
              // Only a swipe on the drawer itself: not from a stacked dialog (React events bubble through it) and not from a control.
              const own = (e.target as Element).closest('dialog') === ref.current
              const control = (e.target as Element).closest('input, select, textarea, [role="slider"]')
              swipeStart.current = own && !control ? e.clientX : null
            }
          : undefined
      }
      onPointerUp={
        variant === 'drawer'
          ? (e) => {
              if (swipeStart.current !== null && e.clientX - swipeStart.current > 80) onClose()
              swipeStart.current = null
            }
          : undefined
      }
    >
      {open && (
        <div className="dkj-dialog-body">
          <div className={cx('dkj-dialog-head', onSave && 'dkj-dialog-head--two')}>
            <div className="dkj-dialog-titles">
              {tag && <TitleTag tone={tone === 'info' ? 'info' : 'accent'}>{tag}</TitleTag>}
              <div className="dkj-dialog-title-row">
                <Title id={titleId} className={cx('dkj-dialog-title', heading === 'card' && 'dkj-dialog-title--card')}>
                  {title}
                </Title>
                {info && <RoundToggle kind="info" expanded={infoOpen} onClick={() => setInfoOpen(true)} />}
              </div>
              {subtitle && <p className="dkj-dialog-sub">{subtitle}</p>}
            </div>
          </div>
          {onSave && (
            <button type="button" className="dkj-dialog-action dkj-dialog-action--cancel" aria-label="Cancel" onClick={onClose}>
              <Icon name="undo" />
            </button>
          )}
          <button
            type="button"
            className={cx('dkj-dialog-action', onSave && 'dkj-dialog-action--save')}
            aria-label={onSave ? 'Save and close' : 'Close'}
            onClick={() => {
              onSave?.()
              onClose()
            }}
          >
            <Icon name={onSave ? 'check' : 'close'} />
          </button>
          <Depth.Provider value={depth + 1}>
            {children}
            {info && (
              <Dialog open={infoOpen} onClose={() => setInfoOpen(false)} title={title} tag="info" heading="plain">
                <p className="dkj-dialog-text">{info}</p>
              </Dialog>
            )}
          </Depth.Provider>
        </div>
      )}
    </dialog>
  )
}

/** DialogActions -- a wrapping row of buttons at the bottom of a dialog, clear of the content above. */
export function DialogActions({ children }: { children: ReactNode }) {
  return <div className="dkj-dialog-actions">{children}</div>
}

/** DialogLabel -- a heading-weight label above an input inside a dialog. */
export function DialogLabel({ children, htmlFor }: { children: ReactNode; htmlFor?: string }) {
  return (
    <label className="dkj-dialog-label" htmlFor={htmlFor}>
      {children}
    </label>
  )
}
