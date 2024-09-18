const std = @import("std");
const Input = @import("input.zig").Input;

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const GameState = struct {};

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

const RectF = struct {
    minX: f32 = 0,
    minY: f32 = 0,
    maxX: f32 = 0,
    maxY: f32 = 0,

    fn toRect(self: RectF) Rect {
        return Rect{
            .minX = @floatFromInt(self.minX),
            .minY = @floatFromInt(self.minY),
            .maxX = @floatFromInt(self.maxX),
            .maxY = @floatFromInt(self.maxY),
        };
    }
};

const Rect = struct {
    minX: i32 = 0,
    minY: i32 = 0,
    maxX: i32 = 0,
    maxY: i32 = 0,
};

fn drawRectangle(buffer: *ScreenBuffer, rect: Rect, color: Color) void {
    const minX: usize = @intCast(std.math.clamp(rect.minX, 0, rect.maxX));
    const minY: usize = @intCast(std.math.clamp(rect.minY, 0, rect.maxY));
    const w: usize = @intCast(buffer.width);
    const h: usize = @intCast(buffer.height);
    const maxX = std.math.clamp(@as(usize, @intCast(rect.maxX)), minX, w);
    const maxY = std.math.clamp(@as(usize, @intCast(rect.maxY)), minY, h);

    for (minY..maxY) |y| {
        const dest = buffer.memory.?[y * w + minX .. y * w + maxX];
        @memset(dest, color);
    }
}

pub fn gameUpdateAndRender(state: *GameState, input: Input, buffer: *ScreenBuffer) void {
    for (input.controllers) |_| {}
    _ = state;

    var rect = Rect{ .maxX = buffer.width, .maxY = buffer.height };
    drawRectangle(buffer, rect, .{ .r = 0xFF, .g = 0x00, .b = 0xFF });
    rect = Rect{ .minX = 10, .minY = 10, .maxX = 40, .maxY = 40 };
    drawRectangle(buffer, rect, .{ .g = 0xFF, .b = 0xFF });
}

fn outputSound(state: *GameState, buffer: *SoundBuffer, hz: f32) void {
    const samplePerSecond: f32 = @floatFromInt(buffer.samplesPerSecond);
    var sampleOut = buffer.samples;
    for (0..@intCast(buffer.sampleCount)) |_| {
        const sampleValue: i16 = 0;
        // const toneVolume: u32 = 3000;
        // const sampleValue: i16 = @intFromFloat(@sin(state.tSine) * toneVolume);
        sampleOut[0] = sampleValue;
        sampleOut[1] = sampleValue;
        sampleOut += 2;
    }

    _ = samplePerSecond;
    _ = hz;
    _ = state;
}

const playerSize: u8 = 10;
fn renderPlayer(buffer: *ScreenBuffer, playerX: u32, playerY: u32) void {
    const playerColor = Color{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 0xFF };

    const w: u16 = @intCast(buffer.width);
    for (playerY..playerY + playerSize) |y| {
        const dest = buffer.memory.?[y * w + playerX ..][0..playerSize];
        @memset(dest, playerColor);
    }
}

// fn renderWeirdGradient(buffer: *ScreenBuffer, offsetX: i32, offsetY: i32) void {
//     const w: usize = @intCast(buffer.width);

//     for (0..@as(usize, @intCast(buffer.height))) |y| {
//         for (0..w) |x| {
//             buffer.memory.?[x + y * w] = .{
//                 .b = @truncate(x + @as(u32, @bitCast(offsetX))),
//                 .g = @truncate(y + @as(u32, @bitCast(offsetY))),
//             };
//         }
//     }
// }

pub fn getSoundSamples(state: *GameState, soundBuffer: *SoundBuffer) void {
    outputSound(state, soundBuffer, 400);
}
