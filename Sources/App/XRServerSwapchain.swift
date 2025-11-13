//
//  XRServerSwapchain.swift
//  FruitXR
//
//  Created by user on 2025/04/09.
//

import AppKit
import IOSurface
import VideoToolbox
import OSLog

class XREncodeFrameInfo: NSObject {
    let eye: Int8 = 0
}

class XRServerSwapchain: NSObject {
    static let logger = Logger(subsystem: "net.rinsuki.apps.FruitXR", category: "XRServerSession")
    let port: NSMachPort
    @objc let remoteId: UInt32
    
    var surfaces: [IOSurface] = []
    let window = NSWindow(contentRect: .init(origin: .zero, size: .zero), styleMask: .titled, backing: .buffered, defer: true)
    let view = NSView()
    var lastActiveSurface: IOSurface?

    override init() {
        var rawPort: mach_port_t = .init(MACH_PORT_NULL)
        precondition(KERN_SUCCESS == mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &rawPort))
        port = .init(machPort: rawPort, options: [.deallocateReceiveRight])
        self.remoteId = XRServer.shared.lastSwapchainId
        XRServer.shared.lastSwapchainId += 1
        super.init()
        Self.logger.trace("new instance was made: \(self), remoteId=\(self.remoteId)")
        XRServer.shared.swapchains[port.machPort] = self
        XRServer.shared.swapchainsById[remoteId] = self
        XRServer.shared.bindPortAndSchedule(port: port)
        
        view.wantsLayer = true
        window.title = "FruitXR Swapchain \(self)"
        window.contentView = view
        window.makeKeyAndOrderFront(self)
    }
    
    @objc func sendPort() -> mach_port_t {
        precondition(KERN_SUCCESS == mach_port_insert_right(mach_task_self_, port.machPort, port.machPort, .init(MACH_MSG_TYPE_MAKE_SEND)))
        return port.machPort
    }
    
    @objc(addIOSurface:) func add(ioSurface: IOSurface) {
        surfaces.append(ioSurface)
        window.setContentSize(.init(width: ioSurface.width, height: ioSurface.height))
    }
    
    @objc(switchSurfaceTo:) func switchSurface(to index: Int32) {
        let surface = surfaces[Int(index)]
        lastActiveSurface = surface
        view.layer!.contents = surface
    }
}
