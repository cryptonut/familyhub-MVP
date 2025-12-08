# SIMPC1 Setup Guide - Git and Firebase Authentication

## Prerequisites
- Ensure Git is installed: `git --version`
- Ensure Firebase CLI is installed: `firebase --version`
  - If not installed: `npm install -g firebase-tools`

## Step 1: Configure Git Authentication

### Option A: Using HTTPS with Personal Access Token (Recommended for Windows)

1. **Check current Git config:**
   ```powershell
   git config --global user.name
   git config --global user.email
   ```

2. **Set Git user (if not set):**
   ```powershell
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

3. **Set up credential helper (Windows):**
   ```powershell
   git config --global credential.helper wincred
   ```

4. **Test Git access:**
   ```powershell
   git fetch origin
   ```
   - If prompted, enter your GitHub username and a Personal Access Token (not password)
   - To create a token: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token
   - Required scopes: `repo` (full control of private repositories)

### Option B: Using SSH Keys

1. **Check for existing SSH keys:**
   ```powershell
   ls ~/.ssh
   ```

2. **Generate new SSH key (if needed):**
   ```powershell
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```
   - Press Enter to accept default location
   - Optionally set a passphrase

3. **Start SSH agent:**
   ```powershell
   Start-Service ssh-agent
   ssh-add ~/.ssh/id_ed25519
   ```

4. **Copy public key:**
   ```powershell
   cat ~/.ssh/id_ed25519.pub | clip
   ```

5. **Add to GitHub:**
   - Go to GitHub → Settings → SSH and GPG keys → New SSH key
   - Paste the key and save

6. **Test SSH connection:**
   ```powershell
   ssh -T git@github.com
   ```

7. **Update remote URL to use SSH (if currently using HTTPS):**
   ```powershell
   git remote set-url origin git@github.com:YOUR_USERNAME/familyhub-MVP.git
   ```

## Step 2: Configure Firebase CLI Authentication

1. **Login to Firebase:**
   ```powershell
   firebase login
   ```
   - This will open a browser window for authentication
   - Select the correct Google account
   - Grant permissions

2. **Verify Firebase projects:**
   ```powershell
   firebase projects:list
   ```

3. **Set the default project (if needed):**
   ```powershell
   firebase use --add
   ```
   - Select your Firebase project from the list

4. **Test Firebase deployment:**
   ```powershell
   firebase deploy --only firestore:rules --dry-run
   ```

## Step 3: Verify Everything Works

1. **Test Git push:**
   ```powershell
   git status
   git push origin develop
   ```

2. **Test Firebase rules deployment:**
   ```powershell
   firebase deploy --only firestore:rules
   ```

## Troubleshooting

### Git Issues:
- **"Permission denied"**: Check your Personal Access Token has `repo` scope, or SSH key is added to GitHub
- **"Repository not found"**: Verify you have access to the repository
- **Credential issues**: Clear stored credentials: `git credential-manager-core erase` (then re-authenticate)

### Firebase Issues:
- **"Not logged in"**: Run `firebase login` again
- **"Permission denied"**: Ensure your Google account has access to the Firebase project
- **"Project not found"**: Run `firebase use --add` to select the correct project

## Quick Setup Script (Run all at once)

```powershell
# Git Setup
git config --global credential.helper wincred
git fetch origin

# Firebase Setup
firebase login
firebase projects:list
```

## NUCLEAR OPTION - Switch to SSH (Bypasses All Credential Issues)

If credential managers keep interfering, **just use SSH keys** - it's actually simpler:

1. **Check your remote URL:**
   ```powershell
   git remote -v
   ```

2. **Generate SSH key (if you don't have one):**
   ```powershell
   ssh-keygen -t ed25519 -C "your.email@example.com"
   # Press Enter 3 times (no passphrase needed, or set one)
   ```

3. **Copy public key:**
   ```powershell
   cat ~/.ssh/id_ed25519.pub | clip
   ```

4. **Add to GitHub:**
   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Paste the key, give it a name like "SIMPC1", save

5. **Test SSH connection:**
   ```powershell
   ssh -T git@github.com
   # Should say "Hi username! You've successfully authenticated..."
   ```

6. **Switch remote to SSH:**
   ```powershell
   git remote set-url origin git@github.com:cryptonut/familyhub-MVP.git
   ```

7. **Test it:**
   ```powershell
   git fetch origin
   git push origin develop
   ```

**That's it. No credential managers, no PAT tokens, no prompts. Just works.**

## Alternative: Embed PAT in URL (Quick but less secure)

If you MUST use HTTPS and PAT token, embed it in the URL:

```powershell
git remote set-url origin https://YOUR_USERNAME:YOUR_PAT_TOKEN@github.com/cryptonut/familyhub-MVP.git
```

Replace `YOUR_USERNAME` and `YOUR_PAT_TOKEN` with actual values. This bypasses all credential prompts.

## Notes
- After setting up, you should be able to commit, push, and deploy from SIMPC1
- If you encounter issues, check that you're using the same GitHub account and Firebase project as the main PC
- **SSH keys are the most reliable solution** - no credential manager interference

