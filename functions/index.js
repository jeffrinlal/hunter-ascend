/**
 * Hunter Ascend — Firebase Cloud Functions
 *
 * Backend for rewarded-ad membership system.
 *
 * Functions:
 * - claimMembershipReward: Callable function invoked by the Flutter client
 *   after a rewarded ad is completed. Securely grants membership time.
 *
 * Legacy functions (verifyPurchase, handlePlayNotification) have been removed.
 * Google Play Billing has been permanently replaced by the rewarded-ad model.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// ── Initialize Firebase Admin SDK ──────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();

// ── Constants ──────────────────────────────────────────────────────────────

/** Valid membership types that can be claimed via rewarded ads. */
const VALID_MEMBERSHIP_TYPES = ["pro", "max"];

/** Number of milliseconds in one day. */
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Minimum interval (in milliseconds) between reward claims for the same user.
 * Basic abuse protection only — true duplicate verification will require
 * AdMob Server-Side Verification (SSV) in a future phase.
 * Set to 30 seconds.
 */
const MIN_CLAIM_INTERVAL_MS = 30 * 1000;

/**
 * Maximum time (in milliseconds) allowed between the first and second Max
 * rewarded ad. If the second ad is not completed within this window, the
 * pending progress is automatically reset.
 * Set to 24 hours.
 */
const MAX_PENDING_EXPIRY_MS = 24 * 60 * 60 * 1000;

