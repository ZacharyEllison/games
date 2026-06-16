import { createComponent, Types } from "@iwsdk/core";

export const Brick = createComponent("Brick", {
  isTetris: { type: Types.Boolean, default: false },
});
