// site.jsx — Casual Contacts marketing page
const { useState, useEffect } = React;

// ----- Brand logo (uses tintable SVGs from /assets) -----
const Logo = ({ size = 22, variant = "small", className, style }) => (
  <img
    src={`assets/Logo${variant === "large" ? "Large" : "Small"}.svg`}
    alt=""
    aria-hidden="true"
    className={className}
    style={{ width: size, height: "auto", display: "block", ...style }}
  />
);

// ----- App Store badge (uses the official SVG file) -----
const AppStoreBadge = ({ href = "#" }) => (
  <a className="app-store-badge" href={href} aria-label="Download on the App Store">
    <img src="assets/AppStoreBadge.svg" alt="" style={{ height: 56, width: "auto" }} />
  </a>
);

// ----- Top nav -----
const TopNav = () => (
  <nav className="topnav">
    <a href="#top" className="wordmark">
      <span className="wordmark-glyph" aria-hidden="true" />
      <span className="wordmark-text">casual contacts</span>
    </a>
    <span className="nav-meta">v1.0 · ios</span>
  </nav>
);

// ----- Hero -----
const HERO_GRADIENT_FILE = {
  sunset: "Sunset.png", dusk: "Dusk.png", night: "Night.png", midnight: "Midnight.png",
};

function Hero({ headline }) {
  return (
    <header id="top" className="hero hero-showcase">
      <div className="container">
        {/* Centered brand mark + title */}
        <div className="showcase-mark">
          <div className="app-icon" aria-hidden="true">
            <img src="assets/AppIcon.png" alt="" />
          </div>
          <h1 className="showcase-title">Casual Contacts</h1>
          <div className="showcase-sub eyebrow">iOS Application</div>
        </div>

        {/* Two-up: Noble portrait + clipped video */}
        <div className="showcase-pair">
          <figure className="showcase-noble">
            <img src="assets/CC_Noble_export.png" alt="Casual Contacts noble portrait" />
          </figure>
          <figure className="showcase-video">
            <video
              src="assets/CC.mp4"
              autoPlay muted loop playsInline
              poster="assets/cards/Photo_1.png"
            />
          </figure>
        </div>

        {/* Showcase tagline */}
        <p className="showcase-tagline">
          {headline}
        </p>

        {/* Actions + stamps, kept understated below */}
        <div className="showcase-actions">
          <AppStoreBadge href="#" />
          <div className="hero-stamps">
            <div>Available<span>iPhone · iOS 17+</span></div>
            <div>Price<span>Free · no accounts</span></div>
            <div>Storage<span>On device only</span></div>
          </div>
        </div>
      </div>
    </header>
  );
}

// ----- How it works -----
const STEPS = [
  {
    n: "01", title: "Meet someone",
    body: "You're at a dinner, a coworking floor, a bookshop in Edinburgh. You learn a name. Maybe two. Maybe one and a half.",
  },
  {
    n: "02", title: "Tap +, jot it down",
    body: "Their name and a few notes — when, where, what was in the air. The app stamps in the date, the time of day, the moon phase, the zodiac.",
  },
  {
    n: "03", title: "Remember on sight",
    body: "Every card is unique. A painterly gradient. A guilloche letter. The visual sticks before the name does — and pulls the name back with it.",
  },
];

const HowItWorks = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 01</span>
          <span className="eyebrow">how it works</span>
        </div>
        <h2>Three steps. No accounts. Nothing leaves your phone.</h2>
      </div>
      <div className="steps">
        {STEPS.map((s) => (
          <div className="step" key={s.n}>
            <div className="step-num">step {s.n}</div>
            <h3>{s.title}</h3>
            <p>{s.body}</p>
          </div>
        ))}
      </div>
    </div>
  </section>
);

// ----- Sample cards gallery -----
const SAMPLES = [
  { file: "Photo_1.png", name: "Bernard", when: "aug 25, 2020 · sunset" },
  { file: "Card_3.png", name: "Alona", when: "nov 24, 2019 · midday" },
  { file: "Photo_4.png", name: "Satori", when: "jun 24, 2019 · midday" },
  { file: "Card_4.png", name: "Isaiah", when: "jul 28, 2019 · dusk" },
];

