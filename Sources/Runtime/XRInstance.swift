//
//  XRInstance.swift
//  FruitXR
//
//  Created by user on 2025/03/13.
//

import Foundation
import Metal

private let VALID_SYSTEM_ID: XrSystemId = 1

class XRInstance {
    enum Event {
        case ready(XRSession)
    }
    
    private let device: MTLDevice
    private var destroyed: Bool = false
    private var queuedEvents = [Event]()
//    private let port: CFMessagePort
    
    init() {
        // TODO: We need to ask the server for the which GPU should be used for rendering
        // (btw, since we will only support the Apple Silicon Mac, they will likely have a only one GPU, unless Apple will support dGPU for Mac Pro or eGPU)
        device = MTLCreateSystemDefaultDevice()!
    }
    
    deinit {
        precondition(destroyed)
    }
    
    func destroy() {
        destroyed = true
    }
    
    func getInstance(properties: inout XrInstanceProperties) -> XrResult {
        properties.runtimeVersion = 1
        setToCString(&properties, key: \.runtimeName, "FruitXR")
//        propeties.runtimeName = "FruitXR"
        return XR_SUCCESS
    }
    
    func getSystem(systemInfo: XrSystemGetInfo, systemId: inout XrSystemId) -> XrResult {
        guard systemInfo.formFactor == XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY else {
            return XR_ERROR_FORM_FACTOR_UNAVAILABLE
        }
        
        systemId = VALID_SYSTEM_ID
        return XR_SUCCESS
    }
    
    func enumerateEnvironmentBlendModes(
        systemId: XrSystemId,
        viewConfigurationType: XrViewConfigurationType,
        environmentBlendModes: UnsafeMutableBufferPointer<XrEnvironmentBlendMode>,
        environmentBlendModeCount: inout UInt32
    ) -> XrResult {
        guard viewConfigurationType == XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO else {
            return XR_ERROR_VIEW_CONFIGURATION_TYPE_UNSUPPORTED
        }
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        
        if environmentBlendModes.count < 1 {
            environmentBlendModeCount = 1
            return XR_SUCCESS
        }
        
        // TODO: We might be need to support alpha blend or something to passthrough real world? i'm not sure
        environmentBlendModes[0] = XR_ENVIRONMENT_BLEND_MODE_OPAQUE
        environmentBlendModeCount = 1
        
        return XR_SUCCESS
    }
     
    func enumerateViewConfigurations(
        systemId: XrSystemId,
        viewConfigurationTypes: UnsafeMutableBufferPointer<XrViewConfigurationType>,
        viewConfigurationTypeCount: inout UInt32
    ) -> XrResult {
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        
        if viewConfigurationTypes.count < 1 {
            viewConfigurationTypeCount = 1
            return XR_SUCCESS
        }
        
        viewConfigurationTypes[0] = XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO
        viewConfigurationTypeCount = 1
        
        return XR_SUCCESS
    }
    
    func getViewConfigurationProperties(
        systemId: XrSystemId,
        viewConfigurationType: XrViewConfigurationType,
        viewConfigurationProperties: inout XrViewConfigurationProperties
    ) -> XrResult {
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        guard viewConfigurationType == XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO else {
            return XR_ERROR_VIEW_CONFIGURATION_TYPE_UNSUPPORTED
        }
        
        viewConfigurationProperties.fovMutable = .init(XR_FALSE)
        viewConfigurationProperties.viewConfigurationType = viewConfigurationType
        
        return XR_SUCCESS
    }
    
