# Account avatars

The profile images of the GitHub accounts this repo is worked on under. Each file is named after the
account it belongs to, and each one is a plain initials tile in that account's own colour — which is
the whole point: the colour says at a glance **which account a machine is set up as** without anybody
having to read a username.

Nothing in the tree reads these files. They are material, kept here so that any machine can reach them
without hunting through a chat history or a download folder.

## Reaching them from any machine

The marketplace clone of this repo is the **whole repository**, not just the plugin payload, so every
machine that has this marketplace has these files at a fixed path:

```
~/.claude/plugins/marketplaces/dkj-claude-plugins/assets/avatars/<account>.png
```

They arrive with `claude plugin marketplace update dkj-claude-plugins` — **no release and no version
bump**, unlike anything under `plugins/`, which reaches a session only after a cut. That property is
the reason this folder sits at the root and not in a plugin: it is also what keeps these images out of
the plugin cache of every consuming repo, none of which has any use for them.

## Adding one

Drop the PNG in beside the others, named after its account, and add a row to the table below. Binary
handling is already covered — `.gitattributes` carries `*.png binary` for the whole repo.

| File | Tile | Account |
|---|---|---|
| `davekjohn.png` | `DK`, green | `DaveKJohn` |
| `davekokbwj.png` | `DK`, blue | — |
| `maikel-bwj.png` | `MH`, red | — |

A dash means the exact login has not been written down here yet; the file name is the working
identification until it is.
