# Bricktris — design notes and lessons learned

WebXR LEGO-style builder at [zellis.games/bricktris](https://zellis.games/bricktris/). Godot 4.6, Kenney bevel-hq brick GLBs, Web export.

This doc captures layout, snapping, input, and deployment decisions from building and iterating on Bricktris so future changes stay consistent.

---

## Architecture

| Script | Role |
|--------|------|
| `main.gd` | WebXR lifecycle, VR/desktop input, grab/place/throw, camera |
| `build_layout.gd` | **All spatial constants** — stud pitch, desk size, palette offsets, throw timing |
| `grid_snapper.gd` | Stud footprints, XZ snap, rotation steps, desk bounds, shader sync |
| `build_grid.gd` | Per-column seat heights, placement/preview, stack registration |
| `brick_palette.gd` | 3D palette slots beside the grid |
| `placement_preview.gd` | Desktop snap footprint highlight (green/red cells) |
| `desktop_camera.gd` | Orbit / front / top / ortho / iso view presets |
| `brick.gd` | Ghost, held, placed, thrown states |

**Rule:** Put layout numbers in `BuildLayout` as `const` multiples of `STUD_PITCH`. Never use function calls inside `const` declarations (Godot parse error).

---

## Grid and desk

- **Stud pitch:** `0.0795` m (Kenney mesh scale).
- **Grid:** 10×10 studs → desk mesh `0.795 × 0.795` m.
- **Grid origin:** desk **min corner** (not center). `GridSnapper.configure_from_desk()` syncs origin + stud shader params.
- **Seated layout:** desk placed in front of default XR camera using `DESK_TOP_Y`, `SEATED_CAM_Z`, and `DESK_NEAR_MARGIN` in `BuildLayout.desk_position()`.

Footprints (mesh space, long axis +X):

| Type | Studs (X × Z) |
|------|----------------|
| brick_1x1, plate_1x1 | 1×1 |
| brick_1x2, plate_1x2, brick_slope_1x2 | 2×1 |
| brick_2x2, plate_2x2, brick_corner | 2×2 |
| brick_1x4 | 4×1 |
| brick_2x4 | 4×2 |

**Seat heights** (body top where next brick pegs connect, not stud tips): bricks `0.096`, plates `0.032`.

---

## Snapping and stacking

### Horizontal snap

For multi-stud bricks, the **clicked stud must stay inside the footprint**. Snap extends **leftward** (lower index) so a 1×2 spanning two columns always covers the same two cells regardless of which stud you click:

```gdscript
# grid_snapper.gd — placement snap
return clampi(clicked - stud_count + 1, 0, DESK_STUDS - stud_count)
```

**Do not** always treat the clicked cell as `min_ix` — that makes a 1×2 land on top of a neighbor when clicking the far stud.

### Footprint from center

When recovering cells from a placed brick center, use center-based min index (`_min_index_from_center`), not the hit-based snap function. Mixing the two broke seat registration and stack height.

### Vertical stack

`BuildGrid` keeps a per-stud-column **seat Y** map. New brick bottom Y = max desk surface and seat under any footprint cell. A brick spanning columns at different heights sits level on the **taller** support (LEGO-like).

When the ray hits an existing brick, **snap aligns to the support run under the click** (same seat height, contiguous studs). Equal spans share the same min stud index. Narrower/deeper pieces pick **whichever peg connects** to the clicked stud: the hit position within the stud cell chooses whether that stud is the near or far peg along each axis (e.g. **2×2 on 1×4** — click stud 2 can become pegs 1–2 or 2–3 depending on where on the stud you aim).

Placement rejects footprints outside the 10×10 grid via `footprint_fits_desk()`.

### Rotation

- Only **90° steps** (0–3). VR tracks `_held_rot_steps`; do **not** copy controller euler angles onto the brick.
- `rot_steps_from_y` must normalize negatives: `((steps % 4) + 4) % 4`.

---

## 3D palette

- Fixed beside the grid (not head-following). Origin at grid **front-right corner**; slots run along **−Z** (down the right edge), two rows in **+X**.
- **`VR_PALETTE_GAP`:** offset from grid edge in stud multiples (currently 2 studs — 0 overlapped, head-following felt random).
- **Display scale:** `PALETTE_BRICK_SCALE = 0.85` on palette previews only; grabbed/placed bricks stay full size.
- **`look_at` the desk** rotated columns along depth and scattered bricks — keep `rotation = Vector3.ZERO`.

---

## Input

### VR

- **Either controller** works: squeeze/grip on left (source 0) or right (source 1) grabs; release on the **same** hand places. While holding, that hand drives position, rotation, and throw velocity.
- Grip / squeeze: grab from palette or re-grab placed brick; release to snap-place.
- Fast release → throw (velocity averaged over 4 frames).
- Thumbstick **right** / **left**: rotate held brick 90° clockwise / counter-clockwise (one step per flick).

### Desktop

- **Invisible** `RightHand` mesh; mouse ray positions the hand.
- **Left-click hold:** grab; **release:** place (same pipeline as VR).
- **R:** rotate held brick; **Ctrl+Z:** undo; **right-drag:** orbit; **scroll:** zoom.
- Sidebar type list is cosmetic — grab from the **3D palette** like VR.
- **`PlacementPreview`:** green/red stud cells under the held brick; uses `BuildGrid.preview()` and a downward ray (same as release).

### Failed placement

If release is invalid (off grid), **keep** `held_brick` set — do not clear the reference and leave a orphan ghost. Orphan ghosts with a `brick_type` remain grabbable via proximity scan of `Bricks` children.

---

## Throw

- Threshold: `THROW_SPEED_THRESHOLD` (~7 stud pitches of hand speed).
- Thrown bricks use physics (`begin_throw`), full materials, collision on desk + bricks.
- Despawn after **`THROW_DESPAWN_SECONDS` (3)** — timer only, **not** when leaving desk bounds (early off-desk despawn made throws invisible).

---

## Camera (desktop)

Presets in `desktop_camera.gd`. **Ortho** is a **top-corner** orthogonal view (yaw 45°, pitch ~47°), not straight top-down. **Top** stays nadir perspective.

---

## Web export

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  --path bricktris \
  --export-release "Web" bricktris/index.html
```

- OpenXR stays **disabled** in `project.godot` for the web build; WebXR interface is used at runtime in the browser.
- Commit `index.html` and `index.pck` with script/scene changes.
- Deploy: push to `main` → GitHub Pages. Hard refresh after deploy.

---

## Godot UID pitfalls

- **Do not hand-write `.uid` files** outside the editor — causes `Unrecognized UID` when cache and references disagree.
- **`build_grid.gd.uid` had an invalid 14-char UID**; Godot expects 13 characters.
- Scripts used only from code: prefer a **scene node** with path-based `ext_resource` in `main.tscn` (e.g. `PlacementPreview`) over `ClassName.new()` if UID/cache issues appear.
- After UID problems: delete `bricktris/.godot/` and re-import, or run `--import --quit-after 1`.

---

## Checklist for common regressions

| Symptom | Likely cause |
|---------|----------------|
| Brick floats above pegs | Wrong seat height or grid origin at desk center |
| 1×N lands on wrong column when bridging | Hit anchored as footprint min instead of leftward span |
| VR rotation misaligned after turn | Using `held_brick.rotation.y` / controller euler instead of `_held_rot_steps` |
| Palette far or overlapping grid | `VR_PALETTE_GAP`, palette `look_at`, or row layout along +X vs −Z |
| Ghost stuck after bad release | Cleared `held_brick` without `queue_free()` |
| Throw invisible | Off-desk despawn before timer; keep 3s timer-only despawn |
| Desktop sidebar click places brick | Use `_unhandled_input` + `hud.is_pointer_over_ui()` |
| Web build parse error on constants | Function call inside `const` in `BuildLayout` |

---

## Key files to touch together

Changing desk size or layout:

1. `build_layout.gd` — `DESK_STUDS`, margins, palette gap  
2. `scenes/desk.tscn` — mesh/collision size  
3. `grid_snapper.gd` — bounds check uses `DESK_STUDS`  
4. Re-export web build  

Changing snap feel:

1. `grid_snapper.gd` — `_min_stud_index`, footprints  
2. `build_grid.gd` — seat map  
3. `placement_preview.gd` — desktop feedback  
