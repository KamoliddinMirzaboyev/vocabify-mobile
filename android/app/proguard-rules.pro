# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Desugar JDK Libs
-dontwarn java.lang.invoke.**
-dontwarn java.time.**

# Keep models and serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
