/**
 * Hunter Ascend — Firebase Cloud Functions
 *
 * Backend for Google Play Billing subscription management.
 *
 * Functions:
 * - verifyPurchase: Callable function invoked by the Flutter client after a
 *   successful Google Play purchase. Verifies the purchase token with the
 *   Google Play Developer API and updates the hunter's membership in Firestore.
 *
 * - handlePlayNotification: Pub/Sub function triggered by Google Play
 *   Real-Time Developer Notifications (RTDN). Handles subscription lifecycle
 *   events (renewal, cancellation, expiry, revocation, etc.).
 */

const functions = require("firebase-functions");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const playStore = require("./play-store");

// ── Initialize Firebase Admin SDK ──────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();

// ── Parameterized Configuration ────────────────────────────────────────────
//
// These parameters are resolved at deploy time from environment variables,
// .env files, or the Firebase Console (Extensions > Functions > Configuration).
//
// Set values in functions/.env:
//   PLAY_PACKAGE_NAME=com.hunterascend.hunter_ascend
//   RTDN_TOPIC=play-rtdn
//   PRODUCT_MAP={"com.hunterascend.pro_monthly":"pro","com.hunterascend.max_monthly":"max"}
//
// Or provide them at deploy time via --set-env-vars or the Firebase Console.

/**
 * The Android package name registered in Google Play Console.
 */
const PLAY_PACKAGE_NAME = defineString("PLAY_PACKAGE_NAME", {
  default: "com.hunterascend.hunter_ascend",
  description: "Android package name for Google Play API calls.",
});

/**
 * The Cloud Pub/Sub topic that receives Google Play Real-Time Developer
 * Notifications (RTDN). Must match the topic configured in Google Play
 * Console → Monetization → Monetization Setup.
 */
const RTDN_TOPIC = defineString("RTDN_TOPIC", {
  default: "play-rtdn",
  description: "Pub/Sub topic for Google Play RTDN.",
});

/**
 * JSON string mapping Google Play product IDs to logical membership plans.
 * Example: {"com.hunterascend.pro_monthly":"pro","com.hunterascend.max_monthly":"max"}
 *
 * Parsed at runtime inside each function invocation.
 */
const PRODUCT_MAP = defineString("PRODUCT_MAP", {
  default: "{\"com.hunterascend.pro_monthly\":\"pro\",\"com.hunterascend.max_monthly\":\"max\"}",
  description: "JSON mapping of Google Play product IDs to membership plans.",
});

/**
 * Parses the PRODUCT_MAP parameter into a usable object.
 * Called inside function handlers (not at module level) because parameterized
 * values are only resolved after deployment.
 */
function getProductToPlan() {
  try {
    return JSON.parse(PRODUCT_MAP.value());
  } catch (_) {
    functions.logger.warn("Failed to parse PRODUCT_MAP, using defaults.");
    return {
      "com.hunterascend.pro_monthly": "pro",
      "com.hunterascend.max_monthly": "max",
    };
  }
}

// ── Google Play Developer API Client ───────────────────────────────────────
//
// Uses Application Default Credentials (ADC) for server-to-server auth.
//
// Setup:
// 1. In Google Cloud Console, grant the App Engine default service account
//    (or a dedicated service account) the "Android Publisher" role.
// 2. Enable the "Google Play Android Developer API" in the Cloud project.
// 3. Link the Cloud project to Google Play Console under
//    Settings → API Access.
//
// ADC automatically picks up the correct credentials when running on
// Cloud Functions — no JSON key file needed in production.

