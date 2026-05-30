# Mobile App Store Launch Playbook

This is the operating brief for turning a mobile app idea into a shipped App Store product. It is based on the Fitcountable build and submission process, but it is written as a reusable checklist for future apps.

The goal is not just to remember the obvious steps. The value is in the small sequencing details: when to create products, when to verify privacy language, when to test IAP in sandbox, when to avoid local-only demo paths, when to update reviewer notes, and when an automation can proceed without stopping for human clarification.

## 1. Start With The Product Truth

Before touching Xcode, decide what the app actually is.

Write a short product brief that answers:

- Who is the user?
- What daily pain does the app remove?
- What does the app do on the first screen after onboarding?
- What is the minimum complete workflow?
- What is deliberately not in v1?
- What data does the app need to collect?
- What user trust concerns exist?
- What paid value, if any, is truly premium?

For Fitcountable, the product truth was:

> A fitness tracker that lets users speak or type what happened, turns messy human language into editable workout and meal logs, and makes consistency visible through optional accountability.

That sentence shaped everything: AI command logging, confirmation before saving, food/workout workflows, proof posts, privacy controls, social, and subscriptions.

## 2. Turn The Brief Into An Implementation-Ready PRD

Create a PRD before building. It should be written for an autonomous coding agent, not a marketing audience.

Include:

- Product vision
- Target users
- MVP scope
- v1 non-goals
- Onboarding flow
- Authentication model
- Main screens
- Core data model
- Backend functions
- AI/automation workflow
- Payments and entitlement plan
- App Store submission plan
- Privacy and compliance assumptions
- Acceptance criteria
- "Do not ask unless blocked" operating rules

For mobile apps, the PRD should name real identifiers early:

- App name
- Bundle ID
- SKU
- Apple Developer Team ID
- App Store category
- Platform/device target
- Review contact
- Support email
- Privacy URL
- Terms URL
- EULA URL
- Demo/reviewer access plan

Do not wait until the end to choose identifiers. Bundle IDs, product IDs, backend table names, RevenueCat entitlements, and App Store metadata all depend on them.

## 3. Research The Category, But Convert Research Into Build Decisions

Research should not become a vague inspiration pile. It should become specific UI and product decisions.

For a fitness app, inspect:

- MyFitnessPal
- Lose It
- Cronometer
- MacroFactor
- Strong
- Hevy
- Strava
- Ladder
- Any direct social/accountability competitors

Capture:

- What users expect by default
- What must be faster or clearer
- What copy feels normal in the category
- What UI patterns are familiar enough to reuse
- What workflows are too complex for v1
- What reviewers might question

For design research, use tools like Mobbin when available. The output should be concrete: "macro cards should appear on Today," "food estimates must be editable before save," "proof posts should not look like a generic social feed," etc.

## 4. Choose The Architecture Before Building Screens

A mobile app that touches auth, backend data, payments, and AI needs an architecture decision up front.

Define:

- App shell and navigation
- Local state strategy
- Auth boundary
- Backend API boundary
- Offline behavior
- Payment entitlement source of truth
- Analytics/event strategy
- Error handling and retry behavior
- File/image upload strategy
- Environment/secrets strategy

For Fitcountable:

- iOS: SwiftUI
- Project generation: XcodeGen
- Backend/database: Insforge
- Web/landing/legal pages: Vercel
- AI: Vercel AI Gateway server-side only
- Transcription: local recording + server-side transcription
- Payments: RevenueCat + Apple IAP
- Auth: Sign in with Apple required before entering dashboard

The biggest lesson: decide local-vs-cloud data early. Letting users run locally for weeks and then sign in creates merge complexity. If the real product needs server identity, start onboarding without auth if desired, but require auth before creating durable records.

## 5. Set Up The Repo Like A Launch Repo

Create a clean repository layout:

```text
ios/        app source, project spec, entitlements, privacy manifest
backend/    API handlers, database schema, migrations, function wrappers
web/        landing, privacy, terms, support, EULA
appstore/   metadata, privacy plan, screenshots plan, IAP plan
assets/     generated/source assets and prompts
docs/       PRD, build addendum, implementation status, launch playbook
scripts/    validation, release, App Store Connect helpers
```

