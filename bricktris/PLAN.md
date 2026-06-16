# Bricktris — Godot 4.6 Build Mode (WebXR)

## Scope

A free-build brick construction toy in Godot 4.6, exported as a **Web (HTML5) build with WebXR**. Runs in the browser on a Meta Quest (or any WebXR headset) via the built-in browser. Desktop mouse is a fallback for development. No tetris mode in this phase.

Fits into the existing `games/` site alongside brickbreaker, flappy, etc. Exported to `bricktris/index.html`.

Player flow:
1. Open `https://zellis.games/bricktris/` on Quest browser — see baseplate and "Enter VR" button
2. Click "Enter VR" → WebXR session starts, controllers appear
3. Select a brick type from the floating HUD panel (point + trigger)
4. Squeeze grip → ghost brick appears at hand; position it
5. Release grip → brick snaps to grid and becomes a physics body
6. Repeat. Reset button clears everything.

**Why WebXR not Android APK:**
- No sideloading or Meta store submission — URL is enough
- Same deployment pipeline as the other games (GitHub Pages)
- Works on any WebXR-capable browser (Quest Browser, Chrome on PC with Link)
- Godot's Web export supports WebXR natively via `WebXRInterface`

---

## 1. Repository layout after setup

```
bricktris/
├── project.godot
├── icon.svg                         # copy from brickbreaker
├── export_presets.cfg               # Android/Web exports
├── art/
│   └── kenney-bricks/               # extracted from kenney_brick-kit.zip
│       ├── bevel-hq-brick-1x1.glb
│       ├── bevel-hq-brick-1x2.glb
│       ├── bevel-hq-brick-2x2.glb
│       ├── bevel-hq-brick-1x4.glb
│       ├── bevel-hq-brick-2x4.glb
│       ├── bevel-hq-plate-1x1.glb
│       ├── bevel-hq-plate-1x2.glb
│       ├── bevel-hq-plate-2x2.glb
│       ├── bevel-hq-brick-corner.glb
│       ├── bevel-hq-brick-slope-1x2.glb
│       └── colormap.png             # shared texture (from Textures/)
├── audio/
│   └── chime.mp3                    # from public/audio/
├── scenes/
│   ├── main.tscn
│   ├── brick.tscn
│   ├── desk.tscn
│   └── hud.tscn
└── scripts/
    ├── main.gd
    ├── brick.gd
    ├── grid_snapper.gd
    ├── hud.gd
    └── audio_manager.gd             # autoload
```

**Asset extraction:**
```bash
cd bricktris
mkdir -p art/kenney-bricks
unzip kenney_brick-kit.zip "Models/GLB format/bevel-hq-brick-1x1.glb" -d /tmp/kb && cp /tmp/kb/Models/GLB\ format/*.glb art/kenney-bricks/
unzip kenney_brick-kit.zip "Models/FBX format/Textures/colormap.png" -d /tmp/kb && cp /tmp/kb/Models/FBX\ format/Textures/colormap.png art/kenney-bricks/
cp public/audio/chime.mp3 audio/
```

The public/gltf/bricktris/ GLBs are the same kenney kit — either source works.

---

## 2. Godot project settings (`project.godot`)

Create via editor. Set these in Project → Project Settings:

```ini
[application]
config/name="Bricktris"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")
config/icon="res://icon.svg"

[autoload]
AudioManager="*res://scripts/audio_manager.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[physics]
common/physics_ticks_per_second=72   # Quest browser WebXR runs at 72 Hz
```

**No OpenXR plugin needed.** WebXR is built into Godot's Web export. Do NOT enable Project Settings → XR → OpenXR — that is for native OpenXR (Android APK), not web.

**Web export setup (do once in editor):**
1. Editor → Export → Add → Web
2. Export Path: `./index.html`
3. Custom HTML Shell: `../shell/game_shell.html` (reuses the shared games shell)
4. `Variant / Thread Support` = **OFF**
   - Since Godot 4.3 this is the default and recommended mode for web
   - Single-threaded export does not use `SharedArrayBuffer`, so **no COOP/COEP headers needed**
   - Works on itch.io, GitHub Pages, and any host without special server config
5. `VRAM Texture Compression / For Desktop` = ON, `For Mobile` = ON
   (Quest uses a mobile GPU; ticking both covers desktop dev + Quest runtime)
6. `Progressive Web App / Ensure Cross-Origin Isolation Headers` = leave OFF
   (only needed when Thread Support is ON)

---

## 3. Brick grid math

