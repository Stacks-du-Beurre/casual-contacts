#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { validateSnapshot } from "./developer-settings-ingest.mjs";

const execFileAsync = promisify(execFile);

export const DEFAULT_BUCKET = "casual-contacts-developer-settings";
export const DEFAULT_PREFIX = "developer-settings/";
export const DEFAULT_OUTPUT_DIR = "developer-settings-downloads";
const DEFAULT_WRANGLER_CWD = "remote/developer-settings-worker";

export function selectAccountId(whoami, requestedAccountId) {
  const accounts = Array.isArray(whoami?.accounts) ? whoami.accounts : [];

  if (requestedAccountId) {
    if (accounts.length > 0 && !accounts.some((account) => account.id === requestedAccountId)) {
      throw new Error(`Wrangler is not logged into account ${requestedAccountId}.`);
    }
    return requestedAccountId;
  }

  if (accounts.length === 1) {
    return accounts[0].id;
  }

  if (accounts.length === 0) {
    throw new Error("Wrangler is not logged into a Cloudflare account.");
  }

  const accountList = accounts.map((account) => `${account.name ?? "unnamed"} (${account.id})`).join(", ");
  throw new Error(`Multiple Cloudflare accounts are available. Pass --account <id>. Accounts: ${accountList}`);
}

export async function collectListedObjects(fetchPage) {
  const objects = [];
  let cursor;

  while (true) {
    const page = await fetchPage({ cursor });
    if (!page?.success) {
      const details = JSON.stringify(page?.errors ?? page ?? {}, null, 2);
      throw new Error(`Cloudflare R2 object listing failed: ${details}`);
    }

    objects.push(...(page.result ?? []));

    const resultInfo = page.result_info ?? {};
    if (!resultInfo.is_truncated) {
      return objects;
    }

    if (!resultInfo.cursor) {
      throw new Error("Cloudflare R2 object listing was truncated without a pagination cursor.");
    }

    cursor = resultInfo.cursor;
  }
}

export function buildDownloadPlan(objects, outputDir, options = {}) {
  const fileBaseDir = options.fileBaseDir ?? outputDir;

  return sortObjectsNewestFirst(objects).map((object) => ({
    key: object.key,
    file: path.join(outputDir, localFileNameForKey(object.key)),
    downloadFile: path.join(fileBaseDir, localFileNameForKey(object.key)),
    uploadedAt: objectTimestamp(object),
    size: object.size ?? null,
    etag: object.etag ?? null,
    customMetadata: object.custom_metadata ?? {}
  }));
}

export function buildReviewIndex({ bucket, prefix, generatedAt, objects, outputDir, summariesByKey }) {
  const submissions = buildDownloadPlan(objects, outputDir).map((entry) => {
    const summary = summariesByKey.get(entry.key) ?? null;
    const source = summary?.source ?? {};

    return {
      key: entry.key,
      file: entry.file,
      uploadedAt: entry.uploadedAt,
      size: entry.size,
      etag: entry.etag,
      appVersion: entry.customMetadata.appVersion ?? source.appVersion ?? null,
      buildNumber: entry.customMetadata.buildNumber ?? source.buildNumber ?? null,
      snapshot: summary
    };
  });

  return {
    generatedAt,
    bucket,
    prefix,
    count: submissions.length,
    submissions
  };
}

export function snapshotSummary(snapshot) {
  return {
    schemaVersion: snapshot.schemaVersion,
    exportedAt: snapshot.exportedAt,
    source: snapshot.source,
    sectionCounts: Object.fromEntries(
      Object.entries(snapshot.settings ?? {})
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([section, value]) => [section, value && typeof value === "object" ? Object.keys(value).length : 0])
    )
  };
}

export function buildReviewMarkdown(index) {
  const lines = [
    "# Developer Settings Downloads",
    "",
    `Generated: ${index.generatedAt}`,
    `Bucket: ${index.bucket}`,
    `Prefix: ${index.prefix}`,
    "",
    "Choose one JSON file to ingest with:",
    "",
    "```bash",
    "Tools/developer-settings-ingest.mjs developer-settings-downloads/<chosen-file>.json",
    "```",
    "",
    "| Uploaded | Exported | App | Build | File |",
    "| --- | --- | --- | --- | --- |"
  ];

  for (const submission of index.submissions) {
    lines.push(
      [
        submission.uploadedAt ?? "",
        submission.snapshot?.exportedAt ?? "",
        submission.appVersion ?? "",
        submission.buildNumber ?? "",
        submission.file
      ].map(markdownCell).join(" | ").replace(/^/, "| ").replace(/$/, " |")
    );
  }

  lines.push("");
  return `${lines.join("\n")}`;
}