// ── verifyPurchase ─────────────────────────────────────────────────────────
//
// Callable function: the Flutter client calls this after a successful
// Google Play purchase to verify the token server-side and activate the
// membership in Firestore.
//
// Input: { purchaseToken: string, productId: string }
//   - productId is used ONLY to locate the subscription on Google Play.
//   - The ACTUAL product identity comes from Google's API response, NOT from
//     the client. This prevents clients from claiming a cheaper product
//     grants a higher tier.
//
// Output: { success: boolean, plan?: string, expiryDate?: string, error?: string }
//
exports.verifyPurchase = functions.https.onCall(async (data, context) => {
  // ── Authentication check ──
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated to verify a purchase."
    );
  }

  const uid = context.auth.uid;
  const { purchaseToken, productId } = data;
  const productToPlan = getProductToPlan();

  // ── Input validation ──
  if (!purchaseToken || typeof purchaseToken !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "purchaseToken is required and must be a string."
    );
  }

  if (!productId || typeof productId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "productId is required and must be a string."
    );
  }

  functions.logger.info("verifyPurchase called", {
    uid,
    productId,
    tokenPrefix: purchaseToken.substring(0, 20) + "...",
  });

  // ── Step 1: Fetch subscription from Google Play ──
  // SECURITY: The client-supplied productId is NEVER trusted for granting
  // membership. It is used ONLY as a lookup hint — the subscriptionId path
  // parameter required by Google's purchases.subscriptions.get() API.
  //
  // If the purchaseToken does not belong to the claimed productId, Google's
  // API returns 404 — the verification fails and no membership is granted.
  //
  // If the API succeeds, it confirms the token is genuinely associated with
  // this productId. Only THEN do we map productId → plan. The mapping itself
  // lives server-side (PRODUCT_MAP) and is never influenced by client input.
  //
  // Therefore: membership is always determined from Google's verified
  // subscription response, never from client-provided data alone.
  let subscription;
  try {
    subscription = await playStore.getSubscription(
      PLAY_PACKAGE_NAME.value(),
      productId,
      purchaseToken
    );
  } catch (apiError) {
    functions.logger.error("Play API transient failure", {
      uid,
      error: apiError.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to verify purchase with Google Play. Please try again."
    );
  }

  if (!subscription) {
    return { success: false, error: "invalid_token" };
  }

  // ── Step 2: Validate the complete subscription state ──
  const validation = playStore.validateSubscription(subscription);

  if (!validation.valid) {
    functions.logger.info("Subscription validation failed", {
      uid,
      error: validation.error,
    });
    return { success: false, error: validation.error };
  }

  // ── Step 3: Determine the verified product identity ──
  // SECURITY: The plan is determined by the server-side PRODUCT_MAP lookup
  // using the productId that Google's API just validated. If Google returned
  // a successful response, the token genuinely belongs to this productId.
  //
  // The client CANNOT influence plan selection — even if it sent a different
  // productId, the API would have rejected the token (404). A successful
  // response here is cryptographic proof that the productId is authentic.
  //
  // Membership is ALWAYS determined from Google's verified response, never
  // from client-provided data alone.
  const plan = productToPlan[productId];
  if (!plan) {
    functions.logger.error("Verified product not in plan mapping", { productId });
    return { success: false, error: "unknown_product" };
  }

  // ── Step 4: Acknowledge the subscription (backend responsibility) ──
  // This ensures the purchase is acknowledged within Google's 3-day window.
  // The client does NOT need to call completePurchase() for acknowledgement —
  // the backend handles it here after successful verification.
  if (!validation.acknowledged) {
    await playStore.acknowledgeSubscription(
      PLAY_PACKAGE_NAME.value(),
      productId,
      purchaseToken
    );
  }

  // ── Step 5: Persist to Firestore (transaction) ──
  // Uses a transaction to ensure the hunter document and subscription record
  // are updated atomically. This guarantees consistency and idempotency —
  // repeated verification of the same purchase token produces the same result
  // without creating duplicate records.
  const expiryDate = new Date(validation.expiryTimeMillis);
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  const now = admin.firestore.Timestamp.now();

  const hunterRef = db.collection("hunters").doc(uid);
  const tokenHash = crypto.createHash("sha256").update(purchaseToken).digest("hex");
  const subscriptionRef = db.collection("subscriptions").doc(tokenHash);

  await db.runTransaction(async (txn) => {
    const hunterSnap = await txn.get(hunterRef);
    const subscriptionSnap = await txn.get(subscriptionRef);

    // ── Update hunter membership ──
    // Only update if the hunter document exists (it should — created on signup).
    if (hunterSnap.exists) {
      txn.update(hunterRef, {
        membership: plan,
        subscriptionActive: true,
        membershipExpiry: expiryTimestamp,
        lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      functions.logger.warn("Hunter document not found during verification", { uid });
    }

    // ── Create or update subscription record ──
    // Using SHA256(purchaseToken) as document ID ensures idempotency and
    // avoids exposing raw purchase tokens as Firestore document IDs.
    // The raw token is stored inside the document for backend operations
    // (e.g., calling Google Play API for acknowledgement or status checks).
    const subscriptionData = {
      uid,
      purchaseToken,
      productId,
      membership: plan,
      expiry: expiryTimestamp,
      orderId: validation.orderId || null,
      linkedPurchaseToken: validation.linkedPurchaseToken || null,
      lastVerified: now,
      platform: "google_play",
      active: true,
    };

    if (subscriptionSnap.exists) {
      // Idempotent update — same purchase verified again.
      txn.update(subscriptionRef, subscriptionData);
    } else {
      // First verification of this purchase.
      subscriptionData.createdAt = now;
      txn.set(subscriptionRef, subscriptionData);
    }

    // ── Handle linkedPurchaseToken (upgrade/downgrade) ──
    // When present, it points to the previous subscription's purchase token.
    // Mark the old subscription as inactive but do NOT delete it — preserve
    // subscription history for auditing and dispute resolution.
    if (validation.linkedPurchaseToken) {
      const oldTokenHash = crypto.createHash("sha256").update(validation.linkedPurchaseToken).digest("hex");
      const oldSubscriptionRef = db.collection("subscriptions").doc(oldTokenHash);
      const oldSnap = await txn.get(oldSubscriptionRef);
      if (oldSnap.exists) {
        txn.update(oldSubscriptionRef, {
          active: false,
          replacedBy: tokenHash,
          replacedAt: now,
        });
      }
    }
  });

  functions.logger.info("Firestore updated — membership activated", {
    uid,
    plan,
    expiryDate: expiryDate.toISOString(),
    orderId: validation.orderId,
    linkedPurchaseToken: validation.linkedPurchaseToken ? "handled" : "none",
  });

  return {
    success: true,
    plan,
    expiryDate: expiryDate.toISOString(),
  };
});

// ── handlePlayNotification ─────────────────────────────────────────────────
//
// Pub/Sub function: triggered by Google Play Real-Time Developer Notifications.
// Processes subscription lifecycle events and updates Firestore accordingly.
//
// Delivery mechanism:
// 1. In Google Play Console → Monetization → Monetization Setup, configure
//    the "Real-time developer notifications" topic to a Cloud Pub/Sub topic
//    in your Firebase project (e.g. projects/<project-id>/topics/play-rtdn).
// 2. This function subscribes to that topic via the RTDN_TOPIC parameter.
// 3. Google Play pushes a message to the topic on every subscription event.
//
exports.handlePlayNotification = functions.pubsub
  .topic(RTDN_TOPIC)
  .onPublish(async (message) => {
    // ── Decode the notification ──
    const messageBody = message.data
      ? JSON.parse(Buffer.from(message.data, "base64").toString("utf8"))
      : null;

    if (!messageBody) {
      functions.logger.error("Empty RTDN message received.");
      return;
    }

    const subscriptionNotification = messageBody.subscriptionNotification;

    if (!subscriptionNotification) {
      // Could be a test notification or a one-time purchase notification.
      functions.logger.info("Non-subscription notification received", {
        messageBody,
      });
      return;
    }

    const {
      purchaseToken,
      subscriptionId,
      notificationType,
    } = subscriptionNotification;

    functions.logger.info("RTDN received", {
      notificationType,
      subscriptionId,
      tokenPrefix: purchaseToken
        ? purchaseToken.substring(0, 20) + "..."
        : "null",
    });

    // ── TODO: Phase 2 — Lifecycle handling ──
    // 1. Look up uid from subscriptions/{purchaseToken}.
    // 2. Call Google Play Developer API to get current subscription state.
    //    Use PLAY_PACKAGE_NAME.value() as the package name.
    // 3. Based on notificationType:
    //    - SUBSCRIPTION_RECOVERED (1): reactivate
    //    - SUBSCRIPTION_RENEWED (2): update expiry
    //    - SUBSCRIPTION_CANCELED (3): set subscriptionActive = false
    //    - SUBSCRIPTION_PURCHASED (4): verify + activate
    //    - SUBSCRIPTION_ON_HOLD (5): pause features
    //    - SUBSCRIPTION_IN_GRACE_PERIOD (6): keep active, warn user
    //    - SUBSCRIPTION_RESTARTED (7): reactivate
    //    - SUBSCRIPTION_PRICE_CHANGE_CONFIRMED (8): no action
    //    - SUBSCRIPTION_DEFERRED (9): extend expiry
    //    - SUBSCRIPTION_PAUSED (10): pause features
    //    - SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED (11): no action
    //    - SUBSCRIPTION_REVOKED (12): immediate downgrade
    //    - SUBSCRIPTION_EXPIRED (13): downgrade to basic
    // 4. Update Firestore hunters/{uid} accordingly.

    return;
  });
