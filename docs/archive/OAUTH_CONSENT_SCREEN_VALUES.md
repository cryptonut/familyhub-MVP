# OAuth Consent Screen - What to Enter

## Step 1: App Information

### App name *
Enter:
```
Family Hub
```
Or any name you prefer for your app (e.g., "Family Hub MVP", "Family Organizer")

### User support email *
Select your email from the dropdown, or enter:
- Your personal email address
- Or a support email for the app

This is the email users can contact if they have questions about the app's permissions.

## Quick Guide

**App name**: `Family Hub` (or your preferred app name)
**User support email**: Your email address

Then click **"Next"** to proceed to the next steps.

## Next Steps After This

1. **Step 2: Audience** - Choose "External" (unless you're using Google Workspace internally)
2. **Step 3: Contact Information** - Add your email as developer contact
3. **Step 4: Finish** - Review and save

After completing all steps:
- Wait 5-10 minutes for Firebase to generate OAuth clients
- Re-download `google-services.json` from Firebase Console
- Check if `oauth_client` is now populated

