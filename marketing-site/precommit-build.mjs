#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const MARKETING_SITE_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.dirname(MARKETING_SITE_DIR);

const PIPELINE_PREFIXES = ["marketing-site/src/"];
const PIPELINE_FILES = ["marketing-site/build.mjs"];

export const GENERATED_SITE_PATHS = [
  "marketing-site/index.html",
  "marketing-site/privacy.html",
  "marketing-site/support.html",
  "marketing-site/ru/index.html",
  "marketing-site/ru/privacy.html",
  "marketing-site/ru/support.html",
  "marketing-site/uk/index.html",
  "marketing-site/uk/privacy.html",
  "marketing-site/uk/support.html",
];

export function shouldBuildMarketingSite(stagedPaths) {
  return stagedPaths.some((stagedPath) => (
    PIPELINE_FILES.includes(stagedPath)
    || PIPELINE_PREFIXES.some((prefix) => stagedPath.startsWith(prefix))
  ));
}

export function stagedPaths({ repoRoot = REPO_ROOT } = {}) {
  const result = spawnSync(
    "git",
    ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
    { cwd: repoRoot, encoding: "utf8" },
  );

  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || "Unable to read staged files");
  }

  return result.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

export function runPreCommitMarketingBuild({
  repoRoot = REPO_ROOT,
  marketingSiteDir = MARKETING_SITE_DIR,
} = {}) {
  const staged = stagedPaths({ repoRoot });

  if (!shouldBuildMarketingSite(staged)) {
    return false;
  }

  console.log("Marketing site pipeline changed; regenerating generated pages.");
  run("node", ["build.mjs"], { cwd: marketingSiteDir });
  run("git", ["add", ...GENERATED_SITE_PATHS], { cwd: repoRoot });
  return true;
}

function run(command, args, options) {
  const result = spawnSync(command, args, { ...options, stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    runPreCommitMarketingBuild();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
