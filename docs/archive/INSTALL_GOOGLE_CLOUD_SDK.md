# Installing Google Cloud SDK for CORS Configuration

## Option 1: Install via Chocolatey (Windows - Easiest)

If you have Chocolatey installed:
```powershell
choco install gcloudsdk
```

Then restart your terminal and run:
```powershell
gcloud init
gcloud auth login
gcloud config set project family-hub-71ff0
gsutil cors set cors.json gs://family-hub-71ff0.appspot.com
```

## Option 2: Manual Installation

1. **Download Google Cloud SDK**:
   - Go to: https://cloud.google.com/sdk/docs/install
   - Download the Windows installer
   - Run the installer and follow the prompts

2. **After installation, restart your terminal** and run:
   ```powershell
   gcloud init
   gcloud auth login
   gcloud config set project family-hub-71ff0
   ```

3. **Apply CORS configuration**:
   ```powershell
   gsutil cors set cors.json gs://family-hub-71ff0.appspot.com
   ```

## Option 3: Use Firebase CLI (Alternative)

If you have Firebase CLI installed, you can use it to access gsutil:
```powershell
firebase login
# Then use the gcloud SDK that comes with Firebase CLI
```

## Option 4: Test on Mobile Instead (No CORS Issues)

Since CORS is only an issue on web, you can:
1. Test photo uploads on the Android emulator (no CORS restrictions)
2. Deploy to production where CORS can be configured via Firebase Console

## Quick Check

After installation, verify it works:
```powershell
gcloud --version
gsutil --version
```

