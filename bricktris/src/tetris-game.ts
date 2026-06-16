import { createSystem, PhysicsBody, PhysicsState, PhysicsShape, PhysicsShapeType, OneHandGrabbable, Interactable, Vector3, AssetManager, eq, PanelUI, PanelDocument, UIKitDocument, Grabbed } from "@iwsdk/core";
import { Brick } from "./brick.js";
import { signal } from "@preact/signals-core";

export const BRICK_DEFS: Record<string, { gridX: number; gridY: number; gridZ: number }> = {
  brick1x1: { gridX: 1, gridY: 1, gridZ: 1 },
  brick1x2: { gridX: 1, gridY: 1, gridZ: 2 },
  brick2x2: { gridX: 2, gridY: 1, gridZ: 2 },
  brick1x4: { gridX: 1, gridY: 1, gridZ: 4 },
  plate1x1: { gridX: 1, gridY: 0.5, gridZ: 1 },
};

function getBrickDef(name: string): { gridX: number; gridY: number; gridZ: number } | undefined {
  return BRICK_DEFS[name];
}

export class TetrisGameStateSystem extends createSystem({
  grabbedTetrisBricks: { required: [Brick, Grabbed] },
  brickPanel: {
    required: [PanelUI, PanelDocument],
    where: [eq(PanelUI, "config", "./ui/bricktris.json")],
  },
  allTetrisBricks: { required: [Brick] },
}) {
  private spawnPos!: Vector3;
  private containerBounds: { minX: number; maxX: number; minZ: number; maxZ: number; maxHeight: number } = {
    minX: -40,
    maxX: 40,
    minZ: -60,
    maxZ: 60,
    maxHeight: 180,
  };
  private tetrisQueue: string[] = [];
  private score: number = 0;
  private layersCleared: number = 0;
  private gameOver: boolean = false;
  private layerCheckInterval: number = 0;

  init() {
    this.spawnPos = new Vector3();
  }

  startTetris() {
    this.tetrisQueue = [];
    this.fillQueue();
    this.score = 0;
    this.layersCleared = 0;
    this.gameOver = false;
    this.layerCheckInterval = 0;
    this.spawnNextBrick();
  }

  fillQueue() {
    while (this.tetrisQueue.length < 3) {
      const types = ["brick1x1", "brick1x2", "brick2x2", "brick1x4", "plate1x1"];
      this.tetrisQueue.push(types[Math.floor(Math.random() * types.length)]);
    }
  }

  spawnNextBrick() {
    if (this.tetrisQueue.length === 0) this.fillQueue();
    const selectedType = this.tetrisQueue.shift()!;
    const brickDef = BRICK_DEFS[selectedType];
    if (!brickDef) return;

    const scale = (this.globals.brickScale as signal<number>).peek();
    const centerX = (this.containerBounds.maxX + this.containerBounds.minX) / 2;
    const centerZ = (this.containerBounds.maxZ + this.containerBounds.minZ) / 2;
    const spawnY = this.containerBounds.maxHeight + scale * 1.5;

    this.spawnPos.set(centerX, spawnY, centerZ);

    const { scene: brickMesh } = AssetManager.getGLTF(selectedType)!;
    brickMesh.scale.setScalar(scale);

    const entity = this.world.createTransformEntity(brickMesh);
    entity.object3D!.position.copy(this.spawnPos);
    entity.object3D!.name = selectedType;
    entity.addComponent(OneHandGrabbable, {});
    entity.addComponent(Interactable);
    entity.addComponent(PhysicsBody, { state: PhysicsState.Dynamic, gravityFactor: 1.0, friction: 0.5, restitution: 0.1 });
    entity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Auto, dimensions: [0, 0, 0] });
    entity.addComponent(Brick, { isTetris: true });
  }

  update(_delta: number, _time: number) {
    // Check for layer clears every 1 second (~60 frames at 60fps)
    this.layerCheckInterval++;
    if (this.layerCheckInterval >= 60) {
      this.layerCheckInterval = 0;
      this.checkLayerClears();
      this.checkGameOver();
      this.updateUI();
    }
  }

  checkLayerClears() {
    const scale = (this.globals.brickScale as signal<number>).peek();
    const cell = scale;
    const gridWidth = Math.round((this.containerBounds.maxX - this.containerBounds.minX) / cell);
    const gridDepth = Math.round((this.containerBounds.maxZ - this.containerBounds.minZ) / cell);
    const gridHeight = Math.round(this.containerBounds.maxHeight / cell);

    // For each Y layer, count how many grid cells are occupied
    for (let layer = 0; layer < gridHeight; layer++) {
      const layerY = (layer + 0.5) * cell;
      let filledCount = 0;

      for (const brick of this.queries.allTetrisBricks.entities) {
        const brickComp = brick.getValue(Brick);
        if (!brickComp) continue;
        if (!brickComp.isTetris) continue;

        const brickY = brick.object3D!.position.y;
        const brickDef = getBrickDef(brick.object3D!.name!);
        if (!brickDef) continue;

        // This brick occupies this layer if its Y range overlaps
        const brickBottom = brickY - (brickDef.gridY / 2) * cell;
        const brickTop = brickY + (brickDef.gridY / 2) * cell;

        if (brickBottom <= layerY && brickTop >= layerY) {
          filledCount += brickDef.gridX * brickDef.gridZ;
        }
      }

      if (filledCount >= gridWidth * gridDepth) {
        // Full layer -- clear it
        this.clearLayer(layer, layerY, cell);
        this.score += gridWidth * gridDepth * 10;
        this.layersCleared++;
      }
    }
  }

  clearLayer(_layer: number, layerY: number, cell: number) {
    for (const brick of this.queries.allTetrisBricks.entities) {
      const brickComp = brick.getValue(Brick);
      if (!brickComp) continue;
      if (!brickComp.isTetris) continue;

      const brickY = brick.object3D!.position.y;
      const brickDef = getBrickDef(brick.object3D!.name!);
      if (!brickDef) continue;

      const brickBottom = brickY - (brickDef.gridY / 2) * cell;
      const brickTop = brickY + (brickDef.gridY / 2) * cell;

      if (Math.abs(brickY - layerY) < cell * 0.75) {
        brick.dispose();
      }
    }
  }

  checkGameOver() {
    if (this.gameOver) return;
    const scale = (this.globals.brickScale as signal<number>).peek();
    const threshold = this.containerBounds.maxHeight * 0.8;

    for (const brick of this.queries.allTetrisBricks.entities) {
      if (!brick.object3D) continue;
      const brickY = brick.object3D!.position.y;
      if (brickY > threshold) {
        this.gameOver = true;
        break;
      }
    }
  }

  updateUI() {
    this.queries.brickPanel.subscribe("qualify", (entity) => {
      const doc = PanelDocument.data.document[entity.index] as UIKitDocument;
      const scoreEl = doc.getElementById("stat-score") as HTMLElement;
      const layersEl = doc.getElementById("stat-layers") as HTMLElement;
      if (scoreEl) scoreEl.textContent = String(this.score);
      if (layersEl) layersEl.textContent = String(this.layersCleared);
    });
  }
}
