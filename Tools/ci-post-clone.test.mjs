import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const script = path.resolve("CasualContacts/ci_scripts/ci_post_clone.sh");

test("development archives use the next patch version only in the cloud checkout", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    const env = projectEnvironment(workspace, {
      CI_XCODEBUILD_ACTION: "archive", CI_WORKFLOW: "Development TestFlight", CI_BRANCH: "dev/cards",
      CC_DEVELOPER_SETTINGS_UPLOAD_URL: "https://example.invalid/upload",
      CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN: "test-token"
    });
    const project = path.join(env.CI_PROJECT_FILE_PATH, "project.pbxproj");
    fs.writeFileSync(project, "MARKETING_VERSION = 1.0.9;\nMARKETING_VERSION = 1.0.9;\n");
    execFileSync("sh", [script], { env, stdio: "pipe" });
    assert.equal(fs.readFileSync(project, "utf8"), "MARKETING_VERSION = 1.0.10;\nMARKETING_VERSION = 1.0.10;\n");
    fs.writeFileSync(project, "MARKETING_VERSION = 1.0.9;\n");
    execFileSync("sh", [script], { env: { ...env, CI_WORKFLOW: "Testflight Tagged Workflow" }, stdio: "pipe" });
    assert.equal(fs.readFileSync(project, "utf8"), "MARKETING_VERSION = 1.0.9;\n");
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});

test("development archives fail clearly for an invalid marketing version", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    const env = projectEnvironment(workspace, {
      CI_XCODEBUILD_ACTION: "archive", CI_WORKFLOW: "Development TestFlight", CI_BRANCH: "dev/cards"
    });
    fs.writeFileSync(path.join(env.CI_PROJECT_FILE_PATH, "project.pbxproj"), "MARKETING_VERSION = invalid;\n");
    assert.throws(() => execFileSync("sh", [script], { env, stdio: "pipe" }),
      error => /could not calculate/.test(error.stderr.toString()));
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});

test("development workflow refuses a main branch build before writing config", () => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "cc-ci-post-clone-"));
  try {
    assert.throws(() => execFileSync("sh", [script], {
      env: projectEnvironment(workspace, {
        CI_XCODEBUILD_ACTION: "archive", CI_WORKFLOW: "Development TestFlight", CI_BRANCH: "main"
      }), stdio: "pipe"
    }), error => /requires a dev\/\* branch/.test(error.stderr.toString()));
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
});

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
