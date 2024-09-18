const std = @import("std");
const Input = @import("input.zig").Input;

pub const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

pub const GameState = struct {
    playerX: i32 = 100,
    playerY: i32 = 100,
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
    for (input.controllers) |controller| {
        var playerX: i32, var playerY: i32 = .{ 0, 0 };
        if (controller.moveUp.endedDown) playerY = -1;
        if (controller.moveDown.endedDown) playerY = 1;
        if (controller.moveLeft.endedDown) playerX = -1;
        if (controller.moveRight.endedDown) playerX = 1;

        const nano: i32 = @intCast(input.nanoPerFrame / 10000000);
        state.playerX += nano * playerX;
        state.playerY += nano * playerY;
    }

    const tileMap: [width * height]u8 = .{
        1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, //
        1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1,
        1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1,
        1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1,
        1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1,
        1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1,
    };

    const upperLeftX: i32 = -30;
    const upperLeftY: i32 = 0;
    const tileWidth: i32 = 60;
    const tileHeight: i32 = 60;

    var rect = Rect{ .maxX = buffer.width, .maxY = buffer.height };
    drawRectangle(buffer, rect, .{ .r = 0xFF, .g = 0x00, .b = 0xFF });

    for (&tileMap, 0..) |tile, index| {
        const color: Color = if (tile == 1)
            .{ .r = 0xFF, .g = 0xFF, .b = 0xFF }
        else
            .{ .r = 128, .g = 128, .b = 128 };

        const i: i32 = @intCast(index);
        const minX: i32 = upperLeftX + tileWidth * @mod(i, width);
        const minY: i32 = upperLeftY + tileHeight * @divTrunc(i, width);
        rect = .{
            .minX = minX,
            .minY = minY,
            .maxX = minX + tileWidth,
            .maxY = minY + tileHeight,
        };

        drawRectangle(buffer, rect, color);
    }

    const playerWidth = tileWidth / 4 * 3;
    const playerHeight = tileHeight;
    const playerLeft = state.playerX - playerWidth / 2;
    const playerTop = state.playerY - playerHeight;

    rect = Rect{
        .minX = std.math.clamp(playerLeft, 0, buffer.width - playerWidth),
        .minY = std.math.clamp(playerTop, 0, buffer.width - playerHeight),
        .maxX = std.math.clamp(playerLeft + playerWidth, playerWidth, buffer.width),
        .maxY = std.math.clamp(playerTop + playerHeight, playerHeight, buffer.height),
    };
    // std.log.debug("player rect: {any}", .{rect});
    drawRectangle(buffer, rect, .{ .r = 0xFF });
}

const width = 17;
const height = 9;

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

pub fn getSoundSamples(state: *GameState, soundBuffer: *SoundBuffer) void {
    outputSound(state, soundBuffer, 400);
}
