//
//  XRSession.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation
import Metal

class XRSession {
    let instance: XRInstance
    let graphicsAPI: GraphicsAPI
    private(set) var destroyed = false

    enum GraphicsAPI {
        case metal(commandQueue: MTLCommandQueue)
    }

    init(instance: XRInstance, graphicsAPI: GraphicsAPI) {
        self.instance = instance
        self.graphicsAPI = graphicsAPI
    }
    
    static func create(instance: XRInstance, createInfo: XrSessionCreateInfo) -> XRResult<XRSession> {
        print(createInfo.next)
        if createInfo.next == nil {
            return .failure(XR_ERROR_GRAPHICS_DEVICE_INVALID)
        }
        let nextType = createInfo.next.bindMemory(to: XrStructureType.self, capacity: 1).pointee
        
        let graphicsAPI: GraphicsAPI
        
        switch nextType {
        case XR_TYPE_GRAPHICS_BINDING_METAL_KHR:
            let next = createInfo.next.bindMemory(to: XrGraphicsBindingMetalKHR.self, capacity: 1).pointee
            let commandQueue = Unmanaged<MTLCommandQueue>.fromOpaque(.init(next.commandQueue)).takeUnretainedValue()
            graphicsAPI = GraphicsAPI.metal(commandQueue: commandQueue)
            break
        default:
            print("INVALID next: \(nextType)")
            return .failure(XR_ERROR_RUNTIME_FAILURE)
        }
        
        let session = XRSession(instance: instance, graphicsAPI: graphicsAPI)
        instance.push(event: .ready(session))
        return .success(session)
    }
    
    deinit {
        precondition(destroyed)
    }
    
    func destroy() {
        destroyed = true
    }
    
    func enumerateReferenceSpaces(spaces: UnsafeMutableBufferPointer<XrReferenceSpaceType>, spaceCount: inout UInt32) -> XrResult {
        let ourSupportedSpaces = [
            XR_REFERENCE_SPACE_TYPE_LOCAL,
            XR_REFERENCE_SPACE_TYPE_VIEW,
        ]
        
        if spaces.count < ourSupportedSpaces.count {
            spaceCount = .init(ourSupportedSpaces.count)
            return XR_SUCCESS
        }
        
        for (i, space) in ourSupportedSpaces.enumerated() {
            spaces[i] = space
        }
        
        spaceCount = .init(ourSupportedSpaces.count)
        return XR_SUCCESS
    }
    
    func enumerateSwapchainFormats(formats: UnsafeMutableBufferPointer<Int64>, formatCount: inout UInt32) -> XrResult {
        switch graphicsAPI {
        case .metal(_):
            let ourSupportedFormats: [MTLPixelFormat] = [
                MTLPixelFormat.bgra8Unorm,
                MTLPixelFormat.bgra8Unorm_srgb,
                MTLPixelFormat.rgba8Unorm,
                MTLPixelFormat.rgba8Unorm_srgb,
            ]
            
            if formats.count < ourSupportedFormats.count {
                formatCount = .init(ourSupportedFormats.count)
                return XR_SUCCESS
            }
            
            for (i, format) in ourSupportedFormats.enumerated() {
                formats[i] = .init(format.rawValue)
            }
            
            formatCount = .init(ourSupportedFormats.count)
        }
        
        return XR_SUCCESS
    }
    
    func beginSession(info: XrSessionBeginInfo) -> XrResult {
        print("STUB: xrBeginSession(\(self), \(info))")
        return XR_SUCCESS
    }
    
    func syncActions(info: XrActionsSyncInfo) -> XrResult {
        print("STUB: xrSyncActions(\(self), \(info))")
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, float: inout XrActionStateFloat) -> XrResult {
        print("STUB: xrGetActionStateFloat(\(self), \(info), \(float))")
        float.isActive = .init(XR_FALSE)
        float.changedSinceLastSync = .init(XR_FALSE)
        float.currentState = 0
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, pose: inout XrActionStatePose) -> XrResult {
        print("STUB: xrGetActionStatePose(\(self), \(info), \(pose))")
        pose.isActive = .init(XR_FALSE)
        
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, boolean: inout XrActionStateBoolean) -> XrResult {
        print("STUB: xrGetActionStateBoolean(\(self), \(info), \(boolean))")
        boolean.isActive = .init(XR_FALSE)
        boolean.changedSinceLastSync = .init(XR_FALSE)
        boolean.currentState = .init(XR_FALSE)
        return XR_SUCCESS
    }
    
    func waitFrame(waitInfo: XrFrameWaitInfo, frameState: inout XrFrameState) -> XrResult {
        print("STUB: xrWaitFrame(\(self), \(waitInfo), \(frameState))")
        usleep(1_000_000 / 120) // TODO: stub
        frameState.shouldRender = .init(XR_TRUE) // TODO: stub
        return XR_SUCCESS
    }
    
    func beginFrame(frameBeginInfo: XrFrameBeginInfo) -> XrResult {
        print("STUB: xrBeginFrame(\(self), \(frameBeginInfo))")
        return XR_SUCCESS
    }
    
    func endFrame(frameEndInfo: XrFrameEndInfo) -> XrResult {
        print("STUB: xrEndFrame(\(self), \(frameEndInfo))")
        return XR_SUCCESS
    }
    
