# Running Tests with Firebase Emulator

## Quick Start

### 1. Start Firebase Emulator
```bash
firebase emulators:start
```

This will start:
- Auth Emulator on port 9099
- Firestore Emulator on port 8080
- Storage Emulator on port 9199
- Emulator UI on port 4000

### 2. Run Tests
In a **separate terminal**, run:

```bash
# Integration tests (no emulator needed)
flutter test test/integration/extended_family_hub_integration_test.dart

# Service tests with emulator
flutter test test/services/extended_family_hub_service_test_with_emulator.dart
```

### 3. View Emulator UI
Open browser to: http://localhost:4000

---

## Test Files

### ✅ No Emulator Required
- `test/integration/extended_family_hub_integration_test.dart` - Pure Dart logic tests

### 🔥 Emulator Required
- `test/services/extended_family_hub_service_test_with_emulator.dart` - Service tests with real Firebase

---

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Start Firebase Emulators
  run: firebase emulators:start --detach

- name: Run Tests
  run: flutter test

- name: Stop Emulators
  run: pkill -f firebase
```

---

## Troubleshooting

### Emulator Not Starting
```bash
# Check if ports are in use
netstat -ano | findstr :9099
netstat -ano | findstr :8080

# Kill processes if needed
taskkill /PID <pid> /F
```

### Tests Can't Connect to Emulator
1. Ensure emulator is running: `firebase emulators:start`
2. Check emulator UI: http://localhost:4000
3. Verify ports match `firebase.json` configuration

---

## Benefits

✅ **Real Firebase Behavior** - Tests run against actual Firebase services  
✅ **Fast** - Emulators are faster than network calls  
✅ **Isolated** - Each test run starts clean  
✅ **No Production Data** - Safe testing environment  
✅ **Full Feature Testing** - Auth, Firestore, Storage all work

