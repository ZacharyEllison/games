class_name UnderwaterBackground
extends CanvasLayer

const TERRAIN_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/background_terrain.png")
const SEAWEED_A_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/background_seaweed_c.png")
const SEAWEED_B_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/background_seaweed_f.png")
const ROCK_A_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/background_rock_a.png")
const ROCK_B_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/background_rock_b.png")
const BUBBLE_A_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/bubble_a.png")
const BUBBLE_B_TEX := preload("res://art/kenney_fish-pack_2/PNG/Default/bubble_c.png")

@export var scroll_speed: float = 0.04
@export var asset_blend_speed: float = 0.35

@onready var panel: ColorRect = $Panel


func _ready() -> void:
    layer = -100
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _apply_shader_textures()
    fit_viewport()
    get_viewport().size_changed.connect(fit_viewport)


func fit_viewport() -> void:
    panel.position = Vector2.ZERO
    panel.size = get_viewport().size


func _apply_shader_textures() -> void:
    var mat := panel.material as ShaderMaterial
    if mat == null:
        return
    # Own material instance so instances do not share runtime state.
    panel.material = mat.duplicate()
    mat = panel.material as ShaderMaterial
    mat.set_shader_parameter("terrain_tex", TERRAIN_TEX)
    mat.set_shader_parameter("seaweed_tex_a", SEAWEED_A_TEX)
    mat.set_shader_parameter("seaweed_tex_b", SEAWEED_B_TEX)
    #mat.set_shader_parameter("rock_tex_a", ROCK_A_TEX)
    #mat.set_shader_parameter("rock_tex_b", ROCK_B_TEX)
    mat.set_shader_parameter("bubble_tex_a", BUBBLE_A_TEX)
    mat.set_shader_parameter("bubble_tex_b", BUBBLE_B_TEX)
    mat.set_shader_parameter("scroll_speed", scroll_speed)
    mat.set_shader_parameter("asset_blend_speed", asset_blend_speed)
