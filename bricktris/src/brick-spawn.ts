import { createSystem, Vector3, PhysicsBody, PhysicsState, PhysicsShape, PhysicsShapeType, OneHandGrabbable, Interactable, AssetManager, InputComponent } from "@iwsdk/core";
import { Brick } from "./brick.js";
import { signal } from "@preact/signals-core";

export const BRICK_DEFS: Record<string, { gridX: number; gridY: number; gridZ: number }> = {
  brick1x1: { gridX: 1, gridY: 1, gridZ: 1 },
  brick1x2: { gridX: 1, gridY: 1, gridZ: 2 },
  brick2x2: { gridX: 2, gridY: 1, gridZ: 2 },
  brick1x4: { gridX: 1, gridY: 1, gridZ: 4 },
  plate1x1: { gridX: 1, gridY: 0.5, gridZ: 1 },
  brickCorner: { gridX: 1, gridY: 1, gridZ: 1 },
  brickSlope1x2: { gridX: 1, gridY: 1, gridZ: 2 },
};

export class BrickSpawnSystem extends createSystem({}) {
  private spawnPos!: Vector3;

  init() {
    this.spawnPos = new Vector3();
    this.cleanupFuncs.push(
      this.world.input.xr.gamepads.right?.onButtonUp(InputComponent.Squeeze).subscribe(() => {
        this.trySpawnBrick();
      })
    );
  }

  trySpawnBrick() {
    const selectedType = (this.globals.selectedBrick as string);
    if (!selectedType) return;

    const brickDef = BRICK_DEFS[selectedType];
    if (!brickDef) return;

    const scale = (this.globals.brickScale as signal<number>).peek();
    const rightGrip = this.world.playerSpaceEntities.gripSpaces.right;
    if (!rightGrip) return;

    rightGrip.getWorldPosition(this.spawnPos);

    const cell = scale;
    this.spawnPos.x = Math.round(this.spawnPos.x / cell) * cell + ((brickDef.gridX / 2) - 0.5) * cell;
    this.spawnPos.y = Math.max(0, Math.round(this.spawnPos.y / cell) * cell);
    this.spawnPos.z = Math.round(this.spawnPos.z / cell) * cell + ((brickDef.gridZ / 2) - 0.5) * cell;

    const { scene: brickMesh } = AssetManager.getGLTF(selectedType)!;
    brickMesh.scale.setScalar(scale);

    const entity = this.world.createTransformEntity(brickMesh);
    entity.object3D!.name = selectedType;
    entity.addComponent(OneHandGrabbable, {});
    entity.addComponent(Interactable);
    entity.addComponent(PhysicsBody, { state: PhysicsState.Dynamic, gravityFactor: 1.0, friction: 0.5, restitution: 0.1 });
    entity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Auto, dimensions: [0, 0, 0] });
    entity.addComponent(Brick, { isTetris: false });
  }
}
