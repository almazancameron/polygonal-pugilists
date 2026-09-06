**Pixel Pugilists**

**Game Design Document v1**

**Document purpose**

> Define the intended direction of *Pixel Pugilists* — a standalone, deliberately small tournament-roguelike prototype and proof-of-concept for the combat-and-buildcraft thesis behind the larger planned game, *Familiar Fight Club*. This document is the current source of truth for what is actually being built in this repository. See `FAMILIAR_FIGHT_CLUB_VISION.md` for the larger long-term vision this prototype is *not* currently building toward directly, but is expected to inform.

# 0. Document status and scope

LOCKED

## 0.1 Status vocabulary

| **Status**            | **Meaning**                                                                                                                               |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| **LOCKED**            | A foundational design commitment for this project. Should not change casually, although playtesting can still reveal it was wrong.        |
| **CURRENT DIRECTION** | The intended solution today, subject to iteration as the project becomes playable.                                                        |
| **OPEN / PLAYTEST**   | Deliberately unresolved. Building and playing should answer this rather than the document choosing prematurely.                          |
| **OUT OF SCOPE**      | Deliberately excluded from Pixel Pugilists. Belongs to the eventual full *Familiar Fight Club* — see `FAMILIAR_FIGHT_CLUB_VISION.md`.      |

## 0.2 What Pixel Pugilists is

A standalone single-tournament roguelike: draft a fighter from a randomized bracket, fight your way through single-elimination rounds against opponents who are *also* accumulating power, choosing your own upgrades between rounds, ending in a clash between two heavily-built familiars. It is a complete, small game in its own right — not "Milestone 1 of Familiar Fight Club" nested inside a bigger document, even though it is expected to validate ideas the larger game will eventually reuse.

## 0.3 What Pixel Pugilists deliberately excludes

OUT OF SCOPE for this project (see `FAMILIAR_FIGHT_CLUB_VISION.md` for all of these in their full form):

- Meta-progression or persistence between separate playthroughs (no Money, Reputation, Legacy Points, or unlocks that carry across runs).
- A multi-week "raise a familiar" career, retirement, or the Ranch.
- Multiple circuits or a narrative campaign.
- Grid-based movement and spatial combat.
- Recruitment/breeding/lineage systems.

If a system on this list starts feeling necessary to make Pixel Pugilists work, that's worth a real conversation before adding it — it likely means either the scope is drifting toward the bigger game, or there's a genuinely small version worth carving out (the way the pre-fight build-select screen was deliberately kept small rather than becoming a full round/reward economy).

# Contents

- 1\. High concept
- 2\. Core player experience
- 3\. Design pillars
- 4\. Combat foundation
- 5\. Combat timing and universal stats
- 6\. Behavior and autonomous decision-making
- 7\. Techniques, tags, and statuses
- 8\. Familiar construction — bracket entrants
- 9\. Tournament structure
- 10\. Development roadmap
- 11\. Playtest questions
- 12\. Elevator pitch

# 1. High concept

LOCKED

Pixel Pugilists is a single-elimination tournament roguelike. The player drafts one familiar from a randomized bracket of entrants, then guides it through the tournament by choosing upgrades between rounds — the player is not piloting the familiar turn-by-turn during a fight, they're shaping how it fights before and between fights, the same way the full Familiar Fight Club vision intends, just compressed into one run instead of a career.

Central fantasy: pick your fighter, watch it grow more dangerous with every round, and see two fully-built familiars collide in an absurd final showdown.

## 1.1 What this game is not

- Not a game where the player issues an attack every turn — combat is fully autonomous once a fight starts (see §6).
- Not a persistent career sim — there is no "raising" a familiar over time, no retirement, no Ranch.
- Not a narrative game — no story, characters, or campaign arc. (That belongs to Familiar Fight Club.)

# 2. Core player experience

LOCKED

## 2.1 Theorycrafting between rounds

The player should repeatedly ask "what does my build need right now?" when choosing upgrades — build identity emerges from which techniques, priority rules, and (eventually) passives accumulate over the run, not from any single choice.

## 2.2 Execution as payoff

