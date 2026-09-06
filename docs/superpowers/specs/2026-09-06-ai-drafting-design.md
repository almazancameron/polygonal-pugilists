# AI Drafting & Priority Optimization — Design

**Date:** 2026-09-06
**Status:** approved, not yet implemented
**Scope:** Pixel Pugilists

## 1. Goal

Two problems, one system:

1. **Bracket AI opponents need to feel like different fighters, not one
   generic "also accumulates power" rule** (the placeholder in
   `2026-09-06-tournament-bracket-design.md` §7 that ships with the
   bracket first).
2. **`scripts/tools/balance_test.gd` only ever tests a familiar's default
   starting kit.** A familiar that looks balanced at round 0 could be
   either dead weight or absurd once real reward choices accumulate, and
   nothing in this project's balance-testing has ever checked that — every
   prior balance pass (`DEVLOG.md` sessions 7–8, `DECISIONS.md`'s
   stat-search entry) reasons about starting kits and hand-picked stat
   nudges, never about *which builds a familiar's kit can actually become*.

A small set of **drafting personalities** — differently-weighted reward
and skip preferences — combined with a **shared priority-rule optimizer**
solves both at once: the same drafted-build-plus-optimized-priorities
machinery can either sit behind a live bracket opponent or run headless in
a much richer round-robin that samples a realistic range of builds per
familiar instead of one.

## 2. Scope

**In scope**

- `DrafterPersonality` (data-driven, not subclassed — see §4.1) and a
  starting set of three: **Greedy**, **Synergy Master**, **Random** (the
  cheapest personality to build, since it skips the heuristic entirely,
  and the right control group to validate the other two against).
- The drafter/optimizer split: a personality scores *candidates*: the
  optimizer decides *how a build gets used* and is shared by every
  personality unconditionally.
- `Technique.priority_hints` metadata (§4.2), reusing this project's
  existing `Condition` subclasses rather than inventing new predicate
  types.
- The priority optimizer: bounded candidate-table generation from hint
  combinations (§4.3), not exhaustive search.
- Two-layer reward evaluation: fast heuristic scoring (reusing
  `RewardSelector`'s existing relevance terms) with combat-lookahead only
  when candidates are genuinely close (§4.4).
- Skip-vs-take as a utility comparison (best reward utility vs. best
  stat-upgrade utility), personality-tuned (§4.5).
- Re-optimizing priorities after every draft pick, not just once (§4.6).
- A new balance-testing tool, `scripts/tools/draft_balance_test.gd`,
  extending `balance_test.gd`'s existing round-robin the same way
  the deleted `_stat_search.gd` throwaway did (`extends
  "res://scripts/tools/balance_test.gd"`) — runs each familiar through
  several full simulated drafts (one per personality) before the
  round-robin, instead of testing default kits only.

**Out of scope**

- **Wiring this into the live bracket.** Per the sequencing decision, the
  bracket ships with its placeholder stat-fraction rule first; this
  system is built and validated as a standalone balance tool, then swapped
  into the bracket's AI-progression step later with no bracket-side
  changes required (that step is already isolated to one function).
- **Species Loyalist, Balanced Drafter, Experimental Drafter**, and any
  further personalities — real, wanted, but deliberately deferred until
  the three-personality mechanism is proven. Adding one is authoring a new
  `DrafterPersonality` resource, not new code (§4.1).
- **Manually authoring `priority_hints` for all 33 techniques up front.**
  Most are mechanically derivable from a technique's own
  conditions/actions/statuses (§4.2); only genuinely unusual techniques
  need a manual hint, authored as they're found to need one rather than as
  an upfront pass.
- **Live-play performance tuning for real-time bracket use** (small
  lookahead-suite sizes, response-time budgets). Not needed while this
  lives only in the offline tool; revisit when §7's "wire into the
  bracket" work actually starts.

**Deferred with a reason**

- The ambiguity threshold (§4.4), the priority-table search cap (§4.3),
  and every personality's skip-threshold multiplier (§4.5) are first,
  reversible guesses, same status as the bracket spec's odds formula —
  tune once `draft_balance_test.gd` has actually run against the real
  roster.

## 3. Approach

**Why `DrafterPersonality` is one data-driven class, not a subclass per
personality** — this project's own established rule (`DECISIONS.md`,
`LEARNING.md`): subclass when the *logic* differs, use fields when only
the *numbers* differ. Every personality (Greedy, Synergy Master, and every
deferred one) runs the identical heuristic formula and the identical
utility-comparison skip logic — they differ only in *weights*
(`tag_synergy_weight`, `species_affinity_weight`, `role_coverage_weight`,
`wildcard_bias_weight`, `skip_threshold_multiplier`). That is exactly
`Technique`'s shape, not `Condition`'s — `Condition` earned subclassing
because `TargetMissingStatusCondition`/`SelfHPBelowXCondition`/etc. read
genuinely different battle-state facts. Random is the one apparent
exception (it ignores the formula entirely) and is handled as a single
`use_random_selection: bool` field rather than a second class, for the
same reason `Technique` didn't get a `RandomTechnique` subclass for any of
its data-driven variance.

