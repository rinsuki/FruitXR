//
//  XRSpace.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation

class XRSpace {
    let session: XRSession
    let pose: XrPosef

    private(set) var destroyed = false
    
    init(session: XRSession, pose: XrPosef) {
        self.session = session
        self.pose = pose
    }

    deinit {
        assert(destroyed)
    }
    
    func destroy() {
        destroyed = true
    }
    
    func locate(baseSpace: XRSpace?, time: XrTime, spaceLocation: inout XrSpaceLocation) -> XrResult {
        print("STUB: XRSpace.locate(self=\(self), base=\(baseSpace), \(time), \(spaceLocation))")
        spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_TRACKED_BIT | XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT
        spaceLocation.pose.position = .init(x: 0, y: 0, z: 0)
        spaceLocation.pose.orientation = .init(x: 0, y: 0, z: 0, w: 1)
        return XR_SUCCESS
    }
}

class XRActionSpace: XRSpace, CustomStringConvertible {
    let action: XRAction
    let subpath: XrPath
    
    init(session: XRSession, pose: XrPosef, action: XRAction, subpath: XrPath) {
        self.action = action
        self.subpath = subpath
        super.init(session: session, pose: pose)
    }

    var description: String {
        return "XRActionSpace(action=\(action))"
    }

    override func locate(baseSpace: XRSpace?, time: XrTime, spaceLocation: inout XrSpaceLocation) -> XrResult {
        switch subpath {
        case XR_PATH_USER_HAND_LEFT:
            spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_TRACKED_BIT | XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT
            spaceLocation.pose.set(from: session.currentHeadsetInfo.leftController.pointerTransform)
        case XR_PATH_USER_HAND_RIGHT:
            spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_TRACKED_BIT | XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT
            spaceLocation.pose.set(from: session.currentHeadsetInfo.rightController.pointerTransform)
        default:
            spaceLocation.locationFlags = 0
        }
        // TODO: care about baseSpace and pose
        return XR_SUCCESS
    }
}

func xrCreateActionSpace(session: XrSession?, createInfo: UnsafePointer<XrActionSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    let actionPtr = createInfo?.pointee.action
    let action = Unmanaged<XRAction>.fromOpaque(.init(actionPtr!)).takeUnretainedValue()

    if createInfo!.pointee.subactionPath != XR_NULL_PATH, !action.paths.contains(createInfo!.pointee.subactionPath) {
        return XR_ERROR_PATH_UNSUPPORTED
    }
    
    let space = XRActionSpace(session: sessionObj, pose: createInfo!.pointee.poseInActionSpace, action: action, subpath: createInfo!.pointee.subactionPath)
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    print("STUB: xrCreateActionSpace(\(session), \(action), \(createInfo?.pointee))")
    
    return XR_SUCCESS
}

class XRReferenceSpace: XRSpace, CustomStringConvertible {
    let referenceSpaceType: XrReferenceSpaceType
    
    init(session: XRSession, pose: XrPosef, referenceSpaceType: XrReferenceSpaceType) {
        self.referenceSpaceType = referenceSpaceType
        super.init(session: session, pose: pose)
    }
    
    var description: String {
        return "XRReferenceSpace(type=\(referenceSpaceType), pose=\(pose))"
    }
}

func xrCreateReferenceSpace(session: XrSession?, createInfo: UnsafePointer<XrReferenceSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    let space = XRReferenceSpace(session: sessionObj, pose: createInfo!.pointee.poseInReferenceSpace, referenceSpaceType: createInfo!.pointee.referenceSpaceType)
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    return XR_SUCCESS
}

func xrDestroySpace(space: XrSpace?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }

    autoreleasepool {
        let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeUnretainedValue()
        spaceObj.destroy()
    }
    
    return XR_SUCCESS
}

func xrLocateSpace(space: XrSpace?, baseSpace: XrSpace?, time: XrTime, spaceLocation: UnsafeMutablePointer<XrSpaceLocation>?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeUnretainedValue()
    let baseSpaceObj: XRSpace?
    if let baseSpace {
        baseSpaceObj = Unmanaged<XRSpace>.fromOpaque(.init(baseSpace)).takeUnretainedValue()
    } else {
        baseSpaceObj = nil
    }

    return spaceObj.locate(baseSpace: baseSpaceObj, time: time, spaceLocation: &spaceLocation!.pointee)
}
