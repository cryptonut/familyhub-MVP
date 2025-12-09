# Gradle/Flutter Build Performance - Optimization Guide

## Overview

This guide covers hardware and software optimizations to speed up Gradle and Flutter builds.

## Software Optimizations (Free!) 💰

### 1. Gradle Configuration (`android/gradle.properties`)

**Essential optimizations:**
```properties
# Memory allocation (adjust based on available RAM)
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m

# Enable daemon (keeps Gradle running between builds)
org.gradle.daemon=true

# Parallel builds (uses multiple CPU cores)
org.gradle.parallel=true

# Build caching (reuses outputs from previous builds)
org.gradle.caching=true

# Configure on demand (only configures needed projects)
org.gradle.configureondemand=true

# Worker optimization (set to CPU cores - 1)
org.gradle.workers.max=7  # Example: 8 cores = 7 workers
```

**Impact:** Can reduce build time by **30-50%**

### 2. Flutter Build Optimizations

**Use build flavors wisely:**
- Separate dev/qa/prod builds to avoid unnecessary work
- Use `--release` only when needed (dev builds can be debug)

**Skip unnecessary steps:**
```bash
# For dev builds, skip code signing (faster)
flutter build apk --release --flavor dev --dart-define=FLAVOR=dev

# Clean only when necessary (incremental builds are faster)
# Avoid: flutter clean (unless you have issues)
```

### 3. Android Build Optimizations

**Enable R8 full mode** (already enabled):
```properties
android.enableR8.fullMode=true
```

**Incremental compilation:**
- Enable if your project and Gradle cache are on same drive
- Disable if you experience cache corruption issues

**Minimize dependency resolution:**
- Use dependency versions (avoid `+` versions)
- Use `implementation` over `api` when possible

## Hardware Impact Analysis

### 1. Storage (SSD vs HDD) - **BIGGEST IMPACT** 🚀

**Why it matters:**
- Gradle reads/writes thousands of files per build
- Dependency downloads and cache writes
- Build artifact generation
- Incremental compilation checks

**Recommendations:**
- ✅ **Use NVMe M.2 SSD** for project directory
- ✅ **Use SSD** for Gradle cache (`~/.gradle` or `%USERPROFILE%\.gradle`)
- ✅ **Use SSD** for Android SDK
- ✅ **Use SSD** for build outputs
- ⚠️ **Avoid** network drives or slow external storage

**Impact:** Can reduce build time by **40-60%** compared to HDD

**Setup tips:**
- Put project, Gradle cache, and Android SDK on fastest drive
- Use same drive for all (avoid cross-drive operations)
- Prefer NVMe M.2 over SATA SSD if possible

### 2. RAM - **MEDIUM IMPACT** 💾

**Current:** 8GB heap allocated to Gradle

**Recommendations:**
- **16GB total RAM minimum** - allows 8GB Gradle + 8GB system
- **32GB total RAM ideal** - allows 16GB Gradle + 16GB system
- More RAM = less GC pauses = smoother builds

**If you have 16GB+ RAM, consider:**
```properties
org.gradle.jvmargs=-Xmx12G -XX:MaxMetaspaceSize=4G ...
```

**Impact:** Can reduce build time by **10-20%** (mainly via fewer GC pauses)

### 3. CPU Cores - **MEDIUM IMPACT** ⚡

**Current:** Parallel builds enabled

**Recommendations:**
- **8+ cores ideal** for parallel compilation
- **16+ cores** if doing heavy native builds

**Optimize worker count:**
```properties
# In gradle.properties, add (adjust to CPU cores - 1):
org.gradle.workers.max=7  # For 8-core CPU
```

**Impact:** Can reduce build time by **20-40%** with more cores

### 4. CPU Speed (GHz) - **SMALL IMPACT** 🏃

**Single-core speed** matters for:
- Gradle startup
- Kotlin compilation (partially single-threaded)
- APK signing

**Recommendations:**
- **3.5GHz+ base clock** preferred
- Modern CPUs with **high boost clocks** help

