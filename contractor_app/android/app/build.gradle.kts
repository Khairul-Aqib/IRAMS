plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.contractor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    kotlin {
        jvmToolchain(21)
    }

    compileOptions {
        // Fixes the "Inconsistent JVM-target" error for Java tasks
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.contractor"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // "getByName" is required in Kotlin DSL (vs just .debug in Groovy)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    // Required since you enabled isCoreLibraryDesugaringEnabled = true
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}