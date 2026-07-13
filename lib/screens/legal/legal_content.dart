/// Privacy Policy and Terms of Service content for Hunter Ascend.
///
/// These are displayed in-app via [LegalDocumentScreen]. Plain text format
/// with section headers in uppercase for readability.

const String privacyPolicyText = '''
PRIVACY POLICY

Last Updated: July 13, 2026

Hunter Ascend ("we", "our", "us") operates the Hunter Ascend mobile application. This Privacy Policy explains how we collect, use, and protect your information.


INFORMATION WE COLLECT

Account Data
When you create an account, we collect your hunter name, age, height, weight, and fitness goals. If you sign in with Google, we receive your email address and display name via Google Sign-In.

Usage Data
We collect data about how you use the app, including completed quests, steps tracked, streaks, XP earned, and duel participation.

Health & Fitness Data
With your permission, we access step count data from your device's pedometer (via the activity recognition permission). This data is used solely to track your daily steps within the app.

Location Data
With your permission, we access your device's GPS location for the run-tracking feature (Map screen). Location data is used to display your route on the map and calculate distance. We do not store location history on our servers — only the route points for your saved runs are stored in your Firestore document.

Camera & Photo Library
With your permission, we access your device's camera and photo library for:
- Uploading a profile picture.
- Photographing food for AI-powered calorie estimation.
Images are compressed locally and stored as Base64 data in your Firestore user document (profile picture) or processed temporarily by our AI service (food photos are not stored permanently).

Profile Pictures
If you upload a profile picture, it is stored as compressed data within your Firestore user document.


HOW WE USE YOUR INFORMATION

- To provide and maintain the Hunter Ascend service.
- To personalize your experience (AI-generated quests based on your fitness data).
- To display your profile on leaderboards and in duels.
- To track your progress and award XP.
- To send you mission reminders via local notifications (if enabled).
- To display advertisements (for non-premium users).


THIRD-PARTY SERVICES

We use the following third-party services:

- Firebase Authentication — Google LLC (account management, anonymous and Google Sign-In)
- Cloud Firestore — Google LLC (data storage)
- Google Mobile Ads (AdMob) — Google LLC (advertising)
- Gemini AI — Google LLC (quest generation and calorie estimation, via our Cloudflare Worker proxy)
- Mistral AI — Mistral AI (quest generation, via our Cloudflare Worker proxy)
- Groq — Groq Inc. (calorie estimation fallback, via our Cloudflare Worker proxy)
- Facebook App Events — Meta Platforms, Inc. (app activation tracking)
- Google Sign-In — Google LLC (authentication)
- Workmanager — (background task scheduling for notifications)

These services may collect data according to their own privacy policies.


NOTIFICATIONS

Hunter Ascend may send local notifications to remind you to complete your daily missions. Notifications are scheduled locally on your device using Workmanager and flutter_local_notifications. You can enable or disable reminders within the app. We do not send push notifications from a remote server.


ADVERTISING

Basic users see banner ads and rewarded ads served by Google AdMob. Pro users see rewarded ads only (no banner ads). Max members do not see any ads. Ad personalization is handled by Google according to your device's ad settings.


DATA STORAGE

Your data is stored in Google Cloud Firestore. We do not sell your personal data to third parties.


DATA RETENTION

Your account data is retained as long as your account is active. Anonymous accounts can be deleted at any time from Settings. If you delete your account, your data is permanently removed from our servers.


CHILDREN'S PRIVACY

Hunter Ascend is not intended for children under 13. We do not knowingly collect personal information from children under 13.


YOUR RIGHTS

You may request deletion of your account and all associated data at any time by using the account deletion feature in Settings, or by contacting us at the email below.


CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Changes will be reflected by the "Last Updated" date at the top of this document.


CONTACT US

If you have questions about this Privacy Policy, contact us at:
hunterascendapp@gmail.com


────────────────────────────────

Hunter Ascend
Version 1.0

\u00a9 2026 Hunter Ascend. All rights reserved.
''';

const String termsOfServiceText = '''
TERMS OF SERVICE

Last Updated: July 13, 2026

Please read these Terms of Service ("Terms") carefully before using the Hunter Ascend mobile application ("the App") operated by Hunter Ascend ("we", "our", "us").

By downloading, installing, or using the App, you agree to be bound by these Terms.


1. ACCEPTANCE OF TERMS

By using Hunter Ascend, you agree to these Terms and our Privacy Policy. If you do not agree, do not use the App.


2. ACCOUNT

You are responsible for maintaining the security of your account. You may not share your account credentials or use another person's account. We reserve the right to suspend or terminate accounts that violate these Terms.


3. MEMBERSHIP & SUBSCRIPTIONS

Hunter Ascend offers optional paid memberships (Pro and Max). Subscriptions are billed monthly through Google Play. By subscribing, you agree to the following:

- Payment will be charged to your Google Play account at confirmation of purchase.
- Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current billing period.
- You can manage or cancel your subscription in your Google Play Store account settings.
- No refunds are provided for partial billing periods.

Membership benefits are described on the Membership screen within the App. We reserve the right to modify membership features with reasonable notice.


4. USER RESPONSIBILITIES

You agree to:
- Provide accurate information when creating your account.
- Use the App only for its intended purpose (personal fitness tracking and gamification).
- Not attempt to manipulate leaderboards, XP, or streaks through unauthorized means.
- Not use the App to harass, threaten, or harm other users.
- Not reverse-engineer, decompile, or attempt to extract the source code of the App.


5. AI-GENERATED CONTENT

Hunter Ascend uses artificial intelligence to generate personalized fitness quests. AI-generated content is provided for informational and motivational purposes only. It does not constitute medical, health, or fitness advice. Always consult a qualified professional before starting any exercise program.


6. HEALTH DISCLAIMER

Hunter Ascend is a fitness gamification app, not a medical device. We do not provide medical advice. You use the fitness features (step tracking, calorie estimation, workout missions) at your own risk. Stop any activity immediately if you experience pain or discomfort.


7. INTELLECTUAL PROPERTY

All content, design, code, and branding within Hunter Ascend is owned by us or our licensors. You may not copy, modify, or distribute any part of the App without written permission.


8. ACCOUNT TERMINATION

We may suspend or terminate your account at our discretion if:
- You violate these Terms.
- You engage in fraudulent activity.
- You manipulate app systems (XP, streaks, leaderboards).
- Your account has been inactive for an extended period.

Upon termination, your right to use the App ceases immediately.


9. LIMITATION OF LIABILITY

Hunter Ascend is provided "as is" without warranties of any kind. To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App.

We do not guarantee uninterrupted access to the App, and we are not responsible for data loss due to device failure, network issues, or server outages.


10. PRIVACY

Your use of the App is also governed by our Privacy Policy, which describes how we collect, use, and protect your information.


11. CHANGES TO THESE TERMS

We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the revised Terms. Material changes will be communicated through the App.


12. GOVERNING LAW

These Terms are governed by the laws of India. Any disputes arising from these Terms shall be subject to the jurisdiction of the courts in India.


13. CONTACT US

If you have questions about these Terms, contact us at:
hunterascendapp@gmail.com


────────────────────────────────

Hunter Ascend
Version 1.0

\u00a9 2026 Hunter Ascend. All rights reserved.
''';
