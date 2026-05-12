import { writeFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { en } from "./locales/en.mjs";
import { ru } from "./locales/ru.mjs";
import { uk } from "./locales/uk.mjs";

const BASE_URL = "https://casualcontacts.app";
const PAGE_ORDER = ["home", "privacy", "support"];
const PAGE_FILES = {
  home: "index.html",
  privacy: "privacy.html",
  support: "support.html",
};

const locales = [en, ru, uk];

export function buildSite() {
  const files = {};

  for (const locale of locales) {
    for (const pageId of PAGE_ORDER) {
      const filePath = outputPath(locale, pageId);
      const assetPrefix = locale.code === "en" ? "" : "../";
      files[filePath] = renderPage({ locale, pageId, assetPrefix });
    }
  }

  return files;
}

export async function writeSite(outputDir = projectMarketingDir()) {
  const files = buildSite();

  for (const [relativePath, contents] of Object.entries(files)) {
    const target = path.join(outputDir, relativePath);
    await mkdir(path.dirname(target), { recursive: true });
    await writeFile(target, contents);
  }
}

function renderPage({ locale, pageId, assetPrefix }) {
  const page = locale.pages[pageId];
  const body = {
    home: renderHome,
    privacy: renderPrivacy,
    support: renderSupport,
  }[pageId]({ locale, assetPrefix });

  return `<!doctype html>
<html lang="${locale.code}" class="density-cozy">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>${page.title}</title>
  <meta name="description" content="${page.description}" />
  <meta property="og:title" content="${page.ogTitle ?? locale.appName}" />
  <meta property="og:description" content="${page.description}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${canonicalUrl(locale, pageId)}" />
  <meta property="og:image" content="${BASE_URL}/assets/CC_Noble_export.webp" />
  <meta property="og:image:type" content="image/webp" />
  <meta property="og:image:width" content="900" />
  <meta property="og:image:height" content="1327" />
  <meta property="og:image:alt" content="${locale.ogImageAlt}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${page.ogTitle ?? locale.appName}" />
  <meta name="twitter:description" content="${page.description}" />
  <meta name="twitter:image" content="${BASE_URL}/assets/CC_Noble_export.webp" />
  <meta name="twitter:image:alt" content="${locale.ogImageAlt}" />
  <meta name="theme-color" content="#FAFAF7" media="(prefers-color-scheme: light)" />
  <meta name="theme-color" content="#141415" media="(prefers-color-scheme: dark)" />
  <link rel="canonical" href="${canonicalUrl(locale, pageId)}" />
${alternateLinks(pageId)}

  <link rel="icon" type="image/svg+xml" href="${assetPrefix}favicon.svg" />
  <link rel="icon" type="image/png" sizes="32x32" href="${assetPrefix}favicon-32.png" />
  <link rel="icon" type="image/png" sizes="16x16" href="${assetPrefix}favicon-16.png" />
  <link rel="apple-touch-icon" sizes="180x180" href="${assetPrefix}apple-touch-icon.png" />

  <link rel="preload" href="${assetPrefix}fonts/CormorantSC-Bold.woff2" as="font" type="font/woff2" crossorigin />
  <link rel="preload" href="${assetPrefix}fonts/CormorantInfant-Variable.woff2" as="font" type="font/woff2" crossorigin />

  <link rel="stylesheet" href="${assetPrefix}colors_and_type.css" />
  <link rel="stylesheet" href="${assetPrefix}site.css" />
${pageId !== "home" ? `  <link rel="stylesheet" href="${assetPrefix}privacy.css" />\n` : ""}${pageId === "support" ? `  <link rel="stylesheet" href="${assetPrefix}support.css" />\n` : ""}</head>
<body>
${body}
</body>
</html>
`;
}

function renderHome({ locale, assetPrefix }) {
  const { home } = locale.pages;
  return `  ${renderNav({ locale, pageId: "home", assetPrefix })}

  <header id="top" class="hero hero-showcase">
    <div class="container">
      <div class="showcase-mark">
        <div class="app-icon" aria-hidden="true">
          <img src="${assetPrefix}assets/AppIcon.png" alt="" width="132" height="132" />
        </div>
        <h1 class="showcase-title">${locale.appName}</h1>
        <div class="showcase-sub eyebrow">${home.hero.kicker}</div>
      </div>

      <div class="showcase-pair">
        <figure class="showcase-noble">
          <picture>
            <source srcset="${assetPrefix}assets/CC_Noble_export.webp" type="image/webp" />
            <img src="${assetPrefix}assets/CC_Noble_export.png" alt="${locale.ogImageAlt}" />
          </picture>
        </figure>
        <figure class="showcase-video">
          <video autoplay muted loop playsinline poster="${assetPrefix}assets/cards/Photo_1.png">
            <source src="${assetPrefix}assets/CC.webm" type="video/webm" />
            <source src="${assetPrefix}assets/CC.mp4" type="video/mp4" />
          </video>
        </figure>
      </div>

      <p class="showcase-tagline">${home.hero.tagline}</p>

      <div class="showcase-actions">
        ${renderAppStoreBadge({ locale, assetPrefix })}
        <div class="hero-stamps">
${home.hero.stamps.map((stamp) => `          <div>${stamp.label}<span>${stamp.value}</span></div>`).join("\n")}
        </div>
      </div>
    </div>
  </header>

  ${renderSteps(home)}
  ${renderGallery(home, assetPrefix)}
  ${renderEssay(home)}
  ${renderScreens(home, assetPrefix)}
  ${renderFaq(home.faq)}
  ${renderColophon(home, assetPrefix)}
  ${renderFooter({ locale, pageId: "home", assetPrefix })}`;
}

function renderPrivacy({ locale, assetPrefix }) {
  const { privacy } = locale.pages;
  return `  <a id="top"></a>
  ${renderNav({ locale, pageId: "privacy", assetPrefix })}

  <header class="privacy-hero">
    <div class="container">
      <div class="privacy-eyebrow">${privacy.eyebrow}</div>
      <h1 class="privacy-title">${privacy.heading}</h1>
      <p class="privacy-lede">${privacy.lede}</p>
      <div class="privacy-meta">
${privacy.meta.map((item, index) => renderMetaPair(item, index)).join("\n")}
      </div>
    </div>
  </header>

${privacy.sections.map(renderPrivacySection).join("\n\n")}

  ${renderFooter({ locale, pageId: "privacy", assetPrefix })}`;
}

function renderSupport({ locale, assetPrefix }) {
  const { support } = locale.pages;
  return `  <a id="top"></a>
  ${renderNav({ locale, pageId: "support", assetPrefix })}

  <header class="privacy-hero">
    <div class="container">
      <div class="privacy-eyebrow">${support.eyebrow}</div>
      <h1 class="privacy-title">${support.heading}</h1>
      <p class="privacy-lede">${support.lede}</p>
      <div class="privacy-meta">
${support.meta.map((item, index) => renderMetaPair(item, index)).join("\n")}
      </div>
    </div>
  </header>

${support.sections.map(renderPrivacySection).join("\n\n")}

  ${renderFooter({ locale, pageId: "support", assetPrefix })}`;
}

function renderNav({ locale, pageId, assetPrefix }) {
  const homeHref = pageId === "home" ? "#top" : pageHref(locale, "home");
  const backLink = pageId === "home"
    ? `<span class="nav-meta" data-app-version>${locale.version}</span>`
    : `<a href="${pageHref(locale, "home")}" class="nav-meta nav-back">${locale.nav.back}</a>`;

  return `<nav class="topnav">
    <a href="${homeHref}" class="wordmark">
      <span class="wordmark-glyph" aria-hidden="true"></span>
      <span class="wordmark-text">${locale.wordmark}</span>
    </a>
    <div class="nav-actions">
      ${renderLanguageSwitcher({ locale, pageId })}
      ${backLink}
    </div>
  </nav>`;
}

function renderLanguageSwitcher({ locale, pageId }) {
  return `<div class="language-switcher" aria-label="${locale.nav.languageLabel}">
${locales.map((targetLocale) => {
  const current = targetLocale.code === locale.code ? ` aria-current="true"` : "";
  return `        <a href="${pageHref(targetLocale, pageId, locale.code)}"${current}>${targetLocale.shortName}</a>`;
}).join("\n")}
      </div>`;
}

function renderFooter({ locale, pageId, assetPrefix }) {
  const { footer } = locale;
  return `<footer class="cc-footer">
    <div class="container">
      <div class="cc-footer-grid">
        <div>
          <div class="brand">${locale.wordmark}</div>
          <div class="tag">${footer.tagline}</div>
          <div style="margin-top:24px;">
            ${renderAppStoreBadge({ locale, assetPrefix })}
          </div>
        </div>
        <div class="col">
          <h4>${footer.appTitle}</h4>
          <a href="${pageHref(locale, "home")}#top"${pageId === "home" ? ` aria-current="page"` : ""}>${footer.overview}</a>
          <a href="https://apps.apple.com/us/app/casual-contacts/id6763807407">${footer.download}</a>
          <a href="https://github.com/Stacks-du-Beurre/casual-contacts/commits/main/" target="_blank" rel="noopener noreferrer">${footer.releaseNotes}</a>
        </div>
        <div class="col">
          <h4>${footer.etcTitle}</h4>
          <a href="${pageHref(locale, "privacy")}"${pageId === "privacy" ? ` aria-current="page"` : ""}>${footer.privacy}</a>
          <a href="${pageHref(locale, "support")}"${pageId === "support" ? ` aria-current="page"` : ""}>${footer.support}</a>
          <a href="mailto:hello@casualcontacts.app">${footer.contact}</a>
        </div>
      </div>
      <div class="fineprint">
        <span>${footer.copyright}</span>
        <span>${footer.credits}</span>
      </div>
    </div>
  </footer>`;
}

function renderSteps(home) {
  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(home.stepsSection)}
        <h2>${home.stepsSection.heading}</h2>
      </div>
      <div class="steps">
${home.steps.map((step) => `        <div class="step">
          <div class="step-num">${step.num}</div>
          <h3>${step.heading}</h3>
          <p>${step.body}</p>
        </div>`).join("\n")}
      </div>
    </div>
  </section>`;
}

function renderGallery(home, assetPrefix) {
  const images = [
    ["Photo_1", "Bernard"],
    ["Card_3", "Alona"],
    ["Photo_4", "Satori"],
    ["Card_4", "Isaiah"],
  ];

  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(home.gallerySection)}
        <h2>${home.gallerySection.heading}</h2>
      </div>
      <div class="gallery">
${home.gallery.map((item, index) => `        <div class="gallery-item">
          <div class="card-img">
            <picture>
              <source srcset="${assetPrefix}assets/cards/${images[index][0]}.webp" type="image/webp" />
              <img src="${assetPrefix}assets/cards/${images[index][0]}.png" alt="${images[index][1]}" loading="lazy" />
            </picture>
          </div>
          <div class="meta">
            <div class="name">${images[index][1]}</div>
            <div class="when">${item.when}</div>
          </div>
        </div>`).join("\n")}
      </div>
    </div>
  </section>`;
}

