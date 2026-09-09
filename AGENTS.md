# Pixel Pugilists: agent working contract

## Purpose and scope

Pixel Pugilists (PP) is a standalone, small tournament roguelike proving whether building a familiar, arranging autonomous priorities, and watching that build execute is satisfying. It informs the planned **Familiar Fight Club (FFC)**; it is not an instruction to build FFC here. The current game has a 16-entrant tournament, between-fight build growth, and a separate final boss. `DEVLOG.md` records an owner-playtested complete loop; that is historical validation, not proof every current edge case works.

Preserve the core agency: preparation and buildcraft between fights, autonomous 1v1 technique selection during fights, and understandable outcomes/skip reasons. Manual playback advancement changes presentation, not combat choices. Cross-run progression, careers/Ranch, circuits/campaign, grid movement, and breeding/lineage are outside PP's scope unless the owner explicitly changes it.

## Owner understanding and authority

Investigate autonomously. Implement deliberately. Escalate consequential decisions.

For substantial work:

1. Investigate and explain the existing architecture and data flow.
2. Explain where the request fits; propose small, reviewable implementation steps.
3. Identify assumptions, tradeoffs, architectural decisions, and meaningful design ambiguities before implementing the affected portion.
4. Resolve necessary decisions with the owner, implement the agreed approach, and validate it.
5. Explain what changed, why, how it works, and what remains unverified.

Significant architecture changes require explicit approval. Do not introduce abstractions, dependencies, architectural patterns, or large refactors just to simplify the immediate task. Prefer established patterns; explain and discuss an existing pattern's problems before replacing it. Working code is insufficient if the owner cannot understand or reason about it.

Surface choices affecting player experience, combat/balance, content semantics, AI, progression, data models, extensibility, save compatibility, UI/UX, or future FFC design. Explain the uncertainty, plausible interpretations, consequences, and recommendation; ask a targeted question. Do not ask about routine details that established patterns resolve. Recommendations and reasoned disagreement are welcome; final product/design decisions belong to the owner. Historical instructions to implement autonomously or assign learning exercises do not override the owner's current request.

## Documentation map and conflict handling

Paths below are relative to the repository root.

| Work | Read |
| --- | --- |
| Scope, player experience, design status | `.claude/GAME_DESIGN.md` |
| Architecture and non-obvious decisions | `.claude/DECISIONS.md`, then the relevant source |
| Historical context and recent changes | `AGENT_HANDOFF.md`, recent `.claude/DEVLOG.md` entries, relevant git history **and working-tree diffs** |
| Combat/content/balance | `.claude/BALANCE_PRIMITIVES.md`, `.claude/BALANCE_TEST_PLAN.md`, `scripts/tools/`, relevant `.tres` and execution paths |
| AI drafting | `docs/superpowers/specs/2026-09-06-ai-drafting-design.md` (approved design, not implemented) |
| Tournament / priority editor / visuals | Corresponding specs and plans under `docs/superpowers/`; visual work also requires studying `assets/ui_mockup/` and later owner-directed changes in `DEVLOG.md` |
| Godot pitfalls and owner learning context | `.claude/CLAUDE.md`, `.claude/LEARNING.md`, `.claude/LEARNING_ROADMAP.md` |
| Future ideas / FFC consequences | `.claude/CONTENT_IDEAS.md`, `.claude/FAMILIAR_FIGHT_CLUB_VISION.md` (not an active PP backlog) |

Respect the design vocabulary: **LOCKED** is foundational; **CURRENT DIRECTION** can iterate; **OPEN / PLAYTEST** needs a small, reversible experiment; **OUT OF SCOPE** is deliberately excluded. Speed timing and the universal stat line remain OPEN / PLAYTEST despite being implemented. Focus's intended identity is threshold-based, not simply another Power stat.

Source establishes current behavior, not intended design. The handoff is historical evidence, not unquestioned authority. Specs can describe superseded implementations; even `DECISIONS.md` has stale entries. Distinguish intended design, implementation, prototype behavior, debt, historical decisions, and unresolved ideas. If a conflict affects the work, cite both sides and resolve it with the owner rather than silently choosing one. Do not canonize a behavior solely because it exists.

