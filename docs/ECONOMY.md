# Economy and monetization

All numbers are hypotheses to be tested. Formulas live in data and are tuned with simulations, playtests and, later, real player data.

## Currencies (three only)

| Currency | Earned | Spent | Notes |
|---|---|---|---|
| **Gold** | rooms, bosses, first clears, offline rewards, gold caches | hero level, training, gear enhancement | Main gameplay currency |
| **Gems** | first clears (30), Codex discoveries (20 per relic, 50 per Resonance), achievements, later daily missions; purchases | Gold Cache, Shard Cache, revive, cosmetics, hero unlocks | Paid and free gems are tracked in separate buckets; free gems are spent first |
| **Relic Shards** | every run (more for wins), bosses | relic attunement | Can appear in bundles |

Rules: never add a currency to make prices confusing (FTC v. HoYoverse 2025; EU CPC principles). Gem-priced items show an approximate real-money value ("≈ $X") computed from the store's localized gem-pack price.

## Formulas (tuned with `tools/economy_sim.gd`; live in `data/progression.json` and `data/gear.json`)

| System | Formula |
|---|---|
| Enemy stats | base × 1.40^(chapter−1) × (1 + 0.06 × (room−1)); elite and boss defined in data |
| Hero level | stats × 1.06^(L−1); cost 60 × 1.09^(L−1) gold; **max level 10 + 6 × best chapter** |
| Training | +3% per rank (Might ATK, Vitality HP), Finesse +0.4% crit chance / +1.5% crit damage; cost 90 × 1.18^rank (Finesse 120 × 1.20^rank) |
| Gear | rarity multiplier (common 1×, rare 1.8×, epic 3.2×); +6% per enhancement level (cap 10/20/30); cost 40 × 1.14^level; merge 3 → next rarity |
| Relic attunement | +8% potency per level (max 30); cost 8 × 1.45^level shards |
| Gold per room | 3 × 1.36^(chapter−1) (elite ×2.5, boss ×12); replays pay 60%; first clear +3× boss gold |
| Shards | 2 per room won (+10% per chapter), +15 for beating the boss |
| Offline | 3% of active farming rate per minute, 12 h cap; never gems |
| Gold Cache (5 per day: 100, 150, 200, 300, 400 gems) | One cache = 60 minutes of farming gold at your best chapter (scales with progress, no inflation) |
| Shard Cache (3 per day: 100, 150, 250 gems) | One cache = 60 minutes of winning runs' shards at your best chapter |

