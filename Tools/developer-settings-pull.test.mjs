import assert from "node:assert/strict";
import test from "node:test";
import {
  buildDownloadPlan,
  buildReviewIndex,
  collectListedObjects,
  selectAccountId,
  snapshotSummary
} from "./developer-settings-pull.mjs";

test("selectAccountId uses the explicit account id when present", () => {
  const whoami = {
    accounts: [
      { id: "account-a", name: "A" },
      { id: "account-b", name: "B" }
    ]
  };

  assert.equal(selectAccountId(whoami, "account-b"), "account-b");
});

test("selectAccountId uses the only authenticated account", () => {
  assert.equal(selectAccountId({ accounts: [{ id: "account-a" }] }), "account-a");
});

test("selectAccountId requires --account when multiple accounts are available", () => {
  assert.throws(
    () => selectAccountId({ accounts: [{ id: "account-a" }, { id: "account-b" }] }),
    /Pass --account/
  );
});

test("collectListedObjects follows Cloudflare cursor pagination", async () => {
  const cursors = [];
  const objects = await collectListedObjects(async ({ cursor }) => {
    cursors.push(cursor ?? null);
    if (!cursor) {
      return {
        success: true,
        result: [{ key: "developer-settings/older.json", last_modified: "2026-05-23T01:00:00Z" }],
        result_info: { is_truncated: true, cursor: "next-page" }
      };
    }

    return {
      success: true,
      result: [{ key: "developer-settings/newer.json", last_modified: "2026-05-23T02:00:00Z" }],
      result_info: { is_truncated: false }
    };
  });

  assert.deepEqual(cursors, [null, "next-page"]);
  assert.deepEqual(
    objects.map((object) => object.key),
    ["developer-settings/older.json", "developer-settings/newer.json"]
  );
});

test("buildDownloadPlan sorts newest first and writes safe local JSON filenames", () => {
  const plan = buildDownloadPlan(
    [
      { key: "developer-settings/2026-05-23T01-00-00.json", last_modified: "2026-05-23T01:00:00Z" },
      { key: "developer-settings/2026-05-23T02-00-00.json", last_modified: "2026-05-23T02:00:00Z" }
    ],
    "developer-settings-downloads"
  );

  assert.deepEqual(
    plan.map((entry) => entry.key),
    ["developer-settings/2026-05-23T02-00-00.json", "developer-settings/2026-05-23T01-00-00.json"]
  );
  assert.equal(plan[0].file, "developer-settings-downloads/2026-05-23T02-00-00.json");
});

test("buildDownloadPlan can separate review paths from absolute download paths", () => {
  const [entry] = buildDownloadPlan(
    [{ key: "developer-settings/newer.json", last_modified: "2026-05-23T02:00:00Z" }],
    "developer-settings-downloads",
    { fileBaseDir: "/repo/developer-settings-downloads" }
  );

  assert.equal(entry.file, "developer-settings-downloads/newer.json");
  assert.equal(entry.downloadFile, "/repo/developer-settings-downloads/newer.json");
});

test("snapshotSummary exposes review metadata without settings values", () => {
  const summary = snapshotSummary({
    schemaVersion: 1,
    exportedAt: "2026-05-23T02:00:00Z",
    source: {
      appBundleIdentifier: "com.example.App",
      appVersion: "1.2.3",
      buildNumber: "9"
    },
    settings: {
      motion: { relativeFullScaleDegrees: 61 },
      hologram: { backdropBlurOpacity: 0.5 }
    }
  });

  assert.deepEqual(summary, {
    schemaVersion: 1,
    exportedAt: "2026-05-23T02:00:00Z",
    source: {
      appBundleIdentifier: "com.example.App",
      appVersion: "1.2.3",
      buildNumber: "9"
    },
    sectionCounts: {
      hologram: 1,
      motion: 1
    }
  });
});

test("buildReviewIndex combines object metadata with downloaded snapshot summaries", () => {
  const objects = [
    {
      key: "developer-settings/newer.json",
      etag: "etag-newer",
      last_modified: "2026-05-23T02:00:00Z",
      size: 456,
      custom_metadata: { appVersion: "1.2.3", buildNumber: "9" }
    }
  ];
  const summariesByKey = new Map([
    [
      "developer-settings/newer.json",
      {
        schemaVersion: 1,
        exportedAt: "2026-05-23T01:59:59Z",
        source: {
          appBundleIdentifier: "com.example.App",
          appVersion: "1.2.3",
          buildNumber: "9"
        },
        sectionCounts: { motion: 3 }
      }
    ]
  ]);

  assert.deepEqual(
    buildReviewIndex({
      bucket: "bucket",
      prefix: "developer-settings/",
      generatedAt: "2026-05-23T03:00:00Z",
      objects,
      outputDir: "developer-settings-downloads",
      summariesByKey
    }),
    {
      generatedAt: "2026-05-23T03:00:00Z",
      bucket: "bucket",
      prefix: "developer-settings/",
      count: 1,
      submissions: [
        {
          key: "developer-settings/newer.json",
          file: "developer-settings-downloads/newer.json",
          uploadedAt: "2026-05-23T02:00:00Z",
          size: 456,
          etag: "etag-newer",
          appVersion: "1.2.3",
          buildNumber: "9",
          snapshot: {
            schemaVersion: 1,
            exportedAt: "2026-05-23T01:59:59Z",
            source: {
              appBundleIdentifier: "com.example.App",
              appVersion: "1.2.3",
              buildNumber: "9"
            },
            sectionCounts: { motion: 3 }
          }
        }
      ]
    }
  );
});
