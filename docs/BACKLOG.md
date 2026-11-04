# Backlog

## M4: MVP complete (next)
- [ ] **Resume an expedition after the app is killed.** Persist `{chapter, run_seed, run_id, actions[]}` and rebuild by replaying the actions (the expedition is deterministic). Mobile OSes kill background apps, so this is a must.
- [ ] Simulated shop: catalog JSON (gem packs, Starter Pack, Tail Ledger, Fox Charter, Swift Paws, caches), eligibility rules, fake store adapter, idempotent grants keyed by transaction id, purchase history
- [ ] **Gold Cache limits:** the economy sim shows a $150/month player about 4× faster to chapter 30 than an active free player. Test a daily cap or escalating price, then re-run `tools/economy_sim.gd`.
- [ ] Onboarding: chapter 1's first draft guarantees a Resonance pair; short hints on the first door, draft and upgrade
- [ ] Debug panel (debug builds only): add currency, set chapter/level, force relics, run N battles
- [ ] Analytics event schema + local sink (session, expedition start/end, draft offered/picked, upgrade, currency source/sink, shop view/purchase)
- [ ] Music (simple loop) behind the existing Music toggle
- [ ] Play-test pass on a real phone with the CI APK: layout on small screens, touch targets, readability, performance

## Later
- [ ] Rift Seed weekly challenge (v1.1)
- [ ] Permanent Tail Awakening (v1.0)
- [ ] 30 chapters / 3 biomes, ~20 relics, ~8 Resonances (M5)
- [ ] Replace placeholder art with AI art (`docs/ART_PROMPTS.md`); sprites go in `assets/sprites/<id>.png`

## Known issues / notes
- MVP data has 5 chapters. Simulations beyond chapter 5 reuse chapter 5's enemies (stats still scale).
- `tools/balance_sim.gd` is a raw combat probe. Use `tools/economy_sim.gd` for pacing.
- Expected pacing (first pass) is in `docs/ECONOMY.md`. It must be re-checked with real playtests (M5).
- Harmless "ObjectDB instances leaked at exit" warning after the test summary (static caches and preloaded fonts).