Watching a fight should show the player's preparation working. The player should be able to tell what their familiar attempted, why, and whether it worked — same legibility goal as the full game (see `FAMILIAR_FIGHT_CLUB_VISION.md` §3.3), achieved here through the combat log and the priority-rule skip-reason logging already built.

## 2.3 The bracket creates stakes without narrative

Seeing the surrounding bracket — who else is fighting, how those matches went, who's coming up next — should create tension and a sense of stakes on its own, without needing written narrative to do it.

# 3. Design pillars

LOCKED

## 3.1 Theorycrafting is the main form of agency

Reused directly from the full game's design pillars: the most important decisions happen between fights, not during them.

## 3.2 Simple baseline rules, expressive exceptions

The universal combat rules stay small; complexity comes from techniques, statuses, and priority-rule conditions that bend them in readable ways.

## 3.3 Autonomous combat must be legible

Every automated decision needs an understandable cause, and unexpected behavior must be inspectable after the fact (the combat log and skip-reason logging exist specifically for this).

## 3.4 Build variety should change behavior, not only numbers

A build should visibly fight differently, not just hit harder — already true of the difference between the two existing example builds ("Status Stacker" rotates through inflicting statuses; "Poison Spammer" turtles at low HP).

## 3.5 Variable bracket runs create replay value

Since there's no persistent career to create variety across playthroughs, the randomized bracket (entrant pool, matchups, upgrade offers) needs to carry that job instead — no two runs should draft the same fighter into the same bracket with the same upgrade choices.

# 4. Combat foundation

LOCKED

## 4.1 Match format

One familiar versus one familiar, automated according to each familiar's configured techniques and priority rules. **Implemented.**

## 4.2 Action economy

One action per turn, alternating sides. **Implemented** as `Combatant.choose_technique()` + `Technique.execute()`, called once per side per turn via `battle_controller.gd`'s `take_turn()`.

## 4.3 Determinism and variance

The player's own combat resolution stays fully deterministic and rule-driven — no hidden accuracy/resistance rolls. Randomness is reserved for the bracket layer (simulated off-screen fights, §9.3; bracket generation and upgrade offers, §9). **Implemented** for player-side combat; the bracket-layer randomness is not yet built.

# 5. Combat timing and universal stats

OPEN / PLAYTEST

## 5.1 Timing model

**Implemented:** Speed is the real turn-order driver, re-decided at the start of every exchange (not once per fight) — a mid-fight Speed swing can hand one side two turns in a row before alternation resumes. Equal Speed defaults to the player acting first. A `Status.grants_first_act_override()` hook lets a status force its side to open regardless of Speed; if both or neither side holds it, the Speed comparison decides as normal. See §5.2 for the stat-philosophy pass this came out of, and `DECISIONS.md` for the `battle_controller.gd` mechanics. Still an experiment per this section's OPEN/PLAYTEST status, not a locked answer — revisit if playtesting says otherwise.

## 5.2 Stat line

**Current implementation:** HP, Power, Defense, Speed, Focus.

**Design philosophy, decided but mostly not yet implemented beyond HP/Power/Defense's existing damage math:**

- **HP** — a resource pool, the same "the resource" feel most games give it. Every build spends from or replenishes this pool somehow, even builds that aren't specifically HP-focused. Techniques built around HP treat it as a cost to pay and a resource to restore (Renewal/Regeneration/Lifesteal already lean into this).
- **Power** — "big number go up." Drives direct-attack damage; should scale disproportionately hard relative to other stats via techniques. Techniques built around Power care about making it scale in absurd ways and applying that huge number to various effects, with little regard for what the opponent is doing.
- **Defense** — "beat this number," a comparison stat. Even at baseline, its damage-reduction math already conveys a threshold to beat. Techniques built around Defense should mostly compare Power-vs-Defense (either direction) or Defense-vs-Defense directly, not just feed into the existing subtractive formula.
- **Speed** — tempo. Higher Speed acts first by default (§5.1), but techniques shouldn't all hinge on the identical "did you go first" / "do you have higher Speed" check — a deliberate mix of the two (plus letting passives decouple them, e.g. a low-Speed familiar with an "always acts first" passive) keeps the design space from collapsing onto one axis and opens up rare double-dip combinations.
- **Focus** — set thresholds, not comparisons. Unlike the other four's linear/comparative scaling, Focus acts like a built-in upgrade tree: fixed breakpoints unlock fixed bonuses (e.g. "5 Focus: +1 Foretell pop damage," "10 Focus: Burn deals +1 extra damage per tick," "15 Focus: +1 extra Poison stack per application"). Techniques built around Focus care about hitting specific goals — parity checks (odd/even), ranges ("15–20 Focus: double damage") — rather than raw magnitude.

