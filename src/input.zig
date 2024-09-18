const std = @import("std");

pub const ButtonState = struct {
    halfTransitionCount: u32,
    endedDown: bool,
};

pub const ControllerInput = struct {
    connected: bool = false,
    analog: bool = false,

    stickAverageX: f32 = 0,
    stickAverageY: f32 = 0,

    moveUp: ButtonState,
    moveDown: ButtonState,
    moveLeft: ButtonState,
    moveRight: ButtonState,

    actionUp: ButtonState,
    actionDown: ButtonState,
    actionLeft: ButtonState,
    actionRight: ButtonState,

    leftShoulder: ButtonState,
    rightShoulder: ButtonState,

    back: ButtonState,
    start: ButtonState,

    terminator: ButtonState,

    pub fn copyEndedDown(self: *ControllerInput, old: *ControllerInput) void {
        self.moveUp.endedDown = old.moveUp.endedDown;
        self.moveDown.endedDown = old.moveDown.endedDown;
        self.moveLeft.endedDown = old.moveLeft.endedDown;
        self.moveRight.endedDown = old.moveRight.endedDown;

        self.actionUp.endedDown = old.actionUp.endedDown;
        self.actionDown.endedDown = old.actionDown.endedDown;
        self.actionLeft.endedDown = old.actionLeft.endedDown;
        self.actionRight.endedDown = old.actionRight.endedDown;

        self.leftShoulder.endedDown = old.leftShoulder.endedDown;
        self.rightShoulder.endedDown = old.rightShoulder.endedDown;

        self.back.endedDown = old.back.endedDown;
        self.start.endedDown = old.start.endedDown;
        self.terminator.endedDown = old.terminator.endedDown;
    }
};

pub const Input = struct {
    mouseX: i32 = 0,
    mouseY: i32 = 0,
    mouseButtons: [5]ButtonState = undefined,

    controllers: [5]ControllerInput = undefined,
};
