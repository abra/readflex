# ML Kit discovers these constructors through reflection. AGP 9 no longer
# retains them implicitly when the dependency keeps only the registrar class.
-keepclassmembers class com.google.mlkit.** implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
