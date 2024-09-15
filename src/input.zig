const std = @import("std");

pub const ButtonState = struct {
    halfTransitionCount: u32,
    endedDown: bool,
};

pub const ControllerInput = struct {
    analog: bool = false,
    startX: f32 = 0.0,
    startY: f32 = 0.0,
    minX: f32 = 0.0,
    minY: f32 = 0.0,
    maxX: f32 = 0.0,
    maxY: f32 = 0.0,
    endX: f32 = 0.0,
    endY: f32 = 0.0,

    extend: struct {
        up: ButtonState,
        down: ButtonState,
        left: ButtonState,
        right: ButtonState,
        leftShoulder: ButtonState,
        rightShoulder: ButtonState,
    },
};

pub const Input = struct {
    controllers: [4]ControllerInput = undefined,
};
