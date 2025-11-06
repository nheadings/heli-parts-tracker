#!/bin/bash

# Create Xcode project structure
PROJECT_NAME="HeliPartsTracker"
BUNDLE_ID="com.helitracker.HeliPartsTracker"

# Create project directory structure
mkdir -p "${PROJECT_NAME}.xcodeproj"
mkdir -p "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset"

# Create Assets catalog
cat > "${PROJECT_NAME}/Assets.xcassets/Contents.json" << 'ASSETS'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ASSETS

cat > "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'APPICON'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
APPICON

# Create project.pbxproj
cat > "${PROJECT_NAME}.xcodeproj/project.pbxproj" << 'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A1000001 /* HeliPartsTrackerApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000001; };
		A1000002 /* User.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000002; };
		A1000003 /* Part.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000003; };
		A1000004 /* Helicopter.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000004; };
		A1000005 /* APIService.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000005; };
		A1000006 /* AuthViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000006; };
		A1000007 /* PartsViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000007; };
		A1000008 /* HelicoptersViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000008; };
		A1000009 /* LoginView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000009; };
		A1000010 /* MainTabView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000010; };
		A1000011 /* PartsListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000011; };
		A1000012 /* PartDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000012; };
		A1000013 /* AddPartView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000013; };
		A1000014 /* HelicoptersListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000014; };
		A1000015 /* HelicopterDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000015; };
		A1000016 /* InstallPartView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000016; };
		A1000017 /* QRScannerView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000017; };
		A1000018 /* AlertsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000018; };
		A1000019 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000019; };
		A1000020 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = A3000001; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A0000001 /* HeliPartsTracker.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = HeliPartsTracker.app; sourceTree = BUILT_PRODUCTS_DIR; };
		A2000001 /* HeliPartsTrackerApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HeliPartsTrackerApp.swift; sourceTree = "<group>"; };
		A2000002 /* User.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = User.swift; sourceTree = "<group>"; };
		A2000003 /* Part.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Part.swift; sourceTree = "<group>"; };
		A2000004 /* Helicopter.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Helicopter.swift; sourceTree = "<group>"; };
		A2000005 /* APIService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = APIService.swift; sourceTree = "<group>"; };
		A2000006 /* AuthViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AuthViewModel.swift; sourceTree = "<group>"; };
		A2000007 /* PartsViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PartsViewModel.swift; sourceTree = "<group>"; };
		A2000008 /* HelicoptersViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelicoptersViewModel.swift; sourceTree = "<group>"; };
		A2000009 /* LoginView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LoginView.swift; sourceTree = "<group>"; };
		A2000010 /* MainTabView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MainTabView.swift; sourceTree = "<group>"; };
		A2000011 /* PartsListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PartsListView.swift; sourceTree = "<group>"; };
		A2000012 /* PartDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PartDetailView.swift; sourceTree = "<group>"; };
		A2000013 /* AddPartView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AddPartView.swift; sourceTree = "<group>"; };
		A2000014 /* HelicoptersListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelicoptersListView.swift; sourceTree = "<group>"; };
		A2000015 /* HelicopterDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelicopterDetailView.swift; sourceTree = "<group>"; };
		A2000016 /* InstallPartView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = InstallPartView.swift; sourceTree = "<group>"; };
		A2000017 /* QRScannerView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = QRScannerView.swift; sourceTree = "<group>"; };
		A2000018 /* AlertsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AlertsView.swift; sourceTree = "<group>"; };
		A2000019 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
		A3000001 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
		A4000001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A5000001 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A6000001 = {
			isa = PBXGroup;
			children = (
				A6000002 /* HeliPartsTracker */,
				A6000003 /* Products */,
			);
			sourceTree = "<group>";
		};
		A6000002 /* HeliPartsTracker */ = {
			isa = PBXGroup;
			children = (
				A2000001 /* HeliPartsTrackerApp.swift */,
				A6000004 /* Models */,
				A6000005 /* Services */,
				A6000006 /* ViewModels */,
				A6000007 /* Views */,
				A6000008 /* Resources */,
			);
			path = HeliPartsTracker;
			sourceTree = "<group>";
		};
		A6000003 /* Products */ = {
			isa = PBXGroup;
			children = (
				A0000001 /* HeliPartsTracker.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		A6000004 /* Models */ = {
			isa = PBXGroup;
			children = (
				A2000002 /* User.swift */,
				A2000003 /* Part.swift */,
				A2000004 /* Helicopter.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		A6000005 /* Services */ = {
			isa = PBXGroup;
			children = (
				A2000005 /* APIService.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
		A6000006 /* ViewModels */ = {
			isa = PBXGroup;
			children = (
				A2000006 /* AuthViewModel.swift */,
				A2000007 /* PartsViewModel.swift */,
				A2000008 /* HelicoptersViewModel.swift */,
			);
			path = ViewModels;
			sourceTree = "<group>";
		};
		A6000007 /* Views */ = {
			isa = PBXGroup;
			children = (
				A2000009 /* LoginView.swift */,
				A2000010 /* MainTabView.swift */,
				A2000011 /* PartsListView.swift */,
				A2000012 /* PartDetailView.swift */,
				A2000013 /* AddPartView.swift */,
				A2000014 /* HelicoptersListView.swift */,
				A2000015 /* HelicopterDetailView.swift */,
				A2000016 /* InstallPartView.swift */,
				A2000017 /* QRScannerView.swift */,
				A2000018 /* AlertsView.swift */,
				A2000019 /* SettingsView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		A6000008 /* Resources */ = {
			isa = PBXGroup;
			children = (
				A3000001 /* Assets.xcassets */,
				A4000001 /* Info.plist */,
			);
			path = Resources;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A7000001 /* HeliPartsTracker */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A8000001 /* Build configuration list for PBXNativeTarget "HeliPartsTracker" */;
			buildPhases = (
				A9000001 /* Sources */,
				A5000001 /* Frameworks */,
				AA000001 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = HeliPartsTracker;
			productName = HeliPartsTracker;
			productReference = A0000001 /* HeliPartsTracker.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		AB000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1540;
				LastUpgradeCheck = 1540;
				TargetAttributes = {
					A7000001 = {
						CreatedOnToolsVersion = 15.4;
					};
				};
			};
			buildConfigurationList = AC000001 /* Build configuration list for PBXProject "HeliPartsTracker" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A6000001;
			productRefGroup = A6000003 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A7000001 /* HeliPartsTracker */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		AA000001 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1000020 /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A9000001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1000001 /* HeliPartsTrackerApp.swift in Sources */,
				A1000002 /* User.swift in Sources */,
				A1000003 /* Part.swift in Sources */,
				A1000004 /* Helicopter.swift in Sources */,
				A1000005 /* APIService.swift in Sources */,
				A1000006 /* AuthViewModel.swift in Sources */,
				A1000007 /* PartsViewModel.swift in Sources */,
				A1000008 /* HelicoptersViewModel.swift in Sources */,
				A1000009 /* LoginView.swift in Sources */,
				A1000010 /* MainTabView.swift in Sources */,
				A1000011 /* PartsListView.swift in Sources */,
				A1000012 /* PartDetailView.swift in Sources */,
				A1000013 /* AddPartView.swift in Sources */,
				A1000014 /* HelicoptersListView.swift in Sources */,
				A1000015 /* HelicopterDetailView.swift in Sources */,
				A1000016 /* InstallPartView.swift in Sources */,
				A1000017 /* QRScannerView.swift in Sources */,
				A1000018 /* AlertsView.swift in Sources */,
				A1000019 /* SettingsView.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		AD000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		AD000002 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		AE000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = 7KZX225WZP;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = HeliPartsTracker/Resources/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.helitracker.HeliPartsTracker;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		AE000002 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = 7KZX225WZP;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = HeliPartsTracker/Resources/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.helitracker.HeliPartsTracker;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A8000001 /* Build configuration list for PBXNativeTarget "HeliPartsTracker" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AE000001 /* Debug */,
				AE000002 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AC000001 /* Build configuration list for PBXProject "HeliPartsTracker" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AD000001 /* Debug */,
				AD000002 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = AB000001 /* Project object */;
}
PBXPROJ

echo "✅ Xcode project structure created!"