async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.help) {
    console.log(usage());
    return;
  }

  const downloadOutputDir = path.resolve(options.outputDir);
  await fs.mkdir(downloadOutputDir, { recursive: true });

  const whoami = await wranglerJson(["whoami", "--json"], options.wranglerCwd);
  const accountId = selectAccountId(whoami, options.accountId);
  const tokenResponse = await wranglerJson(["auth", "token", "--json"], options.wranglerCwd);
  if (!tokenResponse.token) {
    throw new Error("Wrangler did not return an auth token.");
  }

  const objects = await listR2Objects({
    accountId,
    bucket: options.bucket,
    prefix: options.prefix,
    token: tokenResponse.token
  });
  const plan = buildDownloadPlan(objects, options.outputDir, { fileBaseDir: downloadOutputDir });
  const summariesByKey = new Map();

  for (const entry of plan) {
    await fs.rm(entry.downloadFile, { force: true });
    await wrangler([
      "r2",
      "object",
      "get",
      `${options.bucket}/${entry.key}`,
      "--remote",
      "--file",
      entry.downloadFile
    ], options.wranglerCwd);

    const snapshot = JSON.parse(await fs.readFile(entry.downloadFile, "utf8"));
    validateSnapshot(snapshot);
    summariesByKey.set(entry.key, snapshotSummary(snapshot));
  }

  const generatedAt = new Date().toISOString();
  const index = buildReviewIndex({
    bucket: options.bucket,
    prefix: options.prefix,
    generatedAt,
    objects,
    outputDir: options.outputDir,
    summariesByKey
  });

  await fs.writeFile(path.join(downloadOutputDir, "index.json"), `${JSON.stringify(index, null, 2)}\n`);
  await fs.writeFile(path.join(downloadOutputDir, "README.md"), buildReviewMarkdown(index));

  console.log(`Pulled ${index.count} developer settings submission${index.count === 1 ? "" : "s"} into ${options.outputDir}`);
  console.log(`Review ${path.join(options.outputDir, "README.md")}`);
  console.log(`Ingest one with: Tools/developer-settings-ingest.mjs ${options.outputDir}/<chosen-file>.json`);
}

async function listR2Objects({ accountId, bucket, prefix, token }) {
  return collectListedObjects(async ({ cursor }) => {
    const url = new URL(
      `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(accountId)}/r2/buckets/${encodeURIComponent(bucket)}/objects`
    );
    url.searchParams.set("prefix", prefix);
    url.searchParams.set("per_page", "1000");
    if (cursor) {
      url.searchParams.set("cursor", cursor);
    }

    const response = await fetch(url, {
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json"
      }
    });
    const body = await response.text();
    const json = JSON.parse(body);

    if (!response.ok) {
      throw new Error(`Cloudflare R2 object listing failed (${response.status}): ${body}`);
    }

    return json;
  });
}

function sortObjectsNewestFirst(objects) {
  return [...objects].sort((left, right) => {
    const rightTime = new Date(objectTimestamp(right) ?? 0).valueOf();
    const leftTime = new Date(objectTimestamp(left) ?? 0).valueOf();
    return rightTime - leftTime || String(right.key).localeCompare(String(left.key));
  });
}

function localFileNameForKey(key) {
  const basename = path.basename(key);
  if (!basename || basename === "." || basename === "..") {
    throw new Error(`Cannot derive a local file name from R2 key: ${key}`);
  }
  return basename;
}

function objectTimestamp(object) {
  return object.uploaded ?? object.last_modified ?? object.lastModified ?? null;
}

function parseArgs(argv) {
  const options = {
    accountId: undefined,
    bucket: DEFAULT_BUCKET,
    prefix: DEFAULT_PREFIX,
    outputDir: DEFAULT_OUTPUT_DIR,
    wranglerCwd: DEFAULT_WRANGLER_CWD,
    help: false
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--account":
        options.accountId = requireValue(argv, ++index, arg);
        break;
      case "--bucket":
        options.bucket = requireValue(argv, ++index, arg);
        break;
      case "--prefix":
        options.prefix = requireValue(argv, ++index, arg);
        break;
      case "--output":
      case "-o":
        options.outputDir = requireValue(argv, ++index, arg);
        break;
      case "--wrangler-cwd":
        options.wranglerCwd = requireValue(argv, ++index, arg);
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}\n\n${usage()}`);
    }
  }

  return options;
}

function requireValue(argv, index, flag) {
  const value = argv[index];
  if (!value || value.startsWith("-")) {
    throw new Error(`${flag} requires a value.`);
  }
  return value;
}

async function wranglerJson(args, cwd) {
  const { stdout } = await wrangler(args, cwd);
  return JSON.parse(stdout);
}

async function wrangler(args, cwd) {
  const wranglerArgs = cwd ? ["--cwd", cwd, ...args] : args;
  return execFileAsync("wrangler", wranglerArgs, {
    maxBuffer: 10 * 1024 * 1024,
    env: cleanCliEnv()
  });
}

function cleanCliEnv() {
  const env = { ...process.env, NO_COLOR: "1" };
  delete env.FORCE_COLOR;
  return env;
}

function usage() {
  return `Usage: Tools/developer-settings-pull.mjs [options]

Pulls developer settings submissions from Cloudflare R2 into a local ignored
review directory. It does not ingest or delete remote objects.

Options:
  -o, --output <dir>       Local review directory (default: ${DEFAULT_OUTPUT_DIR})
      --bucket <name>      R2 bucket (default: ${DEFAULT_BUCKET})
      --prefix <prefix>    R2 key prefix (default: ${DEFAULT_PREFIX})
      --account <id>       Cloudflare account id, required if Wrangler has multiple accounts
      --wrangler-cwd <dir> Directory Wrangler should run from (default: ${DEFAULT_WRANGLER_CWD})
  -h, --help               Show this help
`;
}

function markdownCell(value) {
  return String(value).replaceAll("|", "\\|");
}

if (process.argv[1] && import.meta.url === new URL(process.argv[1], "file:").href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
