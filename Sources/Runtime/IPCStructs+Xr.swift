//
//  IPCStructs+Xr.swift
//  FruitXR
//
//  Created by user on 2026/02/18.
//

// MARK: - IPC Conversion Helpers

extension XrPosef {
    mutating func set(from transform: IPCTransform) {
        self.position.set(from: transform.position)
        self.orientation.set(from: transform.orientation)
    }

    init(from transform: IPCTransform) {
        self.init(
            orientation: XrQuaternionf(
                x: transform.orientation.x,
                y: transform.orientation.y,
                z: transform.orientation.z,
                w: transform.orientation.w
            ),
            position: XrVector3f(
                x: transform.position.x,
                y: transform.position.y,
                z: transform.position.z
            )
        )
    }
}

extension XrVector3f {
    mutating func set(from position: IPCPosition) {
        self.x = position.x
        self.y = position.y
        self.z = position.z
    }
}

extension XrQuaternionf {
    mutating func set(from orientation: IPCOrientation) {
        self.x = orientation.x
        self.y = orientation.y
        self.z = orientation.z
        self.w = orientation.w
    }
}

// MARK: - Pose Math Utilities

private func cross(_ a: XrVector3f, _ b: XrVector3f) -> XrVector3f {
    return XrVector3f(
        x: a.y * b.z - a.z * b.y,
        y: a.z * b.x - a.x * b.z,
        z: a.x * b.y - a.y * b.x
    )
}

extension XrQuaternionf {
    static var identity: XrQuaternionf { .init(x: 0, y: 0, z: 0, w: 1) }

    /// Returns the Hamilton product self * other.
    func multiplied(by other: XrQuaternionf) -> XrQuaternionf {
        return XrQuaternionf(
            x: w * other.x + x * other.w + y * other.z - z * other.y,
            y: w * other.y - x * other.z + y * other.w + z * other.x,
            z: w * other.z + x * other.y - y * other.x + z * other.w,
            w: w * other.w - x * other.x - y * other.y - z * other.z
        )
    }

    /// Conjugate (equals inverse for unit quaternions).
    var conjugate: XrQuaternionf {
        return XrQuaternionf(x: -x, y: -y, z: -z, w: w)
    }

    /// Rotates a vector by this quaternion: q * v * q^-1.
    func rotate(_ v: XrVector3f) -> XrVector3f {
        let qv = XrVector3f(x: x, y: y, z: z)
        let uv = cross(qv, v)
        let uuv = cross(qv, uv)
        return XrVector3f(
            x: v.x + 2 * (w * uv.x + uuv.x),
            y: v.y + 2 * (w * uv.y + uuv.y),
            z: v.z + 2 * (w * uv.z + uuv.z)
        )
    }
}

extension XrPosef {
    static var identity: XrPosef {
        .init(orientation: .identity, position: XrVector3f(x: 0, y: 0, z: 0))
    }

    /// Composes two poses: self(other(x)) = R_self(R_other(x) + t_other) + t_self.
    func composed(with other: XrPosef) -> XrPosef {
        let newOrientation = orientation.multiplied(by: other.orientation)
        let rotatedPosition = orientation.rotate(other.position)
        let newPosition = XrVector3f(
            x: rotatedPosition.x + position.x,
            y: rotatedPosition.y + position.y,
            z: rotatedPosition.z + position.z
        )
        return XrPosef(orientation: newOrientation, position: newPosition)
    }

    /// Returns the inverse pose P^-1 such that P.composed(with: P^-1) ≈ identity.
    var inverse: XrPosef {
        let invOrientation = orientation.conjugate
        let invPosition = invOrientation.rotate(position)
        return XrPosef(
            orientation: invOrientation,
            position: XrVector3f(x: -invPosition.x, y: -invPosition.y, z: -invPosition.z)
        )
    }
}
