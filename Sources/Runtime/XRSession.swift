//
//  XRSession.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation
import Metal

class XRSession {
    let port: mach_port_t
    let instance: XRInstance
    let graphicsAPI: GraphicsAPI
    private(set) var destroyed = false
    var currentHeadsetInfo = CurrentHeadsetInfo()
     var sessionStarted = false

    enum GraphicsAPI {
        case metal(commandQueue: MTLCommandQueue)
    }

    init(instance: XRInstance, graphicsAPI: GraphicsAPI, port: mach_port_t) {
        self.instance = instance
        self.graphicsAPI = graphicsAPI
        self.port = port
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
        
        guard let instancePort = instance.port else {
            print("INVALID instance port")
            return .failure(XR_ERROR_RUNTIME_FAILURE)
        }
        
        var port: mach_port_t = .init(MACH_PORT_NULL)
        let result = FI_C_SessionCreate(instancePort.machPort, &port)
        guard result == KERN_SUCCESS else {
            print("FAILED to call SessionCreate \(result)")
            return .failure(XR_ERROR_RUNTIME_FAILURE)
        }
        
        let session = XRSession(instance: instance, graphicsAPI: graphicsAPI, port: port)
        instance.push(event: .stateChanged(session, XR_SESSION_STATE_READY))
        return .success(session)
    }
    
    deinit {
        precondition(destroyed)
    }
    
    func destroy() {
        destroyed = true
    }
    
    func end() -> XrResult {
        print("TODO: end session")
        return XR_SUCCESS
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
        if !sessionStarted {
            sessionStarted = true
            instance.push(event: .stateChanged(self, XR_SESSION_STATE_SYNCHRONIZED))
            instance.push(event: .stateChanged(self, XR_SESSION_STATE_VISIBLE))
            instance.push(event: .stateChanged(self, XR_SESSION_STATE_FOCUSED))
        }
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
    
    func getActionState(info: XrActionStateGetInfo, vector2f: inout XrActionStateVector2f) -> XrResult {
        print("STUB: xrGetActionStateVector2f(\(self), \(info), \(vector2f))")
        vector2f.isActive = .init(XR_FALSE)
        vector2f.changedSinceLastSync = .init(XR_FALSE)
        vector2f.currentState = .init(x: 0, y: 0)
        return XR_SUCCESS
    }
    
    func waitFrame(waitInfo: XrFrameWaitInfo, frameState: inout XrFrameState) -> XrResult {
        print("STUB: xrWaitFrame(\(self), \(waitInfo), \(frameState))")
        frameState.shouldRender = .init(XR_TRUE) // TODO: stub
        return XR_SUCCESS
    }
    
    func beginFrame(frameBeginInfo: XrFrameBeginInfo) -> XrResult {
        print("STUB: xrBeginFrame(\(self), \(frameBeginInfo))")
        return XR_SUCCESS
    }
    
    func endFrame(frameEndInfo: XrFrameEndInfo) -> XrResult {
        print("STUB: xrEndFrame(\(self), \(frameEndInfo))")
        for i in 0..<Int(frameEndInfo.layerCount) {
            guard let layer = frameEndInfo.layers[i] else {
                print("WARNING: layer[\(i)] is null")
                return XR_ERROR_LAYER_INVALID
            }
            switch layer.pointee.type {
            case XR_TYPE_COMPOSITION_LAYER_PROJECTION:
                // TODO: cares about the space
                let res = layer.withMemoryRebound(to: XrCompositionLayerProjection.self, capacity: 1, { projectionLayer in
                    print(projectionLayer.pointee)
                    if projectionLayer.pointee.viewCount != 2 {
                        print("WARNING: viewCount should be two but \(projectionLayer.pointee.viewCount)")
                        return XR_ERROR_LAYER_INVALID
                    }
                    var endInfo = EndFrameInfo()
                    withUnsafeMutableBytes(of: &endInfo.eyes) {
                        $0.withMemoryRebound(to: EndFrameInfoPerEye.self) { eyes in
                            for i in 0..<eyes.count {
                                let swapchain = Unmanaged<XRSwapchain>.fromOpaque(.init(projectionLayer.pointee.views[i].subImage.swapchain)).takeUnretainedValue()
                                eyes[i].swapchain_id = swapchain.remoteId
                            }
                        }
                    }
                    FI_C_EndFrame(port, endInfo)
                    return XR_SUCCESS
                })
                if res != XR_SUCCESS {
                    return res
                }
            default:
                print("WARNING: layer \(layer.pointee.type) is not supported at this time")
                return XR_ERROR_LAYER_INVALID
            }
        }
        return XR_SUCCESS
    }
    
    func locateViews(locateInfo: XrViewLocateInfo, state: inout XrViewState, views: UnsafeMutableBufferPointer<XrView>, viewCount: inout UInt32) -> XrResult {
        // print("STUB: xrLocateViews(\(self), \(locateInfo), \(views), \(viewCount))")
        viewCount = 2
        guard views.count >= viewCount else {
            return XR_ERROR_SIZE_INSUFFICIENT
        }

        state.viewStateFlags = XR_VIEW_STATE_POSITION_VALID_BIT | XR_VIEW_STATE_ORIENTATION_VALID_BIT
        
        FI_C_SessionGetCurrentInfo(port, &currentHeadsetInfo)

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
            let transform = i == 0 ? currentHeadsetInfo.leftEye : currentHeadsetInfo.rightEye
            views[i].pose.position = .init(
                x: transform.position.x,
                y: transform.position.y,
                z: transform.position.z
            )
            views[i].pose.orientation = .init(
                x: transform.orientation.x,
                y: transform.orientation.y,
                z: transform.orientation.z,
                w: transform.orientation.w
            )
        }
        
        return XR_SUCCESS
    }
    