const Gallery = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 02</span>
          <span className="eyebrow">specimens</span>
        </div>
        <h2>Every card is generated. No two look the same.</h2>
      </div>
      <div className="gallery">
        {SAMPLES.map((s) => (
          <div className="gallery-item" key={s.file}>
            <div className="card-img"><img src={`assets/cards/${s.file}`} alt={s.name} /></div>
            <div className="meta">
              <div className="name">{s.name}</div>
              <div className="when">{s.when}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  </section>
);

// ----- Essay -----
const Essay = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 03</span>
          <span className="eyebrow">why it exists</span>
        </div>
        <h2>You only get one chance to remember someone&rsquo;s name.</h2>
      </div>
      <div className="essay">
        <aside>
          <div className="pull">
            Meeting people in the neighborhood is fun, until you forget a name and end up dodging them for months.
          </div>
        </aside>
        <div className="body">
          <p>
            You meet someone at the coffee shop, the dog park, a friend&rsquo;s
            kitchen. You catch the name once, in passing, while you&rsquo;re also
            tracking the room, the music, what you&rsquo;re going to say next. By
            the time you&rsquo;re shaking hands it&rsquo;s already gone &mdash; and
            the next time you bump into them you&rsquo;re both pretending. A few
            weeks of that and the relationship is just awkward terrain.
          </p>
          <p>
            The apps that try to fix this read like business software. CRMs, address
            books, &ldquo;people&rdquo; databases. They ask for too much, and what
            they give back is a row in a list. None of it is built for the way you
            actually remember someone, which is mostly through the picture in your
            head: late afternoon light, a corner you almost never walk through, the
            kind of cold where your hands hurt.
          </p>
          <p>
            Casual Contacts is built around that picture. You give it a name and a
            short note &mdash; that&rsquo;s the required part &mdash; and the app
            fills in the where and the when on its own: address, time of day, moon
            phase, zodiac, season. Those values seed a generated card. Guilloche
            line-work in the shape of the first letter, a palette pulled from the
            time of day, a holographic seal, a constellation, a phase of the moon.
            No two records look alike. The card itself becomes the hook the name
            hangs on.
          </p>
          <p>
            It borrows its visual vocabulary from currency, IDs, and tickets &mdash;
            objects designed, over centuries, to be authoritative and hard to
            forget. Light-reflecting elements move with the gyroscope. Patterns
            shift as you tilt the phone. The result is closer to a deck of small
            printed objects than a contact list. You flip through them later and
            the face comes back before you&rsquo;ve read the name.
          </p>
          <p>
            It is not a CRM. It is not a journal. It is a small, deliberate tool
            for the people you barely met &mdash; so the next time you see them,
            you actually know who they are.
          </p>
        </div>
      </div>
    </div>
  </section>
);

// ----- iPhone scroll strip (real framed screenshots) -----
const PHONE_SHOTS = [
  { src: "02-list_framed.png?v=2", caption: "Records list", note: "every card unique" },
  { src: "06-create-step2_framed.png?v=2", caption: "Create flow", note: "preview as you type" },
  { src: "03-list-sort-open_framed.png?v=2", caption: "Sort & filter", note: "by name, date, place" },
];

const PhoneShot = ({ src, caption, note }) => (
  <figure className="phone-shot">
    <img src={`assets/screens/${src}`} alt={caption} loading="lazy" />
    <figcaption>
      <span className="cap-label">{caption}</span>
      <span className="cap-note">{note}</span>
    </figcaption>
  </figure>
);

const PhoneStrip = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 04</span>
          <span className="eyebrow">in the app</span>
        </div>
        <h2>Your stack of cards. Quiet, local, on the phone you already carry.</h2>
      </div>
    </div>
    <div className="container">
      <div className="scroll-strip">
        <div className="strip-row">
          {PHONE_SHOTS.map((s) => <PhoneShot key={s.src} {...s} />)}
        </div>
      </div>
    </div>
  </section>
);

// ----- FAQ -----
const FAQS = [
  {
    q: "Where does my data live?",
    a: "On your phone. Casual Contacts has no servers, no accounts, no sync. The cards exist in a local database on your device and nowhere else. iCloud backup of your phone includes them; nothing else does.",
  },
  {
    q: "How is the card visual generated?",
    a: "From the inputs you give it. The time of day picks the painterly gradient. The first letter of the name draws the guilloche. The date picks the moon phase and zodiac. Optional photo sits underneath the gradient.",
  },
  {
    q: "Can I edit a card later?",
    a: "Yes. Tap the card, edit any field — the visual regenerates. Older cards keep their generated assets unless you change a field that drives them.",
  },
  {
    q: "Is there an Android version?",
    a: "Not yet. The card system relies on SwiftUI rendering quirks we haven't ported. We'll announce here if that changes.",
  },
  {
    q: "Is it open source?",
    a: "Yes. The full source lives at github.com/stacks-du-Beurre/casual-contacts — Swift, SwiftUI, the card-generation algorithms, all of it. Read it, fork it, file an issue, send a PR.",
  },
];

