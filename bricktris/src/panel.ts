import { createSystem, PanelUI, PanelDocument, eq, VisibilityState, UIKitDocument, UIKit } from "@iwsdk/core";

export class PanelSystem extends createSystem({
  brickPanel: {
    required: [PanelUI, PanelDocument],
    where: [eq(PanelUI, "config", "./ui/bricktris.json")],
  },
}) {
  init() {
    this.queries.brickPanel.subscribe("qualify", (entity) => {
      const document = PanelDocument.data.document[
        entity.index
      ] as UIKitDocument;
      if (!document) {
        return;
      }

      const xrButton = document.getElementById("xr-button") as UIKit.Text;
      if (!xrButton) return;

      xrButton.addEventListener("click", () => {
        if (this.world.visibilityState.value === VisibilityState.NonImmersive) {
          this.world.launchXR();
        } else {
          this.world.exitXR();
        }
      });
      this.world.visibilityState.subscribe((visibilityState) => {
        if (visibilityState === VisibilityState.NonImmersive) {
          xrButton.setProperties({ text: "Enter XR" });
        } else {
          xrButton.setProperties({ text: "Exit to Browser" });
        }
      });
    });
  }
}