**Resolved:** one shared `FocusTable` resource (`resources/focus_tables/focus_table.tres`), referenced by every familiar's `focus_table` field, rather than per-familiar/per-build tables — a breakpoint means "everyone gets the same bonus at the same tier," not a per-species tuning knob. Currently four tier-gated effects (defense, heal power, Foretell burst damage, Burn flare damage), gated at Focus 5/10/15/20 via `FocusBreakpointCondition`. The roster's Focus values only reach 5/10/15 so far, so the tier-20 effect is currently inert for everyone — not a bug, just unreached content.

# 6. Behavior and autonomous decision-making

LOCKED

## 6.1 Priority-rule system

**Implemented.** A familiar's `priority_rules` (ordered `PriorityRule`s, each an ANDed set of `Condition`s plus a `Technique`) get evaluated in order each turn; the first rule whose conditions all hold wins. Every rule the evaluator passes over produces a loggable skip reason (currently gated behind a debug toggle, off by default for normal play). Both the player and the enemy use the identical evaluator — there is no separate "AI" system.

## 6.2 Where priority rules come from

**Current implementation:** authored ahead of time as `PriorityRule`/`Condition`/`Technique` resources, assigned to a familiar's `priority_rules`/`techniques` via the Inspector. The pre-fight `PriorityBuild`-picker stopgap (choosing between whole pre-authored rule sets before a run started) has been retired now that the real reward loop (§9.4) exists — the player starts a run with their drafted familiar's own authored default build and grows it from there. Composing individual rules directly still isn't wired into the actual game (see §9.4/§10) — only the standalone prototype below.

**Decided (playtested):** the player composes rules directly, from building-block choices. A standalone prototype — `scenes/priority_builder/priority_builder.tscn` — was built and played, and confirmed as the shape the real in-run editor should take. This closes what was previously an open question here.

The validated shape:

- **Draggable palette blocks.** Techniques come from the familiar's own `techniques`; conditions come from a palette grouped by kind (Status / HP / Stat / Logic).
- **Conditions are fill-in-the-blank sentences**, built from `ConditionBlockDefinition`/`SentencePart` `.tres` descriptors — one descriptor per sentence *shape* rather than per `Condition` subclass, which is what avoids slots that hide and show (see `DECISIONS.md`).
- **Nesting means AND**, flattened depth-first pre-order into `PriorityRule.conditions` — presentation only, since an ANDed array is already what that field means.
- **An ordered list of reorderable slots**, since priority order is the whole mechanic.
- **A live mock-state panel** — play the currently-edited rules out for real, one round at a time, against a passive dummy target (Step/Play/Reset/Previous/Next), with every rule badged FIRES / skipped (naming the failed condition) / unreached / incomplete as play progresses. This is a required feature of the real editor, not a debug affordance: "unreached" is what makes a catch-all sitting above three conditional rules visibly the reason they're all dead, and watching the build actually fight is what makes a passive's real effect legible instead of assumed.

Still open: whether nesting genuinely reads as AND to someone who didn't build it, versus a flat ANDed list with an explicit separator. Cheap to switch — it changes one scene and the tree walk, nothing else.

# 7. Techniques, tags, and statuses

CURRENT DIRECTION

## 7.1 Techniques

**Implemented.** A `Technique` is authored data: a name, a power multiplier, and (optionally) a status it applies with a stack count. Techniques with genuinely different execution logic (currently only Defend) are real subclasses instead of parameterized fields — see the codebase's own `DECISIONS.md`/`LEARNING.md` for the reasoning already worked out on when that split applies.

## 7.2 Status baseline

