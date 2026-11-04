# Architecture

## Layout

```
project.godot
data/                  game content as JSON (balance, heroes, enemies, relics, resonances; later chapters, gear, shop)
src/core/              pure logic: no Nodes, no wall-clock time, no global randomness
  sim/                 Rng32, Fx (integer math), SimConfig, Combatant, BattleSim, BattleResult, CombatFactory
  content/             ContentDB (load + index), ContentValidator, ContentSchema (allowed vocabulary)
  run/                 Expedition (state machine: doors, fights, drafts, events, tails, Echo, loot),
                       RunResult, AutoPilot (bot for sims, softlock tests and auto-repeat)
  progression/         PlayerProfile (all persistent state), Wallet (+ ledger with reason codes),
                       Progression (levels, training, attunement, gear, power, rewards, offline income)
  save/                SaveCodec (schema version + migration chain)
  shop/       (M4)     catalog, eligibility, purchase flow, idempotent grants
src/services/          SaveService (atomic write, 2 backups, checksum); autoloads Game (GameState) and Audio
src/platform/ (M4/M6)  store adapters: fake, Apple (godot-iap), Google (Play Billing)
src/ui/
  app/                 App shell: backdrop, currency bar, bottom tabs, expedition takeover, toasts
  screens/             Camp, Expedition, Hero, Codex, Settings, Shop (stub)
  battle/              BattleView: replays BattleResult.events (damage numbers, statuses, banner, skip)
  kit/                 UiKit helpers, IconDraw, CreatureDraw (placeholder art), Backdrop
  theme/               Palette (all colours) and UiTheme (code-built Theme, OFL fonts)
assets/                fonts (+ OFL licences), audio (generated), icon; sprites/<id>.png when AI art arrives
localization/          strings.csv (English); UI uses English msgids via tr(), content uses keys
tests/                 headless tests (run_tests.gd, test_case.gd, sim_test_case.gd, unit/, fixtures/)
tools/                 test.sh, validate_content.gd, balance_sim.gd
docs/                  design, economy, decisions, roadmap, art prompts
```

## Key ideas

### 1. Simulate first, then present
`BattleSim.run()` computes a whole fight and returns a `BattleResult` with an **event log** (`attack`, `damage`, `status`, `status_end`, `heal`, `shield`, `proc`, `death`, `battle_start`, `battle_end`). The UI animates that log. This gives battle skip, speed control, replays and future PvP replays almost for free, and lets the logic be tested without graphics.

### 2. Determinism
- Integer math only; percentages are basis points (10000 = 100%).
- `Rng32` (xoshiro128\*\*) is pinned by known-answer tests against a Python reference.
- One seed per battle. Use `Rng32.derive_seed(base, stream)` for independent streams (combat, loot, draft), so changing one never shifts another.
- `tests/unit/test_determinism.gd` holds a golden hash of a reference fight, built from the frozen content in `tests/fixtures/golden/`.

### 3. Data-driven effects
A relic, a Resonance and an enemy ability are all lists of effects:
`{ "trigger": ..., [conditions], "action": { "type": ..., "target": ..., params } }`

- Triggers: `passive`, `fight_start`, `on_hit`, `on_crit`, `every_n_attacks`, `every_seconds`, `on_kill`, `on_damage_taken`, `hp_below`, `on_status_applied`.
- Conditions: `chance_bp`, `n`, `seconds`, `threshold_bp`, `status`, `target_has_status`.
- Actions: `apply_status`, `damage`, `heal`, `shield`, `modify_stat`, `consume_burst`.
- Targets: `target`, `self`, `all_enemies`, `other_enemies` (with `max_targets`), `random_enemy`.
- Potency (relic level) scales `mult_bp`, `pct_max_hp_bp` and `modify_stat.add` (unless `"scales": false`).
- Resonances activate by **tags**: `ContentDB.active_resonances(relic_ids)`.

Adding a relic means adding JSON only. A new trigger, action, status or stat means: register it in `ContentSchema`, validate it in `ContentValidator`, implement it in `BattleSim`, and test it.

### 4. Content validation
`ContentDB.load_from_dir()` normalizes JSON numbers (integral floats → int), validates everything and refuses to build lookup tables if anything is wrong. CI runs `tools/validate_content.gd`.

