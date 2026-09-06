# Visual Overhaul — Design

**Date:** 2026-09-06
**Status:** approved, not yet implemented
**Scope:** Pixel Pugilists

## 1. Goal

Six mockups in `assets/ui_mockup/` (battle, builder, reward, stat, prefight,
bracket) share one consistent visual language — dark navy background,
orange (player) / teal (opponent) as the recurring color pair, a
corner-rivet/notched-tab panel frame used everywhere, all-caps pixel-font
labels, and a `[Z]`/`[X]`/`[ESC]` hint bar. `GAME_DESIGN.md` §10 has
deprioritized matching this look behind the bracket since session 8; the
bracket is done, so this is next.

The question this design settles: **what shared visual system reproduces
that language, and — since matching the mockups surfaced a few real gaps,
not just skins — what small behavior changes ride along with it, screen by
screen.**

## 2. Scope

**In scope**

- A shared visual foundation: `Theme` resource, a reusable custom-drawn
  framed-panel component, a shared title-banner component, a small stat
  icon set, and the HP bar re-skinned to the mockups' heart-icon style.
  Validated on the Game Over screen first, before six screens depend on it.
- Per-screen reskins using that foundation: battle, bracket, builder,
  prefight, stat, reward.
- Three small pieces of *new* behavior the mockups call for, each scoped
  to stay small (§4.6–§4.8): a real Auto ON/OFF toggle for battle pacing,
  a round-name mapping for the prefight panel, and techniques/passives
  shown on the stat screen.
- One larger piece of new behavior, deliberately sequenced last since it
  touches the reward flow most (§4.9): showing the next opponent and a
  bracket-preview popup on the reward screen, plus a "view my current
  build" popup. Turned out simpler than expected — verified against the
  real code that `start_next_round()` already resolves the round and
  assigns the next opponent *before* showing the reward screen, so this
  is a display addition reading already-correct data, not a reorder of
  the bracket logic just built.

**Out of scope**

- Background art (arena floor, crowd silhouettes, banners, spotlights) —
  the mockups' scene-setting imagery, not the UI chrome on top of it.
  Battle/prefight/bracket keep a simple background. A separate, later
  effort if wanted.
- Rebuilding the priority builder's condition-editing widgets to match
  the mockup's exact atomic-dropdown-row look. The builder gets the
  shared visual system applied to its current structure; the underlying
  widget mechanism is unchanged.
- Real keyboard shortcuts. Every mockup's hint bar is dropped outright
  (per-screen footers become just their functional buttons — Continue,
  Save Priority Rules, Confirm Upgrades, etc.) rather than kept and wired
  to real hotkeys.
- The battle mockup's "ACID BATH!" splash banner, its center "VS" graphic,
  and a fade-in/fade-out technique-name toast — all explicitly dropped or
  deferred, not reproduced.
