import { createSystem, PanelUI, PanelDocument, eq, UIKitDocument } from "@iwsdk/core";
import { Brick } from "./brick.js";
import { signal } from "@preact/signals-core";

export class BrickUISystem extends createSystem({
  brickPanel: {
    required: [PanelUI, PanelDocument],
    where: [eq(PanelUI, "config", "./ui/bricktris.json")],
  },
  allBricks: { required: [Brick] },
}) {
  init() {
    (this.globals as Record<string, unknown>).selectedBrick = "brick1x1";
    (this.globals as Record<string, unknown>).brickScale = signal(15.0);
    (this.globals as Record<string, unknown>).gameMode = "build";

    this.queries.brickPanel.subscribe("qualify", (entity) => {
      const doc = PanelDocument.data.document[entity.index] as UIKitDocument;
      const scaleSignal = this.globals.brickScale as signal<number>;
      const modeSignal = this.globals.gameMode as signal<string>;

      // Brick selection
      const brickButtons = doc.querySelectorAll(".brick-btn[data-type]");
      brickButtons.forEach((btn: HTMLElement) => {
        btn.addEventListener("click", () => {
          const type = btn.getAttribute("data-type");
          if (type) {
            (this.globals.selectedBrick as string) = type;
            brickButtons.forEach((b: HTMLElement) => b.setProperties({ class: "brick-btn" }));
            btn.setProperties({ class: "brick-btn selected" });
          }
        });
      });

      // Mode switching
      const modeButtons = doc.querySelectorAll(".mode-btn[data-mode]");
      modeButtons.forEach((btn: HTMLElement) => {
        btn.addEventListener("click", () => {
          const mode = btn.getAttribute("data-mode");
          if (!mode) return;
          (this.globals.gameMode as string) = mode;
          modeButtons.forEach((b: HTMLElement) => b.setProperties({ class: "mode-btn" }));
          btn.setProperties({ class: "mode-btn active" });
        });
      });

      // Scale controls
      const scaleDown = doc.getElementById("scale-down") as HTMLElement;
      const scaleUp = doc.getElementById("scale-up") as HTMLElement;
      const scaleValue = doc.getElementById("scale-value") as HTMLElement;

      scaleDown?.addEventListener("click", () => {
        scaleSignal.value = Math.max(3, scaleSignal.value - 3);
        scaleValue.textContent = String(Math.round(scaleSignal.value));
      });

      scaleUp?.addEventListener("click", () => {
        scaleSignal.value = Math.min(60, scaleSignal.value + 3);
        scaleValue.textContent = String(Math.round(scaleSignal.value));
      });

      // Reset button -- dispose all brick entities
      const resetBtn = doc.getElementById("reset-btn") as HTMLElement;
      resetBtn.addEventListener("click", () => {
        for (const brickEntity of this.queries.allBricks.entities) {
          brickEntity.dispose();
        }
      });
    });
  }
}
