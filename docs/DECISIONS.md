# Decision log

Settled decisions and why. Add new entries at the bottom; to change a decision, add a new entry that supersedes the old one.

| # | Date | Decision | Why |
|---|---|---|---|
| 1 | 2026-11-04 | **Engine: Godot 4.7 + GDScript** | Free (MIT), 2D-first, text-based scenes that AI can edit, headless tests on Linux, small builds. C# on iOS is still experimental, so GDScript. Weak spot: iOS in-app purchases rely on a third-party plugin, so they sit behind a `StoreAdapter` interface. |
| 2 | 2026-11-04 | **Title: "Legend of Kitsune"** (working title) | "Relic Hunters" is an existing franchise by Rogue Snail (Zero, Rebels on Netflix mobile, Legend). Hits in this genre are named after their mascot. Formal trademark search needed before launch. |
| 3 | 2026-11-04 | **Mascot: a cute kitsune that gains tails** | Cute-animal mascots drive the genre's marketing. Tails give visible power growth (one per Resonance in a run; up to nine as permanent progression). |
| 4 | 2026-11-04 | **Visual direction: bright, colourful chibi cartoon with a rich UI**, in the genre language of games like Legend of Mushroom, without copying any assets, layouts or characters | The owner's choice after reviewing concepts. |
| 5 | 2026-11-04 | **Art produced with AI image tools** (owner's choice) | Fast and cheap. Trade-off: purely AI-generated art is not copyrightable in the US, so others can copy the mascot. Keep a provenance log (`docs/ASSET_LOG.md`) and check each tool's commercial terms. |
| 6 | 2026-11-04 | **One premium currency (Gems); no paid random rewards** | FTC v. HoYoverse (2025), Brazil's ECA Digital loot-box ban for minors (March 2026), EU CPC principles on virtual currencies, and Apple's odds-disclosure rule all point the same way. Fixed-content bundles only. |
| 7 | 2026-11-04 | **No energy system at launch** | Energy walls are the genre's most-hated mechanic. Revisit only if soft-launch data shows pacing problems. |
| 8 | 2026-11-04 | **Deterministic, integer-only combat that emits an event log** | Enables replays, battle skip, golden tests, balance simulation and future server-verified PvP. |
| 9 | 2026-11-04 | **Own RNG (xoshiro128\*\*) in 32-bit-safe math** | Engine RNG implementations can change between versions; ours is pinned by known-answer tests against a Python reference, and is easy to port to a server. |
| 10 | 2026-11-04 | **Content as JSON + validator**, not Godot `.tres` | Portable to a future backend (shop catalog, balance), easy to diff and to generate, and validated with readable errors. |
| 11 | 2026-11-04 | **Custom ~150-line test runner** instead of GUT/gdUnit4 | No third-party dependency. It uses Godot 4.5+'s `Logger` API to fail tests on engine or script errors, and fails tests that make no assertions. |
| 12 | 2026-11-04 | **Compatibility (OpenGL) renderer** | Widest device support for a 2D mobile game, including low-end Android devices without good Vulkan drivers. |
| 13 | 2026-11-04 | **Statuses last their full duration**: timers don't count down on the tick a status is applied | Found by a test: Freeze lasted 29 ticks instead of 30. |
| 14 | 2026-11-04 | **Burn ignores armor** | Gives Ember builds a clear role against armored enemies. Build diversity. |
| 15 | 2026-11-04 | **Golden replay test uses a frozen content fixture** | Balance tuning in `data/` must not break the determinism test; only rule changes should. |
| 16 | 2026-11-04 | **Level cap = 10 + 6 per chapter cleared; level cost ×1.09 per level; gold ×1.36 per chapter; 3 gold per room** | Found with `tools/economy_sim.gd` on the real code. A cap of 4/chapter created a hard wall at ~ch 21 that more play could not move; 7/chapter (1.06⁷ ≈ 1.50× > enemy 1.40×) ran away. 6/chapter keeps levels cost-limited and gives a generous start, a steady middle and a soft late-game slope. |
| 17 | 2026-11-04 | **Overflow-safe integer math** (`Fx.bp` splits the multiplication; exponential curves saturate at 1e15) | Idle-RPG numbers are exponential; the economy sim overflowed int64 near chapter 70. Results in normal ranges are unchanged (golden hash identical). |
| 18 | 2026-11-04 | **Never name members after GDScript/Object built-ins** (`has_meta`, `sign`, `seed`, `log`, ...) | Two bugs came from this; the names collide silently with engine functions. |
| 19 | 2026-11-04 | **The Godot economy sim replaces the Python planning model** | One source of truth: it runs the real expedition, combat, upgrade and reward code. |
| 20 | 2026-11-04 | **Meta-game data files are optional when loading** (required by the game and by `validate_content.gd`) | Lets combat-only fixtures (the golden test) stay small and frozen. |
| 21 | 2026-11-04 | **UI is built in GDScript code (minimal `.tscn`)** with a code-built Theme and a small `UiKit` | Text-only, easy for AI to generate and review, testable headless; screens are plain `Control` classes. |
| 22 | 2026-11-04 | **Placeholder art is vector-drawn in code; real sprites drop in by file name** (`assets/sprites/<creature_id>.png`) | The game is fully playable before the AI art exists; no code change when art arrives. |
| 23 | 2026-11-04 | **Sound effects are generated (sine/noise), one bell note per element; a Resonance plays its tags as a chord** | Zero licensing risk; a distinctive audio identity that grows with content. |
| 24 | 2026-11-04 | **Tests run on the first frame**, not in `_initialize` | Only then are the scene tree and autoloads live, so UI nodes get `_ready`. |
| 25 | 2026-11-04 | **Playtest builds come from CI**: every push to main/milestone branches builds a debug APK artifact | The owner can install and play on a phone without any local Android tooling. |
| 26 | 2026-11-04 | **Camp kitsune shows 1 + discovered Resonances tails** (max 9) | A visible, permanent sign of collection progress until the Tail Awakening system (v1.0). |
