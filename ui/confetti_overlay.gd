class_name ConfettiOverlay
extends Control
## The 100% celebration: GPUParticles2D confetti raining over the WHOLE screen plus golden
## sparkles twinkling around the picture. A fixed pool of one-shot emitters is created once and
## re-fired, so celebrating costs nothing until it happens. Mouse-transparent.

const CONFETTI_COLORS: Array[Color] = [
	AppTheme.PINK, AppTheme.ORANGE, AppTheme.YELLOW, AppTheme.GREEN,
	AppTheme.CYAN, AppTheme.BLUE, AppTheme.PURPLE, AppTheme.RED,
]
const WAVES := 3                ## confetti emitters in the pool = waves per celebration
const SPARKLE_EMITTERS := 3

var _confetti: Array[GPUParticles2D] = []
var _sparkles: Array[GPUParticles2D] = []
var _strip: ImageTexture
var _star: ImageTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip = _make_strip_texture()
	_star = _make_star_texture()

	var confetti_mat := _make_confetti_material()
	for i in WAVES:
		var p := _make_emitter(confetti_mat.duplicate(), _strip, 70, 3.4)
		p.explosiveness = 0.55
		add_child(p)
		_confetti.append(p)

	var sparkle_mat := _make_sparkle_material()
	for i in SPARKLE_EMITTERS:
		var p := _make_emitter(sparkle_mat.duplicate(), _star, 26, 1.3)
		p.explosiveness = 0.25
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = cm
		add_child(p)
		_sparkles.append(p)


## Fires the whole show: three waves of confetti and a few rounds of sparkles.
func celebrate() -> void:
	if _confetti.is_empty():
		return
	var w := size.x
	var h := size.y
	for k in WAVES:
		var p := _confetti[k]
		p.position = Vector2(w * 0.5, -30.0)
		(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(w * 0.5, 4.0, 1.0)
		get_tree().create_timer(k * 0.38).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.restart()
				p.emitting = true)
	for k in SPARKLE_EMITTERS:
		var p := _sparkles[k]
		p.position = Vector2(w * (0.28 + 0.22 * k), h * (0.3 + 0.12 * (k % 2)))
		(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(w * 0.22, h * 0.14, 1.0)
		get_tree().create_timer(0.2 + k * 0.45).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.restart()
				p.emitting = true)


func _make_emitter(mat: ParticleProcessMaterial, tex: Texture2D, amount: int, lifetime: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.process_material = mat
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.emitting = false
	p.local_coords = false
	return p


func _make_confetti_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(540, 4, 1)
	m.direction = Vector3(0, 1, 0)
	m.spread = 28.0
	m.initial_velocity_min = 380.0
	m.initial_velocity_max = 900.0
	m.gravity = Vector3(0, 620, 0)
	m.damping_min = 25.0
	m.damping_max = 70.0
	m.scale_min = 0.8
	m.scale_max = 1.7
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -420.0
	m.angular_velocity_max = 420.0
	m.color_initial_ramp = _palette_ramp(CONFETTI_COLORS)
	m.color_ramp = _fade_out_ramp(0.72)
	return m


func _make_sparkle_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(240, 200, 1)
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 40.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.angle_min = -25.0
	m.angle_max = 25.0
	m.scale_min = 0.5
	m.scale_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	m.color_initial_ramp = _palette_ramp([Color("fff3a0"), Color("ffffff"), Color("ffd23f"), Color("ffc2e6")])
	return m


## A GradientTexture1D with hard stops: the particle system picks one color of it at random.
func _palette_ramp(colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size()))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _fade_out_ramp(fade_start: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, fade_start, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A small rounded paper strip.
func _make_strip_texture() -> ImageTexture:
	var w := 18
	var h := 10
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := maxf(absf(x - (w - 1) * 0.5) - (w * 0.5 - 3.0), 0.0)
			var dy := maxf(absf(y - (h - 1) * 0.5) - (h * 0.5 - 3.0), 0.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.6 - sqrt(dx * dx + dy * dy) * 0.9, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Four-point sparkle: |x|^0.55 + |y|^0.55 <= 1, with a soft edge.
func _make_star_texture() -> ImageTexture:
	var n := 56
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var px := absf((x + 0.5) / n * 2.0 - 1.0)
			var py := absf((y + 0.5) / n * 2.0 - 1.0)
			var d := pow(px, 0.55) + pow(py, 0.55)
			var a := clampf((1.0 - d) * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	return tex
