# Legend of Kitsune

A portrait mobile roguelite RPG for iOS and Android. A little kitsune delves into relic-filled ruins, battles automatically, and drafts relics that combine into **Resonances**. Every Resonance it awakens gives the kitsune a new tail.

> Working title. A trademark check is still needed before launch.

## Status

Pre-production. Development follows the milestones in `docs/ROADMAP.md`.

## Tech

- Engine: Godot 4.7 (GDScript)
- Platforms: iOS (primary), Android
- Monetization: free-to-play with optional in-app purchases. No paid random rewards.

## Repository layout

See `docs/ARCHITECTURE.md`. In short: `src/core` holds pure, deterministic game logic, `data` holds JSON content, `src/ui` holds the views, and `tests` holds the headless tests.

## Running the tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
