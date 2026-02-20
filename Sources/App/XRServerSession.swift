//
//  XRServerSession.swift
//  FruitXR
//
//  Created by user on 2025/11/12.
//

import CoreImage
import OSLog
import MetalPerformanceShaders

class XRServerSession: NSObject, XRVideoEncoderDelegate {
    static let logger = Logger(subsystem: "net.rinsuki.apps.FruitXR", category: "XRServerSession")
    let port: NSMachPort
    var encoder = XRVideoEncoder(eye: 0)
    var websocket = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:18034/encoder")!)
    var currentInfo = IPCCurrentHeadsetInfo()
    let instance: XRServerInstance
    var pixelBufferPool: CVPixelBufferPool?
    let ciContext: CIContext
    let commandQueue: MTLCommandQueue
    var textureCache: CVMetalTextureCache!
    let scale: MPSImageLanczosScale
    let textures: [MTLTexture]
    
    let bufferWidth = 2064
    let bufferHeight = 2208
    
    init(instance: XRServerInstance) {
        self.instance = instance
        var rawPort: mach_port_t = .init(MACH_PORT_NULL)
        precondition(KERN_SUCCESS == mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &rawPort))
        port = .init(machPort: rawPort, options: [.deallocateReceiveRight])
        precondition(kCVReturnSuccess == CVPixelBufferPoolCreate(nil, nil, [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: bufferWidth * 2,
            kCVPixelBufferHeightKey: bufferHeight,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ] as CFDictionary, &pixelBufferPool))
        ciContext = .init(mtlDevice: instance.device)
        commandQueue = instance.device.makeCommandQueue()!
        CVMetalTextureCacheCreate(nil, nil, instance.device, nil, &textureCache)
        scale = .init(device: instance.device)
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: bufferWidth, height: bufferHeight, mipmapped: false)
        textureDesc.usage = [.shaderWrite]
        textures = [
            instance.device.makeTexture(descriptor: textureDesc)!,
            instance.device.makeTexture(descriptor: textureDesc)!,
        ]
        super.init()
        commandQueue.label = "XRServerSession:\(self)"
        Self.logger.trace("new instance was made: \(self)")
        XRServer.shared.sessions[port.machPort] = self
        XRServer.shared.bindPortAndSchedule(port: port)
        encoder.delegate = self
        websocket.resume()
        // TODO: should wait until websocket opens
        Task {
            await receiveLoop()
        }
    }
    
    deinit {
        Self.logger.trace("deinit: \(self)")
    }
    
    func receiveLoop() async {
        do {
            while true {
                let res = try await websocket.receive()
                guard case .data(let data) = res else {
                    continue
                }
                let fb = try FromBrowser(serializedBytes: data)
                guard let message = fb.message else {
                    return
                }
                switch message {
                case .initEncoder(let ie):
                    // TODO
                    break
                case .currentPosition(let cp):
                    currentInfo.hmd.set(from: cp.hmd)
                    currentInfo.leftEye.set(from: cp.leftEye)
                    currentInfo.rightEye.set(from: cp.rightEye)
                    currentInfo.leftController.set(from: cp.leftController)
                    currentInfo.rightController.set(from: cp.rightController)
                }
            }
        } catch {
            Self.logger.error("receiveLoop fail: \(error)")
        }
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
        let swapchain = XRServerSwapchain(session: self)
        return swapchain
    }
    
    @objc func endFrame(info: IPCEndFrameInfo) {
        var info = info
        withUnsafePointer(to: &info.eyes) {
            $0.withMemoryRebound(to: IPCEndFrameInfoPerEye.self, capacity: 2) { eyes in
                var images: [Surface] = []
                var pixelBuffer: CVPixelBuffer?
                let res = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBuffer)
                precondition(res == kCVReturnSuccess)
                let buffer = commandQueue.makeCommandBuffer()!
                var cvTexture: CVMetalTexture!
                assert(kCVReturnSuccess == CVMetalTextureCacheCreateTextureFromImage(
                    nil, textureCache,
                    pixelBuffer!, nil, .bgra8Unorm, CVPixelBufferGetWidth(pixelBuffer!), CVPixelBufferGetHeight(pixelBuffer!),
                    0, &cvTexture
                ))
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
                    let texture = ioSurface.texture
                    var transform = MPSScaleTransform(
                        scaleX: Double(bufferWidth) / Double(texture.width),
                        scaleY: Double(bufferHeight) / Double(texture.height),
                        translateX: i == 0 ? 0 : 0.5,
                        translateY: 0
                    )
                    withUnsafePointer(to: &transform) { ptr in
                        scale.scaleTransform = ptr
                        scale.encode(
                            commandBuffer: buffer,
                            sourceTexture: texture,
                            destinationTexture: textures[i],
                        )
                    }
                }
                let blit = buffer.makeBlitCommandEncoder()!
                for i in 0..<2 {
                    blit.copy(
                        from: textures[i],
                        sourceSlice: 0, sourceLevel: 0,
                        sourceOrigin: .init(x: 0, y: 0, z: 0),
                        sourceSize: .init(width: bufferWidth, height: bufferHeight, depth: textures[i].depth),
                        to: CVMetalTextureGetTexture(cvTexture)!,
                        destinationSlice: 0, destinationLevel: 0,
                        destinationOrigin: .init(x: bufferWidth * i, y: 0, z: 0)
                    )
                }
                blit.endEncoding()
                buffer.commit()
                buffer.waitUntilCompleted()
                encoder.handle(pixelBuffer: pixelBuffer!)
            }
        }
    }
    
    @objc func getCurrentHeadsetInfo(_ chi: UnsafeMutablePointer<IPCCurrentHeadsetInfo>) {
        chi.pointee = currentInfo
    }
}
