# Backlog

## M3: playable slice (next)
- [ ] `GameState` service: load/save the profile (SaveService), seed_base on first launch, offline claim on resume, autosave after each run and purchase
- [ ] Theme: colours, fonts and button/panel styles in the bright chibi direction (Godot Theme resource); safe-area margins
- [ ] Camp screen: chapter card with Recommended vs your Power, Delve button, offline chest, currency bar, bottom tabs
- [ ] Expedition screen: room track, door choice, battle stage, draft overlay (cards with "completes Resonance" hint), event dialog, Results with Echo choice
- [ ] Battle replay view: plays `BattleResult.events` (attacks, damage numbers, crits, statuses, procs, Resonance banner); 1×/2× speed and skip
- [ ] Hero screen: level, three trainings, gear (equip, enhance, merge), attunement
- [ ] Codex screen: relics and Resonances (silhouettes until discovered)
- [ ] Settings: audio, reduced effects, screen shake, text size
- [ ] Placeholder art: consistent shapes and colours; swap in AI art when ready (`docs/ART_PROMPTS.md`)
- [ ] Basic audio plus the Resonance "chord"
- [ ] Localization: `localization/strings.csv`, all UI text through `tr()`
- [ ] Android debug export from CI or locally; check it runs on a phone

## M4
- [ ] Simulated shop (catalog JSON, eligibility, fake store adapter, idempotent grants)
- [ ] **Gold Cache limits:** the economy sim shows a $150/month player reaching chapter 30 about 4× faster than an active free player. Test a daily cap or escalating price, then re-run `tools/economy_sim.gd`.
- [ ] Debug panel (debug builds only)
- [ ] Analytics event schema + local sink
- [ ] Onboarding (first Resonance guaranteed in chapter 1)

## Later
- [ ] Rift Seed weekly challenge (v1.1)
- [ ] Permanent Tail Awakening (v1.0)
- [ ] 30 chapters / 3 biomes, ~20 relics, ~8 Resonances (M5)

## Known issues / notes
- The MVP data has 5 chapters. Simulations beyond chapter 5 reuse chapter 5's enemies (stats still scale).
- `tools/balance_sim.gd` is a raw combat probe with a simplified room loop. Use `tools/economy_sim.gd` for pacing.
- Expected pacing (first pass) is in `docs/ECONOMY.md`. It must be re-checked with real playtests (M5).
