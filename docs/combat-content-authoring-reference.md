# Combat content authoring reference

Inventory of the current Pixel Pugilists implementation, checked 2026-09-09. This describes available building blocks and their current behavior, not locked design or a balance prescription. Defaults below come from scripts; authored resources and passive field modifiers can change them. Existing descriptions/tooltips are not uniformly accurate.

For design constraints, read [BALANCE_PRIMITIVES.md](../.claude/BALANCE_PRIMITIVES.md) and [GAME_DESIGN.md](../.claude/GAME_DESIGN.md), alongside the implementation caveats here. For unresolved discrepancies, see [AGENTS.md](../AGENTS.md) and the historical [comment audit](comment-consistency-audit.md). This document does not authorize fixes to those discrepancies.

## 1. How content fits together

```text
Familiar
  techniques[]                 available moves
  priority_rules[]             ordered selection policy
    PriorityRule
      conditions[]             AND; empty means unconditional
      technique -> Technique
        step_groups[]
          TechniqueStepGroup
            conditions[]       AND; gates the whole group
            repeat_count
            actions[]          ordered effects
            numeric_bonuses[]   filtered by action type
  passives[]                   tradable/build-specific effects
  focus_table -> FocusTable
    effects[]                  additional PassiveEffect resources

Combatant                      runtime HP, statuses, passive counters
  familiar -> Familiar         persistent run build
  statuses[] -> Status         runtime instances, not authored .tres resources
```

The authored objects above are Godot Resources, except `Combatant` and `Status`, which are RefCounted runtime objects. A Technique can hold StepGroups, actions, conditions and bonuses as subresources or external resources. Shared references matter: use the existing `duplicate_for_run()` pattern for run builds, and do not mutate shared nested content to customize one entrant.

[Familiar](../scripts/familiar.gd) exposes `familiar_name`, `sprite`, five base stats (`MAX_HP`, `POWER`, `DEFENSE`, `SPEED`, `FOCUS`), `techniques`, `priority_rules`, `passives`, `focus_table`, `focus_step_size` (default 5), and `species_affinities`. Current HP is on Combatant. Effective stats apply active statuses in list order, then continuous passive flat modifiers.

[PriorityRule](../scripts/priority_rule.gd) pairs ANDed conditions with one Technique. Combatant selects the first matching rule. Owning a technique is insufficient to select it: a rule must reference it. An empty condition list makes a fallback. No match currently returns null that the engine dereferences; it is not a supported idle action.

## 2. Techniques, StepGroups and actions

[Technique](../scripts/technique/technique.gd) fields: `technique_name`, `power_multiplier` (default 1.0), `step_groups`, and reward tags/role weights. [TechniqueStepGroup](../scripts/technique/technique_step_group.gd) fields: `actions`, `repeat_count` (1), `conditions`, `numeric_bonuses`.

`execute()` builds Callables; it does not immediately perform their effects. **All StepGroup gates are evaluated before any returned action executes.** Earlier actions cannot enable a later group's gate in that activation. Actions and bonuses resolve when each Callable runs. Each passing group repeats its ordered action list `repeat_count` times. There is no independent per-action condition field; use a gated group.

Bonuses apply to all matching action types within their group. Separate groups when two hits need different bonuses. The technique's multiplier is shared by its hits and percentage-heal calculation; there is no per-HitAction multiplier.

| Action | Authored fields and defaults | Current effect |
| --- | --- | --- |
| [HitAction](../scripts/technique/hit_action.gd) | `target=TARGET`, `ignore_power_and_defense=false` | Hit SELF or TARGET. Normal damage uses effective Power/Defense. Flat mode treats `int(power_multiplier)` as literal base damage. |
| [StatusApplicationAction](../scripts/technique/status_application_action.gd) | `target=SELF` (enum default), `effect=NONE`, `stacks=1` | Create/apply a selected status, with STATUS bonuses and queried application modifiers. Set effect and target explicitly. |
| [RandomStatusApplicationAction](../scripts/technique/random_status_application_action.gd) | `target=SELF` (enum default), `stacks=1` | Choose uniformly from StatusEffect values except NONE, then use ordinary status application. No authored whitelist, weighting or beneficial/harmful classification. Uses global randomness. |
| [ModifyStatusAction](../scripts/technique/modify_status_action.gd) | `effect=NONE`, `modifier=1.0`, `operator=MULTIPLY`, `target=TARGET` | Direct stack arithmetic: MULTIPLY, SUBTRACT, DIVIDE, SET. No ADD operator; ordinary application provides merging. See exceptions below. |
| [HealAction](../scripts/technique/heal_action.gd) | `heal_percent=0.0`, `heal_flat=0` | Heals the user; no target selector. Includes HEAL bonuses and queried heal modifiers. Percent is a fraction: 0.5 means 50%. |
| [HalveAllStatusesAction](../scripts/technique/halve_all_statuses_action.gd) | `target=TARGET` | Requests `int(stacks / 2.0)` for each status, then settles it. Stasis can intercept reductions. |

