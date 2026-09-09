**Familiar Fight Club**

**Foundational Game Design Document v2**

*Long-term full-game vision — not this project's current scope*

**A note on what this document is**

> This is the original full-scope design for *Familiar Fight Club*: a creature-raising auto-tactics game with a career loop, Ranch, circuits, campaign narrative, and postgame challenge system. It is preserved here as the long-term vision the team is building toward, informed by lessons learned along the way.
>
> **This repository is not currently building this game.** The active project in this repository is *Pixel Pugilists* — a deliberately much smaller, standalone tournament-roguelike prototype and proof-of-concept, with no meta-progression, no career/Ranch systems, and no narrative. See `GAME_DESIGN.md` for what is actually being built right now.
>
> Once Pixel Pugilists has proven its core combat-and-buildcraft thesis, work may begin on the full Familiar Fight Club described below, incorporating validated lessons (turn timing, stat design, technique/status/priority-rule shapes, bracket-simulation mechanics) rather than starting design from scratch. Until then, treat this document as reference and aspiration, not an active backlog.

**Document purpose**

> Define the current intended direction of Familiar Fight Club while clearly separating established design pillars from provisional systems, prototype questions, and deprecated ideas. This document is intended to be usable as both a human design reference and an implementation brief for AI-assisted development.

# 0. Document status and revision policy

LOCKED

This is the current authoritative design baseline for Familiar Fight Club. It supersedes the original foundational document where the two conflict. It does not pretend that unresolved systems are finalized.

## 0.1 Status vocabulary

| **Status**            | **Meaning**                                                                                                                               |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| **LOCKED**            | A foundational design commitment. It should not change casually, although playtesting can still reveal that a locked assumption is wrong. |
| **CURRENT DIRECTION** | The intended solution today, but still subject to iteration as the project becomes playable.                                              |
| **OPEN / PLAYTEST**   | Deliberately unresolved. The prototype should help answer this question rather than the document choosing prematurely.                    |
| **DEPRECATED**        | An older design direction that should not be treated as current unless deliberately revived.                                              |

## 0.2 What changed from v1

- The central fantasy and theorycrafting-first identity remain intact.

- Combat timing and the exact universal stat model are now explicitly open questions rather than assumed to be solved.

- The first prototype has been reduced dramatically. It begins without movement and exists to prove buildcraft, readable automated decision-making, and satisfying combat resolution.

- Universal knockout injuries have been removed from the baseline design.

- The performance-reward concept has shifted toward varied fight objectives and medals rather than a single spectacle metric that favors only speed or raw damage.

- The campaign now has a light anime-style narrative culminating in a corrupt league organization stacking the odds against the player.

- Defeating that organization opens a postgame league-management fiction and a Hades II-style configurable challenge system whose thresholds unlock new content.

## 0.2A What changed in the 2026-09 delta reconciliation

Reconciled against a separate design-delta document (`FFC_Recent_Design_Canon_and_Delta_v2_Audited.md`, 2026-09) covering ground this document previously left thin. New or substantially expanded: world/setting/visual identity (§1A), high-speed-playback presentation requirements (§2.4), two new design pillars on state/event-driven combat and reusable compositional primitives (§3.8, §3.9), a new Combat Signals/Events/Ledger system (§4A), an expanded priority-rule comparison grammar (§6.2), a new Technique Fusion/Linking system (§6.5, deliberately left with unresolved legality/cost/Recharge-interaction details), a clarification that species/types are primarily non-combat classification (§9.1), a new cosmetic dress-up subsection (§9.5), an expanded status-baseline list (§10.5), a bracket-as-living-system subsection covering real NPC simulation and scouting-reveals-strategy (§12.6), a boss-progression-as-mechanical-preview subsection validated directly by Pixel Pugilists' own final boss (§12.7), and a four-stage recruitment/acquisition progression ending in Perfect Essence (§14.4). One direct, unresolved contradiction was surfaced rather than silently merged: §14.5's prior "no exact clones" language conflicts with Perfect Essence's exact-recreation capability — flagged in place, needs an explicit developer decision.

## 0.3 Production hierarchy

Familiar Fight Club contains three nested games: the combat engine, the familiar career, and the campaign/metagame. Development should prove them in that order.

> 1\. Combat engine — Is building a familiar and watching its autonomous combat logic express that build fun?
>
> 2\. Familiar career — Does constrained development across tournaments create memorable, distinct build arcs?
>
> 3\. Campaign and metagame — Do circuits, Ranch persistence, unlocks, narrative, and postgame challenge structure make repeated careers meaningful?

**Note:** *Pixel Pugilists* (the project actually being built now — see `GAME_DESIGN.md`) is validating layer 1 and a compressed, single-run stand-in for layer 2's core question (does an accumulating build across a run feel good), deliberately without layer 3 or the full career/Ranch shape of layer 2.

# Contents

- 1\. High concept

- 2\. Core player experience

- 3\. Design pillars

- 4\. Combat foundation

- 4A\. Combat signals, events, and ledger

- 5\. Combat timing and universal stats

- 6\. Behavior and autonomous decision-making

- 7\. Coaching and intervention

- 8\. Spatial combat, movement, and arenas

- 9\. Familiar construction

- 10\. Techniques, passives, tags, and statuses

- 11\. Career structure and development

- 12\. Tournaments, circuits, and campaign

- 13\. Performance objectives and medals

- 14\. Economy, recruitment, and persistent progression

- 15\. Retirement and the Ranch

- 16\. Postgame league and custom tournaments

- 17\. Prototype roadmap

- 18\. Playtest questions

- 19\. Deprecated or non-baseline systems

- 20\. Current elevator pitch and core identity

# 1. High concept

LOCKED

Familiar Fight Club is a creature-raising auto-tactics game in which the player develops a familiar, constructs a coherent combat build, and guides that familiar through a finite competitive career.

The player is not primarily a pilot issuing an attack every turn. The most important agency happens before and between fights: selecting techniques and passives, shaping behavior priorities, responding to development opportunities, and adapting the familiar to upcoming opponents.

Combat is the performance generated by that preparation. The familiar should win in ways that visibly belong to the build the player created.

Central fantasy: Raise a unique creature, construct a coherent combat engine, and watch it win in a way that feels personal, clever, and spectacular.

## 1.1 What the game is not

- Not a conventional turn-based RPG where the player chooses every action directly.

- Not an opaque autobattler where the player cannot understand why a unit behaved a certain way.

- Not primarily a collection game where species alone determines combat identity.

- Not a permanent-party progression game where one familiar is expected to grow forever.

## 1A. World, setting, and visual identity

LOCKED / STRONG DIRECTION (added from the 2026-09 design-delta reconciliation — see revision note at the end of this section)

FFC should not read as generic medieval fantasy plus Pokémon. The premise is:

> **The industrialized/modern-ish world already existed, and then magic arrived or became newly accessible.** Society did not grow around magic from antiquity — already-existing institutions had to react to a new impossible phenomenon.

This means magic gets absorbed into universities, laboratories, corporations, factories, transit systems, regulators, organized sport, broadcast media, organized crime, medicine, research, markets, consumer culture, and public infrastructure — not into castles and guilds. The aesthetic is **post-industrial occult noir**: old brick, concrete, steel, industrial districts, elevated rail, wet streets, neon/signage, modern clothing, arenas, laboratories, strange containment rigs, arcane instrumentation, improvised magical retrofits, aging infrastructure modified *after* magic arrived. The target feeling is *ordinary infrastructure with strange arcane systems bolted onto it later*, not *generic fantasy buildings with gears and glowing crystals pasted on*.

