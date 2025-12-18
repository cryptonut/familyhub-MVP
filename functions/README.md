# Family Hub Cloud Functions

Cloud Functions for server-side IAP receipt validation and subscription management.

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Build TypeScript:
```bash
npm run build
```

3. Configure Firebase Functions config:
```bash
# Google Play credentials (optional - uses mock validation if not set)
firebase functions:config:set googleplay.service_account_email="your-service-account@project.iam.gserviceaccount.com"
firebase functions:config:set googleplay.private_key="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# App Store credentials (optional - uses mock validation if not set)
firebase functions:config:set appstore.shared_secret="your-shared-secret"
firebase functions:config:set appstore.sandbox="false"

# App package name
firebase functions:config:set app.package_name="com.example.familyhub_mvp"
```

## Deployment

```bash
firebase deploy --only functions
```

## Functions

### `validateGooglePlayReceipt`
Validates Google Play purchase receipts server-side.

### `validateAppStoreReceipt`
Validates App Store purchase receipts server-side.

### `checkSubscriptionsExpiration`
Scheduled function (runs every 6 hours) to check and update expired subscriptions.

### `checkUserSubscription`
Manual trigger to check a specific user's subscription status.

## Development

Run emulator:
```bash
npm run serve
```

## Notes

- Functions use mock validation in development/emulator mode
- Production requires proper credentials configured
- Subscription expiration check runs automatically every 6 hours