[TechniqueAction](../scripts/technique/technique_action.gd) is a marker base Resource. Technique's dispatcher recognizes the six concrete types above; creating an arbitrary new subclass alone does not make it execute.

Current calculations, before damage interception or HP caps:

```text
normal hit:
  raw = int(user.effective_power * power_multiplier) + HIT bonuses
  damage = max(integer_divide(raw * raw, raw + target.effective_defense), 1)

flat hit:
  damage = max(int(power_multiplier) + HIT bonuses, 1)

heal:
  basis = max(int(user.effective_power * power_multiplier)
              - opponent.effective_defense, 1)
  amount = int(basis * heal_percent) + heal_flat + HEAL bonuses + passive heal bonus
```

Damage goes through incoming-damage modifiers and Absorption. `take_damage()` can return more than actual HP lost on overkill. Healing uses the opponent argument's subtractive Defense calculation, not the normal hit formula or actual prior damage dealt; intended healing semantics remain unresolved. These formulas are not general input validation: avoid DIVIDE by zero and pathological bonus/stat combinations that make the hit denominator zero.

For SELF hits, the affected user is passed as the helper's `target`, so target-based hit bonuses also see the user. Status/heal bonus evaluation receives the original user/opponent pair. Do not assume target routing is identical across action types.

## 3. Numeric bonuses

[NumericBonus](../scripts/numeric_bonus/numeric_bonus.gd) is usable directly. Its common fields are:

| Field | Meaning |
| --- | --- |
| `applies_to` | HIT (default), STATUS, or HEAL. No bonus channel for direct stack modification or halving. |
| `flat_bonus=0` | Integer additive component. |
| `percent_bonus=0.0` | Fraction of a selected value; 1.0 means 100%. |
| `percent_source=STAT` | STAT, STATUS_STACKS, STATUS_COUNT, HP. |
| `percent_target=SELF` | Which side supplies that value. |
| `percent_stat=POWER` | Effective stat for STAT; choose MAX_HP for max-HP scaling. |
| `percent_status_effect=POISON` | Selected status for STATUS_STACKS; absent status contributes zero. |
| `percent_check_all=false` | For STATUS_STACKS, sum every status's stacks instead of one effect. |

`base_amount = flat_bonus + int(selected_value * percent_bonus)`. HP means current HP. STATUS_COUNT means the number of active status entries, not summed stacks. All subclasses inherit these fields:

| Bonus type | Additional fields | Result |
| --- | --- | --- |
| [ConditionalNumericBonus](../scripts/numeric_bonus/conditional_numeric_bonus.gd) | `condition` | Base amount if condition passes, otherwise zero. Assign a condition; compute does not guard null. |
| [StackCountNumericBonus](../scripts/numeric_bonus/stack_count_numeric_bonus.gd) | `count_on=TARGET`, `count_status_effect=POISON`, `count_all=false` | Base amount times selected stacks, or total stacks when count_all. |
| [StatusCountNumericBonus](../scripts/numeric_bonus/status_count_numeric_bonus.gd) | `count_on=TARGET` | Base amount times status entry count on one side. |
| [TotalStatusCountNumericBonus](../scripts/numeric_bonus/total_status_count_numeric_bonus.gd) | None | Base amount times the sum of both sides' status entry counts. Same effect present on both counts twice. |
| [StackComparisonNumericBonus](../scripts/numeric_bonus/stack_comparison_numeric_bonus.gd) | Left/right status effects and targets; `compare_mode=STATUS` or FLAT_VALUE; `right_value`; `check_all` | `(left stacks - right stacks/value) * base_amount`. check_all sums stacks on both compared sides. |
| [StatComparisonNumericBonus](../scripts/numeric_bonus/stat_comparison_numeric_bonus.gd) | Left/right stats and targets; `compare_mode=STAT` or FLAT_VALUE; `right_value` | `base_amount + (left effective stat - right effective stat/value)`. **Adds** the difference; does not multiply by it. |

