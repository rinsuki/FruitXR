//
//  XRAction.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

class XRAction: CustomStringConvertible {
    let actionSet: XRActionSet
    let name: String
    let localizedName: String
    let actionType: XrActionType
    /// The subaction paths this action was created with (e.g. /user/hand/left, /user/hand/right).
    /// Empty means the action does not use subaction path filtering.
    let subactionPaths: [XrPath]
    
    init(actionSet: XRActionSet, name: String, localizedName: String, actionType: XrActionType, subactionPaths: [XrPath]) {
        self.actionSet = actionSet
        self.name = name
        self.localizedName = localizedName
        self.actionType = actionType
        self.subactionPaths = subactionPaths
    }
    
    var description: String {
        return "<XRAction: \(String(format: "%p", unsafeBitCast(self, to: Int.self))), name=\(name), type=\(actionType), subactionPaths=\(subactionPaths.map { xrRegisteredPaths[Int($0)] })>"
    }
    
    func destroy() {
    }
}

func xrCreateAction(actionSet: XrActionSet?, createInfo: UnsafePointer<XrActionCreateInfo>?, actionPtr: UnsafeMutablePointer<XrAction?>?) -> XrResult {
    guard let actionSet else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(actionSet)).takeUnretainedValue()
    
    guard !actionSetObj.attached else {
        return XR_ERROR_ACTIONSETS_ALREADY_ATTACHED
    }
    
    var subactionPaths: [XrPath] = []
    for i in 0..<createInfo!.pointee.countSubactionPaths {
        let pathPtr = createInfo!.pointee.subactionPaths.advanced(by: Int(i)).pointee
        subactionPaths.append(pathPtr)
    }
    
    var createInfo = createInfo!.pointee
    let name = withUnsafeBytes(of: &createInfo.actionName) { ptr in
        return String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
    }
    let localizedName = withUnsafeBytes(of: &createInfo.localizedActionName) { ptr in
        return String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
    }
    let action = XRAction(actionSet: actionSetObj, name: name, localizedName: localizedName, actionType: createInfo.actionType, subactionPaths: subactionPaths)
    actionSetObj.actions.append(action)
    let ptr = Unmanaged.passRetained(action).toOpaque()
    actionPtr!.pointee = OpaquePointer(ptr)
    
    return XR_SUCCESS
}

func xrDestroyAction(action: XrAction?) -> XrResult {
    guard let action else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    autoreleasepool {
        let actionObj = Unmanaged<XRAction>.fromOpaque(.init(action)).takeRetainedValue()
        actionObj.destroy()
    }
    
    return XR_SUCCESS
}