### 5. Expedition and progression (M2)
- `Expedition.start(content, profile, chapter)` consumes a run number from the profile; the run seed is `derive_seed(profile.seed_base, run_number)`, with separate streams for doors, encounters, drafts, events, loot and each battle.
- The UI drives it by phase (DOOR → BATTLE → DRAFT/EVENT → …). `fight()` returns the BattleResult to animate.
- Rewards are collected in a `RunResult` and applied once with `Progression.apply_run_result()`, which refuses a run id it has already seen.
- Every currency change goes through `Wallet.add/spend(currency, amount, reason)`. Gems have free and paid buckets; free gems are spent first.
- Offline income is gold only, capped, and grants nothing if the clock moved backwards.

### 6. Saves (M2)
`SaveService` writes `user://saves/profile.json`: the profile is encoded by `SaveCodec` with `schema` and `game` fields, then wrapped as `{payload, sig}` (HMAC-SHA256 checksum, not security).
- Writes go to a temp file first, then rotate `.bak1`/`.bak2`, then rename.
- Loading tries main → backup1 → backup2 → temp, so a corrupt or interrupted save falls back to the newest valid copy.
- A newer schema is refused. Older schemas run through `SaveCodec.steps()` (one tested step per version).

### 7. UI layer (M3)
- `Game` (autoload, `src/services/game_state.gd`) owns the profile at runtime: `boot()`, `save()`, offline claim on resume, expedition start/finish, upgrade wrappers that save and emit `profile_changed`. Screens never change the profile directly.
- `boot()` is called by the App scene, never in `_ready`, so tests and tools can boot it with their own save folders.
- Screens are code-built `Control`s. Text goes through `tr()`; colours come only from `Palette`.
- `BattleView` animates a finished `BattleResult`. Speed and skip never affect the outcome.
- `tools/screenshot.gd` renders any scene or `.gd` screen to PNG under `xvfb-run` (see `tools/preview/`), for visual review in CI or by AI.

### 8. Simulation tools
- `tools/economy_sim.gd`: day-by-day player archetypes (casual/active free, three spender levels) using the real code: offline claims, gem caches, greedy upgrades and AutoPilot expeditions within a time budget. This is the tool for pacing decisions.
- `tools/balance_sim.gd`: raw combat power probe (simplified rooms, power multiplier).

## Planned systems

### Purchases (M4 simulated, M6 real)
`StoreAdapter` (fake / Apple / Google) → verification (fake locally; server in production) → `GrantService`, which refuses to grant the same transaction ID twice → wallet, inventory and entitlements. Paid gems, free gems, entitlements, cosmetics and progression are separate.

### Backend (M6, commercial launch only)
A small serverless worker (e.g. Cloudflare Workers, ~$0–5/month):
- Verifies Apple signed transactions (App Store Server Library; `verifyReceipt` is deprecated) and Google purchase tokens.
- Keeps a transaction ledger.
- Handles refunds and revocations (App Store Server Notifications V2, Google RTDN plus the Voided Purchases API).
- Acknowledges Google purchases within 3 days.

Secrets live only in the worker. Alternative: RevenueCat (no official Godot SDK).

### Offline rewards (M2)
Elapsed time = now − last seen, clamped to [0, cap]. If the clock moved backwards, reset and grant 0. Gold only, never gems. Server time is checked when a backend exists.

### Future PvP (later)
Server-stored build snapshots, server-side replay of the deterministic simulation, never trusting results the client reports, and normalized stats in the Arena.

## Testing
- `tools/test.sh`: the custom runner fails a test on failed assertions, on engine or script errors (via `OS.add_logger`), and on tests with no assertions.
- Current coverage: RNG known answers, damage math, crit, armor, shields, lifesteal, every status, every relic, every Resonance, enemy abilities and scaling, determinism and the golden hash, the content validator.
- `tools/balance_sim.gd`: many simulated runs per chapter and power level.

## Platforms and builds
- Android builds from Windows or Linux. iOS needs macOS with Xcode 26 (an App Store requirement since 2026-04-28): a Mac, or a cloud macOS build (GitHub Actions macOS runners, Codemagic).
- New personal Google Play accounts need a closed test with 12 testers for 14 days before production.
