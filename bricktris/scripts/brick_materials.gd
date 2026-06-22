class_name BrickMaterials
extends RefCounted

const COLORMAP := preload("res://art/kenney-bricks/colormap.png")

static var _placed_cache: Dictionary = { }


static func placed_from(source: Material) -> StandardMaterial3D:
    var key: String = source.resource_path if source and source.resource_path else str(source)
    if _placed_cache.has(key):
        return _placed_cache[key]
    var m := StandardMaterial3D.new()
    if source is StandardMaterial3D:
        var src := source as StandardMaterial3D
        m.albedo_color = src.albedo_color
        m.uv1_scale = src.uv1_scale
        m.uv1_offset = src.uv1_offset
    m.albedo_texture = COLORMAP
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    m.disable_receive_shadows = false
    m.roughness = 0.78
    m.metallic = 0.0
    m.metallic_specular = 0.35
    _placed_cache[key] = m
    return m