**Magic and familiars should feel like phenomena** society is still classifying, not a conventional spell list. Familiars can be strange enough to challenge simple biological categories — an arcane ferret-like creature, a golem composed of a collector's treasured pebbles, an heirloom pen that gradually began behaving like a living creature, industrially adapted magical wildlife, object-like manifestations, occult organisms, creatures that appear to be environmental or emotional phenomena. Not every familiar needs an industrial origin story; some should simply be mystical creatures now inhabiting an industrialized magical world. Scientists, corporations, trainers, researchers, and ordinary people may genuinely disagree about what familiars fundamentally are — that ambiguity is a feature, not a gap to close.

**Visual/magical language is CMYK-derived**, a recurring symbolic system across the world (spell/technique VFX, UI accents, research classifications, signage, occult diagrams, corporate/academic iconography, magical machinery, familiar traits, environments, ritual equipment, narrative symbolism):

| Color | Category |
|---|---|
| Cyan / Teal | Arcane |
| Magenta / Purple | Occult |
| Yellow / Gold | Divine |
| Black | Void |
| White | Aether |

The exact metaphysical relationship between these five categories is **open** — treat the color-language mapping itself as current direction, not the underlying cosmology.

**Riverton** is the current leading candidate for FFC's main anchor city — major arena/tournament district, industrial zones, a research institute, markets, transit infrastructure, contaminated/abandoned industrial sites, Ranch/training facilities, corporate presence, broadcast/sports media, organized crime, regulatory presence. It should support both the competitive sport and the broader mystery of how society is adapting to magic.

**Sebastian** is a strong candidate for connective tissue across eras: *competitor/champion-era figure → retired researcher/familiar authority → potentially an older professor-like elder authority later in the timeline*. The strongest characterization is that people assume he left competition because he could no longer keep up, when the real reason is that understanding what familiars and magic actually *are* became more compelling to him than continuing to compete. A retroactive tie to the Pixel Pugilists protagonist/player figure, and later mentor/Ranch-presence/commentator/public-figure roles, are possibilities worth keeping open, not separately locked requirements.

*(This subsection was added wholesale from a 2026-09 design-delta document that reconciled recent worldbuilding/visual-design discussion against this vision doc — the prior version of this document had no dedicated world/setting/visual-identity content at all. Treat the mechanical sections below as the more load-bearing/established part of this document; this section is comparatively newer and less battle-tested.)*

# 2. Core player experience

LOCKED

## 2.1 Theorycrafting

The player should repeatedly ask: “What can I build from the opportunities this familiar has received?”

Build identity emerges from the interaction of species, individual traits, techniques, passives, status synergies, behavioral logic, and the choices offered during the career. The game should reward coherent engines and unusual interactions rather than converging immediately on one universally correct build.

## 2.2 Execution as payoff

Watching a fight should provide feedback on the player’s preparation. The player should be able to recognize what the familiar attempted, why it attempted it, what triggered, and why the result differed from expectation.

Ideal reaction: “It did exactly what I taught it to do — and all the pieces triggered together.”

## 2.3 Attachment through finite careers

A familiar should feel individual because its career is finite. Opportunities are constrained, builds cannot acquire everything, victories and mistakes become part of a record, and retirement closes one competitive story while feeding future careers.

## 2.4 Presentation must survive high-speed playback

STRONG DIRECTION (added from the 2026-09 design-delta reconciliation)

Because both PP and FFC are autobattlers, "execution as payoff" (§2.2) depends heavily on VFX/SFX quality — and players may watch combat at accelerated speeds such as 4×. Effects need to remain readable, satisfying, and non-chaotic when many automated actions resolve quickly, not only at normal speed. Treat high-speed readability as a real presentation constraint to test against directly, not an afterthought discovered late. Exact audio/VFX implementation remains open.

# 3. Design pillars

LOCKED

## 3.1 Theorycrafting is the main form of agency

The most important decisions happen while developing and configuring the familiar. Observation during battle matters, but the game should not drift into full manual control.

## 3.2 Simple baseline rules, expressive exceptions

The universal rules should be easy to explain. Complexity should come from techniques, passives, statuses, triggers, and special interactions that bend those rules in readable ways.

## 3.3 Autonomous combat must be legible

Automation is satisfying only when the player can form expectations. Every important autonomous decision needs understandable causes, and unexpected behavior must be inspectable after the fact.

## 3.4 Build variety should change behavior, not only numbers

A powerful build is more interesting when it creates a distinctive combat pattern: maintaining a status engine, countering, chaining follow-ups, setting up a delayed payoff, exploiting movement, or deliberately breaking normal action rules.

## 3.5 Variable opportunities create career stories

Curated randomness should constrain what a familiar can become without making success arbitrary. The player adapts to opportunities rather than assembling the exact same solved build every run.

## 3.6 Each familiar has a finite story

A familiar eventually leaves active competition. Retirement converts one finished build and one finished career into persistent legacy rather than erasing that familiar from the player’s world.

## 3.7 Difficulty should unlock possibility

Later challenge should not only inflate enemy numbers. Harder competition should introduce new opponents, new build pressures, new species or candidate pools, and other content that expands the game’s possibility space.

## 3.8 Combat is state/status/event/history driven, not type-chart driven

LOCKED (added from the 2026-09 design-delta reconciliation)

FFC combat should **not** revolve around Pokémon-like elemental weakness charts or direct type-matchup multipliers. The main combat language is instead statuses, current state, recent turn state, historical battle state, event signals, technique properties/tags, positioning, conditional behavior, action economy, and resource/cooldown state (see the new §4A, Combat Signals, Events, and Ledger). The strategic question is not "what element beats this enemy?" but "what state is the fight currently in, what state am I trying to create, and how does my familiar respond to that?"

This directly informs §9.1 (Species): familiars keep flavorful **types**, but those types are primarily non-combat classification (acquisition, raising, meta progression, research/identity, thematic technique access) rather than a damage-multiplier chart. A fire-aligned familiar naturally has access to many Burn-oriented techniques and related build pieces — that's the type's combat *influence*, not a type-vs-type resistance table.

## 3.9 Prefer reusable compositional primitives over combinatorial content multiplication

LOCKED (added from the 2026-09 design-delta reconciliation)

FFC's biggest production risk is combinatorial content multiplication — familiars, techniques, passives, statuses, priorities, the combat ledger, events, grid movement, terrain, tournaments, brackets, NPC simulation, circuits, the Ranch, acquisition, story, maps, modifiers, and career progression can each demand bespoke content if treated in isolation. Prefer reusable primitives that recombine into content over authoring bespoke systems for every circuit, familiar, or tournament — the game should become deep because shared systems combine in surprising ways, not because each new piece of content requires its own mechanical ecosystem. This governs circuits specifically (§12.2: circuits should remix existing systems more often than they demand bespoke new ones) and cosmetics specifically (§9.5), but is stated here as the general production rule those sections apply.

# 4. Combat foundation

LOCKED

## 4.1 Match format

The baseline match is one familiar versus one familiar. Combat is automated according to each familiar’s configured capabilities and decision logic.

## 4.2 Action economy

CURRENT / PROVISIONAL

The intended full game should have a small, understandable baseline action economy. The earlier design used one movement plus one action per turn; that remains a useful reference model, but exact timing and action structure should be validated in prototypes.

Techniques and passives may create explicit exceptions, such as follow-up attacks, reactions, counters, movement after attacking, or thresholds that allow additional actions.

## 4.3 Determinism and variance

The underlying rules should be dependable. Randomness should be explicit or constrained rather than hidden inside broad accuracy, resistance, or AI unpredictability systems.

- Explicit probability effects may exist when clearly communicated.

- Enemy behavior may choose among known or inferable options rather than following one fixed script.

- Later spatial arenas may vary between authored layouts, but the loaded arena state should be visible and stable.

- Status resistance should preferably modify outcomes predictably rather than causing invisible percentage failures.

