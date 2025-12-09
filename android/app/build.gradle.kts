import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load secrets from secrets.properties file
val secretsPropertiesFile = rootProject.file("secrets.properties")
val secretsProperties = Properties()
if (secretsPropertiesFile.exists()) {
    secretsProperties.load(FileInputStream(secretsPropertiesFile))
}

android {
    namespace = "com.example.familyhub_mvp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    // Fix for incremental compilation cache issues with different drive roots
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            incremental = false
        }
    }

    defaultConfig {
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Inject Google Maps API key from secrets.properties
        val googleMapsApiKey = secretsProperties["GOOGLE_MAPS_API_KEY"] as String? ?: ""
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
        
        // Explicitly enable core library desugaring for all flavors
        multiDexEnabled = true
    }

    // Product flavors for Dev/Test/Prod environments
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.example.familyhub_mvp.dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "FamilyHub Dev")
        }
        create("qa") {
            dimension = "environment"
            applicationId = "com.example.familyhub_mvp.test"
            versionNameSuffix = "-test"
            resValue("string", "app_name", "FamilyHub Test")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.example.familyhub_mvp"
            resValue("string", "app_name", "FamilyHub")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Enable ProGuard/R8 rules to prevent obfuscation issues with plugins
            // Flutter enables minification by default in release builds
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Firebase BOM (Bill of Materials) - manages Firebase library versions
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    
    // Firebase services (versions managed by BOM)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    
    // Core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
