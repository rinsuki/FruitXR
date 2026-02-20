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

    /// Returns the world-space pose of this space, or nil if unlocatable.
    func getWorldPose() -> XrPosef? {
        return nil
    }

    func locate(baseSpace: XRSpace, time: XrTime, spaceLocation: inout XrSpaceLocation) -> XrResult {
        guard let spaceWorldPose = getWorldPose(),
              let baseWorldPose = baseSpace.getWorldPose() else {
            // At least one space is unlocatable
            spaceLocation.locationFlags = 0
            spaceLocation.pose = .identity
            return XR_SUCCESS
        }

        let relativePose = baseWorldPose.inverse.composed(with: spaceWorldPose)
        spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_TRACKED_BIT | XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT
        spaceLocation.pose = relativePose
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

    override func getWorldPose() -> XrPosef? {
        // Per spec: action spaces are unlocatable unless the action set was active in the most recent xrSyncActions
        let isActionSetActive = session.activeActionSets.contains(where: { $0.actionSet === action.actionSet })
        guard isActionSetActive else {
            return nil
        }

        // Determine which top-level user path(s) to use for this space.
        // If subpath is specified, use that. Otherwise, find any binding for this action.
        let topLevelPaths: [XrPath]
        if subpath != XR_NULL_PATH {
            topLevelPaths = [subpath]
        } else if !action.subactionPaths.isEmpty {
            topLevelPaths = action.subactionPaths
        } else {
            // No subaction paths — find from resolved bindings
            var foundPaths: [XrPath] = []
            for bindings in session.resolvedBindings.values {
                for binding in bindings {
                    if binding.action === action, !foundPaths.contains(binding.topLevelUserPath) {
                        foundPaths.append(binding.topLevelUserPath)
                    }
                }
            }
            topLevelPaths = foundPaths
        }

        // Find the first active binding for a pose input
        for path in topLevelPaths {
            let controller: IPCHandController
            switch path {
            case XR_PATH_USER_HAND_LEFT:
                controller = session.currentHeadsetInfo.leftController
            case XR_PATH_USER_HAND_RIGHT:
                controller = session.currentHeadsetInfo.rightController
            default:
                continue
            }

            // Check if there's a resolved binding for this action on this hand
            var hasPoseBinding = false
            var useGrip = false
            for (_, bindings) in session.resolvedBindings {
                for binding in bindings {
                    if binding.action === action && binding.topLevelUserPath == path {
                        hasPoseBinding = true
                        if binding.componentPath == "input/grip/pose" {
                            useGrip = true
                        }
                    }
                }
            }

            if hasPoseBinding {
                let transform = useGrip ? controller.gripTransform : controller.pointerTransform
                let controllerWorldPose = XrPosef(from: transform)
                return controllerWorldPose.composed(with: pose)
            }
        }

        // No matching binding found — unlocatable
        return nil
    }
}

func xrCreateActionSpace(session: XrSession?, createInfo: UnsafePointer<XrActionSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    let actionPtr = createInfo?.pointee.action
    let action = Unmanaged<XRAction>.fromOpaque(.init(actionPtr!)).takeUnretainedValue()

    if createInfo!.pointee.subactionPath != XR_NULL_PATH, !action.subactionPaths.contains(createInfo!.pointee.subactionPath) {
        return XR_ERROR_PATH_UNSUPPORTED
    }
    
    let space = XRActionSpace(session: sessionObj, pose: createInfo!.pointee.poseInActionSpace, action: action, subpath: createInfo!.pointee.subactionPath)
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    print("STUB: xrCreateActionSpace(\(session), \(action), \(createInfo?.pointee))")
    
    return XR_SUCCESS
}

class XRReferenceSpace: XRSpace, CustomStringConvertible {
    static let supportedTypes: [XrReferenceSpaceType] = [
        XR_REFERENCE_SPACE_TYPE_LOCAL,
        XR_REFERENCE_SPACE_TYPE_VIEW,
        XR_REFERENCE_SPACE_TYPE_STAGE,
    ]

    let referenceSpaceType: XrReferenceSpaceType
    
    init(session: XRSession, pose: XrPosef, referenceSpaceType: XrReferenceSpaceType) {
        self.referenceSpaceType = referenceSpaceType
        super.init(session: session, pose: pose)
    }
    
    var description: String {
        return "XRReferenceSpace(type=\(referenceSpaceType), pose=\(pose))"
    }

    override func getWorldPose() -> XrPosef? {
        switch referenceSpaceType {
        case XR_REFERENCE_SPACE_TYPE_LOCAL, XR_REFERENCE_SPACE_TYPE_STAGE:
            // LOCAL/STAGE natural origin is the world origin.
            // The created space's world pose is just poseInReferenceSpace.
            return pose
        case XR_REFERENCE_SPACE_TYPE_VIEW:
            // VIEW natural origin tracks the HMD.
            // The created space's world pose = hmdWorldPose * poseInReferenceSpace.
            let hmdPose = XrPosef(from: session.currentHeadsetInfo.hmd)
            return hmdPose.composed(with: pose)
        default:
            return nil
        }
    }
}

func xrCreateReferenceSpace(session: XrSession?, createInfo: UnsafePointer<XrReferenceSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    let refType = createInfo!.pointee.referenceSpaceType

    // Per spec: must return XR_ERROR_REFERENCE_SPACE_UNSUPPORTED if the type is not supported
    guard XRReferenceSpace.supportedTypes.contains(refType) else {
        return XR_ERROR_REFERENCE_SPACE_UNSUPPORTED
    }

    let space = XRReferenceSpace(session: sessionObj, pose: createInfo!.pointee.poseInReferenceSpace, referenceSpaceType: refType)
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    return XR_SUCCESS
}

func xrDestroySpace(space: XrSpace?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }

    autoreleasepool {
        let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeRetainedValue()
        spaceObj.destroy()
    }
    
    return XR_SUCCESS
}

func xrLocateSpace(space: XrSpace?, baseSpace: XrSpace?, time: XrTime, spaceLocation: UnsafeMutablePointer<XrSpaceLocation>?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }
    guard let baseSpace else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeUnretainedValue()
    let baseSpaceObj = Unmanaged<XRSpace>.fromOpaque(.init(baseSpace)).takeUnretainedValue()

    // Refresh tracking data for accurate poses
    FI_C_SessionGetCurrentInfo(spaceObj.session.port, &spaceObj.session.currentHeadsetInfo)

    return spaceObj.locate(baseSpace: baseSpaceObj, time: time, spaceLocation: &spaceLocation!.pointee)
}
