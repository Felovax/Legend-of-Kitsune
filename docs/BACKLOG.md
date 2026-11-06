# Backlog

## M4: MVP complete
- [x] Resume an expedition after the app is killed (action log + replay; `tests/unit/test_resume.gd`)
- [x] Simulated shop: catalog JSON, eligibility, fake store, idempotent grants per transaction id, purchase history, Tail Ledger, Fox Charter, caches
- [x] Gold Cache limits: 5 per day at rising prices (100 → 400 gems); Shard Cache 3 per day. Re-simulated (`docs/ECONOMY.md`)
- [x] Onboarding: the first expedition's first two drafts guarantee a Resonance pair; hints on camp, first door, first draft and results
- [x] Swift Paws: 3× speed and Auto mode (1× / 2× free)
- [x] Debug panel (debug builds only): add currency, unlock next chapter, reset save, failing test purchases, play-log summary
- [x] Local play log (debug builds only, no network): session, run start/end, level-up, purchase, cache
- [ ] Play-test pass on a real phone with the CI APK: layout on small screens, touch targets, readability, performance (owner, see `docs/GUIDE_EIER.md`)
- [x] Music: two generated placeholder loops (camp, expedition) behind the Music toggle (`tools/audio/gen_music.py`). Replace with real music later by keeping the file names

## Later
- [ ] Rift Seed weekly challenge (v1.1)
- [ ] Permanent Tail Awakening (v1.0)
- [ ] 30 chapters / 3 biomes, ~20 relics, ~8 Resonances (M5)
- [ ] Replace placeholder art with AI art (`docs/ART_PROMPTS.md`); sprites go in `assets/sprites/<id>.png`
- [ ] Analytics events for drafts offered/picked and currency sources/sinks; a consented network sink before soft launch (M6)
- [ ] Debug panel extras: set level, force relics, run N simulated battles

## Known issues / notes
- MVP data has 5 chapters. Simulations beyond chapter 5 reuse chapter 5's enemies (stats still scale).
- `tools/balance_sim.gd` is a raw combat probe. Use `tools/economy_sim.gd` for pacing.
- Expected pacing (first pass) is in `docs/ECONOMY.md`. It must be re-checked with real playtests (M5).
- Harmless "ObjectDB instances leaked at exit" and "1 resources still in use at exit" (a music stream released late by the dummy audio driver) after the test summary.
