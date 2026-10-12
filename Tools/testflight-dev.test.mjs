import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const pushScript = path.resolve("Tools/testflight-dev.sh");
const notesScript = path.resolve("CasualContacts/ci_scripts/ci_post_xcodebuild.sh");

function fixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cc-dev-testflight-"));
  const repo = path.join(root, "repo");
  fs.mkdirSync(path.join(repo, "Tools"), { recursive: true });
  fs.mkdirSync(path.join(repo, "CasualContacts/CasualContacts.xcodeproj"), { recursive: true });
  fs.copyFileSync(pushScript, path.join(repo, "Tools/testflight-dev.sh"));
  const git = (...args) => execFileSync("git", ["-C", repo, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  git("init", "-b", "main");
  git("add", "Tools/testflight-dev.sh");
  git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false", "commit", "-m", "Test branch build");
  try { run({ root, repo, git }); }
  finally { fs.rmSync(root, { recursive: true, force: true }); }
}

test("development helper refuses main and pending files", () => fixture(({ repo, git }) => {
  const run = () => execFileSync("bash", [path.join(repo, "Tools/testflight-dev.sh"), "--dry-run"], { stdio: ["ignore", "pipe", "pipe"] });
  assert.throws(run, error => /require a dev\/\* branch/.test(error.stderr.toString()));
  git("switch", "-c", "dev/cards");
  fs.writeFileSync(path.join(repo, "pending.txt"), "pending");
  assert.throws(run, error => /pending changes/.test(error.stderr.toString()));
}));

test("development helper pushes only its branch and creates no tags", () => fixture(({ root, repo, git }) => {
  const remote = path.join(root, "origin.git");
  execFileSync("git", ["init", "--bare", remote], { stdio: "pipe" });
  git("remote", "add", "origin", remote);
  git("switch", "-c", "dev/cards");
  const script = path.join(repo, "Tools/testflight-dev.sh");
  execFileSync("bash", [script, "--dry-run"], { stdio: "pipe" });
  assert.equal(git("ls-remote", "origin"), "");
  execFileSync("bash", [script], { stdio: "pipe" });
  assert.match(git("ls-remote", "origin"), /refs\/heads\/dev\/cards/);
  assert.doesNotMatch(git("ls-remote", "origin"), /refs\/heads\/main|refs\/tags/);
  assert.equal(git("tag", "--list"), "");
}));

test("development notes include branch, commit, and cloud build number", () => fixture(({ repo, git }) => {
  const env = {
    ...process.env, CI_XCODE_CLOUD: "TRUE", CI_XCODEBUILD_ACTION: "archive",
    CI_WORKFLOW: "Development TestFlight", CI_BRANCH: "dev/cards", CI_BUILD_NUMBER: "42",
    CI_PROJECT_FILE_PATH: path.join(repo, "CasualContacts/CasualContacts.xcodeproj")
  };
  execFileSync("sh", [notesScript], { env, stdio: "pipe" });
  const notes = fs.readFileSync(path.join(repo, "CasualContacts/TestFlight/WhatToTest.en-US.txt"), "utf8");
  assert.match(notes, /Branch: dev\/cards/);
  assert.ok(notes.includes(git("rev-parse", "--short", "HEAD").trim()));
  assert.match(notes, /Xcode Cloud build: 42/);
  assert.match(notes, /Test branch build/);
  assert.throws(() => execFileSync("sh", [notesScript], { env: { ...env, CI_BRANCH: "main" }, stdio: "pipe" }));
}));

test("release workflows do not generate development notes", () => fixture(({ repo }) => {
  execFileSync("sh", [notesScript], {
    env: { ...process.env, CI_XCODE_CLOUD: "TRUE", CI_XCODEBUILD_ACTION: "archive", CI_WORKFLOW: "Testflight Tagged Workflow" },
    stdio: "pipe"
  });
  assert.equal(fs.existsSync(path.join(repo, "CasualContacts/TestFlight")), false);
}));
