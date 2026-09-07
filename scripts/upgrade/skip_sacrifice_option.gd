class_name SkipSacrificeOption
extends UpgradeOption

## Display-only wrapper for the sacrifice screen's third card, sitting in
## the same row as the two "give up a passive" choices so skipping reads
## as an equally-weighted option instead of an afterthought tucked into
## the footer -- the whole reason this card exists at all (see
## RewardSelectPanel._populate_sacrifice_cards()). Fires immediately on
## click (that card's own pressed signal, not toggled), so -- like
## GiveUpPassiveOption -- apply() is never called here; skipping the
## trade already has its own handler on battle_controller.gd
## (_on_skip_pressed(), 2 stat points) that this just triggers via
## RewardSelectPanel's existing skip_requested signal.

func _init() -> void:
	label = "Skip"

func describe() -> String:
	return "Keep both passives. Gain +2 stat points instead."
