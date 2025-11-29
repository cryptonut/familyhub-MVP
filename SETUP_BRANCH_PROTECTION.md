# Setting Up Branch Protection Rules

This guide will help you protect your `main` and `release/qa` branches to ensure production stability.

## 🎯 What Branch Protection Does

- ✅ Prevents direct commits to protected branches
- ✅ Requires pull requests for changes
- ✅ Ensures code review before merging
- ✅ Keeps production stable

## 📋 Step-by-Step Setup

### 1. Protect `main` Branch (Production)

1. **Go to your repository on GitHub:**
   - Navigate to: https://github.com/cryptonut/familyhub-MVP

2. **Open Settings:**
   - Click the **Settings** tab (top right of repository)

3. **Go to Branches:**
   - In the left sidebar, click **Branches**

4. **Add Branch Protection Rule:**
   - Click **Add rule** or **Add branch protection rule**

5. **Configure for `main` branch:**
   - **Branch name pattern**: `main`
   
   - **Enable these settings:**
     - ✅ **Require a pull request before merging**
       - ✅ Require approvals: **1** (or more if you have a team)
       - ✅ Dismiss stale pull request approvals when new commits are pushed
       - ✅ Require review from Code Owners (if you set up CODEOWNERS)
     
     - ✅ **Require status checks to pass before merging**
       - (Optional) Require branches to be up to date before merging
       - (Optional) Add specific status checks if you have CI/CD
     
     - ✅ **Require conversation resolution before merging**
       - Ensures all PR comments are addressed
     
     - ✅ **Do not allow bypassing the above settings**
       - Even admins must follow these rules
     
     - ✅ **Restrict who can push to matching branches**
       - (Optional) Only allow specific people/teams
       - (Optional) Allow force pushes: **Unchecked** (recommended)
       - (Optional) Allow deletions: **Unchecked** (recommended)

6. **Save the rule:**
   - Click **Create** or **Save changes**

### 2. Protect `release/qa` Branch (Optional but Recommended)

Repeat the same process for `release/qa`:

1. **Add another branch protection rule**
2. **Branch name pattern**: `release/qa`
3. **Enable similar settings** (can be slightly less strict than `main`)
   - ✅ Require a pull request before merging
   - ✅ Require approvals: **1**
   - ✅ Require conversation resolution
   - ✅ Do not allow bypassing

### 3. Leave `develop` Unprotected

- **Don't protect `develop`** - This is where you do daily development
- You can commit directly to `develop` for faster iteration
- Only protect branches that need stability

## 🔄 How It Works Now

### Daily Development (on `develop`)
```powershell
# You can commit directly to develop (no protection)
git checkout develop
# ... make changes ...
git commit -m "New feature"
git push origin develop
```

### Moving to QA (requires PR)
```powershell
# Create a pull request from develop → release/qa
# Go to GitHub and create PR
# Someone must approve it
# Then merge it
```

### Moving to Prod (requires PR + approval)
```powershell
# Create a pull request from release/qa → main
# Go to GitHub and create PR
# Someone must approve it (you can self-approve if solo)
# Then merge it
```

## 🚀 Quick Setup via GitHub Web UI

**Direct links to your repository:**

1. **Protect `main` branch:**
   - https://github.com/cryptonut/familyhub-MVP/settings/branches
   - Click **Add rule**
   - Enter `main` as branch name pattern
   - Enable the settings above
   - Click **Create**

2. **Protect `release/qa` branch:**
   - Same page, click **Add rule** again
   - Enter `release/qa` as branch name pattern
   - Enable similar settings
   - Click **Create**

## 📝 Alternative: Using GitHub CLI (If Installed)

If you install GitHub CLI later, you can use:

```powershell
# Install GitHub CLI first: winget install GitHub.cli

# Protect main branch
gh api repos/cryptonut/familyhub-MVP/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

But the web UI is easier for first-time setup.

## ✅ Verification

After setting up:

1. **Try to push directly to `main`** (should fail):
   ```powershell
   git checkout main
   # Make a small change
   git commit -m "Test" --allow-empty
   git push origin main
   # Should be blocked or require PR
   ```

2. **Create a test PR** to verify the workflow works

## 🎯 Recommended Settings Summary

### `main` Branch (Strict)
- ✅ Require pull request
- ✅ Require 1 approval
- ✅ Require conversation resolution
- ✅ Do not allow bypassing
- ✅ No force pushes
- ✅ No deletions

### `release/qa` Branch (Moderate)
- ✅ Require pull request
- ✅ Require 1 approval
- ✅ Require conversation resolution
- ✅ Do not allow bypassing

### `develop` Branch (No Protection)
- ❌ No protection (free development)

## 💡 Tips

- **Self-approval**: If you're solo, you can approve your own PRs
- **Bypass for emergencies**: If you need to bypass (not recommended), you can temporarily disable protection
- **Status checks**: Add CI/CD later if you want automated testing before merges

## 🆘 Troubleshooting

**"I can't push to main"**
- ✅ This is correct! Use a PR instead

**"I need to fix a critical bug"**
- Use the hotfix workflow (see WORKFLOW_GUIDE.md)
- Or temporarily disable protection (not recommended)

**"PR is stuck waiting for approval"**
- You can self-approve if you're the only developer
- Or add yourself as a required reviewer

