# Content Ideas — Status & Technique Backlog

This is a running backlog of status/technique ideas from brainstorming (2026-08-31 and ongoing), not a commitment or a queue in priority order. Pull from it whenever authoring new content; update it as ideas get built, dropped, or refined. See `GAME_DESIGN.md` §3.2 for the underlying design lens these lean on: statuses as reusable pieces of delayed/recurring logic, not one-off special cases.

## Status ideas — very good / want to build

- **Stat-modifying statuses** (Fortify, Enlarge, Hone) — ✅ **Built.** Justified generalizing `modify_defense()` into `modify_stat()` as intended; Hone (a Power buff triggered on attack rather than on hit) also justified adding a new `on_attack()` hook alongside `on_hit()`.
- ~~**Vulnerability**~~ → **Ruin** (renamed during implementation) — ✅ **Built.** Increases damage taken by X%, applied after all other damage modifiers via a new `modify_incoming_damage()` hook.
- **Echo** — repeats the user's next technique. Not yet built — see the Echo architecture note below, since it's a different shape from every status so far.
- **Recharge** — ✅ **Built** (status side only — a stack that decays on its own turn by turn). The actual cooldown-gating behavior (a technique that applies Recharge to itself fizzling/weakening if the user is already Recharging) has no consumer wired up yet; still just an inert decaying stack in practice.
- **Infestation** — ✅ **Built.** Self-growing stack, gains 1 and deals 1 damage per tick; nothing yet reads or spends the stacks beyond that.
- **Ward** — ✅ **Built**, refined during implementation: blocks **both** positive and negative incoming status applications, not negative-only as originally scoped — clarified mid-build that "block both" was the intended answer to the design question the negative-only wording had left open. Intercepts inside `Combatant.add_status()` before the normal merge happens, as planned.
- **Thorns** — ✅ **Built.** Deals damage (scaled by stacks, losing 1 per hit) whenever the owner takes a hit.
- **Hex** — ✅ **Built.** Deals damage whenever any status is applied to the target, including Hex re-applying itself.
- **Absorption** — ✅ **Built.** A secondary HP pool; incoming hits drain Absorption before HP, unaffected by Defense.

## Status ideas — decent / worth exploring

- **Rage** — grows in stacks when hit; either a stat bonus directly, or a resource other abilities consume/read.
- **Expose** — temporary defense bypass, contrasted with Acid's persistent reduction.
- **Dodge** — consumable hit avoidance; should be harder to get or rarer than Defend.
- ~~**Persistence**~~ → **Stasis** (renamed) — **Up next.** Refined mechanic: whenever stacks would be removed from *any other* status, Stasis's own stacks are removed first instead. Architecturally the hardest idea here: every other status manages its own stack loss privately, so this needs a real cross-cutting redesign (every status's decrement path needs to check Stasis first, likely via a `Status.owner: Combatant` back-reference plus a custom `stacks` property setter), not just a new hook. Needs its own design conversation before implementation — flagged as possibly too strong combined with things like Dodge.
- **Retaliate** → **Retaliation** (built as-named) — ✅ **Built.** Deals damage back when the owner is hit, and that retaliation itself triggers on-hit effects — the one status allowed to trigger on-hits this way.
- **Technique-referencing statuses** — a general pattern for a technique to leave a specific, checkable mark rather than a generic status: "Marked by Snipe," "X technique on cooldown," "X technique category disabled." Needs a status that carries a reference to *which technique* applied it (a data payload, not just a stack count) — a different shape than every status built so far.

## Technique ideas — patterns to build from

- Big dumb hit. Big dumb hit with self-damage. Weaker hit + Defend.
- Bonus damage if the user defended last turn (or currently has the Defending status).
- Small hit + big flat heal (vs. percent-based healing).
- Multi-hit (or one big hit) that heals the *enemy* at the end (a deliberately bad-looking but potentially exploitable effect).
- Big frontloaded status applicator, for statuses worth stacking hard and immediately.
- Hit + status. Hit + multiple distinct statuses. Multi-hit + multi-status, especially statuses that interact with hits directly (Acid, Bleed).
- Pure multi-status application, for statuses with an on-reapply effect worth chaining (Burn's flare).
- Status consumption for a powerful payoff effect.
- **Conditional bonuses** — a priority-rule-shaped branch living *inside* a technique's own execution: "deal damage, apply Stagger, bonus hit if that capped into Stun." "2.0x power if target below 30% HP, otherwise 1.0x." "Bonus damage scaled by total enemy status stacks."
- **Battle-state manipulation as the payoff itself** — remove your own negative statuses, strip the enemy's positive ones, double the enemy's Poison stacks, give the enemy half your Acid stacks, swap/split HP values.
- **Temporary battle-state modification** — double Acid for one attack then revert at end of turn; reduce Foretell by 5 now but add 10 back at end of turn if it didn't pop.
- Effects entirely dependent on battle state — "heal for each Poison stack applied to the enemy."
- Effects that need "hidden" tracked state — total damage dealt/taken this fight, total statuses applied, total turns passed. None of this exists on `Combatant` today; worth building one small generic tracker once an idea using it actually gets picked up, rather than each idea inventing its own counter.
- Self-apply a negative status as a deliberate tradeoff — also a synergy vector for builds that care about having that status on themselves.
- Status "conversion" — turn stacks of one status into stacks of another.
- A technique that applies Acid but does massive bonus damage if the target has *no* Acid yet — a strong opener you later pay off by consuming the Acid you just placed.
- Grant the user an extra turn — a strong candidate for gating behind Recharge or a similar cooldown mechanic rather than being free.

## Architecture notes

- ~~**Self-targeting for status application**~~ — ✅ **Built.** `StatusApplicationAction`/`ModifyStatusAction` both carry a `Target { SELF, TARGET }` field; `TargetMissingStatusCondition`/`TargetStatusStacksBelowXCondition` later reused the same enum shape so priority rules can check either combatant too (see `DECISIONS.md`).
- ~~**Ward** needs an interception point inside `Combatant.add_status()`~~ — ✅ **Built**, as planned.
- **Echo** (repeat next technique) needs to reach into turn/technique-selection itself (`choose_technique()`/`take_turn()`), not just Status hooks — the first idea that changes *how a combatant decides what to do* rather than reacting to something that already happened. Not yet built.
- **Stasis** (renamed from Persistence) needs every status's stack-loss path to check it first — a cross-cutting change, not an additive one. Up next; treat as its own design conversation before building, not another independent `Status` subclass.
- A composable per-action ordering inside `TechniqueStepGroup` (any sequence of hit/status-apply/status-modify/heal actions, not a fixed hit→status→heal order) — ✅ **Built**, motivated by a real limitation found while testing Enlarge (a technique needing to apply a status *before* its hit had no way to express that under the old fixed sequence).
- **Hidden battle-state tracking** (damage dealt/taken, statuses applied, turns passed) has no home on `Combatant` yet — build one generic tracker when the first idea needing it gets picked up, rather than piecemeal per-technique counters. Not yet built.