function renderEssay(home) {
  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(home.essaySection)}
        <h2>${home.essaySection.heading}</h2>
      </div>
      <div class="essay">
        <aside>
          <div class="pull">${home.essay.pull}</div>
        </aside>
        <div class="body">
${home.essay.paragraphs.map((paragraph) => `          <p>${paragraph}</p>`).join("\n")}
        </div>
      </div>
    </div>
  </section>`;
}

function renderScreens(home, assetPrefix) {
  const images = [
    "02-list_framed",
    "06-create-step2_framed",
    "03-list-sort-open_framed",
  ];

  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(home.screensSection)}
        <h2>${home.screensSection.heading}</h2>
      </div>
    </div>
    <div class="container">
      <div class="scroll-strip">
        <div class="strip-row">
${home.screens.map((screen, index) => `          <figure class="phone-shot">
            <picture>
              <source srcset="${assetPrefix}assets/screens/${images[index]}.webp" type="image/webp" />
              <img src="${assetPrefix}assets/screens/${images[index]}.png" alt="${screen.alt}" loading="lazy" />
            </picture>
            <figcaption>
              <span class="cap-label">${screen.label}</span>
              <span class="cap-note">${screen.note}</span>
            </figcaption>
          </figure>`).join("\n")}
        </div>
      </div>
    </div>
  </section>`;
}

