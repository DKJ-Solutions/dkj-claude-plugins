/**
 * The top of the brand book: the page title, a hero card at the house display size (h1) and a type
 * specimen -- every heading level and the running-text styles, set as real elements, so the type scale
 * is seen in use rather than only measured in the Tokens section.
 */
export function Intro() {
  return (
    <header className="dkj-intro" id="intro">
      <p className="dkj-eyebrow">DKJ-Solutions</p>
      <h1>DKJ Brand Book</h1>
      <p className="dkj-lead">
        One brand, several themes. The tokens, the twelve themes and every component the DKJ-Solutions apps share, in one place
        -- pick a theme in the settings and the whole page follows.
      </p>

      <div className="card hero">
        <div>
          <div className="muted">Themes</div>
          <div className="value num">12</div>
        </div>
        <div>
          <div className="muted">Spacing steps</div>
          <div className="value num">40</div>
        </div>
        <div>
          <div className="muted">Brand</div>
          <div className="value num">1</div>
        </div>
      </div>

      <div className="card dkj-specimen">
        <p className="dkj-eyebrow">Type specimen</p>
        <h1>Heading 1 -- the page title</h1>
        <h2>Heading 2 -- a section</h2>
        <h3>Heading 3 -- a block inside a section</h3>
        <h4>Heading 4 -- a part of a block, or an alert or question title</h4>
        <h5>Heading 5 -- a card or dialog title</h5>
        <p className="dkj-specimen-lg">Large text (--text-lg) for a lead or a figure beside the hero value.</p>
        <p>
          Body text (--text-base) is what most of an app is set in, with <a href="#tokens">a link in the theme colour</a>,{' '}
          <strong>a bold word</strong> and <code>inline code</code>.
        </p>
        <p className="sub">A .sub line under a heading (--text-sm, --ink-4).</p>
        <p className="muted">A .muted note (--text-sm; --ink-6, on a paragraph too).</p>
      </div>
    </header>
  )
}