Kenney's bevel-hq GLBs export at **1 Godot unit = 1 unit of the model's native scale**. Open any GLB in the Godot editor and check the MeshInstance3D's AABB size to find the actual stud pitch.

Based on the IWSDK codebase (`scale = 15.0` in Three.js units with `gridX=1` for 1x1), and typical Kenney exports, the bricks are approximately **1.0 × 1.2 × 1.0** Godot units per stud (width × height × depth). Measure on import and set `CELL_SIZE` to match.

```
CELL_SIZE = 1.0       # one stud unit in Godot meters (adjust after measuring)
PLATE_HEIGHT = 0.4    # plates are 1/3 height of bricks
```

In VR, 1 Godot unit = 1 meter. At CELL_SIZE=1.0 the bricks are enormous (1m per stud). Scale the bricks down on import or adjust cell size. Recommended: set CELL_SIZE to the measured mesh width, or set import scale to make each stud ≈ 0.032m (3.2cm, matching physical LEGO).

**Import scale recipe:**
- Open `bevel-hq-brick-1x1.glb` in Godot editor
- Note AABB x-size (the stud footprint)
- Set `CELL_SIZE = that value`
- If it's way too big (>0.1m per stud), set import scale in the GLB import settings: Import → Scale = 0.032 / measured_size

---

## 4. Brick definitions

```gdscript
# scripts/grid_snapper.gd
class_name GridSnapper
extends RefCounted

const CELL_SIZE := 1.0   # UPDATE after measuring import

# Brick footprint in stud units [x, y, z]
const BRICK_DEFS := {
    "brick_1x1":       Vector3(1, 1, 1),
    "brick_1x2":       Vector3(1, 1, 2),
    "brick_2x2":       Vector3(2, 1, 2),
    "brick_1x4":       Vector3(1, 1, 4),
    "brick_2x4":       Vector3(2, 1, 4),
    "plate_1x1":       Vector3(1, 0.4, 1),
    "plate_1x2":       Vector3(1, 0.4, 2),
    "plate_2x2":       Vector3(2, 0.4, 2),
    "brick_corner":    Vector3(1, 1, 1),
    "brick_slope_1x2": Vector3(1, 1, 2),
}

# Snap a world position to the nearest grid cell centre.
# dims: the brick's stud dimensions (from BRICK_DEFS)
static func snap(world_pos: Vector3, dims: Vector3) -> Vector3:
    var c := CELL_SIZE
    var x := round(world_pos.x / c) * c + ((dims.x / 2.0) - 0.5) * c
    var y := max(0.0, round(world_pos.y / c) * c)
    var z := round(world_pos.z / c) * c + ((dims.z / 2.0) - 0.5) * c
    return Vector3(x, y, z)
```

---

## 5. Scene tree — `main.tscn`

```
Main  [Node3D]  ← main.gd
│
├── XROrigin3D
│   ├── XRCamera3D              (y=1.7 in editor for desktop preview)
│   ├── RightHand  [XRController3D]  tracker_name="right_hand"
│   │   └── RightHandMesh  [MeshInstance3D]  (small sphere, for desktop preview)
│   └── LeftHand   [XRController3D]  tracker_name="left_hand"
│
├── WorldEnvironment
│   └── Environment  (sky: ProceduralSkyMaterial)
│
├── DirectionalLight3D
│   position=(5,10,5), rotation=(-45,45,0), shadow=true
│
├── Desk  [StaticBody3D]  ← desk.tscn instanced here
│
├── Bricks  [Node3D]         ← spawned brick instances added here
│
└── HUD  [CanvasLayer]  ← hud.tscn instanced here
```

**Editor setup notes:**
- `XRCamera3D` editor position: y=1.7 (so you can see the desk in editor)
- `RightHand` editor position: (0.3, 1.2, -0.4)
- `LeftHand` editor position: (-0.3, 1.2, -0.4)

---

## 6. `scripts/main.gd` — complete

WebXR is **asynchronous** and requires a user gesture to start (browser security policy). The flow is:

1. `_ready()` — find the interface, connect signals, call `is_session_supported()`
2. `_webxr_session_supported()` fires → show/hide "Enter VR" button accordingly
3. User clicks "Enter VR" button → set session properties, call `initialize()`
4. `_webxr_session_started()` fires → `get_viewport().use_xr = true`
5. `_webxr_session_ended()` fires → `get_viewport().use_xr = false`, show 2D UI again

