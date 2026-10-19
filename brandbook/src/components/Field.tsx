import { useId, useState, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react'
import { cx } from './cx'
import { Icon } from './Icon'
import './forms.css'

/** TextField -- a muted label above a full-width input on the page fill. */
export function TextField({ label, className, ...rest }: InputHTMLAttributes<HTMLInputElement> & { label: string }) {
  return (
    <label className={cx('dkj-field', className)}>
      <span className="dkj-field-label">{label}</span>
      <input className="dkj-input" {...rest} />
    </label>
  )
}

/** SelectField -- the same box as TextField, with its own chevron in the muted colour and room to the edge. */
export function SelectField({
  label,
  options,
  className,
  ...rest
}: SelectHTMLAttributes<HTMLSelectElement> & { label: string; options: readonly string[] }) {
  return (
    <label className={cx('dkj-field', className)}>
      <span className="dkj-field-label">{label}</span>
      <select className="dkj-input dkj-select" {...rest}>
        {options.map((o) => (
          <option key={o}>{o}</option>
        ))}
      </select>
    </label>
  )
}

/** FixedField -- a fixed value in the box of a field, without a control: read-only, bold. */
export function FixedField({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="dkj-field">
      <span className="dkj-field-label">{label}</span>
      <p className="dkj-fixed">{children}</p>
    </div>
  )
}

/** Checkbox -- a native checkbox with a 44px tap area, a bold label and an optional muted description. */
export function Checkbox({
  label,
  description,
  ...rest
}: Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> & { label: string; description?: string }) {
  return (
    <label className="dkj-check">
      <input type="checkbox" {...rest} />
      <span>
        {label}
        {description && <small>{description}</small>}
      </span>
    </label>
  )
}

/**
 * Stepper -- minus, a centred number, plus. size="md" is 44px, size="lg" 52px (in a dialog, bold value).
 * A reset button (accent text, no fill) can sit beside it.
 */
export function Stepper({
  value,
  onChange,
  min = 0,
  max = 999,
  size = 'md',
  label,
}: {
  value: number
  onChange: (value: number) => void
  min?: number
  max?: number
  size?: 'md' | 'lg'
  label: string
}) {
  const clamp = (n: number) => Math.min(max, Math.max(min, n))
  return (
    <div className={cx('dkj-stepper', size === 'lg' && 'dkj-stepper--lg')} role="group" aria-label={label}>
      <button type="button" aria-label="Decrease" onClick={() => onChange(clamp(value - 1))} disabled={value <= min}>
        −
      </button>
      <input
        type="number"
        inputMode="numeric"
        aria-label={label}
        value={value}
        min={min}
        max={max}
        onChange={(e) => onChange(clamp(Number(e.target.value) || 0))}
      />
      <button type="button" aria-label="Increase" onClick={() => onChange(clamp(value + 1))} disabled={value >= max}>
        +
      </button>
    </div>
  )
}

/**
 * SearchCombobox -- the chosen value is a button laid over an invisible search input in the same cell; a tap
 * reveals the input and a list opens under it over the full width. The active option is tinted with an accent
 * bar on the left (not colour alone). An "own" option is dashed with a plus, so it never reads as a result.
 * A "more" line is muted and not selectable.
 */
export function SearchCombobox({
  label,
  options,
  value,
  onChange,
  ownLabel,
  moreText,
}: {
  label: string
  options: readonly { value: string; meta?: string }[]
  value: string | null
  onChange: (value: string) => void
  ownLabel?: (query: string) => string
  moreText?: string
}) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const listId = useId()
  const matches = options.filter((o) => o.value.toLowerCase().includes(query.toLowerCase()))
  const ownValue = query.trim()
  const own = ownLabel && ownValue && !options.some((o) => o.value.toLowerCase() === ownValue.toLowerCase())
  // Everything the keyboard can reach: the matches, then the "own" option.
  const choices = own ? [...matches.map((o) => o.value), ownValue] : matches.map((o) => o.value)
  const pick = (v: string) => {
    onChange(v)
    setOpen(false)
    setQuery('')
  }
  return (
    <div className={cx('dkj-combo', !value && 'dkj-combo--empty')}>
      <input
        className={cx('dkj-input', 'dkj-combo-input', value && !open && 'dkj-combo-input--under')}
        role="combobox"
        aria-label={value ? `${label}: ${value}` : label}
        aria-expanded={open}
        aria-controls={listId}
        aria-activedescendant={open && choices[active] !== undefined ? `${listId}-${active}` : undefined}
        placeholder={label}
        value={query}
        onFocus={() => setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 120)}
        onChange={(e) => {
          setQuery(e.target.value)
          setActive(0)
          setOpen(true)
        }}
        onKeyDown={(e) => {
          // Closed, only ArrowDown acts (it opens the list); nothing is picked out of sight.
          if (!open) {
            if (e.key === 'ArrowDown') setOpen(true)
            return
          }
          if (e.key === 'ArrowDown') setActive((a) => Math.min(a + 1, choices.length - 1))
          else if (e.key === 'ArrowUp') setActive((a) => Math.max(a - 1, 0))
          else if (e.key === 'Enter' && choices[active] !== undefined) {
            e.preventDefault()
            pick(choices[active])
          } else if (e.key === 'Escape') setOpen(false)
        }}
      />
      {value && !open && (
        <button
          type="button"
          className="dkj-combo-picked"
          onClick={(e) => {
            setOpen(true)
            ;(e.currentTarget.previousElementSibling as HTMLInputElement | null)?.focus()
          }}
        >
          {value}
        </button>
      )}
      <Icon name="search" size={18} className="dkj-combo-glass" />
      {open && (
        <ul className="dkj-combo-list" id={listId} role="listbox">
          {matches.map((o, i) => (
            <li
              key={o.value}
              id={`${listId}-${i}`}
              role="option"
              aria-selected={i === active}
              className={cx(i === active && 'is-active')}
              onMouseDown={(e) => e.preventDefault()}
              onMouseEnter={() => setActive(i)}
              onClick={() => pick(o.value)}
            >
              <span className="dkj-combo-name">{o.value}</span>
              {o.meta && <span className="dkj-combo-meta">{o.meta}</span>}
            </li>
          ))}
          {own && (
            <li
              id={`${listId}-${matches.length}`}
              role="option"
              aria-selected={active === matches.length}
              className={cx('is-own', active === matches.length && 'is-active')}
              onMouseDown={(e) => e.preventDefault()}
              onMouseEnter={() => setActive(matches.length)}
              onClick={() => pick(ownValue)}
            >
              {ownLabel(ownValue)}
            </li>
          )}
          {moreText && <li role="presentation" className="is-more">{moreText}</li>}
        </ul>
      )}
    </div>
  )
}
