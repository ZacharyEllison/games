import * as THREE from "three";
import {
  AssetManifest,
  AssetType,
  Mesh,
  MeshBasicMaterial,
  PlaneGeometry,
  SessionMode,
  SRGBColorSpace,
  AssetManager,
  World,
  PhysicsBody,
  PhysicsState,
  PhysicsShape,
  PhysicsShapeType,
  Interactable,
  PanelUI,
  ScreenSpace,
  Transform,
  Vector3,
} from "@iwsdk/core";

import { Brick } from "./brick.js";
import { BRICK_DEFS } from "./brick-spawn.js";
import { BrickUISystem } from "./brick-ui.js";
import { BrickPlaceSystem } from "./brick-place.js";
import { BrickSpawnSystem } from "./brick-spawn.js";
import { TetrisGameStateSystem } from "./tetris-game.js";
import { PanelSystem } from "./panel.js";

const assets: AssetManifest = {
  brick1x1: {
    url: "/gltf/bricktris/bevel-hq-brick-1x1.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  brick1x2: {
    url: "/gltf/bricktris/bevel-hq-brick-1x2.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  brick2x2: {
    url: "/gltf/bricktris/bevel-hq-brick-2x2.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  brick1x4: {
    url: "/gltf/bricktris/bevel-hq-brick-1x4.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  plate1x1: {
    url: "/gltf/bricktris/bevel-hq-plate-1x1.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  brickCorner: {
    url: "/gltf/bricktris/bevel-hq-brick-corner.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
  brickSlope1x2: {
    url: "/gltf/bricktris/bevel-hq-brick-slope-1x2.glb",
    type: AssetType.GLTF,
    priority: "critical",
  },
};

// Canvas texture for grid lines on the desk surface
function createGridTexture() {
  const canvas = document.createElement("canvas");
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext("2d")!;

  // Dark background
  ctx.fillStyle = "#1a1a2e";
  ctx.fillRect(0, 0, 512, 512);

  // Grid lines
  ctx.strokeStyle = "#2a2a3e";
  ctx.lineWidth = 2;

  const gridSize = 512 / 12; // 12 grid cells
  for (let i = 0; i <= 12; i++) {
    ctx.beginPath();
    ctx.moveTo(i * gridSize, 0);
    ctx.lineTo(i * gridSize, 512);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, i * gridSize);
    ctx.lineTo(512, i * gridSize);
    ctx.stroke();
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = SRGBColorSpace;
  return texture;
}

World.create(document.getElementById("scene-container") as HTMLDivElement, {
  assets,
  xr: {
    sessionMode: SessionMode.ImmersiveAR,
    offer: "always",
    features: {
      handTracking: true,
      anchors: true,
      hitTest: true,
      planeDetection: true,
      meshDetection: false,
      layers: { required: true },
    },
  },
  features: {
    locomotion: false,
    grabbing: true,
    physics: true,
    sceneUnderstanding: true,
    environmentRaycast: true,
  },
}).then((world) => {
  const { camera } = world;
  camera.position.set(0, 1, 0.5);

  // --- Grid desk floor ---
  const deskWidth = 6;
  const deskDepth = 4;
  const deskThickness = 0.05;
  const deskGeometry = new THREE.BoxGeometry(deskWidth, deskThickness, deskDepth);
  const gridTexture = createGridTexture();
  const deskMaterial = new THREE.MeshStandardMaterial({
    map: gridTexture,
    roughness: 0.8,
    metalness: 0.1,
  });
  const deskMesh = new THREE.Mesh(deskGeometry, deskMaterial);
  deskMesh.position.set(0, -deskThickness / 2, 0);

  const deskEntity = world.createTransformEntity(deskMesh);
  deskEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  deskEntity.addComponent(
    PhysicsShape,
    {
      shape: PhysicsShapeType.Box,
      dimensions: [deskWidth, deskThickness, deskDepth],
    }
  );

  // --- Demo bricks pre-placed on the desk ---
  const demoBricks: Array<{ type: string; x: number; y: number; z: number }> = [
    { type: "brick1x1", x: 0, y: 1, z: 0 },
    { type: "brick1x2", x: 2, y: 1, z: 0 },
    { type: "brick2x2", x: -2, y: 1, z: 0 },
  ];

  for (const demo of demoBricks) {
    const brickDef = BRICK_DEFS[demo.type];
    if (!brickDef) continue;
    const scale = 15.0;
    const cell = scale;

    const { scene: brickMesh } = AssetManager.getGLTF(demo.type)!;
    brickMesh.scale.setScalar(scale);

    const entity = world.createTransformEntity(brickMesh);
    entity.object3D!.position.set(demo.x * cell, demo.y * cell, demo.z * cell);
    entity.object3D!.name = demo.type;
    entity.addComponent(Interactable);
    entity.addComponent(PhysicsBody, { state: PhysicsState.Dynamic, gravityFactor: 1.0, friction: 0.5, restitution: 0.1 });
    entity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Auto, dimensions: [0, 0, 0] });
    entity.addComponent(Brick, { isTetris: false });
  }

  // --- Tetris container zone (4 translucent walls) ---
  const containerWidth = 80;   // 5 cells
  const containerDepth = 120;  // 8 cells
  const containerHeight = 180; // 12 cells
  const wallThickness = 0.1;
  const containerY = containerHeight / 2;
  const halfW = containerWidth / 2;
  const halfD = containerDepth / 2;

  const wallMaterial = new THREE.MeshBasicMaterial({
    color: 0x60a5fa,
    transparent: true,
    opacity: 0.25,
    side: THREE.DoubleSide,
  });

  // Front wall (z = +halfD)
  const frontWall = new THREE.Mesh(
    new THREE.BoxGeometry(containerWidth, containerHeight, wallThickness),
    wallMaterial
  );
  frontWall.position.set(0, containerY, halfD);
  const frontWallEntity = world.createTransformEntity(frontWall);
  frontWallEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  frontWallEntity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Box, dimensions: [containerWidth, containerHeight, wallThickness] });

  // Back wall (z = -halfD)
  const backWall = new THREE.Mesh(
    new THREE.BoxGeometry(containerWidth, containerHeight, wallThickness),
    wallMaterial
  );
  backWall.position.set(0, containerY, -halfD);
  const backWallEntity = world.createTransformEntity(backWall);
  backWallEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  backWallEntity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Box, dimensions: [containerWidth, containerHeight, wallThickness] });

  // Left wall (x = -halfW)
  const leftWall = new THREE.Mesh(
    new THREE.BoxGeometry(wallThickness, containerHeight, containerDepth),
    wallMaterial
  );
  leftWall.position.set(-halfW, containerY, 0);
  const leftWallEntity = world.createTransformEntity(leftWall);
  leftWallEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  leftWallEntity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Box, dimensions: [wallThickness, containerHeight, containerDepth] });

  // Right wall (x = +halfW)
  const rightWall = new THREE.Mesh(
    new THREE.BoxGeometry(wallThickness, containerHeight, containerDepth),
    wallMaterial
  );
  rightWall.position.set(halfW, containerY, 0);
  const rightWallEntity = world.createTransformEntity(rightWall);
  rightWallEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  rightWallEntity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Box, dimensions: [wallThickness, containerHeight, containerDepth] });

  // --- Container floor (solid ground for tetris pieces) ---
  const floorGeometry = new THREE.BoxGeometry(containerWidth, wallThickness, containerDepth);
  const floorMesh = new THREE.Mesh(floorGeometry, wallMaterial);
  floorMesh.position.set(0, wallThickness / 2, 0);
  const floorEntity = world.createTransformEntity(floorMesh);
  floorEntity.addComponent(PhysicsBody, { state: PhysicsState.Static });
  floorEntity.addComponent(PhysicsShape, { shape: PhysicsShapeType.Box, dimensions: [containerWidth, wallThickness, containerDepth] });

  // --- Brick selection PanelUI ---
  const panelEntity = world
    .createTransformEntity()
    .addComponent(PanelUI, {
      config: "./ui/bricktris.json",
      maxHeight: 0.8,
      maxWidth: 1.6,
    })
    .addComponent(Interactable)
    .addComponent(ScreenSpace, {
      top: "20px",
      left: "20px",
      height: "40%",
    });
  panelEntity.object3D!.position.set(0, 1.29, -1.9);

  // --- Register systems ---
  world
    .registerSystem(BrickUISystem)
    .registerSystem(BrickPlaceSystem)
    .registerSystem(BrickSpawnSystem)
    .registerSystem(TetrisGameStateSystem)
    .registerSystem(PanelSystem);
});
