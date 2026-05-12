import assert from "node:assert/strict";
import test from "node:test";
import { generateDefaultsSources, validateSnapshot } from "./developer-settings-ingest.mjs";

const snapshot = {
  schemaVersion: 1,
  exportedAt: "2026-05-12T19:30:00Z",
  source: { appBundleIdentifier: "tests", appVersion: "1", buildNumber: "1" },
  settings: {
    motion: { relativeFullScaleDegrees: 61, saveButtonGradientGain: 3.25, zeroPointSettleDuration: 1.5 },
    hologram: {
      backdropBlurOpacity: 0.91,
      whiteFillOpacity: 0.42,
      lightenOpacity: 0.17,
      luminosityOpacity: 0.29,
      translationScaleX: 111,
      translationScaleY: 88,
      rotationDegrees: 45
    },
    cardBackdrop: {
      depthScale: 7,
      hideBackdrop: true,
      reverseDepthOrder: true,
      reverseMotionDirection: false,
      rotationGuillocheMovesInsteadOfRotates: true,
      guillocheMovementScaleX: 0.66,
      guillocheMovementScaleY: 1.4
    },
    diagnostics: { showsCardAnimationOverlay: true },
    gradientAndFiligree: {
      emptyStateEdgeReach: 0.72,
      emptyStateRotationDegrees: 80,
      cardRotationDegrees: 31,
      emptyStateOpacity: 0.2,
      cardOpacity: 0.13,
      cardPhotoOpacity: 0.22
    },
    elementDepth: {
      perspectiveAmount: 1.7,
      isSkewEnabled: true,
      skewAmount: 0.12,
      moonPhaseLayer: 10,
      zodiacGlyphLayer: 3,
      zodiacConstellationLayer: 14
    },
    zodiacAndPhoto: { zodiacRotationDegrees: 250, photoFaceZoom: 0.34, photoOpacity: 0.44 },
    mediumCard: { aspectRatio: 1.2 }
  }
};

test("validateSnapshot accepts complete schema version one payloads", () => {
  assert.doesNotThrow(() => validateSnapshot(snapshot));
});

test("validateSnapshot rejects missing nested settings", () => {
  const invalid = structuredClone(snapshot);
  delete invalid.settings.motion.relativeFullScaleDegrees;

  assert.throws(() => validateSnapshot(invalid), /settings\.motion\.relativeFullScaleDegrees/);
});

test("generateDefaultsSources emits CoreModels and Visuals Swift defaults", () => {
  const generated = generateDefaultsSources(snapshot);

  assert.match(generated.coreModels, /public enum CoreDeveloperSettingsDefaults/);
  assert.match(generated.coreModels, /relativeFullScaleDegrees: 61/);
  assert.match(generated.visuals, /public enum VisualDeveloperSettingsDefaults/);
  assert.match(generated.visuals, /hideBackdrop: true/);
  assert.match(generated.visuals, /photoOpacity: 0.44/);
});
