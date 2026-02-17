//
//  AppDelegate.swift
//  FruitXR
//
//  Created by user on 2025/03/12.
//

import Cocoa
import FruitXRIPC

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    let vrIPCQueue = DispatchQueue(label: "net.rinsuki.apps.FruitXR.IPC.Server", qos: .userInteractive)
    var machPort: NSMachPort?
    var swapchainCreatedCount: Int32 = 0
    var videoEncoderInitializedCount: UInt32 = 0
    @objc var swapchains: [Int32: XRServerSwapchain] = [:]
    @objc var instances = [mach_port_t: XRServerInstance]()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        activateOpenXRRuntime()
        _ = XRServer.shared // need to access getters
    }
    
    func activateOpenXRRuntime() {
        let openXRDir = "/usr/local/share/openxr/1"
        let openXRRuntimeJSONPath = "\(openXRDir)/active_runtime.json"
        let ourRuntimeJSONPath = Bundle.main.url(forResource: "openxr_manifest", withExtension: "json")!.path()
        while !FileManager.default.fileExists(atPath: openXRDir) {
            do {
                try FileManager.default.createDirectory(atPath: openXRDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // TODO: replace with better onboarding
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Please create \(openXRDir)"
                alert.informativeText = "\(openXRDir) is not exists, and this app doesn't have a permission to create it.\n\nYou need to create the folder by run this script in the Terminal.app:\n\nsudo mkdir -p \(openXRDir) && sudo chown \"$(whoami)\" \(openXRDir)\n\nAfter that, Please click \"Retry\"."
                let retryButton = alert.addButton(withTitle: "Retry")
                retryButton.keyEquivalent = "\r"
                retryButton.tag = NSApplication.ModalResponse.OK.rawValue
                let cancelButton = alert.addButton(withTitle: "Quit")
                cancelButton.keyEquivalent = "q"
                cancelButton.keyEquivalentModifierMask = .command
                cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
                if alert.runModal() != .OK {
                    NSApplication.shared.terminate(self)
                    return
                }
            }
        }
        // read runtime json's destination of symlink
        let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: openXRRuntimeJSONPath)
        if let destination {
            if destination != ourRuntimeJSONPath {
                // replace symlink to our runtime json
                try! FileManager.default.removeItem(atPath: openXRRuntimeJSONPath)
            } else {
                return
            }
        }
        try! FileManager.default.createSymbolicLink(atPath: openXRRuntimeJSONPath, withDestinationPath: ourRuntimeJSONPath)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