    func locateViews(locateInfo: XrViewLocateInfo, state: inout XrViewState, views: UnsafeMutableBufferPointer<XrView>, viewCount: inout UInt32) -> XrResult {
        print("STUB: xrLocateViews(\(self), \(locateInfo), \(views), \(viewCount))")
        viewCount = 2
        guard views.count >= viewCount else {
            return XR_SUCCESS
        }

        state.viewStateFlags = XR_VIEW_STATE_POSITION_VALID_BIT | XR_VIEW_STATE_ORIENTATION_VALID_BIT
        
        for i in 0..<Int(viewCount) {
            func convertDegreesToRadians(degree: Float) -> Float {
                return degree * .pi / 180
            }
            views[i].fov = .init(
                angleLeft: convertDegreesToRadians(degree: i == 0 ? -54 : -40),
                angleRight: convertDegreesToRadians(degree: i == 0 ? 40 : 54),
                angleUp: convertDegreesToRadians(degree: 43.98),
                angleDown: convertDegreesToRadians(degree: -54.27)
            )
            views[i].pose.position = .init(x: 0, y: 0, z: 0)
            views[i].pose.orientation = .init(x: 0, y: 0, z: 0, w: 1)
        }
        
        return XR_SUCCESS
    }
}

func xrCreateSession(instance: XrInstance?, createInfo: UnsafePointer<XrSessionCreateInfo>?, sessionPtr: UnsafeMutablePointer<XrSession?>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    
    guard let sessionPtr else {
        return XR_ERROR_RUNTIME_FAILURE
    }
    let session = XRSession.create(instance: instanceObj, createInfo: createInfo!.pointee)
    switch session {
    case .failure(let result):
        return result
    case .success(let session):
        let ptr = Unmanaged.passRetained(session).toOpaque()
        sessionPtr.pointee = OpaquePointer(ptr)

        return XR_SUCCESS
    }
}

func xrDestroySession(session: XrSession?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    autoreleasepool {
        let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeRetainedValue()
        sessionObj.destroy()
    }
    
    return XR_SUCCESS
}

func xrEnumerateReferenceSpaces(session: XrSession?, spaceCapacityInput: UInt32, spaceCountOutput: UnsafeMutablePointer<UInt32>?, spaces: UnsafeMutablePointer<XrReferenceSpaceType>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    return sessionObj.enumerateReferenceSpaces(
        spaces: UnsafeMutableBufferPointer(start: spaces, count: .init(spaceCapacityInput)),
        spaceCount: &spaceCountOutput!.pointee
    )
}

func xrAttachSessionActionSets(session: XrSession?, attachInfo: UnsafePointer<XrSessionActionSetsAttachInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    print("STUB: xrAttachSessionActionSets(\(session), \(attachInfo?.pointee))")
    
    return XR_SUCCESS
}

func xrEnumerateSwapchainFormats(session: XrSession?, formatCapacityInput: UInt32, formatCountOutput: UnsafeMutablePointer<UInt32>?, formats: UnsafeMutablePointer<Int64>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    return sessionObj.enumerateSwapchainFormats(
        formats: UnsafeMutableBufferPointer(start: formats, count: .init(formatCapacityInput)),
        formatCount: &formatCountOutput!.pointee
    )
}

func xrBeginSession(session: XrSession?, beginInfo: UnsafePointer<XrSessionBeginInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    return sessionObj.beginSession(info: beginInfo!.pointee)
}

func xrSyncActions(session: XrSession?, syncInfo: UnsafePointer<XrActionsSyncInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    return sessionObj.syncActions(info: syncInfo!.pointee)
}

func xrGetActionStateFloat(session: XrSession?, getInfo: UnsafePointer<XrActionStateGetInfo>?, state: UnsafeMutablePointer<XrActionStateFloat>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    return sessionObj.getActionState(info: getInfo!.pointee, float: &state!.pointee)
}

func xrGetActionStatePose(session: XrSession?, getInfo: UnsafePointer<XrActionStateGetInfo>?, state: UnsafeMutablePointer<XrActionStatePose>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.getActionState(info: getInfo!.pointee, pose: &state!.pointee)
}

func xrGetActionStateBoolean(session: XrSession?, getInfo: UnsafePointer<XrActionStateGetInfo>?, state: UnsafeMutablePointer<XrActionStateBoolean>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.getActionState(info: getInfo!.pointee, boolean: &state!.pointee)
}

func xrWaitFrame(session: XrSession?, waitInfo: UnsafePointer<XrFrameWaitInfo>?, frameState: UnsafeMutablePointer<XrFrameState>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.waitFrame(waitInfo: waitInfo!.pointee, frameState: &frameState!.pointee)
}

func xrBeginFrame(session: XrSession?, frameBeginInfo: UnsafePointer<XrFrameBeginInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.beginFrame(frameBeginInfo: frameBeginInfo!.pointee)
}

func xrEndFrame(session: XrSession?, frameEndInfo: UnsafePointer<XrFrameEndInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.endFrame(frameEndInfo: frameEndInfo!.pointee)
}

func xrLocateViews(session: XrSession?, locateInfo: UnsafePointer<XrViewLocateInfo>?, viewState: UnsafeMutablePointer<XrViewState>?, viewCapacityInput: UInt32, viewCountOutput: UnsafeMutablePointer<UInt32>?, views: UnsafeMutablePointer<XrView>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
   
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.locateViews(locateInfo: locateInfo!.pointee, state: &viewState!.pointee, views: .init(start: views, count: .init(viewCapacityInput)), viewCount: &viewCountOutput!.pointee)
}


