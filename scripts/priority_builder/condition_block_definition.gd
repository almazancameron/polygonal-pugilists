class_name ConditionBlockDefinition
extends Resource

## One palette block: which Condition subclass it builds, which of that
## subclass's fields its sentence exposes, and which it pins down.
##
## There is one definition per *sentence shape*, not per Condition subclass.
## compare_mode decides whether right_value or right_target is the live
## field, so a single block covering both would need slots that hide and
## show; instead "target's Acid stacks < 5" and "my Poison vs their Poison"
## are two separate blocks. That is what keeps ConditionBlock free of any
## conditional visibility logic.
##
## Shared and read-only. Never mutated at runtime -- each ConditionBlock
## instantiates its own Condition via condition_script.new(). See
## DECISIONS.md on resources referenced by more than one owner.

## Palette grouping header ("Status", "HP", "Stat", "Logic").
@export var category: String = "Status"

## Short name shown on the palette entry.
@export var block_label: String = ""

@export var condition_script: Script

## Fields the sentence never exposes, applied before the sentence's own
## values. Enum values are raw ints: compare_mode 1 is FLAT_VALUE and 0 is
## the compare-against-the-other-side mode (STATUS/HP/STAT) in all three
## comparison classes. Getting these wrong yields a condition that silently
## always evaluates the same way, so they are asserted in verification.
@export var fixed_values: Dictionary = {}

@export var sentence: Array[SentencePart] = []

## Non-empty makes this a wrapper block: its single body child compiles to a
## Condition assigned to this property (only NotCondition.wrapped_condition
## today) instead of being flattened into the rule's conditions[].
##
## A wrapper's body takes exactly one leaf condition, and that condition
## takes no body children of its own -- otherwise a block nested inside a
## NOT would flatten into the rule's conditions[] and escape the negation,
## turning "not (A and B)" into "not A and B" while the on-screen nesting
## reads as the former.
@export var body_property: StringName = &""
