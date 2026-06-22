class_name GridSnapper
extends RefCounted

# Stud footprint in mesh space: X = width (studs), Y = depth (studs).
# Kenney GLBs orient 1xN bricks with the long axis along +X.
const BRICK_STUDS := {
    "brick_1x1": Vector2i(1, 1),
    "brick_1x2": Vector2i(2, 1),
    "brick_2x2": Vector2i(2, 2),
    "brick_1x4": Vector2i(4, 1),
    "brick_2x4": Vector2i(4, 2),
    "plate_1x1": Vector2i(1, 1),
    "plate_1x2": Vector2i(2, 1),
    "plate_2x2": Vector2i(2, 2),
    "brick_corner": Vector2i(2, 2),
    "brick_slope_1x2": Vector2i(2, 1),
}

static var desk_surface_y: float = 0.81
static var grid_origin_xz: Vector2 = Vector2.ZERO


static func studs_for(type: String) -> Vector2i:
    return BRICK_STUDS.get(type, Vector2i.ONE)


static func height_for(type: String) -> float:
    return BuildLayout.full_height(type)


static func seat_offset(type: String) -> float:
    return BuildLayout.seat_height(type)


static func seat_surface_y(type: String, bottom_y: float) -> float:
    return bottom_y + seat_offset(type)


static func rot_steps_from_y(rot_y: float) -> int:
    var steps := int(round(rot_y / (PI * 0.5)))
    return ((steps % 4) + 4) % 4


static func rotated_studs(studs: Vector2i, steps: int) -> Vector2i:
    if steps % 2 == 1:
        return Vector2i(studs.y, studs.x)
    return studs


static func _stud_cell(rel: float) -> int:
    return int(round(rel - 0.5))


static func _peg_connect_min_index(rel: float, stud_count: int, run_min: int, run_max: int) -> int:
    if stud_count <= 1:
        var click := _stud_cell(rel)
        if run_min >= 0:
            return clampi(click, run_min, run_max)
        return clampi(click, 0, BuildLayout.DESK_STUDS - 1)

    var click := _stud_cell(rel)
    var frac := rel - float(click) - 0.5
    # Footprint min indices where `click` is one of the peg columns/rows.
    var peg_lo := click - stud_count + 1
    var peg_hi := click
    var bound_lo := 0
    var bound_hi := BuildLayout.DESK_STUDS - stud_count

    if run_min >= 0:
        var run_width := run_max - run_min + 1
        if stud_count == run_width:
            return run_min
        if stud_count < run_width:
            bound_lo = maxi(bound_lo, run_min)
            bound_hi = mini(bound_hi, run_max - stud_count + 1)
        else:
            bound_lo = maxi(bound_lo, run_max - stud_count + 1)
            bound_hi = mini(bound_hi, run_min)

    var want_hi := frac < 0.0
    var min_ix := peg_hi if want_hi else peg_lo
    var lo := maxi(peg_lo, bound_lo)
    var hi := mini(peg_hi, bound_hi)
    if lo > hi:
        min_ix = clampi(click, bound_lo, bound_hi)
    else:
        min_ix = clampi(min_ix, lo, hi)
    return min_ix


static func _min_stud_index(rel: float, stud_count: int) -> int:
    return _peg_connect_min_index(rel, stud_count, -1, -1)


static func _min_index_from_center(rel: float, stud_count: int) -> int:
    return int(round(rel - stud_count * 0.5))


static func _axis_center(origin: float, min_ix: int, stud_count: int) -> float:
    return origin + (min_ix + stud_count * 0.5) * BuildLayout.STUD_PITCH


static func snap_xz(hit: Vector3, studs: Vector2i) -> Dictionary:
    var pitch := BuildLayout.STUD_PITCH
    var rel_x := (hit.x - grid_origin_xz.x) / pitch
    var rel_z := (hit.z - grid_origin_xz.y) / pitch
    var click_ix := _stud_cell(rel_x)
    var click_iz := _stud_cell(rel_z)

    var run_x := BuildGrid.support_run_x(click_ix, click_iz)
    var run_z := BuildGrid.support_run_z(click_ix, click_iz)
    var min_ix := _peg_connect_min_index(rel_x, studs.x, run_x.x, run_x.y) if run_x.x >= 0 else _min_stud_index(rel_x, studs.x)
    var min_iz := _peg_connect_min_index(rel_z, studs.y, run_z.x, run_z.y) if run_z.x >= 0 else _min_stud_index(rel_z, studs.y)

    return {
        "position": Vector2(
            _axis_center(grid_origin_xz.x, min_ix, studs.x),
            _axis_center(grid_origin_xz.y, min_iz, studs.y),
        ),
        "min_indices": Vector2i(min_ix, min_iz),
    }


static func footprint_indices(center_xz: Vector2, studs: Vector2i) -> Array[Vector2i]:
    var pitch := BuildLayout.STUD_PITCH
    var rel_x := (center_xz.x - grid_origin_xz.x) / pitch
    var rel_z := (center_xz.y - grid_origin_xz.y) / pitch
    var min_ix := _min_index_from_center(rel_x, studs.x)
    var min_iz := _min_index_from_center(rel_z, studs.y)
    var cells: Array[Vector2i] = []
    for ix in studs.x:
        for iz in studs.y:
            cells.append(Vector2i(min_ix + ix, min_iz + iz))
    return cells


static func footprint_fits_desk(center_xz: Vector2, studs: Vector2i) -> bool:
    for cell in footprint_indices(center_xz, studs):
        if cell.x < 0 or cell.y < 0:
            return false
        if cell.x >= BuildLayout.DESK_STUDS or cell.y >= BuildLayout.DESK_STUDS:
            return false
    return true


static func footprint_indices_from_min(min_ix: int, min_iz: int, studs: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for ix in studs.x:
        for iz in studs.y:
            cells.append(Vector2i(min_ix + ix, min_iz + iz))
    return cells


static func footprint_fits_desk_from_min(min_ix: int, min_iz: int, studs: Vector2i) -> bool:
    for ix in studs.x:
        for iz in studs.y:
            var cell_x := min_ix + ix
            var cell_z := min_iz + iz
            if cell_x < 0 or cell_z < 0:
                return false
            if cell_x >= BuildLayout.DESK_STUDS or cell_z >= BuildLayout.DESK_STUDS:
                return false
    return true


static func snap_rotation(rot_y: float) -> float:
    return float(rot_steps_from_y(rot_y)) * (PI * 0.5)


static func configure_from_desk(desk: Node3D) -> void:
    grid_origin_xz = BuildLayout.grid_origin_xz(desk)
    desk_surface_y = BuildLayout.desk_top_y(desk)
    _sync_desk_shader(desk)


static func _sync_desk_shader(desk: Node3D) -> void:
    var mesh := desk.get_node_or_null("DeskMesh") as MeshInstance3D
    if not mesh:
        return
    var mat := mesh.get_surface_override_material(0) as ShaderMaterial
    if not mat:
        return
    mat.set_shader_parameter("grid_origin", grid_origin_xz)
    mat.set_shader_parameter("cell_size", BuildLayout.STUD_PITCH)
    mat.set_shader_parameter("stud_radius", BuildLayout.STUD_DOT_RADIUS)