Comparison bonuses are arithmetic, not Boolean gates, and their differences can be negative. Use ConditionalNumericBonus plus a Condition for an actual gated bonus.

## 4. Conditions

All six specialized classes inherit [Condition](../scripts/condition/condition.gd). The base always returns true. Comparison classes support GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL and EQUAL. Negate EQUAL with NotCondition when needed; there is no NOT_EQUAL enum.

| Condition | Available configuration | Reads |
| --- | --- | --- |
| [StatusComparisonCondition](../scripts/condition/status_comparison_condition.gd) | `left_status_effect`, `left_target`; `compare_mode=FLAT_VALUE` or STATUS; `right_status_effect`, `right_target`, `right_value`; `check_all`; `comparator` | Current stacks. Missing effect is zero. check_all sums stacks rather than counting distinct statuses, on both sides when comparing sides. |
| [HpComparisonCondition](../scripts/condition/hp_comparison_condition.gd) | `left_target`; `compare_mode=FLAT_VALUE` or HP; `right_target`, `right_value`; `use_percent=true`; `comparator` | Current HP or current/max HP fraction. With use_percent, 0.5 is 50%, not 50. The same mode applies to both sides. |
| [StatComparisonCondition](../scripts/condition/stat_comparison_condition.gd) | `left_stat`, `left_target`; `compare_mode=STAT` or FLAT_VALUE; `right_stat`, `right_target`, `right_value`; `comparator` | Effective stats, including currently applied modifiers. |
| [FocusBreakpointCondition](../scripts/condition/focus_breakpoint_condition.gd) | `focus_target=SELF`, `tier=1`, `comparator=GREATER_OR_EQUAL` | Effective Focus compared with `tier * familiar.focus_step_size`; not a separately stored tier. |
| [StatusPresentBeforeApplicationCondition](../scripts/condition/status_present_before_application_condition.gd) | `check_target=TARGET`, `status_effect=NONE`, `check_all=false`, `value=1`, `comparator=GREATER_OR_EQUAL` | `pre_application_snapshot` stacks. Intended for the application-event context, not ordinary priority predicates; outside that context the snapshot may be empty or stale. |
| [NotCondition](../scripts/condition/not_condition.gd) | `wrapped_condition` | Logical negation of one predicate. Assign its wrapped condition. |

Condition arrays in rules, groups and passives mean AND. No general OR/compound-condition resource, turn-history predicate, technique-history predicate, or explicit status-count comparison predicate currently exists. Numeric bonuses can read status count, but that is a different capability.

SELF/TARGET are relative to the pair passed to the condition. In passive matching, they are the passive owner and its opponent, regardless of which side the event concerns.

## 5. Status catalog

There are **24 concrete statuses**, plus the NONE sentinel. Each table entry links to its implementation; enum names are uppercase versions of these IDs. Factory/mapping code is in [Status](../scripts/status/status.gd).

Status instances start with the requested `initial_stacks` (default 1). Unless overridden, reapplication **adds** incoming stacks, `max_stacks()` is -1 (no declared cap), and there is no automatic tick/consumption behavior beyond that implemented by the subclass. Expiration means stacks <= 0. Reductions below are requests through the shared stack setter: Stasis can intercept them.

