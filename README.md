# Legend of Kitsune

A portrait mobile roguelite RPG for iOS and Android. A little kitsune delves into relic-filled ruins, battles automatically, and drafts relics that combine into **Resonances**. Every Resonance it awakens gives the kitsune a new tail.

> Working title. A trademark check is still needed before launch.

## Status

Pre-production. M0 (project setup) and M1 (combat simulation core, 77 tests) are done. Next: M2 (expedition and progression).

## Tech

- Engine: Godot 4.7 (GDScript)
- Platforms: iOS (primary), Android
- Monetization: free-to-play with optional in-app purchases. No paid random rewards.

## Repository layout

See `docs/ARCHITECTURE.md`. Design: `docs/GDD.md`, economy: `docs/ECONOMY.md`, decisions: `docs/DECISIONS.md`, roadmap: `docs/ROADMAP.md`, art prompts: `docs/ART_PROMPTS.md`. In short: `src/core` holds pure, deterministic game logic, `data` holds JSON content, `src/ui` holds the views, and `tests` holds the headless tests.

## Running the tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