## Repository and architecture

- `project.godot`: Godot 4.7 feature declaration; main scene `scenes/battle.tscn`. GDScript gameplay. There is no gameplay autoload; the configured `MCPRuntimeServer` autoload belongs to the editor-tooling addon.
- `scripts/`: core `combatant.gd`, `battle_engine.gd`, `battle_controller.gd`, `familiar.gd`; category folders for techniques, statuses, conditions, numeric bonuses, passives, upgrades, rewards, bracket, and priority builder. Keep existing placement rather than reorganizing incidentally.
- `resources/`: authored `.tres` builds/content. `resources/familiars/` is the starting roster; `resources/bosses/` is separate. `resources/techniques/passive_operations/` holds internal passive payloads, not ordinary reward offerings.
- `scenes/battle_panels/`: self-contained overlays with public setup/show methods and signals. `BracketScreen`'s script remains under `scripts/bracket/`; most other panel scripts are under `scripts/battle_panels/`.
- Use `Resource` for Inspector/saveable data, `RefCounted` for scene-independent runtime objects, and Nodes/Controls for scene-tree behavior. `Familiar` and bracket Resources also carry mutable **run** data; they are not universally immutable templates.
- Both sides use the same `Familiar`/`Combatant` model. Per-fighter battle state belongs on `Combatant`; persistent run upgrades affect its `Familiar`. Keep simulation independent of UI. Prefer exported fields for different numbers/choices and subclasses for genuinely different logic.
- Use `Familiar.duplicate_for_run()` for mutable run copies. It isolates arrays while preserving shared Technique/PassiveEffect identity needed by reward exclusions. Extend it when adding mutable fields. Do not substitute deep duplication or mutate shared nested content to customize one build; trace all resource consumers first.
- Preserve authored exported roster/pool/block-definition arrays for shipped content discovery. Tool scripts scan loose directories; those scans are not the established exported-game pattern. Preserve serialized enum meanings: append passive triggers, retain retired `HEAL_CAST`, and audit `.tres` consumers before changing any enum/default/resource schema.

## Combat and composable content

Read `BattleEngine`, `Combatant`, `Technique`, `Status`, and affected subclasses together before changing execution.

- `BattleEngine` sequences fights; `battle_controller.gd` orchestrates the live run and presentation. `run_to_completion()` drives headless battles. Wire both `Combatant.opponent` references when constructing a fight.
- Current ordering: battle-start passives, first actor, technique turn; thereafter reset the next actor's turn limiters, run its upkeep, then act. Speed/override priority is recalculated after the second actor completes an exchange; ties favor the first argument (player in live play). Stun returns before technique selection and TURN_END. Preserve ordering unless changing semantics deliberately.
- `check_victory()` fires BATTLE_END and is **not idempotent**. Stop driving the fight once it succeeds; do not invoke it manually alongside the live loop.
- `choose_technique()` takes the first matching priority rule; conditions are ANDed. Empty conditions make a catch-all. A move in `techniques` alone is not selectable without a rule. No match returns null, which `BattleEngine.take_turn()` currently dereferences; do not describe this as a supported idle turn.
- A Technique contains StepGroups: ANDed conditions, repeated ordered actions, and NumericBonuses filtered by action type. **All group gates are evaluated when `execute()` builds its Callables; actions and bonuses resolve later when called.** Earlier actions do not enable a later group's gate in the same activation today. Bonuses are shared by same-type actions in a group; split groups when distinct bonuses are needed, and inspect SELF/TARGET argument routing rather than assuming it is uniform.
- `execute()` returns steps; the engine executes the entire turn before the controller displays/paces returned messages. Preserve that distinction when reasoning about intermediate HP display or playback.
- Normal hit damage uses integer `raw² / (raw + defense)`, with a minimum of 1 before incoming-damage effects/Absorption. `ignore_power_and_defense` uses `int(power_multiplier)` as flat base plus bonuses; it still passes through `take_damage()` and Absorption. Read `apply_heal()` separately; it does not use normal hit mitigation or actual prior damage dealt.
- Statuses are runtime objects made through `Status.create()`. Update the factory/id/description/icon paths for new statuses. Application, reapplication, direct stack modification, and expiration are distinct paths. `ModifyStatusAction.SET` is an absolute value and can create an absent status; it is not ordinary application.
- Preserve stack settlement/notification through `_settle_status()` or the existing hook-specific `_notify_stack_change()` path. Ward/Absorption intercept inside `Combatant`; Stasis intercepts reductions in the base `Status.stacks` setter. Its per-status/per-turn redirect guard, reactive zero-stack guards, and fresh-Hex notification ordering protect real bug cases. Do not replace them with balance-changing passive limits.
- A merge cap needs `stack_with()` handling as well as `max_stacks()` for direct modification; do not assume every creation path clamps. Recharge is a countdown whose restrictions come from authored conditions, not a universal cooldown gate.
- Passives distinguish reactive Operation/PermanentStat effects from queried status/heal modifiers and continuously applied stat modifiers. Record limiter use **before** firing effects. `trigger_target` defaults to TARGET; explicitly check whose event is observed. ATTACK is attacker-side, HIT defender-side; damage triggers currently cover technique hits, not all damage sources. `triggers_hooks=false` is not a blanket suppression of every stack-change reaction.
- Pre-application snapshots are meaningful only around STATUS_APPLIED/CREATED; do not use `StatusPresentBeforeApplicationCondition` as a normal priority predicate. Keep FocusTable effects separate from tradable passives. Keep `describe()`/bonus summaries/status previews consistent with any changed mechanics.

