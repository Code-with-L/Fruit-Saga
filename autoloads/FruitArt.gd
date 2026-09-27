extends Node
## Procedural vector art for every fruit tier — no image assets in the project.
##
## Each tier is painted ONCE at startup into an ImageTexture (via an MSAA'd
## SubViewport) and cached. A live fruit then costs a single draw_texture_rect
## instead of ~20 draw_* calls, which is what makes fully hand-drawn fruit
## affordable on ARM64 mobile. The painting code below is plain vector art:
## shaded spheres, quadratic beziers, ellipses and clipped polylines.

## Transparent margin baked around each fruit, room for outlines and glows.
const PAD := 10.0
## Bake at 2x and let the GPU downscale, so fruit stay crisp on high-DPI screens.
const BAKE_SCALE := 2.0

static var PALETTE := {
	0: {
		"base": Color("#e1344a"), "light": Color("#ff8492"), "dark": Color("#8f0d20"),
		"stem": Color("#4e7a2e"), "leaf": Color("#6fa83b"),
	},
	1: {
		"base": Color("#ef4a61"), "light": Color("#ff95a1"), "dark": Color("#a81f33"),
		"leaf": Color("#5fa03a"), "accent": Color("#ffe6a3"),
	},
	2: {
		"base": Color("#9b5bc9"), "light": Color("#c68bee"), "dark": Color("#5f2b8a"),
		"stem": Color("#5a7a2a"), "leaf": Color("#6fa83b"),
	},
	3: {
		"base": Color("#f28c1a"), "light": Color("#ffb85c"), "dark": Color("#b45c06"),
		"stem": Color("#6b4a22"), "leaf": Color("#4e8a2e"), "accent": Color("#d1740f"),
	},
	4: {
		"base": Color("#d62b33"), "light": Color("#ff7a63"), "dark": Color("#8e111d"),
		"stem": Color("#6b4a22"), "leaf": Color("#4e8a2e"),
	},
	5: {
		"base": Color("#b8d43a"), "light": Color("#dced7a"), "dark": Color("#7f9813"),
		"stem": Color("#7a5a2a"),
	},
	6: {
		"base": Color("#fab48f"), "light": Color("#ffd9bd"), "dark": Color("#d97a4c"),
		"leaf": Color("#5c9a38"), "accent": Color("#e88a5c"),
	},
	7: {
		"base": Color("#f2c21a"), "light": Color("#ffe066"), "dark": Color("#a8810a"),
		"leaf": Color("#4e9a3a"), "accent": Color("#d8a80f"),
	},
	8: {
		"base": Color("#9ed46a"), "light": Color("#c8efa2"), "dark": Color("#6a9c3f"),
		"stem": Color("#7a6a2a"), "accent": Color("#7fb04f"),
	},
	9: {
		"base": Color("#2e8b4a"), "light": Color("#57b96f"), "dark": Color("#175a2c"),
		"stem": Color("#6a5a2a"), "accent": Color("#0f4423"),
	},
}

var _textures: Array[Texture2D] = []
var _half_sizes: Array[float] = []


func _ready() -> void:
	_bake_all()


## World-space half-extent of a baked texture (transparent margin included).
func get_half_size(tier_id: int) -> float:
	if tier_id < 0 or tier_id >= _half_sizes.size():
		return 0.0
	return _half_sizes[tier_id]


func get_texture(tier_id: int) -> Texture2D:
	if tier_id < 0 or tier_id >= _textures.size():
		return null
	return _textures[tier_id]


func get_palette(tier_id: int) -> Dictionary:
	return PALETTE.get(tier_id, PALETTE[0])


# --- baking -------------------------------------------------------------

func _bake_all() -> void:
	_textures.clear()
	_half_sizes.clear()
	for tier in FruitDatabase.tiers:
		var half: float = tier.radius + PAD
		var tex := await _bake(tier.tier_id, half)
		_textures.append(tex)
		_half_sizes.append(half)


