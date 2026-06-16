import { createSystem, Vector3, PhysicsBody, PhysicsState, Entity } from "@iwsdk/core";
import { Brick } from "./brick.js";
import { Grabbed } from "@iwsdk/core";
import { signal } from "@preact/signals-core";

const SPAWN_DEFS: Record<string, { gridX: number; gridZ: number }> = {
  brick1x1: { gridX: 1, gridZ: 1 },
  brick1x2: { gridX: 1, gridZ: 2 },
  brick2x2: { gridX: 2, gridZ: 2 },
  brick1x4: { gridX: 1, gridZ: 4 },
  plate1x1: { gridX: 1, gridZ: 1 },
  brickCorner: { gridX: 1, gridZ: 1 },
  brickSlope1x2: { gridX: 1, gridZ: 2 },
};

export class BrickPlaceSystem extends createSystem({
  grabbedBricks: { required: [Brick, Grabbed] },
}) {
  private snapPos!: Vector3;

  init() {
    this.snapPos = new Vector3();
    this.queries.grabbedBricks.subscribe("disqualify", (entity: Entity) => {
      const obj = entity.object3D!;
      const scale = (this.globals.brickScale as signal<number>).peek();
      const cell = scale;

      const name = entity.object3D?.name || "";
      const offsetData = SPAWN_DEFS[name] ?? { gridX: 1, gridZ: 1 };

      obj.position.x = Math.round(obj.position.x / cell) * cell + ((offsetData.gridX / 2) - 0.5) * cell;
      obj.position.y = Math.max(0, Math.round(obj.position.y / cell) * cell);
      obj.position.z = Math.round(obj.position.z / cell) * cell + ((offsetData.gridZ / 2) - 0.5) * cell;

      // Enable physics for stacking (brick was held in place by grab, now falls)
      entity.setValue(PhysicsBody, "state", PhysicsState.Dynamic);
    });
  }
}
