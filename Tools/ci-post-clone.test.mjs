import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const script = path.resolve("CasualContacts/ci_scripts/ci_post_clone.sh");

function projectEnvironment(workspace, overrides = {}) {
  fs.mkdirSync(path.join(workspace, "CasualContacts/CasualContacts.xcodeproj"), { recursive: true });

  return {
    ...process.env,
    CI: "TRUE",
    CI_XCODE_CLOUD: "TRUE",
    CI_PROJECT_FILE_PATH: path.join(workspace, "CasualContacts/CasualContacts.xcodeproj"),
    ...overrides
  };
}

test("ci_post_clone writes xcconfig-safe developer settings upload URL", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    execFileSync("sh", [script], {
      cwd: workspace,
      env: projectEnvironment(workspace, {
        CI_XCODEBUILD_ACTION: "archive",
        CI_WORKFLOW: "Testflight Tagged Workflow",
        CC_DEVELOPER_SETTINGS_UPLOAD_URL: "https://casualcontacts.app/api/developer-settings",
        CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN: "test-token"
      })
    });

    const config = fs.readFileSync(
      path.join(workspace, "CasualContacts/Config/DeveloperSettingsUpload.xcconfig"),
      "utf8"
    );

    assert.match(config, /CC_DEVELOPER_SETTINGS_UPLOAD_URL = https:\/\$\(\)\/casualcontacts\.app\/api\/developer-settings/);
    assert.doesNotMatch(config, /https:\/\//);
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});

test("ci_post_clone ignores upload variables outside TestFlight archives", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    execFileSync("sh", [script], {
      cwd: workspace,
      env: projectEnvironment(workspace, {
        CI_XCODEBUILD_ACTION: "build",
        CI_WORKFLOW: "Testflight Tagged Workflow",
        CC_DEVELOPER_SETTINGS_UPLOAD_URL: "https://casualcontacts.app/api/developer-settings",
        CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN: "test-token"
      })
    });

    assert.equal(
      fs.existsSync(path.join(workspace, "CasualContacts/Config/DeveloperSettingsUpload.xcconfig")),
      false
    );
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});

test("ci_post_clone fails TestFlight archives when secrets are missing", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    assert.throws(
      () => execFileSync("sh", [script], {
        cwd: workspace,
        env: projectEnvironment(workspace, {
          CI_XCODEBUILD_ACTION: "archive",
          CI_WORKFLOW: "Testflight Tagged Workflow"
        }),
        stdio: ["ignore", "pipe", "pipe"]
      }),
      (error) => {
        assert.equal(error.status, 1);
        const stderr = error.stderr.toString();
        assert.match(stderr, /CC_DEVELOPER_SETTINGS_UPLOAD_URL/);
        assert.match(stderr, /CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN/);
        return true;
      }
    );

    assert.equal(
      fs.existsSync(path.join(workspace, "CasualContacts/Config/DeveloperSettingsUpload.xcconfig")),
      false
    );
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});