Same vocabulary as the full game (`FAMILIAR_FIGHT_CLUB_VISION.md` §10.5): Poison, Burn, Acid built and working; Vines, Chill, Shock, Bleed named but not implemented — movement-related ones (Vines, Chill, Shock) likely stay unimplemented for this project specifically, since Pixel Pugilists has no movement (§0.3).

## 7.3 Passives and tags

CURRENT DIRECTION. Needed, not optional -- part of the current content-pass scope (a dozen or so passives, authored as a new `UpgradeOption` subtype) and a core piece of how bracket entrants get their identity: each of the 16 starting familiars is meant to carry one species-bound passive (innate from the start, not drafted) alongside its base stats, using the same passive type the in-run upgrade pool later offers as a pickup.

**Two categories, by design intent, not just by implementation convenience:**

- **Rule-following passives** (the implementation target for now, and now fully built) -- a shared `PassiveEffect` base (`Trigger`, `Conditions`, `Limiter`) with four concrete subclasses covering everything short of engine-behavior changes: `OperationPassiveEffect` (fires its own separate consequence -- a full `Technique` as payload, e.g. "deal 3 damage to the enemy," "apply 3 stacks of Ward to yourself at battle start"), `ModifyStatusPassiveEffect` (adjusts a status application already in progress -- "+1 poison stack applied per application," or a bonus to one of a status's own numeric fields -- resolved *before* the status is created/merged rather than as a reaction, since bolting it on after would incorrectly re-trigger reapply-only effects like Burn's Flare), `ModifyHealPassiveEffect` (the same idea for a heal amount instead of a status), and `PermanentStatPassiveEffect` (a permanent, run-persistent stat change via the same `ModifyStatUpgrade` payload stat upgrades already use -- "gain 5 Focus permanently at the end of combat"). A wide survey of desired passive behaviors ("when status reaches X stacks," "when HP drops below X," "if your Speed beats the opponent's, gain a bonus every turn") turned out to already be expressible as Trigger + Conditions + one of these four payloads, with no new subclass needed -- see `DECISIONS.md` for the full mapping. Focus breakpoints (§5.2) are not a separate mechanism -- a Focus breakpoint is just a rule-following passive whose Conditions include a self-Focus threshold check, authored into a swappable per-familiar `focus_table` rather than a familiar's directly-owned `passives` (see `DECISIONS.md` for why those two containers stay separate even though they hold the same effect type). The mechanism is fully wired, and a real shared `FocusTable` now exists with content (see §5.2).
- **Rule-breaking passives** (deliberately deferred, case-by-case) -- abilities that change how the *engine itself* behaves rather than reacting to an event within it: "always acts first, full stop, no status involved"; "techniques ignore their own conditions and fire in raw priority order"; "the fallback technique also gets evaluated as a top-priority trigger, not just kept as the fallback"; "odd-numbered turns always use the fallback technique regardless of priority"; "give techniques extra repeats under a condition" (modifies a technique's own `repeat_count` mid-execution); "lock a stat so it can't be modified" (an interception effect, the same *class* of thing Ward/Absorption already needed a hardcoded interception point for). Each is expected to need its own bespoke implementation; no shared scaffolding is planned for this category until a specific one is actually being built.
- **Continuously-live passives** -- a third category, now built as `ModifyStatPassiveEffect` (a permanent, always-active flat stat bonus, e.g. "+2 Power"): consulted directly by `Combatant.effective_stat()` alongside every active `Status`'s `modify_stat()`, with no `Trigger` involved at all -- `trigger`/`conditions`/`limiter` are simply unused on this subclass, since there's no event to gate. Turned out not to need the opponent-parameter signature change this entry originally anticipated, since the first real case (a flat per-stat bonus) never needed to compare against the opponent's own stats -- see `DECISIONS.md`.

# 8. Familiar construction — bracket entrants

CURRENT DIRECTION

## 8.1 No "raising" — entrants are pre-generated

Familiars are not raised or developed from scratch. Each bracket entrant is a pre-generated combination of a base familiar (sprite/stats — recolors or minor sprite variations are fine, no need for unique art per entrant) and a starting moveset/priority-rule set. The player selects one entrant from the bracket and takes its place.

## 8.2 Weighted rarity pool

Entrant generation should draw from a weighted pool so some combinations are rarer than others (stronger stats, an unusual moveset, whatever ends up feeling notable) — enough to make drafting itself a small, interesting decision, without building the deeper trait/rarity systems the full game has (`FAMILIAR_FIGHT_CLUB_VISION.md` §9.3). Exact weighting is an open tuning question once there's enough content to weight.

## 8.3 Opponents accumulate power too

Opponent entrants aren't static — they should gain a comparable amount of upgrades/modifiers over the course of the bracket as the player does, so the final match is a clash between two builds that both grew over the run, not the player's build versus a flat baseline.

## 8.4 Species vs. Familiar vs. Combatant

Three layers, each progressively more specific:

- **Species** (planned) — a template: base stats and one bound-in passive, shared by every member of that species. Not yet built; today's `Familiar` resource holds what Species will own.
- **Familiar** — one specific fighter's current build for this run: its own stats (seeded from its species, then diverging via upgrades), its accumulated techniques and priority rules, and any passives picked up beyond its species-bound one.
- **Combatant** — one fighter's live state for the battle currently in progress (current HP, active statuses). Already built, unaffected by the Species split.

For Pixel Pugilists, Species should *seed* a Familiar once at creation time (copy in base stats and the bound passive, then Familiar is independently authoritative from then on) rather than Familiar holding a live reference it keeps deriving from — a Familiar's whole point is to diverge from its species over a run, so continuing to resolve stats back through the species template adds real complexity (every stat read would need to walk species + accumulated modifiers) for no benefit this project needs. A live reference is expected to matter for the full Familiar Fight Club game instead, where cross-run tracking (species completion, species-specific achievements) genuinely needs to know what species a given career's familiar belongs to for longer than just its creation moment.

## 8.5 Minimum entrant build skeleton

Each of the 16 starting bracket entrants should have exactly: a species (base stats + its one bound passive), one conditioned priority rule (a condition plus the technique it gates), and one unconditioned fallback technique (an empty-conditions `PriorityRule`, the same catch-all shape already used today). That's enough for every starting entrant to already fight noticeably differently from the others, giving the player a wide variety of jumping-off points to build from.

Familiars filling that skeleton can come from either of two sources: procedurally constructed at runtime (randomly draw a species + a starting technique + a starting priority rule from their respective pools), or hand-authored as complete fixed variations (today's `guubal.tres`-style familiars) that get drawn from directly. Nothing rules out mixing both approaches in the same bracket.

# 9. Tournament structure

CURRENT DIRECTION — the least-built part of this document; expect it to change once implementation starts.

## 9.1 The bracket

**Settled:** a single-elimination bracket of 16 entrants, semi-randomly generated at the start of a run. The bracket screen doubles as the character-select screen — picking your entrant's spot in the bracket is how you start the run. Winning all 4 bracket rounds leads to a separate, fixed final boss encounter (§9.2) — a deliberately-authored showdown, not another random bracket match, and not resolved via the off-screen simulation (§9.3) the way matches the player doesn't take part in are.

## 9.2 Loop

**Settled**, including the reward cadence (see §9.4 for the reward details):

> 1\. Draft a familiar (assume their spot in the bracket). Comes pre-built with one species-bound passive and two techniques — one gated behind a priority rule, one an unconditioned fallback.
>
> 2\. Fight your round's match, fully autonomously.
>
> 3\. Choose that round's reward(s) — see §9.4 for exactly what's on offer each round.
>
> 4\. Arrange priority rules in the priority editor (§6.2), using whatever was just picked up alongside everything already owned. A distinct step from choosing the reward — the reward screen decides *what* you gain, the editor decides *how* it gets used.
>
> 5\. Inspect surrounding bracket results (see §9.3).
>
> 6\. Repeat from step 2 for 4 rounds total.
>
> 7\. Face the fixed final boss encounter (§9.1) — an absurd showdown between two heavily-built familiars. No reward follows it; the run ends either way.

No separate upgrade choice happens before the very first fight beyond the draft itself — a freshly-drafted familiar's built-in loadout (one passive, two techniques) is the starting point step 3 then builds on.

## 9.3 Simulated off-screen fights

Matches elsewhere in the bracket that the player doesn't take part in are *not* played through the full combat engine — they're resolved by comparing the two entrants' stats/builds into a win probability, then rolling against it. This is deliberately lightweight: full simulation of every bracket match would be expensive for no real payoff, since the player never sees them play out move-by-move.

**Open questions to settle before implementing:**
- What exactly feeds the odds calculation — raw stat totals, or does technique/priority-rule quality factor in too? Cheaper is better unless it visibly produces bad-feeling odds.
- What fidelity does the player see when scouting an upcoming or already-decided match — an exact percentage, or a coarser signal (Favored/Toss-up/Underdog)? A coarser signal probably sits better with "occasional unclear outcomes and upsets" being a deliberate feature, not noise.
- Is scouting free/always-visible, or a resource/choice the player spends something on? Given this project has no economy (§0.3), it's likely free — but worth deciding deliberately rather than defaulting.

## 9.4 Upgrade choices between rounds

**Implemented.** The pre-fight `PriorityBuild` picker this section used to defer to has been retired (§6.2) — post-round rewards are now the real place build choices happen, exactly as originally intended here.

**Reward cadence per round, settled and implemented:** a stat upgrade every round, plus one rotating second choice depending on which round just ended:

| After... | Second choice (pick 1 of 3) |
|---|---|
| Round 1 | A technique |
| Round 2 | A passive |
| Round 3 | A technique |
| Round 4 | Trade one currently-held passive for a different one |

Past round 4, a round is stat-upgrade-only — not a crash or a repeat of the trade round. No reward follows the final boss fight (§9.1/§9.2) — the run ends either way.

**Each round's second choice offers 3 tailored options, not 3 random ones**, via three fixed, named slots: **Species** (biased toward the drafted familiar's own innate identity), **Build** (biased toward reinforcing whatever the current run has actually leaned into so far), and **Wildcard** (deliberately "a little relevant, a little strange" — not maximally random, but not on-theme either). A shared pool of reroll charges (3 per screen) can be spent on any one slot independently. This is what makes the second choice feel like it's responding to the specific fighter and the specific run, rather than three interchangeable options from one flat pool.

**Stat-upgrade points are allocated, then confirmed as a batch** — not applied the instant a stat is clicked, specifically so a misclick can't permanently commit the wrong stat (a stat upgrade is a one-way, run-persistent change). Skipping the round's tailored options grants 2 stat-upgrade points on that round's stat screen instead of 1, so skipping never means "gained strictly less than picking something."

**The reward screen is not the priority editor.** They're separate steps (§9.2 step 3 vs. step 4), doing different jobs: the reward screen decides *what* the player gains (a stat bump, a new technique, a new or swapped passive); the priority editor decides *how* a technique actually gets used, by letting the player arrange priority rules with whatever's newly available. A reward without the editor step following it would grant a technique with no way to see or arrange whether it'll actually trigger. **Implemented.** The reward screen now hands off to the priority editor (§6.2) before the next fight starts, reopening it pre-populated with whatever the familiar already has, not a blank screen.

**Implemented and integrated**, not hypothetical: §6.2's block editor with its live mock-state panel is embedded in `battle.tscn` as a hidden sibling of the other reward-sequence panels, shown after every reward screen (reopening pre-populated with whatever the familiar already has), and writes its result back onto the familiar's `priority_rules` before the next fight starts.

## 9.5 Loss ends the run

Single elimination means losing a match ends the run — no Reputation-style buffer like the full game's career (`FAMILIAR_FIGHT_CLUB_VISION.md` §11.4). Worth confirming this feels right once there's a real run to lose; a bracket-flavored buffer (e.g. a rare "second chance" upgrade) is a reasonable thing to consider later if losses feel too punishing, but isn't planned now.

# 10. Development roadmap

Tracked in detail in `LEARNING_ROADMAP.md`; summarized here for design context.

**Done:** combat engine with Speed-driven dynamic turn order, 24 statuses (adding Stasis/Renewal/Lifesteal/Regeneration/Cleanse to the 19 already covering Poison/Burn/Acid/Bleed/Stagger/Stun/Foretell/Defending/Fortify/Hone/Enlarge/Recharge/Infestation/Ward/Hex/Absorption/Ruin/Thorns/Retaliation), the `PassiveEffect` system giving species passives and Focus breakpoints a real mechanism (§7.3, now including a real `FocusTable` and the continuously-live `ModifyStatPassiveEffect` category), techniques-as-composable-steps (`TechniqueStepGroup`/`TechniqueAction` — hit/heal/status-apply/status-modify actions, gated per-group by conditions, with situational `NumericBonus`es), the priority-rule behavior system for both sides, the pre-fight build-select stopgap, sequential per-step combat resolution (each hit/heal/status application gets its own paced log line rather than one batched turn summary). **All 16 familiars for the entrant roster now exist**, each with two techniques, priority rules, and a species passive, and have been through a full balance pass (round-robin harness + an automated stat-search tool, see `DEVLOG.md`) landing every one between roughly 40–60% win rate against the rest of the field with none doomed.

**Done (session 8):** the real reward screen (§9.4) — weighted Species/Build/Wildcard slots, shared rerolls, allocate-then-confirm stat upgrades, the passive-trade sacrifice flow, all wired into `battle.tscn`/`battle_controller.gd`. The pre-fight `PriorityBuild` picker it replaces is retired. The priority editor (§6.2) is now integrated as the step that follows each reward screen, reopening pre-populated with the familiar's existing rules rather than blank, and writing the result back before the next fight starts — its mock-state panel now plays a build out for real against a passive dummy target rather than declaring a hypothetical state.

**Done, same session, developer-verified end-to-end:** a Game Over screen (win or the final loss) with a Restart button that re-rolls the whole run — replacing the old behavior of quitting the application outright — and a randomly-drawn player familiar + opponent lineup at the start of every run (from an authored full roster, not the bracket itself; a deliberate stand-in for the real bracket/character-select draft below, expected to be replaced outright once the bracket exists, not extended). Together these close the full non-bracket play loop end-to-end for the first time: launch, get assigned a fighter, fight through the whole opponent lineup with a reward-and-priority-editor step after each non-final win, reach a win/loss screen, and restart into a genuinely new run. This is effectively Milestone 1 minus the bracket itself — everything the bracket will eventually sit on top of already plays start to finish.

**Next, per explicit developer direction:** the bracket (§9) — the only remaining piece before Milestone 1 is feature-complete. See §9's own open questions (off-screen simulation odds/fidelity/cost) before starting it. A mockup-matching visual style pass across battle/builder/reward/stat is planned but deprioritized behind the bracket. Remaining content-pass scope (traits/augments, if still wanted — see `LEARNING_ROADMAP.md`) is otherwise open and can slot in whenever.

**After that:** the tournament/bracket structure (§9) itself — now settled at 16 entrants plus a fixed final boss (§9.1) rather than open — then whatever §9.3's remaining open questions (off-screen simulation odds/fidelity/cost) resolve into, and playtesting/balance passes.

# 11. Playtest questions

OPEN / PLAYTEST

## 11.1 Combat timing and stats

- Does fixed alternation hold up once opponents have accumulated very different amounts of power, or does turn order start to matter more than intended?
- Does Speed or Focus need a job, or does the run stay interesting with them unused?

## 11.2 Bracket and upgrade pacing

- How many rounds (bracket size) makes a run feel complete without dragging?
- How many upgrade choices does a build need before it feels distinctly "yours"?
- Do simulated off-screen results feel meaningful to scout, or do players ignore them?
- How much of an upset should the off-screen simulation allow before it reads as unfair rather than tense?

## 11.3 Status and combo pacing

Carried over from the full design (`FAMILIAR_FIGHT_CLUB_VISION.md` §18.3) since it's equally relevant here: how many actions should a setup build need before payoff, and are stacking statuses interesting to maintain or just fiddly?

# 12. Elevator pitch

LOCKED

Pixel Pugilists is a single-elimination tournament roguelike: draft a fighter from a randomized bracket, watch it fight autonomously according to the techniques and priorities you've given it, choose how it grows between rounds, and scout the rest of the field as everyone else's builds grow too — building toward a final clash between two familiars that have accumulated a run's worth of power. It's a standalone prototype proving the combat-and-buildcraft core of the larger planned game, *Familiar Fight Club*, without any of that game's career, Ranch, or narrative systems.