| Status | Current effect / stack behavior | Tunable runtime fields and defaults |
| --- | --- | --- |
| [Poison](../scripts/status/poison_status.gd) | Upkeep damage proportional to current stacks, then decay. | `damage_per_stack=1`, `stacks_lost_per_tick=1` |
| [Burn](../scripts/status/burn_status.gd) | Fixed upkeep damage; reapply Flare; merge keeps max(existing,incoming), not a fixed refresh. | `damage_per_tick=3`, `flare_damage=3`, `stacks_lost_per_tick=1`, `max_stack_count=5`, `stacks_multiply_flare_damage=0` (1 enables stack-scaled Flare) |
| [Acid](../scripts/status/acid_status.gd) | Defense becomes `int(value * (1 - reduction * stacks))`; additive merge capped at 5 by default; no natural decay. | `defense_reduction_per_stack=0.1`, `max_stack_count=5` |
| [Bleed](../scripts/status/bleed_status.gd) | On being hit, damages bearer by damage_per_stack * stacks, then consumes stacks. | `damage_per_stack=1`, `stacks_lost_per_hit=1` |
| [Stagger](../scripts/status/stagger_status.gd) | Additive capped merge; on application at threshold, resets and adds Stun. | `max_stack_count=5` |
| [Foretell](../scripts/status/foretell_status.gd) | Upkeep/reapply accelerate countdown; burst when those paths reach zero. Incoming stacks do not merge. Arbitrary removal is not a generic burst hook. | `burst_damage=9`, `stacks_lost_per_tick=1` |
| [Stun](../scripts/status/stun_status.gd) | On upkeep sets Combatant.is_stunned and requests zero stacks. Next turn skips technique execution. Stack count is not a number of skipped turns. | No subclass numeric fields |
| [Defending](../scripts/status/defending_status.gd) | Multiplies Defense while active; consumed on being hit. | `defense_multiplier=2`, `stacks_lost_per_hit=1` |
| [Infestation](../scripts/status/infestation_status.gd) | Upkeep adds stacks and deals a fixed amount of damage, both using tick_magnitude; damage does not scale with stack count. | `tick_magnitude=1` |
| [Hone](../scripts/status/hone_status.gd) | Adds stack_value * stacks to Power; consumed on attacks made. | `stack_value=2`, `stacks_lost_per_hit=1` |
| [Fortify](../scripts/status/fortify_status.gd) | Adds stack_value * stacks to Defense; decays on upkeep. | `stack_value=1`, `stacks_lost_per_tick=2` |
| [Enlarge](../scripts/status/enlarge_status.gd) | Multiplies Power while active; countdown on upkeep. | `stack_value=2.0`, `stacks_lost_per_tick=1` |
| [Recharge](../scripts/status/recharge_status.gd) | Countdown used by authored gates; no universal technique restriction. | `stacks_lost_per_tick=1` |
| [Thorns](../scripts/status/thorns_status.gd) | On being hit, damages attacker by damage_per_stack * stacks; does not explicitly invoke attacker's hit reactions. **Current handler does not consume stacks.** | `damage_per_stack=1`; `stacks_lost_per_hit=1` exists but is unused by the handler |
| [Ward](../scripts/status/ward_status.gd) | Combatant consumes it against external applications one-for-one. Self-application and incoming Ward bypass it. | No subclass numeric fields |
| [Hex](../scripts/status/hex_status.gd) | On status application notification, reads the notified instance's stacks, subtracts that count from Hex and deals count * damage_per_stack. Fresh Hex does not react to its own creation. | `damage_per_stack=1` |
| [Absorption](../scripts/status/absorption_status.gd) | Damage shield consumed one-for-one in take_damage; additive capped merge. | `max_stack_count=20` |
| [Ruin](../scripts/status/ruin_status.gd) | Multiplies incoming damage by 1 + percent_increase; magnitude does not scale with stacks. Countdown on upkeep. | `percent_increase=0.5`, `stacks_lost_per_tick=1` |
| [Retaliation](../scripts/status/retaliation_status.gd) | On hit, damages attacker by damage_per_stack * stacks, requests zero stacks, then explicitly invokes attacker's hit reactions. | `damage_per_stack=1` |
| [Stasis](../scripts/status/stasis_status.gd) | Shared stack setter spends one Stasis to prevent a reduction of another status, at most once per status ID per owner's turn. It does not protect itself. | No subclass numeric fields |
| [Renewal](../scripts/status/renewal_status.gd) | Upkeep heals heal_per_stack * stacks, then decays. | `heal_per_stack=1`, `stacks_lost_per_tick=2` |
| [Lifesteal](../scripts/status/lifesteal_status.gd) | On attack, heals a fraction of effective Power, then consumes stacks. Independent of actual damage dealt. | `heal_percent_of_power=0.333`, `stacks_lost_per_hit=1` |
| [Regeneration](../scripts/status/regeneration_status.gd) | Flat heal when hit and on upkeep; only upkeep consumes stacks. | `heal_per_hit=2`, `heal_per_tick=2`, `stacks_lost_per_tick=1` |
| [Cleanse](../scripts/status/cleanse_status.gd) | Upkeep randomly selects other statuses, without replacement within the tick, and requests zero stacks; can remove beneficial effects and can be intercepted by Stasis. | `statuses_stripped_per_tick=1`, `stacks_lost_per_tick=1` |

