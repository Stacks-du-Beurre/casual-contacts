import assert from "node:assert/strict";
import { test } from "node:test";

import { GENERATED_SITE_PATHS, shouldBuildMarketingSite } from "../precommit-build.mjs";
import { buildSite } from "./site.mjs";

test("buildSite emits every page for each locale", () => {
  const files = buildSite();

  assert.deepEqual(
    Object.keys(files).sort(),
    [
      "index.html",
      "privacy.html",
      "support.html",
      "ru/index.html",
      "ru/privacy.html",
      "ru/support.html",
      "uk/index.html",
      "uk/privacy.html",
      "uk/support.html",
    ].sort(),
  );
});

test("localized pages use correct asset prefixes and language metadata", () => {
  const files = buildSite();
  const russianHome = files["ru/index.html"];

  assert.match(russianHome, /<html lang="ru"/);
  assert.match(russianHome, /href="\.\.\/colors_and_type\.css"/);
  assert.match(russianHome, /src="\.\.\/assets\/AppIcon\.png"/);
  assert.match(russianHome, /href="https:\/\/casualcontacts\.app\/ru\/"/);
});

test("every generated page includes alternate language links", () => {
  const files = buildSite();
  const ukrainianPrivacy = files["uk/privacy.html"];

  assert.match(ukrainianPrivacy, /hreflang="en" href="https:\/\/casualcontacts\.app\/privacy\.html"/);
  assert.match(ukrainianPrivacy, /hreflang="ru" href="https:\/\/casualcontacts\.app\/ru\/privacy\.html"/);
  assert.match(ukrainianPrivacy, /hreflang="uk" href="https:\/\/casualcontacts\.app\/uk\/privacy\.html"/);
  assert.match(ukrainianPrivacy, /hreflang="x-default" href="https:\/\/casualcontacts\.app\/privacy\.html"/);
});

test("support contact helper lists are not nested inside paragraphs", () => {
  const files = buildSite();

  assert.doesNotMatch(files["support.html"], /<p><span class="privacy-aside">[\s\S]*?<dl class="permissions">/);
  assert.doesNotMatch(files["ru/support.html"], /<p><span class="privacy-aside">[\s\S]*?<dl class="permissions">/);
  assert.doesNotMatch(files["uk/support.html"], /<p><span class="privacy-aside">[\s\S]*?<dl class="permissions">/);
});

test("pre-commit generation runs only when marketing pipeline files are staged", () => {
  assert.equal(shouldBuildMarketingSite(["marketing-site/src/locales/en.mjs"]), true);
  assert.equal(shouldBuildMarketingSite(["marketing-site/build.mjs"]), true);
  assert.equal(shouldBuildMarketingSite(["marketing-site/index.html"]), false);
  assert.equal(shouldBuildMarketingSite(["Packages/Sources/Visuals/CardView.swift"]), false);
});

test("pre-commit generation stages every generated marketing page", () => {
  assert.deepEqual(
    GENERATED_SITE_PATHS,
    [
      "marketing-site/index.html",
      "marketing-site/privacy.html",
      "marketing-site/support.html",
      "marketing-site/ru/index.html",
      "marketing-site/ru/privacy.html",
      "marketing-site/ru/support.html",
      "marketing-site/uk/index.html",
      "marketing-site/uk/privacy.html",
      "marketing-site/uk/support.html",
    ],
  );
});