# 4A. Combat signals, events, and ledger

CORE / STRONG DIRECTION (new section, added from the 2026-09 design-delta reconciliation — this system did not previously exist anywhere in this document)

## 4A.1 The problem: plain damage has too few hooks

A recent PP realization worth carrying into FFC's foundational design: **plain damage attacks currently interact with much less of the combat system than status-oriented attacks do.** Applying a status immediately creates interaction points (is target afflicted, is it above a threshold, can it be consumed/protected/scaled-with, does applying or decaying it fire a trigger, can it be compared between targets) — a plain "deal 8 damage" often happens and leaves nothing behind, which makes status techniques feel like real build pieces while plain attacks feel like filler. **Do not solve this by putting statuses on every attack.** Build a broader interaction language instead — the rest of this section.

## 4A.2 Four kinds of readable combat information

- **Current state** — persistent information currently true: HP, statuses, recharge, buffs/debuffs, position, active defenses, current target state.
- **Event signals** — things that just happened: `hit`, `damage_dealt`, `damage_taken`, `status_applied`, `status_removed`, `status_consumed`, `healed`, `technique_used`, `turn_started`, `turn_ended`, `multi_hit_turn`.
- **Technique properties / tags** — structural facts about the technique itself: attack, multi-hit, heavy, defensive, healing, status, direct damage, movement, ranged, etc.
- **Historical / ledger state** — accumulated memory of the fight (§4A.4): total Poison applied, total direct damage dealt, largest hit this combat, damage the enemy took last turn, hits landed this turn, total Bleed consumed, total healing received, number of heavy techniques used.

Statuses remain the richest form of persistent state (§10.5/§10.6 still apply), but they are not the only interaction surface.

## 4A.3 Multi-hit needs a real runtime signal, distinct from a technique tag

FFC needs a signal equivalent to *"this familiar hit multiple times this turn,"* kept distinct from a static `multi_hit` technique tag. A technique can be inherently multi-hit, but a familiar may also hit multiple times because of technique fusion (§6.5), a passive's extra attack, a follow-up, a chained action, or several separate single-hit effects landing in the same turn. So: `multi_hit` (technique property, structural) is a different thing from `hits_this_turn >= 2` / `multiple_hits_this_turn` (runtime event/state, actual). This lets a passive like *"after you hit multiple times in a turn, gain Hone"* trigger correctly regardless of *why* the extra hit happened — a real example of the interaction density this system is meant to enable.

## 4A.4 Combat Ledger / Combat History

FFC should maintain a **Combat Ledger** separate from visible statuses. Statuses answer "what is true now?"; the ledger answers "what has happened?" Useful categories, starting with a curated subset rather than tracking every imaginable statistic:

- **Per-turn state**: hits dealt this turn, direct damage dealt this turn, status damage dealt this turn, damage taken this turn, healing performed/received this turn, status stacks applied/consumed this turn, techniques used this turn.
- **Previous-turn snapshot**: the same fields, one turn back (e.g. damage the target took last turn, hits the target landed last turn).
- **Combat totals**: total hits, total direct damage, total status damage, total damage taken, total healing, total status stacks applied/consumed, per-status totals, total techniques used by tag, largest hit, largest healing instance, turns survived, etc.

This creates a real ledger-based technique design space — e.g. *Toxic Reckoning* (damage equal to total Poison stacks applied to the target this combat), *Echo Strike* (damage based on total damage the target took last turn), *Blood Memory* (bonus damage based on total Bleed consumed this combat), *Vindication* (heal based on damage taken last turn), *Combo Engine* (gain Hone if you hit at least 3 times this turn), *Pressure* (consecutive direct-damage actions strengthen until interrupted), *Record Breaker* (a benefit for exceeding your own previous largest hit). The broader principle: **the battle itself becomes an accumulating object techniques can query**, letting late-fight techniques become more powerful because history has accumulated — not just because a status happens to be stacked high.

## 4A.5 Statuses + events + history + tags = the core mechanical substrate

Together, these four categories are the main interaction substrate for combat, and should be read as one system rather than "statuses, plus some other stuff." This creates room for raw-damage archetypes, multi-hit archetypes, defensive archetypes, healing archetypes, combo/momentum archetypes, genuinely statusless archetypes, retaliation, history-scaling attacks, and fused-technique engines — all without needing a bespoke status invented for each one. Non-status build ecosystems are an explicit, intended archetype: plain damage should be able to form real builds via consecutive direct-damage turns, heavy hits, multi-hit turns, retaliation after taking damage, missing-HP scaling, damage dealt last turn, largest hit, total hits, attacking *without* applying statuses, repeated use of the same attack class, attack streaks, and damage thresholds — e.g. bonus damage for consecutive turns without applying a status, which turns "statusless" into a readable property of recent behavior rather than an absence of build identity.

**Even with this broader signal language, combat should remain more status/state-centric than type-matchup-centric** (§3.8) — statuses stay especially useful because they persist, are visible, provide readable thresholds, create strong conditional hooks, allow setup/payoff loops, create tactical identities, and work naturally with priority rules.

# 5. Combat timing and universal stats

OPEN / PLAYTEST

The exact turn-resolution model and universal stat line are intentionally unresolved. They should be chosen because they create interesting buildcraft and readable combat, not because the original design happened to use a familiar RPG convention.

## 5.1 Timing models worth testing

- Sequential initiative: Speed determines which familiar acts first, after which the second familiar evaluates the updated state.

- Simultaneous declaration: both familiars choose from the same beginning-of-turn state, then actions resolve according to a separate rule such as Speed or priority.

- Simultaneous outcomes: selected actions resolve in a way that permits mutual hits or other genuinely simultaneous results.

- Threshold/action-economy Speed: Speed contributes toward extra actions, extra movement, initiative thresholds, or other periodic advantages rather than only deciding first and second.

No one model is canonical until the combat prototype demonstrates which creates the best combination of clarity, tactical identity, and build diversity.

**Prototype status:** see `GAME_DESIGN.md` (Pixel Pugilists) for the live experiment — currently sequential/fixed alternation.

## 5.2 Stat design requirements

The universal stat line should stay small. Stats should support multiple build identities and ideally influence both direct power and tactical behavior. Physical/magical offense and defense should not be split by default unless playtesting proves a compelling need.

Historically useful candidates include HP, Power, Defense, and Speed, with Movement derived from species or combat systems. These names and roles are provisional.

**Prototype status:** see `GAME_DESIGN.md` (Pixel Pugilists) for the live experiment — currently HP/Power/Defense/Speed/Focus, with Speed and Focus not yet functionally used by any system.

## 5.3 Speed in particular

Speed should not automatically become the universally best stat. If it determines initiative, acting second must still support meaningful strategies. Alternatively, Speed may influence movement, specific technique scaling, action thresholds, or other systems. The correct role should emerge from prototype comparison.

# 6. Behavior and autonomous decision-making

LOCKED

## 6.1 Behavioral priorities

The player must be able to configure how a familiar chooses among its available actions. An ordered priority system remains the leading approach because it is expressive, inspectable, and understandable without becoming a full programming language.

A familiar should evaluate available options and choose according to stable rules. If an option is skipped, the game should be able to explain why: condition not met, target invalid, action unavailable, movement impossible, resource missing, or another explicit reason.

**Prototype status:** validated in Pixel Pugilists — see `GAME_DESIGN.md`. An ordered `PriorityRule` list (ANDed conditions + a technique) with per-skip logging is built and working for both sides of a fight.

## 6.2 Exact rule grammar

CURRENT DIRECTION

The original structure combined a condition, movement instruction, action, and target into one rule. This remains a strong candidate for the spatial game, but the prototype should begin with the smallest vocabulary necessary to test prioritization and build expression.

