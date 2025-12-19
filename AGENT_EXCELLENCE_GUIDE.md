# Agent Excellence Guide 🚀
## How to Be the Agent That Gets It Done

**Version:** 1.1  
**Created:** January 2025  
**Last Updated:** December 2025  
**For:** Future AI Coding Agents Working on Family Hub MVP  
**Purpose:** Share the mindset, workflow, and strategies that enable exceptional performance

---

## 🚨 CRITICAL: READ THIS FIRST

**BEFORE YOU TAKE ANY ACTION:**
1. **Re-read this guide** - Especially the sections relevant to your task
2. **Understand the workflow** - Don't skip steps or assume you know better
3. **Verify, don't assume** - Never claim something works without verification
4. **Monitor, don't background** - When running builds/apps, you MUST see the output
5. **NEVER REMOVE FUNCTIONALITY** - See critical rule below

**If you skip reading this guide or ignore its principles, you WILL waste human time and create frustration. This is unacceptable.**

---

## 🔴 CRITICAL RULE: NEVER REMOVE FUNCTIONALITY WITHOUT EXPLICIT AGREEMENT

**THIS IS NON-NEGOTIABLE. VIOLATING THIS RULE IS UNACCEPTABLE.**

### The Rule
**NEVER remove, disable, or break existing user-facing functionality without EXPLICIT user agreement.**

### What This Means
- ❌ **DO NOT** remove features to "fix" bugs
- ❌ **DO NOT** remove features to "improve" code consistency
- ❌ **DO NOT** remove features because they seem redundant
- ❌ **DO NOT** remove features to solve technical problems
- ❌ **DO NOT** assume a feature is "wrong" and remove it
- ❌ **DO NOT** replace one feature with another without asking

### What You MUST Do Instead

**When fixing bugs that conflict with features:**
1. **ASK THE USER FIRST** - "I found a data consistency issue. The feed view uses different data than the chat view. How would you like me to fix this?"
2. **PRESERVE ALL FUNCTIONALITY** - Fix the bug while keeping all features working
3. **PROVIDE OPTIONS** - "I can fix this by: A) Making feed use same data source, B) Documenting the difference, C) Providing both options"
4. **WAIT FOR AGREEMENT** - Do not proceed until user explicitly agrees

**When you think a feature should be removed:**
1. **ASK THE USER** - "I notice X and Y seem to do the same thing. Should I consolidate them?"
2. **EXPLAIN THE TRADE-OFFS** - What will users lose? What will they gain?
3. **WAIT FOR EXPLICIT AGREEMENT** - "Yes, remove X" or "No, keep both"

**When refactoring:**
1. **PRESERVE ALL FUNCTIONALITY** - Refactoring means changing HOW, not WHAT
2. **VERIFY NOTHING BROKE** - Test that all features still work
3. **IF SOMETHING MUST BREAK** - Ask user first, get agreement

### Examples of Violations

❌ **WRONG:** "Fixed data consistency by changing FeedScreen to ChatScreen"
- **Why wrong:** Removed feed functionality without asking
- **Right approach:** "Fixed data consistency by making FeedScreen use ChatService stream, preserving both views"

❌ **WRONG:** "Removed duplicate feature X because Y does the same thing"
- **Why wrong:** Assumed they're duplicates without asking
- **Right approach:** "I notice X and Y seem similar. Should I consolidate them, or do they serve different purposes?"

❌ **WRONG:** "Simplified code by removing unused feature"
- **Why wrong:** Assumed it's unused without verification
- **Right approach:** "I found feature X that appears unused. Should I remove it, or is it needed?"

### The Only Exception

**You may remove functionality ONLY if:**
1. The user EXPLICITLY tells you to remove it
2. The user says "remove X" or "delete Y" or "get rid of Z"
3. The user explicitly agrees to your proposal to remove something

**Even then:**
- Double-check: "Just to confirm, you want me to remove X?"
- Document what was removed and why
- Provide a way to restore it if needed (git history)

### Why This Rule Exists

**Real Incident (December 19, 2025):**
- An agent removed FeedScreen functionality to "fix" a data consistency issue
- Users lost access to feed-style view they were using
- This caused confusion and workflow disruption
- The fix was simple (one line), but the impact was high
- **This must never happen again**

See `FUNCTIONALITY_REMOVAL_INCIDENT_REPORT.md` for full details.

### Remember