Add `.gitignore` before any build:

- `node_modules/`
- `.next/`
- `dist/`
- `.vercel/`
- `DerivedData/`
- generated Xcode projects if using XcodeGen
- archives and IPA artifacts
- `.env`
- `.env.*`
- `*.local.json`
- secret/key files

Create a secret scan script early. It does not replace proper secret management, but it prevents obvious mistakes.

## 6. Build The First Real App Screen, Not A Landing Page In App Clothing

For product apps, avoid building a marketing hero as the first app screen. Build the actual experience.

For Fitcountable, the first real screen became:

- Today dashboard
- Weekly consistency row
- Calories/macros
- Command bar
- Quick actions
- Center mic/AI control

The app should prove its purpose immediately. A landing page can explain the app. The app itself should do the work.

## 7. Design System: Make It Small, Stable, And Reusable

Create tokens and components early:

- Background/surface/card colors
- Text/muted/accent colors
- Primary button
- Secondary/back button
- Cards
- Section headers
- Tabs
- Command bar
- Empty states
- Loading states
- Error states
- Dark mode colors

Specific mobile rules:

- Buttons must not jump between onboarding screens.
- Text must fit on small phones.
- Dark mode cannot be an afterthought.
- Icon buttons should use familiar system symbols.
- Avoid visible implementation language like "tool," "parser," "agent workflow," or "log_meal."
- Every async action needs visible progress.
- Every voice action needs listening feedback.
- Every save action needs success/failure feedback.

## 8. Onboarding Should Create Investment, Then Require Account At The Right Moment

A strong onboarding flow can ask useful questions before sign-in:

- Main goal
- Current routine
- Weekly target
- Nutrition preference
- Accountability preference
- Privacy default

But if the app requires cloud sync, social features, payments, or durable user identity, require Sign in with Apple before entering the main app.

Do not hide a local/demo fallback unless it is a deliberate product feature. It complicates review, data persistence, and entitlement state.

Good pattern:

1. First few onboarding screens introduce value and collect choices.
2. Require Sign in with Apple before dashboard.
3. Bootstrap profile server-side.
4. Save onboarding choices to backend.
5. Enter app.

Reviewer note: Do not give reviewers your Apple password. If the app uses Sign in with Apple, reviewers can use their own Apple review account. If App Store Connect requires username/password fields, use placeholders and explain in notes.

## 9. Authentication

Decide:

- Is auth required?
- Which auth providers are allowed?
- What data exists before auth?
- What happens if auth fails?
- What backend profile row is created?
- What user ID is used for RevenueCat?

For iOS apps using third-party login, review Apple's Sign in with Apple rules. If Sign in with Apple is the only login, keep the flow simple: use Apple's identity, create/update the backend profile, and use the backend user ID consistently everywhere.

Implementation checklist:

- Add Sign in with Apple capability.
- Add entitlement.
- Request only needed scopes.
- Store backend session securely if possible.
- Bootstrap user profile after first auth.
- Use stable backend user ID for RevenueCat `appUserID`.
- Refresh auth state on launch.
- Make session-expired copy human, not technical.

## 10. Backend And Database

Create the schema before screens become too advanced.

Core tables usually include:

- profiles
- user_settings
- goals
- logs/workouts/meals
- saved_foods or reusable items
- subscriptions
- social relationships if needed
- proof posts/media if needed
- audit/events if needed

Function categories:

- auth/profile bootstrap
- dashboard read
- create/update/delete records
- AI parsing/estimation
- media upload
- social/follow/proof
- RevenueCat webhook
- support/contact

Use server-side validation. The app can be optimistic, but the backend should reject invalid visibility, ownership, and entitlement claims.

## 11. AI Features

AI should improve the workflow, not expose the workflow.

Do:

- Let users type/speak natural language.
- Convert input into structured drafts.
- Show assumptions.
- Require confirmation before saving.
- Preserve the user's original wording.
- Use reliable external data sources where available.
- Use AI to reconcile and refine evidence, not blindly invent defaults.

