class_name DesktopCamera
extends RefCounted

enum Preset { ORBIT, FRONT, TOP, ORTHO, LEFT, RIGHT, ISO }

const ORBIT_DISTANCE := BuildLayout.DESK_EXTENT * 1.15
const ORTHO_SIZE := BuildLayout.DESK_HALF_EXTENT * 1.4
const MIN_DISTANCE := BuildLayout.DESK_HALF_EXTENT * 0.8
const MAX_DISTANCE := BuildLayout.DESK_EXTENT * 2.5
const MIN_ORTHO := BuildLayout.DESK_HALF_EXTENT * 0.6
const MAX_ORTHO := BuildLayout.DESK_EXTENT * 2.0
const FOCUS_LIFT := BuildLayout.BRICK_HEIGHT * 2.0


static func focus_point(desk: Node3D) -> Vector3:
    return desk.global_position + Vector3(0, FOCUS_LIFT, 0)


static func preset(p: Preset) -> Dictionary:
    match p:
        Preset.ORBIT:
            return { "yaw": 0.0, "pitch": 0.52, "dist": ORBIT_DISTANCE, "ortho": false }
        Preset.FRONT:
            return { "yaw": PI, "pitch": 0.38, "dist": ORBIT_DISTANCE * 0.95, "ortho": false }
        Preset.TOP:
            return { "yaw": 0.0, "pitch": 1.52, "dist": ORBIT_DISTANCE * 1.1, "ortho": false }
        Preset.ORTHO:
            # Corner-down orthographic (two sides + plan), not straight top-down.
            return {
                "yaw": PI * 0.25,
                "pitch": 0.82,
                "dist": ORBIT_DISTANCE,
                "ortho": true,
                "ortho_size": ORTHO_SIZE * 1.35,
            }
        Preset.LEFT:
            return { "yaw": -PI * 0.5, "pitch": 0.35, "dist": ORBIT_DISTANCE, "ortho": false }
        Preset.RIGHT:
            return { "yaw": PI * 0.5, "pitch": 0.35, "dist": ORBIT_DISTANCE, "ortho": false }
        Preset.ISO:
            return { "yaw": PI * 0.25, "pitch": 0.58, "dist": ORBIT_DISTANCE * 1.05, "ortho": false }
    return preset(Preset.ORBIT)


static func preset_name(p: Preset) -> String:
    match p:
        Preset.ORBIT:
            return "Orbit"
        Preset.FRONT:
            return "Front"
        Preset.TOP:
            return "Top"
        Preset.ORTHO:
            return "Ortho"
        Preset.LEFT:
            return "Left"
        Preset.RIGHT:
            return "Right"
        Preset.ISO:
            return "Iso"
    return "Orbit"


static func apply(
        cam: Camera3D,
        desk: Node3D,
        yaw: float,
        pitch: float,
        dist: float,
        ortho: bool,
        ortho_size: float = ORTHO_SIZE,
) -> void:
    var focus := focus_point(desk)
    var clamped_pitch := clampf(pitch, 0.08, 1.56)
    var cp := cos(clamped_pitch)
    var dir := Vector3(cp * sin(yaw), sin(clamped_pitch), cp * cos(yaw))
    cam.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho else Camera3D.PROJECTION_PERSPECTIVE
    if ortho:
        cam.size = clampf(ortho_size, MIN_ORTHO, MAX_ORTHO)
    cam.global_position = focus + dir * clampf(dist, MIN_DISTANCE, MAX_DISTANCE)
    cam.look_at(focus, Vector3.UP)


static func reset_rig(xr_origin: Node3D, cam: Camera3D) -> void:
    xr_origin.global_position = Vector3.ZERO
    xr_origin.global_rotation = Vector3.ZERO
    cam.position = Vector3(0, 1.7, 0.3)
    cam.rotation = Vector3(-0.5, 0, 0)
    cam.projection = Camera3D.PROJECTION_PERSPECTIVE
