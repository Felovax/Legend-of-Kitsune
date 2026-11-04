# Legend of Kitsune: notes for AI-assisted development

Portrait mobile roguelite RPG in Godot 4.7 (GDScript). Read `docs/ARCHITECTURE.md` before changing code, `docs/GDD.md` for design intent, and `docs/DECISIONS.md` before revisiting a settled choice.

## Commands

- Run all tests: `tools/test.sh` (or `tools/test.sh <filter>`)
- Validate content: `godot --headless --path . --script res://tools/validate_content.gd`
- Balance probe: `godot --headless --path . --script res://tools/balance_sim.gd -- --chapter=2 --runs=300 --power=10000`
- After adding a new `class_name` script, run `godot --headless --path . --import` once so the class cache updates.

## Rules

- Everything in `src/core` is pure logic: no Nodes, no scene tree, no `Time`, no global `randi()`/`randf()`. Use `Rng32` with an explicit seed.
- Combat math uses integers only. Percentages are basis points (10000 = 100%). Use `Fx.bp()`.
- New relics, enemies and resonances are data in `data/*.json`. Add code only for a genuinely new trigger, action, status or stat, and register it in `ContentSchema` and `ContentValidator`.
- Every behaviour change ships with tests. Tests must be deterministic.
- If combat rules change on purpose, update `GOLDEN_HASH` in `tests/unit/test_determinism.gd` and say so in the commit message. Balance tuning in `data/` must never change it, because the golden test uses `tests/fixtures/golden`.
- Static typing everywhere. Tabs for indentation (Godot default).
- Never commit secrets (store keys, keystores, service accounts).
- Monetization rules: no paid random rewards, a single premium currency, real-money prices only from the store APIs, and no purchase prompts after a defeat. See `docs/ECONOMY.md`.