// ── claimMembershipReward ──────────────────────────────────────────────────
//
// Callable function: the Flutter client calls this after a rewarded ad has
// been fully watched. The backend validates the claim and extends (or starts)
// the user's membership.
//
// SECURITY:
// - Requires Firebase Authentication.
// - Basic abuse protection via rate limiting (MIN_CLAIM_INTERVAL_MS).
//   True duplicate verification will require AdMob SSV in a future phase.
// - Uses Firestore transactions to prevent race conditions.
// - The client NEVER updates membership fields directly.
//
// Input: { membershipType: "pro" | "max" }
//
// PRO flow:
//   1 ad watched → +1 day immediately.
//
// MAX flow:
//   1st ad watched → pendingMaxRewardAds incremented to 1. No extension yet.
//   2nd ad watched → pendingMaxRewardAds reset to 0. +1 day granted.
//
// Output: {
//   success: boolean,
//   membershipType?: string,
//   expiryDate?: string,
//   pendingAds?: number,
//   error?: string
// }
//
exports.claimMembershipReward = functions.https.onCall(async (data, context) => {
  // ── Authentication check ──
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated to claim a reward."
    );
  }

  const uid = context.auth.uid;
  const { membershipType } = data;

  // ── Input validation ──
  if (!membershipType || typeof membershipType !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "membershipType is required and must be a string."
    );
  }

  if (!VALID_MEMBERSHIP_TYPES.includes(membershipType)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid membershipType: "${membershipType}". Must be "pro" or "max".`
    );
  }

  functions.logger.info("claimMembershipReward called", {
    uid,
    membershipType,
    projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || admin.app().options.projectId || "UNKNOWN",
  });

  // ── Firestore transaction ──
  const hunterRef = db.collection("hunters").doc(uid);

  functions.logger.info("Attempting to read document", {
    documentPath: `hunters/${uid}`,
    projectId: admin.app().options.projectId || "UNKNOWN",
    databaseURL: admin.app().options.databaseURL || "default",
  });

  try {
    const result = await db.runTransaction(async (txn) => {
      const hunterSnap = await txn.get(hunterRef);

      functions.logger.info("Document read result", {
        uid,
        documentPath: `hunters/${uid}`,
        exists: hunterSnap.exists,
        hasData: hunterSnap.exists ? !!hunterSnap.data() : false,
      });

      if (!hunterSnap.exists) {
        functions.logger.error("Hunter document NOT FOUND", {
          uid,
          documentPath: `hunters/${uid}`,
          projectId: admin.app().options.projectId || "UNKNOWN",
        });
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Hunter profile not found."
        );
      }

      const hunterData = hunterSnap.data();
      const now = Date.now();
      const nowTimestamp = admin.firestore.Timestamp.fromMillis(now);

      // ── Basic abuse protection: rate limiting ──
      // Prevents rapid-fire claims. True duplicate verification will require
      // AdMob Server-Side Verification (SSV) in a future phase.
      const lastRewardClaim = hunterData.lastRewardClaim;
      if (lastRewardClaim) {
        const lastClaimMs = lastRewardClaim.toMillis
          ? lastRewardClaim.toMillis()
          : lastRewardClaim;
        if (now - lastClaimMs < MIN_CLAIM_INTERVAL_MS) {
          return {
            success: false,
            error: "too_fast",
            message: "Please wait before claiming another reward.",
          };
        }
      }

      // ── Read current membership state ──
      const currentType = hunterData.membershipType || "basic";
      const currentExpiry = hunterData.membershipExpiry;
      const pendingMax = hunterData.pendingMaxRewardAds || 0;
      const pendingMaxStartedAt = hunterData.pendingMaxRewardStartedAt;

      // ── Max ad progress expiry ──
      // If the first Max ad was completed more than 24 hours ago,
      // automatically reset the pending progress before processing.
      let effectivePendingMax = pendingMax;
      if (effectivePendingMax > 0 && pendingMaxStartedAt) {
        const startedAtMs = pendingMaxStartedAt.toMillis
          ? pendingMaxStartedAt.toMillis()
          : pendingMaxStartedAt;
        if (now - startedAtMs > MAX_PENDING_EXPIRY_MS) {
          // Pending progress expired — reset.
          effectivePendingMax = 0;
          functions.logger.info("Max pending progress expired — resetting", {
            uid,
            elapsedMs: now - startedAtMs,
          });
        }
      }

      // Determine the base time for extension:
      // If membership is the same type and not expired, extend from expiry.
      // Otherwise, start from now.
      let baseTimeMs = now;
      if (currentExpiry) {
        const expiryMs = currentExpiry.toMillis
          ? currentExpiry.toMillis()
          : currentExpiry;
        if (currentType === membershipType && expiryMs > now) {
          baseTimeMs = expiryMs;
        }
      }

      // ── Process based on membership type ──
      if (membershipType === "pro") {
        // PRO: 1 ad = +1 day immediately.
        // If switching from max, reset pending and start fresh.
        const newExpiry = admin.firestore.Timestamp.fromMillis(
          baseTimeMs + ONE_DAY_MS
        );

        txn.update(hunterRef, {
          membershipType: "pro",
          membershipExpiry: newExpiry,
          pendingMaxRewardAds: 0,
          pendingMaxRewardStartedAt: null,
          lastRewardClaim: nowTimestamp,
        });

        return {
          success: true,
          membershipType: "pro",
          expiryDate: new Date(baseTimeMs + ONE_DAY_MS).toISOString(),
          pendingAds: 0,
        };
      } else {
        // MAX: 2 ads = +1 day.
        // Check if this is the first or second ad.

        // If currently NOT max membership, or switching from pro,
        // reset the pending counter context.
        const effectivePending =
          currentType === "max" || currentType === "basic"
            ? effectivePendingMax
            : 0; // switching from pro resets pending

        if (effectivePending < 1) {
          // First ad for Max — record pending, no extension yet.
          txn.update(hunterRef, {
            // If switching from pro, set type to max immediately
            // but don't extend until second ad.
            membershipType: currentType === "max" ? "max" : membershipType,
            pendingMaxRewardAds: 1,
            pendingMaxRewardStartedAt: nowTimestamp,
            lastRewardClaim: nowTimestamp,
          });

          return {
            success: true,
            membershipType: "max",
            pendingAds: 1,
            message: "First ad completed. Watch one more to earn +1 day.",
          };
        } else {
          // Second ad for Max — grant +1 day, reset pending.
          const newExpiry = admin.firestore.Timestamp.fromMillis(
            baseTimeMs + ONE_DAY_MS
          );

          txn.update(hunterRef, {
            membershipType: "max",
            membershipExpiry: newExpiry,
            pendingMaxRewardAds: 0,
            pendingMaxRewardStartedAt: null,
            lastRewardClaim: nowTimestamp,
          });

          return {
            success: true,
            membershipType: "max",
            expiryDate: new Date(baseTimeMs + ONE_DAY_MS).toISOString(),
            pendingAds: 0,
          };
        }
      }
    });

    functions.logger.info("claimMembershipReward result", {
      uid,
      membershipType,
      success: result.success,
      pendingAds: result.pendingAds,
    });

    return result;
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error("claimMembershipReward error", {
      uid,
      membershipType,
      error: error.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to process reward. Please try again."
    );
  }
});