```gdscript
extends Node3D

const BRICK_SCENES := {
    "brick_1x1":       preload("res://scenes/brick_1x1.tscn"),
    "brick_1x2":       preload("res://scenes/brick_1x2.tscn"),
    "brick_2x2":       preload("res://scenes/brick_2x2.tscn"),
    "brick_1x4":       preload("res://scenes/brick_1x4.tscn"),
    "brick_2x4":       preload("res://scenes/brick_2x4.tscn"),
    "plate_1x1":       preload("res://scenes/plate_1x1.tscn"),
    "plate_1x2":       preload("res://scenes/plate_1x2.tscn"),
    "plate_2x2":       preload("res://scenes/plate_2x2.tscn"),
    "brick_corner":    preload("res://scenes/brick_corner.tscn"),
    "brick_slope_1x2": preload("res://scenes/brick_slope_1x2.tscn"),
}

var selected_type: String = "brick_1x1"
var held_brick: Node3D = null
var webxr_interface: WebXRInterface
var _rotated_this_flick := false

@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var bricks_container: Node3D = $Bricks
@onready var hud = $HUD   # typed as HUD after hud.gd is written

func _ready() -> void:
    right_hand.button_pressed.connect(_on_right_button_pressed)
    right_hand.button_released.connect(_on_right_button_released)
    hud.brick_selected.connect(_on_brick_selected)
    hud.reset_requested.connect(_on_reset)
    hud.enter_vr_requested.connect(_on_enter_vr)
    _init_webxr()

# ── WebXR lifecycle ──────────────────────────────────────────────────────────

func _init_webxr() -> void:
    webxr_interface = XRServer.find_interface("WebXR") as WebXRInterface
    if not webxr_interface:
        # Running in Godot editor or non-web build — desktop fallback
        print("WebXR not available — desktop mode")
        hud.set_vr_status("desktop")
        return

    webxr_interface.session_supported.connect(_webxr_session_supported)
    webxr_interface.session_started.connect(_webxr_session_started)
    webxr_interface.session_ended.connect(_webxr_session_ended)
    webxr_interface.session_failed.connect(_webxr_session_failed)

    # Async check — result arrives via session_supported signal
    webxr_interface.is_session_supported("immersive-vr")

func _webxr_session_supported(session_mode: String, supported: bool) -> void:
    if session_mode == "immersive-vr":
        hud.set_vr_status("supported" if supported else "unsupported")

func _on_enter_vr() -> void:
    if not webxr_interface:
        return
    webxr_interface.session_mode = "immersive-vr"
    # Request reference spaces in preference order
    webxr_interface.requested_reference_space_types = "bounded-floor, local-floor, local"
    # required_features must include any space type you want to use.
    # local-floor is needed so the player starts at floor level, not at the origin.
    webxr_interface.required_features = "local-floor"
    # bounded-floor (room scale) and hand-tracking are nice but optional
    webxr_interface.optional_features = "bounded-floor, hand-tracking"
    if not webxr_interface.initialize():
        OS.alert("Failed to start WebXR session")

func _webxr_session_started() -> void:
    print("WebXR started. Reference space: ", webxr_interface.reference_space_type)
    print("Enabled features: ", webxr_interface.enabled_features)
    get_viewport().use_xr = true
    hud.on_xr_started()
    # Also connect the squeeze signals on the interface — more reliable across
    # WebXR devices than XRController3D.button_pressed for the grip action
    webxr_interface.squeezestart.connect(_on_squeeze_start)
    webxr_interface.squeezeend.connect(_on_squeeze_end)
    # Visibility state changes (headset removed, system menu opened)
    webxr_interface.visibility_state_changed.connect(_on_visibility_changed)

func _webxr_session_ended() -> void:
    get_viewport().use_xr = false
    hud.on_xr_ended()

func _webxr_session_failed(message: String) -> void:
    OS.alert("WebXR failed: " + message)
    hud.set_vr_status("supported")  # reset button so user can retry

func _on_visibility_changed() -> void:
    # visibility_state values: "hidden", "visible", "visible-blurred"
    # "visible-blurred" = system menu open; "hidden" = headset removed
    var visible := webxr_interface.visibility_state
    get_tree().paused = (visible != "visible")

# ── Grip/squeeze input ───────────────────────────────────────────────────────
# WebXRInterface emits squeezestart/squeezeend with an input_source_id (0=left, 1=right).
# XRController3D.button_pressed also fires for advanced controllers — use both.
# To confirm button names at runtime: print(button) inside _on_right_button_pressed.

func _on_squeeze_start(input_source_id: int) -> void:
    # input_source_id 0 = left, 1 = right (may vary — check at runtime)
    if input_source_id == 1:
        _begin_hold()

func _on_squeeze_end(input_source_id: int) -> void:
    if input_source_id == 1:
        _place_brick()

# Fallback via XRController3D for advanced controllers
func _on_right_button_pressed(button: String) -> void:
    if button == "grip_click":
        _begin_hold()

func _on_right_button_released(button: String) -> void:
    if button == "grip_click":
        _place_brick()

func _begin_hold() -> void:
    if held_brick or not BRICK_SCENES.has(selected_type):
        return
    var scene: PackedScene = BRICK_SCENES[selected_type]
    held_brick = scene.instantiate()
    bricks_container.add_child(held_brick)
    held_brick.set_ghost(true)        # semi-transparent, no physics

func _process(_delta: float) -> void:
    if held_brick:
        # Track ghost brick to right hand grip position
        var hand_pos := right_hand.global_position
        var dims: Vector3 = GridSnapper.BRICK_DEFS.get(selected_type, Vector3.ONE)
        held_brick.global_position = GridSnapper.snap(hand_pos, dims)
        held_brick.global_basis = right_hand.global_basis   # match controller rotation

func _place_brick() -> void:
    if not held_brick:
        return
    held_brick.set_ghost(false)       # solid, enable physics
    AudioManager.play_place()
    held_brick = null

# ── Desktop fallback (left-click to place) ──────────────────────────────────

func _input(event: InputEvent) -> void:
    if xr_interface and xr_interface.is_initialized():
        return   # XR handles input
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not held_brick:
            _begin_hold_desktop(event)
        else:
            _place_brick()

func _begin_hold_desktop(_event: InputEventMouseButton) -> void:
    # Raycast from camera to desk plane to find spawn position
    var cam := $XROrigin3D/XRCamera3D
    var ray := cam.project_ray_normal(get_viewport().get_mouse_position())
    var origin := cam.global_position
    # Intersect with y=0 plane
    if ray.y >= 0.0:
        return
    var t := -origin.y / ray.y
    var hit := origin + ray * t
    if not BRICK_SCENES.has(selected_type):
        return
    var scene: PackedScene = BRICK_SCENES[selected_type]
    held_brick = scene.instantiate()
    bricks_container.add_child(held_brick)
    held_brick.set_ghost(true)
    var dims: Vector3 = GridSnapper.BRICK_DEFS.get(selected_type, Vector3.ONE)
    held_brick.global_position = GridSnapper.snap(hit, dims)

# ── HUD signals ─────────────────────────────────────────────────────────────

func _on_brick_selected(type: String) -> void:
    selected_type = type
    if held_brick:
        held_brick.queue_free()
        held_brick = null

func _on_reset() -> void:
    if held_brick:
        held_brick.queue_free()
        held_brick = null
    for child in bricks_container.get_children():
        child.queue_free()
    AudioManager.play_chime()
```

