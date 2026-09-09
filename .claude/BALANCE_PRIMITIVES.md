# PP Balance Primitives & Constraints

## Purpose

This document defines the parts of Pixel Pugilists' combat system that should stay stable while content is authored and rebalanced around them, and separates them clearly from the content itself, which is expected to change constantly.

It is **not** a snapshot of the current meta. It does not record what the 16 starting familiars currently do, how strong they currently are, or what their current win rates are — those numbers are already stale the moment more content is added, and this document should not need to change just because they moved. `DEVLOG.md` and the `balance_reports/` CSVs are where that history lives.

Hand this document to a future session (human or Claude) with the instruction: *"Create or rebalance content freely, but stay within these constraints and principles unless you can show one of them needs to change."*

## Balance Philosophy

Pixel Pugilists' combat is a **contest of authored kits**, not a stat-scaling game. The interesting decisions are almost entirely in *how* a kit's pieces relate to each other and to the priority-rule system that pilots it, not in whether one number is 8% bigger than another. Two consequences follow from that:

1. **The numeric language matters more than the numbers.** A small, recognizable set of damage steps, stat ranges, and stack-count conventions lets a player (and a future author) read a new technique's rough power level at a glance, the same way a fighting game's "light/medium/heavy" nomenclature does. Blowing past that vocabulary with arbitrary decimals or wildly divergent stat spreads erodes that legibility even if any single value in isolation is "balanced."
2. **Interaction density matters more than raw efficiency.** A kit whose pieces read and write shared state (statuses, triggers, turn/battle history once it exists) is more interesting to build around and more resilient to being "solved" than a pile of individually-efficient, isolated numbers. See the Pebbloq section below for a concrete existing example of this, and the Content Authoring Rules section for how to apply it to new content.

The system is still small (16 familiars, 32 techniques, ~16 passives as of this writing) and is expected to grow by a large factor. Nothing about the *current* content pool's shape should be read as a target to preserve — see "What This Document Does NOT Protect."

## Qualitative Content Design Benchmark

**Pebbloq's actual current kit** (`resources/familiars/pebbloq.tres` + its two techniques + its passive, read directly for this document, not assumed) is used here as a worked example of what dense, well-integrated kit design looks like in this engine. Its numbers are not the point — the *shape* of how its three pieces relate is.

**The kit, as implemented:**

- **Chronoparry** (the catch-all fallback — no conditions, so it fires whenever nothing else does) applies three statuses to itself in one activation: 1 stack of Defending (doubles Defense, consumed on the next hit taken), 2 stacks of Stasis (negates the next 2 status-reduction events), and 1 stack of Ward (absorbs the next 1 stack of an incoming status). One technique activation creates three independent pieces of persistent state at once.
- **Timeline Collapse** is gated by a priority rule that checks two of those three pieces directly — *"self has Defending > 0 AND self has Ward > 0"* — so it only fires while Chronoparry's setup is still substantially intact. Its own effect is a single Hit action whose damage gets a **+200% bonus scaled by `STATUS_COUNT`** (the number of distinct active statuses on the user) — a signal that happens to be highest right after Chronoparry just ran, since Stasis, Ward, and Defending are all still up.
- **Ancient Sentinel** (the species passive) triggers on `STATUS_REDUCED`, filtered specifically to the user's own Stasis, once per turn — i.e., precisely the moment Stasis actually does its job (absorbs a reduction that would otherwise have stripped something else). Its payload is a stack of Hone (a stat buff) on the user. This turns a purely defensive event (something *not* happening to another status) into an *additional* offensive payoff.

**What makes this a good reference, independent of its numbers:**

- **One setup technique creates several readable state variables at once**, rather than one technique doing one thing. Defending, Stasis, and Ward each mean something different and each get read independently elsewhere in the kit.
- **The payoff technique's gate and its scaling read *different* (overlapping but not identical) subsets of that state** — the gate cares about two specific statuses being present at all; the scaling cares about the total count, which happens to include a third. This is richer than "if Buffed, deal bonus damage."
- **The passive converts a purely defensive event into an additional payoff**, rather than being a flat, always-on number. It changes what Stasis *means* (it's no longer just a shield; it's a shield that pays out when it works), which is a different kind of leverage than "this passive adds +2 Power."
- **The kit creates a real priority-rule decision, not just a fixed rotation**: Timeline Collapse's own conditions mean the fallback (Chronoparry) reapplies automatically once the opponent has broken through (consuming Defending on hit, or spending Ward's absorption), without needing an explicit "if I don't have the buff, re-buff" rule authored by hand. The *structure* of the two rules produces the rhythm; no rule had to spell it out.
- **Its pieces are not sealed off from the rest of the game.** Ward, Defending, and Stasis are all shared, roster-wide statuses — anything the player later drafts that reads or writes any of those three (a technique that punishes a Warded target, a passive that cares about Stasis, a status-count payoff on an entirely different familiar) interacts with this kit's state without either side needing to know about the other by name. Compare this to a hypothetical kit that invents a bespoke, single-use status just for itself — that would be a closed loop, not an open one.

**Do not** conclude every familiar should look like this. A pure-aggression kit with no setup, a status-stacking DoT kit, a tempo/Speed kit, and a scaling-payoff kit are all legitimate and should feel different from Pebbloq and from each other. The property to chase is the *density and legibility* of the interactions, not this specific defensive-setup shape. See Content Authoring Rules for the extracted, reusable version of these principles.

**Why this is the healthy pattern, not a borderline case of the red flag below:** Timeline Collapse's `NumericBonus` scales off `STATUS_COUNT`, which sounds superficially like "a payoff scaling off state this kit created" — the same shape as the compounding-loop red flag in Scaling and Accumulation. It isn't the same thing, and the distinction is worth being precise about, because it's the difference between the core setup/payoff loop this whole game is built on and the thing that loop must *not* turn into:

