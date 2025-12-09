# Setup Firebase CLI for Automated Deployments

This guide will help you install and configure Firebase CLI for automated rule deployments.

---

## Prerequisites Check

Firebase CLI requires **Node.js** (which includes npm). Let's check what's installed:

```powershell
node --version
npm --version
```

If these fail, Node.js needs to be installed.

---

## Step 1: Install Node.js

### Option A: Using Winget (Recommended - Fastest)

```powershell
# Install Node.js LTS version
winget install OpenJS.NodeJS.LTS

# Restart PowerShell after installation
# Then verify:
node --version
npm --version
```

### Option B: Using Chocolatey (If installed)

```powershell
choco install nodejs-lts -y

# Restart PowerShell after installation
# Then verify:
node --version
npm --version
```

### Option C: Manual Download

1. Go to: https://nodejs.org/
2. Download LTS version (recommended)
3. Run installer
4. Restart PowerShell
5. Verify:
   ```powershell
   node --version
   npm --version
   ```

---

## Step 2: Install Firebase CLI

Once Node.js is installed:

```powershell
# Install Firebase CLI globally
npm install -g firebase-tools

# Verify installation
firebase --version
```

---

## Step 3: Login to Firebase

```powershell
# Login to Firebase (opens browser)
firebase login

# Verify you're logged in
firebase login:list
```

**Note:** If you're already logged in on another machine, you can use:
```powershell
firebase login --no-localhost
```

---

## Step 4: Initialize Firebase Project (If needed)

```powershell
# Navigate to project directory
cd D:\Users\Simon\Documents\familyhub-MVP

# Initialize Firebase (only if .firebaserc doesn't exist)
firebase init

# Select:
# - Firestore: Configure security rules
# - Storage: Configure security rules
# - Use existing project: [Your Firebase project ID]
```

**Note:** Your `firebase.json` already exists and is configured, so you might skip this step.

---

## Step 5: Link to Firebase Project (If needed)

If Firebase isn't linked to your project:

```powershell
# List available projects
firebase projects:list

# Use your project (replace with your actual project ID)
firebase use YOUR_PROJECT_ID

# Or set default project
firebase use --add
```

---

## Step 6: Test Deployment

```powershell
# Deploy Firestore rules only (test first)
firebase deploy --only firestore:rules

# Deploy Storage rules only (test first)
firebase deploy --only storage:rules

# Deploy both (once confirmed working)
firebase deploy --only firestore:rules,storage:rules
```

---

## Step 7: Create Deployment Script

Create `deploy_firebase_rules.ps1`:

```powershell
# Deploy Firebase Rules Script
Write-Host "Deploying Firebase rules..." -ForegroundColor Cyan

# Deploy Firestore rules
Write-Host "`nDeploying Firestore rules..." -ForegroundColor Yellow
firebase deploy --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firestore rules deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Firestore rules deployment failed!" -ForegroundColor Red
    exit 1
}

# Deploy Storage rules
Write-Host "`nDeploying Storage rules..." -ForegroundColor Yellow
firebase deploy --only storage:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Storage rules deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Storage rules deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ All Firebase rules deployed successfully!" -ForegroundColor Green
```

**Usage:**
```powershell
.\deploy_firebase_rules.ps1
```

---

## Troubleshooting

### Issue: "firebase: command not found"
**Fix:** Node.js/npm not in PATH. Restart PowerShell after installing Node.js.

### Issue: "Permission denied" on npm install
**Fix:** Run PowerShell as Administrator, or use:
```powershell
npm install -g firebase-tools --unsafe-perm=true
```

### Issue: "Not logged in"
**Fix:** Run `firebase login` and authenticate in browser.

### Issue: "Project not found"
**Fix:** 
1. Check `.firebaserc` file exists
2. Run `firebase use --add` to link project
3. Or check `firebase.json` has correct project reference

### Issue: "Rules file not found"
**Fix:** Verify `firestore.rules` and `storage.rules` exist in project root.

---

## Quick Start (After Node.js Installed)

```powershell
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Deploy rules
firebase deploy --only firestore:rules,storage:rules
```

---

**Once Firebase CLI is working, rule deployments can be automated!**

