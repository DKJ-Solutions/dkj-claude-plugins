import { useEffect, useRef, type MouseEvent } from 'react'
import { Icon } from '../../components/Icon'

/**
 * Demos of the house app components (house-style/house-style.css, "App components"), in plain house
 * classes and native elements, so the house layer itself can be judged next to the brand-book versions.
 */

/** A tap on the backdrop is a click on the dialog element itself; the padding sits in .dialog__body. */
function closeOnBackdrop(e: MouseEvent<HTMLDialogElement>) {
  if (e.target === e.currentTarget) e.currentTarget.close()
}

export function HouseFieldDemo() {
  return (
    <>
      <label className="field">
        <span>Label</span>
        <input placeholder="Placeholder" />
      </label>
      <label className="field">
        <span>Label</span>
        <select defaultValue="b">
          <option value="a">Option one</option>
          <option value="b">Option two</option>
          <option value="c">Option three with a long name that truncates</option>
        </select>
      </label>
      <label className="field">
        <span>Label</span>
        <input defaultValue="12,5" aria-invalid="true" />
        <p className="field__error" role="alert">
          Enter a whole number.
        </p>
      </label>
    </>
  )
}

export function HouseButtonsDemo() {
  return (
    <>
      <div className="dkj-demo-row">
        <button type="button" className="btn btn--touch">
          Touch
        </button>
        <button type="button" className="btn btn--touch btn--primary">
          Primary
        </button>
        <button type="button" className="btn btn--touch btn--primary" disabled>
          Disabled
        </button>
      </div>
      <button type="button" className="btn btn--touch btn--primary btn--block">
        Block
      </button>
      <div className="action-row">
        <button type="button" className="icon-btn">
          <Icon name="pencil" />
          <span className="sr-only">Edit</span>
        </button>
        <button type="button" className="icon-btn">
          <Icon name="search" />
          <span className="sr-only">Search</span>
        </button>
        <button type="button" className="icon-btn">
          <Icon name="download" />
          <span className="sr-only">Download</span>
        </button>
      </div>
    </>
  )
}

export function HouseDialogsDemo() {
  const plain = useRef<HTMLDialogElement>(null)
  const edit = useRef<HTMLDialogElement>(null)
  const drawer = useRef<HTMLDialogElement>(null)
  return (
    <>
      <div className="dkj-demo-row">
        <button type="button" className="btn btn--touch" onClick={() => plain.current?.showModal()}>
          .dialog
        </button>
        <button type="button" className="btn btn--touch" onClick={() => edit.current?.showModal()}>
          .dialog (cancel / save)
        </button>
        <button type="button" className="btn btn--touch" onClick={() => drawer.current?.showModal()}>
          .dialog--drawer
        </button>
      </div>

      <dialog ref={plain} className="dialog" aria-labelledby="house-dialog-plain" onClick={closeOnBackdrop}>
        <div className="dialog__body">
          <div className="dialog__head">
            <div>
              <h5 className="dialog__title" id="house-dialog-plain">
                Dialog title
              </h5>
              <p className="dialog__sub">A subtitle in --ink-7</p>
            </div>
          </div>
          <button type="button" className="dialog__close" aria-label="Close" onClick={() => plain.current?.close()}>
            <Icon name="close" />
          </button>
          <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
        </div>
      </dialog>

      <dialog ref={edit} className="dialog" aria-labelledby="house-dialog-edit" onClick={closeOnBackdrop}>
        <div className="dialog__body">
          <div className="dialog__head dialog__head--two">
            <h5 className="dialog__title" id="house-dialog-edit">
              Edit a value
            </h5>
          </div>
          <button type="button" className="dialog__close dialog__close--cancel" aria-label="Cancel" onClick={() => edit.current?.close()}>
            <Icon name="undo" />
          </button>
          <button type="button" className="dialog__close dialog__close--save" aria-label="Save" onClick={() => edit.current?.close()}>
            <Icon name="check" />
          </button>
          <label className="field">
            <span>Label</span>
            <input defaultValue="12" />
          </label>
        </div>
      </dialog>

      <dialog ref={drawer} className="dialog dialog--drawer" aria-labelledby="house-dialog-drawer" onClick={closeOnBackdrop}>
        <div className="dialog__body">
          <div className="dialog__head">
            <h4 className="dialog__title" id="house-dialog-drawer">
              Menu
            </h4>
          </div>
          <button type="button" className="dialog__close" aria-label="Close" onClick={() => drawer.current?.close()}>
            <Icon name="close" />
          </button>
          <HouseMenuItems />
        </div>
      </dialog>
    </>
  )
}

export function HouseTopBarDemo() {
  return (
    <div style={{ border: '1px solid var(--paper-3)', borderRadius: 'var(--dkj-radius-lg)', overflow: 'hidden', background: 'var(--paper-1)' }}>
      <header className="topbar">
        <div className="topbar__inner">
          <div className="topbar__brand">
            <span className="topbar__name">Appname</span>
          </div>
          <button type="button" className="icon-btn icon-btn--ghost">
            <Icon name="menu" />
            <span className="sr-only">Menu</span>
          </button>
        </div>
      </header>
      <div style={{ height: '6rem' }} />
    </div>
  )
}