---

## 7. `scenes/brick.tscn` — template scene (one per brick type)

Each brick type gets its own `.tscn` that inherits this pattern:

```
BrickRoot  [RigidBody3D]  ← brick.gd
├── Mesh   [MeshInstance3D]   ← GLB sub-scene instanced here, or import directly
└── Shape  [CollisionShape3D]  ← BoxShape3D fitted to mesh AABB
```

**How to create a brick scene:**
1. New scene → root type `RigidBody3D`, rename to e.g. `Brick1x1`
2. Attach `scripts/brick.gd`
3. Add child `MeshInstance3D` → Mesh → drag in `art/kenney-bricks/bevel-hq-brick-1x1.glb`
   (or: instance the GLB as a sub-scene directly)
4. Add child `CollisionShape3D` → Shape → `BoxShape3D`
   → Size = match the GLB AABB (read from MeshInstance3D → AABB in editor)
5. Save as `scenes/brick_1x1.tscn`
6. Repeat for each type, setting the collision shape size appropriately

**Per-type collision shapes** (update X after measuring import scale):

| Type | BoxShape3D size (studs × CELL_SIZE) |
|---|---|
| brick_1x1 | (1×C, 1×C, 1×C) |
| brick_1x2 | (1×C, 1×C, 2×C) |
| brick_2x2 | (2×C, 1×C, 2×C) |
| brick_1x4 | (1×C, 1×C, 4×C) |
| brick_2x4 | (2×C, 1×C, 4×C) |
| plate_1x1 | (1×C, 0.4×C, 1×C) |
| plate_1x2 | (1×C, 0.4×C, 2×C) |
| plate_2x2 | (2×C, 0.4×C, 2×C) |
| brick_corner | (1×C, 1×C, 1×C) |
| brick_slope_1x2 | (1×C, 1×C, 2×C) |

