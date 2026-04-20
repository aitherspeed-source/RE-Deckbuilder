# Changelog

All notable changes to **Umbra Containment Outbreak** are documented here.

Format follows “Keep a Changelog” with a lightweight, game-dev friendly scope:
- We track **player-visible changes**, major systems, and workflow-impacting refactors.
- We don’t list every micro-edit.

## [Unreleased]

### Added
- TBD

### Changed
- TBD

### Fixed
- TBD

---

## [2026-04-20]

### Added
- **Boss-first enemy data system**:
  - `EnemyData.gd` resource blueprint
  - `data/enemies/bosses/Containment_Tyrant.tres`
  - Export-safe directory scan for boss resources (`.import` / `.remap` handling).
- **Boss evolution (phase shift)**:
  - Threshold-based evolution hook (`after_damage`)
  - Name change via `enemy_evolved(new_name)`
  - Phase intent pool swap + `Strength +5`
  - Mutation glitch VFX in combat HUD (flash + shake, boss/elite gated).

### Changed
- **Combat UI (procedural, responsive)**:
  - HP bars + numeric readouts for player/enemy
  - Intent line styling and layout hierarchy
  - Hand cards styled with `StyleBoxFlat` chrome and viewport-aware sizing
  - Reward + game-over overlays moved into anchor/container layouts (no fixed screen coordinates).
- **Event room UI**:
  - Rebuilt under procedural `CanvasLayer` + full-rect `Control` root for consistent anchoring
  - Themed background + bio-scan overlay
  - Centered content column with viewport-percentage width clamp
  - Jammed-signal hint insertion targets the procedural VBox (keeps insert-at-index behavior).
- **Boss flow**:
  - Boss nodes now start combat immediately (BossRoom placeholder bypassed / auto-forwarded).

### Fixed
- Responsive stretch settings confirmed in `project.godot` (`canvas_items` + `expand`).
- Map header refactored to `PRESET_TOP_WIDE` container layout (no fixed width bar).

