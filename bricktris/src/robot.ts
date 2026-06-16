import {
  AudioUtils,
  createComponent,
  createSystem,
  Pressed,
} from "@iwsdk/core";

export const Robot = createComponent("Robot", {});

export class RobotSystem extends createSystem({
  robot: { required: [Robot] },
  robotClicked: { required: [Robot, Pressed] },
}) {
  init() {
    this.queries.robotClicked.subscribe("qualify", (entity) => {
      AudioUtils.play(entity);
    });
  }
}
