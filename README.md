# Fitcountable

Fitcountable is a fitness logger for the days when tracking should feel less like data entry and more like telling the truth about what happened.

You can type or speak a messy note like "leg press 5 sets of 12 at 400" or "medium Starbucks coffee, McDonald's fries, and sweet and sour sauce." The app turns it into an editable workout or food log, shows the assumptions, and lets the user confirm before anything becomes part of their record.

The product is built around one idea: consistency gets easier when the app understands the way people actually talk. Workouts, meals, goals, progress, and proof should live in one calm system instead of scattered across notes, screenshots, calculators, and group chats.

## What Is Here

This repository contains the current Fitcountable launch build:

- A SwiftUI iPhone app with onboarding, Sign in with Apple, AI command logging, workout tracking, food and macro tracking, social accountability, proof posting, and RevenueCat-backed Premium.
- A TypeScript backend for Insforge/Vercel functions that parse commands, estimate nutrition, serve dashboard data, receive RevenueCat webhooks, and support social/accountability workflows.
- A Vercel landing site with privacy, terms, and support pages.
- App Store metadata, subscription plan notes, release scripts, implementation docs, and generated brand assets.

Fitcountable is intentionally iPhone-first. The first version is focused on making the core daily loop work: speak or type, review the draft, save the log, and keep a visible thread of accountability.

## Product Shape

The iOS app has five main surfaces:

- **Today**: calories, macros, weekly workout target, quick log actions, and the command bar.
- **Log**: manual workout and food entry for users who want control.
- **AI**: natural-language command review, including voice uploads and editable AI drafts.
- **Social**: accountability mode, proof posts, friends/public visibility, and Instagram Story handoff.
- **Profile**: goals, privacy, profile photo, support links, and Premium upgrade state.

Premium is handled through RevenueCat and Apple In-App Purchase. The app currently supports monthly, yearly, and lifetime products tied to the `premium` entitlement.

## Repository Map

```text
ios/        SwiftUI app, XcodeGen project spec, entitlements, privacy manifest
backend/    Insforge and Vercel backend functions, schema, migrations
web/        Landing page, privacy policy, terms, EULA/support pages
appstore/   App Store metadata, privacy label plan, screenshot and subscription notes
assets/     Generated app and marketing assets plus prompt source
docs/       PRD, build addendum, release state, implementation notes
scripts/    Local verification, App Store Connect checks, IPA export helpers
```

## Local Development

Generate the Xcode project:

```bash
cd /Users/sirakinb/Documents/Projects/fitcountable
xcodegen generate --spec ios/project.yml
```

Build the iOS app for Simulator:

```bash
xcodebuild \
  -project ios/Fitcountable.xcodeproj \
  -scheme Fitcountable \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Run the landing site:

```bash
cd web
npm install
npm run dev
```

Run backend checks/build:

```bash
cd backend
npm install
npm run build
```

## Release Notes

The current app is already moving through TestFlight. Recent launch-critical work includes:

- Sign in with Apple is required before entering the dashboard.
- Local/demo fallback mode has been removed from the production path.
- RevenueCat identifies the signed-in Apple user and refreshes Premium entitlement on launch, purchase, and restore.
- The Premium screen shows the active plan instead of marking every plan as selected.
- The Apple sign-in gate no longer shows unnecessary helper copy.
- TestFlight purchases have been verified against RevenueCat sandbox subscription records.

For App Review, reviewers should use their own Apple review account through Sign in with Apple. No developer Apple password should ever be shared.

## Secrets

Do not commit real secrets. The repo intentionally ignores local environment files, App Store Connect local config, Vercel state, RevenueCat secrets, Insforge service keys, build archives, `.next`, `dist`, and `node_modules`.

Expected local-only files include:

- App Store Connect API key/config
- RevenueCat secret API key
- Vercel AI Gateway key
- Insforge service credentials
- Deepgram key
- Spoonacular key

## Verification

Run the local verification script before release work:

```bash
./scripts/verify-local.sh
```

Run the secret scan before committing:

```bash
./scripts/check-secrets.sh
```

## Philosophy

Fitcountable is not trying to be another spreadsheet with prettier buttons. It is trying to be the fitness app that can keep up with human behavior: half-remembered meals, gym notes typed between sets, voice logs on the way home, and the small accountability moments that make consistency visible.

The app should feel calm, direct, and useful. The AI should do work in the background, but the user should always stay in control of what gets saved.
