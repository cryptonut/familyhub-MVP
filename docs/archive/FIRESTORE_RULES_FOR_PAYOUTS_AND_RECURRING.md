# Firestore Security Rules for Payouts and Recurring Payments

Add these rules to your Firestore security rules to support payout requests and recurring payments.

## Collections:
- `families/{familyId}/payoutRequests` - Payout requests from users
- `families/{familyId}/payouts` - Approved payouts (for balance tracking)
- `families/{familyId}/recurringPayments` - Recurring payment configurations
- `families/{familyId}/pocketMoneyPayments` - Pocket money payment records

## Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ... existing rules ...
    
    // Payout Requests
    match /families/{familyId}/payoutRequests/{requestId} {
      // Users can create their own payout requests
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId
        && request.resource.data.status == 'pending'
        && request.resource.data.amount is number
        && request.resource.data.amount > 0;
      
      // Users can read their own payout requests
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.userId 
            || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin']));
      
      // Only Bankers/Admins can update (approve/reject) payout requests
      allow update: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin'])
        && request.resource.data.userId == resource.data.userId
        && request.resource.data.amount == resource.data.amount;
      
      // No delete (requests should be kept for history)
      allow delete: if false;
    }
    
    // Approved Payouts (for balance tracking)
    match /families/{familyId}/payouts/{payoutId} {
      // Only Bankers/Admins can create payout records
      allow create: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin'])
        && request.resource.data.userId is string
        && request.resource.data.amount is number
        && request.resource.data.amount > 0;
      
      // Users can read their own payouts, Bankers/Admins can read all
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.userId 
            || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin']));
      
      // No update or delete (payouts are immutable records)
      allow update: if false;
      allow delete: if false;
    }
    
    // Recurring Payments
    match /families/{familyId}/recurringPayments/{paymentId} {
      // Only Bankers/Admins can create recurring payments
      allow create: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin'])
        && request.resource.data.fromUserId == request.auth.uid
        && request.resource.data.toUserId is string
        && request.resource.data.amount is number
        && request.resource.data.amount > 0
        && request.resource.data.frequency in ['weekly', 'monthly']
        && request.resource.data.isActive == true;
      
      // Users can read recurring payments where they are the recipient or creator
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.toUserId 
            || request.auth.uid == resource.data.fromUserId
            || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin']));
      
      // Only Bankers/Admins can update (e.g., deactivate) recurring payments
      allow update: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin'])
        && request.resource.data.fromUserId == resource.data.fromUserId
        && request.resource.data.toUserId == resource.data.toUserId
        && request.resource.data.amount == resource.data.amount
        && request.resource.data.frequency == resource.data.frequency;
      
      // No delete (keep for history)
      allow delete: if false;
    }
    
    // Pocket Money Payments (payment records)
    match /families/{familyId}/pocketMoneyPayments/{paymentRecordId} {
      // Only system (via Banker/Admin) can create payment records
      // In practice, this will be created by the RecurringPaymentService
      // which runs with Banker/Admin privileges
      allow create: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin'])
        && request.resource.data.fromUserId is string
        && request.resource.data.toUserId is string
        && request.resource.data.amount is number
        && request.resource.data.amount > 0;
      
      // Users can read their own pocket money payments, Bankers/Admins can read all
      allow read: if request.auth != null 
        && (request.auth.uid == resource.data.toUserId 
            || request.auth.uid == resource.data.fromUserId
            || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin']));
      
      // No update or delete (payment records are immutable)
      allow update: if false;
      allow delete: if false;
    }
    
  }
}
```

## Notes:

1. **Payout Requests**: Users can create their own payout requests, but only Bankers/Admins can approve/reject them.

2. **Approved Payouts**: These are immutable records created when a payout is approved. They're used to track which payouts have been made outside the app.

3. **Recurring Payments**: Only Bankers/Admins can create and manage recurring payments. Recipients can view their own recurring payments.

4. **Pocket Money Payments**: These are payment records created when a recurring payment is processed. They're immutable and used for balance tracking.

5. **Balance Calculation**: The wallet balance calculation includes:
   - Earnings from completed jobs (positive)
   - Liabilities from created jobs (negative for non-Bankers, can go negative for Bankers)
   - Pocket money payments received (positive)
   - Approved payouts (negative)

## Testing:

After deploying these rules, test:
1. User creates a payout request
2. Banker approves/rejects the payout request
3. Banker sets up a recurring payment
4. Recipient views their pocket money
5. Balance calculations include all transaction types

