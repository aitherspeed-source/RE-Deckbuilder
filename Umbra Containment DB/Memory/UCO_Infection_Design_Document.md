# UMBRA CONTAINMENT OUTBREAK
## Systems Design Document — Infection, Containment Devices & Architecture
**Classification: Internal Development Reference**
**Engine: Godot 4 | Genre: Roguelike Deckbuilder**

---

> *"You are not fighting the infection. You are deciding how far you let it take you."*

---

## TABLE OF CONTENTS

1. [A — Project Assessment](#a--project-assessment)
2. [B — Revised Infection System](#b--revised-infection-system)
3. [C — Three Launch Infection States](#c--three-launch-infection-states)
4. [D — Infection Temptation Design](#d--infection-temptation-design)
5. [E — Containment Device Design Rules](#e--containment-device-design-rules)
6. [F — Five Deck Archetypes](#f--five-deck-archetypes)
7. [G — Godot Architecture Plan: RunModifierManager](#g--godot-architecture-plan-runmodifiermanager)

---

---

# A — PROJECT ASSESSMENT

## What the Architecture Gets Right

### The Effect System is Exceptionally Well-Designed

The `Effect` base class with `on_turn_trigger`, `apply`, `tick`, and `remove` hooks is a near-ideal foundation for the Infection redesign. Every new Infection state and Containment Device behavior can be expressed cleanly inside this pattern without breaking existing effects. The `EffectManager._create_effect()` factory is the only coupling point that will need extending.

### The Signal Architecture on Player.gd is Underutilized But Correct

`infection_changed`, `hp_changed`, `ammo_changed` are already defined and emitted. This is the exact hook surface that `RunModifierManager` needs to listen on. The groundwork exists — it just needs a subscriber.

### GameManager's Event Flag System is a Hidden Gem

`contaminated_meds`, `survivor_abandoned`, `specimen_released` are exactly the type of narrative consequence chains that make roguelikes feel alive. The pattern of "player choice in EventRoom creates a named flag that modifies a future room" is sound and should be expanded, not redesigned.

### Data-Driven Cards via `.tres` Resources

The `CardData` resource approach is correct for long-term scalability. Mutations (a core feature of the revised Infection system) can be implemented as alternate `.tres` references swapped at runtime without touching gameplay logic.

### Ammo as the Energy Resource

Using Ammo instead of Energy is an underappreciated thematic decision. It creates natural Resident Evil pacing — careful resource management rather than generous action economy. This should be leveraged in card design, not neutralized.

### Boss Evolution System (Phase Shift)

The `after_damage` hook on enemy that triggers phase transitions is well-placed. The `apply_from_enemy_data()` method allows data-driven boss configuration. This pattern is sound for adding more bosses with distinct phase behaviors.

---

## Risks and Weak Points

### CRITICAL: InfectionEffect Currently Contradicts the Design Goal

The existing `InfectionEffect.on_turn_trigger()` deals direct HP damage equal to stacks. The design brief explicitly states: *"Infection itself NEVER deals scaling damage. Damage only comes from specific named instability states."*

This is a foundational conflict. The InfectionEffect must be rearchitected from a damage source into a **tier tracker and behavior trigger**. This is the highest-priority systemic change before any new content is added.

### CombatManager Has No Signal-Based Event Surface

`CombatManager.gd` controls turn flow through direct method calls (`start_player_turn`, `start_enemy_turn`, `check_combat_end`). There are no signals emitted at key moments — turn start, turn end, card played, damage dealt, combat won. This means external systems (Containment Devices, Infection States) cannot react to combat events without being coupled into CombatManager directly.

Adding a sparse set of combat signals to CombatManager is required before `RunModifierManager` can function properly.

### EffectManager._create_effect() Uses a Match Statement

The factory `_create_effect()` works today with five effects. At twenty effects it becomes fragile maintenance overhead. Before adding Infection States and new Device-driven effects, this should be refactored to a registration dictionary pattern.

### GameManager Has No Containment Device Collection

GameManager tracks `player_infection`, `player_gold`, `player_deck` across rooms — but has no equivalent collection for persistent devices acquired during the run. This slot needs to be added before Containment Device implementation begins.

### Infection Zone Room Applies Infection Silently

`GameManager.enter_room()` applies `+2 Infection` on Infection Zone entry as a plain integer increment with only a print statement. When Infection becomes a tiered behavioral system, silent integer increments without tier-check resolution are a bug surface. This application path needs to route through the Infection resolution system.

---

## What You Should NOT Redesign

- The `Map.gd` / `MapGenerator.gd` / `MapNode.gd` architecture. It is complete and correct.
- The `Player.gd` deck cycle (draw, play, discard, reshuffle). It handles edge cases cleanly.
- The `CardData.tres` resource pattern. It is the right approach.
- The event flag mechanism in `GameManager.gd`. Expand it, don't replace it.
- The `enemy.gd` intent system. It already supports the behavioral telegraphing the tone requires.
- The boss `apply_from_enemy_data()` + `after_damage()` phase framework. It's the right abstraction.

---

---

# B — REVISED INFECTION SYSTEM

## Core Principle: Infection is a State Machine, Not a Meter

Infection is no longer a value that deals damage. It is a number that determines **which behavioral ruleset is active for the player during combat**. Moving through Infection tiers changes *what the game is* — not just what the numbers are.

Players must understand: **Infection is not health. Infection is identity.**

---

## Tier Definitions

Tiers are defined by threshold values. Recommended launch thresholds:

| Tier | Infection Range | Tier Name | Player Status |
|------|----------------|-----------|---------------|
| 0 | 0–4 | Contained | Stable survivor. Standard rules. |
| 1 | 5–9 | Symptomatic | Early mutation pressure. Minor rule alterations. |
| 2 | 10–14 | Infectious | Active mutation. Significant rule changes. |
| 3 | 15–19 | Critical | Dangerous transformation. High power, high instability risk. |
| 4 | 20+ | Terminal | Player is becoming the outbreak. Extreme effects. |

Thresholds are tuneable data values, not hardcoded constants. Store them in a `InfectionConfig` resource.

---

## Tier 0 — Contained (0–4 Infection)

**Rule state:** Baseline. Standard deckbuilder behavior.

**Behavioral notes:** No Infection States are active. Cards function as written. Turn structure is normal. Healing is fully effective. This is where players begin each run and where most early-game card rewards incentivize leaving.

**Design intent:** Establish the baseline so players can feel the contrast when tiers shift. Safe Room interactions feel genuinely valuable here.

---

## Tier 1 — Symptomatic (5–9 Infection)

**Rule alterations:**

- One random card in the player's hand each turn is **Contaminated** — visually distinguished, costs +1 Ammo to play. The contaminated card rotates each draw, not each turn.
- Healing from all sources is reduced by 20% (rounded down). Using the Safe Room costs more to achieve the same result.
- The player gains access to **Reactive Biology**: the first time each turn the player takes damage, they draw 1 card. This is the first hint that Infection returns something.

**Design intent:** Create mild friction. Make players aware the system is active. The Reactive Biology draw reward is small but planted as a seed — Infection gives back. Some players will immediately try to push further.

---

## Tier 2 — Infectious (10–14 Infection)

**Rule alterations:**

- **Card Mutation begins.** A percentage of the player's deck (recommended: 30%) is now Mutated. Mutated cards have altered effects — a Pistol Shot that gains +3 damage but Exhaust. A Take Cover that grants Block but also applies 1 Infection to the player. Mutations are assigned at tier entry and persist for the run.
- Healing is reduced by 40%. The Safe Room becomes a risk calculation.
- **Turn sequencing shifts:** Once per combat, the player may spend 3 Infection stacks to take an additional mini-turn — draw 2, play 1 card, no Ammo refill. This is a deliberate rule-break that rewards leaning into Infection.
- **Bleed effect on the player is doubled in stacks applied** (the body is compromised).

**Design intent:** This is the threshold where players feel genuinely transformed. The mini-turn is a powerful incentive to reach and stay at Tier 2. Card mutations change the deck identity mid-run, forcing adaptation. Players who reach Tier 2 intentionally have a meaningfully different game.

---

## Tier 3 — Critical (15–19 Infection)

**Rule alterations:**

- **Full deck mutation.** All cards in deck are now Mutated variants.
- **Combat sequencing rule change:** The enemy's Intent is now shown one turn late — it is revealed at the end of the turn it executes rather than the turn before. This is a genuine threat. Players must adapt to reactive rather than predictive play.
- **Viral Surge:** At the start of each player turn, gain Strength +1 that lasts only for that turn (volatile strength). This represents uncontrolled biological power.
- Healing is reduced by 60%.
- **Instability window opens:** All three Infection States (Sepsis, Hemorrhagic Fever, the neurological state) are now active simultaneously if triggered. At Tier 2 only one can trigger per combat.

**Design intent:** This is the survival horror apex. Players are powerful and imperiled. The delayed Intent is the most narratively resonant rule change in the game — you can no longer trust your predictions about the enemy. You are losing cognitive clarity. But Viral Surge makes you strong. The tension is real.

---

## Tier 4 — Terminal (20+ Infection)

**Rule alterations:**

- **The player's maximum hand size is increased by 2** (the mutation is enhancing cognitive capacity in monstrous ways).
- **Ammo no longer refreshes at turn start.** Instead, the player gains Ammo equal to the number of cards played last turn. This is a fundamentally altered resource loop that rewards momentum-style play.
- **The player cannot be reduced below 1 HP by a single hit** (once per combat). Mutation preserves vital function even when logic says it shouldn't.
- Healing is reduced by 80%.
- **Transformation narrative triggers:** Special dialogue/log entries reference the player's changing condition.

**Design intent:** Terminal is both a reward and a punishment. The altered Ammo mechanic completely rewrites how decks function. Players who reach Terminal are playing a different game — one their deck may or may not have been designed for. This tier should be rare but achievable and survivable with the right build.

---

## How Players Intentionally Manipulate Infection

Infection should never feel purely punishing or purely empowering. The following mechanisms give players deliberate agency over their Infection level.

**Raising Infection (intentional):**

- Cards with the keyword **Volatile** — deal bonus damage or effect but apply 1–2 Infection to the player.
- Containment Devices that trade safety for power (detailed in Section E).
- Choosing Infection Zone rooms on the map.
- Certain Event choices that offer powerful rewards at Infection cost.
- Spending Infection to activate special card abilities (keyword: **Catalyze** — discard and apply 2 Infection to gain a powerful immediate effect).

**Reducing Infection (intentional):**

- Safe Room option: **Decontamination Protocol** — remove 3–5 Infection, costs more than standard healing.
- Cards with the keyword **Stabilize** — reduce player Infection by 1 on play.
- Certain Containment Devices that passively reduce Infection per combat won.
- Elite combat rewards can include a **Viral Suppressor** one-time item (removes 4 Infection).

**The critical design rule:** Infection reduction should always have a cost. It is never free. The decision to decontaminate must compete with a healing or card upgrade choice.

---

---

# C — THREE LAUNCH INFECTION STATES

Infection States are activated by crossing into certain tiers and are the **only source of Infection-related damage**. They function as active conditions with specific triggers, not passive damage per turn.

---

## State 1 — SEPSIS

**Thematic identity:** The bloodstream is compromised. The body attacks itself.

**Activation threshold:** Tier 1 (5+ Infection). Active from Tier 1 onward.

**Trigger condition:** Activates whenever the player ends a turn without having played at least 2 cards.

**Effect:** The player takes damage equal to their current Ammo at the start of the next turn (representing wasted biological resources, the body consuming itself during inaction). Minimum 2, maximum 8.

**Purpose in design:** Sepsis is a **pressure mechanic that punishes passive play**. It forces engagement. Players cannot turtle with full Ammo and no cards played. It also creates a decision point around Ammo-efficient decks — spending Ammo on cards is now survival behavior, not just tactical choice.

**Player interaction:** Cards that cost 0 Ammo still count as "played" for Sepsis tracking. This creates design space for zero-cost cards that serve purely as Sepsis relief. Some Containment Devices can suppress Sepsis for one turn.

**Narrative framing:** *"The viral load is metabolizing your resources. Keep moving or the body turns against itself."*

---

## State 2 — HEMORRHAGIC FEVER

**Thematic identity:** Internal collapse triggered by exertion overload.

**Activation threshold:** Tier 2 (10+ Infection). Active from Tier 2 onward.

**Trigger condition:** Activates whenever the player plays 4 or more cards in a single turn.

**Effect:** At end of that turn, the player takes 6 damage (bypasses Block, represents internal hemorrhage) and discards their entire hand at the start of next turn rather than drawing. The turn after Hemorrhagic Fever triggers, the player starts with 0 cards and must rebuild.

**Purpose in design:** Hemorrhagic Fever is an **anti-combo limiter** that punishes excessive chaining. It specifically targets decks that try to play massive hands — the very strategy that Tier 2's mutation mutations might enable. Players who want to play aggressively must manage their per-turn card volume.

**Player interaction:** Cards with the **Controlled Burst** keyword count as 0.5 cards for Hemorrhagic Fever purposes (rounded down). This allows high-Infection decks to build around burst-style play without being destroyed by the limiter. Certain Containment Devices raise the trigger threshold from 4 cards to 5.

**Narrative framing:** *"Overstimulation. Every system is screaming. Slow down or rupture."*

---

## State 3 — CORTICAL DRIFT

**Thematic identity:** Neurological degradation. The infection is in the brain now.

**Activation threshold:** Tier 3 (15+ Infection). Active from Tier 3 onward.

**Trigger condition:** Persistent — active every turn once Tier 3 is reached.

**Effect (non-damage):** At the start of each player turn, one random card in the player's hand has its **displayed cost randomized** — it shows a cost that is 0, 1, or 2 (chosen randomly), which may differ from its actual cost. The player does not know the real cost until they attempt to play it. If they cannot pay the real cost, the card fails and returns to hand (no Ammo spent). The actual cost is revealed in the failure message.

**Purpose in design:** Cortical Drift is a **cognitive reliability attack**. It does not deal damage. Instead it attacks the player's most fundamental resource: accurate information. Players at Tier 3 are powerful (Viral Surge, full mutations) but cannot fully trust their own hand read. This creates genuine psychological pressure consistent with neurological infection symptoms.

**Player interaction:** Cards with the **Muscle Memory** keyword always display their correct cost regardless of Cortical Drift. These are cards representing trained physical responses that bypass conscious decision-making. Building a Muscle Memory–heavy deck is one way to operate stably at Tier 3.

**Narrative framing:** *"The synaptic architecture is compromised. You know what you meant to do. The body has other opinions."*

---

---

# D — INFECTION TEMPTATION DESIGN

The core emotional loop of Umbra Containment Outbreak should be: **the game tempts you, you calculate the risk, you choose, and you live with the consequence.**

Infection gain must feel like a choice with upside, not a penalty accumulator.

---

## Map-Level Temptation: Infection Zone Rooms

Infection Zone rooms are visible on the map before the player selects them. The player always knows what they are choosing. The temptation design:

- **Entering an Infection Zone** grants +2 Infection on entry (already implemented).
- **Winning an Infection Zone combat** should offer a reward tier *above* standard Hallway rewards — three cards instead of one, or a choice including rare cards unavailable elsewhere.
- The enemy in an Infection Zone should be slightly weaker than a standard Elite but reward-equivalent, reinforcing that the danger is *entering the zone*, not *the fight inside it*.
- **Infection Zone rooms on the map should be placed as shortcuts** — routes through Infection Zones reach the next floor in fewer rooms than routes that avoid them. Players who avoid all Infection Zones take longer paths.

---

## Event Room Temptation Design

Every Event should have at least one option that offers a meaningful benefit at an Infection cost. Existing events already do this (contaminated_meds). Expand with these principles:

**Pattern A — Tiered Temptation.** One choice gives safe modest reward. One choice gives larger reward at +2–3 Infection. The dangerous choice should be clearly labeled and genuinely worth considering.

**Pattern B — Information Asymmetry.** One choice is labeled with an unknown outcome and a small Infection gain. Sometimes it rewards generously. Sometimes it punishes. Players learn to read event flavor text for risk signals.

**Pattern C — Narrative Consequence Chain.** Some choices don't show Infection cost immediately but set an event flag that applies Infection in a later room. The `contaminated_meds` flag is exactly this pattern. Players who read carefully can identify these — players who rush will be surprised.

**Specific event examples to add:**

- **Umbra Research Terminal:** Read a data file (reveals a Boss phase pattern you haven't seen) or inject the experimental compound (+3 Infection, full heal).
- **Emergency Biohazard Kit:** Use it cleanly (remove all Bleed/Weak effects) or crack the contaminated seal (same effect + powerful Containment Device + 2 Infection).
- **Survivor's Cache:** Take the standard supplies (heal 8 HP) or take the survivor's modified syringe (gain a Volatile card, +2 Infection, +1 max HP permanently).
- **Specimen Tank [CRACKED]:** Seal it (no effect, safe) or study it before sealing (draw 3 cards to keep, set `specimen_released = true`).

---

## Elite Combat Temptation

Elite combats are already stronger and better-rewarded. Layer Infection temptation on top:

- **Pre-combat choice:** Before an Elite fight begins, the player sees two options: Enter normally, or **Breach Protocol** — inject a stimulant (+2 Infection, gain Strength +2 for the fight). The choice is made with knowledge of the Elite's intent preview but before combat begins.
- **Elite reward bonus:** If the player ends an Elite combat at Tier 2 or higher, they receive a bonus reward card selection (rare tier). This incentivizes *maintaining* elevated Infection, not just reaching it.

---

## Boss Temptation: The Umbra Bargain

Bosses are the final Infection temptation. Design a mechanic called **The Umbra Bargain**:

Before the Boss fight, the player is presented with a forced choice from one of three options (chosen randomly per run):

- **Surrender a Containment Device** — lose one equipped device, gain full HP restoration before the fight.
- **Accept the Mark** — gain +5 Infection, gain Volatile Strength +3 that persists through the fight.
- **Enter Uncompromised** — no benefit, no cost. Fight as-is.

The Bargain is presented as narrative — an Umbra containment system "offering" terms to the biological anomaly entering the facility's final sector. Players who have invested in Infection builds will take The Mark. Players who have maintained Containment will refuse or trade a device. Every choice is legitimate and comes from the player's run state, not from an arbitrary modifier.

---

## Reward Track Temptation

After winning combat, the standard reward is: **choose 1 of 3 cards**.

Add a secondary reward option visible alongside cards:

**"Viral Assimilation — Skip the card reward and gain +1 Infection, +1 max HP permanently."**

This option is always present. Taking it repeatedly increases max HP significantly (a powerful run modifier) but accelerates Infection tier advancement. Some runs this is the correct choice. It should never be obviously wrong or obviously correct.

---

---

# E — CONTAINMENT DEVICE DESIGN RULES

## Naming and Presentation Language

Containment Devices are dangerous Umbra Corporation technology. They were built to study, contain, or exploit the Kestrel-7 viral strain. Finding one in the facility suggests either a nearby laboratory or something terrible happened here.

**Naming convention examples:**
- Umbra Viral Attenuator Mk.II
- Kestrel-7 Specimen Flask (Cracked)
- Emergency Containment Collar
- Phase-Shift Injection Rig
- Umbra Protocol Override Chip
- Bio-Adaptive Circulation Pump
- Cortical Dampener Array (Prototype)

**Tone rule:** Devices should sound like objects a real (evil) pharmaceutical research facility would build. Clinical, utilitarian, slightly wrong. Never magical or fantasy-coded.

---

## Design Principle 1: Devices Modify Behavior, Not Stats

A Containment Device should rarely say "deal +2 damage." It should change *how* combat works for the player. Every device should answer the question: *"What does this player now do differently?"*

**Bad device:** Umbra Combat Stimulant — Gain +3 Strength permanently.

**Good device:** Adrenal Surge Injector — The first card you play each turn costs 0 Ammo.

**Bad device:** Specimen Collection Flask — Gain 5 Gold.

**Good device:** Specimen Collection Flask — After winning a combat, if you have Bleed active, remove it and gain 1 Infection. If you do, gain a random Volatile card.

---

## Design Principle 2: Devices React to Events, Not Just Turns

The richest devices are triggered by combat signals — things that happen, not passive modifiers. Every device should ideally respond to at least one of these events:

- Player takes damage
- Player plays a card
- Player plays a specific card type
- Turn begins / ends
- Player reaches an Infection tier
- Enemy uses a specific intent type
- Combat begins / ends
- Player falls below a HP threshold

---

## Design Principle 3: Devices May Intentionally Increase Infection

Some devices are dangerous. They provide real benefit but at the cost of Infection acceleration. These should be clearly telegraphed in the device description — players choose to equip them knowing the cost.

**Example:** Kestrel-7 Mutagenic Enhancer — Your Mutated cards deal +4 damage. At the start of each combat, gain 1 Infection.

**Design rule:** A device that increases Infection must provide a benefit that a player building toward higher Infection tiers would genuinely want. It should never feel like a trap — it should feel like a deal.

---

## Design Principle 4: Devices Have Implicit Synergy Categories

Do not expose categories to players via labels. But internally, design devices with four rough archetypes that create natural synergies with deck archetypes:

- **Containment Devices** — Synergize with Stabilize and low-Infection strategies. Often reduce Infection or suppress Infection State triggers.
- **Mutation Amplifiers** — Synergize with high-Infection tiers. Often enhance Mutated card effects or interact with Viral Surge.
- **Field Gear** — Synergize with Ammo economy or Block strategies. Combat efficiency focused.
- **Specimen Tech** — Synergize with effect stacking (Bleed, Weak, Infection on enemies). Often apply enemy debuffs as a side effect.

---

## Design Principle 5: Maximum One Passive Rule Change Per Device

A device can break one rule. If it changes how ammo works, it doesn't also change how cards draw. If it modifies Infection gain, it doesn't also modify healing. Devices with compound rule changes become cognitively overloaded and undermine the player's ability to understand their own gamestate.

---

## Launch Scope Device Examples (5 illustrative)

**1. Cortical Dampener Array (Prototype)**
Category: Containment | Acquisition: Elite Reward
Effect: Cortical Drift does not randomize the cost of cards with the lowest base cost in your hand. (One card per turn is always displayed accurately.)
Design note: Direct response to Tier 3 instability. Doesn't eliminate the threat — just gives a reliable window.

**2. Adrenal Auto-Injector**
Category: Field Gear | Acquisition: Combat Reward (Rare)
Effect: The first time each combat you fall below 30% HP, immediately gain 3 Block and restore 1 Ammo.
Design note: Reactive survival tool. Especially powerful in aggressive builds that take damage deliberately.

**3. Viral Sequencer (Experimental)**
Category: Mutation Amplifier | Acquisition: Infection Zone Reward
Effect: Your Mutated cards cost 1 less Ammo. At the start of each combat, gain 1 Infection.
Design note: Clearly labeled trade. Accelerates Infection but makes Tier 2 builds dramatically more efficient.

**4. Emergency Containment Collar**
Category: Containment | Acquisition: Safe Room (Purchase Option)
Effect: Once per run, when you would advance to Tier 3 Infection, negate the tier advancement. Infection remains at 14. (Single use, consumed.)
Design note: A safety valve for players who want to operate at maximum Tier 2 power without tipping into Tier 3 risk. High strategic value for mid-run insurance.

**5. Specimen Flask Mk.IV (Pressurized)**
Category: Specimen Tech | Acquisition: Event Room
Effect: When you apply Bleed to an enemy, apply 1 additional stack. When you take Bleed damage yourself, gain 1 temporary Strength until end of turn.
Design note: Dual-purpose interaction with existing Bleed effect. Rewards Bleed-focused decks while being slightly self-destructive (the Flask pressurizes against the player too).

---

---

# F — FIVE DECK ARCHETYPES

Each archetype represents a coherent playstyle enabled by the combination of Infection tier management and Containment Device synergies. These are not character classes — they emerge from card draft and device acquisition decisions.

---

## Archetype 1 — THE FIELD MEDIC

**Infection Strategy:** Stay at Tier 0–1. Decontaminate aggressively at Safe Rooms. Treat Infection as a resource to be minimized.

**Core cards:** Stabilize-keyword cards, high Block generators, healing cards, Controlled Burst attacks (avoid Hemorrhagic Fever even when it can't trigger).

**Containment Device preference:** Emergency Containment Collar (insurance), Field Gear devices (Ammo efficiency), Cortical Dampener (preemptive).

**Gameloop:** Outlast fights through Block and healing. Efficient and consistent. Low variance. Win condition is resource supremacy — enemies run out of ability to threaten before the player's engine is exhausted.

**Thematic identity:** The professional. The person who came into the facility with a mission and refuses to become part of the problem.

**Design challenge to watch:** This archetype must remain competitive with high-Infection builds, or players will feel punished for playing the "right" way thematically. Field Medic wins through efficiency, not power spikes.

---

## Archetype 2 — THE MUTAGENIST

**Infection Strategy:** Target Tier 2 as the operating range. Acquire Mutated cards deliberately. Use the mini-turn ability (Tier 2 rule change) as a core action.

**Core cards:** Volatile-keyword attacks, cards with strong Mutation variants, zero-cost cards to avoid Sepsis at Tier 1.

**Containment Device preference:** Viral Sequencer (Mutated cards cost less), Mutation Amplifier devices.

**Gameloop:** Let the deck mutate and learn what it has become. The Mutagenist's deck is partly designed by the player and partly procedurally generated by the mutation system — every run the mutations are different. Build around the mutations the game hands you.

**Thematic identity:** The researcher who started studying the infection and got too close.

**Design challenge to watch:** Mutations must be interesting, not just better or worse versions of base cards. Each Mutated variant should enable a different decision, not just be a stat adjustment.

---

## Archetype 3 — THE SEPSIS FARMER

**Infection Strategy:** Stay at Tier 1. Intentionally trigger and then mitigate Sepsis for secondary benefits.

**Core cards:** Reactive Biology (the Tier 1 bonus — draw when taking damage) combined with cards that gain bonuses when the player has taken damage that turn. High Ammo spend to avoid Sepsis triggering, but deliberately low-Ammo turns to fish Reactive Biology draws.

**Containment Device preference:** Adrenal Auto-Injector (HP threshold reaction), devices that modify what happens when Infection States trigger.

**Gameloop:** Walk the Sepsis edge. Time turns to take Reactive Biology draws at ideal moments. Occasionally let Sepsis fire and treat the damage as a draw engine trigger.

**Thematic identity:** The survivor who has learned to exploit their own symptoms.

**Design challenge to watch:** This archetype requires very precise Infection State trigger timing. It becomes unplayable if Sepsis mitigation items are too rare or if the damage is too severe.

---

## Archetype 4 — THE CORTICAL AGENT

**Infection Strategy:** Push to Tier 3 and sustain it. Build around Muscle Memory cards to operate under Cortical Drift.

**Core cards:** Muscle Memory keyword cards (reliable cost display), high-variance cards that are powerful when they fire (worth the uncertainty if you have resources to absorb failures), cards that grant Ammo on play (to recover from failed plays).

**Containment Device preference:** Cortical Dampener Array (reliable card per turn), Viral Surge-amplifying devices.

**Gameloop:** Operate in chaos and navigate it better than anyone else. Cortical Drift is the opponent. The Cortical Agent learns to read the RNG, to maintain enough Ammo to absorb failed plays, and to sequence Muscle Memory cards before uncertain ones.

**Thematic identity:** The mutation victim who has adapted. Who can see patterns in the noise because they *are* the noise now.

**Design challenge to watch:** This archetype must feel like mastery, not frustration. Cortical Drift needs to be beatable with skill, not pure luck. The Muscle Memory keyword is the skill expression — players should be able to draft deliberately toward reliability.

---

## Archetype 5 — THE TERMINAL CASE

**Infection Strategy:** Reach Tier 4. Survive the Ammo resource revolution. Win before the healing deficit kills you.

**Core cards:** High card-play-count decks (to generate Ammo under Tier 4's altered rule), cards that generate their own Ammo, cards that combo into chains that become the new resource loop.

**Containment Device preference:** Anything that increases maximum HP (compensates for healing reduction), devices that react to the altered Ammo system.

**Gameloop:** The highest-variance archetype. The Tier 4 Ammo rule (gain Ammo equal to cards played last turn) means the first turn of every combat is resource-starved. Second turn is normal. Third turn rewards chaining. Winning requires surviving the setup turns and then overwhelming enemies before the HP deficit catches up.

**Thematic identity:** The outbreak itself. The player character is no longer entirely human and is winning on terms that weren't available to them at the start.

**Design challenge to watch:** This archetype must be achievable before the Boss fight. Map layout and Infection temptation design must make it possible (but not easy) to reach Tier 4 by the final floor.

---

---

# G — GODOT ARCHITECTURE PLAN: RUNMODIFIERMANAGER

## Overview

`RunModifierManager` is a new Autoload node that manages all **run-persistent rule modifications**. It is the unified listener for both:

- **Containment Devices** (acquired during the run, active until consumed or run ends)
- **Infection States** (activated by Infection tier thresholds, representing rule changes from Infection)

Both systems share the same architecture because they share the same role: *listening to combat signals and modifying behavior in response.*

---

## Why These Systems Belong Together

A Containment Device that says "the first card you play each turn costs 0 Ammo" and an Infection State that says "if you played fewer than 2 cards, take damage at turn start" are both event listeners responding to the same signal (`player_turn_started`, `card_played`). If implemented as separate systems, they will inevitably conflict, duplicate signal routing logic, and create maintenance burden. Unified, they become a single subscription bus.

---

## Architecture: The RunModifier Base

Every Containment Device and every Infection State is a `RunModifier` resource — a `Resource`-extending class with a defined hook interface.

**RunModifier hook interface:**

```
on_run_start(context: ModifierContext)
on_combat_start(context: ModifierContext)
on_turn_start(context: ModifierContext)
on_card_played(card: CardData, context: ModifierContext)
on_damage_taken(amount: int, context: ModifierContext)
on_damage_dealt(amount: int, context: ModifierContext)
on_turn_end(context: ModifierContext)
on_combat_end(won: bool, context: ModifierContext)
on_infection_tier_changed(new_tier: int, context: ModifierContext)
on_run_end(context: ModifierContext)
```

Each hook is optional — modifiers only implement the hooks they need. Empty hooks are no-ops, not abstract requirements.

`ModifierContext` is a lightweight dictionary-like object passed into every hook containing read-only references to the Player, the current enemy, CombatManager state, and a write interface for requesting rule modifications. Modifiers do not directly mutate game state — they request modifications through context, which RunModifierManager validates and applies.

---

## Architecture: RunModifierManager Autoload

`RunModifierManager` is an Autoload (like `GameManager`) that persists across scene transitions. It maintains:

- `active_devices: Array[RunModifier]` — Containment Devices currently held
- `active_states: Array[RunModifier]` — Infection States currently active (managed by Infection tier system)
- `all_modifiers: Array[RunModifier]` — combined list iterated on signal dispatch

**Signal flow:**

`CombatManager` emits signals at key moments (this requires adding ~8 signal emissions to CombatManager — the only change required to existing code). `RunModifierManager` connects to these signals on scene load. When a signal fires, `RunModifierManager` iterates `all_modifiers` and calls the corresponding hook on each modifier in priority order.

**Priority system:** Each RunModifier has an integer `priority` field. Modifiers with lower priority numbers execute first. Containment Devices default to priority 10. Infection States default to priority 5 (States execute before Devices, ensuring tier-level rules resolve before device-level rules).

---

## Integration With Existing Systems

### CombatManager Changes Required

Add signal emissions at the following points (no logic changes, purely signal additions):

- Start of `start_player_turn()` → emit `player_turn_started`
- End of `end_player_turn()` → emit `player_turn_ended`
- Inside `play_card()` after card execution → emit `card_played(card)`
- Inside `check_combat_end()` on enemy death → emit `combat_won`
- Inside `check_combat_end()` on player death → emit `combat_lost`
- Inside `start_enemy_turn()` → emit `enemy_turn_started`

### GameManager Changes Required

Add to run state:

- `active_devices: Array[Resource]` — serializable list of acquired Containment Device resources
- `player_infection_tier: int` — computed property or cached integer matching current tier

On `start_new_run()`, clear `active_devices` and reset `player_infection_tier` to 0.

### InfectionEffect Refactoring

`InfectionEffect` becomes a **tier tracker only**. Remove `on_turn_trigger()` damage logic. Instead:

- `on_turn_trigger()` calls `RunModifierManager.resolve_infection_tier(stacks)` which evaluates current stacks against threshold config and activates/deactivates Infection State modifiers accordingly.
- Infection States (Sepsis, Hemorrhagic Fever, Cortical Drift) are themselves RunModifier resources instantiated and added to `active_states` when tier thresholds are crossed.
- When Infection drops back below a tier threshold (via Decontamination), the corresponding Infection State modifier is removed from `active_states`.

### EffectManager Changes Required

Refactor `_create_effect()` from a match statement to a registration dictionary. Add a `register_effect(id: String, effect_class)` method. This allows RunModifier devices to register new effect types dynamically without editing EffectManager source.

---

## Data-Driven Device Resources

Each Containment Device is a `.tres` resource extending `RunModifier`. Device acquisition is handled by:

1. `DeviceLibrary` autoload — scans a `res://data/devices/` directory at startup, loads all `.tres` files extending `RunModifier` into a registry.
2. On Elite/Event/Infection Zone reward, `DeviceLibrary.get_reward_pool(tier)` returns a filtered array of unacquired devices at appropriate rarity.
3. Player selects one. `RunModifierManager.add_device(device)` is called. Device is appended to `active_devices` and saved to `GameManager.active_devices`.
4. On scene transitions, `RunModifierManager` reads `GameManager.active_devices` and reconstructs modifier subscriptions.

This mirrors the existing `.tres` pattern used by cards and enemies. No new infrastructure is required — only a new directory and a new autoload.

---

## Infection Tier Evaluation Flow (Revised)

```
Player gains Infection stacks (via card, event, or zone entry)
  → InfectionEffect.apply() fires
  → emit infection_changed signal
  → RunModifierManager.on_infection_changed(new_stacks)
    → evaluate stacks against InfectionConfig thresholds
    → determine new tier
    → if tier changed:
        → call on_infection_tier_changed(new_tier) on all active modifiers
        → add/remove Infection State modifiers based on new tier
        → emit infection_tier_changed signal (for UI update)
```

The UI listens to `infection_tier_changed` to update the Infection display with tier name and visual state. This is a read-only display signal — the UI never writes to the Infection system.

---

## What RunModifierManager Does NOT Do

- It does not manage deck contents (that remains on Player and GameManager).
- It does not manage standard status effects (Bleed, Block, Weak, Strength — those remain in EffectManager).
- It does not make direct changes to HP, ammo, or card data — it requests modifications through ModifierContext and CombatManager applies them.
- It does not know about individual card definitions — it responds to the event that a card was played, not to which specific card.

---

## Scalability Assessment

This architecture supports:
- Unlimited additional Containment Devices added as `.tres` files with zero code changes.
- New Infection States added as RunModifier subclasses with targeted hook implementations.
- New combat signals added to CombatManager to give devices finer-grained event hooks.
- Multiplier or conditional modifiers (devices that activate only above certain Infection thresholds) expressed entirely within the modifier's hook logic.
- Post-launch additions (new room types, new event flag types) hookable through `ModifierContext` without touching RunModifierManager's core dispatch.

The system is designed to be extended by adding resources, not by editing existing scripts.

---

---

## APPENDIX: CRITICAL IMPLEMENTATION ORDER

If implementation begins tomorrow, the recommended sequence is:

1. **Add combat signals to CombatManager** — foundational, unblocks everything.
2. **Refactor InfectionEffect** — remove turn-end damage, add tier resolution call.
3. **Build RunModifierManager** — start with empty modifier lists, wire signals, confirm signal flow works.
4. **Implement Sepsis as first RunModifier** — validates the architecture with a real use case.
5. **Implement Hemorrhagic Fever** — second validation, tests the card-count tracking.
6. **Add GameManager device collection** — enables persistence testing.
7. **Build DeviceLibrary and first two Containment Devices** — validates data-driven acquisition.
8. **Implement Cortical Drift** — final Infection State, most complex.
9. **Implement card mutation system** — requires mutation variant `.tres` files per base card.
10. **Implement Tier 2+ behavioral rule changes** — mini-turn, intent delay, etc.

Do not implement card mutations before the Infection tier system is stable. Mutations depend on knowing exactly when tier transitions fire reliably.

---

*End of Document — Version 1.0 — Umbra Containment Outbreak Systems Design*
*Prepared for internal development reference. Do not distribute.*
