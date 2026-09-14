# The preview handover -- the portable rule

**This page applies in exactly two repos, named by store rather than by org: `smartwatchbanden` and
`xoxowildhearts`** -- see [`WORKFLOW-portable.md`](WORKFLOW-portable.md) for why the org is left out.
**Unlike chapter one, this reach did NOT widen when `dkj-claude-plugins` was admitted on
September 14, 2026** -- a preview handover exists to compare a theme against its own live control, and
the source repo runs no theme and no store, so there is nothing here for it to hand over. That page's
opening explains the widening; this one stays exactly the pair it always was. It is chapter three of
this plugin, beside [`WORKFLOW-portable.md`](WORKFLOW-portable.md) and
[`SYNC-LOG-portable.md`](SYNC-LOG-portable.md), and it answers two questions neither of those does:
**what a preview handover owes, and how it reaches the reviewer.**

It is a layer on top of `dkj-policy` in the same way the other two chapters are. It changes nothing
about **which** changes need a preview before they may open a PR -- that reach is the consumer's own
rule and `dkj-policy`'s, unchanged. It states only what the handover itself contains once one is owed,
and what carries it.

**The two halves arrived on the same day, from the same handover, as two separate reports** -- inbound
[#1874](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1874) for the content and
[#1873](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1873) for the carrier -- and each was
built as its own chapter three before either saw the other. They are one chapter, because they are one
question: a control variant nobody can open is not a control variant, and a carrier with nothing to
compare against carries half a handover.

**How to read this page.** It travels with the plugin, so a link that walks out of this plugin's own
folder is written as an absolute URL. Measurements and issue numbers are the **source repo's**; they
are the evidence behind a rule, never your repo's own record.

## Why this is policy and not mechanism

`dkj-subagents-shopify` ships the **mechanism** -- `push-preview.ps1`, the theme it creates, the
live-theme guard. That is generic: any repo serving a Shopify theme needs a preview theme, and every
one of them gets the machinery through a plugin update whether or not it ever reads this page.

This page is the **policy** -- *what the person receiving a preview is handed*. That is BWJ's house
rule for two repos, not a Shopify fact.

**One piece of mechanism does sit in this plugin, and it is here because it is BWJ-shaped too.**
[`scripts/lib/market-urls.ps1`](scripts/lib/market-urls.ps1) builds the URLs a handover is made of, and
`Get-MarketHandoverPairs` returns exactly the pair the rule below asks for -- the preview and its live
control, per market and per page -- so the page you publish has an input rather than a recollection.
Which markets a store has stays that store's own `Get-StorefrontMarkets` seam answer; the builder is
shared because both stores had written one and only the exported function names ever matched
([#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886)). Its terminal output says in
as many words that it is the **material** and not the handover, and points back here.

## The rule, in two halves

**One: a preview handover is a PAIR per market -- the preview, and the control.** The control variant
is the same page on the **live** theme -- what the visitor sees right now -- so the difference is one
tab-switch rather than a recollection.

**Two: the handover is ONE LINK to a published page, and the terminal never gets the URLs.** Not a
markdown table, not a bulleted list, not "here are the five markets" followed by ten lines. One link,
and the page behind it is the handover.

The second half is what makes the first half reachable, which is why they are one rule and not two.

**A preview alone shows what a page will look like. It never shows what changed.** Only the reader
knows the current state, from memory, while looking at something else -- and that is precisely the
judgement the preview exists to make possible. A handover that skips the control has moved the hard
half of the work onto the person it was handed to.

Dave, September 11, 2026, after a five-market preview handover that was complete by the letter of the
rule then in force:

> wat ik ook wel fijn vind in het vervolg is een preview naar de control variant. dus hoe het live nu
> staat om het verschil meteen te zien.

The change under review was one colour on a product-page notice. Described in prose it was *"a
lighter, more yellow amber"*; held against the live tab it is obvious in a second. Prose is not a
control variant.

### Why the carrier is a page and not a table

**Pairing the URLs doubles them, which is exactly what a terminal cannot take.** Five markets by two
variants is ten URLs of 70 to 100 characters each -- a full domain, a theme id, and the three admin
parameters. Three things are wrong with laying those out in a table, and only the first is cosmetic
([#1873](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1873), September 11, 2026, measured
on exactly that handover):

1. **The terminal cannot render it.** Ten URLs that long in two columns wrap, and the column structure
   that was carrying *which market, preview or control* wraps with them. The layout that was the whole
   point of the table is the first thing it loses -- and in the same session the reply was also
   *"het selecteren is ook onmogelijk"*: a wrapped URL cannot even be copied out by hand.
2. **The reader is on the wrong device.** Storefront work is judged on a phone, and some of it exists
   *only* there -- one change that produced this rule lived inside a lazily-fetched mobile menu drawer
   and was invisible on a desktop at any width. A URL in a desktop terminal is something the reviewer
   has to retype on a phone, twice per market, query string included.
3. **The handover carries no state.** What the gates already proved, what is still open, and what the
   reviewer is actually being asked all sit in prose above and below the table -- so none of it travels
   with the link when they come back to it an hour later.

Dave, the same day, on the table:

> we moeten even stoppen met het tonen van preview urls in tabellen, want in de terminal werkt dit
> gewoon niet. [...] Ik denk dat een link naar een artefact pagina het beste werkt

**It costs the producing side nothing.** The session has already resolved the changed page per market
in order to build the preview list at all; the control URL is that same URL with one parameter
changed.

## What the control URL is -- and the trap in the obvious answer

**The control URL names the LIVE theme's id explicitly:**

```
https://<market domain>/<the changed page>?preview_theme_id=<live theme id>
```

**It is NOT the URL with the parameter left off**, and this is the part that has to be written down,
because the obvious answer is wrong in a way that fails silently.

`preview_theme_id` sets a **cookie** on that domain. Once a market's preview URL has been opened, every
later request to that domain keeps rendering the preview theme -- including the bare URL that was meant
to be the control. The control tab then shows the preview, both tabs agree, and the reviewer concludes
the change is not visible.

Measured in `smartwatchbanden` on September 11, 2026, against one product page on `smartwatchbanden.nl`,
reading `Shopify.theme` out of the rendered markup:

| what was requested, in one session, in order | what actually rendered |
|---|---|
| the preview URL, with the branch theme's id | the branch theme (`role: unpublished`) -- correct |
| **the same URL with no parameter at all** | **still the branch theme** -- the cookie survives |
| `?preview_theme_id=0` | no page at all: *"Theme cannot be previewed because it's missing one of these required files: layout/theme.liquid, config/settings_schema.json"* |
| `?preview_theme_id=<live id>` | the live theme (`role: main`) -- correct, and the session is back on live afterwards |

Three consequences, in descending order of how easily they are missed:

- **Pin the control to the live id.** It is the only form measured to be correct regardless of what the
  browser did before it, and it needs no clean browser profile, no incognito window and no instruction
  to the reader.
- **`preview_theme_id=0` is not a reset.** It renders the error above, which reads like a broken
  preview theme and sends the reader hunting for a fault that does not exist. It is worth naming
  because it is the first thing anyone tries, and because that same message is what a reader reports
  when they hit it.
- **The live id is already answered by the repo.** `Get-ShopifyLiveThemeId` in
  `scripts/repo-config.ps1` -- the seam `dkj-subagents-shopify`'s live-theme guard reads -- states it
  once. Read it from there rather than pasting a number into a handover, and a store that republishes
  under a new theme id keeps one place to correct.

## The shape of the handover

Three blocks on the page, and each is there because the other two cannot supply it:

| block | what it holds |
|---|---|
| **how to see the change** | the page under review named once -- with the tag or condition the change depends on -- and the steps a reviewer has to take before the change is even visible: which device, which viewport, which menu to open. No URL can say this, and a change that is invisible without it reads as *not shipped* |
| **one card per market** | the market code and its domain, a **QR code to the preview**, the preview and control links as text beneath it, and the expected copy in that market's language where the change has copy in it |
| **what is proven, and what is asked** | which gates ran and what they verified mechanically, then the one question the reviewer is being asked. This is the half that makes the link a self-contained handover rather than a bookmark needing the transcript beside it |

Two things the cards inherit from the consumer's own preview rule rather than restating:

- **Per market**, because these stores serve several and a change can land differently in each.
- **Of the concretely changed page** -- a set of homepages is already refused there, and a control that
  is not the changed page controls nothing.

### Why a QR code, and one per market

**Because a QR is what makes the phone the reviewing device rather than a second one.** The reviewer
scans instead of retyping a 90-character URL with a query string, which is the difference between
reviewing the change and not reviewing it.

**One per market, because the preview is per domain.** A scan puts the preview on the domain it opens,
and that is the domain the code encoded -- a market's card cannot borrow the scan from the card above
it. Five markets is five codes.

**The code encodes the PREVIEW, and the control stays a text link.** Both belong on the card, but only
one of them can be the thing a phone lands on: scanning the control would set the live theme on that
domain as the reviewer's starting point, which is the opposite of what they came for. And the code has
to carry `_ab=0&_fd=0&_sc=1`, exactly as `push-preview`'s own page requires of every URL that seam
produces -- without them the preview holds only through the cookie and is lost at the first internal
click, and the reviewer is then on live believing they are on the preview. That matters more on a QR
than anywhere else, because the scan is their only entry point.

### The one mechanism note, and why a policy page carries it

**A QR served as an image from a QR-image API does not render, and says nothing when it fails.** A
published Artifact runs under a content-security policy that permits external **scripts** from a short
list of CDNs and blocks everything else -- images included, from every host. So an
`<img src="https://some-qr-api/...">` is silently empty, and a page of five markets is a page of five
blank squares with no error anywhere. The two shapes that do work: render the code **client-side** from
a QR library loaded as a script from an allowlisted CDN, or embed it as a `data:` URI in the page.

This is mechanism on a policy page, deliberately and once. A rule that prescribes a carrier and omits
the single constraint that makes the carrier fail *silently* is not a rule anybody can follow, and this
is the worst kind to leave out: the page looks published, and the reviewer is the one who finds out.

### And the link is as sensitive as the URLs it encodes

**The CSP is not the reason to keep the QR local, it is only the reason the remote one does not
render.** A preview URL carries `preview_theme_id` plus the three admin parameters, which is exactly
what lets a viewer see an unpublished theme -- so a QR generator that round-trips that URL to a
third-party service hands the store's unreleased work to somebody who was never asked. Rule it out on
its own terms: **the preview URL never leaves the page**, whatever the CSP happens to permit that
month.

**And the page inherits that.** The whole point of the handover is that the link is easy to open, which
means it is also easy to forward -- and one link now reaches every market's preview at once, where the
terminal printout reached whoever was looking at the terminal. The page is private until its link is
shared, so treat the link the way you would treat the URLs on it: to the reviewer, and not onward.

This paragraph exists because the section above it reads as complete without it. *"Render it
client-side"* is a full answer to a rendering problem, and a later editor taking the CSP as the whole
reason picks whichever library renders -- including one that phones home.

## Where the rule is carried

A policy page that nothing loads at the moment a preview is pushed loses to the printed list every
time, because that list is what a session has in front of it. So the carrier half is carried at the
print site too, in the generic plugin and in generic terms:

- `push-preview` prints a closing note whenever it emits **more than one** URL, saying the list is raw
  material rather than the handover and pointing at whatever handover rule the repo's workflow states.
  One URL is left alone -- a single line in a terminal genuinely is a usable handover, and the count is
  the honest trigger.
- [`push-preview`'s own page](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-shopify/skills/push-preview/SKILL.md)
  carries the same thing in prose, under its own heading.

**Neither of those names BWJ or this page**, and that is the mechanism/policy split holding rather than
an omission: the generic plugin states that a list of URLs is not a handover, which is true of any
multi-market Shopify repo, and *this* page states what BWJ's handover actually is.

## What this page does not decide

- **Which changes owe a preview at all.** That reach test lives in the consumer's `CLAUDE.md` and in
  `dkj-policy`, and this page neither widens nor narrows it.
- **When the PR may open.** Also the consumer's rule, unchanged: where a preview is owed, its approval
  is what the PR waits on.
- **Anything about pushing to live.** A control URL previews the published theme read-only. It is not a
  live action, it writes nothing, and it goes nowhere near the live-push procedure or its guard.
