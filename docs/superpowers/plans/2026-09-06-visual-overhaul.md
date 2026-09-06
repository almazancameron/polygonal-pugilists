# Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin all six screens (battle, bracket, builder, prefight, stat, reward) to match `assets/ui_mockup/`'s shared visual language, plus four small-to-medium behavior additions the mockups exposed as missing.

**Architecture:** A Foundation of reusable pieces (`Theme`, a custom-drawn `FramedPanel`, a shared `TitleBanner`, stat icons, a re-skinned `HPBar`) validated on the Game Over screen first. Every later task reskins one existing screen using that Foundation — no screen gets rebuilt, only re-styled — except where a screen genuinely needs new logic (Auto toggle, round names, techniques/passives display, reward popups), each its own task.

**Tech Stack:** Godot 4.7.1, GDScript. Visual work is verified live through `godot-mcp-toolkit` (screenshot against the matching mockup); logic pieces get a headless check in `scripts/tools/bracket_test.gd` first.

**Spec:** `docs/superpowers/specs/2026-09-06-visual-overhaul-design.md`

## Global Constraints

- **Godot binary** (run from the project directory): `"../Godot_v4.7.1-stable_win64_console.exe"`
- **Parse check after every task:** `"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"` — empty output means clean.
- **Scene edits go through the MCP toolkit** (`scene_create_node`, `node_set_property`, `node_set_script`, `editor_save_scene`), never direct `.tscn` text edits — the editor has `battle.tscn` open live.
- **Screenshot verification**: after any visual change, `game_start` on `res://scenes/battle.tscn`, reach the screen under test (force a win per the recipe below if needed), `runtime_screenshot`, compare against the matching `assets/ui_mockup/*.png`, then `game_stop`.
- **Forcing a win**: with a fight actually in progress, `execute_code` (channel `runtime`) `get_node('/root/Battle').enemy.set('current_hp', 0)`, then let the natural turn loop end it — do not call `check_victory()` manually (double-advances the round; see `CLAUDE.md`).
- **`click_node` fires a button's `pressed` signal regardless of visibility** — screenshot first, never click a node you haven't confirmed is actually shown.
- **Switching git branches with the editor open can corrupt the `class_name` cache** — if a class the code clearly defines reports "not declared," rescan with `godot --headless --editor --quit-after 300` (not `--quit`, which exits before the scan finishes).
- **Commit after every task.** Do not push.

---

## Phase A — Foundation

### Task 1: Theme resource

**Files:**
- Create: `assets/themes/pixel_pugilists.tres`

**Interfaces:**
- Consumes: `assets/fonts/BoldPixels.ttf` (existing).
- Produces: a `Theme` resource every later task's `node_set_property` calls reference by path.

- [ ] **Step 1: Create the theme through the editor**

Use `execute_code` (channel `editor`) to build and save it programmatically —
more reliable than hand-authoring `.tres` theme syntax:

```gdscript
var theme := Theme.new()
var font := load("res://assets/fonts/BoldPixels.ttf")

theme.default_font = font
theme.set_font_size("font_size", "Label", 16)
theme.set_font_size("font_size", "Button", 16)
theme.set_font_size("font_size", "RichTextLabel", 16)

var button_normal := StyleBoxFlat.new()
button_normal.bg_color = Color(0.11, 0.13, 0.16)
button_normal.border_color = Color(0.227, 0.251, 0.282)
button_normal.set_border_width_all(2)
button_normal.set_corner_radius_all(2)
button_normal.set_content_margin_all(6)
theme.set_stylebox("normal", "Button", button_normal)

var button_hover := button_normal.duplicate()
button_hover.border_color = Color(1.0, 0.714, 0.282)  # gold_accent
theme.set_stylebox("hover", "Button", button_hover)
theme.set_stylebox("focus", "Button", button_hover)

var button_pressed := button_normal.duplicate()
button_pressed.bg_color = Color(0.16, 0.18, 0.22)
theme.set_stylebox("pressed", "Button", button_pressed)

var button_disabled := button_normal.duplicate()
button_disabled.bg_color = Color(0.08, 0.09, 0.10)
button_disabled.border_color = Color(0.15, 0.16, 0.18)
theme.set_stylebox("disabled", "Button", button_disabled)

ResourceSaver.save(theme, "res://assets/themes/pixel_pugilists.tres")
print("saved")
```

- [ ] **Step 2: Verify it saved correctly**

```gdscript
var reloaded: Theme = load("res://assets/themes/pixel_pugilists.tres")
print(reloaded.default_font != null, " ", reloaded.get_font_size("font_size", "Button"))
```

Expected: `true 16`.

- [ ] **Step 3: Also record the palette as GDScript constants**

Colors need to be referenced from scripts (HP bar fill, `FramedPanel`
border), not only from the `Theme`'s own StyleBoxes. Create
`scripts/ui/palette.gd`:

```gdscript
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
```

