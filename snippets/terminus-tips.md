# Terminus Phone Tips

## First-time Terminus setup
- **Font**: JetBrains Mono or Fira Code (supports box-drawing chars in the menu)
- **Font size**: 13–15pt — small enough to see status bar, large enough to tap
- **Color scheme**: Tokyo Night or Dracula (matches the tmux palette)
- **Keyboard toolbar**: enable the extended row; add `Ctrl`, `Alt`, `Esc`, `Tab`

## Key sequences in Terminus
| Action              | Tap sequence                  |
|---------------------|-------------------------------|
| tmux prefix         | `Ctrl` then `a`               |
| Switch → main       | Prefix → `m`                  |
| Switch → code       | Prefix → `e`                  |
| Switch → dev        | Prefix → `d`                  |
| Switch → other      | Prefix → `o`                  |
| Visual chooser      | Prefix → `s`                  |
| Split horizontal    | Prefix → `\|`                 |
| Split vertical      | Prefix → `-`                  |
| Pane navigate       | `Alt` + arrow (no prefix)     |
| Scroll mode         | Prefix → `v` then arrow/PgUp |
| Copy selection      | Prefix → `v`, select, then `y`|
| Detach              | Prefix → `d`                  |

## Status bar (top of screen)
```
 main │  1:menu           e:code d:dev o:other  14:32
 ↑              ↑                ↑                ↑
 prefix indicator  windows    session shortcuts   time
```

## Session menu (in 'main' session)
- Tap a number (1–3) to jump to that session
- `r` refreshes status without switching
- `s` starts any stopped sessions
- `q` exits the menu loop (stays in main)
- Menu auto-refreshes every 30 s to update status badges

## Returning to the menu
From any session: `Prefix + m` switches you back to main.
The session-menu loop restarts automatically if you exit and re-enter main.
