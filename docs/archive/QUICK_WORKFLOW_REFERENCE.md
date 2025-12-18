# Quick Workflow Reference Card

## 🎯 The Rule

**dev flavor** → Build from `develop` branch  
**qa flavor** → Build from `release/qa` branch  
**prod flavor** → Build from `main` branch

## 📝 Daily Development

```powershell
# 1. Start on develop
git checkout develop
git pull origin develop

# 2. Make changes
# ... edit code ...

# 3. Test locally
flutter run --release --flavor dev --dart-define=FLAVOR=dev

# 4. Commit and push
git add .
git commit -m "Your message"
git push origin develop

# 5. Build dev APK
.\build_and_distribute.ps1 dev firebase-manual
```

## 🧪 Promote to QA

```powershell
git checkout release/qa
git merge develop
git push origin release/qa
.\build_and_distribute.ps1 qa firebase-manual
```

## 🚀 Release to Prod

```powershell
git checkout main
git merge release/qa
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main --tags
.\build_and_distribute.ps1 prod firebase-manual
```

## 🚨 Current Branch

Check which branch you're on:
```powershell
git branch
```

**You should be on `develop` for daily work!**