- The fuel (Ward/Stasis/Defending) is created by a *different* technique (Chronoparry), not by Timeline Collapse itself — Timeline Collapse only reads the count, it never adds to it.
- The fuel is externally consumable: the opponent hitting Pebbloq spends Defending, the opponent applying a status spends Ward. There is real counterplay that drains the exact quantity the payoff scales from.
- Nothing here regrows on its own turn over turn without Chronoparry running again, and Chronoparry itself is the unconditioned fallback, not a free action.

The actual red flag (below) is narrower: a technique whose payoff scales from a quantity that *the same technique's own repeated use* keeps adding to, with no decay and no opposing-side lever to drain it — a closed loop that gets stronger every activation with nothing outside it able to stop that growth. Pebbloq's kit is a clean instance of the *first* pattern (separate setup and payoff, externally interruptible fuel), not a mild instance of the second. Don't read "scales off status count" alone as the risk signal — read whether the fuel can be created, spent, and denied by pieces *other than* the one harvesting it.

## Stable Numeric Language

Everything in this section is a **Balance Primitive (A)** unless explicitly marked otherwise. Content-specific numbers (a particular technique's exact multiplier, a particular familiar's exact stat) are never appropriate here — only the shape of the language they're drawn from is.

### Damage

**Confirmed from implementation** (`Technique.apply_hit()`, `scripts/technique/technique.gd`):

```
raw_technique_damage = int(user_power * power_multiplier)
raw_damage = raw_technique_damage + numeric_bonuses
post_mitigation = (raw_damage * raw_damage) / (raw_damage + target_defense)   # integer division — floors
damage = max(post_mitigation, 1)                                             # hard floor of 1
```

- **`power_multiplier` band (Current Tuning Convention — B):** established steps are **0.1** (chip), **0.333** (small), **0.667** (medium), **1.0** (a strong standard hit), and **1.5+** as an authored, uncapped "burst territory" band rather than a single further step. Prefer landing on one of these over an arbitrary decimal (0.74, 0.82, 1.13, ...); if none fits, that's worth a deliberate decision, not a rounding error.
- **`ignore_power_and_defense` hits** (flat damage, e.g. a percent-of-max-HP-style effect) read `power_multiplier` as a literal flat integer amount instead of a scalar: `damage = max(int(power_multiplier) + bonuses, 1)`. Author these with small whole numbers (1–5ish), not the 0.1–1.5 fractional band — they're a different sub-language, not a continuation of the same one.
- **Damage floor and rounding (Primitive):** every hit deals at least 1 damage, and the mitigation formula truncates (never rounds up). Multi-hit techniques exploiting the floor against very high Defense are an expected, intentional property of the system, not a bug to design around.

### Stats

**Confirmed from implementation** (`familiar.gd` defaults; full 16-familiar roster surveyed directly for this document):

- Default stat line if unset: `max_hp=50, power=10, defense=5, speed=10, focus=10`.
- **Actual roster spread, Power/Defense/Speed/Focus:** Power 5–11, Defense 3–16, Speed 5–13, Focus 5–15 — i.e., the whole roster already sits inside the stated **2–20 band (Primitive)** for these four stats.
- **Max HP is explicitly a separate scale, not part of the 2–20 band:** the actual roster ranges **40–75**. The 2–20 primitive as stated in this document's brief applies to Power/Defense/Speed/Focus; HP's own primitive range is documented separately below. Treating HP as if it belonged to the same 2–20 language would be a misreading of the current implementation — flagging this explicitly rather than silently assuming one or the other.
- **Stat-upgrade increment (Current Tuning Convention — B):** the existing reward-pool stat upgrades grant **+2** to Power/Defense/Speed/Focus and **+15** to Max HP per pick (`resources/upgrades/increase_*.tres`). Note the *relative* impact of a flat +2 varies enormously across the roster as authored today — +2 to a base-3 Defense (Twerpent) is a 67% increase, +2 to a base-16 Defense (Mallegrav) is 12.5% — this is an existing, unaddressed asymmetry worth knowing about rather than a hidden assumption, not necessarily a bug.

### HP

- **Primitive:** HP is a spendable/restorable resource pool (per `GAME_DESIGN.md` §5.2), not merely a loss counter — techniques that spend the user's own HP as a cost, or that treat HP thresholds as a meaningful state (see Focus-adjacent threshold design below), are an intended part of the design space, not an edge case.
- **Current Tuning Convention (B):** starting Max HP roughly **40–75** across the roster.

### Defense

**Confirmed from implementation**, restated for clarity as a standalone primitive since it's the piece most likely to be reasoned about incorrectly:

- Defense is a **contest**, not a percentage armor stat. Mitigation is `raw² / (raw + defense)`, which means:
  - **Defense == incoming raw damage → ≈50% mitigation** (exact at the algebra level; floored in practice by integer division).
  - Defense performs **better against fewer, larger hits** and **worse against many smaller hits** — splitting the same total damage budget across more hits systematically deals more total damage into a fixed Defense value, because each individual hit's mitigation ratio is worse than one big hit's. This is a structural property of the formula, not a balance choice that could be "fixed" by retuning a constant — any multi-hit-vs-single-hit reasoning about a new technique should account for it directly.
  - The 1-damage floor per hit means Defense has a **hard ceiling on how much a single hit can be reduced**, regardless of how large Defense gets — an attacker can never be fully walled out by Defense alone if they can land hits at all.
- **Healing shares the same shape** (see below) — a heal's base amount is computed as if it were a hit against the *healer's own* Defense-equivalent mitigation, then converted to healing. This is a real, if slightly surprising, consequence of `apply_heal()`'s implementation and worth knowing before assuming heal scaling is independent of the damage formula.