    func enumerateViewConfigurationViews(
        systemId: XrSystemId,
        viewConfigurationType: XrViewConfigurationType,
        views: UnsafeMutableBufferPointer<XrViewConfigurationView>,
        viewCount: inout UInt32
    ) -> XrResult {
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        guard viewConfigurationType == XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO else {
            return XR_ERROR_VIEW_CONFIGURATION_TYPE_UNSUPPORTED
        }
        
        if views.count < 2 {
            viewCount = 2
            return XR_SUCCESS
        }
        
        // TODO: STUB, we need to get real view properties from the server
        for i in 0..<2 {
            views[i].recommendedImageRectWidth = 2064
            views[i].recommendedImageRectHeight = 2240
            views[i].maxImageRectWidth = 2064
            views[i].maxImageRectHeight = 2240
            views[i].recommendedSwapchainSampleCount = 1
            views[i].maxSwapchainSampleCount = 1
        }
        
        viewCount = 2
        
        return XR_SUCCESS
    }
    
    func getMetalGraphicsRequirements(systemId: XrSystemId, metalRequirements: inout XrGraphicsRequirementsMetalKHR) -> XrResult {
        print("called")
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        
        metalRequirements.metalDevice = Unmanaged.passUnretained(device).toOpaque()
        
        return XR_SUCCESS
    }
    
    func suggestInteractionProfileBindings(suggestedBindings: XrInteractionProfileSuggestedBinding) -> XrResult {
        print("STUB: suggestInteractionProfileBindings(\(suggestedBindings))")
        return XR_SUCCESS
    }
    
    func getSystemProperties(systemId: XrSystemId, properties: inout XrSystemProperties) -> XrResult {
        guard systemId == VALID_SYSTEM_ID else {
            return XR_ERROR_SYSTEM_INVALID
        }
        
        properties.systemId = systemId
        setToCString(&properties, key: \.systemName, "FruitXR HMD")
        properties.vendorId = 0
        properties.graphicsProperties.maxLayerCount = 1
        properties.graphicsProperties.maxSwapchainImageHeight = 1024
        properties.graphicsProperties.maxSwapchainImageWidth = 1024
        properties.trackingProperties.orientationTracking = .init(XR_FALSE)
        properties.trackingProperties.positionTracking = .init(XR_FALSE)
        
        return XR_SUCCESS
    }

    func pollEvent(event: UnsafeMutablePointer<XrEventDataBuffer>) -> XrResult {
        guard queuedEvents.count > 0 else {
            return XR_EVENT_UNAVAILABLE
        }
        let ourEvent = queuedEvents.removeFirst()
        switch ourEvent {
        case .ready(let session):
            event.withMemoryRebound(to: XrEventDataSessionStateChanged.self, capacity: 1) { pointer in
                pointer.pointee.type = XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED
                pointer.pointee.next = nil
                pointer.pointee.session = .init(Unmanaged.passUnretained(session).toOpaque())
                pointer.pointee.state = XR_SESSION_STATE_READY
                pointer.pointee.time = 0
            }
        }
        
        return XR_SUCCESS
    }
    
    func push(event: Event) {
        queuedEvents.append(event)
    }
}

func xrCreateInstance(
    createInfo: UnsafePointer<XrInstanceCreateInfo>?,
    createdInstance: UnsafeMutablePointer<XrInstance?>?
) -> XrResult {
    guard let createdInstance else {
        return XR_ERROR_RUNTIME_FAILURE
    }
    let instance = XRInstance()
    let ptr = Unmanaged.passRetained(instance).toOpaque()
    createdInstance.pointee = OpaquePointer(ptr)

    return XR_SUCCESS
}

func xrDestroyInstance(instance: XrInstance?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    autoreleasepool {
        let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
        instanceObj.destroy()
    }
    Unmanaged<XRInstance>.fromOpaque(.init(instance)).release()
    return XR_SUCCESS
}

func xrGetInstanceProperties(
    instance: XrInstance?,
    properties: UnsafeMutablePointer<XrInstanceProperties>?
)-> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.getInstance(properties: &properties!.pointee)
}

func xrGetSystem(
    instance: XrInstance?,
    systemInfo: UnsafePointer<XrSystemGetInfo>?,
    systemId: UnsafeMutablePointer<XrSystemId>?
) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.getSystem(systemInfo: systemInfo!.pointee, systemId: &systemId!.pointee)
}