function renderFaq(faq) {
  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(faq)}
        <h2>${faq.heading}</h2>
      </div>
      <div class="faq">
${faq.items.map((item, index) => `        <details${index === 0 ? " open" : ""}>
          <summary>${item.question}</summary>
          <p>${item.answer}</p>
        </details>`).join("\n")}
      </div>
    </div>
  </section>`;
}

function renderColophon(home, assetPrefix) {
  return `<section class="cc-sec">
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(home.colophon)}
        <h2>${home.colophon.heading}</h2>
      </div>
      <div class="colophon">
        <div class="block">
          <div class="label">${home.colophon.creditsLabel}</div>
          <div class="lines">
            <span class="role">${home.colophon.engineeringRole}</span>
            Adam Mork
            <span class="role">${home.colophon.designRole}</span>
            Taras Hrybanov
          </div>
        </div>
        <div class="block">
          <div class="label">${home.colophon.privacyLabel}</div>
          <div class="privacy-note">
            <div class="glyph">
              <img src="${assetPrefix}assets/LogoSmall.svg" alt="" aria-hidden="true" style="width:36px;height:auto;display:block;" />
            </div>
            <div class="copy">
              <strong>${home.colophon.privacyStrong}</strong>
              ${home.colophon.privacyBody}
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>`;
}

function renderPrivacySection(section) {
  return `  <section class="cc-sec privacy-sec"${section.id ? ` id="${section.id}"` : ""}>
    <div class="container">
      <div class="section-head">
        ${renderSectionLabel(section)}
        <h2>${section.heading}</h2>
      </div>
      <div class="privacy-body${section.wide ? " privacy-body--wide" : ""}">
        ${renderSectionBody(section)}
      </div>
    </div>
  </section>`;
}

function renderSectionBody(section) {
  if (section.kind === "html") {
    return section.body;
  }

  if (section.kind === "list") {
    return `<ul class="privacy-list">
