# Reglas de ProGuard/R8 para Hookahub (Flutter + Supabase + Google Sign-In)

# Preservar clases y bindings del motor de Flutter y plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Deferred Components (evita errores de R8 al no usar Play Core split install)
-dontwarn com.google.android.play.core.**

# Google Mobile Ads (AdMob)
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep class com.google.ads.mediation.** {
    public *;
}
-dontwarn com.google.android.gms.ads.**

# Google Play Services & Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}

# Supabase y Gson/Jackson si aplica en dependencias transitivas
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-dontwarn okio.**
-dontwarn javax.annotation.**