**Priority comparison language (strong direction, added from the 2026-09 design-delta reconciliation):** conditions should not be authored as a giant list of bespoke permutations. They should compare **arbitrary left/right value expressions** — conceptually `[left value] [operator] [right value]`, where either side can be drawn from useful value sources such as Me/Target, HP or HP%, stats, status stacks/values, flat numeric values, or percentages (e.g. *target Burn stacks > my Burn stacks*, *target HP > 12*, *target Defense > 12*, *target Power > my Defense*). The UI should expose this through configurable/scrollable condition building rather than authoring every possible comparison as its own hard-coded rule — this is the grammar §6.2 is deliberately keeping open room for, not a separate system.

## 6.3 Specialized logic

Advanced behavioral components may eventually be learned or unlocked. They should feel like useful tactical cards rather than syntax fragments in a complicated programming language. A specialized option should generally have a useful floor even outside its ideal matchup.

## 6.4 Explanation tooling

Readable AI is a feature, not only a debugging convenience. Useful surfaces may include the selected rule, skipped-rule reasons, triggered passives, status changes, and a compact event timeline. The first prototype should prioritize this visibility early.

## 6.5 Technique Fusion / Linking

CORE / STRONG DIRECTION (new section, added from the 2026-09 design-delta reconciliation — carried forward from an earlier four-character tactics-RPG concept that ports well into FFC)

**Technique Fusion / Linking** lets two techniques execute together in a single turn under one shared priority rule/behavioral instruction. The essential tradeoff:

> **You get both techniques in one turn, but you normally have to do both every time the fused instruction fires.**

Without fusion, two techniques can have fully separate priority conditions. With fusion, they're coupled under one priority rule — improving action economy while reducing behavioral granularity. Example: *Guard if HP < 50%* and *Renewal if HP < 30%*, authored separately, can be converted into a fused Guard+Renewal action — but now the two effects are tied together whenever that fused action is chosen, not "Technique A, plus Technique B only when B's own private condition happens to be convenient." At base Fusion, losing a separate conditional barrier for the second technique is part of the cost, which is exactly what makes Fusion an appropriately powerful metaprogression unlock (§16).

**Fusion progression can become more sophisticated** over the course of metaprogression: basic Fusion (two techniques coupled, executing together under the same priority logic) can later be joined by a **composite-conditioning** unlock that restores some control by letting the fused/composite technique be gated behind an *additional* condition on top of the fusion itself — powerful precisely because base Fusion sacrifices that granularity. The exact rule syntax for composite conditioning is open; do not assume a specific implementation (e.g. "global condition then internal condition") until a technical design document locks one. Multiple fused pairs, triple-technique composites, or deeper nesting are exploratory, not current requirements.

**Fusion legality, costs, Recharge-interaction, and pair-compatibility are explicitly unresolved** — whether all component costs are always paid, how Recharge/cooldowns combine, how once-per-fight restrictions combine, whether the whole composite must be legal before it can fire, what happens when one component has an invalid target/state, and which technique pairs are considered compatible are all open design questions, not assistant-invented rules to treat as canon. The one locked conceptual constraint is: **at base Fusion, linked techniques execute together rather than retaining fully independent conditional behavior.** Everything past that needs its own explicit design pass.

**Metaprogression should more broadly let players build more sophisticated machines, not simply bigger stats** — this is the philosophy Fusion is one instance of. Early player logic: *if X → use Y*. More advanced: *if X AND Y → use Z*. Later: *if X OR Y → use Z*. Later still: combine two techniques into one action, then eventually gain more control over when that composite action is allowed to fire. Strong metaprogression axes beyond Fusion itself: additional priority/rule capacity, additional conditions, AND/OR logic, richer comparison/value sources (§6.2), more readable battle-history variables (§4A.4), additional fused pairs, extra conditional control over fused techniques.

Progression should also let earlier resource gates loosen as later ones become the frontier: advanced mechanics can have meaningful costs when first unlocked so they feel special, but as the player pushes into harder routes, older resources should become increasingly plentiful relative to what the player can realistically spend — shifting the active question from "can I afford the old mechanic?" to "the old mechanic is now part of my normal toolbox; the newer resource/mechanic is the real constraint." Legacy Points (§14.3) already point at "unlock breadth, not stat superiority" — this is the same philosophy applied specifically to combat-logic sophistication rather than to Ranch/acquisition breadth.

# 7. Coaching and intervention

CURRENT DIRECTION

Combat remains autonomous, but the player may receive limited opportunities to influence execution without replacing preparation with direct control.

The original “force a currently valid learned rule to the top of the priority list” remains a strong model because it means: “Do the thing I taught you, but do it now.” Exact intervention count, timing, and tournament economy are not locked.

## 7.1 Constraints

- Intervention should not invent a capability the familiar does not have.

- Intervention should not turn every battle into manual move selection.

- Intervention should be scarce enough that saving it versus spending it creates tension.

- Between-round coaching may allow reconfiguration using already learned components without granting new training during the bracket.

# 8. Spatial combat, movement, and arenas

CURRENT DIRECTION

Movement remains part of the intended full game, but it is deliberately excluded from the first prototype so that combat logic can be validated before spatial AI multiplies complexity.

## 8.1 Grid

OPEN / PLAYTEST

The original 5×5 arena remains a useful baseline candidate, especially because it provides a true center tile, meaningful edges and corners, and enough room for melee/ranged distinction. It is no longer treated as a fixed requirement.

## 8.2 Movement philosophy

When movement returns, the player should generally teach broad intentions rather than micromanaging exact destination tiles. Examples include approaching, retreating, maintaining distance, seeking cover, avoiding hazards, or remaining stationary.

The exact destination should be selected through stable internal rules so players can develop intuition about how a familiar interprets an instruction.

## 8.3 Arena features

Arenas should contain a small number of strategically meaningful elements that create build expression rather than environmental puzzle solving.

- Walls or edges that interact with forced movement.

- Cover or blockers that matter to ranged actions.

- Hazardous or beneficial zones.

- Destructible or interactable objects.

- Simple mechanisms whose rules are visible once the fight begins.

# 9. Familiar construction

LOCKED

## 9.1 Species

Species defines the familiar’s broad chassis and visual identity, not its entire build. It may influence baseline stats, movement traits, technique affinities, or a species-specific passive, but species should provide useful primitives rather than prescribing one narrow element or status theme.

Species/familiar **types** are primarily a *non-combat* classification — acquisition, raising/development, meta progression, research/classification, familiar identity, and thematic technique access/affinity — not a Pokémon-style combat weakness/resistance chart (see §3.8). A fire-aligned familiar naturally has access to many Burn-oriented techniques and related build pieces; that's the type's combat influence, expressed through the same status/state/event language every other familiar uses, not a type-vs-type multiplier applied on top of it. The exact type taxonomy, and every non-combat system that reads type, remain open — do not infer a breeding system, tournament-eligibility system, or other type-dependent subsystem unless another design document explicitly establishes one.

## 9.2 Individual identity

Two members of the same species should be capable of developing differently. Small stat differences, innate traits, affinities, and career opportunities can nudge the player toward different builds without creating obviously worthless candidates.

## 9.3 Innate traits

CURRENT DIRECTION

Familiars should begin with one or more innate traits that do not compete directly with ordinary passive slots and that help establish individual identity. Rarity should describe unusualness or rule-changing potential, not a simple ladder of numerical superiority.

Innate traits may influence combat, development opportunities, or both. Effects that alter future offerings are especially valuable because they make the career itself feel different.

## 9.4 Build limits

OPEN / PLAYTEST

The final loadout will likely limit techniques, combat passives, behavioral rules, and innate traits through separate or partially separate capacities. Exact slot counts and whether unusually versatile components consume additional capacity should be determined after the component systems are playable.

