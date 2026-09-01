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

**Current implementation:** sequential/fixed alternation — the player's familiar always acts first, then the enemy, repeat. One candidate under test, not a conclusion; revisit if a difficulty curve emerges across the bracket that this model doesn't support well.

## 5.2 Stat line

**Current implementation:** HP, Power, Defense, Speed, Focus. Speed and Focus are both defined but functionally unused by any system — don't give either a job until a specific mechanic (an upgrade, a bracket-simulation formula) needs one. Keep the line this small unless a real need for more appears.

# 6. Behavior and autonomous decision-making

LOCKED

## 6.1 Priority-rule system

**Implemented.** A familiar's `priority_rules` (ordered `PriorityRule`s, each an ANDed set of `Condition`s plus a `Technique`) get evaluated in order each turn; the first rule whose conditions all hold wins. Every rule the evaluator passes over produces a loggable skip reason (currently gated behind a debug toggle, off by default for normal play). Both the player and the enemy use the identical evaluator — there is no separate "AI" system.

## 6.2 Where priority rules come from

**Current implementation:** authored ahead of time as `PriorityRule`/`Condition`/`Technique` resources, assigned to a familiar's `priority_rules`/`techniques` via the Inspector. The player currently picks between whole pre-authored `PriorityBuild`s on a pre-fight screen (see §9.4) rather than composing individual rules themselves — composing rules directly (or from smaller building-block choices) during the between-round upgrade loop is the natural next step once §9's tournament structure exists, but isn't decided yet.

# 7. Techniques, tags, and statuses

CURRENT DIRECTION

## 7.1 Techniques

**Implemented.** A `Technique` is authored data: a name, a power multiplier, and (optionally) a status it applies with a stack count. Techniques with genuinely different execution logic (currently only Defend) are real subclasses instead of parameterized fields — see the codebase's own `DECISIONS.md`/`LEARNING.md` for the reasoning already worked out on when that split applies.

## 7.2 Status baseline

Same vocabulary as the full game (`FAMILIAR_FIGHT_CLUB_VISION.md` §10.5): Poison, Burn, Acid built and working; Vines, Chill, Shock, Bleed named but not implemented — movement-related ones (Vines, Chill, Shock) likely stay unimplemented for this project specifically, since Pixel Pugilists has no movement (§0.3).

## 7.3 Passives and tags

CURRENT DIRECTION. Needed, not optional -- part of the current content-pass scope (a dozen or so passives, authored as a new `UpgradeOption` subtype) and a core piece of how bracket entrants get their identity: each of the 16 starting familiars is meant to carry one species-bound passive (innate from the start, not drafted) alongside its base stats, using the same passive type the in-run upgrade pool later offers as a pickup.

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

Each of the 16 (or 32) starting bracket entrants should have exactly: a species (base stats + its one bound passive), one conditioned priority rule (a condition plus the technique it gates), and one unconditioned fallback technique (an empty-conditions `PriorityRule`, the same catch-all shape already used today). That's enough for every starting entrant to already fight noticeably differently from the others, giving the player a wide variety of jumping-off points to build from.

Familiars filling that skeleton can come from either of two sources: procedurally constructed at runtime (randomly draw a species + a starting technique + a starting priority rule from their respective pools), or hand-authored as complete fixed variations (today's `guubal.tres`-style familiars) that get drawn from directly. Nothing rules out mixing both approaches in the same bracket.

# 9. Tournament structure

CURRENT DIRECTION — the least-built part of this document; expect it to change once implementation starts.

## 9.1 The bracket

A single-elimination bracket of 16 or 32 entrants (exact size open), semi-randomly generated at the start of a run. The bracket screen doubles as the character-select screen — picking your entrant's spot in the bracket is how you start the run.

## 9.2 Loop

> 1\. Choose entrant (assume their spot in the bracket).
>
> 2\. Fight your round's match, fully autonomously.
>
> 3\. Choose upgrade(s).
>
> 4\. Inspect surrounding bracket results (see §9.3).
>
> 5\. Repeat from step 2 until the final match.
>
> 6\. Absurd final showdown between two heavily-built familiars.

Whether an upgrade choice also happens before the very first fight (in addition to after each round) is open — worth playtesting both ways once there's an upgrade pool to offer from.

## 9.3 Simulated off-screen fights

Matches elsewhere in the bracket that the player doesn't take part in are *not* played through the full combat engine — they're resolved by comparing the two entrants' stats/builds into a win probability, then rolling against it. This is deliberately lightweight: full simulation of every bracket match would be expensive for no real payoff, since the player never sees them play out move-by-move.

**Open questions to settle before implementing:**
- What exactly feeds the odds calculation — raw stat totals, or does technique/priority-rule quality factor in too? Cheaper is better unless it visibly produces bad-feeling odds.
- What fidelity does the player see when scouting an upcoming or already-decided match — an exact percentage, or a coarser signal (Favored/Toss-up/Underdog)? A coarser signal probably sits better with "occasional unclear outcomes and upsets" being a deliberate feature, not noise.
- Is scouting free/always-visible, or a resource/choice the player spends something on? Given this project has no economy (§0.3), it's likely free — but worth deciding deliberately rather than defaulting.

## 9.4 Upgrade choices between rounds

The current pre-fight `PriorityBuild` picker (choose between whole pre-authored rule sets) is a deliberate stopgap built to avoid removing all player agency before this section existed — see the codebase's `DECISIONS.md`. Once this section is actually implemented, it should likely replace or absorb that picker: post-round upgrades are the real place build choices happen, and they should feel like real theorycrafting decisions (new technique, new priority rule, a stat bump, etc.) rather than picking a whole premade build each time.

## 9.5 Loss ends the run

Single elimination means losing a match ends the run — no Reputation-style buffer like the full game's career (`FAMILIAR_FIGHT_CLUB_VISION.md` §11.4). Worth confirming this feels right once there's a real run to lose; a bracket-flavored buffer (e.g. a rare "second chance" upgrade) is a reasonable thing to consider later if losses feel too punishing, but isn't planned now.

# 10. Development roadmap

Tracked in detail in `LEARNING_ROADMAP.md`; summarized here for design context.

**Done:** combat engine, 19 statuses (Poison/Burn/Acid/Bleed/Stagger/Stun/Foretell/Defending/Fortify/Hone/Enlarge/Recharge/Infestation/Ward/Hex/Absorption/Ruin/Thorns/Retaliation), techniques-as-composable-steps (`TechniqueStepGroup`/`TechniqueAction` — hit/heal/status-apply/status-modify actions, gated per-group by conditions, with situational `DamageBonus`es), the priority-rule behavior system for both sides, the pre-fight build-select stopgap, sequential per-step combat resolution (each hit/heal/status application gets its own paced log line rather than one batched turn summary).

**Next:** finish the current content-pass milestone (more familiars/techniques/traits, tracked in `LEARNING_ROADMAP.md`), then build a real in-run priority-rule editor -- the §9.4 replacement for the `PriorityBuild` stopgap. Picking up a new technique between rounds with no way to see or arrange whether it'll actually trigger is a real gap, and the bracket shouldn't be built on top of it.

**After that:** the tournament/bracket structure (§9) itself, then whatever its open questions resolve into, and playtesting/balance passes.

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