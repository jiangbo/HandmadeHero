const std = @import("std");

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const ScreenBuffer = struct {
    memory: ?[]Color = null,
    width: i32,
    height: i32,
};

pub const SoundBuffer = struct {
    samplesPerSecond: u32,
    sampleCount: u32,
    samples: [*]i16,
};

pub fn gameUpdateAndRender(screenBuffer: *ScreenBuffer, soundBuffer: *SoundBuffer) void {
    const toneHz = 256;
    outputSound(soundBuffer, toneHz);
    renderWeirdGradient(screenBuffer, 0, 0);
}

var tSine: f32 = 0;
const toneVolume: u32 = 3000;
fn outputSound(buffer: *SoundBuffer, toneHz: u32) void {
    const wavePeriod: f32 = @floatFromInt(buffer.samplesPerSecond / toneHz);

    var sampleOut = buffer.samples;
    for (0..@intCast(buffer.sampleCount)) |_| {
        {
            const sampleValue: i16 = @intFromFloat(@sin(tSine) * toneVolume);
            sampleOut[0] = sampleValue;
            sampleOut[1] = sampleValue;
            sampleOut += 2;

            tSine += (2.0 * std.math.pi) / wavePeriod;
        }
    }
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
