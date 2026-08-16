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
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use {
        keystoreProperties.load(it)
    }
}

/**
 * Le keystore de release est un secret local, absent du depot (gitignore) et de
 * toute machine fraichement clonee.
 *
 * Le bloc `signingConfigs` le lisait sans condition : sur un poste sans
 * `key.properties`, la phase de configuration echouait sur
 * « null cannot be cast to non-null type kotlin.String » et plus rien ne
 * compilait, pas meme un build debug. La presence du keystore est donc evaluee
 * ici, une fois, et conditionne la suite.
 */
val releaseKeystoreFields = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    releaseKeystoreFields.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

if (!hasReleaseKeystore) {
    logger.warn(
        "ATTENTION : android/key.properties absent ou incomplet. Les builds release " +
        "seront signes avec la cle de debug et ne sont PAS publiables. " +
        "Voir android/key.properties.example."
    )
}

android {
    namespace = "com.sendprocolis.app"
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
        applicationId = "com.sendprocolis.app"

        // BiometricPrompt (local_auth) demande l'API 23.
        minSdk = maxOf(23, flutter.minSdkVersion)
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Repli sur la cle de debug plutot qu'un echec : `flutter run
            // --release` et les tests de performance restent possibles sans le
            // keystore. L'avertissement ci-dessus signale que le binaire produit
            // n'est pas publiable.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // ✅ ACTIVER ProGuard pour réduire la taille et optimiser
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // ✅ DÉSACTIVER LE SPLIT APK - SOLUTION POUR LE CRASH
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = false
        }
        abi {
            enableSplit = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
}