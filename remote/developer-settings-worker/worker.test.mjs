import assert from "node:assert/strict";
import test from "node:test";
import worker from "./src/worker.mjs";

const validPayload = {
  schemaVersion: 1,
  exportedAt: "2026-05-12T19:30:00Z",
  source: {
    appBundleIdentifier: "com.stacksdubeurre.CasualContacts",
    appVersion: "1.0.6",
    buildNumber: "3"
  },
  settings: {
    motion: { relativeFullScaleDegrees: 45, saveButtonGradientGain: 2.5, zeroPointSettleDuration: 2 },
    hologram: {
      backdropBlurOpacity: 1,
      whiteFillOpacity: 0.56,
      lightenOpacity: 0.2,
      luminosityOpacity: 0.35,
      translationScaleX: 90,
      translationScaleY: 90,
      rotationDegrees: 30
    },
    cardBackdrop: {
      depthScale: 5,
      hideBackdrop: false,
      reverseDepthOrder: false,
      reverseMotionDirection: true,
      rotationGuillocheMovesInsteadOfRotates: false,
      guillocheMovementScaleX: 0.8,
      guillocheMovementScaleY: 0.8
    },
    diagnostics: { showsCardAnimationOverlay: false },
    gradientAndFiligree: {
      emptyStateEdgeReach: 1,
      emptyStateRotationDegrees: 90,
      cardRotationDegrees: 45,
      emptyStateOpacity: 0.3,
      cardOpacity: 0.2,
      cardPhotoOpacity: 0.23
    },
    elementDepth: {
      perspectiveAmount: 1,
      isSkewEnabled: false,
      skewAmount: 0.08,
      moonPhaseLayer: 12,
      zodiacGlyphLayer: 4,
      zodiacConstellationLayer: 12
    },
    zodiacAndPhoto: { zodiacRotationDegrees: 300, photoFaceZoom: 0, photoOpacity: 0.35 },
    mediumCard: { aspectRatio: 1 }
  }
};

test("authorized POST stores payload in R2", async () => {
  const writes = [];
  const response = await worker.fetch(
    new Request("https://casualcontacts.app/api/developer-settings", {
      method: "POST",
      headers: {
        authorization: "Bearer secret",
        "content-type": "application/json"
      },
      body: JSON.stringify(validPayload)
    }),
    {
      DEVELOPER_SETTINGS_UPLOAD_TOKEN: "secret",
      DEVELOPER_SETTINGS_BUCKET: {
        put: async (key, value, options) => writes.push({ key, value, options })
      }
    }
  );

  assert.equal(response.status, 201);
  assert.equal(writes.length, 1);
  assert.match(writes[0].key, /^developer-settings\/2026-05-12T19-30-00-000Z-[a-f0-9-]+\.json$/);
  assert.equal(JSON.parse(writes[0].value).schemaVersion, 1);
  assert.equal(writes[0].options.httpMetadata.contentType, "application/json");
});

test("missing bearer token is rejected without storage write", async () => {
  const writes = [];
  const response = await worker.fetch(
    new Request("https://casualcontacts.app/api/developer-settings", {
      method: "POST",
      body: JSON.stringify(validPayload)
    }),
    {
      DEVELOPER_SETTINGS_UPLOAD_TOKEN: "secret",
      DEVELOPER_SETTINGS_BUCKET: {
        put: async (key, value, options) => writes.push({ key, value, options })
      }
    }
  );

  assert.equal(response.status, 401);
  assert.equal(writes.length, 0);
});
