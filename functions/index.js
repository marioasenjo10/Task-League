/**
 * Cloud Functions for Task League.
 *
 * verifyPurchase: validates a Google Play in-app purchase receipt server-side
 * and, only if it is genuine and in the "purchased" state, grants the premium
 * "unlock all skins" entitlement by setting `allSkinsUnlocked = true` on the
 * caller's user document. Because this runs with the Admin SDK it bypasses
 * Firestore security rules, which is exactly why the client is NOT allowed to
 * write that flag itself.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { google } = require("googleapis");

initializeApp();
const db = getFirestore();

// Android application id (package name) of the app on Google Play.
const ANDROID_PACKAGE_NAME = "com.masen.taskfight";

// Product id created in Google Play Console (managed product).
const UNLOCK_ALL_SKINS_PRODUCT_ID = "unlock_all_skins";

/**
 * Verify a Google Play product purchase token against the Play Developer API.
 * Returns true when the purchase is valid and fully paid (purchaseState === 0).
 */
async function verifyGooglePlayProduct(productId, purchaseToken) {
  // Uses Application Default Credentials. In Cloud Functions this is the
  // runtime service account; grant it access in Play Console (see README).
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const androidpublisher = google.androidpublisher({ version: "v3", auth });

  const res = await androidpublisher.purchases.products.get({
    packageName: ANDROID_PACKAGE_NAME,
    productId,
    token: purchaseToken,
  });

  // purchaseState: 0 = Purchased, 1 = Canceled, 2 = Pending.
  return res.data && res.data.purchaseState === 0;
}

exports.verifyPurchase = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { productId, source, serverVerificationData } = request.data || {};

  if (productId !== UNLOCK_ALL_SKINS_PRODUCT_ID) {
    throw new HttpsError("invalid-argument", "Unknown product.");
  }
  if (!serverVerificationData) {
    throw new HttpsError("invalid-argument", "Missing receipt.");
  }
  // Only Google Play is supported for now.
  if (source && source !== "google_play") {
    throw new HttpsError("failed-precondition", "Unsupported store.");
  }

  let valid = false;
  try {
    valid = await verifyGooglePlayProduct(productId, serverVerificationData);
  } catch (err) {
    console.error("Play verification error:", err);
    throw new HttpsError("internal", "Verification failed.");
  }

  if (!valid) {
    return { valid: false };
  }

  // Grant the entitlement. Admin write bypasses security rules by design.
  await db.collection("users").doc(uid).set(
    { allSkinsUnlocked: true },
    { merge: true }
  );

  return { valid: true };
});