## Rewards, AI, and tournament progression

- Preserve the separation: `RewardProgression` owns cadence, `RewardSelector` weighted choice, `BuildSnapshot` owned-content tag/role totals, `RewardFlowController` screen state, and `UpgradeOption` subclasses build mutations. Tags/roles are drafting metadata, not combat triggers; audit authored coverage and relevance rather than assuming declared fields make tailoring work.
- Species uses innate affinities; RUN uses owned techniques/passives; PIVOT is the UI's Wildcard, favoring moderate overlap. Owned and already-shown items are excluded by identity; eligible low-relevance items retain a chance. Three rerolls are shared across slots. Trade scoring excludes the proposed sacrifice before removal is committed.
- Current flow awards technique/passive/technique/passive-trade after rounds 1–4, plus staged stat allocation; skipping gives two stat points instead of one. Reward cards precede stat allocation despite legacy Phase B/A names. Priorities are edited separately through the repeatable prefight/editor loop, not on the reward screen; the opening fight has no editor option.
- `AIDrafter` is a placeholder: lowest normalized stat, RUN-slot reward, oldest-passive trade. It grants +1 raw stat, unlike player-authored +2/+15 upgrades, and supplies no rule for drafted techniques. These are current limitations, not canonical AI fairness/design. Personalities, priority hints/optimizer, and `draft_balance_test.gd` do not exist yet. Consult the AI spec before implementing; its standalone-tool-first scope and unresolved choices still need reconciliation with the requested work.
- `Bracket` → `BracketRound` → `BracketMatch` represents 16 entrants and four rounds. Advance via `Bracket.advance_round()`. `BracketTree` also assumes this fixed shape; bracket-size changes span data, UI, content wiring, and tests.
- Scout with the real engine before a fight; resolve off-screen winners with an upset roll afterward. Keep odds separate from actual player-match outcomes. Formula/label boundaries in `BracketOdds` remain tuning guesses.
- Recreate Combatants between fights for full HP/cleared statuses while retaining run builds. `current_round` is zero-based; reward cadence takes completed rounds, one-based. The boss transition retains round index 3 and explicitly awards round 4's trade. Entropy is outside the roster/tree; no reward follows its fight. Restart creates a new run.

## UI and validation

Use the shared Theme (`assets/themes/pixel_pugilists.tres`), `Palette`, `FramedPanel`, reusable HP/status/log widgets, and `TooltipLayer`. Palette and Theme require coordinated edits. Keep panel internals owned by their panel, communicating through APIs/signals; do not centralize them back into deep controller node paths. Existing fighter-card duplication is deliberate where layouts differ; it is not automatic grounds for a generic component.