## 9.5 Cosmetic familiar dress-up

EXPLORATORY / STRONG RECENT IDEA (added from the 2026-09 design-delta reconciliation)

A recent cosmetic direction is accessory/clothing packs that let players decorate familiar sprites — closer to Pokémon Contest-style dress-up than a conventional equipment paper-doll system. Per §3.9's scope discipline, the implementation should stay deliberately lightweight: don't author bespoke equipment slots for every familiar/accessory combination; expose general attachment/anchor points, let the player place and rotate cosmetic pieces, then effectively "glue" the cosmetic to the sprite at the chosen transform. The goal is expressive cosmetic packs without multiplying sprite-authoring work across the entire familiar roster.

# 10. Techniques, passives, tags, and statuses

CURRENT DIRECTION

## 10.1 Techniques

Techniques are active combat actions. Availability should often be constrained by battlefield state, position, target state, cooldowns, prior actions, stored effects, or other explicit requirements rather than by one universal mana system.

Reliable techniques and setup/payoff techniques should coexist. Reliable actions are valuable because they work immediately and provide fallbacks; synergistic actions earn higher ceilings through deliberate preparation.

## 10.2 Technique development

CURRENT / PROVISIONAL

Techniques may have authored upgrade paths that allow the same base technique to evolve into different roles. The earlier three-path structure with a committed path and limited cross-pathing remains a useful model, but exact tree shape and capstone pacing are not locked.

## 10.3 Combat passives

Combat passives modify rules, create triggers, enable follow-ups, interact with tags and statuses, or alter behavior incentives. Their value should come primarily from combinations rather than isolated stat bonuses.

## 10.4 Tags

Complexity should be expressed through a readable tag vocabulary rather than unnecessary parallel stat systems. Possible tags include Contact, Projectile, Fire, Venom, Acid, Lightning, Charge, Bite, Summon, Healing, Guard, Forced Movement, and Terrain. The exact taxonomy remains content-driven.

## 10.5 Status baseline

The originally established status vocabulary was Poison, Burn, Acid, Vines, Chill, Shock, and Bleed. Exact numbers, stack caps, durations, and final clauses remain balance variables, but the statuses should have distinct baseline jobs.

| **Status** | **Baseline identity**                                                                 |
|------------|---------------------------------------------------------------------------------------|
| Poison     | Stacking damage-over-time effect with decay or consumption opportunities.             |
| Burn       | Persistent damage-over-time effect that is simpler and less stack-centric by default. Reapplying Burn to an already-burning target should trigger a distinct "Flare" moment — bonus immediate damage scaled to however much duration remained — in addition to refreshing the duration. This rewards refreshing Burn before it fades rather than making reapplication a no-op. |
| Acid       | Defense-reduction / vulnerability effect with stacking potential. Baseline duration is indefinite — Acid persists until the battle ends, or (once such systems exist) until cleansed or cancelled by an opposing defensive buff, rather than decaying on its own. |
| Vines      | Movement-control effect, especially relevant once spatial combat is introduced.       |
| Chill      | Movement reduction or other mobility pressure over a duration.                        |
| Shock      | Punishes movement, historically by dealing damage as the afflicted familiar moves.    |
| Bleed      | Stacking delayed-payoff damage whose eventual burst scales with accumulated stacks.   |

**The vocabulary has since grown substantially in Pixel Pugilists** (as of this writing: Poison, Burn, Acid, Bleed, Stagger, Foretell, Stun, Defending, Infestation, Hone, Fortify, Enlarge, Recharge, Thorns, Ward, Hex, Absorption, Ruin, Retaliation, Stasis, Renewal, Lifesteal, Regeneration, Cleanse — plus a further-explored "Persistence"-style status-preservation concept). **Treat the exact current implementation list as something to pull from PP's own current status/content data when needed, not from this vision document** — the important design point was never any single frozen list, it's that statuses act as reusable interaction primitives rather than generic RPG ailments. Several of PP's newer statuses demonstrate especially useful interaction patterns worth preserving as *patterns*, independent of their exact PP numbers:

- **Recharge** — shared cooldown-like state that other mechanics can read, reduce, or manipulate (see §16 on why bypassing/reducing it deserves the same scrutiny as an extra action).
- **Ward** — a readable defense specifically against enemy status/debuff application, distinct from HP-damage mitigation.
- **Hex** — turns the *event* of a status being applied into something that itself generates value, not just the status's own direct effect.
- **Foretell** — a delayed/countdown payoff, rewarding a setup investment that pays off later rather than immediately.
- **Stasis** and similar preservation mechanics — intercepting or altering status *loss* (rather than status gain) as its own distinct archetype.

The general rule carried forward: **statuses should create readable state that other techniques, passives, priorities, and events can inspect, preserve, consume, transform, or react to** — this is the same substrate described in §4A, just with statuses as the richest (not the only) layer of it.

## 10.6 Deterministic resistance

CURRENT DIRECTION

Status resistance should usually modify application predictably rather than create hidden “resisted” percentage rolls. Possible levers include fewer stacks, shorter duration, reduced damage, faster decay, lower maximum stacks, or weakened secondary effects.

# 11. Career structure and development

CURRENT DIRECTION

## 11.1 Finite career

The player raises one active competing familiar through a finite career. Exact career length remains a pacing question, but the earlier target of roughly 60–90 minutes is still a useful reference rather than a locked requirement.

## 11.2 Career loop

> 1\. Select or acquire a familiar candidate.
>
> 2\. Choose or enter an available circuit.
>
> 3\. Complete a short development phase.
>
> 4\. Enter a tournament or major fight sequence.
>
> 5\. Coach and adapt between rounds where allowed.
>
> 6\. Receive rewards, losses, career consequences, and new opportunities.
>
> 7\. Continue through the circuit until the familiar retires through victory, depleted career viability, or another explicit ending condition.
>
> 8\. Return to the Ranch, where the retired familiar contributes to persistent progression.

## 11.3 Three-week development rhythm

CURRENT DIRECTION

The current baseline is approximately three development opportunities between tournament events. Each week presents a curated-random set of choices such as learning a technique, gaining a passive, upgrading a technique, adjusting stats, obtaining specialized logic, scouting, recovering from a special debuff, or triggering a special event.

Offerings should mix support for the current build, broadly useful value, and at least occasional pivot opportunities. Special events can provide more targeted control when the player needs to address a weakness or pursue a specific synergy.

## 11.4 Loss and career viability

OPEN / PLAYTEST

The run-ending consequence of losing is deliberately unresolved. One-loss careers may create strong tension if fights are fair and predictable enough, but may be too punitive if the game expects experimentation.

The leading alternative is Reputation as “career HP.” Losses deal significant Reputation damage; some powerful services, risks, or shortcuts may also cost Reputation; recovery is rare; reaching zero ends the career. This allows meaningful failure without automatically ending every run after one bad matchup.

## 11.5 Persistent debuffs

CURRENT DIRECTION

There is no universal injury system. Rare events, explicit opponent effects, curses, or risky choices may inflict persistent or difficult-to-remove debuffs as memorable career complications, but ordinary knockouts should not automatically generate an additional injury subsystem.

# 12. Tournaments, circuits, and campaign

LOCKED

## 12.1 Tournament format

Tournaments are short multi-fight sequences that provide the payoff for development. Before entering, the familiar commits to its current learned toolkit. Between rounds, coaching may allow reordering behavior, swapping already learned components, reviewing scouting, and allocating limited recovery or interventions, but not learning entirely new capabilities.

