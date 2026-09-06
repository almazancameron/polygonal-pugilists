class_name BuildSnapshot
extends RefCounted

## A build's aggregated reward-tailoring signal, computed fresh each time
## the Run/Pivot slots need it (see RewardSelector) -- never authored,
## never stored on Familiar itself. Tag counts accumulate (a tag repeated
## across several equipped items should score higher than one seen only
## once), not a boolean set.

var owned_tag_counts: Dictionary = {}  # RewardTag.Tag -> int
var owned_role_totals: Dictionary = {"offense": 0, "defense": 0, "sustain": 0, "control": 0}

## excluding lets a caller compute "as if this item were already removed"
## -- used by the passive-trade flow (RewardFlowController), which scores
## replacement candidates against the build as it will be *after* the
## sacrificed passive, even though the actual removal only happens later
## on confirm. Tailoring on a profile that still counted the
## just-abandoned passive would recommend "more of what you just quit."
static func compute(familiar: Familiar, excluding: Array = []) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()

	var equipped: Array = []
	equipped.append_array(familiar.techniques)
	equipped.append_array(familiar.passives)

	for item in equipped:
		if item in excluding:
			continue

		for tag in item.tags:
			snapshot.owned_tag_counts[tag] = snapshot.owned_tag_counts.get(tag, 0) + 1

		snapshot.owned_role_totals["offense"] += item.role_offense
		snapshot.owned_role_totals["defense"] += item.role_defense
		snapshot.owned_role_totals["sustain"] += item.role_sustain
		snapshot.owned_role_totals["control"] += item.role_control

	return snapshot
