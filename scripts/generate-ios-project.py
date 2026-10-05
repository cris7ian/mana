#!/usr/bin/env python3
"""Generate only the isolated iOS project, configuration, and asset catalog.

Uses the Python standard library. Does not modify Swift sources or the Mac project.
Run from any directory with: python3 scripts/generate-ios-project.py
"""

import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"
PROJECT = IOS / "ManaIOS.xcodeproj"
TEAM = "5P4X92K99Q"
BUNDLE = "com.salsaparapizza.mana.ios"
OBJECTS = {}


def identifier(name):
    return hashlib.sha256(f"ManaIOS:{name}".encode()).hexdigest()[:24].upper()


def obj(label, isa, **fields):
    key = identifier(label)
    OBJECTS[key] = {"isa": isa, **fields}
    return key


def encode(value, depth=0):
    indent = "\t" * depth
    if isinstance(value, dict):
        entries = [f"{indent}\t{key} = {encode(item, depth + 1)};" for key, item in value.items()]
        return "{\n" + "\n".join(entries) + f"\n{indent}}}"
    if isinstance(value, list):
        return "(\n" + "".join(f"{indent}\t{encode(item, depth + 1)},\n" for item in value) + f"{indent})"
    value = str(value)
    return value if re.fullmatch(r"[A-Za-z0-9_./]+", value) else json.dumps(value)


def write_plist(name, values):
    path = IOS / "Config" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(values, sort_keys=False))


def configurations(name, common):
    configs = []
    for mode in ("Debug", "Release"):
        configs.append(obj(f"{name}:{mode}", "XCBuildConfiguration", buildSettings=common(mode), name=mode))
    return obj(f"{name}:configurations", "XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def project_settings(mode):
    values = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "COPY_PHASE_STRIP": "NO",
        "DEAD_CODE_STRIPPING": "YES",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym",
        "ENABLE_TESTABILITY": "YES" if mode == "Debug" else "NO",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0" if mode == "Debug" else "s",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
    }
    if mode == "Debug":
        values.update(ONLY_ACTIVE_ARCH="YES", SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG $(inherited)",
                      GCC_PREPROCESSOR_DEFINITIONS=["DEBUG=1", "$(inherited)"])
    else:
        values.update(SWIFT_COMPILATION_MODE="wholemodule", VALIDATE_PRODUCT="YES")
    return values


def target_settings(name, mode):
    values = {
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": TEAM,
        "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE,
        "PRODUCT_NAME": name,
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    }
    if name == "ManaIOS":
        values.update(PRODUCT_NAME="Mana", PRODUCT_MODULE_NAME="ManaIOS",
                      GENERATE_INFOPLIST_FILE="NO", INFOPLIST_FILE="Config/Mana-Info.plist",
                      CODE_SIGN_ENTITLEMENTS="Config/Mana.entitlements",
                      ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon", ENABLE_PREVIEWS="YES")
    elif name == "ManaWidgets":
        values.update(PRODUCT_BUNDLE_IDENTIFIER=BUNDLE + ".widgets", GENERATE_INFOPLIST_FILE="NO",
                      INFOPLIST_FILE="Config/ManaWidgets-Info.plist",
                      CODE_SIGN_ENTITLEMENTS="Config/ManaWidgets.entitlements",
                      APPLICATION_EXTENSION_API_ONLY="YES", SKIP_INSTALL="YES",
                      LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks",
                                               "@executable_path/../../Frameworks"])
    else:
        values.update(PRODUCT_BUNDLE_IDENTIFIER=BUNDLE + (".tests" if name == "ManaIOSTests" else ".uitests"),
                      SWIFT_EMIT_LOC_STRINGS="NO", SKIP_INSTALL="YES")
        if name == "ManaIOSTests":
            values.update(BUNDLE_LOADER="$(TEST_HOST)", TEST_HOST="$(BUILT_PRODUCTS_DIR)/Mana.app/Mana")
        else:
            values.update(TEST_TARGET_NAME="ManaIOS")
    return values


def dependency(owner, target):
    proxy = obj(f"{owner}:{target}:proxy", "PBXContainerItemProxy", containerPortal=identifier("project"),
                proxyType=1, remoteGlobalIDString=identifier(target), remoteInfo=target)
    return obj(f"{owner}:{target}:dependency", "PBXTargetDependency", target=identifier(target), targetProxy=proxy)