These fields live on runtime status classes, not on StatusApplicationAction. Ordinary authored applications choose effect and stacks. ModifyStatusPassiveEffect exposes numeric field adjustments; it is not a generic immutable per-application configuration object.

Caps are path-dependent: Absorption/Acid/Stagger implement capped merging; Burn's max-merge does not clamp to its declared maximum. Direct modification of an existing status uses max_stacks, but fresh creation does not universally clamp. SET of an absent status can create it without the ordinary application/Ward/hooks/field-modifier path. Do not treat creation, reapplication, direct modification and expiration as interchangeable authoring operations.

## 6. Passive payloads, triggers and limits

[PassiveEffect](../scripts/passive/passive_effect.gd) supplies `passive_name`, `trigger`, `trigger_target` (default TARGET), `status_effect_filter=NONE`, ANDed `conditions`, `limiter=NONE`, tags and role weights. The base has no executable payload.

| Payload class | Fields | How it is consumed |
| --- | --- | --- |
| [OperationPassiveEffect](../scripts/passive/operation_passive_effect.gd) | `operation: Technique`, `triggers_hooks=false` | Matching event executes a Technique against passive owner/opponent. Internal payload Techniques can reuse all six action types. |
| [PermanentStatPassiveEffect](../scripts/passive/permanent_stat_passive_effect.gd) | `stat_change: ModifyStatUpgrade` | Matching event mutates the Familiar's persistent base stat. |
| [ModifyStatusPassiveEffect](../scripts/passive/modify_status_passive_effect.gd) | `status_effect`, `stack_bonus=0`, `field_name`, `field_bonus=0.0` | Queries STATUS_APPLIED matching before stack creation and before lifecycle hooks on the surviving status instance. Field choices are reflected numeric status fields other than stacks. |
| [ModifyHealPassiveEffect](../scripts/passive/modify_heal_passive_effect.gd) | `heal_bonus=0` | Queries HEALED matching during HealAction calculation; not a universal modifier of every Status.heal call. |
| [ModifyStatPassiveEffect](../scripts/passive/modify_stat_passive_effect.gd) | `stat=POWER`, `flat_bonus=0` | Continuously adds to effective_stat. Currently ignores trigger, conditions and limiter. |

The first two are reactive payloads; the next two are queried calculation inputs; the last is continuous. Do not assume the shared base fields make every trigger/payload combination operational. For ModifyStatusPassiveEffect select `status_effect`, and leave the base `status_effect_filter` at NONE: these modifier queries do not supply a relevant_status object. The same non-NONE filter problem applies to heal modifier queries.

### Trigger inventory and actual dispatch

There are 15 serialized Trigger entries: 14 dispatched names plus retired HEAL_CAST. The table describes reactive notifications; queried modifiers use the matching machinery separately.

