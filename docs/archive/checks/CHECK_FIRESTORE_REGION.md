# How to Check Firestore Region/Location

## Step-by-Step

1. **Go to Firebase Console**
   - Visit [https://console.firebase.google.com/](https://console.firebase.google.com/)
   - Select project: **family-hub-71ff0**

2. **Open Firestore Database**
   - Click **"Firestore Database"** in the left sidebar
   - You should see the **Data** tab (with collections) or an empty database

3. **Check Region/Location**
   - Look at the **top of the Firestore Database page**
   - You should see text like:
     - **"Location: us-central1"** or
     - **"Region: europe-west1"** or
     - **"Database location: asia-southeast1"**
   - It's usually displayed near the database name or in a banner

4. **Alternative: Check in Database Settings**
   - If you don't see it at the top, look for:
     - A **gear icon** ⚙️ or **settings icon**
     - Or click on the **database name** (if shown)
     - This should show database details including location

5. **What Region Should You Use?**
   - Choose the **closest region** to your users
   - Common regions:
     - **us-central1** (United States - Central)
     - **europe-west1** (Belgium)
     - **asia-southeast1** (Singapore)
     - **australia-southeast1** (Sydney)
   - **Note**: Once set, you can't change it easily (would need to export/import data)

## If You Can't Find It

The region is usually displayed prominently when you first create the database. If you can't see it:
- The database might be in the default region (usually **us-central1**)
- Check the **Usage** tab - it might show region info there
- Or check **Project Settings** > **General** tab - might show default region

## Why Region Matters

- **Latency**: Closer region = faster queries
- **Cost**: Some regions are cheaper than others
- **Compliance**: Some regions required for data residency laws

For development, any region is fine. For production, choose based on where most users are.

