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
const CORNER_CUT: float = 13.0
const RIVET_SIZE: float = 9.0
const RIVET_CORNER_RADIUS: int = 2
const RIVET_OFFSET: float = CORNER_CUT / 2.0
const HEADER_HEIGHT: float = 28.0
const HEADER_TAB_PADDING: float = 15.0
const HEADER_TEXT_INSET: float = 10.0

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
		add_child(_header_label)

	_header_label.add_theme_color_override("font_color", border_color)
	_header_label.text = header_text
	_header_label.position = Vector2(CORNER_CUT + HEADER_TAB_PADDING + HEADER_TEXT_INSET, -HEADER_HEIGHT)
	_header_label.size = Vector2(size.x, HEADER_HEIGHT)
	_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _draw() -> void:
	# Skip rectangles with no positive area while layout is pending. Small
	# positive rectangles still draw: _outline_points() clamps the corner cut
	# to half the smaller dimension so notch points cannot cross.
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var rect := Rect2(Vector2.ZERO, size)
	var has_header: bool = header_text != ""
	var header_width: float = 0.0
	if has_header and _header_label != null:
		header_width = _header_label.get_combined_minimum_size().x + HEADER_TEXT_INSET * 2

	var points: Array[Vector2] = _outline_points(rect, has_header, header_width)

	draw_colored_polygon(points, fill_color)

	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, border_color, BORDER_WIDTH)

	# Signed per-corner offsets (not "toward rect center") so the rivet lands
	# centered on the notch's 45-degree cut line regardless of the panel's
	# aspect ratio -- insetting toward center skews mostly sideways on a
	# wide/tall panel and misses the notch entirely.
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]
	var corner_signs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	var rivet_style := StyleBoxFlat.new()
	rivet_style.bg_color = border_color
	rivet_style.set_corner_radius_all(RIVET_CORNER_RADIUS)
	for i in corners.size():
		var rivet_center := corners[i] + corner_signs[i] * RIVET_OFFSET
		var rivet_rect := Rect2(rivet_center - Vector2.ONE * RIVET_SIZE / 2.0, Vector2.ONE * RIVET_SIZE)
		draw_style_box(rivet_style, rivet_rect)

## The panel's outline as a notched-corner polygon, with an optional
## rectangular tab cut upward out of the top edge (left-aligned, just
## inside the top-left notch) for the header label to sit in.
func _outline_points(rect: Rect2, has_header: bool, header_width: float) -> Array[Vector2]:
	# Clamped so a rect smaller than 2*CORNER_CUT in either dimension can't
	# push the notch points past each other into a self-intersecting polygon.
	var c := minf(CORNER_CUT, minf(rect.size.x, rect.size.y) / 2.0)
	var points: Array[Vector2] = [
		Vector2(rect.position.x, rect.position.y + c),
		Vector2(rect.position.x + c, rect.position.y),
	]

	if has_header:
		var tab_left: float = rect.position.x + c + HEADER_TAB_PADDING
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
