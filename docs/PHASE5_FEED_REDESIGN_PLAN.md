# Phase 5: Social Feed Redesign - Implementation Plan
**Date:** December 13, 2025  
**Status:** In Progress

---

## 🎯 **OBJECTIVE**

Transform the chat system from SMS-style bubbles to a modern social feed experience similar to X (formerly Twitter), with support for threaded comments, rich media previews, polls, and cross-hub engagement.

---

## 📋 **IMPLEMENTATION CHECKLIST**

### **Step 1: Data Model Enhancements** ✅
- [x] ChatMessage model exists with basic fields
- [ ] Extend ChatMessage to support:
  - [ ] Post type (text, poll, media)
  - [ ] Poll data structure (options, votes, expiration)
  - [ ] Engagement metrics (likes, comments, shares)
  - [ ] Cross-hub visibility flags
  - [ ] URL preview metadata

### **Step 2: Feed Service** 🚧
- [ ] Create `FeedService` to replace/enhance `ChatService`:
  - [ ] Feed querying with pagination
  - [ ] Poll creation and voting
  - [ ] Comment threading logic
  - [ ] Engagement tracking
  - [ ] Cross-hub feed aggregation

### **Step 3: Feed UI Components** 📋
- [ ] Build new `FeedScreen` component:
  - [ ] Feed list view with post cards
  - [ ] Post detail view with full thread
  - [ ] Poll voting UI
  - [ ] Comment composer
  - [ ] Media preview components

### **Step 4: URL Preview Service** 📋
- [ ] Implement URL preview service:
  - [ ] Fetch metadata from URLs (Open Graph, Twitter Cards)
  - [ ] Generate preview cards
  - [ ] Cache previews for performance
  - [ ] Handle preview errors gracefully

### **Step 5: Polling System** 📋
- [ ] Poll creation UI
- [ ] Poll voting UI
- [ ] Real-time poll results
- [ ] Poll expiration handling
- [ ] Cross-hub poll support

### **Step 6: Enhanced Threading** 📋
- [ ] Nested comment UI (2-3 levels deep)
- [ ] Thread collapse/expand
- [ ] Comment count indicators
- [ ] Reply-to-post functionality
- [ ] Reply-to-comment functionality

### **Step 7: Migration & Backward Compatibility** 📋
- [ ] Migrate existing chat messages to feed format
- [ ] Preserve message history
- [ ] Convert old bubbles to feed posts
- [ ] Feature flag for gradual rollout

---

## 🚀 **IMPLEMENTATION ORDER**

1. **Data Model** (Foundation)
2. **FeedService** (Backend logic)
3. **Feed UI** (User-facing)
4. **URL Previews** (Enhancement)
5. **Polls** (Feature)
6. **Enhanced Threading** (Feature)
7. **Migration** (Deployment)

---

**Last Updated:** December 13, 2025