- Any gold/fame currency display (reward mockup shows "You earned 25 gold,
  10 fame") — no economy exists in this project (§0.3), nothing to show.
- Any change to game balance, combat resolution, or the reward-selection
  algorithm itself — this touches presentation and the one sequencing
  change in §4.9, not what any of those systems actually decide.

**Deferred with a reason**

- NinePatchRect texture assets for the framed-panel style, as a fallback
  if the custom-drawn version doesn't look right once seen live. Noted
  explicitly rather than silently dropped, per the developer's own call.
- Real hotkey wiring, background art, and the builder's atomic-condition
  rework are all real, wanted follow-ups — just not this pass.

## 3. Approach

**Foundation before screens, validated on the smallest one first.** Six
screens sharing one design system is too much surface area to build and
verify at once — the same reasoning that kept the bracket spec's phases
ordered data-first. Game Over is the smallest real screen (a label, a
button), so the whole kit (Theme, panel, banner, icons, HP bar) proves
itself there before anything else depends on it.

**A custom-drawn `Control` for the panel frame, not NinePatchRect.** The
mockups' corner rivets, notched corners, and flag-shaped header tab aren't
expressible with Godot's built-in `StyleBoxFlat` (which only does flat
fills, borders, and rounded corners) or with a single texture unless that
texture is authored pixel-art matching this exact frame at every panel
size it's used at. A script overriding `_draw()` renders the frame
procedurally from Theme colors and the panel's own rect — one file
controls every screen's panel look, no image assets to author or
re-export if a color changes. This is the developer's explicit choice,
made knowing the tradeoff: if the result doesn't read as pixel-art enough
once seen live, authored NinePatchRect textures are the fallback,
addressed at the Foundation layer only (screens that already reskinned
onto the shared component don't need to change).

**Reskin existing scenes/scripts in place; don't rebuild.** Every screen
already has working logic (`battle_controller.gd`, `PriorityBuilder`,
`RewardCard`, `StatUpgradeRow`, `BracketScreen`) built and tested across
the last two sessions. This pass changes how those screens *look* —
swapping backgrounds/borders/fonts/colors onto the shared components and
adjusting layout to match the mockups — not what they *do*, except for
the three-plus-one behavior changes named in scope, each independently
described in its own subsection below.

## 4. Design

### 4.1 `Theme` resource (`assets/themes/pixel_pugilists.tres`)

Colors read directly off the mockups (approximate hex, refined once seen
live against `BoldPixels.ttf`):

| Token | Use | Approx. hex |
|---|---|---|
| `background` | Screen/panel fill | `#0d1117` |
| `panel_border` | Frame lines, rivets | `#3a4048` |
| `player_accent` | Player name/HP/highlights | `#e8542e` |
| `enemy_accent` | Opponent name/HP/highlights | `#3ecfc4` |
| `gold_accent` | Titles, crowns, selection glow | `#ffb648` |
| `text_primary` | Body label text | `#e8e8e8` |
| `text_muted` | Secondary/flavor text | `#8a8f98` |
| `hp_full` | HP bar fill (healthy) | `#4caf50` |
| `hp_low` | HP bar fill (critical) | `#e53935` |

`BoldPixels.ttf` (already in `assets/fonts/`) becomes the Theme's default
font, at three sizes: header (title banners, screen titles), body (labels,
descriptions), and small (stat values, hint text). `Button` gets a default
`StyleBoxFlat` derived from `panel_border`/`background` with a
`gold_accent` focus/hover state — the built-in theme system handles plain
buttons natively; only the distinctive frame (§4.2) needs custom drawing.

### 4.2 `FramedPanel` (new, `scripts/ui/framed_panel.gd` + matching scene)

A `Control` overriding `_draw()`:

- A rectangular border in `panel_border`, inset from the control's own
  rect.
- Small filled-circle "rivets" at each corner, just inside the border.
- Notched (cut-corner) corners rather than square ones — drawn as short
  diagonal line segments at each corner instead of a right angle.
- An optional header "tab": a small flag-shaped label area cut into the
  top edge, sized to its text, used wherever a mockup shows a named
  section (e.g. "CONDITIONS PALETTE", "COMBAT LOG").

Exported: `border_color`, `header_text: String` (empty = no tab). Every
other screen's panels become children of a `FramedPanel` (or the screen's
root background does), rather than plain `Panel`/`ColorRect` nodes.

### 4.3 `TitleBanner` (new, small shared scene)

The "★ PIXEL PUGILISTS ★" tag shown top-center on every mockup. One scene
(`scenes/ui/title_banner.tscn`), instanced into each screen rather than
duplicated — it's pixel-identical everywhere, and a shared scene is the
right call for content that never varies (contrast with per-screen
`FramedPanel` instances, which do vary in size/header text).

### 4.4 Stat icon set

Power/Defense/Speed/Focus/Max HP have no icons yet — confirmed by
checking `assets/sprites/icons/` (23 status-effect icons exist, no stat
icons) and `RewardCard`'s own code comment, which already calls out "icon
placeholder" as a known gap. Sourced first from the unused stock sheets
already in the project (`Icons_RPG.png`, `Icons_Warfare.png`, etc. — a
sword/shield/heart/lightning-bolt/eye are generic enough to very likely
already exist in one of these); only genuinely missing icons get new art.
Five new `AtlasTexture` `.tres` resources, mirroring the existing
`*_icon.tres` convention.

### 4.5 HP bar re-skin

`HPBar` (`scripts/hp_bar.gd`) already composites a `ProgressBar` + status
preview segments + a label — re-skinned, not rebuilt: the fill color
switches between `hp_full`/`hp_low` (already partly true via the
mockups' green/red split, probably threshold-based rather than binary,
tuned once seen live), a heart icon is added, and the label's numeric
text is centered over the bar rather than beside it, matching every
mockup's HP bar treatment.

### 4.6 Battle: Auto ON/OFF replaces always-on pacing

Currently `take_turn()` (`battle_controller.gd:748`) pauses 0.6s after
every `paced` log entry via `get_tree().create_timer()`, scaled by
`Engine.time_scale` from the existing speed toggle (1x/2x/4x). This adds
a mode, not a replacement: a new `auto_enabled: bool` (default true) on
`battle_controller.gd`. When true, behavior is exactly what exists today
plus the speed control. When false, `take_turn()`'s per-turn pause point
(after `advance_turn()`'s upkeep resolves, before the next actor's own
turn) instead awaits a `step_requested` signal from a new "step forward"
button — one step advances one full turn (one actor's upkeep + action),
matching the granularity `StateProbe`'s existing Step/Play/Reset already
established for the priority builder's mock fights, not per-message
granularity. The footer becomes: an Auto ON/OFF toggle button; to its
right, either the existing speed control (auto on) or a step-forward
button (auto off) — one visible at a time.

### 4.7 Prefight: round-name mapping

The "Bout 2" panel needs "Quarterfinals"/"Semifinals"/etc., which doesn't
exist — `current_round` is presently just a 0-indexed int. A small static
lookup, `Bracket.round_display_name(round_index: int) -> String`
(0→"First Round", 1→"Quarterfinals", 2→"Semifinals", 3→"Final"), colocated
with `Bracket` since it's a property of the tournament structure (4
rounds, always), not UI. The flavor lines beneath it, and the header's
"Season 3 • Semifinals" subtitle, are dropped rather than reproduced —
this project has no season/circuit concept (§0.3).

