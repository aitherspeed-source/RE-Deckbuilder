# Combat System

- Turn-based system
- Player acts first
- Uses Ammo instead of energy
- Draw 5 cards each turn
- Discard hand at end of turn
- Deck reshuffles automatically

Enemy:
- Has Intent system (telegraphs actions)
- Scales based on room type
- Boss enemies can be loaded from `EnemyData` `.tres` resources and can evolve mid-fight (name/intent pool swap + Strength buff)

Win Condition:
- Enemy HP = 0

Loss Condition:
- Player HP = 0

Presentation:
- Combat HUD layout and HP bars live in `Combat_ui.gd` (see UI System.md)