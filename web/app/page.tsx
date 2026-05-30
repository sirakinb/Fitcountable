import { LandingInteractions } from "./landing-interactions";

function CheckIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

export default function HomePage() {
  return (
    <>
      <header className="nav" id="nav">
        <div className="container nav-inner">
          <a className="brand" href="#top" aria-label="Fitcountable home">
            <img src="/fitcountable-mascot.png" alt="" />
            <span>Fitcountable</span>
          </a>
          <nav className="nav-links" aria-label="Primary">
            <a href="#how">How it works</a>
            <a href="#proof">Proof</a>
            <a href="#covers">Features</a>
            <a href="/privacy">Privacy</a>
          </nav>
          <div className="nav-cta">
            <a className="btn btn-primary" href="#get">
              Get the app
            </a>
          </div>
        </div>
      </header>

      <main id="top">
        <section className="hero">
          <div className="container hero-grid">
            <div className="hero-copy">
              <h1 className="display">
                Log workouts
                <br />
                and meals by
                <br />
                <span className="hero-headline-accent">saying what happened.</span>
              </h1>
              <p className="lede">
                Fitcountable turns natural language into editable workout, nutrition, and proof records — so consistency is easier to keep.
              </p>
              <div className="hero-cta">
                <a className="appstore" id="get" href="#" aria-label="Download on the App Store">
                  <img src="/download-on-app-store.svg" alt="Download on the App Store" />
                </a>
                <span className="hero-cta-note">iPhone app launching on the App&nbsp;Store.</span>
              </div>
              <div className="trust">
                <span className="trust-item">
                  <CheckIcon />
                  Review before save
                </span>
                <span className="trust-item">
                  <CheckIcon />
                  Private by default
                </span>
                <span className="trust-item">
                  <CheckIcon />
                  Built for accountability
                </span>
              </div>
            </div>

            <div className="hero-stage">
              <div className="phone phone--back">
                <img src="/app-ai.png" alt="Fitcountable AI meal review screen" />
              </div>
              <div className="phone phone--front">
                <img src="/app-today.png" alt="Fitcountable Today dashboard showing calories, macros, and logging shortcuts" />
              </div>

              <div className="float-input" id="floatInput" aria-hidden="true">
                <div className="float-input-bar">
                  <svg className="float-spark" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2l1.6 5.4L19 9l-5.4 1.6L12 16l-1.6-5.4L5 9l5.4-1.6L12 2z" />
                  </svg>
                  <span className="float-text" id="floatText"></span>
                  <span className="caret" id="floatCaret"></span>
                  <span className="float-mic">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <rect x="9" y="2" width="6" height="12" rx="3" />
                      <path d="M5 10a7 7 0 0 0 14 0M12 19v3" />
                    </svg>
                  </span>
                </div>
                <div className="float-result" id="floatResult">
                  <span className="float-check">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M20 6 9 17l-5-5" />
                    </svg>
                  </span>
                  <span>
                    <span className="float-result-label" id="floatResultLabel">
                      LOGGED
                    </span>
                    <br />
                    <span className="float-result-value" id="floatResultValue"></span>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section how" id="how">
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">How it works</span>
              <h2 className="h2 mt-12">One input becomes a clean log.</h2>
              <p className="lede">Speak or type in plain language. Fitcountable structures it, you review, and it saves.</p>
            </div>
            <div className="steps">
              <article className="step reveal">
                <svg className="step-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="9" y="2" width="6" height="12" rx="3" />
                  <path d="M5 10a7 7 0 0 0 14 0M12 19v3" />
                </svg>
                <div className="step-num">01</div>
                <div className="step-rule"></div>
                <h3>Say the meal</h3>
                <p>Speak or type what you ate. Fitcountable turns it into an editable calorie and macro estimate.</p>
              </article>
              <article className="step reveal">
                <svg className="step-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6.5 6.5h11M6.5 17.5h11M4 9v6M20 9v6M2 10.5v3M22 10.5v3" />
                </svg>
                <div className="step-num">02</div>
                <div className="step-rule"></div>
                <h3>Log the lift</h3>
                <p>Capture sets, reps, weight, notes, and duration without rebuilding a workout from scratch.</p>
              </article>
              <article className="step reveal">
                <svg className="step-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 2l2.4 7.4H22l-6 4.4 2.3 7.2-6.3-4.6-6.3 4.6L8 13.8 2 9.4h7.6L12 2z" />
                </svg>
                <div className="step-num">03</div>
                <div className="step-rule"></div>
                <h3>Show proof</h3>
                <p>Choose private, friends, or public proof when accountability helps you stay consistent.</p>
              </article>
            </div>
          </div>
        </section>

        <section className="section section--wide">
          <div className="container container--wide">
            <div className="feature-row reverse solo">
              <div className="feature-copy reveal">
                <span className="eyebrow">Daily tracking</span>
                <h2 className="h2">Calm enough for every day. Smart enough for messy inputs.</h2>
                <p>
                  Calories, macros, workouts, and weekly consistency live in one quiet dashboard — no rebuilding entries, no friction between intention and the log.
                </p>
                <ul className="feature-list">
                  <li>
                    <CheckIcon />
                    One natural-language estimate, always editable before it saves.
                  </li>
                  <li>
                    <CheckIcon />
                    Calories and macros that read at a glance, not a spreadsheet.
                  </li>
                  <li>
                    <CheckIcon />
                    Weekly workout targets you can actually keep.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>

        <section className="section how covers-section" id="covers">
          <div className="container">
            <div className="section-head reveal">
              <span className="eyebrow">What it covers</span>
              <h2 className="h2 mt-12">Training, food, AI, and proof in one loop.</h2>
            </div>
            <div className="covers-grid">
              <article className="cover-card reveal">
                <div className="cover-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="9" />
                    <path d="M12 12l4-2.5M12 12v4.5" />
                  </svg>
                </div>
                <span className="cover-tag">Today</span>
                <h3>One calm dashboard</h3>
                <p>Calories, macros, workouts, and weekly consistency — together, at a glance.</p>
              </article>
              <article className="cover-card reveal">
                <div className="cover-icon">
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2l1.6 5.4L19 9l-5.4 1.6L12 16l-1.6-5.4L5 9l5.4-1.6L12 2z" />
                  </svg>
                </div>
                <span className="cover-tag">AI</span>
                <h3>Review before save</h3>
                <p>Natural-language logging that proposes — and never saves anything you haven&apos;t checked.</p>
              </article>
              <article className="cover-card reveal">
                <div className="cover-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="9" cy="8" r="3.2" />
                    <path d="M3 20a6 6 0 0 1 12 0M16.5 5.2a3.2 3.2 0 0 1 0 5.6M18 20a6 6 0 0 0-3-5.2" />
                  </svg>
                </div>
                <span className="cover-tag">Social</span>
                <h3>Opt-in accountability</h3>
                <p>Share workout and food proof with friends — only when you choose to.</p>
              </article>
              <article className="cover-card reveal">
                <div className="cover-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 3l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9 6.8 19.2l1-5.8L3.5 9.2l5.9-.9L12 3z" />
                  </svg>
                </div>
                <span className="cover-tag">Premium</span>
                <h3>Go deeper</h3>
                <p>Higher AI limits, deeper history, and advanced planning when you&apos;re ready.</p>
              </article>
            </div>
          </div>
        </section>

        <section className="section proof" id="proof">
          <div className="container">
            <div className="proof-grid">
              <div className="proof-copy reveal">
                <span className="eyebrow">Proof &amp; privacy</span>
                <h2 className="h2 mt-12">Proof when it helps. Private when it doesn&apos;t.</h2>
                <p>
                  Accountability works when it&apos;s yours to control. Keep everything to yourself, share with approved friends, or go public — switch any time, post by
                  post.
                </p>
                <div className="privacy-toggle" role="group" aria-label="Privacy preview">
                  <button type="button" data-priv>
                    Private
                  </button>
                  <button type="button" className="active" data-priv>
                    Friends
                  </button>
                  <button type="button" data-priv>
                    Public
                  </button>
                </div>
                <p className="privacy-note" id="privNote">
                  // Approved friends can see this.
                </p>
              </div>
              <div className="proof-media reveal">
                <div className="phone phone--front proof-phone">
                  <img src="/app-social.png" alt="Fitcountable accountability and proof screen" />
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section final">
          <div className="container">
            <div className="reveal">
              <img className="final-mascot" src="/fitcountable-mascot.png" alt="Fitcountable" />
              <h2>A fitness log that keeps up with real life.</h2>
              <p className="lede">Say what happened. Review the estimate. Keep the streak. That&apos;s the whole loop.</p>
              <div className="final-cta">
                <a className="appstore" href="#">
                  <img src="/download-on-app-store.svg" alt="Download on the App Store" />
                </a>
                <span className="hero-cta-note">iPhone app launching on the App&nbsp;Store.</span>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="container">
          <div className="footer-top">
            <a className="brand" href="#top">
              <img className="footer-brand-icon" src="/fitcountable-mascot.png" alt="" />
              <span>Fitcountable</span>
            </a>
            <nav className="footer-links" aria-label="Footer">
              <a href="#how">How it works</a>
              <a href="#proof">Proof</a>
              <a href="#covers">Features</a>
              <a href="/privacy">Privacy Policy</a>
              <a href="/terms">Terms of Service</a>
              <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">EULA</a>
              <a href="/support">Support</a>
            </nav>
          </div>
          <div className="footer-meta">
            <span className="mono">© 2026 Pentridge Media — Fitcountable is not medical advice.</span>
            <span className="mono">Log workouts and meals by saying what happened.</span>
          </div>
        </div>
      </footer>

      <LandingInteractions />
    </>
  );
}
