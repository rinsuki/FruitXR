//
//  XRActionSet.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation

class XRActionSet {
    let instance: XRInstance
    private(set) var destroyed = false
    
    init(instance: XRInstance) {
        self.instance = instance
    }
    
    deinit {
        precondition(destroyed)
    }
    
    func destroy() {
        destroyed = true
    }
}

func xrCreateActionSet(instance: XrInstance?, createInfo: UnsafePointer<XrActionSetCreateInfo>?, actionSetPtr: UnsafeMutablePointer<XrActionSet?>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    let actionSet = XRActionSet(instance: instanceObj)
    let ptr = Unmanaged.passRetained(actionSet).toOpaque()
    actionSetPtr!.pointee = OpaquePointer(ptr)
    
    return XR_SUCCESS
}

func xrDestroyActionSet(actionSet: XrActionSet?) -> XrResult {
    guard let actionSet else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    autoreleasepool {
        let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(actionSet)).takeRetainedValue()
        actionSetObj.destroy()
    }
    
    return XR_SUCCESS
}
