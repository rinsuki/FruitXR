//
//  XRActionSet.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation

class XRActionSet {
    let instance: XRInstance
    let name: String
    let localizedName: String
    var actions: [XRAction] = []
    /// Whether this action set has been attached to a session via xrAttachSessionActionSets
    private(set) var attached = false
    private(set) var destroyed = false
    
    init(instance: XRInstance, name: String, localizedName: String) {
        self.instance = instance
        self.name = name
        self.localizedName = localizedName
    }
    
    deinit {
        precondition(destroyed)
    }
    
    func markAttached() {
        attached = true
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
    
    var info = createInfo!.pointee
    let name = withUnsafeBytes(of: &info.actionSetName) { ptr in
        return String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
    }
    let localizedName = withUnsafeBytes(of: &info.localizedActionSetName) { ptr in
        return String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
    }
    
    let actionSet = XRActionSet(instance: instanceObj, name: name, localizedName: localizedName)
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