Why these numbers: a cap of 4 levels per chapter gave free players a hard wall around chapter 21 that extra play could not move. A cap of 7 (1.06⁷ ≈ 1.50× per chapter, more than the enemies' 1.40×) ran away. With 6, levels stay cost-limited, and income versus cost per chapter gives a gentle, growing grind.

### Simulated pacing (Godot, real game code)

`tools/economy_sim.gd -- --days=90 --seeds=2` (median of 2 seeds), with the real shop rules: gems buy Gold Caches (5 per day at 100, 150, 200, 300, 400 gems) and Shard Caches (3 per day). Day on which the chapter was first cleared:

| Archetype (play/day, spend) | Ch 3 | Ch 5 | Ch 10 | Ch 15 | Ch 20 | Ch 25 | Ch 30 | Chapter on day 7 / 30 / 90 |
|---|---|---|---|---|---|---|---|---|
| Casual free (15 min, $0) | 1 | 1 | 3 | 6 | 11 | 18 | 31 | 16 / 30 / 39 |
| Active free (50 min, $0) | 1 | 1 | 2 | 4 | 6 | 11 | 20 | 24 / 33 / 40 |
| Occasional spender (20 min, $5 starter + $5/mo) | 1 | 1 | 2 | 5 | 7 | 13 | 24 | 21 / 33 / 40 |
| Regular spender (45 min, $30/mo) | 1 | 1 | 2 | 4 | 5 | 8 | 14 | 25 / 36 / 44 |
| High spender (75 min, $150/mo) | 1 | 1 | 2 | 3 | 4 | 6 | 8 | 29 / 42 / 50 |

What this means:
- **Onboarding is generous** (chapter 10 within 2–3 days for everyone).
- **Free players finish the 30 launch chapters in 3–4 weeks**, then keep progressing more slowly. That fits a content update every 4–6 weeks.
- **Spending accelerates without skipping:** a regular spender is about 1.4× faster to chapter 30 than an active free player, and a high spender about 2.5× (it was about 4× before the cache limits). By day 90 the high spender is 10 chapters ahead, partly because that bot also plays 50% longer.
- The daily limit binds only for heavy spenders: $150/month buys roughly 3 caches a day.

Read with care: these are bots with fixed habits, not people, and only 5 chapters have unique content today (simulations reuse chapter 5's enemies above that).

## In-app purchase catalog (hypotheses)

Gem ladder (about 88 gems per $): $0.99 = 80, $4.99 = 420, $9.99 = 880, $19.99 = 1,800, $49.99 = 4,700, $99.99 = 9,800. The first purchase of each tier gives double gems, once.

| Product | Price | Contents | When shown | Value vs gem rate |
|---|---|---|---|---|
| Starter Pack (one-time) | $4.99 | 600 gems, a specific Epic weapon, 200 shards | After the first boss **win**; removed at chapter 10 (disclosed) | ~3.8× |
| Tail Ledger (milestone fund) | $9.99 | Premium rewards at chapters 2–30 (~4,500 gems + 1,000 shards); claimable retroactively | Chapter 3 | ~5× |
| Fox Charter (30-day pass, not auto-renewing) | $4.99 | 300 gems now + 90/day (unclaimed days bank up to 7); +4 h offline cap | Chapter 5 | ~6.8× |
| Swift Paws (permanent) | $4.99 | 3× speed + auto-repeat farming | Chapter 4 | convenience |
| Relic Attunement Bundle | $19.99 | 3,000 shards + 1,000 gems; max 3 per month | Attunement unlocked | ~2× |
| Equipment Bundle | $24.99 | A specific Epic set + enhancement gold | First Epic merge | ~2× |
| Tail & fur skins | $4.99–$24.99 | Cosmetic only | Post-launch | — |
| Hero Bundle | $14.99 | Hero 2 + skin + 1,000 gems (hero 2 is also earnable free) | When hero 2 ships | — |

**Presentation rules**
- Shop sections appear when their system unlocks.
- Each product gets at most one intro popup ever, on Camp after a win, never after a loss.
- No fake countdowns. "Value" labels are computed against the stated gem rate.
- Prices always come from StoreKit / Play Billing (localized), never hardcoded.
- Optional player-set monthly spending limit and a purchase history screen.
- Price tests run by region or time window, never personalized per user.

**Deferred:** rewarded ads (test at soft launch, opt-in only), season pass (needs a content cadence), energy (only if data demands it). **Never:** paid random rewards.

## Revenue scenarios (assumptions, not predictions)

Assumptions: ~10% tax, 15% store fee (Apple Small Business Program; Google's new US/UK/EEA rate cards are split into a service fee plus a 5% billing fee, so verify in Play Console), 2% refunds, ~$45/month fixed costs.

| Scenario | Payers / MAU / month | Purchases per payer | Avg purchase | Net per MAU |
|---|---|---|---|---|
| Conservative | 1.0% | 1.4 | $7 | $0.073 |
| Base | 2.0% | 1.8 | $10 | $0.270 |
| Optimistic | 3.5% | 2.2 | $13 | $0.750 |

| Net target / month | Conservative | Base | Optimistic |
|---|---|---|---|
| $100 | 2.0K MAU | 540 | 190 |
| $1,000 | 14K | 3.9K | 1.4K |
| $5,000 | 69K | 19K | 6.7K |
| $10,000 | 137K | 37K | 13K |

In the base case, $10K/month means roughly 25K new installs every month. At about $0.40 lifetime value per install, paid user acquisition only pays off if real metrics beat the base case. The plan is store-page optimization and organic growth first; paid UA only after lifetime value has been measured.

## Metrics to instrument

M4 ships a local play log (debug builds only, `src/services/analytics.gd`): `session_start`, `run_start`, `run_end`, `level_up`, `purchase`, `purchase_failed`, `offer`. A network sink with consent comes in M6. Full target list:

Engagement (D1/D7/D30, sessions, chapter funnel, boss win rates, where players quit), economy (sources and sinks by reason, upgrade frequency, relic pick and win rates, Resonance discovery), revenue (conversion, ARPPU, revenue by product, repeat purchases, refunds).
