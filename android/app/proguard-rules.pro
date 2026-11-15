# Extra R8 (code shrinker) rules for release builds. Shrinking is OFF
# (see app/build.gradle.kts); these rules are kept for when it is turned on.
#
# The Google Mobile Ads SDK pulls in WorkManager, which stores its jobs in a
# Room database. Room creates the generated `*_Impl` database class by
# reflection, so R8 cannot see that it is ever instantiated and (in full
# mode) strips its constructor. In Block Burst Magic the app then crashed with
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
# before Flutter started. Keep Room database implementations intact.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase { *; }

# shared_preferences_android calls these from Dart through JNI; R8 removed
# getAll(...) so storage failed. (Only relevant if shrinking is re-enabled.)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
