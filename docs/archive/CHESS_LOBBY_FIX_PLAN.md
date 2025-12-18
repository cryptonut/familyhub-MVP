# Chess Lobby Fix Plan - Stop the Circular Fixes

## Root Cause Analysis

### Problem 1: Dual Data Sources (chess_games + invites)
**Issue**: We're querying two separate collections and trying to merge them, which creates:
- Duplicate detection complexity
- Race conditions between collections
- Inconsistent state (game exists but invite doesn't, or vice versa)
- Complex stream merging logic that's hard to debug

**Why it keeps breaking**: Every fix to one stream affects the other, creating new edge cases.

### Problem 2: Scattered State Logic
**Issue**: The logic for determining "is user invited?", "is user challenger?", "should show accept button?" is duplicated across:
- `chess_lobby_screen.dart`
- `chess_family_game_screen.dart`
- `chess_service.dart` stream filtering

**Why it keeps breaking**: Changes in one place don't propagate, creating inconsistencies.

### Problem 3: No Clear State Machine
**Issue**: Game state transitions are implicit and scattered:
- `waiting` → `active` (when?)
- `active` → `finished` (when?)
- What about `invitedPlayerId` vs `blackPlayerId`?

**Why it keeps breaking**: We're guessing at valid states instead of defining them explicitly.

### Problem 4: UI Logic Duplication
**Issue**: Button visibility, text, and actions are determined in multiple places with slightly different logic.

**Why it keeps breaking**: One screen shows "Accept" but another shows "Join" for the same state.

## Solution: Single Source of Truth Architecture

### Phase 1: Consolidate Data Model (CRITICAL)

**Goal**: Make `chess_games` collection the single source of truth.

**Changes**:
1. **Remove dependency on `invites` collection for game discovery**
   - Keep `invites` only for FCM notifications (temporary)
   - All game state lives in `chess_games` document
   - `invitedPlayerId` field in `chess_games` is the source of truth

2. **Simplify stream query**:
   ```dart
   // ONE query, no merging needed
   _firestore
     .collection('chess_games')
     .where('mode', isEqualTo: 'family')
     .where('familyId', isEqualTo: familyId)
     .where('status', whereIn: ['waiting', 'active'])
     .snapshots()
     .map((snapshot) => snapshot.docs
       .map((doc) => ChessGame.fromJson(doc.data()))
       .where((game) => 
         game.whitePlayerId == currentUserId ||  // Challenger
         game.blackPlayerId == currentUserId ||  // Joined player
         game.invitedPlayerId == currentUserId   // Invited player
       )
       .toList()
     )
   ```

3. **Update `acceptInvite` to be atomic**:
   - Use Firestore transaction
   - Update `chess_games` document: set `blackPlayerId`, clear `invitedPlayerId`, set `status=active`
   - Update `invites` document: set `status=accepted` (for notification history only)

### Phase 2: Centralize State Logic

**Goal**: One place that determines user role and UI state.

**Changes**:
1. **Create `ChessGameRole` helper class**:
   ```dart
   class ChessGameRole {
     final bool isChallenger;
     final bool isInvited;
     final bool isBlackPlayer;
     final bool isWhitePlayer;
     final bool canAccept;
     final bool canJoin;
     final bool canDelete;
     final String displayText;
     final String buttonText;
     final Color buttonColor;
     
     static ChessGameRole determine(ChessGame game, String userId) {
       // ALL logic in one place
     }
   }
   ```

2. **Use in all screens**:
   - `chess_lobby_screen.dart` → `ChessGameRole.determine(game, userId)`
   - `chess_family_game_screen.dart` → `ChessGameRole.determine(game, userId)`
   - No duplicate logic anywhere

### Phase 3: Define State Machine Explicitly

**Goal**: Clear, testable state transitions.

**Changes**:
1. **Document valid states and transitions**:
   ```
   waiting (invitedPlayerId set, blackPlayerId null)
     → acceptInvite() → active (blackPlayerId set, invitedPlayerId null)
     → deleteGame() → deleted
   
   active (blackPlayerId set, invitedPlayerId null)
     → makeMove() → active (or finished if game ends)
     → resign() → finished
     → deleteGame() → deleted
   ```

2. **Add validation in service methods**:
   ```dart
   Future<void> acceptInvite(String gameId) async {
     return _firestore.runTransaction((transaction) async {
       final gameDoc = await transaction.get(_firestore.collection('chess_games').doc(gameId));
       final game = ChessGame.fromJson(gameDoc.data()!);
       
       // EXPLICIT state validation
       if (game.status != GameStatus.waiting) {
         throw ValidationException('Game must be waiting to accept');
       }
       if (game.invitedPlayerId != currentUserId) {
         throw ValidationException('You are not invited to this game');
       }
       if (game.blackPlayerId != null) {
         throw ValidationException('Game already has a black player');
       }
       
       // Atomic update
       transaction.update(gameDoc.reference, {
         'blackPlayerId': currentUserId,
         'blackPlayerName': currentUserName,
         'invitedPlayerId': null,
         'status': GameStatus.active.name,
         'startedAt': FieldValue.serverTimestamp(),
       });
     });
   }
   ```

### Phase 4: Simplify UI Components

**Goal**: Reusable, consistent UI components.

**Changes**:
1. **Create `ChessGameCard` widget**:
   ```dart
   class ChessGameCard extends StatelessWidget {
     final ChessGame game;
     
     Widget build(BuildContext context) {
       final role = ChessGameRole.determine(game, currentUserId);
       
       return Card(
         child: ListTile(
           title: Text(role.displayText),
           subtitle: Text(role.subtitleText),
           trailing: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               if (role.canDelete)
                 IconButton(icon: Icon(Icons.delete), onPressed: () => _delete(game)),
               if (role.canAccept || role.canJoin)
                 ElevatedButton(
                   onPressed: () => _action(game, role),
                   child: Text(role.buttonText),
                   style: ElevatedButton.styleFrom(backgroundColor: role.buttonColor),
                 ),
             ],
           ),
         ),
       );
     }
   }
   ```

2. **Use same component everywhere**:
   - Lobby screen: `<ChessGameCard game={game} />`
   - Family screen: `<ChessGameCard game={game} />`
   - No duplicate UI code

### Phase 5: Testing Strategy

**Goal**: Catch regressions before they reach production.

**Changes**:
1. **Unit tests for `ChessGameRole.determine()`**:
   - Test all combinations: challenger waiting, challenger accepted, invited, black player, etc.
   - Verify correct button text, color, visibility

2. **Integration tests for state transitions**:
   - Test `createGame` → `acceptInvite` → `makeMove` flow
   - Test error cases: accept already accepted game, etc.

3. **Manual test checklist**:
   - [ ] Challenger creates game → sees "Waiting..." card
   - [ ] Invited player sees "Accept Challenge" button
   - [ ] After accept, challenger sees "Join Game" button
   - [ ] Both can delete at any time
   - [ ] No duplicates appear
   - [ ] Stream updates in real-time

## Implementation Order (Do NOT skip steps)

1. **Step 1**: Create `ChessGameRole` helper class with all logic
2. **Step 2**: Simplify stream to single query (remove invites collection dependency)
3. **Step 3**: Update `acceptInvite` to be atomic transaction
4. **Step 4**: Create `ChessGameCard` widget using `ChessGameRole`
5. **Step 5**: Replace all UI code with `ChessGameCard`
6. **Step 6**: Add validation to all service methods
7. **Step 7**: Test thoroughly with manual checklist

## Why This Stops the Circular Fixes

1. **Single source of truth**: No more merging streams, no duplicates possible
2. **Centralized logic**: Change role logic once, affects all screens
3. **Explicit state machine**: Can't have invalid states if we validate transitions
4. **Reusable components**: UI bugs fixed once, not in 3 places
5. **Testable**: Can verify behavior without manual testing every time

## Migration Notes

- Keep `invites` collection for now (for FCM notifications)
- Gradually deprecate it once we confirm single-query approach works
- Add logging to track any edge cases during migration

