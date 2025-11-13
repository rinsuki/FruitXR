//
//  XRServerInstance.swift
//  FruitXR
//
//  Created by user on 2025/11/12.
//

import OSLog

class XRServerInstance: NSObject {
    static let logger = Logger(subsystem: "net.rinsuki.apps.FruitXR", category: "XRServerInstance")
    let port: NSMachPort
    
    override init() {
        var rawPort: mach_port_t = .init(MACH_PORT_NULL)
        precondition(KERN_SUCCESS == mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &rawPort))
        port = .init(machPort: rawPort, options: [.deallocateReceiveRight])
        super.init()
        Self.logger.trace("new instance was made: \(self)")
        XRServer.shared.instances[port.machPort] = self
        XRServer.shared.bindPortAndSchedule(port: port)
    }
    
    deinit {
        Self.logger.trace("deinit: \(self)")
    }
    
    @objc func sendPort() -> mach_port_t {
        precondition(KERN_SUCCESS == mach_port_insert_right(mach_task_self_, port.machPort, port.machPort, .init(MACH_MSG_TYPE_MAKE_SEND)))
        
        return port.machPort
    }
    
    @objc func createSession() -> XRServerSession {
        let session = XRServerSession()
        return session
    }
}
