# ProGuard/R8 rules for FamilyHub MVP
# These rules prevent code obfuscation from breaking plugins in release builds

# Keep device_calendar plugin classes (package may vary by version)
-keep class com.builttoroam.devicecalendar.** { *; }
-keep class com.builttoroam.devicecalendar.common.** { *; }
-keep class com.builttoroam.devicecalendar.domain.** { *; }
-keep class com.builttoroam.devicecalendar.platforms.android.** { *; }

# Keep all Calendar and Event model classes from device_calendar
-keep class * extends com.builttoroam.devicecalendar.domain.Calendar { *; }
-keep class * extends com.builttoroam.devicecalendar.domain.Event { *; }
-keep class com.builttoroam.devicecalendar.domain.Calendar { *; }
-keep class com.builttoroam.devicecalendar.domain.Event { *; }
-keep class com.builttoroam.devicecalendar.domain.Attendee { *; }
-keep class com.builttoroam.devicecalendar.domain.RecurrenceRule { *; }

# Keep Calendar and Event model classes (used by device_calendar)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep all Calendar Provider related classes
-keep class android.provider.CalendarContract.** { *; }
-keep class android.content.ContentResolver { *; }

# Keep reflection-based code used by plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter plugin classes
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Firebase classes (if needed)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Prevent obfuscation of classes that use reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep all public classes in packages that might use reflection
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep calendar-related classes that might be accessed via reflection
-keep class android.database.** { *; }
-keep class android.content.ContentValues { *; }
-keep class android.net.Uri { *; }

# Keep timezone classes (used by device_calendar)
-keep class org.threeten.bp.** { *; }

# Don't warn about missing classes (some may be optional)
-dontwarn com.builttoroam.devicecalendar.**

# Ignore missing Google Play Core classes (optional, not needed for our app)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

