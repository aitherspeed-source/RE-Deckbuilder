# UI System

- Fully procedural for combat and event screens (built in code)
- No scene-based UI for those flows; uses signals for updates (no polling)

## Combat ([Combat_ui.gd](../../deckbuilder-combat/scripts/Combat_ui.gd))
- Full-screen margin layout; enemy block top-center; bottom row: player panel, expanding hand, action buttons
- Player and enemy HP use `ProgressBar` plus numeric labels
- Intent uses `NEXT:` prefix and emphasized styling
- Hand cards: `Button` with `StyleBoxFlat` styles (normal/hover/pressed/disabled/focus); long descriptions truncated safely
- Hand cards resize based on viewport width (`Viewport.size_changed`)
- Shared color/font constants for hierarchy (intent vs headline vs body)
- Spacing constants for margins and separations
- Reward/game-over overlays use container/anchor layouts (no fixed pixel positioning)

## Event room ([EventRoom.gd](../../deckbuilder-combat/scripts/Rooms/EventRoom.gd))
- UI is built under a procedural `CanvasLayer` + full-rect `Control` root for reliable anchoring
- Background + bio-scan overlay are full-rect and ignore mouse input
- Centered main column (`content_vbox`) with width clamped to a viewport percentage
- Flavour vs choices separated by spacer and line
- Choice buttons: autowrap, flat styleboxes, bounded width from viewport
- Outcome text in `PanelContainer` with green-toned border; auto-return to map after a short delay (no manual Continue click required)

## Still optional / not done
- Custom theme `.tres` files (still theme overrides in code)
- Heavy Resident Evil art pass, animations, post-process vignette in combat
- Map / safe room visual passes beyond their current state