---

## 8. `scripts/brick.gd` — complete

```gdscript
class_name Brick
extends RigidBody3D

# Semi-transparent ghost material applied while held
var _ghost_mat: StandardMaterial3D
var _original_mats: Array[Material] = []

func _ready() -> void:
    _ghost_mat = StandardMaterial3D.new()
    _ghost_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.45)
    _ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    # Store original materials from the mesh child
    var mesh_child := _get_mesh()
    if mesh_child:
        for i in mesh_child.get_surface_override_material_count():
            _original_mats.append(mesh_child.get_surface_override_material(i))

func set_ghost(is_ghost: bool) -> void:
    var mesh_child := _get_mesh()
    if not mesh_child:
        return
    if is_ghost:
        freeze = true                           # no physics while held
        collision_layer = 0                     # no collisions while ghost
        collision_mask = 0
        for i in mesh_child.get_surface_override_material_count():
            mesh_child.set_surface_override_material(i, _ghost_mat)
    else:
        freeze = false
        collision_layer = 1
        collision_mask = 1
        for i in mesh_child.get_surface_override_material_count():
            mesh_child.set_surface_override_material(i, _original_mats[i] if i < _original_mats.size() else null)

func _get_mesh() -> MeshInstance3D:
    for child in get_children():
        if child is MeshInstance3D:
            return child
    return null
```

---

## 9. `scenes/desk.tscn`

```
Desk  [StaticBody3D]
├── DeskMesh   [MeshInstance3D]
│   └── Mesh: BoxMesh  size=(20, 0.1, 20)   # flat baseplate, 20×20 studs
│       Material: StandardMaterial3D
│         albedo_texture: grid texture (generated or a grid PNG)
│         albedo_color: Color(0.12, 0.12, 0.15)
│         roughness: 0.9
└── DeskShape  [CollisionShape3D]
    └── Shape: BoxShape3D  size=(20, 0.1, 20)
```

Position: y = -0.05 so the top surface is at y=0.

**Grid texture**: generate procedurally via a simple 512×512 canvas texture in GDScript, or use a plain dark material with `uv1_scale` tiling. The grid just needs to visually show stud positions. A lightweight approach is a StandardMaterial3D with `albedo_color` + tiled 1×1 grid PNG.

---

## 10. `scenes/hud.tscn`

```
HUD  [CanvasLayer]  ← hud.gd
└── Panel  [PanelContainer]
    anchors: top-left, margins: (12, 12, 0, 0)
    └── VBox  [VBoxContainer]
        ├── TitleLabel     [Label]  text="Bricktris"
        │
        ├── BrickSection   [VBoxContainer]
        │   ├── SectionLabel [Label] text="Brick"
        │   └── BrickGrid  [GridContainer]  columns=3
        │       ├── Btn_1x1   [Button]  text="1×1"   meta: type="brick_1x1"
        │       ├── Btn_1x2   [Button]  text="1×2"   meta: type="brick_1x2"
        │       ├── Btn_2x2   [Button]  text="2×2"   meta: type="brick_2x2"
        │       ├── Btn_1x4   [Button]  text="1×4"   meta: type="brick_1x4"
        │       ├── Btn_2x4   [Button]  text="2×4"   meta: type="brick_2x4"
        │       ├── Btn_Plate1x1 [Button] text="P1×1" meta: type="plate_1x1"
        │       ├── Btn_Plate1x2 [Button] text="P1×2" meta: type="plate_1x2"
        │       ├── Btn_Plate2x2 [Button] text="P2×2" meta: type="plate_2x2"
        │       ├── Btn_Corner  [Button]  text="Corner" meta: type="brick_corner"
        │       └── Btn_Slope   [Button]  text="Slope"  meta: type="brick_slope_1x2"
        │
        ├── HSeparator
        │
        ├── EnterVRBtn     [Button]  text="Enter VR"   (unique_name_in_owner=true → %EnterVRBtn)
        ├── VRStatusLabel  [Label]   text="Checking…"  (unique_name_in_owner=true → %VRStatusLabel)
        ├── DesktopHint    [Label]   text=""            (unique_name_in_owner=true → %DesktopHint)
        └── ResetBtn       [Button]  text="Reset"       (unique_name_in_owner=true → %ResetBtn)
```

Theme: dark background `#09090b`, white text `#fafafa`, selected button `#60a5fa`.

