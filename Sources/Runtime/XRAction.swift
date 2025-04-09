//
//  XRAction.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

class XRAction {
    let actionSet: XRActionSet
    
    init(actionSet: XRActionSet) {
        self.actionSet = actionSet
    }
}

func xrCreateAction(actionSet: XrActionSet?, createInfo: UnsafePointer<XrActionCreateInfo>?, actionPtr: UnsafeMutablePointer<XrAction?>?) -> XrResult {
    guard let actionSet else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(actionSet)).takeUnretainedValue()
    
    let action = XRAction(actionSet: actionSetObj)
    let ptr = Unmanaged.passRetained(action).toOpaque()
    actionPtr!.pointee = OpaquePointer(ptr)
    
    return XR_SUCCESS
}