**Priority rules should encourage matchup adaptation, not accumulation** (strong direction, added from the 2026-09 design-delta reconciliation): players should not necessarily leave every known technique active in the priority list at all times. The game should actively encourage swapping techniques, changing priority rules, adjusting condition thresholds, adapting to specific opponents, and pivoting builds — tutorialization should explicitly push back on the likely beginner pitfall of "I learned six techniques, therefore I should always have all six active," teaching instead that a narrower, matchup-specific behavior set can be stronger. This connects directly to §7 (Coaching): coaching exists partly to make this narrowing/adaptation practical between rounds. Tutorialization more broadly needs to be unusually explicit given the player is programming behavior indirectly — covering how priority rules resolve, why a familiar chose a move, when to remove a technique from the active routine, how to change thresholds, how status state affects decisions, how to scout opponents, how to identify bad loops, how to avoid wasting techniques, and how to interpret a loss. The goal isn't explaining controls; it's teaching the player how to think about building an automated fighter.

## 12.1A Tournament routing: many available, only some required

CORE / LOCKED (new subsection, added from the 2026-09 design-delta reconciliation)

One of the most important recent structural decisions: a career/run should have **more tournaments available than the player is required to complete.** The player may need only a limited number of qualifying tournament completions before proceeding to a circuit/career finale — e.g. several Easy tournaments, several Medium, several Hard, perhaps Very Hard/special events, but only 3–4 successful completions required before the finale. This turns career progression into **routing**: the question becomes "which tournaments should I risk entering with this familiar and this build?" rather than "can I clear the exact next level?" A tutorial/first career may subtly introduce a safe route (Easy → Medium → Hard → Finale) before the player realizes they can enter Hard first, and eventually that Easy can be skipped entirely in favor of Medium → Hard → Very Hard.

This directly resolves a metaprogression tension noted in §3.7/§14.3 (difficulty should unlock possibility, not just bigger numbers): with many available tournaments, **progression lets the player voluntarily attempt more dangerous and rewarding content**, rather than either (a) permanent stat progression trivializing old content, or (b) enemies always scaling with the player so progression feels fake. Harder tournaments can offer stronger rewards, rarer acquisition opportunities, new techniques/passives, rare resources, prestige, unusual opponents, special-event access, or meta unlocks — the metaprogression goal is the player thinking "I can probably get away with entering this harder tournament now," not "my permanent +25% damage makes this trivial."

**Note for Pixel Pugilists:** PP's own single-run bracket structure is a compressed stand-in for this system (§0.3) and doesn't currently implement optional/skippable tournament routing — this section describes the full FFC career layer, not a requirement to retrofit into PP.

## 12.2 Circuits

The game contains several authored competitive circuits. Each circuit should have a thematic identity, characteristic opponents, development-event tendencies, and eventually spatial arena tendencies. Exact routing, transfers, and branching remain provisional.

**Circuits vs. tournaments, and what circuits can vary** (added from the 2026-09 design-delta reconciliation): a *tournament* is one discrete competition; a *circuit* is the broader competitive environment containing multiple tournaments, opponent pools, rules, themes, events, and reward/resource profiles. Circuits can vary entrant pool, difficulty distribution, tournament availability, arena/map rules, event pool, reward profile, which resources are emphasized, hazards, and thematic/regional identity — a key purpose being that **different circuits and harder routes can pay out different resources**, giving the player reasons to choose among them rather than merely climbing one linear difficulty ladder. This is the same "how much can I win, and how ambitious can I afford to be?" question §12.1A introduces at the tournament level, one layer up. Per §3.9's production-scope rule: **circuits should remix existing systems more often than they demand bespoke new ones** — avoid making every circuit require a unique mechanical ecosystem, a bespoke roster, and a large set of one-off maps; prefer recombination of shared primitives.

## 12.3 Narrative tone

CURRENT DIRECTION

The campaign uses a loose anime-style plot to connect the competitive climb. The story should add personality, rivals, escalating stakes, and memorable circuit identities without overwhelming the buildcrafting game with constant narrative interruption.

## 12.4 Campaign arc

> 1\. The player begins as an unknown trainer entering lower-level circuits.
>
> 2\. Each circuit introduces rivals, champions, organizers, local personalities, and small self-contained conflicts.
>
> 3\. As the player rises, suspicious patterns around matchmaking, favoritism, rules, or league control become more visible.
>
> 4\. The player eventually learns that a shady organization controlling the competitive ecosystem has been manipulating outcomes or protecting its interests.
>
> 5\. The final story tournament is deliberately unfair: the organization stacks rules, recovery, brackets, matchups, or other conditions against the player.
>
> 6\. Winning breaks the organization’s control and transitions the game into its long-term postgame fiction.

## 12.5 Narrative restraint

The conspiracy should remain readable and energetic rather than becoming a dense political thriller. The competitive scene, characters, and familiar careers remain the emotional center of the game.

## 12.6 Brackets as living systems: real NPC simulation, scouting, and sports stories

CORE / STRONG DIRECTION (new subsection, added from the 2026-09 design-delta reconciliation)