| Trigger | Dispatch point / scope |
| --- | --- |
| `BATTLE_START` | Each side checks its own passives before first actor selection. |
| `BATTLE_END` | Each side checks its own passives when victory is detected. The engine method is not idempotent. |
| `TURN_START` | Actor's own passives, before the stun check. |
| `TURN_END` | Actor's own passives after its technique; skipped by the stunned-turn return. |
| `TECHNIQUE_USED` | Actor's own passives after selecting its technique, before building its steps. |
| `ATTACK` | Attacker-side hit helper calls status on_attack hooks and then own passive notification. |
| `HIT` | Defender-side status on_hit hooks and own passive notification; ordinary technique hits skip this after defender defeat. Retaliation also invokes this path explicitly. |
| `DAMAGE_DEALT` | Attacker's own notification from technique hit resolution after attack/hit reactions. Not a general take_damage event. |
| `DAMAGE_TAKEN` | Target's own notification from technique hit resolution if still alive. Not a universal DoT/retaliation event. |
| `STATUS_APPLIED` | Technique application, fresh or merged; both sides queried about the affected bearer. It is dispatched even when Ward absorbed the application fully. |
| `STATUS_CREATED` | Additional application notification when add_status reports fresh creation; both sides queried. |
| `STATUS_REDUCED` | Stack-change notification for a decrease, including depletion; both sides queried. |
| `STATUS_REMOVED` | Additional notification when that decrease expires the status; both sides queried. |
| `HEALED` | Recipient's own notification after positive HealAction recovery, or detected HP gain in upkeep/on_hit processing. Lifesteal's on_attack heal does not use that same detection path. |
| `HEAL_CAST` | Retired enum slot retained for compatibility; do not author new content against it. |

`trigger_target` chooses whose event to match, not where the payload aims. Only the status-event paths above explicitly consult both owners: setting TARGET does **not** subscribe to every opponent turn/attack/heal event. Most own-only events need SELF. Payload actions select their targets separately.

HIT/ATTACK and damage notifications can run for hits fully absorbed by Absorption: dispatch tests the pre-interception damage branch, not positive final HP loss. `triggers_hooks=false` is not a universal reaction mute; status lifecycle/stack-change reactions still have their own paths. These are current implementation limitations, not newly approved semantics.

Limiters: NONE, ONCE_PER_TURN, ONCE_PER_BATTLE, ONCE_PER_TECHNIQUE. Counts are stored by PassiveEffect identity on Combatant. Turn and technique limits currently reset together before that owner's upkeep in normal combat; battle limits persist for the Combatant lifetime. Record-before-effect protects reactive recursion. Stack and field modifier queries both use limiter accounting; combining both in one limited passive is not guaranteed to behave like one atomic modification.

[FocusTable](../scripts/passive/focus_table.gd) is an `effects: Array[PassiveEffect]` added to the familiar's own passives during matching/stat calculation. Its assigned [table resource](../resources/focus_tables/focus_table.tres) currently references Defense, Burn Flare, Foretell damage and heal-power effects. Thresholds are conditions on those resources, not an automatic table-wide tier filter. The continuous Defense effect's condition is currently ignored.

## 7. Editor, reward and presentation scaffolding

[ConditionBlockDefinition](../scripts/priority_builder/condition_block_definition.gd) describes a sentence shape: `category`, `block_label`, `condition_script`, `fixed_values`, `sentence`, and optional `body_property`. [SentencePart](../scripts/priority_builder/sentence_part.gd) supports TEXT, ENUM_CHOICE and NUMBER; option sources NONE, TARGET, COMPARATOR, STATUS_EFFECT and FAMILIAR_STAT. Number fields include min/max/step, display_scale and suffix.

The nine shipped [palette definitions](../resources/priority_builder/blocks) are `status_vs_value`, `status_vs_status`, `all_stacks_vs_value`, `hp_vs_percent`, `hp_vs_value`, `hp_vs_hp`, `stat_vs_value`, `stat_vs_stat`, `not`. Runtime condition support is broader than this palette: Focus and pre-application predicates have no shipped blocks. Nested normal blocks flatten to AND; NOT wraps one leaf. Incomplete segments are excluded. Adding a runtime predicate does not automatically add editor support.

Technique and PassiveEffect reward metadata: `tags`, `role_offense`, `role_defense`, `role_sustain`, `role_control`. Familiar uses `TagAffinity` resources (`tag`, `weight`) for Species and Pivot; BuildSnapshot counts owned content for RUN. These fields influence drafting, not combat effects.

[RewardTag](../scripts/reward/reward_tag.gd) currently contains these 42 values (no STUN tag):

