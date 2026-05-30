# Fitcountable App Privacy Label Plan

Use this as the App Store Connect App Privacy questionnaire source of truth for the current launch build.

## Tracking
- Does this app track users across apps and websites owned by other companies? **No**
- Uses IDFA? **No**

## Data Linked To The User
These are linked to the user because Fitcountable stores them against the user profile/session or account-backed records.

### Contact Info
- Email Address: account identity, support, App Review/demo fallback.
- Name: display name/profile identity.

Purpose: App Functionality, Account Management, Customer Support.

### User Content
- Photos or Videos: optional proof photos/profile photos/meal context photos.
- Audio Data: user-initiated voice recordings uploaded for transcription.
- Customer Support: support requests and deletion/privacy contacts.
- Other User Content: typed meal/workout commands, captions, proof posts, workout logs, food logs, plans, goals, social/accountability content.

Purpose: App Functionality, Account Management, Customer Support.

### Health and Fitness
- Fitness: workouts, sets, reps, weights, consistency, goals.
- Health: nutrition targets, food logs, calories/macros, diet preferences.

Purpose: App Functionality.

### Purchases
- Purchase History: subscription/purchase entitlement state through App Store/RevenueCat.

Purpose: App Functionality, Account Management.

### Identifiers
- User ID: app/backend user id, Sign in with Apple user identifier, RevenueCat app user id.

Purpose: App Functionality, Account Management.

### Usage Data
- Product Interaction: app events needed for app functionality, debugging, feature usage, AI command limits, premium entitlement checks.

Purpose: App Functionality, Analytics.

### Diagnostics
- Crash Data / Performance Data: if Apple/Xcode or operational logging surfaces crash/performance diagnostics.

Purpose: App Functionality, Analytics.

## Data Not Used For Tracking
All selected data above should be marked **not used for tracking**.

## Sensitive Data Notes
Fitcountable should not claim medical diagnosis/treatment. Nutrition and macro values are informational estimates and user-reviewed before saving.

## Permissions In App Binary
- Microphone: spoken commands and local recording upload.
- Speech recognition: local speech workflow where used.
- Camera: optional proof/menu/profile photos.
- Photo library: optional existing proof/menu/profile photos.
- Notifications: reminders/accountability nudges chosen by the user.
