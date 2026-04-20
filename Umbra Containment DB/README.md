🧫 Umbra Containment Outbreak — A Biohazard Deckbuilder

Built in Godot 4.6.2 · GDScript · Work in Progress
Inspired by Slay the Spire · Thematically driven by corporate bio-weapons horror

🎮 About

Umbra Containment Outbreak is a roguelike deckbuilding game where you descend through a live biohazard facility during an active outbreak.

You are not just surviving.

You are being observed. Evaluated. Experimented on.

The entire game revolves around one core system:

🧬 Infection is both your greatest weapon — and your inevitable downfall.

Infection damages you every turn
But it also unlocks stronger cards, rooms, and mutations
The deeper you go, the more Umbra Corporation pushes you to evolve
🧬 Core Theme

Umbra Corporation is a pharmaceutical giant specializing in:

Viral experimentation
Bio-Organic Weapons (B.O.W.s)
Human mutation trials

This outbreak is not a failure.

It is a test environment — and you are inside it.
---

## ✅ What's Built So Far

### 🗺️ Map System
- 7-row procedurally generated branching map
- Each run generates a unique path
- Room types with weighted random distribution per row
- Clickable nodes — available rooms highlighted in yellow
- Player stats shown in header (HP, Infection, Deck size, Floor)
- Path lines connecting rooms, brightening when accessible

### 🚪 Room Types
| Icon | Room | Description |
|------|------|-------------|
| 🚪 | Hallway | Standard combat encounter |
| ⭐ | Elite | Tougher enemy, better rewards |
| ☣️ | Infection Zone | Gain 2 Infection on entry, better rewards |
| 🏥 | Safe Room | Heal, remove, or upgrade a card |
| ❓ | Event | Random choices with consequences (8 events, procedural UI) |
| 💀 | Boss | Final encounter of the run |

### 👾 Enemy Data (Boss-first)
- Boss enemies are now data-driven via `.tres` resources:
  - `deckbuilder-combat/scripts/EnemyData.gd`
  - `deckbuilder-combat/data/enemies/bosses/*.tres`
- Boss selection loads a random boss resource and applies it to the enemy at combat start.
- Boss evolution is supported (phase shift at threshold): name change + intent pool swap + `Strength +5`.

### ⚔️ Combat System
- Turn-based combat — Player then Enemy
- **Ammo system** — resource spent to play cards (refills each turn)
- **Hand management** — draw 5 cards per turn, discard at end
- **Deck cycling** — automatic reshuffle from discard pile when deck runs out
- Max hand size cap with overflow protection
- Enemy **Intent system** — telegraphs next move before acting (like Slay the Spire)
- Enemy scales per room type (Elite = buffed stats, Boss = massive HP)
- Signal-based UI — stats update instantly when anything changes

### 🃏 Card System
- Cards defined as `.tres` Resource files (no hardcoded data)
- Add new cards with zero code changes — just create a `.tres` file
- 10 starter cards across 3 types:

| Type | Cards |
|------|-------|
| ⚔️ Attack | Pistol Shot, Double Tap, Hollow Point, Burst Fire |
| 🛠️ Skill | Take Cover, Adrenaline, Biohazard Round, Field Dressing |
| 🔱 Power | Infected Rage, Fortify |

- Starter deck: 10 cards (3× Pistol Shot, 2× Take Cover, 2× Hollow Point, 1× Adrenaline, 1× Field Dressing)
- Cards carry between rooms via `GameManager`

### 🧪 Effect System
Full node-based status effect system — every effect is its own class:

| Effect | Behaviour |
|--------|-----------|
| 🧫 Infection | Deals damage equal to stacks at end of turn. Never fades naturally |
| 🛡️ Block | Absorbs incoming damage. Resets at start of turn |
| 🩸 Bleed | Deals damage then fades by 1 stack each turn |
| 🔱 Weak | Reduces all damage dealt by 25%. Fades each turn |
| 💪 Strength | Adds flat bonus damage to all attacks. Permanent |

- `EffectManager` node attached to Player and Enemy
- Handles stacking, ticking, expiry, and cleanup automatically
- Damage routes through Block before hitting HP
- Outgoing damage modified by Strength and Weak before being sent
- Signals emitted on every stat change — UI reacts automatically

### 🏥 Safe Room
Three mutually exclusive options:
- **Rest & Heal** — restore 20 HP
- **Remove Card** — pick a card from your deck to delete (requires 6+ cards)
- **Upgrade Card** — pick a card to permanently improve (adds `+` to name, improves stats/cost)

### 💾 Run Persistence
- `GameManager` autoload tracks all run state between scenes
- HP, Infection, deck, floor, and map progress all persist
- Stats sync into Combat scene on entry and save back on exit
- Card rewards after combat add directly to the persistent deck

### 🎨 UI
- Dark themed procedural UI built entirely in code (no scene-based UI nodes)
- **Combat** — responsive layout (enemy top / player bottom-left / hand center / actions bottom-right), shared typography and spacing constants, HP bars with numeric readouts, intent line as `NEXT: …`, hand cards with bordered chrome and truncated descriptions when needed
- Enemy panel — name, HP bar, Block, Intent
- Player panel — HP bar, Block, Ammo, Infection
- Card hand — styled buttons, greyed out when unaffordable
- End Turn and Map buttons
- Victory screen with **Card Reward** — pick 1 of 3 random cards or skip
- Game Over screen with New Run button
- **Event room** — procedural CanvasLayer UI, separator between flavour and choices, wrapped choice buttons, outcome in a bordered panel, auto-return to map after a short delay

