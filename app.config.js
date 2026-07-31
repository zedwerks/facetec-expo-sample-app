export default {
  runtimeVersion: {
    policy: "appVersion"
  },
  expo: {
    name: "SampleApp",
    slug: "facetec-sample-expo",
    version: "0.2.1",
    orientation: "portrait",
    icon: "./assets/icon.png",
    userInterfaceStyle: "light",
    assetBundlePatterns: ["**/*"],
    newArchEnabled: false,      // FaceTec's native modules aren't yet compatible with the New Architecture. Re-enable once they are.
    extra: {
      eas: {
        projectId: "b9b86d76-cc00-4e54-98d0-c6759aac0393",
      },
    },
    autolinking: {
      exclude: [
        "expo-dev-client"
      ],
    },
    ios: {
      statusBar: {
        barStyle: "dark-content",
        backgroundColor: "#A5A5A5",
      },
      buildConfiguration:  "Debug",
      deploymentTarget: process.env.IPHONEOS_DEPLOYMENT_TARGET || "16.4",
      supportsTablet: false,

      bundleIdentifier:  process.env.IOS_BUNDLE_IDENTIFIER || "com.zedwerks.facetec.sample.expo", 
      appleTeamId: process.env.IOS_DEVELOPMENT_TEAM || "XD785M4668",

      infoPlist: {
        NSCameraUsageDescription: "$(PRODUCT_NAME) needs camera access to scan your ID and verify your liveness.",
        NSFaceIDUsageDescription: "Face ID is used for biometric liveness verification.",
        NSAppTransportSecurity: {
          NSAllowsArbitraryLoads: true,
        },
        ITSAppUsesNonExemptEncryption: false,
      },
      entitlements: {
        'keychain-access-groups': [
          '$(AppIdentifierPrefix)$(CFBundleIdentifier)',
        ],
      },
    },

    android: {
      statusBar: {
        barStyle: "dark-content",
        backgroundColor: "#A5A5A5",
      },
      adaptiveIcon: {
        foregroundImage: "./assets/icon.png",
        backgroundColor: "#BFD3E5",
      },
      package: process.env.ANDROID_PACKAGE || "com.zedwerks.facetec.sample.expo", // Must be unique across the Play Store if you plan to publish
      versionCode: 1,
      targetSdkVersion: process.env.ANDROID_TARGET_SDK_VERSION || 34,
      compileSdkVersion: process.env.ANDROID_COMPILE_SDK_VERSION || 34,
      buildToolsVersion: process.env.ANDROID_BUILD_TOOLS_VERSION || "34.0.0",
      permissions: [
        "android.permission.INTERNET",
        "android.permission.CAMERA",
      ],
    },

    plugins: [
      "expo-font",    
    ],

    scheme: "sampleapp",
  },
}