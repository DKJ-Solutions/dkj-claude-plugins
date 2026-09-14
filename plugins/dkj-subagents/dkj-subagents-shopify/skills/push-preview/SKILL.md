---
name: push-preview
description: Push the current branch to its own unpublished Shopify preview theme, creating that theme on the first push rather than at branch creation. Use it whenever a theme change has to be looked at -- it prints the preview URL(s), which are raw material for a handover rather than the handover itself. It never publishes, never deletes, and refuses the live theme; the theme it creates is unpublished by definition. Lazy creation is the point: a branch that never needed a preview never leaves one behind on a store whose theme ceiling is finite.
---

# push-preview -- the branch's own preview theme, created when it is first needed

A Shopify change is judged by eye, so it needs a URL somebody can open. This pushes the current branch to
an **unpublished** theme of its own and prints that URL.

**The theme is created on the first push, not when the branch was made.** That is the whole design, and it
is measured rather than tidy: creating one per branch left previews for branches that could never touch a
theme file. On the day the rule was made, one store carried 49 themes, 47 of them unpublished, 16 named
after a branch -- and of the 12 real branch previews, **6 belonged to branches that never needed one**. A
Shopify store's theme ceiling is finite, so that estate does not merely look untidy; it eventually
refuses the next push.

> A preview theme is a consequence of *"I want to show this"*, not of *"I am starting work"*.

**Why not a flag on branch creation:** a flag has to be remembered, and the mistake this replaces was
somebody reaching for the familiar route while the documentation already named the right one. Lazy creation
cannot be forgotten -- there is no moment at which anybody has to get it right.

## Run it

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/push-preview.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude runs
this skill. Typing the command by hand in a terminal means spelling out the absolute path to your own
plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

Run it **without** a stderr redirect: the Shopify CLI writes its progress to stderr, and redirecting it
turns ordinary progress into an error under PowerShell's `Stop` preference.

## What it does, in order

1. **Refuses on the trunk.** A preview theme belongs to a branch. The trunk's name comes from
   `Get-TrunkBranchName` where the repo answers it, `main` otherwise.
2. **Decides which theme to push to**, in four steps and in this order:
   1. an explicit `-ThemeId`;
   2. the id remembered in the branch's own git config (`branch.<name>.previewTheme`), written by an
      earlier run -- per branch, so nothing has to be committed or cleaned up;
   3. a name lookup through `shopify theme list --json`, by the branch name with its slashes flattened to
      dashes (Shopify rejects a theme name containing `/`);
   4. **otherwise it creates the theme** -- `--unpublished` creates it and pushes the working tree in the
      same call, so no second push follows.
3. **Refuses the live theme** where step 2 landed on it. That is the second of two independent refusals:
   `dkj-subagents-shopify`'s `PreToolUse` guard blocks a live-aimed push whatever shell wraps the command, whether
   or not this script recognised the target.
4. **Remembers a newly created id** in the branch's git config, so the next push goes straight to step 2.2.
5. **Prints the preview URL(s)** to hand over -- plus, from two of them upwards, a note that a list is raw material rather than the handover (see below).

## Parameters

| parameter | what it does |
|---|---|
| `-ThemeId` | force a specific preview theme id instead of the remembered or looked-up one. Needed when two themes carry the same name -- the lookup refuses to guess between them rather than pushing to the wrong one, which is invisible until somebody opens the preview. |
| `-Store` | store domain to push to, overriding `Get-ShopifyStoreDomain`. For a repo whose seam is not answered yet, or a one-off against a second store. |
| `-Path` | the storefront path to print preview URLs for, e.g. `/products/some-handle`. Default is the home page -- **a home-page link alone is not enough when the change sits on a product page**, which is the one parameter worth reaching for by habit. |

## The seam answers it reads

Every one is fetched through `Get-Command`, so this script depends on **no workflow plugin** and a repo
running none at all gets identical behaviour.