Do not:

- Show "parser," "tool," "agent," or function names to users.
- Save uncertain data without review.
- Return zero-calorie foods unless truly unresolved.
- Ask for "one more detail" on every entry.
- Let AI override obvious context, such as a food phrase becoming a workout.

For food logging, the better sequence is:

1. Preserve the raw user phrase.
2. Classify intent.
3. Split into likely food items.
4. Search saved foods first.
5. Query nutrition database/API.
6. Use AI to reconcile portions, brands, cuisines, and missing values.
7. If reliable enough, show editable result.
8. If not reliable enough, ask for the minimum missing detail.
9. Save confirmed foods to the user's reusable food list.

## 12. Voice

Voice adds UX risk. Treat it as a first-class workflow.

Checklist:

- Request microphone permission only when needed.
- Show clear listening state.
- Use haptics when recording starts/stops.
- Support tap to open AI page.
- Support long press/hold to record only if it is stable.
- Avoid freezing UI while recording/transcribing.
- Upload audio server-side if using server transcription.
- Show processing state after upload.
- Let users dismiss keyboard and redo entries.

If real-time speech is unstable, use local recording + server-side transcription. It is usually easier to debug and less likely to freeze than live streaming in v1.

## 13. Payments And Entitlements

Decide the business model early:

- Free
- Freemium
- Paid app
- Subscription
- Lifetime purchase
- Consumables

For Apple platforms, digital features must generally use Apple In-App Purchase. Follow App Review Guidelines and configure the products in App Store Connect.

For RevenueCat:

- Create project.
- Create app with correct bundle ID.
- Add App Store Connect integration.
- Create entitlement, e.g. `premium`.
- Create offering, e.g. `default`.
- Attach packages/products.
- Use production public SDK key in app.
- Keep secret API key server-side only.
- Use backend user ID as RevenueCat `appUserID`.
- Refresh entitlement on launch.
- Refresh after sign-in.
- Refresh after purchase.
- Refresh after restore.
- Display the active plan, not just "premium active."

For App Store Connect:

- Create subscription group.
- Create monthly/yearly subscriptions if applicable.
- Create non-consumable for lifetime if applicable.
- Add reference name.
- Add product ID.
- Add display name and description.
- Set pricing.
- Set availability.
- Add review notes.
- Add review screenshot if required.
- Confirm product IDs match the app and RevenueCat.

Important nuance: first IAP/subscription submissions must be submitted with a new app version. Apple says first IAPs/subscriptions, or a new type, should be included with the app version review.

TestFlight nuance: TestFlight IAP runs in sandbox. Subscription renewals are accelerated. Apple may ask for Apple Account authorization/password during sandbox purchases; that is separate from your app auth.

## 14. Legal Pages And Public URLs

Before TestFlight/App Review, publish:

- Landing page
- Privacy Policy
- Terms of Use
- EULA or Apple Standard EULA reference
- Support page/contact
- Optional user privacy choices/data deletion page

Apple requires a privacy policy URL for apps in App Store Connect. If the app collects user data or uses third-party SDKs, the policy must match actual behavior.

Pages must be publicly accessible, final, and not placeholders.

For apps with AI/nutrition/health context, include:

- Informational estimates disclaimer
- Not medical advice
- User controls over saved data
- Contact/support email
- Data deletion instructions
- Third-party services used
- Subscription and cancellation language

## 15. App Privacy And Privacy Manifest

Before submission, map actual data collection.

Inventory:

- Account identifiers
- Email
- Profile info
- Health/fitness logs
- Food/nutrition logs
- Photos
- Audio/transcription text
- Purchase history/entitlement state
- Device diagnostics
- Analytics, if any
- Third-party SDK data collection

Apple says privacy details must include the data collected by the app and third-party partners, and the answers must stay accurate. "Collect" includes transmitting data off-device in a way accessible beyond what is necessary for real-time servicing.

Create:

- `PrivacyInfo.xcprivacy`
- App Store privacy questionnaire source-of-truth document
- Privacy Policy URL
- User privacy choices/deletion instructions