**Why hints reuse `Condition`, not a new predicate language** — the
worked examples in the brainstorm (`target_status_below(POISON, 6)`,
`own_hp_below(0.5)`, `self_status_missing(DEFENDING)`, `recharge_ready`)
are all already expressible with `StatusComparisonCondition`,
`HpComparisonCondition`, and `StatusComparisonCondition` again
respectively (self Recharge stacks == 0) — the exact three condition
kinds the priority builder's own descriptor palette already covers
(`DECISIONS.md`'s condition-blocks entry). Inventing a parallel predicate
language would duplicate a system this project already has and already
trusts (the same evaluator `Combatant.choose_technique()` uses, not a
second one the optimizer would need its own confidence in).

**Why the heuristic reuses `RewardSelector`'s own terms** —
`RewardSelector._species_relevance()`/`_run_relevance()`/
`_pivot_relevance()` already compute exactly "how much does this candidate
fit this familiar's species identity / this build's accumulated tags and
role gaps / this build's pivot-worthiness." A personality's heuristic
score is a weighted sum of those same three terms (§4.4) rather than a
fourth, independently-invented scoring function — the player's own reward
screen and the AI's drafting decision should agree on what "fits" means,
differing only in how much each cares about each factor.

## 4. Design

### 4.1 `DrafterPersonality` (new `Resource`, `scripts/ai_drafting/drafter_personality.gd`)

```gdscript
@export var personality_name: String
@export var tag_synergy_weight: float = 1.0
@export var species_affinity_weight: float = 1.0
@export var role_coverage_weight: float = 1.0   # "fill whatever role I'm lacking" -- Balanced-style
@export var role_bias_offense: float = 0.0      # "always want more of this role," independent of current investment
@export var role_bias_defense: float = 0.0
@export var role_bias_sustain: float = 0.0
@export var role_bias_control: float = 0.0
@export var wildcard_bias_weight: float = 0.0
@export var skip_threshold_multiplier: float = 1.0   # see §4.5
@export var use_random_selection: bool = false        # Random personality only
```

`role_coverage_weight` and the four `role_bias_*` fields are deliberately
separate terms, not one: coverage reuses `RewardSelector`'s existing
deficiency factor (`1.0 / (1.0 + current_role_total)`, favoring whichever
role a build is currently *short* on), which is the right shape for a
gap-filling personality but the *wrong* shape for Greedy, which wants to
keep stacking offense specifically regardless of how much it already
has -- the opposite of a deficiency term. `role_bias_offense` multiplies a
candidate's own `role_offense` field directly, uninverted, so it never
tapers off. Greedy sets `role_bias_offense` high and everything else
(including `role_coverage_weight`) at or near zero.

Three authored instances for this pass: `resources/ai_personalities/
greedy.tres` (high `role_bias_offense`, low `role_coverage_weight`),
`synergy_master.tres` (high `tag_synergy_weight`, aggressive
`skip_threshold_multiplier`, `role_coverage_weight` and every `role_bias_*`
near zero -- it cares about tag interactions, not role totals),
`random.tres` (`use_random_selection = true`, every weight irrelevant).

### 4.2 `Technique.priority_hints`

New field on `Technique` (parallel to the existing `tags`/`role_*` added
for reward tagging):

```gdscript
@export var priority_hints: Array[PriorityHint] = []
```

`PriorityHint` (new small `Resource`, `scripts/ai_drafting/priority_hint.gd`):

```gdscript
enum Role { SETUP, PAYOFF, DEFENSE, SUSTAIN, BURST, FALLBACK }

@export var role: Role
@export var condition: Condition   # null = unconditioned (a FALLBACK hint)
```

Worked examples, using conditions this project already has:

- Serpent Fang: `[{PAYOFF, StatusComparisonCondition(self Poison < 6)},
  {FALLBACK, null}]`.
- Venom Pulse: `[{BURST, StatusComparisonCondition(target Poison >= 6)},
  {PAYOFF, StatusComparisonCondition(target Poison >= 3)}, {FALLBACK,
  null}]`.
- A Defending-applying technique: `[{DEFENSE,
  HpComparisonCondition(self HP < 50%)}, {DEFENSE,
  StatusPresentBeforeApplicationCondition(self missing Defending)}]`.
- Meteor Rush: `[{BURST, StatusComparisonCondition(self Recharge == 0)},
  {FALLBACK, null}]`.

Most techniques' hints are mechanically derivable from their existing
`step_groups`/`conditions`/`NumericBonus`es (a technique that already
applies a status conditionally *has* the condition; the hint layer is
mostly "attach a `Role` label to a condition the technique already
carries," not authoring new logic). Techniques with no clean 1:1 mapping
(e.g. `Timeline Collapse`'s "scale off my own active status count," which
has no single triggering condition) get a manually-authored hint —
expected to be the minority, found as the optimizer is run against real
content rather than guessed at up front.

### 4.3 Priority table generation

Given a build's techniques and their `priority_hints`, the optimizer does
*not* search every permutation (combinatorially unworkable once a build
has several multi-hint techniques). Instead:

1. Build one default ordering by `Role` precedence: `DEFENSE` → `BURST`/
   `PAYOFF` (interleaved by each hint's own condition specificity — a
   higher stack-count threshold sorts earlier, mirroring how a human
   would order "use at 6+" before "use at 3+") → `SETUP` → `FALLBACK`.
2. Generate a bounded number of variants (a small constant, e.g. 12 — see
   §2's "deferred with a reason") by locally perturbing that default: swap
   two adjacent same-`Role` hints, promote/demote one conditioned hint by
   one slot, try omitting a marginal `SETUP` hint entirely.
3. Compile each variant into a real `Array[PriorityRule]` (the exact
   structure `PriorityBuilder.compiled_rules()` already produces) and hand
   it to §4.4's evaluation.

### 4.4 Two-layer reward evaluation

**Fast heuristic**, for every eligible candidate in a reward slot:

```
score = personality.species_affinity_weight * RewardSelector._species_relevance(...)
      + personality.tag_synergy_weight * RewardSelector._tag_synergy_term(...)
      + personality.role_coverage_weight * RewardSelector._role_coverage_term(...)
      + (personality.role_bias_offense * candidate.role_offense
         + personality.role_bias_defense * candidate.role_defense
         + personality.role_bias_sustain * candidate.role_sustain
         + personality.role_bias_control * candidate.role_control)
      + personality.wildcard_bias_weight * (1.0 if slot == PIVOT else 0.0)
```

`_run_relevance()` currently computes and sums a tag-repeat term and a
role-deficiency term inline, with no way to weight them separately. This
needs one small, behavior-preserving refactor: extract those two pieces
into their own functions (`_tag_synergy_term()`/`_role_coverage_term()`),
with `_run_relevance()` itself becoming their unweighted sum -- the
player's own reward screen keeps behaving exactly as it does today, and
the AI heuristic gets to weight the same two terms independently.

If the top score's lead over the second-best is large (candidate scores
example: 8.2 / 3.1 / 1.8 — the leader's margin over second place exceeds
half the leader's own score), take the heuristic winner directly, no
lookahead. Otherwise (6.2 / 6.0 / 5.8 — margin is small relative to the
scores themselves) the heuristic can't tell them apart confidently, so:

**Combat lookahead**, only for the top few (2–3) ambiguous candidates:
temporarily add each candidate to the build, run §4.3's table generation
+ evaluation to get that candidate's *best achievable* priority table, then
battle that build through a small fixed evaluation suite (a handful of
representative opponents, not the full roster — size is a tool-context
parameter, larger for `draft_balance_test.gd` than it would ever need to
be for live bracket use, see §2). The candidate whose best table wins the
most evaluation fights is taken.

### 4.5 Skip as utility comparison

Not a threshold rule ("skip if nothing matches") but a direct comparison:
`best_reward_utility` (the winning candidate's score from §4.4) against
`best_stat_utility` (a fixed baseline utility for taking a stat point
instead — a constant per personality, since stat points are not currently
tag-scored). `personality.skip_threshold_multiplier` scales
`best_stat_utility` before the comparison — a Synergy Master's high
multiplier means it needs a much stronger reward fit to justify not
skipping (skips aggressively when nothing advances its build); a Greedy
Drafter's low multiplier means almost any offense-positive reward beats
skipping.

### 4.6 Re-optimizing after every draft pick

Every time a simulated familiar's build changes (a reward taken, a stat
point applied), §4.3 re-runs against the *new* full technique set, not
just the newly-added piece — the stored "current best priority table"
gets replaced, not patched. This is what lets a build's priorities
actually track a pivot (a Poison-cashout build that acquires defensive
pieces ends up with a genuinely different table, not its original rules
plus an afterthought) — the same thing a human does in the real priority
editor, which is exactly why a shared, competent optimizer matters: a
personality's *drafting* choices are what's being measured, not its
ability to write rules.

## 5. Files (expected)

- `scripts/reward/reward_selector.gd` -- small, behavior-preserving
  refactor: extract `_tag_synergy_term()`/`_role_coverage_term()` out of
  `_run_relevance()` (§4.4).
- `scripts/ai_drafting/drafter_personality.gd`, `priority_hint.gd` (new).
- `scripts/ai_drafting/priority_optimizer.gd` (new) — §4.3/§4.6.
- `scripts/ai_drafting/drafter.gd` (new) — §4.4/§4.5, takes a
  `DrafterPersonality` + current build state, returns a pick or skip.
- `resources/ai_personalities/greedy.tres`, `synergy_master.tres`,
  `random.tres` (new).
- `priority_hints` added to existing `Technique` `.tres` files as found
  necessary (most techniques get hints; not a mandatory pass over all 33
  up front — see §2).
- `scripts/tools/draft_balance_test.gd` (new, extends `balance_test.gd`
  the way the deleted `_stat_search.gd` throwaway did).

## 6. Validation

- Headless `_verify_*.gd` scripts: a hint-derivation spot-check against a
  handful of real techniques (confirms the mechanically-derived hints
  actually match what a human would author), a priority-table-generation
  check (confirms the bounded variant generation produces valid, compilable
  `PriorityRule` arrays, never a null-technique rule), and a full
  single-familiar draft-then-fight run built directly from
  `Combatant`/`BattleEngine` (same pattern as the bracket spec's own
  validation plan).
- `draft_balance_test.gd` itself is the real validation: run it against
  the current 16-familiar roster once built, and read the results the way
  every other balance pass in this project has (`DEVLOG.md`) — expect
  this to surface at least one familiar whose default-kit balance doesn't
  hold up once a personality actually drafts it a full build, since that's
  the entire reason this system exists.

## 7. Open questions

- Ambiguity threshold, table-generation cap, and skip-threshold
  multipliers (§4.3–§4.5) are first guesses, tuned against real
  `draft_balance_test.gd` output, not against intuition.
- Evaluation-suite size/composition for the combat-lookahead step (§4.4)
  is a tool-context parameter, not yet fixed — likely different for a
  future live-bracket use than for this pass's offline tool.
- Whether "best achievable priority table" scoring should itself average
  across a few different evaluation opponents or use the same fixed
  handful every time is left to implementation — either is a reversible
  choice at this stage.