def generate_project():
    groups = {name: obj(f"group:{name}", "PBXFileSystemSynchronizedRootGroup", explicitFileTypes={},
                        explicitFolders=[], path=name, sourceTree="<group>")
              for name in ("Mana", "Shared", "ManaWidgets", "ManaTests", "ManaUITests")}
    package = obj("ManaCore:package", "XCLocalSwiftPackageReference", relativePath="../Packages/ManaCore")
    targets = []
    products = []
    specs = [
        ("ManaIOS", "Mana.app", "wrapper.application", "application", ["Mana", "Shared"]),
        ("ManaWidgets", "ManaWidgets.appex", "wrapper.app-extension", "app-extension", ["ManaWidgets", "Shared"]),
        ("ManaIOSTests", "ManaIOSTests.xctest", "wrapper.cfbundle", "bundle.unit-test", ["ManaTests"]),
        ("ManaIOSUITests", "ManaIOSUITests.xctest", "wrapper.cfbundle", "bundle.ui-testing", ["ManaUITests"]),
    ]
    for name, product, file_type, product_type, source_groups in specs:
        ref = obj(f"{name}:product", "PBXFileReference", explicitFileType=file_type, includeInIndex=0,
                  path=product, sourceTree="BUILT_PRODUCTS_DIR")
        products.append(ref)
        package_products, frameworks = [], []
        if name != "ManaIOSUITests":
            package_product = obj(f"{name}:ManaCore", "XCSwiftPackageProductDependency", package=package,
                                  productName="ManaCore")
            package_products.append(package_product)
            frameworks.append(obj(f"{name}:ManaCore:build", "PBXBuildFile", productRef=package_product))
        phases = [obj(f"{name}:{phase}", f"PBX{phase}BuildPhase", buildActionMask=2147483647,
                      files=frameworks if phase == "Frameworks" else [], runOnlyForDeploymentPostprocessing=0)
                  for phase in ("Sources", "Frameworks", "Resources")]
        dependencies = []
        if name == "ManaIOS":
            dependencies.append(dependency(name, "ManaWidgets"))
            embed = obj("ManaWidgets:embed", "PBXBuildFile", fileRef=identifier("ManaWidgets:product"),
                        settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
            phases.append(obj("extensions:copy", "PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                              dstPath="", dstSubfolderSpec=13, files=[embed], name="Embed App Extensions",
                              runOnlyForDeploymentPostprocessing=0))
        elif name.endswith("Tests"):
            dependencies.append(dependency(name, "ManaIOS"))
        targets.append(obj(name, "PBXNativeTarget",
                           buildConfigurationList=configurations(name, lambda mode, name=name: target_settings(name, mode)),
                           buildPhases=phases, buildRules=[], dependencies=dependencies,
                           fileSystemSynchronizedGroups=[groups[group] for group in source_groups], name=name,
                           packageProductDependencies=package_products, productName=product.split(".")[0],
                           productReference=ref, productType="com.apple.product-type." + product_type))
    product_group = obj("products", "PBXGroup", children=products, name="Products", sourceTree="<group>")
    config_refs = []
    for filename in ("Mana-Info.plist", "ManaWidgets-Info.plist", "Mana.entitlements", "ManaWidgets.entitlements"):
        config_refs.append(obj(f"config:{filename}", "PBXFileReference",
                               lastKnownFileType="text.plist.entitlements" if filename.endswith("entitlements") else "text.plist.xml",
                               path=filename, sourceTree="<group>"))
    config_group = obj("config", "PBXGroup", children=config_refs, path="Config", sourceTree="<group>")
    main_group = obj("main", "PBXGroup", children=[*groups.values(), config_group, product_group], sourceTree="<group>")
    attributes = {identifier(name): {"CreatedOnToolsVersion": "26.0", "DevelopmentTeam": TEAM,
                                    "ProvisioningStyle": "Automatic"} for name, *_ in specs}
    for name in ("ManaIOS", "ManaWidgets"):
        attributes[identifier(name)]["SystemCapabilities"] = {
            "com.apple.ApplicationGroups.iOS": {"enabled": 1},
            "com.apple.Keychain": {"enabled": 1},
        }
    attributes[identifier("ManaIOS")]["SystemCapabilities"]["com.apple.BackgroundModes"] = {"enabled": 1}
    for name in ("ManaIOSTests", "ManaIOSUITests"):
        attributes[identifier(name)]["TestTargetID"] = identifier("ManaIOS")
    project = obj("project", "PBXProject",
                  attributes={"BuildIndependentTargetsInParallel": 1, "LastSwiftUpdateCheck": "2600",
                              "LastUpgradeCheck": "2600", "TargetAttributes": attributes},
                  buildConfigurationList=configurations("project", project_settings), developmentRegion="en",
                   hasScannedForEncodings=0, knownRegions=["en", "de", "es", "fr", "Base"], mainGroup=main_group,
                  minimizedProjectReferenceProxies=1, packageReferences=[package], preferredProjectObjectVersion=77,
                  productRefGroup=product_group, projectDirPath="", projectRoot="", targets=targets)
    PROJECT.mkdir(parents=True, exist_ok=True)
    values = {"archiveVersion": 1, "classes": {}, "objectVersion": 77, "objects": OBJECTS, "rootObject": project}
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(values) + "\n")


