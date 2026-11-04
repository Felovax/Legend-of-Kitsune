# Roadmap

Complexity is relative (S/M/L/XL); no calendar promises. Each milestone ends with a short report: what was built, decisions, tests, known issues, next step.

| Milestone | Scope | Acceptance criteria | Size | Status |
|---|---|---|---|---|
| **M0 Setup** | Godot project, test runner, CI, docs | Tests pass headless locally and in CI | S | ✅ Done |
| **M1 Combat core** | RNG, deterministic battle sim, statuses, data-driven relics and Resonances, validator, balance probe | 77 tests green, golden replay stable | L | ✅ Done |
| **M2 Run & progression** | Expedition (10 rooms, doors, drafts, Echo, rewards), hero level, training, gear (3 slots, merge), attunement, wallet and ledger, save and migrations, offline rewards, in-run tails; archetype simulations using the real code | A free random-choice player has no softlock; pacing matches targets; save round-trip and migrations tested | L | Next |
| **M3 Playable slice** | Camp, Expedition, battle replay view, draft and door UI, Results, Hero, Codex, Settings; damage numbers, effects, basic audio and chords; placeholder or first AI art | The full 12-step player journey works end to end on desktop and Android | L | |
| **M4 MVP complete** | Simulated shop, debug tools, analytics interface (local), onboarding, accessibility settings | Every MVP acceptance test passes → internal playtest build | M | |
| **M5 Playtest & content** | TestFlight and Play internal testing; 30 chapters / 3 biomes, ~20 relics, ~8 Resonances; permanent tails | Data from 10+ testers; balance revised | L | |
| **M6 Commercial readiness** | Real IAP adapters, verification worker, restore and refunds, privacy and consent, store listings, age ratings, trademark check | Sandbox purchases verified end to end; refunds revoke | L | |
| **M7 Soft launch** | Limited countries | Real D1/D7/D30 and payer metrics | M | |
| **M8 Global launch + live content** | New chapter/relics every 4–6 weeks, Rift Seed, hero 2, cosmetics | — | ongoing | |

## Owner actions needed later
- **Before M5:** Apple Developer account ($99/yr), Google Play account ($25); a Mac or cloud macOS builds; at least one test phone of each kind. Start recruiting 12 Android testers for Google's 14-day closed test.
- **Before M6:** approve backend choice and costs; trademark search for the final name; privacy policy.
- **Art (any time):** generate the kitsune with the prompts in `docs/ART_PROMPTS.md` and log each asset in `docs/ASSET_LOG.md`.