**Impact:** Can reduce build time by **5-15%**

## Quick Wins (Software Optimizations)

### 1. Add Worker Count Optimization

Add to `android/gradle.properties`:
```properties
# Set to (CPU cores - 1) for optimal performance
org.gradle.workers.max=7  # Example: 8 cores = 7 workers
```

### 2. Enable Incremental Compilation (if not causing issues)

Currently disabled in `build.gradle.kts`:
```kotlin
kotlinOptions {
    incremental = false  // Disabled due to cross-drive issues
}
```

If you move project to same drive as Gradle cache, enable:
```kotlin
kotlinOptions {
    incremental = true
}
```

### 3. Use Gradle Build Scans (for analysis)

Add to `gradle.properties`:
```properties
org.gradle.scan=true
```

Run build with:
```bash
./gradlew build --scan
```

## Recommended Hardware Upgrade Priority

1. **🥇 SSD/NVMe for project** (if on HDD) - **40-60% speedup**
2. **🥈 More RAM** (if <16GB) - **10-20% speedup**
3. **🥉 More CPU cores** (if <8 cores) - **20-40% speedup**
4. **4️⃣ Faster CPU clock** - **5-15% speedup**

## Expected Build Time Improvements

**Typical baseline build time:** ~100-120 seconds for full release build

**With optimizations:**
- Software optimizations only: **70-85 seconds** (30-40% faster)
- SSD upgrade: **60-75 seconds** (40-50% faster)
- SSD + more RAM: **50-65 seconds** (45-55% faster)
- SSD + RAM + more cores: **40-55 seconds** (55-65% faster)

**With optimizations:**
- SSD upgrade: **60-75 seconds** (40-50% faster)
- SSD + more RAM: **50-65 seconds** (45-55% faster)
- SSD + RAM + more cores: **40-55 seconds** (55-65% faster)

## Cost vs Benefit

| Upgrade | Cost | Time Saved | ROI |
|---------|------|------------|-----|
| SSD (if on HDD) | $50-100 | 40-50s per build | ⭐⭐⭐⭐⭐ |
| 16GB RAM | $50-100 | 10-20s per build | ⭐⭐⭐⭐ |
| 32GB RAM | $100-150 | 15-25s per build | ⭐⭐⭐ |
| More CPU cores | $200+ | 20-40s per build | ⭐⭐ |

## Incremental vs Full Builds

**Incremental builds** (only changed files):
- Typical time: **10-30 seconds**
- Uses build cache effectively
- Much faster than full builds

**Full builds** (clean + rebuild):
- Typical time: **100-120 seconds**
- Necessary for release builds
- Use `flutter clean` only when needed

## Common Pitfalls to Avoid

1. **❌ Running `flutter clean` too often**
   - Kills incremental build benefits
   - Only clean when you have build issues

2. **❌ Building on network drives**
   - Extremely slow file I/O
   - Move project to local SSD

3. **❌ Insufficient RAM allocation**
   - Causes frequent GC pauses
   - Allocate 50-75% of available RAM to Gradle

4. **❌ Disabling Gradle daemon**
   - Adds 10-20s startup time per build
   - Always enable daemon for development

5. **❌ Not using build cache**
   - Rebuilds everything unnecessarily
   - Enable caching in gradle.properties

## Quick Optimization Checklist

**Software (Free):**
- ✅ Enable Gradle daemon
- ✅ Enable parallel builds
- ✅ Enable build caching
- ✅ Set worker count to (CPU cores - 1)
- ✅ Allocate adequate heap memory (8GB+)
- ✅ Use incremental builds when possible

**Hardware (Costs money):**
- ✅ Use SSD/NVMe for project and cache
- ✅ 16GB+ RAM (32GB ideal)
- ✅ 8+ CPU cores (16+ ideal)
- ✅ Fast CPU single-core performance

---

**Bottom Line:** Software optimizations are free and give **30-50% speedup**. If your project is on HDD, moving to SSD/NVMe gives the **biggest additional boost** (40-60% more). RAM and CPU improvements are valuable but secondary.