func _bake(tier_id: int, half: float) -> Texture2D:
	var side: int = int(round(half * 2.0 * BAKE_SCALE))
	var vp := SubViewport.new()
	vp.size = Vector2i(side, side)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR

	var painter := FruitPainter.new()
	painter.tier_id = tier_id
	painter.radius = FruitDatabase.get_tier(tier_id).radius
	painter.position = Vector2(side, side) * 0.5
	vp.add_child(painter)
	add_child(vp)

	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()

	if img == null:
		push_warning("FruitArt: failed to bake tier %d" % tier_id)
		return null
	return ImageTexture.create_from_image(img)


# --- vector painting ----------------------------------------------------

## Paints tier `tier_id` centred on the origin with the given radius.
static func paint(ci: CanvasItem, tier_id: int, r: float) -> void:
	match tier_id:
		0: _paint_cherry(ci, r)
		1: _paint_strawberry(ci, r)
		2: _paint_grape(ci, r)
		3: _paint_orange(ci, r)
		4: _paint_apple(ci, r)
		5: _paint_pear(ci, r)
		6: _paint_peach(ci, r)
		7: _paint_pineapple(ci, r)
		8: _paint_melon(ci, r)
		9: _paint_watermelon(ci, r)
		_: _sphere(ci, Vector2.ZERO, r, PALETTE[0]["base"], PALETTE[0]["light"], PALETTE[0]["dark"])