/** The house settings button inline in a .topbar, with the Dutch default texts. The panel lies over the room below it. */
export function HouseSettingsDemo() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    window.DKJTheme.settings(ref.current)
  }, [])
  return (
    <div style={{ border: '1px solid var(--paper-3)', borderRadius: 'var(--dkj-radius-lg)', background: 'var(--paper-1)' }}>
      <header className="topbar">
        <div className="topbar__inner">
          <div className="topbar__brand">
            <span className="topbar__name">Appname</span>
          </div>
          <div ref={ref} />
        </div>
      </header>
      <div style={{ height: '22rem' }} />
    </div>
  )
}

function Chevron() {
  return (
    <svg className="menu-item__chevron" viewBox="0 0 24 24" width={20} height={20} aria-hidden="true" focusable="false">
      <path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

function HouseMenuItems() {
  return (
    <div>
      <button type="button" className="menu-item">
        <Icon name="person" className="menu-item__icon" />
        <span className="menu-item__label">Profile</span>
        <Chevron />
      </button>
      <button type="button" className="menu-item">
        <Icon name="book" className="menu-item__icon" />
        <span className="menu-item__label">Guide</span>
        <Chevron />
      </button>
    </div>
  )
}

export function HouseMenuDemo() {
  return (
    <>
      <ul className="menu-list">
        <li className="menu-row">
          <span className="menu-row__label">Label</span>
          <span className="menu-row__value">Value A</span>
          <button type="button" className="icon-btn">
            <Icon name="pencil" />
            <span className="sr-only">Edit</span>
          </button>
        </li>
        <li className="menu-row">
          <span className="menu-row__label">Another label</span>
          <span className="menu-row__value">A longer value that wraps when needed</span>
          <button type="button" className="icon-btn">
            <Icon name="pencil" />
            <span className="sr-only">Edit</span>
          </button>
        </li>
      </ul>
      <HouseMenuItems />
    </>
  )
}

/** The house controls with their focus rings and 44px hit areas: tab through them to judge the rings. */
export function HouseFocusDemo() {
  return (
    <>
      <div className="dkj-demo-row">
        <span className="seg" role="group" aria-label="View" style={{ height: '30px' }}>
          <button type="button" aria-pressed="true">
            Primary
          </button>
          <button type="button" aria-pressed="false">
            Secondary
          </button>
        </span>
        <span>
          Label
          <button type="button" className="info-button" aria-label="Explain">
            ?
          </button>
        </span>
      </div>
      <details className="more">
        <summary>More detail</summary>
        <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
      </details>
      <table className="table">
        <thead>
          <tr>
            <th aria-sort="descending">
              <button type="button" className="sort">
                Value
              </button>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>1,234</td>
          </tr>
        </tbody>
      </table>
      <div className="chart">
        <svg viewBox="0 0 120 40" role="img" aria-label="Three bars">
          {[30, 18, 24].map((h, i) => (
            <rect key={i} className="bar" tabIndex={0} x={8 + i * 38} y={40 - h} width={28} height={h} fill="var(--cat-1)" aria-label={`Bar ${i + 1}: ${h}`} />
          ))}
        </svg>
      </div>
      <button type="button" className="moretoggle" aria-expanded="false">
        Read more
      </button>
    </>
  )
}

/** How far a theme reaches: links, native controls, the selection, and the opt-in --accent modifiers. */
export function HouseThemeReachDemo() {
  return (
    <>
      <header className="header--accent">
        <h2>Page header</h2>
        <span className="meta">.header--accent</span>
      </header>
      <p>
        A <a href="#tokens">plain link</a> takes the theme's ink, --ink-1, visited or not. Select this text: the selection does too.
      </p>
      <div className="dkj-demo-row">
        <label>
          <input type="checkbox" defaultChecked /> Checkbox
        </label>
        <label>
          <input type="radio" name="reach" defaultChecked /> Radio
        </label>
        <input type="range" defaultValue={60} aria-label="Slider" />
        <progress value={0.6} aria-label="Progress" />
      </div>
      <div className="grid-2">
        <div className="card card--accent">
          <b>.card--accent</b>
          <p className="muted">No longer draws a rule across the top.</p>
        </div>
        <div className="tile tile--accent">
          <div className="label">.tile--accent</div>
          <div className="v num">1,234</div>
        </div>
      </div>
      <table className="table table--accent">
        <thead>
          <tr>
            <th>.table--accent</th>
            <th>Value</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Row one</td>
            <td>12.5</td>
          </tr>
          <tr>
            <td>Row two</td>
            <td>8.0</td>
          </tr>
        </tbody>
      </table>
    </>
  )
}
