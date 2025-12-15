# Quick Test Instructions - Phase 3: Homeschooling Hubs

## 📱 **To Run on Dev Phone**

1. **Connect your Android device** via USB
2. **Enable USB Debugging** on the device
3. **Verify connection:**
   ```bash
   adb devices
   ```
   Should show your device

4. **Run the app:**
   ```bash
   flutter run -d <device-id>
   ```
   Or just:
   ```bash
   flutter run
   ```
   (if only one device connected)

---

## ✅ **Quick Verification Checklist** (5-10 minutes)

### **1. Navigation (1 min)**
- [ ] Open app → Navigate to "My Hubs"
- [ ] Find/create a homeschooling hub
- [ ] Tap hub → Should open `HomeschoolingHubScreen`
- [ ] Verify premium gate (if not premium, should show upgrade prompt)

### **2. Student Management (2 min)**
- [ ] Tap "Student Management" card
- [ ] Tap "+" to create student
- [ ] Fill form: Name, Grade, DOB, select subjects
- [ ] Save → Should appear in list
- [ ] Tap student → Edit → Save changes
- [ ] Long press/options → Delete (with confirmation)

### **3. Assignment Tracking (2 min)**
- [ ] Tap "Assignment Tracking" card
- [ ] Tap "+" to create assignment
- [ ] Fill: Title, Subject, Description, Due Date, Student
- [ ] Save → Should appear in list
- [ ] Test filters: By student, By status
- [ ] Mark assignment as complete
- [ ] Verify overdue highlighting (if due date passed)

### **4. Lesson Planning (2 min)**
- [ ] Tap "Lesson Planning" card
- [ ] Tap "+" to create lesson plan
- [ ] Fill: Title, Subject, Description, Scheduled Date, Duration
- [ ] Add learning objectives (type + Enter)
- [ ] Add resources (type + Enter)
- [ ] Save → Should appear in list
- [ ] Test subject filter

### **5. Data Persistence (1 min)**
- [ ] Hot restart app (press 'r' in terminal)
- [ ] Verify all created data still visible
- [ ] Navigate between screens → Data persists

### **6. Error Handling (1 min)**
- [ ] Try creating student without name → Should show validation error
- [ ] Try creating assignment without required fields → Should show error
- [ ] Verify loading indicators show during operations

---

## 🚨 **Critical Issues to Report**

1. **App crashes** on any screen
2. **Data not saving** to Firestore
3. **Navigation broken** (can't get back, wrong screen)
4. **Premium gate not working** (should block non-premium users)
5. **Lists not loading** (spinner forever)
6. **Forms not validating** (can save empty data)

---

## 📝 **Quick Notes**

- **Test with dev flavor** (should use `dev_` prefixed collections)
- **Check Firestore console** to verify data is being created
- **Watch terminal logs** for any errors
- **Test on actual homeschooling hub** (not family hub)

---

**Expected Test Time:** 5-10 minutes  
**If all checks pass:** ✅ Ready for Phase 4  
**If issues found:** Document and fix before proceeding

