class_name ParticleFx
extends Node2D
## Pooled GPUParticles2D pixel-dust bursts (the sparks of a painted cell).
##
## Dragging paints ~30 cells/second; instancing and freeing a particle node per cell
## would stutter on low-end phones. Instead a fixed pool is created once and re-fired
## round-robin. Particles are small *squares* (not soft dots) so they read as shards
## of the painted pixel.
##
## Pool size matters: modulate is per emitter, so an emitter must not be recycled while
## its particles are still alive (they would change color mid-flight). 28 emitters x
## 0.45 s lifetime covers ~60 bursts/second. The screen-wide confetti is ConfettiOverlay's job.

const SPARK_POOL := 28
const SPARK_LIFETIME := 0.45

var _sparks: Array[GPUParticles2D] = []
var _next_spark := 0
var _square: ImageTexture


func _init() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_square = ImageTexture.create_from_image(img)

	var spark_mat := _make_spark_material()
	for i in SPARK_POOL:
		var p := _make_emitter(spark_mat, 9, SPARK_LIFETIME)
		add_child(p)
		_sparks.append(p)


## One pixel-dust burst at `pos` (this node's local space), tinted `color`.
## `size` scales with the canvas zoom so shards stay proportional to the cell.
func burst(pos: Vector2, color: Color, size: float = 1.0) -> void:
	var p := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	p.position = pos
	p.scale = Vector2.ONE * size
	p.modulate = color.lightened(0.15)
	p.restart()
	p.emitting = true


func _make_emitter(mat: ParticleProcessMaterial, amount: int, lifetime: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = _square
	p.process_material = mat
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.96
	p.local_coords = false  # shards keep flying where they were born, even if the canvas pans
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


func _make_spark_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 3.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 110.0
	m.initial_velocity_max = 300.0
	m.gravity = Vector3(0, 520, 0)
	m.damping_min = 60.0
	m.damping_max = 140.0
	m.scale_min = 1.1
	m.scale_max = 2.6
	m.scale_curve = _curve_texture([Vector2(0, 1), Vector2(0.65, 0.8), Vector2(1, 0)])
	m.color_ramp = _fade_out_ramp()
	return m


func _fade_out_ramp(fade_start: float = 0.55) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, fade_start, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve_texture(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t