def generate_scheme():
    def reference(name, product):
        return (f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier(name)}" '
                f'BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:ManaIOS.xcodeproj"/>')

    app = reference("ManaIOS", "Mana.app")
    tests = "\n".join(f'<TestableReference skipped="NO">{reference(name, name + ".xctest")}</TestableReference>'
                      for name in ("ManaIOSTests", "ManaIOSUITests"))
    path = PROJECT / "xcshareddata" / "xcschemes" / "ManaIOS.xcscheme"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>{tests}</Testables>
    <MacroExpansion>{app}</MacroExpansion>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
    widget = reference("ManaWidgets", "ManaWidgets.appex")
    (path.parent / "ManaWidgets.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="YES" buildForAnalyzing="YES">{widget}</BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')


def generate_configuration():
    base = {
        "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
        "CFBundleDisplayName": "Mana",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "ManaKeychainAccessGroup": "$(AppIdentifierPrefix)" + BUNDLE + ".shared",
    }
    write_plist("Mana-Info.plist", {
        **base,
        "LSRequiresIPhoneOS": True,
        "CFBundleURLTypes": [{"CFBundleURLName": BUNDLE, "CFBundleURLSchemes": ["mana"]}],
        "BGTaskSchedulerPermittedIdentifiers": [BUNDLE + ".refresh"],
        "UIBackgroundModes": ["fetch"],
        "UILaunchScreen": {},
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {}},
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                                              "UIInterfaceOrientationLandscapeRight"],
        "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                                                   "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
    })
    write_plist("ManaWidgets-Info.plist", {
        **base, "CFBundleDisplayName": "Mana Widgets",
        "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
    })
    for name in ("Mana", "ManaWidgets"):
        write_plist(name + ".entitlements", {
            "com.apple.security.application-groups": ["group." + BUNDLE],
            "keychain-access-groups": ["$(AppIdentifierPrefix)" + BUNDLE + ".shared"],
        })


def opaque_icon(source, destination):
    """Flatten the existing 8-bit RGBA PNG without lossy encoding or dependencies."""
    data = source.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    offset, compressed = 8, bytearray()
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            assert (width, height, depth, color, compression, filtering, interlace) == (1024, 1024, 8, 6, 0, 0, 0)
        elif kind == b"IDAT":
            compressed.extend(payload)
        offset += length + 12
    raw = zlib.decompress(compressed)
    stride, output, previous = width * 4, bytearray(), bytearray(width * 4)
    for y in range(height):
        start = y * (stride + 1)
        method = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            left, above, corner = row[x - 4] if x >= 4 else 0, previous[x], previous[x - 4] if x >= 4 else 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = above
            elif method == 3:
                predictor = (left + above) // 2
            elif method == 4:
                p = left + above - corner
                distances = (abs(p - left), abs(p - above), abs(p - corner))
                predictor = (left, above, corner)[distances.index(min(distances))]
            else:
                assert method == 0
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        output.append(0)
        for x in range(0, stride, 4):
            alpha = row[x + 3]
            for channel, background in enumerate((5, 22, 89)):
                output.append((row[x + channel] * alpha + background * (255 - alpha) + 127) // 255)
        previous = row

    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    destination.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                            + chunk(b"IDAT", zlib.compress(output, 9)) + chunk(b"IEND", b""))


def generate_assets():
    source = ROOT / "Mana" / "Assets.xcassets"
    catalog = IOS / "Mana" / "Assets.xcassets"
    catalog.mkdir(parents=True, exist_ok=True)
    (catalog / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name in ("ManaBrandIcon", "Provider-codex", "Provider-opencode"):
        shutil.copytree(source / (name + ".imageset"), catalog / (name + ".imageset"), dirs_exist_ok=True)
        contents = catalog / (name + ".imageset") / "Contents.json"
        description = json.loads(contents.read_text())
        for image in description.get("images", []):
            if image.get("idiom") == "mac":
                image["idiom"] = "universal"
        contents.write_text(json.dumps(description, indent=2) + "\n")
    icons = catalog / "AppIcon.appiconset"
    icons.mkdir(exist_ok=True)
    opaque_icon(source / "AppIcon.appiconset" / "AppIcon-512@2x.png", icons / "AppIcon.png")
    (icons / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


if __name__ == "__main__":
    generate_project()
    generate_scheme()
    generate_configuration()
    generate_assets()
    print("Generated ios/ManaIOS.xcodeproj, ios/Config, and ios/Mana/Assets.xcassets")
