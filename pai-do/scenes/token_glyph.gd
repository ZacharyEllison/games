@tool
class_name TokenGlyph
extends Control

const CANON_FLOWER := preload("res://scenes/assets/extracted_tiles/canon_flower.svg")
const CANON_WHEEL := preload("res://scenes/assets/extracted_tiles/canon_wheel.svg")
const CANON_BELL := preload("res://scenes/assets/extracted_tiles/canon_bell.svg")
const CANON_BLOSSOM := preload("res://scenes/assets/extracted_tiles/canon_blossom.svg")
const CANON_LEAF := preload("res://scenes/assets/extracted_tiles/canon_leaf.svg")

const TOKEN_TEXTURES := {
	"lotus": CANON_FLOWER,
	"bell_flower": CANON_BELL,
	"lily": CANON_BLOSSOM,
	"temple": CANON_LEAF,
	"coin": CANON_BLOSSOM,
	"road": CANON_WHEEL,
	"sun": CANON_FLOWER,
	"dhamma_wheel": CANON_WHEEL,
	"moon": CANON_LEAF,
}

@onready var glyph_texture: TextureRect = $GlyphTexture

@export var glyph_id := "":
	set(value):
		glyph_id = value
		_refresh_texture()

@export var ink_color := Color("2f2118"):
	set(value):
		ink_color = value
		_refresh_texture()

@export var scale_bias := 1.0:
	set(value):
		scale_bias = value
		_apply_texture_layout()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	glyph_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_texture()


func configure(next_glyph_id: String, next_ink_color: Color, next_scale_bias := 1.0) -> void:
	glyph_id = next_glyph_id
	ink_color = next_ink_color
	scale_bias = next_scale_bias
	_refresh_texture()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	if not is_node_ready():
		return
	_apply_texture_layout()


func _refresh_texture() -> void:
	if not is_node_ready():
		return
	glyph_texture.texture = TOKEN_TEXTURES[glyph_id] if TOKEN_TEXTURES.has(glyph_id) else null
	glyph_texture.visible = glyph_texture.texture != null
	_apply_texture_layout()


func _apply_texture_layout() -> void:
	if not is_node_ready():
		return
	var safe_scale: float = clampf(scale_bias, 0.1, 1.0)
	var inset: float = maxf(0.0, (1.0 - safe_scale) * minf(size.x, size.y) * 0.5)
	glyph_texture.offset_left = inset
	glyph_texture.offset_top = inset
	glyph_texture.offset_right = -inset
	glyph_texture.offset_bottom = -inset
