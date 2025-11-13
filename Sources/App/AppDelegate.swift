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
        let openXRRuntimeJSONPath = "/usr/local/share/openxr/1/active_runtime.json"
        let ourRuntimeJSONPath = Bundle.main.url(forResource: "openxr_manifest", withExtension: "json")!.path()
        try? FileManager.default.createDirectory(atPath: "/usr/local/share/openxr/1", withIntermediateDirectories: true, attributes: nil)
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
    
    @objc func createServerSwapchainObject() -> Int32 {
        swapchainCreatedCount += 1
        let swapchain = XRServerSwapchain()
        swapchains[swapchainCreatedCount] = swapchain
        
        return swapchainCreatedCount
    }

}
