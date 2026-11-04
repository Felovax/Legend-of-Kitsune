# Backlog

## M2: run and progression (next)
- [ ] `src/core/run/expedition.gd`: 10-room state machine, door generation from chapter data, encounter tables, HP carryover, 15% heal between rooms
- [ ] Relic draft: offer 3, duplicates level up, one free reroll, Resonance hint on cards
- [ ] Echo Keepsake after a defeat
- [ ] In-run tails: +1 tail per active Resonance (+5% ATK each, first pass)
- [ ] Rewards: gold, shards, first-clear bonus, gear drops
- [ ] `data/chapters.json`, `data/gear.json`, `data/progression.json` (cost curves)
- [ ] Progression: hero level (capped by progress), training ×3, gear (3 slots, 3 rarities, enhance, merge), relic attunement
- [ ] Wallet + ledger with reason codes; insufficient-funds handling
- [ ] Save: JSON, schema version, migrations, atomic write, 2 backups, checksum
- [ ] Offline rewards with cap and clock-rollback guard
- [ ] Rewrite the economy simulation in Godot using the real code; 5 player archetypes
- [ ] Tests: softlock check, save round-trip, migrations, double-grant guard

## Later
- [ ] Battle replay view (M3)
- [ ] Debug panel (debug builds only)
- [ ] Analytics event schema + local sink
- [ ] Localization CSV wiring (English first)
- [ ] Rift Seed weekly challenge (v1.1)
- [ ] Permanent Tail Awakening (v1.0)

## Known issues / notes
- Balance: chapter 2 is cleared only ~27% of the time by a fresh hero. Intended to be fixed by M2 rewards and upgrades; re-measure then.
- Enemy formations are currently random in the balance probe; real encounter tables arrive with chapters.json.
