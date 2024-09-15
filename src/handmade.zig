const std = @import("std");
const input = @import("input.zig");

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const GameState = struct {
    toneHz: f32 = 256,
    blueOffset: i32 = 0,
    greenOffset: i32 = 0,
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
var toneHz: f32 = 256;

pub fn gameUpdateAndRender(
    state: *GameState,
    inputs: input.Input,
    screenBuffer: *ScreenBuffer,
    soundBuffer: *SoundBuffer,
) void {
    const input0 = inputs.controllers[0];
    if (input0.analog) {
        state.blueOffset += @as(i32, @intFromFloat(4 * input0.startX));
        state.toneHz = 256 + 128 * input0.endY;
    }
    if (input0.extend.down.endedDown) state.greenOffset += 1;

    outputSound(soundBuffer, state.toneHz);
    renderWeirdGradient(screenBuffer, state.blueOffset, state.greenOffset);
}

var tSine: f32 = 0;
const toneVolume: u32 = 3000;
fn outputSound(buffer: *SoundBuffer, hz: f32) void {
    const samplePerSecond: f32 = @floatFromInt(buffer.samplesPerSecond);
    var sampleOut = buffer.samples;
    for (0..@intCast(buffer.sampleCount)) |_| {
        {
            const sampleValue: i16 = @intFromFloat(@sin(tSine) * toneVolume);
            sampleOut[0] = sampleValue;
            sampleOut[1] = sampleValue;
            sampleOut += 2;

            tSine += (2.0 * std.math.pi) / (samplePerSecond / hz);
        }
    }
}

fn renderWeirdGradient(buffer: *ScreenBuffer, offsetX: i32, offsetY: i32) void {
    const w: usize = @intCast(buffer.width);
    const ox: usize = @intCast(@abs(offsetX));
    const oy: usize = @intCast(@abs(offsetY));

    for (0..@as(usize, @intCast(buffer.height))) |y| {
        for (0..w) |x| {
            buffer.memory.?[x + y * w] = .{
                .b = @truncate(x + ox),
                .g = @truncate(y + oy),
            };
        }
    }
}