| function | required? | what its absence costs |
|---|---|---|
| `Get-ShopifyStoreDomain` | **required** | it refuses rather than guessing which store to push to. `-Store` gets you through one run; answering the seam is the durable fix. |
| `Get-ShopifyLiveThemeId` | recommended | this script can then no longer recognise the live theme **by id**, so one of the two refusals is gone. It warns and continues rather than blocking, because a preview push is aimed at an unpublished theme and the guard hook still stands -- unlike `sync-main`, which reads *from* live and therefore cannot work at all without it. |
| `Get-TrunkBranchName` | optional | the trunk check falls back to `main`. |
| `Get-BranchInfo` | optional | the theme name falls back to the branch with its slashes replaced by dashes -- which is what `SafeName` answers anyway, so a repo without the seam loses nothing. |
| `Get-ShopifyPreviewUrls` | optional | you get **one** preview URL, on the store's own domain. Answer it in a multi-market store to get one per market or locale. |

### `Get-ShopifyPreviewUrls` -- the one genuinely per-store half

Everything else about pushing to a preview theme is the same in every Shopify repo. The market table is
not, and that is why it is a seam rather than shipped: one consumer runs **one** domain with
locale-prefixed paths (`/`, `/en`, `/de`, `/nl-gb`, ...), another runs **five separate domains**. A shared
table would have produced four domains that do not exist.

```powershell
function Get-ShopifyPreviewUrls {
    param([string]$ThemeId, [string]$Path = '/')
    # One line per market or locale. Whatever this returns is printed as-is.
    return @(
        "https://www.example.com$Path`?preview_theme_id=$ThemeId&_ab=0&_fd=0&_sc=1",
        "https://www.example.de$Path`?preview_theme_id=$ThemeId&_ab=0&_fd=0&_sc=1"
    )
}
```

**Keep `_ab=0&_fd=0&_sc=1` on every URL you build.** Those are the three parameters the Shopify admin
itself hangs on a preview link, and without them the preview holds only through the cookie and is lost at
the first internal click -- at which point you are looking at **live** while believing you are looking at
the preview. A consumer lost a whole review to that. The built-in single URL carries them already; a seam
answer has to carry them itself.

## Handing it over -- the printed list is raw material, not the handover

**Where this prints more than one URL, it also prints a note saying so**, because what happens next is
where the failure actually lives (inbound
[#1873](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1873), September 11, 2026). A
multi-market store's list is five to ten URLs of 70 to 100 characters each -- a full domain, the theme
id, and the three admin parameters -- and the reflex is to lay them out in a markdown table by market
and page type. Measured on a handover of ten:

- **The terminal wraps them**, and the column structure that was carrying *which market, which page* is
  the first thing lost. The table's whole purpose goes before anything else does.
- **The reviewer is on a phone**, because that is where storefront work is judged and sometimes the only
  place the change exists at all. A URL in a desktop terminal is something they have to retype, once per
  market, query string included.
- **None of the surrounding state travels with it** -- what the gates proved, what is still open, what
  is actually being asked sits in prose above and below the table and is gone an hour later.

**What replaces it is your repo's to state, not this script's.** Where the workflow you run ships a
handover rule, follow it; `dkj-policy-bwj` states one for BWJ's two store repos --
[`PREVIEW-portable.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/dkj-policy-bwj/PREVIEW-portable.md),
one link to a published page carrying a QR code per market. Where your workflow says nothing, the
generic part still holds: hand over one link to something that renders, not a list.

**One URL prints no note**, deliberately. A single line in a terminal genuinely is a usable handover,
and the count is the honest trigger rather than a threshold chosen to keep the output quiet.

## Boundaries

- **Preview only.** The theme is unpublished, and nothing here publishes, deletes, or pushes to live.
- **A refusal is an answer.** Where the script refuses a name, an id, or a flag, resolve what it names --
  do not try another spelling to get past it. The flag whitelist exists because an invented flag
  (`--theme-name`, which the CLI has never had) reached a real run and failed in front of the person who
  needed it most.
- **The estate is finite.** A `A shop may only have N themes` error means archive and remove a spent
  preview first; this script will not clear space on its own.
