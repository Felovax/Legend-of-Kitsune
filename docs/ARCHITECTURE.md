# Architecture

## Layout

```
project.godot
data/                  game content as JSON (balance, heroes, enemies, relics, resonances; later chapters, gear, shop)
src/core/              pure logic: no Nodes, no wall-clock time, no global randomness
  sim/                 Rng32, Fx (integer math), SimConfig, Combatant, BattleSim, BattleResult, CombatFactory
  content/             ContentDB (load + index), ContentValidator, ContentSchema (allowed vocabulary)
  run/        (M2)     expedition state machine: rooms, doors, drafts, rewards, Echo keepsake
  progression/ (M2)    hero level, training, gear, attunement, codex
  economy/    (M2)     wallet, ledger (every currency change has a reason), offline rewards
  shop/       (M4)     catalog, eligibility, purchase flow, idempotent grants
src/services/ (M2+)    thin autoloads: GameState, SaveService, StoreService, Analytics, Audio
src/platform/ (M4/M6)  store adapters: fake, Apple (godot-iap), Google (Play Billing)
src/ui/                screens and views; the battle view replays BattleResult.events
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

## Planned systems

### Save system (M2)
JSON in `user://`, with a `schema` version and a chain of migration functions (one per version step, each tested). Writes are atomic (write a temp file, then rename), the last 2 saves are kept as backups, and an HMAC checksum deters casual editing (it is not security).

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