    func applyHapticFeedback(actionInfo: XrHapticActionInfo, feedback: XrHapticBaseHeader) -> XrResult {
        print("STUB: xrApplyHapticFeedback(\(self), \(actionInfo), \(feedback))")
        return XR_SUCCESS
    }
    
    func getCurrentInteractionProfile(topLevelUserPath: XrPath, interactionProfile: inout XrInteractionProfileState) -> XrResult {
        print("STUB: xrGetCurrentInteractionProfile(\(self), \(topLevelUserPath), \(interactionProfile))")
        interactionProfile.interactionProfile = .init(XR_PATH_OCULUS_TOUCH_CONTROLLER)
        return XR_SUCCESS
    }
    
    func getReferenceSpaceBoundsRect(referenceSpaceType: XrReferenceSpaceType, boundsRect: inout XrExtent2Df) -> XrResult {
        print("STUB: xrGetReferenceSpaceBoundsRect(\(self), \(referenceSpaceType), \(boundsRect))")
        boundsRect = .init(width: 0, height: 0)
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

func xrGetActionStateVector2f(session: XrSession?, getInfo: UnsafePointer<XrActionStateGetInfo>?, state: UnsafeMutablePointer<XrActionStateVector2f>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.getActionState(info: getInfo!.pointee, vector2f: &state!.pointee)
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


func xrApplyHapticFeedback(session: XrSession?, actionInfo: UnsafePointer<XrHapticActionInfo>?, feedback: UnsafePointer<XrHapticBaseHeader>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.applyHapticFeedback(actionInfo: actionInfo!.pointee, feedback: feedback!.pointee)
}

func xrEndSession(session: XrSession?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.end()
}

func xrGetCurrentInteractionProfile(session: XrSession?, topLevelUserPath: XrPath, interactionProfile: UnsafeMutablePointer<XrInteractionProfileState>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.getCurrentInteractionProfile(topLevelUserPath: topLevelUserPath, interactionProfile: &interactionProfile!.pointee)
}

func xrGetReferenceSpaceBoundsRect(session: XrSession?, referenceSpaceType: XrReferenceSpaceType, boundsRect: UnsafeMutablePointer<XrExtent2Df>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.getReferenceSpaceBoundsRect(referenceSpaceType: referenceSpaceType, boundsRect: &boundsRect!.pointee)
}

