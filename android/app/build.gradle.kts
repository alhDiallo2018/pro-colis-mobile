import java.util.Properties

/**
 * Clé du SDK Google Maps natif, par ordre de priorité :
 * propriété Gradle → variable d'environnement → local.properties.
 * Chaîne vide si aucune n'est fournie : le build passe, la carte reste grise.
 */
fun resolveGoogleMapsKey(): String {
    (project.findProperty("google.maps.key") as String?)?.let { if (it.isNotBlank()) return it }
    System.getenv("GOOGLE_MAPS_API_KEY")?.let { if (it.isNotBlank()) return it }
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        val props = Properties()
        localProps.inputStream().use { props.load(it) }
        props.getProperty("googleMapsApiKey")?.let { if (it.isNotBlank()) return it }
    }
    return ""
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // TODO(Firebase): placer google-services.json dans android/app/ puis
    // décommenter la ligne ci-dessous (et celle dans android/settings.gradle)
    // pour activer Firebase Cloud Messaging.
    // id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pro_colis_clean"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

    defaultConfig {
        applicationId = "com.example.pro_colis_clean"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true

        // Clé Google Maps du SDK natif (rendu de la carte). Distincte de la clé
        // Dart `--dart-define=GOOGLE_MAPS_API_KEY`, qui ne sert qu'aux appels
        // HTTP Places / Geocoding : sans celle-ci, la carte reste grise.
        // Fournir via `-Pgoogle.maps.key=…`, la variable d'environnement
        // GOOGLE_MAPS_API_KEY, ou `googleMapsApiKey=…` dans local.properties.
        manifestPlaceholders["googleMapsApiKey"] = resolveGoogleMapsKey()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}