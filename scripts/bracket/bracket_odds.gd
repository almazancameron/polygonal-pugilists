class_name BracketOdds
extends RefCounted

## Turns a simulated match's HP margin into the odds an off-screen match
## gets rolled against, plus the coarse label the player sees while
## scouting. All static -- no state, no scene tree.
##
## OPEN / PLAYTEST: every constant here is a first, reversible guess.
## Retune once real brackets have actually been played, not before.

const HEAVY_FAVORITE_THRESHOLD: float = 0.90
const FAVORITE_THRESHOLD: float = 0.70

const LABEL_HEAVY_FAVORITE: String = "Heavy Favorite"
const LABEL_FAVORITE: String = "Favorite"
const LABEL_TOSS_UP: String = "Toss-up"
const LABEL_UNDERDOG: String = "Underdog"
const LABEL_HEAVY_UNDERDOG: String = "Heavy Underdog"

## How decisively the winner won, as a 0..1 HP-fraction gap. A real
## defeat leaves the loser at 0.0, so this collapses to "how much HP did
## the winner keep"; a stalemate (both sides alive at the turn cap) has
## both fractions above zero and naturally lands near 0, which is exactly
## what a stalemate should mean.
static func margin(winner_hp_pct: float, loser_hp_pct: float) -> float:
	return clampf(winner_hp_pct - loser_hp_pct, 0.0, 1.0)

## The chance the simulated winner actually advances. Linear and
## symmetric: a dead-even fight is a coin flip, a flawless win is a lock,
## and everything between leaves room for an upset.
static func advance_probability(margin_value: float) -> float:
	return clampf(0.5 + 0.5 * margin_value, 0.5, 1.0)

static func winner_label(probability: float) -> String:
	if probability >= HEAVY_FAVORITE_THRESHOLD:
		return LABEL_HEAVY_FAVORITE
	if probability >= FAVORITE_THRESHOLD:
		return LABEL_FAVORITE
	return LABEL_TOSS_UP

static func loser_label(probability: float) -> String:
	if probability >= HEAVY_FAVORITE_THRESHOLD:
		return LABEL_HEAVY_UNDERDOG
	if probability >= FAVORITE_THRESHOLD:
		return LABEL_UNDERDOG
	return LABEL_TOSS_UP

## The color an odds label reads in wherever it's shown directly (not just
## in a tooltip) -- e.g. BracketTree's leaf cards. Defaults to the
## toss-up gray for an empty/unrecognized label (a match with no odds
## scouted yet), rather than something alarming like red.
static func label_color(label: String) -> Color:
	match label:
		LABEL_HEAVY_FAVORITE:
			return Palette.ODDS_HEAVY_FAVORITE
		LABEL_FAVORITE:
			return Palette.ODDS_FAVORITE
		LABEL_UNDERDOG:
			return Palette.ODDS_UNDERDOG
		LABEL_HEAVY_UNDERDOG:
			return Palette.ODDS_HEAVY_UNDERDOG
	return Palette.ODDS_TOSS_UP
