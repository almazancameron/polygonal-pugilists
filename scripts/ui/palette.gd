class_name Palette
extends RefCounted

## The visual overhaul's shared color tokens (design spec §4.1). Read from
## scripts as Palette.BACKGROUND etc.; the Theme resource
## (assets/themes/pixel_pugilists.tres) uses the same values for
## button/label default styling, kept in sync by hand since Theme has no
## "read a constant" mechanism of its own.

const BACKGROUND := Color(0.051, 0.067, 0.090)
const PANEL_BORDER := Color(0.227, 0.251, 0.282)
const PLAYER_ACCENT := Color(0.910, 0.329, 0.180)
const ENEMY_ACCENT := Color(0.243, 0.812, 0.769)
const GOLD_ACCENT := Color(1.0, 0.714, 0.282)
const TEXT_PRIMARY := Color(0.910, 0.910, 0.910)
const TEXT_MUTED := Color(0.541, 0.561, 0.596)
const HP_FULL := Color(0.298, 0.686, 0.314)
const HP_LOW := Color(0.898, 0.224, 0.208)
const HP_TRACK := Color(0.11, 0.13, 0.16)
