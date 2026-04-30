# Privacy Policy

**Flight Path**
Last updated: 30 April 2026

## 1. Introduction

Flight Path ("the App") is developed and operated by Edward Radford, a sole developer based in the United Kingdom ("we", "us", "our"). This Privacy Policy explains what personal data we collect, why we collect it, who processes it on our behalf, and your rights under the UK General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018.

The App is a training aid for student pilots working through the UK CAA PPL(A) syllabus. It does not replace professional flight instruction. Always follow your instructor's guidance and current CAA regulations.

## 2. Data Controller

Edward Radford
Email: contact@getflightpath.app
Privacy queries: privacy@getflightpath.app

## 3. Data we collect

### 3.1 Account information (you provide)
- Full name
- Email address
- Encrypted password (handled by Firebase Authentication — we never see the plaintext)

### 3.2 Training profile (you provide)
- Aircraft type (e.g. Cessna 152, PA-28)
- Flight school name
- Home airfield ICAO code

### 3.3 Generated through use of the App
- Lesson logs: dates, durations, exercise IDs, ratings, notes, personal reflections
- Exercise progress, completion status, and rating history
- Flashcard progress
- AI chat history with the in-app AI instructor (stored locally in Hive on your device, with the most recent training-context lessons synced to Firestore)
- AI lesson debrief outputs (returned by Anthropic's Claude API and saved against the lesson)
- Subscription status (whether you hold the £39 lifetime "Pro" entitlement)

### 3.4 Automatically collected
- Firebase Analytics events: anonymised usage patterns such as screens visited and features used
- Firebase Crashlytics: crash reports including device model, OS version, and stack traces
- Firebase Cloud Messaging token: a device-specific token used to deliver push notifications
- Firebase App Check token: a short-lived attestation that the request came from a legitimate copy of the App

## 4. What we don't collect

To be explicit, the App does **not** collect:

- Location data, GPS coordinates, or geolocation of any kind. Weather lookups use ICAO codes you type in, not your location.
- Biometric data (Face ID / Touch ID is handled by your device's operating system and never leaves it).
- Payment card numbers. Purchases are processed by Apple, Google, and RevenueCat — we only see the resulting subscription status.
- Photos, contacts, calendar entries, or any other device data outside the App.
- Audio recordings. The microphone is used only for live speech-to-text transcription during RT Practice (see section 6) and no audio is stored or transmitted to us.

## 5. How and why we use your data

| Purpose | Legal basis (UK GDPR Art. 6) |
|---|---|
| Operating the App's core features (lesson tracking, progress, flashcards) | Performance of contract — Art. 6(1)(b) |
| Generating AI lesson debriefs and AI chat responses | Legitimate interest — Art. 6(1)(f) |
| Sending push notifications (lesson reminders, spaced repetition) | Consent — Art. 6(1)(a) |
| Improving the App through anonymised analytics | Legitimate interest — Art. 6(1)(f) |
| Diagnosing crashes and bugs | Legitimate interest — Art. 6(1)(f) |
| Managing your subscription and entitlement | Performance of contract — Art. 6(1)(b) |
| Verifying requests come from a legitimate App install (App Check) | Legitimate interest — Art. 6(1)(f) |

## 6. Microphone and speech recognition

The App requests microphone access **only** when you open the RT Practice screen. When you tap to speak:

- Your speech is transcribed locally by your device's operating system (Apple Speech Recognition on iOS, Google Speech-to-Text on Android). On modern devices this transcription typically runs on-device; on older devices the OS may briefly send audio to Apple or Google for processing under their respective privacy policies.
- The resulting **text** is compared against the expected radiotelephony phrase to score your readback.
- Audio is **never** recorded, stored, or transmitted to our servers, to Anthropic, or to any other third party.
- The Text-to-Speech voice that reads ATC calls aloud uses your device's built-in TTS engine. No data leaves the device.

You can revoke microphone permission at any time in your device's system settings. The rest of the App will continue to work — only RT Practice voice features will be disabled.

## 7. Third-party processors

We use the following third-party services to operate the App. Each one only receives the data needed for its specific job.

### 7.1 Google Firebase (Google LLC / Google Ireland Ltd)
Authentication, Cloud Firestore, Cloud Functions, Analytics, Crashlytics, Cloud Messaging, App Check. Stores your account, training data, anonymised analytics, crash reports, and push tokens. EU-region servers used where available.
Privacy policy: https://firebase.google.com/support/privacy

### 7.2 Anthropic PBC
Powers the AI lesson debrief and the in-app AI instructor chat. We send your exercise name, ratings, instructor notes, personal reflections, and recent chat messages to the Claude API via our Cloud Functions. **No personal identifiers (name, email, user ID) are included in the prompts.** Anthropic does not train its models on data submitted through its commercial API and does not retain prompts beyond what is needed to serve the request, per Anthropic's Trust Center and commercial terms.
Privacy policy: https://www.anthropic.com/legal/privacy
Trust portal: https://trust.anthropic.com

### 7.3 RevenueCat, Inc.
Manages the £39 lifetime in-app purchase and the "Pro" entitlement. Receives an anonymous user ID, purchase receipts, and subscription status. Does not receive your name or email.
Privacy policy: https://www.revenuecat.com/privacy

### 7.4 AVWX Inc.
Aviation weather API used to fetch live METAR data when you enter an ICAO code in the Weather or METAR tools. The Cloud Function sends only the ICAO code (e.g. "EGTC") to AVWX. **No personal data, location, or user identifier is sent.**
Privacy policy: https://avwx.rest/

### 7.5 Apple App Store / Google Play
Process the actual lifetime purchase under their own terms. We never see your card details — only the resulting receipt, via RevenueCat.
Apple: https://www.apple.com/legal/privacy
Google: https://policies.google.com/privacy

## 8. Data storage and security

- Account data and training records are stored in Cloud Firestore on Google Cloud infrastructure, in EU regions where available.
- Data is encrypted in transit (TLS 1.2+) and at rest (AES-256) by Google Cloud.
- All Cloud Functions require a valid Firebase Authentication token and a valid App Check token.
- The Anthropic and AVWX API keys are held as Firebase Function secrets and never shipped inside the App binary.
- Access to the Firebase project is restricted to the developer.

## 9. Data retention

- Your data is retained for as long as your account is active.
- When you delete your account from inside the App (Settings → Delete Account), our `deleteUserAccount` Cloud Function permanently removes your Firestore documents, your Firebase Authentication record, your AI chat history, and your subscription record from RevenueCat — typically within seconds and at the latest within 30 days.
- Anonymised analytics events that are no longer linked to your account may be retained by Google Analytics under their standard retention period.
- Local data on your device (cached briefs, flashcards, AI chat history in Hive) is removed when you uninstall the App or sign out and clear app data.

## 10. Your rights (UK GDPR, Articles 13–22)

You have the right to:

- **Access (Art. 15)** — request a copy of the personal data we hold about you.
- **Rectification (Art. 16)** — update your profile in Settings → Edit Profile, or ask us to correct anything you can't change yourself.
- **Erasure (Art. 17)** — delete your account in Settings → Delete Account, or contact us.
- **Portability (Art. 20)** — request your data in a machine-readable format.
- **Restriction (Art. 18)** — ask us to limit how we process your data.
- **Objection (Art. 21)** — object to processing based on legitimate interest.
- **Withdraw consent** — disable push notifications or revoke microphone access at any time in your device settings.

To exercise any of these rights, email privacy@getflightpath.app. We will respond within 30 calendar days.

## 11. Children

The App is intended for student pilots and is not directed at children under the age of 16. The minimum age aligns with the typical first-solo age in UK PPL training. We do not knowingly collect personal data from anyone under 16. If you believe we have inadvertently collected data from a child under 16, please contact privacy@getflightpath.app and we will delete it promptly.

## 12. International data transfers

Some processors (Anthropic, RevenueCat, AVWX) operate from outside the United Kingdom. Where personal data is transferred internationally, we rely on the safeguards built into those providers' standard agreements — Standard Contractual Clauses (SCCs) and the UK addendum, or applicable adequacy decisions — so that the level of protection remains equivalent to UK GDPR.

## 13. Changes to this policy

We may update this Privacy Policy as the App evolves. The "Last updated" date at the top of the policy reflects when it was last revised. Material changes will be communicated in-app or by email.

## 14. Complaints

If you are not satisfied with how we handle your data, you have the right to lodge a complaint with the UK Information Commissioner's Office (ICO):

- Website: https://ico.org.uk
- Telephone: 0303 123 1113

## 15. Contact

For any privacy question or to exercise your rights:

Edward Radford
Email: privacy@getflightpath.app
General contact: contact@getflightpath.app