### Focus

- **Primitive (per `GAME_DESIGN.md` §5.2):** Focus is a **threshold stat**, not a linear scaling stat — fixed breakpoints unlock fixed bonuses, rather than "more Focus = proportionally more of X." Content built around Focus should care about hitting specific goals (a tier, a parity check, a range), not about maximizing Focus as if it behaved like Power.
- **Current Tuning Convention (B):** one shared `FocusTable` (not per-familiar), currently four tier-gated effects at breakpoints 5/10/15/20. The roster currently only reaches Focus 15, so the tier-20 effect is inert for everyone today — this is unreached content, not a bug, and not evidence the breakpoint itself is wrong.
- This whole area (along with the Speed timing model) is explicitly marked **OPEN / PLAYTEST** in `GAME_DESIGN.md` §5 — treat the *shape* (thresholds, not scaling) as the stable primitive, but not any specific breakpoint value or the exact number of tiers as locked.

### Healing / Sustain

- **Confirmed from implementation** (`Technique.apply_heal()`): `heal_amount = int(damage_as_computed_above * heal_percent) + heal_flat + bonuses`, where the "damage" fed in is computed against the *target's* (i.e., the healer's own, since heals are typically self-targeted) Defense the same way a hit would be — meaning heal output is implicitly gated by the healer's own Defense stat, not just Power.
- **Primitive (design intent, not yet a hard cap in code):** healing/sustain must not be capable of producing an unbounded equilibrium against offense — see Defensive/Sustain Constraints and Red-Flag Patterns below. This is a constraint on *what gets authored*, since the engine itself does not currently enforce any global healing cap.

### Statuses

- **Primitive:** the base `Status.stack_with()` behavior is **uncapped addition** (`stacks += other.stacks`) unless a subclass overrides it. Only Acid, Stagger, and Absorption clamp via `min()`; Burn refreshes-to-max rather than adding; Foretell's reapplication is a no-op. Every other status in the game (Poison, Bleed, Infestation, Hone, Fortify, Enlarge, Ward, Retaliation, Stasis, Renewal, Lifesteal, Regeneration, Thorns, Hex, Ruin, Recharge, ...) has **no stacking cap at all** today. This is a real, systemic property of the engine, not a per-status oversight — see Scaling and Accumulation and Red-Flag Patterns for how to reason about it when authoring new content.
- **Current Tuning Convention (B) for stack counts:** existing content mostly authors small, fixed stack counts (1–5 typical; Foretell's 20 in the final boss's kit is a deliberate, documented outlier tied to a slow decay). No single "small/medium/large" stack-count band is well-evidenced yet across enough content to assert with confidence — see Evidence/Open Questions.
- Status *application itself* has value independent of its direct numeric effect, because it creates persistent, readable state — see Interaction Surfaces.

### Recharge / Cooldowns