- [ ] **Step 4: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add assets/themes/pixel_pugilists.tres scripts/ui/palette.gd
git commit -m "feat: shared theme resource and color palette"
```

---

### Task 2: `FramedPanel` component

**Files:**
- Create: `scripts/ui/framed_panel.gd`
- Create: `scenes/ui/framed_panel.tscn`

**Interfaces:**
- Consumes: `Palette` (Task 1).
- Produces: `FramedPanel` (a `Control`), `@export var border_color: Color`,
  `@export var fill_color: Color`, `@export var header_text: String`
  (empty = no tab). Every later screen-reskin task instances this scene
  as the background for panels that show the mockups' notched-corner
  frame.

- [ ] **Step 1: Write `scripts/ui/framed_panel.gd`**

```gdscript
@tool
class_name FramedPanel
extends Control

## The mockups' shared panel frame: a notched-corner border, small rivet
## circles just inside each corner, and an optional flag-shaped header tab
## cut into the top edge. Drawn procedurally rather than as a texture
## (design spec §3) -- one script controls every screen's panel look, no
## image assets to author or re-export if a color changes.
##
## If this doesn't read as pixel-art enough once seen live against the
## real mockups, the documented fallback is authored NinePatchRect
## textures instead -- swapping FramedPanel's usage sites for NinePatchRect
## nodes, not a rewrite of the screens that use it.

const BORDER_WIDTH: float = 2.0
const CORNER_CUT: float = 10.0
const RIVET_RADIUS: float = 2.5
const RIVET_INSET: float = 9.0
const HEADER_HEIGHT: float = 22.0
const HEADER_SIDE_PADDING: float = 12.0

@export var border_color: Color = Palette.PANEL_BORDER:
	set(value):
		border_color = value
		queue_redraw()

@export var fill_color: Color = Palette.BACKGROUND:
	set(value):
		fill_color = value
		queue_redraw()

@export var header_text: String = "":
	set(value):
		header_text = value
		_update_header_label()
		queue_redraw()

var _header_label: Label

func _ready() -> void:
	resized.connect(queue_redraw)
	_update_header_label()

func _update_header_label() -> void:
	if header_text == "":
		if _header_label != null:
			_header_label.queue_free()
			_header_label = null
		return

	if _header_label == null:
		_header_label = Label.new()
		_header_label.add_theme_color_override("font_color", border_color)
		add_child(_header_label)

	_header_label.text = header_text
	_header_label.position = Vector2(HEADER_SIDE_PADDING * 2, 0)
	_header_label.size = Vector2(size.x, HEADER_HEIGHT)
	_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var has_header: bool = header_text != ""
	var header_width: float = 0.0
	if has_header and _header_label != null:
		header_width = _header_label.get_combined_minimum_size().x + HEADER_SIDE_PADDING * 2

	var points: Array[Vector2] = _outline_points(rect, has_header, header_width)

	draw_colored_polygon(points, fill_color)

	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, border_color, BORDER_WIDTH)

	for corner in [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]:
		var offset := (rect.get_center() - corner).normalized() * RIVET_INSET
		draw_circle(corner + offset, RIVET_RADIUS, border_color)

## The panel's outline as a notched-corner polygon, with an optional
## rectangular tab cut upward out of the top edge (left-aligned, just
## inside the top-left notch) for the header label to sit in.
func _outline_points(rect: Rect2, has_header: bool, header_width: float) -> Array[Vector2]:
	var c := CORNER_CUT
	var points: Array[Vector2] = [
		Vector2(rect.position.x, rect.position.y + c),
		Vector2(rect.position.x + c, rect.position.y),
	]

	if has_header:
		var tab_left: float = rect.position.x + c + HEADER_SIDE_PADDING
		var tab_right: float = tab_left + header_width
		points.append(Vector2(tab_left, rect.position.y))
		points.append(Vector2(tab_left, rect.position.y - HEADER_HEIGHT))
		points.append(Vector2(tab_right, rect.position.y - HEADER_HEIGHT))
		points.append(Vector2(tab_right, rect.position.y))

	points.append(Vector2(rect.end.x - c, rect.position.y))
	points.append(Vector2(rect.end.x, rect.position.y + c))
	points.append(Vector2(rect.end.x, rect.end.y - c))
	points.append(Vector2(rect.end.x - c, rect.end.y))
	points.append(Vector2(rect.position.x + c, rect.end.y))
	points.append(Vector2(rect.position.x, rect.end.y - c))
	return points
```

- [ ] **Step 2: Build `scenes/ui/framed_panel.tscn`**

Through the MCP toolkit — create a new scene with a `Control` root named
`FramedPanel`, attach the script:

```
scene_create(root_class="Control", root_name="FramedPanel", save_path="res://scenes/ui/framed_panel.tscn")
node_set_script(node_path=".", script_path="res://scripts/ui/framed_panel.gd")
node_set_property(node_path=".", property="mouse_filter", value=2)  # MOUSE_FILTER_IGNORE -- a background, never blocks clicks to real content on top
editor_save_scene()
```

- [ ] **Step 3: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/framed_panel.gd scenes/ui/framed_panel.tscn
git commit -m "feat: FramedPanel, the shared notched-corner panel component"
```

---

### Task 3: `TitleBanner` shared scene

**Files:**
- Create: `scenes/ui/title_banner.tscn`

**Interfaces:**
- Consumes: `Palette` (Task 1).
- Produces: a scene instanced (not duplicated) into every screen's root,
  top-center.

- [ ] **Step 1: Build the scene**

