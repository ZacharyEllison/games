@tool
class_name TokenGlyph
extends Control

const CANON_FLOWER := preload("res://scenes/assets/extracted_tiles/canon_flower.svg")
const CANON_WHEEL := preload("res://scenes/assets/extracted_tiles/canon_wheel.svg")
const CANON_ROAD := preload("res://scenes/assets/extracted_tiles/canon_road.svg")
const CANON_BELL := preload("res://scenes/assets/extracted_tiles/canon_bell.svg")
const CANON_BLOSSOM := preload("res://scenes/assets/extracted_tiles/canon_blossom.svg")
const CANON_LEAF := preload("res://scenes/assets/extracted_tiles/canon_leaf.svg")
const CANON_COIN := preload("res://scenes/assets/extracted_tiles/canon_coin.svg")
const CANON_SUN := preload("res://scenes/assets/extracted_tiles/canon_sun.svg")
const CANON_MOON := preload("res://scenes/assets/extracted_tiles/canon_moon.svg")

const TOKEN_TEXTURES := {
    "lotus": CANON_FLOWER,
    "bell_flower": CANON_BELL,
    "lily": CANON_BLOSSOM,
    "beetle": CANON_LEAF,
    "coin": CANON_COIN,
    "road": CANON_ROAD,
    "sun": CANON_SUN,
    "dharma": CANON_WHEEL,
    "moon": CANON_MOON,
}
const GLYPH_SHADER_CODE := """
shader_type canvas_item;

uniform bool invert_enabled = false;
uniform vec4 ink_tint : source_color = vec4(0.184, 0.129, 0.094, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float ink_alpha = tex.a * (1.0 - luminance);
	float alpha = ink_alpha;
	if (invert_enabled) {
		float circle_mask = 1.0 - smoothstep(0.485, 0.515, distance(UV, vec2(0.5)));
		alpha = circle_mask * (1.0 - ink_alpha);
	}
	COLOR = vec4(ink_tint.rgb, alpha * ink_tint.a);
}
"""

@onready var glyph_texture: TextureRect = $GlyphTexture
var _invert_material: ShaderMaterial

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

@export var inverted := false:
    set(value):
        inverted = value
        _refresh_texture()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    glyph_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glyph_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    glyph_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glyph_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _ensure_invert_material()
    _refresh_texture()


func configure(next_glyph_id: String, next_ink_color: Color, next_scale_bias := 1.0, next_inverted := false) -> void:
    glyph_id = next_glyph_id
    ink_color = next_ink_color
    scale_bias = next_scale_bias
    inverted = bool(next_inverted)
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
    _ensure_invert_material()
    glyph_texture.texture = TOKEN_TEXTURES[glyph_id] if TOKEN_TEXTURES.has(glyph_id) else null
    glyph_texture.visible = glyph_texture.texture != null
    _invert_material.set_shader_parameter("invert_enabled", inverted)
    _invert_material.set_shader_parameter("ink_tint", ink_color)
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


func _ensure_invert_material() -> void:
    if _invert_material != null:
        return
    var shader := Shader.new()
    shader.code = GLYPH_SHADER_CODE
    _invert_material = ShaderMaterial.new()
    _invert_material.shader = shader
    glyph_texture.material = _invert_material
