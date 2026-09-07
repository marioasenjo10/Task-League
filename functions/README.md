# Task League — Cloud Functions

## `verifyPurchase`

Validates a Google Play in-app purchase server-side and grants the premium
"unlock all skins" entitlement (`allSkinsUnlocked = true`) on the caller's user
document. The client can never set this flag directly (blocked by Firestore
rules); only this function can, via the Admin SDK.

## One-time setup

### 1. Enable Blaze plan
Cloud Functions require the Firebase **Blaze** plan (pay-as-you-go). The free
monthly quota is generous; a small app typically stays within it.

### 2. Adjust constants in `index.js`
- `ANDROID_PACKAGE_NAME`: already set to `com.masen.taskfight` (the app's
  `applicationId` in `android/app/build.gradle.kts`).
- `UNLOCK_ALL_SKINS_PRODUCT_ID`: `unlock_all_skins` (matches Play Console).

### 3. Create the managed product in Google Play Console
Play Console → your app → Monetize → Products → **In-app products** →
Create product:
- Product ID: `unlock_all_skins`  (must match the code)
- Type: managed product (non-consumable)
- Price: e.g. 4.99 EUR
- Status: Active

### 4. Grant the function access to the Play Developer API
1. Play Console → **Settings → API access** → link your Google Cloud project
   (the same project as Firebase).
2. Enable the **Google Play Android Developer API** in Google Cloud Console.
3. The Cloud Functions runtime service account
   (`<project>@appspot.gserviceaccount.com`) needs permission to read
   purchases. In Play Console → **Users and permissions**, invite that service
   account email and grant it at least **View financial data / Manage orders**
   (account-level or for this app).

### 5. Install deps and deploy
```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

Also deploy the updated Firestore rules (the `allSkinsUnlocked` field):
```powershell
firebase deploy --only firestore:rules
```

## Testing
Use a **license tester** account (Play Console → Settings → License testing)
so test purchases are free and refundable. Install a signed build from an
internal testing track — IAP does not work on debug builds installed via
`flutter run`.
