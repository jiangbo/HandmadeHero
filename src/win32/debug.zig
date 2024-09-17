const std = @import("std");
const main = @import("../main.zig");
const game = @import("../game.zig");

const win32ScreenBuffer = main.win32ScreenBuffer;
const Win32SoundOutput = main.Win32SoundOutput;

fn win32DebugDrawVertical(
    backBuffer: *win32ScreenBuffer,
    x: usize,
    top: usize,
    bottom: usize,
    color: game.Color,
) void {
    std.debug.assert(backBuffer.height >= bottom);
    const w: usize = @intCast(backBuffer.width);
    for (top..bottom) |index| {
        backBuffer.memory.?[index * w + x] = color;
    }
}

fn win32DrawSoundBufferMarker(
    backBuffer: *win32ScreenBuffer,
    c: f32,
    padX: u32,
    top: usize,
    bottom: usize,
    value: u32,
    color: game.Color,
) void {
    const xReal32 = c * @as(f32, @floatFromInt(value));
    const x = padX + @as(usize, @intFromFloat(xReal32));
    win32DebugDrawVertical(backBuffer, x, top, bottom, color);
}

fn win32DebugSyncDisplay(
    backBuffer: *win32ScreenBuffer,
    markers: []Win32TimeMarker,
    currentMarkerIndex: usize,
    soundOutput: *Win32SoundOutput,
) void {
    const padX = 16;
    const padY = 16;
    const lineHeight = 64;

    const a: f32 = @floatFromInt(backBuffer.width - 2 * padX);
    const c = a / @as(f32, @floatFromInt(soundOutput.secondaryBufferSize));
    const playColor = game.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    const writeColor = game.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const expectedFlipColor = game.Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
    const playWindowColor = game.Color{ .r = 255, .g = 0, .b = 255, .a = 255 };

    for (markers, 0..) |marker, markerIndex| {
        std.debug.assert(marker.outputPlayCursor < soundOutput.secondaryBufferSize);
        std.debug.assert(marker.outputWriteCursor <= soundOutput.secondaryBufferSize);
        std.debug.assert(marker.outputLocation <= soundOutput.secondaryBufferSize);
        std.debug.assert(marker.outputByteCount <= soundOutput.secondaryBufferSize);
        std.debug.assert(marker.flipPlayCursor < soundOutput.secondaryBufferSize);
        std.debug.assert(marker.flipWriteCursor <= soundOutput.secondaryBufferSize);

        var top = padY;
        var bottom: usize = @intCast(padY + lineHeight);

        if (markerIndex == currentMarkerIndex) {
            top += lineHeight + padY;
            bottom += lineHeight + padY;

            const firstTop = top;

            win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
                marker.outputPlayCursor, playColor);
            win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
                marker.outputWriteCursor, writeColor);

            top += lineHeight + padY;
            bottom += lineHeight + padY;

            win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
                marker.outputLocation, playColor);
            win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
                marker.outputLocation + marker.outputByteCount, writeColor);

            top += lineHeight + padY;
            bottom += lineHeight + padY;

            win32DrawSoundBufferMarker(backBuffer, c, padX, firstTop, bottom, //
                marker.expectedFlipCursor, expectedFlipColor);
        }

        win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
            marker.flipPlayCursor, playColor);

        win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
            marker.flipPlayCursor * 480 * soundOutput.bytesPerSample, playWindowColor);

        win32DrawSoundBufferMarker(backBuffer, c, padX, top, bottom, //
            marker.flipWriteCursor, writeColor);
    }
}

const Win32TimeMarker = struct {
    outputPlayCursor: u32 = 0,
    outputWriteCursor: u32 = 0,
    outputLocation: u32 = 0,
    outputByteCount: u32 = 0,
    expectedFlipCursor: u32 = 0,

    flipPlayCursor: u32 = 0,
    flipWriteCursor: u32 = 0,
};