**The tournament bracket should be more than a fight-selection menu.** It can simultaneously function as opponent preview, scouting interface, route visualization, story generator, tournament-simulation display, character-selection context, and anticipation builder — PP already validates the character-selection use (the starting familiar is effectively chosen by taking over one entrant's bracket slot) and the scouting/route-visualization use (its own bracket screen). The overall bracket should feel alive, not static.

**Background tournament matches should actually simulate**, not resolve to arbitrary winners: NPC competitors fight one another, gain upgrades, change build direction, and create upsets over the course of a tournament — meaning the eventual final opponent can be the survivor of *their own* miniature roguelike run rather than a pre-scripted final boss. This is one of the strongest systemic narrative ideas in the design and should be preserved deliberately. **AI systems built to draft/evaluate builds for balance-simulation testing can double as actual NPC trainer logic** — different NPCs preferring status engines, defense, raw damage, specific technique tags, risky combos, counter-building, or specific familiar archetypes, so opponents develop systemically rather than receiving arbitrary scripted upgrades. (PP's own AI-drafting/priority-optimizer system, `docs/superpowers/specs/2026-09-06-ai-drafting-design.md`, is exactly this pattern already — see `GAME_DESIGN.md` §11.)

**Scouting should reveal strategy, not an opponent's exact build.** Rather than exposing a full exact loadout, scouting should expose archetype tags, recent performance, a rough stat profile, behavioral tendencies, build themes, and broad strengths/weaknesses — "Attrition / Poison / Defensive," not an exact technique list plus exact priority rules. This preserves uncertainty while still allowing informed preparation; the player should feel like a coach/scout, not an omniscient one.

**Real simulation naturally produces sports stories** — "that weird Guubal upset the tournament favorite and somehow made finals" — via concepts like favorite, underdog, heavy favorite, lock, upset, rivalry, dominant run, collapse, comeback, Cinderella run, tournament history, and familiar record. The system should produce narrative through competition rather than requiring every rivalry to be hand-authored. Following the sport this way also becomes a natural lens into the broader world (§1A): familiar fighting is simultaneously sport, entertainment, research opportunity, business, prestige system, social mobility, exploitation, regulation, advertising, celebrity culture, gambling/crime pressure, and corporate influence — which strengthens the corrupt-league storyline (§12.4) by grounding it in a competitive world the player has actually watched develop.

## 12.7 Boss progression can preview and unlock new mechanical layers

STRONG DIRECTION (new subsection, added from the 2026-09 design-delta reconciliation)

Bosses can do more than test raw build strength — tournament bosses can teach the player what the next layer of the game looks like. A recurring pattern worth building toward: an early "hard" tournament boss can use essentially every mechanic already in the player's starting arsenal (the fight asks "have you actually learned how the tools you already possess fit together?"), while a later "harder" boss can use a mechanic the player does **not** yet have access to — intentionally shocking on first encounter ("wait, it can do that?") — with beating that boss unlocking the mechanic for the player. **Technique Fusion (§6.5) is a strong candidate for a mechanic introduced this way.** This creates a progression rhythm: master current toolbox → see an enemy break the apparent rules → overcome it → gain that expressive tool yourself → discover a new frontier — which fits the broader metaprogression philosophy (§16) closely, and later/very-hard tournaments can keep revealing further layers beyond what previously looked like the endpoint.

At the far end, **an intentionally absurd final boss** can use abilities that look blatantly unfair, provided a sufficiently strong run can still beat them — e.g. applying every negative status to the player and every positive status to itself, then dealing damage scaling with the combined stack count across both combatants, potentially paired with an automated defensive passive. The design question is deliberately "how ridiculous can the final encounter appear while remaining beatable by a genuinely excellent build?" rather than forcing perfect symmetry, which fits roguelike final-boss philosophy better than a fair, symmetric fight would.

**Direct validation from Pixel Pugilists:** PP's own final boss (The Champion, `GAME_DESIGN.md` §9, `DEVLOG.md` session 12) already implements almost exactly this "absurd final boss" example — Calamity Manipulation applies the full negative-status kit to the target, Taste of Immortality sets the full positive-status kit on itself, and Reap scales damage off total unique statuses across both combatants — and the developer has confirmed via direct playtesting that the fight is difficult but genuinely beatable. This is real evidence the pattern works as intended, not just a promising idea on paper.

# 13. Performance objectives and medals

CURRENT DIRECTION

Winning is always sufficient for basic progression. Strong or stylish performance can grant additional rewards, but the game should not define “good play” as only winning faster through overwhelming damage.

## 13.1 Objective philosophy

Different fights, circuits, or opponents may offer performance objectives inspired by dungeon-medal systems: clear signals that encourage the player to demonstrate different forms of mastery.

- Defeat an opponent substantially faster than its expected fight length.

- Win while taking very little damage.

- Win after a comeback or from a disadvantaged state.

- Trigger a notable status interaction or setup-payoff chain.

- Exploit an arena feature once spatial combat exists.

- Win while satisfying an explicit restriction or special condition.

- Execute a rare build-specific interaction or finishing condition.

These are examples of objective categories, not a locked checklist. Objectives should be selected so different builds can shine rather than making every match ask for the same speed-clear solution.

## 13.2 Medals

Named medals can commemorate notable performance and make a familiar’s career record more memorable. Medals may grant bonus practical rewards, contribute to Legacy, or serve primarily as records and goals. Their exact reward weight remains open.

## 13.3 Baselines and opponent expectations

Where the game rewards unusually fast or dominant wins, it should compare performance against meaningful expectations for that opponent or encounter rather than arbitrary universal turn counts.

# 14. Economy, recruitment, and persistent progression

CURRENT DIRECTION

## 14.1 Money

Money is the practical persistent currency for services such as scouting, recovery, special training, rerolls, candidate acquisition, event entry, or Ranch functions. Exact sinks are still subject to system simplification.

## 14.2 Reputation

CURRENT / PROVISIONAL

Reputation remains the leading candidate for a per-familiar career resource. It may govern eligibility, invitations, risky services, circuit branches, and ultimately career viability. If the Reputation-as-run-HP model is adopted, losses and voluntary risky spending both consume this same scarce resource.

## 14.3 Legacy Points

Legacy Points are permanent progression earned when familiar careers end. Legacy should primarily unlock breadth and possibility rather than direct universal numerical superiority.

- New species or candidate pools.

- New techniques, passives, innate-trait pools, or development events.

- New circuits, opponents, or arena variation.

- Ranch facilities and mentorship functions.

- Later lineage/breeding systems.

## 14.4 Recruitment

New familiars are acquired rather than captured during battle. The baseline recruitment structure remains rotating Ranch candidates plus special candidates or eggs earned through career rewards, events, circuits, or unlock milestones. A fallback candidate should always be available so the player cannot become unable to start another career.

**Expanded, staged acquisition progression** (added from the 2026-09 design-delta reconciliation; STRONG DIRECTION, detail OPEN-PLAYTEST). Recruitment should read as a four-stage arc of increasing player control, mirroring the broader metaprogression philosophy of gaining expressive power rather than only bigger numbers (§6.5, §16):

- **Stage 1 — researcher-provided candidates (low control).** Early on, a researcher/handler presents a small selection of familiar candidates; the player chooses among what is offered rather than requesting an exact species or build. This is deliberately about working creatively with imperfect, partly-random opportunities, not optimizing a known target.
- **Stage 2 — Essence Echoes and controlled randomness.** Retired familiars (§15.2) can produce **Essence Echoes** — not a generic currency, but components used directly in the acquisition process. The player combines Echoes in a formula/ritual that shapes a *weighted table* of possible outcomes, then rolls from that table: influence over probability, not yet a guarantee.
- **Stage 3 — better formulas, increasing control.** Progression grants stronger ingredients, improved formulas, and narrower/more favorable outcome tables — the player is moving along a spectrum from "accept possibilities" toward "strongly constrain possibilities."
- **Stage 4 — Perfect Essence: guaranteed species, not a stat/build clone.** At the far end, a **Perfect Essence** guarantees the exact same *species* as the essence's source rather than another weighted roll across the species table — turning acquisition from probabilistic engineering into true precision. It does not carry over the source familiar's stats or build; the resulting familiar is freshly generated within that species like any other candidate. How Perfect Essence is actually earned is left open until specified elsewhere.

## 14.5 Lineage

CURRENT DIRECTION

Later progression may allow retired familiars to influence future candidates through a simple breeding or mentorship system. The goal is meaningful influence over traits, affinities, stat tendencies, or cosmetic features without turning the game into a breeding-management simulator or producing exact clones — a familiar's specific stats and build are never directly reproducible in a new candidate.

**Resolved tension with Perfect Essence (§14.4 Stage 4):** the delta reconciliation flagged an apparent conflict between this "no exact clones" rule and Perfect Essence's "exact recreation" language. Resolved: Perfect Essence guarantees only the source's *species*, not its stats or build — the produced familiar is a freshly generated individual of that species, same as any other candidate. "No exact clones" and Perfect Essence are therefore compatible as written; no further reconciliation needed.

# 15. Retirement and the Ranch

LOCKED

## 15.1 Retirement

Retirement ends tournament participation, not the familiar’s existence. A retired familiar remains part of the player’s history and can continue contributing to future careers.

## 15.2 Legacy contribution

A career’s lasting contribution may reflect tournament progress, championships, difficult opponents, medals/objectives, unusual build accomplishments, and other meaningful milestones. Exact formulas should be simple enough that the player understands why a career generated its reward.

## 15.3 Mentorship

Retired familiars may influence later training offerings, techniques, recovery, scouting, special events, or circuit knowledge. Mentorship should ideally have visible Ranch presence and character rather than functioning only as an invisible percentage modifier.

## 15.4 Ranch roles

- Welcome or help evaluate new candidates.

- Assist training, recovery, or scouting.

- Participate in practice or exhibition activities.

- Improve or staff Ranch facilities.

- Appear in scenes, commentary, records, and celebrations.

## 15.5 Archive and memory

Players should be able to revisit important careers through records such as prior builds, medals, notable opponents, trophies, and potentially battle replays. Favorite familiars should remain meaningful after retirement rather than becoming disposable run data.

# 16. Postgame league and custom tournaments

CURRENT DIRECTION

## 16.1 Narrative transition

After the player defeats the corrupt organization, the competitive scene continues because the player and allies help replace or rebuild the league. The postgame is therefore not a non-canonical reset; the player’s relationship to the competition has changed.

## 16.2 Custom tournament modifiers

The postgame unlocks a configurable challenge system inspired by Hades II’s Fear structure. The player enables tournament modifiers, each carrying a challenge value. Different combinations can reach the same overall rating while creating very different run pressures.

Modifiers should prefer rule changes and build constraints over pure numerical inflation. Illustrative categories include harsher economy, reduced recovery, stronger opponent traits, more elite trainers, more punishing arenas, roster restrictions, or altered tournament structure.

**Note:** this modifier concept translates unusually well to Pixel Pugilists' single-run structure too (escalating-difficulty replays of one bracket) — see `GAME_DESIGN.md` if that gets picked up there first.

## 16.3 Challenge rating name

OPEN / PLAYTEST

The rating itself still needs a final name. “Reputation” should probably be avoided if Reputation remains the familiar’s career resource. Renown, Notoriety, Prestige, Hype, or another term can be evaluated later against the game’s final tone.

## 16.4 Threshold unlocks

Clearing tournaments at higher challenge thresholds should unlock new game content rather than only paying out more currency.

- Stronger or more unusual trainers enter the opponent pool.

- New species or candidate pools become available to acquire.

- New arenas, circuit variants, rules, or special events appear.

- Optional elite or superboss trainers become available.

Thresholds should generally care about the highest qualifying challenge cleared rather than encourage repetitive farming of the easiest modifier combination at one level.

## 16.5 Why this matters

The postgame loop becomes: raise challenge → encounter new content → gain new build possibilities → use those possibilities to push challenge further.

# 17. Prototype roadmap

LOCKED (superseded in practice — see note)

**Note:** This roadmap originally assumed Pixel Pugilists (referred to below by its earlier working title, "Polygonal Pugilists") was Milestone 1 *of this same game*. It has since been split off as its own standalone prototype with its own document (`GAME_DESIGN.md`) and its own success criteria. This section is preserved for the milestone sequencing logic (spatial combat only after the non-spatial engine proves out; career only after combat proves out; campaign/postgame only after career proves out), which remains the intended order once full Familiar Fight Club development resumes.

The first prototype should be much smaller than the original v1 sandbox. Its job is to answer the central combat question before the project absorbs the complexity of movement, long-term careers, or content production.

## 17.1 Milestone 0 — learning exercises

CURRENT DIRECTION

Small Godot exercises may be used when necessary, but they should preferentially teach systems that feed directly into Familiar Fight Club: scene composition, signals, Resources/data models, UI updates, state machines, save data, and combat events.

## 17.2 Milestone 1 — Pixel Pugilists

Spun off into its own project and document. See `GAME_DESIGN.md`.

## 17.3 Milestone 2 — spatial combat sandbox

CURRENT DIRECTION

Only after the non-spatial engine is fun should the prototype add movement, grid/arena geometry, spatial targeting, hazards, forced movement, and movement-related statuses. This milestone exists to test whether spatial depth improves the game enough to justify its implementation cost and how large the baseline arena should be.

## 17.4 Milestone 3 — miniature career

Once combat is strong, add one short circuit with approximately three-week development phases, a few tournaments, candidate selection, basic Money/Reputation, retirement, and a minimal Ranch/Legacy return. The purpose is to test whether repeated development choices create attachment and distinct career arcs.

## 17.5 Milestone 4 — campaign and postgame proof

Narrative circuits, league corruption, broader Ranch persistence, performance medals, and postgame challenge thresholds should be expanded only after the career loop demonstrates that repeated familiar runs are compelling.

# 18. Playtest questions

OPEN / PLAYTEST

## 18.1 Combat timing and stats

- Which turn-resolution model creates the best balance of readability and interesting interaction?

- What should Speed actually do?

- How small can the universal stat line be without flattening build variety?

- Do extra-action thresholds create excitement or simply make Speed mandatory?

## 18.2 Behavior readability

- How many rules or priorities can players comfortably manage?

- How much explanation should be visible live versus available on inspection?

- What kinds of targeting or conditions are expressive without becoming programming homework?

## 18.3 Status and combo pacing

- How many actions should a setup build need before its payoff?

- Are stacking statuses interesting to maintain or merely fiddly?

- How should control statuses be balanced in one-versus-one combat?

- How much deterministic resistance is required for meaningful counterplay?

## 18.4 Career failure

- Does one loss ending a career create satisfying stakes or discourage experimentation?

- If Reputation is run HP, how many meaningful losses should a healthy career survive?

- What voluntary Reputation spends are tempting enough to create real risk decisions?

- How rare should Reputation recovery be?

## 18.5 Performance objectives

- Can objectives reward varied mastery without favoring one archetype?

- How should the game establish an expected fight length for speed-clear medals?

- Should medals influence Legacy, immediate rewards, cosmetics, or some combination?

## 18.6 Spatial combat

- Does movement add enough build depth to justify the extra AI and readability complexity?

- Is 5×5 sufficient, or does ranged/spatial play need a larger baseline?

- Can broad movement directives resolve predictably enough that players trust automation?

## 18.7 Career pacing

- How many development choices are needed before a familiar feels like it has a distinct build story?

- How many tournaments make retirement feel earned rather than abrupt?

- How much persistence should transfer between careers before runs stop feeling distinct?

# 19. Deprecated or non-baseline systems

DEPRECATED

These ideas existed in the original design but should not be treated as current requirements.

## 19.1 Mandatory sequential Speed initiative

The old design assumed the faster familiar completed a turn before the slower familiar evaluated the new state. This is now only one timing model to test.

## 19.2 Mandatory 5×5 arena

A 5×5 grid remains a candidate, not a locked balancing baseline.

## 19.3 Full movement system in the first prototype

The first prototype intentionally removes movement. Spatial combat is a later validation milestone.

## 19.4 Universal knockout injuries

Ordinary knockouts no longer automatically generate injuries. Persistent debuffs are reserved for explicit and comparatively rare events or effects.

## 19.5 Overbuilt first prototype

The original prototype attempted to prove movement, behavior construction, statuses, arenas, enemy variance, interventions, and more at once. The current roadmap isolates the combat thesis first.

## 19.6 Spectacle as a single dominant score

The underlying desire to reward impressive victories remains, but the preferred direction is a broader objective/medal system that recognizes speed, efficiency, comeback play, combos, restrictions, and other forms of mastery.

# 20. Current elevator pitch and core identity

LOCKED

## 20.1 Elevator pitch

Familiar Fight Club is a creature-raising auto-tactics game where you build a familiar’s techniques, passives, and decision logic, then guide it through a finite tournament career. The familiar fights autonomously, so every match is a performance of the build you created. Each career develops differently, eventually ends in retirement, and leaves a legacy that expands future possibilities.

## 20.2 Campaign/postgame extension

Across multiple circuits, a light anime-style story leads the player from unknown trainer to champion, then into conflict with the corrupt organization controlling the competitive scene. Defeating that organization unlocks a rebuilt-league postgame where the player can configure increasingly difficult tournaments and reach challenge thresholds that attract stronger trainers, new species, and new content.

## 20.3 Core identity

The game’s strongest distinguishing idea is not simply “Monster Rancher with automated combat.” It is a creature-raising game where training means constructing an autonomous tactical build, and the familiar’s career becomes the story of how that build evolved and expressed itself.

- Species provides the starting point.

- Innate traits provide individuality.

- Curated development provides the career’s opportunities.

- The player’s theorycrafting provides the fighting style.

- Combat provides the performance.

- Retirement turns that performance into legacy.

- Postgame challenge turns mastery into new possibility.

Revision note: This v2 document intentionally preserves open questions where additional design discussion would be less valuable than building and observing a prototype. When a prototype resolves one of those questions, the relevant section should be promoted from OPEN / PLAYTEST to CURRENT DIRECTION or LOCKED and the deprecated alternative recorded rather than erased.