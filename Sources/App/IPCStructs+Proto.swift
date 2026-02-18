extension IPCTransform {
    mutating func set(from proto: Transform) {
        self.position.set(from: proto.position)
        self.orientation.set(from: proto.orientation)
    }
}

extension IPCPosition {
    mutating func set(from proto: Position) {
        self.x = proto.x
        self.y = proto.y
        self.z = proto.z
    }
}

extension IPCOrientation {
    mutating func set(from proto: Orientation) {
        self.x = proto.x
        self.y = proto.y
        self.z = proto.z
        self.w = proto.w
    }
}

extension IPCHandController {
    mutating func set(from proto: HandController) {
        self.transform.set(from: proto.transform)
        self.thumbstick_x = proto.stickX
        self.thumbstick_y = proto.stickY
        self.trigger = proto.trigger
        self.squeeze = proto.squeeze
        self.buttons = proto.buttons
    }
}
