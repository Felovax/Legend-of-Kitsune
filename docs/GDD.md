# Game Design Document: Legend of Kitsune

Status: pre-production. Numbers are first-pass and live in `data/`; they will be tuned with simulations and playtests.

## 1. Concept

A bright, cute, portrait roguelite RPG for short mobile sessions. A little **kitsune** (fox spirit) delves into relic-filled ruins. Combat is automatic; the player's skill is in **drafting relics** that combine into **Resonances**. Every Resonance awakened gives the kitsune a new **tail**. Between runs, gold, shards and gear make the kitsune permanently stronger.

**One-line pitch:** *Draft relics, awaken Resonances, grow nine tails.*

Target audience: casual-to-midcore mobile RPG players (the audience of Capybara Go!, Legend of Mushroom, Archero 2). They want instant feedback, visible power growth and light decisions.

## 2. Pillars

1. **Readable synergy.** Relics are simple alone and spectacular together. A Resonance is announced loudly: banner, chord sound, a new tail.
2. **Always progressing.** Every run, win or lose, leaves you stronger.
3. **Fair and honest.** The PvE campaign is fully achievable for free. No paid random rewards, no energy walls, no purchase prompts after defeats.
4. **Short sessions.** One run is about 3 minutes at 2× speed.

## 3. Mascot and the tails

- The hero is a chibi kitsune: big head, big amber eyes, cream-and-orange fur, one fluffy tail with a glowing tip, and a small explorer's satchel with a paper lantern charm. Name to be decided.
- **In a run:** each active Resonance adds a glowing tail, up to 9, plus a small bonus (first pass: +5% ATK per tail). Tail colour follows the Resonance's elements.
- **Permanent (post-MVP), "Tail Awakening":** the kitsune starts with 1 tail. Tails 2–9 unlock at progression milestones; each grants a permanent perk (extra reroll, an extra draft option, a bigger offline cap, a new door type). "Awaken all nine tails" is the long-term goal and the marketing hook.
- Cosmetics: tail and fur skins (no stats).

## 4. Core loop

1. Camp: pick a chapter and press **Delve**.
2. 10 rooms. Rooms 2–9 offer a fork of 2 doors (fight, elite, shrine, treasure, event). Room 5 is a fixed elite, room 10 is the boss.
3. Automatic combat.
4. After each won fight, **draft 1 of 3 relics**. Drafting a relic you already have levels it up (+50% potency). One free reroll per run.
5. HP carries between rooms; you heal 15% between rooms.
6. Run ends (win or loss). You keep all gold and shards earned. A first clear gives a big bonus and a gear drop.
7. **Echo Keepsake:** after a defeat, choose one relic from that run to start your next attempt with.
8. Spend at Camp: hero level, training, gear, relic attunement.
9. Delve again, visibly stronger.

## 5. Combat (implemented in M1, see `src/core/sim`)

- 20 ticks per second, integer math, seeded RNG. Same inputs give the same fight, every time.
- Each fighter fills an attack gauge by its attack speed; a full gauge means a basic attack. The hero hits the front enemy.
- Damage = ATK × (crit ? crit damage : 1) × (1 − armor), with armor capped at 60% and a minimum of 1. Crit chance is capped at 75%.
- Shields absorb damage first. Lifesteal heals a share of basic-hit damage.

| Status | Rule (data/balance.json) |
|---|---|
| Burn | 20% of the source's ATK per second per stack, up to 5 stacks, 3 s, refreshed on reapply. **Ignores armor.** |
| Chill | −10% attack speed per stack, 4 s. At 5 stacks: **Freeze**. |
| Freeze | Cannot act for 1.5 s, then 3 s immune to freezing. |
| Shock | The next hit on the target deals +30%. |

## 6. Relics (8 in the MVP)

