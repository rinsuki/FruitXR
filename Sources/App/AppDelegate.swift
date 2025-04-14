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
    @objc var swapchains: [Int32: XRServerSwapchain] = [:]
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        activateOpenXRRuntime()
        let machBootstrapServer = FXMachBootstrapServer.sharedInstance() as! FXMachBootstrapServer
        let port = machBootstrapServer.servicePort(withName: "net.rinsuki.apps.FruitXR.IPC") as! NSMachPort
        port.setDelegate(self)
        machPort = port
        port.schedule(in: .main, forMode: .default) // TODO: runs on non-main thread
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

extension AppDelegate: NSMachPortDelegate {
    func handleMachMessage(_ msg: UnsafeMutableRawPointer) {
        var reply = __ReplyUnion__FI_S_FruitXR_subsystem()
        withUnsafeMutableBytes(of: &reply) { ptr in
            let outPtr = ptr.baseAddress!.bindMemory(to: mach_msg_header_t.self, capacity: 1)
            let res = FruitXR_server(
                msg.bindMemory(to: mach_msg_header_t.self, capacity: 1),
                outPtr
            )
            if res != 0, outPtr.pointee.msgh_remote_port != 0 {
                let resres = mach_msg(
                    outPtr,
                    MACH_SEND_MSG,
                    outPtr.pointee.msgh_size,
                    0,
                    mach_port_name_t(MACH_PORT_NULL),
                    0,
                    mach_port_name_t(MACH_PORT_NULL)
                )
                assert(resres == 0)
            }
        }
    }
}

