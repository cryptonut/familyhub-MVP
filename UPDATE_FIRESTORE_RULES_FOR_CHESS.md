# Update Firestore Rules for Chess Games

The new chess feature requires Firestore rules for two new collections:
- `chess_games` - Stores all chess games
- `chess_matchmaking` - Queue for open matchmaking

## How to Update

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Scroll to the bottom (before the closing braces)
6. Add the chess rules (they're already in `firestore.rules` file)
7. Click **Publish**

## What Was Added

### Chess Games Collection
- Players can read their own games
- Users can create games (as white player)
- Players can update games (make moves)
- Players can delete games (resign/abort)
- Spectators can read games they're watching

### Chess Matchmaking Collection
- Users can manage their own queue entries
- Prevents unauthorized access to matchmaking

## Security

✅ **Secure:** Users can only access their own games and queue entries
✅ **No data leaks:** Can't see other players' games unless you're a player/spectator
✅ **Works for all environments:** Dev, QA, and Prod share the same rules

## Test After Updating

1. Try creating a solo chess game
2. Try joining matchmaking
3. Try making a move in a game

If you get permission errors, the rules haven't been published yet.

