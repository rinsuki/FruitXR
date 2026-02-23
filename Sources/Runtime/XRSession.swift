//
//  XRSession.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation
import Metal

/// Represents a resolved binding: maps an action + top-level user path to a specific component path on a controller.
struct ResolvedBinding {
    let action: XRAction
    /// The top-level user path this binding is for (e.g. XR_PATH_USER_HAND_LEFT)
    let topLevelUserPath: XrPath
    /// The component subpath (e.g. "input/trigger/value", "input/thumbstick", "input/grip/pose")
    let componentPath: String
}

/// Cached action state for a single action + subaction path combination
struct CachedActionState {
    var isActive: Bool = false
    var booleanValue: Bool = false
    var floatValue: Float = 0
    var vector2fValue: XrVector2f = .init(x: 0, y: 0)
    var changedSinceLastSync: Bool = false
    var lastChangeTime: XrTime = 0
}

/// Key for looking up cached action states
struct ActionStateKey: Hashable {
    let actionPtr: UnsafeMutableRawPointer
    let subactionPath: XrPath
    
    init(action: XRAction, subactionPath: XrPath) {
        self.actionPtr = Unmanaged.passUnretained(action).toOpaque()
        self.subactionPath = subactionPath
    }
}

class XRSession {
    let port: mach_port_t
    let instance: XRInstance
    let graphicsAPI: GraphicsAPI
    private(set) var destroyed = false
    var currentHeadsetInfo = IPCCurrentHeadsetInfo()
    var sessionStarted = false

    enum GraphicsAPI {
        case metal(commandQueue: MTLCommandQueue)
    }
    
    // --- Action system state ---
    
    /// The action sets attached to this session (set once by xrAttachSessionActionSets)
    var attachedActionSets: [XRActionSet]?
    
    /// The resolved bindings, computed when action sets are attached.
    /// Maps interaction profile path -> [ResolvedBinding]
    var resolvedBindings: [String: [ResolvedBinding]] = [:]
    
    /// Current interaction profile for each top-level user path.
    /// nil means no profile is active (XR_NULL_PATH will be returned).
    var currentInteractionProfiles: [XrPath: String] = [:]
    
    /// Cached action states, updated during xrSyncActions
    var cachedActionStates: [ActionStateKey: CachedActionState] = [:]
    
    /// Previous action states for changedSinceLastSync computation
    var previousActionStates: [ActionStateKey: CachedActionState] = [:]
    
    /// The set of active action sets from the last xrSyncActions call (action set + subaction path pairs)
    var activeActionSets: [(actionSet: XRActionSet, subactionPath: XrPath)] = []

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
            commandQueue.label = (commandQueue.label ?? "") + " (Attached to FruitXR XrSession \(self))"
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
        let ourSupportedSpaces = XRReferenceSpace.supportedTypes
        
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
                MTLPixelFormat.depth32Float,
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
        guard let attachedActionSets else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        
        // Validate all active action sets are attached
        var newActiveActionSets: [(actionSet: XRActionSet, subactionPath: XrPath)] = []
        for i in 0..<Int(info.countActiveActionSets) {
            let activeSet = info.activeActionSets[i]
            let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(activeSet.actionSet)).takeUnretainedValue()
            
            guard attachedActionSets.contains(where: { $0 === actionSetObj }) else {
                return XR_ERROR_ACTIONSET_NOT_ATTACHED
            }
            
