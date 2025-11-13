//
//  XRServer.swift
//  FruitXR
//
//  Created by user on 2025/11/12.
//

@objc
class XRServer: NSObject, NSMachPortDelegate {
    @objc static let shared = XRServer()
    var port: NSMachPort
    
    @objc var instances = [mach_port_t: XRServerInstance]()
    @objc var sessions = [mach_port_t: XRServerSession]()
    @objc var swapchains = [mach_port_t: XRServerSwapchain]()
    @objc var swapchainsById = [UInt32: XRServerSwapchain]()
    
    var lastSwapchainId: UInt32 = 1
    
    private override init() {
        let machBootstrapServer = FXMachBootstrapServer.sharedInstance() as! FXMachBootstrapServer
        let port = machBootstrapServer.servicePort(withName: "net.rinsuki.apps.FruitXR.IPC") as! NSMachPort
        self.port = port
        super.init()
        bindPortAndSchedule(port: port)
    }
    
    func bindPortAndSchedule(port: NSMachPort) {
        port.setDelegate(self)
        port.schedule(in: .main, forMode: .default) // TODO: runs on non-main thread
    }
    
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
    
    @objc func createServerInstanceObject() -> XRServerInstance {
        let instance = XRServerInstance()
        instances[instance.port.machPort] = instance
        return instance
    }
}
