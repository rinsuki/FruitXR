//
//  XRSwapchain.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Metal
import IOSurface
@preconcurrency import AppKit
import FruitXRIPC

class XRSwapchain {
    private let session: XRSession
    private var ioSurfaces = [IOSurface]()
    private var textures = [MTLTexture]()
    private var destroyed = false
    var remoteId: UInt32
    var port: mach_port_t
    var currentTextureIndex: Int = 0
    var ioSurfaceBackend = true

    nonisolated(unsafe) init(session: XRSession, createInfo: XrSwapchainCreateInfo) throws(XRError) {
        self.session = session
        
        port = 0
        remoteId = 0
        assert(FI_C_SwapchainCreate(session.port, &port, &remoteId) == KERN_SUCCESS)

        switch session.graphicsAPI {
        case .metal(let commandQueue):
            for i in 0..<2 {
                var metalPixelFormat = MTLPixelFormat(rawValue: .init(createInfo.format))!
                let ioSurface = IOSurface(properties: [
                    .width: createInfo.width,
                    .height: createInfo.height,
                    .bytesPerElement: 4,
                    .pixelFormat: metalPixelFormat == .depth32Float ? kCVPixelFormatType_DepthFloat32 : kCVPixelFormatType_32BGRA,
                    .name: "test",
                ])!
                switch metalPixelFormat {
                case .rgba8Unorm:
                    print("WARNING: converting RGB to BGR")
                    metalPixelFormat = .bgra8Unorm
                    break
                case .rgba8Unorm_srgb:
                    print("WARNING: converting RGB to BGR")
                    metalPixelFormat = .bgra8Unorm_srgb
                    IOSurfaceSetValue(ioSurface, "IOSurfaceColorSpace" as CFString, CGColorSpace.sRGB)
                    break
                case .bgra8Unorm:
                    // its ok
                    break
                case .bgra8Unorm_srgb:
                    IOSurfaceSetValue(ioSurface, "IOSurfaceColorSpace" as CFString, CGColorSpace.sRGB)
                    break
                case .depth32Float:
                    ioSurfaceBackend = false
                    break
                default:
                    fatalError() // TODO: return error properly
                }
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: metalPixelFormat, width: ioSurface.width, height: ioSurface.height, mipmapped: false)
                descriptor.usage = [
                    .renderTarget,
                ]
                descriptor.storageMode = .managed
                let texture: any MTLTexture
                if ioSurfaceBackend {
                    ioSurfaces.append(ioSurface)
                    texture = commandQueue.device.makeTexture(
                        descriptor: descriptor,
                        iosurface: ioSurface,
                        plane: 0
                    )!
                    texture.label = "\(self) IOSurface-based \(i)"
                    print("trying to send", ioSurface, "through", port)
                    assert(FI_C_SwapchainAddIOSurface(port, IOSurfaceCreateMachPort(ioSurface)) == KERN_SUCCESS)
                } else {
                    texture = commandQueue.device.makeTexture(descriptor: descriptor)!
                    texture.label = "\(self) local \(i)"
                }
                textures.append(texture)

            }
        }
    }
    
    
    deinit {
        precondition(destroyed)
    }
    
    func destroy() {
        ioSurfaces.removeAll()
        textures.removeAll()
        destroyed = true
    }
    
    func enumerateImages(images: UnsafeMutableBufferPointer<XrSwapchainImageBaseHeader>, imageCount: inout UInt32) -> XrResult {
        if images.count < textures.count {
            imageCount = .init(textures.count)
            return XR_SUCCESS
        }
        let imagesRaw = UnsafeMutableRawPointer(images.baseAddress)!
        
        switch session.graphicsAPI {
        case .metal(let commandQueue):
            imagesRaw.withMemoryRebound(to: XrSwapchainImageMetalKHR.self, capacity: images.count) { metalImages in
                for i in 0..<textures.count {
                    metalImages[i].texture = Unmanaged.passUnretained(textures[i]).toOpaque()
               }
            }
            imageCount = .init(textures.count)
        }
        
        return XR_SUCCESS
    }
    
    func acquireImage(info: XrSwapchainImageAcquireInfo?, index: inout UInt32) -> XrResult {
        // print("STUB: XRSwapchain.acquireImage(\(info), \(index))")
        currentTextureIndex += 1
        index = .init(currentTextureIndex % textures.count)
        return XR_SUCCESS
    }
    
    func waitImage(info: XrSwapchainImageWaitInfo?) -> XrResult {
        // print("STUB: XRSwapchain.waitImage(\(info))")
        return XR_SUCCESS
    }

    func releaseImage(info: XrSwapchainImageReleaseInfo?) -> XrResult {
        // print("STUB: XRSwapchain.releaseImage(\(info))")
        if ioSurfaceBackend {
            assert(FI_C_SwapchainSwitch(port, Int32(currentTextureIndex % textures.count)) == KERN_SUCCESS)
        }
        return XR_SUCCESS
    }
}

func xrCreateSwapchain(session: XrSession?, createInfo: UnsafePointer<XrSwapchainCreateInfo>?, swapchainPtr: UnsafeMutablePointer<XrSwapchain?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    do {
        let swapchain = try XRSwapchain(session: sessionObj, createInfo: createInfo!.pointee)
        let ptr = Unmanaged.passRetained(swapchain).toOpaque()
        swapchainPtr!.pointee = OpaquePointer(ptr)
    } catch {
        return error.result
    }
    
    return XR_SUCCESS
}

func xrEnumerateSwapchainImages(swapchain: XrSwapchain?, imageCapacityInput: UInt32, imageCountOutput: UnsafeMutablePointer<UInt32>?, images: UnsafeMutablePointer<XrSwapchainImageBaseHeader>?) -> XrResult {
    guard let swapchain else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let swapchainObj = Unmanaged<XRSwapchain>.fromOpaque(.init(swapchain)).takeUnretainedValue()
    return swapchainObj.enumerateImages(images: .init(start: images, count: .init(imageCapacityInput)), imageCount: &imageCountOutput!.pointee)
}

func xrDestroySwapchain(swapchain: XrSwapchain?) -> XrResult {
    guard let swapchain else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    autoreleasepool {
        let swapchainObj = Unmanaged<XRSwapchain>.fromOpaque(.init(swapchain)).takeRetainedValue()
        swapchainObj.destroy()
    }
    
    return XR_SUCCESS
}

func xrAcquireSwapchainImage(swapchain: XrSwapchain?, acquireInfo: UnsafePointer<XrSwapchainImageAcquireInfo>?, index: UnsafeMutablePointer<UInt32>?) -> XrResult {
    guard let swapchain else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let swapchainObj = Unmanaged<XRSwapchain>.fromOpaque(.init(swapchain)).takeUnretainedValue()
    return swapchainObj.acquireImage(info: acquireInfo?.pointee, index: &index!.pointee)
}

func xrWaitSwapchainImage(swapchain: XrSwapchain?, waitInfo: UnsafePointer<XrSwapchainImageWaitInfo>?) -> XrResult {
    guard let swapchain else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let swapchainObj = Unmanaged<XRSwapchain>.fromOpaque(.init(swapchain)).takeUnretainedValue()
    return swapchainObj.waitImage(info: waitInfo?.pointee)
}

func xrReleaseSwapchainImage(swapchain: XrSwapchain?, releaseInfo: UnsafePointer<XrSwapchainImageReleaseInfo>?) -> XrResult {
    guard let swapchain else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let swapchainObj = Unmanaged<XRSwapchain>.fromOpaque(.init(swapchain)).takeUnretainedValue()
    return swapchainObj.releaseImage(info: releaseInfo?.pointee)
}

