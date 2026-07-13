/**
 * Hunter Ascend — Google Play Store Service
 *
 * Dedicated helper for all Google Play Developer API interactions.
 * Keeps the Cloud Functions orchestration layer clean and testable.
 */

const { google } = require("googleapis");
const functions = require("firebase-functions");

/**
 * Creates an authenticated Google Play Developer API client.
 * Uses Application Default Credentials (ADC) — no JSON key needed in production.
 */
async function getClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const authClient = await auth.getClient();
  return google.androidpublisher({ version: "v3", auth: authClient });
}

/**
 * Fetches the full subscription resource from Google Play for a given token.
 *
 * @param {string} packageName - Android package name.
 * @param {string} subscriptionId - The subscription product ID (used as path param).
 * @param {string} purchaseToken - The purchase token from the client.
 * @returns {object|null} The subscription resource, or null if not found/invalid.
 */
async function getSubscription(packageName, subscriptionId, purchaseToken) {
  try {
    const client = await getClient();
    const response = await client.purchases.subscriptions.get({
      packageName,
      subscriptionId,
      token: purchaseToken,
    });
    return response.data;
  } catch (error) {
    functions.logger.error("Play Store API: getSubscription failed", {
      packageName,
      subscriptionId,
      code: error.code,
      message: error.message,
    });

    if (error.code === 404 || error.code === 400) {
      return null; // Invalid or unknown token
    }
    throw error; // Transient failure — let caller handle retry
  }
}

/**
 * Validates a subscription resource and returns a structured verification result.
 *
 * @param {object} subscription - The raw subscription resource from Google Play.
 * @returns {{ valid: boolean, error?: string, expiryTimeMillis?: number, linkedPurchaseToken?: string, orderId?: string }}
 */
function validateSubscription(subscription) {
  if (!subscription) {
    return { valid: false, error: "invalid_token" };
  }

  // ── Payment state ──
  // 0 = pending, 1 = received, 2 = free trial, 3 = deferred upgrade/downgrade
  // Absent = subscription expired or otherwise inactive.
  const paymentState = subscription.paymentState;

  if (paymentState === undefined || paymentState === null) {
    return { valid: false, error: "expired" };
  }
  if (paymentState === 0) {
    return { valid: false, error: "payment_pending" };
  }

  // ── Cancel reason (subscription-level invalidity) ──
  // cancelReason: 0 = user cancelled, 1 = system cancelled (billing issue),
  //               2 = replaced (upgrade/downgrade), 3 = developer cancelled
  // A cancelled subscription is still valid if expiryTime is in the future.
  // However, system-cancelled (1) with no payment means we should reject.
  if (subscription.cancelReason === 1 && paymentState !== 1 && paymentState !== 2) {
    return { valid: false, error: "billing_issue" };
  }

  // ── Expiry time ──
  const expiryTimeMillis = parseInt(subscription.expiryTimeMillis, 10);
  if (!expiryTimeMillis || isNaN(expiryTimeMillis)) {
    return { valid: false, error: "invalid_expiry" };
  }

  if (expiryTimeMillis <= Date.now()) {
    return { valid: false, error: "expired" };
  }

  // ── Acknowledgement state ──
  // 0 = not acknowledged, 1 = acknowledged.
  // We track this internally but do NOT expose it to the client.
  const acknowledged = subscription.acknowledgementState === 1;

  // ── Linked purchase token (upgrade/downgrade chain) ──
  const linkedPurchaseToken = subscription.linkedPurchaseToken || null;

  // ── Order ID (for logging/auditing) ──
  const orderId = subscription.orderId || null;

  return {
    valid: true,
    expiryTimeMillis,
    acknowledged,
    linkedPurchaseToken,
    orderId,
  };
}

/**
 * Acknowledges a subscription purchase on Google Play.
 * Must be called within 3 days of purchase or Google auto-refunds.
 *
 * @param {string} packageName - Android package name.
 * @param {string} subscriptionId - The subscription product ID.
 * @param {string} purchaseToken - The purchase token.
 */
async function acknowledgeSubscription(packageName, subscriptionId, purchaseToken) {
  try {
    const client = await getClient();
    await client.purchases.subscriptions.acknowledge({
      packageName,
      subscriptionId,
      token: purchaseToken,
    });
    functions.logger.info("Subscription acknowledged", { subscriptionId });
  } catch (error) {
    // Non-fatal: if already acknowledged, the API returns success anyway.
    // Log but don't throw — the subscription is still valid.
    functions.logger.warn("Acknowledge failed (may already be acknowledged)", {
      subscriptionId,
      code: error.code,
      message: error.message,
    });
  }
}

module.exports = {
  getSubscription,
  validateSubscription,
  acknowledgeSubscription,
};
