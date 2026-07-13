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
// SECURITY: Never trusts the RTDN payload alone. Always verifies the current
// subscription state with Google Play Developer API before updating Firestore.
//
// IDEMPOTENCY: Repeated delivery of the same notification produces the same
// Firestore state. All updates are idempotent by design.
//
// Delivery mechanism:
// 1. In Google Play Console → Monetization → Monetization Setup, configure
//    the "Real-time developer notifications" topic to a Cloud Pub/Sub topic
//    in your Firebase project (e.g. projects/<project-id>/topics/play-rtdn).
// 2. This function subscribes to that topic via the RTDN_TOPIC parameter.
// 3. Google Play pushes a message to the topic on every subscription event.
//

// Notification type constants (from Google Play documentation).
const NOTIFICATION_TYPE = {
  SUBSCRIPTION_RECOVERED: 1,
  SUBSCRIPTION_RENEWED: 2,
  SUBSCRIPTION_CANCELED: 3,
  SUBSCRIPTION_PURCHASED: 4,
  SUBSCRIPTION_ON_HOLD: 5,
  SUBSCRIPTION_IN_GRACE_PERIOD: 6,
  SUBSCRIPTION_RESTARTED: 7,
  SUBSCRIPTION_PRICE_CHANGE_CONFIRMED: 8,
  SUBSCRIPTION_DEFERRED: 9,
  SUBSCRIPTION_PAUSED: 10,
  SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED: 11,
  SUBSCRIPTION_REVOKED: 12,
  SUBSCRIPTION_EXPIRED: 13,
};

