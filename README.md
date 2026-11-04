# Legend of Kitsune

A portrait mobile roguelite RPG for iOS and Android. A little kitsune delves into relic-filled ruins, battles automatically, and drafts relics that combine into **Resonances**. Every Resonance it awakens gives the kitsune a new tail.

> Working title. A trademark check is still needed before launch.

## Status

Playable prototype. M0–M3 are done: combat core, expedition, progression, economy, saves, and a complete UI with placeholder art and sound (151 tests). Next: M4 (shop, onboarding, resume after app kill).

## Tech

- Engine: Godot 4.7 (GDScript)
- Platforms: iOS (primary), Android
- Monetization: free-to-play with optional in-app purchases. No paid random rewards.

## Repository layout

See `docs/ARCHITECTURE.md`. Design: `docs/GDD.md`, economy: `docs/ECONOMY.md`, decisions: `docs/DECISIONS.md`, roadmap: `docs/ROADMAP.md`, art prompts: `docs/ART_PROMPTS.md`. In short: `src/core` holds pure, deterministic game logic, `data` holds JSON content, `src/ui` holds the views, and `tests` holds the headless tests.

## Play it on an Android phone

Every push to `main` builds a debug APK on GitHub Actions:
1. Open the repository's **Actions** tab and choose the latest **android-debug-apk** run.
2. Download the **legend-of-kitsune-debug-apk** artifact (a zip) and unzip it.
3. Copy the `.apk` to the phone and open it (allow "install unknown apps" for your file manager).

## Running the tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
