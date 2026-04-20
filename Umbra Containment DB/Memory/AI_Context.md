# Umbra Containment Outbreak — AI Context

## Overview
Roguelike deckbuilder built in Godot 4.6.2 inspired by Slay the Spire with a Resident Evil–style biohazard theme.

Core mechanic:
Infection damages the player each turn but also unlocks stronger abilities, rewards, and progression.

## Current State
- Map system complete (procedural, 7 rows)
- Combat system functional
- Safe room implemented
- Event room implemented (pool of random events, procedural UI)
- Card system working using .tres resources
- Effect system fully modular (node/class based)
- Combat and event UI are procedural (code-based, no scene UI for those screens)
- Boss-first enemy data system implemented (`EnemyData` resources for bosses + evolution hook)

## Core Systems

### Combat
- Turn-based (player → enemy)
- Ammo resource system
- Draw 5 cards per turn
- Deck reshuffles automatically
- Enemy Intent system

### Cards
- Data-driven via .tres files
- No hardcoding required
- Starter deck implemented

### Effects
- Modular effect system (each effect is a class)
- Includes:
  - Infection (damage over time, permanent)
  - Block (resets each turn)
  - Bleed (decays)
  - Weak (reduces damage)
  - Strength (permanent boost)

### Map
- Procedural branching paths
- Multiple room types (combat, elite, safe room, event, etc.)

### UI
- Combat HUD: responsive layout, HP bars, intent line, hand card chrome, typography/spacing constants, container-based overlays
- Event room: CanvasLayer + full-rect root, themed background/bio-scan overlay, centered content width clamp, outcome panel, auto-return after choice
- Further polish optional (animation, heavy theming, feedback VFX)

## Design Philosophy
- Infection is both risk and power
- Systems should be modular and expandable
- Player should always have clear information (intent system)
- Game should scale in complexity over time

## Current Focus Direction
- Boss content and fights (more bosses + more varied phase patterns)
- Optional deeper visual polish (animations, screen effects, card art)
- Longer-term: relics, more cards/enemies, save system (see README)