The priority builder uses `ConditionBlockDefinition`/`SentencePart` descriptors per sentence shape. Compilation flattens nesting into AND in reading order; NOT wraps one leaf rather than ANDing its child separately. Incomplete slots are excluded. `StateProbe` uses real combat primitives against a non-acting dummy; it is not a full matchup simulation or proof of defensive-kit balance.

Study mockups with current scope before visual changes; do not import their currency displays or decorative keyboard prompts as features. Check overlay sibling order, global canvas `z_index`, deferred container sizing, drag coordinates/reorder indices, and nested tooltip hover. Preserve the project's yoster comparator/plus glyph choices (`＜ ＞ ≤ ≥ ✚`). Recheck bracket layout across fresh, intermediate, and completed tournaments, with details open/closed. Static parsing does not validate these behaviors.

For code changes, use relevant existing tools (from the repo root; `godot` below means the locally available compatible binary):

```text
godot --headless --script res://scripts/tools/bracket_test.gd
godot --headless --script res://scripts/tools/balance_test.gd
godot --headless --script res://scripts/tools/diagnose_matchup.gd -- Ironcap Twerpent
```

The historical Windows binary is `../Godot_v4.7.1-stable_win64_console.exe`; verify availability locally. The bracket harness expects 12 completed checks, including run-copy isolation, but does not test live panels. The balance harness writes CSVs and tests starting kits in both tie-order positions, not drafted builds. After combat/content changes inspect whole-roster shifts and targeted traces, not just one win rate. Check parse/load errors and run the affected flow; do not treat the historical bare `--check-only --quit` command as proof of whole-project correctness. Use completion assertions for behavioral checks; runtime errors can abort a function without proving a test passed. Report checks actually performed and limitations. Documentation-only work need not generate Godot caches or balance reports.

For UI work, validate visible interactions and overlays in the running game. MCP direct button activation can bypass visibility; confirm the target is visible. Synthetic hover cannot verify all real-cursor tooltip behavior. Coordinate scene edits with an open editor to avoid stale in-memory saves overwriting disk changes. Verify the export preset and actual exported build when packaging: the two Windows presets have different output names. Do not assume a historical playtest binary is current.

## Unresolved discrepancies: verify before relying on them

These are investigation findings, **not authorization to fix or canonicalize them**:

- `GAME_DESIGN.md` has stale alternation, technique-subclass, status-count, and editor-not-integrated prose. Specs/handoff also retain retired flows. `PriorityBuild` is the retired resource picker; `PriorityBuilder` is the live editor.
- Deterministic combat is stated design, but Cleanse and RandomStatusApplicationAction use global randomness. Scouting re-simulates, and `reward_seed` does not seed the separate entrant-shuffle RNG. Full-run reproducibility is not established.
- `BALANCE_PRIMITIVES.md`/handoff reverse the general multi-hit mitigation relationship: before the damage floor, splitting equal raw damage increases mitigation. They also misidentify healing's Defense target: `apply_heal(user, target)` uses the opponent argument's Defense and subtractive math, then heals the user. Clarify intended healing before changing it.
- The Focus tier-1 Defense resource has a condition, but `effective_stat()` ignores ModifyStatPassiveEffect conditions. Higher tiers are reachable through run upgrades despite notes calling tier 20 inert. Confirm continuous-modifier gating before building on it.
- No-fallback handling remains unresolved: editor confirmation does not ensure a matching rule; the engine's null dereference is more severe than the design doc's description of simply not acting. The warning about unedited priorities does not validate coverage.
- Bracket simulation wraps the actual entrant Familiar objects. PermanentStatPassiveEffect can therefore mutate builds during scouting/lookahead; fresh Combatants alone do not isolate run data. Agree on simulation side-effect semantics before extending such content.
- The AI spec's defensive-hint example uses the event-only pre-application condition in a priority context. Reconcile that example before implementing hint derivation. Stable stat/stack bands, future history signals, and Fusion/Linking must not become new PP commitments merely because a reference doc mentions them.

Begin each task with working-tree inspection; preserve pre-existing changes and untracked content. The onboarding tree included uncommitted boss/tree/docs work beyond `HEAD`. Never discard it or commit unrelated work to simplify a task. Keep this contract concise and update relevant deeper documentation when an authorized substantive change resolves a discrepancy.