            newActiveActionSets.append((actionSet: actionSetObj, subactionPath: activeSet.subactionPath))
        }
        self.activeActionSets = newActiveActionSets
        
        // Get current hardware state
        FI_C_SessionGetCurrentInfo(port, &currentHeadsetInfo)
        
        // Save previous states for changedSinceLastSync computation
        previousActionStates = cachedActionStates
        cachedActionStates = [:]
        
        // For each active action set, evaluate all actions
        for activeEntry in activeActionSets {
            let actionSet = activeEntry.actionSet
            let filterSubactionPath = activeEntry.subactionPath
            
            for action in actionSet.actions {
                // Determine which subaction paths to evaluate
                let subactionPathsToEvaluate: [XrPath]
                if action.subactionPaths.isEmpty {
                    // Action has no subaction paths — evaluate with XR_NULL_PATH
                    subactionPathsToEvaluate = [.init(XR_NULL_PATH)]
                } else if filterSubactionPath == XR_NULL_PATH {
                    // Wildcard — evaluate all subaction paths
                    subactionPathsToEvaluate = action.subactionPaths
                } else if action.subactionPaths.contains(filterSubactionPath) {
                    subactionPathsToEvaluate = [filterSubactionPath]
                } else {
                    // The subaction path filter doesn't apply to this action
                    continue
                }
                
                for subactionPath in subactionPathsToEvaluate {
                    let key = ActionStateKey(action: action, subactionPath: subactionPath)
                    
                    // Skip if already evaluated (duplicate active action set entries)
                    if cachedActionStates[key] != nil {
                        continue
                    }
                    
                    let state = evaluateActionState(action: action, subactionPath: subactionPath)
                    
                    // Compute changedSinceLastSync
                    var finalState = state
                    if let prev = previousActionStates[key], prev.isActive {
                        switch action.actionType {
                        case XR_ACTION_TYPE_BOOLEAN_INPUT:
                            finalState.changedSinceLastSync = state.booleanValue != prev.booleanValue
                        case XR_ACTION_TYPE_FLOAT_INPUT:
                            finalState.changedSinceLastSync = state.floatValue != prev.floatValue
                        case XR_ACTION_TYPE_VECTOR2F_INPUT:
                            finalState.changedSinceLastSync = state.vector2fValue.x != prev.vector2fValue.x || state.vector2fValue.y != prev.vector2fValue.y
                        default:
                            finalState.changedSinceLastSync = false
                        }
                    } else {
                        // No previous state or was inactive — changedSinceLastSync must be false
                        finalState.changedSinceLastSync = false
                    }
                    
                    cachedActionStates[key] = finalState
                }
            }
        }
        
        return XR_SUCCESS
    }
    
    /// Evaluate the current state of an action for a specific subaction path by inspecting resolved bindings and hardware state.
    private func evaluateActionState(action: XRAction, subactionPath: XrPath) -> CachedActionState {
        var state = CachedActionState()
        
        // Find resolved bindings that match this action + subaction path
        let matchingBindings = findMatchingBindings(action: action, subactionPath: subactionPath)
        
        if matchingBindings.isEmpty {
            // No binding — inactive
            return state
        }
        
        state.isActive = true
        
        switch action.actionType {
        case XR_ACTION_TYPE_BOOLEAN_INPUT:
            // OR of all bound boolean inputs
            var result = false
            for binding in matchingBindings {
                let value = readBooleanInput(binding: binding)
                result = result || value
            }
            state.booleanValue = result
            
        case XR_ACTION_TYPE_FLOAT_INPUT:
            // Largest absolute value
            var result: Float = 0
            for binding in matchingBindings {
                let value = readFloatInput(binding: binding)
                if abs(value) > abs(result) {
                    result = value
                }
            }
            state.floatValue = result
            
        case XR_ACTION_TYPE_VECTOR2F_INPUT:
            // Longest length
            var result = XrVector2f(x: 0, y: 0)
            var bestLength: Float = 0
            for binding in matchingBindings {
                let value = readVector2fInput(binding: binding)
                let length = sqrt(value.x * value.x + value.y * value.y)
                if length > bestLength {
                    bestLength = length
                    result = value
                }
            }
            state.vector2fValue = result
            
        case XR_ACTION_TYPE_POSE_INPUT:
            state.isActive = true
            
        case XR_ACTION_TYPE_VIBRATION_OUTPUT:
            state.isActive = true
            
        default:
            break
        }
        
        return state
    }
    
    /// Find all resolved bindings matching an action and subaction path
    private func findMatchingBindings(action: XRAction, subactionPath: XrPath) -> [ResolvedBinding] {
        var result: [ResolvedBinding] = []
        
        for (profilePath, bindings) in resolvedBindings {
            // Only consider bindings for profiles that are currently active
            let isActive = currentInteractionProfiles.values.contains(profilePath)
            guard isActive else { continue }
            
            for binding in bindings {
                guard binding.action === action else { continue }
                
                // Check subaction path filter
                if subactionPath != XR_NULL_PATH {
                    guard binding.topLevelUserPath == subactionPath else { continue }
                }
                
                result.append(binding)
            }
        }
        
        return result
    }
    
    /// Read a boolean value from the hardware for this binding
    private func readBooleanInput(binding: ResolvedBinding) -> Bool {
        let controller = controllerForPath(binding.topLevelUserPath)
        
        switch binding.componentPath {
        // Click/touch inputs
        case "input/x/click", "input/a/click":
            return (controller.buttons & UInt32(HC_BUTTON_PRIMARY_CLICK)) != 0
        case "input/x/touch", "input/a/touch":
            return (controller.buttons & UInt32(HC_BUTTON_PRIMARY_TOUCH)) != 0
        case "input/y/click", "input/b/click":
            return (controller.buttons & UInt32(HC_BUTTON_SECONDARY_CLICK)) != 0
        case "input/y/touch", "input/b/touch":
            return (controller.buttons & UInt32(HC_BUTTON_SECONDARY_TOUCH)) != 0
        case "input/menu/click":
            // Use primary click for menu on left hand (same button mapping)
            return (controller.buttons & UInt32(HC_BUTTON_PRIMARY_CLICK)) != 0
        case "input/system/click":
            return (controller.buttons & UInt32(HC_BUTTON_SYSTEM_CLICK)) != 0
        case "input/thumbstick/click":
            return (controller.buttons & UInt32(HC_BUTTON_STICK_CLICK)) != 0
        case "input/thumbstick/touch":
            return (controller.buttons & UInt32(HC_BUTTON_STICK_TOUCH)) != 0
        case "input/thumbrest/touch":
            return (controller.buttons & UInt32(HC_BUTTON_THUMBREST_TOUCH)) != 0
        case "input/trigger/touch":
            // Treat trigger > 0 as touched
            return controller.trigger > 0
        case "input/trigger/value":
            // Float-to-boolean conversion: apply threshold
            return controller.trigger > 0.5
        case "input/squeeze/value":
            return controller.squeeze > 0.5
        default:
            return false
        }
    }
    
    /// Read a float value from the hardware for this binding
    private func readFloatInput(binding: ResolvedBinding) -> Float {
        let controller = controllerForPath(binding.topLevelUserPath)
        
        switch binding.componentPath {
        case "input/trigger/value":
            return controller.trigger
        case "input/squeeze/value":
            return controller.squeeze
        case "input/thumbstick/x":
            return controller.thumbstick_x
        case "input/thumbstick/y":
            return -controller.thumbstick_y
        // Boolean-to-float conversion
        case "input/x/click", "input/a/click":
            return (controller.buttons & UInt32(HC_BUTTON_PRIMARY_CLICK)) != 0 ? 1.0 : 0.0
        case "input/y/click", "input/b/click":
            return (controller.buttons & UInt32(HC_BUTTON_SECONDARY_CLICK)) != 0 ? 1.0 : 0.0
        case "input/thumbstick/click":
            return (controller.buttons & UInt32(HC_BUTTON_STICK_CLICK)) != 0 ? 1.0 : 0.0
        case "input/menu/click":
            return (controller.buttons & UInt32(HC_BUTTON_PRIMARY_CLICK)) != 0 ? 1.0 : 0.0
        case "input/system/click":
            return (controller.buttons & UInt32(HC_BUTTON_SYSTEM_CLICK)) != 0 ? 1.0 : 0.0
        default:
            return 0
        }
    }
    
    /// Read a vector2f value from the hardware for this binding
    private func readVector2fInput(binding: ResolvedBinding) -> XrVector2f {
        let controller = controllerForPath(binding.topLevelUserPath)
        
        switch binding.componentPath {
        case "input/thumbstick":
            return .init(x: controller.thumbstick_x, y: -controller.thumbstick_y)
        default:
            return .init(x: 0, y: 0)
        }
    }
    
    /// Get the IPCHandController for a top-level user path
    private func controllerForPath(_ path: XrPath) -> IPCHandController {
        switch path {
        case XR_PATH_USER_HAND_LEFT:
            return currentHeadsetInfo.leftController
        case XR_PATH_USER_HAND_RIGHT:
            return currentHeadsetInfo.rightController
        default:
            return IPCHandController()
        }
    }
    
    // --- Attach action sets and resolve bindings ---
    
    func attachActionSets(actionSets: [XRActionSet]) -> XrResult {
        guard attachedActionSets == nil else {
            return XR_ERROR_ACTIONSETS_ALREADY_ATTACHED
        }
        
        attachedActionSets = actionSets
        instance.actionSetsAttached = true
        
        // Mark each action set as attached
        for actionSet in actionSets {
            actionSet.markAttached()
        }
        
        // Resolve bindings: for each interaction profile that the app provided bindings for,
        // create resolved bindings that map actions to specific inputs/outputs.
        for (profilePath, suggestedBindings) in instance.suggestedBindings {
            var resolved: [ResolvedBinding] = []
            
            for suggested in suggestedBindings {
                // Only consider bindings for actions in attached action sets
                guard actionSets.contains(where: { $0 === suggested.action.actionSet }) else { continue }
                
                // Parse the binding path to extract top-level user path and component path
                let bindingPath = suggested.bindingPath
                
                var topLevelUserPath: XrPath = .init(XR_NULL_PATH)
                var componentPath: String = ""
                
                if bindingPath.hasPrefix("/user/hand/left/") {
                    topLevelUserPath = XR_PATH_USER_HAND_LEFT
                    componentPath = String(bindingPath.dropFirst("/user/hand/left/".count))
                } else if bindingPath.hasPrefix("/user/hand/right/") {
                    topLevelUserPath = XR_PATH_USER_HAND_RIGHT
                    componentPath = String(bindingPath.dropFirst("/user/hand/right/".count))
                }
                
                guard topLevelUserPath != XR_NULL_PATH else { continue }
                
                resolved.append(ResolvedBinding(action: suggested.action, topLevelUserPath: topLevelUserPath, componentPath: componentPath))
            }
            
            resolvedBindings[profilePath] = resolved
        }
        
        // Set initial interaction profiles. Since we always emulate Oculus Touch:
        let oculusTouchPath = "/interaction_profiles/oculus/touch_controller"
        if instance.suggestedBindings[oculusTouchPath] != nil {
            currentInteractionProfiles[XR_PATH_USER_HAND_LEFT] = oculusTouchPath
            currentInteractionProfiles[XR_PATH_USER_HAND_RIGHT] = oculusTouchPath
            // Queue interaction profile changed event
            instance.push(event: .interactionProfileChanged(self))
        }
        
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, float: inout XrActionStateFloat) -> XrResult {
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(info.action)).takeUnretainedValue()
        
        guard attachedActionSets != nil, attachedActionSets!.contains(where: { $0 === actionObj.actionSet }) else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        guard actionObj.actionType == XR_ACTION_TYPE_FLOAT_INPUT else {
            return XR_ERROR_ACTION_TYPE_MISMATCH
        }
        
        let subactionPath = info.subactionPath
        if let res = validateSubactionPath(action: actionObj, subactionPath: subactionPath) {
            return res
        }
        
        let key = ActionStateKey(action: actionObj, subactionPath: subactionPath)
        if let cached = cachedActionStates[key] {
            float.isActive = .init(cached.isActive ? XR_TRUE : XR_FALSE)
            float.currentState = cached.floatValue
            float.changedSinceLastSync = .init(cached.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            float.lastChangeTime = cached.lastChangeTime
        } else if subactionPath == XR_NULL_PATH, !actionObj.subactionPaths.isEmpty {
            // Aggregate: if querying with XR_NULL_PATH and action has subaction paths, pick largest absolute value
            var bestState = CachedActionState()
            for sp in actionObj.subactionPaths {
                let spKey = ActionStateKey(action: actionObj, subactionPath: sp)
                if let cached = cachedActionStates[spKey] {
                    if cached.isActive {
                        bestState.isActive = true
                        if abs(cached.floatValue) > abs(bestState.floatValue) {
                            bestState.floatValue = cached.floatValue
                        }
                        bestState.changedSinceLastSync = bestState.changedSinceLastSync || cached.changedSinceLastSync
                    }
                }
            }
            float.isActive = .init(bestState.isActive ? XR_TRUE : XR_FALSE)
            float.currentState = bestState.floatValue
            float.changedSinceLastSync = .init(bestState.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            float.lastChangeTime = bestState.lastChangeTime
        } else {
            float.isActive = .init(XR_FALSE)
            float.currentState = 0
            float.changedSinceLastSync = .init(XR_FALSE)
            float.lastChangeTime = 0
        }
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, pose: inout XrActionStatePose) -> XrResult { 
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(info.action)).takeUnretainedValue()
        
        guard attachedActionSets != nil, attachedActionSets!.contains(where: { $0 === actionObj.actionSet }) else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        guard actionObj.actionType == XR_ACTION_TYPE_POSE_INPUT else {
            return XR_ERROR_ACTION_TYPE_MISMATCH
        }
        
        let subactionPath = info.subactionPath
        if let res = validateSubactionPath(action: actionObj, subactionPath: subactionPath) {
            return res
        }
        
        let key = ActionStateKey(action: actionObj, subactionPath: subactionPath)
        if let cached = cachedActionStates[key] {
            pose.isActive = .init(cached.isActive ? XR_TRUE : XR_FALSE)
        } else if subactionPath == XR_NULL_PATH, !actionObj.subactionPaths.isEmpty {
            // Aggregate: active if any subaction path is active
            var active = false
            for sp in actionObj.subactionPaths {
                let spKey = ActionStateKey(action: actionObj, subactionPath: sp)
                if let cached = cachedActionStates[spKey], cached.isActive {
                    active = true
                    break
                }
            }
            pose.isActive = .init(active ? XR_TRUE : XR_FALSE)
        } else {
            pose.isActive = .init(XR_FALSE)
        }
        
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, boolean: inout XrActionStateBoolean) -> XrResult {
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(info.action)).takeUnretainedValue()
        
        guard attachedActionSets != nil, attachedActionSets!.contains(where: { $0 === actionObj.actionSet }) else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        guard actionObj.actionType == XR_ACTION_TYPE_BOOLEAN_INPUT else {
            return XR_ERROR_ACTION_TYPE_MISMATCH
        }
        
        let subactionPath = info.subactionPath
        if let res = validateSubactionPath(action: actionObj, subactionPath: subactionPath) {
            return res
        }
        
        let key = ActionStateKey(action: actionObj, subactionPath: subactionPath)
        if let cached = cachedActionStates[key] {
            boolean.isActive = .init(cached.isActive ? XR_TRUE : XR_FALSE)
            boolean.currentState = .init(cached.booleanValue ? XR_TRUE : XR_FALSE)
            boolean.changedSinceLastSync = .init(cached.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            boolean.lastChangeTime = cached.lastChangeTime
        } else if subactionPath == XR_NULL_PATH, !actionObj.subactionPaths.isEmpty {
            // Aggregate: OR of all subaction paths
            var bestState = CachedActionState()
            for sp in actionObj.subactionPaths {
                let spKey = ActionStateKey(action: actionObj, subactionPath: sp)
                if let cached = cachedActionStates[spKey] {
                    if cached.isActive {
                        bestState.isActive = true
                        bestState.booleanValue = bestState.booleanValue || cached.booleanValue
                        bestState.changedSinceLastSync = bestState.changedSinceLastSync || cached.changedSinceLastSync
                    }
                }
            }
            boolean.isActive = .init(bestState.isActive ? XR_TRUE : XR_FALSE)
            boolean.currentState = .init(bestState.booleanValue ? XR_TRUE : XR_FALSE)
            boolean.changedSinceLastSync = .init(bestState.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            boolean.lastChangeTime = bestState.lastChangeTime
        } else {
            boolean.isActive = .init(XR_FALSE)
            boolean.currentState = .init(XR_FALSE)
            boolean.changedSinceLastSync = .init(XR_FALSE)
            boolean.lastChangeTime = 0
        }
        return XR_SUCCESS
    }
    
    func getActionState(info: XrActionStateGetInfo, vector2f: inout XrActionStateVector2f) -> XrResult {
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(info.action)).takeUnretainedValue()
        
        guard attachedActionSets != nil, attachedActionSets!.contains(where: { $0 === actionObj.actionSet }) else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        guard actionObj.actionType == XR_ACTION_TYPE_VECTOR2F_INPUT else {
            return XR_ERROR_ACTION_TYPE_MISMATCH
        }
        
        let subactionPath = info.subactionPath
        if let res = validateSubactionPath(action: actionObj, subactionPath: subactionPath) {
            return res
        }
        
        let key = ActionStateKey(action: actionObj, subactionPath: subactionPath)
        if let cached = cachedActionStates[key] {
            vector2f.isActive = .init(cached.isActive ? XR_TRUE : XR_FALSE)
            vector2f.currentState = cached.vector2fValue
            vector2f.changedSinceLastSync = .init(cached.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            vector2f.lastChangeTime = cached.lastChangeTime
        } else if subactionPath == XR_NULL_PATH, !actionObj.subactionPaths.isEmpty {
            // Aggregate: longest length
            var bestState = CachedActionState()
            var bestLength: Float = 0
            for sp in actionObj.subactionPaths {
                let spKey = ActionStateKey(action: actionObj, subactionPath: sp)
                if let cached = cachedActionStates[spKey] {
                    if cached.isActive {
                        bestState.isActive = true
                        let length = sqrt(cached.vector2fValue.x * cached.vector2fValue.x + cached.vector2fValue.y * cached.vector2fValue.y)
                        if length > bestLength {
                            bestLength = length
                            bestState.vector2fValue = cached.vector2fValue
                        }
                        bestState.changedSinceLastSync = bestState.changedSinceLastSync || cached.changedSinceLastSync
                    }
                }
            }
            vector2f.isActive = .init(bestState.isActive ? XR_TRUE : XR_FALSE)
            vector2f.currentState = bestState.vector2fValue
            vector2f.changedSinceLastSync = .init(bestState.changedSinceLastSync ? XR_TRUE : XR_FALSE)
            vector2f.lastChangeTime = bestState.lastChangeTime
        } else {
            vector2f.isActive = .init(XR_FALSE)
            vector2f.currentState = .init(x: 0, y: 0)
            vector2f.changedSinceLastSync = .init(XR_FALSE)
            vector2f.lastChangeTime = 0
        }
        return XR_SUCCESS
    }
    
    /// Validate subaction path for action state getter. Returns nil if valid, or an error result.
    private func validateSubactionPath(action: XRAction, subactionPath: XrPath) -> XrResult? {
        if subactionPath == XR_NULL_PATH {
            return nil // Always valid
        }
        // If the action has subaction paths, the queried path must be one of them
        if !action.subactionPaths.isEmpty {
            guard action.subactionPaths.contains(subactionPath) else {
                return XR_ERROR_PATH_UNSUPPORTED
            }
        }
        return nil
    }
    
    func waitFrame(waitInfo: XrFrameWaitInfo?, frameState: inout XrFrameState) -> XrResult {
        print("STUB: xrWaitFrame(\(self), \(waitInfo), \(frameState))") 
        // TODO: these are stub
        // frameState.predictedDisplayTime = .init(clock_gettime_nsec_np(CLOCK_UPTIME_RAW))
        // frameState.predictedDisplayPeriod = 1_000_000_000 / 120
        frameState.shouldRender = .init(XR_TRUE)
        return XR_SUCCESS
    }
    
    func beginFrame(frameBeginInfo: XrFrameBeginInfo?) -> XrResult {
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
                    var endInfo = IPCEndFrameInfo()
                    withUnsafeMutableBytes(of: &endInfo.eyes) {
                        $0.withMemoryRebound(to: IPCEndFrameInfoPerEye.self) { eyes in
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
        guard attachedActionSets != nil else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }
        
        // Only valid top-level user paths are accepted
        switch topLevelUserPath {
        case XR_PATH_USER_HAND_LEFT, XR_PATH_USER_HAND_RIGHT:
            break
        default:
            return XR_ERROR_PATH_UNSUPPORTED
        }
        
        if let profilePath = currentInteractionProfiles[topLevelUserPath] {
            // Find the XrPath for this profile string
            if let pathIndex = xrRegisteredPaths.firstIndex(of: profilePath) {
                interactionProfile.interactionProfile = .init(pathIndex)
            } else {
                interactionProfile.interactionProfile = .init(XR_NULL_PATH)
            }
        } else {
            interactionProfile.interactionProfile = .init(XR_NULL_PATH)
        }
        return XR_SUCCESS
    }
    
    func getReferenceSpaceBoundsRect(referenceSpaceType: XrReferenceSpaceType, boundsRect: inout XrExtent2Df) -> XrResult {
        print("STUB: xrGetReferenceSpaceBoundsRect(\(self), \(referenceSpaceType), \(boundsRect))")
        boundsRect = .init(width: 0, height: 0)
        return XR_SUCCESS
    }

    func requestExit() -> XrResult {
        print("STUB: xrRequestExitSession(\(self))")
        return XR_SUCCESS
    }

    func enumerateBoundSourcesForAction(enumerateInfo: XrBoundSourcesForActionEnumerateInfo, sourceCountOutput: inout UInt32, sources: UnsafeMutableBufferPointer<XrPath>?) -> XrResult {
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(enumerateInfo.action)).takeUnretainedValue()

        // Must return XR_ERROR_ACTIONSET_NOT_ATTACHED if the action's action set was never attached
        guard let attachedActionSets, attachedActionSets.contains(where: { $0 === actionObj.actionSet }) else {
            return XR_ERROR_ACTIONSET_NOT_ATTACHED
        }

        // Collect all bound source paths for this action across active interaction profiles
        var boundSourcePaths: [XrPath] = []

        for (profilePath, bindings) in resolvedBindings {
            // Only consider bindings for profiles that are currently active
            let isActive = currentInteractionProfiles.values.contains(profilePath)
            guard isActive else { continue }

            for binding in bindings {
                guard binding.action === actionObj else { continue }

                // Reconstruct the full source path from top-level user path + component path
                let topLevelStr = xrRegisteredPaths[Int(binding.topLevelUserPath)]
                let fullPath = topLevelStr + "/" + binding.componentPath

                // Convert to XrPath (register if not already registered)
                let pathIndex: XrPath
                if let existingIndex = xrRegisteredPaths.firstIndex(of: fullPath) {
                    pathIndex = XrPath(existingIndex)
                } else {
                    xrRegisteredPaths.append(fullPath)
                    pathIndex = XrPath(xrRegisteredPaths.count - 1)
                }

                // Avoid duplicates
                if !boundSourcePaths.contains(pathIndex) {
                    boundSourcePaths.append(pathIndex)
                }
            }
        }

        // Two-call idiom: if sourceCapacityInput is 0, just return the count
        sourceCountOutput = UInt32(boundSourcePaths.count)

        if let sources, sources.count > 0 {
            guard sources.count >= boundSourcePaths.count else {
                return XR_ERROR_SIZE_INSUFFICIENT
            }
            for i in 0..<boundSourcePaths.count {
                sources[i] = boundSourcePaths[i]
            }
        }

        return XR_SUCCESS
    }

    func getInputSourceLocalizedName(info: XrInputSourceLocalizedNameGetInfo, bufferCountOutput: inout UInt32, buffer: UnsafeMutableBufferPointer<CChar>) -> XrResult {
        print("STUB: xrGetInputSourceLocalizedName(\(self), \(xrRegisteredPaths[Int(info.sourcePath)]))")

        let name = xrRegisteredPaths[Int(info.sourcePath)]
        let nameData: ContiguousArray<CChar> = name.utf8CString

        bufferCountOutput = UInt32(nameData.count)
        if buffer.count == 0 {
            return XR_SUCCESS
        }
        if buffer.count < bufferCountOutput {
            return XR_ERROR_SIZE_INSUFFICIENT
        }

        _ = nameData.withUnsafeBytes { src in
            memcpy(buffer.baseAddress!, src.baseAddress!, .init(bufferCountOutput))
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
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    guard let attachInfo = attachInfo?.pointee else {
        return XR_ERROR_VALIDATION_FAILURE
    }
    
    var actionSets: [XRActionSet] = []
    for i in 0..<Int(attachInfo.countActionSets) {
        let actionSetHandle = attachInfo.actionSets[i]!
        let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(actionSetHandle)).takeUnretainedValue()
        actionSets.append(actionSetObj)
    }
    
    return sessionObj.attachActionSets(actionSets: actionSets)
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
    return sessionObj.waitFrame(waitInfo: waitInfo?.pointee, frameState: &frameState!.pointee)
}

func xrBeginFrame(session: XrSession?, frameBeginInfo: UnsafePointer<XrFrameBeginInfo>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.beginFrame(frameBeginInfo: frameBeginInfo?.pointee)
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

func xrRequestExitSession(session: XrSession?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.requestExit()
}

func xrEnumerateBoundSourcesForAction(session: XrSession?, enumerateInfo: UnsafePointer<XrBoundSourcesForActionEnumerateInfo>?, sourceCapacityInput: UInt32, sourceCountOutput: UnsafeMutablePointer<UInt32>?, sources: UnsafeMutablePointer<XrPath>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }

    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    return sessionObj.enumerateBoundSourcesForAction(enumerateInfo: enumerateInfo!.pointee, sourceCountOutput: &sourceCountOutput!.pointee, sources: .init(start: sources, count: .init(sourceCapacityInput)))
}

func xrGetInputSourceLocalizedName(session: XrSession?, getInfo: UnsafePointer<XrInputSourceLocalizedNameGetInfo>?, bufferCapacityInput: UInt32, bufferCountOutput: UnsafeMutablePointer<UInt32>?, buffer: UnsafeMutablePointer<CChar>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }

    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()

    return sessionObj.getInputSourceLocalizedName(info: getInfo!.pointee, bufferCountOutput: &bufferCountOutput!.pointee, buffer: .init(start: buffer, count: .init(bufferCapacityInput)))
}