```
scene_create(root_class="Label", root_name="TitleBanner", save_path="res://scenes/ui/title_banner.tscn")
node_set_property(node_path=".", property="text", value="★ PIXEL PUGILISTS ★")
node_set_property(node_path=".", property="horizontal_alignment", value=1)
node_set_property(node_path=".", property="anchor_left", value=0)
node_set_property(node_path=".", property="anchor_right", value=1)
node_set_property(node_path=".", property="offset_top", value=8)
node_set_property(node_path=".", property="offset_bottom", value=28)
node_set_property(node_path=".", property="mouse_filter", value=2)
editor_save_scene()
```

Then set its font color to `Palette.TEXT_MUTED` via a theme override
(`node_set_property` with `property: "theme_override_colors/font_color"`,
`value: {"type":"Color","r":0.541,"g":0.561,"b":0.596,"a":1}`).

- [ ] **Step 2: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/title_banner.tscn
git commit -m "feat: shared TitleBanner scene"
```

---

### Task 4: Stat icon set

**Files:**
- Create: `assets/sprites/icons/power_icon.tres`, `defense_icon.tres`,
  `speed_icon.tres`, `focus_icon.tres`, `max_hp_icon.tres`

**Interfaces:**
- Consumes: existing icon sheets (`Icons_RPG.png`, `Icons_Warfare.png`,
  etc.) or the existing status-icon convention as a fallback pattern.
- Produces: five `AtlasTexture` resources, one per `Familiar.Stat` value,
  mirroring the `*_icon.tres` convention already used for statuses.

- [ ] **Step 1: Inspect the existing sheets for usable icons**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1
```

(Confirms the sheets still import cleanly before use.) Then, through
the editor UI (not scriptable — this is a human visual-judgment step),
open `assets/sprites/icons/Icons_RPG.png` and `Icons_Warfare.png` in the
editor's image preview and identify a sword, shield, boot/wing (speed),
eye/gem (focus), and heart icon, noting each one's pixel region.

- [ ] **Step 2: Author each `AtlasTexture` resource**

For each stat, following the exact pattern an existing status icon uses
(read one, e.g. `cat assets/sprites/icons/burn_icon.tres`, for the exact
`atlas`/`region` field shape), create e.g.
`assets/sprites/icons/power_icon.tres`:

```
[gd_resource type="AtlasTexture" format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/icons/Icons_Warfare.png" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2(0, 0, 16, 16)
```