```text
POISON BURN ACID BLEED STAGGER FORETELL DEFENDING INFESTATION
HONE FORTIFY ENLARGE RECHARGE THORNS WARD HEX ABSORPTION RUIN
RETALIATION STASIS RENEWAL LIFESTEAL REGENERATION CLEANSE
SELF_STATUS TARGET_STATUS STATUS_TALL STATUS_WIDE STATUS_CHURN
STATUS_PRESERVATION MULTIHIT BIG_HIT GETTING_HIT SELF_DEBUFF
DEFENSE_SCALING POWER_SCALING STAT_COMPARISON HP_THRESHOLD CONTROL_TAG
HEALING BIG_HEAL MULTI_HEAL GETTING_HEALED
```

Species scores innate affinity; RUN scores owned tags and role deficiencies; Pivot/Wildcard favors moderate combined overlap. Preserve enum order because `.tres` stores numeric indices. Existing “placeholder vocabulary” notes do not establish that this list is final design.

Build mutation resources under [scripts/upgrade](../scripts/upgrade): AddTechniqueUpgrade (`technique`, optional `rule`), AddPassiveUpgrade (`passive`), ModifyStatUpgrade (`stat`, `bonus`), TradePassiveUpgrade (`new_passive`, runtime `passive_to_remove`). GiveUpPassiveOption and SkipSacrificeOption are reward UI choices, not combat operations. UpgradeOption.unique is unused by current reward selection. Learning through current rewards does not automatically install a rule; placeholder AIDrafter also has this limitation.

Presentation hooks are part of authoring support: Conditions provide `describe()` for skip reasons; Techniques provide `describe()`/`effect_summary()`; bonuses provide lead/qualifier summaries; passives compose trigger and payload text; statuses provide `describe()`, `icon()`, `preview_color()`, `next_tick_damage()`, and `Status.status_link()` for nested tooltips. Descriptions are not a validation engine and some are stale, notably configurable status decay and healing descriptions. Verify visible text against the authored effect.

## 8. Authoring workflow and extension boundaries

1. Start with an existing `.tres` of the required shape. [Chronoparry](../resources/techniques/chronoparry.tres) demonstrates ordered status actions; its [fallback rule](../resources/priority_rules/pebbloq_parry_rule.tres) has no conditions. [Reap](../resources/techniques/reap.tres) demonstrates both-side status-count scaling. These are structural examples, not recommended balance values.
2. Configure groups, repeats, conditions, actions and bonus targets explicitly. Use separate groups for distinct bonus sets, remembering that group gates are sampled before execution.
3. Put the technique in a Familiar's available list and reference it from its intended priority rule. Configure passives by payload kind and actual event dispatch, not trigger name alone.
4. Add intended draftable content to the controller's authored reward pools. Keep internal [passive operation Techniques](../resources/techniques/passive_operations) out of ordinary offerings unless deliberately exposed. Keep boss content out of the starting roster.
5. Inspect descriptions, priority skip reasons, targeting and multi-hit behavior. Use existing bracket/balance/matchup tools described in [AGENTS.md](../AGENTS.md); choose checks appropriate to the change. StateProbe is a rotation preview against a non-acting dummy, not a full defensive matchup test.

New statuses require a subclass plus enum/factory/ID mappings, presentation hooks and any special interception plumbing. Available status hooks are `on_applied`, `on_reapply`, `on_tick`, `on_hit`, `on_attack`, `on_status_applied`, `stack_with`, `max_stacks`, `modify_stat`, `modify_incoming_damage`, `is_expired`, and `grants_first_act_override`. No concrete status currently overrides the first-actor hook. There is no generic death, expiration-payload, history-query, priority-reordering, or arbitrary-script action Resource.

New action types require dispatch and summary support; new conditions need editor descriptors if the player should manipulate them; new passive triggers require explicit call sites and correct affected-side/relevant-status context. Significant changes to those execution contracts require owner discussion.

Known hazards when validating new content: editor conditions can alias shared resources; preview reset/cross-check fidelity is incomplete; simulations can mutate Familiar stats through permanent effects; random effects prevent blanket determinism; and strong runtime reference cycles can retain objects. The inventory documents these boundaries so authors do not mistake a present field or class for a stronger guarantee. No code, resources, comments or gameplay text were changed to produce this reference.