- **Confirmed from implementation:** Recharge is a plain stack-count status that loses 1 stack per turn on its own tick, with no other mechanical effect *by itself* — its actual cost is enforced by other content choosing to check for it (its own doc comment: "any technique that applies recharge to the user has extremely diminished effect \[...\] if the user is already recharging"). This means Recharge's balance weight today lives entirely in *how much content actually respects it*, not in the status object itself.
- **Primitive:** anything that reduces, bypasses, or ignores Recharge (for the user reducing their own, or transferring/copying another combatant's Recharge state) is a genuine action-economy lever and should receive the same scrutiny as extra actions in general — see Action Economy and Red-Flag Patterns.

### Action Economy

- **Primitive:** one turn / one technique activation is the fundamental balance unit. A technique's `TechniqueStepGroup.repeat_count` lets a single activation execute its actions multiple times in one turn — **confirmed from implementation that each repetition independently fires its own HIT/ATTACK/STATUS_APPLIED hooks** (i.e., a repeat_count-3 hit technique triggers three separate ATTACK events, not one), so multi-hit techniques are already a real, working way to generate extra trigger events per turn, not just extra raw damage. See Multi-Hit and Per-Hit Effects.
- **Planned, not yet implemented (per the developer's own roadmap):** persistent turn-scoped state such as "did I hit more than once last turn" or "did the enemy take status damage this turn" does not exist yet as combatant-level signals — today, only a `PassiveEffect`'s own `Limiter` (e.g. `ONCE_PER_TURN`) can gate *that specific passive's* firing rate; there is no general-purpose "how many times did X happen this turn" counter other content can read yet. Don't assume this signal exists until the roadmap's step 3 lands it.
- **Fusion/Linking (planned, not yet implemented):** two techniques executing together under one shared priority rule, at the cost of losing independent conditions for the fused pair. Treat this, once built, as a genuine action-economy multiplier requiring the same scrutiny as repeat_count or Recharge-bypass — especially in combination with either.

## Setup, Payoff, and Efficiency

**Primitive:** raw damage-per-turn is not, by itself, a valid way to evaluate a technique. A technique that requires prior setup (its own earlier turns, a status it needed present, a narrow HP/Focus/turn-order condition, consumed accumulated stacks) is allowed to exceed ordinary one-turn efficiency in exchange for that investment, the same way Pebbloq's Timeline Collapse only reaches its full multiplier once Chronoparry has run.

When evaluating (or authoring) a payoff technique, ask what it actually *cost* to enable:

- How many prior turns/actions did it require?
- Was there a window where the setup could have been punished or wasted (opponent removes the status, opponent doesn't cooperate, fight ends before payoff)?
- Is the payoff's scaling bounded by something that itself decays or has a natural ceiling (see Scaling and Accumulation), or could it in principle run away?

A technique that gets Pebbloq-style leverage (Timeline Collapse's +200%) with *no* real setup cost, no gating condition, and no way for the opponent to interrupt it is not the same kind of design and should not get graded on the same curve.

## Interaction Surfaces

The concrete, currently-implemented ways one piece of content can read or affect state another piece of content created:

- **Statuses** — the primary surface today. `NumericBonus.ValueSource` already lets a technique's own bonus read `STAT`, `STATUS_STACKS` (a specific status, or all statuses summed via `percent_check_all`), `STATUS_COUNT`, or `HP` — of either the user or the target (`percent_target`). `StatusComparisonCondition`/`HpComparisonCondition` let priority rules gate on the same categories. This is genuinely rich already — a large fraction of "interaction density" in current content comes from this one mechanism.
- **`PassiveEffect` triggers** — `STATUS_APPLIED`/`STATUS_REDUCED`/`STATUS_REMOVED`/`STATUS_CREATED`, `BATTLE_START`/`BATTLE_END`, `TURN_START`/`TURN_END`, `HIT`/`ATTACK`, `TECHNIQUE_USED`, `DAMAGE_DEALT`/`DAMAGE_TAKEN`, `HEALED`. These are events, not state — a passive reacts to something *happening*, which is a different (and currently underused, per the roadmap) surface than reading a status's current stack count.
- **Technique/passive `tags`** — a flat set of `RewardTag.Tag` values authored per technique/passive, currently consumed only by the reward-drafting system (`RewardSelector`) to judge relevance/synergy for what gets offered, not by combat logic itself. This is an interaction surface for *drafting*, not for *combat*, and shouldn't be conflated with the combat-facing surfaces above.
- **Combat history / turn history — planned, not yet implemented.** The roadmap's step 3 (persistent battle state, turn-scoped state, more events/signals) is explicitly about building this surface out further. Until it lands, don't assume a technique can read "how much damage did I do last turn" or "how many turns has this fight lasted" — it can't, today.

**Authoring implication:** plain, un-gated raw-damage techniques with no status application at all are still expected to exist (a straightforward aggression archetype needs them), but per the developer's own stated direction, they should still have *some* way to participate — via tags for drafting synergy at minimum, and via the events/history surfaces once those exist — rather than being pure isolated numbers forever.

## Kit Interaction Density

**A load-bearing question, refined after auditing the actual roster against an earlier, blunter version of this paragraph: how many genuinely distinct pieces does this engine need to complete its own loop, AND does what it produces grow in frequency or in magnitude?** A closed engine that needs nothing external (no second technique, no passive, no opponent action) to keep running is **not automatically a problem** — a real, audited example (Berylazagor: Regeneration+Lifesteal+Gnashing Maw's own heal all feeding a passive that fires a *fixed* flat amount) shows a fully self-contained loop can be a legitimate, intended build-around reward as long as the payout size never grows, only how often a fixed amount fires. The actual danger is a self-contained loop whose payout keeps getting *bigger* from its own repeated use with nothing external able to stop it (an audited real example: Guubal's Acid cap permanently rising every reapplication, feeding an ever-larger percent-of-stacks payoff) — see Scaling and Accumulation for the full frequency-vs-magnitude test.

**Starting-kit target, distinct from the above test: a starting familiar's kit (its 2 techniques + 1 species passive) should generally need *all three* of those pieces cooperating to form its real engine**, matching Pebbloq's Chronoparry + Timeline Collapse + Ancient Sentinel shape. Treat needing only 2 of the 3 pieces from the very start as under-using the kit's own design budget, not as an acceptable minimum. A build that a player has invested a run's worth of drafted upgrades into *earning its way down to* only needing 2 pieces to run the same engine (a passive picked up mid-run that makes one starting piece redundant, say) is a real, satisfying payoff for that investment — but that's a property of where a *built-up* kit can arrive over a run, not a lower bar for what a *starting* kit should already be.

What separates an "interconnected" kit from "a pile of individually efficient effects" (using Pebbloq as the worked example above):

- **Does one piece create state that another piece reads?** (Chronoparry → Timeline Collapse's gate and scaling.)
- **Does a passive change how a technique gets *used or valued*, rather than just adding a flat number?** (Ancient Sentinel turns "Stasis blocked something" into a payoff, rather than being "+2 Defense, always.")
- **Do the pieces, taken together, create a real priority-rule decision** — a rhythm or branch that falls out of the conditions themselves, rather than a single fixed rotation authored by brute-force ordering?
- **Are the shared pieces (statuses, tags) generic enough that content from *outside* this kit could plausibly read or write them too?** A kit that only works because it invented a bespoke, single-use mechanic just for itself is a closed loop; a kit built from shared vocabulary (Ward, Stasis, STATUS_COUNT, ...) stays open to whatever gets drafted alongside it later.

A kit does not need every technique to hit all of these to be good — an aggressive kit's basic attack can just be a basic attack. What's being asked for is that *somewhere* in a kit's 2 techniques + 1 passive, there's at least one real instance of state being created and read across pieces, not that every single piece must participate.

## Multi-Hit and Per-Hit Effects

- **Confirmed:** each hit inside a `repeat_count > 1` step group independently triggers its own ATTACK/HIT (and DAMAGE_DEALT/DAMAGE_TAKEN) events. A passive with `Limiter.NONE` reacting to `HIT` will fire once *per hit*, not once per turn — this is correct, existing engine behavior, and is a real source of extra value for multi-hit techniques beyond their raw summed damage.
- **Authoring implication:** when evaluating a multi-hit technique, account for both (a) the total damage across all hits against the Defense-contest formula (worse per-hit mitigation than one big hit of the same total, per the Defense section above) and (b) how many times it re-triggers any reactive passive/status either side holds (Thorns, Retaliation, Ward-consumption, a future "once per hit" passive) — a 3-hit technique against a Thorns holder takes Thorns damage three times, not once.
- **Red flag:** a passive or status meant to fire "once per turn" that has no explicit `Limiter` and is gated on a per-hit trigger (`HIT`/`ATTACK`/`STATUS_APPLIED`) will silently fire once per hit instead. This has already been a real bug source in this codebase (see `CLAUDE.md`'s documented pitfalls around passive limiters and reentrant triggers) — always ask explicitly whether a new passive's intended cadence is "per event" or "per turn" and set its `Limiter` accordingly.

## Defensive / Sustain Constraints

**Primitive:** infinite or near-infinite equilibrium is a design failure, full stop. Defensive mechanics exist to buy time, shift tempo, or mitigate damage — never to create permanent stability that offense structurally cannot break through given enough turns.

**The test is empirical, not categorical: does the fight actually resolve?** A defensive or sustain mechanic that scales — even one built on an uncapped stat or status — is fine *as long as it's paired with enough offense (from either side) that fights still resolve inside a reasonable turn count* (see Fight Duration Targets). "This scales" is not itself the red flag; "this produces a stalemate" is. A kit that stacks Defense every turn but still has to attack to win is a legitimate scaling-defense archetype, not a violation — check its actual fight lengths in simulation before assuming it's a problem.

Concretely, be especially cautious around:

- Uncapped healing or lifesteal that keeps pace with or exceeds *realistic* incoming damage, to the point that HP totals stop trending toward zero.
- Mitigation (Defense buffs, Absorption, Ward) that can be refreshed indefinitely faster than it decays or gets consumed, **if** the same kit (or its opponent) has no way to close the fight out regardless.
- Any combination of the above that, played out to its logical extreme, produces a fight that cannot resolve inside a reasonable turn count.

**Required property for any new defensive mechanic:** it needs a plausible path to *not* stalling — either its own decay/cap, or simply that the kit carrying it still deals real damage on the way to using it. A kit that is 100% defense with zero offense is the actual failure mode, not "a kit with strong, scaling defense." Verify with simulation (Fight Duration Targets) rather than asserting from reading the numbers alone.

## Scaling and Accumulation

- **Primitive:** since most statuses have no stacking cap (see Statuses above), any payoff that scales off a status's *stack count* is implicitly scaling off an uncapped quantity today. This is not automatically wrong — Pebbloq's own STATUS_COUNT scaling is bounded in practice because its source statuses are all small, fixed applications — but it means the *bounding has to come from somewhere else* (a capped application size, a natural decay, a limited number of turns before the fight ends) rather than from the status system itself.
- **The load-bearing distinction, confirmed by auditing the actual 16-familiar roster against an earlier, blunter version of this rule: does the payoff's *frequency* increase, or does its *magnitude* increase without bound?** These look similar (both involve "a self-contained piece firing repeatedly, no opponent needed") but only one is the real red flag:
  - **Frequency-scaling a fixed payoff is fine, and is exactly the kind of build-around synergy this game wants.** A passive that fires a flat, unscaling amount every time some event happens, where the *number* of qualifying events per turn is small and fixed by the kit's own limited pieces (and grows further only if the player successfully drafts *more* triggering pieces), is a legitimate reward for assembling synergy — not an engine that scales "on its own merit." Confirmed-fine examples from the actual roster: Berylazagor's Malignant Vitality (flat 2 damage per heal event; the number of heal events per turn is fixed by Regeneration/Lifesteal/Gnashing Maw's own bounded cadence, and only grows if more healing gets drafted in later — the intended vector); Ignimite's Protean Purge (flat 5 HP on a slow, cyclical self-Burn→Cleanse loop, magnitude never grows); Omenfly's Portent's Toll (flat 2 damage, bounded to roughly one or two procs per round by Foretell's own natural decay cadence).
  - **Magnitude growing without bound from a single kit's own repeated actions, with nothing external needed to sustain it, is the real red flag.** This means: a scalar quantity (a stat, a stack count, an application's own cap) that has no ceiling, grows every time the same kit uses its own technique, and directly feeds a payoff whose *size* — not just its frequency — increases as a result. Confirmed real examples from the actual roster: Guubal's Corrosive Growth (a passive permanently raises Acid's own stack *cap* by 1 every reapplication, so a status explicitly documented as "capped at 5" never actually plateaus, and that ever-growing count directly feeds a percent-of-total-stacks payoff); Mystbud's Chlorophyll and Thymoxen's Growing Fury (both net-positive, uncapped Hone accumulation per repeatable cycle, directly and linearly inflating Power with nothing to stop it).
  - **Practical test:** if a payoff scaled off this quantity twice in a row, would the *second* instance be worth more than the first (magnitude growing — investigate), or just "another one of the same amount" (frequency — probably fine)?
- **Historical counters** (once combat-history signals exist, per the roadmap) need an explicit ceiling or sufficiently slow accumulation rate relative to typical fight length (see below) — an uncapped "damage dealt this fight" scaling payoff is a real risk the moment that surface is built, and should be designed with a cap or diminishing return from day one rather than retrofitted after a problem shows up in simulation.

## Fight Duration Targets

**Confirmed from a direct simulation run against the full 16-familiar roster** (all 240 ordered pairs, current content, run for this document — not pre-existing recorded data, since the existing `balance_test.gd`/`bracket_test.gd` harnesses track win/loss/stalemate but not turn counts):

| | value |
|---|---|
| Stalemate rate (200-turn cap) | 0 / 240 (0%) |
| Minimum | 5 turns |
| 10th percentile | 7 turns |
| Median | 14 turns |
| Mean | 16.4 turns |
| 90th percentile | 23 turns |
| Maximum (still resolved) | 82 turns |

**Current Tuning Convention (B), derived from the above:**

- A **typical** fight is roughly **7–23 turns** (10th–90th percentile), centered around **14**.
- A fight resolving in **under ~5 turns** is unusually fast — worth a second look if a new technique is consistently producing this, since it suggests very low counterplay.
- A fight running **60+ turns** while still resolving is already a rare tail case in the current roster (only the far end of a 240-match sample reached 82) — a *new* piece of content that reliably pushes fights into this range against a meaningful slice of the roster is worth flagging even before it produces an outright stalemate.
- **200 turns is the existing, already-implemented stalemate threshold** (`balance_test.gd`'s `MAX_TURNS`) — treat this as the operational definition of "stalled" for now, not a value to casually change without evidence a shorter or longer cap serves testing better.

This data reflects **only the current 16-familiar, no-upgrades starting-kit content pool**. It will shift once the AI-drafting/full-run simulation harness (roadmap steps 1–2) exists and can sample built-up, mid-run kits rather than only default starting kits — re-run this measurement once that harness exists rather than assuming these numbers still hold.

## Red-Flag Patterns

Any of the following should trigger deliberate extra simulation/testing before content is considered done, not an automatic rejection. **Most of these are specific instances of one umbrella pattern — a self-contained engine that needs only one piece to both generate and harvest its own fuel, with no second piece and no opponent cooperation required — BUT ONLY when what it harvests grows in *magnitude* over time, not merely in *frequency*.** A closed, opponent-independent loop that repeatedly pays out the same *fixed* amount (an audited real example: Berylazagor's Malignant Vitality firing a flat 2 damage per self-generated heal event) is a legitimate build-around reward, not a red flag — the number of payouts is capped by how many triggering pieces the kit (or a later draft) actually has. What actually needs scrutiny is a self-contained loop where the *size* of each payout keeps growing (an audited real example: Guubal's Corrosive Growth permanently raising Acid's own stack cap every reapplication, feeding an ever-larger percent-of-stacks payoff). Ask "if this fired twice in a row, would the second payout be bigger than the first, or just another one the same size?" before flagging anything below as a real problem.

- **A single technique or technique+passive pair whose payout *magnitude* — not just its frequency — keeps growing from its own repeated use**, needing no second technique, no separate passive, and no opponent action to keep growing. This is the actual red flag underneath most of the entries below; see Kit Interaction Density's leading question ("how many genuinely distinct pieces does this need?"), but remember a closed loop paying out a *fixed* amount repeatedly is not itself the problem — see the framing above.
- Uncapped scaling of a *payoff's own size* (damage, healing, stat bonus that itself grows, not just how often a fixed amount fires) with no cap, decay, or natural ceiling.
- Self-sustaining healing/lifesteal loops (healing that can keep pace with or exceed realistic incoming damage indefinitely).
- Lifesteal combined with burst/multi-hit damage (each hit both damages and heals, compounding both directions at once).
- Permanent or effectively-permanent mitigation (Defense buffs, Absorption, Ward that can be refreshed faster than consumed).
- Recharge reduction/bypass that is large enough, or easy enough to trigger, that Recharge stops functioning as a real cost.
- Repeat-action loops — anything that grants extra technique activations, extra repeats, or extra turns beyond the base one-technique-per-turn unit, especially in combination with each other.
- Fusion/Linking (once implemented) combined with repeats, Recharge-bypass, or extra-action effects.
- A multi-hit effect whose reactive interactions (passives, Thorns/Retaliation, etc.) were evaluated as if they fire once per turn when the engine actually fires them once per hit (see Multi-Hit and Per-Hit Effects).
- Exponential or recursive status scaling — a status whose own growth rate depends on its own current stacks, or two statuses that each feed the other's growth — a single-piece engine wearing a status-system costume.
- A historical counter (once they exist) that can grow without a meaningful ceiling across a realistic fight length.
- Damage scaling from a quantity that itself scales from damage dealt (a self-reinforcing offense loop with no opposing lever) — the single-piece engine again, this time as one technique's own damage feeding its own multiplier.
- Healing based on prior healing (a self-reinforcing sustain loop, the healing-side mirror of the above).
- Two or more defensive passives/statuses that mutually reinforce each other (each makes the other harder to remove or more effective) *without anything external able to break the cycle* — note this one is the one case on this list that technically involves two+ pieces, but they're only interacting with *each other*, not with anything the opponent or the rest of the kit can touch, so it's a closed loop in every way that matters even though it isn't literally single-piece.
- An effect that bypasses more than one opportunity cost simultaneously (e.g., ignores Recharge *and* skips its own setup requirement *and* has no priority-rule conditionality) — stacking several "this one is free" properties onto a single piece of content is a red flag even if each property alone would be fine.

## Content Authoring Rules

Practical rules for designing new techniques, passives, and familiars, refined from the Pebbloq case study above:

1. **Reach for an established damage step (0.1/0.333/0.667/1.0/1.5+) before inventing a new decimal.** If none fits, that's a deliberate decision worth a sentence of justification, not a rounding choice.
2. **A technique that gains substantial utility (status application, defensive value, conditionality-bypass) should generally give up something in exchange** — raw damage, reliability, setup time, or action efficiency. Free utility on top of full damage is the thing to be suspicious of.
3. **A defensive effect needs a legible failure mode.** If you can't say what makes it run out, get consumed, or become punishable, it isn't finished yet.
4. **A payoff that scales over combat history, stacks, or repeated setup needs a cap, a decay, or a fight-length-bounded accumulation rate** — don't ship an uncapped scaling payoff on the assumption "fights don't last that long" without checking that assumption against Fight Duration Targets.
5. **Evaluate multi-hit techniques on two axes**: total damage through the Defense-contest formula (worse per-hit mitigation than an equivalent single big hit), and how many separate trigger events they generate for either side's reactive content.
6. **Status application has value beyond its direct numeric effect** — it creates a persistent, readable piece of state other content (including content from a different kit entirely) can key off. Weigh "did this create something legible and interactable" alongside "how much did it directly do."
7. **When designing a new mechanic, ask explicitly what signals it emits, and what signals it consumes or reacts to** — not just what number it produces. A mechanic that emits nothing readable and reacts to nothing existing is, by definition, an isolated numeric packet, not part of the engine.
8. **Prefer content that participates in several meaningful interactions over content that only contributes an isolated number.** This doesn't mean every technique needs three synergies — it means a whole kit (both techniques + the passive) should have at least one real cross-piece interaction somewhere in it.
9. **A starting kit should generally need all three of its pieces (both techniques + the species passive) to complete its own engine** — Pebbloq's shape, and the target for new starting kits, not merely "at least two." A build that a player earns its way down to only needing two pieces over the course of a run (a drafted passive making one starting piece redundant, say) is a legitimate, satisfying payoff for that investment — but that's a property of a *built-up* kit, not a lower starting bar. Separately: whether a self-contained engine (one that needs nothing external to run) is a red flag depends on whether its payout *grows in size* over time, not merely on whether it's self-contained — a closed loop that keeps paying out the same fixed amount is a legitimate build-around reward (see Scaling and Accumulation's frequency-vs-magnitude test), not automatically suspect. Its pieces should also be built primarily from shared vocabulary (existing statuses, tags, general-purpose conditions), not a bespoke single-use mechanic invented just for this kit, so unrelated drafted content can plausibly interact with it too — see Pebbloq's use of Ward/Stasis/STATUS_COUNT as the model.
10. **Passives should preferably change how a technique gets evaluated, sequenced, or combined**, rather than only adding an unconditional flat bonus — Ancient Sentinel changing what Stasis's own trigger *means* is the model to reach for over "+2 Power, always."
11. **Defensive pieces can be proactive engine components** (creating a signal something else reads, like Chronoparry feeding Timeline Collapse) rather than purely reactive survivability filler.
12. **Techniques should create real priority-rule decisions wherever practical** — a technique whose conditions naturally produce a setup/payoff rhythm, a branch, or a meaningful "should I still be doing this" check is doing more design work than one that's simply always correct to use.
13. **Don't fix weak content by breaking a global numeric convention** — retuning a specific multiplier, stack count, or stat spread is always on the table; deciding a familiar needs a 0.9 power_multiplier because 0.667 and 1.0 both felt wrong is a signal to re-examine the technique's actual design, not license to abandon the numeric language for one piece of content. If the convention itself seems wrong after broad testing, that's a primitive-revision conversation (see below), not a one-off exception.

## What This Document Does NOT Protect

None of the following are constraints this document defends, and none should block a rebalance:

- Exact current familiar win rates or the current round-robin win-rate table.
- Exact technique power multipliers, stack counts, cooldown/Recharge values, or numeric bonus amounts.
- Exact passive trigger conditions or payload strengths.
- Exact familiar stat spreads (including Pebbloq's own).
- The current matchup table or any specific matchup's outcome.
- Current reward-pool rarity weighting.
- The current composition of the technique/passive pool (32 techniques, ~16 passives) as any kind of target size or shape.
- **Pebbloq's exact numeric tuning.** Its role here is entirely as a qualitative example of interaction design — its actual Defense/Speed/HP, its exact stack counts, and its exact damage multiplier are all fair game for a future rebalance pass like anything else in the roster.

These are all Content-Specific Values (tier C) by the classification this document uses, and are expected to move — sometimes substantially — as the content pool grows per the developer's own stated roadmap.

## Evidence / Open Questions

Distinguishing how confident each claim in this document actually is:

**Confirmed directly from implementation (read the code for this document):**
- The damage/mitigation formula and its floor/rounding behavior (`technique.gd`).
- The heal formula's reuse of the same Defense-contest shape (`technique.gd`).
- `Status.stack_with()`'s uncapped-by-default behavior and which statuses override it.
- Recharge's actual (minimal) mechanical effect.
- `NumericBonus`'s four `ValueSource` categories as the current interaction surface.
- The full 16-familiar roster's actual stat spread.
- Pebbloq's full kit (both techniques, its passive, and its priority rules).
- Multi-hit techniques triggering per-hit events, not per-turn.
- The 200-turn stalemate threshold already used by `balance_test.gd`.

**Directly measured for this document (not pre-existing recorded data):**
- Fight-length distribution (min/median/mean/percentiles/stalemate rate) across the full round-robin, current starting-kit content only.

**Inferred from current balance/content patterns, not hard-coded anywhere:**
- The 0.1/0.333/0.667/1.0/1.5+ damage-multiplier band (an established authoring convention, not an engine-enforced rule — nothing stops a `.tres` file from using 0.74).
- The 2–20 stat band for Power/Defense/Speed/Focus (an observed property of the current roster, not an enforced limit).
- Typical stack-count sizes (small/medium/large bands) — genuinely under-evidenced; see below.

**Demonstrated qualitatively by Pebbloq specifically, not (yet) confirmed as a repeatable pattern across other familiars:**
- The "setup creates several readable signals → payoff reads a subset → passive converts a defensive event into an offensive payoff" structure. Worth checking whether any *other* current familiar achieves comparable interaction density, or whether Pebbloq is currently an outlier in kit quality — that in itself would be useful evidence for where the content-pass priority (roadmap step 4) should focus.

**Full-roster audit against the frequency-vs-magnitude test (done directly against all 16 starting kits' actual `.tres` files, not inferred):**
- **Confirmed magnitude-growth engines (the real red flag) — worth a rebalance pass:** Guubal (Corrosive Growth permanently raises Acid's own stack cap every reapplication, feeding an ever-larger percent-of-stacks payoff in Reclaim Byproducts — the clearest case), Mystbud (Chlorophyll → net-positive, uncapped Hone accumulation per Renewal cycle, linearly inflating Power), Thymoxen (Growing Fury → same Hone-accumulation shape via its own Recharge cycle). Ironcap (Ironclad/Fortify) is a lower-confidence fourth case — Fortify is additive/uncapped and Body Press's own bonus scales with the resulting Defense gap, but Fortify also decays each tick, so whether it nets upward over many cycles or self-balances is a genuine open question, not something confirmed from reading the code alone.
- **Confirmed fine — frequency-scaling a fixed payout, a legitimate build-around reward, not a red flag:** Berylazagor (Malignant Vitality — flat damage per self-generated heal event, bounded by the kit's own small number of heal sources), Ignimite (Protean Purge — flat heal on a slow self-Burn→Cleanse cycle), Omenfly (Portent's Toll — flat damage bounded to roughly one or two procs per round by Foretell's own decay cadence), Twerpent (Venomous Rhythm — Enlarge's ×2 multiplier doesn't scale with stack count at all; this is high buff uptime, not growth). All four were initially over-flagged in an earlier pass of this document by conflating "fires without a per-turn limiter" with "grows without bound" — they are different things; see Scaling and Accumulation.
- **Positive counter-examples worth keeping in mind when authoring new content:** Pyrewisp's Ward→Cursed Barrier→Hex loop genuinely stalls without the opponent applying a status to Pyrewisp — a real example of an engine that *needs* opponent cooperation, not just one that happens to have 2+ pieces. Mallegrav's Hone usage is technically uncapped by the engine but self-balances in practice because its own cadence (1 stack gained roughly every 5-turn Stagger cycle, 1 spent per attack including its own spam technique) never lets it compound — a good example that "uncapped in the engine" doesn't automatically mean "grows in this specific kit."
- Not yet done: the equivalent audit for whether any of these kits' *defensive* pieces (Absorption caps at 20 by design; Fortify/Thorns/Ruin do not) actually produce measurably longer fights or any stalemates in practice — this would need the full-run simulation harness (roadmap steps 1–2) to check properly, since `balance_test.gd` only tests default starting kits, not accumulated ones, and none of the confirmed magnitude-growth cases above have been run through actual fight-length simulation yet.

**Still requiring simulation / explicitly TBD — do not invent values for these:**
- Reliable numeric bands (trivial/small/medium/strong/large/extreme) for status stack counts, cooldown/Recharge burden, and setup duration. The current content pool is too small and too narrow (mostly small, fixed stack counts) to support confident bands yet.
- Whether the 0.667 damage step is actually balanceable against 1.0 across a wide range of future archetypes (see Rules for Revising the Primitives — this is exactly the kind of question that needs the full-run simulation harness from roadmap steps 1–2, not a guess).
- Whether the current Focus breakpoint tiers (5/10/15/20) are the right cadence once more Focus-scaling content exists, given the roster only reaches tier 15 today.
- Everything about combat-history/turn-history signals, since they don't exist yet.

## Rules for Revising the Primitives

Primitives should change rarely, and only with real justification:

- **A single piece of content being weak or strong is never sufficient justification** to change a primitive. If a technique built at the 0.667 damage step feels bad, the fix is almost always to reconsider that technique's other properties (setup, utility, conditionality) — not to change what 0.667 means globally.
- **Broad, ecosystem-wide evidence is required to revise a primitive** — e.g., if the full-run simulation harness (once built) shows that the 0.667 step consistently cannot be made competitive across many different archetypes and kit shapes, that is real evidence the step itself (not any one technique using it) needs revisiting.
- **A primitive may also be revised if it's shown to be internally inconsistent with the actual implementation** — e.g., if this document asserts a stat band that a later, more careful reading of the code contradicts. Fix the document to match reality in that case, and say so explicitly rather than quietly editing around it.
- **Document every revision as a revision.** State what changed, what evidence justified it, and what content (if any) needs re-auditing as a result. A primitive that changes silently stops being trustworthy as a shared reference.

## Final Compact Checklist

When authoring or reviewing a technique, passive, or familiar, run through:

- [ ] Does this obey the established numeric language (damage steps, stat band, stack-count conventions), or is there a deliberate, stated reason it doesn't?
- [ ] What opportunity cost pays for its strength — reduced damage, setup time, conditionality, vulnerability, or reliability?
- [ ] What signals or state does it create (a status, a tag, a future history entry)?
- [ ] What other content — including content outside its own kit — could plausibly read or exploit those signals?
- [ ] Does it create an interesting priority-rule decision, or is it simply always correct to use?
- [ ] Does it have any meaningful interaction outside its own starting kit, or is it a closed loop?
- [ ] Is this a coherent machine (pieces that reference each other) rather than a pile of individually-efficient but unconnected effects?
- [ ] Does the starting kit need all three pieces (both techniques + the passive) to run its real engine, not just one or two?
- [ ] If this is a self-contained loop needing nothing external: does its payout stay a *fixed* size (fine — a build-around reward), or does the payout's own *magnitude* grow from its own repeated use with nothing to stop it (the real red flag)?
- [ ] Does it introduce any stall risk (verified against actual fight resolution, not asserted from the numbers), recursive/compounding-magnitude scaling, or action-economy red flag from the list above?
- [ ] If it violates a stated primitive, is there real (ideally simulated) evidence the primitive itself should change — or does the content need to change instead?