${section.items.map((item) => `          <li>${item}</li>`).join("\n")}
        </ul>`;
  }

  if (section.kind === "permissions") {
    return `<dl class="permissions${section.compact ? " reqs" : ""}">
${section.items.map((item) => `          <div>
            <dt>${item.term}</dt>
            <dd>${item.description}</dd>
          </div>`).join("\n")}
        </dl>${section.note ? `\n        <p class="muted">${section.note}</p>` : ""}`;
  }

  if (section.kind === "faq") {
    return `<div class="faq-list support-faq">
${section.items.map((item, index) => `          <details${index === 0 ? " open" : ""}>
            <summary>${item.question}</summary>
            <div class="faq-body">
              ${item.body}
            </div>
          </details>`).join("\n")}
        </div>`;
  }

  return section.paragraphs.map((paragraph) => `        <p>${paragraph}</p>`).join("\n");
}

function renderSectionLabel(section) {
  return `<div class="label">
          <span class="num">${section.num}</span>
          <span class="eyebrow">${section.eyebrow}</span>
        </div>`;
}

function renderMetaPair(item, index) {
  const rule = index === 0 ? "" : `        <span class="meta-rule" aria-hidden="true"></span>\n`;
  return `${rule}        <span class="meta-pair">
          <span class="meta-label">${item.label}</span>
          <span class="meta-value">${item.value}</span>
        </span>`;
}

function renderAppStoreBadge({ locale, assetPrefix }) {
  return `<a class="app-store-badge" href="https://apps.apple.com/us/app/casual-contacts/id6763807407" aria-label="${locale.appStoreAria}">
              <img src="${assetPrefix}assets/AppStoreBadge.svg" alt="" style="height:56px;width:auto;" />
            </a>`;
}

function alternateLinks(pageId) {
  const links = locales.map((locale) => {
    return `  <link rel="alternate" hreflang="${locale.code}" href="${canonicalUrl(locale, pageId)}" />`;
  });
  links.push(`  <link rel="alternate" hreflang="x-default" href="${canonicalUrl(en, pageId)}" />`);
  return links.join("\n");
}

function pageHref(locale, pageId, fromLocaleCode = locale.code) {
  if (locale.code === fromLocaleCode) {
    return PAGE_FILES[pageId];
  }

  if (locale.code === "en") {
    return fromLocaleCode === "en" ? PAGE_FILES[pageId] : `../${PAGE_FILES[pageId]}`;
  }

  return fromLocaleCode === "en"
    ? `${locale.code}/${PAGE_FILES[pageId]}`
    : `../${locale.code}/${PAGE_FILES[pageId]}`;
}

function canonicalUrl(locale, pageId) {
  const pageFile = PAGE_FILES[pageId];

  if (locale.code === "en") {
    return pageId === "home" ? `${BASE_URL}/` : `${BASE_URL}/${pageFile}`;
  }

  return pageId === "home"
    ? `${BASE_URL}/${locale.code}/`
    : `${BASE_URL}/${locale.code}/${pageFile}`;
}

function outputPath(locale, pageId) {
  const pageFile = PAGE_FILES[pageId];
  return locale.code === "en" ? pageFile : `${locale.code}/${pageFile}`;
}

function projectMarketingDir() {
  const currentFile = fileURLToPath(import.meta.url);
  return path.resolve(path.dirname(currentFile), "..");
}