exports.handlePlayNotification = functions.pubsub
  .topic(RTDN_TOPIC)
  .onPublish(async (message) => {
    // ── Step 1: Validate and decode the Pub/Sub payload ──
    let messageBody;
    try {
      messageBody = message.data
        ? JSON.parse(Buffer.from(message.data, "base64").toString("utf8"))
        : null;
    } catch (parseError) {
      functions.logger.error("Malformed RTDN payload — cannot parse", {
        error: parseError.message,
      });
      return; // Ack the message to prevent infinite retries on bad data.
    }

    if (!messageBody) {
      functions.logger.error("Empty RTDN message received.");
      return;
    }

    const subscriptionNotification = messageBody.subscriptionNotification;

    if (!subscriptionNotification) {
      // Test notification or one-time purchase — not a subscription event.
      functions.logger.info("Non-subscription notification received", {
        messageBody,
      });
      return;
    }

    // ── Step 2: Extract notification fields ──
    const {
      purchaseToken,
      subscriptionId,
      notificationType,
    } = subscriptionNotification;

    const eventTime = messageBody.eventTimeMillis
      ? parseInt(messageBody.eventTimeMillis, 10)
      : Date.now();

    if (!purchaseToken || !subscriptionId) {
      functions.logger.error("RTDN missing purchaseToken or subscriptionId", {
        notificationType,
      });
      return;
    }

    functions.logger.info("RTDN received", {
      event: "rtdn_received",
      notificationType,
      subscriptionId,
      tokenHash: crypto.createHash("sha256").update(purchaseToken).digest("hex"),
      timestamp: new Date().toISOString(),
    });

    // ── Step 3: Lookup subscription record to find uid ──
    const tokenHash = crypto.createHash("sha256").update(purchaseToken).digest("hex");
    const subscriptionRef = db.collection("subscriptions").doc(tokenHash);
    const subscriptionSnap = await subscriptionRef.get();

    let uid;
    let productId = subscriptionId; // fallback to subscriptionId from RTDN

    if (subscriptionSnap.exists) {
      const subData = subscriptionSnap.data();
      uid = subData.uid;
      productId = subData.productId || subscriptionId;
    } else {
      // Subscription not in our records — this can happen if:
      // - SUBSCRIPTION_PURCHASED arrived before verifyPurchase() was called.
      // - The subscription was created outside our app flow.
      // We cannot process without a uid. Log and skip.
      functions.logger.warn("RTDN for unknown subscription — no uid found", {
        tokenHash,
        notificationType,
        subscriptionId,
      });
      return;
    }

    // ── Step 4: Verify current state with Google Play (NEVER trust RTDN alone) ──
    let subscription;
    try {
      subscription = await playStore.getSubscription(
        PLAY_PACKAGE_NAME.value(),
        productId,
        purchaseToken
      );
    } catch (apiError) {
      functions.logger.error("RTDN: Play API failure — will retry on next delivery", {
        uid,
        notificationType,
        error: apiError.message,
      });
      // Throw to trigger Pub/Sub retry (message will be redelivered).
      throw apiError;
    }

    if (!subscription) {
      functions.logger.warn("RTDN: Google returned null for subscription", {
        uid,
        notificationType,
        tokenHash,
      });
      return;
    }

    // ── Step 5: Determine Firestore updates based on verified Google state ──
    const productToPlan = getProductToPlan();
    const plan = productToPlan[productId] || null;
    const expiryTimeMillis = parseInt(subscription.expiryTimeMillis, 10) || 0;
    const expiryTimestamp = expiryTimeMillis
      ? admin.firestore.Timestamp.fromDate(new Date(expiryTimeMillis))
      : null;
    const now = admin.firestore.Timestamp.now();
    const paymentState = subscription.paymentState;
    const isExpired = expiryTimeMillis <= Date.now();
    const linkedPurchaseToken = subscription.linkedPurchaseToken || null;

    // Determine what to write based on the VERIFIED Google state
    // (not the notification type alone).
    let hunterUpdate = null;
    let subscriptionUpdate = null;
    let subscriptionStatus = "unknown";

    switch (notificationType) {
      // ── Active subscription events ──────────────────────────────────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_PURCHASED:
      case NOTIFICATION_TYPE.SUBSCRIPTION_RENEWED:
      case NOTIFICATION_TYPE.SUBSCRIPTION_RECOVERED:
      case NOTIFICATION_TYPE.SUBSCRIPTION_RESTARTED: {
        // Verify the subscription is actually active and not expired.
        if (isExpired || (paymentState !== 1 && paymentState !== 2)) {
          functions.logger.warn("RTDN activation event but subscription not active", {
            uid, notificationType, paymentState, isExpired,
          });
          // Still update with what Google says — don't leave stale state.
        }

        if (!isExpired && plan) {
          hunterUpdate = {
            membership: plan,
            subscriptionActive: true,
            membershipExpiry: expiryTimestamp,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "active";
        } else {
          // Google says expired despite activation event — downgrade.
          hunterUpdate = {
            membership: "basic",
            subscriptionActive: false,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "expired";
        }
        break;
      }

      // ── Cancellation (auto-renew disabled, access continues) ─────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_CANCELED: {
        // Cancellation only means auto-renew has been disabled.
        // The user KEEPS full access until the subscription period ends
        // (EXPIRED or REVOKED). Do NOT remove access here.
        if (!isExpired && plan) {
          hunterUpdate = {
            membership: plan,
            subscriptionActive: true,
            membershipExpiry: expiryTimestamp,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "canceled";
        } else {
          // Already past expiry — treat as expired.
          hunterUpdate = {
            membership: "basic",
            subscriptionActive: false,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "expired";
        }
        break;
      }

      // ── Grace period (payment failing, still active temporarily) ────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_IN_GRACE_PERIOD: {
        // Keep features active during grace period.
        if (plan) {
          hunterUpdate = {
            membership: plan,
            subscriptionActive: true,
            membershipExpiry: expiryTimestamp,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "grace_period";
        }
        break;
      }

      // ── On hold / Paused (features suspended, tier preserved) ──────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_ON_HOLD:
      case NOTIFICATION_TYPE.SUBSCRIPTION_PAUSED: {
        // Suspend subscription active flag but keep the membership tier.
        // The user's plan is preserved — only the active state changes.
        // Access will resume on RECOVERED/RESTARTED or end on EXPIRED.
        hunterUpdate = {
          subscriptionActive: false,
          lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
        };
        subscriptionStatus = notificationType === NOTIFICATION_TYPE.SUBSCRIPTION_ON_HOLD
          ? "on_hold"
          : "paused";
        break;
      }

      // ── Expiry (subscription period ended) ──────────────────────────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_EXPIRED: {
        // Downgrade to basic immediately.
        hunterUpdate = {
          membership: "basic",
          subscriptionActive: false,
          lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
        };
        subscriptionStatus = "expired";
        break;
      }

      // ── Revocation (refund or administrative action) ────────────────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_REVOKED: {
        // Immediate downgrade — no grace period.
        hunterUpdate = {
          membership: "basic",
          subscriptionActive: false,
          lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
        };
        subscriptionStatus = "revoked";
        break;
      }

      // ── Deferred (subscription extended by developer) ───────────────────
      case NOTIFICATION_TYPE.SUBSCRIPTION_DEFERRED: {
        // Update expiry to the new deferred date.
        if (expiryTimestamp && plan) {
          hunterUpdate = {
            membership: plan,
            subscriptionActive: true,
            membershipExpiry: expiryTimestamp,
            lastMembershipVerification: admin.firestore.FieldValue.serverTimestamp(),
          };
          subscriptionStatus = "active";
        }
        break;
      }

      // ── Informational (no membership change, but record the event) ─────
      case NOTIFICATION_TYPE.SUBSCRIPTION_PRICE_CHANGE_CONFIRMED:
      case NOTIFICATION_TYPE.SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED: {
        // No membership or access change needed, but update tracking
        // timestamps so the subscription record reflects recent activity.
        subscriptionStatus = notificationType === NOTIFICATION_TYPE.SUBSCRIPTION_PRICE_CHANGE_CONFIRMED
          ? "price_change_confirmed"
          : "pause_schedule_changed";
        break;
      }

      default: {
        functions.logger.warn("RTDN unknown notification type", {
          uid, notificationType,
        });
        return;
      }
    }

    // ── Step 6: Update Firestore in a transaction ──
    const hunterRef = db.collection("hunters").doc(uid);

    await db.runTransaction(async (txn) => {
      const hunterSnap = await txn.get(hunterRef);
      const subSnap = await txn.get(subscriptionRef);

      // Update hunter document (only if there are membership changes).
      if (hunterUpdate && hunterSnap.exists) {
        txn.update(hunterRef, hunterUpdate);
      }

      // Always update subscription record timestamps + status.
      const subUpdate = {
        lastVerified: now,
        status: subscriptionStatus,
        updatedAt: now,
        active: subscriptionStatus === "active" ||
                subscriptionStatus === "grace_period" ||
                subscriptionStatus === "canceled",
      };

      if (expiryTimestamp) {
        subUpdate.expiry = expiryTimestamp;
      }
      if (plan) {
        subUpdate.membership = plan;
      }

      if (subSnap.exists) {
        txn.update(subscriptionRef, subUpdate);
      }

      // Handle linkedPurchaseToken (upgrade/downgrade chain).
      if (linkedPurchaseToken) {
        const oldTokenHash = crypto.createHash("sha256").update(linkedPurchaseToken).digest("hex");
        const oldSubRef = db.collection("subscriptions").doc(oldTokenHash);
        const oldSnap = await txn.get(oldSubRef);
        if (oldSnap.exists) {
          txn.update(oldSubRef, {
            active: false,
            status: "replaced",
            replacedBy: tokenHash,
            replacedAt: now,
            updatedAt: now,
          });
        }
      }
    });

    // ── Step 7: Structured logging ──
    functions.logger.info("RTDN processed", {
      event: "rtdn_processed",
      notificationType,
      uid,
      tokenHash,
      subscriptionStatus,
      plan: plan || "none",
      expiryDate: expiryTimestamp ? new Date(expiryTimeMillis).toISOString() : null,
      hunterUpdated: !!hunterUpdate,
      timestamp: new Date().toISOString(),
    });

    return;
  });
