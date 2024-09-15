const std = @import("std");

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const ScreenBuffer = struct {
    memory: ?[]Color = null,
    width: i32,
    height: i32,
};

pub fn gameUpdateAndRender(buffer: *ScreenBuffer, offsetX: usize) void {
    renderWeirdGradient(buffer, offsetX, 0);
}

fn renderWeirdGradient(buffer: *ScreenBuffer, offsetX: usize, offsetY: usize) void {
    const w: usize = @intCast(buffer.width);
    for (0..@as(usize, @intCast(buffer.height))) |y| {
        for (0..w) |x| {
            buffer.memory.?[x + y * w] = .{
                .b = @truncate(x + offsetX),
                .g = @truncate(y + offsetY),
            };
        }
    }
}
