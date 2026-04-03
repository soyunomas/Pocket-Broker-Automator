# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Moquette Broker
-keep class io.moquette.** { *; }
-keep interface io.moquette.** { *; }
-dontwarn io.moquette.**

# Netty (Required by Moquette)
-keep class io.netty.** { *; }
-keep interface io.netty.** { *; }
-keep class org.jboss.netty.** { *; }
-dontwarn io.netty.**
-dontwarn org.jboss.netty.**

# H2 Database (Persistent store for Moquette)
-keep class org.h2.** { *; }
-keep interface org.h2.** { *; }
-dontwarn org.h2.**

# Slf4j / Logging
-keep class org.slf4j.** { *; }
-dontwarn org.slf4j.**

# Misc
-dontwarn sun.misc.Unsafe
-dontwarn java.lang.invoke.**
-dontwarn java.nio.**

# Plugin
-keep class com.pocketbroker.pocket_broker_automator.** { *; }
