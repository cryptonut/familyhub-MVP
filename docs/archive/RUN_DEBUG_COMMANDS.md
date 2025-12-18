# Commands to Run App in Debug Mode

## For QA Flavor (Test)
```bash
flutter run --flavor qa --debug
```

## For Dev Flavor
```bash
flutter run --flavor dev --debug
```

## For Production Flavor
```bash
flutter run --flavor prod --debug
```

## Short Version (QA - Most Common)
```bash
flutter run --flavor qa
```
(debug is the default, so `--debug` is optional)

## With Specific Device
If you have multiple devices connected:
```bash
flutter devices
flutter run --flavor qa -d <device-id>
```

## From Android Directory
If you're in the `android` folder:
```bash
cd ..
flutter run --flavor qa
```

## What to Look For
After running, watch the console for:
```
🔑 APP CHECK DEBUG TOKEN (Copy this!)
Token: [your-token-here]
```

Copy that token and paste it into Firebase Console.

