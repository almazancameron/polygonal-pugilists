class_name SentencePart
extends Resource

## One fragment of a condition block's fill-in-the-blank sentence: either
## literal text, a dropdown bound to one of the shared enum option tables, or
## a numeric spinner. `property` names the field on the Condition this part
## writes to -- so the same option_source serves both left_target and
## right_target, differing only in destination.

enum Kind { TEXT, ENUM_CHOICE, NUMBER }
enum OptionSource { NONE, TARGET, COMPARATOR, STATUS_EFFECT, FAMILIAR_STAT }

@export var kind: Kind = Kind.TEXT

## Kind.TEXT only.
@export var text: String = ""

## Destination field on the Condition, for ENUM_CHOICE and NUMBER.
@export var property: StringName = &""

@export var option_source: OptionSource = OptionSource.NONE

@export var min_value: float = 0.0
@export var max_value: float = 99.0
@export var step: float = 1.0

## Widget value * display_scale = the value stored on the Condition. 0.01
## makes a spinner reading 25 store 0.25, which is how HpComparisonCondition
## expects a percentage (see poison_spammer.tres's right_value = 0.25).
##
## One NUMBER kind covers integers, raw floats and percentages, because what
## actually varies between them is the widget's configuration, not the
## property's type.
@export var display_scale: float = 1.0

@export var suffix: String = ""