# Cherry: two joined spheres on curved stems with a leaf.
static func _paint_cherry(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[0]
	var join := Vector2(0.05 * r, -1.02 * r)
	var always := func(_pt: Vector2) -> bool: return true
	_polyline_inside(ci, _bezier(Vector2(-0.42 * r, -0.42 * r), Vector2(-0.34 * r, -0.85 * r), join, 12), always, p["stem"], maxf(1.5, r * 0.09))
	_polyline_inside(ci, _bezier(Vector2(0.46 * r, -0.30 * r), Vector2(0.32 * r, -0.80 * r), join, 12), always, p["stem"], maxf(1.5, r * 0.09))
	_leaf(ci, join + Vector2(0.02 * r, 0.06 * r), -0.45, 0.72 * r, 0.17 * r, p["leaf"], p["stem"])
	_sphere(ci, Vector2(-0.44 * r, 0.22 * r), 0.60 * r, p["base"], p["light"], p["dark"])
	_sphere(ci, Vector2(0.46 * r, 0.34 * r), 0.54 * r, p["base"], p["light"], p["dark"])


# Strawberry: bezier heart-cone, seeded, leafy crown.
static func _paint_strawberry(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[1]
	var body := PackedVector2Array()
	body.append_array(_bezier(Vector2(0.0, -0.90 * r), Vector2(0.58 * r, -1.02 * r), Vector2(0.98 * r, -0.30 * r), 14))
	body.append_array(_bezier(Vector2(0.98 * r, -0.30 * r), Vector2(0.84 * r, 0.60 * r), Vector2(0.0, 1.06 * r), 14))
	body.append_array(_bezier(Vector2(0.0, 1.06 * r), Vector2(-0.84 * r, 0.60 * r), Vector2(-0.98 * r, -0.30 * r), 14))
	body.append_array(_bezier(Vector2(-0.98 * r, -0.30 * r), Vector2(-0.58 * r, -1.02 * r), Vector2(0.0, -0.90 * r), 14))
	ci.draw_colored_polygon(body, p["base"])
	ci.draw_colored_polygon(_scaled(body, 0.74), Color(p["light"], 0.45))
	ci.draw_polyline(body + PackedVector2Array([body[0]]), p["dark"], max(1.2, r * 0.07), true)
	for i in 7:
		var a := -PI * 0.5 + (float(i) - 3.0) * 0.30
		ci.draw_circle(Vector2(cos(a), sin(a) * 1.1) * 0.52 * r, max(1.0, r * 0.055), p["accent"])
	for i in 7:
		var t := -0.55 + float(i) * 0.18
		_leaf(ci, Vector2(t * 0.9 * r, -0.86 * r), -PI * 0.5 + t * 0.5, 0.46 * r, 0.13 * r, p["leaf"], p["dark"])
	ci.draw_circle(Vector2(-0.30 * r, -0.18 * r), 0.13 * r, Color(1, 1, 1, 0.45))


# Grape: a cluster of small shaded berries.
static func _paint_grape(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[2]
	var berry := 0.34 * r
	var spots := PackedVector2Array([
		Vector2(0.0, -0.52),
		Vector2(-0.36, -0.14), Vector2(0.36, -0.14),
		Vector2(-0.56, 0.30), Vector2(0.0, 0.30), Vector2(0.56, 0.30),
		Vector2(-0.34, 0.74), Vector2(0.34, 0.74),
		Vector2(0.0, 1.02),
	])
	ci.draw_line(Vector2(0.0, -0.86 * r), Vector2(0.06 * r, -1.18 * r), p["stem"], max(1.5, r * 0.09), true)
	_leaf(ci, Vector2(0.08 * r, -1.06 * r), -0.25, 0.62 * r, 0.16 * r, p["leaf"], p["stem"])
	for i in range(spots.size() - 1, -1, -1):
		var c: Vector2 = spots[i] * r
		_sphere(ci, c, berry, p["base"], p["light"], p["dark"])


# Orange: peeled sphere with dimpled rind, stem and leaf.
static func _paint_orange(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[3]
	_sphere(ci, Vector2.ZERO, r, p["base"], p["light"], p["dark"])
	for i in 26:
		var a := float(i) * 2.399963
		var d := sqrt((float(i) + 0.5) / 26.0) * 0.86
		ci.draw_circle(Vector2(cos(a), sin(a)) * d * r, max(0.8, r * 0.035), Color(p["accent"], 0.75))
	ci.draw_line(Vector2(0.0, -r * 0.96), Vector2(0.02 * r, -1.24 * r), p["stem"], max(1.5, r * 0.10), true)
	_leaf(ci, Vector2(0.03 * r, -1.10 * r), -0.2, 0.66 * r, 0.17 * r, p["leaf"], p["stem"])


# Apple: shouldered sphere with a top dimple.
static func _paint_apple(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[4]
	ci.draw_colored_polygon(_scaled(_apple_outline(r), 1.0), p["base"])
	ci.draw_colored_polygon(_scaled(_apple_outline(r), 0.76), Color(p["light"], 0.42))
	ci.draw_polyline(_apple_outline(r) + PackedVector2Array([_apple_outline(r)[0]]), p["dark"], max(1.2, r * 0.06), true)
	ci.draw_circle(Vector2(0.0, -0.80 * r), 0.20 * r, Color(p["dark"], 0.55))
	ci.draw_line(Vector2(0.0, -0.86 * r), Vector2(0.10 * r, -1.30 * r), p["stem"], max(1.5, r * 0.10), true)
	_leaf(ci, Vector2(0.08 * r, -1.16 * r), -0.35, 0.70 * r, 0.18 * r, p["leaf"], p["stem"])
	ci.draw_colored_polygon(_scaled(_leaf_points(Vector2(-0.42 * r, -0.30 * r), -0.7, 0.40 * r, 0.11 * r), 1.0), Color(1, 1, 1, 0.40))


# Pear: big bottom lobe, narrow neck, top lobe.
static func _paint_pear(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[5]
	ci.draw_colored_polygon(_pear_outline(r), p["base"])
	ci.draw_colored_polygon(_scaled(_pear_outline(r), 0.78), Color(p["light"], 0.40))
	ci.draw_polyline(_pear_outline(r) + PackedVector2Array([_pear_outline(r)[0]]), p["dark"], max(1.2, r * 0.06), true)
	ci.draw_line(Vector2(0.0, -0.92 * r), Vector2(0.14 * r, -1.30 * r), p["stem"], max(1.5, r * 0.10), true)
	ci.draw_circle(Vector2(-0.34 * r, 0.22 * r), 0.15 * r, Color(1, 1, 1, 0.38))


# Peach: sphere with a vertical cleft, fuzz and a leaf.
static func _paint_peach(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[6]
	_sphere(ci, Vector2.ZERO, r, p["base"], p["light"], p["dark"])
	_polyline_inside(ci, _bezier(Vector2(-0.10 * r, -0.98 * r), Vector2(0.16 * r, 0.0), Vector2(-0.10 * r, 0.98 * r), 16), _inside_circle(r * 0.99), Color(p["accent"], 0.8), max(1.2, r * 0.07))
	_polyline_inside(ci, _bezier(Vector2(0.34 * r, -0.88 * r), Vector2(0.46 * r, 0.0), Vector2(0.34 * r, 0.88 * r), 16), _inside_circle(r * 0.99), Color(p["accent"], 0.45), max(1.0, r * 0.05))
	for i in 12:
		var a := float(i) * 2.399963
		ci.draw_circle(Vector2(cos(a), sin(a)) * 0.9 * r, max(0.7, r * 0.022), Color(1, 1, 1, 0.22))
	ci.draw_line(Vector2(0.0, -0.94 * r), Vector2(0.05 * r, -1.26 * r), p["leaf"], max(1.5, r * 0.09), true)
	_leaf(ci, Vector2(0.06 * r, -1.14 * r), -0.3, 0.62 * r, 0.16 * r, p["leaf"], p["accent"])


# Pineapple: crosshatched body plus a spiky crown.
static func _paint_pineapple(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[7]
	var rx := 0.78 * r
	var ry := 1.0 * r
	ci.draw_colored_polygon(_ellipse_points(rx, ry, 40), p["base"])
	ci.draw_colored_polygon(_scaled(_ellipse_points(rx, ry, 40), 0.8), Color(p["light"], 0.35))
	var inside := func(pt: Vector2) -> bool: return (pt.x / rx) ** 2 + (pt.y / ry) ** 2 <= 0.97
	for dir in [PI * 0.25, -PI * 0.25]:
		for i in range(-8, 9):
			var off := Vector2(-sin(dir), cos(dir)) * float(i) * 0.30 * r
			var span := Vector2(cos(dir), sin(dir)) * 1.6 * r
			_polyline_inside(ci, PackedVector2Array([off - span, off + span]), inside, Color(p["accent"], 0.75), max(1.0, r * 0.055))
	ci.draw_polyline(_ellipse_points(rx, ry, 40) + PackedVector2Array([Vector2(rx, 0)]), p["dark"], max(1.2, r * 0.06), true)
	for i in 7:
		var a := -PI * 0.5 + (float(i) - 3.0) * 0.30
		_leaf(ci, Vector2(0.0, -0.92 * r), a, 0.78 * r, 0.15 * r, p["leaf"], p["dark"])


# Melon: pale sphere with wide soft ribs and a stem scar.
static func _paint_melon(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[8]
	_sphere(ci, Vector2.ZERO, r, p["base"], p["light"], p["dark"])
	for i in 7:
		var u := -0.86 + float(i) * (1.72 / 6.0)
		var half := sqrt(max(0.0, 1.0 - u * u)) * 0.99
		var x := u * r
		_polyline_inside(ci, _bezier(Vector2(x, -half * r), Vector2(x + 0.16 * r, 0.0), Vector2(x, half * r), 14), _inside_circle(r * 0.99), Color(p["accent"], 0.62), max(1.2, r * 0.10))
	ci.draw_line(Vector2(0.0, -r * 0.95), Vector2(0.04 * r, -1.18 * r), p["stem"], max(1.5, r * 0.10), true)


# Watermelon: dark rind with wavy stripes.
static func _paint_watermelon(ci: CanvasItem, r: float) -> void:
	var p := PALETTE[9]
	_sphere(ci, Vector2.ZERO, r, p["base"], p["light"], p["dark"])
	for i in 7:
		var u := -0.84 + float(i) * (1.68 / 6.0)
		var half := sqrt(max(0.0, 1.0 - u * u)) * 0.99
		var x := u * r
		_polyline_inside(ci, _bezier(Vector2(x, -half * r), Vector2(x + 0.22 * r, 0.0), Vector2(x, half * r), 16), _inside_circle(r * 0.99), Color(p["accent"], 0.85), max(1.4, r * 0.13))
	ci.draw_line(Vector2(0.0, -r * 0.95), Vector2(0.05 * r, -1.16 * r), p["stem"], max(1.5, r * 0.10), true)


# --- primitives ---------------------------------------------------------

## A lit sphere: base disc, warm top-left bloom, cool bottom-right falloff,
## dark rim and a specular dot. Every fruit body is built from this.
static func _sphere(ci: CanvasItem, c: Vector2, r: float, base: Color, light: Color, dark: Color) -> void:
	ci.draw_circle(c, r, base)
	ci.draw_circle(c + Vector2(-0.26 * r, -0.28 * r), r * 0.74, Color(light, 0.55))
	ci.draw_circle(c + Vector2(0.28 * r, 0.32 * r), r * 0.80, Color(dark, 0.30))
	ci.draw_arc(c, r * 0.97, 0.0, TAU, 44, dark, max(1.0, r * 0.07), true)
	ci.draw_circle(c + Vector2(-0.34 * r, -0.40 * r), r * 0.19, Color(1, 1, 1, 0.50))


static func _ellipse_points(rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		pts.append(p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t))
	return pts


static func _scaled(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * f)
	return out


## Draws a polyline but only the runs that satisfy `inside` — used to keep
## stripes and crosshatch from spilling outside the fruit silhouette.
static func _polyline_inside(ci: CanvasItem, pts: PackedVector2Array, inside: Callable, color: Color, width: float) -> void:
	var run := PackedVector2Array()
	for p in pts:
		if inside.call(p):
			run.append(p)
		else:
			if run.size() > 1:
				ci.draw_polyline(run, color, width, true)
			run = PackedVector2Array()
	if run.size() > 1:
		ci.draw_polyline(run, color, width, true)


static func _inside_circle(radius: float) -> Callable:
	return func(p: Vector2) -> bool: return p.length_squared() <= radius * radius


## Pointed two-bezier leaf, with a centre vein.
static func _leaf_points(base: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var dir := Vector2.RIGHT.rotated(angle)
	var n := Vector2(-dir.y, dir.x)
	var tip := base + dir * length
	var pts := _bezier(base, base + dir * length * 0.45 + n * width, tip, 10)
	pts.append_array(_bezier(tip, base + dir * length * 0.45 - n * width, base, 10))
	return pts


static func _leaf(ci: CanvasItem, base: Vector2, angle: float, length: float, width: float, color: Color, vein: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var n := Vector2(-dir.y, dir.x)
	var tip := base + dir * length
	ci.draw_colored_polygon(_leaf_points(base, angle, length, width), color)
	ci.draw_polyline(_bezier(base, base + dir * length * 0.5 + n * width * 0.18, tip, 10), vein, max(1.0, length * 0.055), true)


static func _apple_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append_array(_bezier(Vector2(0.0, -0.74 * r), Vector2(0.52 * r, -1.10 * r), Vector2(1.0, -0.34 * r), 14))
	pts.append_array(_bezier(Vector2(1.0, -0.34 * r), Vector2(1.02 * r, 0.66 * r), Vector2(0.0, 1.02 * r), 16))
	pts.append_array(_bezier(Vector2(0.0, 1.02 * r), Vector2(-1.02 * r, 0.66 * r), Vector2(-1.0, -0.34 * r), 16))
	pts.append_array(_bezier(Vector2(-1.0, -0.34 * r), Vector2(-0.52 * r, -1.10 * r), Vector2(0.0, -0.74 * r), 14))
	return pts


static func _pear_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append_array(_bezier(Vector2(0.0, -0.90 * r), Vector2(0.46 * r, -0.88 * r), Vector2(0.58 * r, -0.20 * r), 12))
	pts.append_array(_bezier(Vector2(0.58 * r, -0.20 * r), Vector2(0.66 * r, 0.22 * r), Vector2(0.96 * r, 0.52 * r), 12))
	pts.append_array(_bezier(Vector2(0.96 * r, 0.52 * r), Vector2(0.72 * r, 1.06 * r), Vector2(0.0, 1.04 * r), 14))
	pts.append_array(_bezier(Vector2(0.0, 1.04 * r), Vector2(-0.72 * r, 1.06 * r), Vector2(-0.96 * r, 0.52 * r), 14))
	pts.append_array(_bezier(Vector2(-0.96 * r, 0.52 * r), Vector2(-0.66 * r, 0.22 * r), Vector2(-0.58 * r, -0.20 * r), 12))
	pts.append_array(_bezier(Vector2(-0.58 * r, -0.20 * r), Vector2(-0.46 * r, -0.88 * r), Vector2(0.0, -0.90 * r), 12))
	return pts
