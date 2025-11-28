# Migration Plan: Adopt New Infrastructure

## Overview
Migrate codebase from old patterns to new infrastructure:
- `debugPrint` → `Logger`
- Magic strings/numbers → `AppConstants`
- Generic `Exception` → Typed exceptions

## Migration Strategy

### Principles
1. **Incremental**: One service at a time
2. **Testable**: Verify each migration doesn't break functionality
3. **Reversible**: Each phase can be committed independently
4. **Low Risk**: Start with less critical code, then move to core services

### Phases

## Phase 1: Core Services (High Impact) ⚡
**Priority**: Critical services used throughout the app
**Files**: 
- `lib/services/auth_service.dart` (1800+ lines, many debugPrint calls)
- `lib/main.dart` (entry point, initialization)

**Changes**:
- Replace all `debugPrint` with `Logger` calls
- Replace magic numbers (timeouts) with `AppConstants`
- Replace magic strings (roles, statuses) with `AppConstants`
- Replace generic exceptions with typed exceptions

**Estimated Impact**: ~50 debugPrint calls, ~10 magic strings/numbers, ~5 exception throws

## Phase 2: Feature Services (Medium Impact)
**Priority**: Services for specific features
**Files**:
- `lib/services/task_service.dart`
- `lib/services/photo_service.dart`
- `lib/services/chat_service.dart`
- `lib/services/location_service.dart`
- `lib/services/notification_service.dart`

**Changes**: Same as Phase 1

**Estimated Impact**: ~30-40 debugPrint calls per service

## Phase 3: Supporting Services
**Priority**: Supporting/utility services
**Files**:
- `lib/services/wallet_service.dart`
- `lib/services/voice_recording_service.dart`
- `lib/services/video_call_service.dart`
- Other service files

**Changes**: Same as Phase 1

## Phase 4: Screens & Widgets
**Priority**: UI layer
**Files**: All files in `lib/screens/` and `lib/widgets/`

**Changes**:
- Replace `debugPrint` with `Logger` (fewer calls, mostly error logging)
- Replace magic strings with constants where applicable

**Estimated Impact**: ~20-30 debugPrint calls total

## Phase 5: Models & Utils
**Priority**: Data layer and utilities
**Files**: `lib/models/`, `lib/utils/`

**Changes**: Minimal - mostly error handling improvements

## Execution Order

1. ✅ **Phase 1.1: AuthService** (STARTING NOW)
   - Most critical service
   - High visibility
   - Many debugPrint calls to migrate

2. **Phase 1.2: main.dart**
   - Entry point
   - Initialization code
   - Fewer changes but high visibility

3. **Phase 2: Feature Services** (one at a time)
   - TaskService
   - PhotoService
   - ChatService
   - LocationService
   - NotificationService

4. **Phase 3: Supporting Services**
   - Remaining services

5. **Phase 4: UI Layer**
   - Screens
   - Widgets

6. **Phase 5: Models & Utils**
   - Final cleanup

## Migration Checklist (per file)

For each file being migrated:

- [ ] Add imports:
  ```dart
  import '../core/services/logger_service.dart';
  import '../core/constants/app_constants.dart';
  import '../core/errors/app_exceptions.dart';
  ```

- [ ] Replace `debugPrint` calls:
  - `debugPrint('message')` → `Logger.debug('message', tag: 'ServiceName')`
  - `debugPrint('Error: $e')` → `Logger.error('Error message', error: e, stackTrace: st, tag: 'ServiceName')`

- [ ] Replace magic numbers:
  - `Duration(seconds: 30)` → `AppConstants.authOperationTimeout`
  - `Duration(seconds: 20)` → `AppConstants.firestoreQueryTimeout`

- [ ] Replace magic strings:
  - `'admin'` → `AppConstants.roleAdmin`
  - `'banker'` → `AppConstants.roleBanker`
  - `'pending'` → `AppConstants.statusPending`

- [ ] Replace generic exceptions:
  - `throw Exception('message')` → `throw AuthException('message')` (or appropriate type)

- [ ] Test the migrated file
- [ ] Commit changes

## Success Criteria

- [ ] All `debugPrint` calls replaced with `Logger`
- [ ] All magic strings/numbers replaced with constants
- [ ] All generic exceptions replaced with typed exceptions
- [ ] No breaking changes
- [ ] All tests pass (when tests are added)
- [ ] Code is more maintainable and consistent

## Notes

- Keep old patterns working during migration (backward compatible)
- Can mix old and new patterns temporarily
- Each phase should be tested before moving to next
- Document any issues encountered during migration

