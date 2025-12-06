# Family Hub MVP - Deployment Guide

This guide covers deployment procedures for different environments.

## Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Code review completed
- [ ] Dependencies updated and tested
- [ ] Firebase rules deployed
- [ ] Environment configs verified
- [ ] Release notes prepared

## Branch Strategy

- `develop` - Development branch (active development)
- `release/qa` - QA/Test branch (testing)
- `main` - Production branch (stable releases)

## Release Process

### 1. Prepare Release Branch

```bash
git checkout develop
git pull origin develop
git checkout -b release/qa
git merge develop
```

### 2. Update Version

Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Major.Minor.Patch+Build
```

### 3. Build Release

```bash
flutter clean
flutter pub get
flutter build apk --flavor qa --release
```

### 4. Test Release

- Install APK on test devices
- Verify all features work
- Check for crashes
- Test on multiple devices

### 5. Merge to Production

After QA approval:
```bash
git checkout main
git merge release/qa
git tag v1.0.0
git push origin main --tags
```

## Firebase Deployment

### Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### Storage Rules

```bash
firebase deploy --only storage
```

## App Distribution

### Internal Testing

- Upload APK to Firebase App Distribution
- Distribute to testers
- Collect feedback

### Play Store

1. Build app bundle:
   ```bash
   flutter build appbundle --flavor prod --release
   ```

2. Upload to Google Play Console
3. Complete store listing
4. Submit for review

## Post-Deployment

- Monitor crash reports
- Check analytics
- Gather user feedback
- Plan next release