| Relic | Tag | Effect |
|---|---|---|
| Ember Stone | ember | Hits apply Burn |
| Frozen Core | frost | Hits apply Chill |
| Storm Crystal | storm | Every 4th attack: a bolt for 120% ATK |
| Chain Relic | chain | On-hit effects and bolts also hit 1 more enemy (bolts at 50%) |
| Whetstone | edge | +15% crit chance, +30% crit damage |
| Blood Chalice | life | Lifesteal 4% |
| Ward Stone | ward | Start each fight with a shield of 25% max HP |
| Hourglass | tempo | +20% attack speed |

## 7. Resonances (3 in the MVP)

Resonances are **tag rules**, not pairs of specific relics. A future relic tagged `ember` automatically works with every ember Resonance. That is how the game scales to hundreds of relics without code changes.

| Resonance | Tags | Effect |
|---|---|---|
| Thermal Shock | ember + frost | Freezing a burning enemy shatters it for 150% of its remaining Burn damage |
| Arc Storm | storm + chain | Every 4th attack arcs to 2 more enemies (80% ATK) and Shocks all enemies |
| Crimson Edge | edge + life | Crits heal 3% max HP; overhealing becomes a shield (up to 20% max HP) |

The Codex shows undiscovered Resonances as silhouettes; discovering one pays gems.

## 8. Enemies (biome 1: Lantern Shrine Ruins)

| Enemy | Role | Notes |
|---|---|---|
| Moss Slime | normal | Plain bruiser |
| Ember Imp | normal | Fast; can Burn the kitsune |
| Stone Sentinel | normal | 30% armor (Burn counters it) |
| Lantern Wisp | normal | Flare for 150% ATK every 4 s |
| Ruin Brute | elite | Enrages below 50% HP (+30% attack speed) |
| Gatekeeper Golem | boss | Slam for 250% ATK every 6 s; enrages below 50% HP |

Enemy stats scale ×1.40 per chapter and +6% per room.

## 9. Progression (milestone M2; formulas in `docs/ECONOMY.md`)

- **Hero level** (gold), capped by progress: max level = 10 + 6 × highest chapter cleared.
- **Training** (gold): Might (+ATK%), Vitality (+HP%), Finesse (crit).
- **Gear** (3 slots: weapon, charm, robe), 3 rarities in the MVP. Enhance with gold; merge 3 identical items into the next rarity.
- **Relic attunement** (shards): permanent potency per relic.
- **Codex**: relics and Resonances discovered.
- **Recommended Power** shown for each chapter, so players know when to farm.

Pacing (economy simulation on the real code, see `docs/ECONOMY.md`): chapters 1–10 fly by on day 1–3, chapter 20 around days 5–10, and the 30 launch chapters take free players about a month. After that progress keeps going, but more slowly.

## 10. Screens (MVP)

Bottom tabs: **Shop · Hero · DELVE (centre) · Codex**, plus settings.

- **Camp:** chapter card, Recommended Power vs your Power, offline chest, currency bar.
- **Expedition:** room track 1–10, battle stage, door choice, relic draft overlay, relic bar, speed (1×/2× free).
- **Results**, **Hero** (level, training, gear), **Codex**, **Shop** (simulated in the MVP), **Settings** (audio, reduced effects, screen shake, text size).

## 11. Differentiators

| Feature | Value | Cost | When |
|---|---|---|---|
| Tag-based Resonances | Core identity, scalable content | Done in M1 | MVP |
| Kitsune tails | Visible power, mascot hook | Small–medium | MVP (in-run), v1.0 (permanent) |
| Resonance Codex with silhouettes | Collection and experimentation | Small | MVP |
| Echo Keepsake | Losing feels productive | Small | MVP |
| Chord audio feedback | Distinctive feel | Small–medium | MVP (basic) |
| Rift Seed weekly challenge | Retention; cheap thanks to determinism | Medium | v1.1 |
| Fair Arena (async PvP, normalized stats) | "No pay-to-win arena" | Large | After retention is proven |

## 12. MVP scope

**In:** the items above, with 1 biome × 5 chapters, local save, offline rewards, a simulated shop, a debug panel, analytics events logged locally, English text via the localization system.

**Out:** real purchases, backend, accounts, cloud save, ads, PvP, daily missions, a second hero, cosmetics, events, push notifications.
