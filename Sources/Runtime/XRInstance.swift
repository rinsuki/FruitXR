//
//  XRInstance.swift
//  FruitXR
//
//  Created by user on 2025/03/13.
//

import Foundation
import Metal

private let VALID_SYSTEM_ID: XrSystemId = 1

/// Represents a single suggested binding from the application: an action bound to a specific input/output path.
struct SuggestedBinding {
    let action: XRAction
    /// The full binding path, e.g. /user/hand/left/input/trigger/value
    let bindingPath: String
}

/// Stores the set of valid component paths for a known interaction profile.
struct InteractionProfileDefinition {
    /// Valid component subpaths for /user/hand/left (e.g. "input/trigger/value")
    let leftHandComponents: Set<String>
    /// Valid component subpaths for /user/hand/right (e.g. "input/trigger/value")
    let rightHandComponents: Set<String>
}

/// The Oculus Touch controller profile component paths
let oculusTouchProfile: InteractionProfileDefinition = {
    let bothHands: Set<String> = [
        "input/squeeze/value",
        "input/trigger/value",
        "input/trigger/touch",
        "input/thumbstick",
        "input/thumbstick/x",
        "input/thumbstick/y",
        "input/thumbstick/click",
        "input/thumbstick/touch",
        "input/thumbrest/touch",
        "input/grip/pose",
        "input/aim/pose",
        "output/haptic",
    ]
    
    let leftOnly: Set<String> = [
        "input/x/click",
        "input/x/touch",
        "input/y/click",
        "input/y/touch",
        "input/menu/click",
    ]
    
    let rightOnly: Set<String> = [
        "input/a/click",
        "input/a/touch",
        "input/b/click",
        "input/b/touch",
        "input/system/click",
    ]
    
    return InteractionProfileDefinition(
        leftHandComponents: bothHands.union(leftOnly),
        rightHandComponents: bothHands.union(rightOnly)
    )
}()

/// Known interaction profiles and their definitions
let knownInteractionProfiles: [String: InteractionProfileDefinition] = [
    "/interaction_profiles/oculus/touch_controller": oculusTouchProfile,
]

let mtlDevice = MTLCreateSystemDefaultDevice()

class XRInstance {
    enum Event {
        case stateChanged(XRSession, XrSessionState)
        case interactionProfileChanged(XRSession)
    } 

    var port: NSMachPort?
    
    private let device: MTLDevice
    private var destroyed: Bool = false
    private var queuedEvents = [Event]()
    
    /// Suggested bindings per interaction profile path (String -> [SuggestedBinding])
    /// Set by xrSuggestInteractionProfileBindings, used during xrAttachSessionActionSets to resolve bindings.
    var suggestedBindings: [String: [SuggestedBinding]] = [:]
    
    /// Whether any session has attached action sets (prevents further xrSuggestInteractionProfileBindings calls)
    var actionSetsAttached = false
    
    init() throws(XRError) {
        guard let machServer = FXMachBootstrapServer.sharedInstance() as? FXMachBootstrapServer else {
            throw XRError(result: XR_ERROR_INITIALIZATION_FAILED)
        }
        guard let serverPort = machServer.port(forName: "net.rinsuki.apps.FruitXR.IPC") as? NSMachPort else {
            throw XRError(result: XR_ERROR_INITIALIZATION_FAILED)
        }
        var port: mach_port_t = 0
        let res = FI_C_InstanceCreate(serverPort.machPort, &port)
        guard res == KERN_SUCCESS, port != 0 else {
            print("ERR: failed to call InstanceCreate: \(res)")
            throw XRError(result: XR_ERROR_INITIALIZATION_FAILED)
        }
        self.port = .init(machPort: port, options: [.deallocateSendRight, .deallocateReceiveRight])
        // TODO: We need to ask the server for the which GPU should be used for rendering
        // (btw, since we will only support the Apple Silicon Mac, they will likely have a only one GPU, unless Apple will support dGPU for Mac Pro or eGPU)
        guard let device = mtlDevice else {
            print("ERR: GPU not found")
            throw XRError(result: XR_ERROR_INITIALIZATION_FAILED)
        }
        self.device = device
    }
    
    deinit {
        precondition(destroyed)
        destroyed = false
    }
    
    func destroy() {
        self.port = nil
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
            views[i].recommendedImageRectHeight = 2208
            views[i].maxImageRectWidth = 2064
            views[i].maxImageRectHeight = 2208
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
        // Cannot call after action sets have been attached
        if actionSetsAttached {
            return XR_ERROR_ACTIONSETS_ALREADY_ATTACHED
        }
        
        let profilePath = xrRegisteredPaths[Int(suggestedBindings.interactionProfile)]
        
        // Validate that the interaction profile is known
        guard let profileDef = knownInteractionProfiles[profilePath] else {
            print("xrSuggestInteractionProfileBindings: unknown interaction profile \(profilePath)")
//            return XR_ERROR_PATH_UNSUPPORTED
            return XR_SUCCESS
        }
        
        var bindings: [SuggestedBinding] = []
        
        for i in 0..<Int(suggestedBindings.countSuggestedBindings) {
            let binding = suggestedBindings.suggestedBindings[i]
            let action = Unmanaged<XRAction>.fromOpaque(.init(binding.action)).takeUnretainedValue()
            let bindingPathStr = xrRegisteredPaths[Int(binding.binding)]
            
            // Validate binding path: must start with a valid top-level user path for this profile
            // and the component subpath must be valid for that hand
            var valid = false
            if bindingPathStr.hasPrefix("/user/hand/left/") {
                let component = String(bindingPathStr.dropFirst("/user/hand/left/".count))
                valid = profileDef.leftHandComponents.contains(component)
            } else if bindingPathStr.hasPrefix("/user/hand/right/") {
                let component = String(bindingPathStr.dropFirst("/user/hand/right/".count))
                valid = profileDef.rightHandComponents.contains(component)
            }
            
            if !valid {
                print("xrSuggestInteractionProfileBindings: unsupported binding path \(bindingPathStr) for profile \(profilePath)")
                return XR_ERROR_PATH_UNSUPPORTED
            }
            
            bindings.append(SuggestedBinding(action: action, bindingPath: bindingPathStr))
        }
        
        // Replace any previous bindings for this profile
        self.suggestedBindings[profilePath] = bindings
        print("xrSuggestInteractionProfileBindings: stored \(bindings.count) bindings for \(profilePath)")
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
        case .stateChanged(let session, let state):
            event.withMemoryRebound(to: XrEventDataSessionStateChanged.self, capacity: 1) { pointer in
                pointer.pointee.type = XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED
                pointer.pointee.next = nil
                pointer.pointee.session = .init(Unmanaged.passUnretained(session).toOpaque())
                pointer.pointee.state = state
                pointer.pointee.time = 0
            }
        case .interactionProfileChanged(let session):
            event.withMemoryRebound(to: XrEventDataInteractionProfileChanged.self, capacity: 1) { pointer in
                pointer.pointee.type = XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED
                pointer.pointee.next = nil
                pointer.pointee.session = .init(Unmanaged.passUnretained(session).toOpaque())
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
    do {
        let instance = try XRInstance()
        let ptr = Unmanaged.passRetained(instance).toOpaque()
        createdInstance.pointee = OpaquePointer(ptr)
    } catch {
        return error.result
    }

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
