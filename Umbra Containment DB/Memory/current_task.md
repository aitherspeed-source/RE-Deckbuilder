# Current focus

## Implemented (current state)

### Combat UI ([Combat_ui.gd](deckbuilder-combat/scripts/Combat_ui.gd))
- HP bars + numeric labels (player and enemy), shared `_make_hp_bar` helper
- Intent line as `NEXT: …` with emphasis and spacing
- Layout: enemy top, player bottom-left, hand bottom-center, End Turn / Map bottom-right; screen margins and spacing constants
- Hand cards: `StyleBoxFlat` chrome, typography hierarchy (shared color/font constants), truncated long descriptions, viewport-aware sizing on resize
- Background + contrast pass for labels and actions
- Reward + game-over overlays now use anchored/container layouts (no fixed screen positions)

### Event room UI ([EventRoom.gd](deckbuilder-combat/scripts/Rooms/EventRoom.gd))
- Procedural UI built under `CanvasLayer` + full-rect `Control` root (anchors behave consistently)
- Themed background + bio-scan overlay; centered content column with width clamped to viewport
- Choice buttons: autowrap + themed `StyleBoxFlat`, result text in bordered panel
- After a choice, the outcome displays and the room auto-returns to map after ~3 seconds (no manual Continue click required)

### Boss + Enemy data (boss-first)
- Boss nodes now load combat immediately (BossRoom placeholder click is bypassed)
- Boss enemy is loaded from `EnemyData` `.tres` resources under `data/enemies/bosses/` (export-safe directory scan)
- Boss evolution supported: name change + intent pool swap + Strength buff + mutation VFX

---

## Next (planned / to come)
- More `EnemyData` resources for elites and standard enemies
- More bosses + richer phase logic (beyond current pool swap + Strength)
- Combat feedback polish (non-damage UI flashes, additional Umbra terminal styling)
- Relics system and expanded card pool
- Save/resume run persistence

## Working constraints
- Procedural UI where applicable; signal-driven combat UI (no polling)
- Dark biohazard / Umbrella tone