**CanvasLayer in WebXR**: Godot automatically renders CanvasLayer as a flat quad in front of the player when `use_xr = true`. This means the HUD is visible inside the headset. The "Enter VR" button will be invisible once XR starts (hidden by `on_xr_started()`); brick selection is done by pointing the controller ray at the panel and pressing trigger.

---

## 11. `scripts/hud.gd` — complete

```gdscript
class_name HUD
extends CanvasLayer

signal brick_selected(type: String)
signal reset_requested
signal enter_vr_requested   # fired by "Enter VR" button click

@onready var brick_buttons: Array[Button] = []
@onready var enter_vr_btn: Button = %EnterVRBtn
@onready var vr_status_label: Label = %VRStatusLabel
@onready var reset_btn: Button = %ResetBtn
@onready var desktop_hint: Label = %DesktopHint

func _ready() -> void:
    var grid := %BrickGrid
    for child in grid.get_children():
        if child is Button:
            brick_buttons.append(child)
            child.pressed.connect(_on_brick_btn_pressed.bind(child))

    reset_btn.pressed.connect(func(): reset_requested.emit())
    enter_vr_btn.pressed.connect(func(): enter_vr_requested.emit())

    # Start with Enter VR button disabled until session_supported fires
    enter_vr_btn.disabled = true
    vr_status_label.text = "Checking VR support…"
    desktop_hint.hide()

func set_vr_status(status: String) -> void:
    match status:
        "supported":
            enter_vr_btn.disabled = false
            vr_status_label.text = "VR ready"
        "unsupported":
            enter_vr_btn.disabled = true
            vr_status_label.text = "VR not supported in this browser"
        "desktop":
            enter_vr_btn.hide()
            vr_status_label.hide()
            desktop_hint.text = "Desktop mode — click to place bricks"
            desktop_hint.show()

func on_xr_started() -> void:
    # Hide 2D panel once inside VR — bricks are selected via controllers
    # Keep it visible for now (CanvasLayer renders into VR as a flat quad)
    # Optionally hide with: hide()
    enter_vr_btn.hide()
    vr_status_label.hide()

func on_xr_ended() -> void:
    enter_vr_btn.show()
    enter_vr_btn.disabled = false
    vr_status_label.text = "VR ready"
    vr_status_label.show()

func _on_brick_btn_pressed(btn: Button) -> void:
    var type: String = btn.get_meta("type", "")
    if type.is_empty():
        return
    brick_selected.emit(type)
    for b in brick_buttons:
        b.button_pressed = false
    btn.button_pressed = true
```

**Button wiring in editor:**
- Each brick Button: `toggle_mode = true`, meta `type` = brick type string
- `EnterVRBtn` — large primary button, label "Enter VR"
- `VRStatusLabel` — small label below the button
- `DesktopHint` — label hidden by default, shown in desktop mode
- First brick button (brick_1x1) starts with `button_pressed = true`

---

## 12. `scripts/audio_manager.gd` — complete

```gdscript
extends Node

var _place_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer

func _ready() -> void:
    _place_player = AudioStreamPlayer.new()
    _chime_player = AudioStreamPlayer.new()
    add_child(_place_player)
    add_child(_chime_player)
    # Soft thud synthesised from AudioStreamGenerator, or load an asset
    var chime := load("res://audio/chime.mp3")
    if chime:
        _chime_player.stream = chime

func play_place() -> void:
    # Short pitched click — generate if no asset available
    if _place_player.stream == null:
        _place_player.stream = _make_click()
    _place_player.pitch_scale = randf_range(0.9, 1.1)
    _place_player.play()

func play_chime() -> void:
    _chime_player.play()

func _make_click() -> AudioStreamWAV:
    # 12ms square-wave click at 440 Hz
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_8_BITS
    wav.mix_rate = 22050
    var samples := PackedByteArray()
    for i in 265:   # ~12ms
        samples.append(127 if (i % 50) < 25 else 0)
    wav.data = samples
    return wav
```

---

## 13. Input map (Project → Input Map)

| Action | XR binding | Desktop binding |
|---|---|---|
| `grab` | Right controller grip (grip_click via OpenXR) | Mouse left button |
| `ui_select` | Right controller trigger (trigger_click) | Mouse left button |

XRController3D emits `button_pressed(button_name)` and `button_released(button_name)` signals. The `button_name` values come from the OpenXR action map. With the Meta Quest via the Godot OpenXR Vendors Plugin, grip = `"grip_click"`, trigger = `"trigger_click"`.

To confirm button names at runtime during development: add a temporary `print(button)` inside `_on_right_button_pressed` and squeeze/trigger on the Quest.

