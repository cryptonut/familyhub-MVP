# How to Get an App URL for Hub Invites

Your app needs a URL so that invite links can work. Here are your options:

## Option 1: Firebase Hosting (Recommended - Free & Easy)

Firebase Hosting is the easiest way to host your Flutter web app and get a URL.

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Firebase Hosting
```bash
firebase init hosting
```

When prompted:
- Select your project: **family-hub-71ff0**
- Public directory: `build/web` (default)
- Configure as single-page app: **Yes**
- Set up automatic builds: **No** (for now)

### Step 4: Build Your App
```bash
flutter build web
```

### Step 5: Deploy
```bash
firebase deploy --only hosting
```

### Your App URL
After deployment, your app will be available at:
- **https://family-hub-71ff0.web.app** (default Firebase URL)
- **https://family-hub-71ff0.firebaseapp.com** (alternate URL)

You can also set up a custom domain later in Firebase Console > Hosting.

### Update the Invite Link
Once you have your URL, update the invite link in `lib/screens/hubs/invite_members_dialog.dart`:
- Replace `https://familyhub.app` with your Firebase Hosting URL
- Or keep the dynamic URL generation (it will use the current domain automatically)

---

## Option 2: Other Hosting Services

### Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Build: `flutter build web`
3. Deploy: `vercel --prod`
4. Get your URL from Vercel dashboard

### Netlify
1. Install Netlify CLI: `npm install -g netlify-cli`
2. Build: `flutter build web`
3. Deploy: `netlify deploy --prod --dir=build/web`
4. Get your URL from Netlify dashboard

### GitHub Pages
1. Build: `flutter build web --base-href "/your-repo-name/"`
2. Push `build/web` to `gh-pages` branch
3. Enable GitHub Pages in repo settings
4. URL: `https://yourusername.github.io/your-repo-name/`

---

## Option 3: Custom Domain

Once you have hosting set up, you can:
1. Buy a domain (e.g., from Google Domains, Namecheap, etc.)
2. Configure DNS to point to your hosting
3. Update your hosting service with the custom domain

Example: `https://familyhub.app` or `https://myfamilyhub.com`

---

## For Development/Testing

### Local Development
When running locally, the app automatically uses:
- `http://localhost:PORT/?hub-invite=INVITE_ID`

### Testing with ngrok (for sharing local dev)
1. Install ngrok: https://ngrok.com/
2. Run your app: `flutter run -d chrome`
3. In another terminal: `ngrok http 8080` (or your port)
4. Use the ngrok URL for testing invites

---

## Current Implementation

The app currently:
- **Automatically detects the current URL** when running on web
- Uses `Uri.base` to get the current domain
- Generates invite links like: `http://localhost:8080/?hub-invite=INVITE_ID`

This means:
- ✅ Works automatically in development
- ✅ Works automatically when deployed (uses the deployed domain)
- ✅ No code changes needed when you deploy!

---

## Next Steps

1. **For now**: The dynamic URL generation will work with your current setup
2. **For production**: Deploy to Firebase Hosting (or your preferred service)
3. **Update mobile fallback**: If you plan to support mobile apps, update the mobile URL in the code

---

## Example URLs After Deployment

- **Firebase Hosting**: `https://family-hub-71ff0.web.app/?hub-invite=abc123`
- **Custom Domain**: `https://familyhub.app/?hub-invite=abc123`
- **Local Dev**: `http://localhost:8080/?hub-invite=abc123`

The invite link format is: `YOUR_APP_URL/?hub-invite=INVITE_ID`

