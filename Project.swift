import ProjectDescription

let deploymentTargets = DeploymentTargets.macOS("15.0")

let appTarget = Target.target(
    name: "ActionTrigger",
    destinations: .macOS,
    product: .app,
    bundleId: "com.foyoodo.ActionTrigger",
    deploymentTargets: deploymentTargets,
    infoPlist: .extendingDefault(
        with: [
            "CFBundleDisplayName": "ActionTrigger",
            "CFBundleShortVersionString": "0.2.0",
            "CFBundleVersion": "2",
        ]
    ),
    buildableFolders: [
        "Shared",
        "ActionTrigger/Sources",
        "ActionTrigger/Resources",
    ],
    entitlements: "ActionTrigger/ActionTrigger.entitlements",
    dependencies: [
        .target(name: "FinderExtension"),
    ]
)

let finderExtensionTarget = Target.target(
    name: "FinderExtension",
    destinations: .macOS,
    product: .extensionKitExtension,
    bundleId: "com.foyoodo.ActionTrigger.FinderExtension",
    deploymentTargets: deploymentTargets,
    infoPlist: .file(path: "FinderExtension/Info.plist"),
    buildableFolders: [
        "Shared",
        "FinderExtension/Sources",
        "ActionTriggerHelperXPC/Shared",
    ],
    entitlements: "FinderExtension/FinderExtension.entitlements",
    dependencies: [
        .target(name: "ActionTriggerHelperXPC")
    ]
)

let xpcTarget = Target.target(
    name: "ActionTriggerHelperXPC",
    destinations: .macOS,
    product: .xpc,
    bundleId: "com.foyoodo.ActionTrigger.xpc",
    infoPlist: .file(path: "ActionTriggerHelperXPC/Info.plist"),
    buildableFolders: [
        "ActionTriggerHelperXPC/Shared",
        "ActionTriggerHelperXPC/Sources",
    ],
    entitlements: "ActionTriggerHelperXPC/ActionTriggerHelperXPC.entitlements",
)

let project = Project(
    name: "ActionTrigger",
    organizationName: "foyoodo",
    targets: [
        appTarget,
        finderExtensionTarget,
        xpcTarget,
    ]
)