---

## 14. VR interaction detail

### Ghost brick tracking
While grip is held, the ghost brick follows the right hand every `_process` frame. This runs every frame (not physics), so it feels responsive at any refresh rate.

### Grid snapping on release
`GridSnapper.snap()` is called on the position when the brick is placed. The result is the snapped world position. The brick is then un-frozen and becomes a physics `RigidBody3D` — it falls and settles on whatever surface is below it.

### Rotation
Add support for rotating the held brick around Y by 90° increments on thumbstick flick right/left:

```gdscript
# In main.gd _process():
if held_brick:
    var axes := right_hand.get_vector2("primary")  # thumbstick
    if axes.x > 0.7 and not _rotated_this_flick:
        held_brick.rotate_y(deg_to_rad(90.0))
        _rotated_this_flick = true
    elif abs(axes.x) < 0.3:
        _rotated_this_flick = false
```

### Collision layers
- Layer 1: static world (desk, walls)
- Layer 2: placed bricks
- Layer 3: ghost brick (no collision with anything)

Desk: `collision_layer=1, collision_mask=0`
Placed brick: `collision_layer=2, collision_mask=1|2` (lands on desk and other bricks)
Ghost brick: `collision_layer=0, collision_mask=0`

---

## 15. Desktop camera

When OpenXR is not initialised, give the player an orbit camera to place bricks:

```gdscript
# In main.gd _process() — desktop only:
if not (xr_interface and xr_interface.is_initialized()):
    var cam_pivot := $XROrigin3D
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var delta_mouse := Input.get_last_mouse_velocity() * 0.002
        cam_pivot.rotation.y -= delta_mouse.x
        cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - delta_mouse.y, -1.2, 0.1)
```

---

## 16. Implementation checklist (in order)

**Step 1 — Project skeleton**
- [ ] Create `project.godot` in editor (3D project, Compatibility renderer)
- [ ] Copy `icon.svg` from brickbreaker
- [ ] Create folder structure: `art/kenney-bricks/`, `audio/`, `scenes/`, `scripts/`
- [ ] Extract GLBs from `kenney_brick-kit.zip` into `art/kenney-bricks/`
- [ ] Copy `public/audio/chime.mp3` → `audio/chime.mp3`
- [ ] Editor → Export → Add → Web; set path `./index.html`, custom shell `../shell/game_shell.html`, threads OFF, desktop+mobile VRAM ON, COEP headers OFF (not needed with threads OFF)

**Step 2 — Measure brick dimensions**
- [ ] Open `art/kenney-bricks/bevel-hq-brick-1x1.glb` in editor
- [ ] Read AABB size from MeshInstance3D inspector (Surface 0 → AABB)
- [ ] Update `GridSnapper.CELL_SIZE` to the x-dimension of the 1x1 brick

**Step 3 — Scripts (no scenes yet)**
- [ ] Write `scripts/grid_snapper.gd`
- [ ] Write `scripts/brick.gd`
- [ ] Write `scripts/audio_manager.gd`
- [ ] Write `scripts/hud.gd`
- [ ] Write `scripts/main.gd`

**Step 4 — Brick scenes**
- [ ] Create `scenes/brick_1x1.tscn` (RigidBody3D + MeshInstance3D + CollisionShape3D + brick.gd)
- [ ] Verify ghost material looks correct (run game, check blue transparency)
- [ ] Duplicate and adjust for all 10 brick types (collision shape sizes per table in §7)

**Step 5 — Desk scene**
- [ ] Create `scenes/desk.tscn`
- [ ] Set BoxMesh to 20×20 baseplate at y=-0.05
- [ ] Apply dark material with light grid tiling

**Step 6 — HUD scene**
- [ ] Create `scenes/hud.tscn` with CanvasLayer → PanelContainer tree
- [ ] Add all 10 brick buttons to BrickGrid with `type` metadata
- [ ] Style: dark panel, white text, blue selected state
- [ ] Attach `scripts/hud.gd`

**Step 7 — Main scene**
- [ ] Create `scenes/main.tscn`
- [ ] Add XROrigin3D → XRCamera3D + RightHand (XRController3D) + LeftHand
- [ ] Instance `desk.tscn` as child
- [ ] Add `Bricks` Node3D as child
- [ ] Instance `hud.tscn` as child
- [ ] Add WorldEnvironment + DirectionalLight3D
- [ ] Attach `scripts/main.gd`
- [ ] Wire signals: `RightHand.button_pressed` → `_on_right_button_pressed`