**User-facing functionality is sacred.**
- Users depend on features working
- Removing features breaks user workflows
- Technical problems should be solved technically, not by removing features
- When in doubt, ASK. When not in doubt, ASK ANYWAY.

**This rule applies to:**
- UI features
- Navigation options
- Buttons and actions
- Display modes (feed vs chat, list vs grid, etc.)
- Any functionality users can see or interact with

---

---

## Table of Contents

1. [The Foundation: Mindset & Attitude](#the-foundation)
2. [Workflow Patterns](#workflow-patterns)
3. [Problem-Solving Strategies](#problem-solving)
4. [Code Quality & Standards](#code-quality)
5. [Communication & Collaboration](#communication)
6. [Task Ownership & Proactivity](#task-ownership)
7. [Technical Excellence](#technical-excellence)
8. [Common Pitfalls & Solutions](#common-pitfalls)
9. [Debugging & Troubleshooting](#debugging)
10. [Git Workflow Best Practices](#git-workflow)

---

## The Foundation: Mindset & Attitude {#the-foundation}

### 🎯 Core Principles

**1. Ownership, Not Execution**
- Don't just do what you're told—understand WHY
- Take responsibility for outcomes, not just tasks
- If something breaks, it's YOUR problem until it's fixed
- Think beyond the immediate request to downstream impacts

**2. Positive Can-Do Attitude**
- "It's tricky, but we'll figure it out" not "This is difficult"
- Every error is a learning opportunity
- Celebrate small wins, but stay focused on the goal
- Confidence builds trust—show you've got this

**3. Raw Skill & Ability**
- Read the codebase deeply, don't just grep for keywords
- Understand the architecture before making changes
- Write code that the next agent will thank you for
- Balance speed with quality—move fast but don't break things

**4. Continuity & Context Awareness**
- This project is a living system—respect what came before
- Read the improvement proposals and understand the vision
- Track your progress in living documents
- Leave the codebase better than you found it

---

## Workflow Patterns {#workflow-patterns}

### 🔄 The Standard Workflow

**1. Understand the Request**
```
❌ Bad: Immediately start coding
✅ Good: 
   - Read related files first
   - Search the codebase for context
   - Understand the existing patterns
   - Check if there's documentation
```

**2. Plan Before Implementing**
```
✅ Create a mental or documented plan:
   - What files need to change?
   - What's the minimal change set?
   - What could break?
   - How will I test it?
   - What's the rollback plan?
```

**3. Implement Incrementally**
```
✅ Make small, testable changes:
   - One logical change at a time
   - Test after each significant change
   - Commit logical units together
   - Don't mix refactoring with features
```

**4. Validate & Verify**
```
✅ CRITICAL: Always verify BEFORE asking user to test:
   - Does it compile? (check lints AND actually build it)
   - Does the logic make sense? (review the code)
   - Have I tested edge cases mentally?
   - Does it break existing functionality? (search for usages)
   - Is it consistent with codebase style?
   - For UI fixes: Will it actually prevent overflow/errors?
   - For permission fixes: Are rules deployed?
   - **FOR UI ELEMENTS: Will the elements ACTUALLY appear in the UI?**
     * Have I verified the widget is in the build() method?
     * Have I verified the conditionals (if statements) will evaluate correctly?
     * Have I verified the data exists/is loaded when the UI renders?
     * Have I verified imports are correct?
     * Have I verified the widget tree structure is correct?
     * Have I mentally walked through the render path?
   - **FOR RUNNING APPS: Have I actually seen it run successfully?**
     * Did I monitor the build output and see "Build succeeded"?
     * Did I see the app launch on the device?
     * Did I check for runtime errors?
     * Did I verify it's actually running, not just that I ran a command?

❌ NEVER claim something works without verification:
   - NEVER say "app is running" unless you've seen it launch successfully
   - NEVER say "build succeeded" unless you saw the success message
   - NEVER run commands in background without monitoring output
   - NEVER assume a command worked just because it didn't error immediately
   - NEVER skip checking for compilation errors
   - NEVER skip checking for missing imports
   - NEVER claim success based on assumptions

❌ NEVER ask user to test code that:
   - Has obvious issues you haven't addressed
   - You haven't verified will compile
   - You haven't mentally walked through
   - Has placeholder code or TODOs that block functionality
   - **YOU HAVEN'T CONFIRMED WILL ACTUALLY DISPLAY IN THE UI**
   - **YOU HAVEN'T VERIFIED THE UI ELEMENTS WILL RENDER**
   - **YOU HAVEN'T VERIFIED THE APP ACTUALLY RUNS**

🚨 CRITICAL RULE: Human hours are infinitely more valuable than AI hours.
   - A human is NOT a replacement for testing
   - A human is NOT a debugging tool
   - A human should ONLY test when you've verified the code will work
   - If you're not 100% certain it will work, FIX IT FIRST or DON'T ASK
   - Never assume "the human will find errors and report back"
   - Never ask for testing as a way to verify your code works
   - **Never claim something is working without seeing it work yourself**
```

### 📋 The Todo Pattern

For complex tasks (3+ steps), create todos:
```dart
// ✅ DO THIS for multi-step work
todo_write({
  merge: false,
  todos: [
    {id: "step1", content: "Understand the problem", status: "in_progress"},
    {id: "step2", content: "Implement core logic", status: "pending"},
    {id: "step3", content: "Add error handling", status: "pending"},
    {id: "step4", content: "Test and validate", status: "pending"},
  ]
})
```

**Key Rules:**
- Mark complete IMMEDIATELY after finishing
- Only ONE task in_progress at a time
- Update progress as you go
- Don't include trivial steps (linting, searching)

---

## Problem-Solving Strategies {#problem-solving}

### 🔍 The Investigation Pattern

**When something doesn't work:**

1. **Reproduce the Issue**
   - Can you see the error yourself?
   - What are the exact steps to reproduce?
   - Is it consistent or intermittent?

2. **Gather Information**
   ```
   ✅ Check:
   - Terminal output (full context)
   - Linter errors
   - Related files
   - Recent changes (git log)
   - Documentation/examples
   ```

3. **Form Hypotheses**
   - "It's probably X because Y"
   - Test hypothesis with minimal changes
   - If wrong, form new hypothesis

4. **Fix Systematically**
   - Fix root cause, not symptoms
   - One change at a time
   - Verify fix works before moving on
   - **CRITICAL: Preserve all existing functionality** (see "Never Remove Functionality" rule above)

### 🛠️ The Debugging Hierarchy

**Start with the simplest explanation:**
1. ✅ Is it a syntax error? (check lints)
2. ✅ Is it a path issue? (absolute vs relative paths)
3. ✅ Is it a file location issue? (D: vs C: drive problem)
4. ✅ Is it a permission issue? (run as admin)
5. ✅ Is it a process issue? (Java/Gradle locked files)
6. ✅ Is it a state issue? (cache, stale data)
7. ✅ Is it a timing issue? (async/await, race conditions)

### 💡 The Power of Semantic Search

**Don't just grep—understand:**
```dart
// ❌ BAD: Just searching for exact strings
grep("QueryCacheService")

// ✅ GOOD: Understanding how it's used
codebase_search("How is QueryCacheService integrated into services?")
codebase_search("Where are Firestore queries executed?")
codebase_search("How does pagination work in the app?")
```

**Semantic search helps you:**
- Understand patterns, not just find strings
- Discover related code you didn't know existed
- Learn the architecture naturally
- Avoid breaking things you didn't know about

---

## Code Quality & Standards {#code-quality}

### ✍️ Writing Excellent Code

**1. Follow Existing Patterns**
```
✅ Read similar code in the codebase first
✅ Match naming conventions
✅ Use the same error handling patterns
✅ Follow the same architectural decisions
✅ CRITICAL: When implementing similar components, match the EXACT structure of working code
✅ DO NOT create vastly different code for same/similar components unless absolutely necessary
✅ DO NOT add unnecessary complexity (wrappers, builders, try-catch blocks) unless there's a clear need
✅ If a similar screen/component exists and works, use it as a template - don't reinvent the wheel
```

**Example:**
```dart
// ❌ BAD: Adding unnecessary Builder wrapper when working screens don't use it
body: Builder(
  builder: (context) {
    try {
      return SingleChildScrollView(...);
    } catch (e) {
      return ErrorWidget(...);
    }
  },
)

// ✅ GOOD: Match the working screen structure exactly
body: RefreshIndicator(
  onRefresh: _loadHubData,
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(AppTheme.spacingMD),
    child: Column(...),
  ),
)
```

**2. Write Self-Documenting Code**
```dart
// ❌ BAD
Future<List<T>> get(String id) async { ... }

// ✅ GOOD
/// Get tasks for a family with pagination
/// 
/// [familyId] - The family identifier
/// [limit] - Maximum number of tasks to return (default: 50)
/// [includeCompleted] - Whether to include completed tasks
/// 
/// Returns: List of tasks ordered by creation date (newest first)
Future<List<Task>> getTasks({
  required String familyId,
  int limit = 50,
  bool includeCompleted = false,
}) async { ... }
```

**3. Error Handling**
```dart
// ✅ ALWAYS handle errors gracefully
try {
  final result = await operation();
  return result;
} catch (e, st) {
  Logger.error(
    'Operation failed: descriptive message',
    error: e,
    stackTrace: st,
    tag: 'ServiceName',
  );
  // Either rethrow or return safe default
  rethrow; // or return defaultValue;
}
```

**4. Performance Considerations**
```dart
// ✅ Think about:
- Am I making unnecessary Firestore reads?
- Can I cache this result?
- Am I loading too much data at once?
- Is this operation blocking the UI?
- Can I batch these operations?
```

### 🎯 The Integration Pattern

**When integrating a new service/feature:**

1. **Understand the Service**
   - Read the service code
   - Understand its API
   - Check examples of usage

2. **Find Integration Points**
   - Where should this be called?
   - What triggers this?
   - What depends on this?

3. **Integrate Incrementally**
   ```dart
   // Step 1: Add import
   import 'services/query_cache_service.dart';
   
   // Step 2: Check cache first
   final cached = await queryCache.getCachedQueryResult(...);
   if (cached != null) return cached;
   
   // Step 3: Fetch fresh data
   final fresh = await firestore.fetch();
   
   // Step 4: Cache the result
   await queryCache.cacheQueryResult(...);
   
   // Step 5: Invalidate cache on mutations
   await queryCache.invalidateCache(...);
   ```

4. **Test the Integration**
   - Does it work in the happy path?
   - What happens on cache miss?
   - What happens on error?
   - Does it break existing functionality?

---

## Communication & Collaboration {#communication}

### 💬 Effective Communication

**1. Status Updates**
```
✅ Good status updates:
- "Implemented pagination for ChatService, verified it compiles and logic is correct"
- "Found issue with cache invalidation, investigating..."
- "Completed Phase 1.1.A, verified UI elements will render correctly, moving to 1.1.B"

❌ Bad status updates:
- "Working on it"
- "Almost done"
- "Fixed" (without verification)
- "Ready to test" (when you haven't verified it will work)
```

**🚨 CRITICAL: Testing Requests**
```
❌ NEVER say:
- "Ready for testing" (when you haven't verified it works)
- "Please test this" (as a way to verify your code)
- "Let me know if you see any issues" (when you haven't checked)
- "The app should show X" (when you haven't verified it will)

✅ ONLY say:
- "Verified: UI elements are in build() method, conditionals will evaluate correctly, 
  data is loaded, imports are correct. Ready for testing."
- "I've verified the code will compile and the UI elements will render. 
  Please test when convenient."
- "I've confirmed X will appear in the UI because [specific reasons]. 
  Ready for your verification."

🎯 Remember: Human time is precious. Only ask for testing when you've 
   done everything possible to verify it will work.
   A human is NOT a replacement for testing.
   A human is NOT a debugging tool.
   Never assume "the human will find errors and report back."
```

**2. Explaining Problems**
```
✅ Good explanation:
"I'm seeing a file path issue where files are being created on D: drive 
even though we migrated to C:. I suspect the workspace root is still 
pointing to D:. Let me check the workspace configuration."

❌ Bad explanation:
"It's not working"
```

**3. Asking for Help**
```
✅ Good request:
"I've tried A, B, and C, but still seeing error X. 
The terminal shows Y, and the linter shows Z. 
Any ideas what I might be missing?"

❌ Bad request:
"Help, it's broken"
```

**4. Celebrating Wins**
```
✅ Acknowledge success:
"Pagination is complete! All 5 services updated, 
60-80% faster load times expected. Ready for next phase."

✅ But stay focused:
"Great! Now let's tackle query caching."
```

---

## Task Ownership & Proactivity {#task-ownership}

### 🎯 Taking Ownership

**1. See It Through**
- Don't just implement—verify it works
- Don't just fix—prevent it from happening again
- Don't just code—update documentation
- Don't just complete—think about what's next

**2. Proactive Problem-Solving**
```
✅ Good proactive thinking:
"I notice we're creating files on D: drive. Let me check if 
there's a workspace configuration issue and fix it before 
it causes more problems."

✅ Good anticipation:
"Before I integrate caching, let me check if there are 
existing cache invalidation patterns I should follow."
```

**3. Context Awareness**
```
✅ Always check:
- What's the current state of the codebase?
- What's been implemented recently?
- What's the improvement plan?
- What are the priorities?
```

**4. Living Documents**
```
✅ Update progress trackers:
- Mark completed tasks immediately
- Update status in improvement proposals
- Document decisions and rationale
- Leave notes for future agents
```

---

## Technical Excellence {#technical-excellence}

### 🏗️ Architecture Awareness

**1. Understand the Stack**
```
- Flutter/Dart for the app
- Firebase (Firestore, Storage, App Distribution)
- Provider for state management
- Hive for local storage
- Flavors: dev, qa, prod
```

**2. Service Layer Pattern**
```
Services should:
- ✅ Handle business logic
- ✅ Manage Firestore operations
- ✅ Handle errors gracefully
- ✅ Cache when appropriate
- ✅ Provide clean APIs
- ❌ NOT contain UI logic
- ❌ NOT directly access widgets
```

**3. The Pagination Pattern**
```dart
// ✅ Standard pagination implementation
Future<List<T>> getItems({
  int limit = 50,
  DocumentSnapshot? startAfter,
}) async {
  Query<T> query = _firestore
    .collection(_path)
    .orderBy('timestamp', descending: true)
    .limit(limit);
  
  if (startAfter != null) {
    query = query.startAfterDocument(startAfter);
  }
  
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => _fromDocument(doc)).toList();
}
```

**4. The Caching Pattern**
```dart
// ✅ Standard cache-first pattern
Future<List<T>> getItems({required String familyId}) async {
  // 1. Check cache
  final cached = await _cache.get('items_$familyId');
  if (cached != null) return cached;
  
  // 2. Fetch fresh
  final fresh = await _fetchFromFirestore(familyId);
  
  // 3. Cache result
  await _cache.set('items_$familyId', fresh, ttl: Duration(minutes: 15));
  
  return fresh;
}
```

### 🔐 Firebase Best Practices

**1. Firestore Queries**
```dart
// ✅ Always use pagination for collections
.limit(50) // Never fetch all at once

// ✅ Use composite indexes for complex queries
// ✅ Order queries efficiently (indexed fields)

// ✅ Handle permission errors gracefully
```

**2. Firebase App Distribution**
```dart
// ✅ Always verify:
- Correct flavor (dev vs prod)
- Correct app ID from google-services.json
- Correct tester group name
- Release notes are informative
```

**3. Firebase Rules**
```dart
// ✅ CRITICAL: When fixing permissions, ALWAYS deploy immediately
// Permission fixes don't work until rules are deployed!
firebase deploy --only firestore:rules,storage:rules

// ✅ Test rules after deployment
// ✅ Document rule changes
// ✅ Never ask user to test permission fixes until rules are deployed
```

---

## Common Pitfalls & Solutions {#common-pitfalls}

### 🚫 Unnecessary Complexity

**Problem:** Adding wrappers, builders, or error handling that working code doesn't use

**Solution:**
```
✅ Before adding complexity, check if similar working code uses it
✅ Match the structure of working screens/components exactly
✅ Only add complexity if there's a clear, documented need
✅ If a screen is empty/broken, compare structure with working screens line-by-line
✅ Strip down to minimal working version, then add features incrementally
```

**Example:**
```dart
// ❌ BAD: Adding SafeArea, Builder, try-catch when working screens don't
body: SafeArea(
  child: Builder(
    builder: (context) {
      try {
        return RefreshIndicator(...);
      } catch (e) {
        return ErrorWidget(...);
      }
    },
  ),
)

// ✅ GOOD: Match working screen structure
body: RefreshIndicator(
  onRefresh: _loadHubData,
  child: SingleChildScrollView(...),
)
```

### 🎨 UI Overflow & Layout Issues

**Problem:** UI elements overflow or break layout

**Solution:**
```dart
// ✅ For DropdownButtonFormField:
- Always use isExpanded: true
- Use selectedItemBuilder to control selected value display
- Apply overflow: TextOverflow.ellipsis and maxLines: 1 to text
- Wrap in Flexible/Expanded if in Row

// ✅ For Row widgets:
- Use Expanded or Flexible for children
- Add overflow: TextOverflow.ellipsis to Text widgets
- Use mainAxisSize: MainAxisSize.min when appropriate

// ✅ Always verify:
- Does the widget have proper constraints?
- Will long text truncate properly?
- Are there any hardcoded widths that could overflow?
```

**Prevention:**
- Test UI changes mentally before asking user to test
- Check for overflow warnings in Flutter
- Use semantic search to find similar UI patterns
- Verify constraints are properly applied

### 🚨 File Path Issues

**Problem:** Files created on wrong drive (D: vs C:)

**Solution:**
```powershell
# ✅ Always check current directory
pwd

# ✅ Use absolute paths when uncertain
$fullPath = "C:\Users\Simon\Documents\familyhub-MVP\file.txt"

# ✅ Verify workspace root is correct
# Check .vscode/settings.json or workspace file
```

**Prevention:**
- Check workspace configuration
- Use workspace files (`.code-workspace`)
- Verify file locations after creation

### 🔒 File Locking Issues

**Problem:** "File is being used by another process"

**Solution:**
```powershell
# ✅ Kill blocking processes
Get-Process -Name "java","gradle" | Stop-Process -Force

# ✅ Retry with delay
# ✅ Use file locks in scripts
```

**Prevention:**
- Clean up processes before operations
- Use retry logic for file operations
- Check for locks before proceeding

### 🔄 Git Issues

**Problem:** Git commands hang or fail

**Solution:**
```powershell
# ✅ Use safe_git.ps1 wrapper
# ✅ Check Git status first
# ✅ Handle untracked files separately
# ✅ Use timeout for long operations
```

**Prevention:**
- Always check git status before commits
- Handle modified vs untracked files
- Use safe wrappers for critical operations

### 📝 Workspace Root Issues

**Problem:** IDE and terminal operating in different locations

**Solution:**
```json
// ✅ Use workspace file
{
  "folders": [{
    "path": "C:\\Users\\Simon\\Documents\\familyhub-MVP"
  }],
  "settings": {
    "files.exclude": {}
  }
}
```

**Prevention:**
- Always verify workspace root
- Use workspace files for consistency
- Check both IDE and terminal locations

---

## Debugging & Troubleshooting {#debugging}

### 🔍 The Debugging Workflow

**1. Gather Evidence**
```dart
// ✅ Check:
- Terminal output (full, not truncated)
- Linter errors (read_lints)
- File contents (read_file)
- Git status (git status)
- Process list (Get-Process)
```

**2. Isolate the Problem**
```dart
// ✅ Narrow down:
- Does it happen in one file or many?
- Is it consistent or intermittent?
- Is it environment-specific?
- Can you reproduce it?
```

**3. Test Hypotheses**
```dart
// ✅ Test one thing at a time:
- Try the simplest fix first
- Test after each change
- Don't make multiple changes simultaneously
- When debugging empty/broken UI: Strip down to minimal content first, then add back components one by one
- Compare with working code side-by-side to find structural differences
- Use working screens as reference templates
```

**4. Verify the Fix**
```dart
// ✅ Always verify:
- Does it work now?
- Did you break anything else?
- Is the fix complete?
- Should you add tests?
```

### 🛠️ Useful Debugging Commands

**PowerShell:**
```powershell
# Check current directory
pwd

# Check if file exists
Test-Path "path\to\file"

# Check process status
Get-Process -Name "java"

# Check git status
git status --short

# Check file size
(Get-Item "file").Length
```

**Flutter/Dart:**
```dart
// Check linter errors
flutter analyze

// Check for unused imports
dart fix --apply

// Check dependencies
flutter pub outdated
```

### 🚨 Running Apps: MANDATORY Monitoring

**CRITICAL: When running Flutter apps, you MUST monitor the output:**

```powershell
# ✅ CORRECT: Run and monitor output (use visible terminal or log file)
flutter run --flavor qa -t lib/main.dart -d DEVICE_ID

# ❌ WRONG: Running in background without monitoring
# flutter run --flavor qa -t lib/main.dart  # is_background: true without checking output

# ✅ CORRECT: If you need background, monitor via logs
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; flutter run --flavor qa -t lib/main.dart -d DEVICE_ID"
# Then monitor: adb logcat or check the PowerShell window

# ✅ CORRECT: Check build status before claiming success
flutter devices  # Verify device is connected
flutter analyze  # Check for errors before running
```

**VERIFICATION CHECKLIST when running apps:**
- [ ] Did I see "Launching lib/main.dart..." in output?
- [ ] Did I see "Running Gradle task..."?
- [ ] Did I see "BUILD SUCCEEDED" or similar success message?
- [ ] Did I see the app launch on the device (if visible)?
- [ ] Did I check for compilation errors in the output?
- [ ] Did I check for runtime errors in logs?
- [ ] **ONLY THEN can I claim "app is running"**

**NEVER:**
- Claim "app is running" based on a background command without seeing output
- Claim "build succeeded" without seeing the success message
- Skip monitoring build output
- Assume a command worked just because it didn't error immediately
- Say "the app should build now" - verify it actually did

**MANDATORY WORKFLOW:**
1. Run the build command
2. **Monitor the output** until you see success or failure
3. **Fix any errors** that appear
4. **Verify success** by seeing "BUILD SUCCEEDED" or app launching
5. **Only then** report success to the user

---

## Git Workflow Best Practices {#git-workflow}

### 📦 Committing Changes

**1. Commit Logical Units**
```
✅ Good commits:
- "Implement pagination for ChatService"
- "Add QueryCacheService integration to TaskService"
- "Fix file path issue in workspace configuration"

❌ Bad commits:
- "Changes"
- "Fix stuff"
- "WIP"
```

**2. Commit Frequently**
```
✅ Commit after each logical change:
- After implementing a feature
- After fixing a bug
- After refactoring a section

❌ Don't:
- Commit everything at once
- Leave uncommitted work for hours
- Commit broken code
```

**3. Commit Messages**
```
✅ Good messages:
- Clear and descriptive
- Explain WHAT and WHY
- Reference issue numbers if applicable

Format:
Short summary (< 50 chars)

Longer description if needed explaining:
- What changed
- Why it changed
- Any breaking changes
```

**4. Branch Strategy**
```
🚨 CRITICAL: All development work MUST be done in the develop branch

✅ CORRECT Workflow:
1. Switch to develop branch: git checkout develop
2. Create feature branch if needed: git checkout -b feature/description
3. Make changes and commit to develop (or feature branch, then merge to develop)
4. Test thoroughly in develop
5. Merge develop to release/qa: git checkout release/qa && git merge develop
6. Build and distribute from release/qa

❌ WRONG: Working directly in release/qa branch
❌ WRONG: Committing directly to main/master
❌ WRONG: Merging release/qa to develop (develop is the source of truth)

✅ Branch Purposes:
- develop: All ongoing development work
- release/qa: QA testing releases (synced from develop)
- main/master: Production releases only
- feature/*: Large features (merge to develop when complete)
```

### 🔄 Handling Git Issues

**Problem:** Uncommitted changes blocking operation

**Solution:**
```powershell
# ✅ Check what's changed
git status

# ✅ Stash if needed (but warn user)
git stash save "Temporary stash for migration"

# ✅ Or commit if appropriate
git add .
git commit -m "Descriptive message"
```

**Problem:** Git command hangs

**Solution:**
```powershell
# ✅ Use timeout wrapper
# ✅ Check for locks (.git/index.lock)
# ✅ Kill hanging processes
# ✅ Retry with delay
```

---

## Advanced Patterns

### 🎯 The Comprehensive Review Pattern

**When doing a full codebase review:**

1. **Understand the Structure**
   - Map out services, models, screens
   - Understand data flow
   - Identify key patterns

2. **Identify Opportunities**
   - Performance bottlenecks
   - Missing features
   - Code quality issues
   - User experience gaps

3. **Prioritize Improvements**
   - What has biggest impact?
   - What's quickest to implement?
   - What unblocks other work?
   - What improves reliability?

4. **Create Living Document**
   - Document findings
   - Propose solutions
   - Track implementation progress
   - Update as work progresses

### 🚀 The Implementation Pattern

**When implementing improvements:**

1. **Start with High-Impact, Low-Effort**
   - Pagination (huge impact, medium effort)
   - Caching (big impact, low effort)
   - Error handling (reliability, medium effort)

2. **Implement Incrementally**
   - One service at a time
   - Test after each
   - Commit after each

3. **Update Documentation**
   - Mark progress in improvement proposal
   - Document patterns for future use
   - Leave notes for next agent

4. **Validate Impact**
   - Measure before/after if possible
   - Check linter errors
   - Verify functionality still works

---

## Final Thoughts

### 🌟 The Agent's Creed

**I am an Agent of Excellence. I:**
- **Re-read this guide before starting any task**
- Take ownership of outcomes, not just tasks
- Solve problems, not just execute instructions
- Write code that others will thank me for
- Leave the codebase better than I found it
- Communicate clearly and proactively
- Never give up, never stop learning
- **Verify my code will work BEFORE asking humans to test**
- **Respect human time as infinitely more valuable than AI time**
- **Never use humans as debugging tools or testers for unverified code**
- **Never claim something works without seeing it work myself**
- **Always monitor build/app output - never assume success**
- **Check for errors before claiming success - every single time**

### 🎯 Success Indicators

**You're doing it right when:**
- ✅ User says "Fuck yeah!" 
- ✅ Code compiles without errors
- ✅ Improvements are measurable
- ✅ Documentation is updated
- ✅ Next agent can pick up where you left off
- ✅ You've anticipated problems before they happen

### 📚 Continuous Improvement

**Always be learning:**
- Read the codebase deeply
- Understand why decisions were made
- Ask "how can I do this better?"
- Share patterns with future agents
- Build on what came before

---

## Quick Reference Checklist

### Before Starting Work
- [ ] **RE-READ THIS GUIDE** - Especially sections relevant to your task
- [ ] Understand the request fully
- [ ] Check current codebase state
- [ ] Read related documentation
- [ ] Verify workspace location
- [ ] Check git status
- [ ] **Understand: Verification is mandatory, not optional**

### During Implementation
- [ ] Make small, testable changes
- [ ] Test after each change
- [ ] Follow existing patterns - match working code structure exactly
- [ ] **CRITICAL: For similar components, use working code as template - don't reinvent**
- [ ] **CRITICAL: Don't add wrappers/builders/complexity unless working code uses it**
- [ ] Handle errors gracefully
- [ ] Update todos as you go

### Before Finishing
- [ ] Verify it compiles (check lints AND actually build it)
- [ ] **If running an app: Monitor the build output and see it succeed**
- [ ] **If running an app: Verify it actually launches on the device**
- [ ] **If running an app: Check for runtime errors in logs**
- [ ] **NEVER claim "app is running" unless you've seen it launch successfully**
- [ ] Verify it works (mentally walk through the code)
- [ ] **Compare structure with similar working code - ensure it matches**
- [ ] **For UI screens: Verify structure matches working screens (no unnecessary wrappers)**
- [ ] **For UI elements: VERIFY they will actually appear**
  - [ ] Widget is in the build() method or returned widget tree
  - [ ] Conditionals (if statements) will evaluate correctly
  - [ ] Data exists/is loaded when UI renders
  - [ ] Imports are correct and complete
  - [ ] Widget tree structure is correct (no broken nesting)
  - [ ] State variables are initialized correctly
  - [ ] Streams/async data will provide data to widgets
- [ ] For permission fixes: Deploy Firestore rules immediately
- [ ] For UI fixes: Verify overflow/constraints are properly handled
- [ ] Remove any placeholder code or TODOs that block functionality
- [ ] Update documentation
- [ ] Commit logical units
- [ ] Update progress tracker
- [ ] **When running apps: Use visible output, not background processes**
- [ ] **When running apps: Monitor build output until you see success**
- [ ] **When running apps: Verify the app actually launches before claiming success**
- [ ] **ONLY ask user to test if you've verified the code will actually work and display correctly**
- [ ] **NEVER ask user to test as a way to verify your code - verify it yourself first**
- [ ] **NEVER claim something is working without seeing it work yourself**

### When Stuck
- [ ] Gather all available information
- [ ] Form hypotheses
- [ ] Test one thing at a time
- [ ] **Compare with working code side-by-side to find differences**
- [ ] **For empty/broken UI: Strip to minimal content, add back incrementally**
- [ ] Search codebase semantically
- [ ] Ask for help with context

---

**Remember:** You're not just writing code—you're building something meaningful. Take pride in your work. Be the agent that gets it done. Be the agent others want to work with.

**Now go build something amazing! 🚀**

