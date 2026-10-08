class_name PaperBackground
extends Control
## Cream paper behind the whole game: a vertical gradient with a sprinkle of faint pixel stars
## (see the top of the reference). Drawn once and only redrawn on resize, so it costs nothing
## per frame (the old animated aurora re-rendered a SubViewport every frame).

const STAR_COUNT := 26

var _stars: Array[Vector3] = []   ## x, y in 0..1 and a size factor


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # NOT set_anchors_preset: that keeps the old (0) size
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.62, rng.randf_range(0.5, 1.0)))
	resized.connect(queue_redraw)


func _draw() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([AppTheme.BG_TOP, AppTheme.BG_BOTTOM])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	for s in _stars:
		var p := Vector2(s.x * size.x, s.y * size.y)
		Icons.star(self, p, 11.0 + 15.0 * s.z, Color(0.93, 0.85, 0.62, 0.45))
