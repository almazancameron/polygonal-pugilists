class_name RewardTag
extends RefCounted

## Closed, append-only vocabulary for the reward-selection system's tags
## (Technique.tags / PassiveEffect.tags / Familiar.species_affinities.tag).
## Append-only for the same reason PassiveEffect.Trigger is: an authored
## .tres stores a tag as this enum's raw integer index, so inserting a
## value would silently shift every tag already saved after it.
##
## This is a placeholder starter set, not the authoritative vocabulary --
## the developer supplies that separately; appending the real list later
## costs nothing since RewardSelector only ever does generic set/weight
## lookups against whichever values exist, never a per-tag match().
##
## Authoring discipline, not enforced by code: a tag should capture one of
## a piece of content's few genuinely meaningful drafting hooks, not an
## exhaustive checklist of every mechanical property it touches. More tags
## can increase Species/Run relevance, but Pivot (Wildcard) favors moderate
## overlap: adding overlap beyond its peak reduces the candidate's weight.
enum Tag {
	POISON, BURN, ACID, BLEED, STAGGER, FORETELL, DEFENDING, INFESTATION,
	HONE, FORTIFY, ENLARGE, RECHARGE, THORNS, WARD, HEX, ABSORPTION, RUIN,
	RETALIATION, STASIS, RENEWAL, LIFESTEAL, REGENERATION, CLEANSE,
	SELF_STATUS, TARGET_STATUS, STATUS_TALL, STATUS_WIDE, STATUS_CHURN,
	STATUS_PRESERVATION, MULTIHIT, BIG_HIT, GETTING_HIT, SELF_DEBUFF,
	DEFENSE_SCALING, POWER_SCALING, STAT_COMPARISON, HP_THRESHOLD, CONTROL_TAG,
	HEALING, BIG_HEAL, MULTI_HEAL, GETTING_HEALED,
}