const FAQ = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 05</span>
          <span className="eyebrow">frequently asked</span>
        </div>
        <h2>Questions, answered.</h2>
      </div>
      <div className="faq">
        {FAQS.map((f, i) => (
          <details key={i} {...(i === 0 ? { open: true } : {})}>
            <summary>{f.q}</summary>
            <p>
              {f.q === "Is it open source?" ? (
                <>
                  Yes. The full source lives at{" "}
                  <a
                    href="https://github.com/stacks-du-Beurre/casual-contacts"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    github.com/stacks-du-Beurre/casual-contacts
                  </a>{" "}
                  &mdash; Swift, SwiftUI, the card-generation algorithms, all
                  of it. Read it, fork it, file an issue, send a PR.
                </>
              ) : (
                f.a
              )}
            </p>
          </details>
        ))}
      </div>
    </div>
  </section>
);

// ----- Credits + privacy -----
const Colophon = () => (
  <section className="cc-sec">
    <div className="container">
      <div className="section-head">
        <div className="label">
          <span className="num">§ 06</span>
          <span className="eyebrow">colophon</span>
        </div>
        <h2>Made by three people, one note at a time.</h2>
      </div>
      <div className="colophon">
        <div className="block">
          <div className="label">credits</div>
          <div className="lines">
            <span className="role">Concept &amp; engineering</span>
            Adam Mork
            <span className="role">Design</span>
            Taras Gribanov
          </div>
        </div>
        <div className="block">
          <div className="label">privacy</div>
          <div className="privacy-note">
            <div className="glyph"><Logo size={36} /></div>
            <div className="copy">
              <strong>On device. Nowhere else.</strong>
              No accounts. No servers. No analytics. No third-party SDKs. The app
              cannot read your contacts, your photos library, or your location unless
              you explicitly attach them to a card.
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
);

// ----- Footer -----
const Footer = () => (
  <footer className="cc-footer">
    <div className="container">
      <div className="cc-footer-grid">
        <div>
          <div className="brand">casual contacts</div>
          <div className="tag">
            A field journal for the people you almost remember. Made for iPhone.
          </div>
          <div style={{ marginTop: 24 }}>
            <AppStoreBadge href="#" />
          </div>
        </div>
        <div className="col">
          <h4>App</h4>
          <a href="#top">Overview</a>
          <a href="#">Download</a>
          <a href="#">Release notes</a>
        </div>
        <div className="col">
          <h4>Etc</h4>
          <a href="#">Privacy</a>
          <a href="mailto:hello@casualcontacts.app">Contact</a>
          <a href="#">Press kit</a>
        </div>
      </div>
      <div className="fineprint">
        <span>© 2026 casual contacts · all rights reserved</span>
        <span>concept &amp; engineering — adam mork · design — taras gribanov</span>
      </div>
    </div>
  </footer>
);

// ----- Tweaks -----
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "headline": "canonical",
  "showGallery": true,
  "density": "cozy"
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweak] = window.useTweaks
    ? window.useTweaks(TWEAK_DEFAULTS)
    : [TWEAK_DEFAULTS, () => {}];

  // apply density to <html>
  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove("density-tight", "density-cozy", "density-airy");
    root.classList.add(`density-${tweaks.density}`);
  }, [tweaks.density]);

  const HEADLINE_OPTS = {
    canonical: "Casual Contacts, like the Nobles, speaks for itself — just one glance is enough to understand its luxury.",
    short: "Remember the people you barely met.",
    reflective: "A field journal for the people you almost remember.",
  };
  const headlineText = HEADLINE_OPTS[tweaks.headline] || HEADLINE_OPTS.canonical;

  return (
    <>
      <TopNav />
      <Hero
        headline={headlineText}
      />
      <HowItWorks />
      {tweaks.showGallery && <Gallery />}
      <Essay />
      <PhoneStrip />
      <FAQ />
      <Colophon />
      <Footer />

      {/* Tweaks panel */}
      {window.TweaksPanel && (
        <window.TweaksPanel title="Tweaks">
          <window.TweakSection title="Hero">
            <window.TweakSelect
              label="Headline"
              value={tweaks.headline in HEADLINE_OPTS ? tweaks.headline : "canonical"}
              onChange={(v) => setTweak("headline", v)}
              options={[
                { value: "canonical", label: "Canonical (Nobles)" },
                { value: "short", label: "Short" },
                { value: "reflective", label: "Reflective" },
              ]}
            />
          </window.TweakSection>
          <window.TweakSection title="Layout">
            <window.TweakRadio
              label="Density"
              value={tweaks.density}
              onChange={(v) => setTweak("density", v)}
              options={[
                { value: "tight", label: "Tight" },
                { value: "cozy", label: "Cozy" },
                { value: "airy", label: "Airy" },
              ]}
            />
            <window.TweakToggle
              label="Sample cards section"
              value={tweaks.showGallery}
              onChange={(v) => setTweak("showGallery", v)}
            />
          </window.TweakSection>
        </window.TweaksPanel>
      )}
    </>
  );
}

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