For each data type, record:

- Collected or not
- Linked to user or not
- Used for tracking or not
- Purpose: app functionality, analytics, developer communications, etc.
- Third-party processors

## 16. App Store Metadata

Prepare metadata as files in the repo.

Minimum:

- Name
- Subtitle
- Promotional text
- Description
- Keywords
- Category
- Support URL
- Marketing URL
- Privacy URL
- Copyright
- Review contact
- Review notes
- Sign-in instructions
- IAP review notes

Keep metadata accurate. Apple explicitly expects screenshots, description, privacy info, and app behavior to match.

Review notes should include:

- How to sign in
- Whether reviewers should use Sign in with Apple
- How to find paid features
- How IAP works
- Any backend dependency
- Any permission explanation
- Any AI/nutrition disclaimers
- No personal Apple password

Example reviewer note for Sign in with Apple:

```text
Fitcountable requires Sign in with Apple before entering the main app. Please tap "Sign in with Apple" and use the reviewer Apple ID; no Fitcountable-specific username or password is required.

Premium uses Apple In-App Purchase through RevenueCat. Reviewers can test subscriptions using Apple's review/sandbox purchase flow. No developer Apple Account credentials are required.

AI commands are reviewed by the user before saving. Nutrition and macro values are informational estimates. Microphone/speech recognition is used only when the user taps or holds the voice command control. Proof photos are optional and user-initiated.
```

## 17. Screenshots And Visual Assets

Create App Store screenshots after the app is visually stable.

Checklist:

- Use final UI, not stale screenshots.
- Avoid duplicate screenshots.
- Avoid washed-out/low-contrast exports.
- Do not include fake AI visuals that were removed from the app.
- Show core workflow, not just profile/settings.
- Include paid screen if IAP review needs it.
- Make sure screenshots match the actual build.

Suggested screenshot order:

1. Main dashboard
2. AI command review
3. Manual logging
4. Social/accountability/proof
5. Premium/paywall

For paid apps/IAP, capture a review screenshot that clearly shows what is being offered.

## 18. Build And Signing

Standardize release commands.

For XcodeGen:

```bash
xcodegen generate --spec ios/project.yml
```

Build:

```bash
xcodebuild \
  -project ios/Fitcountable.xcodeproj \
  -scheme Fitcountable \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Archive:

```bash
xcodebuild \
  -project ios/Fitcountable.xcodeproj \
  -scheme Fitcountable \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath artifacts/App.xcarchive \
  -allowProvisioningUpdates \
  archive
```

Export:

```bash
xcodebuild \
  -exportArchive \
  -allowProvisioningUpdates \
  -archivePath artifacts/App.xcarchive \
  -exportPath artifacts/testflight \
  -exportOptionsPlist ios/ExportOptions-AppStore.plist
```

Validate:

```bash
xcrun altool --validate-app \
  -f artifacts/testflight/App.ipa \
  --type ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

Upload:

```bash
xcrun altool --upload-app \
  -f artifacts/testflight/App.ipa \
  --type ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

Always bump build number before upload.

## 19. TestFlight

After upload:

- Wait for processing.
- Add internal testers.
- Create external group if needed.
- Add beta app description.
- Add feedback email.
- Add "What to Test."
- Submit external beta review if external testers are needed.
- Confirm build appears in TestFlight.
- Install on a real device.

Test:

- Fresh install
- Sign in
- Onboarding
- Permissions
- Main dashboard
- Manual logs
- AI logs
- Voice logs
- Paid flow
- Restore purchases
- Dark mode
- Low connectivity
- Force close/reopen
- App review URLs

For subscriptions, remember TestFlight sandbox renewal is accelerated. A monthly subscription may renew daily for a limited cycle. Do not interpret that as production behavior.

## 20. Device Sanity Pass

Before App Store submission, do a final pass on a physical device.

Checklist:

- Fresh install starts cleanly.
- No demo/local-only language remains.
- Sign in with Apple works.
- User can complete onboarding.
- Dashboard matches day/date correctly.
- Logging food works.
- Logging workout works.
- Voice upload works.
- Processing indicators appear.
- Keyboard can be dismissed.
- User can redo a bad AI draft.
- Premium opens.
- Products load.
- Purchase sandbox path works.
- Restore works.
- Active plan is visible.
- Social/proof screens do not show fake/demo junk.
- Profile photo selection works.
- Privacy/terms/support links open public web pages.
- Dark mode is readable.
- App does not crash after force close/reopen.

## 21. App Review Submission

Before pressing submit:

- Build is selected.
- Screenshots uploaded.
- Metadata complete.
- Privacy questionnaire complete.
- Age rating complete.
- Content rights answered.
- Export compliance answered.
- App Review contact complete.
- Reviewer access notes clear.
- IAP/subscriptions attached if first submission.
- IAP review screenshots uploaded if required.
- Support/privacy/terms URLs live.
- Backend production environment is live.
- Webhook endpoints are live.
- No expired test keys.

Apple's App Review Guidelines expect final versions, complete metadata, functional URLs, reviewer access when login is required, and visible/functional IAPs.

## 22. Automation Opportunities

Future mobile apps should automate:

- PRD template creation
- Bundle ID/SKU/product ID generation
- XcodeGen scaffold
- Privacy questionnaire draft
- App Store metadata JSON
- Legal page scaffold
- Landing page scaffold
- App Store Connect API validation
- RevenueCat project/offering/entitlement validation
- Product ID consistency checks
- Screenshot capture
- Screenshot contact sheet
- Secret scan
- Simulator build
- Backend build
- Web build
- Archive/export/validate/upload
- TestFlight metadata update
- Reviewer notes generation
- Release status report

Automation should stop only for:

- Missing/invalid credentials
- Irreversible/destructive actions
- Legal/compliance choices that cannot be reasonably defaulted
- Apple manual UI steps that the API or browser automation cannot safely complete

## 23. Common Failure Points

### App Looks Built But Is Not Launch-Ready

Symptoms:

- Demo data is visible.
- Placeholder legal pages.
- Fake images.
- Dark mode unreadable.
- Screenshots do not match current app.
- Paid screen copy is unclear.

Fix: run a launch-readiness pass, not just a compile pass.

### IAP Products Load But Purchases Feel Broken

Check:

- Product IDs match App Store Connect exactly.
- RevenueCat offering has the products.
- Entitlement includes all products.
- App uses production public SDK key.
- App identifies the signed-in backend user in RevenueCat.
- Entitlement refreshes on launch, purchase, and restore.
- Dashboard filter is showing sandbox customers.
- TestFlight sandbox behavior is understood.

### Reviewers Cannot Sign In

Do not provide your Apple password.

If the app uses Sign in with Apple, instruct reviewers to use their review Apple ID. If the app has custom auth, provide a real demo account. If legal/security prevents demo accounts, Apple allows demo mode only with prior approval.

### AI Output Feels Random

Usually caused by:

- Weak intent classification
- No reliable source lookup
- Defaults instead of evidence
- Not preserving user wording
- Not using existing saved data
- Not asking targeted follow-up questions

Fix the sequence before adding more model prompts.

## 24. Source Links

Use current Apple docs when repeating this process:

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Connect App Privacy: https://developer.apple.com/help/app-store-connect/reference/app-privacy/
- App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi/
- App Store Connect API Overview: https://developer.apple.com/app-store-connect/api/
- In-App Purchase Information: https://developer.apple.com/help/app-store-connect/reference/in-app-purchase-information
- Configure In-App Purchases: https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- Submit an In-App Purchase: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
- Testing IAP in TestFlight: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight
- Troubleshooting IAP sandbox availability: https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox

## 25. The Launch Rule

The app is not ready because it compiles. It is ready when:

- A new user can understand it.
- A reviewer can access it.
- Paid features are clear and functional.
- Privacy answers match real behavior.
- URLs are live.
- Screenshots match the build.
- The backend is on.
- The app survives a force close and a fresh install.
- The team can explain every permission, purchase, and data flow.

That is the bar to automate toward.