(Region values determined from Step 1's inspection; adjust per icon.)
Repeat for `defense_icon`, `speed_icon`, `focus_icon`, `max_hp_icon` —
`max_hp_icon` may reuse the same heart region a status icon already uses,
if one exists (check `assets/sprites/icons/` for a heart before assuming
none exists).

- [ ] **Step 3: Verify each loads and renders a non-empty region**

```gdscript
extends SceneTree
func _init() -> void:
	for name in ["power", "defense", "speed", "focus", "max_hp"]:
		var tex: AtlasTexture = load("res://assets/sprites/icons/%s_icon.tres" % name)
		print(name, " ", tex != null, " ", tex.region if tex else "n/a")
	quit()
```

Save as `scripts/_verify_stat_icons.gd`, run
`"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_stat_icons.gd`,
confirm every line prints `true` with a non-zero region, then delete the
script.

- [ ] **Step 4: Commit**

```bash
git add assets/sprites/icons/power_icon.tres assets/sprites/icons/defense_icon.tres assets/sprites/icons/speed_icon.tres assets/sprites/icons/focus_icon.tres assets/sprites/icons/max_hp_icon.tres
git commit -m "feat: stat icon set (power/defense/speed/focus/max HP)"
```

---

### Task 5: HP bar re-skin

**Files:**
- Modify: `scripts/hp_bar.gd`
- Modify: the `HPBar` scene (find its path: `grep -rn "class_name HPBar" scenes/ 2>/dev/null` won't match since it's a script reference — instead find the owning scene with `grep -rln "hp_bar.gd" scenes/*.tscn` or check `Panels/PlayerPanel/HPBar`'s scene source via `scene_get_tree` on `battle.tscn`; it is likely `scenes/hp_bar.tscn`).

**Interfaces:**
- Consumes: `Palette` (Task 1).
- Produces: `HPBar.set_hp()`/`set_status_preview_segments()` unchanged
  (every caller keeps working); visual change only.

- [ ] **Step 1: Confirm the HP bar's owning scene**

```bash
grep -rln "hp_bar.gd" scenes/*.tscn scenes/**/*.tscn 2>/dev/null
```

- [ ] **Step 2: Add a heart icon and re-color the fill in `hp_bar.gd`**

```gdscript
@onready var heart_icon: TextureRect = $HeartIcon

const HEART_TEXTURE: Texture2D = preload("res://assets/sprites/icons/max_hp_icon.tres")

func set_hp(current: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = current
	label.text = "%d / %d" % [current, max_hp]

	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		fill_style = StyleBoxFlat.new()
	var hp_fraction: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	fill_style.bg_color = Palette.HP_FULL if hp_fraction > 0.35 else Palette.HP_LOW
	bar.add_theme_stylebox_override("fill", fill_style)
```

(The `>` 0.35 threshold is the spec's own noted first guess, §7 —
tune once seen live.)

- [ ] **Step 3: Add the `HeartIcon` node and center the label over the bar**

Through the MCP toolkit, on the HP bar's scene: add a `TextureRect` named
`HeartIcon` as a sibling of `Bar`, positioned at the bar's left edge
(`anchor_left`/`anchor_top` 0, small fixed size e.g. 16×16), texture set
to `res://assets/sprites/icons/max_hp_icon.tres`. Re-anchor `Bar/Label`
to full-rect + center alignment (it currently likely sits beside the bar
per the pre-mockup layout; the mockups show the number centered over the
fill).

- [ ] **Step 4: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 5: Screenshot verification**

`game_start` on `battle.tscn`, screenshot the pre-fight or battle screen,
confirm the heart icon renders and the HP number is centered over the
green/red fill, matching `assets/ui_mockup/battle_mockup.png`'s HP bars.
`game_stop`.

- [ ] **Step 6: Commit**

```bash
git add scripts/hp_bar.gd
git commit -m "feat: HP bar re-skin -- heart icon, centered label, threshold-colored fill"
```

---

### Task 6: Validate the Foundation on Game Over

**Files:**
- Modify: `scenes/battle.tscn` (`GameOverPanel`)

**Interfaces:**
- Consumes: `FramedPanel`, `TitleBanner`, `Palette` (Tasks 1–3).
- Produces: nothing new — this is the Foundation's first real proof,
  not a new component.

- [ ] **Step 1: Wrap `GameOverPanel` in a `FramedPanel` background**

Through the MCP toolkit: instance `res://scenes/ui/framed_panel.tscn` as
the first child of `GameOverPanel`, named `Background`, sized to fill the
panel (full-rect anchors), `header_text` left empty (Game Over has no
named section per the mockups' closest analog). Move it behind
`MessageLabel`/`RestartButton` (`node_manage` reorder to index 0).

- [ ] **Step 2: Instance `TitleBanner` at the scene root**

Instance `res://scenes/ui/title_banner.tscn` as a child of `Battle` (the
scene root), named `TitleBanner`, visible on every screen including Game
Over (it's always shown — the mockups never hide it).

- [ ] **Step 3: Apply the shared theme**

`node_set_property(node_path=".", property="theme", value={"type":"Resource","path":"res://assets/themes/pixel_pugilists.tres"})`
on the `Battle` root, so every button/label in the whole scene picks up
the Foundation's defaults at once.

- [ ] **Step 4: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 5: Screenshot verification**

`game_start`, force a loss (or a final win) to reach Game Over, screenshot
it. Confirm: the title banner shows top-center, `GameOverPanel` has a
visible notched-corner frame with rivets, and every button uses the
Foundation's bordered style with gold hover. This is the one screenshot
that validates the whole Foundation before six more screens depend on it
— if the frame doesn't read as intended, this is the moment to switch to
the NinePatchRect fallback (spec §3/§7), before it's built six more times.
`game_stop`.

- [ ] **Step 6: Commit**

```bash
git add scenes/battle.tscn
git commit -m "feat: validate the visual Foundation on the Game Over screen"
```

---

## Phase B — Battle screen

### Task 7: Battle screen reskin

**Files:**
- Modify: `scenes/battle.tscn` (`Panels`, `LogScroll`)

**Interfaces:**
- Consumes: `FramedPanel`, `Palette` (Tasks 1–2), re-skinned `HPBar`
  (Task 5).
- Produces: nothing new.

- [ ] **Step 1: Frame `PlayerPanel`/`EnemyPanel`**

For each of `Panels/PlayerPanel` and `Panels/EnemyPanel`: instance a
`FramedPanel` as their first child (full-rect, behind existing content),
`border_color` = `Palette.PLAYER_ACCENT` for `PlayerPanel`,
`Palette.ENEMY_ACCENT` for `EnemyPanel` — matching the mockups' orange/
teal split. Set `NameLabel`'s font color to match the same accent.

- [ ] **Step 2: Frame the combat log**

Instance a `FramedPanel` behind `LogScroll`, `header_text = "COMBAT LOG"`,
`border_color = Palette.PLAYER_ACCENT` (the mockup's log tab uses the
player's own accent color).

- [ ] **Step 3: Parse check and screenshot**

Parse check as in every prior task. Then `game_start`, reach the battle
screen (character select → Begin Combat), screenshot mid-fight, compare
against `assets/ui_mockup/battle_mockup.png`'s panel framing (ignore its
arena background art and the VS/splash graphics — explicitly out of
scope, spec §2). `game_stop`.

- [ ] **Step 4: Commit**

```bash
git add scenes/battle.tscn
git commit -m "feat: battle screen reskin -- framed player/enemy panels and combat log"
```

---

### Task 8: Auto ON/OFF toggle

**Files:**
- Modify: `scripts/battle_controller.gd`
- Modify: `scenes/battle.tscn` (`SpeedToggleButton`'s row)

**Interfaces:**
- Consumes: existing `take_turn()`, `advance_turn()`, `SPEED_MULTIPLIERS`.
- Produces: `battle_controller.gd` — `var auto_enabled: bool = true`,
  `signal step_requested`, `@onready var auto_toggle_button: Button`,
  `@onready var step_button: Button`.

- [ ] **Step 1: Add the state and signal**

```gdscript
## True = existing always-on pacing (paused only by the speed multiplier).
## False = each turn pauses after resolving, awaiting a manual step.
var auto_enabled: bool = true

## Emitted when the player clicks "step forward" while auto is off.
signal step_requested
```

- [ ] **Step 2: Add the toggle handler**

```gdscript
func _on_auto_toggle_pressed() -> void:
	auto_enabled = not auto_enabled
	auto_toggle_button.text = "AUTO: %s" % ("ON" if auto_enabled else "OFF")
	speed_toggle_button.visible = auto_enabled
	step_button.visible = not auto_enabled
```

- [ ] **Step 3: Gate `take_turn()`'s pacing on the mode**

Locate the existing paced-entry loop (`scripts/battle_controller.gd`,
inside `take_turn()`):

```gdscript
		if entry.paced:
			await get_tree().create_timer(0.6).timeout
```

Leave that line as the auto-on behavior (per-entry pacing, matching what
exists today). After the loop, before `await advance_turn(actor)`, add
the manual-step gate at the turn boundary (matching the granularity
`StateProbe`'s own Step/Play/Reset already uses for mock fights — one
step per full turn, not per message):

```gdscript
	if not auto_enabled:
		await step_button.pressed
```

- [ ] **Step 4: Wire the buttons in `_ready()`**

```gdscript
	auto_toggle_button.pressed.connect(_on_auto_toggle_pressed)
	step_button.visible = false
```

- [ ] **Step 5: Add the two new buttons through the MCP toolkit**

Sibling of `SpeedToggleButton`: `AutoToggleButton` (text
`"AUTO: ON"`), and `StepButton` (text `"Step"`, initially hidden). Add
the corresponding `@onready` lines to `battle_controller.gd`.

- [ ] **Step 6: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty.

- [ ] **Step 7: Live verification**

`game_start`, reach a fight, screenshot to confirm `AUTO: ON` and the
speed control both show, `Step` is hidden. `click_node` the auto toggle,
screenshot again to confirm it now reads `AUTO: OFF`, `Step` shows, and
the speed control is hidden. `click_node` `Step` once, confirm exactly
one turn's worth of log lines appended (compare log line count before
and after via `execute_code` reading `get_node('/root/Battle/LogScroll/LogView').get_child_count()`)
and combat is paused again, not continuing on its own. `game_stop`.

- [ ] **Step 8: Commit**

```bash
git add scripts/battle_controller.gd scenes/battle.tscn
git commit -m "feat: Auto ON/OFF toggle for battle pacing"
```

---

## Phase C — Bracket screen

### Task 9: Bracket screen reskin

**Files:**
- Modify: `scripts/bracket/bracket_screen.gd`
- Modify: `scenes/battle.tscn` (`BracketScreen`)
- Modify: `scripts/tooltip_panel.gd` or `scripts/tooltip_layer.gd` (whichever renders the tooltip's background — read first to confirm which)

**Interfaces:**
- Consumes: `FramedPanel`, `Palette` (Tasks 1–2).
- Produces: nothing new.

- [ ] **Step 1: Remove the footer and subtitle**

Delete `BracketScreen/ContinueButton` — replaced by the reveal being
readable directly (already true per `DECISIONS.md`'s "results read off
the bracket, not the log" entry) plus a simple click-anywhere-to-dismiss
or a minimal single "Continue" text integrated into the panel itself.
Actually: keep `ContinueButton` (it's the only way to leave the scouting
screen) but remove any keyboard-hint row alongside it — confirm none
exists first (`grep -n "\[Z\]\|\[X\]\|\[ESC\]" scripts/bracket/bracket_screen.gd`,
expected: no matches, since this screen was never built with hint text).
If `TitleLabel`'s subtitle line exists (check current text for "Pick your
fighter..."), remove it — re-read `bracket_screen.gd`'s `setup()` first;
per the current implementation `TitleLabel.text` is already just
`"Choose your familiar"` / `"Round %d"` with no subtitle, so this step
may already be satisfied — confirm before assuming a change is needed.

- [ ] **Step 2: Frame the entrant list and detail panel**

Instance `FramedPanel` behind `Body/EntrantScroll` (`header_text =
"ENTRANTS"`) and behind `Body/DetailPanel` (`header_text = "DETAILS"`),
`border_color = Palette.GOLD_ACCENT` for both (neutral, since this
screen isn't player-vs-opponent framed).

- [ ] **Step 3: Restyle the scouting tooltip**

Read `scripts/tooltip_layer.gd`/`tooltip_panel.gd` to find the tooltip's
background node, and swap its current styling (a plain `Panel` or
`ColorRect`, based on this project's established tooltip pattern) for a
`FramedPanel` instance with no header. This is a shared component used
by every tooltip in the game (reward cards, status icons, bracket
entrants), so this one change updates all of them, not just the
bracket's.

- [ ] **Step 4: Parse check and screenshot**

Parse check. `game_start`, reach character select, screenshot, compare
against `assets/ui_mockup/bracket_mockup.png`'s panel framing (its
left-list/right-detail split already matches `BracketScreen`'s existing
`Body` layout). Hover an entrant, screenshot the tooltip to confirm the
new frame renders. `game_stop`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/bracket_screen.gd scenes/battle.tscn scripts/tooltip_layer.gd scripts/tooltip_panel.gd
git commit -m "feat: bracket screen reskin and framed tooltips"
```

---

## Phase D — Builder screen

### Task 10: Priority builder reskin

**Files:**
- Modify: `scenes/priority_builder/priority_builder.tscn`

**Interfaces:**
- Consumes: `FramedPanel`, `Palette` (Tasks 1–2).
- Produces: nothing new.

- [ ] **Step 1: Remove footer keyboard hints, if any**

`grep -n "\[Z\]\|\[X\]\|\[C\]\|\[ESC\]" scripts/priority_builder/priority_builder.gd`
— if any hint labels exist in the scene (check
`PriorityBuilder/Columns/BuildColumn/Header` for anything beyond
`Title`/`Spacer`/`AddSlotButton`/`ConfirmButton`), remove them. Per this
screen's current structure (confirmed via `scene_get_tree`), the header
row already holds exactly `Title`, `Spacer`, `AddSlotButton`,
`ConfirmButton` — no separate hint row exists, so this step is likely
already satisfied; confirm rather than assume.

- [ ] **Step 2: Frame the three columns**

Instance `FramedPanel` behind `Columns/LeftColumn` (`header_text =
"TECHNIQUES"`), behind `Columns/BuildColumn` (`header_text = "PRIORITY"`),
and behind `Columns/RightColumn` (`header_text = "CONDITIONS PALETTE"`),
each `border_color = Palette.GOLD_ACCENT`, matching the mockup's neutral
framing for this screen (no player/opponent split here).

- [ ] **Step 3: Parse check and screenshot**

Parse check. `game_start`, open the priority builder (character select →
a round win → Open Priority Builder), screenshot, compare against
`assets/ui_mockup/builder_mockup.png`'s three-panel framing (the
condition-editing widgets themselves are unchanged per spec §2 — only
the surrounding frame). `game_stop`.

- [ ] **Step 4: Commit**

```bash
git add scenes/priority_builder/priority_builder.tscn
git commit -m "feat: priority builder reskin"
```

---

## Phase E — Prefight screen

### Task 11: Round-name mapping

**Files:**
- Modify: `scripts/bracket/bracket.gd`
- Test: `scripts/tools/bracket_test.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Bracket.round_display_name(round_index: int) -> String`.

- [ ] **Step 1: Add the failing check**

Append `"round_display_name_maps_correctly"` to `EXPECTED_CHECKS`, add
`_check_round_display_name_maps_correctly()` to `_init()`, and add:

```gdscript
func _check_round_display_name_maps_correctly() -> void:
	_expect(Bracket.round_display_name(0) == "First Round", "round 0 should be First Round")
	_expect(Bracket.round_display_name(1) == "Quarterfinals", "round 1 should be Quarterfinals")
	_expect(Bracket.round_display_name(2) == "Semifinals", "round 2 should be Semifinals")
	_expect(Bracket.round_display_name(3) == "Final", "round 3 should be Final")
	_done("round_display_name_maps_correctly")
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about a nonexistent `round_display_name` method.

- [ ] **Step 3: Implement it**

Append to `scripts/bracket/bracket.gd`:

```gdscript
const ROUND_NAMES: Array[String] = ["First Round", "Quarterfinals", "Semifinals", "Final"]

## Tournament terminology for a 0-indexed round -- always 4 rounds
## (§4.7 of the design spec), so this is a fixed lookup, not derived from
## rounds.size() (which would be wrong mid-generation, before all 4 exist).
static func round_display_name(round_index: int) -> String:
	if round_index < 0 or round_index >= ROUND_NAMES.size():
		return "Round %d" % (round_index + 1)
	return ROUND_NAMES[round_index]
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|  - "
```

Expected: `ALL CHECKS PASSED (12/12)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/bracket.gd scripts/tools/bracket_test.gd
git commit -m "feat: bracket round display names (First Round/Quarterfinals/Semifinals/Final)"
```

---

### Task 12: Prefight screen reskin

**Files:**
- Modify: `scripts/battle_controller.gd`
- Modify: `scenes/battle.tscn` (`BeginCombatPanel`)

**Interfaces:**
- Consumes: `Bracket.round_display_name()` (Task 11), `FramedPanel`
  (Task 2).
- Produces: nothing new.

- [ ] **Step 1: Show the round name instead of nothing**

In `_wait_for_pre_fight_screen()` (`scripts/battle_controller.gd`), where
`begin_combat_message_label.text` is currently set to `"Ready to fight?"`,
change it to include the round:

```gdscript
	begin_combat_message_label.text = "%s — Ready to fight?" % Bracket.round_display_name(current_round)
```

- [ ] **Step 2: Frame the panel, with a round name that updates every round**

Instance `FramedPanel` behind `BeginCombatPanel`, named `Background`,
`header_text` left blank at instance-time in the editor (the round
changes every call, so a fixed editor-authored value would go stale).
Add `@onready var begin_combat_frame: FramedPanel =
$BeginCombatPanel/Background`, and set its `header_text` at runtime in
`_wait_for_pre_fight_screen()`, alongside the message label update from
Step 1:

```gdscript
	begin_combat_frame.header_text = Bracket.round_display_name(current_round)
```

- [ ] **Step 3: Parse check and screenshot**

Parse check. `game_start`, reach the pre-fight screen, screenshot,
confirm the round name shows and the panel is framed. Compare against
`assets/ui_mockup/prefight_mockup.png`'s panel framing (the flavor text
and "Season 3" header subtitle are intentionally not reproduced, per
your direction). `game_stop`.

- [ ] **Step 4: Commit**

```bash
git add scripts/battle_controller.gd scenes/battle.tscn
git commit -m "feat: prefight screen reskin with round name"
```

---

## Phase F — Stat screen

### Task 13: Techniques/passives display on the stat screen

**Files:**
- Modify: `scripts/battle_controller.gd`
- Modify: `scenes/battle.tscn` (`StatUpgradePanel`)

**Interfaces:**
- Consumes: `player_familiar_data.techniques`/`.passives` (existing).
- Produces: `battle_controller.gd` —
  `@onready var stat_technique_list: VBoxContainer`,
  `@onready var stat_passive_list: VBoxContainer`.

- [ ] **Step 1: Add the two list containers to the scene**

Through the MCP toolkit: add `TechniqueList` and `PassiveList`
(`VBoxContainer`s) as siblings of `RowsContainer` under
`StatUpgradePanel`, each preceded by a small `Label` header ("TECHNIQUES"
/ "PASSIVES"), matching how `BracketScreen`'s detail panel already lists
a familiar's techniques.

- [ ] **Step 2: Populate them in `populate_stat_upgrade_rows()`**

```gdscript
	for child in stat_technique_list.get_children():
		child.queue_free()
	for technique in player_familiar_data.techniques:
		var label := Label.new()
		label.text = technique.technique_name
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		stat_technique_list.add_child(label)

	for child in stat_passive_list.get_children():
		child.queue_free()
	for passive in player_familiar_data.passives:
		var label := Label.new()
		label.text = passive.passive_name
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		stat_passive_list.add_child(label)
```

Add this block right before `stat_upgrade_panel.visible = true` at the
end of the existing function.

- [ ] **Step 3: Parse check and screenshot**

Parse check. `game_start`, reach the stat screen (via a round win),
screenshot, confirm technique and passive names now list alongside the
stat rows. `game_stop`.

- [ ] **Step 4: Commit**

```bash
git add scripts/battle_controller.gd scenes/battle.tscn
git commit -m "feat: show techniques/passives on the stat upgrade screen"
```

---

### Task 14: Stat screen reskin

**Files:**
- Modify: `scenes/battle.tscn` (`StatUpgradePanel`)

**Interfaces:**
- Consumes: `FramedPanel`, `Palette` (Tasks 1–2).
- Produces: nothing new.

- [ ] **Step 1: Frame the panel and remove any hint text**

Instance `FramedPanel` behind `StatUpgradePanel`, `header_text = "CHOOSE
YOUR STAT UPGRADE"`. Confirm no keyboard-hint labels exist alongside
`ConfirmButton` (this screen's footer should end up as exactly one
button, "Confirm Upgrades" — rename `ConfirmButton`'s text if it
currently reads something else, e.g. "Confirm").

- [ ] **Step 2: Parse check and screenshot**

Parse check. `game_start`, reach the stat screen, screenshot, compare
against `assets/ui_mockup/stat_mockup.png`'s framing. `game_stop`.

- [ ] **Step 3: Commit**

```bash
git add scenes/battle.tscn
git commit -m "feat: stat screen reskin"
```

---

## Phase G — Reward screen

### Task 15: Next-opponent preview + bracket-preview popup

**Files:**
- Modify: `scripts/battle_controller.gd`
- Modify: `scenes/battle.tscn` (`RewardSelectPanel`)

**Interfaces:**
- Consumes: `enemy_familiar_data`, `bracket`, `current_round` (all
  already correctly assigned before `begin_reward_sequence()` runs — see
  design spec §4.9's verified note), `BracketScreen.setup(bracket,
  round_index, selectable)` (existing).
- Produces: `battle_controller.gd` —
  `@onready var next_opponent_panel: Button`,
  `func _on_next_opponent_panel_pressed() -> void`.

- [ ] **Step 1: Add the preview panel to the scene**

Through the MCP toolkit: add `NextOpponentPanel` (a `Button`, so it's
clickable) as a child of `RewardSelectPanel`, above `CardRow`. Its own
children: a small `TextureRect` (portrait) and `Label` (name), enough to
identify the opponent at a glance — full stats aren't needed here, the
scouting screen already shows those.

- [ ] **Step 2: Populate it in `begin_reward_sequence()`**

```gdscript
	next_opponent_panel.get_node("Portrait").texture = enemy_familiar_data.sprite
	next_opponent_panel.get_node("NameLabel").text = "Next: %s" % enemy_familiar_data.familiar_name
```

Add this near the top of `begin_reward_sequence()`, before the existing
panel-hiding lines.

- [ ] **Step 3: Wire the click to a read-only bracket preview**

```gdscript
func _on_next_opponent_panel_pressed() -> void:
	bracket_screen.setup(bracket, current_round, false)
	bracket_screen.visible = true
	await bracket_screen.dismissed
	bracket_screen.visible = false
```

Connect `next_opponent_panel.pressed.connect(_on_next_opponent_panel_pressed)`
in `_ready()`. This reuses `BracketScreen` exactly as the between-round
scouting screen already does (`selectable = false`), just reachable from
a different place.

- [ ] **Step 4: Parse check and live verification**

Parse check. `game_start`, reach a reward screen, screenshot to confirm
the next-opponent panel shows the correct portrait/name. `click_node` it,
screenshot to confirm the bracket screen appears read-only (no Select
button), `click_node` `ContinueButton` to dismiss, screenshot to confirm
it returns to the reward screen (not advancing past it). `game_stop`.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle_controller.gd scenes/battle.tscn
git commit -m "feat: next-opponent preview and bracket-preview popup on the reward screen"
```

---

### Task 16: "View my build" popup

**Files:**
- Modify: `scripts/battle_controller.gd`
- Modify: `scenes/battle.tscn` (`RewardSelectPanel/ActionRow`, a new popup panel)

**Interfaces:**
- Consumes: `player_familiar_data` (existing), the list-building pattern
  from Task 13 (technique/passive name lists).
- Produces: `battle_controller.gd` —
  `@onready var build_view_panel: VBoxContainer`,
  `@onready var build_view_button: Button`,
  `func _on_build_view_pressed() -> void`,
  `func _on_build_view_closed_pressed() -> void`.

- [ ] **Step 1: Add the popup panel and its trigger button**

Through the MCP toolkit: add `BuildViewPanel` (a `VBoxContainer`, hidden
by default, full-rect like the other full-screen panels) as a sibling of
`RewardSelectPanel`, containing a stats summary label, a
`TechniqueList`/`PassiveList` pair (same shape as Task 13's), and a
`CloseButton`. Add `ViewBuildButton` to `RewardSelectPanel/ActionRow`.

- [ ] **Step 2: Wire it**

```gdscript
func _on_build_view_pressed() -> void:
	build_view_stats_label.text = "HP %d   Power %d   Defense %d   Speed %d   Focus %d" % [
		player_familiar_data.max_hp, player_familiar_data.power,
		player_familiar_data.defense, player_familiar_data.speed, player_familiar_data.focus
	]
	for child in build_view_technique_list.get_children():
		child.queue_free()
	for technique in player_familiar_data.techniques:
		var label := Label.new()
		label.text = technique.technique_name
		build_view_technique_list.add_child(label)
	for child in build_view_passive_list.get_children():
		child.queue_free()
	for passive in player_familiar_data.passives:
		var label := Label.new()
		label.text = passive.passive_name
		build_view_passive_list.add_child(label)
	build_view_panel.visible = true

func _on_build_view_closed_pressed() -> void:
	build_view_panel.visible = false
```

Connect both buttons in `_ready()`.

- [ ] **Step 3: Rename the reward screen's remaining footer button**

`RewardSelectPanel/ActionRow/NextRoundButton`'s text becomes "Confirm
Selection" (its handler, `_on_next_round_pressed()`, is unchanged).
Remove `SkipButton` from the footer only if it duplicates
`ViewBuildButton`'s row awkwardly — otherwise leave it (Skip is real,
existing functionality, not a keyboard hint).

- [ ] **Step 4: Parse check and live verification**

Parse check. `game_start`, reach a reward screen, `click_node`
`ViewBuildButton`, screenshot to confirm the popup shows current
techniques/passives/stats, `click_node` its close button, screenshot to
confirm it returns to the reward screen. `game_stop`.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle_controller.gd scenes/battle.tscn
git commit -m "feat: view-current-build popup on the reward screen"
```

---

### Task 17: Reward screen reskin

**Files:**
- Modify: `scenes/battle.tscn` (`RewardSelectPanel`)

**Interfaces:**
- Consumes: `FramedPanel`, `Palette` (Tasks 1–2).
- Produces: nothing new.

- [ ] **Step 1: Frame the panel and each reward column**

Instance `FramedPanel` behind `RewardSelectPanel` itself, and behind each
of `CardRow/SpeciesColumn`, `RunColumn`, `PivotColumn`, `header_text` =
"SPECIES" / "RUN" / "WILDCARD" respectively, `border_color =
Palette.GOLD_ACCENT`.

- [ ] **Step 2: Parse check and screenshot**

Parse check. `game_start`, reach a reward screen, screenshot, compare
against `assets/ui_mockup/reward_mockup.png`'s card framing (no gold/fame
line, per spec §2). `game_stop`.

- [ ] **Step 3: Commit**

```bash
git add scenes/battle.tscn
git commit -m "feat: reward screen reskin"
```

---

## Final validation

- [ ] **Full regression pass**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|  - "
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/balance_test.gd 2>&1 | grep -A 19 "=== Summary ==="
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: `ALL CHECKS PASSED (12/12)`, balance numbers matching the last
recorded baseline, empty parse-check output. Nothing in this whole pass
should have touched combat or bracket logic.

- [ ] **Full playthrough screenshot pass**

Play (or force through, per the Global Constraints recipe) one complete
run — character select, a battle with Auto toggled both ways, a reward
screen using both new popups, a stat screen, the priority builder, a
scouting screen, Game Over, Restart — screenshotting each. Confirm every
screen shows the title banner, framed panels, and the shared theme's
button styling consistently.