**Step 8 — Desktop test**
- [ ] Run in editor (no headset): verify camera, click spawns ghost brick, click places
- [ ] Verify brick falls and lands on desk
- [ ] Verify stacking: second brick lands on first

**Step 9 — Web export**
- [ ] Editor → Export → Export Project → `bricktris/index.html`
- [ ] Serve locally (no special headers needed with Thread Support OFF):
  ```bash
  python3 -m http.server 8080 --directory /Users/zacharyellison/code/games
  ```
- [ ] Open `http://localhost:8080/bricktris/index.html` in Chrome (desktop) — verify 3D renders, bricks place with mouse click
- [ ] Open the same URL on Quest Browser or via Meta Link → click "Enter VR" → verify session starts
- [ ] Verify grip spawns ghost brick at hand, release snaps and places
- [ ] Verify stacking, reset
- [ ] Deploy: push to GitHub Pages — the existing CI/deploy pipeline handles it

---

## 17. Key differences from existing 2D games (brickbreaker, flappy, etc.)

| Topic | 2D games | Bricktris |
|---|---|---|
| Root node | Node2D | Node3D |
| Physics | Area2D / CharacterBody2D | RigidBody3D / StaticBody3D |
| Camera | Camera2D / stretch | XRCamera3D driven by WebXR headset pose |
| XR interface | n/a | `WebXRInterface` (not OpenXR) — async signals, requires user gesture |
| Input | `_input(event)` keyboard/touch | `WebXRInterface.squeezestart/end` (primary grip) + `XRController3D.button_pressed` (advanced controllers) + mouse fallback |
| UI | Control nodes fill viewport | CanvasLayer (Godot auto-renders it as flat quad in VR) |
| Export | Web (no special config) | Web, Thread Support OFF — no COOP/COEP headers needed |
| Scenes path | `scenes/` + `scripts/` separate | Same |
| Autoload | AudioManager same pattern | Same |
| Signals up | Same pattern | Same |

The code structure (signals up to main, autoload AudioManager, preload+instantiate, CanvasLayer HUD) is identical to the existing games. The only new concepts are 3D physics nodes and the WebXR async session lifecycle.

---

## 18. WebXR gotchas

| Gotcha | Detail |
|---|---|
| User gesture required | `webxr_interface.initialize()` **must** be called from a button press handler, not from `_ready()`. Browsers block XR session creation otherwise. |
| `WebXRInterface` not `OpenXRInterface` | These are different classes. Don't enable Project Settings → XR → OpenXR. |
| Thread Support OFF | **Default and recommended since Godot 4.3.** No `SharedArrayBuffer` = no COOP/COEP headers required. Works on any plain host (itch.io, GitHub Pages, plain `python3 -m http.server`). Enable threads only if you hit a performance ceiling. |
| COOP/COEP headers | Only needed when `Thread Support` is ON. If you do enable threads: server must send `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`, or enable `Progressive Web App / Ensure Cross-Origin Isolation Headers` to inject them via service worker. |
| `required_features` is mandatory | Any reference space type you list in `requested_reference_space_types` **must also appear** in `required_features` or `optional_features`. E.g. to use `local-floor`, set `required_features = "local-floor"`. Omitting it causes the session to fail or silently fall back to `local` (no floor height). |
| Squeeze via WebXRInterface signals | `WebXRInterface` emits `squeezestart(input_source_id)` and `squeezeend(input_source_id)` directly — these work on all WebXR devices. `XRController3D.button_pressed("grip_click")` also fires for advanced controllers (Oculus Touch, Index) and can be used as a parallel path. |
| Pause on headset removal | OpenXR has `session_visible` signal. WebXR uses `visibility_state_changed()` signal + `visibility_state` property (`"visible"`, `"visible-blurred"`, `"hidden"`). Pause when not `"visible"`. |
| Button names | WebXR controller button names (`"trigger_click"`, `"grip_click"`) are interface-defined and may vary by device/browser. Add `print(button)` in `_on_right_button_pressed` on first run to confirm exact names. |
| CanvasLayer in VR | Godot renders CanvasLayer as a flat panel in front of the player in WebXR. It works, but it won't follow the player's gaze. Keep the panel small and positioned at a comfortable viewing angle, or hide it once VR starts and use controller ray-pointing to interact with a 3D WorldspaceUI instead (future enhancement). |
| Physics in WebXR | WebXR doesn't change physics. `RigidBody3D` works normally. Set `physics_ticks_per_second = 72` to match Quest's refresh rate and avoid visual stutter. |