---

## 🏗️ Project Structure

```
DeckbuilderCombat/
├── data/
│   └── cards/              # .tres card resource files (10 cards)
│   └── enemies/             # .tres enemy resource files (bosses first)
├── scenes/
│   ├── Combat.tscn         # Main combat scene
│   ├── Map.tscn            # Map navigation scene
│   ├── SafeRoom.tscn       # Safe room scene
│   └── rooms/              # EventRoom.tscn, etc.
├── scripts/
│   ├── CardData.gd         # Card resource blueprint
│   ├── CardLibrary.gd      # Loads .tres cards, executes effects (Autoload)
│   ├── EnemyData.gd        # Enemy resource blueprint (.tres-driven)
│   ├── CombatManager.gd    # Turn system, win/loss logic
│   ├── Combat_ui.gd        # Combat UI + card reward screen
│   ├── GameManager.gd      # Persistent run state (Autoload)
│   ├── Player.gd           # Player stats, deck, signals
│   ├── enemy.gd            # Enemy stats, intent system, signals
│   ├── StatusEffects.gd    # Legacy status helpers (Autoload)
│   ├── Effects/            # Effect system
│   │   ├── Effect.gd           # Base class
│   │   ├── EffectManager.gd    # Manages active effects per entity
│   │   ├── InfectionEffect.gd
│   │   ├── BlockEffect.gd
│   │   ├── BleedEffect.gd
│   │   ├── WeakEffect.gd
│   │   └── StrengthEffect.gd
│   ├── Map/                # Map system
│   │   ├── MapNode.gd          # Room data resource
│   │   ├── MapGenerator.gd     # Procedural map builder (Autoload)
│   │   ├── Map.gd              # Map scene controller
│   │   └── MapUI.gd            # Map UI control
│   └── Rooms/              # Room scripts
│       ├── SafeRoom.gd
│       ├── SafeRoomUI.gd
│       └── EventRoom.gd
```

---

## 🚀 Near-Future Plans

### 💀 Boss Room
- More bosses as `EnemyData` resources (beyond the current Containment Tyrant → MR.X phase shift)
- More phase behaviors (beyond pool swap + Strength)
- Boss-specific rewards (relics) and post-boss victory flow polish

### 🔄 Restart & New Run Flow
- Full new run button from Game Over screen
- Map regenerates fresh on each new run
- Starting deck resets cleanly

---

## 🔭 Future Features (Longer Term)

### 🏺 Relic System
- Passive items collected during the run
- Modify how effects work globally
- Examples:
  - *Biohazard Flask* — Infection also deals damage to enemy each turn
  - *Steel Plating* — Block no longer resets each turn
  - *Adrenaline Syringe* — Start each combat with 1 extra Ammo
  - *Infected Core* — Every 3 Infection stacks = +1 card draw

### 🃏 Expanded Card Library
- 30+ cards total across all types
- Card synergy groups (Infection-focused, Block-focused, Ammo-generating)
- Rare cards available only as Elite/Boss rewards

### 👾 Multiple Enemy Types
- Each enemy type has a unique move set and intent pool
- Examples: Carrier (heavy Infect), Brute (pure damage), Guardian (blocks heavily)
- Boss-tier enemies with phase transitions

### 🗺️ Extended Map
- Shop room — spend Gold to buy cards or remove cards
- Treasure room — guaranteed relic
- Mystery room — unknown until entered
- Mini-boss rooms at row 4

### 🎨 Visual Polish
- Card art placeholder sprites
- Animated path reveal on map
- Screen shake on heavy hits
- Infection visual effect building on screen edge
- Extra combat feedback (damage flashes, stronger Umbrella theming) beyond current layout pass

### 💾 Save System
- Save run state to disk between sessions
- Resume interrupted runs

---

## 🛠️ Technical Notes

- **Godot version:** 4.6.2 stable
- **Renderer:** Compatibility (runs on all hardware)
- **Language:** GDScript only
- **UI approach:** Procedural (built in code, no scene-based UI)
- **Card data:** `.tres` Resource files — zero code needed to add new cards
- **Effect system:** Class-based, each effect is an independent `RefCounted` object
- **Signal architecture:** Player and Enemy emit signals on every stat change — UI never polls

### Autoloads
| Name | Purpose |
|------|---------|
| `CardLibrary` | Loads all card `.tres` files, executes card effects |
| `StatusEffects` | Legacy status helpers |
| `GameManager` | Persistent run state across scenes |
| `MapGenerator` | Procedural map generation |

---

## 🎯 Design Goals

- **Every run feels different** — procedural map, random events, random rewards
- **Infection is a mechanic, not just a debuff** — it interacts with rooms, cards, and relics
- **Readable combat** — Intent system means you always know what's coming
- **Expandable by design** — add cards, enemies, relics, and effects with minimal code changes
- **Beginner-friendly codebase** — heavily commented, clear separation of concerns

---

## 👤 Author

Built step by step as a learning project in Godot 4.6.2.
