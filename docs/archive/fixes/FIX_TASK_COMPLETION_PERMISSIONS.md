# Fix: Task Completion Permissions

## Problem
Users were unable to complete tasks that don't require claim, even though they're family members. The error was:
```
[cloud_firestore/permission-denied] Missing or insufficient permissions
```

## Root Cause
The Firestore security rules only allowed task updates if the user was:
- The creator
- The claimer
- The assigned user

This prevented family members from completing tasks that don't require claim (open tasks).

## Solution
Updated the Firestore security rules to allow any family member to complete tasks that don't require claim.

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Find the tasks subcollection rules (around line 60-71)
6. Replace the `allow update` rule with:

```javascript
allow update: if belongsToFamily(familyId) && 
  (resource.data.createdBy == request.auth.uid ||
   resource.data.claimedBy == request.auth.uid ||
   resource.data.assignedTo == request.auth.uid ||
   // Allow any family member to complete tasks that don't require claim
   (resource.data.requiresClaim == false || !('requiresClaim' in resource.data)));
```

7. Click **Publish**

## Complete Updated Rules

Or replace the entire rules file with the updated version from `FIRESTORE_RULES_COMPLETE.md` (which has been updated with this fix).

## What Changed

The task update rule now allows updates if:
- User is the creator, OR
- User is the claimer, OR
- User is assigned, OR
- **Task doesn't require claim** (new condition)

This means any family member can complete "open" tasks (tasks that don't require claiming first).

## Testing

After deploying:
1. Refresh your Flutter app (hot restart: `R` in terminal)
2. Try completing a task that doesn't require claim
3. It should work now!

