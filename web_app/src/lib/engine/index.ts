/**
 * The learning engine (domain only, no UI): a TypeScript port of kids_app
 * lib/features/play/domain. Plays the same `games.config` JSON as the Flutter app and reports
 * the same results to `POST /play/sync`.
 */
export * from "./types";
export * from "./rng";
export {
  dartStr,
  textFromJson,
  textOf,
  textIsEmpty,
  en,
  pictureFromJson,
  pictureScheme,
  pictureName,
  pictureParams,
  pictureColor,
  pictureSize,
  describePicture,
  promptFromJson,
  promptSpoken,
  choiceFromJson,
  choiceSpoken,
  makePolicy,
  policyForChild,
  PICTURE_COLORS,
  PICTURE_SIZES,
} from "./common";
export { KindRegistry, standardRegistry, defaultHint } from "./registry";
export {
  trimAndShuffle,
  numberWord,
  equationResult,
  equationText,
  equationSpoken,
  PHONICS,
  BLANK,
  SHAPES,
  SIDES,
} from "./kinds/choice";
export { fits, jigsawIndexOf, pieceOf } from "./kinds/arrange";
export { pairOf, dist, resample, checkpoints, glyphStrokes, KNOWN_GLYPHS, MIN_COVERAGE, MAX_STRAY, MAX_INK_RATIO } from "./kinds/memory-trace";
export * from "./source";
export * from "./engine";
export * from "./report";
