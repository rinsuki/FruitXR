//
//  XRAction.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

class XRAction: CustomStringConvertible {
    let actionSet: XRActionSet
    let name: String
    let paths: [XrPath]
    
    init(actionSet: XRActionSet, name: String, paths: [XrPath]) {
        self.actionSet = actionSet
        self.name = name
        self.paths = paths
    }
    
    var description: String {
        return "<XRAction: \(String(format: "%p", unsafeBitCast(self, to: Int.self))), name=\(name), paths=\(paths.map { xrRegisteredPaths[Int($0)] })>"
    }
    
    func destroy() {
        print("STUB: destroy XRAction")
    }
}

func xrCreateAction(actionSet: XrActionSet?, createInfo: UnsafePointer<XrActionCreateInfo>?, actionPtr: UnsafeMutablePointer<XrAction?>?) -> XrResult {
    guard let actionSet else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let actionSetObj = Unmanaged<XRActionSet>.fromOpaque(.init(actionSet)).takeUnretainedValue()
    var paths: [XrPath] = []
    for i in 0..<createInfo!.pointee.countSubactionPaths {
        let pathPtr = createInfo!.pointee.subactionPaths.advanced(by: Int(i)).pointee
        paths.append(pathPtr)
    }
    
    var createInfo = createInfo!.pointee
    // TODO: feels unsafe
    let name = withUnsafeBytes(of: &createInfo.actionName) { ptr in
        return String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
    }
    let action = XRAction(actionSet: actionSetObj, name: name, paths: paths)
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


