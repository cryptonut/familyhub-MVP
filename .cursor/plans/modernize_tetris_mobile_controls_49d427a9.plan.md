---
name: Modernize Tetris Mobile Controls
overview: Replace the low-positioned IconButton controls with intuitive touch-based controls on the game board itself, using tap zones relative to the falling block position and swipe gestures for better mobile playability.
todos: []
---

# Modernize Tetris Mobile Controls

## Current State

The Tetris game uses IconButtons at the bottom of the screen (lines 648-672 in `lib/games/tetris/screens/tetris_screen.dart`), which are positioned too low for comfortable phone play.

## Research Findings

Common mobile Tetris patterns include:

- **Tap zones** relative to the falling piece (left/right/center)
- **Swipe gestures** for movement (left/right/down)
- **Tap to rotate** on the piece itself
- **Visual feedback** (haptics, highlights) for better UX

## Proposed Solution

### Primary Controls (Your Proposal + Enhancements)

1. **Tap Left Zone** (left of falling block) → Move left
2. **Tap Right Zone** (right of falling block) → Move right  
3. **Tap on Block** → Rotate clockwise
4. **Tap Bottom Row** → Hard drop (instant drop to bottom)
5. **Swipe Down** → Soft drop (faster fall while held)

### Implementation Details

#### 1. Calculate Falling Block Position

- Get the current block's column range: `_currentCol` to `_currentCol + pieceWidth`
- Divide the board into three zones:
  - **Left zone**: Columns 0 to `_currentCol - 1`
  - **Block zone**: Columns `_currentCol` to `_currentCol + pieceWidth - 1`
  - **Right zone**: Columns `_currentCol + pieceWidth` to `cols - 1`

#### 2. Wrap Game Board with GestureDetector

- Replace the static `GridView.builder` (line 512) with a `GestureDetector` wrapper
- Use `onTapDown` to detect tap position
- Use `onPanUpdate` for swipe gestures

#### 3. Touch Zone Detection

```dart
// Calculate which column was tapped
final tapColumn = (tapX / cellWidth).floor();
final tapRow = (tapY / cellHeight).floor();

if (tapColumn < _currentCol) {
  // Left zone - move left
} else if (tapColumn >= _currentCol + pieceWidth) {
  // Right zone - move right
} else {
  // Block zone - rotate
}
```

#### 4. Bottom Row Detection

- If `tapRow >= rows - 1` (bottom row), trigger hard drop
- Hard drop: Move piece down until collision, then place

#### 5. Swipe Gesture Support

- `onPanUpdate`: Detect horizontal swipes for movement
- Detect vertical swipes for soft drop
- Add debouncing to prevent rapid-fire moves

#### 6. Visual Feedback

- Optional: Subtle highlight on tap zones (can be disabled)
- Haptic feedback on successful actions (using `HapticFeedback`)
- Visual indicator for hard drop zone (subtle border or color)

#### 7. Remove Old Controls

- Remove the IconButton row (lines 648-672)
- Keep only pause/leaderboard/restart in AppBar

### Files to Modify

- `lib/games/tetris/screens/tetris_screen.dart`
  - Add gesture detection to game board
  - Implement zone-based tap handling
  - Add swipe gesture support
  - Add hard drop functionality
  - Remove IconButton controls
  - Add haptic feedback

### Additional Enhancements (Optional)

1. **Ghost Piece Preview**: Show translucent preview of where piece will land
2. **Control Settings**: Allow users to toggle between tap-only and swipe+tap modes
3. **Sensitivity Settings**: Adjust swipe threshold for movement

### Edge Cases to Handle

- Block at left edge (no left zone)
- Block at right edge (no right zone)
- Block at top (rotation still works)
- Rapid taps (debounce/throttle)
- Accidental swipes during tap (distinguish tap vs swipe)

## Benefits

- More ergonomic for phone play
- Larger touch targets (entire board vs small buttons)
- Intuitive relative positioning
- Modern mobile-first UX
- Better one-handed playability