### 4.8 Stat screen: show techniques/passives

`populate_stat_upgrade_rows()` currently populates only the 5 stat rows —
confirmed by reading it; no technique/passive list exists on this screen
today. Add two read-only list panels (technique names + descriptions,
passive names + descriptions) reading `player_familiar_data.techniques`/
`.passives`, mirroring how `BracketScreen`'s detail panel already lists a
familiar's techniques. Footer becomes just "Confirm Upgrades".

### 4.9 Reward screen: next-opponent preview, bracket popup, build popup

The most architectural piece, sequenced last deliberately.

**No resequencing needed — verified against the real code, not assumed.**
`start_next_round()` (`scripts/battle_controller.gd:868`) already calls
`BracketResolver.resolve_round()`, `bracket.advance_round()`, and assigns
the new `enemy_familiar_data` *before* its final call to
`begin_reward_sequence()`. The off-screen matches are resolved, the round
has advanced, and the player's next opponent is already known by the time
the reward screen shows — this was true the moment the bracket shipped.
What's actually missing is only that the reward screen doesn't yet
*display* any of that already-available data. This section is a UI
addition, not an architecture change.

**Next-opponent preview + bracket mini-summary.** A small panel on the
reward screen showing `enemy_familiar_data` (already assigned by
`start_next_round()` before the reward screen shows) — portrait, name,
stats — plus a compact bracket summary (how many rounds remain, the
player's remaining path). Clicking it opens a temporary popup reusing
`BracketScreen` in read-only mode (`selectable = false`, matching how the
between-round scouting screen already uses it), dismissed the same way.

**"View my build" popup.** A footer button opening a read-only panel
listing `player_familiar_data`'s current techniques, passives, and stats
— reusing the same list layout as §4.8's stat-screen technique/passive
panels rather than a third bespoke one.

**Footer becomes:** "Confirm Selection" and "View My Build" — no
gold/fame line (§2), no keyboard hints.

## 5. Files (expected)

- `assets/themes/pixel_pugilists.tres` (new).
- `scripts/ui/framed_panel.gd` + `scenes/ui/framed_panel.tscn` (new).
- `scenes/ui/title_banner.tscn` (new).
- `assets/sprites/icons/power_icon.tres`, `defense_icon.tres`,
  `speed_icon.tres`, `focus_icon.tres`, `max_hp_icon.tres` (new, sourced
  from existing sheets where possible).
- `scripts/hp_bar.gd`, `scenes/*.tscn` containing an `HPBar` (modified).
- `scripts/battle_controller.gd` — Auto toggle/step (§4.6), stat-screen
  technique/passive panels (§4.8), reward-screen preview/popups (§4.9),
  every screen's footer simplified, `TitleBanner`/`FramedPanel` wired in.
- `scripts/bracket/bracket.gd` — `round_display_name()` (§4.7).
- `scenes/battle.tscn`, `scenes/priority_builder/priority_builder.tscn` —
  panel/background restyling, footer node removal.
- Every screen scene gains `FramedPanel`/`TitleBanner` instances in place
  of plain `Panel`/`ColorRect`/ad-hoc backgrounds.

## 6. Validation

- Live, through the `godot-mcp-toolkit` MCP tools — this is a visual pass;
  a headless harness can confirm data (round names, which techniques show)
  but not whether a panel actually looks like the mockup. Screenshot each
  screen against its mockup side by side after reskinning.
- Before touching `start_next_round()`/`begin_reward_sequence()` for §4.9,
  re-read the current call order and confirm in writing which parts (if
  any) actually need reordering, per that section's own note.
- `scripts/tools/bracket_test.gd` and `balance_test.gd` re-run at the end
  — nothing in this pass should change either, so both should still match
  their current baselines.
- Parse-check (`--check-only`) after every task, same as every prior pass.

## 7. Open questions

- Exact HP-bar green/red threshold (a hard cutoff vs. a gradient) — first
  guess, tune once seen live.
- Whether the custom-drawn `FramedPanel` reads as intended, or whether
  the NinePatchRect fallback (§3) is needed — decided after Foundation
  validates on Game Over, before six screens commit to one approach.
- Exact wording/count of the reward screen's bracket mini-summary (how
  much detail is enough vs. cluttered) — a first pass, refined once seen
  against real bracket state.