func xrEnumerateEnvironmentBlendModes(
    instance: XrInstance?,
    systemId: XrSystemId,
    viewConfigurationType: XrViewConfigurationType,
    environmentBlendModeCapacityInput: UInt32,
    environmentBlendModeCountOutput: UnsafeMutablePointer<UInt32>?,
    environmentBlendModes: UnsafeMutablePointer<XrEnvironmentBlendMode>?
) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.enumerateEnvironmentBlendModes(
        systemId: systemId,
        viewConfigurationType: viewConfigurationType,
        environmentBlendModes: UnsafeMutableBufferPointer(start: environmentBlendModes, count: .init(environmentBlendModeCapacityInput)),
        environmentBlendModeCount: &environmentBlendModeCountOutput!.pointee
    )
}

func xrEnumerateViewConfigurations(
    instance: XrInstance?,
    systemId: XrSystemId,
    viewConfigurationTypeCapacityInput: UInt32,
    viewConfigurationTypeCountOutput: UnsafeMutablePointer<UInt32>?,
    viewConfigurationTypes: UnsafeMutablePointer<XrViewConfigurationType>?
) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.enumerateViewConfigurations(
        systemId: systemId,
        viewConfigurationTypes: UnsafeMutableBufferPointer(start: viewConfigurationTypes, count: .init(viewConfigurationTypeCapacityInput)),
        viewConfigurationTypeCount: &viewConfigurationTypeCountOutput!.pointee
    )
}

func xrGetViewConfigurationProperties(
    instance: XrInstance?,
    systemId: XrSystemId,
    viewConfigurationType: XrViewConfigurationType,
    viewConfigurationProperties: UnsafeMutablePointer<XrViewConfigurationProperties>?
) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.getViewConfigurationProperties(
        systemId: systemId,
        viewConfigurationType: viewConfigurationType,
        viewConfigurationProperties: &viewConfigurationProperties!.pointee
    )
}

func xrEnumerateViewConfigurationViews(
    instance: XrInstance?,
    systemId: XrSystemId,
    viewConfigurationType: XrViewConfigurationType,
    viewCapacityInput: UInt32,
    viewCountOutput: UnsafeMutablePointer<UInt32>?,
    views: UnsafeMutablePointer<XrViewConfigurationView>?
) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    return instanceObj.enumerateViewConfigurationViews(
        systemId: systemId,
        viewConfigurationType: viewConfigurationType,
        views: UnsafeMutableBufferPointer(start: views, count: .init(viewCapacityInput)),
        viewCount: &viewCountOutput!.pointee
    )
}

func xrGetMetalGraphicsRequirementsKHR(instance: XrInstance?, systemId: XrSystemId, metalRequirements: UnsafeMutablePointer<XrGraphicsRequirementsMetalKHR>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    return instanceObj.getMetalGraphicsRequirements(systemId: systemId, metalRequirements: &metalRequirements!.pointee)
}

func xrSuggestInteractionProfileBindings(instance: XrInstance?, suggestedBindings: UnsafePointer<XrInteractionProfileSuggestedBinding>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    return instanceObj.suggestInteractionProfileBindings(suggestedBindings: suggestedBindings!.pointee)
}

func xrGetSystemProperties(instance: XrInstance?, systemId: XrSystemId, properties: UnsafeMutablePointer<XrSystemProperties>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }

    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    return instanceObj.getSystemProperties(systemId: systemId, properties: &properties!.pointee)
}

func xrPollEvent(instance: XrInstance?, event: UnsafeMutablePointer<XrEventDataBuffer>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    return instanceObj.pollEvent(event: &event!.pointee)
}

func xrResultToString(instance: XrInstance?, result: XrResult, resultString: UnsafeMutablePointer<CChar>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    guard let resultString else {
        preconditionFailure()
    }
    
    print("STUB: xrResultToString(\(instanceObj), \(result))")
    
    return XR_SUCCESS
}
