class_name TagAffinity
extends Resource

## A weighted "this species cares about this tag, by this much" pair --
## Familiar.species_affinities is an Array of these. Weighted rather than
## a plain tag set, since a species can care about one tag a lot (e.g.
## Burn) and another only a little (e.g. Target Status), not just
## "relevant or not." A small Resource rather than a Dictionary export,
## for the same reason ConditionBlockDefinition's sentence parts are
## small Resources -- an Inspector-editable array of typed structs is
## friendlier to author than a typed Dictionary's more limited editor UI.

@export var tag: RewardTag.Tag
@export var weight: int = 1
