class_name StatusPresentBeforeApplicationCondition
extends Condition

## Checks whether a combatant already had a status BEFORE the status
## application currently being resolved -- unlike StatusComparisonCondition,
## which reads live/current state and can't distinguish "already had it"
## from "just gained it via this very application" (by the time any
## STATUS_APPLIED/STATUS_CREATED passive is checked, add_status() has
## already run, so a fresh application already shows up as "present").
##
## Only meaningful inside a PassiveEffect triggered by STATUS_APPLIED/
## STATUS_CREATED -- reads Combatant.pre_application_snapshot, which is
## only ever populated by Technique.apply_status() immediately before
## add_status() runs. Checked anywhere else (a PriorityRule's conditions,
## say), it reads stale or empty data.

enum Target { SELF, TARGET }
enum Comparator { GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL }

@export var check_target: Target = Target.TARGET
@export var status_effect: Status.StatusEffect = Status.StatusEffect.NONE

## Sums every status's pre-application stacks instead of one specific
## effect -- same idea as StatusComparisonCondition's check_all.
@export var check_all: bool = false

@export var value: int = 1
@export var comparator: Comparator = Comparator.GREATER_OR_EQUAL

func _resolve(combatant: Combatant) -> int:
	if check_all:
		var total: int = 0
		for stacks in combatant.pre_application_snapshot.values():
			total += stacks
		return total

	return combatant.pre_application_snapshot.get(Status.status_effect_id(status_effect), 0)

func is_met(user: Combatant, target: Combatant) -> bool:
	var combatant: Combatant = user if check_target == Target.SELF else target
	var left: int = _resolve(combatant)

	match comparator:
		Comparator.GREATER:
			return left > value
		Comparator.GREATER_OR_EQUAL:
			return left >= value
		Comparator.LESS:
			return left < value
		Comparator.LESS_OR_EQUAL:
			return left <= value
		Comparator.EQUAL:
			return left == value
	return false

func describe() -> String:
	var whose: String = "target's" if check_target == Target.TARGET else "user's"
	var name_str: String = "total status stacks" if check_all else String(Status.status_effect_id(status_effect)).capitalize()
	var comparator_str: String = {
		Comparator.GREATER: ">", Comparator.GREATER_OR_EQUAL: ">=",
		Comparator.LESS: "<", Comparator.LESS_OR_EQUAL: "<=", Comparator.EQUAL: "==",
	}[comparator]
	return "%s %s stacks (before this application) %s %d" % [whose, name_str, comparator_str, value]
