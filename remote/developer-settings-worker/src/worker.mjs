const REQUIRED_NUMBER_PATHS = [
  "settings.motion.relativeFullScaleDegrees",
  "settings.motion.saveButtonGradientGain",
  "settings.motion.zeroPointSettleDuration",
  "settings.hologram.backdropBlurOpacity",
  "settings.hologram.whiteFillOpacity",
  "settings.hologram.lightenOpacity",
  "settings.hologram.luminosityOpacity",
  "settings.hologram.translationScaleX",
  "settings.hologram.translationScaleY",
  "settings.hologram.rotationDegrees",
  "settings.cardBackdrop.depthScale",
  "settings.cardBackdrop.guillocheMovementScaleX",
  "settings.cardBackdrop.guillocheMovementScaleY",
  "settings.gradientAndFiligree.emptyStateEdgeReach",
  "settings.gradientAndFiligree.emptyStateRotationDegrees",
  "settings.gradientAndFiligree.cardRotationDegrees",
  "settings.gradientAndFiligree.emptyStateOpacity",
  "settings.gradientAndFiligree.cardOpacity",
  "settings.gradientAndFiligree.cardPhotoOpacity",
  "settings.elementDepth.perspectiveAmount",
  "settings.elementDepth.skewAmount",
  "settings.zodiacAndPhoto.zodiacRotationDegrees",
  "settings.zodiacAndPhoto.photoFaceZoom",
  "settings.zodiacAndPhoto.photoOpacity",
  "settings.mediumCard.aspectRatio"
];

const REQUIRED_BOOLEAN_PATHS = [
  "settings.cardBackdrop.hideBackdrop",
  "settings.cardBackdrop.reverseDepthOrder",
  "settings.cardBackdrop.reverseMotionDirection",
  "settings.cardBackdrop.rotationGuillocheMovesInsteadOfRotates",
  "settings.diagnostics.showsCardAnimationOverlay",
  "settings.elementDepth.isSkewEnabled"
];

const REQUIRED_INTEGER_PATHS = [
  "schemaVersion",
  "settings.elementDepth.moonPhaseLayer",
  "settings.elementDepth.zodiacGlyphLayer",
  "settings.elementDepth.zodiacConstellationLayer"
];

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    if (!authorized(request, env.DEVELOPER_SETTINGS_UPLOAD_TOKEN)) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }

    let payload;
    try {
      payload = await request.json();
      validatePayload(payload);
    } catch (error) {
      return json({ ok: false, error: "invalid_payload", detail: error.message }, 400);
    }

    const key = storageKey(payload);
    await env.DEVELOPER_SETTINGS_BUCKET.put(key, JSON.stringify(payload, null, 2) + "\n", {
      httpMetadata: { contentType: "application/json" },
      customMetadata: {
        appVersion: String(payload.source?.appVersion ?? ""),
        buildNumber: String(payload.source?.buildNumber ?? "")
      }
    });

    return json({ ok: true, key }, 201);
  }
};

function authorized(request, token) {
  if (!token) return false;
  return request.headers.get("authorization") === `Bearer ${token}`;
}

function storageKey(payload) {
  const exportedAt = new Date(payload.exportedAt);
  const stamp = Number.isNaN(exportedAt.valueOf())
    ? new Date().toISOString()
    : exportedAt.toISOString();
  const safeStamp = stamp.replace(/[:.]/g, "-");
  return `developer-settings/${safeStamp}-${crypto.randomUUID()}.json`;
}

function validatePayload(payload) {
  if (!payload || typeof payload !== "object") {
    throw new Error("payload must be an object");
  }

  for (const path of REQUIRED_INTEGER_PATHS) {
    const value = valueAt(payload, path);
    if (!Number.isInteger(value)) {
      throw new Error(`${path} must be an integer`);
    }
  }

  if (payload.schemaVersion !== 1) {
    throw new Error("schemaVersion must be 1");
  }

  if (Number.isNaN(new Date(payload.exportedAt).valueOf())) {
    throw new Error("exportedAt must be an ISO date");
  }

  for (const path of ["source.appBundleIdentifier", "source.appVersion", "source.buildNumber"]) {
    if (typeof valueAt(payload, path) !== "string") {
      throw new Error(`${path} must be a string`);
    }
  }

  for (const path of REQUIRED_NUMBER_PATHS) {
    if (typeof valueAt(payload, path) !== "number") {
      throw new Error(`${path} must be a number`);
    }
  }

  for (const path of REQUIRED_BOOLEAN_PATHS) {
    if (typeof valueAt(payload, path) !== "boolean") {
      throw new Error(`${path} must be a boolean`);
    }
  }
}

function valueAt(object, path) {
  return path.split(".").reduce((value, part) => value?.[part], object);
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" }
  });
}
