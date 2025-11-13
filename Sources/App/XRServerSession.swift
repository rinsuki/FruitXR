//
//  XRServerSession.swift
//  FruitXR
//
//  Created by user on 2025/11/12.
//

import OSLog

class XRServerSession: NSObject, XRVideoEncoderDelegate {
    static let logger = Logger(subsystem: "net.rinsuki.apps.FruitXR", category: "XRServerSession")
    let port: NSMachPort
    var encoder = (XRVideoEncoder(eye: 0), XRVideoEncoder(eye: 1))
    var websocket = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:18034/encoder")!)
    
    override init() {
        var rawPort: mach_port_t = .init(MACH_PORT_NULL)
        precondition(KERN_SUCCESS == mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &rawPort))
        port = .init(machPort: rawPort, options: [.deallocateReceiveRight])
        super.init()
        Self.logger.trace("new instance was made: \(self)")
        XRServer.shared.sessions[port.machPort] = self
        XRServer.shared.bindPortAndSchedule(port: port)
        encoder.0.delegate = self
        encoder.1.delegate = self
        websocket.resume()
        // TODO: should wait until websocket opens
    }
    
    deinit {
        Self.logger.trace("deinit: \(self)")
    }
    
    func send(message: ToBrowser) {
        websocket.send(.data(try! message.serializedData())) { error in
            if let error {
                print(error)
            }
        }
    }
    
    @objc func sendPort() -> mach_port_t {
        precondition(KERN_SUCCESS == mach_port_insert_right(mach_task_self_, port.machPort, port.machPort, .init(MACH_MSG_TYPE_MAKE_SEND)))
        
        return port.machPort
    }
    
    @objc func createSwapchain() -> XRServerSwapchain {
        let swapchain = XRServerSwapchain()
        return swapchain
    }
    
    @objc func endFrame(info: EndFrameInfo) {
        var info = info
        withUnsafePointer(to: &encoder) {
            $0.withMemoryRebound(to: XRVideoEncoder.self, capacity: 2) { encoder in
                withUnsafePointer(to: &info.eyes) {
                    $0.withMemoryRebound(to: EndFrameInfoPerEye.self, capacity: 2) { eyes in
                        for i in 0..<2 {
                            let swapchainId = eyes[i].swapchain_id
                            guard let swapchain = XRServer.shared.swapchainsById[swapchainId] else {
                                Self.logger.error("failed to get eyes[\(i)].swapchain (id=\(swapchainId))")
                                return
                            }
                            guard let ioSurface = swapchain.lastActiveSurface else {
                                Self.logger.warning("swapchain doesn't have a last active IOSurface")
                                return
                            }
                            encoder[i].handle(ioSurface: ioSurface)
                        }
                    }
                }
            }
        }
    }
}
