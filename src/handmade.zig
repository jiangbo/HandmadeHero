const std = @import("std");
const Input = @import("input.zig").Input;

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const GameState = struct {
    toneHz: f32 = 512,
    blueOffset: i32 = 0,
    greenOffset: i32 = 0,
    tSine: f32 = 0,
};

pub const ScreenBuffer = struct {
    memory: ?[]Color = null,
    width: i32,
    height: i32,
};

pub const SoundBuffer = struct {
    samplesPerSecond: i32,
    sampleCount: u32,
    samples: [*]i16,
};

var blueOffset: i32 = 0;
var greenOffset: i32 = 0;
var toneHz: f32 = 512;

pub fn readEntireFile(allocator: std.mem.Allocator, filename: []const u8) []const u8 {
    const file = std.fs.cwd().openFile(filename, .{}) catch unreachable;
    defer file.close();
    return file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch unreachable;
}
pub fn writeEntireFile(filename: []const u8, data: []const u8) void {
    const file = std.fs.cwd().createFile(filename, .{}) catch unreachable;
    defer file.close();
    file.writeAll(data) catch unreachable;
}

pub fn gameUpdateAndRender(state: *GameState, input: Input, buffer: *ScreenBuffer) void {
    for (input.controllers) |controller| {
        if (controller.analog) {
            state.blueOffset += @as(i32, @intFromFloat(4 * controller.stickAverageX));
            state.toneHz = toneHz + 128 * controller.stickAverageY;
        } else {
            if (controller.moveLeft.endedDown) state.blueOffset -= 1;
            if (controller.moveRight.endedDown) state.blueOffset += 1;
        }

        if (controller.actionDown.endedDown) state.greenOffset += 1;
    }

    renderWeirdGradient(buffer, state.blueOffset, state.greenOffset);
}

fn outputSound(state: *GameState, buffer: *SoundBuffer, hz: f32) void {
    const toneVolume: u32 = 3000;
    const samplePerSecond: f32 = @floatFromInt(buffer.samplesPerSecond);
    var sampleOut = buffer.samples;
    for (0..@intCast(buffer.sampleCount)) |_| {
        const sampleValue: i16 = @intFromFloat(@sin(state.tSine) * toneVolume);
        sampleOut[0] = sampleValue;
        sampleOut[1] = sampleValue;
        sampleOut += 2;
        state.tSine += (2.0 * std.math.pi) / (samplePerSecond / hz);
        if (state.tSine >= 2.0 * std.math.pi) state.tSine -= 2.0 * std.math.pi;
    }
}

fn renderWeirdGradient(buffer: *ScreenBuffer, offsetX: i32, offsetY: i32) void {
    const w: usize = @intCast(buffer.width);

    for (0..@as(usize, @intCast(buffer.height))) |y| {
        for (0..w) |x| {
            buffer.memory.?[x + y * w] = .{
                .b = @truncate(x + @as(u32, @bitCast(offsetX))),
                .g = @truncate(y + @as(u32, @bitCast(offsetY))),
            };
        }
    }
}

pub fn getSoundSamples(state: *GameState, soundBuffer: *SoundBuffer) void {
    outputSound(state, soundBuffer, state.toneHz);
}
